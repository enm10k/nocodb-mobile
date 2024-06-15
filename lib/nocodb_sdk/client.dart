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

class _Api {
  late final _HttpClient _client = _HttpClient(http.Client());
  late Uri _baseUri;
  Uri get uri => _baseUri;

  init(final String url, {final String? authToken}) {
    _baseUri = Uri.parse(url);
    logger.info(_baseUri);
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

  Future<http.Response> _send({
    required final HttpMethod method,
    final Uri? baseUri,
    final String? path,
    final Iterable<String> pathSegments = const [],
    final String? data,
    final Map<String, dynamic>? queryParameters,
    final String? baseUrl,
    final http.Client? httpClient,
    final Map<String, String>? headers,
  }) async {
    final client = httpClient ?? _client;
    final uri = _uri(
      baseUri: baseUri,
      path: path,
      pathSegments: pathSegments,
      queryParameters: queryParameters,
      baseUrl: baseUrl,
    );
    final censored = data?.contains('password') == true ? '{***}' : data;

    logger.finer(
      '=> ${method.name.toUpperCase()} ${uri.path} ${uri.queryParametersAll.isNotEmpty ? uri.queryParametersAll : '-'} ${censored ?? '-'}',
    );
    switch (method) {
      case HttpMethod.get:
        return await client.get(uri, headers: headers);
      case HttpMethod.post:
        return await client.post(
          uri,
          body: data,
          headers: headers,
        );
      case HttpMethod.patch:
        return await client.patch(
          uri,
          body: data,
          headers: headers,
        );
      case HttpMethod.delete:
        return await client.delete(
          uri,
          body: data,
          headers: headers,
        );
    }
  }

  Future<bool> version(final String endpoint, {final String? authToken}) async {
    final headers = authToken != null ? {'xc-auth': authToken} : null;
    final res = await _send(
      baseUri: Uri.parse(endpoint),
      method: HttpMethod.get,
      path: '/api/v1/version',
      httpClient: http.Client(), // This function should use plain HTTP client.
      headers: headers,
    );
    return res.statusCode == 200;
  }

  Future<String> authSignin(final String email, final String password) async {
    final res = await _send(
      method: HttpMethod.post,
      path: '/api/v1/auth/user/signin',
      data: json.encode({
        'email': email,
        'password': password,
      }),
      httpClient: http.Client(), // This function should use plain HTTP client.
      headers: {'Content-type': 'application/json'},
    );
    final data = _decode(res, expectedStatusCode: [200]);
    final {'token': token} = data;
    _client.addHeaders({'xc-auth': token});
    return token;
  }

  Future<model.NcUser> me([final Map<String, dynamic>? queryParameters]) async {
    final res = await _send(
      method: HttpMethod.get,
      path: '/api/v1/auth/user/me',
    );

    final data = _decode(res);
    final user = model.NcUser.fromJson(data);
    logger.info(user);
    return user;
  }

  Future<model.NcProjectList> projectList() async {
    final res = await _send(
      method: HttpMethod.get,
      path: '/api/v1/db/meta/projects',
    );
    final data = _decode(res);
    return model.NcProjectList.fromJson(data, model.fromJsonT<model.NcProject>);
  }

  Future<model.NcSimpleTableList> dbTableList({
    required final String projectId,
  }) async {
    final res = await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/meta/projects',
        projectId,
        'tables',
      ],
    );
    final data = _decode(res);
    return model.NcSimpleTableList.fromJson(data);
  }

  Future<model.NcTable> dbTableRead({required final String tableId}) async {
    final res = await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/meta/tables',
        tableId,
      ],
    );
    final data = _decode(res);
    return model.NcTable.fromJson(data);
  }

  Future<model.ViewList> dbViewList({required final String tableId}) async {
    final res = await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/meta/tables',
        tableId,
        'views',
      ],
    );
    final data = _decode(res);
    return model.ViewList.fromJson(data);
  }

  Future<model.NcView> dbViewUpdate({
    required final String viewId,
    required final Map<String, dynamic> data,
  }) async {
    final res = await _send(
      method: HttpMethod.patch,
      pathSegments: [
        '/api/v1/db/meta/views',
        viewId,
      ],
      data: json.encode(data),
    );
    final resData = _decode(res);
    return model.NcView.fromJson(resData);
  }

  Future<List<model.NcViewColumn>> dbViewColumnList({
    required final String viewId,
  }) async {
    final res = await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/meta/views',
        viewId,
        'columns',
      ],
    );
    final data = _decode(res);
    final {'list': list} = data;
    return List<model.NcViewColumn>.from(
      list.map((final c) => model.NcViewColumn.fromJson(c)),
    );
  }

  Future<void> dbViewColumnUpdateOrder({
    required final model.NcViewColumn column,
    required final int order,
  }) async {
    await dbViewColumnUpdate(column: column, data: {'order': order});
  }

  Future<void> dbViewColumnUpdateShow({
    required final model.NcViewColumn column,
    required final bool show,
  }) async {
    await dbViewColumnUpdate(column: column, data: {'show': show});
  }

  Future<void> dbViewColumnUpdate({
    required final model.NcViewColumn column,
    required final Map<String, dynamic> data,
  }) async {
    final res = await _send(
      method: HttpMethod.patch,
      pathSegments: [
        '/api/v1/db/meta/views',
        column.fkViewId,
        'columns',
        column.id,
      ],
      data: json.encode(data),
    );
    _decode(res);
  }

  Future<List<model.NcViewColumn>> dbViewGridColumnsList({
    required final String viewId,
  }) async {
    final res = await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/meta/grids',
        viewId,
        'grid-columns',
      ],
    );

    final data = _decode(res);
    return List<model.NcViewColumn>.from(
      data.map(
        (final c) => model.NcViewColumn.fromJson(c),
      ),
    );
  }

  Future<model.NcRowList> dbViewRowList({
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

    final res = await _send(
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
    );
    final data = _decode(res);
    return NcRowList.fromJson(data, model.fromJsonT<NcRow>);
  }

  Future<Map<String, dynamic>> dbViewRowCreate({
    final org = _defaultOrg,
    required final NcView view,
    required final Map<String, dynamic> data,
  }) async {
    final res = await _send(
      method: HttpMethod.post,
      pathSegments: [
        '/api/v1/db/data',
        org,
        view.baseId,
        view.fkModelId,
        'views',
        view.id,
      ],
      data: json.encode(data),
    );
    return _decode(res, expectedStatusCode: [200]);
  }

  Future<model.NcRowList> dbTableRowNestedList({
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
    final res = await _send(
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
    );
    final data = _decode(res);
    return NcRowList.fromJson(data, model.fromJsonT<NcRow>);
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

  Future<model.NcRowList> dbTableRowNestedChildrenExcludedList({
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
    final res = await _send(
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
    );
    final data = _decode(res);
    return NcRowList.fromJson(data, model.fromJsonT<NcRow>);
  }

  dbViewRowDelete({
    final org = _defaultOrg,
    required final NcView view,
    required final String rowId,
  }) async {
    final res = await _send(
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
    );
    _decode(res);
  }

  Future<Map<String, dynamic>> dbViewRowUpdate({
    final org = _defaultOrg,
    required final NcView view,
    required final String rowId,
    required final Map<String, dynamic> data,
  }) async {
    final res = await _send(
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
      data: json.encode(data),
    );
    return _decode(res, expectedStatusCode: [200]);
  }

  // listFilters({required String viewId}) async {
  //   final u = uri('/api/v1/db/meta/views/$viewId/filters');
  //   final res = await c.get(u, headers: headers);
  //   pj(res.body);
  // }

  Future<model.NcSortList> dbTableSortList({
    required final String viewId,
  }) async {
    final res = await _send(
      method: HttpMethod.get,
      pathSegments: [
        '/api/v1/db/meta/views',
        viewId,
        'sorts',
      ],
    );
    final data = _decode(res);
    return NcSortList.fromJson(data, model.fromJsonT<model.NcSort>);
  }

  Future<void> dbTableSortCreate({
    required final String viewId,
    required final String fkColumnId,
    required final SortDirectionTypes direction,
  }) async {
    final res = await _send(
      method: HttpMethod.post,
      pathSegments: [
        '/api/v1/db/meta/views',
        viewId,
        'sorts',
      ],
      data: json.encode({
        'fk_column_id': fkColumnId,
        'direction': direction.value,
      }),
    );
    _decode(res);
  }

  Future<void> dbTableSortDelete({
    required final String sortId,
  }) async {
    final res = await _send(
      method: HttpMethod.delete,
      pathSegments: [
        '/api/v1/db/meta/sorts',
        sortId,
      ],
    );
    _decode(res);
  }

  Future<void> dbTableSortUpdate({
    required final String sortId,
    required final String fkColumnId,
    required final SortDirectionTypes direction,
  }) async {
    final res = await _send(
      method: HttpMethod.patch,
      pathSegments: [
        '/api/v1/db/meta/sorts',
        sortId,
      ],
      data: json.encode({
        'fk_column_id': fkColumnId,
        'direction': direction.value,
      }),
    );
    _decode(res);
  }

  Future<void> dbTableColumnCreate({
    required final String tableId,
    required final String title,
    required final UITypes uidt,
  }) async {
    final res = await _send(
      method: HttpMethod.post,
      pathSegments: [
        '/api/v1/db/meta/tables',
        tableId,
        'columns',
      ],
      data: json.encode({
        'title': title,
        'column_name': title,
        'uidt': uidt.value.toString(),
      }),
    );
    logger.info(res);
    final data = _decode(res);
    logger.info(data);
  }

  Future<String> dbTableRowNestedAdd({
    required final NcTableColumn column,
    required final String rowId,
    required final String refRowId,
  }) async {
    final res = await _send(
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
    );
    final data = _decode(res, expectedStatusCode: [200]);
    return data['msg'].toString();
  }

  Future<String> dbTableRowNestedRemove({
    final org = _defaultOrg,
    required final NcTableColumn column,
    required final String rowId,
    required final String refRowId,
  }) async {
    final res = await _send(
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
    );
    final data = _decode(res, expectedStatusCode: [200]);
    return data['msg'].toString();
  }

  Future<http.MultipartFile> _createMultipartFile(
      final NcFile file, final String field,) async {
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
