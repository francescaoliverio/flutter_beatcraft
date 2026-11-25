import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'editor_provider.dart';
import 'http_client_provider.dart';
import 'local_storage_provider.dart';
import 'playback_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(httpClientProvider)));

/// Current session: null when logged out.
/// Only the user id is saved on the device; at launch the user is fetched again, so the login is skipped.
class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final int? id = await ref.read(localStorageProvider).readUserId();
    if (id == null) return null;
    try {
      final User? user = await ref.read(authServiceProvider).fetchUser(id);
      if (user == null) {
        await ref.read(localStorageProvider).clearUserId();
        return null;
      }
      return AuthSession(user: user);
    } on AuthException {
      // Offline or server error: show the login, keep the id for the next launch
      return null;
    }
  }

  /// Throws [AuthException].
  Future<void> login(String username, String password) async {
    final AuthSession session = await ref.read(authServiceProvider).login(username, password);
    state = AsyncData(session);
    await ref.read(localStorageProvider).saveUserId(session.user.id);
  }

  /// Also stops the player and the editor. The user's data stays saved for their next login,
  /// and the providers that watch [loggedUserIdProvider] stop showing it.
  Future<void> logout() async {
    state = const AsyncData(null);
    // Disposing the engines unloads their tracks and stops them; the playback state goes back to idle
    ref.invalidate(audioEngineProvider);
    ref.invalidate(editorEngineProvider);
    ref.invalidate(playbackProvider);
    await ref.read(localStorageProvider).clearUserId();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(
  AuthNotifier.new,
  // Failures already end in null, nothing to retry
  retry: (_, _) => null,
);

/// Id of the logged user, null when logged out. Providers of per-user data watch it,
/// so they reload when another user logs in.
final loggedUserIdProvider = Provider<int?>((ref) => ref.watch(authProvider.select((auth) => auth.value?.user.id)));
