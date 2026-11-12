import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_spacing.dart';
import '../widgets/button.dart';
import '../widgets/heading.dart';
import 'main_shell.dart';

/// Login with a DummyJSON demo account.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // TODO: call DummyJSON /auth/login
  void _login(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Heading('BeatCraft', style: HeadingStyle.display),
              const SizedBox(height: AppSpacing.paddingLg),
              const TextField(decoration: InputDecoration(labelText: 'Username')),
              const SizedBox(height: AppSpacing.paddingMd),
              const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password')),
              const SizedBox(height: AppSpacing.paddingLg),
              Button(label: 'Log in', icon: PhosphorIconsRegular.signIn, onPressed: () => _login(context)),
            ],
          ),
        ),
      ),
    );
  }
}
