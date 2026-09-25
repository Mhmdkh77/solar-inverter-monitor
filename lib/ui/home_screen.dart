import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:deye_solarman/deye_solarman.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/data_logger.dart';
import '../providers/data_loggers_provider.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnim.forward();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggers = ref.watch(dataLoggersProvider);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded,
                color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Solar Inverter Monitor',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
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
      body: loggers.isEmpty ? _buildEmptyState() : _buildList(loggers),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddTypeDialog(context),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add),
          label: const Text('Add Logger',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1F2937),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.wifi_tethering_outlined,
                size: 44, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 24),
          const Text('No loggers yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Tap + Add Logger to connect your\nsolar inverter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<DataLogger> loggers) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: loggers.length,
      itemBuilder: (context, index) {
        return _LoggerCard(
          logger: loggers[index],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(loggerId: loggers[index].id),
              ),
            );
          },
          onLongPress: () => _showDeleteDialog(loggers[index]),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  // Add Logger flow
  // ──────────────────────────────────────────────────────────

  void _showAddTypeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            const Text('Add Data Logger',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _AddTypeButton(
              icon: Icons.wifi_find_rounded,
              label: 'Scan Network',
              subtitle: 'Discover loggers via UDP broadcast',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(context);
                _showScanDialog();
              },
            ),
            const SizedBox(height: 12),
            _AddTypeButton(
              icon: Icons.edit_note_rounded,
              label: 'Add Manually',
              subtitle: 'Enter IP address and serial number',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(context);
                _showAddManualDialog({});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScanDialog(
        onSelect: (discovered) {
          Navigator.pop(context);
          _showAddManualDialog(discovered);
        },
        onManual: () {
          Navigator.pop(context);
          _showAddManualDialog({});
        },
      ),
    );
  }

  void _showAddManualDialog(Map<String, String> prefill) {
    showDialog(
      context: context,
      builder: (_) => _AddLoggerDialog(
        prefill: prefill,
        onAdd: (logger) async {
          await ref.read(dataLoggersProvider.notifier).addLogger(logger);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(DataLogger logger) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Logger'),
        content: Text(
            'Remove "${logger.name}"? This will also erase all its history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              ref.read(dataLoggersProvider.notifier).removeLogger(logger.id);
              Navigator.pop(context);
            },
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logger card widget
// ─────────────────────────────────────────────────────────────────────────────

class _LoggerCard extends StatelessWidget {
  final DataLogger logger;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LoggerCard(
      {required this.logger, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final bool? gridOn = logger.lastGridOn;
    final int soc = logger.lastSoc ?? 0;
    final bool hasData = logger.lastSeen != null;

    final gridColor = gridOn == true
        ? const Color(0xFF10B981)
        : gridOn == false
            ? const Color(0xFFEF4444)
            : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF111827),
                const Color(0xFF1F2937).withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasData
                  ? gridColor.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              if (hasData && gridOn == true)
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Status dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gridColor,
                    boxShadow: [
                      if (gridOn == true)
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(logger.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${logger.ipAddress}  •  S/N: ${logger.serial}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // SOC ring (only when data available)
                if (hasData) ...[
                  Column(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: soc / 100.0,
                              backgroundColor: Colors.white12,
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                soc > 50
                                    ? const Color(0xFF10B981)
                                    : soc > 20
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFEF4444),
                              ),
                            ),
                            Text('$soc',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('SOC%',
                          style:
                              TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF4B5563)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add type button
// ─────────────────────────────────────────────────────────────────────────────

class _AddTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddTypeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF4B5563)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network scan dialog  (restored from old app)
// ─────────────────────────────────────────────────────────────────────────────

class _ScanDialog extends StatefulWidget {
  final void Function(Map<String, String>) onSelect;
  final VoidCallback onManual;
  const _ScanDialog({required this.onSelect, required this.onManual});

  @override
  State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> {
  List<Map<String, String>> _results = [];
  bool _scanning = true;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _doScan();
  }

  Future<void> _doScan() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!mounted) return;
      if (connectivity == ConnectivityResult.none) {
        setState(() {
          _scanning = false;
          _message = 'No network connection. Connect to Wi-Fi and try again.';
        });
        return;
      }
      final results = await Inverter.scan();
      if (!mounted) return;
      setState(() {
        _results = results;
        _scanning = false;
        if (results.isEmpty) _message = 'No loggers found on this network.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = 'Scan failed. Add logger manually.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.wifi_find_rounded,
              color: Theme.of(context).colorScheme.secondary, size: 22),
          const SizedBox(width: 10),
          Text(_scanning
              ? 'Scanning Network…'
              : _results.isEmpty
                  ? 'Scan Results'
                  : 'Loggers Found'),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 220,
        child: _scanning
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF10B981)),
                    SizedBox(height: 16),
                    Text('Sending discovery packet…',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  ],
                ),
              )
            : _results.isEmpty
                ? Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 48, color: Color(0xFF4B5563)),
                      const SizedBox(height: 12),
                      Text(_message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF9CA3AF))),
                    ],
                  ))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.router_rounded,
                            color: Color(0xFF10B981)),
                        title: Text(r['serial'] ?? 'Unknown',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(r['ipAddress'] ?? '',
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 12)),
                        onTap: () => widget.onSelect(r),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onManual,
          child: const Text('Add Manually',
              style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
        if (!_scanning)
          TextButton(
            onPressed: () {
              setState(() {
                _scanning = true;
                _results = [];
                _message = '';
              });
              _doScan();
            },
            child: Text('Retry',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add logger form dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddLoggerDialog extends StatefulWidget {
  final Map<String, String> prefill;
  final Future<void> Function(DataLogger) onAdd;

  const _AddLoggerDialog({required this.prefill, required this.onAdd});

  @override
  State<_AddLoggerDialog> createState() => _AddLoggerDialogState();
}

class _AddLoggerDialogState extends State<_AddLoggerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _portCtrl;
  bool _loading = false;

  String? _nameError;
  String? _ipError;
  String? _serialError;
  String? _portError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _ipCtrl = TextEditingController(text: widget.prefill['ipAddress'] ?? '');
    _serialCtrl = TextEditingController(text: widget.prefill['serial'] ?? '');
    _portCtrl = TextEditingController(text: '8899');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _serialCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty
          ? 'Name is required'
          : _nameCtrl.text.trim().length > 20
              ? 'Max 20 characters'
              : null;

      final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      if (!ipRegex.hasMatch(_ipCtrl.text.trim())) {
        _ipError = 'Invalid IP format (e.g. 192.168.1.100)';
      } else {
        final octets = _ipCtrl.text.trim().split('.').map(int.parse).toList();
        _ipError = octets.every((o) => o >= 0 && o <= 255)
            ? null
            : 'IP octet out of range';
      }

      final serial = int.tryParse(_serialCtrl.text.trim());
      _serialError = serial == null || serial < 1 || serial > 0xFFFFFFFF
          ? 'Enter a valid logger serial number'
          : null;

      final port = int.tryParse(_portCtrl.text.trim());
      _portError = port == null || port < 1 || port > 65535
          ? 'Port must be between 1 and 65535'
          : null;
    });

    return _nameError == null &&
        _ipError == null &&
        _serialError == null &&
        _portError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _submitError = null;
    });

    final logger = DataLogger(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      ipAddress: _ipCtrl.text.trim(),
      serial: int.parse(_serialCtrl.text.trim()),
      port: int.parse(_portCtrl.text.trim()),
    );

    try {
      await widget.onAdd(logger);
    } catch (e) {
      if (mounted) {
        setState(
            () => _submitError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Logger Details'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_submitError != null) ...[
                Text(_submitError!,
                    style: const TextStyle(color: Color(0xFFEF4444))),
                const SizedBox(height: 12),
              ],
              _field('Name', _nameCtrl, _nameError, hint: 'e.g. Home Rooftop'),
              const SizedBox(height: 12),
              _field('IP Address', _ipCtrl, _ipError,
                  hint: '192.168.1.x',
                  readOnly: widget.prefill['ipAddress'] != null &&
                      widget.prefill['ipAddress']!.isNotEmpty),
              const SizedBox(height: 12),
              _field('Serial Number', _serialCtrl, _serialError,
                  hint: 'e.g. 1234567890',
                  keyboard: TextInputType.number,
                  readOnly: widget.prefill['serial'] != null &&
                      widget.prefill['serial']!.isNotEmpty),
              const SizedBox(height: 12),
              _field('Port', _portCtrl, _portError,
                  hint: '8899', keyboard: TextInputType.number),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Text('Add Logger'),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String? error, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded,
                size: 16, color: Color(0xFF6B7280))
            : null,
      ),
    );
  }
}
