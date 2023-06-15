import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ScrollDetector extends HookConsumerWidget {
  final Widget child;
  final Future<void> Function()? onEnd;
  const ScrollDetector({
    super.key,
    required this.child,
    this.onEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener(
      onNotification: (ScrollEndNotification n) {
        if (n.metrics.axis != Axis.vertical) {
          return true;
        }

        if (n.metrics.extentAfter != 0) {
          return true;
        }

        onEnd?.call();
        return true;
      },
      child: child,
    );
  }
}
