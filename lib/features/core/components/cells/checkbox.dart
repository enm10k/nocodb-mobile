import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CheckBox extends HookConsumerWidget {
  final bool value;

  const CheckBox(
    this.value, {
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Checkbox(
      value: value == true,
      onChanged: null,
    );
  }
}
