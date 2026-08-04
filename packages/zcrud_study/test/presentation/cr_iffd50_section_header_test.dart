/// **CR-IFFD-50** — l'en-tête de section : titre (①), compteur (②), action
/// secondaire à libellé VISIBLE (③), placement du chevron de repli (④).
///
/// 🔴 **Ce que ces gardes mesurent, et les angles morts qu'elles visent**
/// (une garde hérite de l'angle mort de son auteur) :
///
/// * ① le **style effectivement porté par le `Text` rendu** (taille/poids),
///   jamais « le token existe » ;
/// * ② la **couleur et la forme PEINTES** du badge (décoration résolue +
///   couleur du texte), lues depuis le `ColorScheme` AMBIANT — jamais un hex
///   attendu en dur, jamais un simple `findsOneWidget` ;
/// * ③ le **texte réellement rendu et cliquable** (géométrie dans la ligne
///   d'en-tête, cible ≥ 48 dp, tap qui déclenche), et **UNE seule annonce**
///   sémantique (le libellé visible, ou le `semanticLabel` qui PRIME — jamais
///   les deux) ;
/// * ④ les **rects relatifs** chevron/titre (dans la ligne vs dessous), la
///   variante **RTL** (côté fin = gauche), et la cible ≥ 48 dp **quand le
///   titre est long** (la réserve explicite de la CR).
///
/// Rétro-compatibilité : chaque point a son contrôle « thème muet ⇒ rendu
/// strictement antérieur ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZcrudTheme,
        ZStudySectionCollapsePlacement,
        ZStudySectionCountRole,
        ZStudySectionCountShape;
import 'package:zcrud_study/zcrud_study.dart';

const String kTitle = 'Documents';

ZStudyToolsSectionSpec _spec({
  String title = kTitle,
  int itemCount = 3,
  bool collapsible = false,
  bool initiallyExpanded = true,
  VoidCallback? secondaryAction,
  String? secondaryActionLabel,
  String? secondaryActionSemanticLabel,
  VoidCallback? addAction,
}) =>
    ZStudyToolsSectionSpec(
      id: 'docs',
      title: title,
      itemCount: itemCount,
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey<String>('item_$i'),
        height: 40,
        child: Text('Item $i'),
      ),
      emptyState: const Text('Aucun document'),
      collapsible: collapsible,
      initiallyExpanded: initiallyExpanded,
      secondaryAction: secondaryAction,
      secondaryActionLabel: secondaryActionLabel,
      secondaryActionSemanticLabel: secondaryActionSemanticLabel,
      addAction: addAction,
    );

Future<void> _pump(
  WidgetTester tester,
  ZStudyToolsSectionSpec spec, {
  ZcrudTheme? theme,
  double width = 400,
  TextDirection dir = TextDirection.ltr,
}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme == null
            ? null
            : ThemeData(extensions: <ThemeExtension<dynamic>>[theme]),
        home: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: ZSectionedStudyLayout(
                sections: <ZStudyToolsSectionSpec>[spec],
              ),
            ),
          ),
        ),
      ),
    );

/// Le `Container` de badge — l'ANCÊTRE direct du texte du compteur.
Container _badgeContainer(WidgetTester tester, String count) =>
    tester.widget<Container>(
      find.ancestor(of: find.text(count), matching: find.byType(Container)).first,
    );

void main() {
  // ───────────────────────────────────────────────────────────────── ① titre ─
  group('① — style du titre (token `studySectionTitleStyle`)', () {
    testWidgets('thème MUET ⇒ `titleMedium` ambiant (rendu antérieur)',
        (tester) async {
      await _pump(tester, _spec());
      final Text title = tester.widget<Text>(find.text(kTitle));
      final BuildContext ctx = tester.element(find.text(kTitle));
      final TextStyle? expected = Theme.of(ctx).textTheme.titleMedium;
      expect(title.style?.fontSize, expected?.fontSize);
      expect(title.style?.fontWeight, expected?.fontWeight);
    });

    testWidgets('🔴 token fourni ⇒ le style RENDU est celui du token '
        '(taille ET poids mesurés)', (tester) async {
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(
          studySectionTitleStyle:
              TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      );
      final Text title = tester.widget<Text>(find.text(kTitle));
      expect(title.style?.fontSize, 28);
      expect(title.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('le token PRIME sur `labelTextStyle` (ordre de repli)',
        (tester) async {
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(
          labelTextStyle: TextStyle(fontSize: 11),
          studySectionTitleStyle: TextStyle(fontSize: 28),
        ),
      );
      expect(tester.widget<Text>(find.text(kTitle)).style?.fontSize, 28);
    });
  });

  // ─────────────────────────────────────────────────────────────── ② compteur ─
  group('② — badge compteur (forme + RÔLE de couleur, mesurés PEINTS)', () {
    testWidgets('thème MUET ⇒ rectangle `radiusM` + `secondaryContainer` '
        '(rendu antérieur, couleurs du ColorScheme AMBIANT)', (tester) async {
      await _pump(tester, _spec());
      final BuildContext ctx = tester.element(find.text('3'));
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final Container badge = _badgeContainer(tester, '3');
      final BoxDecoration deco = badge.decoration! as BoxDecoration;
      expect(deco.color, scheme.secondaryContainer);
      expect(
        deco.borderRadius,
        const BorderRadius.all(Radius.circular(8)),
        reason: 'rayon historique = radiusM (8)',
      );
      final Text txt = tester.widget<Text>(find.text('3'));
      expect(txt.style?.color, scheme.onSecondaryContainer);
    });

    testWidgets('🔴 `pill` + rôle `primary` ⇒ stadium PEINT en '
        '`ColorScheme.primary`, texte `onPrimary` (inversé)', (tester) async {
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(
          studySectionCountShape: ZStudySectionCountShape.pill,
          studySectionCountRole: ZStudySectionCountRole.primary,
        ),
      );
      final BuildContext ctx = tester.element(find.text('3'));
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final Container badge = _badgeContainer(tester, '3');
      final ShapeDecoration deco = badge.decoration! as ShapeDecoration;
      expect(deco.shape, isA<StadiumBorder>(),
          reason: 'pastille = stadium, jamais un rayon magique');
      expect(deco.color, scheme.primary);
      expect(tester.widget<Text>(find.text('3')).style?.color, scheme.onPrimary,
          reason: 'texte INVERSÉ : le rôle porte le COUPLE fond/premier plan');
    });

    testWidgets('rôle `inverseSurface` ⇒ couple inverse du schéma ambiant',
        (tester) async {
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(
          studySectionCountRole: ZStudySectionCountRole.inverseSurface,
        ),
      );
      final BuildContext ctx = tester.element(find.text('3'));
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final BoxDecoration deco =
          _badgeContainer(tester, '3').decoration! as BoxDecoration;
      expect(deco.color, scheme.inverseSurface);
      expect(
        tester.widget<Text>(find.text('3')).style?.color,
        scheme.onInverseSurface,
      );
    });
  });

  // ──────────────────────────────────────────────────── ③ libellé visible ─
  group('③ — action secondaire à libellé VISIBLE (`secondaryActionLabel`)', () {
    testWidgets('`null` (défaut) ⇒ icône seule, rendu antérieur inchangé',
        (tester) async {
      await _pump(tester, _spec(secondaryAction: () {}));
      expect(find.byType(TextButton), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('section:docs:secondaryAction')),
        findsOneWidget,
      );
    });

    testWidgets('🔴 libellé fourni ⇒ texte RÉELLEMENT RENDU dans la ligne '
        'd\'en-tête, cible ≥ 48 dp, tap déclenché', (tester) async {
      int taps = 0;
      await _pump(
        tester,
        _spec(
          secondaryAction: () => taps++,
          secondaryActionLabel: 'Afficher tout',
        ),
      );
      // Texte VISIBLE (géométrie non nulle), pas seulement un nœud sémantique.
      final Finder label = find.text('Afficher tout');
      expect(label, findsOneWidget);
      final Rect labelRect = tester.getRect(label);
      expect(labelRect.width, greaterThan(0));
      // Dans la LIGNE d'en-tête : chevauchement vertical avec le titre.
      final Rect titleRect = tester.getRect(find.text(kTitle));
      expect(labelRect.top, lessThan(titleRect.bottom));
      expect(labelRect.bottom, greaterThan(titleRect.top));
      // Cible ≥ 48 dp et tap réel.
      final Finder button =
          find.byKey(const ValueKey<String>('section:docs:secondaryAction'));
      final Size size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('a11y : UNE seule annonce — le libellé visible', (tester) async {
      await _pump(
        tester,
        _spec(secondaryAction: () {}, secondaryActionLabel: 'Afficher tout'),
      );
      expect(find.bySemanticsLabel('Afficher tout'), findsOneWidget);
    });

    testWidgets('a11y : `secondaryActionSemanticLabel` fourni ⇒ il PRIME, '
        'jamais DEUX annonces divergentes', (tester) async {
      await _pump(
        tester,
        _spec(
          secondaryAction: () {},
          secondaryActionLabel: 'Afficher tout',
          secondaryActionSemanticLabel: 'Ouvrir la liste complète',
        ),
      );
      // L'annonce est le semanticLabel…
      expect(find.bySemanticsLabel('Ouvrir la liste complète'), findsOneWidget);
      // …le libellé visible n'est PAS annoncé en plus (remplacé, pas doublé)…
      expect(find.bySemanticsLabel('Afficher tout'), findsNothing);
      // …mais il reste RENDU à l'écran.
      expect(find.text('Afficher tout'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────── ④ placement du chevron ─
  group('④ — placement du chevron (token `studySectionCollapsePlacement`)', () {
    const ValueKey<String> collapseKey = ValueKey<String>('section:docs:collapse');

    testWidgets('thème MUET ⇒ chevron SOUS le titre (rects relatifs — rendu '
        'antérieur)', (tester) async {
      await _pump(tester, _spec(collapsible: true));
      final Rect chevron = tester.getRect(find.byKey(collapseKey));
      final Rect title = tester.getRect(find.text(kTitle));
      expect(chevron.center.dy, greaterThan(title.bottom),
          reason: 'le chevron reste rendu SOUS la ligne du titre');
    });

    testWidgets('🔴 `inHeaderRow` ⇒ chevron DANS la ligne du titre, côté FIN '
        '(LTR : à droite du titre et du badge)', (tester) async {
      await _pump(
        tester,
        _spec(collapsible: true, addAction: () {}),
        theme: const ZcrudTheme(
          studySectionCollapsePlacement:
              ZStudySectionCollapsePlacement.inHeaderRow,
        ),
      );
      final Rect chevron = tester.getRect(find.byKey(collapseKey));
      final Rect title = tester.getRect(find.text(kTitle));
      // MÊME ligne : chevauchement vertical des rects.
      expect(chevron.top, lessThan(title.bottom));
      expect(chevron.bottom, greaterThan(title.top));
      // Côté FIN (LTR = droite), APRÈS l'action d'ajout.
      expect(chevron.center.dx, greaterThan(title.center.dx));
      final Rect add = tester.getRect(find.byIcon(Icons.add));
      expect(chevron.center.dx, greaterThan(add.center.dx),
          reason: 'le chevron est le DERNIER élément de la ligne');
    });

    testWidgets('RTL : côté fin = GAUCHE (directionnel, jamais physique)',
        (tester) async {
      await _pump(
        tester,
        _spec(collapsible: true),
        theme: const ZcrudTheme(
          studySectionCollapsePlacement:
              ZStudySectionCollapsePlacement.inHeaderRow,
        ),
        dir: TextDirection.rtl,
      );
      final Rect chevron = tester.getRect(find.byKey(collapseKey));
      final Rect title = tester.getRect(find.text(kTitle));
      expect(chevron.top, lessThan(title.bottom));
      expect(chevron.bottom, greaterThan(title.top));
      expect(chevron.center.dx, lessThan(title.center.dx));
    });

    testWidgets('`inHeaderRow` : la bascule replie/déplie FONCTIONNE '
        '(même clé, même état)', (tester) async {
      await _pump(
        tester,
        _spec(collapsible: true, initiallyExpanded: false),
        theme: const ZcrudTheme(
          studySectionCollapsePlacement:
              ZStudySectionCollapsePlacement.inHeaderRow,
        ),
      );
      expect(find.byKey(const ValueKey<String>('item_0')), findsNothing);
      await tester.tap(find.byKey(collapseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('item_0')), findsOneWidget);
      await tester.tap(find.byKey(collapseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('item_0')), findsNothing);
    });

    testWidgets('🔴 réserve de la CR : titre LONG ⇒ la cible du chevron ne '
        'passe JAMAIS sous 48 dp (le titre s\'ellipse, pas la cible)',
        (tester) async {
      final String longTitle = 'Documents ${'très ' * 40}longs';
      await _pump(
        tester,
        _spec(title: longTitle, collapsible: true, addAction: () {}),
        theme: const ZcrudTheme(
          studySectionCollapsePlacement:
              ZStudySectionCollapsePlacement.inHeaderRow,
        ),
        width: 320,
      );
      final Size chevron = tester.getSize(find.byKey(collapseKey));
      expect(chevron.height, greaterThanOrEqualTo(48));
      expect(chevron.width, greaterThanOrEqualTo(48));
    });

    testWidgets('non repliable ⇒ AUCUN chevron, quel que soit le token',
        (tester) async {
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(
          studySectionCollapsePlacement:
              ZStudySectionCollapsePlacement.inHeaderRow,
        ),
      );
      expect(find.byKey(collapseKey), findsNothing);
    });
  });
}
