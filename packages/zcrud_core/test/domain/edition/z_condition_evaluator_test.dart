// AC1 — Évaluateur PUR de `ZCondition` : table de vérité par `ZConditionOp` +
// imbrication `and`/`or`/`not`, sémantique `truthy`, extraction des champs de
// garde. Pur-Dart (aucun Flutter).
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Fabrique un `valueOf` depuis une map littérale.
ZValueOf mapOf(Map<String, Object?> m) => (name) => m[name];

void main() {
  group('feuilles (AC1)', () {
    test('equals / notEquals', () {
      final v = mapOf(<String, Object?>{'a': 'x'});
      expect(evaluateZCondition(const ZCondition.equals('a', 'x'), v), isTrue);
      expect(evaluateZCondition(const ZCondition.equals('a', 'y'), v), isFalse);
      expect(
          evaluateZCondition(const ZCondition.notEquals('a', 'y'), v), isTrue);
      expect(
          evaluateZCondition(const ZCondition.notEquals('a', 'x'), v), isFalse);
    });

    test('isNull / notNull (champ absent = null)', () {
      final v = mapOf(<String, Object?>{'a': 1});
      expect(evaluateZCondition(const ZCondition.isNull('absent'), v), isTrue);
      expect(evaluateZCondition(const ZCondition.isNull('a'), v), isFalse);
      expect(evaluateZCondition(const ZCondition.notNull('a'), v), isTrue);
      expect(
          evaluateZCondition(const ZCondition.notNull('absent'), v), isFalse);
    });

    test('truthy : non nul / non vide / non false / non 0', () {
      bool t(Object? val) =>
          evaluateZCondition(const ZCondition.truthy('a'), mapOf({'a': val}));
      // Faux.
      expect(t(null), isFalse);
      expect(t(false), isFalse);
      expect(t(0), isFalse);
      expect(t(0.0), isFalse);
      expect(t(''), isFalse);
      expect(t(<int>[]), isFalse);
      expect(t(<String, int>{}), isFalse);
      // Vrai.
      expect(t(true), isTrue);
      expect(t(1), isTrue);
      expect(t(-1), isTrue);
      expect(t('x'), isTrue);
      expect(t(<int>[0]), isTrue);
      expect(t(<String, int>{'k': 0}), isTrue);
    });
  });

  group('combinateurs + imbrication (AC1)', () {
    final v = mapOf(<String, Object?>{'a': true, 'b': 'x', 'c': 0});

    test('and : conjonction (vide ⇒ true)', () {
      expect(
        evaluateZCondition(
          const ZCondition.and(<ZCondition>[
            ZCondition.truthy('a'),
            ZCondition.equals('b', 'x'),
          ]),
          v,
        ),
        isTrue,
      );
      expect(
        evaluateZCondition(
          const ZCondition.and(<ZCondition>[
            ZCondition.truthy('a'),
            ZCondition.truthy('c'), // 0 ⇒ faux
          ]),
          v,
        ),
        isFalse,
      );
      expect(
          evaluateZCondition(const ZCondition.and(<ZCondition>[]), v), isTrue);
    });

    test('or : disjonction (vide ⇒ false)', () {
      expect(
        evaluateZCondition(
          const ZCondition.or(<ZCondition>[
            ZCondition.truthy('c'), // faux
            ZCondition.equals('b', 'x'), // vrai
          ]),
          v,
        ),
        isTrue,
      );
      expect(
          evaluateZCondition(const ZCondition.or(<ZCondition>[]), v), isFalse);
    });

    test('not : négation', () {
      expect(
        evaluateZCondition(
            const ZCondition.not(ZCondition.truthy('c')), v), // not(false)
        isTrue,
      );
      expect(
        evaluateZCondition(const ZCondition.not(ZCondition.truthy('a')), v),
        isFalse,
      );
    });

    test('imbrication profonde and(or(...), not(...))', () {
      final cond = const ZCondition.and(<ZCondition>[
        ZCondition.or(<ZCondition>[
          ZCondition.equals('b', 'nope'),
          ZCondition.truthy('a'),
        ]),
        ZCondition.not(ZCondition.truthy('c')),
      ]);
      expect(evaluateZCondition(cond, v), isTrue);
    });
  });

  group('zIsTruthy (helper partagé)', () {
    test('cohérent avec l\'opérateur truthy', () {
      expect(zIsTruthy(null), isFalse);
      expect(zIsTruthy(false), isFalse);
      expect(zIsTruthy(0), isFalse);
      expect(zIsTruthy(''), isFalse);
      expect(zIsTruthy('a'), isTrue);
      expect(zIsTruthy(true), isTrue);
    });
  });

  group('zGuardFieldsOf (AC3 — souscription ciblée)', () {
    test('union des champs référencés, récursif', () {
      final conditions = <ZCondition?>[
        null,
        const ZCondition.equals('a', 1),
        const ZCondition.and(<ZCondition>[
          ZCondition.truthy('b'),
          ZCondition.or(<ZCondition>[
            ZCondition.notNull('c'),
            ZCondition.not(ZCondition.equals('d', 2)),
          ]),
        ]),
      ];
      expect(zGuardFieldsOf(conditions), <String>{'a', 'b', 'c', 'd'});
    });

    test('aucune condition ⇒ ensemble vide', () {
      expect(zGuardFieldsOf(<ZCondition?>[null, null]), isEmpty);
    });
  });
}
