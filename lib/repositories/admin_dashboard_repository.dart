import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminDashboardPeriod {
  today(1, 'Hoy'),
  last7Days(7, 'Últimos 7 días'),
  last30Days(30, 'Últimos 30 días');

  const AdminDashboardPeriod(this.days, this.label);
  final int days;
  final String label;
}

class DashboardAssignment {
  const DashboardAssignment({required this.attendanceState, this.personalName});
  final String attendanceState;
  final String? personalName;
}

class DashboardShift {
  const DashboardShift({
    required this.id,
    required this.date,
    required this.type,
    required this.start,
    required this.end,
    required this.area,
    required this.state,
    required this.assignees,
  });

  final String id, type, start, end, area, state;
  final DateTime date;
  final List<DashboardAssignment> assignees;

  factory DashboardShift.fromMap(Map<String, dynamic> row) {
    final rawAssignments = row['asignaciones_turno'];
    final assignments = rawAssignments is List
        ? rawAssignments.whereType<Map>().map((item) {
            final assignment = Map<String, dynamic>.from(item);
            final rawPersonal = assignment['personal'];
            final personal = rawPersonal is Map
                ? Map<String, dynamic>.from(rawPersonal)
                : const <String, dynamic>{};
            final name = personal['user_id'] == null
                ? ''
                : [personal['nombre'], personal['apellido']]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' ');
            return DashboardAssignment(
              attendanceState:
                  assignment['estado_asistencia']?.toString() ?? 'pendiente',
              personalName: name.isEmpty ? null : name,
            );
          }).toList()
        : <DashboardAssignment>[];
    return DashboardShift(
      id: row['id'].toString(),
      date: DateTime.parse(row['fecha'].toString()),
      type: row['tipo']?.toString() ?? '',
      start: row['hora_inicio']?.toString() ?? '',
      end: row['hora_fin']?.toString() ?? '',
      area: row['area']?.toString() ?? '',
      state: row['estado']?.toString() ?? '',
      assignees: assignments,
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.todayShifts,
    required this.activePersonnel,
    required this.programmedShifts,
    required this.unassignedShifts,
    required this.pendingAttendance,
    required this.shiftsByType,
    required this.personnelByType,
    required this.dailyShiftCounts,
    required this.upcomingShifts,
    required this.periodStart,
    required this.today,
    required this.updatedAt,
  });

  final int todayShifts, activePersonnel, programmedShifts;
  final int unassignedShifts, pendingAttendance;
  final Map<String, int> shiftsByType, personnelByType;
  final Map<DateTime, int> dailyShiftCounts;
  final List<DashboardShift> upcomingShifts;
  final DateTime periodStart, today, updatedAt;
}

class AdminDashboardRepository {
  AdminDashboardRepository(this.client);
  final SupabaseClient client;

  static const _turnSelect = 'id,fecha,tipo,hora_inicio,hora_fin,area,estado,'
      'asignaciones_turno(id,estado_asistencia,personal(nombre,apellido,user_id))';
  static const _pageSize = 500;

  Future<AdminDashboardData> load(
    AdminDashboardPeriod period, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final start = today.subtract(Duration(days: period.days - 1));
    final todayKey = _dateKey(today);
    final startKey = _dateKey(start);

    final results = await Future.wait([
      _loadTurnRows(startKey, todayKey),
      _loadActivePersonnelTypes(),
      _loadUpcoming(todayKey, _timeKey(current)),
    ]);
    final shifts = (results[0] as List<Map<String, dynamic>>)
        .map(DashboardShift.fromMap)
        .toList();
    final personnelTypes = results[1] as Map<String, int>;
    final upcomingRows = results[2] as List<Map<String, dynamic>>;
    final shiftsByType = <String, int>{
      'manana': 0,
      'tarde': 0,
      'noche': 0,
      'personalizado': 0,
    };
    final dailyCounts = <DateTime, int>{};
    for (var offset = 0; offset < period.days; offset++) {
      dailyCounts[start.add(Duration(days: offset))] = 0;
    }

    var todayCount = 0;
    var programmed = 0;
    var unassigned = 0;
    var pendingAttendance = 0;
    for (final shift in shifts) {
      shiftsByType.update(shift.type, (value) => value + 1, ifAbsent: () => 0);
      final day = DateTime(shift.date.year, shift.date.month, shift.date.day);
      dailyCounts.update(day, (value) => value + 1, ifAbsent: () => 1);
      if (_dateKey(day) == todayKey) todayCount++;
      if (shift.state == 'programado') programmed++;
      if (shift.state != 'cancelado' && shift.assignees.isEmpty) unassigned++;
      pendingAttendance += shift.assignees
          .where((assignment) => assignment.attendanceState == 'pendiente')
          .length;
    }

    return AdminDashboardData(
      todayShifts: todayCount,
      activePersonnel: personnelTypes.values.fold(0, (a, b) => a + b),
      programmedShifts: programmed,
      unassignedShifts: unassigned,
      pendingAttendance: pendingAttendance,
      shiftsByType: shiftsByType,
      personnelByType: personnelTypes,
      dailyShiftCounts: dailyCounts,
      upcomingShifts: upcomingRows.map(DashboardShift.fromMap).toList(),
      periodStart: start,
      today: today,
      updatedAt: current,
    );
  }

  Future<List<Map<String, dynamic>>> _loadTurnRows(
      String start, String end) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await client
          .from('turnos')
          .select(_turnSelect)
          .gte('fecha', start)
          .lte('fecha', end)
          .order('fecha')
          .order('hora_inicio')
          .range(offset, offset + _pageSize - 1);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < _pageSize) return rows;
      offset += _pageSize;
    }
  }

  Future<Map<String, int>> _loadActivePersonnelTypes() async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await client
          .from('personal')
          .select('tipo_personal,user_id')
          .eq('estado', 'activo')
          .not('user_id', 'is', null)
          .range(offset, offset + _pageSize - 1);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    final counts = <String, int>{
      'medico': 0,
      'enfermero': 0,
      'pasante': 0,
    };
    for (final row in rows) {
      final type = row['tipo_personal']?.toString();
      if (type != null && counts.containsKey(type)) {
        counts[type] = counts[type]! + 1;
      }
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> _loadUpcoming(
      String today, String time) async {
    final rows = await client
        .from('turnos')
        .select(_turnSelect)
        .neq('estado', 'cancelado')
        .or('fecha.gt.$today,and(fecha.eq.$today,hora_inicio.gte.$time)')
        .order('fecha')
        .order('hora_inicio')
        .limit(10);
    return List<Map<String, dynamic>>.from(rows);
  }

  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _timeKey(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}
