// Champs « chemin » (CR DODLP 2026-08-13) — `zFlattenPaths`/`zRegroupPaths` :
// symétrie PAR CONSTRUCTION (garde de propriété round-trip), segments
// manquants → `null` sans throw (invariant AD-10), collision feuille/branche
// (la branche gagne, indépendamment de l'ordre), maps hôtes figées tolérées.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('zFlattenPaths', () {
    test('lit une valeur imbriquée sous sa clé pointée', () {
      final source = <String, dynamic>{
        'vido': <String, dynamic>{'chef_equipe_poste_id': 'p1'},
        'nom': 'x',
      };
      final flat = zFlattenPaths(
        source,
        paths: const <String>['vido.chef_equipe_poste_id', 'nom'],
      );
      expect(flat, <String, Object?>{
        'vido.chef_equipe_poste_id': 'p1',
        'nom': 'x',
      });
    });

    test('segment MANQUANT → null, jamais de throw (invariant AD-10)', () {
      final source = <String, dynamic>{'vido': <String, dynamic>{}};
      final flat = zFlattenPaths(
        source,
        paths: const <String>[
          'vido.absent',
          'sse.chef_poste_id',
          'a.b.c.d',
        ],
      );
      expect(flat['vido.absent'], isNull);
      expect(flat['sse.chef_poste_id'], isNull);
      expect(flat['a.b.c.d'], isNull);
      expect(flat.length, 3, reason: 'chaque chemin demandé est présent');
    });

    test('segment intermédiaire NON-map → null, jamais de throw', () {
      final source = <String, dynamic>{'vido': 42};
      final flat =
          zFlattenPaths(source, paths: const <String>['vido.chef', 'vido']);
      expect(flat['vido.chef'], isNull);
      expect(flat['vido'], 42);
    });
  });

  group('zRegroupPaths', () {
    test('reconstruit l\'imbrication, les clés sans point passent telles '
        'quelles', () {
      final grouped = zRegroupPaths(<String, Object?>{
        'vido.chef_equipe_poste_id': 'p1',
        'vido.chef_poste_id': 'p2',
        'sse.chef_poste_id': 'p3',
        'nom': 'x',
      });
      expect(grouped, <String, dynamic>{
        'vido': <String, dynamic>{
          'chef_equipe_poste_id': 'p1',
          'chef_poste_id': 'p2',
        },
        'sse': <String, dynamic>{'chef_poste_id': 'p3'},
        'nom': 'x',
      });
    });

    test('collision feuille/branche : la BRANCHE gagne, quel que soit '
        'l\'ordre', () {
      final branchLast = zRegroupPaths(<String, Object?>{
        'vido': 1,
        'vido.a': 2,
      });
      final branchFirst = zRegroupPaths(<String, Object?>{
        'vido.a': 2,
        'vido': 1,
      });
      const expected = <String, dynamic>{
        'vido': <String, dynamic>{'a': 2},
      };
      expect(branchLast, expected);
      expect(branchFirst, expected);
    });

    test('map hôte FIGÉE posée en valeur : la descente recopie, jamais de '
        'throw (invariant AD-10)', () {
      final frozen = Map<String, int>.unmodifiable(<String, int>{'a': 1});
      final grouped = zRegroupPaths(<String, Object?>{
        'vido': frozen,
        'vido.b': 2,
      });
      expect(grouped['vido'], <String, dynamic>{'a': 1, 'b': 2});
      expect(frozen, <String, int>{'a': 1}, reason: 'la map hôte est intacte');
    });
  });

  group('symétrie par construction (garde de PROPRIÉTÉ)', () {
    /// Génère un jeu de chemins pointés SANS collision feuille/branche :
    /// aucune clé n'est un préfixe pointé d'une autre.
    Map<String, Object?> randomFlat(Random rng) {
      const segments = <String>['a', 'b', 'c', 'vido', 'sse', 'x1'];
      const values = <Object?>[null, 0, 1, 'v', true, 3.5];
      final flat = <String, Object?>{};
      final count = 1 + rng.nextInt(8);
      var attempts = 0;
      while (flat.length < count && attempts < 64) {
        attempts++;
        final depth = 1 + rng.nextInt(3);
        final path = List<String>.generate(
          depth,
          (_) => segments[rng.nextInt(segments.length)],
        ).join('.');
        final collides = flat.keys.any(
          (k) =>
              k == path ||
              k.startsWith('$path.') ||
              path.startsWith('$k.'),
        );
        if (collides) continue;
        flat[path] = values[rng.nextInt(values.length)];
      }
      return flat;
    }

    test('round-trip : zFlattenPaths(zRegroupPaths(flat), paths: flat.keys) '
        '== flat — 200 tirages, graine fixe', () {
      final rng = Random(20260813);
      for (var i = 0; i < 200; i++) {
        final flat = randomFlat(rng);
        final roundTrip =
            zFlattenPaths(zRegroupPaths(flat), paths: flat.keys);
        expect(
          roundTrip,
          flat,
          reason: 'round-trip cassé au tirage #$i pour $flat',
        );
      }
    });
  });
}
