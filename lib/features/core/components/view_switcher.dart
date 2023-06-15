import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/features/core/components/views/grid.dart';
import '/features/core/providers/providers.dart';
import '/nocodb_sdk/symbols.dart';
import '../../../common/extensions.dart';

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
