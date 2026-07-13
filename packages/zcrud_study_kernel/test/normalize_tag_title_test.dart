/// Tests de `normalizeTagTitle` + `dedupeByNormalizedTitle<T>` (ES-1.2, AC5).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

class _Tag {
  const _Tag(this.title);
  final String? title;
}

void main() {
  group('normalizeTagTitle (AC5)', () {
    test('espaces multiples + casse mixte -> collapse + lowercase', () {
      expect(normalizeTagTitle('  Droit   Douanier '), 'droit douanier');
    });

    test('tabulations -> un espace unique', () {
      expect(normalizeTagTitle('Droit\t\tDouanier'), 'droit douanier');
    });

    test('NBSP (U+00A0) -> collapse comme un espace normal', () {
      expect(normalizeTagTitle('Droit Douanier'), 'droit douanier');
    });

    test('null -> chaîne vide', () {
      expect(normalizeTagTitle(null), '');
    });

    test("'' -> chaîne vide", () {
      expect(normalizeTagTitle(''), '');
    });

    test("'   ' (uniquement des espaces) -> chaîne vide", () {
      expect(normalizeTagTitle('   '), '');
    });

    test('pure : aucune exception quel que soit l\'entrée', () {
      for (final raw in <String?>[null, '', '   ', 'Café', '日本語  タグ']) {
        expect(() => normalizeTagTitle(raw), returnsNormally);
      }
    });

    test('locale-indépendante : pas de règle spécifique à une langue', () {
      // toLowerCase() Dart de base — comportement identique quel que soit
      // l'environnement (pas de Intl.toLocaleLowerCase dépendant d'une locale).
      expect(normalizeTagTitle('DROIT'), 'droit');
      expect(normalizeTagTitle('İstanbul'.toUpperCase()), isNotEmpty);
    });
  });

  group('dedupeByNormalizedTitle<T> (AC5)', () {
    test('conserve la 1re occurrence par titre normalisé, ordre d\'entrée',
        () {
      final tags = <_Tag>[
        const _Tag('Droit'),
        const _Tag('  droit  '),
        const _Tag('Fiscalité'),
        const _Tag('DROIT'),
      ];
      final result = dedupeByNormalizedTitle(tags, titleOf: (t) => t.title);
      expect(result.length, 2);
      expect(result[0].title, 'Droit'); // 1re occurrence conservée telle quelle.
      expect(result[1].title, 'Fiscalité');
    });

    test('titres null/vides tous confondus sous la clé normalisée \'\'', () {
      final tags = <_Tag>[
        const _Tag(null),
        const _Tag(''),
        const _Tag('   '),
        const _Tag('Réel'),
      ];
      final result = dedupeByNormalizedTitle(tags, titleOf: (t) => t.title);
      expect(result.length, 2);
      expect(result[0].title, isNull);
      expect(result[1].title, 'Réel');
    });

    test('pureté : items non muté(e)s', () {
      final tags = <_Tag>[const _Tag('Droit'), const _Tag('droit')];
      final snapshotLength = tags.length;
      dedupeByNormalizedTitle(tags, titleOf: (t) => t.title);
      expect(tags.length, snapshotLength);
    });

    test('aucune duplication -> liste équivalente préservée', () {
      final tags = <_Tag>[
        const _Tag('Droit'),
        const _Tag('Fiscalité'),
        const _Tag('Douane'),
      ];
      final result = dedupeByNormalizedTitle(tags, titleOf: (t) => t.title);
      expect(result.map((t) => t.title).toList(),
          ['Droit', 'Fiscalité', 'Douane']);
    });
  });
}
