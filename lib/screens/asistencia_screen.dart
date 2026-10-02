import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';
import '../models/asistencia_errors.dart';

class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});
  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  List<AsignacionTurno> _asistencias = [];
  final _busqueda = TextEditingController();
  String _estadoFiltro = 'todos';
  bool _cargando = true;
  bool _guardando = false;
  String? _error, _ocupadoId;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool limpiarFiltros = false}) async {
    if (!mounted) return;
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
      if (limpiarFiltros) {
        _busqueda.clear();
        _estadoFiltro = 'todos';
      }
    });
    try {
      final rows = await context.read<GestionController>().listarAsistencias();
      if (!mounted || consulta != _consulta) return;
      setState(() { _asistencias = rows; _cargando = false; });
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() { _error = mensajeErrorAsistencia(error); _cargando = false; });
    }
  }

  Future<void> _marcar(AsignacionTurno asignacion, String estado) async {
    if (_ocupadoId != null || asignacion.id == null || asignacion.estadoAsistencia == estado) return;
    final corregir = asignacion.estadoAsistencia != 'pendiente';
    // Reservar la acción antes de abrir la confirmación evita diálogos/updates duplicados.
    setState(() => _ocupadoId = asignacion.id);
    try {
      if (corregir) {
        final confirmado = await showDialog<bool>(context: context, barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Corregir asistencia'),
            content: Text('Esta asistencia ya fue marcada como ${_etiqueta(asignacion.estadoAsistencia)}.\n¿Deseas cambiarla a ${_etiqueta(estado)}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Cambiar a ${_etiqueta(estado)}')),
            ],
          ));
        if (!mounted || confirmado != true) return;
      }
      if (!mounted) return;
      setState(() => _guardando = true);
      await context.read<GestionController>().marcarAsistencia(asignacionId: asignacion.id!,
        estado: estado, estadoAnterior: asignacion.estadoAsistencia);
      if (!mounted) return;
      await _cargar(limpiarFiltros: true);
      if (!mounted) return;
      final mensaje = corregir ? 'Asistencia actualizada correctamente.'
        : estado == 'cumplido' ? 'Asistencia registrada como cumplida.' : 'Asistencia registrada como falta.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (error) {
      if (!mounted) return;
      if (error is AsistenciaException && error.recargar) {
        await _cargar(limpiarFiltros: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mensajeErrorAsistencia(error))));
    } finally {
      if (mounted) setState(() { _ocupadoId = null; _guardando = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Control de asistencia')),
    body: _contenido(),
  );

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16),
        FilledButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ])));
    }
    final query = _busqueda.text.trim().toLowerCase();
    final rows = _asistencias.where((a) {
      if (_estadoFiltro != 'todos' && a.estadoAsistencia != _estadoFiltro) return false;
      return [a.personal?.nombreCompleto ?? '', a.personal?.codigo ?? '', a.personal?.tipoPersonal ?? '',
        _etiqueta(a.personal?.tipoPersonal ?? a.rolTurno), a.personal?.especialidadNombre ?? '',
        a.turno?.area ?? '', a.turno == null ? '' : _fecha(a.turno!.fecha),
        a.turno == null ? '' : a.turno!.fecha.toIso8601String().substring(0, 10),
        a.estadoAsistencia, _etiqueta(a.estadoAsistencia),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _busqueda,
          decoration: const InputDecoration(labelText: 'Buscar', hintText: 'Personal, código, tipo, especialidad, fecha, área o asistencia', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(key: ValueKey(_estadoFiltro), initialValue: _estadoFiltro,
          decoration: const InputDecoration(labelText: 'Filtrar asistencia', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'todos', child: Text('Todas las asistencias')),
            DropdownMenuItem(value: 'pendiente', child: Text('Solo pendientes')),
            DropdownMenuItem(value: 'cumplido', child: Text('Cumplidos')),
            DropdownMenuItem(value: 'falta', child: Text('Faltas')),
          ],
          onChanged: (value) => setState(() => _estadoFiltro = value!)),
      ])),
      Expanded(child: _asistencias.isEmpty ? const Center(child: Text('No existen asignaciones para controlar asistencia.'))
        : rows.isEmpty ? const Center(child: Text('No hay asistencias que coincidan con los filtros.'))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), itemCount: rows.length,
          itemBuilder: (_, index) => _AsistenciaCard(
            asignacion: rows[index], habilitado: _ocupadoId == null && rows[index].id != null,
            ocupado: _guardando && _ocupadoId == rows[index].id, onMarcar: (estado) => _marcar(rows[index], estado)))),
    ]);
  }
}

class _AsistenciaCard extends StatelessWidget {
  const _AsistenciaCard({required this.asignacion, required this.habilitado, required this.ocupado, required this.onMarcar});
  final AsignacionTurno asignacion;
  final bool habilitado, ocupado;
  final ValueChanged<String> onMarcar;

  @override
  Widget build(BuildContext context) {
    final a = asignacion;
    final p = a.personal;
    final t = a.turno;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p?.nombreCompleto ?? 'Personal no disponible', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text('${p?.codigo ?? 'Sin código'} · ${_etiqueta(p?.tipoPersonal ?? a.rolTurno)}'),
      if (p?.especialidadNombre != null) Text(p!.especialidadNombre!),
      const SizedBox(height: 12),
      if (t == null) const Text('Turno no disponible') else ...[
        Text(_fecha(t.fecha)),
        Text('${_etiqueta(t.tipo)} · ${_hora(t.horaInicio)} - ${_hora(t.horaFin)}${t.horaFin.compareTo(t.horaInicio) < 0 ? ' (día siguiente)' : ''}'),
        Text('Área: ${t.area}'),
        if (t.estado == 'cancelado') const Text('Turno cancelado'),
      ],
      Chip(label: Text('Asistencia: ${_etiqueta(a.estadoAsistencia)}')),
      if (a.observaciones.isNotEmpty) Text('Observaciones: ${a.observaciones}'),
      if (ocupado) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
      Wrap(spacing: 12, runSpacing: 8, children: [
        if (a.estadoAsistencia == 'pendiente') ...[
          FilledButton.icon(onPressed: habilitado ? () => onMarcar('cumplido') : null, icon: const Icon(Icons.check), label: const Text('Marcar cumplido')),
          OutlinedButton.icon(onPressed: habilitado ? () => onMarcar('falta') : null, icon: const Icon(Icons.close), label: const Text('Marcar falta')),
        ],
        if (a.estadoAsistencia == 'cumplido') OutlinedButton(onPressed: habilitado ? () => onMarcar('falta') : null, child: const Text('Cambiar a Falta')),
        if (a.estadoAsistencia == 'falta') OutlinedButton(onPressed: habilitado ? () => onMarcar('cumplido') : null, child: const Text('Cambiar a Cumplido')),
      ]),
    ])));
  }
}

String _fecha(DateTime fecha) => '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
String _hora(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;
String _etiqueta(String value) => const {
  'medico': 'Médico', 'enfermero': 'Enfermero', 'pasante': 'Pasante',
  'manana': 'Mañana', 'tarde': 'Tarde', 'noche': 'Noche', 'personalizado': 'Personalizado',
  'pendiente': 'Pendiente', 'cumplido': 'Cumplido', 'falta': 'Falta',
}[value] ?? value;
