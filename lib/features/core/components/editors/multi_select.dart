import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';

class MultiSelectEditor extends HookConsumerWidget {
  const MultiSelectEditor({
    super.key,
    required this.column,
    this.onUpdate,
    required this.initialValue,
  });
  final model.NcTableColumn column;
  final FnOnUpdate? onUpdate;
  final List<String> initialValue;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final options = column.colOptions?.options;
    assert(options != null);
    if (options == null) {
      return Container();
    }
    final titles = options.map((final option) => option.title);

    final values = useState<List<String>>(
      initialValue.where(titles.contains).toList(),
    );
    final children = options.map(
      (final option) {
        final color = column.colOptions?.getOptionColor(option.title);

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 0,
          ),
          child: FilterChip(
            label: Text(option.title),
            selected: values.value.contains(option.title),
            onSelected: (final selected) {
              if (selected == true) {
                // add
                values.value = [...values.value, option.title];
              } else {
                // delete
                values.value = values.value
                    .where((final element) => element != option.title)
                    .toList();
              }

              final options = values.value
                  .where((final element) => element != 'null')
                  .toList()
                ..sort();
              onUpdate?.call({
                column.title: options.join(','),
              });
            },
            selectedColor: color,
            disabledColor: Colors.grey,
          ),
        );
      },
    ).toList();

    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        children: children,
      ),
    );
  }
}
