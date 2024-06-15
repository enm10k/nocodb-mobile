import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class Number extends HookConsumerWidget {
  const Number(
    this.value, {
    super.key,
  });
  final dynamic value;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => SizedBox(
        width: double.infinity,
        child: Text(
          value != null ? value.toString() : '',
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
