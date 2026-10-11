import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Invalida únicamente la sesión que originó la petición fallida.
class SessionGuard {
  SessionGuard(this.client);
  final SupabaseClient client;
  Future<void>? _signingOut;

  Future<void> invalidate(Session? session) async {
    if (session == null || !identical(client.auth.currentSession, session)) {
      return;
    }
    if (_signingOut != null) return _signingOut;
    final pending = client.auth.signOut(scope: SignOutScope.local);
    _signingOut = pending;
    try {
      await pending;
    } catch (_) {
      // GoTrue elimina la sesión local antes de intentar el cierre remoto.
      // Un fallo remoto no debe reemplazar el error original de la petición.
    } finally {
      _signingOut = null;
    }
  }

  Future<void> handleError(Object error) async {
    if (error is AuthRetryableFetchException) return;
    final code = error is AuthException
        ? error.code
        : error is PostgrestException
            ? error.code
            : null;
    final unauthorized =
        (error is AuthException && error.statusCode == '401') ||
            code == '401' ||
            const {
              'PGRST301',
              'PGRST303',
              'bad_jwt',
              'invalid_jwt',
              'session_not_found',
              'session_expired',
              'refresh_token_not_found',
              'refresh_token_already_used',
            }.contains(code);
    if (unauthorized) await invalidate(client.auth.currentSession);
  }
}

/// Conserva respuestas y payloads; observa solo 401 de APIs protegidas.
class SessionHttpClient extends http.BaseClient {
  SessionHttpClient(
      {required this.baseUrl, required this.guard, http.Client? inner})
      : _inner = inner ?? http.Client();

  final Uri baseUrl;
  final SessionGuard Function() guard;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final protected = request.url.origin == baseUrl.origin &&
        const ['/rest/v1/', '/functions/v1/', '/storage/v1/']
            .any(request.url.path.startsWith);
    final handler = protected ? guard() : null;
    final session = handler?.client.auth.currentSession;
    final response = await _inner.send(request);
    if (response.statusCode == 401 && handler != null) {
      await handler.invalidate(session);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
