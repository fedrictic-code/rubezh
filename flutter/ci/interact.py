"""Проверка отклика интерфейса: нажатия по координатам и снимки до/после. python interact.py <каталог> <url>"""
import sys, time
from playwright.sync_api import sync_playwright
out, base = sys.argv[1], sys.argv[2]
# экран, [(x, y)], имя
plans = [
    ('settings', [(340, 329), (340, 377)], 'i_settings'),
    ('sel', [(128, 662), (40, 755), (205, 755)], 'i_battle'),
]
with sync_playwright() as p:
    b = p.chromium.launch(args=['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'])
    for screen, clicks, name in plans:
        pg = b.new_page(viewport={'width': 412, 'height': 880}, device_scale_factor=2, has_touch=True, is_mobile=True)
        logs = []
        pg.on('console', lambda m: logs.append(m.type + ': ' + m.text))
        pg.on('pageerror', lambda e: logs.append('pageerror: ' + str(e)))
        pg.goto(f'{base}/?screen={screen}')
        time.sleep(10)
        pg.screenshot(path=f'{out}/{name}_0.png')
        for i, (x, y) in enumerate(clicks):
            pg.touchscreen.tap(x, y)
            time.sleep(1.2)
            pg.screenshot(path=f'{out}/{name}_{i + 1}.png')
        open(f'{out}/{name}.log', 'w').write('\n'.join(logs))
        pg.close()
    b.close()
