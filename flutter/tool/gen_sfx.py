"""Синтез звуков игры в WAV (22 кГц, моно). Запуск: python3 tool/gen_sfx.py assets/sfx"""
import sys, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 22050
out = sys.argv[1]
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.002, k=8.0):
    x = np.arange(n) / SR
    e = np.exp(-x * k)
    na = max(1, int(SR * a))
    e[:na] *= np.linspace(0, 1, na)
    return e


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band')
    return lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), 'low')
    return lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), 'high')
    return lfilter(b, a, x)


def tone(f0, f1, d, k=10, shape='sine'):
    tt = t(d)
    f = np.linspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) if shape == 'sine' else np.sign(np.sin(ph)) * .5
    return s * env(len(tt), .003, k)


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    fade = min(len(x), int(SR * .01))
    x[-fade:] *= np.linspace(1, 0, fade)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    with wave.open(f'{out}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())


def pad(*parts):
    return np.concatenate(parts)


def gap(d):
    return np.zeros(int(SR * d))


# интерфейс
save('tap', tone(1500, 900, .035, 60) * .8 + hp(rng.standard_normal(int(SR * .035)), 3000) * env(int(SR * .035), .001, 120) * .2, .55)
save('select', pad(tone(620, 640, .05, 30), tone(930, 960, .07, 28)), .5)
n = int(SR * .16)
squelch = bp(rng.standard_normal(n), 900, 3200) * env(n, .001, 30) * .5
save('order', pad(squelch[:int(SR * .05)], tone(1180, 1180, .09, 22, 'square') * .5), .5)
save('deny', tone(190, 160, .16, 14, 'square'), .45)
save('ready', pad(tone(880, 880, .08, 18), gap(.02), tone(1320, 1320, .14, 12)), .45)
save('radio', pad(squelch[:int(SR * .06)], tone(1000, 1000, .07, 5, 'square') * .4, gap(.04), tone(1000, 1000, .07, 5, 'square') * .4), .5)
save('capture', pad(tone(523, 523, .12, 9), tone(659, 659, .12, 9), tone(784, 784, .3, 6)), .55)
chord = lambda fs, d, k: sum(tone(f, f, d, k) for f in fs)
save('win', pad(chord([392, 494, 587], .18, 6), chord([523, 659, 784], .7, 3)), .6)
save('lose', pad(chord([392, 466, 587], .25, 5), chord([349, 415, 523], .8, 3)), .6)

# бой
for i, (lo, hi) in enumerate([(900, 2600), (1200, 3400), (700, 2000)]):
    n = int(SR * .11)
    x = bp(rng.standard_normal(n), lo, hi) * env(n, .0005, 45)
    x += lp(rng.standard_normal(n), 300) * env(n, .0005, 30) * 1.5
    save(f'shot{i + 1}', x, .8)
n = int(SR * .45)
x = lp(rng.standard_normal(n), 900) * env(n, .001, 9) + tone(70, 40, .45, 8) * .9
save('cannon', x, .9)
for i, d in enumerate([.9, 1.2]):
    n = int(SR * d)
    x = lp(rng.standard_normal(n), 260 + i * 80, 3) * env(n, .003, 4.5) * 3 + tone(55, 30, d, 5) * .8
    x += bp(rng.standard_normal(n), 1500, 5000) * env(n, .001, 40) * .25
    save(f'boom{i + 1}', x, .95)
print('ok')
