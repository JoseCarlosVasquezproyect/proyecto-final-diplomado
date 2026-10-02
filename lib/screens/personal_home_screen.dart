import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';
import '../repositories/personal_panel_repository.dart';

class PersonalHomeScreen extends StatefulWidget {
  const PersonalHomeScreen({super.key, this.repository});
  final PersonalPanelRepository? repository;
  @override
  State<PersonalHomeScreen> createState() => _PersonalHomeScreenState();
}

class _PersonalHomeScreenState extends State<PersonalHomeScreen> {
  late PersonalPanelRepository _repository;
  late Future<Personal> _datos;
  late Future<List<AsignacionTurno>> _turnos;
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PersonalPanelRepository(
      context.read<GestionController>().repository.client,
    );
    _datos = _cargarDatos();
    _turnos = _cargarTurnos();
  }

  Future<Personal> _cargarDatos() {
    final future = _repository.misDatos();
    // El FutureBuilder se suscribe en el próximo frame; conservar el error
    // para mostrarlo sin dejar errores rápidos sin manejar entre frames.
    future.ignore();
    return future;
  }

  Future<List<AsignacionTurno>> _cargarTurnos() {
    final future = _repository.misTurnos();
    future.ignore();
    return future;
  }

  Future<void> _salir() async {
    setState(() => _saliendo = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cerrar sesión. Intenta nuevamente.')));
      }
    } finally {
      if (mounted) setState(() => _saliendo = false);
    }
  }

  String _etiqueta(String value) => switch (value) {
    'medico' => 'Médico', 'enfermero' => 'Enfermero', 'pasante' => 'Pasante',
    'pendiente' => 'Pendiente', 'cumplido' => 'Cumplido', 'falta' => 'Falta',
    'activo' => 'Activo', 'inactivo' => 'Inactivo', 'suspendido' => 'Suspendido',
    'masculino' => 'Masculino', 'femenino' => 'Femenino', 'otro' => 'Otro',
    'manana' => 'Mañana', 'tarde' => 'Tarde', 'noche' => 'Noche',
    'programado' => 'Programado', 'cancelado' => 'Cancelado',
    _ => value.isEmpty ? 'Sin información' : '${value[0].toUpperCase()}${value.substring(1)}',
  };

  String _fecha(DateTime fecha) => '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  String _hora(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;
  Widget _error(String texto, VoidCallback retry) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(texto), TextButton(onPressed: retry, child: const Text('Reintentar')),
  ]);
  Widget _card(List<Widget> children) => Card(child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi cuenta'), actions: [
      TextButton.icon(onPressed: _saliendo ? null : _salir, icon: const Icon(Icons.logout), label: const Text('Cerrar sesión')),
    ]),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Text('Mis datos', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      FutureBuilder<Personal>(future: _datos, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) {
          return _error('No se pudieron cargar tus datos.', () => setState(() { _datos = _cargarDatos(); }));
        }
        final p = snapshot.data!;
        return _card([
          Text(p.codigo, style: Theme.of(context).textTheme.titleMedium),
          Text('Nombre: ${p.nombre}'), Text('Apellido: ${p.apellido}'),
          Text('CI: ${p.ci ?? 'Sin información'}'), Text('Sexo: ${_etiqueta(p.sexo)}'),
          Text('Teléfono: ${p.telefono ?? 'Sin información'}'),
          Text('Tipo: ${_etiqueta(p.tipoPersonal)}'), Text('Estado: ${_etiqueta(p.estado)}'),
          Text(p.especialidadNombre == null ? 'Sin especialidad asignada.' : 'Especialidad: ${p.especialidadNombre}'),
        ]);
      }),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Text('Mis turnos', style: Theme.of(context).textTheme.headlineSmall)),
        IconButton(tooltip: 'Actualizar', onPressed: () => setState(() {
          _datos = _cargarDatos(); _turnos = _cargarTurnos();
        }), icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 12),
      FutureBuilder<List<AsignacionTurno>>(future: _turnos, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _error('No se pudieron cargar tus turnos.', () => setState(() { _turnos = _cargarTurnos(); }));
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const Text('No tienes turnos asignados.');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows.map((a) {
          final t = a.turno!;
          return _card([
            Text('${_fecha(t.fecha)} · ${_etiqueta(t.tipo)}', style: Theme.of(context).textTheme.titleMedium),
            Text('${_hora(t.horaInicio)} - ${_hora(t.horaFin)}'),
            Text('Área: ${t.area}'), Text('Estado: ${_etiqueta(t.estado)}'),
            Text('Asistencia: ${_etiqueta(a.estadoAsistencia)}'),
            if (t.observaciones?.trim().isNotEmpty == true) Text('Observaciones del turno: ${t.observaciones}'),
            if (a.observaciones.trim().isNotEmpty) Text('Observaciones de la asignación: ${a.observaciones}'),
          ]);
        }).toList());
      }),
    ]),
  );
}
