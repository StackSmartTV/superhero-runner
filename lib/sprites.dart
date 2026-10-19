import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'data.dart';

/// All art is generated in code from tiny pixel maps: legally clean, no assets.
ui.Image pixelImage(List<String> rows, Map<String, int> pal) {
  final h = rows.length;
  var w = 0;
  for (final r in rows) {
    if (r.length > w) w = r.length;
  }
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final p = Paint();
  for (var y = 0; y < h; y++) {
    final r = rows[y];
    for (var x = 0; x < r.length; x++) {
      final col = pal[r[x]];
      if (col == null) continue;
      p.color = Color(col);
      c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), p);
    }
  }
  return rec.endRecording().toImageSync(w, h);
}

const heroRows = [
  '....HHHH....',
  '...HHHHHH...',
  '...MMMMMM...',
  '...MWMMWM...',
  '...KKKKKK...',
  '....KKKK....',
  '.CSSSSSSSSC.',
  'CSSSSEESSSSC',
  'CSKSSEESSKSC',
  'CSKSSSSSSKSC',
  'C.KYYYYYYK.C',
  'C..SSSSSS..C',
  'C..SS..SS..C',
  '...SS..SS...',
  '...BB..BB...',
  '..BBB..BBB..',
];

const zombieRows = [
  '...GGGG...',
  '..GGGGGG..',
  '..GRGGRG..',
  '..GGGGGG..',
  '...GDDG...',
  'GTTTTTTTTG',
  'G.TTTTTT.G',
  '..TTTTTT..',
  '..DD..DD..',
  '..DD..DD..',
  '..GG..GG..',
  '.GGG..GGG.',
];

const bossRows = [
  '..H..........H..',
  '..HH........HH..',
  '...HPPPPPPPPH...',
  '...PPPPPPPPPP...',
  '...PYYPPPPYYP...',
  '...PPPPPPPPPP...',
  '...PPWWWWWWPP...',
  '....PPPPPPPP....',
  '.RRAAAAAAAAAARR.',
  'RRAAAAAOOAAAAARR',
  'RRAAPAAOOAAPAARR',
  'RR.PPAAAAAAPP.RR',
  'R...AAAAAAAA...R',
  '....AAA..AAA....',
  '....DDD..DDD....',
  '...DDDD..DDDD...',
];

const barrelRows = [
  '..BBBBBB..',
  '.BWWWWWWB.',
  'BBBBBBBBBB',
  'BMMMMMMMMB',
  'BMMMMMMMMB',
  'BXXXXXXXXB',
  'BXXXXXXXXB',
  'BMMMMMMMMB',
  'BMMMMMMMMB',
  'BBBBBBBBBB',
  '.BMMMMMMB.',
  '..BBBBBB..',
];

const bossPalettes = [
  {'H': 0xFFDDDDDD, 'P': 0xFF7A3FBF, 'Y': 0xFFFFE53B, 'W': 0xFFFFFFFF, 'R': 0xFFB3122E, 'A': 0xFF3B1E66, 'O': 0xFF38FF7A, 'D': 0xFF1A0D30},
  {'H': 0xFFFF7A1A, 'P': 0xFF6E7B8C, 'Y': 0xFFFF3B3B, 'W': 0xFFCCDDEE, 'R': 0xFF2B3A4A, 'A': 0xFF3E4A5A, 'O': 0xFFFF7A1A, 'D': 0xFF1A2230},
  {'H': 0xFF2E2E2E, 'P': 0xFF3FA65A, 'Y': 0xFFFF2BD6, 'W': 0xFFFFFFFF, 'R': 0xFF6A0F8A, 'A': 0xFF1E5E33, 'O': 0xFFFF2BD6, 'D': 0xFF0E2A18},
  {'H': 0xFFFFD21F, 'P': 0xFF8C8C8C, 'Y': 0xFF00E5FF, 'W': 0xFF222222, 'R': 0xFF101010, 'A': 0xFF4A4A4A, 'O': 0xFF00E5FF, 'D': 0xFF151515},
];

const _heroDefs = heroes;

class Sprites {
  final List<ui.Image> heroes;
  final ui.Image zombie;
  final ui.Image zombieFrozen;
  final List<ui.Image> bosses;
  final Map<Power, ui.Image> barrels;
  Sprites._(this.heroes, this.zombie, this.zombieFrozen, this.bosses, this.barrels);

  factory Sprites.build() {
    final hs = [for (final h in _heroDefs) pixelImage(heroRows, h.palette)];
    final z = pixelImage(zombieRows, {'G': 0xFF6FBF3A, 'R': 0xFFFF2B2B, 'D': 0xFF2E3A1E, 'T': 0xFF5B3A7A});
    final zf = pixelImage(zombieRows, {'G': 0xFF9FE8FF, 'R': 0xFF1E5BFF, 'D': 0xFF3A6A8A, 'T': 0xFF7FB8E8});
    final bs = [for (final p in bossPalettes) pixelImage(bossRows, p)];
    final br = <Power, ui.Image>{};
    for (final e in powerDefs.entries) {
      br[e.key] = pixelImage(barrelRows, {
        'B': 0xFF3A2414, 'W': 0xFF8A6A44, 'M': 0xFF8B4A1F, 'X': e.value.color.toARGB32(),
      });
    }
    return Sprites._(hs, z, zf, bs, br);
  }
}
