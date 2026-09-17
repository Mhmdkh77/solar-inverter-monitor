import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'inverter.dart';
import 'shared_prefrences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

const mainColor = Color.fromARGB(255, 11, 123, 88);

class SolarPlant extends StatefulWidget {
  final Map<String, dynamic> dataLogger;

  const SolarPlant({required this.dataLogger, super.key});

  @override
  State<SolarPlant> createState() => _SolarPlantState();
}

class _SolarPlantState extends State<SolarPlant> {
  late SharedPreferences _prefs;
  Inverter? inverter;
  late Map<String, dynamic> dL;
  Map<String, int>? data;
  bool connecting = true;
  String message = "Somthing Went Wrong";
  late FlutterBackgroundService service;
  late bool isAlarm;

  @override
  void initState() {
    super.initState();
    dL = widget.dataLogger;
    SharedPreferences.getInstance().then((prefs) async {
      _prefs = prefs;
    });
    initInverter();
  }

  @override
  void dispose() {
    try {
      inverter!.closeSocket();
    } catch (e) {
      // print
    }
    super.dispose();
  }

  Future<void> initInverter() async {
    setState(() {
      connecting = true;
    });
    try {
      inverter = await Inverter.init(address: dL["ipAddress"] ?? "", loggerSerial: dL["serial"] ?? 0);
      await refresh();
    } catch (e) {
      message = "Connection Failed";
      setState(() {
        connecting = false;
      });
    }
  }

  Future<void> refresh() async {
    setState(() {
      connecting = true;
    });
    _prefs.reload();
    isAlarm = dL["alarm"];
    try {
      data = await inverter!.readHoldingRegisters(register: 184, quantity: 11);
    } catch (e) {
      if (e is StateError && e.toString().contains('Bad state')) {
        message = "Connection Lost";
        inverter = null;
      } else {
        message = "Something Went Wrong";
      }
    }
    setState(() {
      connecting = false;
    });
  }

  @override
  Widget build(BuildContext context0) {
    return Scaffold(
      appBar: AppBar(
        title: Text(dL["name"] ?? "N/A", style: const TextStyle(color: Colors.white)),
        backgroundColor: mainColor,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: inverter == null ? initInverter : refresh, icon: const Icon(Icons.refresh), color: Colors.white),
        ],
      ),
      body: Center(
        child: connecting
            ? const CircularProgressIndicator()
            : inverter == null || data == null
                ? Text(
                    message,
                    style: const TextStyle(fontSize: 30),
                  )
                : Column(children: [
                    const SizedBox(height: 80),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 170, // Adjust the width to accommodate the larger text
                          height: 170, // Adjust the height to accommodate the larger text
                          child: CircularProgressIndicator(
                            value: (data!["Battery SOC"] ?? 0).toDouble() / 100,
                            backgroundColor: mainColor.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(mainColor),
                            strokeWidth: 10,
                          ),
                        ),
                        Text(
                          "${data!["Battery SOC"] ?? "N/A"}",
                          style: const TextStyle(
                            fontSize: 70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Text(
                      data!.containsKey("Grid Relay Status")
                          ? data!["Grid Relay Status"] == 0
                              ? "OFF"
                              : "ON"
                          : "N/A",
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(height: 60),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Text(
                          "Alarm",
                          style: TextStyle(fontSize: 25),
                        ),
                        Switch(
                            value: isAlarm,
                            onChanged: (value) async {
                              String serial = "${dL["serial"]}";
                              dL["alarm"] = value;
                              await setMap(serial, dL);
                              final service = FlutterBackgroundService();
                              List<String> alarms = _prefs.getStringList("alarms") ?? [];

                              if (value) {
                                if (!alarms.contains("${dL["serial"]}")) {
                                  alarms.add("${dL["serial"]}");
                                  await _prefs.setStringList("alarms", alarms);
                                }
                                bool isRunning = await service.isRunning();
                                if (isRunning) {
                                  service.invoke("stopService");
                                }
                                service.startService();
                              } else {
                                alarms.remove("${dL["serial"]}");
                                await _prefs.setStringList("alarms", alarms);
                                service.invoke("stopService");
                                if (alarms.isNotEmpty) {
                                  service.startService();
                                }
                              }
                              setState(() {
                                isAlarm = value;
                                _prefs.reload();
                              });
                            }),
                      ],
                    ),
                    const SizedBox(height: 60),
                    Text("${_prefs.getStringList("alarms") ?? []}")
                  ]),
      ),
    );
  }
}
