import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ScrollDetector extends HookConsumerWidget {
  const ScrollDetector({
    super.key,
    required this.child,
    this.onEnd,
  });
  final Widget child;
  final Future<void> Function()? onEnd;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      NotificationListener(
        onNotification: (final ScrollEndNotification n) {
          if (n.metrics.axis != Axis.vertical) {
            return true;
          }

          if (n.metrics.extentAfter != 0) {
            return true;
          }

          // ignore: discarded_futures
          onEnd?.call();
          return true;
        },
        child: child,
      );
}
