import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/components/attachment_file_card.dart';
import 'package:nocodb/features/core/components/attachment_image_card.dart';
import 'package:nocodb/features/core/pages/attachment_editor.dart';
import 'package:nocodb/features/core/providers/providers.dart';
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

  Widget buildEmpty({final text = '-'}) => Container(
        height: 80,
      );

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    if (rowId == null) {
      return InkWell(
        onTap: () async {
          await showDialog(
            context: context,
            builder: (final context) => AlertDialog(
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
            ),
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
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (final context) =>
                AttachmentEditorPage(rowId!, column.title),
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
                (final file) => file.isImage
                    ? AttachmentImageCard(file)
                    : AttachmentFileCard(file),
              )
              .toList(),
        ),
      ),
    );
  }
}
