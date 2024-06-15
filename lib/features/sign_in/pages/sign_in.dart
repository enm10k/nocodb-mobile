import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/routes.dart';

class SignInPage extends HookConsumerWidget {
  const SignInPage({super.key});

  Widget? _getConnectivityIcon(final bool? connectivity) {
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

  Widget _buildDialog(final BuildContext context, final WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final apiUrlController = useTextEditingController();

    final showPassword = useState(false);
    final connectivity = useState<bool?>(null);
    final rememberMe = useState(false);

    useEffect(
      () {
        // ignore: discarded_futures
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
                onChanged: (final value) {
                  EasyDebounce.debounce(
                    'sign_in_password',
                    const Duration(seconds: 1),
                    () async {
                      await api
                          .version(apiUrlController.text)
                          .then((final result) {
                        connectivity.value = true;
                      }).onError(
                        (final error, final stackTrace) {
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
                    onChanged: (final _) {
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
          onPressed: () async {
            api.init(apiUrlController.text);
            await api
                .authSignin(
              emailController.text,
              passwordController.text,
            )
                .then((final authToken) async {
              if (rememberMe.value) {
                await settings.setEmail(emailController.text);
                await settings.setRememberMe(rememberMe.value);
              }

              // TODO: Need to rewrite Settings class. The following values should not be saved to the storage when rememberMe is false.
              await settings.setApiBaseUrl(apiUrlController.text);
              await settings.setAuthToken(authToken);
              if (context.mounted) {
                const ProjectListRoute().go(context);
              }
            }).onError(
              (final error, final stackTrace) =>
                  notifyError(context, error, stackTrace),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('NocoDB'),
        ),
        body: Center(
          // TODO: Stop using dialog?
          child: _buildDialog(context, ref),
        ),
      );
}
