import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/core/pages/link_record.dart';
import 'features/core/pages/project_list.dart';
import 'features/core/pages/row_editor.dart';
import 'features/core/pages/sheet.dart';
import 'features/core/pages/sheet_selector.dart';
import 'features/debug/debug.dart';
import 'features/sign_in/pages/sign_in.dart';

part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: <TypedGoRoute<GoRouteData>>[
    TypedGoRoute<ProjectListRoute>(
      path: 'project_list',
    ),
    TypedGoRoute<SheetRoute>(
      path: 'sheet',
    ),
    TypedGoRoute<SheetSelectorRoute>(
      path: 'sheet/selector',
    ),
    TypedGoRoute<RowEditorRoute>(
      path: 'row',
    ),
    TypedGoRoute<DebugRoute>(
      path: 'debug',
    ),
    TypedGoRoute<LinkRecordRoute>(
      path: 'sheet/link_record/:columnId/:rowId',
    ),
  ],
)
class HomeRoute extends GoRouteData {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const SignInPage();
}

class ProjectListRoute extends GoRouteData {
  const ProjectListRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProjectListPage();
}

class SheetRoute extends GoRouteData {
  const SheetRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const SheetPage();
}

class SheetSelectorRoute extends GoRouteData {
  const SheetSelectorRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SheetSelectorPage();
}

class RowEditorRoute extends GoRouteData {
  final String? id;
  const RowEditorRoute({this.id});

  @override
  Widget build(BuildContext context, GoRouterState state) => ProviderScope(
        overrides: [
          formProvider.overrideWith((ref) => {}),
        ],
        child: RowEditor(rowId_: id),
      );
}

class DebugRoute extends GoRouteData {
  const DebugRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const DebugPage();
}

class LinkRecordRoute extends GoRouteData {
  final String columnId;
  final String rowId;
  const LinkRecordRoute({
    required this.columnId,
    required this.rowId,
  });
  @override
  Widget build(BuildContext context, GoRouterState state) => LinkRecordPage(
        columnId: columnId,
        rowId: rowId,
      );
}
