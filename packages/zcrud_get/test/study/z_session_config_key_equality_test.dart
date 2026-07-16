// ES-11.1 AC2 (AD-24) — égalité PROFONDE de `ZSessionConfigKey` AU BINDING +
// `tag` déterministe (miroir GetX de la clé de family Riverpod).
//
// R27 (leçon ES-9.3 MEDIUM-1 / ES-10.1) : l'égalité ET le `tag` sont prouvés en
// variant CHAQUE champ un à un (7 cas mono-champ), JAMAIS « tous à la fois ».
// Neutraliser la comparaison d'un seul champ dans `ZSessionConfigKey.==` (ou
// l'exclure de `hashCode`/`tag`) DOIT faire rougir le cas correspondant
// (injections R3-I2a..h).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Extension concrète de test à égalité par VALEUR (pour varier le champ
/// `extension`).
class _FakeExt extends ZExtension {
  const _FakeExt(this.value);
  final int value;
  @override
  int get formatVersion => 1;
  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'value': value};
  @override
  bool operator ==(Object other) => other is _FakeExt && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Construit une config de base **non-const** (chaque appel produit une instance
/// DISTINCTE, listes/maps neuves) — indispensable pour prouver l'égalité
/// PROFONDE (par valeur) et non l'égalité d'IDENTITÉ.
ZStudySessionConfig makeBase() => ZStudySessionConfig(
      mode: ZReviewMode.spaced,
      folderId: 'folder-1',
      tagIds: <String>['t1', 't2'],
      types: <String>['multipleChoice'],
      count: 10,
      // NON-const : chaque appel produit une instance _FakeExt DISTINCTE mais
      // value-égale — épingle la value-equality de `extension` (LOW-2 code-review) :
      // une régression `extension ==` → `identical(extension)` ferait alors ROUGIR
      // le cas `a == b` ci-dessous (aujourd'hui un const partagé masquait le trou).
      extension: _FakeExt(1),
      extra: <String, dynamic>{'note': 'x'},
    );

void main() {
  group('ZSessionConfigKey — égalité profonde + tag au binding (AC2, AD-24)', () {
    test('deux configs structurellement égales mais DISTINCTES ⇒ clés == + '
        'hashCode == + tag ==', () {
      final a = makeBase();
      final b = makeBase();
      // Instances réellement distinctes en mémoire (chemin non-identity).
      expect(identical(a, b), isFalse);
      expect(identical(a.tagIds, b.tagIds), isFalse);
      // …y compris `extension` : distinctes-mais-égales (LOW-2) ⇒ l'égalité de clé
      // ci-dessous PROUVE la value-equality de `extension`, pas son identité.
      expect(identical(a.extension, b.extension), isFalse);

      expect(ZSessionConfigKey(a), equals(ZSessionConfigKey(b)));
      expect(ZSessionConfigKey(a).hashCode, ZSessionConfigKey(b).hashCode);
      // a == b ⟹ a.tag == b.tag (contrat GetX de dedup, AD-24).
      expect(ZSessionConfigKey(a).tag, ZSessionConfigKey(b).tag);
    });

    // R3-I2a..g — 7 cas MONO-CHAMP : varier UN SEUL champ via copyWith ⇒ clés
    // inégales ET tags différents. Chaque cas rougit sous neutralisation du champ
    // correspondant (dans `==` OU dans la dérivation de `tag`).
    final a = makeBase();
    final monoField = <String, ZStudySessionConfig>{
      'mode': a.copyWith(mode: ZReviewMode.learn),
      'folderId': a.copyWith(folderId: 'folder-2'),
      'tagIds': a.copyWith(tagIds: <String>['t1', 't3']),
      'types': a.copyWith(types: <String>['openQuestion']),
      'count': a.copyWith(count: 11),
      'extension': a.copyWith(extension: const _FakeExt(2)),
      'extra': a.copyWith(extra: <String, dynamic>{'note': 'y'}),
    };
    monoField.forEach((field, mutated) {
      test('variation du seul champ "$field" ⇒ clés INÉGALES ET tags DIFFÉRENTS '
          '(R3-I2 $field)', () {
        // Le mutant ne diffère de `a` QUE par ce champ.
        expect(
          ZSessionConfigKey(a),
          isNot(equals(ZSessionConfigKey(mutated))),
          reason: 'neutraliser la comparaison de "$field" dans == laisserait ce '
              'test vert (powerless) — R27',
        );
        expect(
          ZSessionConfigKey(a).tag,
          isNot(ZSessionConfigKey(mutated).tag),
          reason: 'exclure "$field" de la dérivation du tag casserait '
              'a==b ⟺ a.tag==b.tag (SM-1 dériverait sur le mauvais champ) — R27',
        );
      });
    });

    test('a == b ⟺ a.tag == b.tag sur tout le lot mono-champ (cohérence bijective)',
        () {
      final base = makeBase();
      final keyBase = ZSessionConfigKey(base);
      monoField.forEach((field, mutated) {
        final keyMut = ZSessionConfigKey(mutated);
        // inégal ⟹ tag différent
        expect(keyBase == keyMut, isFalse, reason: field);
        expect(keyBase.tag == keyMut.tag, isFalse, reason: field);
      });
    });

    test('extra IMBRIQUÉ comparé par zJsonEquals (valeur), pas par référence — '
        '== + hashCode + tag identiques (R3-I2h)', () {
      final deepA = makeBase().copyWith(
        extra: <String, dynamic>{
          'meta': <String, dynamic>{
            'x': 1,
            'y': <int>[1, 2],
          },
        },
      );
      final deepB = makeBase().copyWith(
        extra: <String, dynamic>{
          'meta': <String, dynamic>{
            'x': 1,
            'y': <int>[1, 2],
          },
        },
      );
      expect(identical(deepA.extra, deepB.extra), isFalse);
      expect(ZSessionConfigKey(deepA), equals(ZSessionConfigKey(deepB)));
      expect(ZSessionConfigKey(deepA).hashCode, ZSessionConfigKey(deepB).hashCode,
          reason: 'a==b ⇒ hash(a)==hash(b) même pour un extra imbriqué (R3-I2h)');
      expect(ZSessionConfigKey(deepA).tag, ZSessionConfigKey(deepB).tag,
          reason: 'tag stable même si l\'ORDRE des clés du extra diffère');
    });

    test('extra IMBRIQUÉ à ordre de clés DIFFÉRENT ⇒ tag identique (canonique)',
        () {
      final aa = makeBase().copyWith(
        extra: <String, dynamic>{'a': 1, 'b': 2},
      );
      final bb = makeBase().copyWith(
        extra: <String, dynamic>{'b': 2, 'a': 1},
      );
      expect(ZSessionConfigKey(aa), equals(ZSessionConfigKey(bb)));
      expect(ZSessionConfigKey(aa).tag, ZSessionConfigKey(bb).tag,
          reason: 'le tag canonicalise (clés triées) ⇒ insensible à l\'ordre');
    });

    test('config différant de l\'extra imbriqué (valeur profonde) ⇒ clés '
        'inégales ET tags différents', () {
      final deepA = makeBase().copyWith(
        extra: <String, dynamic>{
          'meta': <String, dynamic>{'x': 1},
        },
      );
      final deepB = makeBase().copyWith(
        extra: <String, dynamic>{
          'meta': <String, dynamic>{'x': 2},
        },
      );
      expect(ZSessionConfigKey(deepA), isNot(equals(ZSessionConfigKey(deepB))));
      expect(ZSessionConfigKey(deepA).tag, isNot(ZSessionConfigKey(deepB).tag));
    });
  });
}
