import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:nocodb/nocodb_sdk/models.dart';

class FileRenameDialog extends HookConsumerWidget {
  const FileRenameDialog(
    this.file, {
    super.key,
  });
  final NcAttachedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(text: file.title);
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'title',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (context.mounted) {
              Navigator.pop(context, controller.text);
            }
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
