import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../nocodb_sdk/models.dart';
import '/nocodb_sdk/models.dart' as model;
import '../../../common/flash_wrapper.dart';
import '../../../common/logger.dart';
import '../../../nocodb_sdk/symbols.dart';
import '../pages/row_editor.dart';
import '../providers/providers.dart';
import 'editors/attachment.dart';
import 'editors/checkbox.dart';
import 'editors/datetime.dart';
import 'editors/link_to_another_record.dart';
import 'editors/link_to_another_record_bt.dart';
import 'editors/multi_select.dart';
import 'editors/single_select.dart';
import 'editors/text_editor.dart';

class Editor extends HookConsumerWidget {
  final String? rowId;
  final model.NcTableColumn column;
  final dynamic value;

  const Editor({
    super.key,
    this.rowId,
    required this.column,
    required this.value,
  });

  bool get isNew => rowId == null;

  Widget _build(WidgetRef ref) {
    final context = useContext();
    final view = ref.watch(viewProvider)!;
    final isMounted = useIsMounted();

    logger.info(
      'column: ${column.title}, rqd: ${column.rqd}, rowId: $rowId, value: $value',
    );

    final onUpdate = isNew
        ? (Map<String, dynamic> data) {
            final form = ref.watch(formProvider);
            final newForm = {...form, ...data};
            logger.info('form updated: $newForm');
            ref.watch(formProvider.notifier).state = newForm;
          }
        : (data) {
            ref
                .read(dataRowsProvider(view).notifier)
                .updateRow(
                  rowId: rowId!,
                  data: data,
                )
                .then(
              (_) {
                if (isMounted()) {
                  notifySuccess(context, message: 'Updated.');
                }
              },
            ).onError(
              (error, stackTrace) => notifyError(context, error, stackTrace),
            );
          };

    switch (column.uidt) {
      case UITypes.checkbox:
        return CheckboxEditor(
          column: column,
          initialValue: value == true,
          onUpdate: onUpdate,
        );
      case UITypes.singleSelect:
        return SingleSelectEditor(
          column: column,
          initialValue: value,
          onUpdate: onUpdate,
        );
      case UITypes.multiSelect:
        final List<String> initialValue =
            value is String ? (value as String).split(',') : [];
        return MultiSelectEditor(
          column: column,
          initialValue: initialValue..sort(),
          onUpdate: onUpdate,
        );
      case UITypes.number:
        return TextEditor(
          column: column,
          onUpdate: onUpdate,
          initialValue: value,
          isNew: isNew,
          maxLines: null,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        );
      case UITypes.decimal:
        return TextEditor(
          column: column,
          onUpdate: onUpdate,
          initialValue: value,
          isNew: isNew,
          maxLines: null,
          keyboardType: TextInputType.number,
          inputFormatters: [
            // TODO: Implement validators
            FilteringTextInputFormatter.allow(RegExp(r'[\-0-9.]')),
          ],
        );
      case UITypes.longText:
        return TextEditor(
          column: column,
          onUpdate: onUpdate,
          initialValue: value,
          isNew: isNew,
          maxLines: null,
          keyboardType: TextInputType.multiline,
        );
      case UITypes.linkToAnotherRecord:
        final tables = ref.watch(tablesProvider);
        final relation = tables?.relationMap[column.fkRelatedModelId];
        if (relation == null) {
          return const SizedBox();
        }

        return column.isBelongsTo
            ? LinkToAnotherRecordBt(
                column: column,
                rowId: rowId,
                relation: relation,
                initialValue: value,
              )
            : LinkToAnotherRecord(
                column: column,
                relation: relation,
                rowId: rowId,
                initialValue: value,
              );
      case UITypes.dateTime:
      case UITypes.date:
      case UITypes.time:
        return DateTimeEditor(
          column: column,
          onUpdate: onUpdate,
          initialValue: value,
          type: DateTimeType.fromUITypes(column.uidt),
        );
      case UITypes.attachment:
        final attachedFiles = value.map<NcAttachedFile>((e) => NcAttachedFile.fromJson(e as Map<String, dynamic>)).toList();

        return AttachmentEditor(
          column: column,
          onUpdate: onUpdate,
          initialValue: attachedFiles,
        );
      default:
        return TextEditor(
          column: column,
          onUpdate: onUpdate,
          initialValue: value,
          isNew: isNew,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _build(ref);
  }
}
