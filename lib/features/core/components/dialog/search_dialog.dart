import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';

class _SearchDialog extends HookConsumerWidget {
  const _SearchDialog({
    required this.children,
    required this.onSearch,
    required this.onReset,
    required this.initialValue,
  });
  final List<Widget> children;
  final void Function(String query) onSearch;
  final void Function() onReset;
  final String initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = useState(false);
    final controller = useTextEditingController();

    useEffect(
      () {
        controller.text = initialValue;
        return null;
      },
      [],
    );
    return AlertDialog(
      title: const Text(
        'Search',
        overflow: TextOverflow.ellipsis,
      ),
      content: IntrinsicHeight(
        child: Column(
          children: [
            ...children,
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Keyword',
              ),
              onChanged: (value) {
                isActive.value = value.isNotEmpty;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            onReset();
            controller.clear();
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () {
            onSearch(controller.text);
          },
          child: const Text('Search'),
        ),
      ],
    );
  }
}

class SheetSearchDialog extends HookConsumerWidget {
  const SheetSearchDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }
    final table = ref.watch(tableProvider)!;
    final view = ref.watch(viewProvider)!;

    final columns = table.columns;
    final items = columns
        .map(
          (column) => DropdownMenuItem(
            value: column.title,
            child: Text(column.title),
          ),
        )
        .toList();

    final searchQueryProvider = searchQueryFamily(view);
    final query = ref.watch(searchQueryProvider);

    final operator = useState(QueryOperator.eq);
    final columnName = useState<String?>(null);

    useEffect(
      () {
        operator.value = query?.operator ?? QueryOperator.eq;
        columnName.value = query?.columnName ?? columns.first.title;
        return null;
      },
      [query],
    );

    final children = [
      DropdownButtonFormField(
        decoration: const InputDecoration(
          labelText: 'Field',
        ),
        items: items,
        onChanged: (newColumn) {
          columnName.value = newColumn!;
        },
        value: columnName.value,
      ),
      Row(
        children: [
          const Expanded(
            child: Text('Operator'),
          ),
          DropdownButton<QueryOperator>(
            items: QueryOperator.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(mode.toDisplayString()),
                  ),
                )
                .toList(),
            value: operator.value,
            onChanged: (newColumn) => operator.value = newColumn!,
          ),
        ],
      ),
    ];

    return _SearchDialog(
      initialValue: query?.query ?? '',
      onSearch: (String query) {
        ref.watch(searchQueryProvider.notifier).state = query.isEmpty
            ? null
            : SearchQuery(
                columnName: columnName.value!,
                query: query,
                operator: operator.value,
              );
        Navigator.pop(context);
      },
      onReset: () {
        ref.watch(searchQueryProvider.notifier).state = null;
      },
      children: children,
    );
  }
}

class LinkRecordSearchDialog extends HookConsumerWidget {
  const LinkRecordSearchDialog({
    super.key,
    required this.column,
    required this.pvName,
  });
  final model.NcTableColumn column;
  final String pvName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }
    final query = ref.read(rowNestedWhereProvider(column));
    final operator = useState(QueryOperator.eq);

    useEffect(
      () {
        operator.value = query?.$2 ?? QueryOperator.eq;
        return null;
      },
      [query],
    );

    final children = [
      Row(
        children: [
          Expanded(
            child: Text(pvName),
          ),
          DropdownButton<QueryOperator>(
            items: QueryOperator.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(mode.toDisplayString()),
                  ),
                )
                .toList(),
            value: operator.value,
            onChanged: (newColumn) => operator.value = newColumn!,
          ),
        ],
      ),
    ];
    onReset() {
      ref.read(rowNestedWhereProvider(column).notifier).state = null;
    }

    onSearch(String query) {
      ref.read(rowNestedWhereProvider(column).notifier).state =
          query.isEmpty ? null : (pvName, operator.value, query);
      Navigator.pop(context);
    }

    return _SearchDialog(
      initialValue: query?.$3 ?? '',
      onSearch: onSearch,
      onReset: onReset,
      children: children,
    );
  }
}
