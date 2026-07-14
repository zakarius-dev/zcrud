/// AC5 / AC11 — `ZDocumentLearningInfo` : VO **hand-written** (D3), invariants de
/// page **1-based** gardés, `==`/`hashCode` **ordre-indépendants**.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('AC5 — D3 : VO PUR, hors codegen et hors gate', () {
    test('n\'est NI `ZExtensible` NI `ZEntity` (⇒ hors E_disk / R_disk)', () {
      // Conséquence directe de D3 : le générateur ne supporte AUCUN type `Map`
      // (`_classify` n'a pas de branche `isDartCoreMap`) ⇒ `qualityByPage:
      // Map<int,int>` ne PEUT PAS être un `@ZcrudField` ⇒ pas de `@ZcrudModel`,
      // pas de `.g.dart`, pas de `kind`, pas de registrar.
      // Corollaire à NE PAS SUR-APPLIQUER : n'étant ni `ZExtensible` ni
      // enregistrée, elle sort de `E_disk` ET de `R_disk` du gate
      // `reserved-keys` ⇒ AUCUN câblage `manual_probes.dart` requis (celui-ci est
      // réservé aux entités hand-written **ET** `ZExtensible` : ZMindmap…).
      expect(ZDocumentLearningInfo.empty, isNot(isA<ZExtensible>()));
      expect(ZDocumentLearningInfo.empty, isNot(isA<ZEntity>()));
    });

    test('`empty` = aucune page évaluée', () {
      expect(ZDocumentLearningInfo.empty.qualityByPage, isEmpty);
      expect(ZDocumentLearningInfo.empty.masteredCount, 0);
      expect(ZDocumentLearningInfo.empty.isMastered(1), isFalse);
    });
  });

  group('AC5 — persistance `{"quality_by_page": {"<page>": <int>}}`', () {
    test('toJson : clés String, valeurs int', () {
      const info = ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2, 3: 0});
      expect(
        info.toJson(),
        equals(<String, dynamic>{
          kQualityByPageKey: <String, dynamic>{'1': 2, '3': 0},
        }),
      );
    });

    test('round-trip STABLE : fromJson(toJson(i)) == i', () {
      const info = ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2, 7: 0, 12: 2});
      final relu = ZDocumentLearningInfo.fromJson(info.toJson());
      expect(relu, info);
      expect(relu.toJson(), equals(info.toJson()));
    });

    test('idempotence du round-trip vide', () {
      final relu = ZDocumentLearningInfo.fromJson(ZDocumentLearningInfo.empty.toJson());
      expect(relu, ZDocumentLearningInfo.empty);
      expect(relu.toJson(), equals(ZDocumentLearningInfo.empty.toJson()));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC11 / R-H — invariants de page : GARDE + CAS CORROMPU (AD-10, jamais throw).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC11 — désérialisation DÉFENSIVE (entrée invalide ⇒ IGNORÉE)', () {
    ZDocumentLearningInfo decode(Object? raw) =>
        ZDocumentLearningInfo.fromJson(<String, dynamic>{kQualityByPageKey: raw});

    test('GARDE : {"1": 2} conservé', () {
      final i = decode(<String, dynamic>{'1': 2});
      expect(i.qualityByPage, equals(<int, int>{1: 2}));
      expect(i.isMastered(1), isTrue);
      expect(i.masteredCount, 1);
    });

    test('CORROMPU : page < 1 ("0", "-3") ⇒ entrée IGNORÉE (1-based)', () {
      final i = decode(<String, dynamic>{'0': 2, '-3': 2, '2': 2});
      expect(i.qualityByPage, equals(<int, int>{2: 2}),
          reason: 'seule la page 1-based valide subsiste');
    });

    test('CORROMPU : clé non parsable ("abc") ⇒ entrée IGNORÉE', () {
      final i = decode(<String, dynamic>{'abc': 2, '4': 0});
      expect(i.qualityByPage, equals(<int, int>{4: 0}));
    });

    test('CORROMPU : valeur non-`num` ⇒ entrée IGNORÉE', () {
      final i = decode(<String, dynamic>{
        '1': 'x',
        '2': <String, dynamic>{'k': 'v'},
        '3': null,
        '4': 2,
      });
      expect(i.qualityByPage, equals(<int, int>{4: 2}));
    });

    test('CORROMPU : map absente / non-map ⇒ `empty`', () {
      expect(ZDocumentLearningInfo.fromJson(const <String, dynamic>{}),
          ZDocumentLearningInfo.empty);
      expect(decode('pas une map'), ZDocumentLearningInfo.empty);
      expect(decode(42), ZDocumentLearningInfo.empty);
      expect(decode(null), ZDocumentLearningInfo.empty);
      expect(decode(<String>['1', '2']), ZDocumentLearningInfo.empty);
    });

    test('CORROMPU : cas 100 % dégénéré ⇒ `empty` (identité, pas juste ==)', () {
      final i = decode(<String, dynamic>{'0': 2, 'abc': 1, '5': 'x'});
      expect(i, ZDocumentLearningInfo.empty);
      expect(i.qualityByPage, isEmpty);
    });

    test('valeur `num` (double persisté) tronquée en int', () {
      expect(decode(<String, dynamic>{'1': 2.0}).qualityByPage, <int, int>{1: 2});
    });

    test('AUCUNE entrée ne fait THROW (AD-10)', () {
      for (final raw in <Object?>[
        null,
        42,
        'x',
        true,
        <String>[],
        <String, dynamic>{'0': 'x', '-1': null, 'zz': <int>[]},
        <int, Object?>{1: 2},
      ]) {
        expect(() => decode(raw), returnsNormally, reason: 'raw = $raw');
      }
    });

    test('`fromJsonSafe` : tout non-map ⇒ empty ; Map non-typée coercée', () {
      expect(ZDocumentLearningInfo.fromJsonSafe(null), ZDocumentLearningInfo.empty);
      expect(ZDocumentLearningInfo.fromJsonSafe(42), ZDocumentLearningInfo.empty);
      expect(ZDocumentLearningInfo.fromJsonSafe('x'), ZDocumentLearningInfo.empty);
      expect(ZDocumentLearningInfo.fromJsonSafe(<String>[]), ZDocumentLearningInfo.empty);
      // Map à clés dynamiques (Hive / map forgée) : coercée, pas rejetée.
      final coerced = ZDocumentLearningInfo.fromJsonSafe(<dynamic, dynamic>{
        kQualityByPageKey: <dynamic, dynamic>{'1': 2},
      });
      expect(coerced.qualityByPage, equals(<int, int>{1: 2}));
    });
  });

  group('AC5 — API portée de lex', () {
    test('masteredCount ne compte que les qualités >= mastered', () {
      const i = ZDocumentLearningInfo(
        qualityByPage: <int, int>{1: 2, 2: 0, 3: 1, 4: 5},
      );
      expect(i.masteredCount, 2, reason: 'pages 1 (=2) et 4 (=5 >= 2)');
    });

    test('qualityOf / isMastered : page absente ⇒ toReview', () {
      const i = ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2});
      expect(i.qualityOf(1), ZDocPageQuality.mastered);
      expect(i.qualityOf(99), ZDocPageQuality.toReview);
      expect(i.isMastered(99), isFalse);
    });

    test('mark : pose la qualité, immuable', () {
      const i = ZDocumentLearningInfo();
      final j = i.mark(3, ZDocPageQuality.mastered);
      expect(j.qualityByPage, equals(<int, int>{3: 2}));
      expect(i.qualityByPage, isEmpty, reason: 'l\'original n\'est pas muté');
    });

    test('GARDE mark : page < 1 ⇒ NO-OP (jamais de throw, jamais de page 0)', () {
      const i = ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2});
      expect(i.mark(0, ZDocPageQuality.mastered), same(i));
      expect(i.mark(-3, ZDocPageQuality.mastered), same(i));
      expect(i.mark(0, ZDocPageQuality.mastered).qualityByPage.containsKey(0),
          isFalse);
      // Symétrique du rejet opéré par `fromJson` : l'invariant 1-based tient aux
      // DEUX frontières (désérialisation ET mutation applicative).
    });

    test('toggle : idempotent aller-retour', () {
      const i = ZDocumentLearningInfo();
      final t1 = i.toggle(2);
      expect(t1.isMastered(2), isTrue);
      final t2 = t1.toggle(2);
      expect(t2.isMastered(2), isFalse);
      expect(t2.qualityOf(2), ZDocPageQuality.toReview);
      expect(t2.toggle(2).isMastered(2), isTrue);
    });

    test('toggle : page < 1 ⇒ NO-OP', () {
      expect(ZDocumentLearningInfo.empty.toggle(0), same(ZDocumentLearningInfo.empty));
    });

    test('copyWith', () {
      const i = ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2});
      expect(i.copyWith().qualityByPage, equals(<int, int>{1: 2}));
      expect(i.copyWith(qualityByPage: <int, int>{5: 0}).qualityByPage,
          equals(<int, int>{5: 0}));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC5 — `==`/`hashCode` ORDRE-INDÉPENDANTS.
  //
  // La combinaison par SOMME (commutative) est portée VERBATIM de lex : c'est le
  // choix CORRECT, pas une négligence. `==` étant ordre-indépendant, un
  // `Object.hashAll` (ordre-dépendant) romprait le contrat `==`/`hashCode` : deux
  // instances ÉGALES construites dans des ordres d'insertion différents (JSON relu
  // vs suite de `mark`) auraient des hash DIFFÉRENTS et se perdraient dans un
  // `Set`/`Map`. ⛔ Ne pas « corriger ».
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC5 — `==`/`hashCode` ORDRE-INDÉPENDANTS', () {
    test('ordres d\'insertion différents ⇒ MÊME == et MÊME hashCode', () {
      // Ordre A : par `mark` (1 puis 3 puis 7).
      final a = ZDocumentLearningInfo.empty
          .mark(1, ZDocPageQuality.mastered)
          .mark(3, ZDocPageQuality.toReview)
          .mark(7, ZDocPageQuality.mastered);
      // Ordre B : par JSON relu, ordre inverse.
      final b = ZDocumentLearningInfo.fromJson(<String, dynamic>{
        kQualityByPageKey: <String, dynamic>{'7': 2, '3': 0, '1': 2},
      });

      expect(a, b);
      expect(
        a.hashCode,
        b.hashCode,
        reason: 'contrat `==`/`hashCode` : deux instances ÉGALES DOIVENT avoir le '
            'même hashCode, quel que soit l\'ordre d\'insertion.',
      );
      // Preuve d'usage : elles se confondent dans un Set.
      expect(<ZDocumentLearningInfo>{a, b}.length, 1);
    });

    test('== discrimine longueur, clés et valeurs', () {
      const base = ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2});
      expect(base, isNot(const ZDocumentLearningInfo()));
      expect(base, isNot(const ZDocumentLearningInfo(qualityByPage: <int, int>{1: 0})));
      expect(base, isNot(const ZDocumentLearningInfo(qualityByPage: <int, int>{2: 2})));
      expect(base, isNot(const ZDocumentLearningInfo(qualityByPage: <int, int>{1: 2, 2: 2})));
      expect(base, isNot(42));
    });
  });

  group('AC11 — ZDocPageQuality : entier, défensif, JAMAIS un @ZcrudField', () {
    test('valeurs entières stables (ordinal extensible)', () {
      expect(ZDocPageQuality.toReview.value, 0);
      expect(ZDocPageQuality.mastered.value, 2);
      expect(ZDocPageQuality.toReview.toJson(), 0);
      expect(ZDocPageQuality.mastered.toJson(), 2);
      // D5 : le défaut sûr en 1ʳᵉ position (convention, même hors codegen).
      expect(ZDocPageQuality.values.first, ZDocPageQuality.toReview);
    });

    test('fromJson défensif : >= 2 ⇒ mastered ; sinon toReview ; jamais de throw',
        () {
      expect(ZDocPageQuality.fromJson(2), ZDocPageQuality.mastered);
      expect(ZDocPageQuality.fromJson(5), ZDocPageQuality.mastered);
      expect(ZDocPageQuality.fromJson(0), ZDocPageQuality.toReview);
      expect(ZDocPageQuality.fromJson(1), ZDocPageQuality.toReview,
          reason: 'valeur intermédiaire FUTURE : lue « à revoir », jamais rejetée');
      expect(ZDocPageQuality.fromJson(-1), ZDocPageQuality.toReview);
      expect(ZDocPageQuality.fromJson(null), ZDocPageQuality.toReview);
      expect(ZDocPageQuality.fromJson('x'), ZDocPageQuality.toReview);
      expect(ZDocPageQuality.fromJson(<String>[]), ZDocPageQuality.toReview);
      expect(ZDocPageQuality.fromJson(2.9), ZDocPageQuality.mastered);
    });
  });

  // =========================================================================
  // 🟠 M3 (code-review ES-2.1) — `qualityByPage` est NON MODIFIABLE.
  //
  // LE TROU : la map était MUTABLE et EXPOSÉE (alors qu'`extra` est
  // `unmodifiable` sur les deux `ZExtensible` du package — incohérence directe).
  //     i.qualityByPage[0] = 2;  // page 0 : invariant 1-based CONTOURNÉ
  //                              // (gardé à `fromJson` ET à `mark`… mais PAS ici)
  //     s.contains(i);           // ⇒ FALSE : le hashCode (une SOMME) a changé,
  //                              //   l'instance s'est PERDUE dans son propre Set
  //     i.toJson();              // ⇒ {'0': 2} PERSISTÉ, puis SILENCIEUSEMENT
  //                              //   REJETÉ à la relecture ⇒ round-trip cassé
  // =========================================================================
  group('M3 — `qualityByPage` NON MODIFIABLE (l\'invariant ne se rouvre pas)', () {
    test('MORD : muter la map de `fromJson` ⇒ UnsupportedError', () {
      final i = ZDocumentLearningInfo.fromJson(const <String, dynamic>{
        'quality_by_page': <String, dynamic>{'1': 2},
      });
      expect(() => i.qualityByPage[0] = 2, throwsUnsupportedError);
      expect(() => i.qualityByPage.remove(1), throwsUnsupportedError);
      expect(() => i.qualityByPage.clear(), throwsUnsupportedError);
    });

    test('MORD : muter la map de `mark` / `copyWith` ⇒ UnsupportedError', () {
      final m = ZDocumentLearningInfo.empty.mark(1, ZDocPageQuality.mastered);
      expect(() => m.qualityByPage[0] = 2, throwsUnsupportedError);
      final c = m.copyWith(qualityByPage: <int, int>{2: 2});
      expect(() => c.qualityByPage[0] = 2, throwsUnsupportedError);
    });

    test('l\'instance ne se PERD PLUS dans son propre `Set` (hashCode stable)',
        () {
      final i = ZDocumentLearningInfo.fromJson(const <String, dynamic>{
        'quality_by_page': <String, dynamic>{'1': 2},
      });
      final s = <ZDocumentLearningInfo>{i};
      final h = i.hashCode;
      expect(() => i.qualityByPage[0] = 2, throwsUnsupportedError);
      expect(i.hashCode, h);
      expect(s.contains(i), isTrue);
    });

    test('`copyWith` FILTRE aussi les pages < 1 (garde aux DEUX frontières)', () {
      // Sans cette garde, `copyWith` rouvrait l'invariant 1-based que `fromJson`
      // et `mark` ferment : une page 0 était PERSISTÉE puis SILENCIEUSEMENT
      // rejetée à la relecture ⇒ round-trip NON idempotent.
      final c = ZDocumentLearningInfo.empty
          .copyWith(qualityByPage: <int, int>{0: 2, -3: 1, 1: 2, 4: 0});
      expect(c.qualityByPage, equals(<int, int>{1: 2, 4: 0}));
      final relu = ZDocumentLearningInfo.fromJson(c.toJson());
      expect(relu, c, reason: 'convergence par la voie `copyWith`');
    });
  });

  // =========================================================================
  // 🟡 L1 (code-review ES-2.1) — une qualité persistée en `String` n'est PLUS
  // silencieusement PERDUE.
  //
  // La v1 rejetait `{'1': '2'}` (`if (value is! num) continue;`) — alors que TOUT
  // le reste du package COERCE les scalaires (`_$asInt` accepte `String`).
  // Impact au moment précis du chantier de migration : coercion Firestore/Hive,
  // et REPLIAGE LEGACY IFFD (ES-11.2 — le `quality` d'IFFD vient d'un AUTRE
  // schéma, 1 ligne par page). Décision TRANCHÉE : on COERCE (R6 : aucune
  // dégradation silencieuse).
  // =========================================================================
  group('L1 — qualité persistée en `String` : COERCÉE, jamais perdue', () {
    ZDocumentLearningInfo decode(Object? raw) =>
        ZDocumentLearningInfo.fromJsonSafe(<String, dynamic>{
          'quality_by_page': raw,
        });

    test('MORD : `{"1": "2"}` ⇒ page 1 CONSERVÉE (et non plus PERDUE)', () {
      final i = decode(<String, dynamic>{'1': '2', '3': '0'});
      expect(
        i.qualityByPage,
        equals(<int, int>{1: 2, 3: 0}),
        reason: 'la v1 rendait `{}` : l\'entrée DISPARAISSAIT en silence.',
      );
      expect(i.isMastered(1), isTrue);
      expect(i.masteredCount, 1);
    });

    test('la coercion reste BORNÉE : le non-numérique est TOUJOURS rejeté', () {
      final i = decode(<String, dynamic>{
        '1': 'x', // ⛔ non numérique
        '2': <String, dynamic>{'k': 'v'}, // ⛔ map
        '3': null, // ⛔ null
        '4': true, // ⛔ bool
        '5': '2.9', // ✅ String numérique ⇒ tronquée (comme un `num`)
        '6': 2, // ✅ num
      });
      expect(i.qualityByPage, equals(<int, int>{5: 2, 6: 2}));
    });

    test('round-trip stable après coercion', () {
      final i = decode(<String, dynamic>{'1': '2'});
      expect(ZDocumentLearningInfo.fromJson(i.toJson()), i);
      expect(i.toJson(), equals(<String, dynamic>{
        'quality_by_page': <String, dynamic>{'1': 2},
      }));
    });
  });
}
