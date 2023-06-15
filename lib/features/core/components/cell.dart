import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/nocodb_sdk/symbols.dart';
import '../../../common/flash_wrapper.dart';
import '../../../nocodb_sdk/models.dart';
import '../../../nocodb_sdk/types.dart';
import '../../../routes.dart';
import '../providers/providers.dart';
import 'cells/checkbox.dart';
import 'cells/datetime.dart';
import 'cells/link_to_another_record.dart';
import 'cells/multi_select.dart';
import 'cells/number.dart';
import 'cells/simple_text.dart';
import 'cells/single_select.dart';
import 'child_list.dart';
import 'editor.dart';
import 'editors/datetime.dart';
import 'modal_editor_wrapper.dart';

void showModalEditor({
  required BuildContext context,
  required NcTableColumn column,
  required String rowId,
  required dynamic value,
  isMultiline = false,
}) {
  showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    builder: (context) {
      return ModalEditorWrapper(
        rowId: rowId,
        title: column.title,
        content: Editor(
          rowId: rowId,
          column: column,
          value: value,
        ),
      );
    },
  );
}

// TODO: Fix. Assertions are duplicated.
class Cell {
  final String? rowId;
  final BuildContext context;
  final WidgetRef ref;
  final NcTableColumn column;
  final dynamic value;

  NcTableColumn get c => column;

  Cell({
    required this.rowId,
    required this.context,
    required this.ref,
    required this.column,
    required this.value,
  });

  static const emptyCell = DataCell(SizedBox());

  DataCell build() {
    return DataCell(
      _buildChild(),
      onTap: _onTap(),
    );
  }

  Function() _checkboxOnTap() {
    final view = ref.watch(viewProvider)!;
    return () {
      ref
          .watch(dataRowsProvider(view).notifier)
          .updateRow(
            rowId: rowId!,
            data: {column.title: value != true},
          )
          .then(
            (_) => notifySuccess(
              context,
              message: value == true ? 'Checked' : 'Unchecked',
            ),
          )
          .onError(
            (error, stackTrace) => notifyError(context, error, stackTrace),
          );
    };
  }

  void update({
    required rowId,
    required title,
    required value,
    required BuildContext context,
    required WidgetRef ref,
    required NcView view,
  }) {
    ref
        .watch(dataRowsProvider(view).notifier)
        .updateRow(
          rowId: rowId,
          data: {title: value},
        )
        .then(
          (_) => notifySuccess(context, message: 'Updated'),
        )
        .onError(
          (error, stackTrace) => notifyError(context, error, stackTrace),
        );
  }

  Function() _onTap() {
    if (rowId == null) {
      return () => notifyError(context, 'Table has no PK.', null);
    }

    final view = ref.watch(viewProvider)!;
    updateWrapper(String value) {
      update(
        rowId: rowId,
        title: column.title,
        value: value,
        context: context,
        ref: ref,
        view: view,
      );
    }

    switch (c.uidt) {
      case UITypes.checkbox:
        assert(value is bool?);
        return _checkboxOnTap();
      case UITypes.dateTime:
      case UITypes.date:
      case UITypes.time:
        final type = DateTimeType.fromUITypes(column.uidt);

        switch (type) {
          case DateTimeType.datetime:
            final initialDateTime = NocoDateTime.getInitialValue(value).dt;

            return () {
              pickDateTime(
                context,
                initialDateTime,
                (pickedDateTime) {
                  updateWrapper(NocoDateTime(pickedDateTime).toApiValue());
                },
              );
            };
          case DateTimeType.date:
            final initialDate = NocoDate.getInitialValue(value).dt;

            return () {
              pickDate(context, initialDate, (pickedDate) {
                updateWrapper(NocoDate.fromDateTime(pickedDate).toApiValue());
              });
            };

          case DateTimeType.time:
            final initialTime =
                TimeOfDay.fromDateTime(NocoTime.getInitialValue(value).dt);

            return () {
              pickTime(context, initialTime, (pickedTime) {
                updateWrapper(NocoTime.fromLocalTime(pickedTime).toApiValue());
              });
            };
          default:
            assert(false);
            return () {};
        }

      case UITypes.linkToAnotherRecord:
        if (value != null) {
          assert(
            column.isBelongsTo
                ? value is Map<String, dynamic>
                : value is List<dynamic>,
          );
        }

        if (column.isBelongsTo) {
          return () =>
              LinkRecordRoute(columnId: column.id, rowId: rowId!).push(context);
        } else {
          return () => showModalBottomSheet(
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
      default:
        assert(
          value is String? ||
              value is int? ||
              value is double? ||
              value is List, // Only Attachment?
        );
        return () {
          showModalEditor(
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
        assert(value is bool?);
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
        assert(value is List);
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
        assert(
          column.isBelongsTo
              ? value is Map<String, dynamic>?
              : value is List<dynamic>?,
          'value: $value',
        );

        return LinkToAnotherRecord(
          value,
          column: c,
        );
      default:
        return SimpleText(value);
    }
  }
}
