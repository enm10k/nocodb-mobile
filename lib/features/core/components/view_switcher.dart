import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/extensions.dart';
import 'package:nocodb/features/core/components/views/grid.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';

class ViewSwitcher extends HookConsumerWidget {
  const ViewSwitcher({super.key});

  Widget _build(ViewTypes type) {
    switch (type) {
      case ViewTypes.grid:
        return const Grid();
      default:
        return Center(
          child: Text(
            '${type.name.capitalize()} is not yet supported.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(viewProvider.select((v) => v?.type));
    return type != null ? _build(type) : const CircularProgressIndicator();
  }
}
