import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/symbols.dart';
import '/nocodb_sdk/models.dart' as model;

class CheckboxEditor extends HookConsumerWidget {
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
  final bool initialValue;
  const CheckboxEditor({
    super.key,
    required this.column,
    required this.onUpdate,
    required this.initialValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = useState<bool>(initialValue);
    return Checkbox(
      value: checked.value,
      onChanged: (value) {
        onUpdate({
          column.title: value != true,
        });
        checked.value = !checked.value;
      },
    );
  }
}
