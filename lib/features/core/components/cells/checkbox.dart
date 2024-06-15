import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CheckBox extends HookConsumerWidget {
  const CheckBox(
    this.value, {
    super.key,
  });
  final bool value;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => Checkbox(
        value: value == true,
        onChanged: null,
      );
}
