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

  // ══ DP-2 (B3) — sources, forme/longueur, gardes, parité DODLP ══════════════

  group('DP-2 — accesseurs par source (AC3, AC4, AC8)', () {
    final state = mapOf(<String, Object?>{'x': 'state', 'reajusting': false});
    final persisted =
        mapOf(<String, Object?>{'x': 'persisted', 'reajusting': true});
    final context = mapOf(<String, Object?>{'crud': 'read', 'flag': true});

    test('source state (défaut) lit valueOf', () {
      expect(
        evaluateZCondition(const ZCondition.equals('x', 'state'), state),
        isTrue,
      );
    });

    test('source persisted lit persistedValueOf, insensible à valueOf', () {
      // reajusting: state=false mais baseline=true ⇒ notEquals(true) sur persisted
      // reproduit item["reajusting"] != true == false.
      expect(
        evaluateZCondition(
          const ZCondition.notEquals('reajusting', true,
              source: ZValueSource.persisted),
          state,
          persistedValueOf: persisted,
        ),
        isFalse,
      );
      // Sans accesseur persisté ⇒ null (défensif, AD-10) ⇒ null != true ⇒ true.
      expect(
        evaluateZCondition(
          const ZCondition.notEquals('reajusting', true,
              source: ZValueSource.persisted),
          state,
        ),
        isTrue,
      );
    });

    test('source context lit contextValueOf', () {
      expect(
        evaluateZCondition(
          const ZCondition.equals('crud', 'read', source: ZValueSource.context),
          state,
          contextValueOf: context,
        ),
        isTrue,
      );
      // Accesseur context absent ⇒ null ⇒ equals('read') faux (défensif).
      expect(
        evaluateZCondition(
          const ZCondition.equals('crud', 'read', source: ZValueSource.context),
          state,
        ),
        isFalse,
      );
      // Clé de contexte absente ⇒ null (jamais de throw).
      expect(
        evaluateZCondition(
          const ZCondition.isNull('absente', source: ZValueSource.context),
          state,
          contextValueOf: context,
        ),
        isTrue,
      );
    });
  });

  group('DP-2 — zLengthOf + ops de forme/longueur (AC5, AC6, AC9)', () {
    test('zLengthOf : String/Iterable/Map/null/scalaire', () {
      expect(zLengthOf(null), 0);
      expect(zLengthOf(''), 0);
      expect(zLengthOf('abc'), 3);
      expect(zLengthOf(<int>[]), 0);
      expect(zLengthOf(<int>[1, 2]), 2);
      expect(zLengthOf(<String, int>{}), 0);
      expect(zLengthOf(<String, int>{'k': 1}), 1);
      expect(zLengthOf(42), 0); // non-collection ⇒ 0
      expect(zLengthOf(true), 0);
    });

    test('isEmpty / isNotEmpty (null/vide/non-vide)', () {
      bool empty(Object? v) =>
          evaluateZCondition(const ZCondition.isEmpty('a'), mapOf({'a': v}));
      bool notEmpty(Object? v) =>
          evaluateZCondition(const ZCondition.isNotEmpty('a'), mapOf({'a': v}));
      for (final v in <Object?>[null, '', <int>[], <String, int>{}]) {
        expect(empty(v), isTrue, reason: 'vide: $v');
        expect(notEmpty(v), isFalse, reason: 'vide: $v');
      }
      for (final v in <Object?>['x', <int>[1], <String, int>{'k': 1}]) {
        expect(empty(v), isFalse, reason: 'non-vide: $v');
        expect(notEmpty(v), isTrue, reason: 'non-vide: $v');
      }
    });

    test('length Gt/Gte/Lt/Lte/Equals avec seuils', () {
      final v = mapOf(<String, Object?>{'a': <int>[1, 2, 3]}); // length 3
      expect(evaluateZCondition(const ZCondition.lengthGt('a', 2), v), isTrue);
      expect(evaluateZCondition(const ZCondition.lengthGt('a', 3), v), isFalse);
      expect(evaluateZCondition(const ZCondition.lengthGte('a', 3), v), isTrue);
      expect(evaluateZCondition(const ZCondition.lengthLt('a', 4), v), isTrue);
      expect(evaluateZCondition(const ZCondition.lengthLt('a', 3), v), isFalse);
      expect(evaluateZCondition(const ZCondition.lengthLte('a', 3), v), isTrue);
      expect(
          evaluateZCondition(const ZCondition.lengthEquals('a', 3), v), isTrue);
      expect(
          evaluateZCondition(const ZCondition.lengthEquals('a', 2), v), isFalse);
    });

    test('op de forme sur non-collection ⇒ longueur 0 (total, AD-10)', () {
      final v = mapOf(<String, Object?>{'n': 7, 'b': true});
      expect(evaluateZCondition(const ZCondition.isEmpty('n'), v), isTrue);
      expect(evaluateZCondition(const ZCondition.isNotEmpty('b'), v), isFalse);
      expect(evaluateZCondition(const ZCondition.lengthGt('n', 0), v), isFalse);
    });
  });

  group('DP-2 — zGuardFieldsOf filtré state + zContextGuardKeysOf (AC10, AC11)',
      () {
    final conditions = <ZCondition?>[
      const ZCondition.isNotEmpty('entries'), // state ⇒ garde
      const ZCondition.notEquals('reajusting', true,
          source: ZValueSource.persisted), // persisted ⇒ exclu
      const ZCondition.equals('crud', 'read',
          source: ZValueSource.context), // context ⇒ exclu de la garde
      const ZCondition.and(<ZCondition>[
        ZCondition.truthy('is_grouped'), // state ⇒ garde
        ZCondition.equals('mode', 'correction',
            source: ZValueSource.context), // context
      ]),
    ];

    test('zGuardFieldsOf ne remonte QUE les feuilles source state', () {
      expect(zGuardFieldsOf(conditions), <String>{'entries', 'is_grouped'});
    });

    test('zContextGuardKeysOf remonte QUE les feuilles source context', () {
      expect(zContextGuardKeysOf(conditions), <String>{'crud', 'mode'});
    });

    test('feuille de forme state contribue bien à la garde', () {
      expect(
        zGuardFieldsOf(<ZCondition?>[const ZCondition.isNotEmpty('entries')]),
        <String>{'entries'},
      );
    });

    test('persisted/context seuls ⇒ garde state vide', () {
      expect(
        zGuardFieldsOf(<ZCondition?>[
          const ZCondition.equals('x', 1, source: ZValueSource.persisted),
          const ZCondition.equals('y', 2, source: ZValueSource.context),
        ]),
        isEmpty,
      );
    });
  });

  group('DP-2 — parité des 3 formes DODLP (AC18, traçabilité fichier:ligne)',
      () {
    test('Forme A — crud != read (cargaison_form.dart:57)', () {
      const cond =
          ZCondition.notEquals('crud', 'read', source: ZValueSource.context);
      expect(
        evaluateZCondition(cond, mapOf({}),
            contextValueOf: mapOf({'crud': 'read'})),
        isFalse,
      );
      expect(
        evaluateZCondition(cond, mapOf({}),
            contextValueOf: mapOf({'crud': 'update'})),
        isTrue,
      );
    });

    test('Forme A — crud == create (alert_capri_form.dart:143)', () {
      const cond =
          ZCondition.equals('crud', 'create', source: ZValueSource.context);
      expect(
        evaluateZCondition(cond, mapOf({}),
            contextValueOf: mapOf({'crud': 'create'})),
        isTrue,
      );
      expect(
        evaluateZCondition(cond, mapOf({}),
            contextValueOf: mapOf({'crud': 'read'})),
        isFalse,
      );
    });

    test('Forme A — drapeau capturé includeGender (operateurs:224)', () {
      const cond =
          ZCondition.truthy('includeGender', source: ZValueSource.context);
      expect(
        evaluateZCondition(cond, mapOf({}),
            contextValueOf: mapOf({'includeGender': true})),
        isTrue,
      );
      expect(
        evaluateZCondition(cond, mapOf({}),
            contextValueOf: mapOf({'includeGender': false})),
        isFalse,
      );
    });

    test('Forme B — is_grouped && entries.isNotEmpty (besc_detail:375-377)', () {
      const cond = ZCondition.and(<ZCondition>[
        ZCondition.equals('is_grouped', true),
        ZCondition.isNotEmpty('entries'),
      ]);
      expect(
        evaluateZCondition(
            cond, mapOf({'is_grouped': true, 'entries': <int>[1]})),
        isTrue,
      );
      expect(
        evaluateZCondition(
            cond, mapOf({'is_grouped': true, 'entries': <int>[]})),
        isFalse,
      );
      expect(
        evaluateZCondition(cond, mapOf({'is_grouped': true})),
        isFalse,
        reason: 'entries absent ⇒ longueur 0 ⇒ isNotEmpty faux',
      );
    });

    test('Forme B — marchandisesDeclarees isEmpty/isNotEmpty (mes_dossiers:127,135)',
        () {
      expect(
        evaluateZCondition(const ZCondition.isNotEmpty('marchandisesDeclarees'),
            mapOf({'marchandisesDeclarees': 'x'})),
        isTrue,
      );
      expect(
        evaluateZCondition(const ZCondition.isEmpty('marchandisesDeclarees'),
            mapOf({'marchandisesDeclarees': ''})),
        isTrue,
      );
    });

    test('Forme C — item["reajusting"] != true persisté (demande_depotage:197,484)',
        () {
      const cond = ZCondition.notEquals('reajusting', true,
          source: ZValueSource.persisted);
      // baseline reajusting=true ⇒ false, MÊME si l'état courant a été modifié.
      expect(
        evaluateZCondition(cond, mapOf({'reajusting': false}),
            persistedValueOf: mapOf({'reajusting': true})),
        isFalse,
      );
      // baseline reajusting=false ⇒ true.
      expect(
        evaluateZCondition(cond, mapOf({'reajusting': true}),
            persistedValueOf: mapOf({'reajusting': false})),
        isTrue,
      );
      // baseline absent ⇒ null != true ⇒ true.
      expect(
        evaluateZCondition(cond, mapOf({}), persistedValueOf: mapOf({})),
        isTrue,
      );
    });

    test('Forme A+C combinée — marchandises==null(persisted) && crud!=create(context) (demande_depotage:544)',
        () {
      const cond = ZCondition.and(<ZCondition>[
        ZCondition.isNull('marchandisesDeclarees',
            source: ZValueSource.persisted),
        ZCondition.notEquals('crud', 'create', source: ZValueSource.context),
      ]);
      expect(
        evaluateZCondition(
          cond,
          mapOf({}),
          persistedValueOf: mapOf({'marchandisesDeclarees': null}),
          contextValueOf: mapOf({'crud': 'update'}),
        ),
        isTrue,
      );
      expect(
        evaluateZCondition(
          cond,
          mapOf({}),
          persistedValueOf: mapOf({'marchandisesDeclarees': 'x'}),
          contextValueOf: mapOf({'crud': 'update'}),
        ),
        isFalse,
        reason: 'marchandises non-null ⇒ isNull faux',
      );
      expect(
        evaluateZCondition(
          cond,
          mapOf({}),
          persistedValueOf: mapOf({'marchandisesDeclarees': null}),
          contextValueOf: mapOf({'crud': 'create'}),
        ),
        isFalse,
        reason: 'crud==create ⇒ notEquals faux',
      );
    });
  });

  group('DP-2 — rétro-compatibilité stricte (AC16)', () {
    test('appel 2-args inchangé + égalité par défaut source state', () {
      final v = mapOf(<String, Object?>{'a': 'x'});
      expect(evaluateZCondition(const ZCondition.equals('a', 'x'), v), isTrue);
      // Deux equals sans source explicite sont égales (défaut state).
      expect(const ZCondition.equals('a', 1) == const ZCondition.equals('a', 1),
          isTrue);
      // source différente ⇒ non égales.
      expect(
        const ZCondition.equals('a', 1) ==
            const ZCondition.equals('a', 1, source: ZValueSource.persisted),
        isFalse,
      );
    });

    test('const-emissible : les feuilles restent des expressions const', () {
      const c = ZCondition.lengthGt('items', 0, source: ZValueSource.persisted);
      expect(c.length, 0);
      expect(c.source, ZValueSource.persisted);
      expect(c.op, ZConditionOp.lengthGt);
    });
  });
}
