import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SimpleText extends HookConsumerWidget {
  final dynamic value;

  const SimpleText(
    this.value, {
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      value != null ? value.toString() : '',
      overflow: TextOverflow.ellipsis,
    );
  }
}
