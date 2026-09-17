import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';
import 'service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Set your desired color here
    ));

    return const MaterialApp(debugShowCheckedModeBanner: false, title: 'Solar LEB', home: Home());
  }
}
