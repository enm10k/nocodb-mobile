import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/cupertino.dart';

import 'logger.dart';

const _successDuration = Duration(seconds: 1);
const _errorDuration = Duration(seconds: 3);

notifySuccess(
  BuildContext context, {
  required String message,
}) {
  context.showSuccessBar(
    position: FlashPosition.top,
    duration: _successDuration,
    content: Text(message),
  );
}

notifyError(BuildContext context, dynamic error, StackTrace? stackTrace) {
  logger.warning(error);
  if (stackTrace != null) {
    logger.warning(stackTrace);
  }

  context.showErrorBar(
    position: FlashPosition.top,
    duration: _errorDuration,
    content: Text(error.toString()),
  );
}
