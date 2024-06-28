import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/components/attachment_file_card.dart';
import 'package:nocodb/features/core/components/attachment_image_card.dart';
import 'package:nocodb/features/core/pages/attachment_editor.dart';
import 'package:nocodb/features/core/providers/attachments_provider.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

class AttachmentEditor extends HookConsumerWidget {
  const AttachmentEditor({
    super.key,
    required this.rowId,
    required this.column,
    required this.onUpdate,
  });
  final String? rowId;
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;

  Widget buildEmpty({text = '-'}) => Container(
        height: 80,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(attachmentsProvider(rowId, column.title));

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttachmentEditorPage(rowId, column.title),
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
          children: files
              .map<Widget>(
                (file) => file.isImage
                    ? AttachmentImageCard(file)
                    : AttachmentFileCard(file),
              )
              .toList(),
        ),
      ),
    );
  }
}
