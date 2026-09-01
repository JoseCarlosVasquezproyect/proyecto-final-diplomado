import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';

class FieldSpec { const FieldSpec(this.key, this.label, {this.required = false, this.options = const []}); final String key, label; final bool required; final List<String> options; }
class EntitySpec { const EntitySpec({required this.title, required this.table, required this.fields, this.order = 'created_at', this.readOnly = false}); final String title, table, order; final List<FieldSpec> fields; final bool readOnly; }
class EntityScreen extends StatefulWidget { const EntityScreen({super.key, required this.spec}); final EntitySpec spec; @override State<EntityScreen> createState() => _EntityScreenState(); }
class _EntityScreenState extends State<EntityScreen> {
  late Future<List<Json>> items; String query = '';
  @override void initState() { super.initState(); items = _load(); }
  Future<List<Json>> _load() => context.read<GestionController>().listar(widget.spec.table, order: widget.spec.order);
  void _refresh() {
    final nextItems = _load();
    setState(() => items = nextItems);
  }
  Future<void> edit([Json? row]) async { final saved = await showDialog<bool>(context: context, builder: (_) => _EntityForm(spec: widget.spec, row: row)); if (saved == true && mounted) _refresh(); }
  Future<void> menu(String action, Json row) async {
    if (action == 'editar') return edit(row);
    if (action == 'ver') { await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Detalle'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: widget.spec.fields.where((f) => row[f.key] != null).map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${f.label}: ${row[f.key]}'))).toList()), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))])); return; }
    final activo = row['estado'] == 'activo';
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(activo ? 'Desactivar registro' : 'Activar registro'), content: Text('¿Deseas ${activo ? 'desactivar' : 'activar'} este registro?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(activo ? 'Desactivar' : 'Activar'))]));
    if (ok != true || !mounted) return;
    final controller = context.read<GestionController>();
    await controller.guardar(widget.spec.table, {'estado': activo ? 'inactivo' : 'activo'}, id: row['id'].toString(), descripcion: '${activo ? 'Desactivó' : 'Activó'} un registro');
    if (!mounted) return;
    _refresh();
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.spec.title)), floatingActionButton: widget.spec.readOnly ? null : FloatingActionButton.extended(onPressed: edit, label: const Text('Nuevo'), icon: const Icon(Icons.add)), body: FutureBuilder<List<Json>>(future: items, builder: (_, s) { if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator()); if (s.hasError) return const Center(child: Text('No se pudieron cargar los datos.')); final rows = (s.data ?? []).where((r) => r.values.join(' ').toLowerCase().contains(query.toLowerCase())).toList(); return Column(children: [Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: const InputDecoration(labelText: 'Buscar', border: OutlineInputBorder()), onChanged: (v) => setState(() => query = v))), Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final r = rows[i]; return Card(child: ListTile(title: Text('${r['nombre'] ?? r['codigo'] ?? r['id']} ${r['apellido'] ?? ''}'), subtitle: Text(widget.spec.fields.take(3).map((f) => '${f.label}: ${r[f.key] ?? '-'}').join(' · ')), trailing: widget.spec.readOnly ? null : const Icon(Icons.edit), onTap: widget.spec.readOnly ? null : () => edit(r))); }))]); }));
}
class _EntityForm extends StatefulWidget { const _EntityForm({required this.spec, this.row}); final EntitySpec spec; final Json? row; @override State<_EntityForm> createState() => _EntityFormState(); }
class _EntityFormState extends State<_EntityForm> {
  final form = GlobalKey<FormState>(); bool busy = false; late final Map<String, TextEditingController> text; late final Map<String, String?> choice;
  String? initialChoice(FieldSpec field) { final value = widget.row?[field.key]?.toString(); return field.options.contains(value) ? value : null; }
  @override void initState() { super.initState(); text = {for (final f in widget.spec.fields.where((f) => f.options.isEmpty)) f.key: TextEditingController(text: widget.row?[f.key]?.toString() ?? '')}; choice = {for (final f in widget.spec.fields.where((f) => f.options.isNotEmpty)) f.key: initialChoice(f)}; }
  @override void dispose() { for (final c in text.values) { c.dispose(); } super.dispose(); }
  Future<void> save() async { if (!form.currentState!.validate()) return; setState(() => busy = true); final values = <String, dynamic>{for (final f in widget.spec.fields) f.key: f.options.isEmpty ? text[f.key]!.text.trim() : choice[f.key]}; try { await context.read<GestionController>().guardar(widget.spec.table, values, id: widget.row?['id']?.toString()); if (mounted) Navigator.pop(context, true); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar el registro.'))); } finally { if (mounted) setState(() => busy = false); } }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.row == null ? 'Nuevo ${widget.spec.title}' : 'Editar ${widget.spec.title}'), content: SizedBox(width: 520, child: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: widget.spec.fields.map(field).toList())))), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Guardando...' : 'Guardar'))]);
  Widget field(FieldSpec f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: f.options.isEmpty ? TextFormField(controller: text[f.key], decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()), validator: f.required ? (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null : null) : DropdownButtonFormField<String>(initialValue: choice[f.key], decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()), items: f.options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => choice[f.key] = v), validator: f.required ? (v) => v == null ? 'Selecciona una opcion' : null : null));
}
