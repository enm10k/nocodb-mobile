import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/features/core/components/dialog/sort_dialog.dart';
import '/features/core/providers/providers.dart';
import '/nocodb_sdk/models.dart';
import '../../../common/components/not_implementing_dialog.dart';
import '../../../routes.dart';
import 'dialog/fields_dialog.dart';

const double iconSize = 20;

class _FunctionButton extends HookConsumerWidget {
  final String title;
  final IconData iconData;
  final Function()? onTap;
  const _FunctionButton({
    required this.title,
    required this.iconData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
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
}

class ProjectToolbar extends HookConsumerWidget {
  final NcProject project;
  const ProjectToolbar({
    super.key,
    required this.project,
  });

  Widget _buildToolbar(WidgetRef ref, ValueNotifier<bool> isExpanded) {
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
            onTap: () => const SheetSelectorRoute().push(context),
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

  Widget _buildFunctionToolbar(WidgetRef ref) {
    final context = useContext();
    return Row(
      children: [
        _FunctionButton(
          title: 'Fields',
          iconData: Icons.format_list_numbered,
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const FieldsDialog(),
            );
          },
        ),
        _FunctionButton(
          title: 'Filter',
          iconData: Icons.filter_list,
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const NotImplementedDialog(),
            );
          },
        ),
        _FunctionButton(
          title: 'Sort',
          iconData: Icons.sort,
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
