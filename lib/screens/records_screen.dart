import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/registro.dart';
import '../repositories/registro_repository.dart';
import 'record_form_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool _loading = true;
  String? _error;
  List<Registro> _items = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await context.read<RegistroRepository>().fetchAll();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Registro? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecordFormScreen(initial: item)),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(Registro item) async {
    if (item.id == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar "${item.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await context.read<RegistroRepository>().delete(item.id!);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registros demo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 54),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [SizedBox(height: 160), Center(child: Text('Todavía no hay registros. Crea el primero.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(child: Text(item.estado.substring(0, 1).toUpperCase())),
                                title: Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${item.estado} · ${item.descripcion.isEmpty ? 'Sin descripción' : item.descripcion}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _openForm(item);
                                    if (value == 'delete') _delete(item);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
