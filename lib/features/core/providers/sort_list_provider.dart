import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sort_list_provider.g.dart';

@riverpod
class SortList extends _$SortList {
  @override
  FutureOr<NcSortList?> build(String viewId) async =>
      await api.dbTableSortList(viewId: viewId);

  Future<void> create({
    required String fkColumnId,
    required SortDirectionTypes direction,
  }) async {
    state = const AsyncLoading();
    await api.dbTableSortCreate(
      viewId: viewId,
      fkColumnId: fkColumnId,
      direction: direction,
    );

    final result = await api.dbTableSortList(viewId: viewId);
    state = AsyncData(result);
  }

  Future<void> delete(String sortId) async {
    state = const AsyncLoading();
    await api.dbTableSortDelete(sortId: sortId);
    ref.invalidateSelf();
  }

  Future<void> save({
    required String sortId,
    required String fkColumnId,
    required SortDirectionTypes direction,
  }) async {
    await api.dbTableSortUpdate(
      sortId: sortId,
      fkColumnId: fkColumnId,
      direction: direction,
    );
    ref.invalidateSelf();
  }
}
