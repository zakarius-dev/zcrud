/// CR-IFFD-27 / 28 / 29 — jetons inertes, sous-titre absent, teinte nulle.
///
/// **CR-IFFD-27 (le plus grave, et c'est notre défaut)** : cinq jetons de
/// `ZcrudTheme` (`cardShadowBlurRadius`, `cardShadowOffset`, `cardShadowAlpha`,
/// `cardTintAlpha`, `iconContainerRadius`) étaient déclarés, présents dans
/// `copyWith`, interpolés dans `lerp`… et lus par AUCUN widget. Un hôte les
/// réglait, rien ne changeait, sans aucun signal. *Un jeton que personne ne lit
/// est un jeton qui ment.*
///
/// 🔴 **Garde anti-jeton-inerte** — c'est la garde structurante de ce fichier :
/// chaque jeton doit produire un effet **observable** quand on l'injecte SEUL.
/// Elle est ce qui empêche la récidive : retirer la lecture d'un seul des cinq
/// jetons fait rougir exactement une assertion.
///
/// **CR-IFFD-28** : `ZFolderCard` n'avait aucun sous-titre, alors que
/// `belowSubtitle` existe depuis v0.23.0 sur `ZStudyToolsItemCard` **et**
/// `ZStudyNoteCard` — couverture inégale sur une même famille de cartes. Le
/// contournement (composer le sous-titre dans le slot `counts`) trahit la
/// sémantique du slot.
///
/// **CR-IFFD-29** : `tintAlpha: 0` rendait la carte TRANSPARENTE (on voyait le
/// fond d'écran), jamais « carte de surface normale ». Même motif que CR-LEX-61
/// (`shape`) et CR-LEX-73 (`margin`) : ne pas imposer une décision que le
/// `CardTheme` exprime déjà.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const Key _belowKey = Key('below-subtitle');

Future<void> _pumpFolder(
  WidgetTester tester, {
  ZcrudTheme theme = const ZcrudTheme(),
  CardThemeData cardTheme = const CardThemeData(),
  double? tintAlpha,
  Widget? belowSubtitle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(cardTheme: cardTheme),
      home: ZcrudScope(
        theme: theme,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 160,
                child: ZFolderCard(
                  title: 'Valeur en douane',
                  colorKey: 'primary',
                  tintAlpha: tintAlpha,
                  belowSubtitle: belowSubtitle,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpItem(
  WidgetTester tester, {
  ZcrudTheme theme = const ZcrudTheme(),
  Widget? belowSubtitle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ZcrudScope(
        theme: theme,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: ZStudyToolsItemCard(
                  title: 'Cours de chimie.pdf',
                  belowSubtitle: belowSubtitle,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Les ombres peintes par la décoration, sur les `DecoratedBox` ANCÊTRES de la
/// carte. Vide quand aucun jeton `cardShadow*` n'est fourni.
List<BoxShadow> _shadows(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.ancestor(
        of: find.byType(Card),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((DecoratedBox b) => b.decoration)
    .whereType<BoxDecoration>()
    .expand((BoxDecoration d) => d.boxShadow ?? const <BoxShadow>[])
    .toList();

Card _card(WidgetTester tester) => tester.widget<Card>(find.byType(Card));

/// Décoration de la pastille d'accent : sans badge « Archivé », c'est le seul
/// `Container` du sous-arbre de la carte.
BoxDecoration _pastille(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(Card),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  group('CR-IFFD-27 — anti-jeton-inerte : chaque jeton a un effet OBSERVABLE', () {
    testWidgets('cardShadowBlurRadius SEUL pilote le flou (ZFolderCard)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester, theme: const ZcrudTheme(cardShadowBlurRadius: 30));
      final List<BoxShadow> shadows = _shadows(tester);
      // 🔴 Régression à ré-injecter : ignorer `theme.cardShadowBlurRadius` dans
      // `zResolveCardShadowDecoration` (le remplacer par la constante).
      expect(shadows, hasLength(1));
      expect(shadows.single.blurRadius, 30);
      expect(
        _card(tester).elevation,
        0,
        reason: 'deux ombres ne se superposent pas : l\'élévation native cède',
      );
    });

    testWidgets('cardShadowOffset SEUL pilote le décalage (ZFolderCard)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(
        tester,
        theme: const ZcrudTheme(cardShadowOffset: Offset(3, 7)),
      );
      // 🔴 Régression : ignorer `theme.cardShadowOffset`.
      expect(_shadows(tester).single.offset, const Offset(3, 7));
    });

    testWidgets('cardShadowAlpha SEUL pilote l\'opacité (ZFolderCard)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester, theme: const ZcrudTheme(cardShadowAlpha: 0.5));
      final BoxShadow shadow = _shadows(tester).single;
      // 🔴 Régression : ignorer `theme.cardShadowAlpha`.
      expect(shadow.color.a, closeTo(0.5, 0.001));
      // L'ombre doit rester VISIBLE quand seul l'alpha est fourni : un flou et
      // un décalage nuls la cacheraient entièrement derrière la carte opaque —
      // ce serait recréer le jeton menteur que cette CR corrige.
      expect(shadow.blurRadius, kZCardShadowBlurRadius);
      expect(shadow.offset, kZCardShadowOffset);
      expect(kZCardShadowBlurRadius, greaterThan(0));
      expect(kZCardShadowOffset, isNot(Offset.zero));
    });

    testWidgets('les jetons cardShadow* valent AUSSI pour ZStudyToolsItemCard', (
      WidgetTester tester,
    ) async {
      await _pumpItem(
        tester,
        theme: const ZcrudTheme(
          cardShadowBlurRadius: 21,
          cardShadowOffset: Offset(0, 5),
          cardShadowAlpha: 0.4,
        ),
      );
      // 🔴 Régression : retirer l'appel à `zResolveCardShadowDecoration` dans
      // `z_study_tools_item_card.dart`. La CR visait les DEUX cartes, « pour ne
      // pas voir le défaut réapparaître sur une troisième ».
      final BoxShadow shadow = _shadows(tester).single;
      expect(shadow.blurRadius, 21);
      expect(shadow.offset, const Offset(0, 5));
      expect(shadow.color.a, closeTo(0.4, 0.001));
      expect(_card(tester).elevation, 0);
    });

    testWidgets('cardTintAlpha SEUL pilote la teinte de fond (ZFolderCard)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester, theme: const ZcrudTheme(cardTintAlpha: 0.4));
      // 🔴 Régression : retirer `?? theme.cardTintAlpha` de la résolution.
      expect(_card(tester).color!.a, closeTo(0.4, 0.001));
    });

    testWidgets('le slot tintAlpha PRIME sur le jeton cardTintAlpha', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(
        tester,
        theme: const ZcrudTheme(cardTintAlpha: 0.4),
        tintAlpha: 0.9,
      );
      expect(_card(tester).color!.a, closeTo(0.9, 0.001));
    });

    testWidgets('iconContainerRadius SEUL pilote la pastille (ZFolderCard)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(
        tester,
        theme: const ZcrudTheme(iconContainerRadius: Radius.circular(3)),
      );
      // 🔴 Régression : forcer `shape: BoxShape.circle` inconditionnellement.
      final BoxDecoration deco = _pastille(tester);
      expect(deco.shape, BoxShape.rectangle);
      expect(deco.borderRadius, const BorderRadius.all(Radius.circular(3)));
    });
  });

  group('CR-IFFD-27 — défaut `null` ⇒ rendu STRICTEMENT inchangé', () {
    testWidgets('ZFolderCard : aucune ombre, élévation native, pastille ronde', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester);
      expect(
        _shadows(tester),
        isEmpty,
        reason: 'sans jeton, aucune décoration d\'ombre n\'est introduite',
      );
      expect(
        _card(tester).elevation,
        isNull,
        reason: 'l\'élévation native de Card doit rester intacte',
      );
      final BoxDecoration deco = _pastille(tester);
      expect(deco.shape, BoxShape.circle);
      expect(deco.borderRadius, isNull);
      expect(
        _card(tester).color!.a,
        closeTo(kZFolderCardTintAlpha, 0.001),
        reason: 'la teinte par défaut reste la parité lex 0.12',
      );
    });

    testWidgets('ZStudyToolsItemCard : aucune ombre, élévation native', (
      WidgetTester tester,
    ) async {
      await _pumpItem(tester);
      expect(_shadows(tester), isEmpty);
      expect(_card(tester).elevation, isNull);
    });

    testWidgets('la marge du CardTheme survit à l\'activation de l\'ombre', (
      WidgetTester tester,
    ) async {
      // Sans ombre : la marge est portée par le `Card` (comportement CR-LEX-73).
      await _pumpFolder(tester, cardTheme: const CardThemeData(margin: EdgeInsets.all(6)));
      expect(_card(tester).margin, const EdgeInsets.all(6));
      // On mesure la SURFACE PEINTE (le `Material` du `Card`), pas la boîte du
      // widget `Card` : cette dernière englobe la marge quand le `Card` la
      // porte lui-même, et ne l'englobe plus quand elle passe au `Padding`.
      final Rect sansOmbre = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );

      // Avec ombre : la marge passe à un `Padding` externe pour que la boîte
      // ombrée épouse la CARTE et non sa marge — la géométrie rendue de la
      // carte doit être IDENTIQUE.
      // 🔴 Régression : laisser `margin: cardMargin` sur le `Card` dans le
      // chemin ombré ⇒ la marge serait comptée deux fois.
      await _pumpFolder(
        tester,
        cardTheme: const CardThemeData(margin: EdgeInsets.all(6)),
        theme: const ZcrudTheme(cardShadowBlurRadius: 12),
      );
      expect(_card(tester).margin, EdgeInsets.zero);
      expect(
        tester.getRect(
          find
              .descendant(
                of: find.byType(Card),
                matching: find.byType(Material),
              )
              .first,
        ),
        sansOmbre,
      );
    });
  });

  group('CR-IFFD-28 — sous-titre de ZFolderCard, au MÊME contrat que ses sœurs', () {
    testWidgets('`null` ⇒ aucun nœud, aucun espacement', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester);
      expect(find.byKey(_belowKey), findsNothing);
      final Rect titreSansSlot = tester.getRect(find.text('Valeur en douane'));
      final int colonnesSansSlot = tester
          .widgetList(
            find.descendant(of: find.byType(Card), matching: find.byType(Column)),
          )
          .length;

      await _pumpFolder(
        tester,
        belowSubtitle: const Text('Douane', key: _belowKey),
      );
      expect(find.byKey(_belowKey), findsOneWidget);
      // 🔴 Preuve du « aucun nœud quand `null` » : la colonne qui porte le
      // couple titre/sous-titre n'existe QUE lorsque le slot est fourni.
      // Régression à ré-injecter : construire cette `Column` inconditionnellement
      // ⇒ l'arbre par défaut change (et les goldens rougissent).
      expect(
        tester
            .widgetList(
              find.descendant(
                of: find.byType(Card),
                matching: find.byType(Column),
              ),
            )
            .length,
        colonnesSansSlot + 1,
      );
      // Le bloc titre + sous-titre reste ancré EN BAS (patron anti-overflow) :
      // le titre remonte de la hauteur du sous-titre, il ne le chevauche pas.
      final Rect titreAvecSlot = tester.getRect(find.text('Valeur en douane'));
      expect(titreAvecSlot.bottom, lessThan(titreSansSlot.bottom));
      expect(
        tester.getRect(find.byKey(_belowKey)).bottom,
        closeTo(titreSansSlot.bottom, 0.01),
      );
    });

    testWidgets('rendu SOUS le titre, dans la même colonne (alignement start)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(
        tester,
        belowSubtitle: const Text('Douane', key: _belowKey),
      );
      final Rect titre = tester.getRect(find.text('Valeur en douane'));
      final Rect sous = tester.getRect(find.byKey(_belowKey));
      // 🔴 Régression : rendre `belowSubtitle` dans la `Row` de pied (le
      // contournement `counts` que la CR dénonce) ⇒ le slot passerait sous le
      // pied de carte, plus dans la colonne du titre.
      expect(sous.top, greaterThanOrEqualTo(titre.bottom - 0.01));
      expect(sous.left, closeTo(titre.left, 0.01));
    });

    testWidgets(
      'sémantique PRÉSERVÉE — même traitement que ZStudyToolsItemCard',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await _pumpFolder(
          tester,
          belowSubtitle: const Text('Mathématiques', key: _belowKey),
        );
        // 🔴 Régression : envelopper `belowSubtitle` d'un `ExcludeSemantics`
        // (comme `topAccent`/`footer`, qui sont des DÉCORS) ⇒ le slot
        // deviendrait muet au lecteur d'écran, à rebours du contrat des deux
        // cartes sœurs.
        expect(
          find.bySemanticsLabel('Mathématiques'),
          findsOneWidget,
          reason: 'ZFolderCard doit préserver la sémantique du slot',
        );

        await _pumpItem(
          tester,
          belowSubtitle: const Text('Mathématiques', key: _belowKey),
        );
        expect(
          find.bySemanticsLabel('Mathématiques'),
          findsOneWidget,
          reason: 'contrat de référence : ZStudyToolsItemCard (CR-LEX-75)',
        );

        handle.dispose();
      },
    );
  });

  group('CR-IFFD-29 — `tintAlpha: 0` ⇒ surface NEUTRE, jamais transparente', () {
    testWidgets('avec CardTheme.color, la carte adopte la couleur du thème', (
      WidgetTester tester,
    ) async {
      const Color neutre = Color(0xFF123456);
      await _pumpFolder(
        tester,
        tintAlpha: 0,
        cardTheme: const CardThemeData(color: neutre),
      );
      // 🔴 Régression : revenir à `pair.color.withValues(alpha: tintAlpha)`
      // inconditionnel ⇒ `color.a == 0`, carte transparente.
      final Color? color = _card(tester).color;
      expect(color, neutre);
      expect(color!.a, 1.0, reason: 'jamais transparente');
    });

    testWidgets('sans CardTheme.color, repli sur le défaut Material (opaque)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester, tintAlpha: 0);
      // Comportement de repli DOCUMENTÉ : le widget n'impose plus de couleur,
      // `Card` résout alors son propre défaut de surface — opaque.
      expect(_card(tester).color, isNull);
      final Material material = tester.widget<Material>(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      expect(material.color!.a, 1.0, reason: 'surface opaque, pas le fond d\'écran');
    });

    testWidgets('une valeur > 0 teinte toujours (comportement conservé)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(
        tester,
        tintAlpha: 0.5,
        cardTheme: const CardThemeData(color: Color(0xFF123456)),
      );
      final Color color = _card(tester).color!;
      expect(color.a, closeTo(0.5, 0.001));
      expect(color, isNot(const Color(0xFF123456)));
    });

    testWidgets('une valeur négative est traitée comme 0 (AD-10)', (
      WidgetTester tester,
    ) async {
      const Color neutre = Color(0xFF123456);
      await _pumpFolder(
        tester,
        tintAlpha: -1,
        cardTheme: const CardThemeData(color: neutre),
      );
      expect(_card(tester).color, neutre);
    });

    testWidgets('une valeur > 1 est clampée au lieu de lever (AD-10)', (
      WidgetTester tester,
    ) async {
      await _pumpFolder(tester, tintAlpha: 4);
      expect(_card(tester).color!.a, 1.0);
    });
  });
}
