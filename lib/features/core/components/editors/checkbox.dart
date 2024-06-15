import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';

class CheckboxEditor extends HookConsumerWidget {
  const CheckboxEditor({
    super.key,
    required this.column,
    required this.onUpdate,
    required this.initialValue,
  });
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
  final bool initialValue;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final checked = useState<bool>(initialValue);
    return Checkbox(
      value: checked.value,
      onChanged: (final value) {
        onUpdate({
          column.title: value != true,
        });
        checked.value = !checked.value;
      },
    );
  }
}
