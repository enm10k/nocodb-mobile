import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/components/editors/attachment.dart';
import 'package:nocodb/features/core/components/editors/checkbox.dart';
import 'package:nocodb/features/core/components/editors/datetime.dart';
import 'package:nocodb/features/core/components/editors/link_to_another_record.dart';
import 'package:nocodb/features/core/components/editors/link_to_another_record_bt.dart';
import 'package:nocodb/features/core/components/editors/multi_select.dart';
import 'package:nocodb/features/core/components/editors/single_select.dart';
import 'package:nocodb/features/core/components/editors/text_editor.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/utils.dart';
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

    onUpdateWrapper(final NcRow row) async {
      await upsert(context, ref, rowId, row);
    }

    switch (column.uidt) {
      case UITypes.checkbox:
        return CheckboxEditor(
          column: column,
          initialValue: value == true,
          onUpdate: onUpdateWrapper,
        );
      case UITypes.singleSelect:
        return SingleSelectEditor(
          column: column,
          initialValue: value,
          onUpdate: onUpdateWrapper,
        );
      case UITypes.multiSelect:
        final List<String> initialValue =
            value is String ? (value as String).split(',') : [];
        return MultiSelectEditor(
          column: column,
          initialValue: initialValue..sort(),
          onUpdate: onUpdateWrapper,
        );
      case UITypes.number:
        return TextEditor(
          column: column,
          onUpdate: onUpdateWrapper,
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
          onUpdate: onUpdateWrapper,
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
          onUpdate: onUpdateWrapper,
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
          onUpdate: onUpdateWrapper,
          initialValue: value,
          type: DateTimeType.fromUITypes(column.uidt),
        );
      case UITypes.attachment:
        // return ProviderScope(
        //   overrides: [
        //     formProvider.overrideWith((final ref) => {}),
        //   ],
        //   child: AttachmentEditor(
        //     rowId: rowId,
        //     column: column,
        //     onUpdate: onUpdateWrapper,
        //   ),
        // );
        return AttachmentEditor(
          rowId: rowId,
          column: column,
          onUpdate: onUpdateWrapper,
        );
      default:
        return TextEditor(
          column: column,
          onUpdate: onUpdateWrapper,
          initialValue: value,
          isNew: isNew,
        );
    }
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => _build(ref);
}
