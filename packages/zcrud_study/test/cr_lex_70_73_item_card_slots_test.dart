// CR-LEX-70/71/72/73 — quatre écarts d'adoption mesurés par lex_douane sur
// `ZStudyToolsItemCard`.
//
// CR-70 : `gapM` portait DEUX rôles (padding de carte + espacement inter-slots).
// CR-71 : 🔴 a11y — `badge` était sous l'`ExcludeSemantics` alors que la dartdoc
//         promettait le contraire ; un cadenas « lecture seule » était MUET.
// CR-72 : `title`/`subtitle` à styles figés (`titleSmall`/`bodySmall`, 1 ligne).
// CR-73 : `margin: EdgeInsets.zero` en dur ⇒ marge du `CardTheme` inatteignable.
//
// Discipline R3 : chaque garde a été prouvée mordante en réinjectant la
// régression exacte (cf. rapport de story).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(body: Center(child: child)),
  ),
);

/// Le `Padding` de contenu de la carte : le seul dont l'enfant est la `Row` de
/// slots. Le cibler par sa structure évite de dépendre d'un ordre de parcours.
Finder get _contentPadding =>
    find.byWidgetPredicate((Widget w) => w is Padding && w.child is Row);

void main() {
  group('CR-LEX-70 — `contentPadding` distinct du gap inter-slots', () {
    testWidgets('défaut ⇒ padding `gapM` : rendu strictement inchangé', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(
            title: 'Cours',
            leading: Icon(Icons.description_outlined),
          ),
        ),
      );
      final BuildContext context = tester.element(_contentPadding);
      final double gapM = ZcrudTheme.of(context).gapM;
      expect(
        tester.widget<Padding>(_contentPadding).padding,
        EdgeInsetsDirectional.all(gapM),
      );
    });

    testWidgets(
      '🔴 padding injecté ⇒ le PADDING change, le GAP inter-slots ne bouge PAS',
      (WidgetTester tester) async {
        // Le cas exact de lex/IFFD : padding 12, espacement 16. Avec un seul
        // token, aucune valeur ne satisfaisait les deux.
        await tester.pumpWidget(
          _host(
            const ZStudyToolsItemCard(
              title: 'Cours',
              leading: Icon(Icons.description_outlined),
              contentPadding: EdgeInsetsDirectional.all(12),
            ),
          ),
        );
        final BuildContext context = tester.element(_contentPadding);
        final double gapM = ZcrudTheme.of(context).gapM;

        expect(
          tester.widget<Padding>(_contentPadding).padding,
          const EdgeInsetsDirectional.all(12),
          reason: 'le padding de carte suit le slot',
        );
        // …et l'espacement icône → contenu reste sur le jeton : les deux rôles
        // sont bien découplés.
        final Iterable<SizedBox> gaps = tester
            .widgetList<SizedBox>(
              find.descendant(
                of: find.byType(ZStudyToolsItemCard),
                matching: find.byType(SizedBox),
              ),
            )
            .where((SizedBox b) => b.width != null);
        expect(
          gaps.map((SizedBox b) => b.width),
          contains(gapM),
          reason: 'le gap inter-slots ne doit PAS suivre le contentPadding',
        );
      },
    );
  });

  group('CR-LEX-71 — 🔴 un `Semantics` posé dans `badge` est ANNONCÉ', () {
    testWidgets('le cadenas « lecture seule » est trouvable dans l\'arbre', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ZStudyToolsItemCard(
            title: 'Cours de chimie',
            subtitle: 'Modifié hier',
            badge: Semantics(
              label: 'Lecture seule',
              child: const Icon(Icons.lock_outline),
            ),
          ),
        ),
      );

      // Le nœud DOIT exister : c'est toute la CR. Un `find.bySemanticsLabel`
      // vert ici et rouge sous la régression prouve la garde mordante.
      expect(find.bySemanticsLabel('Lecture seule'), findsOneWidget);

      handle.dispose();
    });

    testWidgets(
      'mais `title`/`subtitle` restent exclus : aucune double annonce',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            ZStudyToolsItemCard(
              title: 'Cours de chimie',
              subtitle: 'Modifié hier',
              badge: Semantics(
                label: 'Lecture seule',
                child: const Icon(Icons.lock_outline),
              ),
            ),
          ),
        );

        // Le libellé de la carte porte titre + sous-titre UNE fois ; les `Text`
        // eux-mêmes n'émettent aucun nœud (sinon l'item serait annoncé deux
        // fois — la raison d'être de l'`ExcludeSemantics`).
        expect(
          find.bySemanticsLabel('Cours de chimie, Modifié hier'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'^Cours de chimie$')),
          findsNothing,
        );
        expect(find.bySemanticsLabel(RegExp(r'^Modifié hier$')), findsNothing);

        handle.dispose();
      },
    );
  });

  group('CR-LEX-72 — typographie de l\'hôte atteignable', () {
    testWidgets('défauts ⇒ `titleSmall` / `bodySmall` / 1 ligne', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(title: 'Titre', subtitle: 'Sous-titre'),
        ),
      );
      final TextTheme textTheme = Theme.of(
        tester.element(find.text('Titre')),
      ).textTheme;
      final Text title = tester.widget<Text>(find.text('Titre'));
      final Text subtitle = tester.widget<Text>(find.text('Sous-titre'));

      expect(title.style, textTheme.titleSmall);
      expect(title.maxLines, 1);
      expect(subtitle.style, textTheme.bodySmall);
    });

    testWidgets('🔴 styles et `titleMaxLines` injectés sont APPLIQUÉS', (
      WidgetTester tester,
    ) async {
      const TextStyle t = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
      const TextStyle s = TextStyle(fontSize: 11);
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(
            title: 'Une question de flashcard qui tient sur deux lignes',
            subtitle: 'Sous-titre',
            titleStyle: t,
            subtitleStyle: s,
            titleMaxLines: 2,
          ),
        ),
      );
      final Text title = tester.widget<Text>(
        find.text('Une question de flashcard qui tient sur deux lignes'),
      );
      expect(title.style, t);
      expect(title.maxLines, 2, reason: 'la perte de rendu de lex est levée');
      expect(tester.widget<Text>(find.text('Sous-titre')).style, s);
    });

    testWidgets('`titleMaxLines` ≤ 0 replie sur 1 (AD-10), sans lever', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const ZStudyToolsItemCard(title: 'Titre', titleMaxLines: 0)),
      );
      expect(tester.widget<Text>(find.text('Titre')).maxLines, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('CR-LEX-73 — `margin` : slot > `CardTheme` > zéro', () {
    Card cardOf(WidgetTester tester) => tester.widget<Card>(
      find.descendant(
        of: find.byType(ZStudyToolsItemCard),
        matching: find.byType(Card),
      ),
    );

    testWidgets('défaut, thème muet ⇒ `EdgeInsets.zero` (rendu inchangé)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ZStudyToolsItemCard(title: 'Titre')));
      expect(cardOf(tester).margin, EdgeInsets.zero);
    });

    testWidgets('🔴 la marge du `CardTheme` de l\'hôte est LUE', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(title: 'Titre'),
          theme: ThemeData(
            cardTheme: const CardThemeData(margin: EdgeInsets.all(4)),
          ),
        ),
      );
      expect(
        cardOf(tester).margin,
        const EdgeInsets.all(4),
        reason: 'motif E3 : plus de `Padding` externe à réécrire par hôte',
      );
    });

    testWidgets('le slot l\'emporte sur le thème', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZStudyToolsItemCard(
            title: 'Titre',
            margin: EdgeInsetsDirectional.all(9),
          ),
          theme: ThemeData(
            cardTheme: const CardThemeData(margin: EdgeInsets.all(4)),
          ),
        ),
      );
      expect(cardOf(tester).margin, const EdgeInsetsDirectional.all(9));
    });
  });
}
