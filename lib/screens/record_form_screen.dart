import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/registro.dart';
import '../repositories/registro_repository.dart';

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, this.initial});
  final Registro? initial;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.titulo ?? '');
    _description = TextEditingController(text: widget.initial?.descripcion ?? '');
    _status = widget.initial?.estado ?? 'activo';
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = context.read<RegistroRepository>();
      final item = Registro(
        id: widget.initial?.id,
        titulo: _title.text,
        descripcion: _description.text,
        estado: _status,
        createdAt: widget.initial?.createdAt,
      );
      if (widget.initial == null) {
        await repo.create(item);
      } else {
        await repo.update(item);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Nuevo registro' : 'Editar registro')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.length < 3) return 'Mínimo 3 caracteres';
                if (text.length > 80) return 'Máximo 80 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'activo', child: Text('Activo')),
                DropdownMenuItem(value: 'cerrado', child: Text('Cerrado')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 'activo'),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_busy ? 'Guardando...' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
