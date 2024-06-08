import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:popup_menu/popup_menu.dart';

import '../../../common/extensions.dart';
import '../../../common/flash_wrapper.dart';
import '../../../common/logger.dart';
import '../../../nocodb_sdk/client.dart';
import '../../../nocodb_sdk/models.dart';
import '../../../nocodb_sdk/symbols.dart';
import '../components/attachment_file_card.dart';
import '../components/attachment_image_card.dart';
import '../components/dialog/file_rename_dialog.dart';
import '../providers/providers.dart';

enum PopupMenuAction {
  download,
  rename,
  delete,
}

class PopupMenuUserInfo {
  final PopupMenuAction action;
  final String id;
  PopupMenuUserInfo(this.action, this.id);

// Map<String, dynamic> toJson() {
//   return {
//     'action': action,
//     'id': id,
//   };
// }
}

enum FileUploadType {
  fromStorage,
  fromCamera,
  fromGallery,
}

class AttachmentEditorPage extends HookConsumerWidget {
  final String rowId;
  final String columnTitle;
  AttachmentEditorPage(this.rowId, this.columnTitle, {super.key});

  // TODO: Fix lifetime issue.
  // There is a possibility that the file upload will continue even after the screen is closed,
  // and there is a concern that the lifetime of onUpdate might expire when the file upload is complete.
  Future<void> uploadFile(
    BuildContext context,
    WidgetRef ref,
    Refreshable<AttachedFiles> notifier,
    FileUploadType type,
    FnOnUpdate onUpdate,
  ) async {
    try {
      context.loaderOverlay.show();
      switch (type) {
        case FileUploadType.fromStorage:
          // TODO: Setting withReadStream: true might be better for memory footprint.
          // However, a downside is that it may complicate the code, so the priority is not high.
          final result = await FilePicker.platform.pickFiles(
            withData: true,
            allowMultiple: true,
          );
          if (result == null) {
            return;
          }
          ref.read(notifier).upload(
                result.files.map((e) => NcPlatformFile(e)).toList(),
                onUpdate,
              );
        case FileUploadType.fromCamera:
        case FileUploadType.fromGallery:
          final source = type == FileUploadType.fromCamera
              ? ImageSource.camera
              : ImageSource.gallery;
          final file = await ImagePicker().pickImage(source: source);
          if (file == null) {
            return;
          }
          ref.read(notifier).upload(
            [NcXFile(file)],
            onUpdate,
          );
      }
    } catch (e, s) {
      logger.shout(e);
      logger.shout(s);
      if (context.mounted) {
        notifyError(context, e, s);
      }
    } finally {
      if (context.mounted) {
        context.loaderOverlay.hide();
      }
    }
  }

  Future<void> downloadFile(
    BuildContext context,
    WidgetRef ref,
    Refreshable<AttachedFiles> notifier,
    NcAttachedFile file,
  ) async {
    final downloadDir = await getFileDownloadDirectory();
    logger.info('downloadDir: $downloadDir');
    if (downloadDir == null) {
      const msg = 'Failed to get download directory.';
      logger.shout(msg);
      if (context.mounted) {
        notifyError(context, msg, null);
      }
      return;
    }

    FlutterDownloader.enqueue(
      url: file.signedUrl(api.uri),
      fileName: file.title,
      savedDir: downloadDir,
      showNotification: true,
      // TODO: Ask permission to notify file download.
      openFileFromNotification: true,
      saveInPublicStorage: true,
    ).then((value) {
      logger.info('Download started: $value');
      notifySuccess(context, message: 'Download started.');
    }).onError((e, s) {
      logger.severe(e);
      logger.severe(s);
      if (context.mounted) {
        notifyError(context, e, s);
      }
    });
  }

  static const kDownload = PopupMenuAction.download;
  static const kRename = PopupMenuAction.rename;
  static const kDelete = PopupMenuAction.delete;

// https://stackoverflow.com/questions/59501445/flutter-how-to-save-a-file-on-ios
  Future<String?> getFileDownloadDirectory() async {
    if (Platform.isIOS) {
      final downloadDir = await getApplicationDocumentsDirectory();
      return downloadDir.path;
    } else if (Platform.isAndroid) {
      final downloadDir = await getExternalStorageDirectory();
      return downloadDir?.path;
    } else {
      throw Exception('Unsupported platform');
    }
  }

  List<MenuItemProvider> buildPopupMenuItems(String id) {
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

  GlobalKey fabState = GlobalKey<ExpandableFabState>();

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

    onUpdate(row) {
      final dataRowsNotifier = ref.read(dataRowsProvider(view).notifier);
      dataRowsNotifier
          .updateRow(rowId: rowId, data: row)
          .then(
            (_) => notifySuccess(context, message: 'Updated'),
          )
          .onError(
            (error, stackTrace) => notifyError(context, error, stackTrace),
          );
    }

    // TODO: Adjust the design when files is empty.
    final files = (row[columnTitle] ?? [])
        .map<NcAttachedFile>(
          (e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList() as List<NcAttachedFile>;
    logger.info(files);

    final provider = attachedFilesProvider(files, columnTitle);
    final notifier = provider.notifier;

    return Scaffold(
      appBar: AppBar(
        title: Text(columnTitle),
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        type: ExpandableFabType.fan,
        distance: 100,
        key: fabState,
        // fanAngle: 0,
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          child: const Icon(Icons.arrow_upward_rounded),
          fabSize: ExpandableFabSize.regular,
          shape: const CircleBorder(),
        ),
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: const Icon(Icons.close),
          fabSize: ExpandableFabSize.small,
          shape: const CircleBorder(),
        ),
        children: [
          FloatingActionButton(
            heroTag: 'upload_from_storage',
            onPressed: () {
              uploadFile(
                context,
                ref,
                notifier,
                FileUploadType.fromStorage,
                onUpdate,
              );
            },
            child: const Icon(Icons.upload_file_rounded, size: 32),
          ),
          FloatingActionButton(
            heroTag: 'upload_from_camera',
            onPressed: () {
              uploadFile(
                context,
                ref,
                notifier,
                FileUploadType.fromCamera,
                onUpdate,
              );
            },
            child: const Icon(Icons.photo_camera_rounded, size: 32),
          ),
          FloatingActionButton(
            heroTag: 'upload_from_gallery',
            onPressed: () {
              uploadFile(
                context,
                ref,
                notifier,
                FileUploadType.fromGallery,
                onUpdate,
              );
            },
            child: const Icon(Icons.image_rounded, size: 32),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(8),
        children: files.map(
          (file) {
            // TODO: Implement a file details screen instead of using PopupMenu.
            final popupMenu = PopupMenu(
              items: buildPopupMenuItems(file.id),
              onClickMenu: (item) async {
                try {
                  final userInfo = item.menuUserInfo as PopupMenuUserInfo;

                  switch (userInfo.action) {
                    case kDownload:
                      downloadFile(context, ref, notifier, file);
                    case kRename:
                      showDialog<String>(
                        context: context,
                        builder: (_) => FileRenameDialog(file),
                      ).then((value) async {
                        if (value == null) {
                          return;
                        }
                        await ref
                            .read(notifier)
                            .rename(userInfo.id, value, onUpdate);
                      });

                    case kDelete:
                      await ref.read(notifier).delete(userInfo.id, onUpdate);
                      if (context.mounted) {
                        notifySuccess(context, message: 'Deleted');
                      }
                  }
                } catch (e, s) {
                  logger.severe(e);
                  logger.severe(s);
                  if (context.mounted) {
                    notifyError(context, e, s);
                  }
                }
              },
              context: context,
            );

            return file.isImage
                ? AttachmentImageCard(
                    file,
                    popupMenu: popupMenu,
                  )
                : AttachmentFileCard(
                    file,
                    popupMenu: popupMenu,
                  );
          },
        ).toList(),
      ),
    );
  }
}
