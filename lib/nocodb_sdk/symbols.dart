enum ViewTypes {
  unknown(value: 0),
  form(value: 1),
  gallery(value: 2),
  grid(value: 3),
  kanban(value: 4);

  const ViewTypes({required this.value});
  final int value;
}

enum UITypes {
  id(value: 'ID'),
  links(value: 'Links'),
  linkToAnotherRecord(value: 'LinkToAnotherRecord'),
  foreignKey(value: 'ForeignKey'),
  lookup(value: 'Lookup'),
  singleLineText(value: 'SingleLineText'),
  longText(value: 'LongText'),
  attachment(value: 'Attachment'),
  checkbox(value: 'Checkbox'),
  multiSelect(value: 'MultiSelect'),
  singleSelect(value: 'SingleSelect'),
  collaborator(value: 'Collaborator'),
  date(value: 'Date'),
  year(value: 'Year'),
  time(value: 'Time'),
  phoneNumber(value: 'PhoneNumber'),
  email(value: 'Email'),
  url(value: 'URL'),
  number(value: 'Number'),
  decimal(value: 'Decimal'),
  currency(value: 'Currency'),
  percent(value: 'Percent'),
  duration(value: 'Duration'),
  rating(value: 'Rating'),
  formula(value: 'Formula'),
  rollup(value: 'Rollup'),
  count(value: 'Count'),
  dateTime(value: 'DateTime'),
  createTime(value: 'CreateTime'),
  lastModifiedTime(value: 'LastModifiedTime'),
  autoNumber(value: 'AutoNumber'),
  geometry(value: 'Geometry'),
  json(value: 'JSON'),
  barcode(value: 'Barcode'),
  button(value: 'Button'),
  unknown(value: 'unknown');

  const UITypes({required this.value});
  final String value;
}

enum RelationTypes {
  hasMany(value: 'hm'),
  manyToMany(value: 'mm'),
  belongsTo(value: 'bt'),
  unknown(value: 'unknown');

  const RelationTypes({required this.value});
  final String value;

  @override
  String toString() => value;
}

enum SortDirectionTypes {
  asc(value: 'asc'),
  desc(value: 'desc'),
  unknown(value: 'unknown');

  const SortDirectionTypes({required this.value});
  final String value;

  @override
  String toString() => value;
}

enum QueryOperator {
  eq(value: 'eq'),
  like(value: 'like');

  const QueryOperator({required this.value});
  final String value;

  String toDisplayString() {
    switch (this) {
      case QueryOperator.eq:
        return 'equal';
      case QueryOperator.like:
        return 'like';
    }
  }

  @override
  String toString() => value;
}

typedef Where = (String column, QueryOperator op, String query);

extension WhereEx on Where {
  // We cannot override toString for a Record type.
  // For details see: https://github.com/dart-lang/language/issues/2389
  String toString_() => '(${$1},${$2},${$3})';
}

typedef FnOnUpdate = Function(Map<String, dynamic>);
