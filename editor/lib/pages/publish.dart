// Раздел «Готово»: настройки GitHub, загрузка мода из репозитория, отправка изменений и сборка APK.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:rubezh/mod/mod.dart';

import '../files.dart';
import '../github.dart';
import '../state.dart';
import '../widgets.dart';

void openFolder(String path) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else {
      Process.run('xdg-open', [path]);
    }
  } catch (_) {}
}

class PublishPage extends StatefulWidget {
  const PublishPage({super.key});
  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  bool busy = false;
  String step = '', check = '';
  final List<String> log = [];
  Map<String, Uint8List?>? changes;
  String? runUrl, apkPath, error;
  final TextEditingController msg = TextEditingController(text: 'Мод: изменения из редактора');
  bool showToken = false;
  late final TextEditingController tokenC = TextEditingController(text: ED.token);

  GitHub gh() => GitHub(ED.owner.trim(), ED.repo.trim(), ED.branch.trim(), ED.token.trim());

  void _log(String s) => setState(() {
        step = s;
        log.add('${TimeOfDay.now().format(context)}  $s');
      });

  Future<void> doCheck() async {
    setState(() => check = 'Проверка…');
    try {
      final r = await gh().check();
      setState(() => check = r);
    } catch (e) {
      setState(() => check = '$e');
    }
  }

  Future<Map<String, Uint8List?>> diff() async {
    final r = await gh().remoteMod();
    final local = await ED.ws.listAll();
    final out = <String, Uint8List?>{};
    local.forEach((k, v) {
      if (r.$3[k] != gitSha(v)) out[k] = v;
    });
    for (final k in r.$3.keys) {
      if (!local.containsKey(k)) out[k] = null;
    }
    return out;
  }

  Future<void> doDiff() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final d = await diff();
      setState(() => changes = d);
    } catch (e) {
      setState(() => error = '$e');
    }
    setState(() => busy = false);
  }

  Future<void> download() async {
    if (!await confirm(context, 'Загрузить с GitHub', 'Файлы мода в рабочей папке будут заменены версией из репозитория. Несохранённые на GitHub изменения пропадут.', ok: 'Загрузить')) return;
    setState(() {
      busy = true;
      error = null;
      log.clear();
    });
    try {
      final g = gh();
      _log('Чтение репозитория…');
      final r = await g.remoteMod();
      final local = await ED.ws.listAll();
      int i = 0;
      for (final e in r.$3.entries) {
        i++;
        if (local[e.key] != null && gitSha(local[e.key]!) == e.value) continue;
        _log('Скачивание $i из ${r.$3.length}: ${e.key}');
        await ED.ws.write(e.key, await g.blob(e.value));
      }
      for (final k in local.keys) {
        if (!r.$3.containsKey(k)) await ED.ws.delete(k);
      }
      await ED.ws.ensure();
      await ED.reload();
      _log('Готово: мод загружен из ${ED.owner}/${ED.repo}');
      setState(() => changes = {});
    } catch (e) {
      setState(() => error = '$e');
    }
    setState(() => busy = false);
  }

  Future<void> publish() async {
    if (ED.token.trim().isEmpty) {
      setState(() => error = 'Укажите токен GitHub выше');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      runUrl = null;
      apkPath = null;
      log.clear();
    });
    try {
      final g = gh();
      _log('Сравнение с репозиторием…');
      final r = await g.remoteMod();
      final local = await ED.ws.listAll();
      final ch = <String, Uint8List?>{};
      local.forEach((k, v) {
        if (r.$3[k] != gitSha(v)) ch[k] = v;
      });
      for (final k in r.$3.keys) {
        if (!local.containsKey(k)) ch[k] = null;
      }
      if (ch.isEmpty) {
        _log('Изменений нет — отправлять нечего.');
        setState(() => busy = false);
        return;
      }
      _log('Изменено файлов: ${ch.length}');
      final sha = await g.commit(r.$1, r.$2, ch, msg.text.trim().isEmpty ? 'Мод: изменения из редактора' : msg.text.trim(), progress: _log);
      _log('Изменения отправлены (коммит ${sha.substring(0, 7)}). Ждём запуска сборки…');
      setState(() => changes = {});
      final t0 = DateTime.now();
      Map<String, dynamic>? run;
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 8));
        run = await g.buildRun(sha);
        final el = DateTime.now().difference(t0);
        if (run == null) {
          if (el.inMinutes >= 3) throw Exception('Сборка не запустилась за 3 минуты. Проверьте вкладку Actions в репозитории.');
          continue;
        }
        runUrl = run['html_url'] as String?;
        final st = run['status'] as String;
        final mm = el.inMinutes, ss = el.inSeconds % 60;
        setState(() => step = 'Сборка APK: ${st == 'queued' ? 'в очереди' : (st == 'completed' ? 'завершена' : 'идёт')} · $mm:${ss.toString().padLeft(2, '0')} (обычно 6–8 минут)');
        if (st == 'completed') break;
        if (el.inMinutes > 30) throw Exception('Сборка идёт дольше 30 минут');
      }
      if (run['conclusion'] != 'success') {
        throw Exception('Сборка завершилась с ошибкой (${run['conclusion']}). Откройте ссылку на сборку ниже.');
      }
      _log('Сборка готова. Скачивание APK…');
      Uint8List? apk;
      for (int i = 0; i < 10 && apk == null; i++) {
        apk = await g.latestApk(sha);
        if (apk == null) await Future<void>.delayed(const Duration(seconds: 6));
      }
      if (apk == null) throw Exception('APK не найден в релизе apk-latest. Его можно скачать на странице сборки.');
      Directory dir;
      try {
        dir = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      final now = DateTime.now();
      final name = 'Rubezh_${now.year}${_2(now.month)}${_2(now.day)}_${_2(now.hour)}${_2(now.minute)}.apk';
      final f = File(p.join(dir.path, name));
      await f.writeAsBytes(apk);
      setState(() => apkPath = f.path);
      _log('APK сохранён: ${f.path}');
    } catch (e) {
      setState(() => error = '$e');
      _log('Ошибка: $e');
    }
    setState(() => busy = false);
  }

  String _2(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ED,
      builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
        Section('GitHub', [
          Fields([
            TextF('Владелец', ED.owner, (v) {
              ED.owner = v;
              ED.saveGh();
            }),
            TextF('Репозиторий', ED.repo, (v) {
              ED.repo = v;
              ED.saveGh();
            }),
            TextF('Ветка', ED.branch, (v) {
              ED.branch = v;
              ED.saveGh();
            }),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: tokenC,
                obscureText: !showToken,
                decoration: InputDecoration(
                  labelText: 'Токен GitHub (fine-grained: Contents — Read and write, Actions — Read)',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: Icon(showToken ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => showToken = !showToken)),
                ),
                onChanged: (v) {
                  ED.token = v.trim();
                  ED.saveGh();
                },
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: doCheck, child: const Text('Проверить')),
          ]),
          if (check.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(check)),
          const SizedBox(height: 6),
          const Text('Токен хранится только на этом компьютере. Создать: github.com → Settings → Developer settings → Fine-grained tokens, доступ только к этому репозиторию.',
              style: TextStyle(color: kMut, fontSize: 12)),
        ]),
        Section('Рабочая папка', [
          SelectableText(ED.ws.pathOf('mod')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => openFolder(ED.ws.pathOf('mod')), icon: const Icon(Icons.folder_open), label: const Text('Открыть папку')),
            OutlinedButton.icon(onPressed: busy ? null : download, icon: const Icon(Icons.cloud_download_outlined), label: const Text('Загрузить мод с GitHub')),
            OutlinedButton.icon(onPressed: busy ? null : doDiff, icon: const Icon(Icons.difference_outlined), label: const Text('Что изменилось')),
          ]),
          if (changes != null) ...[
            const SizedBox(height: 8),
            if (changes!.isEmpty) const Text('Отличий от GitHub нет.', style: TextStyle(color: kMut)),
            for (final e in changes!.entries) Text('${e.value == null ? '− удалён' : '• изменён'}  ${e.key}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
          if (MOD.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Предупреждения мода:', style: TextStyle(color: Color(0xFFEE8A3A))),
            for (final w in MOD.warnings) Text('• $w', style: const TextStyle(color: Color(0xFFEE8A3A), fontSize: 12)),
          ],
        ]),
        Section('Готово: отправить и собрать APK', [
          TextField(controller: msg, decoration: const InputDecoration(labelText: 'Что изменено (подпись коммита)', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: busy ? null : publish,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.rocket_launch_outlined),
              label: Text(busy ? 'Выполняется…' : 'Готово — отправить на GitHub и собрать APK', style: const TextStyle(fontSize: 16)),
            ),
          ),
          if (step.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(step, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(error!, style: const TextStyle(color: Color(0xFFFF9478)))),
          if (runUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Text('Сборка: '),
                Flexible(child: SelectableText(runUrl!)),
                IconButton(tooltip: 'Скопировать', icon: const Icon(Icons.copy, size: 16), onPressed: () => Clipboard.setData(ClipboardData(text: runUrl!))),
              ]),
            ),
          if (apkPath != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x337EC27A), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF7EC27A)),
                const SizedBox(width: 10),
                Expanded(child: SelectableText('APK готов: $apkPath')),
                OutlinedButton(onPressed: () => openFolder(File(apkPath!).parent.path), child: const Text('Открыть папку')),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Ссылка на последний APK для телефона: ${GitHub.apkUrl(ED.owner, ED.repo)}', style: const TextStyle(color: kMut, fontSize: 12)),
          if (log.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in log) Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))]),
            ),
          ],
        ]),
      ]),
    );
  }
}

