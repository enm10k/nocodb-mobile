import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../routes.dart';

class ModalEditorWrapper extends HookConsumerWidget {
  final String title;
  final String rowId;
  final Widget content;
  const ModalEditorWrapper({
    super.key,
    required this.title,
    required this.rowId,
    required this.content,
  });

  List<Widget> _buildActions() {
    final context = useContext();
    return [
      TextButton(
        onPressed: () {
          RowEditorRoute(id: rowId).push(context);
        },
        child: const Text(
          'Expand record',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 6,
            child: Container(
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              child: Text(
                title,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(width: 0.2),
            ),
            child: content,
          ),
          Row(
            children: _buildActions(),
          ),
        ],
      ),
    );
  }
}
