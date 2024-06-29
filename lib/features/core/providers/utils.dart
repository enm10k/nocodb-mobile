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

// NOTE: If an error or exception occurs within a provider,
// it will be handled as an AsyncError by the side using the provider.
FutureOr<T> unwrap<T>(Result<T> result) => result.when(
      ok: (ok) => ok,
      ng: errorAdapter,
    );

FutureOr<T2> serialize<T1, T2>(
  Result<T1> result, {
  required T2 Function(T1) fn,
}) =>
    result.when(
      ok: (ok) => fn(ok),
      ng: errorAdapter,
    );

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

  final tableId = await serialize(
    await api.dbTableList(projectId: project.id),
    fn: (data) => data.list.firstOrNull?.id,
  );

  if (tableId == null) {
    return;
  }

  final table = await unwrap(await api.dbTableRead(tableId: tableId));
  await _selectTable(reader, table);
}

Future<void> _selectTable(ProviderReader reader, NcTable table) async {
  reader.read(tableProvider.notifier).state = table;

  final relationMap = await getRelations(table);
  reader.read(tablesProvider.notifier).state = NcTables(
    table: table,
    relationMap: relationMap,
  );

  final view = await serialize(
    await api.dbViewList(tableId: table.id),
    fn: (data) => data.list.firstOrNull,
  );
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
    final newTable = await unwrap(await api.dbTableRead(tableId: table.id));
    await _selectTable(reader, newTable);
  }
}
