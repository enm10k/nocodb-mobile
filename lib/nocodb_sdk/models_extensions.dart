part of 'models.dart';

extension NctablesEx on NcTables {
  List<NcView> get views => table.views;
  List<NcTableColumn> get columns => table.columns;

  NcTable? getRelation(final String relatedTableId) =>
      relationMap[relatedTableId];
}

extension NcColOptionsEx on NcColOptions {
  Color? getOptionColor(final String title) {
    final colorCode = options
        ?.firstWhereOrNull((final option) => option.title == title)
        ?.color;

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
      RelationTypes.values.map((final e) => e.value).contains(type)
          ? RelationTypes.values
              .firstWhere((final relationType) => relationType.value == type)
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
    required final String modelTitle,
    required final String relatedModelTitle,
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

  NcViewColumn? toViewColumn(final List<NcViewColumn> viewColumns) =>
      viewColumns.firstWhereOrNull((final vc) => vc.fkColumnId == id);

  // ref: https://github.com/nocodb/nocodb/blob/fecc12a33ecee23d532b0981523dd6cb52671480/packages/nocodb-sdk/src/lib/helperFunctions.ts#L14-L21
  bool get isSystem =>
      uidt == UITypes.foreignKey ||
      ['created_at', 'updated_at'].contains(columnName) ||
      (pk && (ai || cdf != null)) ||
      (pk && meta?.containsKey('ag') == true) ||
      system;

  String? get singular => meta?['singular'];
  String? get plural => meta?['plural'];
}

extension NcTableEx on NcTable {
  NcTableColumn? getParentColumn(final String id) =>
      columns.firstWhereOrNull((final column) => column.fkChildColumnId == id);

  NcTableColumn? get pvColumn {
    final pvColumns = columns.where((final element) => element.pv);
    assert(pvColumns.length == 1);
    return pvColumns.firstOrNull;
  }

  String? get pvName => pvColumn?.title;

  dynamic getPvFromRow(final Map<String, dynamic> row) => row[pvColumn?.title];

  List<String> get pkNames =>
      columns.where((final c) => c.pk).map((final c) => c.title).toList();

  String? get pkName => pkNames.firstOrNull;

  List<String> get foreignKeys => columns
      .map((final column) => column.fkRelatedModelId)
      .whereNotNull()
      .toList();

  List<String> getPksFromRow(final Map<String, dynamic> row) => pkNames
      .map((final title) => row[title])
      .whereNotNull()
      .map((final v) => v.toString())
      .toList();

  String? getRefRowIdFromRow({
    required final NcTableColumn column,
    required final Map<String, dynamic> row,
  }) {
    final pks = getPksFromRow(row);
    logger.info(
      'column: ${column.title}, type: ${column.relationType}, pks: $pks',
    );

    // assert(column.isHasMay ? pks.length == 2 : pks.length == 1, 'pks: $pks');
    return column.isHasMay ? pks.join('___') : pks.firstOrNull;
  }

  dynamic getPkFromRow(final Map<String, dynamic> row) =>
      getPksFromRow(row).firstOrNull;

  List<NcTableColumn> get requiredColumns =>
      columns.where((final column) => column.rqd).toList();

  bool isReadyToSave(final List<String> keys) {
    // TODO: The condition for excluding columns needs improvement.
    if (requiredColumns.where((final c) => c.ai != true).isEmpty) {
      return true;
    }

    return requiredColumns
        .where((final c) => c.cdf == null)
        .every((final column) => keys.contains(column.title));
  }
}

extension NcViewColumnEx on NcViewColumn {
  NcTableColumn? toTableColumn(final List<NcTableColumn> tableColumns) =>
      tableColumns.firstWhereOrNull((final c) => c.id == fkColumnId);
}

extension NcViewColumnListEx on List<NcViewColumn> {
  List<NcViewColumn> getColumnsToShow(final NcTable table, final NcView view) =>
      where(
        (final column) {
          final tableColumn = column.toTableColumn(table.columns);
          final system = tableColumn?.isSystem ?? false;

          if (!view.showSystemFields && system == true) {
            return false;
          }

          return column.show;
        },
      ).toList();
}

extension NcAttachedFileEx on NcAttachedFile {
  // Use signedPath as id.
  String get id => signedPath;
  bool get isImage => mimetype.startsWith('image');

  String signedUrl(final Uri host) => host.replace(path: signedPath).toString();
}
