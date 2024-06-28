import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
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

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

class App extends HookConsumerWidget {
  const App({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
