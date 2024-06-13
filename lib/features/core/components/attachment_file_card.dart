import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:popup_menu/popup_menu.dart';

import '../../../nocodb_sdk/models.dart';

class AttachmentFileCard extends HookConsumerWidget {
  final NcAttachedFile _file;
  final PopupMenu? popupMenu;
  const AttachmentFileCard(
    this._file, {
    this.popupMenu,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = popupMenu != null ? GlobalKey() : null;
    final child = Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.description_outlined, size: 48),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              _file.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
