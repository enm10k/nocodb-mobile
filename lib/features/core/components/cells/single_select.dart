import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class SingleSelect extends HookConsumerWidget {
  const SingleSelect(
    this.value, {
    super.key,
    required this.column,
  });
  final String? value;
  final NcTableColumn column;

  Widget _buildChip(String? label) {
    if (label == null) {
      return Container();
    }

    final color = column.colOptions?.getOptionColor(label);
    return Chip(
      label: Text(label),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildChip(value)],
      );
}
