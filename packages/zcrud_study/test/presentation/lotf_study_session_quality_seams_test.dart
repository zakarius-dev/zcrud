/// **Lot F « étude »** — relais des seams de présentation de la rangée de
/// notation, de [ZStudySessionHost] jusqu'à la surface de saisie.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Une garde qui retrouverait `ZSrsQualityButtons` par `find.byType`, ou qui
/// lirait le champ `colorKeyFor` du widget monté, resterait **VERTE alors même
/// que le seam ne produirait rien** : elle mesurerait le passage du paramètre,
/// pas son effet. Chaque garde ci-dessous lit donc la **couleur réellement
/// peinte** (`Material.color`), l'**épaisseur de bord réellement posée**
/// (`RoundedRectangleBorder.side.width`) ou le **texte réellement rendu**.
///
/// ## La précondition de montage
///
/// Mesuré sur disque avant ce lot : `grep -rn "onQualitySelected" lib/` rendait
/// **zéro** occurrence. L'assemblage montait donc une surface de saisie SANS
/// voie de notation manuelle, et la rangée de crans — la seule chose que les
/// quatre seams peignent — n'entrait jamais dans l'arbre. Relayer les quatre
/// seams sans cette précondition aurait livré quatre commandes mortes.
///
/// 🔒 Cette voie n'écrit rien dans le SRS : l'écriture de révision reste la
/// soumission (invariant AD-33). Les gardes le vérifient par le compteur du
/// faux `ZSessionReviewer`.
///
/// ## Le trou d'inertie déjà payé en amont
///
/// Les montages « historiques » de ce fichier n'énoncent **aucun** des cinq
/// nouveaux paramètres, pas même à sa valeur neutre : les énoncer
/// court-circuiterait le défaut du constructeur, et l'injection R3 qui change
/// ce défaut passerait sous une garde restée verte.
@TestOn('vm')
library;

import 'package:dartz/dartz.dart' show Right;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;
import 'package:zcrud_core/zcrud_core.dart' show ZcrudLabels, ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcardAnswerEvaluation,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardAnswerEvaluationRequest,
        ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZFlashcardAnswerInput,
        ZQualityScale,
        ZSrsQualityButtons;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

const ZSrsConfig _config = ZSrsConfig();

/// Port d'évaluation espion — pré-sélectionne le cran 4 (advisory).
class _SpyPort implements ZFlashcardAnswerEvaluationPort {
  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async =>
      Right<ZFailure, ZFlashcardAnswerEvaluation>(
        const ZFlashcardAnswerEvaluation(
          feedback: 'retour du barème',
          suggestedQuality: 4,
        ),
      );
}

Widget _wrap(Widget child, {ZcrudLabels? labels}) => MaterialApp(
      home: ZcrudScope(
        labels: labels,
        child: Scaffold(body: child),
      ),
    );

Finder _button(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

Material _material(WidgetTester tester, int q) => tester.widget<Material>(
      find.descendant(of: _button(q), matching: find.byType(Material)).first,
    );

Color _paintedColor(WidgetTester tester, int q) => _material(tester, q).color!;

double _borderWidth(WidgetTester tester, int q) {
  final shape = _material(tester, q).shape! as RoundedRectangleBorder;
  return shape.side.width;
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ZSrsQualityButtons))).colorScheme;

/// Mène la session jusqu'à la correction — seul état où la rangée existe.
Future<void> _submit(WidgetTester tester, {bool expectRow = true}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('zAnswerField')),
    'ma réponse',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
  await tester.pumpAndSettle();
  if (expectRow) {
    expect(
      find.byType(ZSrsQualityButtons),
      findsOneWidget,
      reason: 'la rangée doit être montée pour que la garde mesure quoi que '
          'ce soit',
    );
  }
}

/// Montage de l'assemblage AVEC les seams posés.
Future<FakeSessionReviewer> _pumpSeams(
  WidgetTester tester, {
  required List<int> taps,
  ZQualityLabelKeyResolver qualityLabelKeyFor = zDefaultQualityLabelKey,
  ZQualityColorKeyResolver? qualityColorKeyFor,
  String Function(int quality)? qualityPreviewLabelFor,
  ZSrsQualityEmphasis qualityEmphasis = ZSrsQualityEmphasis.none,
  ZcrudLabels? labels,
}) async {
  useTallSurface(tester);
  final reviewer = FakeSessionReviewer();
  await tester.pumpWidget(
    _wrap(
      ZStudySessionHost(
        mode: ZReviewMode.learn,
        queue: writtenCards(1),
        reviewer: reviewer.call,
        evaluationPort: _SpyPort(),
        onQualitySelected: taps.add,
        qualityLabelKeyFor: qualityLabelKeyFor,
        qualityColorKeyFor: qualityColorKeyFor,
        qualityPreviewLabelFor: qualityPreviewLabelFor,
        qualityEmphasis: qualityEmphasis,
      ),
      labels: labels,
    ),
  );
  await tester.pumpAndSettle();
  await _submit(tester);
  return reviewer;
}

/// Montage HISTORIQUE : aucun des cinq nouveaux paramètres n'est énoncé.
Future<FakeSessionReviewer> _pumpLegacy(WidgetTester tester) async {
  useTallSurface(tester);
  final reviewer = FakeSessionReviewer();
  await tester.pumpWidget(
    _wrap(
      ZStudySessionHost(
        mode: ZReviewMode.learn,
        queue: writtenCards(1),
        reviewer: reviewer.call,
        evaluationPort: _SpyPort(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _submit(tester, expectRow: false);
  return reviewer;
}

/// Dump ORDONNÉ des types du sous-arbre de la surface de saisie.
List<String> _inputDump(WidgetTester tester) => tester.allWidgets
    .where(
      (Widget w) => find
          .descendant(
            of: find.byType(ZFlashcardAnswerInput),
            matching: find.byWidget(w),
            matchRoot: true,
          )
          .evaluate()
          .isNotEmpty,
    )
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

void main() {
  group('🔴 précondition — la rangée n\'est montée QUE sur opt-in', () {
    testWidgets('sans `onQualitySelected`, la rangée est ABSENTE (AD-4)',
        (tester) async {
      await _pumpLegacy(tester);
      expect(find.byType(ZSrsQualityButtons), findsNothing);
    });

    testWidgets('avec `onQualitySelected`, la rangée est montée ET vivante',
        (tester) async {
      final taps = <int>[];
      final reviewer = await _pumpSeams(tester, taps: taps);
      final writesBefore = reviewer.writes;
      await tester.tap(_button(5));
      await tester.pumpAndSettle();
      expect(taps, <int>[5],
          reason: '🔴 la commande relayée porte le cran EXACT tapé — sinon '
              'c\'est une commande morte');
      expect(reviewer.writes, writesBefore,
          reason: '🔒 AD-33 — la rangée NOTIFIE, elle n\'écrit pas une '
              'seconde note');
    });
  });

  group('Relais de `qualityColorKeyFor` — la COULEUR PEINTE change', () {
    testWidgets('chaque cran est peint avec la couleur de SA clé',
        (tester) async {
      await _pumpSeams(
        tester,
        taps: <int>[],
        qualityColorKeyFor: (int q) => q >= 4 ? 'tertiary' : 'neutral',
      );
      final ColorScheme scheme = _scheme(tester);
      for (var q = 0; q <= 5; q++) {
        expect(
          _paintedColor(tester, q),
          q >= 4 ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
          reason: 'le cran $q doit être peint avec la couleur de sa clé',
        );
      }
      // …et ces couleurs ne sont PAS celles de la dérivation par défaut.
      expect(_paintedColor(tester, 5), isNot(scheme.primaryContainer));
      expect(_paintedColor(tester, 0), isNot(scheme.errorContainer));
    });

    testWidgets('sans le seam, la dérivation `passThreshold` est intacte',
        (tester) async {
      await _pumpSeams(tester, taps: <int>[]);
      final ColorScheme scheme = _scheme(tester);
      expect(_paintedColor(tester, 5), scheme.primaryContainer);
      expect(_paintedColor(tester, 0), scheme.errorContainer);
    });
  });

  group('Relais de `qualityPreviewLabelFor` — l\'APERÇU est RENDU', () {
    testWidgets('chaque cran rend l\'aperçu de SA qualité', (tester) async {
      await _pumpSeams(
        tester,
        taps: <int>[],
        qualityPreviewLabelFor: (int q) => '↺ ${q}j',
      );
      for (var q = 0; q <= 5; q++) {
        expect(
          find.descendant(of: _button(q), matching: find.text('↺ ${q}j')),
          findsOneWidget,
          reason: 'le cran $q doit rendre l\'aperçu de sa propre qualité',
        );
      }
    });

    testWidgets('sans le seam, AUCUN aperçu n\'est rendu', (tester) async {
      await _pumpSeams(tester, taps: <int>[]);
      // Un cran sans aperçu ne rend QUE son libellé : un second `Text` frère
      // signalerait un aperçu fabriqué par l'assemblage.
      expect(
        find.descendant(of: _button(0), matching: find.byType(Text)),
        findsOneWidget,
      );
    });
  });

  group('Relais de `qualityEmphasis` — FOND et BORD peints changent', () {
    testWidgets('`fillOpacity` et `borderWidth` sont réellement appliqués',
        (tester) async {
      await _pumpSeams(
        tester,
        taps: <int>[],
        qualityEmphasis: const ZSrsQualityEmphasis(
          fillOpacity: 0.25,
          selectedFillOpacity: 0.5,
          borderWidth: 3,
          selectedBorderWidth: 4,
        ),
      );
      final ColorScheme scheme = _scheme(tester);
      expect(_paintedColor(tester, 0).a, closeTo(0.25, 0.01));
      expect(_paintedColor(tester, 0).r, scheme.errorContainer.r);
      expect(_borderWidth(tester, 0), 3);
      // Cran 4 : pré-sélectionné (suggestion du port espion).
      expect(_paintedColor(tester, 4).a, closeTo(0.5, 0.01));
      expect(_borderWidth(tester, 4), 4);
    });

    testWidgets('sans le seam, fond PLEIN et AUCUN bord', (tester) async {
      await _pumpSeams(tester, taps: <int>[]);
      expect(_paintedColor(tester, 0).a, 1.0);
      expect(_borderWidth(tester, 0), 0);
      expect(_borderWidth(tester, 4), 0);
    });
  });

  group('Relais de `qualityLabelKeyFor` — le TEXTE rendu change', () {
    testWidgets('une clé applicative résolue par le scope est rendue',
        (tester) async {
      await _pumpSeams(
        tester,
        taps: <int>[],
        qualityLabelKeyFor: (int q) => 'app.palier.$q',
        labels: ZcrudLabels(<String, String>{
          'app.palier.5': 'PARFAIT',
          'app.palier.0': 'ENCORE',
        }),
      );
      expect(
        find.descendant(of: _button(5), matching: find.text('PARFAIT')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _button(0), matching: find.text('ENCORE')),
        findsOneWidget,
      );
    });

    testWidgets('sans le seam, la clé HISTORIQUE reste la source',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      final taps = <int>[];
      await tester.pumpWidget(
        _wrap(
          // Seule la précondition de montage est posée : le seam de libellé,
          // lui, n'est pas énoncé — c'est son DÉFAUT qui est mesuré.
          ZStudySessionHost(
            mode: ZReviewMode.learn,
            queue: writtenCards(1),
            reviewer: reviewer.call,
            evaluationPort: _SpyPort(),
            onQualitySelected: taps.add,
          ),
          labels: ZcrudLabels(<String, String>{
            'zcrud.srs.quality.5': 'HISTORIQUE',
            'app.palier.5': 'PARFAIT',
          }),
        ),
      );
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(
        find.descendant(of: _button(5), matching: find.text('HISTORIQUE')),
        findsOneWidget,
      );
      expect(find.text('PARFAIT'), findsNothing);
    });
  });

  group('`gradingBuilder` fourni — les seams NE S\'APPLIQUENT PAS', () {
    testWidgets(
        '🔴 le constructeur de l\'hôte rend seul : ni surface par défaut, ni '
        'rangée de crans, malgré les cinq paramètres posés', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        _wrap(
          ZStudySessionHost(
            mode: ZReviewMode.learn,
            queue: writtenCards(1),
            reviewer: reviewer.call,
            evaluationPort: _SpyPort(),
            onQualitySelected: (_) {},
            qualityLabelKeyFor: (int q) => 'app.palier.$q',
            qualityColorKeyFor: (int q) => 'tertiary',
            qualityPreviewLabelFor: (int q) => '↺ ${q}j',
            qualityEmphasis: const ZSrsQualityEmphasis(borderWidth: 3),
            gradingBuilder: (_, _, _) =>
                const Text('notation de l\'hôte'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('notation de l\'hôte'), findsOneWidget);
      // 🔴 Le cœur de la garde : les seams n'ont AUCUN point d'application.
      expect(find.byType(ZFlashcardAnswerInput), findsNothing,
          reason: 'la surface par défaut n\'est pas montée — les seams n\'ont '
              'rien à traverser');
      expect(find.byType(ZSrsQualityButtons), findsNothing);
      expect(find.textContaining('↺'), findsNothing,
          reason: 'aucun aperçu ne doit apparaître : c\'est l\'hôte qui rend');
    });
  });

  group('INERTIE — un hôte qui ne pose rien obtient l\'arbre historique', () {
    testWidgets(
        'séquence de widgets STRICTEMENT égale au montage nu de la surface',
        (tester) async {
      // 1. L'assemblage, sans aucun des cinq nouveaux paramètres.
      await _pumpLegacy(tester);
      final List<String> assembled = _inputDump(tester);

      // 2. La surface montée NUE, avec exactement les paramètres que
      //    l'assemblage lui passait avant ce lot.
      await tester.pumpWidget(
        _wrap(
          ZFlashcardAnswerInput(
            key: const ValueKey<String>('zStudySessionAnswer_c0'),
            card: writtenCard('c0', answer: 'r0'),
            mode: ZReviewMode.learn,
            srsConfig: _config,
            evaluationPort: _SpyPort(),
            onSubmitted: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _submit(tester, expectRow: false);
      final List<String> bare = _inputDump(tester);

      // Égalité STRICTE — jamais `contains`, jamais `length <=`.
      expect(assembled, equals(bare));
    });

    testWidgets('les slots non posés restent ABSENTS, jamais un objet vide',
        (tester) async {
      await _pumpLegacy(tester);
      final ZFlashcardAnswerInput input = tester.widget<ZFlashcardAnswerInput>(
        find.byType(ZFlashcardAnswerInput),
      );
      expect(input.onQualitySelected, isNull);
      expect(input.qualityColorKeyFor, isNull);
      expect(input.qualityPreviewLabelFor, isNull);
      expect(input.qualityEmphasis, same(ZSrsQualityEmphasis.none));
      expect(input.qualityLabelKeyFor, same(zDefaultQualityLabelKey));
    });

    testWidgets('l\'échelle rendue reste celle de `config` (AD-46)',
        (tester) async {
      await _pumpSeams(tester, taps: <int>[]);
      final ZSrsQualityButtons row =
          tester.widget<ZSrsQualityButtons>(find.byType(ZSrsQualityButtons));
      expect(row.scale, ZQualityScale.fromConfig(_config));
      expect(row.passThreshold, _config.passThreshold);
    });
  });
}
