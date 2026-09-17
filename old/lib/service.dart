import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_prefrences.dart';
import 'dart:async';
import 'dart:ui';
import 'inverter.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  List<Map<String, dynamic>> dLs = [];
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  List<String> alarms = prefs.getStringList("alarms") ?? [];

  for (String serial in alarms) {
    Map<String, dynamic> dL = await getMap(serial);
    if (dL.isNotEmpty) {
      dLs.add(dL);
    }
  }
  if (dLs.isEmpty) {
    service.stopSelf();
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        for (var dL in dLs) {
          try {
            Inverter? inverter = await Inverter.init(address: dL["ipAddress"], loggerSerial: dL["serial"]);
            var data = await inverter.readHoldingRegisters(register: 184, quantity: 11);
            bool state = data["Grid Relay Status"] == 1;

            bool oldState = dL["oldState"] ?? state;
            if (oldState != state) {
              service.setTimer(length: 2);
            }
            dL["oldState"] = state;
            inverter.closeSocket();
          } catch (e) {
            await log("#######${DateTime.now()} : $e");
          }
        }
      }
    }
  });
}
