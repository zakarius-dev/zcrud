/// **Géométrie de progression relayée jusqu'au preset** — la forme de la
/// progression se décrit une fois, et l'écran la peint.
///
/// ## Le défaut visé
///
/// L'écran de session choisissait le **style** de sa progression sans pouvoir
/// en régler la **forme** : ni la taille d'un point, ni l'élongation du point
/// courant, ni l'écart entre deux points, ni l'épaisseur d'une barre. Un hôte
/// qui voulait la forme de sa référence visuelle n'avait qu'une issue —
/// remplacer la pile entière par la sienne, et perdre du même coup tout ce que
/// le socle y monte.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZSessionCardSwiper>(…).progressDotsGeometry`
/// resterait vert le jour où l'indicateur cesserait d'en tenir compte : ce
/// serait mesurer le **passage** d'un paramètre, pas la forme obtenue. Chaque
/// garde ci-dessous mesure la **géométrie réellement mise en page** — le
/// rectangle d'un point, l'écart entre deux points, la hauteur d'une barre —
/// et porte sa contre-preuve : sans la description, la forme est celle du
/// défaut, et elle en diffère.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionDotsGeometry, ZSessionProgressIndicator, ZSessionProgressStyle;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/lotw1_seams.dart';
import '../support/lotw2_scaffold.dart';
import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Mesures de GÉOMÉTRIE RENDUE — jamais de propriété déclarée
// ═══════════════════════════════════════════════════════════════════════════

Finder _dot(int i) => find.byKey(ValueKey<String>('zProgressDot_$i'));

/// Rectangle RÉELLEMENT mis en page du point [i].
Rect _dotRect(WidgetTester tester, int i) => tester.getRect(_dot(i));

/// Écart RÉELLEMENT mis en page entre deux points voisins.
double _dotGap(WidgetTester tester, int a, int b) =>
    _dotRect(tester, b).left - _dotRect(tester, a).right;

/// Hauteur RÉELLEMENT réservée par la barre segmentée à marqueur.
double _markerHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(ZSessionProgressIndicator.segmentedMarkerKey))
        .height;

/// Hauteur RÉELLEMENT mise en page de la barre continue.
double _linearHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(ZSessionProgressIndicator.linearKey)).height;

/// Le dump figé sur disque AVANT le lot.
List<String> _baseline(ZSessionProgressStyle style) {
  final File file = File('${zsrc.packageRoot().path}/test/support/'
      'z_progress_tree_before_p2c_${style.name}.txt');
  if (!file.existsSync()) {
    throw StateError('dump de référence introuvable : ${file.path} — la garde '
        'd\'inertie ne mesure plus rien');
  }
  return file.readAsLinesSync();
}

List<String> _treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    ZStudySessionScaffold page,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(MaterialApp(home: ZcrudScope(child: page)));
    await tester.pumpAndSettle();
  }

  ZStudySessionScaffold page({
    ZStudySessionPreset? preset,
    ZSessionProgressStyle? progressStyle,
    ZSessionDotsGeometry? progressDotsGeometry,
    double? progressLinearThickness,
    double? progressSegmentedMarkerThickness,
    int cards = 3,
  }) =>
      ZStudySessionScaffold(
        title: 'p2c',
        mode: ZReviewMode.list,
        queue: writtenCards(cards),
        preset: preset,
        progressStyle: progressStyle,
        progressDotsGeometry: progressDotsGeometry,
        progressLinearThickness: progressLinearThickness,
        progressSegmentedMarkerThickness: progressSegmentedMarkerThickness,
      );

  // ═════════════════════════════════════════════════════════════════════════
  // 1. La forme PEINTE — sans description, puis décrite par le preset
  // ═════════════════════════════════════════════════════════════════════════
  group('📐 la géométrie des points RÉELLEMENT mise en page', () {
    testWidgets('sans description : la forme du DÉFAUT (non-vacuité)',
        (tester) async {
      await pumpPage(
        tester,
        page(progressStyle: ZSessionProgressStyle.dots),
      );
      expect(_dotRect(tester, 1).size, const Size(8, 8),
          reason: 'point non courant : carré de `gapM`');
      expect(_dotRect(tester, 0).size, const Size(12, 8),
          reason: 'point courant : 1,5 fois sa hauteur');
      expect(_dotGap(tester, 0, 1), 4, reason: 'écart : `gapS`');
    });

    testWidgets('`ZStudySessionPreset.classic` : la forme de RÉFÉRENCE est '
        'peinte', (tester) async {
      await pumpPage(
        tester,
        page(
          preset: ZStudySessionPreset.classic(
            progressStyle: ZSessionProgressStyle.dots,
          ),
        ),
      );
      expect(_dotRect(tester, 1).size, const Size(14, 10),
          reason: '🔴 la taille décrite par le preset n\'atteint pas le point');
      expect(_dotRect(tester, 0).size, const Size(24, 10),
          reason: '🔴 l\'élongation décrite (2,4 × 10) n\'atteint pas le point '
              'courant');
      expect(_dotGap(tester, 0, 1), 12,
          reason: '🔴 l\'écart décrit n\'atteint pas la file');
    });

    testWidgets('`ZStudySessionPreset.classic` : la file est CENTRÉE et tient '
        'sur une rangée', (tester) async {
      await pumpPage(
        tester,
        page(
          preset: ZStudySessionPreset.classic(
            progressStyle: ZSessionProgressStyle.dots,
          ),
        ),
      );
      // Une seule rangée : les trois points partagent la même ligne de base.
      expect(_dotRect(tester, 2).top, _dotRect(tester, 0).top);
      final Rect indicator =
          tester.getRect(find.byKey(ZSessionProgressIndicator.progressKey));
      final double leftMargin = _dotRect(tester, 0).left - indicator.left;
      final double rightMargin = indicator.right - _dotRect(tester, 2).right;
      expect((leftMargin - rightMargin).abs() < 0.5, isTrue,
          reason: '🔴 la file n\'est pas centrée : marges $leftMargin / '
              '$rightMargin');
    });

    testWidgets('sans description : la file démarre au bord de lecture '
        '(non-vacuité du centrage)', (tester) async {
      await pumpPage(
        tester,
        page(progressStyle: ZSessionProgressStyle.dots),
      );
      final Rect indicator =
          tester.getRect(find.byKey(ZSessionProgressIndicator.progressKey));
      expect(_dotRect(tester, 0).left, indicator.left,
          reason: 'sans quoi le centrage mesuré plus haut ne prouverait rien');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 2. Priorité — le paramètre explicite bat le preset
  // ═════════════════════════════════════════════════════════════════════════
  group('🥇 le paramètre explicite bat le preset', () {
    testWidgets('`progressDotsGeometry` posé : c\'est LUI qui est peint',
        (tester) async {
      await pumpPage(
        tester,
        page(
          preset: ZStudySessionPreset.classic(
            progressStyle: ZSessionProgressStyle.dots,
          ),
          progressDotsGeometry: const ZSessionDotsGeometry(
            inactiveSize: Size(30, 6),
            activeScale: 3,
            gap: 2,
          ),
        ),
      );
      expect(_dotRect(tester, 1).size, const Size(30, 6),
          reason: '🔴 le preset a battu le paramètre explicite');
      expect(_dotRect(tester, 0).size, const Size(18, 6));
      expect(_dotGap(tester, 0, 1), 2);
    });

    testWidgets('`progressSegmentedMarkerThickness` posé : c\'est LUI qui est '
        'réservé', (tester) async {
      await pumpPage(
        tester,
        page(
          preset: ZStudySessionPreset.classic(
            progressStyle: ZSessionProgressStyle.segmentedMarker,
          ),
          progressSegmentedMarkerThickness: 20,
        ),
      );
      // Hauteur réservée = épaisseur + marqueur (de même hauteur).
      expect(_markerHeight(tester), 40,
          reason: '🔴 le preset a battu le paramètre explicite');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 3. Les deux épaisseurs de barre
  // ═════════════════════════════════════════════════════════════════════════
  group('📏 les épaisseurs de barre atteignent la mise en page', () {
    testWidgets('barre segmentée : défaut, puis référence du preset',
        (tester) async {
      await pumpPage(
        tester,
        page(progressStyle: ZSessionProgressStyle.segmentedMarker),
      );
      expect(_markerHeight(tester), 8,
          reason: 'défaut : `gapS` (4) + un marqueur de même hauteur');

      await pumpPage(
        tester,
        page(
          preset: ZStudySessionPreset.classic(
            progressStyle: ZSessionProgressStyle.segmentedMarker,
          ),
        ),
      );
      expect(_markerHeight(tester), 16,
          reason: '🔴 l\'épaisseur de référence (8) n\'atteint pas la barre');
    });

    testWidgets('barre continue : défaut, puis épaisseur demandée',
        (tester) async {
      await pumpPage(
        tester,
        page(progressStyle: ZSessionProgressStyle.linear),
      );
      expect(_linearHeight(tester), 4, reason: 'défaut : `gapS`');

      await pumpPage(
        tester,
        page(
          progressStyle: ZSessionProgressStyle.linear,
          progressLinearThickness: 17,
        ),
      );
      expect(_linearHeight(tester), 17,
          reason: '🔴 l\'épaisseur demandée n\'atteint pas la barre');
    });

    testWidgets('barre continue : le preset la décrit aussi', (tester) async {
      await pumpPage(
        tester,
        page(
          preset: ZStudySessionPreset.classic(
            progressStyle: ZSessionProgressStyle.linear,
            progressLinearThickness: 11,
          ),
        ),
      );
      expect(_linearHeight(tester), 11,
          reason: '🔴 l\'épaisseur décrite par le preset n\'atteint pas la '
              'barre');
    });

    testWidgets('`classic` ne DÉCRIT aucune épaisseur continue par défaut',
        (tester) async {
      expect(ZStudySessionPreset.classic().progressLinearThickness, isNull,
          reason: 'rien n\'est fabriqué pour rien : la référence n\'a mesuré '
              'aucune épaisseur de barre continue');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 4. La page ÉNUMÉRÉE relaie aussi la description
  // ═════════════════════════════════════════════════════════════════════════
  group('🚚 la page énumérée peint la même forme', () {
    testWidgets('`.wired` + preset de référence : la forme est peinte',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          child: ZStudySessionScaffold.wired(
            wiring: lotW2Wiring(LotW1Seams(omit: const <String>{'preset'})),
            title: 'p2c',
            mode: ZReviewMode.list,
            queue: writtenCards(3),
            progressStyle: ZSessionProgressStyle.dots,
            progressDotsGeometry: const ZSessionDotsGeometry(
              inactiveSize: Size(21, 7),
              gap: 9,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_dotRect(tester, 1).size, const Size(21, 7),
          reason: '🔴 la description n\'a pas traversé la page énumérée');
      expect(_dotGap(tester, 0, 1), 9);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 5. Le value-object : égalité, empreinte, description
  // ═════════════════════════════════════════════════════════════════════════
  group('🧮 le preset porte ses trois nouveaux champs dans son identité', () {
    // 🔴 Deux `const` d'arguments identiques sont CANONICALISÉS en un seul
    // objet : une égalité mesurée sur eux serait vraie par identité, et ne
    // dirait rien du `==`. Toutes les instances ci-dessous sont donc bâties
    // hors `const`, sur des valeurs portées par des variables.
    ZStudySessionPreset presetWith({
      required double gap,
      double? linear,
      double? marker,
    }) =>
        ZStudySessionPreset(
          progressDotsGeometry: ZSessionDotsGeometry(gap: gap),
          progressLinearThickness: linear,
          progressSegmentedMarkerThickness: marker,
        );

    test('deux descriptions ÉGALES sans être le même objet', () {
      final ZStudySessionPreset a = presetWith(gap: 12, linear: 3, marker: 8);
      final ZStudySessionPreset b = presetWith(gap: 12, linear: 3, marker: 8);
      expect(identical(a, b), isFalse,
          reason: 'sans quoi l\'égalité serait vraie par identité');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('🔴 une géométrie différente SUFFIT à rompre l\'égalité', () {
      final ZStudySessionPreset a = presetWith(gap: 12);
      final ZStudySessionPreset b = presetWith(gap: 13);
      expect(a, isNot(b),
          reason: '🔴 `==` ignore la géométrie : deux écrans différents se '
              'diraient identiques');
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('🔴 une épaisseur continue différente SUFFIT', () {
      expect(presetWith(gap: 12, linear: 3),
          isNot(presetWith(gap: 12, linear: 4)));
      expect(presetWith(gap: 12, linear: 3).hashCode,
          isNot(presetWith(gap: 12, linear: 4).hashCode));
    });

    test('🔴 une épaisseur segmentée différente SUFFIT', () {
      expect(presetWith(gap: 12, marker: 8),
          isNot(presetWith(gap: 12, marker: 9)));
      expect(presetWith(gap: 12, marker: 8).hashCode,
          isNot(presetWith(gap: 12, marker: 9).hashCode));
    });

    test('la description textuelle porte les trois champs', () {
      final String text = presetWith(gap: 12, linear: 3, marker: 8).toString();
      for (final String field in <String>[
        'progressDotsGeometry',
        'progressLinearThickness',
        'progressSegmentedMarkerThickness',
      ]) {
        expect(text, contains(field));
      }
      expect(text, isNot(presetWith(gap: 13, linear: 3, marker: 8).toString()),
          reason: '🔴 deux formes différentes se décrivent pareil');
    });

    test('la référence `classic` pose les valeurs mesurées', () {
      final ZStudySessionPreset p = ZStudySessionPreset.classic();
      expect(p.progressDotsGeometry?.inactiveSize, const Size(14, 10));
      expect(p.progressDotsGeometry?.activeScale, 2.4);
      expect(p.progressDotsGeometry?.gap, 12);
      expect(p.progressDotsGeometry?.alignment, WrapAlignment.center);
      expect(p.progressDotsGeometry?.scrollable, isTrue);
      expect(p.progressSegmentedMarkerThickness, 8);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 6. Inertie — sans preset ni paramètre, l'arbre est celui d'avant
  // ═════════════════════════════════════════════════════════════════════════
  group('🧊 inertie — `preset: null` rend l\'arbre figé AVANT le lot', () {
    for (final ZSessionProgressStyle style in <ZSessionProgressStyle>[
      ZSessionProgressStyle.dots,
      ZSessionProgressStyle.segmentedMarker,
    ]) {
      testWidgets('${style.name} : arbre identique, nœud pour nœud',
          (tester) async {
        expect(_baseline(style), isNotEmpty);
        await pumpPage(tester, page(progressStyle: style));
        expect(_treeDump(tester), _baseline(style),
            reason: '🔴 le lot a changé l\'arbre d\'un écran qui ne décrit '
                'rien');
      });
    }
  });
}
