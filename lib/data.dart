import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

/// Superpowers that barrels unlock. All original, generic power types.
enum Power { kinetic, fire, freeze, lightning, laser }

class PowerDef {
  final String name;
  final String short;
  final Color color;
  final double dmg;
  final double interval;
  final int pierce;
  const PowerDef(this.name, this.short, this.color, this.dmg, this.interval, this.pierce);
}

const powerDefs = <Power, PowerDef>{
  Power.kinetic: PowerDef('KINETIC BOLT', 'BOLT', Color(0xFFFFFFFF), 1.0, 0.30, 0),
  Power.fire: PowerDef('FIRE BLAST', 'FIRE', Color(0xFFFF7A1A), 2.0, 0.32, 0),
  Power.freeze: PowerDef('FREEZE RAY', 'ICE', Color(0xFF6FE8FF), 1.35, 0.27, 0),
  Power.lightning: PowerDef('LIGHTNING', 'ZAP', Color(0xFFFFE53B), 1.5, 0.25, 2),
  Power.laser: PowerDef('LASER EYES', 'LASER', Color(0xFFFF3B5C), 1.1, 0.12, 1),
};

/// Original fictional heroes (no third-party IP).
class HeroDef {
  final String name;
  final String tag;
  final Power power;
  final int cost;
  final Map<String, int> palette;
  const HeroDef(this.name, this.tag, this.power, this.cost, this.palette);
}

const heroes = <HeroDef>[
  HeroDef('KID KINETIC', 'Balanced. Kinetic bolts.', Power.kinetic, 0, {
    'H': 0xFF3A2414, 'M': 0xFF1E5BFF, 'W': 0xFFFFFFFF, 'K': 0xFFF2C29B,
    'S': 0xFF1E5BFF, 'C': 0xFFE8262E, 'E': 0xFFFFD21F, 'Y': 0xFFFFD21F, 'B': 0xFFE8262E,
  }),
  HeroDef('GLACIA', 'Starts with Freeze Ray.', Power.freeze, 150, {
    'H': 0xFFEAF6FF, 'M': 0xFF7FD8FF, 'W': 0xFF0A2A44, 'K': 0xFFE7B892,
    'S': 0xFFBFEFFF, 'C': 0xFF2E7DD6, 'E': 0xFF2E7DD6, 'Y': 0xFFFFFFFF, 'B': 0xFF2E7DD6,
  }),
  HeroDef('THUNDERJACK', 'Starts with Lightning.', Power.lightning, 350, {
    'H': 0xFF111111, 'M': 0xFF222222, 'W': 0xFFFFE53B, 'K': 0xFF9C6A43,
    'S': 0xFF2A2A2A, 'C': 0xFFFFC400, 'E': 0xFFFFE53B, 'Y': 0xFFFFE53B, 'B': 0xFFFFC400,
  }),
  HeroDef('OPTIKA', 'Starts with Laser Eyes.', Power.laser, 600, {
    'H': 0xFFB0122E, 'M': 0xFF9AA3B5, 'W': 0xFFFF3B5C, 'K': 0xFFD9A07A,
    'S': 0xFFB8C0D0, 'C': 0xFF8A0F25, 'E': 0xFFFF3B5C, 'Y': 0xFF8A0F25, 'B': 0xFF8A0F25,
  }),
];

const bossNames = ['BARON BLIGHT', 'MECHA MORTIS', 'QUEEN ROTWING', 'THE GRAVELORD'];

/// Persistent progress (localStorage on web, native prefs on mobile).
class SaveData {
  int coins = 0;
  int level = 1;
  int selected = 0;
  Set<int> unlocked = {0};
  int startUp = 0;
  int powerUp = 0;
  SharedPreferences? _p;

  int get startUpCost => 40 + 40 * startUp;
  int get powerUpCost => 50 + 50 * powerUp;
  double get dmgMul => 1 + 0.12 * powerUp;

  static Future<SaveData> load({bool fresh = false}) async {
    final s = SaveData();
    try {
      final p = await SharedPreferences.getInstance();
      s._p = p;
      if (fresh) return s;
      s.coins = p.getInt('coins') ?? 0;
      s.level = p.getInt('level') ?? 1;
      s.selected = p.getInt('selected') ?? 0;
      s.unlocked = (p.getStringList('unlocked') ?? ['0']).map(int.parse).toSet();
      s.startUp = p.getInt('startUp') ?? 0;
      s.powerUp = p.getInt('powerUp') ?? 0;
    } catch (_) {}
    return s;
  }

  void persist() {
    final p = _p;
    if (p == null) return;
    p.setInt('coins', coins);
    p.setInt('level', level);
    p.setInt('selected', selected);
    p.setStringList('unlocked', unlocked.map((e) => '$e').toList());
    p.setInt('startUp', startUp);
    p.setInt('powerUp', powerUp);
  }
}
