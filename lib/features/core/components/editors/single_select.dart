import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';

class SingleSelectEditor extends HookConsumerWidget {
  const SingleSelectEditor({
    super.key,
    required this.column,
    this.onUpdate,
    required this.initialValue,
  });
  final model.NcTableColumn column;
  final FnOnUpdate? onUpdate;
  final String? initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = column.colOptions?.options;
    assert(options != null);
    if (options == null) {
      return Container();
    }
    final value = useState<String?>(initialValue);

    final children = options.map(
      (option) {
        final color = column.colOptions?.getOptionColor(option.title);

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 0,
          ),
          child: FilterChip(
            label: Text(option.title),
            selected: value.value == option.title,
            onSelected: (selected) {
              if (selected == true) {
                value.value = option.title;
                onUpdate?.call({
                  column.title: value.value,
                });
              } else {
                if (value.value == option.title) {
                  value.value = null;
                  onUpdate?.call({
                    column.title: null,
                  });
                }
              }
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
