import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';
import '../models/asignacion_errors.dart';

class AsignacionesScreen extends StatefulWidget {
  const AsignacionesScreen({super.key});
  @override
  State<AsignacionesScreen> createState() => _AsignacionesScreenState();
}

class _AsignacionesScreenState extends State<AsignacionesScreen> {
  List<AsignacionTurno> _asignaciones = [];
  List<Turno> _turnos = [];
  final _busqueda = TextEditingController();
  String? _turnoFiltro, _error;
  bool _cargando = true;
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
        _turnoFiltro = null;
      }
    });
    try {
      final controller = context.read<GestionController>();
      final resultados = await Future.wait([
        controller.listarAsignaciones(), controller.turnosParaAsignacion(),
      ]);
      final asignaciones = resultados[0] as List<AsignacionTurno>;
      final opciones = {for (final t in resultados[1] as List<Turno>) t.id!: t};
      // Incluir en el filtro también turnos cancelados que tengan asignaciones.
      for (final a in asignaciones) {
        if (a.turno != null) opciones[a.turnoId] = a.turno!;
      }
      final turnos = opciones.values.toList()..sort((a, b) {
        final fecha = a.fecha.compareTo(b.fecha);
        return fecha == 0 ? a.horaInicio.compareTo(b.horaInicio) : fecha;
      });
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _asignaciones = asignaciones;
        _turnos = turnos;
        if (!_turnos.any((t) => t.id == _turnoFiltro)) _turnoFiltro = null;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() { _error = mensajeErrorAsignacion(error); _cargando = false; });
    }
  }

  Future<void> _abrirFormulario([AsignacionTurno? asignacion]) async {
    final guardado = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => _AsignacionForm(asignacion: asignacion));
    if (!mounted || guardado != true) return;
    await _cargar(limpiarFiltros: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asignacion == null
      ? 'Personal asignado al turno correctamente.' : 'Asignación actualizada correctamente.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Asignación de turnos')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _abrirFormulario(), icon: const Icon(Icons.add), label: const Text('Nueva asignación')),
    body: _contenido(),
  );

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _EstadoError(mensaje: _error!, onRetry: _cargar);
    final query = _busqueda.text.trim().toLowerCase();
    final filtradas = _asignaciones.where((a) {
      if (_turnoFiltro != null && a.turnoId != _turnoFiltro) return false;
      return [a.personal?.nombreCompleto ?? '', a.personal?.codigo ?? '',
        a.personal?.tipoPersonal ?? '', _etiqueta(a.personal?.tipoPersonal ?? ''),
        a.turno?.area ?? '', a.turno == null ? '' : _fecha(a.turno!.fecha),
        a.turno == null ? '' : a.turno!.fecha.toIso8601String().substring(0, 10),
        a.estadoAsistencia, _etiqueta(a.estadoAsistencia), a.personal?.especialidadNombre ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _busqueda,
          decoration: const InputDecoration(labelText: 'Buscar', hintText: 'Personal, código, tipo, área, fecha o asistencia', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_turnoFiltro), initialValue: _turnoFiltro ?? '', isExpanded: true,
          decoration: const InputDecoration(labelText: 'Filtrar por turno', border: OutlineInputBorder()),
          items: [const DropdownMenuItem(value: '', child: Text('Todos los turnos')),
            ..._turnos.map((t) => DropdownMenuItem(value: t.id!, child: Text(_resumenTurno(t), overflow: TextOverflow.ellipsis)))],
          onChanged: (value) => setState(() => _turnoFiltro = value == '' ? null : value)),
      ])),
      Expanded(child: _asignaciones.isEmpty ? const Center(child: Text('No existen asignaciones registradas.'))
        : filtradas.isEmpty ? Center(child: Text(_turnoFiltro != null && query.isEmpty
          ? 'No hay personal asignado a este turno.' : 'No hay asignaciones que coincidan con la búsqueda.'))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 88), itemCount: filtradas.length,
          itemBuilder: (_, index) => _AsignacionCard(asignacion: filtradas[index], onEdit: () => _abrirFormulario(filtradas[index])))),
    ]);
  }
}

class _AsignacionCard extends StatelessWidget {
  const _AsignacionCard({required this.asignacion, required this.onEdit});
  final AsignacionTurno asignacion;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final a = asignacion;
    final t = a.turno;
    final p = a.personal;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t == null ? 'Turno no disponible' : 'Fecha: ${_fecha(t.fecha)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      if (t != null) ...[
        Text('Turno: ${_etiqueta(t.tipo)} · ${_hora(t.horaInicio)} - ${_hora(t.horaFin)}${_nocturno(t) ? ' (día siguiente)' : ''}'),
        Text('Área: ${t.area}'),
        if (t.estado == 'cancelado') const Text('Turno cancelado'),
      ],
      const SizedBox(height: 8),
      Text('Personal: ${p?.nombreCompleto ?? 'No disponible'}'),
      if (p != null) Text('Código: ${p.codigo}'),
      Text('Tipo: ${_etiqueta(p?.tipoPersonal ?? a.rolTurno)}'),
      Text('Rol en turno: ${_etiqueta(a.rolTurno)}'),
      Text('Especialidad: ${p?.especialidadNombre ?? 'Sin especialidad'}'),
      Chip(label: Text('Asistencia: ${_etiqueta(a.estadoAsistencia)}')),
      if (a.observaciones.isNotEmpty) Text('Observaciones: ${a.observaciones}'),
      TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
    ])));
  }
}

class _AsignacionForm extends StatefulWidget {
  const _AsignacionForm({this.asignacion});
  final AsignacionTurno? asignacion;
  @override
  State<_AsignacionForm> createState() => _AsignacionFormState();
}

class _AsignacionFormState extends State<_AsignacionForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _observaciones;
  List<Turno> _turnos = [];
  List<Personal> _personal = [];
  String? _turnoId, _personalId, _error, _errorOpciones;
  bool _cargando = true, _ocupado = false;
  GestionController get _controller => context.read<GestionController>();

  @override
  void initState() {
    super.initState();
    _observaciones = TextEditingController(text: widget.asignacion?.observaciones ?? '');
    _turnoId = widget.asignacion?.turnoId;
    _personalId = widget.asignacion?.personalId;
    _cargarOpciones();
  }

  @override
  void dispose() { _observaciones.dispose(); super.dispose(); }

  Future<void> _cargarOpciones() async {
    setState(() { _cargando = true; _errorOpciones = null; });
    try {
      final controller = _controller;
      final resultados = await Future.wait([controller.turnosParaAsignacion(), controller.personalParaAsignacion()]);
      if (!mounted) return;
      final turnos = resultados[0] as List<Turno>;
      final personal = resultados[1] as List<Personal>;
      final actual = widget.asignacion;
      // Conservar relaciones históricas al editar aunque ya no sean elegibles para altas.
      if (actual?.turno != null && !turnos.any((t) => t.id == actual!.turnoId)) turnos.add(actual!.turno!);
      if (actual?.personal != null && !personal.any((p) => p.id == actual!.personalId)) personal.add(actual!.personal!);
      setState(() {
        _turnos = turnos; _personal = personal;
        if (!_turnos.any((t) => t.id == _turnoId)) _turnoId = null;
        if (!_personal.any((p) => p.id == _personalId)) _personalId = null;
        _cargando = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() { _errorOpciones = mensajeErrorAsignacion(error); _cargando = false; });
      }
    }
  }

  Future<void> _guardar() async {
    if (_ocupado || !_form.currentState!.validate()) return;
    setState(() { _ocupado = true; _error = null; });
    try {
      await _controller.guardarAsignacion(id: widget.asignacion?.id,
        turnoId: _turnoId!, personalId: _personalId!, observaciones: _observaciones.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = mensajeErrorAsignacion(error));
    } finally { if (mounted) setState(() => _ocupado = false); }
  }

  @override
  Widget build(BuildContext context) {
    final persona = _personal.where((p) => p.id == _personalId).firstOrNull;
    return PopScope(canPop: !_ocupado, child: AlertDialog(
      title: Text(widget.asignacion == null ? 'Nueva asignación' : 'Editar asignación'),
      content: SizedBox(width: 640, child: _cargando ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
        : _errorOpciones != null ? _EstadoError(mensaje: _errorOpciones!, onRetry: _cargarOpciones)
        : Form(key: _form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_turnos.isEmpty) const Text('No hay turnos disponibles para asignar.'),
          DropdownButtonFormField<String>(
            key: ValueKey('turno-$_turnoId'), initialValue: _turnoId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Turno', border: OutlineInputBorder()),
            items: _turnos.map((t) => DropdownMenuItem(value: t.id!, enabled: t.estado != 'cancelado',
              child: Text('${_resumenTurno(t)}${t.estado == 'cancelado' ? ' · Cancelado' : ''}', maxLines: 3))).toList(),
            itemHeight: 80,
            onChanged: _ocupado ? null : (value) => setState(() => _turnoId = value),
            validator: (value) => value == null ? 'Selecciona un turno.' : null),
          const SizedBox(height: 12),
          if (_personal.isEmpty) const Text('No hay personal activo disponible para asignar.'),
          DropdownButtonFormField<String>(
            key: ValueKey('personal-$_personalId'), initialValue: _personalId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Personal', border: OutlineInputBorder()),
            items: _personal.map((p) => DropdownMenuItem(value: p.id!, enabled: p.estado == 'activo',
              child: Text('${p.nombreCompleto} · ${_etiqueta(p.tipoPersonal)} · ${p.especialidadNombre ?? 'Sin especialidad'} · Código: ${p.codigo}${p.estado != 'activo' ? ' · ${_etiqueta(p.estado)}' : ''}', maxLines: 3))).toList(),
            itemHeight: 80,
            onChanged: _ocupado ? null : (value) => setState(() => _personalId = value),
            validator: (value) => value == null ? 'Selecciona un personal.' : null),
          if (persona != null) ...[const SizedBox(height: 12), Text('Rol en turno: ${_etiqueta(persona.tipoPersonal)}')],
          const SizedBox(height: 12),
          TextFormField(controller: _observaciones, enabled: !_ocupado, minLines: 2, maxLines: 4,
            decoration: const InputDecoration(labelText: 'Observaciones', border: OutlineInputBorder())),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        ])))),
      actions: [
        TextButton(onPressed: _ocupado ? null : () => Navigator.pop(context), child: const Text('Cerrar')),
        FilledButton(onPressed: _ocupado || _cargando || _errorOpciones != null || _turnos.isEmpty || _personal.isEmpty ? null : _guardar,
          child: Text(_ocupado ? 'Guardando...' : 'Guardar')),
      ],
    ));
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onRetry});
  final String mensaje;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error), const SizedBox(height: 12),
    Text(mensaje, textAlign: TextAlign.center), const SizedBox(height: 16),
    FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
  ])));
}

String _fecha(DateTime fecha) => '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
String _hora(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;
bool _nocturno(Turno turno) => turno.horaFin.compareTo(turno.horaInicio) < 0;
String _resumenTurno(Turno t) => '${_fecha(t.fecha)} · ${_etiqueta(t.tipo)} · ${_hora(t.horaInicio)} - ${_hora(t.horaFin)}${_nocturno(t) ? ' (día siguiente)' : ''} · Área: ${t.area}';
String _etiqueta(String value) => const {
  'manana': 'Mañana', 'tarde': 'Tarde', 'noche': 'Noche', 'personalizado': 'Personalizado',
  'medico': 'Médico', 'enfermero': 'Enfermero', 'pasante': 'Pasante',
  'pendiente': 'Pendiente', 'cumplido': 'Cumplido', 'falta': 'Falta',
  'activo': 'Activo', 'inactivo': 'Inactivo', 'suspendido': 'Suspendido',
}[value] ?? value;
