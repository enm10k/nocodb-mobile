import 'package:collection/collection.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attachments_provider.g.dart';

@riverpod
class Attachments extends _$Attachments {
  @override
  List<NcAttachedFile> build(
    String? rowId,
    String columnTitle,
  ) {
    final rows = ref.watch(dataRowsProvider).valueOrNull?.list ?? [];
    final table = ref.watch(tableProvider);
    final row = rows.firstWhereOrNull(
          (row) => table?.getPkFromRow(row) == rowId,
        ) ??
        {};

    final files = (row[columnTitle] ?? [])
        .map<NcAttachedFile>(
          (e) => NcAttachedFile.fromJson(e as Map<String, dynamic>),
        )
        .toList() as List<NcAttachedFile>;
    return files;
  }

  upload(List<NcFile> files, FnOnUpdate onUpdate) async {
    final newAttachedFiles = await api.dbStorageUpload(files);
    state = [
      ...state,
      ...newAttachedFiles,
    ];
    await onUpdate({columnTitle: state});
  }

  delete(String id, FnOnUpdate onUpdate) async {
    state = [...state].where((e) => e.id != id).toList();
    await onUpdate({columnTitle: state});
  }

  rename(String id, String title, FnOnUpdate onUpdate) async {
    state = [...state]
        .map<NcAttachedFile>(
          (e) => e.id == id ? e.copyWith(title: title) : e,
        )
        .toList();
    await onUpdate({columnTitle: state});
  }
}
