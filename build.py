#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Сборка «Рубежа».

  python build.py            собрать игру: rubezh.html (+ копия в android/app/src/main/assets/www/)
  python build.py --no-resize  не уменьшать картинки из art/

Картинки из папки art/ вшиваются в игру. Имена файлов: см. art/ИМЕНА_ФАЙЛОВ.txt и art/README.txt.
Нужен только Python 3. Если установлен Pillow (pip install pillow), большие картинки сами уменьшаются.
"""
import base64, io, json, os, re, shutil, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'src')
ART = os.path.join(ROOT, 'art')
JS = ['01_core.js', '01b_data.js', '02_map.js', '03_sim.js', '03b_combat.js', '04_ai.js', '05_render.js', '05b_sprites.js', '@ARTPACK', '06b_studio.js', '06_ui.js']
NO_RESIZE = '--no-resize' in sys.argv
KINDS = ['rifle', 'lead', 'gren', 'mg', 'at', 'sniper']
EXT = ('.png', '.webp', '.jpg', '.jpeg')


def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def variants():
    txt = read(os.path.join(SRC, '01b_data.js'))
    out = []
    for m in re.finditer(r"\{ id: '([a-z0-9_]+)', cls: '([a-z]+)', side: (-?\d)", txt):
        out.append((m.group(1), m.group(2), int(m.group(3))))
    return out


def key_for(folder, name):
    n = name.lower()
    if folder == 'vehicles':
        return n if n.startswith('veh_') else 'veh_' + n
    if folder == 'soldiers':
        return n if n.startswith(('sol_', 'soldier_')) else 'sol_' + n
    if folder == 'maps':
        return 'map'
    if folder == 'icons':
        return n if n.startswith('icon_') else 'icon_' + n
    return n


def valid_keys():
    keys = set(['map'])
    for vid, cls, side in variants():
        if cls in ('tank', 'ifv'):
            keys.update(['veh_' + vid, 'veh_' + vid + '_hull', 'veh_' + vid + '_turret'])
    for cls in ('ifv', 'tank'):
        for sd in ('ua', 'ru'):
            keys.add('veh_%s_%s' % (cls, sd))
    for k in KINDS:
        for sd in ('ua', 'ru'):
            keys.add('sol_%s_%s' % (k, sd))
    keys.update(['soldier_ua', 'soldier_ru'])
    for c in ('rifle', 'mg', 'at', 'sniper', 'mortar', 'ifv', 'tank'):
        keys.add('icon_' + c)
    return keys


def encode(path, key):
    data = open(path, 'rb').read()
    mime = {'.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg'}[os.path.splitext(path)[1].lower()]
    if not NO_RESIZE:
        try:
            from PIL import Image
            im = Image.open(io.BytesIO(data))
            lim = 3000 if key == 'map' else 1024
            if max(im.size) > lim:
                k = lim / max(im.size)
                im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
                buf = io.BytesIO()
                if mime == 'image/jpeg':
                    im.convert('RGB').save(buf, 'JPEG', quality=88)
                else:
                    im.save(buf, 'PNG', optimize=True)
                    mime = 'image/png'
                data = buf.getvalue()
        except ImportError:
            pass
        except Exception as e:  # битый файл
            print('  ! не удалось уменьшить %s: %s' % (os.path.basename(path), e))
    return 'data:%s;base64,%s' % (mime, base64.b64encode(data).decode())


def pack_art():
    pack, ok, bad = {}, [], []
    valid = valid_keys()
    if os.path.isdir(ART):
        for dp, dn, fn in os.walk(ART):
            folder = os.path.relpath(dp, ART).split(os.sep)[0]
            folder = '' if folder == '.' else folder
            for f in sorted(fn):
                base, ext = os.path.splitext(f)
                if ext.lower() not in EXT or base.startswith('_'):
                    continue
                key = key_for(folder, base)
                p = os.path.join(dp, f)
                if key not in valid:
                    bad.append(os.path.relpath(p, ART))
                    continue
                meta = None
                js = os.path.join(dp, base + '.json')
                if os.path.exists(js):
                    try:
                        meta = json.loads(read(js))
                    except Exception as e:
                        print('  ! %s.json: %s' % (base, e))
                pack[key] = {'url': encode(p, key), 'meta': meta}
                ok.append((os.path.relpath(p, ART), key))
    return pack, ok, bad


def write_names():
    lines = ['ИМЕНА ФАЙЛОВ ДЛЯ ПАПКИ art  (расширение .png, .webp или .jpg)', '', 'Техника: art/vehicles/', '  <id>.png            машина целиком, башня вместе с корпусом (смотрит вправо)',
             '  <id>_hull.png       только корпус, смотрит вправо', '  <id>_turret.png     только башня, ось вращения в центре картинки, ствол вправо',
             '  Допустимые id:']
    for vid, cls, side in variants():
        if cls in ('tank', 'ifv'):
            lines.append('    %-14s %s' % (vid, {-1: 'обе стороны', 0: 'ВСУ', 1: 'ВС РФ'}[side]))
    lines += ['', '  Для любой машины класса: ifv_ua, ifv_ru, tank_ua, tank_ru', '',
              'Пехота: art/soldiers/   (вид строго сверху, взгляд и оружие вправо)',
              '  <роль>_<ua|ru>.png, роли: ' + ', '.join(KINDS), '  rifle стрелок, lead командир, gren гранатомётчик, mg пулемётчик, at противотанкист, sniper снайпер',
              '  Один спрайт на всех: soldier_ua.png, soldier_ru.png', '',
              'Карта: art/maps/map.png  (пропорции 8:5, например 2400x1500)', '',
              'Значки отрядов: art/icons/<класс>.png, классы: rifle, mg, at, sniper, mortar, ifv, tank (квадрат)', '',
              'Необязательно: рядом с картинкой файл с тем же именем и .json, например tank_t90m.json:',
              '  {"len": 31}                        длина машины в игре (по умолчанию стандартная)',
              '  {"len": 18, "ox": 1.2, "oy": 0}    для башни: размер и смещение оси от центра корпуса']
    with open(os.path.join(ART, 'ИМЕНА_ФАЙЛОВ.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


def main():
    os.makedirs(ART, exist_ok=True)
    write_names()
    pack, ok, bad = pack_art()
    artjs = 'const ART_PACK = ' + json.dumps(pack, ensure_ascii=False) + ';\n'
    body = read(os.path.join(SRC, 'body.html')) + '\n<script>\n'
    for j in JS:
        body += (artjs if j == '@ARTPACK' else read(os.path.join(SRC, j))) + '\n'
    body += '</script>\n'
    head = read(os.path.join(SRC, 'head.html'))
    vp = '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
    outs = {'rubezh.html': vp + head + body, 'publish.html': head + body}
    for n, t in outs.items():
        with open(os.path.join(ROOT, n), 'w', encoding='utf-8') as f:
            f.write(t)
    assets = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'assets', 'www')
    if os.path.isdir(os.path.join(ROOT, 'android')):
        os.makedirs(assets, exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, 'rubezh.html'), os.path.join(assets, 'index.html'))
    print('Готово: rubezh.html (%d КБ)' % (len(outs['rubezh.html'].encode()) // 1024))
    print('Картинок из art/: %d' % len(ok))
    for p, k in ok:
        print('  + %-34s -> %s' % (p, k))
    for p in bad:
        print('  ! имя не подходит: %s  (см. art/ИМЕНА_ФАЙЛОВ.txt)' % p)


if __name__ == '__main__':
    main()
