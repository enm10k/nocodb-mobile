import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/models.dart';

class MultiSelect extends HookConsumerWidget {
  final List<String> values;
  final NcTableColumn column;

  const MultiSelect(
    this.values, {
    super.key,
    required this.column,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = values.map((value) {
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
