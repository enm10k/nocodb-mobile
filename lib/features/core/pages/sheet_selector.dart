import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class SheetSelectorPage extends HookConsumerWidget {
  const SheetSelectorPage({super.key});

  Widget Function(
    BuildContext,
    int,
  ) _viewBuilder({
    required final List<NcSlimTable> tables,
    required final WidgetRef ref,
  }) =>
      (final context, final index) {
        final viewId = ref.watch(viewProvider)?.id;
        final table = tables[index];
        return ref.watch(viewListProvider(table.id)).when(
              data: (final views) => ListView.separated(
                separatorBuilder: (final context, final index) => const Divider(
                  height: 2,
                ),
                itemBuilder: (final context, final index) {
                  final view = views.list[index];
                  return ListTile(
                    title: Text(view.title),
                    subtitle: Text('type: ${view.type.name}'),
                    selected: view.id == viewId,
                    onTap: () {
                      ref.read(viewProvider.notifier).set(view);
                      Navigator.pop(context);
                    },
                  );
                },
                itemCount: views.list.length,
              ),
              error: (final error, final stackTrace) {
                notifyError(context, error, stackTrace);
                return const SizedBox();
              },
              loading: () => const CircularProgressIndicator(),
            );
      };

  Widget _buildDrawer({
    required final List<NcSlimTable> tables,
    required final String tableId,
    required final PageController controller,
  }) {
    final context = useContext();
    return Drawer(
      child: ListView(
        children: tables
            .map(
              (final table) => ListTile(
                title: Text(table.title),
                selected: table.id == tableId,
                onTap: () {
                  final index =
                      tables.map((final t) => t.id).toList().indexOf(table.id);
                  controller.jumpToPage(index);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  DefaultTabController _build({
    required final List<NcSlimTable> tables,
    required final WidgetRef ref,
    required final NcProject project,
  }) {
    final tableId = ref.watch(tableProvider)?.id ?? '';
    final initialIndex =
        tables.map((final table) => table.id).toList().indexOf(tableId);
    logger
      ..info('tableId: $tableId')
      ..info('initialIndex: $initialIndex');

    final tabController = useTabController(
      initialLength: tables.length,
      initialIndex: initialIndex,
    );
    final pageController = usePageController(
      initialPage: initialIndex,
    );

    final context = useContext();

    return DefaultTabController(
      length: tables.length,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(project.title),
          bottom: TabBar(
            onTap: (final index) {
              logger.info('TabBar.onTap: $index');
              pageController.jumpToPage(index);
            },
            controller: tabController,
            isScrollable: true,
            tabs: tables.map((final table) => Tab(text: table.title)).toList(),
          ),
        ),
        body: PageView.builder(
          onPageChanged: (final index) async {
            logger.info('PageView.onPageChanged: $index');
            tabController.animateTo(index);

            final table = tables[index];
            await api.dbTableRead(tableId: table.id).then((final table) {
              ref.watch(viewProvider.notifier).set(table.views.first);
            }).onError(
              (final error, final stackTrace) =>
                  notifyError(context, error, stackTrace),
            );
          },
          controller: pageController,
          itemBuilder: _viewBuilder(
            ref: ref,
            tables: tables,
          ),
        ),
        floatingActionButton: Builder(
          builder: (final context) => FloatingActionButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: const Icon(Icons.list),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        drawer: _buildDrawer(
          tables: tables,
          tableId: tableId,
          controller: pageController,
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final project = ref.watch(projectProvider);
    if (project == null) {
      return const SizedBox();
    }
    return ref.watch(tableListProvider(project.id)).when(
          data: (final list) => _build(
            tables: list.list,
            ref: ref,
            project: project,
          ),
          error: (final error, final stackTrace) {
            notifyError(context, error, stackTrace);
            return const SizedBox();
          },
          loading: () => const CircularProgressIndicator(),
        );
  }
}
