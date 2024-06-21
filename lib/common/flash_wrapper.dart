import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/cupertino.dart';

import 'package:nocodb/common/logger.dart';

const _successDuration = Duration(seconds: 1);
const _errorDuration = Duration(seconds: 3);

notifySuccess(
  BuildContext context, {
  required String message,
}) async {
  await context.showSuccessBar(
    position: FlashPosition.top,
    duration: _successDuration,
    content: Text(message),
  );
}

// TODO: Change to dialog?
notifyError(
  BuildContext context,
  dynamic error,
  StackTrace? stackTrace,
) async {
  logger.warning(error);
  if (stackTrace != null) {
    logger.warning(stackTrace);
  }

  await context.showErrorBar(
    position: FlashPosition.top,
    duration: _errorDuration,
    // content: Text('$error\n$stackTrace'),
    content: Text('$error'),
  );
}
