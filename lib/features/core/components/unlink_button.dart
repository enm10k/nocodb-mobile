import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

enum UnlinkButtonType {
  text,
  icon,
}

class _UnlinkButton extends HookConsumerWidget {
  const _UnlinkButton({
    required this.column,
    required this.rowId,
    required this.refRowId,
    required this.relation,
    required this.type,
  });
  final NcTableColumn column;
  final dynamic rowId;
  final String refRowId;
  final NcTable relation;
  final UnlinkButtonType type;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    onPressed() async {
      await ref
          .watch(rowNestedProvider(rowId, column, relation).notifier)
          .remove(refRowId: refRowId)
          .then((final msg) {
        notifySuccess(context, message: msg);
      }).onError(
        (final error, final stackTrace) => notifyError(
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
  const UnlinkTextButton({
    super.key,
    required this.column,
    required this.rowId,
    required this.refRowId,
    required this.relation,
  });
  final NcTableColumn column;
  final dynamic rowId;
  final String refRowId;
  final NcTable relation;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      _UnlinkButton(
        column: column,
        rowId: rowId,
        refRowId: refRowId,
        relation: relation,
        type: UnlinkButtonType.text,
      );
}

class UnlinkIconButton extends HookConsumerWidget {
  const UnlinkIconButton({
    super.key,
    required this.column,
    required this.rowId,
    required this.refRowId,
    required this.relation,
  });
  final NcTableColumn column;
  final dynamic rowId;
  final String refRowId;
  final NcTable relation;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      _UnlinkButton(
        column: column,
        rowId: rowId,
        refRowId: refRowId,
        relation: relation,
        type: UnlinkButtonType.icon,
      );
}
