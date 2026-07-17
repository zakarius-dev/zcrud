/// `ZSessionModeSelector` + badge flamme + toast (SU-6 — AC6/AC7/AC13/AC14).
///
/// 🔴 **Un contrôle doit être ACTIONNÉ** (leçons su-2/su-4 : marqueur sur le
/// MAUVAIS choix ; bouton « précédent » qui AVANÇAIT — vert parce que jamais
/// tapé). Chaque option est donc **`tap`ée**, et l'on assert **quelle file** le
/// callback reçoit — jamais la seule présence du widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// 🔬 **Espion `ZToaster`** — implémente le port RÉEL et enregistre les appels.
class _SpyToaster implements ZToaster {
  final List<({String message, ZToastSeverity severity})> calls =
      <({String message, ZToastSeverity severity})>[];

  @override
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    calls.add((message: message, severity: severity));
  }
}

ZFlashcard _card(String id) => ZFlashcard(id: id, folderId: 'f', question: id);

ZRepetitionInfo _due(String id, DateTime when) => ZRepetitionInfo(
      flashcardId: id,
      folderId: 'f',
      repetitions: 2,
      nextReviewDate: when,
    );

void main() {
  final at = DateTime(2026, 3, 29, 12);

  /// Monte le sélecteur et capture ce que `onStart` reçoit.
  Future<({List<ZSessionModeKind> kinds, List<List<ZFlashcard>> queues})> pump(
    WidgetTester tester, {
    required List<ZFlashcard> cards,
    required Map<String, ZRepetitionInfo> srsById,
    int batchSize = 30,
    ZStudyStreak streak = const ZStudyStreak(current: 3, best: 5),
    VoidCallback? onOpenFilters,
  }) async {
    final kinds = <ZSessionModeKind>[];
    final queues = <List<ZFlashcard>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZSessionModeSelector(
            cards: cards,
            srsById: srsById,
            at: at,
            streak: streak,
            batchSize: batchSize,
            onOpenFilters: onOpenFilters,
            onStart: (kind, queue) {
              kinds.add(kind);
              queues.add(queue);
            },
          ),
        ),
      ),
    );
    return (kinds: kinds, queues: queues);
  }

  group('AC7 — les 3 options : ACTIONNÉES, pas seulement présentes', () {
    testWidgets('🔴 « Apprendre +N » TAPÉE ⇒ onStart reçoit learnNew ET la file '
        'des jamais-apprises', (tester) async {
      final cards = <ZFlashcard>[_card('a'), _card('b'), _card('c')];
      final spy = await pump(
        tester,
        cards: cards,
        srsById: const <String, ZRepetitionInfo>{}, // aucune apprise
      );

      await tester.tap(find.byKey(ZSessionModeSelector.learnKey));
      await tester.pump();

      // 🔴 On assert CE QUE LE CALLBACK REÇOIT — jamais la présence seule.
      expect(spy.kinds, equals(<ZSessionModeKind>[ZSessionModeKind.learnNew]));
      expect(
        spy.queues.single.map((c) => c.id).toList(),
        equals(<String>['a', 'b', 'c']),
      );
    });

    testWidgets('🔴 « À réviser » TAPÉE ⇒ onStart reçoit review ET la file '
        'TRIÉE PAR URGENCE (séquence entière)', (tester) async {
      final cards = <ZFlashcard>[_card('j1'), _card('j5'), _card('j3')];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        _due('j1', at.subtract(const Duration(days: 1))),
        _due('j5', at.subtract(const Duration(days: 5))),
        _due('j3', at.subtract(const Duration(days: 3))),
      ]);

      final spy = await pump(tester, cards: cards, srsById: srsById);

      await tester.tap(find.byKey(ZSessionModeSelector.reviewKey));
      await tester.pump();

      expect(spy.kinds, equals(<ZSessionModeKind>[ZSessionModeKind.review]));
      // 🔴 La plus EN RETARD d'abord — la file REÇUE, pas une liste supposée.
      expect(
        spy.queues.single.map((c) => c.id).toList(),
        equals(<String>['j5', 'j3', 'j1']),
      );
    });

    testWidgets('🔴 « Test » TAPÉE ⇒ ouvre le dialog de filtres (callback '
        'RÉELLEMENT appelé)', (tester) async {
      var opened = 0;
      final spy = await pump(
        tester,
        cards: <ZFlashcard>[_card('a')],
        srsById: const <String, ZRepetitionInfo>{},
        onOpenFilters: () => opened++,
      );

      await tester.tap(find.byKey(ZSessionModeSelector.testKey));
      await tester.pump();

      expect(opened, equals(1), reason: '🔴 le dialog n\'est pas ouvert');
      expect(spy.kinds, equals(<ZSessionModeKind>[ZSessionModeKind.test]));
    });

    testWidgets('🔴 le lot par défaut est 30 : 60 jamais-apprises ⇒ EXACTEMENT '
        '30 cartes reçues', (tester) async {
      final cards = <ZFlashcard>[for (var i = 0; i < 60; i++) _card('c$i')];

      final spy = await pump(
        tester,
        cards: cards,
        srsById: const <String, ZRepetitionInfo>{},
      );

      await tester.tap(find.byKey(ZSessionModeSelector.learnKey));
      await tester.pump();

      expect(spy.queues.single, hasLength(30));
      expect(
        spy.queues.single.first.id,
        equals('c0'),
        reason: 'ordre d\'entrée préservé',
      );
    });

    testWidgets('🔴 batchSize: 35 ⇒ EXACTEMENT 35 (le lot est CONFIGURABLE)',
        (tester) async {
      final cards = <ZFlashcard>[for (var i = 0; i < 60; i++) _card('c$i')];

      final spy = await pump(
        tester,
        cards: cards,
        srsById: const <String, ZRepetitionInfo>{},
        batchSize: 35,
      );

      await tester.tap(find.byKey(ZSessionModeSelector.learnKey));
      await tester.pump();

      expect(spy.queues.single, hasLength(35));
    });

    testWidgets('le badge flamme affiche streak.current', (tester) async {
      await pump(
        tester,
        cards: <ZFlashcard>[_card('a')],
        srsById: const <String, ZRepetitionInfo>{},
        streak: const ZStudyStreak(current: 7, best: 12),
      );

      expect(find.byKey(ZStreakBadge.badgeKey), findsOneWidget);
      final semantics = tester.getSemantics(find.byKey(ZStreakBadge.badgeKey));
      expect(semantics.value, equals('7'));

      // 🔴 AC7 à la LETTRE — « un badge flamme AFFICHE `streak.current` » : le
      // nombre doit être VISIBLE À L'ŒIL, pas seulement annoncé.
      //
      // Ce test n'existait PAS, et son absence a laissé passer un défaut RÉEL :
      // le badge affichait le littéral `'Série en cours'` et le nombre
      // n'existait QUE dans `Semantics(value:)` — annoncé au lecteur d'écran,
      // INVISIBLE à l'œil. L'assertion `semantics.value == '7'` ci-dessus était
      // VERTE sur ce badge cassé : elle observe le canal A11y, jamais le RENDU.
      // Un `Text` en dur a donc pu survivre à une assertion « verte pour une
      // mauvaise raison » — seul le scan de libellés l'a vu, et pour le mauvais
      // motif (la l10n), pas pour le bug d'affichage.
      expect(
        find.descendant(
          of: find.byKey(ZStreakBadge.badgeKey),
          matching: find.text('7'),
        ),
        findsOneWidget,
        reason: '🔴 le badge n\'AFFICHE pas `streak.current` (AC7) — le nombre '
            'n\'est visible que du lecteur d\'écran',
      );
    });

    testWidgets('🔬 R3 — le badge AFFICHÉ suit la valeur (l\'assertion mord)',
        (tester) async {
      // Anti-vacuité : si le badge affichait une constante, le test ci-dessus
      // serait vert par coïncidence pour `current: 7`. Une SECONDE valeur prouve
      // que le rendu est bien DÉRIVÉ du streak injecté.
      await pump(
        tester,
        cards: <ZFlashcard>[_card('a')],
        srsById: const <String, ZRepetitionInfo>{},
        streak: const ZStudyStreak(current: 2, best: 12),
      );

      expect(
        find.descendant(
          of: find.byKey(ZStreakBadge.badgeKey),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('7'), findsNothing);
    });
  });

  group('AC13 — robustesse : jamais de throw, jamais d\'option grisée', () {
    testWidgets('dossier VIDE ⇒ aucune option de session, « Test » reste, '
        'aucun throw', (tester) async {
      await pump(
        tester,
        cards: const <ZFlashcard>[],
        srsById: const <String, ZRepetitionInfo>{},
      );

      expect(find.byKey(ZSessionModeSelector.learnKey), findsNothing);
      expect(find.byKey(ZSessionModeSelector.reviewKey), findsNothing);
      // « Test » est TOUJOURS là (elle ouvre le dialog, elle ne démarre rien).
      expect(find.byKey(ZSessionModeSelector.testKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 AUCUNE carte due ⇒ « À réviser » ABSENTE (jamais grisée)',
        (tester) async {
      final cards = <ZFlashcard>[_card('a')];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        _due('a', at.add(const Duration(days: 10))), // due plus tard
      ]);

      await pump(tester, cards: cards, srsById: srsById);

      expect(find.byKey(ZSessionModeSelector.reviewKey), findsNothing);
    });

    testWidgets('🔴 AUCUNE jamais-apprise ⇒ « Apprendre +N » ABSENTE',
        (tester) async {
      final cards = <ZFlashcard>[_card('a')];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        _due('a', at.subtract(const Duration(days: 1))),
      ]);

      await pump(tester, cards: cards, srsById: srsById);

      expect(find.byKey(ZSessionModeSelector.learnKey), findsNothing);
      expect(find.byKey(ZSessionModeSelector.reviewKey), findsOneWidget);
    });

    testWidgets('batchSize <= 0 ⇒ « Apprendre +N » absente, aucun throw',
        (tester) async {
      await pump(
        tester,
        cards: <ZFlashcard>[_card('a')],
        srsById: const <String, ZRepetitionInfo>{},
        batchSize: 0,
      );

      expect(find.byKey(ZSessionModeSelector.learnKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('carte sans état SRS ⇒ « jamais vue », aucun throw',
        (tester) async {
      await pump(
        tester,
        cards: <ZFlashcard>[_card('orphan')],
        srsById: const <String, ZRepetitionInfo>{},
      );

      expect(find.byKey(ZSessionModeSelector.learnKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 AC14 — Semantics sur TOUTES les tuiles du diff (un défaut est un '
      'MOTIF, pas un point)', () {
    // 🔴 Code-review su-6 / D2 — DEUX défauts de CE groupe, mesurés :
    //
    // (1) Il énumérait les 4 tuiles du SÉLECTEUR et **omettait celles du
    //     DIALOG**, qui sont dans le MÊME diff (3 seaux + chaque source + 3
    //     contrôles de comptage). `ZTestFiltersDialog` — 240 lignes publiques,
    //     exportées — n'était couvert par AUCUN test : inverser `add`/`remove`
    //     ou popper `initial` restait 441/441 VERT. C'est la leçon su-5 citée
    //     par la story, et re-commise dans le diff qui la cite.
    //
    // (2) Son assertion était `expect(node.label, isNotEmpty)`. `isNotEmpty` ne
    //     peut voir NI une fusion sémantique (« Maîtrisées » annoncé par le
    //     parent ET l'enfant : le libellé fusionné reste non vide), NI un
    //     littéral en dur (`label(context, key, fallback:)` rend le fallback non
    //     vide dans les deux cas). Mesuré : remplacer `label: text` par
    //     `label: 'Apprendre les cartes'` (français EN DUR) dans `_ModeTile`
    //     laissait ce groupe VERT, le scan de libellés VERT, la suite VERTE.
    //     AC14 exige pourtant un label « **issu de `ZcrudLabels`**, vérifié par
    //     un test dédié (la garde ne le fera pas) » — la promesse n'était pas
    //     tenue.
    //
    // Correctif : UNE énumération (jamais une garde parallèle — AC14 l'interdit)
    // couvrant TOUT le diff, avec des libellés **INJECTÉS par scope** et une
    // assertion d'**ÉGALITÉ EXACTE**. Un libellé en dur, une fusion, une valeur
    // concaténée au label : les trois rougissent.

    /// Libellés INJECTÉS — des sentinelles qu'aucun fallback ne peut produire.
    final labels = ZcrudLabels(<String, String>{
      'zcrud.study.mode.learnNew': 'L10N_LEARN',
      'zcrud.study.mode.review': 'L10N_REVIEW',
      'zcrud.study.mode.test': 'L10N_TEST',
      'zcrud.study.streak': 'L10N_STREAK',
      'zcrud.study.mastery.bad': 'L10N_BAD',
      'zcrud.study.mastery.good': 'L10N_GOOD',
      'zcrud.study.mastery.mastered': 'L10N_MASTERED',
      'zcrud.study.source.pdf': 'L10N_SOURCE_PDF',
      'zcrud.study.filters.questionCount': 'L10N_COUNT',
      'zcrud.study.filters.questionCount.decrement': 'L10N_COUNT_DEC',
      'zcrud.study.filters.questionCount.increment': 'L10N_COUNT_INC',
      // 🔴 SU-7 (AC7) — l'examen blanc ÉTEND cette énumération (jamais une
      // garde parallèle). Le **DIALOG de confirmation** (D7) y figure : c'est
      // EXACTEMENT ce que su-6 avait omis (un dialog entier du même diff ⇒ 4
      // tuiles non gardées, 4/4 défectueuses).
      'zcrud.study.exam.submit': 'L10N_EXAM_SUBMIT',
      'zcrud.study.exam.submit.confirm': 'L10N_EXAM_CONFIRM',
      'zcrud.study.exam.submit.cancel': 'L10N_EXAM_CANCEL',
      'zcrud.study.exam.unanswered': 'L10N_EXAM_UNANSWERED',
      // 🔴 7ᵉ clé du diff — elle était gardée par RIEN (`grep -rqF` ⇒ RC=1),
      // parce qu'elle a été ajoutée AU-DELÀ des 6 clés listées par AC7. C'est la
      // classe EXACTE du défaut « dialog aveugle au ZcrudScope » que le dev a
      // lui-même trouvé : une clé jamais confrontée à un `ZcrudLabels` INJECTÉ
      // retombe SILENCIEUSEMENT sur son fallback français, et aucune garde de
      // libellés en dur ne bronche (le fallback EST du français légitime).
      'zcrud.study.exam.noAnswer': 'L10N_EXAM_NO_ANSWER',
      // 🔴 Le VERDICT de `_CorrectionReveal` (phase `submitted`) — su-7 le rend,
      // donc su-7 le garde : c'est le nœud le plus important de la story.
      'zcrud.flashcard.correct': 'L10N_CORRECT',
      'zcrud.flashcard.incorrect': 'L10N_INCORRECT',
      // ⚠️ `zcrud.study.exam.progress` a été RETIRÉE : `_ProgressHeader` ne
      // publie plus de nœud sémantique propre (il aurait été un SECOND compteur,
      // contradictoire avec celui de `ZSessionProgressIndicator` — violation
      // d'AC1). La progression est désormais annoncée par le nœud UNIQUE du
      // composant, sous `zcrud.session.progress`.
    });

    testWidgets('SÉLECTEUR — les 3 options ET le badge portent un '
        'Semantics(label:) issu de ZcrudLabels (valeur EXACTE)', (tester) async {
      final cards = <ZFlashcard>[_card('neuf'), _card('due')];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        _due('due', at.subtract(const Duration(days: 2))),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: Scaffold(
              body: ZSessionModeSelector(
                cards: cards,
                srsById: srsById,
                at: at,
                streak: const ZStudyStreak(current: 3, best: 5),
                onOpenFilters: () {},
                onStart: (_, __) {},
              ),
            ),
          ),
        ),
      );

      // 🔴 ÉNUMÉRATION : les 3 tuiles + le badge. su-5 a corrigé UNE tuile et
      // laissé 3 autres cassées — ici, aucune ne peut être oubliée.
      final expected = <ValueKey<String>, String>{
        ZSessionModeSelector.learnKey: 'L10N_LEARN',
        ZSessionModeSelector.reviewKey: 'L10N_REVIEW',
        ZSessionModeSelector.testKey: 'L10N_TEST',
        ZStreakBadge.badgeKey: 'L10N_STREAK',
      };

      for (final entry in expected.entries) {
        expect(find.byKey(entry.key), findsOneWidget,
            reason: 'tuile ${entry.key} absente');
        final node = tester.getSemantics(find.byKey(entry.key));
        expect(
          node.label,
          equals(entry.value),
          reason: '🔴 ${entry.key} : le Semantics(label:) n\'est PAS le libellé '
              'INJECTÉ. Soit il est CODÉ EN DUR (la garde de libellés ne couvre '
              'pas `Semantics(label:)` — angle mort DÉCLARÉ : seul CE test le '
              'tient), soit il a FUSIONNÉ avec un enfant qui rend le même texte '
              '(su-5/D1). `isNotEmpty` ne voyait ni l\'un ni l\'autre. '
              'Reçu : « ${node.label} »',
        );
      }
    });

    testWidgets('🔴 DIALOG — les 3 seaux, les sources ET le comptage portent un '
        'Semantics(label:) issu de ZcrudLabels (valeur EXACTE) — le MÊME diff',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: const Scaffold(
              body: ZTestFiltersDialog(availableSources: <String>['pdf']),
            ),
          ),
        ),
      );

      // 🔴 Les seaux ÉNUMÈRENT `ZMasteryLevel.values` — jamais une liste
      // recopiée : un 4ᵉ seau ajouté demain arrive ici SANS toucher ce test, et
      // rougit s'il n'a pas de libellé.
      final expected = <ValueKey<String>, String>{
        for (final level in ZMasteryLevel.values)
          ZTestFiltersDialog.masteryKey(level):
              'L10N_${level.name.toUpperCase()}',
        ZTestFiltersDialog.sourceKey('pdf'): 'L10N_SOURCE_PDF',
        ZTestFiltersDialog.questionCountKey: 'L10N_COUNT',
        ZTestFiltersDialog.questionCountDecrementKey: 'L10N_COUNT_DEC',
        ZTestFiltersDialog.questionCountIncrementKey: 'L10N_COUNT_INC',
      };

      for (final entry in expected.entries) {
        expect(find.byKey(entry.key), findsOneWidget,
            reason: 'tuile ${entry.key} absente du dialog');
        final node = tester.getSemantics(find.byKey(entry.key));
        expect(
          node.label,
          equals(entry.value),
          reason: '🔴 ${entry.key} : libellé en dur ou FUSION avec l\'enfant '
              '(le `title: Text(text)` de la tuile rend le MÊME texte — c\'est '
              'le MAJEUR su-5/D1). Reçu : « ${node.label} »',
        );
      }
    });

    testWidgets('🔬 R3 — l\'assertion d\'égalité VOIT la fusion : le nœud du '
        'dialog n\'annonce le libellé qu\'UNE fois (jamais « X … X »)',
        (tester) async {
      // Anti-vacuité de l'assertion ci-dessus : on prouve que la FUSION serait
      // détectable, en montrant que le nœud parent n'a aucun descendant qui
      // ré-annonce le libellé. Sans `excludeSemantics`, `node.label` valait
      // toujours « L10N_MASTERED » (le parent) et l'enfant portait un SECOND
      // nœud « L10N_MASTERED » — TalkBack annonçait deux fois.
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: const Scaffold(body: ZTestFiltersDialog()),
          ),
        ),
      );

      for (final level in ZMasteryLevel.values) {
        final node =
            tester.getSemantics(find.byKey(ZTestFiltersDialog.masteryKey(level)));
        final childLabels = <String>[];
        node.visitChildren((child) {
          childLabels.add(child.label);
          return true;
        });
        expect(
          childLabels,
          isEmpty,
          reason: '🔴 $level : le nœud porte des ENFANTS sémantiques '
              '($childLabels) — le lecteur d\'écran annonce le filtre DEUX '
              'fois (su-5/D1 re-commis). `excludeSemantics: true` manque.',
        );
      }
    });

    testWidgets('🔴 DIALOG — l\'état COCHÉ est porté par le nœud annoncé, et il '
        'SUIT le tap (jamais un état muet)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: const Scaffold(body: ZTestFiltersDialog()),
          ),
        ),
      );

      // 🔴 Avant correction, l'état ne vivait QUE sur le `Semantics(selected:)`
      // parent tandis que le nœud enfant — celui qui A L'AIR d'être la case —
      // n'exposait AUCUN état (`hasCheckedState=false`) : un lecteur d'écran
      // qui le focalisait annonçait « Maîtrisées » sans jamais dire si c'était
      // coché. `checked:` est l'état d'une CASE À COCHER (`selected:` est celui
      // d'un élément de liste).
      for (final level in ZMasteryLevel.values) {
        final finder = find.byKey(ZTestFiltersDialog.masteryKey(level));
        expect(
          tester.getSemantics(finder).hasFlag(SemanticsFlag.hasCheckedState),
          isTrue,
          reason: '🔴 $level : le nœud annoncé n\'expose AUCUN état coché',
        );
        expect(
          tester.getSemantics(finder).hasFlag(SemanticsFlag.isChecked),
          isFalse,
          reason: '$level : coché avant tout tap',
        );

        await tester.tap(finder);
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(finder).hasFlag(SemanticsFlag.isChecked),
          isTrue,
          reason: '🔴 $level : l\'état annoncé NE SUIT PAS le tap',
        );
      }
    });

    testWidgets('les cibles tactiles des 3 options sont >= 48 dp (AD-13)',
        (tester) async {
      final cards = <ZFlashcard>[_card('neuf'), _card('due')];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        _due('due', at.subtract(const Duration(days: 2))),
      ]);

      await pump(tester, cards: cards, srsById: srsById);

      for (final key in <ValueKey<String>>[
        ZSessionModeSelector.learnKey,
        ZSessionModeSelector.reviewKey,
        ZSessionModeSelector.testKey,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: '$key : cible de ${size.height} dp < 48 dp (AD-13)',
        );
      }
    });

    testWidgets('le compte passe par Semantics.value, jamais concaténé au label',
        (tester) async {
      final cards = <ZFlashcard>[for (var i = 0; i < 5; i++) _card('c$i')];

      await pump(
        tester,
        cards: cards,
        srsById: const <String, ZRepetitionInfo>{},
      );

      final node = tester.getSemantics(find.byKey(ZSessionModeSelector.learnKey));
      expect(node.value, equals('5'));
      expect(node.label, isNotEmpty);
    });

    testWidgets('RTL : le sélecteur se construit sans exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ZSessionModeSelector(
                cards: <ZFlashcard>[_card('a')],
                srsById: const <String, ZRepetitionInfo>{},
                at: at,
                streak: const ZStudyStreak(current: 2, best: 2),
                onStart: (_, __) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(ZSessionModeSelector.learnKey), findsOneWidget);
    });

    // 🔴 SU-7 (AC7) — l'EXAMEN BLANC, dans la MÊME énumération.
    //
    // Il serait tentant d'ouvrir un `z_list_session_view_a11y_test.dart` : ce
    // serait une garde **PARALLÈLE**, qui divergerait de celle-ci avec le temps
    // (leçon su-5 : deux gardes finissent par se contredire). AC14 l'interdit :
    // **UNE** énumération, étendue.

    /// Monte la vue d'examen sous des libellés INJECTÉS (sentinelles).
    ///
    /// 🔴 [submissions]/[result] existent parce que la phase `submitted`
    /// n'était montée par **AUCUNE** garde a11y : `pumpExam` prenait bien une
    /// `phase`, mais **aucun** de ses appels ne passait `submitted`.
    /// `_CorrectionReveal` — le nœud qui porte le **VERDICT**, raison d'être de
    /// FR-SU13 — était donc **hors de toute garde**. C'est le trou par lequel le
    /// verdict BÉGAYÉ est passé.
    Future<void> pumpExam(
      WidgetTester tester, {
      required ZExamViewPhase phase,
      Map<int, ZFlashcardSubmission> submissions =
          const <int, ZFlashcardSubmission>{},
      ZStudySessionResult? result,
    }) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: Scaffold(
              body: ZListSessionView(
                cards: <ZFlashcard>[_card('a'), _card('b')],
                phase: phase,
                submissions: submissions,
                result: result,
                onAnswered: (_, __) {},
                onSubmit: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('🔴 EXAMEN (su-7) — la barre de soumission et la progression '
        'portent un Semantics(label:) issu de ZcrudLabels (valeur EXACTE)',
        (tester) async {
      await pumpExam(tester, phase: ZExamViewPhase.running);

      final expected = <ValueKey<String>, String>{
        ZListSessionView.submitKey: 'L10N_EXAM_SUBMIT',
        ZListSessionView.unansweredKey: 'L10N_EXAM_UNANSWERED',
      };
      for (final entry in expected.entries) {
        expect(find.byKey(entry.key), findsOneWidget,
            reason: 'contrôle ${entry.key} absent');
        expect(
          tester.getSemantics(find.byKey(entry.key)).label,
          equals(entry.value),
          reason: '🔴 ${entry.key} : le Semantics(label:) n\'est PAS le libellé '
              'INJECTÉ (codé en dur, ou fusionné avec un enfant).',
        );
      }
      // 🔴 Le nombre sans réponse est porté par les DEUX canaux (leçon su-6 : le
      // streak n'existait QUE dans `Semantics(value:)`).
      expect(
        tester.getSemantics(find.byKey(ZListSessionView.unansweredKey)).value,
        '2',
      );
      expect(
        tester.widget<Text>(find.byKey(ZListSessionView.unansweredTextKey)).data,
        '2',
      );
    });

    testWidgets('🔴 EXAMEN — le DIALOG de confirmation (D7) est DANS le diff : '
        'ses DEUX contrôles portent un Semantics(label:) issu de ZcrudLabels',
        (tester) async {
      // 🔴 **C'est LE test que su-6 avait oublié d'écrire.** Un dialog entier du
      // même diff était resté hors de l'énumération : 4 tuiles non gardées,
      // 4/4 défectueuses. On balaye TOUT le diff, dialog inclus.
      await pumpExam(tester, phase: ZExamViewPhase.running);
      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();

      final expected = <ValueKey<String>, String>{
        ZListSessionView.confirmKey: 'L10N_EXAM_CONFIRM',
        ZListSessionView.cancelKey: 'L10N_EXAM_CANCEL',
      };
      for (final entry in expected.entries) {
        expect(find.byKey(entry.key), findsOneWidget,
            reason: 'contrôle ${entry.key} absent du dialog');
        expect(
          tester.getSemantics(find.byKey(entry.key)).label,
          equals(entry.value),
          reason: '🔴 ${entry.key} : libellé en dur ou fusionné dans le dialog.',
        );
      }
    });

    testWidgets('🔴 EXAMEN — toute cible tactile ≥ 48 dp (AD-13) — DIALOG '
        'INCLUS', (tester) async {
      await pumpExam(tester, phase: ZExamViewPhase.running);

      // 🔴 Cette « énumération » n'en était PAS une : elle bouclait sur UN seul
      // élément (`submitKey`) et **omettait `confirmKey`/`cancelKey`** — qui
      // sont dans le MÊME diff et sont des cibles tactiles. C'est LITTÉRALEMENT
      // le motif su-6 que ce fichier cite en tête (« il énumérait les 4 tuiles
      // du SÉLECTEUR et OMETTAIT celles du DIALOG »), re-commis dans le diff
      // qui le corrige.
      final size = tester.getSize(find.byKey(ZListSessionView.submitKey));
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: '🔴 AD-13 : submitKey trop petite (${size.height} dp)');
      expect(size.width, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();

      for (final key in <ValueKey<String>>[
        ZListSessionView.confirmKey,
        ZListSessionView.cancelKey,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: 'cible $key absente');
        final target = tester.getSize(find.byKey(key));
        expect(target.height, greaterThanOrEqualTo(48.0),
            reason: '🔴 AD-13 : cible $key trop petite (${target.height} dp)');
        expect(target.width, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('🔴🔴 EXAMEN — les 3 boutons sont ACTIVABLES au lecteur d\'écran '
        '(`SemanticsAction.tap`) — pas seulement ANNONCÉS « bouton »',
        (tester) async {
      // 🔴 **LE défaut que toutes les autres gardes laissaient passer.**
      // `_ExamButton` posait `ExcludeSemantics` sur TOUT son sous-arbre,
      // `TextButton` INCLUS ⇒ la `SemanticsAction.tap` du bouton était
      // SUPPRIMÉE. Les nœuds s'annonçaient « Soumettre, bouton » **sans aucune
      // action** : TalkBack/VoiceOver n'exposaient pas `ACTION_CLICK`.
      // Un apprenant non-voyant ne pouvait **ni soumettre son examen**, ni —
      // pire — **sortir du dialog de confirmation** (`confirmKey` ET
      // `cancelKey` inactivables ⇒ modale sans issue).
      //
      // ⚠️ **Pourquoi RIEN ne le voyait** : l'énumération de libellés assère le
      // `label` (vert), le test 48 dp assère la `size` (vert), et
      // `tester.tap()` frappe des **COORDONNÉES** — il atteint le
      // `GestureDetector` réel du `TextButton`, **SOUS** l'`ExcludeSemantics`.
      // **Aucun test n'empruntait le canal sémantique pour ACTIVER quoi que ce
      // soit.** Un contrôle jamais activé PAR LE CANAL QU'ON PRÉTEND GARDER est
      // un contrôle NON TESTÉ (leçon su-4, rejouée).
      await pumpExam(tester, phase: ZExamViewPhase.running);

      expect(
        tester.getSemantics(find.byKey(ZListSessionView.submitKey)).getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: '🔴 « Soumettre » est annoncé « bouton » mais n\'expose AUCUNE '
            'action de tap : l\'apprenant non-voyant ne peut PAS soumettre son '
            'examen. L\'écran est un cul-de-sac.',
      );

      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();

      for (final key in <ValueKey<String>>[
        ZListSessionView.confirmKey,
        ZListSessionView.cancelKey,
      ]) {
        expect(
          tester.getSemantics(find.byKey(key)).getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: '🔴 $key est inactivable au lecteur d\'écran ⇒ l\'apprenant '
              'est PIÉGÉ dans une modale irréversible qu\'il ne peut ni '
              'confirmer ni annuler.',
        );
      }
    });

    // ════════════════════════════════════════════════════════════════════════
    // 🔴 PHASE `submitted` — montée par AUCUNE garde a11y avant ces tests.
    // C'est le trou par lequel le verdict bégayé (H3) est passé, et par lequel
    // `zcrud.study.exam.noAnswer` n'a jamais été confrontée à un scope injecté.
    // ════════════════════════════════════════════════════════════════════════
    testWidgets('🔴 EXAMEN `submitted` — le VERDICT n\'est PAS BÉGAYÉ : le nœud '
        'de correction dit « correct » UNE fois, pas deux', (tester) async {
      // 🔴 Défaut MESURÉ : `label="L10N_CORRECT\nBIEN" value="L10N_CORRECT"` ⇒
      // TalkBack annonçait « correct, BIEN — valeur : correct ». `MergeSemantics`
      // fusionne le sous-arbre : le `Text(statusText)` alimentait le `label`
      // pendant que `Semantics(value:)` alimentait la `value`, **avec la MÊME
      // chaîne**. C'est le D1 de su-5 rejoué sur le nœud le PLUS important de la
      // story — celui qui porte le verdict (raison d'être de FR-SU13).
      await pumpExam(
        tester,
        phase: ZExamViewPhase.submitted,
        submissions: <int, ZFlashcardSubmission>{
          0: const ZFlashcardSubmission(
            quality: 5,
            timeTaken: Duration.zero,
            hintsUsed: 0,
            isCorrect: true,
            feedback: 'BIEN',
          ),
        },
        result: const ZStudySessionResult(
          mode: ZReviewMode.whiteExam,
          total: 1,
          correct: 1,
          byQuality: <String, int>{'5': 1},
        ),
      );

      final verdict = find.ancestor(
        of: find.text('L10N_CORRECT'),
        matching: find.byType(MergeSemantics),
      );
      expect(verdict, findsOneWidget, reason: 'contre-preuve : le verdict EST peint');
      final node = tester.getSemantics(verdict);

      // 🔒 Le verdict est porté par la `value` — et le `label` ne doit PAS le
      // répéter. Le `feedback`, lui, est un contenu DISTINCT : il reste annoncé.
      expect(node.value, 'L10N_CORRECT');
      expect(
        node.label,
        isNot(contains('L10N_CORRECT')),
        reason: '🔴 le verdict est prononcé DEUX FOIS au lecteur d\'écran '
            '(« correct, BIEN — valeur : correct ») : le `Text` du verdict '
            'fusionne dans le `label` alors que la `value` le porte déjà.',
      );
      expect(
        node.label,
        contains('BIEN'),
        reason: '🔒 le FEEDBACK doit rester annoncé — il n\'est pas un doublon '
            'du verdict. Un `ExcludeSemantics` trop large le ferait taire.',
      );
    });

    testWidgets('🔴 EXAMEN `submitted` — une question SAUTÉE porte le libellé '
        'INJECTÉ (`zcrud.study.exam.noAnswer`), jamais son fallback français',
        (tester) async {
      // 🔴 7ᵉ clé du diff, gardée par RIEN. Scénario : faute de frappe dans la
      // clé, ou app anglophone ⇒ « Sans réponse » s'affiche en français au
      // milieu d'une correction anglaise, **506/506 VERTS**.
      await pumpExam(
        tester,
        phase: ZExamViewPhase.submitted,
        submissions: <int, ZFlashcardSubmission>{
          0: const ZFlashcardSubmission(
            quality: 5,
            timeTaken: Duration.zero,
            hintsUsed: 0,
            isCorrect: true,
          ),
        },
        result: const ZStudySessionResult(
          mode: ZReviewMode.whiteExam,
          total: 1,
          correct: 1,
          byQuality: <String, int>{'5': 1},
        ),
      );
      // La carte `b` (index 1) n'a AUCUNE soumission ⇒ elle est « sans réponse ».
      expect(
        find.text('L10N_EXAM_NO_ANSWER'),
        findsOneWidget,
        reason: '🔴 la clé l10n n\'est pas câblée : le fallback français passe '
            'en silence (aucune garde de libellés en dur ne bronche — le '
            'fallback EST du français légitime côté source).',
      );
      expect(find.text('Sans réponse'), findsNothing);
    });

    testWidgets('🔴 EXAMEN `submitted` — le RÉSULTAT est une région LIVE (il '
        'est ANNONCÉ, pas seulement affiché)', (tester) async {
      // 🔴 Défaut MESURÉ : l'écran de fin est inséré à l'index 0 de la
      // `ListView`, AU-DESSUS de la position de lecture. Sans `liveRegion`,
      // RIEN n'était annoncé : le focus restait près du bas, et l'apprenant
      // non-voyant devait DEVINER que son examen avait été noté, puis remonter
      // toute la liste à l'aveugle pour trouver son score.
      await pumpExam(
        tester,
        phase: ZExamViewPhase.submitted,
        result: const ZStudySessionResult(
          mode: ZReviewMode.whiteExam,
          total: 2,
          correct: 1,
          byQuality: <String, int>{'5': 1, '0': 1},
        ),
      );
      expect(find.byKey(ZListSessionView.resultKey), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(ZListSessionView.resultKey))
            .hasFlag(SemanticsFlag.isLiveRegion),
        isTrue,
        reason: '🔴 le résultat de l\'examen — précisément l\'information que '
            'l\'apprenant attend à cet instant — n\'est annoncé par AUCUN '
            'canal.',
      );
    });

    testWidgets('🔴 EXAMEN — UN SEUL nœud de progression, portant UN SEUL '
        'nombre (AC1 : aucun compteur parallèle)', (tester) async {
      // 🔴 Défaut MESURÉ : `_ProgressHeader` enveloppait
      // `ZSessionProgressIndicator` — qui porte DÉJÀ son nœud — dans un SECOND
      // `Semantics(label:, value:)`. Les deux annonçaient des nombres qui ne
      // s'accordaient JAMAIS (`0/2` contre `1/2` ; `1/2` contre `2/2`) :
      // l'apprenant non-voyant entendait deux progressions consécutives
      // contradictoires, sans moyen de savoir laquelle est vraie.
      //
      // ⚠️ Le second nœud était INJOIGNABLE par `find.byKey` (aucune `key`) —
      // c'est ce qui l'a soustrait à l'énumération de libellés.
      //
      // 🔴 **ET C'EST CE QUI REND CE TEST DÉLICAT À ÉCRIRE.** Une assertion
      // `getSemantics(progressKey).value == '1/2'` serait **TAUTOLOGIQUE** —
      // MESURÉ : un `Semantics(value:)` enveloppant crée un nœud **SÉPARÉ**
      // (pas de fusion sans `mergeAllDescendants`), si bien que le nœud du
      // composant continue de dire `1/2` **pendant que le parent annonce
      // `0/2`**. La garde reste verte, le défaut vit. Il faut donc **compter
      // les nœuds** de l'arbre entier, pas interroger un nœud choisi d'avance.
      await pumpExam(tester, phase: ZExamViewPhase.running);

      // Scan RÉCURSIF de tout l'arbre sémantique : quels nœuds annoncent une
      // progression (`value` de forme `n/m`) ?
      final progressValues = <String>[];
      final counter = RegExp(r'^\d+/\d+$');
      void visit(SemanticsNode node) {
        final value = node.getSemanticsData().value;
        if (counter.hasMatch(value)) progressValues.add(value);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);

      // 🔒 Contre-preuve de NON-VACUITÉ : le scan VOIT réellement quelque chose
      // (sans quoi « un seul nœud » serait faux… ou vrai par cécité).
      expect(
        progressValues,
        isNotEmpty,
        reason: '🔴 le scan sémantique ne voit AUCUNE progression : il ne '
            'garde rien.',
      );
      expect(
        progressValues,
        hasLength(1),
        reason: '🔴 DEUX nœuds annoncent une progression ($progressValues) et '
            'ne s\'accordent JAMAIS : su-7 comptait `submissions.length` '
            '(réponses données), su-4 compte `(currentIndex+1).clamp(1,total)` '
            '(position courante). L\'apprenant non-voyant entend « 0 sur 2 » '
            'puis « 1 sur 2 » — sans moyen de savoir lequel est vrai. AC1 : '
            '`_ProgressHeader` doit RELAYER, jamais PUBLIER.',
      );
      expect(progressValues.single, '1/2');
    });

    testWidgets('🔴 EXAMEN — l\'arbre se construit en RTL sans exception',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: ZListSessionView(
                  cards: <ZFlashcard>[_card('a')],
                  phase: ZExamViewPhase.running,
                  onAnswered: (_, __) {},
                  onSubmit: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(ZListSessionView.submitKey), findsOneWidget);
    });

    testWidgets('🔴 EXAMEN — l\'état VIDE porte un libellé issu de ZcrudLabels',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: ZcrudLabels(const <String, String>{
              'zcrud.study.exam.empty': 'L10N_EXAM_EMPTY',
            }),
            child: Scaffold(
              body: ZListSessionView(
                cards: const <ZFlashcard>[],
                phase: ZExamViewPhase.running,
                onAnswered: (_, __) {},
                onSubmit: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(ZListSessionView.emptyKey)).data,
        'L10N_EXAM_EMPTY',
        reason: '🔴 l\'état vide affiche un littéral au lieu du libellé injecté',
      );
    });
  });

  group('🔴 AC7/AC10/AC13 — ZTestFiltersDialog : chaque contrôle est ACTIONNÉ '
      'et l\'on assert le PAYLOAD REÇU par l\'hôte', () {
    // 🔴 240 lignes publiques, exportées, ZÉRO test (code-review su-6 / D2).
    // Deux mutations restaient silencieuses : inverser `_levels.add`/`.remove`
    // (cocher « Maîtrisées » DÉSÉLECTIONNAIT le seau ⇒ l'apprenant lance un test
    // « maîtrisées » et reçoit TOUT SAUF les maîtrisées), ou popper
    // `widget.initial` au lieu du composé (TOUTE la sélection jetée à la
    // validation). Dans les deux cas : analyze RC=0, 441/441 VERT, verify vert.
    // C'est le patron nommé par la story elle-même (leçon su-4 : le bouton
    // « précédent » qui AVANÇAIT, vert car jamais tapé) — à l'échelle d'un
    // widget entier.

    /// Monte le dialog et capture **ce que `Navigator.pop` rend à l'hôte**.
    Future<List<ZFlashcardTestFilters?>> open(
      WidgetTester tester, {
      ZFlashcardTestFilters initial = const ZFlashcardTestFilters(),
      List<String> availableSources = const <String>[],
      int minQuestionCount = 1,
      int maxQuestionCount = 100,
    }) async {
      final popped = <ZFlashcardTestFilters?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  popped.add(
                    await showDialog<ZFlashcardTestFilters>(
                      context: context,
                      builder: (_) => ZTestFiltersDialog(
                        initial: initial,
                        availableSources: availableSources,
                        minQuestionCount: minQuestionCount,
                        maxQuestionCount: maxQuestionCount,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      return popped;
    }

    testWidgets('🔴 chaque seau TAPÉ est RETENU (add/remove inversé ⇒ rouge) — '
        'ZMasteryLevel.values ÉNUMÉRÉ', (tester) async {
      for (final level in ZMasteryLevel.values) {
        final popped = await open(tester);

        await tester.tap(find.byKey(ZTestFiltersDialog.masteryKey(level)));
        await tester.pump();
        await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
        await tester.pumpAndSettle();

        // 🔴 Le PAYLOAD REÇU, pas la présence du widget.
        expect(
          popped.single!.masteryLevels,
          equals(<ZMasteryLevel>{level}),
          reason: '🔴 cocher $level ne le retient PAS (add/remove inversé ?)',
        );
      }
    });

    testWidgets('🔴 dé-cocher RETIRE le seau (l\'aller-retour complet)',
        (tester) async {
      final popped = await open(
        tester,
        initial: const ZFlashcardTestFilters(
          masteryLevels: <ZMasteryLevel>{
            ZMasteryLevel.bad,
            ZMasteryLevel.mastered,
          },
        ),
      );

      await tester.tap(find.byKey(ZTestFiltersDialog.masteryKey(ZMasteryLevel.bad)));
      await tester.pump();
      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(
        popped.single!.masteryLevels,
        equals(<ZMasteryLevel>{ZMasteryLevel.mastered}),
      );
    });

    testWidgets('🔴 les SOURCES tapées sont retenues (registre ouvert AD-4)',
        (tester) async {
      final popped = await open(
        tester,
        availableSources: <String>['pdf', 'web'],
      );

      await tester.tap(find.byKey(ZTestFiltersDialog.sourceKey('web')));
      await tester.pump();
      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(popped.single!.sources, equals(<String>{'web'}));
    });

    testWidgets('🔴 « Annuler » ⇒ null : AUCUN filtre n\'est rendu, même après '
        'une sélection', (tester) async {
      final popped = await open(tester);

      await tester.tap(
        find.byKey(ZTestFiltersDialog.masteryKey(ZMasteryLevel.good)),
      );
      await tester.pump();
      await tester.tap(find.byKey(ZTestFiltersDialog.cancelKey));
      await tester.pumpAndSettle();

      expect(popped.single, isNull, reason: '🔴 « Annuler » a rendu des filtres');
    });

    testWidgets('🔴 FR-SU12 — le NOMBRE DE QUESTIONS est RÉGLABLE : le stepper '
        'change le payload REÇU (défaut 10)', (tester) async {
      final popped = await open(tester);

      // Défaut FR-SU12 : 10 — VISIBLE à l'œil, pas seulement dans `initial`.
      expect(
        tester
            .getSemantics(find.byKey(ZTestFiltersDialog.questionCountKey))
            .value,
        equals('10'),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ZTestFiltersDialog.questionCountIncrementKey));
        await tester.pump();
      }
      await tester.tap(find.byKey(ZTestFiltersDialog.questionCountDecrementKey));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.byKey(ZTestFiltersDialog.questionCountKey))
            .value,
        equals('12'),
        reason: '🔴 la valeur annoncée ne suit pas les taps',
      );

      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();

      // 🔴 LA preuve que le champ n'est pas un pass-through mort : l'apprenant
      // qui veut 12 questions les OBTIENT.
      expect(popped.single!.questionCount, equals(12));
    });

    testWidgets('🔴 le stepper est BORNÉ : aux bornes, le bouton est désactivé '
        'ET annoncé comme tel (jamais inerte en silence)', (tester) async {
      final popped = await open(
        tester,
        initial: const ZFlashcardTestFilters(questionCount: 2),
        minQuestionCount: 2,
        maxQuestionCount: 3,
      );

      final dec = find.byKey(ZTestFiltersDialog.questionCountDecrementKey);
      final inc = find.byKey(ZTestFiltersDialog.questionCountIncrementKey);

      expect(tester.getSemantics(dec).hasFlag(SemanticsFlag.isEnabled), isFalse,
          reason: '🔴 à la borne basse, « moins » se dit encore actif');
      expect(tester.getSemantics(inc).hasFlag(SemanticsFlag.isEnabled), isTrue);

      await tester.tap(dec, warnIfMissed: false);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.byKey(ZTestFiltersDialog.questionCountKey))
            .value,
        equals('2'),
        reason: '🔴 la borne basse a été franchie',
      );

      await tester.tap(inc);
      await tester.pump();
      expect(tester.getSemantics(inc).hasFlag(SemanticsFlag.isEnabled), isFalse,
          reason: '🔴 à la borne haute, « plus » se dit encore actif');

      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(popped.single!.questionCount, equals(3));
    });

    testWidgets('AD-10 — un `initial.questionCount` HORS BORNES est borné, '
        'jamais de throw', (tester) async {
      final popped = await open(
        tester,
        initial: const ZFlashcardTestFilters(questionCount: 9999),
        maxQuestionCount: 20,
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(popped.single!.questionCount, equals(20));
    });

    testWidgets('AC13 — availableSources VIDE ⇒ aucune bascule de source, '
        'aucun throw', (tester) async {
      await open(tester);

      expect(find.byKey(ZTestFiltersDialog.sourceKey('pdf')), findsNothing);
      expect(tester.takeException(), isNull);
      // Les seaux, eux, restent là.
      for (final level in ZMasteryLevel.values) {
        expect(find.byKey(ZTestFiltersDialog.masteryKey(level)), findsOneWidget);
      }
    });

    testWidgets('AC14 — les cibles tactiles du dialog sont >= 48 dp (AD-13) — '
        'ÉNUMÉRÉES', (tester) async {
      await open(tester, availableSources: <String>['pdf']);

      final keys = <ValueKey<String>>[
        for (final level in ZMasteryLevel.values)
          ZTestFiltersDialog.masteryKey(level),
        ZTestFiltersDialog.sourceKey('pdf'),
        ZTestFiltersDialog.questionCountDecrementKey,
        ZTestFiltersDialog.questionCountIncrementKey,
      ];

      for (final key in keys) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: '$key : cible de ${size.height} dp < 48 dp (AD-13)');
      }
    });

    testWidgets('AC14 — RTL : le dialog se construit sans exception',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ZTestFiltersDialog(availableSources: <String>['pdf']),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(ZTestFiltersDialog.confirmKey), findsOneWidget);
    });
  });

  group('🔴 AC6 — le toast passe par le port ZToaster (jamais un SnackBar)', () {
    /// Monte un bouton qui déclenche `zShowStreakToast` sous un `ZToasterScope`
    /// portant l'espion.
    Future<void> pumpToast(
      WidgetTester tester,
      _SpyToaster spy,
      ZStreakAdvance advance, {
      ZcrudLabels? labels,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: labels,
            child: ZToasterScope(
              toaster: spy,
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => zShowStreakToast(context, advance),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
    }

    testWidgets('🔴 (1) L\'ESPION CAPTE RÉELLEMENT : `incremented` ⇒ 1 appel '
        '— À PROUVER AVANT toute assertion à 0', (tester) async {
      // 🔴 Sans cette preuve préalable, un espion DÉBRANCHÉ verrait « 0 appel »
      // et les tests « aucun toast » ci-dessous seraient INFALSIFIABLES.
      final spy = _SpyToaster();

      await pumpToast(
        tester,
        spy,
        const ZStreakAdvance(
          streak: ZStudyStreak(current: 4, best: 6, lastGradedDay: '2026-03-29'),
          outcome: ZStreakOutcome.incremented,
        ),
      );

      expect(spy.calls, hasLength(1), reason: '🔴 espion NON branché');
      expect(spy.calls.single.severity, equals(ZToastSeverity.success));
      // 🔴 `isNotEmpty` ne pinnait RIEN : un message réduit à « Série en cours »
      // (compteur disparu) restait vert. Le COMPTEUR est le contenu même de
      // FR-SU11 — on l'assert.
      expect(spy.calls.single.message, contains('4'),
          reason: '🔴 le toast n\'annonce PAS le nombre de jours (FR-SU11)');
    });

    testWidgets('🔴 D4 — le COMPTEUR SURVIT À LA LOCALISATION : une app qui '
        'fournit la clé voit toujours son nombre', (tester) async {
      // 🔴 Défaut MESURÉ (code-review su-6, D4). `label()` n'a AUCUNE
      // substitution de paramètre : le `$current` n'existait que dans le
      // `fallback` EN DUR. Dès qu'une app fournissait
      // `zcrud.study.streak.incremented` — LA raison d'être de la clé — `label()`
      // rendait sa traduction et le NOMBRE DISPARAISSAIT silencieusement.
      // Latent seulement parce que `_enLabels` ne porte pas la clé.
      final spy = _SpyToaster();

      await pumpToast(
        tester,
        spy,
        const ZStreakAdvance(
          streak: ZStudyStreak(current: 4, best: 6, lastGradedDay: '2026-03-29'),
          outcome: ZStreakOutcome.incremented,
        ),
        // Une traduction RÉELLE : aucune ne peut contenir le nombre.
        labels: ZcrudLabels(<String, String>{
          'zcrud.study.streak.incremented': 'Streak',
        }),
      );

      expect(spy.calls.single.message, contains('Streak'),
          reason: '🔴 le libellé injecté n\'est pas consommé (libellé en dur ?)');
      expect(
        spy.calls.single.message,
        contains('4'),
        reason: '🔴 LE défaut D4 : le compteur ne survit pas à la localisation. '
            'Le nombre doit être composé HORS de `label()` (patron du badge : '
            'libellé statique localisable + nombre dans un canal séparé).',
      );
    });

    testWidgets('(2) `started` ⇒ 1 appel, severity success', (tester) async {
      final spy = _SpyToaster();

      await pumpToast(
        tester,
        spy,
        const ZStreakAdvance(
          streak: ZStudyStreak(current: 1, best: 1, lastGradedDay: '2026-03-29'),
          outcome: ZStreakOutcome.started,
        ),
      );

      expect(spy.calls, hasLength(1));
      expect(spy.calls.single.severity, equals(ZToastSeverity.success));
    });

    testWidgets('(3) `resetToOne` ⇒ 1 appel, severity WARNING (série rompue, '
        'pas une erreur)', (tester) async {
      final spy = _SpyToaster();

      await pumpToast(
        tester,
        spy,
        const ZStreakAdvance(
          streak: ZStudyStreak(current: 1, best: 9, lastGradedDay: '2026-03-29'),
          outcome: ZStreakOutcome.resetToOne,
        ),
      );

      expect(spy.calls, hasLength(1));
      expect(spy.calls.single.severity, equals(ZToastSeverity.warning));
    });

    testWidgets('🔴 (4) `alreadyCountedToday` ⇒ AUCUN toast (pas de spam à '
        'chaque carte)', (tester) async {
      final spy = _SpyToaster();

      await pumpToast(
        tester,
        spy,
        const ZStreakAdvance(
          streak: ZStudyStreak(current: 4, best: 6, lastGradedDay: '2026-03-29'),
          outcome: ZStreakOutcome.alreadyCountedToday,
        ),
      );

      // Probant UNIQUEMENT parce que le test (1) a prouvé que l'espion capte.
      expect(spy.calls, isEmpty);
    });

    testWidgets('🔴 (5) `skippedNotGraded` ⇒ AUCUN toast', (tester) async {
      final spy = _SpyToaster();

      await pumpToast(
        tester,
        spy,
        const ZStreakAdvance(
          streak: ZStudyStreak(current: 4, best: 6),
          outcome: ZStreakOutcome.skippedNotGraded,
        ),
      );

      expect(spy.calls, isEmpty);
    });

    testWidgets('AD-10 : SANS ZToasterScope monté ⇒ repli sûr, aucun throw',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => zShowStreakToast(
                  context,
                  const ZStreakAdvance(
                    streak: ZStudyStreak(current: 2, best: 2),
                    outcome: ZStreakOutcome.incremented,
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // `ZToasterScope.of` retombe sur `ZScaffoldMessengerToaster` — jamais de
      // throw (AD-10), sans une ligne de code défensif de notre part.
      expect(tester.takeException(), isNull);
    });

    test('🔴 la règle « pas de spam » est ÉNUMÉRABLE : les 5 outcomes sont '
        'classés (un 6ᵉ forcerait une décision)', () {
      const expected = <ZStreakOutcome, ZToastSeverity?>{
        ZStreakOutcome.started: ZToastSeverity.success,
        ZStreakOutcome.incremented: ZToastSeverity.success,
        ZStreakOutcome.resetToOne: ZToastSeverity.warning,
        ZStreakOutcome.alreadyCountedToday: null,
        ZStreakOutcome.skippedNotGraded: null,
      };

      // Énumère l'enum RÉEL : jamais une liste recopiée.
      for (final outcome in ZStreakOutcome.values) {
        expect(
          zStreakToastSeverityFor(outcome),
          equals(expected[outcome]),
          reason: '$outcome mal classé',
        );
      }
      expect(expected, hasLength(ZStreakOutcome.values.length));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 🔴 AC7/AC14 — CONTRASTE RÉELLEMENT MESURÉ (WCAG AA ≥ 4,5:1)
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Pourquoi ce groupe existe (code-review su-6, ÉCART-2 — MAJEUR) :
  //
  // `ZStreakBadge` peignait `pair.color` — le rôle de **FOND** de la `ZColorPair`
  // — en PREMIER PLAN, sans peindre aucun fond : `primaryContainer` sur
  // `surface`, **1,23:1** mesuré, contre les 4,5:1 de WCAG AA. Le défaut a
  // survécu à AC7 **DEUX FOIS** — non pas parce qu'AC7 était muette, mais parce
  // qu'AUCUN test ne mesurait un contraste : toute la suite (456 tests) restait
  // VERTE avec une flamme invisible à l'œil. Un `expect(find.byType(Icon),
  // findsOneWidget)` ne voit pas une couleur.
  //
  // Ce que ce groupe mesure — et pourquoi il ne peut pas être trompé :
  // - il énumère **TOUS les `RichText` réellement peints** du sous-arbre. `Text`
  //   ET `Icon` rendent l'un comme l'autre via `RichText` (une icône est un
  //   glyphe de police) : les deux puits de l'ÉCART-2 sont donc couverts par le
  //   même balayage, sans liste de widgets à tenir à jour ;
  // - il lit la couleur sur le `RenderParagraph` — le style **FUSIONNÉ**, ce qui
  //   est effectivement peint — jamais la valeur passée au constructeur ;
  // - il remonte au **fond réellement peint** (`DecoratedBox`/`ColoredBox`/
  //   `Material` opaque le plus proche) : un widget qui ne peint AUCUN fond est
  //   mesuré contre la surface du `Scaffold`, ce qui est exactement ce que voit
  //   l'utilisateur — et exactement ce qui rendait le badge illisible ;
  // - il balaie **clair ET sombre** : une paire peut être conforme dans un thème
  //   et pas dans l'autre.
  //
  // 🔒 Un défaut est un MOTIF : ce groupe ÉNUMÈRE les écrans, il ne teste pas le
  // seul badge. C'est ce qui a démasqué le compte de `_ModeTile`
  // (`z_session_mode_selector.dart`) — le MÊME défaut, **1,23:1** lui aussi, à
  // deux fichiers du badge, que personne n'avait signalé.
  group('🔴 AC7/AC14 — contraste ≥ 4,5:1 (WCAG AA) sur TOUT ce qui est peint',
      () {
    /// Luminance relative WCAG 2.x d'une couleur **opaque**.
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    /// Ratio de contraste WCAG entre deux couleurs opaques (1:1 … 21:1).
    double contrast(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    /// Fond **réellement peint** derrière [e] : le premier ancêtre opaque.
    /// `null` si rien n'est peint (le test échoue alors bruyamment plutôt que
    /// de sauter la mesure — un puits « sauté » est un puits non gardé).
    Color? paintedBackgroundOf(Element e) {
      Color? found;
      e.visitAncestorElements((ancestor) {
        final w = ancestor.widget;
        if (w is DecoratedBox) {
          final d = w.decoration;
          if (d is BoxDecoration && d.color != null && d.color!.a == 1.0) {
            found = d.color;
            return false;
          }
        } else if (w is ColoredBox && w.color.a == 1.0) {
          found = w.color;
          return false;
        } else if (w is Material && w.color != null && w.color!.a == 1.0) {
          found = w.color;
          return false;
        }
        return true;
      });
      return found;
    }

    /// Mesure CHAQUE `RichText` peint et exige ≥ 4,5:1.
    void assertAllContrasts(WidgetTester tester, String screen) {
      final targets = find.byType(RichText).evaluate();
      expect(targets, isNotEmpty,
          reason: '🔴 $screen : aucun RichText peint — la garde ne mesurerait '
              'RIEN et resterait verte. Sonde cassée.');

      for (final element in targets) {
        final paragraph = element.renderObject! as RenderParagraph;
        final text = paragraph.text.toPlainText();
        final foreground = paragraph.text.style?.color;
        expect(foreground, isNotNull,
            reason: '🔴 $screen : « $text » n\'a AUCUNE couleur de premier plan '
                'fusionnée — impossible de mesurer un contraste.');

        final background = paintedBackgroundOf(element);
        expect(background, isNotNull,
            reason: '🔴 $screen : « $text » n\'a AUCUN fond opaque derrière lui '
                '— impossible de garantir sa lisibilité.');

        final ratio = contrast(foreground!, background!);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '🔴 $screen : « $text » est peint à '
              '${ratio.toStringAsFixed(2)}:1 — WCAG AA exige 4,5:1.\n'
              '  premier plan : $foreground\n'
              '  fond         : $background\n'
              'Cause quasi certaine : `pair.color` (le rôle de FOND de la '
              '`ZColorPair`) utilisé en PREMIER PLAN. Le contrat du cœur '
              '(`z_color_key_resolver.dart:216`) est : `pair.color` = fond, '
              '`pair.onColor` = premier plan lisible. Patron canonique : '
              '`z_session_quality_breakdown.dart:174-192`.',
        );
      }
    }

    /// Les écrans du diff qui consomment une `ZColorPair`. ÉNUMÉRÉS : ajouter
    /// un écran ici est le seul geste nécessaire pour l'y soumettre.
    final screens = <String, Widget>{
      'ZSessionModeSelector (+ ZStreakBadge)': ZSessionModeSelector(
        cards: <ZFlashcard>[_card('neuf'), _card('due')],
        srsById: zIndexSrsById(<ZRepetitionInfo>[
          _due('due', at.subtract(const Duration(days: 2))),
        ]),
        at: at,
        streak: const ZStudyStreak(current: 3, best: 5),
        onOpenFilters: () {},
        onStart: (_, __) {},
      ),
      'ZTestFiltersDialog': const ZTestFiltersDialog(
        availableSources: <String>['pdf'],
      ),
      'ZSessionQualityBreakdown': ZSessionQualityBreakdown(
        byQuality: const <String, int>{'0': 1, '2': 3, '5': 2},
        scale: ZQualityScale.fromConfig(const ZSrsConfig()),
        passThreshold: 3,
      ),
      'ZSrsQualityButtons': ZSrsQualityButtons(
        scale: ZQualityScale.fromConfig(const ZSrsConfig()),
        passThreshold: 3,
        onQualitySelected: (_) {},
      ),
      // 🔴 SU-7 (AC7) — l'écran d'examen blanc, AJOUTÉ ICI.
      //
      // ⚠️ **Prémisse de la story CORRIGÉE sur disque** : la story annonçait que
      // cette garde « énumère tous les `RichText` et couvrira automatiquement les
      // nouveaux widgets ». C'est **FAUX** — et c'est vérifiable trois lignes
      // plus haut : elle énumère **les ÉCRANS** (`screens`), et n'énumère les
      // `RichText` qu'**À L'INTÉRIEUR** de chacun. Un écran non listé n'est
      // **jamais** mesuré. Compter sur l'« automatisme » aurait laissé su-7
      // **entièrement non gardé** en contraste — exactement le trou de su-6.
      // Le commentaire du `screens` le dit d'ailleurs lui-même : « ajouter un
      // écran ici est le SEUL geste nécessaire ».
      'ZListSessionView (examen blanc)': ZListSessionView(
        cards: <ZFlashcard>[_card('a'), _card('b')],
        phase: ZExamViewPhase.running,
        onAnswered: (_, __) {},
        onSubmit: () {},
      ),
    };

    for (final brightness in Brightness.values) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} — ${brightness.name} : tout est lisible',
            (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF6750A4),
                  brightness: brightness,
                ),
              ),
              home: ZcrudScope(
                child: Scaffold(body: Center(child: entry.value)),
              ),
            ),
          );
          assertAllContrasts(tester, '${entry.key} [${brightness.name}]');
        });
      }
    }
  });
}
