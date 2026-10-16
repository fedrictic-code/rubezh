// Подготовка картинки спрайта: поворот, отражение, удаление фона, обрезка — с предпросмотром.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../imgproc.dart';
import '../widgets.dart';

/// Открывает выбор файла и окно обработки. Возвращает PNG или null.
Future<Uint8List?> pickSprite(BuildContext context, String title, {String hint = 'Картинка должна смотреть вправо (нос машины — вправо).'}) async {
  final f = await openFile(acceptedTypeGroups: const [
    XTypeGroup(label: 'Картинки', extensions: ['png', 'webp', 'jpg', 'jpeg', 'bmp'])
  ]);
  if (f == null || !context.mounted) return null;
  final b = await f.readAsBytes();
  if (!context.mounted) return null;
  return showDialog<Uint8List>(context: context, builder: (_) => SpriteDialog(title: title, src: b, hint: hint));
}

class SpriteDialog extends StatefulWidget {
  final String title, hint;
  final Uint8List src;
  const SpriteDialog({super.key, required this.title, required this.src, required this.hint});
  @override
  State<SpriteDialog> createState() => _SpriteDialogState();
}

class _SpriteDialogState extends State<SpriteDialog> {
  int rot = 0;
  bool flip = false, bg = false, trim = true;
  double tol = 40;
  Uint8List? out;
  bool busy = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    run();
  }

  Future<void> run() async {
    final s = ++_seq;
    setState(() => busy = true);
    final r = await compute(processSprite, SpriteJob(widget.src, rotate: rot, flip: flip, removeBg: bg, trim: trim, tolerance: tol.round()));
    if (!mounted || s != _seq) return;
    setState(() {
      out = r;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 640,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine), color: const Color(0xFF2A3A24)),
            child: Stack(children: [
              if (out != null) Positioned.fill(child: Padding(padding: const EdgeInsets.all(12), child: Image.memory(out!, fit: BoxFit.contain, gaplessPlayback: true))),
              const Positioned(right: 8, top: 8, child: Icon(Icons.arrow_forward, color: Colors.white54)),
              if (busy) const Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator()),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.hint, style: const TextStyle(color: kMut)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final a in const [0, 90, 180, 270])
                  ChoiceChip(
                    label: Text('$a°'),
                    selected: rot == a,
                    onSelected: (_) {
                      rot = a;
                      run();
                    },
                  ),
              ]),
              SwitchF('Отразить', flip, (v) {
                flip = v;
                run();
              }),
              SwitchF('Убрать фон (цвет от углов)', bg, (v) {
                bg = v;
                run();
              }),
              if (bg) SliderF('Допуск цвета', tol, 5, 120, (v) => setState(() => tol = v)),
              if (bg) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: run, child: const Text('Применить допуск'))),
              SwitchF('Обрезать пустые края', trim, (v) {
                trim = v;
                run();
              }),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: out == null || busy ? null : () => Navigator.pop(context, out), child: const Text('Готово')),
      ],
    );
  }
}
