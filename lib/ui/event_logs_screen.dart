import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_helper.dart';

class EventLogsScreen extends StatefulWidget {
  final String loggerId;
  final String loggerName;

  const EventLogsScreen(
      {super.key, required this.loggerId, required this.loggerName});

  @override
  State<EventLogsScreen> createState() => _EventLogsScreenState();
}

class _EventLogsScreenState extends State<EventLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _filter; // null = all, 'GRID_ON', 'GRID_OFF'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await DatabaseHelper.instance
        .getEventLogs(widget.loggerId, eventTypeFilter: _filter);
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Logs'),
        content: const Text(
            'Delete all event logs for this logger? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.clearEventLogs(widget.loggerId);
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.loggerName} — Logs'),
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
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear logs',
              onPressed: _clearLogs,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterBar(),
          // Log list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF10B981)))
                : _logs.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 10),
        child: Row(
          children: [
            _FilterChip(
                label: 'All',
                active: _filter == null,
                color: const Color(0xFF6B7280),
                onTap: () {
                  setState(() => _filter = null);
                  _loadLogs();
                }),
            const SizedBox(width: 8),
            _FilterChip(
                label: 'Grid ON',
                active: _filter == 'GRID_ON',
                color: const Color(0xFF10B981),
                icon: Icons.power_rounded,
                onTap: () {
                  setState(() => _filter = 'GRID_ON');
                  _loadLogs();
                }),
            const SizedBox(width: 8),
            _FilterChip(
                label: 'Grid OFF',
                active: _filter == 'GRID_OFF',
                color: const Color(0xFFEF4444),
                icon: Icons.power_off_rounded,
                onTap: () {
                  setState(() => _filter = 'GRID_OFF');
                  _loadLogs();
                }),
            const Spacer(),
            Text('${_logs.length} events',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off_rounded,
              size: 64, color: Color(0xFF374151)),
          const SizedBox(height: 16),
          Text(
              _filter == null
                  ? 'No events recorded yet'
                  : 'No ${_filter == 'GRID_ON' ? 'Grid ON' : 'Grid OFF'} events',
              style:
                  const TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
          if (_filter != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _filter = null);
                _loadLogs();
              },
              child: const Text('Show all',
                  style: TextStyle(color: Color(0xFF10B981))),
            )
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isGridOn = log['event_type'] == 'GRID_ON';
        final time = DateTime.fromMillisecondsSinceEpoch(
            log['timestamp'] as int);
        final color = isGridOn
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isGridOn
                      ? Icons.power_rounded
                      : Icons.power_off_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              title: Text(
                log['message'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 11, color: color.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy  HH:mm:ss').format(time),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGridOn ? 'ON' : 'OFF',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: active ? color : const Color(0xFF6B7280)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? color : const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
