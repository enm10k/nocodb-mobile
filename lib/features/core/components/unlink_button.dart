import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../common/flash_wrapper.dart';
import '../../../nocodb_sdk/models.dart';
import '../providers/providers.dart';

enum UnlinkButtonType {
  text,
  icon,
}

class _UnlinkButton extends HookConsumerWidget {
  final NcTableColumn column;
  final dynamic rowId;
  final String refRowId;
  final NcTable relation;
  final UnlinkButtonType type;
  const _UnlinkButton({
    required this.column,
    required this.rowId,
    required this.refRowId,
    required this.relation,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onPressed() {
      ref
          .watch(rowNestedProvider(rowId, column, relation).notifier)
          .remove(refRowId: refRowId)
          .then((msg) {
        notifySuccess(context, message: msg);
      }).onError(
        (error, stackTrace) => notifyError(
          context,
          error,
          stackTrace,
        ),
      );
    }

    return type == UnlinkButtonType.icon
        ? IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: onPressed,
          )
        : TextButton(
            onPressed: onPressed,
            child: const Text('Unlink'),
          );
  }
}

class UnlinkTextButton extends HookConsumerWidget {
  final NcTableColumn column;
  final dynamic rowId;
  final String refRowId;
  final NcTable relation;
  const UnlinkTextButton({
    super.key,
    required this.column,
    required this.rowId,
    required this.refRowId,
    required this.relation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _UnlinkButton(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
      relation: relation,
      type: UnlinkButtonType.text,
    );
  }
}

class UnlinkIconButton extends HookConsumerWidget {
  final NcTableColumn column;
  final dynamic rowId;
  final String refRowId;
  final NcTable relation;
  const UnlinkIconButton({
    super.key,
    required this.column,
    required this.rowId,
    required this.refRowId,
    required this.relation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _UnlinkButton(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
      relation: relation,
      type: UnlinkButtonType.icon,
    );
  }
}
