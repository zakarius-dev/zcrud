// CR-LEX-75 — aucun slot sous le sous-titre sur `ZStudyToolsItemCard`.
//
// Le slot `progress` ne pouvait pas en tenir lieu, pour DEUX raisons distinctes :
//   1. il est rendu dans la `Row` de tête, donc À CÔTÉ du bloc titre/sous-titre ;
//   2. il est BORNÉ à `progressMaxWidth` (120 dp par défaut) — borne justifiée
//      pour un `LinearProgressIndicator` (CR-IFFD-20), mais qui TRONQUE une puce
//      d'état localisée : `RenderFlex overflowed` de 41 px mesuré chez lex, et
//      cette largeur dépend de la LOCALE (7 langues, dont l'arabe).
//
// D'où `belowSubtitle` : dans la `Column`, sous le sous-titre, SANS contrainte
// de largeur, et — comme `badge` depuis CR-71 — hors de l'`ExcludeSemantics`.
//
// Discipline R3 : chaque garde a été prouvée mordante en réinjectant la
// régression exacte (cf. rapport de story).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

Widget _host(Widget child, {double width = 600}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  ),
);

/// La puce d'état de lex, reproduite : une `Row` icône + libellé localisé, à
/// largeur INTRINSÈQUE — c'est elle qui déborde d'un `ConstrainedBox` de 120 dp.
const Widget _statusChip = Row(
  key: Key('status-chip'),
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    Icon(Icons.autorenew, size: 16),
    SizedBox(width: 4),
    Text('Traitement du document en cours…'),
  ],
);

void main() {
  group('CR-LEX-75 — slot `belowSubtitle`', () {
    testWidgets(
      'défaut `null` ⇒ AUCUN nœud ni espacement ajouté (rendu inchangé)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(
            const ZStudyToolsItemCard(title: 'Cours', subtitle: 'Modifié hier'),
          ),
        );

        expect(find.byKey(const Key('status-chip')), findsNothing);
        // Aucun `SizedBox` d'espacement VERTICAL : le slot absent ne doit pas
        // laisser de gap résiduel sous le sous-titre.
        final Iterable<SizedBox> verticalGaps = tester
            .widgetList<SizedBox>(
              find.descendant(
                of: find.byType(ZStudyToolsItemCard),
                matching: find.byType(SizedBox),
              ),
            )
            .where((SizedBox b) => b.height != null);
        expect(verticalGaps, isEmpty);
      },
    );

    testWidgets('🔴 rendu SOUS le sous-titre, pas à côté du titre', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(
            title: 'Cours de chimie',
            subtitle: 'Modifié hier',
            belowSubtitle: _statusChip,
          ),
        ),
      );

      final Rect title = tester.getRect(find.text('Cours de chimie'));
      final Rect subtitle = tester.getRect(find.text('Modifié hier'));
      final Rect chip = tester.getRect(find.byKey(const Key('status-chip')));

      // Position VERTICALE réelle : strictement sous le sous-titre, lui-même
      // sous le titre. Une simple assertion de présence passerait aussi si le
      // slot était rendu dans la `Row` de tête — d'où la mesure.
      expect(chip.top, greaterThanOrEqualTo(subtitle.bottom));
      expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
      // …et dans la MÊME colonne : aligné en début sur le titre (LTR ⇒ left).
      expect(chip.left, moreOrLessEquals(title.left, epsilon: 0.5));
    });

    testWidgets('rendu correct quand `subtitle` est `null`', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(
            title: 'Cours de chimie',
            belowSubtitle: _statusChip,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final Rect title = tester.getRect(find.text('Cours de chimie'));
      final Rect chip = tester.getRect(find.byKey(const Key('status-chip')));
      expect(chip.top, greaterThanOrEqualTo(title.bottom));
      expect(chip.left, moreOrLessEquals(title.left, epsilon: 0.5));
    });

    testWidgets(
      '🔴 AUCUNE troncature : la puce que `progress` fait déborder passe',
      (WidgetTester tester) async {
        // Témoin — la même puce dans `progress` DÉBORDE de son `ConstrainedBox`
        // de 120 dp : c'est le défaut mesuré par lex, reproduit ici.
        await tester.pumpWidget(
          _host(
            const ZStudyToolsItemCard(
              title: 'Cours de chimie',
              subtitle: 'Modifié hier',
              progress: _statusChip,
            ),
          ),
        );
        expect(
          tester.takeException(),
          isFlutterError,
          reason: 'témoin : `progress` borné à 120 dp tronque la puce',
        );

        // Le nouveau slot, lui, n'impose aucune borne de largeur.
        await tester.pumpWidget(
          _host(
            const ZStudyToolsItemCard(
              title: 'Cours de chimie',
              subtitle: 'Modifié hier',
              belowSubtitle: _statusChip,
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        final Rect chip = tester.getRect(find.byKey(const Key('status-chip')));
        expect(
          chip.width,
          greaterThan(120),
          reason: 'la puce dépasse la borne de `progress` sans être tronquée',
        );
      },
    );

    testWidgets('♿ le slot RESTE annonçable, contrairement à title/subtitle', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ZStudyToolsItemCard(
            title: 'Cours de chimie',
            subtitle: 'Modifié hier',
            belowSubtitle: Semantics(
              label: 'Traitement en cours',
              child: const Icon(Icons.autorenew),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Traitement en cours'), findsOneWidget);
      // …tandis que les libellés restent exclus (déjà dans le `label` de la
      // carte) : la portée de l'`ExcludeSemantics` n'a pas bougé.
      expect(find.bySemanticsLabel(RegExp(r'^Modifié hier$')), findsNothing);

      handle.dispose();
    });
  });
}
