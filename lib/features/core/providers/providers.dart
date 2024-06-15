import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

final projectProvider = StateProvider<NcProject?>((final ref) => null);

final tableProvider = StateProvider<NcTable?>((final ref) => null);

final tablesProvider = StateProvider<NcTables?>((final ref) => null);

final isLoadedProvider = Provider<bool>((final ref) {
  final table = ref.watch(tableProvider);
  final view = ref.watch(viewProvider);
  final tables = ref.watch(tablesProvider);
  return table != null &&
      view != null &&
      view.fkModelId == table.id &&
      tables != null;
});

Future<Map<String, NcTable>> getRelations(
  final NcTable table,
) async {
  final relations = <String, NcTable>{};

  await Future.wait(
    table.foreignKeys.map((final fk) async {
      await api.dbTableRead(tableId: fk).then((final relatedTable) {
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
  NcView? build() => null;

  void showSystemFields(final bool show) async {
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

  void set(final NcView view) => state = view;
}

@riverpod
Future<NcProjectList> projectList(final ProjectListRef ref) async =>
    api.projectList();

@Riverpod(keepAlive: true)
Future<NcSimpleTableList> tableList(
  final TableListRef ref,
  final String projectId,
) async =>
    api.dbTableList(projectId: projectId);

@Riverpod(keepAlive: true)
Future<ViewList> viewList(final ViewListRef ref, final String tableId) async =>
    api.dbViewList(tableId: tableId);

@Riverpod(keepAlive: true)
Future<List<NcViewColumn>> viewColumnList(
  final ViewColumnListRef ref,
  final String viewId,
) async =>
    api.dbViewColumnList(viewId: viewId);

// TODO: Move to proper file
List<NcTableColumn> tablesToColumns(final NcTables tables) => [
      ...tables.table.columns,
      ...tables.relationMap.values
          .map((final t) => t.columns)
          .expand((final v) => v),
    ];

// TODO: Move to proper file
List<NcTableColumn> rowsToTableColumns(
  final List<Map<String, dynamic>> rows,
  final Iterable<NcTableColumn> columns,
) {
  final titles = rows.firstOrNull?.keys ?? [];
  final columnsByTitle = Map.fromIterables(
    columns.map((final c) => c.title),
    columns,
  );
  return titles.map((final t) => columnsByTitle[t]).whereNotNull().toList();
}

@Riverpod()
class Fields extends _$Fields {
  static const debug = false;

  @override
  Future<List<NcTableColumn>> build(final NcView view) async {
    final table = ref.watch(tableProvider);
    if (table == null) {
      return [];
    }

    return ref
        .watch(viewColumnListProvider(view.id).future)
        .then((final viewColumns) {
      final fields = viewColumns.getColumnsToShow(table, view)
        ..sort((final a, final b) => a.order.compareTo(b.order));
      return fields
          .map(
            (final columns) => columns.toTableColumn(table.columns),
          )
          .whereNotNull()
          .toList();
    });
  }
}

class SearchQuery {
  const SearchQuery({
    required this.columnName,
    required this.operator,
    required this.query,
  });
  final String columnName;
  final String query;
  final QueryOperator operator;

  @override
  String toString() => '($columnName,$operator,$query)';
}

final searchQueryFamily =
    StateProviderFamily<SearchQuery?, NcView>((final ref, final view) => null);

@riverpod
class DataRows extends _$DataRows {
  late String? _pkName;

  dynamic _getForeignKeyPrimaryValue({
    required final Map<String, dynamic> row,
    required final String columnId,
    required final NcTable table,
    required final Map<String, NcTable> relations,
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
    final NcRowList rowList,
    final NcTable table,
    final Map<String, NcTable> relations,
  ) {
    final columns = rowsToTableColumns(rowList.list, table.columns);
    return rowList.copyWith(
      list: rowList.list
          .map(
            (final row) => {
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
    required final String rowId,
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

    final newRows =
        currentRows.where((final row) => row[_pkName] == rowId).toList();

    state = AsyncData(
      NcRowList(
        list: newRows,
        pageInfo: state.value?.pageInfo,
      ),
    );
  }

  Future<NcRow> updateRow({
    required final String rowId,
    required final Map<String, dynamic> data,
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
        data.keys.where((final field) => result.keys.contains(field));

    final currentRows = state.value?.list;

    if (currentRows == null) {
      logger.warning('currentRows is null');
      return {};
    }

    Map<String, dynamic> newRow = {};
    final newRows = currentRows.map<Map<String, dynamic>>((final row) {
      if (row[_pkName].toString() != rowId) {
        return row;
      }

      for (final updatedField in updatedFields) {
        row.update(updatedField, (final _) => result[updatedField]);
      }
      newRow = row;
      return newRow;
    }).toList();

    state = AsyncData(
      NcRowList(
        list: newRows,
        pageInfo: state.value?.pageInfo,
      ),
    );
    return newRow;
  }

  Future<Map<String, dynamic>> createRow(final Map<String, dynamic> row) async {
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

  Map<String, dynamic> getRow(final String? rowId) {
    if (rowId == null) {
      return {};
    }

    final table = ref.watch(tableProvider);
    final rows = state.valueOrNull?.list ?? [];
    return rows.firstWhereOrNull(
          (final row) => table?.getPkFromRow(row) == rowId,
        ) ??
        {};
  }
}

final rowNestedWhereProvider = StateProvider.family<Where?, NcTableColumn>(
  (final ref, final column) => null,
);

typedef PrimaryRecord = (String key, dynamic value);
typedef PrimaryRecordList = (List<PrimaryRecord> list, NcPageInfo? pageInfo);

@riverpod
class RowNested extends _$RowNested {
  List<PrimaryRecord> _populate(final List<Map<String, dynamic>> list) => list
      .map((final row) {
        final key = relation.getRefRowIdFromRow(column: column, row: row);
        if (key == null) {
          return null;
        }
        final value = relation.getPvFromRow(row);
        return (key, value);
      })
      .whereNotNull()
      .toList();

  @override
  Future<PrimaryRecordList> build(
    final String rowId,
    final NcTableColumn column,
    final NcTable relation, {
    final excluded = false,
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
    ref
      ..invalidateSelf()
      ..invalidate(dataRowsProvider)
      ..invalidate(
        rowNestedProvider(rowId, column, relation),
      );
  }

  Future<String> remove({
    required final String refRowId,
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
    required final refRowId,
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
  FutureOr<NcSortList?> build(final String viewId) async =>
      api.dbTableSortList(viewId: viewId);

  Future<void> create({
    required final String fkColumnId,
    required final SortDirectionTypes direction,
  }) async {
    state = const AsyncLoading();
    await api.dbTableSortCreate(
      viewId: viewId,
      fkColumnId: fkColumnId,
      direction: direction,
    );

    state = await AsyncValue.guard(() => api.dbTableSortList(viewId: viewId));
  }

  Future<void> delete(final String sortId) async {
    state = const AsyncLoading();
    await api.dbTableSortDelete(sortId: sortId);
    state = await AsyncValue.guard(() => api.dbTableSortList(viewId: viewId));
  }

  Future<void> save({
    required final String sortId,
    required final String fkColumnId,
    required final SortDirectionTypes direction,
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
  List<NcAttachedFile> build(
    final String? rowId,
    final String columnTitle,
  ) {
    final rows = ref.watch(dataRowsProvider).valueOrNull?.list ?? [];
    final table = ref.watch(tableProvider);
    final row = rows.firstWhereOrNull(
          (final row) => table?.getPkFromRow(row) == rowId,
        ) ??
        {};

    final files = (row[columnTitle] ?? [])
        .map<NcAttachedFile>(
          (final e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList() as List<NcAttachedFile>;
    return files;
  }

  upload(final List<NcFile> files, final FnOnUpdate onUpdate) async {
    final newAttachedFiles = await api.dbStorageUpload(files);
    state = [
      ...state,
      ...newAttachedFiles,
    ];
    await onUpdate({columnTitle: state});
  }

  delete(final String id, final FnOnUpdate onUpdate) async {
    state = [...state].where((final e) => e.id != id).toList();
    await onUpdate({columnTitle: state});
  }

  rename(final String id, final String title, final FnOnUpdate onUpdate) async {
    state = [...state]
        .map<NcAttachedFile>(
          (final e) => e.id == id ? e.copyWith(title: title) : e,
        )
        .toList();
    await onUpdate({columnTitle: state});
  }
}
