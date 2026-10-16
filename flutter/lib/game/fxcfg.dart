// Настройки эффектов и звуков (меняются модом). Цвета — ARGB.

class BoomFx {
  int fire, smoke;
  double size, dur;
  int sparks;
  String? sprite; // картинка взрыва (путь внутри assets/), рисуется вместо кругов
  BoomFx({this.fire = 0xFFFFBE5A, this.smoke = 0xFF463C34, this.size = 1, this.dur = 1, this.sparks = 0, this.sprite});

  Map<String, dynamic> toJson() => {'fire': fire, 'smoke': smoke, 'size': size, 'dur': dur, 'sparks': sparks, if (sprite != null) 'sprite': sprite};
  void load(Map<String, dynamic>? j) {
    if (j == null) return;
    fire = (j['fire'] as num?)?.toInt() ?? fire;
    smoke = (j['smoke'] as num?)?.toInt() ?? smoke;
    size = (j['size'] as num?)?.toDouble() ?? size;
    dur = (j['dur'] as num?)?.toDouble() ?? dur;
    sparks = (j['sparks'] as num?)?.toInt() ?? sparks;
    sprite = j['sprite'] as String? ?? sprite;
  }
}

class FxCfg {
  // трассеры стрелкового оружия
  int tracerUa = 0xF2FFEEAA, tracerRu = 0xF2FFAA82;
  double tracerWidth = 1.3, tracerLife = 1, tracerLen = .55;
  // ракеты, ПТУР, снаряды в полёте
  int missile = 0xD9FFECBE, missileSmoke = 0x66C8C8C8;
  double missileWidth = 1.6, missileTrail = .12;
  bool missileSmokeOn = true;
  // вспышка выстрела/пуска и мелкие попадания
  int flash = 0xE6FFE096;
  double flashSize = 1;
  // обычный взрыв и большой (подрыв техники)
  BoomFx boom = BoomFx();
  BoomFx big = BoomFx(sparks: 8, dur: 1);

  Map<String, dynamic> toJson() => {
        'tracerUa': tracerUa,
        'tracerRu': tracerRu,
        'tracerWidth': tracerWidth,
        'tracerLife': tracerLife,
        'tracerLen': tracerLen,
        'missile': missile,
        'missileSmoke': missileSmoke,
        'missileWidth': missileWidth,
        'missileTrail': missileTrail,
        'missileSmokeOn': missileSmokeOn,
        'flash': flash,
        'flashSize': flashSize,
        'boom': boom.toJson(),
        'big': big.toJson(),
      };

  void load(Map<String, dynamic>? j) {
    if (j == null) return;
    int i(String k, int v) => (j[k] as num?)?.toInt() ?? v;
    double d(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    tracerUa = i('tracerUa', tracerUa);
    tracerRu = i('tracerRu', tracerRu);
    tracerWidth = d('tracerWidth', tracerWidth);
    tracerLife = d('tracerLife', tracerLife);
    tracerLen = d('tracerLen', tracerLen);
    missile = i('missile', missile);
    missileSmoke = i('missileSmoke', missileSmoke);
    missileWidth = d('missileWidth', missileWidth);
    missileTrail = d('missileTrail', missileTrail);
    missileSmokeOn = (j['missileSmokeOn'] as bool?) ?? missileSmokeOn;
    flash = i('flash', flash);
    flashSize = d('flashSize', flashSize);
    boom.load(j['boom'] as Map<String, dynamic>?);
    big.load(j['big'] as Map<String, dynamic>?);
  }
}

final FxCfg FX = FxCfg();

/// Звуковые ячейки: что звучит при выстреле каждого типа оружия и при взрывах.
/// Значение — список файлов внутри assets/ (берётся случайный).
const Map<String, String> SOUND_SLOTS = {
  'shot_rifle': 'Автомат',
  'shot_mg': 'Пулемёт',
  'shot_hmg': 'Крупнокалиберный пулемёт',
  'shot_sniper': 'Снайперская винтовка',
  'shot_ugl': 'Подствольный гранатомёт',
  'shot_acan': 'Автоматическая пушка',
  'shot_cannon': 'Танковая пушка',
  'shot_rocket': 'Гранатомёт (пуск)',
  'shot_atgm': 'ПТУР (пуск)',
  'shot_mortar': 'Миномёт',
  'arty': 'Артиллерия (залп)',
  'boom': 'Взрыв',
  'boom_small': 'Попадание, малый взрыв',
  'boom_big': 'Подрыв техники',
};

Map<String, List<String>> defaultSounds() => {
      'shot_rifle': ['sfx/shot1.wav', 'sfx/shot2.wav', 'sfx/shot3.wav'],
      'shot_mg': ['sfx/shot1.wav', 'sfx/shot3.wav'],
      'shot_hmg': ['sfx/shot3.wav'],
      'shot_sniper': ['sfx/shot2.wav'],
      'shot_ugl': ['sfx/shot1.wav'],
      'shot_acan': ['sfx/shot3.wav'],
      'shot_cannon': ['sfx/cannon.wav'],
      'shot_rocket': ['sfx/cannon.wav'],
      'shot_atgm': ['sfx/cannon.wav'],
      'shot_mortar': ['sfx/cannon.wav'],
      'arty': ['sfx/cannon.wav'],
      'boom': ['sfx/boom1.wav', 'sfx/boom2.wav'],
      'boom_small': ['sfx/boom1.wav'],
      'boom_big': ['sfx/boom2.wav'],
    };

final Map<String, List<String>> SOUNDS = defaultSounds();
