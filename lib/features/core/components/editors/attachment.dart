import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/nocodb_sdk/client.dart';
import '/nocodb_sdk/models.dart' as model;

class AttachmentEditor extends HookConsumerWidget {
  final model.NcTableColumn column;
  final Function(Map<String, dynamic>) onUpdate;
  final List<model.NcAttachedFile> initialValue;
  const AttachmentEditor({
    super.key,
    required this.column,
    required this.onUpdate,
    required this.initialValue,
  });

  Future<dynamic> onUpload() async {
    // TODO: Error handling
    // TODO: Using withReadStream might be better for memory footprint.
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      final res = await api.dbStorageUpload(result.files);
      initialValue.addAll(res);
      onUpdate({
        column.title: initialValue,
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton(
        child: const Icon(Icons.upload_file),
        onPressed: () async {
          await onUpload();
        },
      ),
    );
  }
}
