import 'package:flutter_test/flutter_test.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/providers/utils.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:riverpod/riverpod.dart' hide ErrorListener;
// import 'package:test/test.dart';

// https://riverpod.dev/ja/docs/essentials/testing
/// A testing utility which creates a [ProviderContainer] and automatically
/// disposes it at the end of the test.
ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  // Create a ProviderContainer, and optionally allow specifying parameters.
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  // When the test ends, dispose the container.
  addTearDown(container.dispose);

  return container;
}

void main() {
  setUp(() {
    const ncEndpoint = String.fromEnvironment('NC_ENDPOINT');
    const apiToken = String.fromEnvironment('API_TOKEN');
    api.init(ncEndpoint, token: ApiToken(apiToken));
  });
  test('Hello world', () async {
    final c = createContainer();
    final projectList = await api.projectList();
    final project =
        projectList.list.firstWhere((element) => element.title == 'sakila');
    await selectProject2(c, project);

    // tableProvider and viewProvider should be initialized after selectProject.
    final table = c.read(tableProvider);
    expect(table != null, true);
    logger.info('table: ${table?.title}');

    final view = c.read(viewProvider);
    expect(view != null, true);
    logger.info('view: ${view?.title}');
  });
}
