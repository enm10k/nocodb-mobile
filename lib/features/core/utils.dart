import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

// Currently, this provider is used to notify the RowEditor when a new row is created in the AttachmentEditorPage.
// In the future, it might be used on other screens as well.
final newIdProvider = StateProvider<String?>(
  (final ref) => null,
);

final formProvider = StateProvider<Map<String, dynamic>>(
  (final ref) => throw UnimplementedError(),
);

Future<void> upsert(
  final BuildContext context,
  final WidgetRef ref,
  final String? rowId,
  final NcRow row, {
  final bool updateForm = true,
  final void Function(NcRow)? onCreate,
  final void Function(NcRow)? onUpdate,
  final void Function(Object?, StackTrace)? onError,
}) async {
  if (rowId != null) {
    final dataRowsNotifier = ref.read(dataRowsProvider.notifier);
    await dataRowsNotifier
        .updateRow(rowId: rowId, data: row)
        .then(
          (final row) => onUpdate != null
              ? onUpdate.call(row)
              : notifySuccess(context, message: 'Updated'),
        )
        .onError(
          (final e, final s) =>
              onError != null ? onError(e, s) : notifyError(context, e, s),
        );
    return;
  }
  if (updateForm) {
    final form = ref.read(formProvider);
    final newForm = {...form, ...row};
    logger.info('form updated: $newForm');
    ref.read(formProvider.notifier).state = newForm;
  } else {
    await ref
        .read(dataRowsProvider.notifier)
        .createRow(row)
        .then(
          (final row) => onCreate != null
              ? onCreate.call(row)
              : notifySuccess(context, message: 'Saved.'),
        )
        .onError(
          (final e, final s) =>
              onError != null ? onError(e, s) : notifyError(context, e, s),
        );
  }
}
