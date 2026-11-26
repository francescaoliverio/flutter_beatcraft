import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/button.dart';
import '../widgets/heading.dart';

/// Login with a DummyJSON demo account.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter username and password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On success app.dart replaces this screen with the main shell
      await ref.read(authProvider.notifier).login(username, password);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e.failure) {
          AuthFailure.invalidCredentials => 'Wrong username or password',
          AuthFailure.other => 'Connection problem. Try again.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Centered when it fits; scrolls with large text or the keyboard open instead of overflowing
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.paddingLg),
            // AutofillGroup lets password managers fill both fields together
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Heading('BeatCraft', style: HeadingStyle.display),
                  const SizedBox(height: AppSpacing.paddingLg),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    autofillHints: const [AutofillHints.username],
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.paddingMd),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        // tooltip is also the screen reader label
                        tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                        icon: Icon(_passwordVisible ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye),
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                    obscureText: !_passwordVisible,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.paddingMd),
                    // liveRegion: screen readers announce the error when it appears
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: AppTextStyles.p.copyWith(color: AppColors.error)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.paddingLg),
                  Button(label: 'Log in', icon: PhosphorIconsRegular.signIn, onPressed: _loading ? null : _login),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
