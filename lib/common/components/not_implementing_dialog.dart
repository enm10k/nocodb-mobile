import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NotImplementedDialog extends HookConsumerWidget {
  const NotImplementedDialog({
    super.key,
  });

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      const AlertDialog(
        title: Text('Not implemented'),
        content: Text('...'),
      );
}
