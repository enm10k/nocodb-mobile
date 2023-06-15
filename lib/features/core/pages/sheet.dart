import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/features/core/components/view_switcher.dart';
import '/features/core/providers/providers.dart';
import '../../../routes.dart';
import '../components/dialog/search_dialog.dart';
import '../components/toolbar.dart';

class BottomAppBarButton extends HookConsumerWidget {
  final IconData iconData;
  final Function() onPressed;
  const BottomAppBarButton({
    super.key,
    required this.iconData,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        iconData,
        color: Colors.white,
        size: 28,
      ),
      onPressed: onPressed,
    );
  }
}

class SheetPage extends HookConsumerWidget {
  const SheetPage({super.key});

  Widget _buildBottomAppBar(WidgetRef ref) {
    final context = useContext();
    return BottomAppBar(
      height: 48,
      elevation: 24,
      color: Theme.of(context).primaryColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            BottomAppBarButton(
              iconData: Icons.menu,
              onPressed: () => const SheetSelectorRoute().push(context),
            ),
            BottomAppBarButton(
              iconData: Icons.add_circle_outline,
              onPressed: () {
                final table = ref.watch(tableProvider);
                final view = ref.watch(viewProvider);
                if (table == null || view == null) {
                  return;
                }

                const RowEditorRoute().push(context);
              },
            ),
            BottomAppBarButton(
              iconData: Icons.search,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const SheetSearchDialog(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    if (project == null) {
      return const CircularProgressIndicator();
    }
    final children = [
      ProjectToolbar(project: project),
      const Expanded(
        // child: Align(
        // alignment: Alignment.topLeft,
        child: ViewSwitcher(),
        // ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: const [
          // ReloadButton(),
        ],
        title: Text(project.title),
      ),
      body: Column(
        children: children,
      ),
      bottomNavigationBar: _buildBottomAppBar(ref),
    );
  }
}
