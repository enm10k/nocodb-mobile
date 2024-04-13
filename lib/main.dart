import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:stack_trace/stack_trace.dart';

import 'common/logger.dart';
import 'features/core/providers/providers.dart';
import 'nocodb_sdk/client.dart';
import 'nocodb_sdk/models.dart';
import 'router.dart';

const useMaterial3 = false;

void main() async {
  // https://api.flutter.dev/flutter/foundation/FlutterError/demangleStackTrace.html
  FlutterError.demangleStackTrace = (stack) {
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

setUpProviderListeners(WidgetRef ref) {
  ref.listen(projectProvider, (previous, next) {
    logger.info('projectProvider is changed. prev: $previous, next: $next');
    if (next == null) {
      return;
    }

    // select first table when project is selected.
    () async {
      final tableList = await api.dbTableList(projectId: next.id);
      final sTable = tableList.list.firstOrNull;
      if (sTable == null) {
        return;
      }

      final table = await api.dbTableRead(tableId: sTable.id);
      ref.read(tableProvider.notifier).state = table;
    }();
  });

  ref.listen(tableProvider, (previous, next) {
    logger.info('tableProvider is changed. prev: $previous, next: $next');
    if (next == null) {
      return;
    }
    final table = next;

    // get relations
    getRelations(next).then(
      (relations) => ref.watch(tablesProvider.notifier).state = NcTables(
        table: table,
        relationMap: relations,
      ),
    );

    final view = ref.watch(viewProvider);
    // When a table is selected, update the view if necessary.
    if (view == null || view.fkModelId != table.id) {
      api.dbViewList(tableId: table.id).then((viewList) {
        final view = viewList.list.firstOrNull;
        if (view == null) {
          return;
        }
        ref.read(viewProvider.notifier).set(view);
      });
    }
  });

  ref.listen(viewProvider, (previous, next) {
    logger.info('viewProvider is changed. prev: $previous, next: $next');
    if (next == null) {
      return;
    }

    // When a view is selected, update the table if necessary.
    final tableId = ref.watch(tableProvider)?.id;
    if (tableId != next.fkModelId) {
      api.dbTableRead(tableId: next.fkModelId).then((table) {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
