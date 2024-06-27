import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

const ncEndpoint = String.fromEnvironment('NC_ENDPOINT');
const apiToken = String.fromEnvironment('API_TOKEN');

T _rethrow<T>(Object error, StackTrace? stackTrace) {
  if (stackTrace != null) {
    Error.throwWithStackTrace(error, stackTrace);
  } else {
    throw error;
  }
}

T _unwrap<T>(
  Result<T> result, {
  T Function(T)? serializer,
}) =>
    result.when(
      ok: (ok) => (serializer != null ? serializer(ok) : ok),
      ng: _rethrow,
    );

T2 _unwrap2<T1, T2>(
  Result<T1> result, {
  required T2 Function(T1) serializer,
}) =>
    result.when(
      ok: (ok) => serializer(ok),
      ng: _rethrow,
    );

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

NcRowList _populate(
  NcRowList rowList,
  NcTable table,
  Map<String, NcTable> relations,
) {
  final columns = rowList.toTableColumns(table.columns);
  return rowList.copyWith(
    list: rowList.list
        .map(
          (row) => {
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

Future<Map<String, NcTable>> _getRelations(
  NcTable table,
) async {
  final relations = <String, NcTable>{};

  await Future.wait(
    table.foreignKeys.map((fk) async {
      _unwrap2(
        await api.dbTableRead(tableId: fk),
        serializer: (result) {
          relations[fk] = result;
        },
      );
    }),
  );
  return relations;
}

enum DataRowsState { loading, uninitialized, data }

class ProjectController extends GetxController {
  static ProjectController get to => Get.find();

  final project = Rx<NcProject?>(null);
}

class TableController extends GetxController {
  static TableController get to => Get.find();

  static ProjectController pc = Get.find();

  final table = Rx<NcTable?>(null);
  final loading = false.obs;
  final relationMap = Rx<Map<String, NcTable>>({});

  @override
  onInit() {
    ever(pc.project, (project) async {
      loading(true);
      try {
        if (project == null) {
          table.value = null;
          return;
        }
        final stable = _unwrap2(
          await api.dbTableList(projectId: project.id),
          serializer: (ok) => ok.list.firstOrNull,
        );

        if (stable != null) {
          table.value = _unwrap(await api.dbTableRead(tableId: stable.id));
          relationMap.value = await _getRelations(table.value!);
        }
        // update();
      } finally {
        loading(false);
      }
    });
  }
}

class ViewController extends GetxController {
  static ViewController get to => Get.find();

  final view = Rx<NcView?>(null);
  final loading = false.obs;

  static TableController get tc => Get.find();

  @override
  onInit() {
    ever(tc.table, (t) async {
      loading(true);
      try {
        if (t == null) {
          view.value = null;
          return;
        }

        view.value = _unwrap2(
          await api.dbViewList(tableId: t.id),
          serializer: (ok) => ok.list.firstOrNull,
        );
      } finally {
        loading(false);
      }
    });
  }
}

class DataRowsController extends GetxController {
  final rows = Rx<NcRowList?>(null);
  static ViewController get vc => Get.find();
  static TableController get tc => Get.find();

  final loading = false.obs;

  // TODO: Add loading.

  @override
  onInit() {
    // TODO: Listen SearchQuery.
    ever(vc.view, (v) async {
      loading(true);
      try {
        if (v == null) {
          return;
        }

        rows.value = _unwrap2(
          await api.dbViewRowList(view: v),
          serializer: (result) =>
              _populate(result, tc.table.value!, tc.relationMap.value),
        );
      } finally {
        loading(false);
      }
    });
  }
}

Future<void> _wait(
  bool Function() loading, {
  Duration duration = const Duration(milliseconds: 500),
}) async {
  do {
    logger.info('loading ... ');
    await Future.delayed(duration);
  } while (loading());
}

Future<void> _waitAll(
  List<bool Function()> fs, {
  Duration duration = const Duration(milliseconds: 500),
}) async {
  do {
    logger.info('loading ... ');
    await Future.delayed(duration);
  } while (fs.any((f) => f()));
}

void main() {
  test('Hello world', () async {
    api.init(ncEndpoint, token: ApiToken(apiToken));

    // Initialize
    final pc = ProjectController();
    final tc = TableController();
    final vc = ViewController();
    final rows = DataRowsController();
    Get
      ..put(pc)
      ..put(tc)
      ..put(vc)
      ..put(rows);

    final project = _unwrap2(
      await api.projectList(),
      // serializer: (ok) => ok.list.firstOrNull,
      serializer: (ok) => ok.list[1],
    );

    pc.project.value = project;
    await Future.delayed(Duration.zero);
    await _waitAll([
      () => tc.loading.value,
      () => vc.loading.value,
      () => rows.loading.value,
    ]);

    await _wait(() => rows.loading.value);
    logger.info('first table: ${rows.rows.value?.list}');

    final tableList = _unwrap(await api.dbTableList(projectId: project.id));
    final table = _unwrap(await api.dbTableRead(tableId: tableList.list[1].id));

    tc.table.value = table;

    await Future.delayed(Duration.zero);
    await _waitAll([
      () => tc.loading.value,
      () => vc.loading.value,
      () => rows.loading.value,
    ]);

    logger.info('second table: ${rows.rows.value?.list}');
  });
}
