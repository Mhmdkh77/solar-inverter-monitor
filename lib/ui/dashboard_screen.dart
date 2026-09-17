import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:deye_solarman/deye_solarman.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/data_logger.dart';
import '../providers/data_loggers_provider.dart';
import '../services/background_service.dart';
import '../services/db_helper.dart';
import 'event_logs_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String loggerId;
  const DashboardScreen({super.key, required this.loggerId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  Inverter? _inverter;
  Timer? _pollingTimer;
  Map<String, int>? _data;
  List<Map<String, dynamic>> _chartData = [];
  bool _connecting = true;
  String _error = '';
  bool _autoRefresh = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Track last known grid state to save foreground events too
  bool? _lastGridOn;

  static const _kPollInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initConnection();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _inverter?.closeSocket();
    _pulseCtrl.dispose();
    super.dispose();
  }

  DataLogger get _logger => ref
      .read(dataLoggersProvider)
      .firstWhere((l) => l.id == widget.loggerId,
          orElse: () => const DataLogger(
              id: '', name: 'Unknown', ipAddress: '', serial: 0));

  Future<void> _initConnection() async {
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _error = '';
    });

    try {
      _inverter?.closeSocket();
      final logger = _logger;
      _inverter = await Inverter.init(
          address: logger.ipAddress, loggerSerial: logger.serial, port: logger.port);
      await _fetchData();
      _schedulePolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  void _schedulePolling() {
    _pollingTimer?.cancel();
    if (!_autoRefresh) return;
    _pollingTimer = Timer.periodic(_kPollInterval, (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    if (_inverter == null || !mounted) return;

    try {
      final data = await _inverter!.readHoldingRegisters(register: 184, quantity: 11);
      final chartData = await DatabaseHelper.instance.getChartData24h(widget.loggerId);
      final bool isGridOn = (data['Grid Relay Status'] ?? 0) == 1;
      final int soc = data['Battery SOC'] ?? 0;

      // Save foreground data point too (every poll)
      await DatabaseHelper.instance.insertChartData(widget.loggerId, soc, isGridOn);

      // Log state transitions + fire alarm from foreground too
      if (_lastGridOn != null && _lastGridOn != isGridOn) {
        final bool gridJustWentOff = !isGridOn;
        final String title = gridJustWentOff
            ? '⚠️ GRID POWER LOST — ${_logger.name}'
            : '✅ GRID RESTORED — ${_logger.name}';
        final String msg = gridJustWentOff
            ? 'The grid has gone OFF. Check your inverter!'
            : 'Grid power is back ON. Battery at $soc%.';

        await DatabaseHelper.instance.insertEventLog(
            widget.loggerId, isGridOn ? 'GRID_ON' : 'GRID_OFF', msg);

        // Only fire alarm if the alarm is enabled for this logger
        if (_logger.alarmEnabled) {
          await _fireForegroundAlarm(title: title, body: msg, loggerId: widget.loggerId);
        }
      }
      _lastGridOn = isGridOn;

      // Update home screen live badge
      ref.read(dataLoggersProvider.notifier)
          .updateLiveStatus(widget.loggerId, soc: soc, gridOn: isGridOn);

      if (mounted) {
        setState(() {
          _data = data;
          _chartData = chartData;
          _connecting = false;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
        _pollingTimer?.cancel();
        await _inverter?.closeSocket();
        _inverter = null;
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout')) return 'Connection timed out';
    if (s.contains('connection refused')) return 'Connection refused';
    if (s.contains('network')) return 'Network error';
    return 'Failed to connect to inverter';
  }

  /// Fires the same alarm-style notification from the foreground.
  /// Uses the same channel as the background service so settings are consistent.
  static Future<void> _fireForegroundAlarm({
    required String title,
    required String body,
    required String loggerId,
  }) async {
    final notif = FlutterLocalNotificationsPlugin();
    await notif.show(
      loggerId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          BackgroundService.alarmChannelId,
          'Grid Alerts',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList(
              BackgroundService.alarmVibrationPattern),
          fullScreenIntent: true,
          ongoing: false,
          autoCancel: false,
          enableLights: true,
          ledColor: const Color(0xFFEF4444),
          ledOnMs: 500,
          ledOffMs: 500,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final logger = ref.watch(dataLoggersProvider).firstWhere(
          (l) => l.id == widget.loggerId,
          orElse: () =>
              const DataLogger(id: '', name: 'Unknown', ipAddress: '', serial: 0),
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF080C14),
      appBar: _buildAppBar(logger),
      body: _connecting
          ? _buildConnecting()
          : _error.isNotEmpty
              ? _buildError()
              : _buildContent(logger),
    );
  }

  PreferredSizeWidget _buildAppBar(DataLogger logger) {
    return AppBar(
      title: Text(logger.name),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xCC080C14), Color(0x880D1117)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _autoRefresh ? Icons.pause_circle_outline : Icons.play_circle_outline,
            color: _autoRefresh
                ? const Color(0xFF10B981)
                : const Color(0xFF6B7280),
          ),
          tooltip: _autoRefresh ? 'Pause polling' : 'Resume polling',
          onPressed: () {
            setState(() => _autoRefresh = !_autoRefresh);
            if (_autoRefresh) {
              _schedulePolling();
            } else {
              _pollingTimer?.cancel();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh now',
          onPressed: _inverter == null ? _initConnection : _fetchData,
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Event logs',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventLogsScreen(
                  loggerId: logger.id, loggerName: logger.name),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnecting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981)
                    .withOpacity(0.15 * _pulseAnim.value),
                border: Border.all(
                    color: const Color(0xFF10B981)
                        .withOpacity(_pulseAnim.value),
                    width: 2),
              ),
              child: const Icon(Icons.wifi_rounded,
                  color: Color(0xFF10B981), size: 36),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Connecting to inverter…',
              style: TextStyle(color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(_error,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 17, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: _initConnection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DataLogger logger) {
    final int soc = _data?['Battery SOC'] ?? 0;
    final bool isGridOn = (_data?['Grid Relay Status'] ?? 0) == 1;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // ── Top status row ────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _SocGauge(soc: soc, pulse: _pulseAnim)),
                const SizedBox(width: 14),
                Expanded(child: _GridStatusCard(isOn: isGridOn, pulse: _pulseAnim)),
              ],
            ),
            const SizedBox(height: 14),
            // ── Battery history chart ─────────────────────────────────────
            _buildChart(),
            const SizedBox(height: 14),
            // ── Alarm card ───────────────────────────────────────────────
            _buildAlarmCard(logger),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Battery SOC — Last 24h',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              if (_chartData.isNotEmpty)
                Text('${_chartData.length} pts',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: _chartData.isEmpty
                ? const Center(
                    child: Text('Waiting for data…',
                        style: TextStyle(color: Color(0xFF6B7280))))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: Colors.white10, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 25,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 10)),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= _chartData.length) {
                                return const SizedBox();
                              }
                              final step = max(
                                  1, (_chartData.length / 4).floor());
                              if (idx % step != 0) return const SizedBox();
                              final ts = _chartData[idx]['timestamp'] as int;
                              final dt =
                                  DateTime.fromMillisecondsSinceEpoch(ts);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(DateFormat('HH:mm').format(dt),
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _chartData.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(),
                                (e.value['battery_soc'] as int).toDouble());
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981).withOpacity(0.25),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(DataLogger logger) {
    return _GlassCard(
      accentColor: logger.alarmEnabled
          ? const Color(0xFFF59E0B)
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (logger.alarmEnabled
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF4B5563))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: logger.alarmEnabled
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF4B5563),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Background Alarm',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  logger.alarmEnabled
                      ? 'Notifying on grid state changes'
                      : 'Off — tap to enable alerts',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          Switch(
            value: logger.alarmEnabled,
            onChanged: (val) =>
                ref.read(dataLoggersProvider.notifier).toggleAlarm(logger.id, val),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOC Gauge
// ─────────────────────────────────────────────────────────────────────────────

class _SocGauge extends StatelessWidget {
  final int soc;
  final Animation<double> pulse;
  const _SocGauge({required this.soc, required this.pulse});

  Color get _color => soc > 50
      ? const Color(0xFF10B981)
      : soc > 20
          ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          const Text('Battery SOC',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: soc / 100.0,
                    backgroundColor: Colors.white10,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$soc%',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _color)),
                    Text(
                        soc > 80
                            ? 'Full'
                            : soc > 40
                                ? 'Good'
                                : soc > 15
                                    ? 'Low'
                                    : 'Critical',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid status card
// ─────────────────────────────────────────────────────────────────────────────

class _GridStatusCard extends StatelessWidget {
  final bool isOn;
  final Animation<double> pulse;
  const _GridStatusCard({required this.isOn, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final color =
        isOn ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return _GlassCard(
      child: Column(
        children: [
          const Text('Grid Relay',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1 * pulse.value),
                border: Border.all(
                    color: color.withOpacity(0.6 * pulse.value), width: 2),
                boxShadow: isOn
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3 * pulse.value),
                          blurRadius: 24,
                          spreadRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      isOn
                          ? Icons.power_rounded
                          : Icons.power_off_rounded,
                      color: color,
                      size: 38),
                  const SizedBox(height: 4),
                  Text(
                    isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Shared glass card
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  const _GlassCard({required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1C2333)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor?.withOpacity(0.5) ??
              Colors.white.withOpacity(0.07),
          width: 1.5,
        ),
        boxShadow: [
          if (accentColor != null)
            BoxShadow(
              color: accentColor!.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
