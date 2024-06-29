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
