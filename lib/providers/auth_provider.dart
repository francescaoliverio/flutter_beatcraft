import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import 'http_client_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(httpClientProvider)));

/// Current session in memory: null when logged out.
class AuthNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  /// Throws [AuthException].
  Future<void> login(String username, String password) async {
    state = await ref.read(authServiceProvider).login(username, password);
  }

  void logout() => state = null;
}

final authProvider = NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);
