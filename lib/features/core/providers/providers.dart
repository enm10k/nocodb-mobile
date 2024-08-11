import 'package:collection/collection.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

final workspaceProvider = StateProvider<NcWorkspace?>((ref) => null);
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
      final t = await api.dbTableRead(tableId: fk);
      relations[fk] = t;
    }),
  );
  return relations;
}

@Riverpod(keepAlive: true)
class View extends _$View {
  @override
  NcView? build() => null;

  void showSystemFields() async {
    final view = await api.dbViewUpdate(
      viewId: state!.id,
      data: {
        'show_system_fields': !state!.showSystemFields,
      },
    );
    state = view;
  }

  void update(NcView view) => state = view;

  Future<void> reload() async {
    final table = ref.watch(tableProvider);
    if (table == null) {
      return;
    }

    final result = await api.dbViewList(tableId: table.id);
    state = result.list.firstWhereOrNull((element) => element.id == state?.id);
  }
}

@riverpod
Future<NcWorkspaceList> workspaceList(WorkspaceListRef ref) async {
  final result = await api.workspaceList();
  if (ref.read(workspaceProvider) == null) {
    ref.read(workspaceProvider.notifier).state = result.list.firstOrNull;
  }
  return result;
}

@riverpod
Future<NcProjectList> baseList(BaseListRef ref, workspaceId) async =>
    await api.baseList(workspaceId);

@riverpod
Future<NcProjectList> projectList(ProjectListRef ref) async =>
    await api.projectList();

@Riverpod(keepAlive: true)
Future<NcSimpleTableList> tableList(
  TableListRef ref,
  String projectId,
) async =>
    await api.dbTableList(projectId: projectId);

@Riverpod(keepAlive: true)
Future<ViewList> viewList(ViewListRef ref, String tableId) async =>
    await api.dbViewList(tableId: tableId);

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
    StateProviderFamily<SearchQuery?, NcView>((ref, view) => null);

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
    final columns = rowList.toTableColumns(table.columns);
    return rowList.copyWith(
      list: rowList.list
          .map(
            (row) => {
              // Use columns instead of table.columns.
              // table.columns contain unnecessary ones.
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
    final isLoaded = ref.read(isLoadedProvider);
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

    final rowList = await api.dbViewRowList(
      view: view,
      offset: pageInfo.page * pageInfo.pageSize,
      limit: pageInfo.pageSize,
      where: searchQuery,
    );
    state = AsyncData(
      populate(
        NcRowList(
          list: [...currentRows, ...rowList.list],
          pageInfo: rowList.pageInfo,
        ),
        tables.table,
        tables.relationMap,
      ),
    );
  }

  Future<void> deleteRow({
    required String rowId,
  }) async {
    state = const AsyncValue.loading();
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

    final newRows = currentRows
        .whereNot((row) => row[_pkName].toString() == rowId)
        .toList();

    state = AsyncData(
      NcRowList(
        list: newRows,
        pageInfo: state.value?.pageInfo,
      ),
    );
  }

  Future<NcRow> updateRow({
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

    final rowList = await api.dbViewRowUpdate(
      view: view,
      rowId: rowId,
      data: data,
    );
    final updatedFields =
        data.keys.where((field) => rowList.keys.contains(field));

    final currentRows = state.value?.list;

    if (currentRows == null) {
      logger.warning('currentRows is null');
      return {};
    }

    Map<String, dynamic> newRow = {};
    final newRows = currentRows.map<Map<String, dynamic>>((row) {
      if (row[_pkName].toString() != rowId) {
        return row;
      }

      for (final updatedField in updatedFields) {
        row.update(updatedField, (_) => result[updatedField]);
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
    return rows.firstWhereOrNull(
          (row) => table?.getPkFromRow(row) == rowId,
        ) ??
        {};
  }
}

final rowNestedWhereProvider = StateProvider.family<Where?, NcTableColumn>(
  (ref, column) => null,
);

typedef PrimaryRecord = (String key, dynamic value);
typedef PrimaryRecordList = (List<PrimaryRecord> list, NcPageInfo? pageInfo);

@riverpod
class RowNested extends _$RowNested {
  List<PrimaryRecord> _populate(List<Map<String, dynamic>> list) => list
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

  @override
  Future<PrimaryRecordList> build(
    String rowId,
    NcTableColumn column,
    NcTable relation, {
    bool excluded = false,
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

    if (column.isBelongsTo) {
      assert(
        excluded,
        'excluded flag should be true for relation type belongsTo',
      );
    }

    final result = await fn(
      column: column,
      rowId: rowId,
      offset: offset,
      limit: limit,
      where: where,
    );
    state = AsyncData(
      (
        [
          ...list,
          ..._populate(result.list),
        ],
        result.pageInfo,
      ),
    );
  }

  _invalidate() {
    ref
      ..invalidateSelf()
      ..invalidate(dataRowsProvider)
      ..invalidate(
        rowNestedProvider(rowId, column, relation, excluded: !excluded),
      );
  }

  Future<String> remove({
    required String refRowId,
  }) async {
    final result = await api.dbTableRowNestedRemove(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
    );
    _invalidate();
    return result;
  }

  Future<String> link({
    required refRowId,
  }) async {
    final result = await api.dbTableRowNestedAdd(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
    );
    _invalidate();
    return result;
  }
}
