# Squad Surge: Heroes vs The Horde (prototype)

Hybrid-casual superhero runner-shooter built with Flutter + Flame. One codebase for web, Android and iOS.

- Drag left/right to steer the squad. Heroes auto-fire.
- Shoot barrels to unlock superpowers: Fire Blast, Freeze Ray, Lightning, Laser Eyes. Breaking a barrel of the power you already have levels it up.
- Pass through blue gates (+N / xN) to recruit heroes. Avoid red (-N) gates. Shooting a gate raises its number.
- Zombie horde walks at you. A boss villain waits at the end of every level.
- Coins buy heroes (Kid Kinetic, Glacia, Thunderjack, Optika) and upgrades.
- Ad placeholders (no SDK yet): interstitial between levels; rewarded ads for +5 start heroes, revive, 2x coins.

All characters and art are original and generated in code (`lib/sprites.dart`).

`?demo=1` runs an autopilot (used for automated screenshots).

Build web: `flutter build web --release --base-href /superhero-runner/`
