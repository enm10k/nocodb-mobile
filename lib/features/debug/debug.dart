import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'debug.freezed.dart';
part 'debug.g.dart';

typedef Record = (List<int>, List<int>);

final patternsProvider = StateProvider<Record>(
  (final ref) => ([1, 2, 3], [4, 5, 6]),
);

@freezed
class Union with _$Union {
  factory Union.first(final int value) = _UnionFirst;
  factory Union.second(final double value) = _UnionSecond;
}

@Riverpod()
class Patterns2 extends _$Patterns2 {
  @override
  Record build() => ([7, 8, 9], [10, 11, 12]);

  update(final Record record) {
    state = record;
  }
}

class DebugPage extends HookConsumerWidget {
  const DebugPage({super.key});

  _test(final WidgetRef ref) {
    // ignore_for_file: unnecessary_cast
    final (a, b) = ref.read(patternsProvider) as Record;
    ref.read(patternsProvider.notifier).state = (a..shuffle(), b..shuffle());
  }

  _test2(final WidgetRef ref) {
    final (a, b) = ref.read(patterns2Provider) as Record;
    ref.read(patterns2Provider.notifier).update((a..shuffle(), b..shuffle()));
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    // test union
    final Union n1 = Union.first(1);
    final Union n2 = Union.second(4.5);
    logger.info('$n1: $n1 ${n1.runtimeType}, n2: $n2 ${n2.runtimeType}');

    final (a, b) = ref.watch(patternsProvider);
    final (c, d) = ref.watch(patterns2Provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
      ),
      body: Center(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Testing records feature and riverpod'),
              subtitle: Text('a: $a, b: $b, c: $c, d: $d'),
              trailing: IconButton(
                icon: const Icon(Icons.shuffle_on_outlined),
                onPressed: () {
                  _test(ref);
                  _test2(ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
