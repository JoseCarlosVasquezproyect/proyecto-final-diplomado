import '../widgets/responsive_content.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';

const _tipos = ['manana', 'tarde', 'noche', 'personalizado'];
const _estados = ['programado', 'en_curso', 'finalizado', 'cancelado'];

class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});
  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  List<Turno> _turnos = [];
  bool _cargando = true;
  String? _error;
  int _consulta = 0;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarTurnos();
  }

  Future<void> _cargarTurnos({String? turnoModificadoId}) async {
    if (!mounted) return;
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (kDebugMode)
        debugPrint('[Turnos] Consulta $consulta: consultando Supabase');
      final datos = await context.read<GestionController>().listarTurnos();
      if (kDebugMode) {
        debugPrint(
            '[Turnos] Consulta $consulta: ${datos.length} registros recibidos');
        for (final turno in datos) {
          if (turnoModificadoId != null && turno.id == turnoModificadoId) {
            debugPrint('[Turnos] Recibido id=${turno.id}: ${turno.toMap()}');
          }
        }
      }
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _turnos = datos;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _error = _mensajeError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _abrirFormulario([Turno? turno]) async {
    final resultado = await showDialog<_ResultadoFormulario>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TurnoForm(turno: turno),
    );
    if (!mounted || resultado == null) return;
    await _cargarTurnos(turnoModificadoId: turno?.id);
    if (!mounted) return;
    final mensaje = resultado == _ResultadoFormulario.cancelado
        ? 'Turno cancelado correctamente.'
        : turno == null
            ? 'Turno creado correctamente.'
            : 'Turno actualizado correctamente.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Turnos')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
        ),
        body: ResponsiveContent(child: Builder(
          builder: (context) {
            if (_cargando) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return _EstadoError(mensaje: _error!, onRetry: _cargarTurnos);
            }
            final turnos = _turnos;
            final consulta = _busqueda.trim().toLowerCase();
            final filtrados = turnos.where((turno) {
              if (consulta.isEmpty) return true;
              return [
                turno.area,
                turno.tipo,
                _etiqueta(turno.tipo),
                turno.estado,
                _etiqueta(turno.estado),
                _fechaIso(turno.fecha),
                _fechaLegible(turno.fecha)
              ].any((valor) => valor.toLowerCase().contains(consulta));
            }).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: 'Buscar',
                      hintText: 'Área, tipo, estado o fecha',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) => setState(() => _busqueda = value),
                ),
              ),
              Expanded(
                child: turnos.isEmpty
                    ? const Center(
                        child: Text('No existen turnos registrados.'))
                    : filtrados.isEmpty
                        ? const Center(
                            child: Text(
                                'No hay turnos que coincidan con la búsqueda.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) => _TurnoCard(
                                turno: filtrados[i],
                                onEdit: () => _abrirFormulario(filtrados[i])),
                          ),
              ),
            ]);
          },
        )),
      );
}

class _TurnoCard extends StatelessWidget {
  const _TurnoCard({required this.turno, required this.onEdit});
  final Turno turno;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final observaciones = turno.observaciones?.trim() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_fechaLegible(turno.fecha),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  '${_etiqueta(turno.tipo)} · ${_horaCorta(turno.horaInicio)} - ${_horaCorta(turno.horaFin)}'),
              const SizedBox(height: 6),
              Text(turno.area),
              StatusChip(
                  status: turno.estado,
                  label: 'Estado: ${_etiqueta(turno.estado)}'),
              if (observaciones.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Observaciones: $observaciones')
              ],
            ]),
          ),
          IconButton(
              tooltip: 'Editar turno',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined)),
        ]),
      ),
    );
  }
}

enum _ResultadoFormulario { guardado, cancelado }

class _TurnoForm extends StatefulWidget {
  const _TurnoForm({this.turno});
  final Turno? turno;
  @override
  State<_TurnoForm> createState() => _TurnoFormState();
}

class _TurnoFormState extends State<_TurnoForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _fecha;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFin;
  late String _tipo;
  late String _estado;
  late final TextEditingController _area;
  late final TextEditingController _observaciones;
  bool _ocupado = false;
  String? _error;
  bool get _editando => widget.turno != null;

  @override
  void initState() {
    super.initState();
    final turno = widget.turno;
    _fecha = turno?.fecha ?? DateTime.now();
    _horaInicio =
        _parseHora(turno?.horaInicio) ?? const TimeOfDay(hour: 8, minute: 0);
    _horaFin =
        _parseHora(turno?.horaFin) ?? const TimeOfDay(hour: 16, minute: 0);
    _tipo = _tipos.contains(turno?.tipo) ? turno!.tipo : 'manana';
    _estado = _estados.contains(turno?.estado) ? turno!.estado : 'programado';
    _area = TextEditingController(text: turno?.area ?? '');
    _observaciones = TextEditingController(text: turno?.observaciones ?? '');
  }

  @override
  void dispose() {
    _area.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _fecha,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (mounted && value != null) setState(() => _fecha = value);
  }

  Future<void> _elegirHora(bool inicio) async {
    final value = await showTimePicker(
        context: context, initialTime: inicio ? _horaInicio : _horaFin);
    if (!mounted || value == null) return;
    setState(() {
      if (inicio) {
        _horaInicio = value;
      } else {
        _horaFin = value;
      }
      _error = null;
    });
  }

  Future<void> _guardar() async {
    if (_ocupado) return;
    if (!_formKey.currentState!.validate()) return;
    if (_horaInicio.hour == _horaFin.hour &&
        _horaInicio.minute == _horaFin.minute) {
      setState(() =>
          _error = 'La hora de inicio y la hora de fin deben ser distintas.');
      return;
    }
    if (!_tipos.contains(_tipo) || !_estados.contains(_estado)) {
      setState(() => _error = 'El tipo o el estado seleccionado no es válido.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (kDebugMode)
        debugPrint(
            '[Turnos] ${_editando ? 'Editar' : 'Crear'}: inicio id=${widget.turno?.id}');
      await context.read<GestionController>().guardarTurno(Turno(
            id: widget.turno?.id,
            fecha: _fecha,
            tipo: _tipo,
            horaInicio: _horaSql(_horaInicio),
            horaFin: _horaSql(_horaFin),
            area: _area.text.trim(),
            estado: _estado,
            observaciones: _observaciones.text.trim(),
          ));
      if (kDebugMode) debugPrint('[Turnos] Guardado confirmado por Supabase');
      if (mounted) Navigator.pop(context, _ResultadoFormulario.guardado);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelarTurno() async {
    if (_ocupado) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar turno'),
        content: const Text('¿Confirmas que deseas cancelar este turno?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancelar turno')),
        ],
      ),
    );
    if (confirmado != true || !mounted || _ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (kDebugMode)
        debugPrint('[Turnos] Cancelar: inicio id=${widget.turno!.id}');
      await context.read<GestionController>().cancelarTurno(widget.turno!.id!);
      if (kDebugMode)
        debugPrint('[Turnos] Cancelación confirmada por Supabase');
      if (mounted) Navigator.pop(context, _ResultadoFormulario.cancelado);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_editando ? 'Editar turno' : 'Nuevo turno'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Selector(
                        label: 'Fecha',
                        value: _fechaLegible(_fecha),
                        icon: Icons.calendar_today_outlined,
                        onTap: _ocupado ? null : _elegirFecha),
                    const SizedBox(height: 12),
                    _desplegable(
                        'Tipo', _tipo, _tipos, (value) => _tipo = value),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _Selector(
                              label: 'Hora de inicio',
                              value: _horaSql(_horaInicio),
                              icon: Icons.schedule,
                              onTap:
                                  _ocupado ? null : () => _elegirHora(true))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _Selector(
                              label: 'Hora de fin',
                              value: _horaSql(_horaFin),
                              icon: Icons.schedule,
                              onTap:
                                  _ocupado ? null : () => _elegirHora(false))),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _area,
                      enabled: !_ocupado,
                      decoration: const InputDecoration(labelText: 'Área'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'El área es obligatoria.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _observaciones,
                        enabled: !_ocupado,
                        minLines: 2,
                        maxLines: 4,
                        decoration:
                            const InputDecoration(labelText: 'Observaciones')),
                    const SizedBox(height: 12),
                    _desplegable('Estado', _estado, _estados,
                        (value) => _estado = value),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))
                    ],
                  ]),
            ),
          ),
        ),
        actions: [
          if (_editando && widget.turno!.estado != 'cancelado')
            TextButton(
                onPressed: _ocupado ? null : _cancelarTurno,
                child: const Text('Cancelar turno')),
          TextButton(
              onPressed: _ocupado ? null : () => Navigator.pop(context),
              child: const Text('Cerrar')),
          FilledButton(
              onPressed: _ocupado ? null : _guardar,
              child: Text(_ocupado ? 'Guardando...' : 'Guardar')),
        ],
      );

  Widget _desplegable(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) =>
                DropdownMenuItem(value: item, child: Text(_etiqueta(item))))
            .toList(),
        onChanged: _ocupado ? null : (item) => setState(() => onChanged(item!)),
      );
}

class _Selector extends StatelessWidget {
  const _Selector(
      {required this.label,
      required this.value,
      required this.icon,
      required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label, suffixIcon: Icon(icon), enabled: onTap != null),
          child: Text(value),
        ),
      );
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onRetry});
  final String mensaje;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar')),
          ]),
        ),
      );
}

String _mensajeError(Object error) {
  if (error is AuthException)
    return 'La sesión no es válida. Vuelve a iniciar sesión e inténtalo nuevamente.';
  if (error is PostgrestException) {
    if (error.code == '23514')
      return 'Los datos del turno no cumplen las reglas permitidas.';
    if (error.code == '42501')
      return 'No tienes permisos para realizar esta operación.';
    return 'Supabase no pudo procesar los turnos: ${error.message}';
  }
  return 'No se pudo completar la operación. Revisa tu conexión e inténtalo nuevamente.';
}

String _fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
String _fechaLegible(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year.toString().padLeft(4, '0')}';
String _horaSql(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
String _horaCorta(String hora) {
  final partes = hora.split(':');
  return partes.length >= 2 ? '${partes[0]}:${partes[1]}' : hora;
}

TimeOfDay? _parseHora(String? value) {
  if (value == null) return null;
  final partes = value.split(':');
  if (partes.length < 2) return null;
  final hora = int.tryParse(partes[0]);
  final minuto = int.tryParse(partes[1]);
  if (hora == null || minuto == null || hora > 23 || minuto > 59) return null;
  return TimeOfDay(hour: hora, minute: minuto);
}

String _etiqueta(String value) =>
    const {
      'manana': 'Mañana',
      'tarde': 'Tarde',
      'noche': 'Noche',
      'personalizado': 'Personalizado',
      'programado': 'Programado',
      'en_curso': 'En curso',
      'finalizado': 'Finalizado',
      'cancelado': 'Cancelado',
    }[value] ??
    value;
