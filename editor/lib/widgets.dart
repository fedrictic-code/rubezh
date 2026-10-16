// Поля форм редактора.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kAmber = Color(0xFFE3B341);
const kUa = Color(0xFF3D8FE0);
const kRu = Color(0xFFD4483F);
const kPanel = Color(0xFF161B20);
const kLine = Color(0x22FFFFFF);
const kMut = Color(0xFF8E9AA4);

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const Section(this.title, this.children, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: kMut))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

/// Ряд полей одинаковой ширины.
class Fields extends StatelessWidget {
  final List<Widget> children;
  const Fields(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: children[i])],
        ]),
      );
}

InputDecoration _dec(String label, {String? hint, String? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      isDense: true,
      border: const OutlineInputBorder(),
    );

class TextF extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int lines;
  final String? hint;
  const TextF(this.label, this.value, this.onChanged, {super.key, this.enabled = true, this.lines = 1, this.hint});
  @override
  State<TextF> createState() => _TextFState();
}

class _TextFState extends State<TextF> {
  late final TextEditingController c = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant TextF o) {
    super.didUpdateWidget(o);
    if (widget.value != c.text && !FocusScope.of(context).hasFocus) c.text = widget.value;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        enabled: widget.enabled,
        maxLines: widget.lines,
        decoration: _dec(widget.label, hint: widget.hint),
        onChanged: widget.onChanged,
      );
}

class NumF extends StatefulWidget {
  final String label;
  final num value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final bool integer;
  const NumF(this.label, this.value, this.onChanged, {super.key, this.suffix, this.integer = false});
  @override
  State<NumF> createState() => _NumFState();
}

String fmtNum(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(v.abs() < 1 ? 3 : 2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

class _NumFState extends State<NumF> {
  late final TextEditingController c = TextEditingController(text: fmtNum(widget.value));
  bool bad = false;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
        decoration: _dec(widget.label, suffix: widget.suffix).copyWith(errorText: bad ? 'Число' : null),
        onChanged: (s) {
          final v = double.tryParse(s.replaceAll(',', '.'));
          setState(() => bad = v == null);
          if (v != null) widget.onChanged(widget.integer ? v.roundToDouble() : v);
        },
      );
}

class DropF<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const DropF(this.label, this.value, this.items, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) {
    final has = items.any((e) => e.$1 == value);
    return InputDecorator(
      decoration: _dec(label).copyWith(contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isDense: true,
          isExpanded: true,
          value: has ? value : null,
          items: [for (final e in items) DropdownMenuItem(value: e.$1, child: Text(e.$2, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class SwitchF extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SwitchF(this.label, this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Switch(value: value, onChanged: onChanged),
            const SizedBox(width: 6),
            Flexible(child: Text(label)),
          ]),
        ),
      );
}

/// Ползунок с подписью и значением.
class SliderF extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  const SliderF(this.label, this.value, this.min, this.max, this.onChanged, {super.key, this.divisions});
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 170, child: Text(label)),
        Expanded(child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged)),
        SizedBox(width: 56, child: Text(fmtNum(double.parse(value.toStringAsFixed(2))), textAlign: TextAlign.right)),
      ]);
}

/// Выбор цвета: образцы + поле ARGB.
class ColorF extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const ColorF(this.label, this.value, this.onChanged, {super.key});
  static const _sw = [
    0xFFFFEEAA, 0xFFFFAA82, 0xFFFFE096, 0xFFFFBE5A, 0xFFFF7A3A, 0xFFFF4A2A, 0xFFFFFFFF, 0xFFC8C8C8, //
    0xFF8A8A8A, 0xFF463C34, 0xFF2A2420, 0xFF7AD7FF, 0xFF9EE09A, 0xFFE3B341,
  ];
  @override
  Widget build(BuildContext context) {
    final a = (value >> 24) & 255;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 170, child: Text(label)),
        Container(width: 28, height: 28, decoration: BoxDecoration(color: Color(value), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white38))),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(spacing: 4, runSpacing: 4, children: [
            for (final s in _sw)
              InkWell(
                onTap: () => onChanged((a << 24) | (s & 0xFFFFFF)),
                child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Color(s), borderRadius: BorderRadius.circular(4), border: Border.all(color: (s & 0xFFFFFF) == (value & 0xFFFFFF) ? kAmber : Colors.white24, width: 1.5))),
              ),
          ]),
        ),
        SizedBox(
          width: 120,
          child: Slider(
            value: a / 255,
            onChanged: (v) => onChanged(((v * 255).round() << 24) | (value & 0xFFFFFF)),
          ),
        ),
      ]),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String text, {String ok = 'Да'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> ask(BuildContext context, String title, String label, {String init = ''}) async {
  final c = TextEditingController(text: init);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 360, child: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Готово')),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}
