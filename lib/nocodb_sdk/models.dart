import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/logger.dart';
import 'symbols.dart';

part 'models.freezed.dart';
part 'models.g.dart';
part 'models_extensions.dart';

@freezed
class NcTables with _$NcTables {
  @JsonSerializable()
  const factory NcTables({
    required NcTable table,
    @Default({}) Map<String, NcTable> relationMap,
  }) = _NcTables;
  factory NcTables.fromJson(Map<String, dynamic> json) =>
      _$NcTablesFromJson(json);
}

@freezed
class NcUser with _$NcUser {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcUser({
    required String id,
    required String email,
    required Map<String, bool?> roles,
    bool? emailVerifier,
    String? firstname,
    String? lastname,
  }) = _NcUser;
  factory NcUser.fromJson(Map<String, dynamic> json) => _$NcUserFromJson(json);
}

@freezed
class NcProject with _$NcProject {
  const factory NcProject({required String id, required String title}) =
      _NcProject;
  factory NcProject.fromJson(Map<String, dynamic> json) =>
      _$NcProjectFromJson(json);
}

@freezed
class NcPageInfo with _$NcPageInfo {
  const factory NcPageInfo({
    required int totalRows,
    required int page,
    required int pageSize,
    required bool isFirstPage,
    required bool isLastPage,
  }) = _NcPageInfo;

  factory NcPageInfo.fromJson(Map<String, dynamic> json) =>
      _$NcPageInfoFromJson(json);
}

@freezed
class NcProjectList with _$NcProjectList {
  const factory NcProjectList({
    required List<NcProject> list,
    required NcPageInfo pageInfo,
  }) = _NcProjectList;
  factory NcProjectList.fromJson(Map<String, dynamic> json) =>
      _$NcProjectListFromJson(json);
}

@freezed
class NcSlimTable with _$NcSlimTable {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcSlimTable({
    required String id,
    required String baseId,
    required String tableName,
    required String title,
    required String type,
  }) = _NcSlimTable;
  factory NcSlimTable.fromJson(Map<String, dynamic> json) =>
      _$NcSlimTableFromJson(json);
}

@freezed
class NcSimpleTableList with _$NcSimpleTableList {
  const factory NcSimpleTableList({required List<NcSlimTable> list}) =
      _NcSimpleTableList;
  factory NcSimpleTableList.fromJson(Map<String, dynamic> json) =>
      _$NcSimpleTableListFromJson(json);
}

@freezed
class NcView with _$NcView {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcView({
    required String id,
    required String fkModelId,
    @JsonKey(fromJson: _toViewTypes) required ViewTypes type,
    @JsonKey(fromJson: _toBool) @Default(false) bool showSystemFields,
    required String baseId,
    required String title,
  }) = _NcView;
  factory NcView.fromJson(Map<String, dynamic> json) => _$NcViewFromJson(json);
}

@freezed
class ViewList with _$ViewList {
  const factory ViewList({required List<NcView> list}) = _ViewList;

  factory ViewList.fromJson(Map<String, dynamic> json) =>
      _$ViewListFromJson(json);
}

UITypes _toUITypes(dynamic v) {
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
    required String id,
    required String baseId,
    required String fkModelId,
    required String title,
    String? columnName,
    @Default(_maxInt) int order,
    @JsonKey(name: 'colOptions') NcColOptions? colOptions,
    @JsonKey(fromJson: _toBool) @Default(false) bool pk,
    @JsonKey(fromJson: _toBool) @Default(false) bool pv,
    @JsonKey(fromJson: _toUITypes) required UITypes uidt,
    @JsonKey(fromJson: _toBool) @Default(false) bool system,
    @JsonKey(fromJson: _toBool) required bool ai, // auto increment
    @JsonKey(fromJson: _toBool) required bool rqd, // required
    String? cdf,
    Map<String, dynamic>? meta,
  }) = _NcTableColumn;

  factory NcTableColumn.fromJson(Map<String, dynamic> json) =>
      _$NcTableColumnFromJson(json);
}

@freezed
class NcOption with _$NcOption {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcOption({
    required String color,
    required String fkColumnId,
    required int order,
    required String title,
  }) = _NcOption;

  factory NcOption.fromJson(Map<String, dynamic> json) =>
      _$NcOptionFromJson(json);
}

@freezed
class NcColOptions with _$NcColOptions {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcColOptions({
    String? type,
    String? fkRelatedModelId,
    String? fkChildColumnId,
    String? fkParentColumnId,
    List<NcOption>? options,
  }) = _NcColOptions;

  factory NcColOptions.fromJson(Map<String, dynamic> json) =>
      _$NcColOptionsFromJson(json);
}

bool _toBool(dynamic v) {
  if (v == null) {
    return false;
  }
  if (v is bool) {
    return v;
  }
  return v == 1;
}

ViewTypes _toViewTypes(dynamic v) {
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
    required String id,
    required String baseId,
    required String title,
    required List<NcTableColumn> columns,
    @JsonKey(name: 'columnsById')
    required Map<String, NcTableColumn> columnsById,
    required List<NcView> views,
  }) = _NcTable;

  factory NcTable.fromJson(Map<String, dynamic> json) =>
      _$NcTableFromJson(json);
}

@freezed
class NcViewColumn with _$NcViewColumn {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcViewColumn({
    required String id,
    required String baseId,
    required String fkViewId,
    required String fkColumnId,
    required String width,
    @Default(_maxInt) int order,
    @JsonKey(fromJson: _toBool) required bool show,
  }) = _NcViewColumn;

  factory NcViewColumn.fromJson(Map<String, dynamic> json) =>
      _$NcViewColumnFromJson(json);
}

@freezed
class NcRowList with _$NcRowList {
  const factory NcRowList({
    NcPageInfo? pageInfo,
    required List<Map<String, dynamic>> list,
  }) = _NcRowList;

  factory NcRowList.fromJson(Map<String, dynamic> json) =>
      _$NcRowListFromJson(json);
}

SortDirectionTypes _toSortTypes(dynamic v) {
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
class NcSort with _$NcSort {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory NcSort({
    required String id,
    required String fkViewId,
    required String fkColumnId,
    @JsonKey(fromJson: _toSortTypes) required SortDirectionTypes direction,
    required int order,
  }) = _NcSort;
  factory NcSort.fromJson(Map<String, dynamic> json) => _$NcSortFromJson(json);
}

@freezed
class NcSortList with _$NcSortList {
  const factory NcSortList({
    NcPageInfo? pageInfo,
    required List<NcSort> list,
  }) = _NcSortList;

  factory NcSortList.fromJson(Map<String, dynamic> json) =>
      _$NcSortListFromJson(json);
}

@freezed
class NcAttachedFile with _$NcAttachedFile {
  const factory NcAttachedFile({
    required String path,
    required String title,
    required String mimetype,
    required String signedPath,
  }) = _NcAttachedFile;

  factory NcAttachedFile.fromJson(Map<String, dynamic> json) =>
      _$NcAttachedFileFromJson(json);
}
