import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/models.dart';
import '../../providers/providers.dart';

class LinkToAnotherRecord extends HookConsumerWidget {
  final dynamic value;
  final NcTableColumn column;

  const LinkToAnotherRecord(
    this.value, {
    super.key,
    required this.column,
  });

  static const offset = 25;

  String getPrimaryValues(NcTable table, dynamic value) {
    return (value is List)
        ? value.map((row) => table.getPvFromRow(row)).join(', ')
        : table.getPvFromRow(value).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    if (value == null || tables == null) {
      return const SizedBox();
    }
    final relation = tables.relationMap[column.fkRelatedModelId];
    if (relation == null) {
      return const SizedBox();
    }
    if (column.isBelongsTo) {
      return Text(getPrimaryValues(relation, value));
    }

    return InkWell(
      child: Text(
        getPrimaryValues(relation, value),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
