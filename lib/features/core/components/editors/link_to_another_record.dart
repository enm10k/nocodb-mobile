import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/components/child_list.dart';
import 'package:nocodb/features/core/components/unlink_button.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class LinkToAnotherRecord extends HookConsumerWidget {
  const LinkToAnotherRecord({
    super.key,
    required this.column,
    required this.rowId,
    required this.relation,
    required this.initialValue,
  });
  final NcTableColumn column;
  final dynamic rowId;
  final NcTable relation;
  final dynamic initialValue;

  String? get pvName => relation.pvName;
  String? get pkName => relation.pkName;
  String get pk => initialValue[pkName].toString();
  String get pv => initialValue[pvName].toString();

  Widget _buildCard({
    required final String value,
    required final String refRowId,
    required final WidgetRef ref,
  }) =>
      Card(
        elevation: 4,
        child: ListTile(
          title: Text(value),
          subtitle: Text('key: $refRowId'),
          trailing: UnlinkIconButton(
            rowId: rowId,
            column: column,
            relation: relation,
            refRowId: refRowId,
          ),
        ),
      );

  List<Widget> _buildChildren({
    required final PrimaryRecordList list,
    required final WidgetRef ref,
  }) {
    final context = useContext();
    final (records, _) = list;

    return [
      ...records.map<Widget>((final record) {
        final (pk, pv) = record;
        return _buildCard(value: pv, refRowId: pk, ref: ref);
      }),
      if (9 < records.length)
        Card(
          elevation: 4,
          child: ListTile(
            title: const Text(
              'See more linked records.',
            ),
            leading: const Icon(Icons.open_in_new),
            onTap: () async {
              await showModalBottomSheet(
                isScrollControlled: true,
                context: context,
                builder: (final context) => ChildList(
                  column: column,
                  rowId: rowId!,
                  relation: relation,
                ),
              );
            },
          ),
        ),
    ];
  }

  _buildEmptyCard() => const Card(
        elevation: 4,
        child: ListTile(title: Text('No record linked yet.')),
      );

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    assert(!column.isBelongsTo);

    if (rowId == null) {
      return _buildEmptyCard();
    }
    final child = ref
        .watch(
          rowNestedProvider(
            rowId,
            column,
            relation,
          ),
        )
        .when(
          data: (final list) => list.$1.isEmpty
              ? _buildEmptyCard()
              : ListView(
                  shrinkWrap: true,
                  children: _buildChildren(list: list, ref: ref),
                ),
          error: (final error, final stackTrace) =>
              Center(child: Text('$error\n$stackTrace')),
          loading: () => const CircularProgressIndicator(),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Scrollbar(
        child: child,
      ),
    );
  }
}
