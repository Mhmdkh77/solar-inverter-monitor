import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/data_loggers_provider.dart';
import '../services/db_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = 'v${info.version}+${info.buildNumber}');
  }

  Future<void> _clearAllData() async {
    final loggers = ref.read(dataLoggersProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete all chart data and event logs for every logger. Logger configurations will be kept.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Everything',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() => _clearing = true);
      for (final l in loggers) {
        await DatabaseHelper.instance.deleteLoggerData(l.id);
      }
      if (mounted) {
        setState(() => _clearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All history data cleared.'),
            backgroundColor: Color(0xFF111827),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggers = ref.watch(dataLoggersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: AppBar(
        title: const Text('Settings'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1117), Color(0xFF111827)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── About ────────────────────────────────────────────────────
          const _SectionHeader('About'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Solar Inverter Monitor',
                trailing: Text(_version,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.devices_rounded,
                iconColor: const Color(0xFF3B82F6),
                label: 'Loggers configured',
                trailing: Text('${loggers.length}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 13)),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Alarm-enabled loggers',
                trailing: Text(
                    '${loggers.where((l) => l.alarmEnabled).length}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Data management ──────────────────────────────────────────
          const _SectionHeader('Data'),
          _SettingsCard(
            children: [
              const _SettingsTile(
                icon: Icons.storage_rounded,
                iconColor: Color(0xFF8B5CF6),
                label: 'Data stored locally',
                trailing: Text('SQLite',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
              ),
              const _Divider(),
              const _SettingsTile(
                icon: Icons.history_rounded,
                iconColor: Color(0xFF06B6D4),
                label: 'Chart data retention',
                trailing: Text('7 days',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'Clear all history data',
                onTap: _clearing ? null : _clearAllData,
                trailing: _clearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFEF4444)))
                    : const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF4B5563), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Protocol info ─────────────────────────────────────────────
          const _SectionHeader('Protocol'),
          const _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.lan_rounded,
                iconColor: Color(0xFF10B981),
                label: 'Communication',
                trailing: Text('SolarmanV5 / Modbus RTU',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.wifi_rounded,
                iconColor: Color(0xFFF59E0B),
                label: 'Discovery protocol',
                trailing: Text('UDP broadcast :48899',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.timer_outlined,
                iconColor: Color(0xFF3B82F6),
                label: 'Background poll interval',
                trailing: Text('30 seconds',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.timer_outlined,
                iconColor: Color(0xFF06B6D4),
                label: 'Foreground poll interval',
                trailing: Text('10 seconds',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, thickness: 1, color: Color(0xFF1F2937), indent: 66);
  }
}
