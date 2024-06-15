import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:nocodb/nocodb_sdk/models.dart';

class MultiSelect extends HookConsumerWidget {
  const MultiSelect(
    this.values, {
    super.key,
    required this.column,
  });
  final List<String> values;
  final NcTableColumn column;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final children = values.map((final value) {
      // TODO: Improve performance
      final color = column.colOptions?.getOptionColor(value);
      return Chip(
        label: Text(value),
        backgroundColor: color,
      );
    }).toList();

    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
