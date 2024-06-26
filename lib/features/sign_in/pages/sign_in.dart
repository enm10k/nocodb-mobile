import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/utils.dart';
import 'package:nocodb/routes.dart';

class SignInPage extends HookConsumerWidget {
  const SignInPage({super.key});

  _build1(BuildContext context, WidgetRef ref) {
    final hostController = useTextEditingController();
    final usernameController = useTextEditingController();
    final passwordController = useTextEditingController();
    final apiTokenController = useTextEditingController();

    final showPassword = useState(false);
    final showApiToken = useState(false);

    final rememberMe = useState(true);

    // Disable username and password field when API token is entered.
    final useApiToken = useState(false);

    useEffect(
      () {
        // ignore: discarded_futures
        () async {
          final s = await settings.get();
          rememberMe.value = true;

          // TODO: check if an Android emulator is being used.
          // if (kDebugMode && Platform.isAndroid) {
          //   hostController.text = 'http://10.0.2.2:8080';
          // } else {
          //   hostController.text = 'https://app.nocodb.com';
          // }
          hostController.text = 'https://app.nocodb.com';

          if (s == null) {
            return null;
          }
          if (s.host.isNotEmpty) {
            hostController.text = s.host;
          }

          if (s.username != null) {
            usernameController.text = s.username!;
          }
        }();
        return null;
      },
      [],
    );
    final onPressed = useState<Future<Null> Function()?>(null);

    isActive() =>
        hostController.text.isNotEmpty &&
        ((usernameController.text.isNotEmpty &&
                passwordController.text.isNotEmpty) ||
            apiTokenController.text.isNotEmpty);

    setOnPressed() {
      onPressed.value = isActive()
          ? () async {
              Token? token;
              if (useApiToken.value) {
                token = ApiToken(apiTokenController.text);
              } else {
                api.init(hostController.text);
                (await api.authSignin(
                  usernameController.text,
                  passwordController.text,
                ))
                    .when(
                  ok: (value) {
                    token = AuthToken(value);
                  },
                  ng: (Object error, StackTrace? stackTrace) {
                    notifyError(context, error, stackTrace);
                  },
                );
              }
              if (token == null) {
                return;
              }
              final host = hostController.text;
              api.init(host, token: token);

              if (rememberMe.value) {
                await settings.save(host: host, token: token!);
              }

              if (!context.mounted) {
                return;
              }

              if (isCloud(host)) {
                const CloudProjectListRoute().go(context);
              } else {
                const ProjectListRoute().go(context);
              }
            }
          : null;
      logger.info('onPressed: ${onPressed.value}');
    }

    // NOTE: There might be a more elegant way to implement this.
    hostController.addListener(setOnPressed);
    usernameController.addListener(setOnPressed);
    passwordController.addListener(setOnPressed);
    apiTokenController.addListener(setOnPressed);

    return Container(
      padding: const EdgeInsets.all(16),
      child: AutofillGroup(
        child: Column(
          children: [
            TextField(
              autofillHints: const [
                AutofillHints.url,
              ],
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
              ),
            ),
            Container(height: 16),
            TextField(
              enabled: !useApiToken.value,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            TextField(
              enabled: !useApiToken.value,
              autofillHints: const [
                AutofillHints.password,
              ],
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    showPassword.value
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    showPassword.value = !showPassword.value;
                  },
                ),
              ),
              obscureText: !showPassword.value,
            ),
            Container(height: 16),
            const Text('OR'),
            TextField(
              controller: apiTokenController,
              decoration: InputDecoration(
                labelText: 'API token',
                suffixIcon: IconButton(
                  icon: Icon(
                    showApiToken.value
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    showApiToken.value = !showApiToken.value;
                  },
                ),
              ),
              obscureText: !showApiToken.value,
              onChanged: (value) {
                if (useApiToken.value != value.isNotEmpty) {
                  useApiToken.value = value.isNotEmpty;
                }
              },
            ),
            Container(height: 16),
            Row(
              children: [
                Checkbox(
                  value: rememberMe.value,
                  onChanged: (value) {
                    rememberMe.value = value!;
                  },
                ),
                const Text('Remember Me'),
              ],
            ),
            ElevatedButton(
              onPressed: onPressed.value,
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('NocoDB'),
        ),
        body: _build1(context, ref),
      );
}
