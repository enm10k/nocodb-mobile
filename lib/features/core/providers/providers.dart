import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '/nocodb_sdk/client.dart';
import '/nocodb_sdk/models.dart';
import '/nocodb_sdk/symbols.dart';
import '../../../common/logger.dart';

part 'providers.g.dart';

final projectProvider = StateProvider<NcProject?>((ref) => null);

final tableProvider = StateProvider<NcTable?>((ref) => null);

final tablesProvider = StateProvider<NcTables?>((ref) => null);

final isLoadedProvider = Provider<bool>((ref) {
  final table = ref.watch(tableProvider);
  final view = ref.watch(viewProvider);
  final tables = ref.watch(tablesProvider);
  return table != null &&
      view != null &&
      view.fkModelId == table.id &&
      tables != null;
});

Future<Map<String, NcTable>> getRelations(
  NcTable table,
) async {
  final relations = <String, NcTable>{};

  await Future.wait(
    table.foreignKeys.map((fk) async {
      await api.dbTableRead(tableId: fk).then((relatedTable) {
        logger.info(
          'fetched relation. ${table.title}->${relatedTable.title}',
        );
        relations[fk] = relatedTable;
      });
    }),
  );
  return relations;
}

@Riverpod(keepAlive: true)
class View extends _$View {
  @override
  NcView? build() {
    return null;
  }

  void showSystemFields(bool show) async {
    final view = state;
    if (view == null) {
      return;
    }
    final newView = await api.dbViewUpdate(
      viewId: view.id,
      data: {
        'show_system_fields': show,
      },
    );

    state = newView;
  }

  void set(NcView view) => state = view;
}

@riverpod
Future<NcProjectList> projectList(ProjectListRef ref) async =>
    api.projectList();

@Riverpod(keepAlive: true)
Future<NcSimpleTableList> tableList(TableListRef ref, String projectId) async =>
    api.dbTableList(projectId: projectId);

@Riverpod(keepAlive: true)
Future<ViewList> viewList(ViewListRef ref, String tableId) async =>
    api.dbViewList(tableId: tableId);

@Riverpod(keepAlive: true)
Future<List<NcViewColumn>> viewColumnList(
  ViewColumnListRef ref,
  String viewId,
) async =>
    api.dbViewColumnList(viewId: viewId);

// TODO: Move to proper file
List<NcTableColumn> tablesToColumns(NcTables tables) {
  return [
    ...tables.table.columns,
    ...tables.relationMap.values.map((t) => t.columns).expand((v) => v),
  ];
}

// TODO: Move to proper file
List<NcTableColumn> rowsToTableColumns(
  List<Map<String, dynamic>> rows,
  Iterable<NcTableColumn> columns,
) {
  final titles = rows.firstOrNull?.keys ?? [];
  final columnsByTitle = Map.fromIterables(
    columns.map((c) => c.title),
    columns,
  );
  return titles.map((t) => columnsByTitle[t]).whereNotNull().toList();
}

@Riverpod()
class Fields extends _$Fields {
  static const debug = false;

  @override
  Future<List<NcTableColumn>> build(NcView view) async {
    final table = ref.watch(tableProvider);
    if (table == null) {
      return [];
    }

    return ref
        .watch(viewColumnListProvider(view.id).future)
        .then((viewColumns) {
      final fields = viewColumns.getColumnsToShow(table, view)
        ..sort((a, b) => a.order.compareTo(b.order));
      return fields
          .map(
            (columns) => columns.toTableColumn(table.columns),
          )
          .whereNotNull()
          .toList();
    });
  }
}

class SearchQuery {
  final String columnName;
  final String query;
  final QueryOperator operator;
  const SearchQuery({
    required this.columnName,
    required this.operator,
    required this.query,
  });

  @override
  String toString() {
    return '($columnName,$operator,$query)';
  }
}

final searchQueryFamily =
    StateProviderFamily<SearchQuery?, NcView>((ref, view) => null);

// TODO: Separate to DataRows and PopulatedDataRows
@riverpod
class DataRows extends _$DataRows {
  late String? _pkName;

  dynamic _getForeignKeyPrimaryValue({
    required Map<String, dynamic> row,
    required String columnId,
    required NcTable table,
    required Map<String, NcTable> relations,
  }) {
    final parentColumn = table.getParentColumn(columnId);
    if (parentColumn == null) {
      return;
    }

    final pkTitle = relations[parentColumn.fkRelatedModelId!]!.pkNames.first;

    final value = row[parentColumn.title];
    return value is Map ? value[pkTitle] : null;
  }

  NcRowList populate(
    NcRowList rowList,
    NcTable table,
    Map<String, NcTable> relations,
  ) {
    final columns = rowsToTableColumns(rowList.list, table.columns);
    return rowList.copyWith(
      list: rowList.list
          .map(
            (row) => {
              // Use columns here instead of table.columns.
              // Using table.columns adds unnecessary columns.
              for (final column in columns)
                column.title: column.uidt != UITypes.foreignKey
                    ? row[column.title]
                    : _getForeignKeyPrimaryValue(
                        columnId: column.id,
                        row: row,
                        table: table,
                        relations: relations,
                      ),
            },
          )
          .toList(),
    );
  }

  @override
  Future<NcRowList?> build() async {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return null;
    }
    final table = ref.watch(tableProvider)!;
    final tables = ref.watch(tablesProvider)!;
    final view = ref.watch(viewProvider)!;

    // This provider should be updated every time sort is updated.
    // final _ = ref.watch(sortListProvider(view.id));

    _pkName = table.pkName;
    final searchQuery = ref.watch(searchQueryFamily(view));
    logger.info('searchQuery: $searchQuery');

    final rowList = await api.dbViewRowList(
      view: view,
      where: searchQuery,
    );

    return populate(rowList, table, tables.relationMap);
  }

  Future<void> loadNextPage() async {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return;
    }

    final tables = ref.read(tablesProvider)!;
    final view = ref.read(viewProvider)!;
    final value = state.value;
    if (value == null) {
      assert(false);
      logger.warning('state.value is null');
      return;
    }
    final currentRows = value.list;
    final pageInfo = value.pageInfo!;

    final searchQuery = ref.read(searchQueryFamily(view));
    logger.info('searchQuery: $searchQuery');

    final newRowList = await api.dbViewRowList(
      view: view,
      offset: pageInfo.page * pageInfo.pageSize,
      limit: pageInfo.pageSize,
      where: searchQuery,
    );

    state = AsyncData(
      populate(
        NcRowList(
          list: [...currentRows, ...newRowList.list],
          pageInfo: newRowList.pageInfo,
        ),
        tables.table,
        tables.relationMap,
      ),
    );
  }

  Future<void> deleteRow({
    required String rowId,
  }) async {
    final view = ref.read(viewProvider)!;
    await api.dbViewRowDelete(
      view: view,
      rowId: rowId,
    );

    final currentRows = state.value?.list;

    if (currentRows == null) {
      logger.warning('currentRows are null');
      return;
    }
    if (_pkName == null) {
      return;
    }

    final newRows = currentRows.where((row) => row[_pkName] == rowId).toList();

    state = AsyncData(
      NcRowList(
        list: newRows,
        pageInfo: state.value?.pageInfo,
      ),
    );
  }

  Future<void> updateRow({
    required String rowId,
    required Map<String, dynamic> data,
  }) async {
    // The result doesn't contain related fields.
    final view = ref.read(viewProvider)!;
    final result = await api.dbViewRowUpdate(
      view: view,
      rowId: rowId,
      data: data,
    );
    logger.info(result);

    final updatedFields =
        data.keys.where((field) => result.keys.contains(field));

    final currentRows = state.value?.list;

    if (currentRows == null) {
      logger.warning('currentRows is null');
      return;
    }

    final newRows = currentRows.map((row) {
      if (row[_pkName].toString() != rowId) {
        return row;
      }

      for (final updatedField in updatedFields) {
        row.update(updatedField, (_) => result[updatedField]);
      }

      return row;
    }).toList();

    state = AsyncData(
      NcRowList(
        list: newRows,
        pageInfo: state.value?.pageInfo,
      ),
    );
    return;
  }

  Future<Map<String, dynamic>> createRow(Map<String, dynamic> row) async {
    final view = ref.read(viewProvider)!;
    final newRow = await api.dbViewRowCreate(
      view: view,
      data: row,
    );
    state = AsyncData(
      NcRowList(
        list: [
          ...state.value?.list ?? [],
          newRow,
        ],
        pageInfo: state.value?.pageInfo,
      ),
    );
    return newRow;
  }

  Map<String, dynamic> getRow(String? rowId) {
    if (rowId == null) {
      return {};
    }

    final table = ref.watch(tableProvider);
    final rows = state.valueOrNull?.list ?? [];
    return rows.firstWhereOrNull((row) {
          return table?.getPkFromRow(row) == rowId;
        }) ??
        {};
  }
}

// @riverpod
// class DataRow extends _$DataRow {
//   @override
//   Map<String, dynamic>? build(NcView view, String? rowId) {
//     final table = ref.watch(tableProvider);
//     final rows = ref.watch(dataRowsProvider(view)).valueOrNull;
//
//     return rows?.list.firstWhereOrNull((row) {
//       return table?.getPkFromRow(row) == rowId;
//     });
//   }
// }

final rowNestedWhereProvider =
    StateProvider.family<Where?, NcTableColumn>((ref, column) => null);

typedef PrimaryRecord = (String key, dynamic value);
typedef PrimaryRecordList = (List<PrimaryRecord> list, NcPageInfo? pageInfo);

@riverpod
class RowNested extends _$RowNested {
  List<PrimaryRecord> _populate(List<Map<String, dynamic>> list) {
    return list
        .map((row) {
          final key = relation.getRefRowIdFromRow(column: column, row: row);
          if (key == null) {
            return null;
          }
          final value = relation.getPvFromRow(row);
          return (key, value);
        })
        .whereNotNull()
        .toList();
  }

  @override
  Future<PrimaryRecordList> build(
    String rowId,
    NcTableColumn column,
    NcTable relation, {
    excluded = false,
  }) async {
    final fn = excluded
        ? api.dbTableRowNestedChildrenExcludedList
        : api.dbTableRowNestedList;

    if (column.isBelongsTo) {
      assert(
        excluded,
        'excluded flag should be true for relation type belongsTo',
      );
    }
    final where = excluded ? ref.watch(rowNestedWhereProvider(column)) : null;

    final result = await fn(column: column, rowId: rowId, where: where);

    return (
      _populate(result.list),
      result.pageInfo!,
    );
  }

  Future<void> load() async {
    if (state.value == null) {
      return;
    }

    final (List<PrimaryRecord> list, NcPageInfo? pageInfo) = state.value!;
    if (pageInfo == null) {
      assert(false);
      return;
    }
    final offset = pageInfo.page * pageInfo.pageSize;
    final limit = pageInfo.pageSize;

    final where = excluded ? ref.read(rowNestedWhereProvider(column)) : null;

    final fn = excluded
        ? api.dbTableRowNestedChildrenExcludedList
        : api.dbTableRowNestedList;
    final rowList = await fn(
      column: column,
      rowId: rowId,
      offset: offset,
      limit: limit,
      where: where,
    );

    if (column.isBelongsTo) {
      assert(
        excluded,
        'excluded flag should be true for relation type belongsTo',
      );
    }

    state = AsyncData(
      (
        [
          ...list,
          ..._populate(rowList.list),
        ],
        rowList.pageInfo,
      ),
    );
  }

  _invalidate() {
    ref.invalidateSelf();
    ref.invalidate(dataRowsProvider);
    ref.invalidate(
      rowNestedProvider(rowId, column, relation),
    );
  }

  Future<String> remove({
    required String refRowId,
  }) async {
    final msg = await api.dbTableRowNestedRemove(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
    );

    _invalidate();
    return msg;
  }

  Future<String> link({
    required refRowId,
  }) async {
    final msg = await api.dbTableRowNestedAdd(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
    );

    _invalidate();
    return msg;
  }
}

@riverpod
class SortList extends _$SortList {
  @override
  FutureOr<NcSortList?> build(String viewId) async {
    return api.dbTableSortList(viewId: viewId);
  }

  Future<void> create({
    required String fkColumnId,
    required SortDirectionTypes direction,
  }) async {
    state = const AsyncLoading();
    await api.dbTableSortCreate(
      viewId: viewId,
      fkColumnId: fkColumnId,
      direction: direction,
    );

    state = await AsyncValue.guard(() => api.dbTableSortList(viewId: viewId));
  }

  Future<void> delete(String sortId) async {
    state = const AsyncLoading();
    await api.dbTableSortDelete(sortId: sortId);
    state = await AsyncValue.guard(() => api.dbTableSortList(viewId: viewId));
  }

  Future<void> save({
    required String sortId,
    required String fkColumnId,
    required SortDirectionTypes direction,
  }) async {
    await api.dbTableSortUpdate(
      sortId: sortId,
      fkColumnId: fkColumnId,
      direction: direction,
    );
    state = await AsyncValue.guard(() => api.dbTableSortList(viewId: viewId));
  }
}

@riverpod
class Attachments extends _$Attachments {
  @override
  List<NcAttachedFile> build(NcView view, String? rowId, String columnTitle) {
    final rows = ref.watch(dataRowsProvider).valueOrNull?.list ?? [];
    final table = ref.watch(tableProvider);
    final row = rows.firstWhereOrNull((row) {
          return table?.getPkFromRow(row) == rowId;
        }) ??
        {};

    final files = (row[columnTitle] ?? [])
        .map<NcAttachedFile>(
          (e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList() as List<NcAttachedFile>;
    return files;
  }

  upload(List<NcFile> files, FnOnUpdate onUpdate) async {
    final newAttachedFiles = await api.dbStorageUpload(files);
    state = [
      ...state,
      ...newAttachedFiles,
    ];
    await onUpdate({columnTitle: state});
  }

  delete(String id, FnOnUpdate onUpdate) async {
    state = [...state].where((e) => e.id != id).toList();
    await onUpdate({columnTitle: state});
  }

  rename(String id, String title, FnOnUpdate onUpdate) async {
    state = [...state].map<NcAttachedFile>((e) {
      return e.id == id ? e.copyWith(title: title) : e;
    }).toList();
    await onUpdate({columnTitle: state});
  }
}
