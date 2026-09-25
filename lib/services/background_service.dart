import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:deye_solarman/deye_solarman.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inverter_reading.dart';
import 'db_helper.dart';

class BackgroundService {
  static const String _monitorChannelId = 'solar_monitor_channel';
  // Public so dashboard_screen can reuse it for foreground alarms
  static const String alarmChannelId = 'solar_alarm_channel';
  static const int _monitorNotifId = 888;

  /// Long aggressive vibration pattern (public for reuse in foreground alarms)
  static const List<int> alarmVibrationPattern = [
    0,
    800,
    200,
    800,
    200,
    1200,
    500,
    800,
    200,
    800,
    200,
    1200,
    500,
    800,
    200,
    800,
    200,
    1200,
  ];

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    final notif = FlutterLocalNotificationsPlugin();

    // Silent persistent monitor notification (just to keep the service alive)
    const monitorChannel = AndroidNotificationChannel(
      _monitorChannelId,
      'Grid Monitor',
      description: 'Background grid status monitoring',
      importance: Importance.low,
    );

    // Alarm channel — max importance, full-screen, uses device alarm sound
    final alarmChannel = AndroidNotificationChannel(
      alarmChannelId,
      'Grid Alerts',
      description: 'Loud alarm when the grid state changes',
      importance: Importance.max,
      playSound: true,
      sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(alarmVibrationPattern),
      enableLights: true,
      ledColor: const Color(0xFFEF4444),
      showBadge: true,
    );

    await notif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );

    final androidPlugin = notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(monitorChannel);
    await androidPlugin?.createNotificationChannel(alarmChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _monitorChannelId,
        initialNotificationTitle: 'Solar Inverter Monitor',
        initialNotificationContent: 'Starting…',
        foregroundServiceNotificationId: _monitorNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<bool> requestAlarmPermissions() async {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final notificationsAllowed =
        await android.requestNotificationsPermission() ?? false;
    if (!notificationsAllowed) return false;
    // Android may allow notifications but still restrict full-screen display.
    try {
      await android.requestFullScreenIntentPermission();
    } catch (_) {
      // Regular notifications can still work without full-screen access.
    }
    return true;
  }

  static Future<void> resumeMonitoring(SharedPreferences prefs) async {
    final alarms = jsonDecode(prefs.getString('active_alarms') ?? '[]') as List;
    if (alarms.isEmpty) return;
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) await service.startService();
  }

  /// Saves the updated alarm list to prefs and starts/stops the service.
  static Future<void> updateAlarms(List<Map<String, dynamic>> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_alarms', jsonEncode(alarms));

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (alarms.isEmpty) {
      if (isRunning) service.invoke('stopService');
    } else if (!isRunning) {
      await service.startService();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background entry points
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notif = FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((_) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((_) => service.setAsBackgroundService());
  }

  service.on('stopService').listen((_) => service.stopSelf());

  var polling = false;
  late Timer timer;

  Future<void> poll() async {
    if (polling) return;
    polling = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final alarmsJson = prefs.getString('active_alarms') ?? '[]';
      final List<dynamic> alarms = jsonDecode(alarmsJson);

      if (alarms.isEmpty) {
        timer.cancel();
        service.stopSelf();
        return;
      }

      // Update silent persistent notification
      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        await notif.show(
          BackgroundService._monitorNotifId,
          'Solar Inverter Monitor',
          'Monitoring ${alarms.length} logger${alarms.length == 1 ? '' : 's'}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              BackgroundService._monitorChannelId,
              'Grid Monitor',
              icon: '@drawable/ic_notification',
              ongoing: true,
              importance: Importance.low,
              priority: Priority.low,
            ),
          ),
        );
      }

      for (final loggerMap in alarms) {
        final String ip = loggerMap['ipAddress'] as String;
        final int serial = (loggerMap['serial'] as num).toInt();
        final int port = (loggerMap['port'] as num?)?.toInt() ?? 8899;
        final String id = loggerMap['id'] as String;
        final String name = loggerMap['name'] as String;

        Inverter? inverter;
        try {
          inverter = await Inverter.init(
              address: ip, loggerSerial: serial, port: port);
          final data =
              await inverter.readHoldingRegisters(register: 184, quantity: 11);
          final reading = InverterReading.fromRegisters(data);
          final transition = await DatabaseHelper.instance
              .recordReading(id, reading.batterySoc, reading.gridOn);

          if (transition != null) {
            final String title = !transition
                ? '⚠️ GRID POWER LOST — $name'
                : '✅ GRID RESTORED — $name';
            final String body = !transition
                ? 'The grid has gone OFF. Check your inverter!'
                : 'Grid power is back ON. Battery at ${reading.batterySoc}%.';
            await _fireAlarm(notif, id: id, title: title, body: body);
          }
        } catch (_) {
          // Silently ignore connection failures in background
        } finally {
          await inverter?.closeSocket();
        }
      }
    } catch (_) {
      // Keep the monitor running if preferences or a poll fails.
    } finally {
      polling = false;
    }
  }

  timer = Timer.periodic(const Duration(seconds: 30), (_) => poll());
  await poll();
}

/// Shows a full-screen alarm-style notification that:
/// - Pops up over the lock screen (like an incoming call)
/// - Plays the device's alarm sound
/// - Vibrates with an aggressive pattern
/// - Stays until the user manually dismisses it
Future<void> _fireAlarm(
  FlutterLocalNotificationsPlugin notif, {
  required String id,
  required String title,
  required String body,
}) async {
  await notif.show(
    id.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        BackgroundService.alarmChannelId,
        'Grid Alerts',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_notification',

        // ── Alarm sound ──────────────────────────────────────────────────
        playSound: true,
        sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert'),

        // ── Vibration ────────────────────────────────────────────────────
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList(BackgroundService.alarmVibrationPattern),

        // ── Full-screen (pops up like an incoming call) ───────────────────
        fullScreenIntent: true,

        // ── Stays until user swipes it away ──────────────────────────────
        ongoing: false, // false = user CAN dismiss, but it won't auto-hide
        autoCancel: false, // won't dismiss when tapped — must swipe

        // ── LED blink (red, 500ms on / 500ms off) ────────────────────────
        enableLights: true,
        ledColor: const Color(0xFFEF4444),
        ledOnMs: 500,
        ledOffMs: 500,

        // ── Visibility on lock screen ─────────────────────────────────────
        visibility: NotificationVisibility.public,

        // ── Category tells Android to treat this as an alarm ─────────────
        category: AndroidNotificationCategory.alarm,

        // ── Show as heads-up banner even if another app is in foreground ──
        channelShowBadge: true,
      ),
    ),
  );
}
