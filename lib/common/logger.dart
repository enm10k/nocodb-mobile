import 'package:flutter/foundation.dart';
import 'package:simple_logger/simple_logger.dart';

const debugLogLevel = Level.FINER;

final logger = SimpleLogger()
  ..formatter = ((info) => '[${info.level}] '
      // '${DateFormat('HH:mm:ss.SSS').format(info.time)} '
      // '[${info.callerFrame ?? 'caller info not available'}] '
      '[${info.callerFrame?.library ?? '-'}:${info.callerFrame?.line}] '
      '${info.message}')
  ..setLevel(
    kReleaseMode ? Level.OFF : debugLogLevel,
    includeCallerInfo: true,
  )
  ..onLogged = (log, info) {
    // if (info.level >= Level.SEVERE) {
    //   throw AssertionError('Stopped by logger');
    // }
  };
