import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/components/not_implementing_dialog.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;

model.NcTableColumn getTableColumn(
  final model.NcViewColumn viewColumn,
  final List<model.NcTableColumn> tableColumns,
) =>
    tableColumns
        .where((final tableColumn) => tableColumn.id == viewColumn.fkColumnId)
        .firstOrNull ??
    tableColumns.first;

class FieldsDialog extends HookConsumerWidget {
  const FieldsDialog({
    super.key,
  });
  static const debug = true;

  _debugViewColumns(
    final List<model.NcViewColumn> viewColumns,
    final List<model.NcTableColumn> tableColumns,
  ) {
    viewColumns.asMap().forEach((final index, final column) {
      final tableColumn = getTableColumn(column, tableColumns);
      logger.info('$index ${tableColumn.title}');
    });
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }
    final table = ref.watch(tableProvider)!;
    final view = ref.watch(viewProvider)!;

    final viewColumns_ = ref.watch(viewColumnListProvider(view.id));
    if (!viewColumns_.hasValue) {
      return const SizedBox();
    }

    final viewColumns = viewColumns_.value!;

    // TODO: Move to provider
    final filteredViewColumns = viewColumns.where((final viewColumn) {
      final tableColumn = getTableColumn(viewColumn, table.columns);

      return view.showSystemFields ? true : !tableColumn.isSystem;
    }).toList()
      ..sort((final a, final b) => a.order.compareTo(b.order));

    final List<Widget> children = filteredViewColumns.map(
      (final viewColumn) {
        final column = getTableColumn(viewColumn, table.columns);
        return CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          key: Key(viewColumn.id),
          title: Text(column.title),
          value: viewColumn.show,
          onChanged: (final value) async {
            if (column.pv) {
              await showDialog(
                context: context,
                builder: (final _) => AlertDialog(
                  title: Text('${column.title} is display value'),
                  content: const Text('You cannot hide display value.'),
                  actions: [
                    TextButton(
                      child: const Text('OK'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            }
            // TODO: The following logic should be integrated to provider.
            await api
                .dbViewColumnUpdateShow(
                  column: viewColumn,
                  show: value == true,
                )
                .then(
                  (final _) => ref.invalidate(viewColumnListProvider),
                )
                .onError(
                  (final error, final stackTrace) => notifyError(
                    context,
                    error,
                    stackTrace,
                  ),
                );
          },
        );
      },
    ).toList();

    logger.info('show_system_fields: ${view.showSystemFields}');

    return AlertDialog(
      title: const Text('Fields'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SizedBox(
              width: double.maxFinite,
              child: ReorderableListView(
                shrinkWrap: true,
                onReorder: (final oldIndex, final newIndex) {
                  // TODO: Fix. Current behavior is slightly different from nc-gui.
                  // https://github.com/nocodb/nocodb/blob/fbe406c51176709d1f8779d8d95405f52a869079/packages/nc-gui/components/smartsheet/toolbar/FieldsMenu.vue#L71-L85
                  final newViewColumns = [...viewColumns];

                  if (debug) {
                    _debugViewColumns(viewColumns, table.columns);
                  }
                  final movingColumn = newViewColumns.removeAt(oldIndex);
                  newViewColumns.insert(newIndex, movingColumn);

                  if (debug) {
                    logger.info(
                      'moving ${getTableColumn(movingColumn, table.columns).title}',
                    );
                    _debugViewColumns(viewColumns, table.columns);
                  }

                  // TODO: The following logic should be integrated to provider.
                  newViewColumns
                      .asMap()
                      .forEach((final index, final viewColumn) async {
                    final newOrder = index + 1;
                    if (viewColumn.order != newOrder) {
                      await api.dbViewColumnUpdateOrder(
                        column: viewColumn,
                        order: newOrder,
                      );
                    }
                  });
                  ref.invalidate(viewColumnListProvider);
                },
                children: children,
              ),
            ),
          ),
          const Divider(
            thickness: 2,
          ),
          InkWell(
            onTap: () {
              ref
                  .watch(viewProvider.notifier)
                  .showSystemFields(view.showSystemFields);
            },
            child: Row(
              children: [
                Checkbox(
                  value: view.showSystemFields,
                  onChanged: (final value) {
                    ref.watch(viewProvider.notifier).showSystemFields(value!);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text(
                  'Show system fields',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (final _) => const NotImplementedDialog(),
                  );
                },
                child: const Text('Show all'),
              ),
              TextButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (final _) => const NotImplementedDialog(),
                  );
                },
                child: const Text('Hide all'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
