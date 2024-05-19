import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'common/logger.dart';
import 'common/preferences.dart';
import 'common/settings.dart';
import 'nocodb_sdk/client.dart';
import 'routes.dart';

part 'router.g.dart';

(Map<String, dynamic> header, Map<String, dynamic> payload) decodeJwt(
  String jwt,
) {
  final parts = jwt.split('.');
  assert(parts.length == 3);

  final rawHeader = parts[0];
  final rawPayload = parts[1];

  final header = String.fromCharCodes(base64Decode(rawHeader));
  final payload = String.fromCharCodes(base64Decode(rawPayload));
  return (jsonDecode(header), jsonDecode(payload));
}

jwtTsToDateTime(int timestamp) {
  return DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000 * 1000);
}

(DateTime iat, DateTime exp) getIatAndExpFromPayload(
  Map<String, dynamic> payload,
) {
  return (jwtTsToDateTime(payload['iat']), jwtTsToDateTime(payload['exp']));
}

bool isJwtTokenAlive(String authToken) {
  final (header, payload) = decodeJwt(authToken);
  logger.fine('authToken.header: $header');

  final (iat, exp) = getIatAndExpFromPayload(payload);
  final now = DateTime.now();
  logger.fine('authToken.iat: $iat');
  logger.fine('authToken.exp: $exp');
  logger.fine('now: $now');

  return now.isBefore(exp);
}

FutureOr<String?> redirect(BuildContext context, GoRouterState state) async {
  try {
    // https://pub.dev/documentation/go_router/latest/go_router/GoRouterState-class.html
    if (state.matchedLocation != const HomeRoute().location) {
      return null;
    }
    if (!settings.initialized) {
      final prefs = Preferences();
      await prefs.load();
      settings.init(prefs);
      logger.fine('loaded settings from storage.');
    }

    final remembered = await settings.getRemembered();
    if (remembered == null) {
      return null;
    }
    final (host, token) = (remembered.host, remembered.token);

    logger.config('host: $host');
    logger.config('token type: ${token.runtimeType}');

    api.init(host, token: token);
    // TODO: Check host and token are valid.
    return const ProjectListRoute().location;
  } catch (e, stacktrace) {
    logger.warning(e);
    logger.warning(stacktrace);
    await settings.clear();
    return null;
  }

  return null;
}

@riverpod
GoRouter router(RouterRef ref) => GoRouter(
      routes: $appRoutes,
      debugLogDiagnostics: true,
      redirect: (context, state) async {
        return await redirect(context, state);
      },
    );
