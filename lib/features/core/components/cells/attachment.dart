import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class Attachment extends HookConsumerWidget {
  const Attachment(this.initialValue, {super.key});
  final dynamic initialValue;

  List<Widget> buildChildren(final List<NcAttachedFile> files) => files
      .map(
        (final file) => file.isImage
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: CachedNetworkImage(
                  imageUrl: file.signedUrl(api.uri),
                  placeholder: (final context, final url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (final context, final url, final error) =>
                      const Icon(Icons.error),
                ),
              )
            : const Icon(Icons.description_outlined),
      )
      .toList();

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final files = (initialValue ?? [])
        .map<NcAttachedFile>(
          (final c) => NcAttachedFile.fromJson(c),
        )
        .toList();
    return ListView(
      scrollDirection: Axis.horizontal,
      children: buildChildren(files),
    );
  }
}
