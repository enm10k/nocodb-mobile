import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SingleValueDialog extends HookConsumerWidget {
  const SingleValueDialog({
    super.key,
    required this.title,
    required this.labelText,
    required this.actions,
  });
  final String title;
  final String labelText;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textEditController = useTextEditingController(text: '');

    return AlertDialog(
      title: Text(title),
      content: IntrinsicHeight(
        child: Column(
          children: [
            TextField(
              controller: textEditController,
              decoration: InputDecoration(
                labelText: labelText,
              ),
            ),
          ],
        ),
      ),
      actions: actions,
    );
  }
}
