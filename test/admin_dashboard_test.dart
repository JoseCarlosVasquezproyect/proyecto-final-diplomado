import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gestion_hospitalaria/repositories/admin_dashboard_repository.dart';
import 'package:gestion_hospitalaria/screens/admin_dashboard.dart';

class _DashboardRepository extends AdminDashboardRepository {
  _DashboardRepository()
      : super(SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final periods = <AdminDashboardPeriod>[];

  @override
  Future<AdminDashboardData> load(
    AdminDashboardPeriod period, {
    DateTime? now,
  }) async {
    periods.add(period);
    final today = DateTime(2026, 10, 25);
    final upcoming = DashboardShift(
      id: 'shift-1',
      date: today,
      type: 'manana',
      start: '08:00:00',
      end: '16:00:00',
      area: 'Urgencias',
      state: 'programado',
      assignees: const [
        DashboardAssignment(
          attendanceState: 'pendiente',
          personalName: 'Ana Pérez',
        ),
      ],
    );
    return AdminDashboardData(
      todayShifts: 2,
      activePersonnel: 5,
      programmedShifts: 3,
      unassignedShifts: 1,
      pendingAttendance: 2,
      shiftsByType: const {
        'manana': 1,
        'tarde': 1,
        'noche': 1,
        'personalizado': 0,
      },
      personnelByType: const {'medico': 2, 'enfermero': 2, 'pasante': 1},
      dailyShiftCounts: {today: 2},
      upcomingShifts: [upcoming],
      periodStart: today,
      today: today,
      updatedAt: today,
    );
  }
}

void main() {
  test('does not show an assignee name without an Auth link', () {
    final shift = DashboardShift.fromMap({
      'id': 'shift-1',
      'fecha': '2026-10-25',
      'tipo': 'manana',
      'hora_inicio': '08:00:00',
      'hora_fin': '16:00:00',
      'area': 'Urgencias',
      'estado': 'programado',
      'asignaciones_turno': [
        {
          'estado_asistencia': 'pendiente',
          'personal': {'nombre': 'Ana', 'apellido': 'Pérez', 'user_id': null},
        },
      ],
    });

    expect(shift.assignees, hasLength(1));
    expect(shift.assignees.single.personalName, isNull);
    expect(shift.assignees.single.attendanceState, 'pendiente');
  });

  testWidgets(
      'shows real-data dashboard sections and preserves quick navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DashboardRepository();
    addTearDown(repository.client.dispose);
    final opened = <int>[];

    await tester.pumpWidget(MaterialApp(
      home: AdminDashboard(
        repository: repository,
        onOpen: opened.add,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard administrativo'), findsOneWidget);
    expect(find.text('Turnos de hoy'), findsOneWidget);
    expect(find.text('Personal activo'), findsOneWidget);
    expect(find.text('Turnos programados'), findsOneWidget);
    expect(find.text('Turnos sin asignación'), findsOneWidget);
    expect(find.text('Turnos por tipo'), findsOneWidget);
    expect(find.text('Personal activo por categoría'), findsOneWidget);
    expect(find.text('Evolución de turnos'), findsOneWidget);
    expect(repository.periods, [AdminDashboardPeriod.last7Days]);

    await tester.tap(find.byType(DropdownButton<AdminDashboardPeriod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoy').last);
    await tester.pumpAndSettle();
    expect(repository.periods.last, AdminDashboardPeriod.today);

    await tester.ensureVisible(find.text('Próximos turnos'));
    expect(find.text('Próximos turnos'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Turnos'));
    await tester.tap(find.widgetWithText(ActionChip, 'Turnos'));
    expect(opened, [3]);
  });
}
