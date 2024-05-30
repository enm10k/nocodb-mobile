import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:popup_menu/popup_menu.dart';

import '../../../../common/extensions.dart';
import '../../../../common/flash_wrapper.dart';
import '../../../../common/logger.dart';
import '../../../../nocodb_sdk/symbols.dart';
import '../../providers/providers.dart';
import '../dialog/file_rename_dialog.dart';
import '/nocodb_sdk/client.dart';
import '/nocodb_sdk/models.dart' as model;

enum PopupMenuAction {
  download,
  rename,
  delete,
}

class PopupMenuUserInfo {
  final PopupMenuAction action;
  final String id;
  PopupMenuUserInfo(this.action, this.id);

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'id': id,
    };
  }
}

class AttachmentEditor extends HookConsumerWidget {
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
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

  Widget buildAttachButtons(
    WidgetRef ref,
    Refreshable<AttachedFiles> notifier,
  ) {
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

                ref.read(notifier).upload(
                      result.files.map((e) => NcPlatformFile(e)).toList(),
                      onUpdate,
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
                ref.read(notifier).upload(
                  [NcXFile(file)],
                  onUpdate,
                );
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
                ref.read(notifier).upload(
                  [NcXFile(file)],
                  onUpdate,
                );
              },
              icon: const Icon(Icons.image_rounded, size: iconSize),
            ),
          ),
          Container(),
        ],
      ),
    );
  }

  static const kDownload = PopupMenuAction.download;
  static const kRename = PopupMenuAction.rename;
  static const kDelete = PopupMenuAction.delete;

  List<MenuItemProvider> buildMenuItems(String id) {
    return [
      MenuItem(
        title: kDownload.name.capitalize(),
        image: const Icon(
          Icons.download,
          color: Colors.white,
        ),
        userInfo: PopupMenuUserInfo(
          kDownload,
          id,
        ),
      ),
      MenuItem(
        title: kRename.name.capitalize(),
        image: const Icon(
          Icons.edit,
          color: Colors.white,
        ),
        userInfo: PopupMenuUserInfo(
          kRename,
          id,
        ),
      ),
      MenuItem(
        title: kDelete.name.capitalize(),
        image: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
        userInfo: PopupMenuUserInfo(
          kDelete,
          id,
        ),
      ),
    ];
  }

  List<Widget> buildChildren(
    List<model.NcAttachedFile> files,
    WidgetRef ref,
    Refreshable<AttachedFiles> notifier,
  ) {
    final context = useContext();

    final items = files.map<Widget>((file) {
      final popupMenu = PopupMenu(
        items: buildMenuItems(file.id),
        onClickMenu: (item) {
          try {
            final userInfo = item.menuUserInfo as PopupMenuUserInfo;

            switch (userInfo.action) {
              case kDownload:
                FileDownloader.downloadFile(
                  url: file.signedUrl(api.uri),
                  name: file.title,
                  onProgress: (String? fileName, double progress) {
                    logger.info('Downloading ${file.title}: $progress%');
                  },
                  onDownloadCompleted: (String path) {
                    final name = basename(path);
                    notifySuccess(context, message: 'Downloaded $name.');
                    context.loaderOverlay.hide();
                  },
                  onDownloadError: (String error) {
                    logger.severe('Download error: $error');
                    notifyError(context, error, null);
                    context.loaderOverlay.hide();
                    throw Exception(error);
                  },
                );
                context.loaderOverlay.show();
              case kRename:
                // TODO: Implement rename logic.
                final title = file.title;
                showDialog(
                  context: context,
                  builder: (_) => FileRenameDialog(title),
                );
              case kDelete:
                ref.read(notifier).delete(userInfo.id, onUpdate);
                notifySuccess(context, message: 'Deleted');
            }
          } catch (e, s) {
            logger.severe(e);
            logger.severe(s);
            notifyError(context, e, s);
          }
        },
        context: context,
      );

      final key = GlobalKey();
      final content = file.isImage
          ? Card(
              elevation: 2,
              child: InkWell(
                key: key,
                onTap: () {
                  popupMenu.show(widgetKey: key);
                },
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CachedNetworkImage(
                    imageUrl: file.signedUrl(api.uri),
                    placeholder: (context, url) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
              ),
            )
          : Card(
              key: key,
              elevation: 4,
              child: InkWell(
                onTap: () {
                  popupMenu.show(widgetKey: key);
                },
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

      return content;
    }).toList();

    items.insert(0, buildAttachButtons(ref, notifier));

    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = attachedFilesProvider(initialValue, column.title);
    final files = ref.watch(provider);
    final notifier = provider.notifier;

    final children = buildChildren(files, ref, notifier);
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
