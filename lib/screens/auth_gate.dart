import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_gate.dart';
import '../services/session_guard.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.client});
  final SupabaseClient? client;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _message;
  late final Stream<AuthState> _authChanges;
  late final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;
  late final SessionGuard _guard;
  @override
  void initState() {
    super.initState();
    _client = widget.client ?? Supabase.instance.client;
    _guard = SessionGuard(_client);
    _authChanges = _client.auth.onAuthStateChange.map((state) {
      if (state.event == AuthChangeEvent.signedIn) _message = null;
      return state;
    });
    _subscription = _authChanges.listen((state) {
      if (state.session == null) _clearProtectedRoutes();
    }, onError: (Object error, StackTrace stack) {
      unawaited(_guard.handleError(error));
    });
  }

  void _clearProtectedRoutes() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _client.auth.currentSession != null) return;
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _rechazar() async {
    if (!mounted) return;
    setState(() => _message = 'La cuenta no tiene un perfil autorizado.');
    await _client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return StreamBuilder<AuthState>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (client.auth.currentSession == null) {
          return LoginScreen(key: ValueKey(_message), initialMessage: _message);
        }
        return AdminGate(
            key: ValueKey(client.auth.currentUser?.id),
            onUnauthorized: _rechazar);
      },
    );
  }
}
