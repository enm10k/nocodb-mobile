import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class Number extends HookConsumerWidget {
  final dynamic value;

  const Number(
    this.value, {
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        value != null ? value.toString() : '',
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
