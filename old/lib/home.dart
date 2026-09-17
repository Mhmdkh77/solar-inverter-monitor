import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar/solar_plant.dart';
import 'inverter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'shared_prefrences.dart';

const mainColor = Color.fromARGB(255, 11, 123, 88);

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> _dLs = [];
  bool _start = true;
  bool _loaded = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      _prefs = value;
      _loadData();
    });
  }

  Future<void> _loadData([Future<void> Function()? fn]) async {
    if (_loaded) {
      setState(() {
        _loaded = false;
      });
    }
    if (fn != null) {
      await fn();
    }
    await Future.delayed(const Duration(seconds: 1));
    _dLs = [];
    if (_prefs.containsKey("dataLoggers")) {
      List<String> dLs = _prefs.getStringList("dataLoggers") ?? [];
      for (int i = 0; i < dLs.length; i++) {
        String dLSerial = dLs[i];
        Map<String, dynamic> dL = await getMap(dLSerial);
        if (dL.isNotEmpty) {
          _dLs.add(dL);
        } else {
          await delete(dLSerial);
        }
      }
    }
    setState(() {
      _loaded = true;
      _start = false;
    });
  }

  Future<void> delete(String serial) async {
    List<String> dLs = _prefs.getStringList("dataLoggers") ?? [];
    await _prefs.remove(serial);
    dLs.remove(serial);
    await _prefs.setStringList("dataLoggers", dLs);
  }

  @override
  Widget build(BuildContext context) {
    return !_start
        ? Scaffold(
            appBar: AppBar(
              title: const Text("Data Loggers", style: TextStyle(color: Colors.white)),
              backgroundColor: mainColor,
              actions: [
                IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), color: Colors.white),
                IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add, color: Colors.white)),
              ],
            ),
            body: _loaded
                ? DataLoggersList(
                    dataLoggers: _dLs,
                    onSelectDataLogger: (int index) async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => SolarPlant(dataLogger: _dLs[index])));
                      _loadData();
                    },
                    onLongPress: (int index) => _showDeleteDialog(index),
                  )
                : const Center(child: CircularProgressIndicator(color: mainColor)))
        : const Start();
  }

  void _showAddDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          contentPadding: const EdgeInsets.all(30.0),
          title: const Text("Add Data Logger", style: TextStyle(fontSize: 25)),
          children: <Widget>[
            SizedBox(height: 10, width: MediaQuery.of(context).size.width),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _addLocalDialog();
              },
              style: TextButton.styleFrom(backgroundColor: mainColor),
              child: const Text("Local", style: TextStyle(color: Colors.white, fontSize: 25)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: null,
              style: TextButton.styleFrom(backgroundColor: mainColor),
              child: const Text("API", style: TextStyle(color: Colors.white, fontSize: 25)),
            )
          ],
        );
      },
    );
  }

  void _addLocalDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return _AddLocal(loadData: _loadData);
      },
    );
  }

  void _showDeleteDialog(int index) {
    Map<String, dynamic> dL = _dLs[index];

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Delete ${dL["name"]}?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
              TextButton(
                  onPressed: () {
                    _loadData(() async => await delete("${dL["serial"] ?? ""}"));
                    Navigator.pop(context);
                  },
                  child: const Text("yes"))
            ],
          );
        });
  }
}

class Start extends StatelessWidget {
  const Start({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: mainColor,
      body: Center(
        child: Text("Welcome", style: TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class DataLoggersList extends StatelessWidget {
  final Function(int) onSelectDataLogger;
  final Function(int) onLongPress;
  final List<Map<String, dynamic>> dataLoggers;
  final String message;

  const DataLoggersList(
      {required this.dataLoggers, required this.onSelectDataLogger, required this.onLongPress, this.message = "No Data Loggers", super.key});

  @override
  Widget build(BuildContext context) {
    return dataLoggers.isEmpty
        ? Center(child: Text(message, style: const TextStyle(fontSize: 20)))
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: dataLoggers.length,
            itemBuilder: (context, index) {
              return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: ListTile(
                    tileColor: mainColor.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    onTap: () => onSelectDataLogger(index),
                    onLongPress: () => onLongPress(index),
                    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("${dataLoggers[index]["name"] ?? "unknown"}", style: const TextStyle(fontSize: 20)),
                      Text("${dataLoggers[index]["serial"] ?? "unknown"}"),
                      Text("${dataLoggers[index]["type"] ?? "unKnown"}")
                    ]),
                  ));
            });
  }
}

class _AddLocal extends StatefulWidget {
  final Function(Future<void> Function() fn) loadData;
  const _AddLocal({required this.loadData});

  @override
  State<_AddLocal> createState() => _AddLocalState();
}

class _AddLocalState extends State<_AddLocal> {
  bool scanned = false;
  List<Map<String, String>> dLs = [];
  late SharedPreferences _prefs;
  String message = "No Data Loggers";

  @override
  void initState() {
    super.initState();
    scan();
  }

  Future<void> scan() async {
    _prefs = await SharedPreferences.getInstance();
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      message = "Please Connect to a Network";
    } else {
      try {
        dLs = await Inverter.scan();
      } catch (e) {
        message = "Somthing Went Wrong";
        log("$e");
      }
    }
    if (mounted) {
      setState(() {
        scanned = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(20.0),
      title: const Text("Local Data Loggers"),
      content: SizedBox(
          width: 300,
          height: 200,
          child: scanned
              ? dLs.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: dLs.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          tileColor: mainColor.withOpacity(0.1),
                          onTap: () => _addDialog(dLs[index]),
                          title: Text("${dLs[index]["serial"]} - ${dLs[index]["ipAddress"]}"),
                        );
                      })
                  : Center(child: Text(_prefs.getString("log") ?? message))
              : const Center(child: CircularProgressIndicator())),
      actions: [
        TextButton(
          onPressed: () => _addDialog({}),
          child: const Text("Add Manually", style: TextStyle(color: Colors.black)),
        )
      ],
    );
  }

  void _addDialog(Map<String, String> dL) async {
    bool mounted = true;

    TextEditingController name = TextEditingController();
    TextEditingController ip = TextEditingController(text: dL["ipAddress"] ?? "");
    TextEditingController serial = TextEditingController(text: dL["serial"] ?? "");
    TextEditingController port = TextEditingController(text: "8899");

    bool nameError = false;
    bool ipError = false;
    bool serialError = false;
    bool portError = false;

    bool check() {
      nameError = name.text.length > 10 ? true : false;
      if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip.text)) {
        List<int> octets = ip.text.split('.').map(int.parse).toList();
        ipError = !octets.every((octet) => octet >= 0 && octet <= 255);
      } else {
        ipError = true;
      }
      serialError = int.tryParse(serial.text) == null ? true : false;
      portError = int.tryParse(port.text) == null ? true : false;

      return nameError || ipError || serialError || portError ? false : true;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            contentPadding: const EdgeInsets.all(25.0),
            title: const Text("Add Data Logger"),
            content: SizedBox(
                width: 300,
                height: 300,
                child: SingleChildScrollView(
                    child: Column(
                  children: <Widget>[
                    TextField(
                        controller: name,
                        decoration: InputDecoration(
                          hintText: "Name",
                          errorText: nameError ? 'Name must be less than 10 character' : null,
                        ),
                        onChanged: (s) => setState(() {})),
                    const SizedBox(height: 10),
                    TextField(
                        controller: ip,
                        decoration: InputDecoration(
                          hintText: "Ip Address",
                          errorText: ipError ? 'Invalid IP address format' : null,
                        ),
                        readOnly: dL.isNotEmpty,
                        onChanged: (s) => setState(() {})),
                    SizedBox(height: 10, width: MediaQuery.sizeOf(context).width),
                    TextField(
                      controller: serial,
                      decoration: InputDecoration(
                        hintText: "Serial Number",
                        errorText: serialError ? 'Invalid Serial Number' : null,
                      ),
                      readOnly: dL.isNotEmpty,
                      onChanged: (s) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: port,
                        decoration: InputDecoration(
                          hintText: "Port",
                          errorText: portError ? 'Invalid Port Number' : null,
                        ),
                        onChanged: (s) => setState(() {}))
                  ],
                ))),
            actions: [
              TextButton(
                  onPressed: name.text.isNotEmpty && serial.text.isNotEmpty && ip.text.isNotEmpty && port.text.isNotEmpty
                      ? () {
                          if (check()) {
                            widget.loadData(() async =>
                                await add({"name": name.text, "serial": int.parse(serial.text), "ipAddress": ip.text, "port": int.parse(port.text)}));
                            Navigator.pop(context);
                            Navigator.pop(context);
                          } else if (mounted) {
                            setState(() {});
                          }
                        }
                      : null,
                  child: const Text("Add", style: TextStyle(color: Colors.black)))
            ],
          );
        });
      },
    ).then((_) => mounted = false);
  }

  Future<void> add(Map<String, dynamic> dL) async {
    String serial = "${dL["serial"]}";
    List<String> dLs = _prefs.getStringList("dataLoggers") ?? [];
    if (!dLs.contains(serial)) {
      int id = (_prefs.getInt("idCounter") ?? 0) + 1;
      dLs = [...dLs, serial];
      await _prefs.setStringList("dataLoggers", dLs);
      dL["id"] = id;
      dL["type"] = "local";
      dL["alarm"] = false;
      await setMap(serial, dL);
      await _prefs.setInt("idCounter", id);
    }
  }
}
