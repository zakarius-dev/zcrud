// ES-10.1 AC2 (AD-24) — égalité PROFONDE de `ZSessionConfigKey` AU BINDING.
//
// R27 (leçon ES-9.3 MEDIUM-1) : l'égalité est prouvée en variant CHAQUE champ un
// à un (7 cas mono-champ), JAMAIS « tous à la fois ». Neutraliser la comparaison
// d'un seul champ dans `ZSessionConfigKey.==` (ou le retirer de `hashCode`) DOIT
// faire rougir le cas correspondant (injections R3-I2a..h).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';
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
      extension: const _FakeExt(1),
      extra: <String, dynamic>{'note': 'x'},
    );

void main() {
  group('ZSessionConfigKey — égalité profonde au binding (AC2, AD-24)', () {
    test('deux configs structurellement égales mais DISTINCTES ⇒ clés == + '
        'hashCode ==', () {
      final a = makeBase();
      final b = makeBase();
      // Instances réellement distinctes en mémoire (chemin non-identity).
      expect(identical(a, b), isFalse);
      expect(identical(a.tagIds, b.tagIds), isFalse);

      expect(ZSessionConfigKey(a), equals(ZSessionConfigKey(b)));
      expect(ZSessionConfigKey(a).hashCode, ZSessionConfigKey(b).hashCode);
    });

    // R3-I2a..g — 7 cas MONO-CHAMP : varier UN SEUL champ via copyWith ⇒ clés
    // inégales. Chaque cas rougit sous neutralisation du champ correspondant.
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
      test('variation du seul champ "$field" ⇒ clés INÉGALES (R3-I2 $field)',
          () {
        // Le mutant ne diffère de `a` QUE par ce champ.
        expect(
          ZSessionConfigKey(a),
          isNot(equals(ZSessionConfigKey(mutated))),
          reason: 'neutraliser la comparaison de "$field" laisserait ce test '
              'vert (powerless) — R27',
        );
      });
    });

    test('extra IMBRIQUÉ comparé par zJsonEquals (valeur), pas par référence '
        '(R3-I2 extra profond)', () {
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
    });

    test('config différant de l\'extra imbriqué (valeur profonde) ⇒ clés '
        'inégales', () {
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
    });
  });
}
