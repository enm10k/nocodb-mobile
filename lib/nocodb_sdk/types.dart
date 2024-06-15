import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NocoDateTime {
  NocoDateTime(this.dt);
  factory NocoDateTime.fromString(final String s) =>
      NocoDateTime(DateTime.parse(s));

  factory NocoDateTime.getInitialValue(final String? s) =>
      s == null ? NocoDateTime(DateTime.now()) : NocoDateTime.fromString(s);
  DateTime dt;

  String toApiValue() => dt.toUtc().toString();

  static final DateFormat _format = DateFormat('yyyy-MM-dd hh:mm');
  @override
  String toString() => _format.format(dt.toLocal());
}

class NocoDate {
  NocoDate._(this.dt);
  factory NocoDate.fromDateTime(final DateTime dt) => NocoDate._(dt);
  factory NocoDate.fromString(final String s) {
    final sp = s.split('-');
    final year = int.parse(sp[0]);
    final month = int.parse(sp[1]);
    final day = int.parse(sp[2]);
    return NocoDate._(DateTime(year, month, day, 1, 1, 1));
  }

  factory NocoDate.getInitialValue(final String? s) => s == null
      ? NocoDate.fromDateTime(DateTime.now())
      : NocoDate.fromString(s);
  DateTime dt;

  static final DateFormat _format = DateFormat('yyyy-MM-dd');

  String toApiValue() => _format.format(dt);

  @override
  String toString() => toApiValue();
}

class NocoTime {
  NocoTime._(this.dt);

  factory NocoTime.getInitialValue(final String? s) {
    if (s == null) {
      final now = DateTime.now();
      return NocoTime.fromDateTime(now);
    }
    return NocoTime.fromLocalTimeString(s);
  }

  factory NocoTime.fromDateTime(final DateTime dt) => NocoTime._(dt.toLocal());

  factory NocoTime.fromLocalTime(final TimeOfDay t) => NocoTime._(
        _dt(
          t.hour,
          t.minute,
        ),
      );

  factory NocoTime.fromLocalTimeString(final String s) {
    final sp = s.split(':');

    assert(sp.length == 2 || sp.length == 3, 'invalid format: $s');

    final hour = int.parse(sp[0]);
    final minute = int.parse(sp[1]);
    return NocoTime._(_dt(hour, minute));
  }
  DateTime dt;

  static DateTime _dt(final int hour, final int minute) =>
      DateTime(1999, 1, 1, hour, minute);

  TimeOfDay getLocalTime() {
    final local = dt.toLocal();
    return TimeOfDay.fromDateTime(local);
  }

  String toApiValue() {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => toApiValue();
}
