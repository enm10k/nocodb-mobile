import 'package:collection/collection.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/providers/utils.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fields_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<NcViewColumn>> viewColumnList(
  ViewColumnListRef ref,
  String viewId,
) async =>
    unwrap(await api.dbViewColumnList(viewId: viewId));

@Riverpod()
class _FieldsBase extends _$FieldsBase {
  @override
  Future<List<NcViewColumn>> build() async {
    final view = ref.watch(viewProvider)!;
    return (await ref.watch(viewColumnListProvider(view.id).future))
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}

@Riverpod()
class Fields extends _$Fields {
  @override
  Future<List<NcViewColumn>> build() async {
    final table = ref.watch(tableProvider)!;
    final view = ref.watch(viewProvider)!;
    return (await ref.watch(_fieldsBaseProvider.future))
        .filter(table, view, excludePv: true, ignoreShow: true)
        .toList();
  }

  Future<void> show(NcViewColumn vc, bool b) async {
    await api.dbViewColumnUpdateShow(
      column: vc,
      show: b,
    );
    ref.invalidate(_fieldsBaseProvider);
  }

  _debugViewColumns(
    List<NcViewColumn> vcs,
    List<NcTableColumn> tcs,
  ) {
    vcs.asMap().forEach((index, vc) {
      final tc = vc.toTableColumn(tcs)!;
      logger.info('$index ${tc.title} ${vc.order}');
    });
  }

  static const debug = true;
  // TODO: Fix. Current behavior is slightly different from nc-gui.
  // https://github.com/nocodb/nocodb/blob/fbe406c51176709d1f8779d8d95405f52a869079/packages/nc-gui/components/smartsheet/toolbar/FieldsMenu.vue#L71-L85
  Future<void> reorder(int oldIndex, int newIndex) async {
    final table = ref.watch(tableProvider)!;
    // TODO: Fix. Current behavior is slightly different from nc-gui.
    // https://github.com/nocodb/nocodb/blob/fbe406c51176709d1f8779d8d95405f52a869079/packages/nc-gui/components/smartsheet/toolbar/FieldsMenu.vue#L71-L85
    final vcs = [...state.value!];

    if (debug) {
      _debugViewColumns(vcs, table.columns);
    }
    final vc = vcs.removeAt(oldIndex);
    vcs.insert(newIndex, vc);

    if (debug) {
      logger.info(
        // 'moving ${getTableColumn(vc, table.columns).title}',
        'moving ${vc.toTableColumn(table.columns)?.title} from $oldIndex to $newIndex',
      );
      _debugViewColumns(vcs, table.columns);
    }

    // TODO: The following logic should be integrated to provider.
    vcs.asMap().forEach((index, viewColumn) async {
      final newOrder = index + 1;
      if (viewColumn.order != newOrder) {
        await api.dbViewColumnUpdateOrder(
          column: viewColumn,
          order: newOrder,
        );
      }
    });
    ref.invalidate(viewColumnListProvider);
  }
}

@Riverpod()
class GridFields extends _$GridFields {
  @override
  Future<List<NcTableColumn>> build() async {
    final table = ref.watch(tableProvider)!;
    final view = ref.watch(viewProvider)!;
    return (await ref.watch(_fieldsBaseProvider.future))
        .filter(table, view)
        .map((v) => v.toTableColumn(table.columns))
        .whereNotNull()
        .toList();
  }
}
