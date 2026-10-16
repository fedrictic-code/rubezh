"""Снимки веб-версии редактора: python shot.py <каталог> <url> <имя:запрос,имя:запрос,...>"""
import sys, time
from playwright.sync_api import sync_playwright
out, base, screens = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
with sync_playwright() as p:
    b = p.chromium.launch(args=['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'])
    for s in screens:
        name, q = s.split(':', 1)
        pg = b.new_page(viewport={'width': 1440, 'height': 900}, device_scale_factor=1)
        logs = []
        pg.on('console', lambda m: logs.append(m.type + ': ' + m.text))
        pg.on('pageerror', lambda e: logs.append('pageerror: ' + str(e)))
        pg.goto(f'{base}/?{q}')
        time.sleep(12)
        pg.screenshot(path=f'{out}/{name}.png')
        open(f'{out}/{name}.log', 'w').write('\n'.join(logs))
        pg.close()
    b.close()
