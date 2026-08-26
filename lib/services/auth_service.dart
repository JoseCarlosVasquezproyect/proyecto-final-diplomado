import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<String> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(email: email.trim(), password: password);
    if (response.session == null) {
      return 'Cuenta creada. Revisa tu correo si la confirmación está habilitada.';
    }
    return 'Cuenta creada y sesión iniciada.';
  }

  Future<void> signOut() => _client.auth.signOut();
}
