import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/nocodb_sdk/client.dart';
import '../../../common/settings.dart';
import '../../../routes.dart';

class SignInPage extends HookConsumerWidget {
  const SignInPage({super.key});

  _build1(BuildContext context, WidgetRef) {
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
        () async {
          final remembered = await settings.getRemembered();
          if (remembered == null) {
            return;
          }
          usernameController.text = await settings.email ?? '';
          hostController.text = remembered.host;
        }();
        return null;
      },
      [],
    );

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
                Text('Remember Me'),
              ],
            ),
            ElevatedButton(
              onPressed: () async {
                Token? token;
                if (useApiToken.value) {
                  token = ApiToken(apiTokenController.text);
                } else {
                  api.init(hostController.text);
                  token = AuthToken(
                    await api.authSignin(
                      usernameController.text,
                      passwordController.text,
                    ),
                  );
                }
                api.init(hostController.text, token: token);

                if (rememberMe.value) {
                  await settings.remember(
                    host: hostController.text,
                    token: token,
                  );
                }

                if (!context.mounted) {
                  return;
                }
                const ProjectListRoute().go(context);
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NocoDB'),
      ),
      body: Center(
        // TODO: Stop using dialog?
        // child: _buildDialog(context, ref),
        child: _build1(context, ref),
      ),
    );
  }
}
