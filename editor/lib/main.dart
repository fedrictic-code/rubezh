// Редактор «Рубежа»: карты, юниты, оружие, звуки, эффекты; публикация на GitHub и сборка APK.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'demo.dart';

import 'pages/effects.dart';
import 'pages/maps.dart';
import 'pages/publish.dart';
import 'pages/sounds.dart';
import 'pages/units.dart';
import 'pages/weapons.dart';
import 'state.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EditorApp());
}

class EditorApp extends StatelessWidget {
  final bool autoInit;
  const EditorApp({super.key, this.autoInit = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Рубеж — редактор',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: kAmber, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF0E1317),
        ),
        home: Shell(autoInit: autoInit),
      );
}

class Shell extends StatefulWidget {
  final bool autoInit;
  const Shell({super.key, required this.autoInit});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int page = 0;
  String _lastToast = '';

  @override
  void initState() {
    super.initState();
    final q = Uri.base.queryParameters['page'];
    if (q != null) page = int.tryParse(q) ?? 0;
    ED.addListener(_onEd);
    if (widget.autoInit) {
      ED.init().then((_) async {
        if (kIsWeb && Uri.base.queryParameters.containsKey('demo')) {
          await seedDemo();
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    ED.removeListener(_onEd);
    super.dispose();
  }

  void _onEd() {
    if (ED.toast.isNotEmpty && ED.toast != _lastToast) {
      _lastToast = ED.toast;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ED.toast), duration: const Duration(seconds: 4)));
      ED.toast = '';
      _lastToast = '';
    }
  }

  static const _pages = [
    (Icons.map_outlined, 'Карты'),
    (Icons.local_shipping_outlined, 'Юниты'),
    (Icons.gps_fixed, 'Оружие'),
    (Icons.graphic_eq, 'Звуки'),
    (Icons.local_fire_department_outlined, 'Эффекты'),
    (Icons.rocket_launch_outlined, 'Готово'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: ED,
        builder: (context, _) {
          if (!ED.ready) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Рубеж — редактор')]));
          }
          return Row(children: [
            NavigationRail(
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('РУБЕЖ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: kAmber)),
              ),
              destinations: [for (final p in _pages) NavigationRailDestination(icon: Icon(p.$1), label: Text(p.$2))],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: switch (page) {
                0 => const MapsPage(),
                1 => const UnitsPage(),
                2 => const WeaponsPage(),
                3 => const SoundsPage(),
                4 => const EffectsPage(),
                _ => const PublishPage(),
              },
            ),
          ]);
        },
      ),
    );
  }
}
