import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nocodb/features/core/pages/link_record.dart';
import 'package:nocodb/features/core/pages/project_list.dart';
import 'package:nocodb/features/core/pages/row_editor.dart';
import 'package:nocodb/features/core/pages/sheet.dart';
import 'package:nocodb/features/core/pages/sheet_selector.dart';
import 'package:nocodb/features/debug/debug.dart';
import 'package:nocodb/features/sign_in/pages/sign_in.dart';

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
  Widget build(final BuildContext context, final GoRouterState state) =>
      const SignInPage();
}

class ProjectListRoute extends GoRouteData {
  const ProjectListRoute();
  @override
  Widget build(final BuildContext context, final GoRouterState state) =>
      const ProjectListPage();
}

class SheetRoute extends GoRouteData {
  const SheetRoute();
  @override
  Widget build(final BuildContext context, final GoRouterState state) =>
      const SheetPage();
}

class SheetSelectorRoute extends GoRouteData {
  const SheetSelectorRoute();
  @override
  Widget build(final BuildContext context, final GoRouterState state) =>
      const SheetSelectorPage();
}

class RowEditorRoute extends GoRouteData {
  const RowEditorRoute({this.id});
  final String? id;

  @override
  Widget build(final BuildContext context, final GoRouterState state) =>
      ProviderScope(
        overrides: [
          formProvider.overrideWith((final ref) => {}),
        ],
        child: RowEditor(rowId_: id),
      );
}

class DebugRoute extends GoRouteData {
  const DebugRoute();
  @override
  Widget build(final BuildContext context, final GoRouterState state) =>
      const DebugPage();
}

class LinkRecordRoute extends GoRouteData {
  const LinkRecordRoute({
    required this.columnId,
    required this.rowId,
  });
  final String columnId;
  final String rowId;
  @override
  Widget build(final BuildContext context, final GoRouterState state) =>
      LinkRecordPage(
        columnId: columnId,
        rowId: rowId,
      );
}
