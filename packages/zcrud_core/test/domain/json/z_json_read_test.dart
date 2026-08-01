// CHAT-0 (décision owner) — surface de LECTURE JSON DÉFENSIVE **PARTAGÉE** du
// cœur : `z_json_read.dart`. Elle n'appartient à aucun module ; elle est le
// pendant, pour la LECTURE, de `zJsonEquals`/`zJsonHash` pour l'ÉGALITÉ.
//
// L'invariant central : **aucune de ces fonctions ne lève, quelle que soit la
// valeur reçue** (AD-10). C'est ce que ce fichier prouve, valeur hostile par
// valeur hostile — pas seulement sur le chemin heureux.
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Valeurs hostiles passées à TOUTES les fonctions.
const List<Object?> _hostiles = <Object?>[
  null,
  42,
  3.14,
  true,
  '',
  'zzz',
  <String>['a'],
  <String, dynamic>{'a': 1},
];

void main() {
  group('AD-10 — AUCUNE fonction ne lève, sur AUCUNE valeur', () {
    test('les 14 primitives absorbent toute valeur hostile', () {
      for (final Object? v in _hostiles) {
        expect(() => zJsonMap(v), returnsNormally, reason: '$v');
        expect(() => zJsonString(v), returnsNormally, reason: '$v');
        expect(() => zJsonStringOrNull(v), returnsNormally, reason: '$v');
        expect(() => zJsonInt(v, 0), returnsNormally, reason: '$v');
        expect(() => zJsonIntOrNull(v), returnsNormally, reason: '$v');
        expect(() => zJsonDouble(v, 0), returnsNormally, reason: '$v');
        expect(() => zJsonDoubleOrNull(v), returnsNormally, reason: '$v');
        expect(() => zJsonBool(v, false), returnsNormally, reason: '$v');
        expect(() => zJsonBoolOrNull(v), returnsNormally, reason: '$v');
        expect(() => zJsonDate(v), returnsNormally, reason: '$v');
        expect(() => zJsonStringList(v), returnsNormally, reason: '$v');
        expect(() => zJsonDecodeList<String>(v, (Object? e) => e as String?),
            returnsNormally,
            reason: '$v');
      }
    });
  });

  group('zJsonMap — coerce défensive', () {
    test('Map<String,dynamic> rendue TELLE QUELLE (zéro copie)', () {
      final Map<String, dynamic> m = <String, dynamic>{'a': 1};
      expect(identical(zJsonMap(m), m), isTrue);
    });

    test('Map<dynamic,dynamic> (forme des stores clé-valeur) re-clefée', () {
      final Map<dynamic, dynamic> m = <dynamic, dynamic>{'a': 1, 2: 'b'};
      expect(zJsonMap(m), <String, dynamic>{'a': 1, '2': 'b'});
    });

    test('non-map ⇒ null', () {
      expect(zJsonMap(null), isNull);
      expect(zJsonMap(42), isNull);
      expect(zJsonMap(<dynamic>[]), isNull);
    });
  });

  group('scalaires — replis nommés', () {
    test('zJsonString / zJsonStringOrNull : la vacuité vaut ABSENCE', () {
      expect(zJsonString('x'), 'x');
      expect(zJsonString(42), '');
      expect(zJsonString(42, 'repli'), 'repli');
      expect(zJsonStringOrNull(''), isNull,
          reason: 'sinon le round-trip n\'est plus idempotent');
      expect(zJsonStringOrNull('x'), 'x');
    });

    test('zJsonInt : tolère num et String', () {
      expect(zJsonIntOrNull(3), 3);
      expect(zJsonIntOrNull(3.7), 3);
      expect(zJsonIntOrNull('12'), 12);
      expect(zJsonIntOrNull('zzz'), isNull);
      expect(zJsonInt('zzz', 7), 7);
    });

    test('zJsonDouble : « non évalué » ≠ « évalué à zéro »', () {
      expect(zJsonDoubleOrNull(0.5), 0.5);
      expect(zJsonDoubleOrNull(1), 1.0);
      expect(zJsonDoubleOrNull('0.25'), 0.25);
      expect(zJsonDoubleOrNull(null), isNull,
          reason: 'un score absent ne DOIT PAS devenir 0.0');
      expect(zJsonDouble(null, 0.0), 0.0);
    });

    test('zJsonBool : bool / num / chaîne', () {
      expect(zJsonBoolOrNull(true), isTrue);
      expect(zJsonBoolOrNull(1), isTrue);
      expect(zJsonBoolOrNull(0), isFalse);
      expect(zJsonBoolOrNull('TRUE'), isTrue);
      expect(zJsonBoolOrNull('False'), isFalse);
      expect(zJsonBoolOrNull('zzz'), isNull);
      expect(zJsonBool('zzz', true), isTrue);
    });

    test('🔴 zJsonDate utilise tryParse — jamais parse', () {
      expect(zJsonDate('2026-07-09T10:30:00.000Z'),
          DateTime.utc(2026, 7, 9, 10, 30));
      for (final Object? v in <Object?>[null, '', 'pas-une-date', 42, true]) {
        expect(zJsonDate(v), isNull, reason: '$v');
      }
    });

    test('zJsonStringList : les éléments non-String sont IGNORÉS', () {
      expect(zJsonStringList(<dynamic>['a', 42, null, 'b']), <String>['a', 'b']);
      expect(zJsonStringList(<dynamic>[]), isEmpty);
      expect(zJsonStringList('zzz'), isNull,
          reason: 'non-liste ⇒ ABSENCE (null), pas liste vide');
    });
  });

  group('zJsonGuard / zJsonDecodeList', () {
    test('zJsonGuard absorbe TOUTE exception', () {
      expect(zJsonGuard<int>(() => 1), 1);
      expect(zJsonGuard<int>(() => throw StateError('x')), isNull);
      expect(zJsonGuard<int>(() => throw 'chaîne levée'), isNull);
    });

    test('🔴 un élément illisible est SAUTÉ — la liste survit', () {
      final List<String>? out = zJsonDecodeList<String>(
        <dynamic>['a', 42, null, 'b'],
        (Object? e) => e is String ? e : null,
      );
      expect(out, <String>['a', 'b']);
    });

    test('un `decode` qui LÈVE ne coûte que son élément', () {
      final List<String>? out = zJsonDecodeList<String>(
        <dynamic>['ok', 'boom', 'ok2'],
        (Object? e) {
          if (e == 'boom') throw StateError('élément cassé');
          return e as String?;
        },
      );
      expect(out, <String>['ok', 'ok2'],
          reason: 'c\'est exactement ce que `map(...).toList()` ne fait pas');
    });

    test('non-liste ⇒ null ; liste vide ⇒ []', () {
      expect(zJsonDecodeList<String>(42, (Object? e) => e as String?), isNull);
      expect(zJsonDecodeList<String>(<dynamic>[], (Object? e) => e as String?),
          isEmpty);
    });
  });

  group('zListEquals / zListHash — l\'`==` d\'une List est une IDENTITÉ', () {
    test('égalité élément par élément, cohérente avec le hash', () {
      expect(zListEquals<String>(<String>['a', 'b'], <String>['a', 'b']),
          isTrue);
      expect(
        zListHash<String>(<String>['a', 'b']),
        zListHash<String>(<String>['a', 'b']),
      );
      expect(zListEquals<String>(<String>['a'], <String>['b']), isFalse);
      expect(zListEquals<String>(<String>['a'], <String>['a', 'b']), isFalse);
    });

    test('null-safety : null == null, null ≠ liste', () {
      expect(zListEquals<String>(null, null), isTrue);
      expect(zListEquals<String>(null, <String>[]), isFalse);
      expect(zListEquals<String>(<String>[], null), isFalse);
      expect(zListHash<String>(null), 0);
    });

    test('sonde de MORDANT : l\'`==` natif des listes échouerait ici', () {
      final List<String> a = <String>['a', 'b'];
      final List<String> b = <String>['a', 'b'];
      expect(a == b, isFalse,
          reason: 'c\'est précisément le défaut que zListEquals ferme');
      expect(zListEquals(a, b), isTrue);
    });
  });
}
