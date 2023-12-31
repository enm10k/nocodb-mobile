import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/nocodb_sdk/models.dart' as model;
import '/nocodb_sdk/symbols.dart';
import '../../../common/flash_wrapper.dart';
import '../../../nocodb_sdk/models.dart';
import '../../../routes.dart';
import '../components/editor.dart';
import '../providers/providers.dart';

final formProvider =
    StateProvider<Map<String, dynamic>>((ref) => throw UnimplementedError());

bool isEditable(model.NcTableColumn column, bool isNew) =>
    !((!isNew && column.pk) || column.ai);

Widget _buildTitle({
  required model.NcTables tables,
  required model.NcTableColumn column,
  required String? rowId,
}) {
  final context = useContext();
  final required = column.rqd ? '(required)' : '';

  final relatedModel = tables.getRelation(column.fkRelatedModelId ?? '');
  final description =
      column.uidt == UITypes.linkToAnotherRecord && relatedModel != null
          ? column.getRelationDescription(
              modelTitle: tables.table.title,
              relatedModelTitle: relatedModel.title,
            )
          : column.uidt.value;

  return ListTile(
    tileColor: Colors.grey.shade200,
    horizontalTitleGap: 0,
    minVerticalPadding: 0,
    title: Text(
      '${column.title} $required',
    ),
    subtitle: Text('$description'),
    trailing: column.uidt == UITypes.linkToAnotherRecord
        ? IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {
              if (rowId == null) {
                showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Record Link Error'),
                    content: Text(
                      'Please enter other fields to save the record before linking.',
                    ),
                  ),
                );
              } else {
                LinkRecordRoute(columnId: column.id, rowId: rowId)
                    .push(context);
              }
            },
          )
        : null,
  );
}

class RowEditor extends HookConsumerWidget {
  final String? rowId_;

  const RowEditor({
    super.key,
    this.rowId_,
  });

  int _getViewColumnOrder(
    NcTableColumn tableColumn,
    List<NcViewColumn> viewColumns,
  ) =>
      tableColumn.toViewColumn(viewColumns)?.order ?? 0;

  List<Widget> _buildForm({
    required model.NcView view,
    required model.NcTables tables,
    required WidgetRef ref,
    required BuildContext context,
    required String? rowId,
  }) {
    final rowData =
        rowId != null ? ref.watch(dataRowProvider(view, rowId)) : {};

    final viewColumns = ref.watch(viewColumnListProvider(view.id)).valueOrNull;
    assert(viewColumns != null);
    if (viewColumns == null) {
      return const [SizedBox()];
    }
    // assert(tables.table.columns.length == viewColumns.length);

    final filtered = tables.table.columns.where((c) => !c.isSystem);

    // The required columns should be displayed at the top.
    final rqds = filtered.where((c) => c.rqd).toList();
    rqds.sort(
      (a, b) => _getViewColumnOrder(a, viewColumns).compareTo(
        _getViewColumnOrder(b, viewColumns),
      ),
    );

    final optionals = filtered.where((c) => !c.rqd).toList();
    optionals.sort(
      (a, b) => _getViewColumnOrder(a, viewColumns)
          .compareTo(_getViewColumnOrder(b, viewColumns)),
    );

    return [...rqds, ...optionals].map((c) {
      final initialValue = rowData?[c.title];

      return Column(
        children: [
          _buildTitle(
            tables: tables,
            column: c,
            rowId: rowId,
          ),
          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          Editor(
            column: c,
            value: initialValue,
            rowId: rowId,
          ),
          const Divider(
            color: Colors.grey,
            height: 1,
          ),
        ],
      );
    }).toList();
  }

  Widget _buildDeleteButton({
    required NcView view,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return IconButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete'),
              content: const Text(
                'Are you sure want to delete this record?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref
                        .watch(dataRowsProvider(view).notifier)
                        .deleteRow(rowId: rowId_!)
                        .then(
                          (_) => Navigator.pop(context),
                        )
                        .onError(
                          (error, stackTrace) => notifyError(
                            context,
                            error,
                            stackTrace,
                          ),
                        );
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
      icon: const Icon(
        Icons.delete,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final tables = ref.watch(tablesProvider);
    if (view == null || tables == null) {
      return const SizedBox();
    }

    final rowId = useState<String?>(rowId_);

    ref.listen(formProvider, (previous, next) {
      if (next.isEmpty) {
        return;
      }

      final keys = next.keys.toList();
      final isReadyToSave = tables.table.isReadyToSave(keys);

      if (isReadyToSave) {
        // TODO: This should be passed to Editor as a callback of onUpdate,
        ref.read(dataRowsProvider(view).notifier).createRow(next).then((row) {
          notifySuccess(context, message: 'Saved');
          final pk = tables.table.getPkFromRow(row);
          rowId.value = pk;
        }).onError(
          (error, stackTrace) => notifyError(context, error, stackTrace),
        );
      }
    });

    final title = '${tables.table.title} - ${rowId.value ?? ''}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (rowId.value != null)
            _buildDeleteButton(view: view, context: context, ref: ref),
        ],
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ..._buildForm(
                  view: view,
                  tables: tables,
                  ref: ref,
                  context: context,
                  rowId: rowId.value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
