/// AC1 (CŒUR) — `ZSrsQualityButtons` : mapping cran→qualité EXACT + intervalle
/// prévisionnel issu de `ZSm2Scheduler.simulate` (jamais recalculé en dur).
/// AC4 (label injecté) + AC5 (a11y ≥ 48 dp + Semantics) + AC6 (passThreshold).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

Widget _wrap(Widget child, {ZcrudLabels? labels}) => MaterialApp(
      home: ZcrudScope(
        labels: labels,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('AC1 — mapping cran → qualité EXACT (discriminant INJ-1)', () {
    testWidgets('taper le cran q appelle onQualitySelected(q) — pour chaque q',
        (tester) async {
      final captured = <int>[];
      await tester.pumpWidget(_wrap(
        ZSrsQualityButtons(
          scale: const ZQualityScale(min: 0, max: 5),
          passThreshold: 3,
          onQualitySelected: captured.add,
        ),
      ));

      for (var q = 0; q <= 5; q++) {
        await tester.tap(
          find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q')),
        );
        await tester.pump();
        expect(captured.last, q,
            reason: 'cran visuel $q doit noter la qualité $q (mapping D6)');
      }
      expect(captured, <int>[0, 1, 2, 3, 4, 5]);
    });

    testWidgets('le seam previewLabelFor est appelé avec la qualité du cran',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ZSrsQualityButtons(
          scale: const ZQualityScale(min: 0, max: 5),
          passThreshold: 3,
          onQualitySelected: (_) {},
          previewLabelFor: (q) => 'PREVIEW_$q',
        ),
      ));
      // Chaque cran affiche EXACTEMENT le marqueur de SA qualité : un mapping
      // inversé (cran 5 → previewLabelFor(0)) ou un intervalle en dur ROUGIT.
      for (var q = 0; q <= 5; q++) {
        final buttonKey =
            ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q');
        expect(
          find.descendant(
            of: find.byKey(buttonKey),
            matching: find.text('PREVIEW_$q'),
          ),
          findsOneWidget,
          reason: 'le cran $q doit rendre le preview de la qualité $q',
        );
      }
    });
  });

  group('AC1(b) — intervalle prévisionnel = ZSm2Scheduler.simulate', () {
    testWidgets('l\'intervalle affiché == simulate(current, q).interval',
        (tester) async {
      const scheduler = ZSm2Scheduler();
      const current = ZRepetitionInfo(
        flashcardId: 'card-1',
        folderId: 'folder-1',
        interval: 10,
        repetitions: 2,
      );
      final now = DateTime(2026, 7, 15);
      String preview(int q) =>
          'J+${scheduler.simulate(current, q, now: now).interval}';

      await tester.pumpWidget(_wrap(
        ZSrsQualityButtons(
          scale: const ZQualityScale(min: 0, max: 5),
          passThreshold: 3,
          onQualitySelected: (_) {},
          previewLabelFor: preview,
        ),
      ));

      for (var q = 0; q <= 5; q++) {
        final expected =
            'J+${scheduler.simulate(current, q, now: now).interval}';
        final buttonKey =
            ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q');
        expect(
          find.descendant(
            of: find.byKey(buttonKey),
            matching: find.text(expected),
          ),
          findsOneWidget,
          reason: 'cran $q doit afficher l\'intervalle de simulate ($expected)',
        );
      }
    });
  });

  group('AC5 — a11y : cible ≥ 48 dp + Semantics bouton', () {
    testWidgets('chaque bouton a une cible ≥ 48 dp et un Semantics button',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZSrsQualityButtons(
          scale: const ZQualityScale(min: 0, max: 5),
          passThreshold: 3,
          onQualitySelected: (_) {},
        ),
      ));

      for (var q = 0; q <= 5; q++) {
        final finder =
            find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48),
            reason: 'cran $q : largeur < 48 dp');
        expect(size.height, greaterThanOrEqualTo(48),
            reason: 'cran $q : hauteur < 48 dp');
        // Le bouton EXPOSE bien le flag isButton + une action tap (l'InkWell
        // ajoute aussi focus/isFocusable, hors périmètre de l'assertion). Le
        // widget `Semantics` explicite du cran porte `button: true`.
        final semantics = tester.widget<Semantics>(
          find
              .descendant(of: finder, matching: find.byType(Semantics))
              .first,
        );
        expect(semantics.properties.button, isTrue,
            reason: 'cran $q : Semantics button manquant');
      }
      handle.dispose();
    });
  });

  group('AC4 — label INJECTÉ via l10n (jamais en dur, discriminant INJ-4)', () {
    testWidgets('un label surchargé via ZcrudScope.labels est rendu',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ZSrsQualityButtons(
          scale: const ZQualityScale(min: 0, max: 5),
          passThreshold: 3,
          onQualitySelected: (_) {},
        ),
        labels: ZcrudLabels(<String, String>{
          'zcrud.srs.quality.5': 'PARFAIT',
        }),
      ));
      // Le libellé du cran 5 provient de l10n injectée : un « Facile » en dur
      // ne serait PAS surchargeable ⇒ ce test ROUGIT (INJ-4).
      expect(find.text('PARFAIT'), findsOneWidget);
    });
  });

  group('AC6 — passThreshold INJECTÉ (discriminant INJ-6)', () {
    testWidgets('passThreshold: 4 déplace la frontière réussite/lapse',
        (tester) async {
      // Avec passThreshold 4, le cran 3 devient un LAPSE : son Semantics.value
      // porte « lapse » (et non « ok »). Un `>= 3` en dur ROUGIT ici.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZSrsQualityButtons(
          scale: const ZQualityScale(min: 0, max: 5),
          passThreshold: 4,
          onQualitySelected: (_) {},
        ),
      ));
      final node3 = tester.getSemantics(
        find.byKey(const ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}3')),
      );
      expect(node3.value, contains('lapse'));
      final node4 = tester.getSemantics(
        find.byKey(const ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}4')),
      );
      expect(node4.value, contains('ok'));
      handle.dispose();
    });
  });

  group('ZQualityScale — value-object', () {
    test('qualities est ordonné croissant et borné', () {
      expect(const ZQualityScale(min: 0, max: 5).qualities,
          <int>[0, 1, 2, 3, 4, 5]);
      expect(const ZQualityScale(min: 1, max: 5).qualities,
          <int>[1, 2, 3, 4, 5]);
      expect(const ZQualityScale(min: 1, max: 5).contains(0), isFalse);
      expect(const ZQualityScale(min: 0, max: 5) == const ZQualityScale(),
          isTrue);
    });
  });
}
