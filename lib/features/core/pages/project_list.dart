import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/features/core/components/dialog/new_project_dialog.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/routes.dart';

const _divider = Divider(height: 1);

class ProjectListPage extends HookConsumerWidget {
  const ProjectListPage({super.key});

  Widget _buildScaffold(Widget body) {
    final context = useContext();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
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

  Widget _build(List<NcProject> projects, WidgetRef ref) {
    final context = useContext();
    final content = Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
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

  @override
  Widget build(BuildContext context, WidgetRef ref) => _buildScaffold(
        ref.watch(projectListProvider).when(
              data: (data) => _build(data.list, ref),
              error: (error, stacktrace) => Text('$error\n$stacktrace'),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
      );
}
