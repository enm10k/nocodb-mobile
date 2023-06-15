import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/models.dart';
import '../unlink_button.dart';

class LinkToAnotherRecordBt extends HookConsumerWidget {
  final NcTableColumn column;
  final dynamic rowId;
  final NcTable relation;
  final dynamic initialValue;
  const LinkToAnotherRecordBt({
    super.key,
    required this.column,
    required this.rowId,
    required this.relation,
    required this.initialValue,
  });

  String? get pvName => relation.pvName;
  String? get pkName => relation.pkName;
  String get pk => initialValue[pkName].toString();
  String get pv => initialValue[pvName].toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(column.isBelongsTo);

    final child = initialValue == null
        ? const ListTile(title: Text('No record linked yet.'))
        : ListTile(
            title: Text(pv),
            subtitle: Text(pk),
            trailing: UnlinkIconButton(
              column: column,
              rowId: rowId,
              refRowId: pk,
              relation: relation,
            ),
          );
    return Card(
      child: child,
    );
  }
}
