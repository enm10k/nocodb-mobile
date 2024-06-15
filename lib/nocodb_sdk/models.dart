import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

part 'models.freezed.dart';
part 'models.g.dart';
part 'models_extensions.dart';

/*
@freezed
abstract class Result<T> with _$Result<T> {
  const factory Result.success() = Success;
  const factory Result.successWithValue(final T value) = SuccessWithValue<T>;

  const factory Result.error(final Error error) = ResultError<T>;

  const factory Result.exception(final Exception exception) =
      ResultException<T>;
}
 */

@freezed
abstract class Result<T> with _$Result<T> {
  const factory Result.ok(final T value) = Ok<T>;

  const factory Result.ng(final Object error, final StackTrace? stackTrace) =
      Ng<T>;
}

@Freezed(genericArgumentFactories: true)
class NcList<T> with _$NcList<T> {
  const factory NcList({
    required final List<T> list,
    required final NcPageInfo? pageInfo,
  }) = _NcList<T>;

  factory NcList.fromJson(
    final Map<String, dynamic> json,
    final T Function(Object?) fromJsonT,
  ) =>
      _$NcListFromJson(json, fromJsonT);
}

@freezed
class NcTables with _$NcTables {
  @JsonSerializable()
  const factory NcTables({
    required final NcTable table,
    @Default({}) final Map<String, NcTable> relationMap,
  }) = _NcTables;
  factory NcTables.fromJson(final Map<String, dynamic> json) =>
      _$NcTablesFromJson(json);
}

@freezed
class NcUser with _$NcUser {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcUser({
    required final String id,
    required final String email,
    required final Map<String, bool?> roles,
    final bool? emailVerifier,
    final String? firstname,
    final String? lastname,
  }) = _NcUser;
  factory NcUser.fromJson(final Map<String, dynamic> json) =>
      _$NcUserFromJson(json);
}

@freezed
class NcProject with _$NcProject {
  const factory NcProject({
    required final String id,
    required final String title,
  }) = _NcProject;
  factory NcProject.fromJson(final Map<String, dynamic> json) =>
      _$NcProjectFromJson(json);
}

@freezed
class NcPageInfo with _$NcPageInfo {
  const factory NcPageInfo({
    required final int totalRows,
    required final int page,
    required final int pageSize,
    required final bool isFirstPage,
    required final bool isLastPage,
  }) = _NcPageInfo;

  factory NcPageInfo.fromJson(final Map<String, dynamic> json) =>
      _$NcPageInfoFromJson(json);
}

@freezed
class NcSort with _$NcSort {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcSort({
    required final String id,
    required final String fkViewId,
    required final String fkColumnId,
    @JsonKey(fromJson: _toSortTypes)
    required final SortDirectionTypes direction,
    required final int order,
  }) = _NcSort;
  factory NcSort.fromJson(final Map<String, dynamic> json) =>
      _$NcSortFromJson(json);
}

typedef NcRow = Map<String, dynamic>;
T fromJsonT<T>(final Object? obj) {
  final json = obj as Map<String, dynamic>;

  if (T == NcRow) {
    return json as T;
  } else if (T == NcProject) {
    return NcProject.fromJson(json) as T;
  } else if (T == NcSort) {
    return NcSort.fromJson(json) as T;
  } else {
    throw Exception('Unsupported type');
  }
}

typedef NcProjectList = NcList<NcProject>;
typedef NcSortList = NcList<NcSort>;
typedef NcRowList = NcList<Map<String, dynamic>>;

@freezed
class NcSlimTable with _$NcSlimTable {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcSlimTable({
    required final String id,
    required final String baseId,
    required final String tableName,
    required final String title,
    required final String type,
  }) = _NcSlimTable;
  factory NcSlimTable.fromJson(final Map<String, dynamic> json) =>
      _$NcSlimTableFromJson(json);
}

@freezed
class NcSimpleTableList with _$NcSimpleTableList {
  const factory NcSimpleTableList({required final List<NcSlimTable> list}) =
      _NcSimpleTableList;
  factory NcSimpleTableList.fromJson(final Map<String, dynamic> json) =>
      _$NcSimpleTableListFromJson(json);
}

@freezed
class NcView with _$NcView {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcView({
    required final String id,
    required final String fkModelId,
    @JsonKey(fromJson: _toViewTypes) required final ViewTypes type,
    @JsonKey(fromJson: _toBool) @Default(false) final bool showSystemFields,
    required final String baseId,
    required final String title,
  }) = _NcView;
  factory NcView.fromJson(final Map<String, dynamic> json) =>
      _$NcViewFromJson(json);
}

@freezed
class ViewList with _$ViewList {
  const factory ViewList({required final List<NcView> list}) = _ViewList;

  factory ViewList.fromJson(final Map<String, dynamic> json) =>
      _$ViewListFromJson(json);
}

UITypes _toUITypes(final dynamic v) {
  if (v is String) {
    for (final ut in UITypes.values) {
      if (ut.value == v) {
        return ut;
      }
    }
  }
  return UITypes.unknown;
}

const _maxInt = 4294967296;

@freezed
class NcTableColumn with _$NcTableColumn {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcTableColumn({
    required final String id,
    required final String baseId,
    required final String fkModelId,
    required final String title,
    final String? columnName,
    @Default(_maxInt) final int order,
    @JsonKey(name: 'colOptions') final NcColOptions? colOptions,
    @JsonKey(fromJson: _toBool) @Default(false) final bool pk,
    @JsonKey(fromJson: _toBool) @Default(false) final bool pv,
    @JsonKey(fromJson: _toUITypes) required final UITypes uidt,
    @JsonKey(fromJson: _toBool) @Default(false) final bool system,
    @JsonKey(fromJson: _toBool) required final bool ai, // auto increment
    @JsonKey(fromJson: _toBool) required final bool rqd, // required
    final String? cdf,
    final Map<String, dynamic>? meta,
  }) = _NcTableColumn;

  factory NcTableColumn.fromJson(final Map<String, dynamic> json) =>
      _$NcTableColumnFromJson(json);
}

@freezed
class NcOption with _$NcOption {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcOption({
    required final String color,
    required final String fkColumnId,
    required final int order,
    required final String title,
  }) = _NcOption;

  factory NcOption.fromJson(final Map<String, dynamic> json) =>
      _$NcOptionFromJson(json);
}

@freezed
class NcColOptions with _$NcColOptions {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcColOptions({
    final String? type,
    final String? fkRelatedModelId,
    final String? fkChildColumnId,
    final String? fkParentColumnId,
    final List<NcOption>? options,
  }) = _NcColOptions;

  factory NcColOptions.fromJson(final Map<String, dynamic> json) =>
      _$NcColOptionsFromJson(json);
}

bool _toBool(final dynamic v) {
  if (v == null) {
    return false;
  }
  if (v is bool) {
    return v;
  }
  return v == 1;
}

ViewTypes _toViewTypes(final dynamic v) {
  if (v is int) {
    for (final vt in ViewTypes.values) {
      if (vt.value == v) {
        return vt;
      }
    }
  }
  return ViewTypes.unknown;
}

@freezed
class NcTable with _$NcTable {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcTable({
    required final String id,
    required final String baseId,
    required final String title,
    required final List<NcTableColumn> columns,
    @JsonKey(name: 'columnsById')
    required final Map<String, NcTableColumn> columnsById,
    required final List<NcView> views,
  }) = _NcTable;

  factory NcTable.fromJson(final Map<String, dynamic> json) =>
      _$NcTableFromJson(json);
}

@freezed
class NcViewColumn with _$NcViewColumn {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcViewColumn({
    required final String id,
    required final String baseId,
    required final String fkViewId,
    required final String fkColumnId,
    required final String width,
    @Default(_maxInt) final int order,
    @JsonKey(fromJson: _toBool) required final bool show,
  }) = _NcViewColumn;

  factory NcViewColumn.fromJson(final Map<String, dynamic> json) =>
      _$NcViewColumnFromJson(json);
}

SortDirectionTypes _toSortTypes(final dynamic v) {
  if (v is String) {
    for (final vt in SortDirectionTypes.values) {
      if (vt.value == v) {
        return vt;
      }
    }
  }
  return SortDirectionTypes.unknown;
}

@freezed
class NcAttachedFile with _$NcAttachedFile {
  const factory NcAttachedFile({
    required final String path,
    required final String title,
    required final String mimetype,
    required final String signedPath,
  }) = _NcAttachedFile;

  factory NcAttachedFile.fromJson(final Map<String, dynamic> json) =>
      _$NcAttachedFileFromJson(json);
}
