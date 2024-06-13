import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/models.dart';
import '../../../../nocodb_sdk/symbols.dart';
import '../../pages/attachment_editor.dart';
import '../../providers/providers.dart';
import '../attachment_file_card.dart';
import '../attachment_image_card.dart';
import '/nocodb_sdk/models.dart' as model;

class AttachmentEditor extends HookConsumerWidget {
  final String? rowId;
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
  const AttachmentEditor({
    super.key,
    required this.rowId,
    required this.column,
    required this.onUpdate,
  });

  Widget buildEmpty({text = '-'}) {
    return Container(
      height: 80,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rowId == null) {
      return InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Record is not yet created.'),
                content: const Text(
                  'Once record is created, you can attach files.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
        child: buildEmpty(),
      );
    }

    final view = ref.watch(viewProvider);
    if (view == null) {
      return const SizedBox();
    }
    final files = ref.watch(attachmentsProvider(view, rowId, column.title));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return AttachmentEditorPage(rowId!, column.title);
            },
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 80,
          maxHeight: 500, // TODO: Adjust maxHeight.
        ),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          padding: const EdgeInsets.all(8),
          children: files.map<Widget>((file) {
            return file.isImage
                ? AttachmentImageCard(file)
                : AttachmentFileCard(file);
          }).toList(),
        ),
      ),
    );
  }
}
