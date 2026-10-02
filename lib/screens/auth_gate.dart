import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_gate.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  String? _message;
  late final Stream<AuthState> _authChanges;
  @override
  void initState() {
    super.initState();
    _authChanges = Supabase.instance.client.auth.onAuthStateChange.map((state) {
      if (state.event == AuthChangeEvent.signedIn) _message = null;
      return state;
    });
  }
  Future<void> _rechazar() async {
    if (!mounted) return;
    setState(() => _message = 'La cuenta no tiene un perfil autorizado.');
    await Supabase.instance.client.auth.signOut();
  }
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (client.auth.currentSession == null) {
          return LoginScreen(key: ValueKey(_message), initialMessage: _message);
        }
        return AdminGate(key: ValueKey(client.auth.currentUser?.id), onUnauthorized: _rechazar);
      },
    );
  }
}
