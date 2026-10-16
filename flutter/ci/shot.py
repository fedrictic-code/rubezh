"""Снимает скриншоты веб-версии для проверки интерфейса: python shot.py <каталог> <url> <экран,экран,...>"""
import sys, time
from playwright.sync_api import sync_playwright
out, base, screens = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
with sync_playwright() as p:
    b = p.chromium.launch(args=['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'])
    for s in screens:
        pg = b.new_page(viewport={'width': 412, 'height': 880}, device_scale_factor=2)
        logs = []
        pg.on('console', lambda m: logs.append(m.type + ': ' + m.text))
        pg.on('pageerror', lambda e: logs.append('pageerror: ' + str(e)))
        pg.goto(f'{base}/?screen={s}')
        time.sleep(9)
        pg.screenshot(path=f'{out}/{s}.png')
        open(f'{out}/{s}.log', 'w').write('\n'.join(logs))
        pg.close()
    b.close()
