import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rubezh/game/core.dart';
import 'package:rubezh/game/data.dart';
import 'package:rubezh_editor/files.dart';
import 'package:rubezh_editor/imgproc.dart';
import 'package:rubezh_editor/main.dart';
import 'package:rubezh_editor/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test('slug и sha как у git', () {
    expect(slug('Т-72Б3М Новый'), 't_72b3m_novyy');
    expect(gitSha(Uint8List.fromList('hello\n'.codeUnits)), 'ce013625030ba8dba906f756967f9e9ca394464a');
  });

  test('распознавание местности по цветам', () {
    final im = img.Image(width: 1200, height: 750);
    img.fill(im, color: img.ColorRgb8(150, 160, 90)); // поле
    img.fillRect(im, x1: 0, y1: 300, x2: 1199, y2: 360, color: img.ColorRgb8(40, 80, 170)); // река
    img.fillRect(im, x1: 100, y1: 50, x2: 300, y2: 200, color: img.ColorRgb8(30, 70, 30)); // лес
    final jpg = Uint8List.fromList(img.encodeJpg(im, quality: 95));
    final r = prepareMapImage(MapImageJob(jpg, true));
    expect(r.error, isNull);
    expect(r.terrain.length, GW * GH);
    expect(r.terrain[cellIdx(1200, 660)], Ter.WATER);
    expect(r.terrain[cellIdx(400, 250)], Ter.FOREST);
    expect(r.terrain[cellIdx(1800, 1200)], Ter.OPEN);
  });

  test('рабочая папка: юнит в моде и обратно', () async {
    final dir = await Directory.systemTemp.createTemp('rubezh_ed');
    await ED.init(root: dir.path);
    final u = ED.unitJson('tank_t72b3');
    u['id'] = 'tank_test';
    u['name'] = 'Проверочный танк';
    await ED.saveUnit(u);
    expect(VARS.containsKey('tank_test'), true);
    await ED.deleteUnit('tank_test');
    expect(VARS.containsKey('tank_test'), false);
    await ED.deleteUnit('sniper_ru');
    expect(VARS.containsKey('sniper_ru'), false);
    await ED.restoreUnit('sniper_ru');
    expect(VARS.containsKey('sniper_ru'), true);
    final files = await ED.ws.listAll();
    expect(files.containsKey('mod/mod.json'), true);
    expect(files.containsKey('mod/art/README.txt'), true);
  });

  testWidgets('редактор открывается', (t) async {
    ED.ready = false;
    await t.pumpWidget(const EditorApp(autoInit: false));
    expect(find.text('Рубеж — редактор'), findsOneWidget);
  });
}
