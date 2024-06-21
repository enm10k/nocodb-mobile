import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/components/scroll_detector.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/components/dialog/search_dialog.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class _Card extends HookConsumerWidget {
  const _Card({
    required this.refRowId,
    required this.pv,
    required this.rowId,
    required this.column,
    required this.relation,
  });
  final String refRowId;
  final dynamic pv;
  final String rowId;
  final NcTableColumn column;
  final NcTable relation;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: ListTile(
          title: Text(pv.toString()),
          subtitle: Text('PrimaryKey: $refRowId'),
          onTap: () async {
            await ref
                .read(
                  rowNestedProvider(rowId, column, relation, excluded: true)
                      .notifier,
                )
                .link(refRowId: refRowId)
                .then((msg) {
              notifySuccess(context, message: msg);
            }).onError(
              (error, stackTrace) => notifyError(context, error, stackTrace),
            );
          },
        ),
      );
}

class LinkRecordPage extends HookConsumerWidget {
  const LinkRecordPage({
    super.key,
    required this.columnId,
    required this.rowId,
  });
  final String columnId;
  final String rowId;

  static const debug = true;

  _build({
    required PrimaryRecordList list,
    required NcTable relation,
    required NcTableColumn column,
    required WidgetRef ref,
  }) {
    final (records, pageInfo) = list;
    final context = useContext();

    final children = records
        .map(
          (record) {
            final (key, value) = record;

            return _Card(
              refRowId: key,
              pv: value,
              rowId: rowId,
              column: column,
              relation: relation,
            );
          },
        )
        .whereNotNull()
        .toList();

    return ScrollDetector(
      onEnd: () async {
        if (pageInfo?.isLastPage == true) {
          return;
        }
        context.loaderOverlay.show();
        await ref
            .read(
              rowNestedProvider(rowId, column, relation, excluded: true)
                  .notifier,
            )
            .load()
            .then((_) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () {
              context.loaderOverlay.hide();
              logger.info('done');
            },
          );
        });
      },
      child: ListView(
        shrinkWrap: true,
        children: children,
      ),
    );
  }

  Scaffold _buildScaffold({
    required Widget body,
    required WidgetRef ref,
    required NcTable relation,
    required NcTableColumn column,
  }) {
    final context = useContext();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link record'),
        actions: [
          IconButton(
            onPressed: () async => showDialog(
              context: context,
              builder: (_) => LinkRecordSearchDialog(
                column: column,
                pvName: relation.pvName!,
              ),
            ),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: body,
    );
  }

  Scaffold _buildEmptyScaffold({
    required Widget body,
  }) =>
      Scaffold(
        appBar: AppBar(
          title: const Text('Link record'),
        ),
        body: body,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    if (tables == null) {
      return _buildEmptyScaffold(
        body: const Center(child: Text('Failed to load data.')),
      );
    }

    final column = tables.table.columnsById[columnId];
    if (column == null) {
      return _buildEmptyScaffold(
        body: Center(child: Text('Column for $columnId not found.')),
      );
    }
    final relation = tables.relationMap[column.fkRelatedModelId];

    if (relation == null) {
      return Center(
        child: Text(
          'relation not found. column: ${column.title}, relation_id: ${column.fkRelatedModelId}',
        ),
      );
    }

    final body = ref
        .watch(
          rowNestedProvider(
            rowId,
            column,
            relation,
            excluded: true,
          ),
        )
        .when(
          data: (list) {
            if (list.$1.isEmpty) {
              return const Center(child: Text('No record to link.'));
            }
            return _build(
              list: list,
              relation: relation,
              column: column,
              ref: ref,
            );
          },
          error: (error, stackTrace) => Center(
            child: Text('$error\n$stackTrace'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        );

    return _buildScaffold(
      body: body,
      relation: relation,
      ref: ref,
      column: column,
    );
  }
}
