import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/features/core/providers/providers.dart';
import '/nocodb_sdk/client.dart';
import '/nocodb_sdk/models.dart' as model;
import '../../../../common/components/not_implementing_dialog.dart';
import '../../../../common/flash_wrapper.dart';
import '../../../../common/logger.dart';

model.NcTableColumn getTableColumn(
  model.NcViewColumn viewColumn,
  List<model.NcTableColumn> tableColumns,
) {
  return tableColumns
          .where((tableColumn) => tableColumn.id == viewColumn.fkColumnId)
          .firstOrNull ??
      tableColumns.first;
}

class FieldsDialog extends HookConsumerWidget {
  static const debug = true;
  const FieldsDialog({
    super.key,
  });

  _debugViewColumns(
    List<model.NcViewColumn> viewColumns,
    List<model.NcTableColumn> tableColumns,
  ) {
    viewColumns.asMap().forEach((index, column) {
      final tableColumn = getTableColumn(column, tableColumns);
      logger.info('$index ${tableColumn.title}');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final filteredViewColumns = viewColumns.where((viewColumn) {
      final tableColumn = getTableColumn(viewColumn, table.columns);

      return view.showSystemFields ? true : !tableColumn.isSystem;
    }).toList();

    filteredViewColumns.sort((a, b) => a.order.compareTo(b.order));

    final List<Widget> children = filteredViewColumns.map(
      (viewColumn) {
        final column = getTableColumn(viewColumn, table.columns);
        return CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          key: Key(viewColumn.id),
          title: Text(column.title),
          value: viewColumn.show,
          onChanged: (value) {
            if (column.pv) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
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
            api
                .dbViewColumnUpdateShow(
                  column: viewColumn,
                  show: value == true,
                )
                .then(
                  (_) => ref.invalidate(viewColumnListProvider),
                )
                .onError(
                  (error, stackTrace) => notifyError(
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
                onReorder: (oldIndex, newIndex) {
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
                  newViewColumns.asMap().forEach((index, viewColumn) {
                    final newOrder = index + 1;
                    if (viewColumn.order != newOrder) {
                      api.dbViewColumnUpdateOrder(
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
                  onChanged: (value) {
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
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const NotImplementedDialog(),
                  );
                },
                child: const Text('Show all'),
              ),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const NotImplementedDialog(),
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
