/// Relais des seams de présentation de `ZSrsQualityButtons` par
/// `ZFlashcardAnswerInput` — mesuré sur l'EFFET RENDU, jamais sur le passage
/// du paramètre.
///
/// Pourquoi cette précaution : une garde qui se contenterait de retrouver le
/// widget `ZSrsQualityButtons` par `find.byType` (ou même d'y lire son champ
/// `colorKeyFor`) resterait VERTE si le relais existait sans rien produire.
/// Chaque garde ci-dessous lit donc la COULEUR RÉELLEMENT PEINTE (`Material.color`),
/// l'ÉPAISSEUR DE BORD réellement posée (`RoundedRectangleBorder.side.width`)
/// ou le TEXTE réellement rendu.
///
/// La garde d'inertie compare l'assemblage par défaut à un montage NU de
/// `ZSrsQualityButtons` avec les seuls paramètres historiques : égalité
/// STRICTE de la séquence de widgets et des couleurs peintes.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

const ZSrsConfig _config = ZSrsConfig();

Widget _host(Widget child, {ZcrudLabels? labels}) => MaterialApp(
  home: ZcrudScope(
    labels: labels,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Finder _button(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

/// Le `Material` peint d'un cran — c'est lui qui porte la couleur et le bord.
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

/// Mène la surface montée jusqu'à la correction : c'est la seule façon
/// d'obtenir la rangée de notation dans l'assemblage de production.
Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(find.byKey(K.answerField), 'ma réponse');
  await tester.pump();
  await tester.tap(find.byKey(K.submit));
  await tester.pumpAndSettle();
  expect(
    find.byType(ZSrsQualityButtons),
    findsOneWidget,
    reason: 'la rangée de notation doit être montée pour que la garde mesure',
  );
}

/// Montage de l'assemblage AVEC les nouveaux seams posés.
Future<void> _pumpSeams(
  WidgetTester tester, {
  ZQualityLabelKeyResolver qualityLabelKeyFor = zDefaultQualityLabelKey,
  ZQualityColorKeyResolver? qualityColorKeyFor,
  String Function(int quality)? qualityPreviewLabelFor,
  ZSrsQualityEmphasis qualityEmphasis = ZSrsQualityEmphasis.none,
  ZcrudLabels? labels,
}) async {
  await tester.pumpWidget(
    _host(
      ZFlashcardAnswerInput(
        card: writtenCard(),
        mode: ZReviewMode.learn,
        srsConfig: _config,
        evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
        onQualitySelected: (_) {},
        qualityLabelKeyFor: qualityLabelKeyFor,
        qualityColorKeyFor: qualityColorKeyFor,
        qualityPreviewLabelFor: qualityPreviewLabelFor,
        qualityEmphasis: qualityEmphasis,
      ),
      labels: labels,
    ),
  );
  await _submit(tester);
}

/// Montage HISTORIQUE : aucun des nouveaux paramètres n'est posé, pas même à
/// sa valeur par défaut.
///
/// C'est la différence qui compte : poser explicitement `ZSrsQualityEmphasis.none`
/// depuis le test COURT-CIRCUITERAIT le défaut du constructeur, et une garde
/// d'inertie écrite ainsi resterait verte alors même que le défaut de
/// production aurait changé (mesuré : l'injection R3-I5 passait sous ce trou).
Future<void> _pumpLegacy(WidgetTester tester, {ZcrudLabels? labels}) async {
  await tester.pumpWidget(
    _host(
      ZFlashcardAnswerInput(
        card: writtenCard(),
        mode: ZReviewMode.learn,
        srsConfig: _config,
        evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
        onQualitySelected: (_) {},
      ),
      labels: labels,
    ),
  );
  await _submit(tester);
}

void main() {
  group('Relais de colorKeyFor — la COULEUR PEINTE change', () {
    testWidgets('chaque cran est peint avec la couleur de la clé résolue', (
      tester,
    ) async {
      // Deux clés distinctes, choisies HORS de la dérivation par défaut
      // (`primary`/`error`) : si le seam n'était pas relayé, la rangée
      // peindrait `primaryContainer`/`errorContainer` et ces assertions
      // rougiraient.
      await _pumpSeams(
        tester,
        qualityColorKeyFor: (q) => q >= 4 ? 'tertiary' : 'neutral',
      );
      final scheme = _scheme(tester);
      for (var q = 0; q <= 5; q++) {
        expect(
          _paintedColor(tester, q),
          q >= 4 ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
          reason: 'le cran $q doit être peint avec la couleur de SA clé',
        );
      }
      // …et ces couleurs ne sont PAS celles du défaut : la garde discrimine.
      expect(_paintedColor(tester, 5), isNot(scheme.primaryContainer));
      expect(_paintedColor(tester, 0), isNot(scheme.errorContainer));
    });

    testWidgets('sans le seam, la dérivation passThreshold est intacte', (
      tester,
    ) async {
      await _pumpLegacy(tester);
      final scheme = _scheme(tester);
      expect(_paintedColor(tester, 5), scheme.primaryContainer);
      expect(_paintedColor(tester, 0), scheme.errorContainer);
    });
  });

  group('Relais de previewLabelFor — l\'APERÇU est RENDU', () {
    testWidgets('chaque cran rend l\'aperçu de SA qualité', (tester) async {
      await _pumpSeams(
        tester,
        qualityPreviewLabelFor: (q) => 'APERCU_$q',
      );
      for (var q = 0; q <= 5; q++) {
        expect(
          find.descendant(of: _button(q), matching: find.text('APERCU_$q')),
          findsOneWidget,
          reason: 'le cran $q doit rendre l\'aperçu de sa propre qualité',
        );
      }
    });

    testWidgets('sans le seam, aucun aperçu n\'est rendu', (tester) async {
      await _pumpLegacy(tester);
      // Un cran sans aperçu ne rend QUE son libellé (plus l'icône de coche du
      // cran pré-sélectionné) : deux `Text` frères signaleraient un aperçu
      // fabriqué par la surface.
      expect(
        find.descendant(of: _button(0), matching: find.byType(Text)),
        findsOneWidget,
      );
    });
  });

  group('Relais de emphasis — le FOND et le BORD peints changent', () {
    testWidgets('fillOpacity et borderWidth sont réellement appliqués', (
      tester,
    ) async {
      await _pumpSeams(
        tester,
        qualityEmphasis: const ZSrsQualityEmphasis(
          fillOpacity: 0.25,
          selectedFillOpacity: 0.5,
          borderWidth: 3,
          selectedBorderWidth: 4,
        ),
      );
      final scheme = _scheme(tester);
      // Cran 0 : ordinaire ⇒ opacité 0.25, bord 3.
      expect(_paintedColor(tester, 0).a, closeTo(0.25, 0.01));
      expect(_paintedColor(tester, 0).r, scheme.errorContainer.r);
      expect(_borderWidth(tester, 0), 3);
      // Cran 4 : pré-sélectionné (suggestedQuality du port) ⇒ 0.5 / 4.
      expect(_paintedColor(tester, 4).a, closeTo(0.5, 0.01));
      expect(_borderWidth(tester, 4), 4);
    });

    testWidgets('sans le seam, fond plein et AUCUN bord', (tester) async {
      await _pumpLegacy(tester);
      expect(_paintedColor(tester, 0).a, 1.0);
      expect(_borderWidth(tester, 0), 0);
      expect(_borderWidth(tester, 4), 0);
    });
  });

  group('Relais de labelKeyFor — le TEXTE rendu change', () {
    testWidgets('une clé applicative résolue par le scope est rendue', (
      tester,
    ) async {
      await _pumpSeams(
        tester,
        qualityLabelKeyFor: (q) => 'app.palier.$q',
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

    testWidgets('sans le seam, la clé historique reste la source', (
      tester,
    ) async {
      await _pumpLegacy(
        tester,
        labels: ZcrudLabels(<String, String>{
          'zcrud.srs.quality.5': 'HISTORIQUE',
          'app.palier.5': 'PARFAIT',
        }),
      );
      expect(
        find.descendant(of: _button(5), matching: find.text('HISTORIQUE')),
        findsOneWidget,
      );
      expect(find.text('PARFAIT'), findsNothing);
    });
  });

  group('INERTIE — un hôte qui ne pose rien obtient l\'arbre historique', () {
    testWidgets(
      'séquence de widgets et couleurs peintes STRICTEMENT égales au montage nu',
      (tester) async {
        // 1. L'assemblage, sans aucun des nouveaux paramètres.
        await _pumpLegacy(tester);
        final assembled = tester
            .allWidgets
            .where(
              (w) => find
                  .descendant(
                    of: find.byType(ZSrsQualityButtons),
                    matching: find.byWidget(w),
                    matchRoot: true,
                  )
                  .evaluate()
                  .isNotEmpty,
            )
            .map((w) => w.runtimeType.toString())
            .toList();
        final assembledColors = <int, Color>{
          for (var q = 0; q <= 5; q++) q: _paintedColor(tester, q),
        };
        final assembledBorders = <int, double>{
          for (var q = 0; q <= 5; q++) q: _borderWidth(tester, q),
        };

        // 2. Le montage NU, avec les seuls paramètres historiques et la même
        //    pré-sélection (cran 4 = suggestion du port espion).
        await tester.pumpWidget(
          _host(
            ZSrsQualityButtons(
              scale: ZQualityScale.fromConfig(_config),
              passThreshold: _config.passThreshold,
              selectedQuality: 4,
              onQualitySelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bare = tester
            .allWidgets
            .where(
              (w) => find
                  .descendant(
                    of: find.byType(ZSrsQualityButtons),
                    matching: find.byWidget(w),
                    matchRoot: true,
                  )
                  .evaluate()
                  .isNotEmpty,
            )
            .map((w) => w.runtimeType.toString())
            .toList();
        final bareColors = <int, Color>{
          for (var q = 0; q <= 5; q++) q: _paintedColor(tester, q),
        };
        final bareBorders = <int, double>{
          for (var q = 0; q <= 5; q++) q: _borderWidth(tester, q),
        };

        // Égalité STRICTE — jamais `contains`, jamais `<=`.
        expect(assembled, equals(bare));
        expect(assembledColors, equals(bareColors));
        expect(assembledBorders, equals(bareBorders));
      },
    );

    testWidgets('les slots non posés restent ABSENTS, jamais un objet vide', (
      tester,
    ) async {
      await _pumpLegacy(tester);
      final row = tester.widget<ZSrsQualityButtons>(
        find.byType(ZSrsQualityButtons),
      );
      expect(row.colorKeyFor, isNull);
      expect(row.previewLabelFor, isNull);
      expect(row.emphasis, same(ZSrsQualityEmphasis.none));
      expect(row.labelKeyFor, same(zDefaultQualityLabelKey));
    });
  });
}
