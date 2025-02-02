import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/utils.dart';
import 'package:nocodb/features/core/components/cells/attachment.dart';
import 'package:nocodb/features/core/components/cells/checkbox.dart';
import 'package:nocodb/features/core/components/cells/datetime.dart';
import 'package:nocodb/features/core/components/cells/link_to_another_record.dart';
import 'package:nocodb/features/core/components/cells/multi_select.dart';
import 'package:nocodb/features/core/components/cells/number.dart';
import 'package:nocodb/features/core/components/cells/simple_text.dart';
import 'package:nocodb/features/core/components/cells/single_select.dart';
import 'package:nocodb/features/core/components/child_list.dart';
import 'package:nocodb/features/core/components/editor.dart';
import 'package:nocodb/features/core/components/editors/datetime.dart';
import 'package:nocodb/features/core/components/modal_editor_wrapper.dart';
import 'package:nocodb/features/core/pages/attachment_editor.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/utils.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:nocodb/nocodb_sdk/types.dart';
import 'package:nocodb/routes.dart';

Future<void> showModalEditor({
  required BuildContext context,
  required NcTableColumn column,
  required String rowId,
  required dynamic value,
  isMultiline = false,
}) async {
  await showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    builder: (context) => ModalEditorWrapper(
      rowId: rowId,
      title: column.title,
      content: Editor(
        rowId: rowId,
        column: column,
        value: value,
      ),
    ),
  );
}

// TODO: Fix. Assertions are duplicated.
class Cell {
  Cell({
    required this.rowId,
    required this.context,
    required this.ref,
    required this.column,
    required this.value,
  });
  final String? rowId;
  final BuildContext context;
  final WidgetRef ref;
  final NcTableColumn column;
  final dynamic value;

  NcTableColumn get c => column;

  static const emptyCell = DataCell(SizedBox());

  DataCell build() => DataCell(
        _buildChild(),
        onTap: _onTap(),
      );

  Function() _onTap() {
    if (rowId == null) {
      return () => notifyError(context, 'Table has no PK.', null);
    }

    updateWrapper(String value) async {
      await upsert(context, ref, rowId!, {
        column.title: value,
      });
    }

    switch (c.uidt) {
      case UITypes.checkbox:
        assert(value is bool?);
        return () async {
          await upsert(
            context,
            ref,
            rowId,
            {column.title: value != true},
            onUpdateCallback: (_) => notifySuccess(
              context,
              message: value != true ? 'Checked' : 'Unchecked',
            ),
          );
        };
      case UITypes.dateTime:
      case UITypes.date:
      case UITypes.time:
        final type = DateTimeType.fromUITypes(column.uidt);

        switch (type) {
          case DateTimeType.datetime:
            final initialDateTime = NocoDateTime.getInitialValue(value).dt;

            return () async {
              await pickDateTime(
                context,
                initialDateTime,
                (pickedDateTime) async {
                  await updateWrapper(
                    NocoDateTime(pickedDateTime).toApiValue(),
                  );
                },
              );
            };
          case DateTimeType.date:
            final initialDate = NocoDate.getInitialValue(value).dt;

            return () async {
              await pickDate(context, initialDate, (pickedDate) async {
                await updateWrapper(
                  NocoDate.fromDateTime(pickedDate).toApiValue(),
                );
              });
            };

          case DateTimeType.time:
            final initialTime =
                TimeOfDay.fromDateTime(NocoTime.getInitialValue(value).dt);

            return () async {
              await pickTime(context, initialTime, (pickedTime) {
                updateWrapper(NocoTime.fromLocalTime(pickedTime).toApiValue());
              });
            };
          default:
            assert(false);
            return () {};
        }

      case UITypes.links:
      case UITypes.linkToAnotherRecord:
        if (value != null) {
          assert(
            column.isBelongsTo ? value is Map<String, dynamic> : value is int,
          );
        }

        if (column.isBelongsTo) {
          return () async =>
              LinkRecordRoute(columnId: column.id, rowId: rowId!).push(context);
        } else {
          return () async => showModalBottomSheet(
                isScrollControlled: true,
                context: context,
                builder: (context) {
                  final tables = ref.read(tablesProvider);
                  final relation = tables!.relationMap[column.fkRelatedModelId];
                  return ChildList(
                    column: column,
                    rowId: rowId!,
                    relation: relation!,
                  );
                },
              );
        }
      case UITypes.attachment:
        return () async => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AttachmentEditorPage(rowId!, column.title),
              ),
            );
      default:
        assert(
          value is String? ||
              value is int? ||
              value is double? ||
              value is List, // Only Attachment?
        );
        return () async {
          await showModalEditor(
            context: context,
            column: c,
            rowId: rowId!,
            value: value,
          );
        };
    }
  }

  Widget _buildChild() {
    // logger.info(column.relationType);
    // logger.info(value);
    // logger.info(value.runtimeType);
    switch (c.uidt) {
      case UITypes.checkbox:
        return CheckBox(value ?? false);
      case UITypes.dateTime:
      case UITypes.date:
      case UITypes.time:
        final type = DateTimeType.fromUITypes(column.uidt);
        return value != null
            ? Datetime(
                value,
                type: type,
              )
            : const SizedBox();
      case UITypes.singleSelect:
        assert(value is String?);
        return SingleSelect(value, column: c);
      case UITypes.multiSelect:
        // assert(value is List);
        return MultiSelect(
          value is String ? value.split(',') : [],
          column: c,
        );
      case UITypes.number:
      case UITypes.autoNumber:
      case UITypes.decimal:
        assert(value is String? || value is int?);
        return Number(value);
      case UITypes.linkToAnotherRecord:
        return LinkToAnotherRecord(
          value,
          column: c,
        );
      case UITypes.links:
        final number = cast<num>(value);
        final unit = (number != null && 1 < number) ? c.plural : c.singular;

        return SimpleText('$number $unit');
      case UITypes.attachment:
        return Attachment(value);
      default:
        return SimpleText(value);
    }
  }
}
