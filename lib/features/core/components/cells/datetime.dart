import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/components/editors/datetime.dart';
import 'package:nocodb/nocodb_sdk/types.dart';

class Datetime extends HookConsumerWidget {
  const Datetime(
    this.value, {
    super.key,
    required this.type,
  });
  final String value;
  final DateTimeType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (type) {
      case DateTimeType.datetime:
        return Text(
          NocoDateTime.fromString(value).toString(),
          style: const TextStyle(fontSize: 12),
        );
      case DateTimeType.date:
        return Text(NocoDate.fromString(value).toString());
      case DateTimeType.time:
        return Text(NocoTime.fromLocalTimeString(value).toString());
      default:
        assert(false, 'invalid type. type: $type');
        return const SizedBox();
    }
  }
}
