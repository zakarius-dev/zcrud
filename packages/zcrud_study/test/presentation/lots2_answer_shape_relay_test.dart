/// **Les quatre réglages de FORME de la surface de saisie, relayés par
/// l'assemblage** — porteur, page, et preset de session.
///
/// ## Le défaut visé
///
/// La surface de saisie sait depuis peu changer de forme : ligne de choix en
/// tuile, contrôles d'aide côte à côte, soumission pleine largeur, rangée de
/// paliers montée avant la réponse. Aucun de ces réglages n'atteignait
/// l'assemblage : un hôte qui monte l'écran de session — et non la surface —
/// ne pouvait les poser qu'en **réimplémentant** la surface entière par
/// `gradingBuilder`, c'est-à-dire en reperdant l'évaluation, les indices, la
/// correction, la notation et le verrou one-shot pour changer trois formes.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZFlashcardAnswerInput>(…).choiceLayout` resterait
/// vert le jour où la surface cesserait d'en tenir compte : ce serait mesurer
/// le **passage** d'une valeur, jamais son **effet**. Chaque garde cherche
/// donc le cadre réellement monté, la clé réellement présente, la largeur
/// réellement mise en page, ou la notation réellement émise — et chacune porte
/// sa contre-preuve (sans le réglage, la mesure est autre).
///
/// ## Inertie ABSOLUE
///
/// Les montages « historiques » n'énoncent **aucun** des quatre réglages, pas
/// même à leur valeur de référence : les énoncer court-circuiterait le défaut
/// du constructeur, et une injection qui changerait ce défaut passerait sous
/// une garde restée verte. L'arbre rendu est comparé en **égalité stricte** à
/// des dumps capturés sur disque **avant** l'écriture du lot.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZChoice, ZFlashcard, ZFlashcardHintPort, ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardAnswerInput, ZSessionReviewer, ZSrsQualityButtons;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/lotw1_seams.dart' show W1HintPort;
import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

// ── Clés de la surface de saisie ────────────────────────────────────────────
// Littérales : elles appartiennent à des widgets PRIVÉS de `zcrud_session` et
// ne sont pas nommables d'ici. Les mêmes que les autres gardes du paquet.

const ValueKey<String> kField = ValueKey<String>('zAnswerField');
const ValueKey<String> kSubmit = ValueKey<String>('zSubmit');
const ValueKey<String> kHint = ValueKey<String>('zHintButton');
const ValueKey<String> kDontKnow = ValueKey<String>('zDontKnow');

ValueKey<String> kChoice(int i) => ValueKey<String>('zAnswerChoice_$i');

Finder _quality(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

// ── Cartes ──────────────────────────────────────────────────────────────────

ZFlashcard _mcq(String id) => ZFlashcard(
      id: id,
      folderId: kHarnessFolderId,
      type: ZFlashcardType.multipleChoice,
      question: 'Question $id.',
      answer: 'a',
      choices: const <ZChoice>[
        ZChoice(content: 'a', isCorrect: true),
        ZChoice(content: 'b'),
      ],
    );

List<ZFlashcard> mcqCards(int n) =>
    <ZFlashcard>[for (int i = 0; i < n; i++) _mcq('c$i')];

// ── Sondes de RENDU ─────────────────────────────────────────────────────────

/// Les cadres de TUILE réellement montés autour d'une ligne de choix.
///
/// Cherchés par DESCENDANCE de la clé du choix — jamais par position — et
/// reconnus à leur `shape` : hors disposition tuile, aucune `Material` du
/// sous-arbre d'un choix n'en porte.
Iterable<Material> _tileFrames(WidgetTester tester, int index) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byKey(kChoice(index)),
        matching: find.byType(Material),
      ),
    )
    .where((Material m) => m.shape != null);

/// Largeur RÉELLEMENT mise en page du contrôle de soumission, rapportée à
/// celle de la surface qui le contient.
({double submit, double surface}) _submitWidths(WidgetTester tester) => (
      submit: tester.getSize(find.byKey(kSubmit)).width,
      surface: tester.getSize(find.byType(ZFlashcardAnswerInput)).width,
    );

/// Le dump ordonné des types de widgets montés — égalité STRICTE, jamais
/// `contains` ni un décompte : un nœud intercalé se voit à la position.
List<String> _dump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Le dump figé sur disque AVANT le lot.
List<String> _baseline(String scene) {
  final File file = File('${zsrc.packageRoot().path}/test/support/'
      'z_answer_shape_tree_before_lots2_$scene.txt');
  if (!file.existsSync()) {
    throw StateError('dump de référence introuvable : ${file.path} — la garde '
        'd\'inertie ne mesure plus rien');
  }
  return file.readAsLinesSync();
}


// ── Montage ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) =>
    MaterialApp(home: ZcrudScope(child: Scaffold(body: child)));

Widget _wrapPage(Widget page) => MaterialApp(home: ZcrudScope(child: page));

/// Soumet une réponse rédigée.
Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(find.byKey(kField), 'ma réponse');
  await tester.pump();
  await tester.tap(find.byKey(kSubmit));
  await tester.pumpAndSettle();
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // Inertie ABSOLUE
  // ═════════════════════════════════════════════════════════════════════════
  group('🧊 inertie ABSOLUE — aucun réglage énoncé ⇒ arbre identique', () {
    test('les dumps de référence sont non vides et portent la surface', () {
      const List<String> scenes = <String>['written', 'mcq', 'quality', 'page'];
      for (final String scene in scenes) {
        final List<String> dump = _baseline(scene);
        expect(dump, isNotEmpty, reason: 'dump vide : $scene');
        expect(dump, contains('ZFlashcardAnswerInput'),
            reason: '🔴 un dump sans surface de saisie ne prouverait rien : '
                '$scene');
      }
    });

    testWidgets('porteur, cartes rédigées : arbre strictement identique',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(mode: ZReviewMode.list, queue: writtenCards(2)),
      ));
      await tester.pumpAndSettle();
      expect(_dump(tester), _baseline('written'),
          reason: '🔴 un réglage de forme a changé l\'arbre alors qu\'aucun '
              'n\'est énoncé (AD-4)');
    });

    testWidgets('porteur, cartes à choix : arbre strictement identique',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(mode: ZReviewMode.list, queue: mcqCards(2)),
      ));
      await tester.pumpAndSettle();
      expect(_dump(tester), _baseline('mcq'),
          reason: '🔴 la ligne de choix a changé de forme sans qu\'on le '
              'demande');
    });

    testWidgets('porteur, voie de notation posée : arbre strictement identique',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.learn,
          queue: writtenCards(2),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (int q) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(_dump(tester), _baseline('quality'),
          reason: '🔴 la rangée de paliers est montée avant la réponse alors '
              'que rien ne l\'a demandé — l\'ordre des gestes a changé');
    });

    testWidgets('page : arbre strictement identique',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrapPage(
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(1),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_dump(tester), _baseline('page'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Relais — porteur puis page, la même mesure aux deux étages
  // ═════════════════════════════════════════════════════════════════════════
  const List<({String etage, bool page})> niveaux =
      <({String etage, bool page})>[
    (etage: 'porteur', page: false),
    (etage: 'page', page: true),
  ];
  for (final ({String etage, bool page}) niveau in niveaux) {
    Future<void> pump(
      WidgetTester tester, {
      required List<ZFlashcard> queue,
      required ZReviewMode mode,
      ZSessionReviewer? reviewer,
      ZFlashcardHintPort? hintPort,
      ValueChanged<int>? onQualitySelected,
      ZAnswerChoiceLayout? answerChoiceLayout,
      ZAnswerActionsLayout? answerActionsLayout,
      ZAnswerSubmitWidth? answerSubmitWidth,
      ZAnswerGradingVisibility? answerGradingVisibility,
      ZStudySessionPreset? preset,
    }) async {
      useTallSurface(tester);
      // Les quatre réglages sont énoncés ici — mais à `null` quand l'appelant
      // n'en pose pas, ce qui est EXACTEMENT le défaut du constructeur : les
      // gardes d'inertie ci-dessus, elles, ne les énoncent pas du tout.
      await tester.pumpWidget(
        niveau.page
            ? _wrapPage(ZStudySessionScaffold(
                title: 'Session',
                mode: mode,
                queue: queue,
                reviewer: reviewer,
                hintPort: hintPort,
                onQualitySelected: onQualitySelected,
                answerChoiceLayout: answerChoiceLayout,
                answerActionsLayout: answerActionsLayout,
                answerSubmitWidth: answerSubmitWidth,
                answerGradingVisibility: answerGradingVisibility,
                preset: preset,
              ))
            : _wrap(ZStudySessionHost(
                mode: mode,
                queue: queue,
                reviewer: reviewer,
                hintPort: hintPort,
                onQualitySelected: onQualitySelected,
                answerChoiceLayout: answerChoiceLayout,
                answerActionsLayout: answerActionsLayout,
                answerSubmitWidth: answerSubmitWidth,
                answerGradingVisibility: answerGradingVisibility,
                preset: preset,
              )),
      );
      await tester.pumpAndSettle();
    }

    group('🎛 relais par le ${niveau.etage} — mesuré au RENDU', () {
      testWidgets('sans `answerChoiceLayout` : AUCUN cadre de tuile '
          '(non-vacuité)', (WidgetTester tester) async {
        await pump(tester, queue: mcqCards(1), mode: ZReviewMode.list);
        expect(find.byKey(kChoice(0)), findsOneWidget);
        expect(_tileFrames(tester, 0), isEmpty);
      });

      testWidgets('`tile` : le CADRE de tuile est monté dans la surface',
          (WidgetTester tester) async {
        await pump(
          tester,
          queue: mcqCards(1),
          mode: ZReviewMode.list,
          answerChoiceLayout: ZAnswerChoiceLayout.tile,
        );
        final Iterable<Material> frames = _tileFrames(tester, 0);
        expect(frames, hasLength(1),
            reason: '🔴 la disposition de choix n\'atteint pas la surface de '
                'saisie montée par l\'assemblage');
        final RoundedRectangleBorder shape =
            frames.single.shape! as RoundedRectangleBorder;
        expect(shape.side.width, greaterThan(0),
            reason: 'un cadre sans trait ne serait pas une tuile');
      });

      testWidgets('sans `answerActionsLayout` : AUCUNE ligne d\'aide '
          '(non-vacuité)', (WidgetTester tester) async {
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.list,
          hintPort: W1HintPort(),
        );
        expect(find.byKey(kHint), findsOneWidget);
        expect(find.byKey(kDontKnow), findsOneWidget);
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing);
      });

      testWidgets('`sideBySide` : la LIGNE des deux contrôles d\'aide est '
          'montée', (WidgetTester tester) async {
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.list,
          hintPort: W1HintPort(),
          answerActionsLayout: ZAnswerActionsLayout.sideBySide,
        );
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsOneWidget,
            reason: '🔴 la disposition des contrôles d\'aide n\'atteint pas '
                'la surface');
        // Géométrie MISE EN PAGE : les deux contrôles partagent une bande.
        final Rect hint = tester.getRect(find.byKey(kHint));
        final Rect dontKnow = tester.getRect(find.byKey(kDontKnow));
        expect(hint.top, dontKnow.top,
            reason: 'côte à côte ⇒ même bande verticale');
      });

      testWidgets('sans `answerSubmitWidth` : soumission au CONTENU '
          '(non-vacuité)', (WidgetTester tester) async {
        await pump(tester, queue: writtenCards(1), mode: ZReviewMode.list);
        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsNothing,
        );
        final ({double submit, double surface}) w = _submitWidths(tester);
        expect(w.submit, lessThan(w.surface));
      });

      testWidgets('`full` : la soumission occupe la LARGEUR ENTIÈRE',
          (WidgetTester tester) async {
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.list,
          answerSubmitWidth: ZAnswerSubmitWidth.full,
        );
        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsOneWidget,
          reason: '🔴 la largeur de soumission n\'atteint pas la surface',
        );
        final ({double submit, double surface}) w = _submitWidths(tester);
        expect(w.submit, w.surface);
      });

      testWidgets('sans `answerGradingVisibility` : AUCUNE rangée avant la '
          'réponse (non-vacuité)', (WidgetTester tester) async {
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.learn,
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (int q) {},
        );
        expect(find.byType(ZSrsQualityButtons), findsNothing);
        expect(find.byKey(kSubmit), findsOneWidget);
      });

      testWidgets('`always` : la rangée est montée AVANT la réponse, et un '
          'cran tapé vaut UNE notation, une seule (AD-33)',
          (WidgetTester tester) async {
        final List<int> taps = <int>[];
        final FakeSessionReviewer reviewer = FakeSessionReviewer();
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.learn,
          reviewer: reviewer.call,
          onQualitySelected: taps.add,
          answerGradingVisibility: ZAnswerGradingVisibility.always,
        );
        expect(find.byType(ZSrsQualityButtons), findsOneWidget,
            reason: '🔴 le moment d\'apparition de la rangée n\'atteint pas '
                'la surface');
        expect(find.byKey(kSubmit), findsOneWidget,
            reason: 'avant tout geste, la soumission est encore là');

        await tester.tap(_quality(5));
        await tester.pumpAndSettle();
        expect(taps, <int>[5],
            reason: '🔴 le cran tapé avant la réponse n\'atteint pas l\'hôte');
        expect(reviewer.writes, 0,
            reason: '🔒 AD-33 — la rangée NOTIFIE, elle n\'écrit pas de SRS');
        expect(find.byKey(kSubmit), findsNothing,
            reason: '🔴 la notation manuelle n\'a pas verrouillé la surface');

        // Second geste : le verrou tient, aucune SECONDE notation.
        await tester.tap(_quality(0), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(taps, <int>[5],
            reason: '🔴 deux notations pour une carte notée à la main');
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // Preset — `.classic` pose les quatre formes, un paramètre les bat
    // ═══════════════════════════════════════════════════════════════════════
    group('🎁 `.classic` posé sur le ${niveau.etage}', () {
      testWidgets('les quatre formes sont montées',
          (WidgetTester tester) async {
        final List<int> taps = <int>[];
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.learn,
          reviewer: FakeSessionReviewer().call,
          hintPort: W1HintPort(),
          onQualitySelected: taps.add,
          preset: ZStudySessionPreset.classic(),
        );
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsOneWidget,
            reason: '🔴 `.classic` ne pose pas la ligne des contrôles d\'aide');
        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsOneWidget,
          reason: '🔴 `.classic` ne pose pas la soumission pleine largeur',
        );
        expect(find.byType(ZSrsQualityButtons), findsOneWidget,
            reason: '🔴 `.classic` ne pose pas la rangée montée d\'emblée');
      });

      testWidgets('la ligne de choix devient une tuile',
          (WidgetTester tester) async {
        await pump(
          tester,
          queue: mcqCards(1),
          mode: ZReviewMode.list,
          preset: ZStudySessionPreset.classic(),
        );
        expect(_tileFrames(tester, 0), hasLength(1),
            reason: '🔴 `.classic` ne pose pas la tuile de choix');
      });

      testWidgets('un preset NU ne pose aucune des quatre formes (AD-4)',
          (WidgetTester tester) async {
        final List<int> taps = <int>[];
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.learn,
          reviewer: FakeSessionReviewer().call,
          hintPort: W1HintPort(),
          onQualitySelected: taps.add,
          preset: const ZStudySessionPreset(),
        );
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing);
        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsNothing,
        );
        expect(find.byType(ZSrsQualityButtons), findsNothing);
      });
    });

    group('🥇 priorité sur le ${niveau.etage} — le PARAMÈTRE bat `.classic`',
        () {
      testWidgets('`compact` explicite bat la tuile du preset',
          (WidgetTester tester) async {
        await pump(
          tester,
          queue: mcqCards(1),
          mode: ZReviewMode.list,
          answerChoiceLayout: ZAnswerChoiceLayout.compact,
          preset: ZStudySessionPreset.classic(),
        );
        expect(_tileFrames(tester, 0), isEmpty,
            reason: '🔴 le preset a gagné sur le paramètre explicite');
      });

      testWidgets('`stacked` explicite bat la ligne du preset',
          (WidgetTester tester) async {
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.list,
          hintPort: W1HintPort(),
          answerActionsLayout: ZAnswerActionsLayout.stacked,
          preset: ZStudySessionPreset.classic(),
        );
        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing,
            reason: '🔴 le preset a gagné sur le paramètre explicite');
      });

      testWidgets('`content` explicite bat la pleine largeur du preset',
          (WidgetTester tester) async {
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.list,
          answerSubmitWidth: ZAnswerSubmitWidth.content,
          preset: ZStudySessionPreset.classic(),
        );
        expect(
          find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
          findsNothing,
          reason: '🔴 le preset a gagné sur le paramètre explicite',
        );
      });

      testWidgets('`afterSubmit` explicite bat l\'ordre des gestes du preset',
          (WidgetTester tester) async {
        final List<int> taps = <int>[];
        await pump(
          tester,
          queue: writtenCards(1),
          mode: ZReviewMode.learn,
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: taps.add,
          answerGradingVisibility: ZAnswerGradingVisibility.afterSubmit,
          preset: ZStudySessionPreset.classic(),
        );
        expect(find.byType(ZSrsQualityButtons), findsNothing,
            reason: '🔴 le preset a gagné sur le paramètre explicite — '
                'l\'ordre des gestes a changé sans qu\'on le demande');
        await _submit(tester);
        expect(find.byType(ZSrsQualityButtons), findsOneWidget,
            reason: 'la rangée revient APRÈS la soumission : sans cela, la '
                'garde ci-dessus serait vraie par disparition de la rangée');
      });
    });
  }
}
