import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

sealed class ProviderReader {
  T read<T>(ProviderListenable<T> provider);
}

class WidgetRefWrapper extends ProviderReader {
  WidgetRefWrapper(this.ref);
  final WidgetRef ref;
  @override
  T read<T>(ProviderListenable<T> provider) => ref.read(provider);
}

class ProviderContainerWrapper extends ProviderReader {
  ProviderContainerWrapper(this.c);
  final ProviderContainer c;
  @override
  T read<T>(ProviderListenable<T> provider) => c.read(provider);
}

FutureOr<T> errorAdapter<T>(Object error, StackTrace? stackTrace) {
  if (stackTrace != null) {
    Error.throwWithStackTrace(error, stackTrace);
  } else {
    throw error;
  }
}

Future<void> selectProject(WidgetRef ref, NcProject project) async {
  await _selectProject(WidgetRefWrapper(ref), project);
}

Future<void> selectTable(WidgetRef ref, NcTable table) async {
  await _selectTable(WidgetRefWrapper(ref), table);
}

Future<void> selectView(WidgetRef ref, NcView view) async {
  await _selectView(WidgetRefWrapper(ref), view);
}

Future<void> selectProject2(ProviderContainer c, NcProject project) async {
  await _selectProject(ProviderContainerWrapper(c), project);
}

Future<void> selectTable2(ProviderContainer c, NcTable table) async {
  await _selectTable(ProviderContainerWrapper(c), table);
}

Future<void> selectView2(ProviderContainer c, NcView view) async {
  await _selectView(ProviderContainerWrapper(c), view);
}

Future<void> _selectProject(ProviderReader reader, NcProject project) async {
  reader.read(projectProvider.notifier).state = project;

  final tableList = await api.dbTableList(projectId: project.id);
  final tableId = tableList.list.firstOrNull?.id;

  if (tableId == null) {
    return;
  }

  final table = await api.dbTableRead(tableId: tableId);
  await _selectTable(reader, table);
}

Future<void> _selectTable(ProviderReader reader, NcTable table) async {
  reader.read(tableProvider.notifier).state = table;

  final relationMap = await getRelations(table);
  reader.read(tablesProvider.notifier).state = NcTables(
    table: table,
    relationMap: relationMap,
  );
  final viewList = await api.dbViewList(tableId: table.id);
  final view = viewList.list.firstOrNull;

  if (view == null) {
    return;
  }
  await _selectView(reader, view);
}

Future<void> _selectView(ProviderReader reader, NcView view) async {
  reader.read(viewProvider.notifier).update(view);

  final table = reader.read(tableProvider);
  if (table == null) {
    return;
  }
  if (table.id != view.fkModelId) {
    final newTable = await api.dbTableRead(tableId: table.id);
    await _selectTable(reader, newTable);
  }
}
