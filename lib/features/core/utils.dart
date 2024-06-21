import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

// Currently, this provider is used to notify the RowEditor when a new row is created in the AttachmentEditorPage.
// In the future, it might be used on other screens as well.
final newIdProvider = StateProvider<String?>(
  (ref) => null,
);

final formProvider = StateProvider<Map<String, dynamic>>(
  (ref) => throw UnimplementedError(),
);

Future<void> upsert(
  BuildContext context,
  WidgetRef ref,
  String? rowId,
  NcRow row, {
  // In an independent page other than RowEditor, you need to set `updateForm` to false.
  bool updateForm = true,
  void Function(NcRow)? onCreateCallback,
  void Function(NcRow)? onUpdateCallback,
  void Function(Object?, StackTrace)? onErrorCallback,
}) async {
  onError(e, s) => onErrorCallback != null
      ? onErrorCallback(e, s)
      : notifyError(context, e, s);

  // Update the data if the rowId is not null.
  if (rowId != null) {
    final dataRowsNotifier = ref.read(dataRowsProvider.notifier);
    await dataRowsNotifier
        .updateRow(rowId: rowId, data: row)
        .then(
          (row) => onUpdateCallback != null
              ? onUpdateCallback.call(row)
              : notifySuccess(context, message: 'Updated'),
        )
        .onError(onError);
    return;
  }

  // update form
  if (updateForm) {
    final form = ref.read(formProvider);
    final newForm = {...form, ...row};
    logger.info('form updated: $newForm');
    ref.read(formProvider.notifier).state = newForm;
    return;
  }

  // create
  await ref
      .read(dataRowsProvider.notifier)
      .createRow(row)
      .then(
        (row) => onCreateCallback != null
            ? onCreateCallback.call(row)
            : notifySuccess(context, message: 'Saved.'),
      )
      .onError(onError);
}
