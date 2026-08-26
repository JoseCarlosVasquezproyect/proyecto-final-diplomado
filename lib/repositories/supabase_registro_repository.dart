import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/registro.dart';
import 'registro_repository.dart';

class SupabaseRegistroRepository implements RegistroRepository {
  SupabaseRegistroRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No existe una sesión autenticada');
    return user.id;
  }

  @override
  Future<List<Registro>> fetchAll() async {
    final data = await _client
        .from('registros_demo')
        .select()
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Registro.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<void> create(Registro registro) async {
    await _client
        .from('registros_demo')
        .insert(registro.toInsertMap(_userId));
  }

  @override
  Future<void> update(Registro registro) async {
    if (registro.id == null) throw ArgumentError('El registro no tiene id');
    await _client
        .from('registros_demo')
        .update(registro.toUpdateMap())
        .eq('id', registro.id!);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('registros_demo').delete().eq('id', id);
  }
}
