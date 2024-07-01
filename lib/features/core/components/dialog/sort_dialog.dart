import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/providers/sort_list_provider.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

Future<void> refresh({
  required Future<void> future,
  required WidgetRef ref,
  required BuildContext context,
  required NcView view,
}) async {
  await future.then((_) {
    ref.invalidate(dataRowsProvider);
    notifySuccess(context, message: 'Updated.');
  }).onError(
    (error, stackTrace) => notifyError(context, error, stackTrace),
  );
}

class SortOptionItem extends HookConsumerWidget {
  const SortOptionItem({
    super.key,
    required this.view,
    required this.onRemoved,
    this.sort,
    required this.tableColumns,
  });
  static const debug = true;
  final NcView view;
  final NcSort? sort;
  final Function(Key) onRemoved;
  final List<NcTableColumn> tableColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(key != null, 'key must be specified for $runtimeType');

    final isNew = sort == null;
    final direction = useState<SortDirectionTypes>(
      isNew ? SortDirectionTypes.asc : sort!.direction,
    );
    final fkColumnId = useState<String?>(isNew ? null : sort!.fkColumnId);

    final columnItems = tableColumns
        .where(
          (tableColumn) => !(tableColumn.isManyToMany || tableColumn.isHasMay),
        )
        .map(
          (tableColumn) => DropdownMenuItem(
            value: tableColumn.id,
            child: Text(
              tableColumn.title,
            ),
          ),
        )
        .toList();

    if (sort == null) {
      columnItems.insert(
        0,
        const DropdownMenuItem(
          child: Text(
            'Select field',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              onRemoved(key!);
            },
          ),
        ),
        Expanded(
          flex: 4,
          child: DropdownButton(
            value: fkColumnId.value,
            isExpanded: true,
            items: columnItems,
            onChanged: (newFkColumnId) async {
              if (newFkColumnId == null) {
                return;
              }
              final notifier = ref.watch(sortListProvider(view.id).notifier);

              if (isNew) {
                final future = notifier.create(
                  fkColumnId: newFkColumnId,
                  direction: direction.value,
                );
                await refresh(
                  future: future,
                  ref: ref,
                  context: context,
                  view: view,
                );
              } else {
                final future = notifier.save(
                  sortId: sort!.id,
                  fkColumnId: newFkColumnId,
                  direction: direction.value,
                );
                await refresh(
                  future: future,
                  ref: ref,
                  context: context,
                  view: view,
                );
              }
            },
          ),
        ),
        Expanded(
          flex: 2,
          child: DropdownButton(
            isExpanded: true,
            value: direction.value,
            items: const [
              DropdownMenuItem(
                value: SortDirectionTypes.asc,
                child: Text(
                  // TODO: This text should be different between uidt(s).
                  // https://github.com/nocodb/nocodb/blob/515a8f1701d7053bfc32f6277c9047715b097edf/packages/nc-gui/utils/sortUtils.ts#L3
                  'ASC',
                ),
              ),
              DropdownMenuItem(
                value: SortDirectionTypes.desc,
                child: Text('DESC'),
              ),
            ],
            onChanged: (newDirection) async {
              final newFkColumnId = fkColumnId.value;
              if (newDirection == null || newFkColumnId == null) {
                return;
              }

              direction.value = newDirection;
              final future = ref.watch(sortListProvider(view.id).notifier).save(
                    sortId: sort!.id,
                    fkColumnId: newFkColumnId,
                    direction: direction.value,
                  );
              await refresh(
                future: future,
                ref: ref,
                context: context,
                view: view,
              );
            },
          ),
        ),
      ],
    );
  }
}

class SortDialogContent extends HookConsumerWidget {
  const SortDialogContent({
    super.key,
    required this.view,
    required this.table,
  });
  static const debug = true;
  final NcView view;
  final NcTable table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortList = ref.watch(sortListProvider(view.id));
    if (sortList.hasError) {
      logger
        ..info(sortList.error)
        ..info(sortList.stackTrace);
    }

    final tableColumns = table.columns;

    if (sortList.valueOrNull == null) {
      return Container();
    }

    final sorts = sortList.value!.list;
    final children = useState<List<Widget>>([]);
    useEffect(
      () {
        children.value = sorts
            .map(
              (sort) => SortOptionItem(
                key: UniqueKey(),
                view: view,
                tableColumns: tableColumns,
                sort: sort,
                onRemoved: (key) async {
                  final future = ref
                      .watch(sortListProvider(view.id).notifier)
                      .delete(sort.id);
                  await refresh(
                    future: future,
                    ref: ref,
                    context: context,
                    view: view,
                  );
                },
              ),
            )
            .toList()
          ..sort(
            (a, b) => (a.sort?.order ?? 0.0).compareTo(b.sort?.order ?? 0.0),
          );
        return null;
      },
      [sorts],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...children.value, // TODO: Use ReorderableListView?
        const Divider(),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () {
                children.value = [
                  ...children.value,
                  SortOptionItem(
                    key: UniqueKey(),
                    view: view,
                    tableColumns: tableColumns,
                    onRemoved: (key) {
                      children.value = [...children.value]
                        ..removeWhere((element) => element.key == key);
                    },
                  ),
                ];
              },
              child: const Text('Add Sort Option'),
            ),
          ],
        ),
      ],
    );
  }
}

class SortDialog extends HookConsumerWidget {
  const SortDialog({
    super.key,
    required this.view,
    required this.table,
  });
  final NcView view;
  final NcTable table;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
        title: const Text('Sort'),
        content: SortDialogContent(view: view, table: table),
      );
}
