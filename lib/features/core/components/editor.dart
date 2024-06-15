import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/components/editors/attachment.dart';
import 'package:nocodb/features/core/components/editors/checkbox.dart';
import 'package:nocodb/features/core/components/editors/datetime.dart';
import 'package:nocodb/features/core/components/editors/link_to_another_record.dart';
import 'package:nocodb/features/core/components/editors/link_to_another_record_bt.dart';
import 'package:nocodb/features/core/components/editors/multi_select.dart';
import 'package:nocodb/features/core/components/editors/single_select.dart';
import 'package:nocodb/features/core/components/editors/text_editor.dart';
import 'package:nocodb/features/core/pages/row_editor.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

class Editor extends HookConsumerWidget {
  const Editor({
    super.key,
    this.rowId,
    required this.column,
    required this.value,
  });
  final String? rowId;
  final model.NcTableColumn column;
  final dynamic value;

  bool get isNew => rowId == null;

  Widget _build(final WidgetRef ref) {
    final context = useContext();

    logger.info(
      'column: ${column.title}, rqd: ${column.rqd}, rowId: $rowId, value: $value',
    );

    final onUpdate = isNew
        ? (final Map<String, dynamic> data) {
            final form = ref.read(formProvider);
            final newForm = {...form, ...data};
            logger.info('form updated: $newForm');
            ref.watch(formProvider.notifier).state = newForm;
          }
        : (final data) async {
            await ref
                .read(dataRowsProvider.notifier)
                .updateRow(
                  rowId: rowId!,
                  data: data,
                )
                .then(
              (final _) {
                if (context.mounted) {
                  notifySuccess(context, message: 'Updated.');
                }
              },
            ).onError(
              (final error, final stackTrace) =>
                  notifyError(context, error, stackTrace),
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
        return AttachmentEditor(
          rowId: rowId,
          column: column,
          onUpdate: onUpdate,
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
  Widget build(final BuildContext context, final WidgetRef ref) => _build(ref);
}
