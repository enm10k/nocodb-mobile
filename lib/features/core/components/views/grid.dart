import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '/features/core/providers/providers.dart';
import '/nocodb_sdk/models.dart' as model;
import '/nocodb_sdk/symbols.dart';
import '../../../../common/components/scroll_detector.dart';
import '../../../../common/extensions.dart';
import '../../../../common/logger.dart';
import '../cell.dart';

class Grid extends HookConsumerWidget {
  const Grid({
    super.key,
  });

  static const double _dataColumnWidth = 140;
  static const double _blankDataColumnWidth = 140;
  static const _blankDataColumn = DataColumn2(
    label: Text(''),
    fixedWidth: _blankDataColumnWidth,
  );

  static const _blankDataCell = DataCell(SizedBox());

  List<DataCell> _buildDataCellList(
    Map<String, dynamic> row,
    List<model.NcTableColumn> columns,
    model.NcTables tableMeta,
    WidgetRef ref,
    int blankLength,
  ) {
    // TODO: Some child tables don't have a primary key.
    // TODO: Stop changing the type of primary key.
    final context = useContext();

    final pkId = tableMeta.table.getPkFromRow(row).toString();
    final cells = columns.map((column) {
      final value = row[column.title];

      return Cell(
        rowId: pkId,
        column: column,
        value: value,
        context: context,
        ref: ref,
      ).build();
    }).toList();

    return cells
      ..addAll(
        List.generate(blankLength, (index) => _blankDataCell),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }

    final tables = ref.watch(tablesProvider)!;
    final view = ref.watch(viewProvider)!;

    final columns = ref.watch(fieldsProvider(view)).valueOrNull?.toList() ?? [];
    logger.info('view: ${view.title} has ${columns.length} columns(s).');
    logger.info('columns: ${columns.map((e) => e.title).toList()}');

    final dataRow = ref.watch(dataRowsProvider).valueOrNull;
    final rows = dataRow?.list ?? [];

    if (columns.isEmpty) {
      return const Center(
        child: Text('No columns.'),
      );
    }

    if (rows.isEmpty) {
      return const Center(
        child: Text('Empty.'),
      );
    }

    final dataColumns = columns.map((c) {
      final type = [UITypes.links, UITypes.linkToAnotherRecord].contains(c.uidt)
          ? c.relationType.value
          : c.uidt.value.capitalize();
      return DataColumn2(
        fixedWidth: _dataColumnWidth,
        label: Text(
          '${c.title}\n$type',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    final tableWidth = dataColumns
        .map((c) => c.fixedWidth)
        .whereNotNull()
        .reduce((a, b) => a + b);

    final w = PlatformDispatcher.instance.views.first;
    final size = w.physicalSize / w.devicePixelRatio;
    final screenWidth = size.width;
    final blankLength = tableWidth < screenWidth
        ? ((size.width - tableWidth) ~/ _blankDataColumnWidth) + 1
        : 0;
    logger.fine('tableWidth: $tableWidth, screenWidth: $screenWidth');

    if (0 < blankLength) {
      logger.info(
        'add $blankLength blank column(s) to adjust the spacing.',
      );
    }

    final dataRows = rows.map(
      (row) => DataRow2(
        cells: _buildDataCellList(
          row,
          columns,
          tables,
          ref,
          blankLength,
        ).toList(),
      ),
    );

    dataColumns.addAll(
      List.generate(blankLength, (i) => _blankDataColumn),
    );

    final adjustedMinWidth = dataColumns
        .map((c) => c.fixedWidth)
        .whereNotNull()
        .reduce((a, b) => a + b);

    final table = DataTable2(
      checkboxHorizontalMargin: 0,
      columnSpacing: 24,
      horizontalMargin: 24,
      dividerThickness: 1,
      showBottomBorder: true,
      border: TableBorder.all(
        width: 0.1,
      ),
      columns: dataColumns,
      rows: dataRows.toList(),
      // FIXME: Without adjusting minWidth, the following assertion error occurs.
      // ======== Exception caught by widgets library =======================================================
      // The following assertion was thrown building SyncedScrollControllers(dependencies: [ScrollConfiguration, _InheritedTheme, _LocalizationsScope-[GlobalKey#fb890]], state: SyncedScrollControllersState#aa918):
      // DataTable2, combined width of columns of fixed width is greater than availble parent width. Table will be clipped
      // 'package:data_table_2/src/data_table_2.dart':
      // Failed assertion: line 1133 pos 12: 'totalFixedWidth < totalColAvailableWidth'
      //
      // The relevant error-causing widget was:
      // ...
      minWidth: adjustedMinWidth + 50,
    );

    return ScrollDetector(
      child: table,
      onEnd: () async {
        context.loaderOverlay.show();

        await ref.read(dataRowsProvider.notifier).loadNextPage().then(
              (_) => Future.delayed(
                const Duration(milliseconds: 500),
                () => context.loaderOverlay.hide(),
              ),
            );
      },
    );
  }
}
