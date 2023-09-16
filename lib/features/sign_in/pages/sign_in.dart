import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '/nocodb_sdk/client.dart';
import '../../../common/flash_wrapper.dart';
import '../../../common/settings.dart';
import '../../../routes.dart';

class SignInPage extends HookConsumerWidget {
  const SignInPage({super.key});

  Widget? _getConnectivityIcon(bool? connectivity) {
    if (connectivity == null) {
      return null;
    } else if (connectivity) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Icon(
          Icons.check_circle,
          size: 20,
          // color: Colors.greenAccent,
        ),
      );
    } else {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Icon(
          Icons.warning,
          size: 20,
        ),
      );
    }
  }

  Widget _buildDialog(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final apiUrlController = useTextEditingController();

    final showPassword = useState(false);
    final connectivity = useState<bool?>(null);
    final rememberMe = useState(false);

    useEffect(
      () {
        () async {
          emailController.text = await settings.email ?? '';
          apiUrlController.text = await settings.apiBaseUrl ?? '';
          rememberMe.value = await settings.rememberMe;
        }();
        return null;
      },
      [],
    );

    return AlertDialog(
      title: const Text('SIGN IN'),
      content: IntrinsicHeight(
        child: AutofillGroup(
          child: Column(
            children: [
              TextField(
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
              TextField(
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
              TextField(
                onChanged: (value) {
                  EasyDebounce.debounce(
                    'sign_in_password',
                    const Duration(seconds: 1),
                    () {
                      api.version(apiUrlController.text).then((result) {
                        connectivity.value = true;
                      }).onError(
                        (error, stackTrace) {
                          notifyError(context, error, stackTrace);
                          connectivity.value = false;
                        },
                      );
                    },
                  );
                },
                autofillHints: const [
                  AutofillHints.url,
                ],
                controller: apiUrlController,
                decoration: InputDecoration(
                  labelText: 'API Endpoint',
                  suffixIcon: _getConnectivityIcon(connectivity.value),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe.value,
                    onChanged: (_) {
                      rememberMe.value = !rememberMe.value;
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text('Remember Me'),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('SIGN IN'),
          onPressed: () {
            api.init(apiUrlController.text);
            api
                .authSignin(
              emailController.text,
              passwordController.text,
            )
                .then((authToken) {
              if (rememberMe.value) {
                settings.setEmail(emailController.text);
                settings.setRememberMe(rememberMe.value);
              }

              // TODO: Need to rewrite Settings class. The following values should not be saved to the storage when rememberMe is false.
              settings.setApiBaseUrl(apiUrlController.text);
              settings.setAuthToken(authToken);
              const ProjectListRoute().go(context);
            }).onError(
              (error, stackTrace) => notifyError(context, error, stackTrace),
            );
          },
        ),
      ],
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
        child: _buildDialog(context, ref),
      ),
    );
  }
}
