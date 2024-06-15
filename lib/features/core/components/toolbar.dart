import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/components/not_implementing_dialog.dart';
import 'package:nocodb/features/core/components/dialog/fields_dialog.dart';
import 'package:nocodb/features/core/components/dialog/sort_dialog.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/routes.dart';

const double iconSize = 20;

class _FunctionButton extends HookConsumerWidget {
  const _FunctionButton({
    required this.title,
    required this.iconData,
    required this.onTap,
  });
  final String title;
  final IconData iconData;
  final Function()? onTap;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium,
              children: [
                WidgetSpan(
                  child: Icon(iconData, size: iconSize),
                ),
                TextSpan(text: ' $title'),
              ],
            ),
          ),
        ),
      );
}

class ProjectToolbar extends HookConsumerWidget {
  const ProjectToolbar({
    super.key,
    required this.project,
  });
  final NcProject project;

  Widget _buildToolbar(
    final WidgetRef ref,
    final ValueNotifier<bool> isExpanded,
  ) {
    final table = ref.watch(tableProvider);
    final view = ref.watch(viewProvider);
    if (table == null || view == null) {
      return const SizedBox();
    }

    final context = useContext();

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async => const SheetSelectorRoute().push(context),
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              alignment: Alignment.centerLeft,
              width: double.infinity,
              height: 40,
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleMedium,
                  children: [
                    TextSpan(text: table.title),
                    const TextSpan(text: ' / '),
                    const WidgetSpan(
                      child: Icon(Icons.table_view, size: iconSize),
                    ),
                    TextSpan(text: ' ${view.title}'),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            isExpanded.value = !isExpanded.value;
          },
          icon: const Icon(Icons.tune, size: iconSize),
        ),
      ],
    );
  }

  Widget _buildFunctionToolbar(final WidgetRef ref) {
    final context = useContext();
    return Row(
      children: [
        _FunctionButton(
          title: 'Fields',
          iconData: Icons.format_list_numbered,
          onTap: () async {
            await showDialog(
              context: context,
              builder: (final _) => const FieldsDialog(),
            );
          },
        ),
        _FunctionButton(
          title: 'Filter',
          iconData: Icons.filter_list,
          onTap: () async {
            await showDialog(
              context: context,
              builder: (final _) => const NotImplementedDialog(),
            );
          },
        ),
        _FunctionButton(
          title: 'Sort',
          iconData: Icons.sort,
          onTap: () async {
            await showDialog(
              context: context,
              builder: (final _) {
                final view = ref.watch(viewProvider);
                final table = ref.watch(tableProvider);
                if (view == null || table == null) {
                  return const SizedBox();
                }
                return SortDialog(view: view, table: table);
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final isExpanded = useState(false);
    return Material(
      elevation: 6,
      child: Column(
        children: [
          _buildToolbar(ref, isExpanded),
          if (isExpanded.value) _buildFunctionToolbar(ref),
        ],
      ),
    );
  }
}
