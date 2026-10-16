// Рабочая папка редактора: копия assets/mod игры на диске.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:rubezh/mod/mod.dart';

class Workspace implements ModSource {
  /// Папка, соответствующая flutter/assets/ в репозитории (внутри неё — mod/).
  final String rootPath;
  /// В браузере (для снимков экрана) файлы хранятся в памяти.
  final Map<String, Uint8List>? mem;
  Workspace(this.rootPath, {bool memory = false}) : mem = memory ? {} : null;

  String pathOf(String rel) => p.joinAll([rootPath, ...rel.split('/')]);
  File _f(String rel) => File(pathOf(rel));

  Future<bool> exists(String rel) async => mem != null ? mem!.containsKey(rel) : _f(rel).exists();

  Future<void> ensure() async {
    if (mem == null) {
      for (final d in const ['mod', 'mod/maps', 'mod/art', 'mod/sfx']) {
        await Directory(pathOf(d)).create(recursive: true);
      }
    }
    if (!await exists(MOD_JSON)) await write(MOD_JSON, utf8.encode('{"version": 1}\n'));
    for (final d in const ['maps', 'art', 'sfx']) {
      if (!await exists('mod/$d/README.txt')) await write('mod/$d/README.txt', utf8.encode('Файлы мода ($d). Редактор кладёт сюда свои файлы.\n'));
    }
  }

  @override
  Future<String?> text(String path) async {
    final b = await bytes(path);
    return b == null ? null : utf8.decode(b);
  }

  @override
  Future<Uint8List?> bytes(String path) async {
    if (mem != null) return mem![path];
    final f = _f(path);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<void> write(String rel, List<int> data) async {
    if (mem != null) {
      mem![rel] = Uint8List.fromList(data);
      return;
    }
    final f = _f(rel);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(data, flush: true);
  }

  Future<void> writeJson(String rel, Object j) => write(rel, utf8.encode('${const JsonEncoder.withIndent('  ').convert(j)}\n'));

  Future<void> delete(String rel) async {
    if (mem != null) {
      mem!.remove(rel);
      return;
    }
    final f = _f(rel);
    if (await f.exists()) await f.delete();
  }

  /// Все файлы мода: путь внутри assets/ («mod/…») → содержимое.
  Future<Map<String, Uint8List>> listAll() async {
    if (mem != null) return Map.of(mem!);
    final out = <String, Uint8List>{};
    final dir = Directory(pathOf('mod'));
    if (!await dir.exists()) return out;
    await for (final e in dir.list(recursive: true)) {
      if (e is! File) continue;
      final rel = p.relative(e.path, from: rootPath).split(p.separator).join('/');
      out[rel] = await e.readAsBytes();
    }
    return out;
  }
}

/// SHA-1 объекта git для содержимого файла (так GitHub определяет, изменился ли файл).
String gitSha(List<int> data) => sha1.convert([...utf8.encode('blob ${data.length}\u0000'), ...data]).toString();

/// Латиница для имени файла из русского названия.
String slug(String s) {
  const t = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', //
    'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    'і': 'i', 'ї': 'yi', 'є': 'ye', 'ґ': 'g',
  };
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    if (t.containsKey(ch)) {
      b.write(t[ch]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      b.write(ch);
    } else {
      b.write('_');
    }
  }
  var r = b.toString().replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (r.isEmpty) r = 'item';
  return r;
}
