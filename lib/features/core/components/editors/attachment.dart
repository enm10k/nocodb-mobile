import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:popup_menu/popup_menu.dart';

import '../../../../common/extensions.dart';
import '../../../../common/flash_wrapper.dart';
import '../../../../common/logger.dart';
import '../../../../nocodb_sdk/models.dart';
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

class AttachmentEditor extends HookConsumerWidget {
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
  AttachmentEditor({
    super.key,
    required this.column,
    required this.onUpdate,
  });

  Future<void> uploadFile(
    BuildContext context,
    WidgetRef ref,
    Refreshable<AttachedFiles> notifier,
    FileUploadType type,
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

  Widget buildUploadButtons(
    BuildContext context,
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
              onPressed: () {
                uploadFile(context, ref, notifier, FileUploadType.fromStorage);
              },
              icon: const Icon(Icons.upload_file_rounded, size: iconSize),
            ),
          ),
          Padding(
            padding: padding,
            child: IconButton(
              onPressed: () {
                uploadFile(context, ref, notifier, FileUploadType.fromCamera);
              },
              icon: const Icon(Icons.photo_camera_rounded, size: iconSize),
            ),
          ),
          Padding(
            padding: padding,
            child: IconButton(
              onPressed: () {
                uploadFile(context, ref, notifier, FileUploadType.fromGallery);
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

  Widget buildImageCard(
    NcAttachedFile file,
    PopupMenu popupMenu,
    GlobalKey key,
  ) {
    return Card(
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
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  Widget buildFileCard(
    NcAttachedFile file,
    PopupMenu popupMenu,
    GlobalKey key,
  ) {
    return Card(
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
  }

  List<Widget> buildChildren(
    List<model.NcAttachedFile> files,
    BuildContext context,
    WidgetRef ref,
    Refreshable<AttachedFiles> notifier,
  ) {
    final items = files.map<Widget>((file) {
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
                  await ref.read(notifier).rename(userInfo.id, value, onUpdate);
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

      final key = GlobalKey();
      return file.isImage
          ? buildImageCard(file, popupMenu, key)
          : buildFileCard(file, popupMenu, key);
    }).toList();

    return [buildUploadButtons(context, ref, notifier), ...items];
  }

  static String portName = 'downloader_send_port';
  ReceivePort port = ReceivePort();
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(portName);
    send?.send([id, status, progress]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialFiles = ref.watch(attachmentEditorProvider);
    final provider = attachedFilesProvider(initialFiles, column.title);
    final files = ref.watch(provider);
    final notifier = provider.notifier;

    final children = buildChildren(files, context, ref, notifier);

    final size = MediaQuery.of(context).size;

    useEffect(
      () {
        IsolateNameServer.registerPortWithName(port.sendPort, portName);
        logger.info('IsolateNameServer.registerPortWithName: $portName');
        port.listen((dynamic message) {
          final list = message as List<Object>;
          // final id = list[0] as String;
          final statusId = list[1] as int;
          final status = DownloadTaskStatus.values[statusId];
          // final progress = list[2] as int;
          // logger.info('downloadCallback: $id, $status, $progress');
          logger.info('downloadCallback: $status');
          if (DownloadTaskStatus.complete == status) {
            notifySuccess(context, message: 'Download completed.');
          }
        });

        FlutterDownloader.registerCallback(downloadCallback);
        return () {
          IsolateNameServer.removePortNameMapping(portName);
          logger.info('IsolateNameServer.removePortNameMapping: $portName');
        };
      },
      [],
    );

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
