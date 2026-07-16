// Tests widget de `ZResponsiveLayout` (EX-UI.2).
//
// Couvre : sélection par palier aux frontières de largeur LOCALE (599/600/839/840),
// non-invocation des builders non retenus, cascade descendante (3 cas), mesure
// LOCALE prouvée par un panneau étroit sous un écran large + LayoutBuilder
// imbriqué, et invariance RTL.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

/// Marqueurs distincts par palier (repérés par `find.byKey`).
const _compactKey = Key('marker-compact');
const _mediumKey = Key('marker-medium');
const _expandedKey = Key('marker-expanded');

/// Monte [child] sous une largeur de conteneur **LOCALE** forcée à [width] via un
/// `OverflowBox` (contrainte tight sur la largeur, indépendante de la taille de la
/// surface de test), lui-même sous une fenêtre large et une [textDirection]. La
/// contrainte de largeur du conteneur — et non la taille écran — pilote la
/// sélection. `OverflowBox` autorise le dépassement de la surface (aucune erreur
/// d'overflow), ce qui permet de tester des largeurs `> 800` (surface par défaut).
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
        minHeight: 100,
        maxHeight: 100,
        child: child,
      ),
    ),
  );
}

void main() {
  group('AC1/AC2 — sélection par palier sur largeur LOCALE (frontières)', () {
    for (final (width, expectedKey, label) in <(double, Key, String)>[
      (599, _compactKey, 'compact'),
      (600, _mediumKey, 'medium'),
      (839, _mediumKey, 'medium'),
      (840, _expandedKey, 'expanded'),
    ]) {
      testWidgets('largeur $width → $label', (tester) async {
        await tester.pumpWidget(
          _harness(
            width: width,
            child: ZResponsiveLayout(
              compact: (_) => const SizedBox(key: _compactKey),
              medium: (_) => const SizedBox(key: _mediumKey),
              expanded: (_) => const SizedBox(key: _expandedKey),
            ),
          ),
        );
        expect(find.byKey(expectedKey), findsOneWidget);
        // Non-invocation des autres builders : leur marqueur est absent de l'arbre.
        for (final k in <Key>[_compactKey, _mediumKey, _expandedKey]) {
          if (k != expectedKey) {
            expect(find.byKey(k), findsNothing);
          }
        }
      });
    }

    testWidgets('un seul builder est INVOQUÉ (compteurs)', (tester) async {
      var compactCalls = 0;
      var mediumCalls = 0;
      var expandedCalls = 0;
      await tester.pumpWidget(
        _harness(
          width: 700, // medium
          child: ZResponsiveLayout(
            compact: (_) {
              compactCalls++;
              return const SizedBox();
            },
            medium: (_) {
              mediumCalls++;
              return const SizedBox();
            },
            expanded: (_) {
              expandedCalls++;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(mediumCalls, 1);
      expect(compactCalls, 0);
      expect(expandedCalls, 0);
    });
  });

  group('AC3 — cascade descendante, jamais d\'écran vide', () {
    // (a) Seul `compact` fourni : medium (700) ET expanded (1000) rendent compact.
    for (final width in <double>[700, 1000]) {
      testWidgets('compact seul → compact à largeur $width', (tester) async {
        await tester.pumpWidget(
          _harness(
            width: width,
            child: ZResponsiveLayout(
              compact: (_) => const SizedBox(key: _compactKey),
            ),
          ),
        );
        expect(find.byKey(_compactKey), findsOneWidget);
        expect(find.byKey(_mediumKey), findsNothing);
        expect(find.byKey(_expandedKey), findsNothing);
      });
    }

    // (b) compact + medium (sans expanded), largeur 1000 (expanded) → medium.
    testWidgets('compact+medium, largeur 1000 → medium', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 1000,
          child: ZResponsiveLayout(
            compact: (_) => const SizedBox(key: _compactKey),
            medium: (_) => const SizedBox(key: _mediumKey),
          ),
        ),
      );
      expect(find.byKey(_mediumKey), findsOneWidget);
      expect(find.byKey(_compactKey), findsNothing);
      expect(find.byKey(_expandedKey), findsNothing);
    });

    // (c) compact + expanded (sans medium), largeur 700 (medium) → compact
    // (medium absent redescend directement au plancher requis, sans remontée).
    testWidgets('compact+expanded, largeur 700 → compact', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 700,
          child: ZResponsiveLayout(
            compact: (_) => const SizedBox(key: _compactKey),
            expanded: (_) => const SizedBox(key: _expandedKey),
          ),
        ),
      );
      expect(find.byKey(_compactKey), findsOneWidget);
      expect(find.byKey(_mediumKey), findsNothing);
      expect(find.byKey(_expandedKey), findsNothing);
    });
  });

  group('AC5/D1 — largeur LOCALE (split-view / LayoutBuilder imbriqué)', () {
    testWidgets('panneau 500 dp sous écran 1200 → compact', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Row(
              children: [
                SizedBox(
                  width: 500,
                  child: ZResponsiveLayout(
                    compact: (_) => const SizedBox(key: _compactKey),
                    medium: (_) => const SizedBox(key: _mediumKey),
                    expanded: (_) => const SizedBox(key: _expandedKey),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
      // L'écran est « expanded » (1200) mais le PANNEAU fait 500 → compact.
      expect(find.byKey(_compactKey), findsOneWidget);
      expect(find.byKey(_expandedKey), findsNothing);
      expect(find.byKey(_mediumKey), findsNothing);
    });

    testWidgets('LayoutBuilder parent imbriqué → mesure du conteneur immédiat',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900, // conteneur immédiat = expanded
          child: LayoutBuilder(
            builder: (context, _) => ZResponsiveLayout(
              compact: (_) => const SizedBox(key: _compactKey),
              medium: (_) => const SizedBox(key: _mediumKey),
              expanded: (_) => const SizedBox(key: _expandedKey),
            ),
          ),
        ),
      );
      expect(find.byKey(_expandedKey), findsOneWidget);
      expect(find.byKey(_compactKey), findsNothing);
      expect(find.byKey(_mediumKey), findsNothing);
    });
  });

  group('AC5/AD-13 — RTL invariant à largeur égale', () {
    for (final (width, expectedKey, label) in <(double, Key, String)>[
      (500, _compactKey, 'compact'),
      (700, _mediumKey, 'medium'),
      (1000, _expandedKey, 'expanded'),
    ]) {
      testWidgets('rtl largeur $width → $label (identique à LTR)',
          (tester) async {
        await tester.pumpWidget(
          _harness(
            width: width,
            textDirection: TextDirection.rtl,
            child: ZResponsiveLayout(
              compact: (_) => const SizedBox(key: _compactKey),
              medium: (_) => const SizedBox(key: _mediumKey),
              expanded: (_) => const SizedBox(key: _expandedKey),
            ),
          ),
        );
        expect(find.byKey(expectedKey), findsOneWidget);
      });
    }
  });
}
