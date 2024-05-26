import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class Attachment extends HookConsumerWidget {
  final dynamic initialValue;
  const Attachment(this.initialValue, {super.key});

  Widget buildContent(int fileCount) {
    switch (fileCount) {
      case 0:
        return const SizedBox();
      case 1:
        return const Icon(Icons.description_outlined);
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined),
            Text('x $fileCount'),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileCount = initialValue == null ? 0 : initialValue.length;
    return Center(child: buildContent(fileCount));
  }
}
