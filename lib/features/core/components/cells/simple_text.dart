import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SimpleText extends HookConsumerWidget {
  const SimpleText(
    this.value, {
    super.key,
  });
  final dynamic value;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => Text(
        value != null ? value.toString() : '',
        overflow: TextOverflow.ellipsis,
      );
}
