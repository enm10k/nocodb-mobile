import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '/features/core/providers/providers.dart';
import '../../../common/components/scroll_detector.dart';
import '../../../nocodb_sdk/models.dart';
import '../../../routes.dart';
import 'unlink_button.dart';

class _Card extends HookConsumerWidget {
  final String refRowId;
  final dynamic value;
  final String rowId;
  final NcTableColumn column;
  final NcTable relation;
  const _Card({
    required this.refRowId,
    required this.value,
    required this.rowId,
    required this.column,
    required this.relation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
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
}

class ChildList extends HookConsumerWidget {
  final String rowId;
  final NcTable relation;
  final NcTableColumn column;
  const ChildList({
    super.key,
    required this.rowId,
    required this.relation,
    required this.column,
  });

  static const debug = true;

  Widget _buildBase({
    required Widget child,
    Future<void> Function()? onEnd,
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
                onPressed: () {
                  Navigator.pop(context);
                  RowEditorRoute(id: rowId).push(context);
                },
                child: const Text('Expand record'),
              ),
              const Spacer(),
              if (!column.isBelongsTo)
                TextButton(
                  onPressed: () {
                    LinkRecordRoute(
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
    required PrimaryRecordList list,
    required WidgetRef ref,
  }) {
    final (records, pageInfo) = list;

    final children = records
        .map(
          (record) {
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
        ref
            .watch(rowNestedProvider(rowId, column, relation).notifier)
            .load()
            .then((_) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(rowNestedProvider(rowId, column, relation)).when(
          data: (list) {
            return list.$1.isEmpty
                ? _buildBase(
                    child: const Center(child: Text('No child records.')),
                  )
                : _build(list: list, ref: ref);
          },
          error: (error, stackTrace) =>
              Center(child: Text('$error\n$stackTrace')),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }
}
