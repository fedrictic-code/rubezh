import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const RubezhApp());
}

class RubezhApp extends StatelessWidget {
  const RubezhApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Рубеж',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: Center(child: Text('Рубеж'))),
      );
}
