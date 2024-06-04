import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/client.dart';
import '../../../../nocodb_sdk/models.dart';

class Attachment extends HookConsumerWidget {
  final dynamic initialValue;
  const Attachment(this.initialValue, {super.key});

  List<Widget> buildChildren(List<NcAttachedFile> files) {
    return files.map((file) {
      return file.isImage
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: CachedNetworkImage(
                imageUrl: file.signedUrl(api.uri),
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            )
          : const Icon(Icons.description_outlined);
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = (initialValue ?? [])
        .map<NcAttachedFile>(
          (e) => NcAttachedFile.fromJson(e),
        )
        .toList();
    return ListView(
      scrollDirection: Axis.horizontal,
      children: buildChildren(files),
    );
  }
}
