import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/features/core/providers/providers.dart';
import '/nocodb_sdk/models.dart';
import '../../../common/settings.dart';
import '../../../routes.dart';
import '../components/dialog/new_project_dialog.dart';

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
                onTap: () {
                  settings
                      .clear()
                      .then((value) => const HomeRoute().push(context));
                },
              ),
            ],
          ),
          const PopupMenuDivider(),
          IconButton(
            onPressed: () {
              const DebugRoute().push(context);
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
              onTap: () {
                ref.read(projectProvider.notifier).state = project;
                const SheetRoute().push(context);
              },
            ),
          );
        },
        separatorBuilder: (context, index) {
          return _divider;
        },
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
            onTap: () {
              showDialog(
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
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildScaffold(
      ref.watch(projectListProvider).when(
            data: (data) {
              return _build(data.list, ref);
            },
            error: (error, stacktrace) {
              return Text('$error\n$stacktrace');
            },
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }
}
