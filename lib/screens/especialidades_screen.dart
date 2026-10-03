import '../widgets/responsive_content.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';

class EspecialidadesScreen extends StatefulWidget {
  const EspecialidadesScreen({super.key});

  @override
  State<EspecialidadesScreen> createState() => _EspecialidadesScreenState();
}

class _EspecialidadesScreenState extends State<EspecialidadesScreen> {
  List<Especialidad> _especialidades = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';
  final _busquedaController = TextEditingController();
  int _consulta = 0;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool limpiarBusqueda = false}) async {
    if (!mounted) return;
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
      if (limpiarBusqueda) {
        _busqueda = '';
        _busquedaController.clear();
      }
    });
    try {
      final datos =
          await context.read<GestionController>().listarEspecialidades();
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _especialidades = datos;
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

  Future<void> _abrirFormulario([Especialidad? especialidad]) async {
    final resultado = await showDialog<_Resultado>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EspecialidadForm(especialidad: especialidad),
    );
    if (!mounted || resultado == null) return;
    // Consultar nuevamente la base y reemplazar la lista que pinta este State.
    // Limpiar la búsqueda permite ver también registros cuyo nombre/estado cambió.
    await _cargar(limpiarBusqueda: true);
    if (!mounted) return;
    final mensaje = resultado == _Resultado.baja
        ? 'Especialidad dada de baja correctamente.'
        : especialidad == null
            ? 'Especialidad creada correctamente.'
            : 'Especialidad actualizada correctamente.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Especialidades')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
        ),
        body: ResponsiveContent(child: _contenido()),
      );

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar')),
          ]),
        ),
      );
    }
    final consulta = _busqueda.trim().toLowerCase();
    final filtrados = _especialidades
        .where((item) => [item.nombre, item.descripcion ?? '', item.estado]
            .any((valor) => valor.toLowerCase().contains(consulta)))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _busquedaController,
          decoration: const InputDecoration(
              labelText: 'Buscar',
              hintText: 'Nombre, descripción o estado',
              prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => _busqueda = value),
        ),
      ),
      Expanded(
        child: _especialidades.isEmpty
            ? const Center(
                child: Text('No existen especialidades registradas.'))
            : filtrados.isEmpty
                ? const Center(
                    child: Text(
                        'No hay especialidades que coincidan con la búsqueda.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: filtrados.length,
                    itemBuilder: (_, index) {
                      final item = filtrados[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.nombre,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(item.descripcion?.isNotEmpty == true
                                    ? item.descripcion!
                                    : 'Sin descripción'),
                                const SizedBox(height: 6),
                                StatusChip(
                                    status: item.estado,
                                    label:
                                        'Estado: ${_etiquetaEstado(item.estado)}'),
                                TextButton.icon(
                                    onPressed: () => _abrirFormulario(item),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar')),
                              ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

enum _Resultado { guardado, baja }

class _EspecialidadForm extends StatefulWidget {
  const _EspecialidadForm({this.especialidad});
  final Especialidad? especialidad;

  @override
  State<_EspecialidadForm> createState() => _EspecialidadFormState();
}

class _EspecialidadFormState extends State<_EspecialidadForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late String _estado;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.especialidad?.nombre ?? '');
    _descripcion =
        TextEditingController(text: widget.especialidad?.descripcion ?? '');
    _estado = widget.especialidad?.estado ?? 'activo';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_ocupado || !_formKey.currentState!.validate()) return;
    await _ejecutar(
        () => context.read<GestionController>().guardarEspecialidad(
              Especialidad(
                  id: widget.especialidad?.id,
                  nombre: _nombre.text.trim(),
                  descripcion: _descripcion.text.trim(),
                  estado: _estado),
            ),
        _Resultado.guardado);
  }

  Future<void> _darDeBaja() async {
    if (_ocupado) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dar de baja'),
        content:
            const Text('¿Confirmas que deseas dar de baja esta especialidad?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Dar de baja')),
        ],
      ),
    );
    if (!mounted || confirmado != true || _ocupado) return;
    await _ejecutar(
        () => context
            .read<GestionController>()
            .darDeBajaEspecialidad(widget.especialidad!.id!),
        _Resultado.baja);
  }

  Future<void> _ejecutar(
      Future<void> Function() operacion, _Resultado resultado) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await operacion();
      if (mounted) Navigator.pop(context, resultado);
    } catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_ocupado,
        child: AlertDialog(
          title: Text(widget.especialidad == null
              ? 'Nueva especialidad'
              : 'Editar especialidad'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nombre,
                        enabled: !_ocupado,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) {
                          final nombre = value?.trim() ?? '';
                          if (nombre.isEmpty)
                            return 'El nombre es obligatorio.';
                          if (nombre.length < 2)
                            return 'El nombre debe tener al menos 2 caracteres.';
                          if (nombre.length > 100)
                            return 'El nombre debe tener como máximo 100 caracteres.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _descripcion,
                          enabled: !_ocupado,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'Descripción')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: ['activo', 'inactivo']
                            .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(_etiquetaEstado(value))))
                            .toList(),
                        onChanged: _ocupado
                            ? null
                            : (value) => setState(() => _estado = value!),
                        validator: (value) =>
                            ['activo', 'inactivo'].contains(value)
                                ? null
                                : 'Selecciona un estado válido.',
                      ),
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
            if (widget.especialidad?.estado == 'activo')
              TextButton(
                  onPressed: _ocupado ? null : _darDeBaja,
                  child: const Text('Dar de baja')),
            TextButton(
                onPressed: _ocupado ? null : () => Navigator.pop(context),
                child: const Text('Cerrar')),
            FilledButton(
                onPressed: _ocupado ? null : _guardar,
                child: Text(_ocupado ? 'Guardando...' : 'Guardar')),
          ],
        ),
      );
}

String _etiquetaEstado(String estado) =>
    estado == 'activo' ? 'Activo' : 'Inactivo';

String _mensajeError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '23505')
      return 'Ya existe una especialidad con ese nombre.';
    if (error.code == '23514')
      return 'Revisa el nombre y el estado de la especialidad.';
    if (error.code == '42501')
      return 'No tienes permisos para realizar esta operación.';
    if (error.code == 'PGRST116')
      return 'No se pudo acceder a la especialidad. Recarga la lista e inténtalo nuevamente.';
  }
  if (error is AuthException)
    return 'La sesión no es válida. Vuelve a iniciar sesión.';
  return 'No se pudo completar la operación de especialidades. Revisa tu conexión e inténtalo nuevamente.';
}
