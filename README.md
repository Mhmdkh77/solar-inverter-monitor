# Solar Grid

A Flutter app for monitoring solar inverters on your local network — live battery
state of charge, grid relay status, historical charts, and alarm notifications
when the grid goes down or comes back.

Talks directly to Solarman-compatible data loggers over the SolarmanV5 /
Modbus RTU protocol — no cloud account or internet connection required.

## Features

- **UDP auto-discovery** — find data loggers on your Wi-Fi network, or add
  one manually by IP and serial number
- **Live dashboard** — battery SOC gauge and grid relay status, polled every
  10 seconds while the app is open
- **Background monitoring** — a foreground service keeps polling (every 30s)
  and fires a loud, full-screen alarm notification when the grid goes off or
  comes back on, even if the app is closed
- **History** — 24h battery SOC chart and a filterable event log, stored
  locally in SQLite (chart data auto-pruned after 7 days)
- **Multiple loggers** — monitor several inverters, with alarms toggled per
  logger

## Tech stack

- [Flutter](https://flutter.dev) / Dart
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) for state management
- [sqflite](https://pub.dev/packages/sqflite) for local history storage
- [flutter_background_service](https://pub.dev/packages/flutter_background_service) +
  [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
  for background polling and alarms
- [fl_chart](https://pub.dev/packages/fl_chart) for the SOC history chart
- Raw TCP sockets for the SolarmanV5 protocol (`lib/inverter.dart`) — no
  vendor SDK or cloud API involved

## Project structure

```
lib/
  inverter.dart              # SolarmanV5/Modbus RTU protocol implementation
  main.dart                  # App entry point, theming
  models/data_logger.dart    # Data logger config model
  providers/                 # Riverpod state (logger list, persistence)
  services/
    background_service.dart  # Foreground service: polling, alarms
    db_helper.dart            # SQLite schema and queries
  ui/
    home_screen.dart          # Logger list, add/scan/delete flows
    dashboard_screen.dart     # Live SOC gauge, grid status, chart
    event_logs_screen.dart    # Filterable grid on/off event history
    settings_screen.dart      # App info, data management
    splash_screen.dart
old/                          # Earlier prototype implementation, kept as reference
```

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart >=3.2.2) and an Android device or emulator on the same network as your
inverter's data logger.

```bash
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk
```

The app currently targets Android only (`android/`); no iOS project is
configured.

## How it connects

On the local network, Solarman-compatible data loggers listen on TCP port
`8899` and speak a framed Modbus-over-TCP protocol (SolarmanV5). The app:

1. Broadcasts a UDP discovery packet on port `48899` to find loggers (or you
   enter the IP/serial manually).
2. Opens a persistent TCP socket to the logger and reads holding registers
   `184`–`194`, extracting Battery SOC (register `184`) and Grid Relay
   Status (register `194`).
3. Polls on that interval, in the foreground (10s) and in the background
   (30s), writing each reading to SQLite and firing an alarm notification on
   any grid state change (if enabled for that logger).

Register addresses were confirmed against the author's own inverter — see
the comments in `lib/inverter.dart` for details, since register layouts are
inverter-model specific.

## Permissions

The Android app requests: `INTERNET`, network/Wi-Fi state (for discovery and
connectivity checks), `FOREGROUND_SERVICE` (background polling),
`POST_NOTIFICATIONS` and `USE_FULL_SCREEN_INTENT` (alarm alerts), and
`VIBRATE`/`WAKE_LOCK` for the alarm itself.
