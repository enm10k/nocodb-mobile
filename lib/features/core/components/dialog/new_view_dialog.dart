import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/components/not_implementing_dialog.dart';
import 'package:nocodb/common/components/single_value_dialog.dart';

class NewViewDialog extends HookConsumerWidget {
  const NewViewDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleValueDialog(
        title: 'Create New View',
        labelText: 'View name',
        actions: [
          TextButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const NotImplementedDialog(),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      );
}
