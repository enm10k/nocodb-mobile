import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:nocodb/nocodb_sdk/models.dart';

class Attachment extends HookConsumerWidget {
  const Attachment(this.initialValue, {super.key});
  final dynamic initialValue;

  List<Widget> buildChildren(List<NcAttachedFile> files) => files
      .map(
        (file) => file.isImage
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: CachedNetworkImage(
                  // imageUrl: file.getFullUrl(api.uri),
                  imageUrl: file.signedUrl,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              )
            : const Icon(Icons.description_outlined),
      )
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = (initialValue ?? [])
        .map<NcAttachedFile>(
          (c) => NcAttachedFile.fromJson(c),
        )
        .toList();
    return ListView(
      scrollDirection: Axis.horizontal,
      children: buildChildren(files),
    );
  }
}
