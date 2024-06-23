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

String pp(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

class _HttpClient extends http.BaseClient {
  _HttpClient(this._baseHttpClient);
  final http.Client _baseHttpClient;
  final Map<String, String> _headers = {};

  addHeaders(Map<String, String> headers) {
    _headers.addAll(headers);
  }

  removeHeader(String key) {
    _headers.remove(key);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
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
  model.HttpFn toFn(http.Client client) => switch (this) {
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

  init(String url, {String? authToken}) {
    _baseUri = Uri.parse(url);
    if (authToken != null) {
      _client.addHeaders({'xc-auth': authToken});
    } else {
      _client.removeHeader('xc-auth');
    }
  }

  bool get isReady => _client._headers.containsKey('xc-auth');

  void throwExceptionIfKeyExists({
    required String key,
    required Map data,
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

  _logResponse(http.Response res) {
    logger.finer(
      '<= ${res.request?.method} ${res.request?.url.path} ${res.statusCode} ${res.body}',
    );
  }

  dynamic _decode(
    http.Response res, {
    List<int> expectedStatusCode = const [],
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
    Uri? baseUri,
    String? path,
    Iterable<String> pathSegments = const [],
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
  }) {
    assert(path != null || pathSegments.isNotEmpty);
    final uri = baseUri ?? _baseUri;
    return path != null
        ? uri.replace(path: path, queryParameters: queryParameters)
        : uri.replace(
            pathSegments:
                pathSegments.map((v) => v.split('/')).expand((v) => v),
            queryParameters: queryParameters,
          );
  }

  Future<Result<T>> _send<T>({
    required HttpMethod method,
    Uri? baseUri,
    String? path,
    Iterable<String> pathSegments = const [],
    String? body,
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    http.Client? httpClient,
    Map<String, String>? headers,
    List<int> expectedStatusCode = const [],
    required T Function(http.Response res, dynamic data) serializer,
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
            get: (fn) async => await fn.call(uri, headers: headers),
            others: (fn) async => await fn.call(
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
    String endpoint, {
    String? authToken,
  }) async {
    final headers = authToken != null ? {'xc-auth': authToken} : null;
    return await _send(
      baseUri: Uri.parse(endpoint),
      method: HttpMethod.get,
      path: '/api/v1/version',
      httpClient: http.Client(), // This function should use plain HTTP client.
      headers: headers,
      serializer: (res, _) => res.statusCode == 200,
    );
  }

  Future<model.Result<String>> authSignin(
    String email,
    String password,
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
        serializer: (_, data) {
          final {'token': token} = data;
          if (token == null) {
            throw Exception('authSignin failed.');
          }

          _client.addHeaders({'xc-auth': token});
          return token;
        },
      );

  Future<Result<model.NcUser>> authUserMe([
    Map<String, dynamic>? queryParameters,
  ]) async =>
      await _send(
        method: HttpMethod.get,
        path: '/api/v1/auth/user/me',
        serializer: (_, data) => model.NcUser.fromJson(data),
      );

  Future<model.Result<model.NcList<model.NcProject>>> projectList() async =>
      await _send(
        method: HttpMethod.get,
        path: '/api/v1/db/meta/projects',
        serializer: (_, data) => model.NcProjectList.fromJson(
          data,
          model.fromJsonT<model.NcProject>,
        ),
      );

  Future<model.Result<model.NcSimpleTableList>> dbTableList({
    required String projectId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/projects',
          projectId,
          'tables',
        ],
        serializer: (res, data) => model.NcSimpleTableList.fromJson(data),
      );

  Future<model.Result<model.NcTable>> dbTableRead({
    required String tableId,
  }) async =>
      _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/tables',
          tableId,
        ],
        serializer: (res, data) => model.NcTable.fromJson(data),
      );

  Future<model.Result<model.ViewList>> dbViewList({
    required String tableId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/tables',
          tableId,
          'views',
        ],
        serializer: (res, data) => model.ViewList.fromJson(data),
      );

  Future<model.Result<model.NcView>> dbViewUpdate({
    required String viewId,
    required Map<String, dynamic> data,
  }) async =>
      await _send(
        method: HttpMethod.patch,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
        ],
        body: json.encode(data),
        serializer: (_, data) => model.NcView.fromJson(data),
      );

  Future<Result<List<model.NcViewColumn>>> dbViewColumnList({
    required String viewId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
          'columns',
        ],
        serializer: (_, data) {
          final {'list': list as List} = data;
          return List<model.NcViewColumn>.from(
            list.map((c) => model.NcViewColumn.fromJson(c)),
          );
        },
      );

  Future<Result<EmptyResult>> dbViewColumnUpdateOrder({
    required model.NcViewColumn column,
    required int order,
  }) async =>
      await dbViewColumnUpdate(column: column, data: {'order': order});

  Future<Result<EmptyResult>> dbViewColumnUpdateShow({
    required model.NcViewColumn column,
    required bool show,
  }) async =>
      await dbViewColumnUpdate(column: column, data: {'show': show});

  Future<Result<EmptyResult>> dbViewColumnUpdate({
    required model.NcViewColumn column,
    required Map<String, dynamic> data,
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
        serializer: (res, data) => emptyResult,
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
    org = _defaultOrg,
    required NcView view,
    offset = 0,
    limit = 25,
    SearchQuery? where,
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
      serializer: (res, data) =>
          NcRowList.fromJson(data, model.fromJsonT<NcRow>),
    );
  }

  Future<model.Result<NcRow>> dbViewRowCreate({
    org = _defaultOrg,
    required NcView view,
    required Map<String, dynamic> data,
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
        serializer: (res, data) => data,
      );

  Future<model.Result<model.NcRowList>> dbTableRowNestedList({
    org = _defaultOrg,
    required NcTableColumn column,
    required String rowId,
    offset = 0,
    limit = 10,
    Where? where,
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
      serializer: (res, data) =>
          NcRowList.fromJson(data, model.fromJsonT<NcRow>),
    );
  }

  Map<String, dynamic> _buildQueryParameters({
    offset = 0,
    limit = 10,
    Where? where,
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
    org = _defaultOrg,
    required NcTableColumn column,
    required String rowId,
    offset = 0,
    limit = 10,
    Where? where,
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
      serializer: (res, data) =>
          NcRowList.fromJson(data, model.fromJsonT<NcRow>),
    );
  }

  Future<Result<EmptyResult>> dbViewRowDelete({
    org = _defaultOrg,
    required NcView view,
    required String rowId,
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
        serializer: (res, data) => emptyResult,
      );

  Future<Result<NcRow>> dbViewRowUpdate({
    org = _defaultOrg,
    required NcView view,
    required String rowId,
    required Map<String, dynamic> data,
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
        serializer: (res, data) => data,
      );

  // listFilters({required String viewId}) async {
  //   final u = uri('/api/v1/db/meta/views/$viewId/filters');
  //   final res = await c.get(u, headers: headers);
  //   pj(res.body);
  // }

  Future<model.Result<model.NcList<model.NcSort>>> dbTableSortList({
    required String viewId,
  }) async =>
      await _send(
        method: HttpMethod.get,
        pathSegments: [
          '/api/v1/db/meta/views',
          viewId,
          'sorts',
        ],
        serializer: (res, data) =>
            NcSortList.fromJson(data, model.fromJsonT<model.NcSort>),
      );

  // TODO: Use send2
  Future<model.Result<EmptyResult>> dbTableSortCreate({
    required String viewId,
    required String fkColumnId,
    required SortDirectionTypes direction,
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
        serializer: (data, res) => emptyResult,
      );

  Future<Result<EmptyResult>> dbTableSortDelete({
    required String sortId,
  }) async =>
      await _send(
        method: HttpMethod.delete,
        pathSegments: [
          '/api/v1/db/meta/sorts',
          sortId,
        ],
        serializer: (res, data) => emptyResult,
      );

  Future<Result<EmptyResult>> dbTableSortUpdate({
    required String sortId,
    required String fkColumnId,
    required SortDirectionTypes direction,
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
        serializer: (res, data) => emptyResult,
      );

  Future<Result<EmptyResult>> dbTableColumnCreate({
    required String tableId,
    required String title,
    required UITypes uidt,
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
        serializer: (res, data) => emptyResult,
      );

  // TODO: Fix. "msg" might cause a crash.
  Future<model.Result<String>> dbTableRowNestedAdd({
    required NcTableColumn column,
    required String rowId,
    required String refRowId,
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
        serializer: (res, data) => data['msg'].toString(),
      );

  // TODO: Fix. "msg" might cause a crash.
  Future<model.Result<String>> dbTableRowNestedRemove({
    org = _defaultOrg,
    required NcTableColumn column,
    required String rowId,
    required String refRowId,
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
        serializer: (res, data) => data['msg'].toString(),
      );

  Future<http.MultipartFile> _createMultipartFile(
    NcFile file,
    String field,
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

  bool _checkFileValid(NcFile file) {
    if (file is NcPlatformFile) {
      final NcPlatformFile(:platformFile) = file;
      if (platformFile.bytes == null || platformFile.path == null) {
        return false;
      }
    }
    return true;
  }

  Future<List<model.NcAttachedFile>> dbStorageUpload(
    List<NcFile> files,
  ) async {
    const path = '/api/v1/db/storage/upload';
    final uri = _baseUri.replace(path: path);

    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll({
      ..._client._headers,
      'Content-type': 'multipart/form-data',
    });

    files.asMap().forEach((index, file) async {
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
          (e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }
}

final api = _Api();
