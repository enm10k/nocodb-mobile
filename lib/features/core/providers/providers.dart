import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

final workspaceProvider = StateProvider<NcWorkspace?>((ref) => null);
final projectProvider = StateProvider<NcProject?>((ref) => null);
final tableProvider = StateProvider<NcTable?>((ref) => null);

Future<void> selectProject(WidgetRef ref, NcProject project) async {
  ref.read(projectProvider.notifier).state = project;

  final tableId = await _unwrap2(
    await api.dbTableList(projectId: project.id),
    serializer: (data) => data.list.firstOrNull?.id,
  );

  if (tableId == null) {
    return;
  }

  final table = await _unwrap(await api.dbTableRead(tableId: tableId));
  await selectTable(ref, table);
}

Future<void> selectTable(WidgetRef ref, NcTable table) async {
  ref.read(tableProvider.notifier).state = table;

  final relationMap = await getRelations(table);
  ref.watch(tablesProvider.notifier).state = NcTables(
    table: table,
    relationMap: relationMap,
  );

  final view = await _unwrap2(
    await api.dbViewList(tableId: table.id),
    serializer: (data) => data.list.firstOrNull,
  );
  if (view == null) {
    return;
  }
  await selectView(ref, view);
}

Future<void> selectView(WidgetRef ref, NcView view) async {
  ref.read(viewProvider.notifier).set(view);

  final table = ref.read(tableProvider);
  if (table == null) {
    return;
  }
  if (table.id != view.fkModelId) {
    final newTable = await _unwrap(await api.dbTableRead(tableId: table.id));
    await selectTable(ref, newTable);
  }
}

// @Riverpod(keepAlive: true)
// class Table extends _$Table {
//   @override
//   NcTable? build() => null;
//
//   void set(NcTable table) => state = table;
//
//   Future<NcTable?> load(NcProject project) async {
//     final tableId = await _unwrap2(
//       await api.dbTableList(projectId: project.id),
//       serializer: (data) => data.list.firstOrNull?.id,
//     );
//
//     if (tableId == null) {
//       return null;
//     }
//
//     final table = await _unwrap(await api.dbTableRead(tableId: tableId));
//     state = table;
//     return table;
//   }
// }

// @riverpod
// class Table extends _$Table {
//   @override
//   Future<NcTable?> build() async {
//     final project = ref.watch(projectProvider);
//     final tableId = await _unwrap2(
//       await api.dbTableList(projectId: project.id),
//       serializer: (data) => data.list.firstOrNull?.id,
//     );
//
//     if (tableId == null) {
//       return null;
//     }
//
//     return _unwrap(await api.dbTableRead(tableId: tableId));
//   }
//
//   void set(NcTable table) => state = AsyncData(table);
// }

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
      await _unwrap2(
        await api.dbTableRead(tableId: fk),
        serializer: (result) {
          logger.info(
            'fetched relation. ${table.title}->${result.title}',
          );
          relations[fk] = result;
        },
      );
    }),
  );
  return relations;
}

@Riverpod(keepAlive: true)
class View extends _$View {
  @override
  NcView? build() => null;

  void showSystemFields() async {
    if (state == null) {
      return;
    }
    _unwrap2(
      await api.dbViewUpdate(
        viewId: state!.id,
        data: {
          'show_system_fields': !state!.showSystemFields,
        },
      ),
      serializer: (ok) => state = ok,
    );
  }

  void set(NcView view) => state = view;
}

FutureOr<T> _errorAdapter<T>(Object error, StackTrace? stackTrace) {
  if (stackTrace != null) {
    Error.throwWithStackTrace(error, stackTrace);
  } else {
    throw error;
  }
}

// NOTE: If an error or exception occurs within a provider,
// it will be handled as an AsyncError by the side using the provider.
FutureOr<T> _unwrap<T>(
  Result<T> result, {
  T Function(T)? serializer,
}) =>
    result.when(
      ok: (ok) => (serializer != null ? serializer(ok) : ok),
      ng: _errorAdapter,
    );

FutureOr<T2> _unwrap2<T1, T2>(
  Result<T1> result, {
  required T2 Function(T1) serializer,
}) =>
    result.when(
      ok: (ok) => serializer(ok),
      ng: _errorAdapter,
    );

@riverpod
Future<NcWorkspaceList> workspaceList(WorkspaceListRef ref) async =>
    (await api.workspaceList()).when(
      ok: (ok) {
        if (ref.read(workspaceProvider) == null) {
          ref.read(workspaceProvider.notifier).state = ok.list.firstOrNull;
        }
        return ok;
      },
      ng: _errorAdapter,
    );

@riverpod
Future<NcProjectList> baseList(BaseListRef ref, workspaceId) async =>
    _unwrap(await api.baseList(workspaceId));

@riverpod
Future<NcProjectList> projectList(ProjectListRef ref) async =>
    _unwrap(await api.projectList());

@Riverpod(keepAlive: true)
Future<NcSimpleTableList> tableList(
  TableListRef ref,
  String projectId,
) async =>
    _unwrap(await api.dbTableList(projectId: projectId));

@Riverpod(keepAlive: true)
Future<ViewList> viewList(ViewListRef ref, String tableId) async =>
    _unwrap(await api.dbViewList(tableId: tableId));

@Riverpod(keepAlive: true)
Future<List<NcViewColumn>> viewColumnList(
  ViewColumnListRef ref,
  String viewId,
) async =>
    _unwrap(await api.dbViewColumnList(viewId: viewId));

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

    return _unwrap(
      await api.dbViewRowList(
        view: view,
        where: searchQuery,
      ),
      serializer: (result) {
        if (result == null) {
          return null;
        }
        return populate(result, table, tables.relationMap);
      },
    );
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

    _unwrap2(
      await api.dbViewRowList(
        view: view,
        offset: pageInfo.page * pageInfo.pageSize,
        limit: pageInfo.pageSize,
        where: searchQuery,
      ),
      serializer: (result) {
        state = AsyncData(
          populate(
            NcRowList(
              list: [...currentRows, ...result.list],
              pageInfo: result.pageInfo,
            ),
            tables.table,
            tables.relationMap,
          ),
        );
      },
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

    return _unwrap(
      await api.dbViewRowUpdate(
        view: view,
        rowId: rowId,
        data: data,
      ),
      serializer: (result) {
        final updatedFields =
            data.keys.where((field) => result.keys.contains(field));

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
      },
    );
  }

  Future<Map<String, dynamic>> createRow(Map<String, dynamic> row) async {
    final view = ref.read(viewProvider)!;
    return _unwrap(
      await api.dbViewRowCreate(
        view: view,
        data: row,
      ),
      serializer: (result) {
        state = AsyncData(
          NcRowList(
            list: [
              ...state.value?.list ?? [],
              result,
            ],
            pageInfo: state.value?.pageInfo,
          ),
        );
        return result;
      },
    );
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

    return _unwrap2(
      await fn(column: column, rowId: rowId, where: where),
      serializer: (result) => (
        _populate(result.list),
        result.pageInfo!,
      ),
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

    _unwrap2(
      await fn(
        column: column,
        rowId: rowId,
        offset: offset,
        limit: limit,
        where: where,
      ),
      serializer: (result) {
        state = AsyncData(
          (
            [
              ...list,
              ..._populate(result.list),
            ],
            result.pageInfo,
          ),
        );
      },
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
  }) async =>
      _unwrap(
        await api.dbTableRowNestedRemove(
          column: column,
          rowId: rowId,
          refRowId: refRowId,
        ),
        serializer: (result) {
          _invalidate();
          return result;
        },
      );

  Future<String> link({
    required refRowId,
  }) async =>
      _unwrap(
        await api.dbTableRowNestedAdd(
          column: column,
          rowId: rowId,
          refRowId: refRowId,
        ),
        serializer: (result) {
          _invalidate();
          return result;
        },
      );
}

@riverpod
class SortList extends _$SortList {
  @override
  FutureOr<NcSortList?> build(String viewId) async =>
      _unwrap(await api.dbTableSortList(viewId: viewId));

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

    _unwrap2(
      await api.dbTableSortList(viewId: viewId),
      serializer: (result) {
        state = AsyncData(result);
        return result;
      },
    );
  }

  Future<void> delete(String sortId) async {
    state = const AsyncLoading();
    await api.dbTableSortDelete(sortId: sortId);
    ref.invalidateSelf();
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
    ref.invalidateSelf();
  }
}

@riverpod
class Attachments extends _$Attachments {
  @override
  List<NcAttachedFile> build(
    String? rowId,
    String columnTitle,
  ) {
    final rows = ref.watch(dataRowsProvider).valueOrNull?.list ?? [];
    final table = ref.watch(tableProvider);
    final row = rows.firstWhereOrNull(
          (row) => table?.getPkFromRow(row) == rowId,
        ) ??
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
    state = [...state]
        .map<NcAttachedFile>(
          (e) => e.id == id ? e.copyWith(title: title) : e,
        )
        .toList();
    await onUpdate({columnTitle: state});
  }
}
