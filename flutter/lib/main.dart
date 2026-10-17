import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/controller.dart';
import 'app/fx.dart';
import 'app/loop.dart';
import 'app/model.dart';
import 'app/modsrc.dart';
import 'game/battle.dart';
import 'gfx/render.dart';
import 'ui/battlefield.dart';
import 'ui/hud.dart';
import 'ui/screens.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const RubezhApp());
}

class RubezhApp extends StatelessWidget {
  final bool autoInit;
  const RubezhApp({super.key, this.autoInit = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Рубеж',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: C.ink, splashFactory: NoSplash.splashFactory),
        home: Root(autoInit: autoInit),
      );
}

class Root extends StatefulWidget {
  final bool autoInit;
  const Root({super.key, required this.autoInit});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    if (widget.autoInit) _init();
  }

  @override
  void dispose() {
    LOOP.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await APP.load();
    await Fx.init();
    wireHooks();
    await bootMod();
    Fx.warm();
    final maps = allMaps();
    await prepareMap(maps.firstWhere((m) => m.id == APP.mapId, orElse: () => maps.first));
    if (!mounted) return;
    Assets.onReady = LOOP.poke;
    LOOP.start(this);
    APP.go(Screen.menu);
    _debugScreen();
  }

  /// ?screen=… — прямой вход в нужное состояние для проверки интерфейса.
  void _debugScreen() {
    final s = Uri.base.queryParameters['screen'];
    if (s == null || s == 'menu') return;
    if (s == 'settings') {
      APP.settingsOpen = true;
      APP.changed();
      return;
    }
    APP.force[APP.side] = APP.presetCounts(APP.side);
    APP.tutorial = s == 'game' || s == 'play';
    if (s == 'force') {
      APP.go(Screen.force);
      return;
    }
    CTL.startBattle();
    if (s == 'game') return;
    CTL.beginBattle();
    CTL.toastMsg = '';
    for (int i = 0; i < 20 * 75 && S.over == null; i++) {
      step();
    }
    if (s == 'sel') {
      CTL.sqTap(1);
    } else {
      CTL.selectAll();
    }
    if (s == 'deck') CTL.deckOpen = true;
    if (s == 'end') {
      S.over = Over(S.player, 'Оба рубежа удержаны ${HOLD_NEED.toInt()} секунд');
      CTL.onOver(S.over!);
    }
    CTL.changed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: APP,
        builder: (context, _) {
          final sc = APP.screen;
          return Stack(fit: StackFit.expand, children: [
            if (sc != Screen.loading) const Battlefield() else const ColoredBox(color: C.ink),
            if (sc == Screen.loading)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('РУБЕЖ', style: disp(34, ls: .12)),
                  const SizedBox(height: 8),
                  Text('Рисую карту и технику…', style: body(12, color: C.mut)),
                ]),
              ),
            if (sc == Screen.menu) const MenuScreen(),
            if (sc == Screen.force) const ForceScreen(),
            if (sc == Screen.game) const RepaintBoundary(child: Hud()),
            if (sc == Screen.game && APP.endShown) const EndScreen(),
            if (APP.settingsOpen) const SettingsSheet(),
          ]);
        },
      ),
    );
  }
}
