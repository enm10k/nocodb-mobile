import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:nocodb/nocodb_sdk/types.dart';

final firstDate = DateTime(0);
final lastDate = DateTime(2200);

Future<void> pickDate(
  BuildContext context,
  DateTime initialDate,
  Function(DateTime pickedDateTime) onUpdate,
) async {
  await showDatePicker(
    context: context,
    initialDate: initialDate.toLocal(),
    firstDate: firstDate,
    lastDate: lastDate,
  ).then((pickedDateTime) {
    if (pickedDateTime == null) {
      return;
    }
    logger.info(
      'pickedDateTime: $pickedDateTime, ${pickedDateTime.timeZoneName}',
    );

    onUpdate(pickedDateTime);
  });
}

Future<void> pickTime(
  BuildContext context,
  TimeOfDay initialTime,
  Function(TimeOfDay pickedTime) onUpdate,
) async {
  await showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  ).then((pickedTime) {
    if (pickedTime == null) {
      return;
    }

    onUpdate(pickedTime);
  });
}

Future<void> pickDateTime(
  BuildContext context,
  DateTime initialDateTime,
  Function(DateTime) onUpdate, {
  TextEditingController? controller,
}) async {
  final initialTime = NocoTime.fromDateTime(initialDateTime).getLocalTime();

  await pickDate(context, initialDateTime, (pickedDate) async {
    await pickTime(context, initialTime, (pickedTime) {
      final pickedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      onUpdate(pickedDateTime);
    });
  });
}

enum DateTimeType {
  datetime,
  date,
  time,
  unknown;

  factory DateTimeType.fromUITypes(UITypes type) {
    switch (type) {
      case UITypes.dateTime:
        return DateTimeType.datetime;
      case UITypes.date:
        return DateTimeType.date;
      case UITypes.time:
        return DateTimeType.time;
      default:
        assert(false, 'invalid type. type: $type');
        return DateTimeType.unknown;
    }
  }
}

class DateTimeEditor extends HookConsumerWidget {
  const DateTimeEditor({
    super.key,
    required this.column,
    required this.onUpdate,
    required this.initialValue,
    required this.type,
  });
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
  final dynamic initialValue;
  final DateTimeType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller =
        useTextEditingController(text: initialValue?.toString() ?? '');
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: const Icon(Icons.edit_calendar),
          onPressed: () async {
            switch (type) {
              case DateTimeType.datetime:
                final initialDateTime =
                    NocoDateTime.getInitialValue(initialValue).dt;

                await pickDateTime(context, initialDateTime,
                    (pickedDateTime) async {
                  final v = NocoDateTime(pickedDateTime);
                  await onUpdate({column.title: v.toApiValue()});
                  controller.text = v.toString();
                });
              case DateTimeType.date:
                final initialDate = NocoDate.getInitialValue(initialValue).dt;

                await pickDate(context, initialDate, (pickedDate) async {
                  final v = NocoDate.fromDateTime(pickedDate);
                  await onUpdate({column.title: v.toApiValue()});
                  controller.text = v.toString();
                });
              case DateTimeType.time:
                final initialTime = TimeOfDay.fromDateTime(
                  NocoTime.getInitialValue(initialValue).dt,
                );

                await pickTime(context, initialTime, (pickedTime) async {
                  final v = NocoTime.fromLocalTime(pickedTime);

                  // TODO: improve error handling
                  // Error is handled inside onUpdate.
                  // Regardless of whether onUpdate is successful or not, the controller will be updated.
                  // Add onSuccess and onError parameters to onUpdate
                  await onUpdate({column.title: v.toApiValue()});
                  controller.text = v.toString();
                });
              case DateTimeType.unknown:
                throw UnimplementedError();
            }
          },
        ),
      ),
    );
  }
}
