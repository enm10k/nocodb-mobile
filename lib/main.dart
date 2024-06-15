import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/router.dart';
import 'package:stack_trace/stack_trace.dart';

const useMaterial3 = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(
    debug: true,
    ignoreSsl: true,
  );
  // https://api.flutter.dev/flutter/foundation/FlutterError/demangleStackTrace.html
  FlutterError.demangleStackTrace = (final stack) {
    // Trace and Chain are classes in package:stack_trace
    if (stack is Trace) {
      return stack.vmTrace;
    }
    if (stack is Chain) {
      return stack.toTrace().vmTrace;
    }
    return stack;
  };

  // WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

setUpProviderListeners(final WidgetRef ref) {
  ref
    ..listen(projectProvider, (final previous, final next) async {
      logger.info('projectProvider is changed. prev: $previous, next: $next');
      if (next == null) {
        return;
      }

      // select first table when project is selected.
      await () async {
        final tableList = await api.dbTableList(projectId: next.id);
        final sTable = tableList.list.firstOrNull;
        if (sTable == null) {
          return;
        }

        final table = await api.dbTableRead(tableId: sTable.id);
        ref.read(tableProvider.notifier).state = table;
      }();
    })
    ..listen(tableProvider, (final previous, final next) async {
      logger.info('tableProvider is changed. prev: $previous, next: $next');
      if (next == null) {
        return;
      }
      final table = next;

      // get relations
      await getRelations(next).then(
        (final relations) =>
            ref.watch(tablesProvider.notifier).state = NcTables(
          table: table,
          relationMap: relations,
        ),
      );

      final view = ref.watch(viewProvider);
      // When a table is selected, update the view if necessary.
      if (view == null || view.fkModelId != table.id) {
        await api.dbViewList(tableId: table.id).then((final viewList) {
          final view = viewList.list.firstOrNull;
          if (view == null) {
            return;
          }
          ref.read(viewProvider.notifier).set(view);
        });
      }
    })
    ..listen(viewProvider, (final previous, final next) async {
      logger.info('viewProvider is changed. prev: $previous, next: $next');
      if (next == null) {
        return;
      }

      // When a view is selected, update the table if necessary.
      final tableId = ref.watch(tableProvider)?.id;
      if (tableId != next.fkModelId) {
        await api.dbTableRead(tableId: next.fkModelId).then((final table) {
          ref.read(tableProvider.notifier).state = table;
        });
      }
    });
}

class App extends HookConsumerWidget {
  const App({
    super.key,
  });

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    setUpProviderListeners(ref); // TODO: Stop using ref.listen
    // No provider functionality is currently being used.
    final r = ref.watch(routerProvider);

    return GlobalLoaderOverlay(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: r,
        theme: useMaterial3
            ? ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.black,
              )
            : ThemeData(
                useMaterial3: false,
                primarySwatch: Colors.blue,
              ),
        themeMode: ThemeMode.light,
      ),
    );
  }
}
