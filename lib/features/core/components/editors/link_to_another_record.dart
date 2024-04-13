import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../nocodb_sdk/models.dart';
import '../../providers/providers.dart';
import '../child_list.dart';
import '../unlink_button.dart';

class LinkToAnotherRecord extends HookConsumerWidget {
  final NcTableColumn column;
  final dynamic rowId;
  final NcTable relation;
  final dynamic initialValue;
  const LinkToAnotherRecord({
    super.key,
    required this.column,
    required this.rowId,
    required this.relation,
    required this.initialValue,
  });

  String? get pvName => relation.pvName;
  String? get pkName => relation.pkName;
  String get pk => initialValue[pkName].toString();
  String get pv => initialValue[pvName].toString();

  Widget _buildCard({
    required String value,
    required String refRowId,
    required WidgetRef ref,
  }) {
    return Card(
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
  }

  List<Widget> _buildChildren({
    required PrimaryRecordList list,
    required WidgetRef ref,
  }) {
    final context = useContext();
    final (records, _) = list;

    return [
      ...records.map<Widget>((record) {
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
            onTap: () {
              showModalBottomSheet(
                isScrollControlled: true,
                context: context,
                builder: (context) {
                  return ChildList(
                    column: column,
                    rowId: rowId!,
                    relation: relation,
                  );
                },
              );
            },
          ),
        ),
    ];
  }

  _buildEmptyCard() {
    return const Card(
      elevation: 4,
      child: ListTile(title: Text('No record linked yet.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          data: (list) {
            return list.$1.isEmpty
                ? _buildEmptyCard()
                : ListView(
                    shrinkWrap: true,
                    children: _buildChildren(list: list, ref: ref),
                  );
          },
          error: (error, stackTrace) {
            return Center(child: Text('$error\n$stackTrace'));
          },
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
