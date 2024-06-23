import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/common/preferences.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/utils.dart';
import 'package:nocodb/routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

(Map<String, dynamic> header, Map<String, dynamic> payload) decodeJwt(
  String jwt,
) {
  final parts = jwt.split('.');
  assert(parts.length == 3);

  final rawHeader = parts[0];
  final rawPayload = parts[1];

  final header =
      String.fromCharCodes(base64Decode(base64.normalize(rawHeader)));
  final payload =
      String.fromCharCodes(base64Decode(base64.normalize(rawPayload)));
  return (jsonDecode(header), jsonDecode(payload));
}

jwtTsToDateTime(int timestamp) =>
    DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000 * 1000);

(DateTime iat, DateTime exp) getIatAndExpFromPayload(
  Map<String, dynamic> payload,
) =>
    (jwtTsToDateTime(payload['iat']), jwtTsToDateTime(payload['exp']));

bool isAuthTokenAlive(String authToken) {
  final (header, payload) = decodeJwt(authToken);
  logger.fine('authToken.header: $header');

  final (iat, exp) = getIatAndExpFromPayload(payload);
  final now = DateTime.now();
  logger
    ..fine('authToken.iat: $iat')
    ..fine('authToken.exp: $exp')
    ..fine('now: $now');

  return now.isBefore(exp);
}

FutureOr<String?> redirect(
  BuildContext context,
  GoRouterState state,
) async {
  try {
    if (!settings.initialized) {
      final prefs = Preferences();
      await prefs.load();
      settings.init(prefs);
      logger.fine('loaded settings from storage.');
    }

    final s = await settings.get();
    if (s == null) {
      await settings.clear();
      return const HomeRoute().location;
    }
    final Settings(:host, :token) = s;

    logger
      ..config('host: $host')
      ..config('state.uri: ${state.uri}');
    if (state.uri.toString() == const HomeRoute().location) {
      if (token is AuthToken && !isAuthTokenAlive(token.authToken)) {
        logger.info('authToken is expired.');
        return const HomeRoute().location;
      }

      api.init(host, token: token);
      // TODO: Verify the validity of the credentials by calling an appropriate API.
      if (isCloud(host)) {
        return const CloudProjectListRoute().location;
      } else {
        return const ProjectListRoute().location;
      }
    }
  } catch (e, s) {
    logger
      ..warning(e)
      ..warning(s);
    return const HomeRoute().location;
  }

  return null;
}

@riverpod
GoRouter router(RouterRef ref) => GoRouter(
      routes: $appRoutes,
      debugLogDiagnostics: true,
      redirect: (context, state) async {
        final location = await redirect(context, state);
        if (location != null) {
          logger.info('redirected to $location');
        }
        return location;
      },
    );
