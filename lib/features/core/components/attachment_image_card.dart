import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:popup_menu/popup_menu.dart';

import '../../../nocodb_sdk/client.dart';
import '../../../nocodb_sdk/models.dart';

class AttachmentImageCard extends HookConsumerWidget {
  final NcAttachedFile _file;
  final PopupMenu? popupMenu;
  const AttachmentImageCard(
    this._file, {
    this.popupMenu,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = popupMenu != null ? GlobalKey() : null;
    final child = SizedBox(
      width: 80,
      height: 80,
      child: CachedNetworkImage(
        imageUrl: _file.signedUrl(api.uri),
        placeholder: (context, url) => const Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );

    return Card(
      key: anchor,
      elevation: 4,
      child: anchor == null
          ? child
          : InkWell(
              onTap: () => popupMenu?.show(widgetKey: anchor),
              child: child,
            ),
    );
  }
}
