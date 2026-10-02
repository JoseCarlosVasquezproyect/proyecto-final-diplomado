import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';
import '../models/personal_errors.dart';

const _sexos = ['masculino', 'femenino', 'otro'];
const _tipos = ['medico', 'enfermero', 'pasante'];
const _estados = ['activo', 'inactivo', 'suspendido'];
String _etiqueta(String value) =>
    const {
      'masculino': 'Masculino',
      'femenino': 'Femenino',
      'otro': 'Otro',
      'medico': 'Médico',
      'enfermero': 'Enfermero',
      'pasante': 'Pasante',
      'activo': 'Activo',
      'inactivo': 'Inactivo',
      'suspendido': 'Suspendido',
    }[value] ??
    value;

class PersonalModuleScreen extends StatefulWidget {
  const PersonalModuleScreen({super.key});
  @override
  State<PersonalModuleScreen> createState() => _PersonalModuleScreenState();
}

class _PersonalModuleScreenState extends State<PersonalModuleScreen> {
  List<Personal> _personal = [];
  final _busqueda = TextEditingController();
  bool _cargando = true;
  String? _error;
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

  Future<void> _cargar({bool limpiarBusqueda = false}) async {
    if (!mounted) return;
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
      if (limpiarBusqueda) _busqueda.clear();
    });
    try {
      final rows = await context.read<GestionController>().listarPersonal();
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _personal = rows;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _error = mensajeErrorPersonal(error);
        _cargando = false;
      });
    }
  }

  Future<void> _abrirFormulario([Personal? personal]) async {
    final resultado = await Navigator.push<_Resultado>(
      context,
      MaterialPageRoute(builder: (_) => PersonalForm(initial: personal)),
    );
    if (!mounted || resultado == null) return;
    await _cargar(limpiarBusqueda: true);
    if (!mounted) return;
    final mensaje = resultado == _Resultado.baja
        ? 'Personal dado de baja correctamente.'
        : personal == null
            ? 'Personal creado correctamente.'
            : 'Personal actualizado correctamente.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gestión de Personal')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo Personal')),
        body: _contenido(),
      );

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _EstadoError(mensaje: _error!, onRetry: _cargar);
    final consulta = _busqueda.text.trim().toLowerCase();
    final rows = _personal
        .where((p) => [
              p.codigo,
              p.nombre,
              p.apellido,
              p.nombreCompleto,
              p.ci ?? '',
              p.tipoPersonal,
              _etiqueta(p.tipoPersonal),
              p.especialidadNombre ?? '',
              p.estado
            ].any((value) => value.toLowerCase().contains(consulta)))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _busqueda,
            decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Código, nombre, CI, tipo, especialidad o estado',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          )),
      Expanded(
        child: _personal.isEmpty
            ? const Center(child: Text('No existe personal registrado.'))
            : rows.isEmpty
                ? const Center(
                    child:
                        Text('No hay personal que coincida con la búsqueda.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final p = rows[index];
                      return Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.codigo,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge),
                                    Text(p.nombreCompleto,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('Tipo: ${_etiqueta(p.tipoPersonal)}'),
                                    Text(
                                        'Especialidad: ${p.especialidadNombre ?? 'Sin especialidad'}'),
                                    Text('CI: ${p.ci ?? 'Sin registrar'}'),
                                    Text('Sexo: ${_etiqueta(p.sexo)}'),
                                    Text(
                                        'Teléfono: ${p.telefono ?? 'Sin registrar'}'),
                                    Chip(
                                        label: Text(
                                            'Estado: ${_etiqueta(p.estado)}')),
                                    TextButton.icon(
                                        onPressed: () => _abrirFormulario(p),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Editar')),
                                  ])));
                    }),
      ),
    ]);
  }
}

enum _Resultado { guardado, baja }

class PersonalForm extends StatefulWidget {
  const PersonalForm({super.key, this.initial});
  final Personal? initial;
  @override
  State<PersonalForm> createState() => _PersonalFormState();
}

class _PersonalFormState extends State<PersonalForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _codigo, _nombre, _apellido, _ci, _telefono;
  final _correo = TextEditingController();
  final _password = TextEditingController();
  late String _sexo, _tipo, _estado;
  String? _especialidadId;
  List<Especialidad> _especialidades = [];
  bool _cargando = true, _ocupado = false, _ocultarPassword = true;
  String? _errorOpciones, _error;
  bool get _creando => widget.initial == null;
  GestionController get _controller => context.read<GestionController>();

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _codigo = TextEditingController(text: p?.codigo ?? '');
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _apellido = TextEditingController(text: p?.apellido ?? '');
    _ci = TextEditingController(text: p?.ci ?? '');
    _telefono = TextEditingController(text: p?.telefono ?? '');
    _sexo = p?.sexo ?? 'masculino';
    _tipo = p?.tipoPersonal ?? 'medico';
    _estado = p?.estado ?? 'activo';
    _especialidadId = p?.especialidadId;
    _cargarEspecialidades();
  }

  List<TextEditingController> get _campos =>
      [_codigo, _nombre, _apellido, _ci, _telefono, _correo, _password];
  void _limpiar() {
    for (final campo in _campos) {
      campo.clear();
    }
  }

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.clear();
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarEspecialidades() async {
    setState(() {
      _cargando = true;
      _errorOpciones = null;
    });
    try {
      final datos = await _controller.especialidadesParaPersonal(
          actualId: widget.initial?.especialidadId);
      if (!mounted) return;
      final actual = widget.initial;
      if (actual?.especialidadId != null &&
          !datos.any((e) => e.id == actual!.especialidadId)) {
        datos.add(Especialidad(
            id: actual!.especialidadId,
            nombre: actual.especialidadNombre ?? 'Especialidad actual',
            estado: 'inactivo'));
        datos.sort((a, b) => a.nombre.compareTo(b.nombre));
      }
      setState(() {
        _especialidades = datos;
        _cargando = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorOpciones = mensajeErrorPersonal(error);
          _cargando = false;
        });
      }
    }
  }

  Future<void> _guardar() async {
    if (_ocupado || !_form.currentState!.validate()) return;
    final personal = Personal(
        id: widget.initial?.id,
        codigo: _codigo.text.trim(),
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        ci: _ci.text.trim(),
        telefono: _telefono.text.trim(),
        sexo: _sexo,
        tipoPersonal: _tipo,
        estado: _estado,
        especialidadId: _especialidadId);
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (_creando) {
        await _controller.crearPersonal(personal,
            email: _correo.text.trim().toLowerCase(), password: _password.text);
      } else {
        await _controller.actualizarPersonal(personal);
      }
      if (!mounted) return;
      _limpiar();
      Navigator.pop(context, _Resultado.guardado);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorPersonal(error);
          if (_creando) _password.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _darDeBaja() async {
    if (_ocupado) return;
    final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Dar de baja'),
              content: const Text(
                  '¿Confirmas que deseas dar de baja a este personal?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Dar de baja'))
              ],
            ));
    if (!mounted || confirmado != true || _ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _controller.darDeBajaPersonal(widget.initial!.id!);
      if (!mounted) return;
      _limpiar();
      Navigator.pop(context, _Resultado.baja);
    } catch (error) {
      if (mounted) setState(() => _error = mensajeErrorPersonal(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(
            title: Text(_creando ? 'Nuevo Personal' : 'Editar Personal')),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _errorOpciones != null
                ? _EstadoError(
                    mensaje: _errorOpciones!, onRetry: _cargarEspecialidades)
                : Form(
                    key: _form,
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      Text('Datos del personal',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _campo(_codigo, 'Código', minimo: 2, maximo: 30),
                      _campo(_nombre, 'Nombre', minimo: 2, maximo: 80),
                      _campo(_apellido, 'Apellido', minimo: 2, maximo: 80),
                      _campo(_ci, 'CI'),
                      _selector(
                          'Sexo', _sexo, _sexos, (value) => _sexo = value),
                      _campo(_telefono, 'Teléfono'),
                      _selector('Tipo de personal', _tipo, _tipos,
                          (value) => _tipo = value),
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: _especialidadId ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Especialidad',
                                border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(
                                  value: '', child: Text('Sin especialidad')),
                              ..._especialidades.map((e) => DropdownMenuItem(
                                  value: e.id!,
                                  child: Text(
                                      '${e.nombre}${e.estado == 'inactivo' ? ' (Inactiva)' : ''}')))
                            ],
                            onChanged: _ocupado
                                ? null
                                : (value) => setState(() => _especialidadId =
                                    value == '' ? null : value),
                          )),
                      _selector('Estado', _estado, _estados,
                          (value) => _estado = value),
                      if (_creando) ...[
                        const SizedBox(height: 12),
                        Text('Datos de acceso',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _correo,
                            enabled: !_ocupado,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                labelText: 'Correo',
                                border: OutlineInputBorder()),
                            validator: (value) {
                              final correo = value?.trim() ?? '';
                              if (correo.isEmpty) {
                                return 'El correo es obligatorio.';
                              }
                              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(correo)) {
                                return 'Ingresa un correo válido.';
                              }
                              return null;
                            }),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _password,
                            enabled: !_ocupado,
                            obscureText: _ocultarPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                                labelText: 'Contraseña temporal',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                    tooltip: _ocultarPassword
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    onPressed: _ocupado
                                        ? null
                                        : () => setState(() =>
                                            _ocultarPassword =
                                                !_ocultarPassword),
                                    icon: Icon(_ocultarPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined))),
                            validator: (value) => value == null || value.isEmpty
                                ? 'La contraseña temporal es obligatoria.'
                                : value.length < 10
                                    ? 'La contraseña debe tener al menos 10 caracteres.'
                                    : null),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _ocupado ? null : _guardar,
                          child: Text(_ocupado ? 'Guardando...' : 'Guardar')),
                      if (!_creando && widget.initial!.estado != 'inactivo')
                        TextButton(
                            onPressed: _ocupado ? null : _darDeBaja,
                            child: const Text('Dar de baja')),
                      TextButton(
                          onPressed:
                              _ocupado ? null : () => Navigator.pop(context),
                          child: const Text('Cerrar')),
                    ])),
      ));

  Widget _campo(TextEditingController controller, String label,
          {int? minimo, int? maximo}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
            controller: controller,
            enabled: !_ocupado,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
            validator: minimo == null
                ? null
                : (value) {
                    final texto = value?.trim() ?? '';
                    if (texto.isEmpty) return '$label es obligatorio.';
                    if (texto.length < minimo) {
                      return '$label debe tener al menos $minimo caracteres.';
                    }
                    if (maximo != null && texto.length > maximo) {
                      return '$label debe tener como máximo $maximo caracteres.';
                    }
                    return null;
                  }),
      );
  Widget _selector(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
            items: values
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(_etiqueta(item))))
                .toList(),
            onChanged:
                _ocupado ? null : (item) => setState(() => onChanged(item!)),
            validator: (item) =>
                values.contains(item) ? null : 'Selecciona un valor válido.'),
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
          ])));
}
