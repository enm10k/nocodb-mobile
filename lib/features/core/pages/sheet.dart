import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/features/core/components/dialog/search_dialog.dart';
import 'package:nocodb/features/core/components/toolbar.dart';
import 'package:nocodb/features/core/components/view_switcher.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/routes.dart';

class BottomAppBarButton extends HookConsumerWidget {
  const BottomAppBarButton({
    super.key,
    required this.iconData,
    required this.onPressed,
  });
  final IconData iconData;
  final Function() onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        icon: Icon(
          iconData,
          color: Colors.white,
          size: 28,
        ),
        onPressed: onPressed,
      );
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
              onPressed: () async => const SheetSelectorRoute().push(context),
            ),
            BottomAppBarButton(
              iconData: Icons.add_circle_outline,
              onPressed: () async {
                await const RowEditorRoute().push(context);
              },
            ),
            BottomAppBarButton(
              iconData: Icons.search,
              onPressed: () async => showDialog(
                context: context,
                builder: (_) => const SheetSearchDialog(),
              ),
            ),
            BottomAppBarButton(
              iconData: Icons.refresh,
              onPressed: () async {
                try {
                  await ref.read(viewProvider.notifier).reload();
                } catch (error, stackTrace) {
                  if (context.mounted) {
                    notifyError(context, error, stackTrace);
                  }
                }
              },
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
        actions: const [],
        title: Text(project.title),
      ),
      body: Column(
        children: children,
      ),
      bottomNavigationBar: _buildBottomAppBar(ref),
    );
  }
}
