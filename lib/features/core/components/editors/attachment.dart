import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/models.dart';
import '../../../../nocodb_sdk/symbols.dart';
import '../../pages/attachment_editor.dart';
import '../../providers/providers.dart';
import '/nocodb_sdk/client.dart';
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

  Widget buildImageCard(
    NcAttachedFile file,
    GlobalKey key,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        key: key,
        child: SizedBox(
          width: 80,
          height: 80,
          child: CachedNetworkImage(
            imageUrl: file.signedUrl(api.uri),
            placeholder: (context, url) => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  Widget buildFileCard(
    NcAttachedFile file,
    GlobalKey key,
  ) {
    return Card(
      key: key,
      elevation: 4,
      child: InkWell(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const SizedBox(
                width: 72,
                height: 72,
                child: Icon(Icons.description_outlined, size: 48),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  file.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> buildChildren(
    List<model.NcAttachedFile> files,
  ) {
    return files.map<Widget>((file) {
      final key = GlobalKey();
      return file.isImage
          ? buildImageCard(file, key)
          : buildFileCard(file, key);
    }).toList();
  }

  // TODO: Show files on the list and open AttachmentEditorPage when further actions are required.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final children = buildChildren(files);

    return GestureDetector(
      onTap: () {
        if (rowId == null) {
          // TODO: Show message to explain the reason why AttachmentEditorPage does not open.
          // AttachmentEditorPage only supports updates and does not support saving new records,
          // so it will not open if the line has not been saved yet.
          return;
        }
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
        constraints:
            const BoxConstraints(maxHeight: 500), // TODO: Adjust maxHeight.
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          padding: const EdgeInsets.all(8),
          children: children,
        ),
      ),
    );
  }
}
