/// Filtres test/examen PURS (SU-6 — AC10/AC11/AC12/AC13).
///
/// Assertions **exactes** (séquences/multisets entiers) — jamais `isNotEmpty`.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Sélecteur **sans aucun filtre** (dossier/tags/types libres) — isole la
/// contribution PROPRE de `ZFlashcardTestFilters`.
const ZStudySessionSelector _noFilter =
    ZStudySessionSelector(ZStudySessionConfig(mode: ZReviewMode.test));

/// Construit un état SRS de qualité [quality] (carte déjà révisée).
ZRepetitionInfo _reviewed(String id, int quality) => ZRepetitionInfo(
      flashcardId: id,
      folderId: 'f',
      repetitions: 3,
      lastQuality: quality,
      nextReviewDate: DateTime(2026, 3, 20),
    );

void main() {
  const config = ZSrsConfig();

  group('AC10 — zMasteryLevelOf : la table EXHAUSTIVE q0..q5 + jamais-vue', () {
    // 🔴 7 cas, AUCUN trou (AD-46 : « aucune note n'est hors seau »).
    const expected = <int, ZMasteryLevel>{
      0: ZMasteryLevel.bad, // 🔴 q0 EST dans le seau (résidu PRD « q1-2 » REJETÉ)
      1: ZMasteryLevel.bad,
      2: ZMasteryLevel.bad,
      3: ZMasteryLevel.good, // 🔴 q3 = good, PAS mastered (écart n°1 de su-5)
      4: ZMasteryLevel.mastered,
      5: ZMasteryLevel.mastered,
    };

    for (final entry in expected.entries) {
      test('q${entry.key} ⇒ ${entry.value.name}', () {
        expect(
          zMasteryLevelOf(_reviewed('c', entry.key), config),
          equals(entry.value),
        );
      });
    }

    test('🔴 q0 est « bad » — l\'injection « bad = q1-2 » (le résidu PRD) '
        'rougirait ICI', () {
      // AD-46 : « aucune note n'est hors seau ». Un q0 hors seau, c'est
      // l'apprenant le plus en difficulté qui disparaît des filtres.
      expect(zMasteryLevelOf(_reviewed('c', 0), config), equals(ZMasteryLevel.bad));
    });

    test('🔴 q3 est « good » et **PAS** « mastered » (correct ≠ maîtrisé)', () {
      final level = zMasteryLevelOf(_reviewed('c', 3), config);
      expect(level, equals(ZMasteryLevel.good));
      expect(level, isNot(equals(ZMasteryLevel.mastered)));
    });

    test('« jamais vue » ⇒ bad : info null / repetitions 0 / lastQuality null',
        () {
      expect(zMasteryLevelOf(null, config), equals(ZMasteryLevel.bad));
      expect(
        zMasteryLevelOf(
          const ZRepetitionInfo(flashcardId: 'c', folderId: 'f'),
          config,
        ),
        equals(ZMasteryLevel.bad),
      );
      expect(
        zMasteryLevelOf(
          const ZRepetitionInfo(
            flashcardId: 'c',
            folderId: 'f',
            repetitions: 2,
          ),
          config,
        ),
        equals(ZMasteryLevel.bad),
        reason: 'révisée mais aucune note enregistrée ⇒ jamais vue',
      );
    });

    test('🔴 qualité HORS ÉCHELLE ⇒ clampée par config.clampQuality (UNIQUE '
        'voie), jamais « hors seau », jamais de throw', () {
      // 9 → clampé à 5 ⇒ mastered ; -2 → clampé à 0 ⇒ bad.
      expect(
        zMasteryLevelOf(_reviewed('c', 9), config),
        equals(ZMasteryLevel.mastered),
      );
      expect(
        zMasteryLevelOf(_reviewed('c', -2), config),
        equals(ZMasteryLevel.bad),
      );
      // Et le clamp est bien CELUI du config (cohérence avec la voie unique).
      expect(config.clampQuality(9), equals(config.maxQuality));
      expect(config.clampQuality(-2), equals(config.minQuality));
    });

    test('les bornes viennent du CONFIG : une config non canonique déplace les '
        'seaux (aucun littéral en dur)', () {
      // Échelle « sans blackout » : minQuality=1 ⇒ masteredThreshold reste 4.
      const noBlackout = ZSrsConfig(minQuality: 1);
      expect(noBlackout.masteredThreshold, equals(4));
      expect(
        zMasteryLevelOf(_reviewed('c', 4), noBlackout),
        equals(ZMasteryLevel.mastered),
      );
      // 🔴 Et le seuil DÉRIVE : il n'est jamais le littéral 4.
      expect(config.masteredThreshold, equals(config.maxQuality - 1));
    });
  });

  group('AC10 — zApplyTestFilters : PURE, DÉLÈGUE au sélecteur', () {
    final cards = <ZFlashcard>[
      const ZFlashcard(id: 'bad', folderId: 'f1', question: 'b'),
      const ZFlashcard(id: 'good', folderId: 'f1', question: 'g'),
      const ZFlashcard(id: 'mast', folderId: 'f2', question: 'm'),
    ];
    final srsById = zIndexSrsById(<ZRepetitionInfo>[
      _reviewed('bad', 1),
      _reviewed('good', 3),
      _reviewed('mast', 5),
    ]);

    test('filtre par seau de maîtrise (bad seul)', () {
      final result = zApplyTestFilters(
        cards,
        srsById: srsById,
        filters: const ZFlashcardTestFilters(
          questionCount: 10,
          masteryLevels: <ZMasteryLevel>{ZMasteryLevel.bad},
        ),
        config: config,
        selector: _noFilter,
        random: Random(1),
      );

      expect(result.map((c) => c.id).toList(), equals(<String>['bad']));
    });

    test('masteryLevels VIDE ⇒ aucun filtre de maîtrise (patron du kernel)', () {
      final result = zApplyTestFilters(
        cards,
        srsById: srsById,
        filters: const ZFlashcardTestFilters(questionCount: 10),
        config: config,
        selector: _noFilter,
        random: Random(1),
      );

      expect(result.map((c) => c.id).toSet(),
          equals(<String>{'bad', 'good', 'mast'}));
    });

    test('🔴 le filtre DOSSIER est DÉLÉGUÉ au sélecteur (jamais réécrit)', () {
      const selector = ZStudySessionSelector(
        ZStudySessionConfig(mode: ZReviewMode.test, folderId: 'f1'),
      );

      final result = zApplyTestFilters(
        cards,
        srsById: srsById,
        filters: const ZFlashcardTestFilters(questionCount: 10),
        config: config,
        selector: selector,
        random: Random(1),
      );

      // Seules les cartes de f1 : la règle vient du KERNEL, pas d'une copie.
      expect(result.map((c) => c.id).toSet(), equals(<String>{'bad', 'good'}));
    });

    test('🔴 le filtre TYPE est DÉLÉGUÉ au sélecteur (typeKey du kernel)', () {
      final typed = <ZFlashcard>[
        const ZFlashcard(id: 'open', folderId: 'f', question: 'o'),
        const ZFlashcard(
          id: 'qcm',
          folderId: 'f',
          question: 'q',
          type: ZFlashcardType.multipleChoice,
        ),
      ];
      const selector = ZStudySessionSelector(
        ZStudySessionConfig(
          mode: ZReviewMode.test,
          types: <String>['multipleChoice'],
        ),
      );

      final result = zApplyTestFilters(
        typed,
        srsById: const <String, ZRepetitionInfo>{},
        filters: const ZFlashcardTestFilters(questionCount: 10),
        config: config,
        selector: selector,
        random: Random(1),
      );

      expect(result.map((c) => c.id).toList(), equals(<String>['qcm']));
    });

    test('🔴 le filtre TAGS est DÉLÉGUÉ au sélecteur', () {
      final tagged = <ZFlashcard>[
        const ZFlashcard(
          id: 'droit',
          folderId: 'f',
          question: 'd',
          tagIds: <String>['t-droit'],
        ),
        const ZFlashcard(
          id: 'eco',
          folderId: 'f',
          question: 'e',
          tagIds: <String>['t-eco'],
        ),
      ];
      const selector = ZStudySessionSelector(
        ZStudySessionConfig(mode: ZReviewMode.test, tagIds: <String>['t-droit']),
      );

      final result = zApplyTestFilters(
        tagged,
        srsById: const <String, ZRepetitionInfo>{},
        filters: const ZFlashcardTestFilters(questionCount: 10),
        config: config,
        selector: selector,
        random: Random(1),
      );

      expect(result.map((c) => c.id).toList(), equals(<String>['droit']));
    });

    test('filtre par SOURCE (`kind` du registre ouvert — AD-4)', () {
      final sourced = <ZFlashcard>[
        const ZFlashcard(
          id: 'fromNote',
          folderId: 'f',
          question: 'n',
          source: ZNoteSource(noteId: 'n1'),
        ),
        const ZFlashcard(id: 'sansSource', folderId: 'f', question: 's'),
      ];

      final result = zApplyTestFilters(
        sourced,
        srsById: const <String, ZRepetitionInfo>{},
        filters: const ZFlashcardTestFilters(
          questionCount: 10,
          sources: <String>{'note'},
        ),
        config: config,
        selector: _noFilter,
        random: Random(1),
      );

      expect(result.map((c) => c.id).toList(), equals(<String>['fromNote']));
    });

    test('questionCount défaut = 10 (FR-SU12)', () {
      expect(const ZFlashcardTestFilters().questionCount, equals(10));
    });

    test('🔴 filtres ne retenant RIEN ⇒ liste VIDE, jamais de throw (AD-10)',
        () {
      final result = zApplyTestFilters(
        cards,
        srsById: srsById,
        filters: const ZFlashcardTestFilters(
          questionCount: 10,
          sources: <String>{'inexistant'},
        ),
        config: config,
        selector: _noFilter,
        random: Random(1),
      );

      expect(result, isEmpty);
    });

    test('corpus VIDE ⇒ liste vide, jamais de throw', () {
      final result = zApplyTestFilters(
        const <ZFlashcard>[],
        srsById: const <String, ZRepetitionInfo>{},
        filters: const ZFlashcardTestFilters(),
        config: config,
        selector: _noFilter,
        random: Random(1),
      );
      expect(result, isEmpty);
    });

    test('PURETÉ : deux appels à graine égale rendent le MÊME résultat', () {
      List<String?> run() => zApplyTestFilters(
            cards,
            srsById: srsById,
            filters: const ZFlashcardTestFilters(questionCount: 2),
            config: config,
            selector: _noFilter,
            random: Random(42),
          ).map((c) => c.id).toList();

      expect(run(), equals(run()));
    });
  });

  group('🔴 AC11 — zDrawQuestions : aléa INJECTÉ et PROUVÉ consulté', () {
    final pool = <String>[for (var i = 0; i < 100; i++) 'q$i'];

    test('rend EXACTEMENT count, tous ⊆ eligible, SANS doublon', () {
      final drawn = zDrawQuestions(pool, count: 10, random: Random(7));

      expect(drawn, hasLength(10));
      expect(drawn.toSet(), hasLength(10), reason: 'aucun doublon');
      expect(pool.toSet().containsAll(drawn), isTrue, reason: 'tous ⊆ eligible');
    });

    test('même graine ⇒ séquence STRICTEMENT identique (déterminisme)', () {
      expect(
        zDrawQuestions(pool, count: 10, random: Random(7)),
        equals(zDrawQuestions(pool, count: 10, random: Random(7))),
      );
    });

    test('🔴 DEUX GRAINES ⇒ DEUX SOUS-ENSEMBLES — LE test qui prouve que l\'aléa '
        'est RÉELLEMENT consulté', () {
      // 🔴 C'est le SEUL test qu'une implémentation `eligible.take(count)` fait
      // rougir : elle passerait longueur, inclusion, absence de doublon et
      // déterminisme, et rendrait TOUJOURS les 10 premières.
      final a = zDrawQuestions(pool, count: 10, random: Random(1));
      final b = zDrawQuestions(pool, count: 10, random: Random(999));

      expect(
        a.toSet(),
        isNot(equals(b.toSet())),
        reason: '🔴 deux graines rendent le MÊME sous-ensemble : l\'aléa n\'est '
            'pas consulté (ou le tirage est un `take`)',
      );
    });

    test('🔬 contre-preuve du discriminant : `take(count)` IGNORE la graine '
        '(c\'est le défaut que le test ci-dessus attrape)', () {
      // La référence FAUTIVE, exercée ici pour prouver que l'assertion
      // ci-dessus a du POUVOIR : `take` rend le même sous-ensemble quelle que
      // soit la graine.
      List<String> takeImpl(int count) => pool.take(count).toList();

      expect(
        takeImpl(10).toSet(),
        equals(takeImpl(10).toSet()),
        reason: 'la référence fautive est insensible à la graine — et le test '
            '« deux graines » ci-dessus la ferait donc ROUGIR',
      );
    });

    test('count >= length ⇒ TOUT est rendu, aucun tirage, aucun throw', () {
      final all = zDrawQuestions(pool, count: 100, random: Random(1));
      expect(all, equals(pool), reason: 'ordre d\'entrée préservé');

      final more = zDrawQuestions(pool, count: 500, random: Random(1));
      expect(more, equals(pool));
    });

    test('count <= 0 ⇒ VIDE (cohérent avec ZStudySessionSelector)', () {
      expect(zDrawQuestions(pool, count: 0, random: Random(1)), isEmpty);
      expect(zDrawQuestions(pool, count: -5, random: Random(1)), isEmpty);
    });

    test('eligible VIDE ⇒ vide, jamais de throw', () {
      expect(zDrawQuestions(<String>[], count: 10, random: Random(1)), isEmpty);
    });

    test('l\'original n\'est JAMAIS muté', () {
      final original = List<String>.of(pool);
      zDrawQuestions(pool, count: 10, random: Random(3));
      expect(pool, equals(original));
    });
  });

  group('🔴 AC12 — zShuffleChoices : l\'ASSOCIATION survit (leçon su-2)', () {
    const choices = <ZChoice>[
      ZChoice(content: 'Paris', isCorrect: true),
      ZChoice(content: 'Lyon'),
      ZChoice(content: 'Marseille'),
      ZChoice(content: 'Lille'),
    ];

    /// **MULTISET** des PAIRES `(content, isCorrect)` — l'assertion qui COMPTE.
    ///
    /// 🔴 Ceci rendait un `Set` (code-review su-6, D5). Le nom promettait un
    /// multiset, `toSet()` **écrasait les doublons** : une **perte ET une
    /// duplication simultanées** passaient l'assertion. Soit
    /// `[A|false, A|false, B|true]` ; une implémentation fautive rendant
    /// `[A|false, B|true, B|true]` (un choix **perdu**, un **dupliqué**, et
    /// **deux** bonnes réponses là où il n'y en avait qu'une) satisfaisait
    /// `hasLength(3)` **et** `{A|false, B|true} == {A|false, B|true}`. Le QCM
    /// aurait affiché deux bonnes réponses, et `ZEvaluation` (égalité
    /// ensembliste stricte) aurait noté faux l'apprenant n'en cochant qu'une.
    ///
    /// Le cas « deux choix partageant un `content` » est **nommément signalé par
    /// la story** (`ZChoice` n'a **aucun `id`**) — et n'était testé nulle part :
    /// c'est exactement le corpus sur lequel un `Set` cesse d'être un multiset.
    ///
    /// Défaut **LATENT** : le Fisher-Yates actuel échange sur une copie, il ne
    /// peut ni perdre ni dupliquer. C'est le POUVOIR du test qui manquait, pas
    /// le code — d'où une correction du test seul.
    List<String> pairs(List<ZChoice> cs) =>
        cs.map((c) => '${c.content}|${c.isCorrect}').toList()..sort();

    test('🔴 le multiset des PAIRES (content, isCorrect) est STRICTEMENT '
        'préservé — pas seulement les content', () {
      final shuffled = zShuffleChoices(choices, random: Random(5));

      // 🔴 L'assertion de PAIRES : c'est elle, et elle seule, qui verrait le
      // défaut su-2 (marqueur attribué au MAUVAIS choix). L'assertion de
      // `content` seule resterait VERTE — cf. la contre-preuve ci-dessous.
      expect(pairs(shuffled), equals(pairs(choices)));
      expect(shuffled, hasLength(4));
      // La bonne réponse reste « Paris », où qu'elle soit.
      final correct = shuffled.where((c) => c.isCorrect).toList();
      expect(correct, hasLength(1));
      expect(correct.single.content, equals('Paris'));
    });

    test('🔬 CONTRE-PREUVE : mélanger les CONTENT en laissant isCorrect en '
        'place préserve les content mais CASSE les paires', () {
      // Le défaut su-2 REPRODUIT : on permute les libellés, on laisse le
      // marqueur à sa position.
      final contents = choices.map((c) => c.content).toList()..shuffle(Random(5));
      final broken = <ZChoice>[
        for (var i = 0; i < choices.length; i++)
          ZChoice(content: contents[i], isCorrect: choices[i].isCorrect),
      ];

      // ✅ L'assertion FAIBLE (content seuls) reste VERTE sur le code CASSÉ…
      expect(
        broken.map((c) => c.content).toSet(),
        equals(choices.map((c) => c.content).toSet()),
        reason: 'un test qui n\'assert que les content NE PEUT PAS voir le '
            'défaut su-2',
      );
      // 🔴 …et l'assertion de PAIRES, elle, le VOIT.
      expect(
        pairs(broken),
        isNot(equals(pairs(choices))),
        reason: '🔴 si les paires survivaient à cette permutation, l\'assertion '
            'de paires n\'aurait aucun pouvoir',
      );
      // La bonne réponse a bien changé de libellé : le marqueur est sur le
      // MAUVAIS choix.
      expect(
        broken.firstWhere((c) => c.isCorrect).content,
        isNot(equals('Paris')),
      );
    });

    test('aucun choix perdu ni dupliqué (longueur + multiset)', () {
      for (var seed = 0; seed < 20; seed++) {
        final shuffled = zShuffleChoices(choices, random: Random(seed));
        expect(shuffled, hasLength(choices.length));
        expect(pairs(shuffled), equals(pairs(choices)));
      }
    });

    test('🔴 CONTENUS DUPLIQUÉS (`ZChoice` n\'a aucun `id`) : le multiset '
        'des paires est préservé — le cas que la story signale', () {
      // Le corpus sur lequel un `Set` cesse d\'être un multiset : deux choix
      // partagent le MÊME `content`. La story le nomme explicitement.
      const dup = <ZChoice>[
        ZChoice(content: 'A'),
        ZChoice(content: 'A'),
        ZChoice(content: 'B', isCorrect: true),
      ];

      for (var seed = 0; seed < 20; seed++) {
        final shuffled = zShuffleChoices(dup, random: Random(seed));
        expect(shuffled, hasLength(3));
        // 🔴 `['A|false', 'A|false', 'B|true']` — les DEUX `A` doivent survivre.
        expect(pairs(shuffled), equals(pairs(dup)));
        expect(shuffled.where((c) => c.isCorrect), hasLength(1),
            reason: '🔴 un QCM à DEUX bonnes réponses : l\'apprenant qui n\'en '
                'coche qu\'une est noté faux quoi qu\'il fasse');
      }
    });

    test('🔬 CONTRE-PREUVE R3 du helper : une PERTE + une DUPLICATION '
        'simultanées rougissent — un `Set` les laisserait passer', () {
      const dup = <ZChoice>[
        ZChoice(content: 'A'),
        ZChoice(content: 'A'),
        ZChoice(content: 'B', isCorrect: true),
      ];
      // Le défaut EXACT que le `toSet()` d'origine ne pouvait pas voir : un `A`
      // perdu, un `B` dupliqué. Longueur INCHANGÉE (3).
      const broken = <ZChoice>[
        ZChoice(content: 'A'),
        ZChoice(content: 'B', isCorrect: true),
        ZChoice(content: 'B', isCorrect: true),
      ];

      // ✅ L'assertion FAIBLE d'origine (un Set) reste VERTE sur le cassé…
      expect(
        broken.map((c) => '${c.content}|${c.isCorrect}').toSet(),
        equals(dup.map((c) => '${c.content}|${c.isCorrect}').toSet()),
        reason: 'un `Set` NE PEUT PAS voir une perte compensée par une '
            'duplication — c\'est pourquoi `pairs()` est un multiset',
      );
      expect(broken, hasLength(dup.length), reason: 'la longueur non plus');

      // 🔴 …et le MULTISET, lui, le VOIT.
      expect(
        pairs(broken),
        isNot(equals(pairs(dup))),
        reason: '🔴 si le multiset survivait à cette mutation, `pairs()` '
            'n\'aurait aucun pouvoir sur les contenus dupliqués',
      );
    });

    test('🔴 deux graines ⇒ ordres différents (l\'aléa est consulté)', () {
      final many = <ZChoice>[
        for (var i = 0; i < 12; i++) ZChoice(content: 'c$i', isCorrect: i == 0),
      ];
      final a = zShuffleChoices(many, random: Random(1));
      final b = zShuffleChoices(many, random: Random(999));

      expect(
        a.map((c) => c.content).toList(),
        isNot(equals(b.map((c) => c.content).toList())),
      );
    });

    test('même graine ⇒ ordre identique (déterminisme)', () {
      expect(
        zShuffleChoices(choices, random: Random(3)).map((c) => c.content).toList(),
        equals(
          zShuffleChoices(choices, random: Random(3)).map((c) => c.content).toList(),
        ),
      );
    });

    test('null / vide / un seul choix ⇒ jamais de throw (AD-10)', () {
      expect(zShuffleChoices(null, random: Random(1)), isEmpty);
      expect(zShuffleChoices(const <ZChoice>[], random: Random(1)), isEmpty);
      final single = <ZChoice>[const ZChoice(content: 'seul', isCorrect: true)];
      expect(zShuffleChoices(single, random: Random(1)), equals(single));
    });

    test('l\'original n\'est JAMAIS muté (nouvelle liste rendue)', () {
      final original = <ZChoice>[
        const ZChoice(content: 'a', isCorrect: true),
        const ZChoice(content: 'b'),
        const ZChoice(content: 'c'),
      ];
      final snapshot = List<ZChoice>.of(original);

      final shuffled = zShuffleChoices(original, random: Random(9));

      expect(original, equals(snapshot), reason: 'entrée mutée !');
      expect(identical(shuffled, original), isFalse);
    });
  });

  group('AC15 — enums, jamais de booléens', () {
    test('ZMasteryLevel porte les 3 seaux AD-46', () {
      expect(ZMasteryLevel.values, hasLength(3));
      expect(
        ZMasteryLevel.values.map((l) => l.name),
        containsAll(<String>['bad', 'good', 'mastered']),
      );
    });

    test('ZFlashcardTestFilters : égalité de valeur', () {
      const a = ZFlashcardTestFilters(
        questionCount: 5,
        masteryLevels: <ZMasteryLevel>{ZMasteryLevel.bad},
        sources: <String>{'note'},
      );
      const b = ZFlashcardTestFilters(
        questionCount: 5,
        masteryLevels: <ZMasteryLevel>{ZMasteryLevel.bad},
        sources: <String>{'note'},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
