import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nocodb/main.dart';

const NC_ENDPOINT = String.fromEnvironment('NC_ENDPOINT');
const NC_USER = String.fromEnvironment('NC_USER');
const NC_PASS = String.fromEnvironment('NC_PASS');

// https://github.com/flutter/flutter/issues/88765#issuecomment-1113140289
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);

  do {
    if (DateTime.now().isAfter(end)) {
      throw Exception('Timed out waiting for $finder');
    }

    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 100));
  } while (finder.evaluate().isEmpty);
}

void main() {
  HttpOverrides.global = null;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );
    await waitFor(tester, find.text('SIGN IN'));

    await tester.enterText(
      find.byKey(const ValueKey('email')),
      NC_USER,
    );
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      NC_PASS,
    );
    await tester.enterText(
      find.byKey(const ValueKey('endpoint')),
      NC_ENDPOINT,
    );
    await tester.tap(
      find.byKey(const ValueKey('sign_in_button')),
    );

    await tester.pumpAndSettle();

    await waitFor(tester, find.text('Projects'));
  });
}
