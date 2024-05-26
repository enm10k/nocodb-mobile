import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '/features/core/providers/providers.dart';
import '../common/logger.dart';
import 'models.dart' as model;
import 'models.dart';
import 'symbols.dart';

const _defaultOrg = 'noco';

sealed class NcFile {}

class NcPlatformFile extends NcFile {
  final PlatformFile platformFile;
  NcPlatformFile(this.platformFile);
}

class NcXFile extends NcFile {
  final XFile xFile;
  NcXFile(this.xFile);
}

String pp(Map<String, dynamic> json) {
  return const JsonEncoder.withIndent('  ').convert(json);
}

class _HttpClient extends http.BaseClient {
  final http.Client _baseHttpClient;
  final Map<String, String> _headers = {};

  _HttpClient(this._baseHttpClient);

  addHeaders(Map<String, String> headers) {
    _headers.addAll(headers);
  }

  removeHeader(String key) {
    _headers.remove(key);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    var headers = _headers;
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

  init(String url, {String? authToken}) {
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

  dynamic _decode(http.Response res) {
    return _decodeWithAssert(res);
  }

  _logResponse(http.Response res) {
    logger.finer(
      '<= ${res.request?.method} ${res.request?.url.path} ${res.statusCode} ${res.body}',
    );
  }

  dynamic _decodeWithAssert(
    http.Response res, {
    List<int>? expectedStatusCode,
  }) {
    _logResponse(res);

    final isJson =
        res.headers['content-type']?.contains('application/json') ?? false;
    if (isJson && res.body.isNotEmpty) {
      final data = json.decode(res.body);
      if (expectedStatusCode != null &&
          !expectedStatusCode.contains(res.statusCode)) {
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

  Future<http.Response> _send({
    required HttpMethod method,
    Uri? baseUri,
    String? path,
    Iterable<String> pathSegments = const [],
    String? data,
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    http.Client? httpClient,
    Map<String, String>? headers,
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

  Future<bool> version(String endpoint, {String? authToken}) async {
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

  Future<String> authSignin(String email, String password) async {
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
    final data = _decodeWithAssert(res, expectedStatusCode: [200]);
    final token = data['token'];
    _client.addHeaders({'xc-auth': token});
    return token;
  }

  Future<model.NcUser> me([Map<String, dynamic>? queryParameters]) async {
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
    return model.NcProjectList.fromJson(data);
  }

  Future<model.NcSimpleTableList> dbTableList({
    required String projectId,
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

  Future<model.NcTable> dbTableRead({required String tableId}) async {
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

  Future<model.ViewList> dbViewList({required String tableId}) async {
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
    required String viewId,
    required Map<String, dynamic> data,
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
    required String viewId,
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
      list.map((c) => model.NcViewColumn.fromJson(c)),
    );
  }

  Future<void> dbViewColumnUpdateOrder({
    required model.NcViewColumn column,
    required int order,
  }) async {
    dbViewColumnUpdate(column: column, data: {'order': order});
  }

  Future<void> dbViewColumnUpdateShow({
    required model.NcViewColumn column,
    required bool show,
  }) async {
    dbViewColumnUpdate(column: column, data: {'show': show});
  }

  Future<void> dbViewColumnUpdate({
    required model.NcViewColumn column,
    required Map<String, dynamic> data,
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
    required String viewId,
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
        (c) => model.NcViewColumn.fromJson(c),
      ),
    );
  }

  Future<model.NcRowList> dbViewRowList({
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
    return NcRowList.fromJson(data);
  }

  Future<Map<String, dynamic>> dbViewRowCreate({
    org = _defaultOrg,
    required NcView view,
    required Map<String, dynamic> data,
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
    return _decodeWithAssert(res, expectedStatusCode: [200]);
  }

  Future<model.NcRowList> dbTableRowNestedList({
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
    return NcRowList.fromJson(data);
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

  Future<model.NcRowList> dbTableRowNestedChildrenExcludedList({
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
    return NcRowList.fromJson(data);
  }

  dbViewRowDelete({
    org = _defaultOrg,
    required NcView view,
    required String rowId,
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
    org = _defaultOrg,
    required NcView view,
    required String rowId,
    required Map<String, dynamic> data,
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
    return _decodeWithAssert(res, expectedStatusCode: [200]);
  }

  // listFilters({required String viewId}) async {
  //   final u = uri('/api/v1/db/meta/views/$viewId/filters');
  //   final res = await c.get(u, headers: headers);
  //   pj(res.body);
  // }

  Future<model.NcSortList> dbTableSortList({
    required String viewId,
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

    // No longer needed due to NocoDB update
    // testing patterns feature
    // final {'sorts': list} = data;

    return NcSortList.fromJson(data);
  }

  Future<void> dbTableSortCreate({
    required String viewId,
    required String fkColumnId,
    required SortDirectionTypes direction,
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
    required String sortId,
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
    required String sortId,
    required String fkColumnId,
    required SortDirectionTypes direction,
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
    required String tableId,
    required String title,
    required UITypes uidt,
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
    required NcTableColumn column,
    required String rowId,
    required String refRowId,
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
    final data = _decodeWithAssert(res, expectedStatusCode: [200]);
    return data['msg'].toString();
  }

  Future<String> dbTableRowNestedRemove({
    org = _defaultOrg,
    required NcTableColumn column,
    required String rowId,
    required String refRowId,
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
    final data = _decodeWithAssert(res, expectedStatusCode: [200]);
    return data['msg'].toString();
  }

  Future<void> _addFilesToMultipartRequest(
    http.MultipartRequest req,
    List<NcFile> files,
  ) async {
    for (final (index, file) in files.indexed) {
      switch (file) {
        case NcPlatformFile(platformFile: final platformFile):
          if (platformFile.bytes == null || platformFile.path == null) {
            continue;
          }
          final mimeType = lookupMimeType(platformFile.path!);
          final multipartFile = http.MultipartFile.fromBytes(
            'file_$index',
            (platformFile.bytes) as List<int>,
            filename: platformFile.name,
            contentType:
                MediaType.parse(mimeType ?? 'application/octet-stream'),
          );
          req.files.add(multipartFile);
        case NcXFile(xFile: final xFile):
          final mimeType = lookupMimeType(xFile.path);
          final bytes = await xFile.readAsBytes();
          final multipartFile = http.MultipartFile.fromBytes(
            'file_$index',
            bytes as List<int>,
            filename: xFile.name,
            contentType:
                MediaType.parse(mimeType ?? 'application/octet-stream'),
          );
          req.files.add(multipartFile);
      }
    }
  }

  Future<List<model.NcAttachedFile>> dbStorageUpload(
    List<NcFile> files,
  ) async {
    const path = '/api/v1/db/storage/upload';
    final uri = _baseUri.replace(path: path);

    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll({
      'Content-type': 'multipart/form-data',
      'xc-auth': _client._headers['xc-auth']!,
    });

    _addFilesToMultipartRequest(req, files);

    final res = await http.Response.fromStream(await req.send());
    _logResponse(res);

    final data = json.decode(res.body);
    return data
        .map<NcAttachedFile>(
          (e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }
}

final api = _Api();
