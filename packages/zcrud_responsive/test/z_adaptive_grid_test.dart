// Tests widget de `ZAdaptiveGrid` (EX-UI.3).
//
// Couvre : garde vide → SizedBox.shrink (AC4), colonnes effectives du delegate
// à largeurs de conteneur forcées + clamp haut (AC5/AC6), largeur LOCALE
// prouvée par un panneau étroit sous écran large (AC5/anti-Get.width),
// childAspectRatio recalculé (AC6), invariance RTL (AC7/AD-13).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

/// Monte [child] sous une largeur de conteneur **LOCALE** forcée à [width] via un
/// `OverflowBox` (contrainte tight indépendante de la surface de test 800×600),
/// sous une fenêtre large et une [textDirection]. Permet de tester des largeurs
/// `> 800` sans overflow.
Widget _harness({
  required double width,
  required Widget child,
  TextDirection textDirection = TextDirection.ltr,
  double screenWidth = 3000,
}) {
  return Directionality(
    textDirection: textDirection,
    child: MediaQuery(
      data: MediaQueryData(size: Size(screenWidth, 2000)),
      child: OverflowBox(
        alignment: AlignmentDirectional.topStart,
        minWidth: width,
        maxWidth: width,
        minHeight: 600,
        maxHeight: 600,
        child: child,
      ),
    ),
  );
}

/// Cellules-jouets (non-const car réutilisées comme liste).
List<Widget> _cells(int n) =>
    List<Widget>.generate(n, (i) => SizedBox(key: ValueKey('cell-$i')));

SliverGridDelegateWithFixedCrossAxisCount _delegate(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView));
  return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('AC4 — garde children vide → SizedBox.shrink()', () {
    testWidgets('children vide : SizedBox présent, aucun GridView', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: const ZAdaptiveGrid(children: [], minItemWidth: 300),
        ),
      );
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('AC5/AC6 — colonnes effectives par largeur de conteneur', () {
    testWidgets('conteneur 1000, minItemWidth 300 → 3 colonnes', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 3);
    });

    testWidgets('conteneur 250, minItemWidth 300 → 1 colonne (clamp bas)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 250,
          child: ZAdaptiveGrid(children: _cells(4), minItemWidth: 300),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 1);
    });

    testWidgets('conteneur 650, minItemWidth 300, maxColumns 2 → 2 (clamp haut)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 650,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 300,
            maxColumns: 2,
          ),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 2);
    });
  });

  group('AC5/D2 — largeur LOCALE (anti-Get.width)', () {
    testWidgets('panneau 250 sous écran 1400 → 1 colonne', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900)),
            child: Center(
              child: SizedBox(
                width: 250,
                child: ZAdaptiveGrid(
                  minItemWidth: 300,
                  children: _cells(4),
                ),
              ),
            ),
          ),
        ),
      );
      // L'écran est large (1400) mais le PANNEAU fait 250 → 1 colonne.
      expect(_delegate(tester).crossAxisCount, 1);
    });
  });

  group('AC6 — childAspectRatio déduit', () {
    testWidgets('itemHeight fourni → childAspectRatio = itemWidth/itemHeight',
        (tester) async {
      // Conteneur 900, minItemWidth 300, spacing 8 (AC9 : gouttières comptées) :
      // n = ⌊(900+8)/(300+8)⌋ = ⌊2.94⌋ = 2 (3 colonnes écraseraient les items
      // sous minItemWidth — c'est le bug qu'AC9 corrige).
      // itemWidth = (900 − 8·1) / 2 = 892/2 = 446 ; ratio = itemWidth/200.
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 300,
            itemHeight: 200,
          ),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 2);
      final expectedItemWidth = (900 - 8 * 1) / 2;
      expect(
        _delegate(tester).childAspectRatio,
        closeTo(expectedItemWidth / 200, 0.0001),
      );
    });

    testWidgets('sans itemHeight → childAspectRatio = aspectRatio ?? 1.0',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(children: _cells(3), minItemWidth: 300),
        ),
      );
      expect(_delegate(tester).childAspectRatio, 1.0);
    });

    testWidgets('aspectRatio explicite respecté sans itemHeight', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(
            children: _cells(3),
            minItemWidth: 300,
            aspectRatio: 1.5,
          ),
        ),
      );
      expect(_delegate(tester).childAspectRatio, 1.5);
    });

    testWidgets('itemHeight <= 0 → repli sur aspectRatio ?? 1.0 (garde AD-10)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(
            children: _cells(3),
            minItemWidth: 300,
            itemHeight: 0,
            aspectRatio: 2.0,
          ),
        ),
      );
      expect(_delegate(tester).childAspectRatio, 2.0);
    });
  });

  group('AC7/AD-13 — RTL invariant à largeur égale', () {
    for (final width in <double>[250, 1000]) {
      testWidgets('rtl largeur $width → même crossAxisCount qu\'en LTR',
          (tester) async {
        await tester.pumpWidget(
          _harness(
            width: width,
            child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
          ),
        );
        final rtlCount = _delegate(tester).crossAxisCount;

        await tester.pumpWidget(
          _harness(
            width: width,
            textDirection: TextDirection.rtl,
            child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
          ),
        );
        expect(_delegate(tester).crossAxisCount, rtlCount);
      });
    }
  });

  group('AC7/NFR-U4 — rendu paresseux GridView.builder', () {
    testWidgets('GridView présent avec délégué à colonnes fixes', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
        ),
      );
      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.shrinkWrap, isTrue);
      expect(grid.physics, isA<NeverScrollableScrollPhysics>());
    });
  });

  group('AC9 — padding + spacing pris en compte dans le nombre de colonnes', () {
    testWidgets(
        'padding horizontal fait perdre 1 colonne (1000, minW 300, pad h 120)',
        (tester) async {
      // Sans padding, spacing 8 : (1000+8)/(300+8) = 3.27 → 3.
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 3);

      // Avec padding horizontal 120 : effectiveWidth 880 →
      // (880+8)/(300+8) = 2.88 → 2.
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 300,
            padding: const EdgeInsets.symmetric(horizontal: 60),
          ),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 2);
    });

    testWidgets('spacing élevé fait perdre 1 colonne (920, minW 300, spacing 60)',
        (tester) async {
      // Spacing 8 (défaut) : (920+8)/308 = 3.01 → 3.
      await tester.pumpWidget(
        _harness(
          width: 920,
          child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 3);

      // Spacing 60 : (920+60)/(300+60) = 980/360 = 2.72 → 2.
      await tester.pumpWidget(
        _harness(
          width: 920,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 300,
            spacing: 60,
          ),
        ),
      );
      expect(_delegate(tester).crossAxisCount, 2);
    });

    testWidgets('itemWidth déduit sur la base padding+spacing (childAspectRatio)',
        (tester) async {
      // width 1000, pad h 120 → effectiveWidth 880 ; spacing 8 → n=2 ;
      // itemWidth = (880 − 8·1)/2 = 872/2 = 436 ; ratio = 436/200.
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: ZAdaptiveGrid(
            children: _cells(4),
            minItemWidth: 300,
            itemHeight: 200,
            padding: const EdgeInsets.symmetric(horizontal: 60),
          ),
        ),
      );
      const effectiveWidth = 1000.0 - 120.0;
      final expectedItemWidth = (effectiveWidth - 8 * 1) / 2;
      expect(_delegate(tester).crossAxisCount, 2);
      expect(
        _delegate(tester).childAspectRatio,
        closeTo(expectedItemWidth / 200, 0.0001),
      );
    });

    testWidgets('padding directionnel (EdgeInsetsDirectional) résolu en RTL',
        (tester) async {
      // horizontal total = start 90 + end 30 = 120, invariant LTR/RTL.
      const pad = EdgeInsetsDirectional.only(start: 90, end: 30);
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 300,
            padding: pad,
          ),
        ),
      );
      final ltrCount = _delegate(tester).crossAxisCount;
      expect(ltrCount, 2);

      await tester.pumpWidget(
        _harness(
          width: 1000,
          textDirection: TextDirection.rtl,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 300,
            padding: pad,
          ),
        ),
      );
      expect(_delegate(tester).crossAxisCount, ltrCount);
    });

    testWidgets('padding >= largeur → 1 colonne, aucun throw', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 250,
          child: ZAdaptiveGrid(
            children: _cells(4),
            minItemWidth: 100,
            padding: const EdgeInsets.symmetric(horizontal: 200),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_delegate(tester).crossAxisCount, 1);
      expect(_delegate(tester).childAspectRatio, greaterThan(0));
      expect(_delegate(tester).childAspectRatio.isFinite, isTrue);
    });
  });

  group('AC2/AD-10 — childAspectRatio défensif (jamais de throw)', () {
    testWidgets(
        'spacing > minItemWidth (largeur d\'item ≤ 0) + itemHeight → aucun throw, '
        'ratio > 0 fini', (tester) async {
      // n ≥ 2 avec spacing énorme ⇒ largeur d'item déduite négative : sans garde,
      // childAspectRatio ≤ 0 violerait l'assertion du delegate (throw debug).
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(
            children: _cells(6),
            minItemWidth: 100,
            spacing: 400,
            itemHeight: 100,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GridView), findsOneWidget);
      expect(_delegate(tester).childAspectRatio, greaterThan(0));
      expect(_delegate(tester).childAspectRatio.isFinite, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SU-8 / AC2 — constructeur `.builder` ADDITIF : virtualisation RÉELLE.
  //
  // Pourquoi ce ctor existe (SU-8/D3) : le ctor `children:` est **lazy au rendu**
  // mais **EAGER à la construction** — l'appelant doit matérialiser TOUS les
  // widgets avant de les passer. Combiné à `shrinkWrap: true` +
  // `NeverScrollableScrollPhysics`, la grille layoute TOUT (aucun culling de
  // viewport). Sur des milliers de cartes, c'est NFR-SU9 violée.
  //
  // 🔴 La sonde compte les appels RÉELS d'`itemBuilder` : c'est la seule preuve
  // que la virtualisation n'est pas décorative. Un ctor `.builder` qui
  // délèguerait en interne à `children:` passerait TOUS les autres tests
  // (colonnes, ratio, garde vide) et n'échouerait QUE sur ce compteur.
  // ═══════════════════════════════════════════════════════════════════════════
  group('SU-8/AC2 — ZAdaptiveGrid.builder (additif, virtualisé)', () {
    testWidgets(
      '🔴 VIRTUALISATION : sur 1000 items, itemBuilder est appelé ≪ 1000 fois',
      (tester) async {
        final built = <int>[];
        await tester.pumpWidget(
          _harness(
            width: 900,
            child: ZAdaptiveGrid.builder(
              itemCount: 1000,
              itemBuilder: (context, i) {
                built.add(i);
                return SizedBox(key: ValueKey('cell-$i'));
              },
              minItemWidth: 300,
              itemHeight: 100,
            ),
          ),
        );

        expect(built, isNotEmpty,
            reason: 'sonde cassée : aucun item construit ⇒ le test ne mesure '
                'RIEN et resterait vert quoi qu\'il arrive');
        expect(
          built.length,
          lessThan(200),
          reason: '🔴 NFR-SU9 : ${built.length}/1000 items construits — la '
              'grille n\'est PAS virtualisée. Cause quasi certaine : le ctor '
              '`.builder` délègue à `children:` (shrinkWrap + '
              'NeverScrollableScrollPhysics ⇒ tout est layouté).',
        );
      },
    );

    testWidgets(
      '🔴 D4 — contre-preuve mesurée sur les WIDGETS RENDUS (jamais sur List.generate)',
      (tester) async {
        // 🔴 D4 — L'ANCIENNE version comptait `builtEagerly`, incrémenté par
        // `List.generate` (le SDK Dart), vrai AVANT même le `pumpWidget` : elle
        // mesurait `List.generate`, PAS `ZAdaptiveGrid`. Preuve : mutiler le ctor
        // `children:` (rendre `SizedBox.shrink()`) la laissait VERTE tandis que
        // 19 autres tests rougissaient — une garde décorative. On mesure
        // désormais ce que le WIDGET rend réellement.
        //
        // ⚠️ Fait mesuré (sonde jetable) : les DEUX ctors s'appuient sur
        // `GridView.builder` et **cullent le viewport** ⇒ ils montent le MÊME
        // petit nombre de tuiles (≈12/1000), PAS « 1000 vs 10 ». La vraie
        // différence n'est donc pas le nombre de tuiles montées mais :
        //   (a) `.builder` n'APPELLE `itemBuilder` que pour le viewport (mesuré
        //       ci-dessous, ≪ itemCount) — le caller ne construit jamais 1000
        //       widgets ; `children:` exige une `List<Widget>` pré-construite ;
        //   (b) chaque ctor REND bien son viewport — mutiler l'un rougit ICI.
        bool isCell(Widget w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('cell-');

        // .builder : itemBuilder appelé ≪ itemCount (virtualisation RÉELLE, et
        // c'est une propriété DU widget, pas de List.generate).
        var builderCalls = 0;
        await tester.pumpWidget(
          _harness(
            width: 900,
            child: ZAdaptiveGrid.builder(
              itemCount: 1000,
              itemBuilder: (context, i) {
                builderCalls++;
                return SizedBox(key: ValueKey('cell-$i'));
              },
              minItemWidth: 300,
              itemHeight: 100,
            ),
          ),
        );
        expect(builderCalls, lessThan(200),
            reason: '🔴 .builder ne CONSTRUIT que le viewport ($builderCalls/1000) '
                '— le caller ne matérialise jamais 1000 widgets');
        expect(find.byKey(const ValueKey('cell-0')), findsOneWidget,
            reason: 'sonde : .builder rend bien son viewport');

        // children: le ctor historique REND réellement les widgets qu'on lui
        // passe. 🔴 Mutiler ce ctor (SizedBox.shrink) rougirait ICI — là où
        // l'ancien `builtEagerly` (décorrélé du ctor) restait vert.
        await tester.pumpWidget(
          _harness(
            width: 900,
            child: ZAdaptiveGrid(
              children: _cells(1000),
              minItemWidth: 300,
              itemHeight: 100,
            ),
          ),
        );
        expect(find.byKey(const ValueKey('cell-0')), findsOneWidget,
            reason: '🔴 D4 : le ctor children: MONTE/REND ses widgets — cette '
                'assertion DÉPEND du ctor (mutiler → SizedBox.shrink la rougit), '
                'contrairement à l\'ancien builtEagerly compté par List.generate');
        expect(find.byWidgetPredicate(isCell).evaluate().length, greaterThan(0),
            reason: 'sonde : au moins une tuile réellement montée');
      },
    );

    testWidgets('les DEUX ctors donnent le MÊME nombre de colonnes', (tester) async {
      // computeCrossAxisCount RÉUTILISÉ (jamais une 2e formule de colonnes).
      for (final width in <double>[320, 640, 900, 1440]) {
        await tester.pumpWidget(
          _harness(
            width: width,
            child: ZAdaptiveGrid(children: _cells(20), minItemWidth: 300),
          ),
        );
        final withChildren = _delegate(tester).crossAxisCount;

        await tester.pumpWidget(
          _harness(
            width: width,
            child: ZAdaptiveGrid.builder(
              itemCount: 20,
              itemBuilder: (context, i) => SizedBox(key: ValueKey('cell-$i')),
              minItemWidth: 300,
            ),
          ),
        );
        final withBuilder = _delegate(tester).crossAxisCount;

        expect(withBuilder, withChildren,
            reason: 'largeur $width : les deux ctors doivent partager '
                '`computeCrossAxisCount` — une 2e formule est une 2e source');
      }
    });

    testWidgets('garde vide PARTAGÉE : itemCount 0 → SizedBox.shrink()', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid.builder(
            itemCount: 0,
            itemBuilder: (context, i) => const SizedBox(),
            minItemWidth: 300,
          ),
        ),
      );
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemCount NÉGATIF ⇒ garde vide, jamais de throw (AD-10)', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid.builder(
            itemCount: -5,
            itemBuilder: (context, i) => const SizedBox(),
            minItemWidth: 300,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('replis AD-10 PARTAGÉS : ratio dégénéré ⇒ jamais de throw',
        (tester) async {
      // Même dégénérescence que le ctor children: (spacing > largeur d'item).
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid.builder(
            itemCount: 6,
            itemBuilder: (context, i) => SizedBox(key: ValueKey('cell-$i')),
            minItemWidth: 100,
            spacing: 400,
            itemHeight: 100,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_delegate(tester).childAspectRatio, greaterThan(0));
      expect(_delegate(tester).childAspectRatio.isFinite, isTrue);
    });

    testWidgets('.builder SCROLLE de lui-même (jamais shrinkWrap)', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid.builder(
            itemCount: 1000,
            itemBuilder: (context, i) => SizedBox(
              key: ValueKey('cell-$i'),
              child: Text('item $i', textDirection: TextDirection.ltr),
            ),
            minItemWidth: 300,
            itemHeight: 100,
          ),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.shrinkWrap, isFalse,
          reason: 'shrinkWrap: true layouterait TOUT ⇒ virtualisation morte');
      expect(grid.physics, isNot(isA<NeverScrollableScrollPhysics>()),
          reason: '.builder est la surface SCROLLABLE (AC2)');

      // Le scroll révèle des items NON construits initialement (preuve que le
      // culling est réel et que la grille est réellement parcourable).
      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 900'), findsNothing);
      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      await tester.pump();
      expect(find.text('item 0'), findsNothing,
          reason: 'après scroll, les premiers items sortent du viewport');
    });

    testWidgets('ctor children: NON RÉGRESSÉ (shrinkWrap + physics figées)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          child: ZAdaptiveGrid(children: _cells(6), minItemWidth: 300),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.shrinkWrap, isTrue,
          reason: 'zéro régression : le contrat du ctor existant est intact');
      expect(grid.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}
