import 'dart:async';
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'game.dart';
import 'sprites.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final demo = Uri.base.queryParameters['demo'] == '1';
  FlutterError.onError = (d) => debugPrint('FLUTTER ERROR: ${d.exceptionAsString()}\n${d.stack}');
  PlatformDispatcher.instance.onError = (e, st) {
    debugPrint('ZONE ERROR: $e\n$st');
    return true;
  };
  final save = await SaveData.load(fresh: demo);
  final lvl = int.tryParse(Uri.base.queryParameters['lvl'] ?? '');
  if (demo && lvl != null) save.level = lvl;
  final sprites = Sprites.build();
  final game = RunnerGame(save, sprites, demo: demo);
  runApp(SquadSurgeApp(game));
}

const gold = Color(0xFFFFD21F);

class SquadSurgeApp extends StatelessWidget {
  final RunnerGame game;
  const SquadSurgeApp(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Squad Surge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0B14),
        body: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => game.steer(d.delta.dx * 1.15),
              child: GameWidget(game: game),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: game.screen,
            builder: (context, v, _) {
              switch (v) {
                case 'menu':
                  return MenuScreen(game);
                case 'win':
                  return WinScreen(game);
                case 'lose':
                  return LoseScreen(game);
                case 'interstitial':
                  return AdScreen(game, rewarded: false);
                case 'rewarded':
                  return AdScreen(game, rewarded: true);
                default:
                  // NOTE: a zero-size SizedBox.shrink() here stalls the Flutter web
                  // frame loop (engine quirk), so keep an expanded, click-through box.
                  return const IgnorePointer(child: SizedBox.expand());
              }
            },
          ),
        ]),
      ),
    );
  }
}

Widget bigButton(String label, VoidCallback? onTap, {Color color = const Color(0xFF2F80FF), Color fg = Colors.white, double h = 54}) {
  return SizedBox(
    width: double.infinity,
    height: h,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
        disabledBackgroundColor: Colors.white12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1),
      ),
      onPressed: onTap,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

Widget panel(List<Widget> children) => Container(
      color: const Color(0xE60B0B14),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );

/// Clearly-labelled ad placeholder button (no SDK yet).
Widget adButton(String label, VoidCallback onTap) => bigButton('▶  AD: $label', onTap, color: const Color(0xFF9B30FF), h: 50);

class MenuScreen extends StatefulWidget {
  final RunnerGame game;
  const MenuScreen(this.game, {super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  RunnerGame get g => widget.game;
  SaveData get s => g.save;

  @override
  void initState() {
    super.initState();
    if (g.demo) Timer(const Duration(milliseconds: 2500), () => g.startLevel());
  }

  void _tapHero(int i) {
    setState(() {
      if (s.unlocked.contains(i)) {
        s.selected = i;
      } else if (s.coins >= heroes[i].cost) {
        s.coins -= heroes[i].cost;
        s.unlocked.add(i);
        s.selected = i;
      }
      s.persist();
    });
  }

  @override
  Widget build(BuildContext context) {
    return panel([
      const Text('SQUAD SURGE', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: gold, letterSpacing: 2, height: 1)),
      const Text('HEROES vs THE HORDE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 3)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.circle, color: gold, size: 16),
        const SizedBox(width: 6),
        Text('${s.coins}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: gold)),
        const SizedBox(width: 20),
        Text('LEVEL ${s.level}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.45,
        children: [for (var i = 0; i < heroes.length; i++) _heroCard(i)],
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _upgrade('+1 START HERO', 'Lv ${s.startUp}', s.startUpCost, () => s.startUp++)),
        const SizedBox(width: 8),
        Expanded(child: _upgrade('+12% POWER', 'Lv ${s.powerUp}', s.powerUpCost, () => s.powerUp++)),
      ]),
      const SizedBox(height: 10),
      if (g.pendingBoost == 0)
        adButton('Start with +5 heroes', () {
          g.showAd(rewarded: true, reward: '+5 heroes at the start of your next run', done: () {
            g.pendingBoost = 5;
            g.screen.value = 'menu';
          });
        })
      else
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('+5 HERO BOOST READY!', style: TextStyle(color: Color(0xFFD08BFF), fontWeight: FontWeight.w900)),
        ),
      const SizedBox(height: 10),
      bigButton('PLAY LEVEL ${s.level}', () => g.startLevel(), color: const Color(0xFF22C55E), h: 62),
      const SizedBox(height: 10),
      const Text('Drag left/right to steer. Shoot barrels to unlock powers.\nPick the best gates. Beat the boss!',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
    ]);
  }

  Widget _heroCard(int i) {
    final h = heroes[i];
    final owned = s.unlocked.contains(i);
    final sel = s.selected == i;
    final pd = powerDefs[h.power]!;
    return GestureDetector(
      onTap: () => _tapHero(i),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1E3A8A) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? gold : Colors.white24, width: sel ? 3 : 1),
        ),
        child: Row(children: [
          Opacity(
            opacity: owned ? 1 : 0.35,
            child: RawImage(image: g.sp.heroes[i], width: 42, height: 56, filterQuality: FilterQuality.none, fit: BoxFit.contain),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              FittedBox(child: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
              Text(pd.name, style: TextStyle(color: pd.color, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                owned ? (sel ? 'SELECTED' : 'TAP TO PICK') : 'LOCKED • ${h.cost}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: owned ? Colors.white70 : gold),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _upgrade(String title, String lv, int cost, VoidCallback apply) {
    final can = s.coins >= cost;
    return GestureDetector(
      onTap: can
          ? () => setState(() {
                s.coins -= cost;
                apply();
                s.persist();
              })
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: can ? const Color(0xFF3B2F00) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: can ? gold : Colors.white24),
        ),
        child: Column(children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          Text('$lv  •  $cost coins', style: TextStyle(fontSize: 11, color: can ? gold : Colors.white54)),
        ]),
      ),
    );
  }
}

class WinScreen extends StatefulWidget {
  final RunnerGame game;
  const WinScreen(this.game, {super.key});
  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen> {
  bool doubled = false;
  RunnerGame get g => widget.game;

  void _next() => g.showAd(rewarded: false, reward: '', done: () => g.startLevel());
  void _menu() => g.showAd(rewarded: false, reward: '', done: () => g.screen.value = 'menu');

  @override
  void initState() {
    super.initState();
    if (g.demo) Timer(const Duration(milliseconds: 2500), _next);
  }

  @override
  Widget build(BuildContext context) {
    return panel([
      const SizedBox(height: 40),
      Text('LEVEL ${g.level} CLEARED!', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF5CFF8A))),
      const SizedBox(height: 8),
      Text('${bossNames[(g.level - 1) % bossNames.length]} defeated', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 16),
      Text('+${g.coinsEarned * (doubled ? 2 : 1)} coins', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: gold)),
      Text('Squad size: ${g.n} heroes', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 24),
      if (!doubled)
        adButton('Double your coins', () {
          g.showAd(rewarded: true, reward: '2x coins from this level', done: () {
            g.save.coins += g.coinsEarned;
            g.save.persist();
            g.screen.value = 'win';
          });
          doubled = true;
        }),
      const SizedBox(height: 10),
      bigButton('NEXT LEVEL ▶', _next, color: const Color(0xFF22C55E)),
      const SizedBox(height: 10),
      bigButton('UPGRADES / HEROES', _menu, color: const Color(0xFF334155)),
    ]);
  }
}

class LoseScreen extends StatefulWidget {
  final RunnerGame game;
  const LoseScreen(this.game, {super.key});
  @override
  State<LoseScreen> createState() => _LoseScreenState();
}

class _LoseScreenState extends State<LoseScreen> {
  RunnerGame get g => widget.game;
  @override
  void initState() {
    super.initState();
    if (g.demo) Timer(const Duration(milliseconds: 2000), () => g.startLevel());
  }

  @override
  Widget build(BuildContext context) {
    return panel([
      const SizedBox(height: 40),
      const Text('SQUAD WIPED OUT', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFFF4D4D))),
      const SizedBox(height: 8),
      Text('Level ${g.level} • ${(g.progress * 100).round()}% of the way', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 24),
      if (!g.revived)
        adButton('Revive with 5 heroes', () {
          g.showAd(rewarded: true, reward: 'Revive with 5 heroes', done: () => g.revive());
        }),
      const SizedBox(height: 10),
      bigButton('RETRY', () => g.startLevel(), color: const Color(0xFF22C55E)),
      const SizedBox(height: 10),
      bigButton('MENU', () => g.screen.value = 'menu', color: const Color(0xFF334155)),
    ]);
  }
}

/// PLACEHOLDER for AdMob. Interstitial = between levels, Rewarded = opt-in boosts.
class AdScreen extends StatefulWidget {
  final RunnerGame game;
  final bool rewarded;
  const AdScreen(this.game, {super.key, required this.rewarded});
  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen> {
  late int left;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    left = widget.game.demo ? 1 : (widget.rewarded ? 3 : 2);
    timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      setState(() => left--);
      if (left <= 0) {
        tm.cancel();
        if (widget.game.demo) Timer(const Duration(milliseconds: 600), widget.game.finishAd);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rewarded;
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF9B30FF), width: 3),
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1A0B2E),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('AD PLACEHOLDER', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFD08BFF))),
                const SizedBox(height: 8),
                Text(r ? 'REWARDED VIDEO AD' : 'INTERSTITIAL AD',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('(AdMob ad will show here)', style: TextStyle(color: Colors.white60)),
                if (r) ...[
                  const SizedBox(height: 12),
                  Text('Reward: ${widget.game.adReward}', textAlign: TextAlign.center, style: const TextStyle(color: gold, fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            bigButton(
              left > 0 ? 'Wait $left...' : (r ? 'CLAIM REWARD' : 'CLOSE AD ✕'),
              left > 0 ? null : widget.game.finishAd,
              color: const Color(0xFF9B30FF),
            ),
          ]),
        ),
      ),
    );
  }
}
