import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

const _defaultOrg = 'noco';

sealed class NcFile {}

class NcPlatformFile extends NcFile {
  NcPlatformFile(this.platformFile);
  final PlatformFile platformFile;
}

class NcXFile extends NcFile {
  NcXFile(this.xFile);
  final XFile xFile;
}

class EmptyResult {}

final emptyResult = EmptyResult();

String pp(final Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

class _HttpClient extends http.BaseClient {
  _HttpClient(this._baseHttpClient);
  final http.Client _baseHttpClient;
  final Map<String, String> _headers = {};

  addHeaders(final Map<String, String> headers) {
    _headers.addAll(headers);
  }

  removeHeader(final String key) {
    _headers.remove(key);
  }

  @override
  Future<http.StreamedResponse> send(final http.BaseRequest request) {
    final headers = _headers;
    if (0 < (request.contentLength ?? 0)) {
      headers.addAll(
        {
          'Content-type': 'application/json',
        },
      );
    }
    request.headers.addAll(headers);
    return _baseHttpClient.send(request);
  }
}

enum HttpMethod {
  get,
  post,
  patch,
  delete,
}

extension HttpMethodEx on HttpMethod {
  model.HttpFn toFn(final http.Client client) => switch (this) {
        HttpMethod.get => HttpFn.get(client.get),
        HttpMethod.post => HttpFn.others(client.post),
        HttpMethod.patch => HttpFn.others(client.patch),
        HttpMethod.delete => HttpFn.others(client.delete),
      };
}

class _Api {
  late final _HttpClient _client = _HttpClient(http.Client());
  late Uri _baseUri;
  Uri get uri => _baseUri;

  init(final String url, {final String? authToken}) {
    _baseUri = Uri.parse(url);
    if (authToken != null) {
      _client.addHeaders({'xc-auth': authToken});
    } else {
      _client.removeHeader('xc-auth');
    }
  }

  bool get isReady => _client._headers.containsKey('xc-auth');

  void throwExceptionIfKeyExists({
    required final String key,
    required final Map data,
  }) {
    if (!data.containsKey(key)) {
      return;
    }
    final exception = data[key];
    if (exception.toString() == 'success') {
      return;
    }
    logger.info('$key: $exception');
    throw Exception(exception);
  }

  _logResponse(final http.Response res) {
    logger.finer(
      '<= ${res.request?.method} ${res.request?.url.path} ${res.statusCode} ${res.body}',
    );
  }

  dynamic _decode(
    final http.Response res, {
    final List<int> expectedStatusCode = const [],
  }) {
    _logResponse(res);

    final isJson =
        res.headers['content-type']?.contains('application/json') ?? false;
    if (isJson && res.body.isNotEmpty) {
      final data = json.decode(res.body);
      if (!expectedStatusCode.contains(res.statusCode)) {
        if (data is Map) {
          throwExceptionIfKeyExists(key: 'msg', data: data);
          throwExceptionIfKeyExists(key: 'message', data: data);
        } else {
          throw Exception(
            'INVALID_STATUS_CODE. expected: $expectedStatusCode, actual: ${res.statusCode}',
          );
        }
      }

      return data;
    }
    return null;
  }

  Uri _uri({
    final Uri? baseUri,
    final String? path,
    final Iterable<String> pathSegments = const [],
    final Map<String, dynamic>? queryParameters,
    final String? baseUrl,
  }) {
    assert(path != null || pathSegments.isNotEmpty);
    final uri = baseUri ?? _baseUri;
    return path != null
        ? uri.replace(path: path, queryParameters: queryParameters)
        : uri.replace(
            pathSegments: pathSegments
                .map((final v) => v.split('/'))
                .expand((final v) => v),
            queryParameters: queryParameters,
          );
  }

  Future<Result<T>> _send<T>({
    required final HttpMethod method,
    final Uri? baseUri,
    final String? path,
    final Iterable<String> pathSegments = const [],
    final String? body,
    final Map<String, dynamic>? queryParameters,
    final String? baseUrl,
    final http.Client? httpClient,
    final Map<String, String>? headers,
    final List<int> expectedStatusCode = const [],
    required final T Function(http.Response res, dynamic data) serializer,
  }) async {
    try {
      final client = httpClient ?? _client;
      final uri = _uri(
        baseUri: baseUri,
        path: path,
        pathSegments: pathSegments,
        queryParameters: queryParameters,
        baseUrl: baseUrl,
      );
      final censored = body?.contains('password') == true ? '{***}' : body;

      logger.finer(
        '=> ${method.name.toUpperCase()} ${uri.path} ${uri.queryParametersAll.isNotEmpty ? uri.queryParametersAll : '-'} ${censored ?? '-'}',
      );
      final res = await method.toFn(client).when(
            get: (final fn) async => await fn.call(uri, headers: headers),
            others: (final fn) async => await fn.call(
              uri,
              body: body,
              headers: headers,
            ),
          );
      final data = _decode(res, expectedStatusCode: expectedStatusCode);

      return Result.ok(serializer(res, data));
    } catch (err, s) {
      return Result.ng(err, s);
    }
  }

  Future<model.Result<bool>> version(
    final String endpoint, {
    final String? authToken,
  }) async {
    final headers = authToken != null ? {'xc-auth': authToken} : null;
    return await _send(
      baseUri: Uri.parse(endpoint),
      method: HttpMethod.get,
      path: '/api/v1/version',
      httpClient: http.Client(), // This function should use plain HTTP client.
      headers: headers,
      serializer: (final res, final _) => res.statusCode == 200,
    );
  }

  Future<model.Result<String>> authSignin(
    final String email,
    final String password,
  ) async =>
      await _send<String>(
        method: HttpMethod.post,
        path: '/api/v1/auth/user/signin',
        body: json.encode({
          'email': email,
          'password': password,
        }),
        httpClient:
            http.Client(), // This function should use plain HTTP client.
        headers: {'Content-type': 'application/json'},
        expectedStatusCode: [200],
        serializer: (final _, final data) {
          final {'token': token} = data;
          if (token == null) {
            throw Exception('authSignin failed.');
          }

          _client.addHeaders({'xc-auth': token});
          return token;
        },
      );

  Future<Result<model.NcUser>> authUserMe([
    final Map<String, dynamic>? queryParameters,
  ]) async =>
      await _send(
        method: HttpMethod.get,
        path: '/api/v1/auth/user/me',
        serializer: (final _, final data) => model.NcUser.fromJson(data),
      );

  Future<model.Result<model.NcList<model.NcProject>>> projectList() async =>
      await _send(
        method: HttpMethod.get,
        path: '/api/v1/db/meta/projects',
        serializer: (final _, final data) => model.NcProjectList.fromJson(
          data,
          model.fromJsonT<model.NcProject>,
        ),
      );

  Future<model.Result<model.NcSimpleTableList>> dbTableList({
    required final String projectId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/projects',
          projectId,
          'tables',
        ],
        serializer: (final res, final data) =>
            model.NcSimpleTableList.fromJson(data),
      );

  Future<model.Result<model.NcTable>> dbTableRead({
    required final String tableId,
  }) async =>
      _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/tables',
          tableId,
        ],
        serializer: (final res, final data) => model.NcTable.fromJson(data),
      );

  Future<model.Result<model.ViewList>> dbViewList({
    required final String tableId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/tables',
          tableId,
          'views',
        ],
        serializer: (final res, final data) => model.ViewList.fromJson(data),
      );

  Future<model.Result<model.NcView>> dbViewUpdate({
    required final String viewId,
    required final Map<String, dynamic> data,
  }) async =>
      await _send(
        method: HttpMethod.patch,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
        ],
        body: json.encode(data),
        serializer: (final _, final data) => model.NcView.fromJson(data),
      );

  Future<Result<List<model.NcViewColumn>>> dbViewColumnList({
    required final String viewId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
          'columns',
        ],
        serializer: (final _, final data) {
          final {'list': list as List} = data;
          return List<model.NcViewColumn>.from(
            list.map((final c) => model.NcViewColumn.fromJson(c)),
          );
        },
      );

  Future<Result<EmptyResult>> dbViewColumnUpdateOrder({
    required final model.NcViewColumn column,
    required final int order,
  }) async =>
      await dbViewColumnUpdate(column: column, data: {'order': order});

  Future<Result<EmptyResult>> dbViewColumnUpdateShow({
    required final model.NcViewColumn column,
    required final bool show,
  }) async =>
      await dbViewColumnUpdate(column: column, data: {'show': show});

  Future<Result<EmptyResult>> dbViewColumnUpdate({
    required final model.NcViewColumn column,
    required final Map<String, dynamic> data,
  }) async =>
      await _send(
        method: HttpMethod.patch,
        pathSegments: [
          '/api/v1/db/meta/views',
          column.fkViewId,
          'columns',
          column.id,
        ],
        body: json.encode(data),
        serializer: (final res, final data) => emptyResult,
      );

  // Future<model.Result<List<model.NcViewColumn>>> dbViewGridColumnsList({
  //   required final String viewId,
  // }) async => await _send2(
  //     method: HttpMethod.get,
  //     pathSegments: [
  //       '/api/v1/db/meta/grids',
  //       viewId,
  //       'grid-columns',
  //     ],
  //     serializer: (res, data) => Result.ok(List<model.NcViewColumn>.from(
  //         data.map(
  //               (final c) => model.NcViewColumn.fromJson(c),
  //         ),
  //       ))
  //   );

  Future<model.Result<model.NcRowList>> dbViewRowList({
    final org = _defaultOrg,
    required final NcView view,
    final offset = 0,
    final limit = 25,
    final SearchQuery? where,
  }) async {
    final queryParameters = {
      'offset': offset.toString(),
      'limit': limit.toString(),
    };

    if (where != null) {
      queryParameters['where'] = where.toString();
    }

    return await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/data',
        org,
        view.baseId,
        view.fkModelId,
        'views',
        view.id,
      ],
      queryParameters: queryParameters,
      serializer: (final res, final data) =>
          NcRowList.fromJson(data, model.fromJsonT<NcRow>),
    );
  }

  Future<model.Result<NcRow>> dbViewRowCreate({
    final org = _defaultOrg,
    required final NcView view,
    required final Map<String, dynamic> data,
  }) async =>
      await _send(
        method: HttpMethod.post,
        pathSegments: [
          '/api/v1/db/data',
          org,
          view.baseId,
          view.fkModelId,
          'views',
          view.id,
        ],
        body: json.encode(data),
        serializer: (final res, final data) => data,
      );

  Future<model.Result<model.NcRowList>> dbTableRowNestedList({
    final org = _defaultOrg,
    required final NcTableColumn column,
    required final String rowId,
    final offset = 0,
    final limit = 10,
    final Where? where,
  }) async {
    final queryParameters = _buildQueryParameters(
      offset: offset,
      limit: limit,
      where: where,
    );
    return await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/data',
        org,
        column.baseId,
        column.fkModelId,
        rowId,
        column.relationType.toString(),
        column.title,
      ],
      queryParameters: queryParameters,
      serializer: (final res, final data) =>
          NcRowList.fromJson(data, model.fromJsonT<NcRow>),
    );
  }

  Map<String, dynamic> _buildQueryParameters({
    final offset = 0,
    final limit = 10,
    final Where? where,
  }) {
    final queryParameters = {
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (where != null) {
      queryParameters['where'] = where.toString_();
    }
    return queryParameters;
  }

  Future<Result<NcRowList>> dbTableRowNestedChildrenExcludedList({
    final org = _defaultOrg,
    required final NcTableColumn column,
    required final String rowId,
    final offset = 0,
    final limit = 10,
    final Where? where,
  }) async {
    final queryParameters = _buildQueryParameters(
      offset: offset,
      limit: limit,
      where: where,
    );
    return await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/data',
        org,
        column.baseId,
        column.fkModelId,
        rowId,
        column.relationType.toString(),
        column.title,
        'exclude',
      ],
      queryParameters: queryParameters,
      serializer: (final res, final data) =>
          NcRowList.fromJson(data, model.fromJsonT<NcRow>),
    );
  }

  Future<Result<EmptyResult>> dbViewRowDelete({
    final org = _defaultOrg,
    required final NcView view,
    required final String rowId,
  }) async =>
      await _send(
        method: HttpMethod.delete,
        pathSegments: [
          '/api/v1/db/data',
          org,
          view.baseId,
          view.fkModelId,
          'views',
          view.id,
          rowId,
        ],
        serializer: (final res, final data) => emptyResult,
      );

  Future<Result<NcRow>> dbViewRowUpdate({
    final org = _defaultOrg,
    required final NcView view,
    required final String rowId,
    required final Map<String, dynamic> data,
  }) async =>
      await _send(
        method: HttpMethod.patch,
        pathSegments: [
          '/api/v1/db/data',
          org,
          view.baseId,
          view.fkModelId,
          'views',
          view.id,
          rowId,
        ],
        body: json.encode(data),
        expectedStatusCode: [200],
        serializer: (final res, final data) => data,
      );

  // listFilters({required String viewId}) async {
  //   final u = uri('/api/v1/db/meta/views/$viewId/filters');
  //   final res = await c.get(u, headers: headers);
  //   pj(res.body);
  // }

  Future<model.Result<model.NcList<model.NcSort>>> dbTableSortList({
    required final String viewId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
          'sorts',
        ],
        serializer: (final res, final data) =>
            NcSortList.fromJson(data, model.fromJsonT<model.NcSort>),
      );

  // TODO: Use send2
  Future<model.Result<EmptyResult>> dbTableSortCreate({
    required final String viewId,
    required final String fkColumnId,
    required final SortDirectionTypes direction,
  }) async =>
      await _send(
        method: HttpMethod.post,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
          'sorts',
        ],
        body: json.encode({
          'fk_column_id': fkColumnId,
          'direction': direction.value,
        }),
        serializer: (final data, final res) => emptyResult,
      );

  Future<Result<EmptyResult>> dbTableSortDelete({
    required final String sortId,
  }) async =>
      await _send(
        method: HttpMethod.delete,
        pathSegments: [
          '/api/v1/db/meta/sorts',
          sortId,
        ],
        serializer: (final res, final data) => emptyResult,
      );

  Future<Result<EmptyResult>> dbTableSortUpdate({
    required final String sortId,
    required final String fkColumnId,
    required final SortDirectionTypes direction,
  }) async =>
      _send(
        method: HttpMethod.patch,
        pathSegments: [
          '/api/v1/db/meta/sorts',
          sortId,
        ],
        body: json.encode({
          'fk_column_id': fkColumnId,
          'direction': direction.value,
        }),
        serializer: (final res, final data) => emptyResult,
      );

  Future<Result<EmptyResult>> dbTableColumnCreate({
    required final String tableId,
    required final String title,
    required final UITypes uidt,
  }) async =>
      await _send(
        method: HttpMethod.post,
        pathSegments: [
          '/api/v1/db/meta/tables',
          tableId,
          'columns',
        ],
        body: json.encode({
          'title': title,
          'column_name': title,
          'uidt': uidt.value.toString(),
        }),
        serializer: (final res, final data) => emptyResult,
      );

  // TODO: Fix. "msg" might cause a crash.
  Future<model.Result<String>> dbTableRowNestedAdd({
    required final NcTableColumn column,
    required final String rowId,
    required final String refRowId,
  }) async =>
      await _send(
        method: HttpMethod.post,
        pathSegments: [
          'api/v1/db/data',
          _defaultOrg,
          column.baseId,
          column.fkModelId,
          rowId,
          column.relationType.toString(),
          column.title,
          refRowId,
        ],
        expectedStatusCode: [200],
        serializer: (final res, final data) => data['msg'].toString(),
      );

  // TODO: Fix. "msg" might cause a crash.
  Future<model.Result<String>> dbTableRowNestedRemove({
    final org = _defaultOrg,
    required final NcTableColumn column,
    required final String rowId,
    required final String refRowId,
  }) async =>
      await _send(
        method: HttpMethod.delete,
        pathSegments: [
          '/api/v1/db/data',
          org,
          column.baseId,
          column.fkModelId,
          rowId,
          column.relationType.toString(),
          column.title,
          refRowId,
        ],
        expectedStatusCode: [200],
        serializer: (final res, final data) => data['msg'].toString(),
      );

  Future<http.MultipartFile> _createMultipartFile(
    final NcFile file,
    final String field,
  ) async {
    switch (file) {
      case NcPlatformFile(platformFile: final platformFile):
        final mimeType = lookupMimeType(platformFile.path!);
        return http.MultipartFile.fromBytes(
          field,
          (platformFile.bytes) as List<int>,
          filename: platformFile.name,
          contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
        );
      case NcXFile(xFile: final xFile):
        final mimeType = lookupMimeType(xFile.path);
        final bytes = await xFile.readAsBytes();
        return http.MultipartFile.fromBytes(
          field,
          bytes as List<int>,
          filename: xFile.name,
          contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
        );
    }
  }

  bool _checkFileValid(final NcFile file) {
    if (file is NcPlatformFile) {
      final NcPlatformFile(:platformFile) = file;
      if (platformFile.bytes == null || platformFile.path == null) {
        return false;
      }
    }
    return true;
  }

  Future<List<model.NcAttachedFile>> dbStorageUpload(
    final List<NcFile> files,
  ) async {
    const path = '/api/v1/db/storage/upload';
    final uri = _baseUri.replace(path: path);

    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll({
      ..._client._headers,
      'Content-type': 'multipart/form-data',
    });

    files.asMap().forEach((final index, final file) async {
      if (!_checkFileValid(file)) {
        return;
      }
      req.files.add(await _createMultipartFile(file, 'field_$index'));
    });
    final res = await http.Response.fromStream(await req.send());

    _logResponse(res);

    final data = _decode(res, expectedStatusCode: [200]);
    return data
        .map<NcAttachedFile>(
          (final e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }
}

final api = _Api();
