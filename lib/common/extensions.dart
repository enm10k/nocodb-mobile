import 'package:flutter/material.dart';

extension ContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  Size get size => MediaQuery.of(this).size;

  double get height => MediaQuery.of(this).size.height;

  double get width => MediaQuery.of(this).size.width;
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

extension JsonListExtension on Iterable<Map<String, dynamic>> {
  Map<String, dynamic> flatten() => reduce(
        (a, b) {
          a.addAll(b);
          return a;
        },
      );
}

extension ListExtension<E> on List<E> {
  List<E> u() => List<E>.unmodifiable(this);
}

extension MapExtension<K, V> on Map<K, V> {
  Map<K, V> u() => Map<K, V>.unmodifiable(this);
}
