// Раздел «Звуки»: выстрелы по типам оружия и взрывы.
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:rubezh/game/fxcfg.dart';

import '../state.dart';
import '../widgets.dart';

final AudioPlayer _player = AudioPlayer()..audioCache = AudioCache(prefix: '');

Future<void> playSound(String rel) async {
  try {
    await _player.stop();
    if (rel.startsWith('mod/')) {
      await _player.play(DeviceFileSource(ED.ws.pathOf(rel)));
    } else {
      await _player.play(AssetSource('packages/rubezh/assets/$rel'));
    }
  } catch (e) {
    ED.say('Не удалось проиграть: $e');
  }
}

class SoundsPage extends StatelessWidget {
  const SoundsPage({super.key});

  Map<String, dynamic> _snd() => Map<String, dynamic>.from((ED.mod['sounds'] as Map?) ?? {});

  Future<void> _add(String slot) async {
    final fs = await openFiles(acceptedTypeGroups: const [
      XTypeGroup(label: 'Звук', extensions: ['wav', 'mp3', 'ogg', 'm4a'])
    ]);
    if (fs.isEmpty) return;
    final snd = _snd();
    final list = [for (final x in ((snd[slot] as List?) ?? const [])) x as String];
    for (final f in fs) {
      final ext = p.extension(f.name).toLowerCase();
      var n = 1;
      String rel;
      do {
        rel = 'mod/sfx/${slot}_$n$ext';
        n++;
      } while (list.contains(rel) || await ED.ws.exists(rel));
      await ED.ws.write(rel, await f.readAsBytes());
      list.add(rel);
    }
    snd[slot] = list;
    ED.mod['sounds'] = snd;
    await ED.saveMod();
    ED.say('Звук добавлен: ${SOUND_SLOTS[slot]}');
  }

  Future<void> _remove(String slot, String rel) async {
    final snd = _snd();
    final list = [for (final x in ((snd[slot] as List?) ?? const [])) x as String]..remove(rel);
    if (list.isEmpty) {
      snd.remove(slot);
    } else {
      snd[slot] = list;
    }
    ED.mod['sounds'] = snd;
    if (rel.startsWith('mod/')) await ED.ws.delete(rel);
    await ED.saveMod();
  }

  Future<void> _reset(String slot) async {
    final snd = _snd();
    for (final x in ((snd[slot] as List?) ?? const [])) {
      if ((x as String).startsWith('mod/')) await ED.ws.delete(x);
    }
    snd.remove(slot);
    ED.mod['sounds'] = snd;
    await ED.saveMod();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ED,
      builder: (context, _) {
        final snd = _snd();
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Для каждого события можно задать несколько файлов — в игре звучит случайный. Подходят WAV, MP3, OGG. Короткие звуки (до 1–2 секунд) звучат лучше.', style: TextStyle(color: kMut)),
          ),
          for (final e in SOUND_SLOTS.entries)
            Builder(builder: (context) {
              final custom = snd.containsKey(e.key);
              final files = custom ? [for (final x in snd[e.key] as List) x as String] : (defaultSounds()[e.key] ?? const <String>[]);
              return Section(
                e.value,
                [
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    for (final f in files)
                      InputChip(
                        avatar: const Icon(Icons.play_arrow, size: 18),
                        label: Text(custom ? p.basename(f) : '${p.basename(f)} (встроенный)'),
                        onPressed: () => playSound(f),
                        onDeleted: custom ? () => _remove(e.key, f) : null,
                      ),
                    OutlinedButton.icon(onPressed: () => _add(e.key), icon: const Icon(Icons.library_music_outlined, size: 18), label: Text(custom ? 'Добавить ещё' : 'Заменить своим')),
                  ]),
                ],
                trailing: custom ? TextButton(onPressed: () => _reset(e.key), child: const Text('Встроенный')) : null,
              );
            }),
        ]);
      },
    );
  }
}
