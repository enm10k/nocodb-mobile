import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/extensions.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/components/attachment_file_card.dart';
import 'package:nocodb/features/core/components/attachment_image_card.dart';
import 'package:nocodb/features/core/components/dialog/file_rename_dialog.dart';
import 'package:nocodb/features/core/providers/attachments_provider.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/utils.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:popup_menu/popup_menu.dart';

GlobalKey fabState = GlobalKey<ExpandableFabState>();

class ExFab extends HookConsumerWidget {
  const ExFab(this.rowId, this.columnTitle, {super.key});
  final ValueNotifier<String?> rowId;
  final String columnTitle;

  Future<void> uploadFile(
    BuildContext context,
    WidgetRef ref,
    FileUploadType type,
  ) async {
    try {
      final notifier = attachmentsProvider(rowId.value, columnTitle).notifier;
      Future<void> onUpdateWrapper(NcRow row) async => upsert(
            context,
            ref,
            rowId.value,
            row,
            updateForm: false,
            onCreateCallback: (row) {
              final table = ref.read(tableProvider);
              final pk = table?.getPkFromRow(row);
              if (pk! == null) {
                return;
              }
              rowId.value = pk;

              // Notify new pk to RowEditor
              ref.read(newIdProvider.notifier).state = pk;
              notifySuccess(context, message: 'Saved.');
            },
          );

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
                result.files.map(NcPlatformFile.new).toList(),
                onUpdateWrapper,
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
            onUpdateWrapper,
          );
      }
    } catch (e, s) {
      logger
        ..shout(e)
        ..shout(s);
      if (context.mounted) {
        notifyError(context, e, s);
      }
    } finally {
      if (context.mounted) {
        context.loaderOverlay.hide();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpandableFab(
        type: ExpandableFabType.fan,
        distance: 100,
        key: fabState,
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
            onPressed: () async {
              await uploadFile(
                context,
                ref,
                FileUploadType.fromStorage,
              );
            },
            child: const Icon(Icons.upload_file_rounded, size: 32),
          ),
          FloatingActionButton(
            heroTag: 'upload_from_camera',
            onPressed: () async {
              await uploadFile(
                context,
                ref,
                FileUploadType.fromCamera,
              );
            },
            child: const Icon(Icons.photo_camera_rounded, size: 32),
          ),
          FloatingActionButton(
            heroTag: 'upload_from_gallery',
            onPressed: () async {
              await uploadFile(
                context,
                ref,
                FileUploadType.fromGallery,
              );
            },
            child: const Icon(Icons.image_rounded, size: 32),
          ),
        ],
      );
}

enum PopupMenuAction {
  download,
  rename,
  delete,
}

class PopupMenuUserInfo {
  PopupMenuUserInfo(this.action, this.id);
  final PopupMenuAction action;
  final String id;

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
  const AttachmentEditorPage(this.rowId, this.columnTitle, {super.key});
  final String? rowId;
  final String columnTitle;

  // TODO: Fix lifetime issue.
  // There is a possibility that the file upload will continue even after the screen is closed,
  // and there is a concern that the lifetime of onUpdate might expire when the file upload is complete.
  Future<void> downloadFile(
    BuildContext context,
    WidgetRef ref,
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

    await FlutterDownloader.enqueue(
      // url: file.getFullUrl(api.uri),
      url: file.signedUrl,
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
      logger
        ..severe(e)
        ..severe(s);
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

  List<MenuItemProvider> buildPopupMenuItems(String id) => [
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowId_ = useState(rowId);
    final provider = attachmentsProvider(rowId_.value, columnTitle);
    final notifier = provider.notifier;
    final files = ref.watch(provider);

    Future<void> onUpdateWrapper(NcRow row) async =>
        upsert(context, ref, rowId_.value, row, updateForm: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(columnTitle),
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExFab(rowId_, columnTitle),
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
                      await downloadFile(context, ref, file);
                    case kRename:
                      await showDialog<String>(
                        context: context,
                        builder: (_) => FileRenameDialog(file),
                      ).then((value) async {
                        if (value == null) {
                          return;
                        }
                        await ref
                            .read(notifier)
                            .rename(userInfo.id, value, onUpdateWrapper);
                      });

                    case kDelete:
                      await ref
                          .read(notifier)
                          .delete(userInfo.id, onUpdateWrapper);
                      if (context.mounted) {
                        notifySuccess(context, message: 'Deleted');
                      }
                  }
                } catch (e, s) {
                  logger
                    ..severe(e)
                    ..severe(s);
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
