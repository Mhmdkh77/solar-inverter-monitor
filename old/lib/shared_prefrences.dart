import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

Future<void> setMap(String key, Map<String, dynamic> data) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = json.encode(data);
  await prefs.setString(key, jsonString);
}

Future<Map<String, dynamic>> getMap(String key) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = prefs.getString(key) ?? "{}";
  Map<String, dynamic> data = json.decode(jsonString);
  return data;
}

Future<void> log(String text) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.reload();
  String log = prefs.getString("log") ?? "";
  log += "$text\n";
  await prefs.setString("log", log);
}
