import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/gestion_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AdminGate extends StatefulWidget { const AdminGate({super.key}); @override State<AdminGate> createState() => _AdminGateState(); }
class _AdminGateState extends State<AdminGate> {
  late Future<bool> _check;
  @override void initState() { super.initState(); _check = context.read<GestionController>().verificarAdministrador(); }
  @override Widget build(BuildContext context) => FutureBuilder<bool>(future: _check, builder: (context, s) { if (s.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator())); if (s.data == true) return const HomeScreen(); return const LoginScreen(accessDenied: true); });
}
