import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/gestion_controller.dart';
import '../models/gestion_models.dart';
import '../repositories/personal_panel_repository.dart';
import '../widgets/app_section_card.dart';
import '../widgets/responsive_content.dart';
import '../widgets/status_chip.dart';

class PersonalHomeScreen extends StatefulWidget {
  const PersonalHomeScreen({super.key, this.repository});
  final PersonalPanelRepository? repository;

  @override
  State<PersonalHomeScreen> createState() => _PersonalHomeScreenState();
}

class _PersonalHomeScreenState extends State<PersonalHomeScreen> {
  late final PersonalPanelRepository _repository;
  late Future<PersonalDashboardData> _dashboard;
  final _scrollController = ScrollController();
  final _turnsKey = GlobalKey();
  final _profileKey = GlobalKey();
  late DateTime _selectedDay;
  int _weekOffset = 0;
  bool _showAllAssignments = false;
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        PersonalPanelRepository(
          context.read<GestionController>().repository.client,
        );
    _selectedDay = _day(DateTime.now());
    _dashboard = _loadDashboard();
  }

  Future<PersonalDashboardData> _loadDashboard() {
    final future = _repository.miDashboard();
    future.ignore();
    return future;
  }

  Future<void> _refresh() async {
    final future = _repository.miDashboard();
    setState(() {
      _dashboard = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder presents the section error state.
    }
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  Future<void> _signOut() async {
    setState(() => _saliendo = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo cerrar sesión. Intenta nuevamente.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saliendo = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Mi espacio'),
          actions: [
            IconButton(
              tooltip: 'Actualizar resumen',
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: _saliendo ? 'Cerrando sesión' : 'Cerrar sesión',
              onPressed: _saliendo ? null : _signOut,
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ResponsiveContent(
            maxWidth: 1120,
            child: FutureBuilder<PersonalDashboardData>(
              future: _dashboard,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _scrollable([
                    const SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ]);
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _errorState(snapshot.error);
                }
                final data = snapshot.data!;
                final now = DateTime.now();
                final summary = _PersonalSummary(data.assignments, now);
                return _dashboardBody(data, summary, now);
              },
            ),
          ),
        ),
      );

  Widget _scrollable(List<Widget> children) => ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: children,
      );

  Widget _errorState(Object? error) {
    final message = error is StateError &&
            error.message.toString().contains('Sesión no válida')
        ? 'Tu sesión no está disponible. Inicia sesión nuevamente.'
        : error is StateError &&
                error.message.toString().contains('Perfil no disponible')
            ? 'No encontramos un registro activo de Personal vinculado a tu cuenta.'
            : 'No se pudo cargar tu espacio personal. Revisa la conexión e inténtalo nuevamente.';
    return _scrollable([
      const SizedBox(height: 70),
      AppSectionCard(
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() {
                _dashboard = _loadDashboard();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _dashboardBody(
    PersonalDashboardData data,
    _PersonalSummary summary,
    DateTime now,
  ) {
    final personal = data.personal;
    final name = personal.nombre.trim().isEmpty
        ? 'Bienvenido'
        : '¡Hola, ${personal.nombre.trim()}!';
    return _scrollable([
      _welcome(name, personal, now),
      const SizedBox(height: 18),
      _highlightedShift(summary.featured),
      const SizedBox(height: 16),
      _metrics(summary),
      const SizedBox(height: 16),
      _weekSection(data.assignments, now),
      const SizedBox(height: 16),
      _upcomingSection(summary, data.assignments),
      const SizedBox(height: 16),
      _activitySection(summary),
      const SizedBox(height: 16),
      _profileSection(personal),
      const SizedBox(height: 14),
      _quickAccess(),
    ]);
  }

  Widget _welcome(String greeting, Personal personal, DateTime now) {
    final theme = Theme.of(context);
    return AppSectionCard(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 5),
            Text('Este es el resumen de tu actividad.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _InfoPill(
                icon: Icons.medical_services_outlined,
                text: _category(personal.tipoPersonal),
              ),
              if (personal.especialidadNombre?.trim().isNotEmpty == true)
                _InfoPill(
                  icon: Icons.local_hospital_outlined,
                  text: personal.especialidadNombre!.trim(),
                ),
            ]),
          ],
        );
        final date = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined,
              size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(_fullDate(now), style: theme.textTheme.bodyMedium),
        ]);
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 14), date],
          );
        }
        return Row(children: [
          Expanded(child: identity),
          const SizedBox(width: 16),
          Flexible(child: Align(alignment: Alignment.centerRight, child: date)),
        ]);
      }),
    );
  }

  Widget _highlightedShift(AsignacionTurno? assignment) {
    final theme = Theme.of(context);
    if (assignment == null) {
      return AppSectionCard(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          Icon(Icons.event_available_outlined,
              size: 34, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mi próximo turno'),
                SizedBox(height: 4),
                Text('No tienes turnos próximos asignados.'),
              ],
            ),
          ),
        ]),
      );
    }

    final turno = assignment.turno!;
    final current = _isOngoing(assignment, DateTime.now());
    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(current ? Icons.play_circle_outline : Icons.upcoming_outlined,
                color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 9),
            Expanded(
              child: Text(current ? 'Mi turno en curso' : 'Mi próximo turno',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            ),
            StatusChip(
              status: turno.estado,
              label: _turnStatus(turno.estado),
            ),
          ]),
          const SizedBox(height: 17),
          Wrap(spacing: 24, runSpacing: 12, children: [
            _FeatureValue(
              icon: Icons.calendar_month_outlined,
              label: _longDate(turno.fecha),
            ),
            _FeatureValue(
              icon: Icons.schedule_outlined,
              label: '${_clock(turno.horaInicio)} – ${_clock(turno.horaFin)}',
            ),
            _FeatureValue(
              icon: Icons.wb_twilight_outlined,
              label: _shiftType(turno.tipo),
            ),
            if (turno.area.trim().isNotEmpty)
              _FeatureValue(
                icon: Icons.local_hospital_outlined,
                label: turno.area,
              ),
          ]),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _scrollTo(_turnsKey),
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Ver mis turnos'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _metrics(_PersonalSummary summary) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 850
              ? 4
              : constraints.maxWidth >= 540
                  ? 2
                  : 1;
          const gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          final items = <_MetricData>[
            _MetricData(
                'Turnos esta semana',
                '${summary.weekAssignments.length}',
                Icons.calendar_view_week_outlined,
                'Asignaciones no canceladas'),
            _MetricData('Próximos turnos', '${summary.upcoming.length}',
                Icons.event_note_outlined, 'Por iniciar o en curso'),
            _MetricData('Completados este mes', '${summary.completedThisMonth}',
                Icons.task_alt_outlined, 'Finalizados con asistencia cumplida'),
            if (summary.weekHours != null)
              _MetricData('Horas esta semana', _hours(summary.weekHours!),
                  Icons.timelapse_outlined, 'Según horarios asignados'),
          ];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items
                .map((item) => SizedBox(
                      width: width,
                      child: _MetricCard(item: item),
                    ))
                .toList(),
          );
        },
      );

  Widget _weekSection(List<AsignacionTurno> assignments, DateTime now) {
    final base = _day(now).add(Duration(days: _weekOffset));
    final monday = base.subtract(Duration(days: base.weekday - 1));
    final days = List.generate(7, (index) => monday.add(Duration(days: index)));
    final valid = assignments.where((a) => !_cancelled(a)).toList();
    final selected = valid
        .where((a) => _sameDay(a.turno!.fecha, _selectedDay))
        .toList()
      ..sort(_compareAssignments);

    return AppSectionCard(
      key: const ValueKey('personal-week-section'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mi semana', style: Theme.of(context).textTheme.titleLarge),
              Text(
                  '${_shortDate(monday)} – ${_shortDate(monday.add(const Duration(days: 6)))}'),
            ]),
          ),
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: () => _moveWeek(-1, now),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: () => _moveWeek(1, now),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700
              ? 7
              : constraints.maxWidth >= 430
                  ? 4
                  : 2;
          const gap = 7.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: days.map((day) {
              final count =
                  valid.where((a) => _sameDay(a.turno!.fecha, day)).length;
              final isSelected = _sameDay(day, _selectedDay);
              final colors = Theme.of(context).colorScheme;
              return SizedBox(
                width: width,
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label:
                      '${_weekday(day)}, ${day.day} ${_month(day.month)}${count > 0 ? ', $count turnos' : ', sin turnos'}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedDay = _day(day)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      constraints: const BoxConstraints(minHeight: 78),
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_weekdayShort(day),
                            style: Theme.of(context).textTheme.labelMedium),
                        Text('${day.day}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                count == 0
                                    ? Icons.remove
                                    : Icons.event_available_outlined,
                                size: 14,
                                color: count == 0
                                    ? colors.onSurfaceVariant
                                    : colors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text('$count',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            ]),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
        const SizedBox(height: 18),
        Text(
            '${_weekday(_selectedDay)} ${_selectedDay.day} de ${_month(_selectedDay.month)}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (selected.isEmpty)
          const Text('No tienes turnos asignados para este día.')
        else
          ...selected.map((a) => _dayShift(a)),
      ]),
    );
  }

  void _moveWeek(int direction, DateTime now) {
    setState(() {
      _weekOffset += direction * 7;
      final base = _day(now).add(Duration(days: _weekOffset));
      final monday = base.subtract(Duration(days: base.weekday - 1));
      _selectedDay = monday.add(Duration(days: _selectedDay.weekday - 1));
    });
  }

  Widget _dayShift(AsignacionTurno assignment) {
    final turno = assignment.turno!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.schedule_outlined),
      title: Text(
          '${_clock(turno.horaInicio)} – ${_clock(turno.horaFin)} · ${_shiftType(turno.tipo)}'),
      subtitle:
          Text(turno.area.trim().isEmpty ? 'Área no especificada' : turno.area),
      trailing:
          StatusChip(status: turno.estado, label: _turnStatus(turno.estado)),
    );
  }

  Widget _upcomingSection(
          _PersonalSummary summary, List<AsignacionTurno> assignments) =>
      AppSectionCard(
        key: _turnsKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('Próximos turnos',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            TextButton.icon(
              onPressed: assignments.isEmpty
                  ? null
                  : () => setState(
                      () => _showAllAssignments = !_showAllAssignments),
              icon: Icon(_showAllAssignments
                  ? Icons.expand_less
                  : Icons.list_alt_outlined),
              label: Text(_showAllAssignments
                  ? 'Ocultar todos'
                  : 'Ver todos mis turnos'),
            ),
          ]),
          const SizedBox(height: 5),
          if (summary.upcomingAfterFeatured.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay otros turnos próximos asignados.'),
            )
          else
            ...summary.upcomingAfterFeatured.map(_upcomingTile),
          if (_showAllAssignments && assignments.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Todos tus turnos',
                style: Theme.of(context).textTheme.titleMedium),
            ...(assignments.toList()..sort(_compareAssignments))
                .map(_allAssignmentTile),
          ],
        ]),
      );

  Widget _allAssignmentTile(AsignacionTurno assignment) {
    final turno = assignment.turno!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.event_note_outlined),
      title: Text('${_longDate(turno.fecha)} · ${_shiftType(turno.tipo)}'),
      subtitle: Text(
        '${_clock(turno.horaInicio)} – ${_clock(turno.horaFin)}'
        '${turno.area.trim().isEmpty ? '' : ' · ${turno.area}'}'
        '\nAsistencia: ${_attendance(assignment.estadoAsistencia)}',
      ),
      isThreeLine: true,
      trailing:
          StatusChip(status: turno.estado, label: _turnStatus(turno.estado)),
    );
  }

  Widget _upcomingTile(AsignacionTurno assignment) {
    final turno = assignment.turno!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text('${turno.fecha.day}',
            style: Theme.of(context).textTheme.labelLarge),
      ),
      title: Text('${_longDate(turno.fecha)} · ${_shiftType(turno.tipo)}'),
      subtitle: Text(
          '${_clock(turno.horaInicio)} – ${_clock(turno.horaFin)}${turno.area.trim().isEmpty ? '' : ' · ${turno.area}'}'),
      trailing:
          StatusChip(status: turno.estado, label: _turnStatus(turno.estado)),
    );
  }

  Widget _activitySection(_PersonalSummary summary) => AppSectionCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mi actividad', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
              'Historial reciente de turnos finalizados y asistencia registrada.'),
          const SizedBox(height: 8),
          if (summary.recentFinalized.isEmpty)
            const Text('Aún no hay turnos finalizados en tu historial.')
          else
            ...summary.recentFinalized.take(4).map((assignment) {
              final turno = assignment.turno!;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.history),
                title: Text(
                    '${_longDate(turno.fecha)} · ${_shiftType(turno.tipo)}'),
                subtitle: Text(
                    '${_clock(turno.horaInicio)} – ${_clock(turno.horaFin)}'),
                trailing: StatusChip(
                  status: assignment.estadoAsistencia,
                  label:
                      'Asistencia: ${_attendance(assignment.estadoAsistencia)}',
                ),
              );
            }),
        ]),
      );

  Widget _profileSection(Personal personal) => AppSectionCard(
        key: _profileKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mi perfil', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _detail('Nombre completo', personal.nombreCompleto.trim()),
          _detail('Categoría', _category(personal.tipoPersonal)),
          if (personal.especialidadNombre?.trim().isNotEmpty == true)
            _detail('Especialidad', personal.especialidadNombre!.trim()),
          _detail('Código', personal.codigo),
          if (personal.telefono?.trim().isNotEmpty == true)
            _detail('Teléfono', personal.telefono!.trim()),
        ]),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 132,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ),
          Expanded(child: Text(value.isEmpty ? 'Sin información' : value)),
        ]),
      );

  Widget _quickAccess() => AppSectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Accesos rápidos',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _scrollTo(_turnsKey),
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('Mis turnos'),
            ),
            OutlinedButton.icon(
              onPressed: () => _scrollTo(_profileKey),
              icon: const Icon(Icons.person_outline),
              label: const Text('Mi perfil'),
            ),
          ]),
        ]),
      );

  String _category(String value) => switch (value) {
        'medico' => 'Médico',
        'enfermero' => 'Enfermero',
        'pasante' => 'Pasante',
        _ => value.isEmpty ? 'Categoría no disponible' : value,
      };

  String _turnStatus(String value) => switch (value) {
        'programado' => 'Programado',
        'en_curso' => 'En curso',
        'finalizado' => 'Finalizado',
        'cancelado' => 'Cancelado',
        _ => value,
      };

  String _attendance(String value) => switch (value) {
        'pendiente' => 'Pendiente',
        'cumplido' => 'Cumplido',
        'falta' => 'Falta',
        _ => value,
      };

  String _shiftType(String value) => switch (value) {
        'manana' => 'Mañana',
        'tarde' => 'Tarde',
        'noche' => 'Noche',
        'personalizado' => 'Personalizado',
        _ => value,
      };

  String _clock(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;

  String _fullDate(DateTime date) =>
      '${_weekday(date)} ${date.day} de ${_month(date.month)} de ${date.year}';

  String _longDate(DateTime date) =>
      '${_weekday(date)} ${date.day} de ${_month(date.month)} de ${date.year}';

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  String _weekday(DateTime date) => const [
        'lunes',
        'martes',
        'miércoles',
        'jueves',
        'viernes',
        'sábado',
        'domingo'
      ][date.weekday - 1];

  String _weekdayShort(DateTime date) =>
      const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][date.weekday - 1];

  String _month(int month) => const [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre'
      ][month - 1];

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _cancelled(AsignacionTurno assignment) =>
      assignment.turno!.estado == 'cancelado';

  bool _isOngoing(AsignacionTurno assignment, DateTime now) {
    if (_cancelled(assignment) || assignment.turno!.estado == 'finalizado') {
      return false;
    }
    if (assignment.turno!.estado == 'en_curso') return true;
    final bounds = _bounds(assignment.turno!);
    return bounds != null &&
        !now.isBefore(bounds.start) &&
        now.isBefore(bounds.end);
  }

  ({DateTime start, DateTime end})? _bounds(Turno turno) {
    final startTime = _parseTime(turno.horaInicio);
    final endTime = _parseTime(turno.horaFin);
    if (startTime == null || endTime == null) return null;
    final start = DateTime(turno.fecha.year, turno.fecha.month, turno.fecha.day,
        startTime.$1, startTime.$2, startTime.$3);
    var end = DateTime(turno.fecha.year, turno.fecha.month, turno.fecha.day,
        endTime.$1, endTime.$2, endTime.$3);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  (int, int, int)? _parseTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final second = int.tryParse(match.group(3) ?? '0');
    if (hour == null ||
        minute == null ||
        second == null ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    return (hour, minute, second);
  }

  int _compareAssignments(AsignacionTurno a, AsignacionTurno b) {
    final boundsA = _bounds(a.turno!);
    final boundsB = _bounds(b.turno!);
    if (boundsA == null || boundsB == null) {
      return a.turno!.fecha.compareTo(b.turno!.fecha);
    }
    return boundsA.start.compareTo(boundsB.start);
  }

  String _hours(double value) =>
      '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} h';
}

class _PersonalSummary {
  _PersonalSummary(this.assignments, this.now) {
    final monday = _day(now).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    weekAssignments = assignments
        .where((a) =>
            !_cancelled(a) &&
            !_day(a.turno!.fecha).isBefore(monday) &&
            _day(a.turno!.fecha).isBefore(nextMonday))
        .toList()
      ..sort(_compare);
    upcoming = assignments.where(_isUpcoming).toList()..sort(_compare);
    final active = upcoming.where((a) => _ongoing(a, now)).toList();
    featured = active.isNotEmpty ? active.first : upcoming.firstOrNull;
    upcomingAfterFeatured = upcoming
        .where((a) => !identical(a, featured) && !_ongoing(a, now))
        .toList();
    completedThisMonth = assignments.where((a) {
      final turno = a.turno!;
      return turno.estado == 'finalizado' &&
          a.estadoAsistencia == 'cumplido' &&
          turno.fecha.year == now.year &&
          turno.fecha.month == now.month;
    }).length;
    recentFinalized = assignments
        .where((a) => a.turno!.estado == 'finalizado')
        .toList()
      ..sort((a, b) => _compare(b, a));
    weekHours = _calculateWeekHours(weekAssignments);
  }

  final List<AsignacionTurno> assignments;
  final DateTime now;
  late final List<AsignacionTurno> weekAssignments;
  late final List<AsignacionTurno> upcoming;
  late final List<AsignacionTurno> upcomingAfterFeatured;
  late final List<AsignacionTurno> recentFinalized;
  late final AsignacionTurno? featured;
  late final int completedThisMonth;
  late final double? weekHours;

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _cancelled(AsignacionTurno a) => a.turno!.estado == 'cancelado';

  bool _ongoing(AsignacionTurno a, DateTime instant) {
    if (_cancelled(a) || a.turno!.estado == 'finalizado') return false;
    if (a.turno!.estado == 'en_curso') return true;
    final bounds = _bounds(a.turno!);
    return bounds != null &&
        !instant.isBefore(bounds.start) &&
        instant.isBefore(bounds.end);
  }

  bool _isUpcoming(AsignacionTurno a) {
    if (_cancelled(a) || a.turno!.estado == 'finalizado') return false;
    if (_ongoing(a, now)) return true;
    final bounds = _bounds(a.turno!);
    return bounds != null && bounds.start.isAfter(now);
  }

  int _compare(AsignacionTurno a, AsignacionTurno b) {
    final ba = _bounds(a.turno!);
    final bb = _bounds(b.turno!);
    if (ba == null || bb == null) {
      return a.turno!.fecha.compareTo(b.turno!.fecha);
    }
    return ba.start.compareTo(bb.start);
  }

  double? _calculateWeekHours(List<AsignacionTurno> rows) {
    var totalSeconds = 0;
    for (final row in rows) {
      final bounds = _bounds(row.turno!);
      if (bounds == null) return null;
      totalSeconds += bounds.end.difference(bounds.start).inSeconds;
    }
    return totalSeconds / 3600;
  }

  ({DateTime start, DateTime end})? _bounds(Turno turno) {
    final startTime = _parseTime(turno.horaInicio);
    final endTime = _parseTime(turno.horaFin);
    if (startTime == null || endTime == null) return null;
    final start = DateTime(turno.fecha.year, turno.fecha.month, turno.fecha.day,
        startTime.$1, startTime.$2, startTime.$3);
    var end = DateTime(turno.fecha.year, turno.fecha.month, turno.fecha.day,
        endTime.$1, endTime.$2, endTime.$3);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  (int, int, int)? _parseTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final second = int.tryParse(match.group(3) ?? '0');
    if (hour == null ||
        minute == null ||
        second == null ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    return (hour, minute, second);
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.caption);
  final String label, value, caption;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});
  final _MetricData item;

  @override
  Widget build(BuildContext context) => AppSectionCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(item.icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label, style: Theme.of(context).textTheme.bodyMedium),
              Text(item.value, style: Theme.of(context).textTheme.titleLarge),
              Text(item.caption, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      );
}

class _FeatureValue extends StatelessWidget {
  const _FeatureValue({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ]);
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 17),
        label: Text(text),
        visualDensity: VisualDensity.compact,
      );
}
