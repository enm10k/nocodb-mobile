import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<dynamic> onUpload(
    ValueNotifier<List<model.NcAttachedFile>> files,
    List<NcFile> newFiles,
  ) async {
    // TODO: Show loading indicator.
    // TODO: Error handling.
    final newAttachedFiles = await api.dbStorageUpload(newFiles);
    files.value = [
      ...files.value,
      ...newAttachedFiles,
    ];
    await onUpdate({
      column.title: files.value,
    });
  }

  Widget buildAttachButtons(ValueNotifier<List<model.NcAttachedFile>> files) {
    const iconSize = 38.0;
    const padding = EdgeInsets.all(2);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.count(
        primary: false,
        crossAxisCount: 2,
        children: [
          Padding(
            padding: padding,
            child: IconButton(
              onPressed: () async {
                // TODO: Using withReadStream might be better for memory footprint.
                final result =
                    await FilePicker.platform.pickFiles(withData: true);
                if (result == null) {
                  return;
                }
                onUpload(
                  files,
                  result.files.map((e) => NcPlatformFile(e)).toList(),
                );
              },
              icon: const Icon(Icons.upload_file_rounded, size: iconSize),
            ),
          ),
          Padding(
            padding: padding,
            child: IconButton(
              onPressed: () async {
                final file =
                    await ImagePicker().pickImage(source: ImageSource.camera);
                if (file == null) {
                  return;
                }
                onUpload(files, [NcXFile(file)]);
              },
              icon: const Icon(Icons.photo_camera_rounded, size: iconSize),
            ),
          ),
          Padding(
            padding: padding,
            child: IconButton(
              onPressed: () async {
                final file =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (file == null) {
                  return;
                }
                onUpload(files, [NcXFile(file)]);
              },
              icon: const Icon(Icons.image_rounded, size: iconSize),
            ),
          ),
          Container(),
        ],
      ),
    );
  }

  List<Widget> buildChildren(ValueNotifier<List<model.NcAttachedFile>> files) {
    final items = files.value.map<Widget>((file) {
      final isImage = file.mimetype.startsWith('image');

      final content = isImage
          ? Card(
              elevation: 2,
              child: SizedBox(
                width: 80,
                height: 80,
                child: CachedNetworkImage(
                  imageUrl: api.uri.replace(path: file.signedPath).toString(),
                  placeholder: (context, url) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            )
          : Card(
              elevation: 4,
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
            );

      return content;
    }).toList();

    items.insert(0, buildAttachButtons(files));

    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = useState<List<model.NcAttachedFile>>([]);

    useEffect(
      () {
        files.value = initialValue;
        return null;
      },
      [initialValue],
    );

    final children = buildChildren(files);
    final size = MediaQuery.of(context).size;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: size.width),
      child: Scrollbar(
        thickness: 4,
        radius: const Radius.circular(50),
        thumbVisibility: true,
        child: GridView.count(
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          crossAxisCount: 3,
          children: children,
        ),
      ),
    );
  }
}
