import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/components/not_implementing_dialog.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;

class FieldsDialog extends HookConsumerWidget {
  const FieldsDialog({
    super.key,
  });
  static const debug = true;

  _debugViewColumns(
    List<model.NcViewColumn> vcs,
    List<model.NcTableColumn> tcs,
  ) {
    vcs.asMap().forEach((index, vc) {
      final tc = vc.toTableColumn(tcs);
      logger.info('$index ${tc?.title} ${vc.order}');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }
    final tcs = ref.watch(tableProvider)!.columns;
    final view = ref.watch(viewProvider)!;

    final viewColumns_ = ref.watch(viewColumnListProvider(view.id));
    if (!viewColumns_.hasValue) {
      return const SizedBox();
    }

    final vcs = viewColumns_.value!
        .whereNot((vc) => vc.toTableColumn(tcs)?.pv == true)
        .toList();

    // TODO: Move to provider
    final filteredViewColumns = vcs.where((vc) {
      final tc = vc.toTableColumn(tcs);

      return view.showSystemFields ? true : !(tc?.isSystem == true);
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final List<Widget> children = filteredViewColumns.map(
      (vc) {
        final tc = vc.toTableColumn(tcs);
        return CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          key: Key(vc.id),
          title: Text(tc?.title ?? '-'),
          value: vc.show,
          onChanged: (value) async {
            // TODO: The following logic should be integrated to provider.
            await api
                .dbViewColumnUpdateShow(
                  column: vc,
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
                  final newViewColumns = [...vcs];

                  if (debug) {
                    _debugViewColumns(vcs, tcs);
                  }
                  final movingColumn = newViewColumns.removeAt(oldIndex);
                  newViewColumns.insert(newIndex, movingColumn);

                  if (debug) {
                    logger.info(
                      'moving ${movingColumn.toTableColumn(tcs)?.title} from $oldIndex to $newIndex',
                    );
                    _debugViewColumns(newViewColumns, tcs);
                  }

                  // TODO: The following logic should be integrated to provider.
                  newViewColumns.asMap().forEach((index, vc) async {
                    final newOrder = index + 1;
                    logger.info(
                      '${vc.toTableColumn(tcs)?.title} from ${vc.order} to $newOrder',

                    );
                    if (vc.order != newOrder) {
                      logger.info(
                        'Update ${vc.toTableColumn(tcs)?.title} from ${vc.order} to $newOrder',
                      );
                      await api.dbViewColumnUpdateOrder(
                        column: vc,
                        order: newOrder,
                      );
                    }
                  });
                  // ref.invalidate(viewColumnListProvider(view.id));
                  final updated = ref.refresh(viewColumnListProvider(view.id));

                  if (debug) {
                    updated.whenData(
                      (value) => _debugViewColumns(value, tcs),
                    );
                  }
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
              ref.read(viewProvider.notifier).showSystemFields();
            },
            child: Row(
              children: [
                Checkbox(
                  value: view.showSystemFields,
                  onChanged: (value) {
                    ref.read(viewProvider.notifier).showSystemFields();
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
                    builder: (_) => const NotImplementedDialog(),
                  );
                },
                child: const Text('Show all'),
              ),
              TextButton(
                onPressed: () async {
                  await showDialog(
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
