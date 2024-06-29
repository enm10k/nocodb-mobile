import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/components/not_implementing_dialog.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/fields_provider.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;

import 'package:nocodb/nocodb_sdk/models.dart';

class FieldsDialog extends HookConsumerWidget {
  const FieldsDialog({
    super.key,
  });
  static const debug = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }
    return ref.watch(fieldsProvider).when(
          data: (data) => _build(context, ref, data),
          error: (e, s) => Text('$e\n$s'),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }

  Widget _build(BuildContext context, WidgetRef ref, List<NcViewColumn> vcs) {
    final view = ref.watch(viewProvider)!;
    final table = ref.watch(tableProvider)!;
    final List<Widget> children = vcs.map(
      (vc) {
        final tc = vc.toTableColumn(table.columns)!;
        return CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          key: Key(vc.id),
          title:
              kDebugMode ? Text('${tc.title} (${vc.order})') : Text(tc.title),
          value: vc.show,
          onChanged: (value) async {
            try {
              await ref.read(fieldsProvider.notifier).show(vc, value == true);
            } catch (error, stackTrace) {
              if (context.mounted) {
                notifyError(context, error, stackTrace);
              }
            }
          },
        );
      },
    ).toList();

    logger.info('show_system_fields: ${view.showSystemFields}');

    return AlertDialog(
      title: const Text('Fields'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SizedBox(
              width: double.maxFinite,
              child: ReorderableListView(
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) async {
                  try {
                    await ref
                        .read(fieldsProvider.notifier)
                        .reorder(oldIndex, newIndex);
                  } catch (error, stackTrace) {
                    if (context.mounted) {
                      notifyError(context, error, stackTrace);
                    }
                  }
                },
                children: children,
              ),
            ),
          ),
          const Divider(
            thickness: 2,
          ),
          InkWell(
            onTap: () {
              ref.read(viewProvider.notifier).showSystemFields();
            },
            child: Row(
              children: [
                Checkbox(
                  value: view.showSystemFields,
                  onChanged: (value) {
                    ref.read(viewProvider.notifier).showSystemFields();
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text(
                  'Show system fields',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => const NotImplementedDialog(),
                  );
                },
                child: const Text('Show all'),
              ),
              TextButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => const NotImplementedDialog(),
                  );
                },
                child: const Text('Hide all'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
