import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.accessDenied = false});
  final bool accessDenied;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void initState() { super.initState(); if (widget.accessDenied) _message = 'No tienes permisos para acceder al sistema.'; }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    try {
      final service = AuthService(Supabase.instance.client);
      if (_register) {
        final msg = await service.signUp(email: _email.text, password: _password.text);
        if (mounted) setState(() => _message = msg);
      } else {
        await service.signIn(email: _email.text, password: _password.text);
      }
    } on AuthException {
      if (mounted) setState(() => _message = 'No se pudo iniciar sesión. Verifica tus datos.');
    } catch (_) {
      if (mounted) setState(() => _message = 'No se pudo completar la operación. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Image.asset(
                          'iconos/equipo-medico.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Gestion Hospitalaria', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_register ? 'Crear cuenta de aula' : 'Iniciar sesión', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Procesando...' : (_register ? 'Registrarme' : 'Ingresar')),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() { _register = !_register; _message = null; }),
                        child: Text(_register ? 'Ya tengo cuenta' : 'Crear una cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
