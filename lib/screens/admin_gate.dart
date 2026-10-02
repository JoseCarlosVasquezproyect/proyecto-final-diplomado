import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/gestion_controller.dart';
import 'home_screen.dart';
import 'personal_home_screen.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({super.key, required this.onUnauthorized});
  final Future<void> Function() onUnauthorized;
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late Future<String> _check;
  @override
  void initState() {
    super.initState();
    _check = _cargarPerfil();
  }
  Future<String> _cargarPerfil() {
    final future = _verificar();
    future.ignore();
    return future;
  }
  Future<String> _verificar() async {
    final perfil = await context.read<GestionController>().repository.perfilActual();
    if (perfil == 'no_autorizado' && mounted) {
      await widget.onUnauthorized();
    }
    return perfil;
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _check,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('No se pudo verificar el perfil de la cuenta.'),
          TextButton(onPressed: () => setState(() { _check = _cargarPerfil(); }), child: const Text('Reintentar')),
        ])));
      }
      if (snapshot.data == 'administrador') return const HomeScreen();
      if (snapshot.data == 'personal') return const PersonalHomeScreen();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    },
  );
}
