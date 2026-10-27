import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/gestion_controller.dart';
import '../repositories/admin_dashboard_repository.dart';
import '../widgets/responsive_content.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.onOpen, this.repository});
  final ValueChanged<int> onOpen;
  final AdminDashboardRepository? repository;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminDashboardRepository? _repository;
  AdminDashboardData? _data;
  AdminDashboardPeriod _period = AdminDashboardPeriod.last7Days;
  bool _loading = true;
  String? _error;
  int _request = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    try {
      _repository = widget.repository ??
          AdminDashboardRepository(
            context.read<GestionController>().repository.client,
          );
      _load();
    } catch (_) {
      _loading = false;
      _error = 'No hay una conexión administrativa disponible.';
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await repository.load(_period);
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _error =
            'No se pudo cargar el resumen. Verifica la conexión y los permisos, e inténtalo nuevamente.';
        _loading = false;
      });
    }
  }

  void _setPeriod(AdminDashboardPeriod? value) {
    if (value == null || value == _period) return;
    setState(() => _period = value);
    _load();
  }

  @override
  Widget build(BuildContext context) => ResponsiveContent(
        maxWidth: 1320,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            _header(context),
            const SizedBox(height: 20),
            if (_loading)
              const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _loadError(context)
            else if (_data != null) ...[
              _metrics(context, _data!),
              const SizedBox(height: 12),
              _charts(context, _data!),
              const SizedBox(height: 14),
              _alerts(context, _data!),
              const SizedBox(height: 14),
              _upcoming(context, _data!),
            ],
            const SizedBox(height: 20),
            _quickAccess(context),
          ],
        ),
      );

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 570),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard administrativo',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Resumen de personal y programación de turnos',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(_formatDate(now), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<AdminDashboardPeriod>(
                value: _period,
                onChanged: _loading ? null : _setPeriod,
                items: AdminDashboardPeriod.values
                    .map((period) => DropdownMenuItem(
                          value: period,
                          child: Text(period.label),
                        ))
                    .toList(),
              ),
              IconButton.filledTonal(
                tooltip: 'Actualizar datos',
                onPressed: _loading || _repository == null ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ]),
      ],
    );
  }

  Widget _loadError(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.cloud_off_outlined,
                size: 36, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
      );

  Widget _metrics(BuildContext context, AdminDashboardData data) {
    final items = [
      _Metric('Turnos de hoy', data.todayShifts, Icons.today_outlined,
          'Fecha local actual'),
      _Metric('Personal activo', data.activePersonnel, Icons.groups_outlined,
          'Cuentas vinculadas · estado activo'),
      _Metric('Turnos programados', data.programmedShifts,
          Icons.event_available_outlined, _period.label),
      _Metric('Turnos sin asignación', data.unassignedShifts,
          Icons.person_off_outlined, '${_period.label} · excluye cancelados'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 950
          ? 4
          : constraints.maxWidth >= 560
              ? 2
              : 1;
      final gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items
            .map((item) => SizedBox(
                  width: width,
                  child: _MetricCard(metric: item),
                ))
            .toList(),
      );
    });
  }

  Widget _charts(BuildContext context, AdminDashboardData data) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final chartWidth =
              wide ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
          return Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: chartWidth, child: _shiftTypeChart(context, data)),
            SizedBox(width: chartWidth, child: _personnelChart(context, data)),
            SizedBox(
              width: constraints.maxWidth,
              child: _dailyChart(context, data),
            ),
          ]);
        },
      );

  Widget _shiftTypeChart(BuildContext context, AdminDashboardData data) {
    const labels = {
      'manana': 'Mañana',
      'tarde': 'Tarde',
      'noche': 'Noche',
      'personalizado': 'Personalizado',
    };
    final entries = data.shiftsByType.entries.toList();
    return _Panel(
      title: 'Turnos por tipo',
      subtitle: _period.label,
      child: data.shiftsByType.values.every((value) => value == 0)
          ? const _EmptyChart(text: 'No hay turnos en este periodo.')
          : Column(children: [
              SizedBox(
                height: 190,
                child: CustomPaint(
                  painter: _BarPainter(
                    values: entries.map((entry) => entry.value).toList(),
                    labels: entries
                        .map((entry) => labels[entry.key] ?? entry.key)
                        .toList(),
                    color: Theme.of(context).colorScheme.primary,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    gridColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ]),
    );
  }

  Widget _personnelChart(BuildContext context, AdminDashboardData data) {
    const labels = {
      'medico': 'Médicos',
      'enfermero': 'Enfermeros',
      'pasante': 'Pasantes',
    };
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
    ];
    final entries = data.personnelByType.entries.toList();
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    return _Panel(
      title: 'Personal activo por categoría',
      subtitle: 'Cuentas Auth vinculadas · estado activo',
      child: total == 0
          ? const _EmptyChart(text: 'No hay personal activo registrado.')
          : Row(children: [
              SizedBox(
                width: 150,
                height: 170,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: entries.map((entry) => entry.value).toList(),
                    colors: colors,
                    centerText: '$total',
                    textColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: colors[index], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(labels[entry.key] ?? entry.key)),
                        Text('${entry.value}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ]),
                    );
                  }),
                ),
              ),
            ]),
    );
  }

  Widget _dailyChart(BuildContext context, AdminDashboardData data) {
    final entries = data.dailyShiftCounts.entries.toList();
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    return _Panel(
      title: 'Evolución de turnos',
      subtitle:
          '${_formatDate(data.periodStart)} — ${_formatDate(data.today)} · $total turnos',
      child: total == 0
          ? const _EmptyChart(
              text: 'No hay turnos registrados en este periodo.')
          : SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _LinePainter(
                  values: entries.map((entry) => entry.value).toList(),
                  dates: entries.map((entry) => entry.key).toList(),
                  color: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
    );
  }

  Widget _alerts(BuildContext context, AdminDashboardData data) => _Panel(
        title: 'Alertas administrativas',
        subtitle: 'Datos del periodo seleccionado',
        child: Wrap(spacing: 12, runSpacing: 8, children: [
          _AlertPill(
            icon: Icons.person_off_outlined,
            label: '${data.unassignedShifts} turnos sin asignación',
            warning: data.unassignedShifts > 0,
          ),
          _AlertPill(
            icon: Icons.pending_actions_outlined,
            label: '${data.pendingAttendance} asistencias pendientes',
            warning: data.pendingAttendance > 0,
          ),
        ]),
      );

  Widget _upcoming(BuildContext context, AdminDashboardData data) => _Panel(
        title: 'Próximos turnos',
        subtitle:
            'Siguientes ${data.upcomingShifts.length} · no incluye cancelados',
        child: data.upcomingShifts.isEmpty
            ? const _EmptyChart(text: 'No hay próximos turnos registrados.')
            : LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: data.upcomingShifts
                        .map((shift) => _UpcomingMobileRow(shift: shift))
                        .toList(),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Tipo')),
                      DataColumn(label: Text('Horario')),
                      DataColumn(label: Text('Área')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Personal asignado')),
                    ],
                    rows: data.upcomingShifts
                        .map((shift) => DataRow(cells: [
                              DataCell(Text(_formatDate(shift.date))),
                              DataCell(Text(_typeLabel(shift.type))),
                              DataCell(Text(
                                  '${_shortTime(shift.start)}–${_shortTime(shift.end)}')),
                              DataCell(Text(shift.area)),
                              DataCell(Text(_stateLabel(shift.state))),
                              DataCell(Text(_assigneeSummary(shift))),
                            ]))
                        .toList(),
                  ),
                );
              }),
      );

  Widget _quickAccess(BuildContext context) => _Panel(
        title: 'Accesos rápidos',
        subtitle: 'Administración de módulos',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          _QuickLink(
              label: 'Personal',
              icon: Icons.people_outline,
              onTap: () => widget.onOpen(1)),
          _QuickLink(
              label: 'Especialidades',
              icon: Icons.medical_services_outlined,
              onTap: () => widget.onOpen(2)),
          _QuickLink(
              label: 'Turnos',
              icon: Icons.schedule_outlined,
              onTap: () => widget.onOpen(3)),
          _QuickLink(
              label: 'Asignaciones',
              icon: Icons.assignment_ind_outlined,
              onTap: () => widget.onOpen(4)),
          _QuickLink(
              label: 'Asistencia',
              icon: Icons.fact_check_outlined,
              onTap: () => widget.onOpen(5)),
        ]),
      );
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.caption);
  final String label, caption;
  final int value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text('${metric.value}',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(metric.caption,
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        child: Center(child: Text(text, textAlign: TextAlign.center)),
      );
}

class _AlertPill extends StatelessWidget {
  const _AlertPill(
      {required this.icon, required this.label, required this.warning});
  final IconData icon;
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.errorContainer : scheme.secondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 18,
            color: warning
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}

class _UpcomingMobileRow extends StatelessWidget {
  const _UpcomingMobileRow({required this.shift});
  final DashboardShift shift;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    '${_formatDate(shift.date)} · ${_typeLabel(shift.type)}',
                    style: Theme.of(context).textTheme.titleSmall)),
            Text(_stateLabel(shift.state)),
          ]),
          const SizedBox(height: 3),
          Text(
              '${_shortTime(shift.start)}–${_shortTime(shift.end)} · ${shift.area}'),
          Text('Personal: ${_assigneeSummary(shift)}',
              style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 16),
        ]),
      );
}

class _QuickLink extends StatelessWidget {
  const _QuickLink(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      );
}

class _BarPainter extends CustomPainter {
  _BarPainter(
      {required this.values,
      required this.labels,
      required this.color,
      required this.textColor,
      required this.gridColor});
  final List<int> values;
  final List<String> labels;
  final Color color, textColor, gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, right = 8.0, top = 18.0, bottom = 38.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final maxValue = math.max(1, values.fold<int>(0, (a, b) => a > b ? a : b));
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chart.bottom - chart.height * i / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    final slot = chart.width / values.length;
    final barPaint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final height = chart.height * values[i] / maxValue;
      final x = chart.left + slot * i + slot * .22;
      final rect = Rect.fromLTWH(x, chart.bottom - height, slot * .56, height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)), barPaint);
      _drawText(canvas, '${values[i]}',
          Offset(x + slot * .28, chart.bottom - height - 18), textColor, 12);
      _drawCentered(canvas, _shortType(labels[i]),
          Offset(x + slot * .28, chart.bottom + 8), textColor, 10, slot);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.values != values || old.color != color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(
      {required this.values,
      required this.colors,
      required this.centerText,
      required this.textColor});
  final List<int> values;
  final List<Color> colors;
  final String centerText;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    final rect = Rect.fromCenter(
        center: size.center(Offset.zero), width: 138, height: 138);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = 2 * math.pi * values[i] / total;
      paint.color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
    _drawCentered(
        canvas, centerText, size.center(Offset.zero), textColor, 22, 80);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}

class _LinePainter extends CustomPainter {
  _LinePainter(
      {required this.values,
      required this.dates,
      required this.color,
      required this.textColor,
      required this.gridColor});
  final List<int> values;
  final List<DateTime> dates;
  final Color color, textColor, gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 12.0, top = 18.0, bottom = 32.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final maxValue = math.max(1, values.fold<int>(0, (a, b) => a > b ? a : b));
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _drawText(canvas, '${(maxValue * i / 3).round()}', Offset(2, y - 7),
          textColor, 10);
    }
    final step = values.length <= 1 ? 0.0 : chart.width / (values.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      points.add(Offset(chart.left + step * i,
          chart.bottom - chart.height * values[i] / maxValue));
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (points.length > 1) {
      canvas.drawPath(Path()..addPolygon(points, false), line);
    }
    final dot = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 3, dot);
    }
    if (dates.isNotEmpty) {
      final positions = {0, dates.length ~/ 2, dates.length - 1}.toList()
        ..sort();
      for (final index in positions) {
        final x = chart.left + step * index;
        _drawCentered(canvas, '${dates[index].day}/${dates[index].month}',
            Offset(x, chart.bottom + 12), textColor, 10, 60);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.color != color;
}

void _drawText(
    Canvas canvas, String text, Offset position, Color color, double size) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, position);
}

void _drawCentered(Canvas canvas, String text, Offset center, Color color,
    double size, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
}

String _shortType(String value) =>
    value == 'Personalizado' ? 'Personal.' : value;
String _typeLabel(String type) =>
    const {
      'manana': 'Mañana',
      'tarde': 'Tarde',
      'noche': 'Noche',
      'personalizado': 'Personalizado',
    }[type] ??
    type;
String _stateLabel(String state) =>
    const {
      'programado': 'Programado',
      'en_curso': 'En curso',
      'finalizado': 'Finalizado',
      'cancelado': 'Cancelado',
    }[state] ??
    state;
String _assigneeSummary(DashboardShift shift) {
  final names = shift.assignees
      .map((assignment) => assignment.personalName)
      .whereType<String>()
      .toSet()
      .toList();
  if (names.isEmpty) return 'Sin asignar';
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} +${names.length - 2}';
}

String _shortTime(String time) =>
    time.length >= 5 ? time.substring(0, 5) : time;
String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
