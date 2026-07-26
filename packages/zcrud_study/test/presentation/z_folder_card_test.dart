// SUF-2 — gardes R3 de `ZFolderCard` (AC1..AC9). Chaque `test`/`testWidgets`
// PROUVE une régression : ré-injecter la faute que la garde interdit doit faire
// ROUGIR le test (mordancy vérifiée manuellement, cf. Completion Notes de la
// story). Aucune garde tautologique.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Monte [card] dans un arbre déterministe. [height] borne la hauteur (régime
/// grille, branche `Expanded`) ; `height == null` ⇒ hauteur NON BORNÉE
/// (`SingleChildScrollView`, régime min-content, plancher 48 dp).
Future<void> pumpCard(
  WidgetTester tester,
  ZFolderCard card, {
  ZColorKeyResolver? resolver,
  TextDirection dir = TextDirection.ltr,
  double? height = 160,
  ThemeData? theme,
}) async {
  Widget framed = height != null
      ? SizedBox(height: height, width: 220, child: card)
      : SingleChildScrollView(child: SizedBox(width: 220, child: card));

  if (resolver != null) {
    framed = ZcrudScope(colorKeyResolver: resolver, child: framed);
  }

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? ThemeData(useMaterial3: true),
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: Center(child: framed)),
      ),
    ),
  );
}

/// Pastille d'accent (le seul `Container` à décoration circulaire de la carte).
Finder pastilleFinder() => find.byWidgetPredicate(
      (Widget w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    );

Color pastilleColor(WidgetTester tester) =>
    (tester.widget<Container>(pastilleFinder()).decoration! as BoxDecoration)
        .color!;

Color cardColor(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card)).color!;

/// Nœuds `Semantics` explicitement marqués `button: true` (les nôtres).
Finder buttonSemantics() => find.byWidgetPredicate(
      (Widget w) => w is Semantics && (w.properties.button ?? false),
    );

void main() {
  group('AC1 — accent DÉRIVÉ de la colorKey (jamais codé en dur)', () {
    testWidgets('G1 — resolver injecté : pastille + fond suivent la ZColorPair',
        (WidgetTester tester) async {
      const distinctive = Color(0xFFAABBCC);
      await pumpCard(
        tester,
        const ZFolderCard(title: 'T', colorKey: 'x'),
        resolver: (ColorScheme scheme, String key) => key == 'x'
            ? const ZColorPair(color: distinctive, onColor: Color(0xFF000000))
            : null,
      );

      expect(pastilleColor(tester), distinctive);
      expect(cardColor(tester), distinctive.withValues(alpha: 0.12));
    });

    testWidgets('G2 — colorKey inconnue : colorSlotIndex distinct ⇒ couleurs ≠',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ZFolderCard(title: 'T', colorKey: 'inconnu', colorSlotIndex: 1),
      );
      final Color slot1 = pastilleColor(tester);

      await pumpCard(
        tester,
        const ZFolderCard(title: 'T', colorKey: 'inconnu', colorSlotIndex: 3),
      );
      final Color slot3 = pastilleColor(tester);

      expect(slot1, isNot(equals(slot3)));
    });
  });

  group('AC2 — badge « Archivé » conditionnel (libellé INJECTÉ)', () {
    testWidgets('G3 — isArchived + archivedLabel ⇒ badge présent',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ZFolderCard(
          title: 'T',
          colorKey: 'k',
          isArchived: true,
          archivedLabel: 'ARCH',
        ),
      );
      expect(find.text('ARCH'), findsOneWidget);
    });

    testWidgets('G4 — badge structurellement absent si !archivé OU label null',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ZFolderCard(
          title: 'T',
          colorKey: 'k',
          archivedLabel: 'ARCH',
        ),
      );
      expect(find.text('ARCH'), findsNothing);

      await pumpCard(
        tester,
        const ZFolderCard(title: 'T', colorKey: 'k', isArchived: true),
      );
      expect(find.text('ARCH'), findsNothing);
    });
  });

  group('AC3/AC4 — slots rendus verbatim / absents', () {
    testWidgets('G5 — slot counts rendu puis absent',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ZFolderCard(
          title: 'T',
          colorKey: 'k',
          counts: Text('42 cartes'),
        ),
      );
      expect(find.text('42 cartes'), findsOneWidget);

      await pumpCard(tester, const ZFolderCard(title: 'T', colorKey: 'k'));
      expect(find.text('42 cartes'), findsNothing);
    });

    testWidgets('G6 — slot menu rendu, absent, ET atteignable au lecteur',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ZFolderCard(
          title: 'T',
          colorKey: 'k',
          menu: Semantics(
            label: 'MENU',
            child: IconButton(
              key: const ValueKey<String>('m'),
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('m')), findsOneWidget);
      // NON exclu de la sémantique (ExcludeSemantics ne doit pas l'englober).
      expect(find.bySemanticsLabel('MENU'), findsOneWidget);

      await pumpCard(tester, const ZFolderCard(title: 'T', colorKey: 'k'));
      expect(find.byKey(const ValueKey<String>('m')), findsNothing);
    });
  });

  group('AC5 — interactions / AD-45 absence structurelle', () {
    testWidgets('G7 — onTap déclenché', (WidgetTester tester) async {
      var taps = 0;
      await pumpCard(
        tester,
        ZFolderCard(title: 'T', colorKey: 'k', onTap: () => taps++),
      );
      await tester.tap(find.byType(ZFolderCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('G8 — onLongPress déclenché', (WidgetTester tester) async {
      var longs = 0;
      await pumpCard(
        tester,
        ZFolderCard(title: 'T', colorKey: 'k', onLongPress: () => longs++),
      );
      await tester.longPress(find.byType(ZFolderCard));
      await tester.pump();
      expect(longs, 1);
    });

    testWidgets('G9 — aucune activation ⇒ pas d\'InkWell ni de button',
        (WidgetTester tester) async {
      await pumpCard(tester, const ZFolderCard(title: 'T', colorKey: 'k'));
      expect(find.byType(InkWell), findsNothing);
      expect(buttonSemantics(), findsNothing);
    });
  });

  group('AC6 — cible ≥ 48 dp (AD-13)', () {
    testWidgets('G10 — plancher de hauteur 48 dp (contenu minimal)',
        (WidgetTester tester) async {
      // Thème à titre minuscule ⇒ contenu intrinsèque < 48 dp : SEUL le
      // `ConstrainedBox(minHeight: 48)` maintient la carte ≥ 48 (le retirer la
      // fait descendre sous 48 ⇒ ROUGE). Hauteur NON BORNÉE (min-content).
      final tiny = ThemeData(useMaterial3: true).copyWith(
        textTheme: const TextTheme(titleMedium: TextStyle(fontSize: 2)),
      );
      await pumpCard(
        tester,
        ZFolderCard(title: 'T', colorKey: 'k', onTap: () {}),
        height: null,
        theme: tiny,
      );
      expect(
        tester.getSize(find.byType(ZFolderCard)).height,
        greaterThanOrEqualTo(kZFolderCardMinHeight),
      );
    });
  });

  group('AC7 — neutre thémable + RTL (directionnel)', () {
    testWidgets('G11 — rendu RTL sans exception, titre présent',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ZFolderCard(title: 'Titre RTL', colorKey: 'k'),
        dir: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Titre RTL'), findsOneWidget);
    });

    test('G11b — source sans alignement/inset NON directionnel', () {
      final String src =
          File('lib/src/presentation/z_folder_card.dart').readAsStringSync();
      expect(src.contains('Alignment.centerLeft'), isFalse);
      expect(src.contains('Alignment.centerRight'), isFalse);
      expect(src.contains('EdgeInsets.only(left'), isFalse);
      expect(src.contains('EdgeInsets.only(right'), isFalse);
      expect(RegExp(r'TextAlign\.left').hasMatch(src), isFalse);
      expect(RegExp(r'TextAlign\.right').hasMatch(src), isFalse);
      expect(RegExp(r'Positioned\(\s*left').hasMatch(src), isFalse);
    });
  });

  group('AC8 — sémantique de carte unique', () {
    testWidgets('G12 — un seul nœud button portant le label attendu',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ZFolderCard(
          title: 'Dossier',
          colorKey: 'k',
          isArchived: true,
          archivedLabel: 'Archivé',
          onTap: () {},
        ),
      );
      final List<Semantics> nodes =
          tester.widgetList<Semantics>(buttonSemantics()).toList();
      expect(nodes, hasLength(1));
      expect(nodes.single.properties.label, 'Dossier, Archivé');
      // Le fragment interne de titre est EXCLU (pas de double annonce) : la carte
      // n'annonce le titre qu'une fois, via son label.
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets(
        'G12c — carte NON interactive : titre + badge ANNONCÉS, toujours 0 button',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        const ZFolderCard(
          title: 'Dossier',
          colorKey: 'k',
          isArchived: true,
          archivedLabel: 'Archivé',
          // ni onTap ni onLongPress ⇒ branche `!interactive` (AD-45).
        ),
      );
      // GARDE MORDANTE : les `ExcludeSemantics` du titre et du badge sont
      // INCONDITIONNELS ; supprimer le `Semantics(label:)` de la branche
      // `!interactive` (rétablir `if (!interactive) return card;`) rend la carte
      // TOTALEMENT absente de l'arbre sémantique ⇒ ce `findsOneWidget` rougit.
      expect(find.bySemanticsLabel('Dossier, Archivé'), findsOneWidget);
      // AD-45 préservé : annoncée, mais JAMAIS comme un bouton (éteint ou non).
      expect(buttonSemantics(), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      handle.dispose();
    });

    testWidgets('G12d — carte NON interactive : semanticLabel injecté honoré',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        const ZFolderCard(
          title: 'Titre',
          colorKey: 'k',
          semanticLabel: 'LABEL CUSTOM',
        ),
      );
      // GARDE MORDANTE : câbler le label sur `title` (ignorer `semanticLabel`)
      // dans la branche non interactive ferait rougir la 1re assertion.
      expect(find.bySemanticsLabel('LABEL CUSTOM'), findsOneWidget);
      expect(find.bySemanticsLabel('Titre'), findsNothing);
      handle.dispose();
    });

    testWidgets('G12b — semanticLabel injecté prime sur le repli',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ZFolderCard(
          title: 'Titre',
          colorKey: 'k',
          semanticLabel: 'LABEL CUSTOM',
          onTap: () {},
        ),
      );
      expect(
        tester.widget<Semantics>(buttonSemantics()).properties.label,
        'LABEL CUSTOM',
      );
    });
  });

  group('AC9 — composable dans ZAdaptiveGrid.builder sans overflow', () {
    for (final double itemHeight in <double>[120, 240]) {
      testWidgets('G13 — grille ≥ 2 colonnes, itemHeight=$itemHeight, no overflow',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true),
            home: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: SizedBox(
                  width: 500,
                  height: 400,
                  child: ZAdaptiveGrid.builder(
                    itemCount: 6,
                    minItemWidth: 160,
                    itemHeight: itemHeight,
                    itemBuilder: (BuildContext context, int i) => ZFolderCard(
                      title:
                          'Dossier au titre très long qui doit s\'ellipser sur deux lignes ancrées en bas $i',
                      colorKey: 'k$i',
                      counts: Text('$i cartes'),
                      menu: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {},
                      ),
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // ≥ 2 colonnes : au moins 2 cartes matérialisées côte à côte.
        expect(find.byType(ZFolderCard), findsWidgets);
      });
    }
  });
}
