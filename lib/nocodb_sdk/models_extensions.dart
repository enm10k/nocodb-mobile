part of 'models.dart';

extension NctablesEx on NcTables {
  List<NcView> get views => table.views;
  List<NcTableColumn> get columns => table.columns;

  NcTable? getRelation(String relatedTableId) {
    return relationMap[relatedTableId];
  }
}

extension NcColOptionsEx on NcColOptions {
  Color? getOptionColor(String title) {
    final colorCode =
        options?.firstWhereOrNull((option) => option.title == title)?.color;

    if (colorCode == null) {
      return null;
    }
    assert(colorCode.length == 7); // #cfdffe

    return Color(
      int.parse('FF${colorCode.substring(1)}', radix: 16),
    );
  }
}

extension NcTableColumnEx on NcTableColumn {
  String? get type => colOptions?.type;

  RelationTypes get relationType =>
      RelationTypes.values.map((e) => e.value).contains(type)
          ? RelationTypes.values
              .firstWhere((relationType) => relationType.value == type)
          : RelationTypes.unknown;

  String? get fkRelatedModelId => colOptions?.fkRelatedModelId;
  String? get fkChildColumnId => colOptions?.fkChildColumnId;
  String? get fkParentColumnId => colOptions?.fkParentColumnId;

  bool get isHasMay => type == RelationTypes.hasMany.value;
  bool get isManyToMany => type == RelationTypes.manyToMany.value;
  bool get isBelongsTo => type == RelationTypes.belongsTo.value;

  bool get isLookup => uidt == UITypes.lookup;
  bool get isRollup => uidt == UITypes.rollup;
  bool get isFormula => uidt == UITypes.formula;
  bool get isCount => uidt == UITypes.count;

  String? getRelationDescription({
    required String modelTitle,
    required String relatedModelTitle,
  }) {
    switch (relationType) {
      case RelationTypes.hasMany:
        return "'$modelTitle' has many '$relatedModelTitle'";
      case RelationTypes.manyToMany:
        return "'$modelTitle' and '$relatedModelTitle' have many to many relation";
      case RelationTypes.belongsTo:
        return '$modelTitle belongs to $relatedModelTitle';
      case RelationTypes.unknown:
        return 'unknown relation type';
    }
  }

  NcViewColumn? toViewColumn(List<NcViewColumn> viewColumns) =>
      viewColumns.firstWhereOrNull((vc) => vc.fkColumnId == id);

  // ref: https://github.com/nocodb/nocodb/blob/fecc12a33ecee23d532b0981523dd6cb52671480/packages/nocodb-sdk/src/lib/helperFunctions.ts#L14-L21
  bool get isSystem =>
      uidt == UITypes.foreignKey ||
      ['created_at', 'updated_at'].contains(columnName) ||
      (pk && (ai || cdf != null)) ||
      (pk && meta?.containsKey('ag') == true) ||
      system;
}

extension NcTableEx on NcTable {
  NcTableColumn? getParentColumn(String id) {
    return columns.firstWhereOrNull((column) => column.fkChildColumnId == id);
  }

  NcTableColumn? get pvColumn {
    final pvColumns = columns.where((element) => element.pv);
    assert(pvColumns.length == 1);
    return pvColumns.firstOrNull;
  }

  String? get pvName => pvColumn?.title;

  dynamic getPvFromRow(Map<String, dynamic> row) => row[pvColumn?.title];

  List<String> get pkNames =>
      columns.where((c) => c.pk).map((c) => c.title).toList();

  String? get pkName => pkNames.firstOrNull;

  List<String> get foreignKeys =>
      columns.map((column) => column.fkRelatedModelId).whereNotNull().toList();

  List<String> getPksFromRow(Map<String, dynamic> row) => pkNames
      .map((title) => row[title])
      .whereNotNull()
      .map((v) => v.toString())
      .toList();

  String? getRefRowIdFromRow({
    required NcTableColumn column,
    required Map<String, dynamic> row,
  }) {
    final pks = getPksFromRow(row);
    logger.info(
      'column: ${column.title}, type: ${column.relationType}, pks: $pks',
    );

    // assert(column.isHasMay ? pks.length == 2 : pks.length == 1, 'pks: $pks');
    return column.isHasMay ? pks.join('___') : pks.firstOrNull;
  }

  dynamic getPkFromRow(Map<String, dynamic> row) =>
      getPksFromRow(row).firstOrNull;

  List<NcTableColumn> get requiredColumns =>
      columns.where((column) => column.rqd).toList();

  bool isReadyToSave(List<String> keys) => requiredColumns
      .where((c) => c.cdf == null)
      .every((column) => keys.contains(column.title));
}

extension NcViewColumnEx on NcViewColumn {
  NcTableColumn? toTableColumn(List<NcTableColumn> tableColumns) =>
      tableColumns.firstWhereOrNull((c) => c.id == fkColumnId);
}

extension NcViewColumnListEx on List<NcViewColumn> {
  List<NcViewColumn> getColumnsToShow(NcTable table, NcView view) {
    return where(
      (column) {
        final tableColumn = column.toTableColumn(table.columns);
        final system = tableColumn?.isSystem ?? false;

        if (!view.showSystemFields && system == true) {
          return false;
        }

        return column.show;
      },
    ).toList();
  }
}
