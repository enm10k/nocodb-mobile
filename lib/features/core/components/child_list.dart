import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/components/scroll_detector.dart';
import 'package:nocodb/features/core/components/unlink_button.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/routes.dart';

class _Card extends HookConsumerWidget {
  const _Card({
    required this.refRowId,
    required this.value,
    required this.rowId,
    required this.column,
    required this.relation,
  });
  final String refRowId;
  final dynamic value;
  final String rowId;
  final NcTableColumn column;
  final NcTable relation;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => Card(
        child: Column(
          children: [
            ListTile(
              title: Text(value.toString()),
              subtitle: Text('PrimaryKey: $refRowId'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                UnlinkTextButton(
                  column: column,
                  rowId: rowId,
                  refRowId: refRowId,
                  relation: relation,
                ),
              ],
            ),
          ],
        ),
      );
}

class ChildList extends HookConsumerWidget {
  const ChildList({
    super.key,
    required this.rowId,
    required this.relation,
    required this.column,
  });
  final String rowId;
  final NcTable relation;
  final NcTableColumn column;

  static const debug = true;

  Widget _buildBase({
    required final Widget child,
    final Future<void> Function()? onEnd,
  }) {
    final context = useContext();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            child: Row(
              children: [
                Text(
                  column.title,
                  style: const TextStyle(
                    fontSize: 20,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                  ),
                ),
              ],
            ),
          ),
        ),
        ScrollDetector(
          onEnd: onEnd,
          child: Expanded(
            child: child,
          ),
        ),
        Material(
          elevation: 3,
          child: Row(
            children: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await RowEditorRoute(id: rowId).push(context);
                },
                child: const Text('Expand record'),
              ),
              const Spacer(),
              if (!column.isBelongsTo)
                TextButton(
                  onPressed: () async {
                    await LinkRecordRoute(
                      columnId: column.id,
                      rowId: rowId,
                    ).push(context);
                  },
                  child: const Text('Link record'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  _build({
    required final PrimaryRecordList list,
    required final WidgetRef ref,
  }) {
    final (records, pageInfo) = list;

    final children = records
        .map(
          (final record) {
            final (refRowId, value) = record;

            return _Card(
              refRowId: refRowId,
              value: value,
              rowId: rowId,
              column: column,
              relation: relation,
            );
          },
        )
        .whereNotNull()
        .toList();

    final context = useContext();

    return _buildBase(
      child: ListView(
        shrinkWrap: true,
        children: children,
      ),
      onEnd: () async {
        if (pageInfo?.isLastPage == true) {
          return;
        }
        context.loaderOverlay.show();
        await ref
            .watch(rowNestedProvider(rowId, column, relation).notifier)
            .load()
            .then((final _) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () {
              context.loaderOverlay.hide();
            },
          );
        });
      },
    );
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      ref.watch(rowNestedProvider(rowId, column, relation)).when(
            data: (final list) => list.$1.isEmpty
                ? _buildBase(
                    child: const Center(child: Text('No child records.')),
                  )
                : _build(list: list, ref: ref),
            error: (final error, final stackTrace) =>
                Center(child: Text('$error\n$stackTrace')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
}
