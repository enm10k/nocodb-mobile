import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/features/core/components/dialog/new_project_dialog.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/routes.dart';

const _divider = Divider(height: 1);

class _ProjectList extends HookConsumerWidget {
  const _ProjectList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    return ref.watch(baseListProvider(workspace!.id)).when(
          data: (data) => _build(ref, data),
          error: (e, s) => Text('$e\n$s'),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }

  Widget _build(WidgetRef ref, NcProjectList projectList) {
    final context = useContext();
    // TODO: Pagination
    final content = Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: projectList.list.length,
        itemBuilder: (context, index) {
          final project = projectList.list[index];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: ListTile(
              title: Text(project.title),
              onTap: () async {
                await selectProject(ref, project).then(
                  (data) async => await const SheetRoute().push(context),
                );
              },
            ),
          );
        },
        separatorBuilder: (context, index) => _divider,
      ),
    );

    return Column(
      children: [
        content,
        _divider,
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: ListTile(
            title: const Text('New Project'),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (_) => const NewProjectDialog(),
              );
            },
          ),
        ),
        _divider,
      ],
    );
  }
}

class CloudProjectListPage extends HookConsumerWidget {
  const CloudProjectListPage({super.key});

  Widget _buildScaffold(
    WidgetRef ref,
    Widget body,
    NcList<NcWorkspace> workspaceList,
  ) {
    final workspace = ref.watch(workspaceProvider);
    final context = useContext();
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<NcWorkspace>(
          items: workspaceList.list
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text('${e.title} (${e.id})'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(workspaceProvider.notifier).state = value;
            }
          },
          value: workspace,
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (context) => <PopupMenuEntry>[
              PopupMenuItem(
                child: const ListTile(
                  title: Text('Logout'),
                ),
                onTap: () async {
                  await settings
                      .clear()
                      .then((value) => const HomeRoute().push(context));
                },
              ),
            ],
          ),
          const PopupMenuDivider(),
          IconButton(
            onPressed: () async {
              await const DebugRoute().push(context);
            },
            icon: const Icon(Icons.bug_report),
          ),
        ],
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(workspaceListProvider).when(
            data: (data) => _buildScaffold(ref, const _ProjectList(), data),
            error: (e, s) => Center(child: Text('$e\n$s')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
}
