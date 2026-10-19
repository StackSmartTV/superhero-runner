import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'sprites.dart';

enum Phase { menu, playing, won, lost }

class Bullet {
  double x, y, dmg;
  int pierce;
  final Power power;
  final Set<Object> hit = {};
  Bullet(this.x, this.y, this.dmg, this.pierce, this.power);
}

class Enemy {
  double x, y, hp, maxHp, slow = 0, flash = 0;
  final bool boss;
  Enemy(this.x, this.y, this.hp, {this.boss = false}) : maxHp = hp;
}

class Barrel {
  double x, y, hp, maxHp, flash = 0;
  final Power power;
  Barrel(this.x, this.y, this.hp, this.power) : maxHp = hp;
}

class GateOp {
  final bool mul;
  int value;
  int hits = 0;
  GateOp.add(this.value) : mul = false;
  GateOp.mul(this.value) : mul = true;
  String get label => mul ? 'x$value' : (value >= 0 ? '+$value' : '$value');
  bool get good => mul || value > 0;
  int apply(int n) => mul ? n * value : n + value;
}

class Gate {
  double y;
  final GateOp left, right;
  bool done = false;
  Gate(this.y, this.left, this.right);
}

class Orb {
  double x, y, vx, vy;
  Orb(this.x, this.y, this.vx, this.vy);
}

class Particle {
  double x, y, vx, vy, life, size;
  final Color color;
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.color, this.size);
}

class Floater {
  double x, y, life;
  final String text;
  final Color color;
  Floater(this.x, this.y, this.text, this.color) : life = 1.0;
}

class RunnerGame extends FlameGame {
  final SaveData save;
  final Sprites sp;
  final bool demo;
  final ValueNotifier<String> screen = ValueNotifier('menu');
  VoidCallback? adDone;
  String adReward = '';

  RunnerGame(this.save, this.sp, {this.demo = false});

  static const double W = 360;
  double s = 1, ox = 0, H = 640;
  double get heroY => H - 150;

  Phase phase = Phase.menu;
  int level = 1;
  double traveled = 0, length = 2400, speed = 72, bgScroll = 0, t = 0;
  double sx = W / 2;
  int n = 1;
  Power power = Power.kinetic;
  int powerLv = 1;
  double fireT = 0;
  Random rng = Random(1);
  List<String> events = [];
  List<double> eventD = [];
  int evIdx = 0;
  final bullets = <Bullet>[];
  final enemies = <Enemy>[];
  final barrels = <Barrel>[];
  final gates = <Gate>[];
  final orbs = <Orb>[];
  final particles = <Particle>[];
  final floaters = <Floater>[];
  Enemy? boss;
  bool bossSpawned = false;
  double bossFireT = 2, bossSummonT = 5;
  int coinsEarned = 0;
  bool revived = false;
  int pendingBoost = 0;
  String toast = '';
  double toastT = 0, hurtFlash = 0;

  HeroDef get hero => heroes[save.selected];
  PowerDef get pdef => powerDefs[power]!;

  @override
  Color backgroundColor() => const Color(0xFF0B0B14);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    s = min(size.x / W, size.y / 560);
    ox = (size.x - W * s) / 2;
    H = size.y / s;
  }

  void steer(double dx) {
    if (phase != Phase.playing) return;
    sx = (sx + dx / s).clamp(24, W - 24);
  }

  // ---------------------------------------------------------------- flow
  void startLevel() {
    level = save.level;
    rng = Random(level * 7919 + 13);
    traveled = 0;
    length = 1900 + 200.0 * min(level, 6);
    bullets.clear();
    enemies.clear();
    barrels.clear();
    gates.clear();
    orbs.clear();
    particles.clear();
    floaters.clear();
    boss = null;
    bossSpawned = false;
    bossFireT = 2.2;
    bossSummonT = 5;
    coinsEarned = 0;
    revived = false;
    sx = W / 2;
    n = 1 + save.startUp + pendingBoost;
    pendingBoost = 0;
    power = hero.power;
    powerLv = 1;
    fireT = 0.3;
    const pattern = ['barrel', 'gate', 'wave', 'barrel', 'gate', 'wave', 'wave', 'gate', 'barrel', 'wave', 'gate', 'wave'];
    events = [];
    eventD = [];
    evIdx = 0;
    var d = 110.0;
    var i = 0;
    while (d < length) {
      final ty = pattern[i % pattern.length];
      events.add(ty);
      eventD.add(d);
      d += ty == 'wave' ? 150 : 185;
      i++;
    }
    showToast('LEVEL $level  -  GO!');
    phase = Phase.playing;
    screen.value = 'play';
  }

  void showToast(String s) {
    toast = s;
    toastT = 1.8;
  }

  void showAd({required bool rewarded, required String reward, required VoidCallback done}) {
    adReward = reward;
    adDone = done;
    screen.value = rewarded ? 'rewarded' : 'interstitial';
  }

  void finishAd() {
    final d = adDone;
    adDone = null;
    d?.call();
  }

  void revive() {
    revived = true;
    n = 5;
    orbs.clear();
    enemies.removeWhere((e) => !e.boss && e.y > heroY - 160);
    phase = Phase.playing;
    screen.value = 'play';
    showToast('REVIVED! +5 HEROES');
  }

  void _win() {
    phase = Phase.won;
    final bonus = 20 + 10 * level;
    coinsEarned += bonus;
    save.coins += coinsEarned;
    save.level = level + 1;
    save.persist();
    screen.value = 'win';
  }

  void _lose() {
    phase = Phase.lost;
    save.coins += coinsEarned;
    coinsEarned = 0;
    save.persist();
    screen.value = 'lose';
  }

  double get progress => bossSpawned ? 1 : (traveled / length).clamp(0, 1);

  // ---------------------------------------------------------------- spawn
  void _spawn(String ty) {
    final idx = evIdx;
    if (ty == 'barrel') {
      final x = (level == 1 && idx == 0) ? W / 2 : 60 + rng.nextDouble() * 240;
      final hp = (idx == 0 ? 6 + level * 2 : 8 + level * 5 + idx * 2.2).roundToDouble();
      const opts = [Power.fire, Power.freeze, Power.lightning, Power.laser];
      var p = opts[rng.nextInt(4)];
      if (level == 1 && idx == 0) p = Power.fire;
      barrels.add(Barrel(x, -30, hp, p));
    } else if (ty == 'gate') {
      final GateOp good = idx <= 2
          ? GateOp.add(3 + level)
          : (rng.nextDouble() < 0.25 ? GateOp.mul(2) : GateOp.add(2 + rng.nextInt(3 + level)));
      // the first gate of every level is always friendly so the squad can grow
      final GateOp other = (idx > 2 && rng.nextDouble() < 0.55)
          ? GateOp.add(-(1 + rng.nextInt(2 + level)))
          : GateOp.add(1 + rng.nextInt(3));
      if (rng.nextBool()) {
        gates.add(Gate(-40, good, other));
      } else {
        gates.add(Gate(-40, other, good));
      }
    } else {
      final count = idx < 4 ? 2 + min(level, 2) : 2 + min(level, 4) + rng.nextInt(3) + idx ~/ 4;
      final hp = 2 + level * 0.9 + idx * 0.3;
      for (var k = 0; k < count; k++) {
        enemies.add(Enemy(30 + rng.nextDouble() * (W - 60), -20.0 - k * 22, hp));
      }
    }
  }

  void _spawnBoss() {
    bossSpawned = true;
    final hp = 240.0 * (1 + 0.6 * (level - 1));
    boss = Enemy(W / 2, -70, hp, boss: true);
    enemies.add(boss!);
    showToast('BOSS: ${bossNames[(level - 1) % bossNames.length]}!');
  }

  // ---------------------------------------------------------------- formation
  List<Offset> formation(int count) {
    final out = <Offset>[];
    final vis = min(count, 12);
    for (var i = 0; i < vis; i++) {
      final row = i ~/ 4;
      final inRow = min(4, vis - row * 4);
      final col = i % 4;
      out.add(Offset(sx + (col - (inRow - 1) / 2) * 22, heroY + row * 20));
    }
    return out;
  }

  double get halfW => min(n, 4) * 11.0;

  void _burst(double x, double y, Color c, int k, [double spd = 120]) {
    for (var i = 0; i < k; i++) {
      final a = rng.nextDouble() * pi * 2;
      final v = spd * (0.3 + rng.nextDouble());
      particles.add(Particle(x, y, cos(a) * v, sin(a) * v, 0.4 + rng.nextDouble() * 0.4, c, 2 + rng.nextDouble() * 3));
    }
  }

  void _loseHeroes(int k, double x, double y) {
    n -= k;
    hurtFlash = 0.25;
    floaters.add(Floater(x, y - 20, '-$k', const Color(0xFFFF4D4D)));
    _burst(x, y, hero.palette['S'] != null ? Color(hero.palette['S']!) : Colors.white, 10);
    if (n <= 0) {
      n = 0;
      _lose();
    }
  }

  // ---------------------------------------------------------------- update
  int _errs = 0;
  @override
  void update(double dt) {
    try {
      _update(dt);
    } catch (e, st) {
      if (_errs++ < 3) debugPrint('update error: $e\n$st');
    }
  }

  void _update(double dt) {
    super.update(dt);
    dt = min(dt, 0.05);
    t += dt;
    bgScroll += (phase == Phase.playing ? speed : 25) * dt;
    if (toastT > 0) toastT -= dt;
    if (hurtFlash > 0) hurtFlash -= dt;
    _updateParticles(dt);
    if (phase != Phase.playing) return;
    if (demo) _autopilot(dt);

    traveled += speed * dt;
    while (evIdx < events.length && traveled >= eventD[evIdx]) {
      _spawn(events[evIdx]);
      evIdx++;
    }
    if (!bossSpawned && evIdx >= events.length && traveled >= length) _spawnBoss();

    // firing
    fireT -= dt;
    if (fireT <= 0) {
      fireT += pdef.interval;
      if (fireT < 0) fireT = pdef.interval;
      final shooters = formation(n).take(min(n, 5)).toList();
      final dmg = pdef.dmg * (1 + 0.35 * (powerLv - 1)) * save.dmgMul * n / shooters.length;
      for (final p in shooters) {
        bullets.add(Bullet(p.dx, p.dy - 16, dmg, pdef.pierce + (powerLv >= 3 ? 1 : 0), power));
      }
    }

    // move world objects
    for (final b in barrels) {
      b.y += speed * dt;
      if (b.flash > 0) b.flash -= dt;
    }
    barrels.removeWhere((b) => b.y > H + 40);
    for (final g in gates) {
      g.y += speed * dt;
      if (!g.done && g.y >= heroY - 6) {
        g.done = true;
        final op = sx < W / 2 ? g.left : g.right;
        final before = n;
        n = op.apply(n).clamp(0, 99);
        final gx = sx < W / 2 ? W / 4 : W * 3 / 4;
        floaters.add(Floater(sx, heroY - 40, op.label, op.good ? const Color(0xFF5CFF8A) : const Color(0xFFFF4D4D)));
        _burst(gx, g.y, op.good ? const Color(0xFF4DA3FF) : const Color(0xFFFF4D4D), 18, 160);
        if (n > before) showToast('SQUAD ${op.label}!  ($n HEROES)');
        if (n <= 0) {
          _lose();
          return;
        }
      }
    }
    gates.removeWhere((g) => g.y > H + 60);

    for (final e in enemies) {
      if (e.flash > 0) e.flash -= dt;
      if (e.slow > 0) e.slow -= dt;
      final slowF = e.slow > 0 ? 0.4 : 1.0;
      if (e.boss) {
        if (e.y < 150) {
          e.y += 45 * dt;
        } else {
          e.x = W / 2 + sin(t * 0.9) * 90;
        }
      } else {
        e.y += (speed * 0.75 + 30 * slowF) * dt;
        final d = sx - e.x;
        e.x += d.sign * min(20 * slowF * dt, d.abs());
      }
    }
    // boss attacks
    final bo = boss;
    if (bo != null && bo.hp > 0 && bo.y >= 150) {
      final slowF = bo.slow > 0 ? 0.5 : 1.0;
      bossFireT -= dt * slowF;
      bossSummonT -= dt * slowF;
      if (bossFireT <= 0) {
        bossFireT = max(0.9, 1.9 - level * 0.12);
        final dx = sx - bo.x, dy = heroY - (bo.y + 30);
        final l = sqrt(dx * dx + dy * dy);
        final sp = 170.0 + level * 8;
        orbs.add(Orb(bo.x, bo.y + 30, dx / l * sp, dy / l * sp));
      }
      if (bossSummonT <= 0) {
        bossSummonT = 6;
        for (var k = 0; k < 2 + level ~/ 2; k++) {
          enemies.add(Enemy(bo.x - 40 + rng.nextDouble() * 80, bo.y + 30, 2 + level * 1.5));
        }
      }
    }
    // enemy contact
    for (final e in enemies) {
      if (e.boss || e.hp <= 0) continue;
      if (e.y >= heroY - 12 && e.y <= heroY + 40 && (e.x - sx).abs() < halfW + 12) {
        e.hp = 0;
        _burst(e.x, e.y, const Color(0xFF6FBF3A), 8);
        _loseHeroes(1, e.x, e.y);
        if (phase != Phase.playing) return;
      }
    }
    enemies.removeWhere((e) => e.hp <= 0 || e.y > H + 40);

    // orbs
    for (final o in orbs) {
      o.x += o.vx * dt;
      o.y += o.vy * dt;
    }
    for (final o in orbs) {
      if (o.y >= heroY - 14 && o.y <= heroY + 30 && (o.x - sx).abs() < halfW + 8) {
        final hx = o.x;
        o.y = H + 100;
        _loseHeroes(n >= 6 ? 2 : 1, hx, heroY);
        if (phase != Phase.playing) return;
      }
    }
    orbs.removeWhere((o) => o.y > H + 20 || o.x < -20 || o.x > W + 20);

    _updateBullets(dt);
    if (bo != null && bo.hp <= 0 && phase == Phase.playing) {
      _burst(bo.x, bo.y, const Color(0xFFFFE53B), 60, 260);
      _burst(bo.x, bo.y, const Color(0xFFFF7A1A), 40, 200);
      coinsEarned += 20;
      boss = null;
      orbs.clear();
      for (final e in enemies) {
        _burst(e.x, e.y, const Color(0xFF6FBF3A), 6);
      }
      enemies.clear();
      showToast('BOSS DEFEATED!');
      _win();
    }
  }

  void _updateBullets(double dt) {
    final pd = pdef;
    for (final b in bullets) {
      b.y -= 540 * dt;
      if (b.y < -20) {
        b.pierce = -1;
        continue;
      }
      // gates soak bullets and grow value
      for (final g in gates) {
        if (g.done) continue;
        if (b.y < g.y + 22 && b.y > g.y - 22) {
          final op = b.x < W / 2 ? g.left : g.right;
          if (!op.mul) {
            op.hits++;
            if (op.hits % 6 == 0 && op.value < 9) {
              op.value++;
              if (op.value == 0) op.value = 1;
            }
          }
          b.pierce = -1;
          break;
        }
      }
      if (b.pierce < 0) continue;
      for (final br in barrels) {
        if (br.hp <= 0) continue;
        if ((b.x - br.x).abs() < 16 && (b.y - br.y).abs() < 18) {
          br.hp -= b.dmg;
          br.flash = 0.06;
          b.pierce = -1;
          if (br.hp <= 0) {
            final def = powerDefs[br.power]!;
            if (power == br.power) {
              powerLv = min(5, powerLv + 1);
              showToast('${def.name} LV$powerLv!');
            } else {
              power = br.power;
              showToast('${def.name} UNLOCKED!');
            }
            coinsEarned += 3;
            _burst(br.x, br.y, def.color, 30, 200);
            floaters.add(Floater(br.x, br.y, def.name, def.color));
          }
          break;
        }
      }
      if (b.pierce < 0) continue;
      for (final e in enemies) {
        if (e.hp <= 0 || b.hit.contains(e)) continue;
        final r = e.boss ? 40.0 : 13.0;
        final dx = b.x - e.x, dy = b.y - e.y;
        if (dx * dx + dy * dy < r * r) {
          b.hit.add(e);
          e.hp -= b.dmg;
          e.flash = 0.05;
          if (b.power == Power.freeze) e.slow = e.boss ? 1.0 : 2.0;
          if (b.power == Power.fire) {
            for (final o in enemies) {
              if (o == e || o.hp <= 0) continue;
              final ddx = o.x - e.x, ddy = o.y - e.y;
              if (ddx * ddx + ddy * ddy < 34 * 34) o.hp -= b.dmg * 0.5;
            }
            _burst(b.x, b.y, pd.color, 3, 60);
          }
          if (b.power == Power.lightning) _burst(b.x, b.y, pd.color, 2, 90);
          b.pierce--;
          if (b.pierce < 0) break;
        }
      }
    }
    // resolve deaths from bullets
    for (final e in enemies) {
      if (!e.boss && e.hp <= 0 && e.maxHp > 0) {
        e.maxHp = -1;
        coinsEarned += 1;
        _burst(e.x, e.y, const Color(0xFF6FBF3A), 10);
      }
    }
    enemies.removeWhere((e) => !e.boss && e.hp <= 0);
    barrels.removeWhere((b) => b.hp <= 0);
    bullets.removeWhere((b) => b.pierce < 0);
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.94;
      p.vy *= 0.94;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
    if (particles.length > 400) particles.removeRange(0, particles.length - 400);
    for (final f in floaters) {
      f.y -= 40 * dt;
      f.life -= dt * 0.8;
    }
    floaters.removeWhere((f) => f.life <= 0);
  }

  int _gateVal(GateOp op) => op.apply(n);

  void _autopilot(double dt) {
    double? tx;
    Gate? g;
    for (final c in gates) {
      if (!c.done && c.y < heroY && c.y > heroY - 320 && (g == null || c.y > g.y)) g = c;
    }
    if (g != null) {
      tx = _gateVal(g.left) >= _gateVal(g.right) ? W / 4 : W * 3 / 4;
    } else {
      Barrel? b;
      for (final c in barrels) {
        if (c.y < heroY - 60 && (b == null || c.y > b.y)) b = c;
      }
      if (b != null) {
        tx = b.x;
      } else if (boss != null) {
        tx = boss!.x;
      } else {
        Enemy? e;
        for (final c in enemies) {
          if (c.y < heroY - 30 && (e == null || c.y > e.y)) e = c;
        }
        if (e != null) tx = e.x;
      }
    }
    if (tx != null) {
      final d = tx - sx;
      sx = (sx + d.sign * min(240 * dt, d.abs())).clamp(24, W - 24);
    }
  }

  // ---------------------------------------------------------------- render
  final Map<String, TextPainter> _tp = {};
  final Paint _pix = Paint()..filterQuality = FilterQuality.none;

  void _text(Canvas c, String str, double x, double y, double size, Color col, {bool left = false}) {
    final key = '$str|$size|${col.toARGB32()}';
    var tp = _tp[key];
    if (tp == null) {
      if (_tp.length > 400) _tp.clear();
      tp = TextPainter(
        text: TextSpan(
          text: str,
          style: TextStyle(
            fontSize: size,
            color: col,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: const [Shadow(offset: Offset(1.5, 1.5), color: Color(0xDD000000))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _tp[key] = tp;
    }
    tp.paint(c, Offset(left ? x : x - tp.width / 2, y - tp.height / 2));
  }

  void _sprite(Canvas c, ui.Image img, double cx, double cy, double scale, {Paint? paint}) {
    final w = img.width * scale, h = img.height * scale;
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h), paint ?? _pix);
  }

  @override
  void render(Canvas canvas) {
    try {
      _render(canvas);
    } catch (e, st) {
      if (_errs++ < 3) debugPrint('render error: $e\n$st');
    }
  }

  void _render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(ox, 0);
    canvas.scale(s);
    canvas.clipRect(Rect.fromLTWH(0, 0, W, H));
    _drawBg(canvas);
    if (phase != Phase.menu) _drawWorld(canvas);
    canvas.restore();
  }

  void _drawBg(Canvas c) {
    c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFF2B2D42));
    final side = Paint()..color = const Color(0xFF4A4E69);
    c.drawRect(Rect.fromLTWH(0, 0, 18, H), side);
    c.drawRect(Rect.fromLTWH(W - 18, 0, 18, H), side);
    final curb = Paint()..color = const Color(0xFFF2E9E4);
    final dash = Paint()..color = const Color(0x55F2E9E4);
    final off = bgScroll % 60;
    for (double y = -60 + off; y < H; y += 60) {
      c.drawRect(Rect.fromLTWH(W / 2 - 2, y, 4, 30), dash);
      c.drawRect(Rect.fromLTWH(16, y, 3, 30), curb);
      c.drawRect(Rect.fromLTWH(W - 19, y + 30, 3, 30), curb);
    }
    final speck = Paint()..color = const Color(0xFF353852);
    final off2 = bgScroll % 120;
    for (double y = -120 + off2; y < H; y += 120) {
      c.drawRect(Rect.fromLTWH(70, y + 20, 6, 6), speck);
      c.drawRect(Rect.fromLTWH(250, y + 80, 8, 4), speck);
      c.drawRect(Rect.fromLTWH(140, y + 55, 4, 4), speck);
      c.drawRect(Rect.fromLTWH(300, y + 10, 5, 5), speck);
    }
  }

  void _drawWorld(Canvas c) {
    // gates
    for (final g in gates) {
      if (g.done && g.y > heroY + 30) continue;
      for (var side = 0; side < 2; side++) {
        final op = side == 0 ? g.left : g.right;
        final r = Rect.fromLTWH(side == 0 ? 22 : W / 2 + 4, g.y - 22, W / 2 - 26, 44);
        final col = op.good ? const Color(0xFF2F80FF) : const Color(0xFFE63946);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = col.withValues(alpha: 0.45));
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
            Paint()
              ..color = col
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        _text(c, op.label, r.center.dx, r.center.dy, 22, Colors.white);
      }
    }
    // barrels
    for (final b in barrels) {
      _sprite(c, sp.barrels[b.power]!, b.x, b.y, 2.8);
      if (b.flash > 0) {
        c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: 28, height: 34), Paint()..color = const Color(0x66FFFFFF));
      }
      final def = powerDefs[b.power]!;
      _text(c, '${b.hp.ceil()}', b.x, b.y + 2, 15, Colors.white);
      _text(c, def.short, b.x, b.y - 26, 11, def.color);
    }
    // enemies
    for (final e in enemies) {
      if (e.boss) {
        final img = sp.bosses[(level - 1) % sp.bosses.length];
        _sprite(c, img, e.x, e.y, 5.5);
        if (e.slow > 0) {
          c.drawCircle(Offset(e.x, e.y), 44, Paint()..color = const Color(0x446FE8FF));
        }
        if (e.flash > 0) c.drawCircle(Offset(e.x, e.y), 40, Paint()..color = const Color(0x33FFFFFF));
      } else {
        final bob = sin(t * 10 + e.x) * 1.5;
        _sprite(c, e.slow > 0 ? sp.zombieFrozen : sp.zombie, e.x, e.y + bob, 2.1);
        if (e.flash > 0) c.drawCircle(Offset(e.x, e.y), 12, Paint()..color = const Color(0x55FFFFFF));
      }
    }
    // orbs
    for (final o in orbs) {
      c.drawCircle(Offset(o.x, o.y), 11, Paint()..color = const Color(0x55B04DFF));
      c.drawCircle(Offset(o.x, o.y), 6, Paint()..color = const Color(0xFFD08BFF));
    }
    // bullets
    for (final b in bullets) {
      final col = powerDefs[b.power]!.color;
      switch (b.power) {
        case Power.laser:
          c.drawRect(Rect.fromCenter(center: Offset(b.x, b.y), width: 3, height: 16), Paint()..color = col);
        case Power.lightning:
          final p = Path()
            ..moveTo(b.x, b.y - 8)
            ..lineTo(b.x + 3, b.y - 2)
            ..lineTo(b.x - 3, b.y + 2)
            ..lineTo(b.x, b.y + 8);
          c.drawPath(p, Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
        case Power.fire:
          c.drawCircle(Offset(b.x, b.y), 5.5, Paint()..color = col);
          c.drawCircle(Offset(b.x, b.y), 2.5, Paint()..color = const Color(0xFFFFE9A0));
        case Power.freeze:
          final p = Path()
            ..moveTo(b.x, b.y - 6)
            ..lineTo(b.x + 4, b.y)
            ..lineTo(b.x, b.y + 6)
            ..lineTo(b.x - 4, b.y)
            ..close();
          c.drawPath(p, Paint()..color = col);
        case Power.kinetic:
          c.drawCircle(Offset(b.x, b.y), 3.5, Paint()..color = col);
      }
    }
    // squad
    if (n > 0) {
      final pos = formation(n);
      final img = sp.heroes[save.selected];
      final glow = Paint()..color = pdef.color.withValues(alpha: 0.18);
      c.drawOval(Rect.fromCenter(center: Offset(sx, heroY + 10 + (pos.length > 4 ? 20 : 0)), width: halfW * 2 + 30, height: 30 + (pos.length > 4 ? 40 : 0)), glow);
      for (var i = pos.length - 1; i >= 0; i--) {
        final p = pos[i];
        _sprite(c, img, p.dx, p.dy + sin(t * 14 + i) * 1.2, 1.8);
      }
      // squad counter bubble
      final by = heroY - 34;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx, by), width: 40, height: 20), const Radius.circular(10)),
          Paint()..color = const Color(0xDD1E5BFF));
      _text(c, '$n', sx, by, 14, Colors.white);
    }
    // particles & floaters
    for (final p in particles) {
      c.drawRect(Rect.fromCenter(center: Offset(p.x, p.y), width: p.size, height: p.size),
          Paint()..color = p.color.withValues(alpha: (p.life * 2).clamp(0, 1)));
    }
    for (final f in floaters) {
      _text(c, f.text, f.x, f.y, 18, f.color.withValues(alpha: f.life.clamp(0, 1)));
    }
    if (hurtFlash > 0) {
      c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Color.fromARGB((hurtFlash * 300).clamp(0, 90).toInt(), 255, 0, 0));
    }
    _drawHud(c);
  }

  void _drawHud(Canvas c) {
    final top = 40.0; // leave room for iPhone notch / status bar
    c.drawRect(Rect.fromLTWH(0, 0, W, top + 46), Paint()..color = const Color(0x99000000));
    _text(c, 'LV $level', 14, top + 10, 16, Colors.white, left: true);
    // progress bar
    final bar = Rect.fromLTWH(84, top + 4, 170, 12);
    c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(6)), Paint()..color = const Color(0xFF444444));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, bar.width * progress, bar.height), const Radius.circular(6)),
        Paint()..color = const Color(0xFF5CFF8A));
    _text(c, 'BOSS', bar.right - 2, top + 24, 9, const Color(0xFFFF7A7A));
    c.drawCircle(Offset(W - 70, top + 10), 7, Paint()..color = const Color(0xFFFFD21F));
    _text(c, '${save.coins + coinsEarned}', W - 58, top + 10, 15, const Color(0xFFFFD21F), left: true);
    // power chip
    c.drawCircle(Offset(20, top + 34), 6, Paint()..color = pdef.color);
    _text(c, '${pdef.name}  LV$powerLv', 32, top + 34, 12, pdef.color, left: true);
    _text(c, hero.name, W - 14 - hero.name.length * 7.2, top + 34, 11, Colors.white70, left: true);
    // boss bar
    final bo = boss;
    if (bo != null) {
      final r = Rect.fromLTWH(30, top + 54, W - 60, 12);
      c.drawRect(r, Paint()..color = const Color(0xFF331111));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width * (bo.hp / bo.maxHp).clamp(0, 1), r.height), Paint()..color = const Color(0xFFE63946));
      _text(c, bossNames[(level - 1) % bossNames.length], W / 2, top + 76, 13, const Color(0xFFFFB3B3));
    }
    if (toastT > 0) {
      final a = toastT.clamp(0, 1).toDouble();
      _text(c, toast, W / 2, H * 0.36, 22, Colors.white.withValues(alpha: a));
    }
    if (demo) _text(c, 'DEMO AUTOPILOT', W / 2, H - 14, 10, Colors.white38);
  }
}
