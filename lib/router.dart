import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/common/preferences.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

(Map<String, dynamic> header, Map<String, dynamic> payload) decodeJwt(
  final String jwt,
) {
  final parts = jwt.split('.');
  assert(parts.length == 3);

  final rawHeader = parts[0];
  final rawPayload = parts[1];

  final header = String.fromCharCodes(base64Decode(rawHeader));
  final payload = String.fromCharCodes(base64Decode(rawPayload));
  return (jsonDecode(header), jsonDecode(payload));
}

jwtTsToDateTime(final int timestamp) =>
    DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000 * 1000);

(DateTime iat, DateTime exp) getIatAndExpFromPayload(
  final Map<String, dynamic> payload,
) =>
    (jwtTsToDateTime(payload['iat']), jwtTsToDateTime(payload['exp']));

bool isAuthTokenAlive(final String authToken) {
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

// FutureOr<String?> redirect(context, state) async {
FutureOr<String?> redirect(
  final BuildContext context,
  final GoRouterState state,
) async {
  try {
    if (!settings.initialized) {
      final prefs = Preferences();
      await prefs.load();
      settings.init(prefs);
      logger.fine('loaded settings from storage.');
    }

    final rememberMe = await settings.rememberMe;
    final apiBaseUrl = await settings.apiBaseUrl;
    final authToken = await settings.authToken;

    logger.config('apiBaseUrl: $apiBaseUrl');

    if (authToken == null || apiBaseUrl == null) {
      return const HomeRoute().location;
    } else if (state.path == const HomeRoute().location) {
      if (!rememberMe) {
        await settings.clear();
        return const HomeRoute().location;
      }

      final isAlive = isAuthTokenAlive(authToken);
      logger.info(
        'authToken: ${isAlive ? 'alive' : 'expired'}',
      );

      if (isAlive) {
        final ok = await api.version(apiBaseUrl);
        if (!ok) {
          return const HomeRoute().location;
        }
        api.init(apiBaseUrl, authToken: authToken);
        return const ProjectListRoute().location;
      }
    }
  } catch (e) {
    logger.warning(e);
    return const HomeRoute().location;
  }

  return null;
}

@riverpod
GoRouter router(final RouterRef ref) => GoRouter(
      routes: $appRoutes,
      debugLogDiagnostics: true,
      redirect: (final context, final state) async {
        logger.info('redirecting ...');
        final location = await redirect(context, state);
        if (location == null) {
          logger.info('redirected to $location');
        }
        return location;
      },
    );
