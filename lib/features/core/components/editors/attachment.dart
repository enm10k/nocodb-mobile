import 'package:collection/collection.dart';
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

    // TODO: Organize initialization.
    // NOTE: The initialization process needs to be the same for both AttachmentEditor and AttachmentEditorPage.
    // If they differ, file synchronization will be lost when navigating between the two components.
    final view = ref.watch(viewProvider);
    if (view == null) {
      return const SizedBox();
    }
    final table = ref.watch(tableProvider);
    final rows = ref.watch(dataRowsProvider(view)).valueOrNull;
    if (table == null || rows == null) {
      return const SizedBox();
    }

    final row = rows.list.firstWhereOrNull((row) {
      return table.getPkFromRow(row) == rowId;
    });
    if (row == null) {
      return const SizedBox();
    }

    final files = (row[column.title] ?? [])
        .map<NcAttachedFile>(
          (e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList() as List<NcAttachedFile>;

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
