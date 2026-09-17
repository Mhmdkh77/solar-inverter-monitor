import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_logger.dart';
import '../services/background_service.dart';
import '../services/db_helper.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in ProviderScope');
});

final dataLoggersProvider =
    StateNotifierProvider<DataLoggersNotifier, List<DataLogger>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DataLoggersNotifier(prefs);
});

class DataLoggersNotifier extends StateNotifier<List<DataLogger>> {
  final SharedPreferences _prefs;
  static const _key = 'data_loggers_v2';

  DataLoggersNotifier(this._prefs) : super([]) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final jsonString = _prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      state = decoded.map((e) => DataLogger.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, encoded);
    // Keep the background service in sync with enabled alarms
    final alarmed = state.where((l) => l.alarmEnabled).map((l) => l.toJson()).toList();
    await BackgroundService.updateAlarms(alarmed);
  }

  Future<void> addLogger(DataLogger logger) async {
    final isDuplicate =
        state.any((l) => l.ipAddress == logger.ipAddress || l.serial == logger.serial);
    if (isDuplicate) {
      throw Exception('A logger with this IP or Serial already exists.');
    }
    state = [...state, logger];
    await _persist();
  }

  Future<void> removeLogger(String id) async {
    state = state.where((l) => l.id != id).toList();
    await _persist();
    // Clean up all stored data for this logger
    await DatabaseHelper.instance.deleteLoggerData(id);
  }

  Future<void> toggleAlarm(String id, bool enabled) async {
    state = state.map((l) => l.id == id ? l.copyWith(alarmEnabled: enabled) : l).toList();
    await _persist();
  }

  /// Update transient live values (SOC, grid status) for home-screen badges.
  void updateLiveStatus(String id, {int? soc, bool? gridOn}) {
    state = state.map((l) {
      if (l.id != id) return l;
      return l.copyWith(
        lastSoc: soc ?? l.lastSoc,
        lastGridOn: gridOn ?? l.lastGridOn,
        lastSeen: DateTime.now(),
      );
    }).toList();
    // Note: no persist — these are transient and don't need storage
  }

  Future<void> updateLogger(DataLogger updated) async {
    state = state.map((l) => l.id == updated.id ? updated : l).toList();
    await _persist();
  }
}
