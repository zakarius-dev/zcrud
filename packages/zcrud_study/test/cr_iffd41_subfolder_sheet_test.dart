/// **CR-IFFD-41** — la référence visuelle de la barre de fratrie est fixée sur
/// la maquette IFFD, en séparant STRUCTURE (socle) et LOOK (tokens + hôte).
///
/// Deux décisions du propriétaire sont ici GARDÉES, pas discutées :
///
/// 1. **Séparation structure / préréglage** — aucune couleur, aucun glyphe,
///    aucun libellé n'entre dans un paquet (FR-26/NFR-S7). Les cinq points de
///    structure sont codés dans le socle ; les quatre points de look passent par
///    des tokens `ZcrudTheme` **nullables** dont l'absence rend **strictement
///    comme avant**.
/// 2. **La feuille modale REMPLACE le déploiement en ligne** de v0.34.0. Ce
///    n'est pas la correction d'un défaut : l'hôte ne prétend pas que l'inline
///    en fût un. C'est donc un changement de COMPORTEMENT à documenter, sans
///    rupture d'API (`ZSubfolderNarrowMode.selector` et `compact` intacts).
///
/// 🔴 **Ce que ces gardes cherchent à ne PAS être** : « une garde hérite de
/// l'angle mort de son auteur ». Chaque mesure de look est doublée d'un
/// **contrôle négatif** (le même arbre, sans préréglage, doit rendre l'autre
/// valeur), chaque plancher de 48 dp est **borné par le haut**, et l'inversion
/// est mesurée sur le **contraste réellement peint** — jamais sur la présence
/// d'une décoration.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

// ---------------------------------------------------------------------------
// Outillage
// ---------------------------------------------------------------------------

/// Préréglage « façon IFFD » — **jamais un hex** : une variante, deux glyphes,
/// un mode de contraste. C'est la moitié « look » que l'hôte injecte.
const ZcrudTheme _kIffdPreset = ZcrudTheme(
  subfolderTriggerVariant: ZSubfolderTriggerVariant.outlined,
  subfolderTriggerCollapsedIcon: Icons.arrow_drop_down,
  subfolderTriggerExpandedIcon: Icons.arrow_drop_up,
  subfolderSelectedEmphasis: ZSubfolderSelectedEmphasis.inverted,
);

const String _kSheetTitle = 'SHEET_TITLE';
const String _kActionLabel = 'ITEM_ACTION';

/// Enveloppe injectant [theme] par `ZcrudScope` — **et non** par
/// `ThemeData.extensions`.
///
/// 🔴 Le choix est délibéré : `ZcrudScope` est un `InheritedWidget` nu, il n'est
/// **pas** capturé par `showModalBottomSheet`. Faire passer le préréglage par là
/// mesure donc, en plus du token, sa SURVIE dans l'`Overlay`. Le passer par
/// `ThemeData` aurait rendu toutes les gardes de look vertes même si la feuille
/// perdait le scope.
Widget Function(Widget) _scoped(ZcrudTheme theme) =>
    (Widget child) => ZcrudScope(theme: theme, child: child);

/// Spec paramétrable : le harnais partagé ne connaît pas les slots CR-IFFD-41.
ZSubfolderNavSpec _spec({
  String? sheetTitle,
  VoidCallback? addAction,
  ZSubfolderItemActionBuilder? itemActionBuilder,
  ZSubfolderItemBuilder? itemBuilder,
  ZSubfolderNarrowMode? narrowMode,
  List<ZSubfolderRef>? subfolders,
}) {
  final ZSubfolderNavSpec base = navSpec(
    subfolders: subfolders,
    addAction: addAction,
    itemBuilder: itemBuilder,
    narrowMode: narrowMode,
  );
  return ZSubfolderNavSpec(
    subfolders: base.subfolders,
    allSubfoldersLabel: base.allSubfoldersLabel,
    itemBuilder: base.itemBuilder,
    itemActionBuilder: itemActionBuilder,
    narrowMode: base.narrowMode,
    sheetTitle: sheetTitle,
    addAction: base.addAction,
    addLabel: base.addLabel,
    addIcon: base.addIcon,
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
  await tester.pumpAndSettle();
}

/// Taille RENDUE (jamais une contrainte déclarée : un parent peut l'écraser).
Size _size(WidgetTester tester, Finder f) =>
    (tester.renderObject(f) as RenderBox).size;

/// `ColorScheme` réellement actif sous la feuille.
ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(ZSubfolderSelectorBar.sheetKey)))
        .colorScheme;

/// Fond RÉELLEMENT peint derrière l'item [id] de la feuille.
Color? _itemBackground(WidgetTester tester, String id) {
  final Iterable<Container> containers = tester.widgetList<Container>(
    find.descendant(
      of: find.byKey(ZSubfolderSelectorBar.itemKey(id)),
      matching: find.byType(Container),
    ),
  );
  for (final Container c in containers) {
    final Decoration? d = c.decoration;
    if (d is BoxDecoration && d.shape != BoxShape.circle && d.color != null) {
      return d.color;
    }
  }
  return null;
}

/// Couleur RÉELLEMENT appliquée au texte de l'item [id] — lue sur le
/// `RenderParagraph` après fusion du `DefaultTextStyle` ambiant, donc ni sur le
/// widget `Text` (qui ne porte aucun style) ni sur une intention déclarée.
///
/// ⚠️ Portée à l'ITEM : le même libellé est aussi peint dans le déclencheur, et
/// une mesure non portée lirait l'un pour l'autre.
Color? _paintedTextColor(WidgetTester tester, String id, String label) =>
    (tester.renderObject(
              find.descendant(
                of: find.byKey(ZSubfolderSelectorBar.itemKey(id)),
                matching: find.text(label),
              ),
            )
            as RenderParagraph)
        .text
        .style
        ?.color;

/// Écart de luminance entre deux couleurs — proxy honnête du contraste.
double _contrast(Color a, Color b) =>
    (a.computeLuminance() - b.computeLuminance()).abs();

void main() {
  // -------------------------------------------------------------------------
  // 1. NEUTRALITÉ — sans préréglage, les QUATRE points de look sont INCHANGÉS
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — sans préréglage, rendu strictement inchangé', () {
    testWidgets('point 1 : AUCUN habillage de déclencheur dans l\'arbre', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      // « Absent de l'arbre » et non « transparent » : c'est la seule forme
      // d'inchangé qu'on puisse prouver (AD-4).
      expect(
        find.byKey(ZSubfolderSelectorBar.triggerChromeKey),
        findsNothing,
      );
    });

    testWidgets('point 2 : chevron conventionnel `expand_more`/`expand_less`', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      final Finder chevron = find.byKey(ZSubfolderSelectorBar.chevronKey);
      expect(tester.widget<Icon>(chevron).icon, Icons.expand_more);
      await _open(tester);
      expect(tester.widget<Icon>(chevron).icon, Icons.expand_less);
    });

    testWidgets('point 4 : aucun titre de feuille (slot ABSENT)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: _spec());
      await _open(tester);

      expect(find.byKey(ZSubfolderSelectorBar.sheetTitleKey), findsNothing);
    });

    testWidgets('point 6 : SURLIGNAGE (`secondaryContainer`), premier plan '
        'HÉRITÉ — pas d\'inversion', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, initialSelectedSubfolderId: 'sf1');
      await _open(tester);

      final ColorScheme scheme = _scheme(tester);
      expect(_itemBackground(tester, 'sf1'), scheme.secondaryContainer);
      // 🔴 LA garde de non-inversion : le texte NE doit PAS avoir été forcé.
      // Vérifier le seul fond laisserait passer un socle qui inverserait le
      // premier plan par défaut — c'est exactement l'angle mort visé.
      expect(
        _paintedTextColor(tester, 'sf1', 'Sous-dossier 1'),
        isNot(scheme.onInverseSurface),
      );
    });

    testWidgets('points 8 et 9 : slots ABSENTS quand rien n\'est fourni', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: _spec());
      await _open(tester);

      expect(find.byKey(ZSubfolderSelectorBar.footerAddKey), findsNothing);
      for (final String id in <String>['', 'sf0', 'sf1', 'sf2']) {
        expect(find.byKey(ZSubfolderSelectorBar.itemActionKey(id)), findsNothing);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 2. AVEC PRÉRÉGLAGE — les quatre points de look basculent RÉELLEMENT
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — avec préréglage, les 4 points de look sont rendus', () {
    testWidgets('point 1 : déclencheur CONTOUR, bordure dérivée du ColorScheme',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, wrap: _scoped(_kIffdPreset));

      final Finder chrome = find.byKey(ZSubfolderSelectorBar.triggerChromeKey);
      expect(chrome, findsOneWidget);
      // CR-IFFD-60 : le chrome est un `Material` (l'encre de l'`InkWell` doit
      // se dessiner AU-DESSUS du fond — un `DecoratedBox` opaque l'avalerait).
      final Material m = tester.widget<Material>(chrome);
      final ColorScheme scheme =
          Theme.of(tester.element(chrome)).colorScheme;
      // CONTOUR : bordure présente, fond ABSENT (alpha 0) — « rempli » serait
      // l'inverse, et c'est ce qui distingue les deux valeurs de l'enum.
      final RoundedRectangleBorder shape = m.shape! as RoundedRectangleBorder;
      expect(shape.side, isNot(BorderSide.none));
      expect(m.color?.a, 0.0, reason: 'outlined ne peint AUCUN fond');
      expect(
        shape.side.color,
        scheme.outlineVariant,
        reason: 'aucun hex : la bordure est un RÔLE du ColorScheme',
      );
    });

    testWidgets('point 1 bis : `filled` rend le CONTRAIRE de `outlined`', (
      tester,
    ) async {
      // Contrôle négatif de l'enum : sans lui, un socle qui rendrait toujours
      // « contour » serait vert sur la garde précédente.
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerVariant: ZSubfolderTriggerVariant.filled,
          ),
        ),
      );

      final Finder chrome = find.byKey(ZSubfolderSelectorBar.triggerChromeKey);
      final Material m = tester.widget<Material>(chrome);
      expect((m.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(
        m.color,
        Theme.of(tester.element(chrome)).colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('point 2 : chevron = TRIANGLE PLEIN, dans les DEUX états', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, wrap: _scoped(_kIffdPreset));

      final Finder chevron = find.byKey(ZSubfolderSelectorBar.chevronKey);
      expect(tester.widget<Icon>(chevron).icon, Icons.arrow_drop_down);
      await _open(tester);
      // Le glyphe reste un ÉTAT lisible : un préréglage qui figerait le chevron
      // rendrait l'affordance décorative.
      expect(tester.widget<Icon>(chevron).icon, Icons.arrow_drop_up);
    });

    testWidgets('point 4 : le titre INJECTÉ est affiché dans la feuille', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: _spec(sheetTitle: _kSheetTitle));
      await _open(tester);

      final Finder title = find.byKey(ZSubfolderSelectorBar.sheetTitleKey);
      expect(title, findsOneWidget);
      // Deux chemins DISTINCTS : le texte AFFICHÉ, et la valeur réellement
      // portée par le widget. Vider l'un ne fait pas rougir l'autre.
      expect(find.text(_kSheetTitle), findsOneWidget);
      expect(tester.widget<Text>(title).data, _kSheetTitle);
    });

    testWidgets('point 6 : l\'élément courant est INVERSÉ — contraste MESURÉ', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        wrap: _scoped(_kIffdPreset),
      );
      await _open(tester);

      final ColorScheme scheme = _scheme(tester);
      final Color? bg = _itemBackground(tester, 'sf1');
      final Color? fg = _paintedTextColor(tester, 'sf1', 'Sous-dossier 1');

      // (a) le couple de RÔLES est bien celui de l'inversion…
      expect(bg, scheme.inverseSurface);
      expect(fg, scheme.onInverseSurface);
      // (b) …et il produit un contraste RÉEL, mesuré sur les couleurs peintes.
      //     Sans (b), un socle qui poserait un fond opaque en laissant le texte
      //     hériter (donc illisible) resterait vert : c'est le défaut que
      //     l'hôte décrit, et c'est le contraste — pas la décoration — qui est
      //     la capacité demandée.
      // (b) …et le couple est RÉELLEMENT lisible : le texte tranche sur son
      //     propre fond. Sans cette mesure, poser un fond opaque en laissant le
      //     texte hériter (donc illisible) resterait vert — c'est précisément
      //     le défaut que l'hôte décrit.
      expect(_contrast(bg!, fg!), greaterThan(0.5));
      // (c) …et il SÉPARE davantage que le surlignage qu'il remplace. C'est
      //     l'affirmation exacte de l'hôte (« un surlignage doux ne le
      //     remplace pas »), mesurée sur les DEUX fonds réellement disponibles
      //     et non sur une impression. Un socle qui rendrait `inverted` comme
      //     `highlight` rougirait ici.
      final Color plain = _itemBackground(tester, 'sf0') ?? scheme.surface;
      expect(
        _contrast(bg, plain),
        greaterThan(_contrast(scheme.secondaryContainer, plain)),
        reason: '🔴 l\'inversion doit détacher l\'élément courant PLUS que le '
            'surlignage `secondaryContainer` du rendu par défaut',
      );
    });

    testWidgets('point 6 bis : les ICÔNES de l\'hôte s\'inversent aussi', (
      tester,
    ) async {
      // L'hôte insiste : « texte ET icônes inversés ». Un `DefaultTextStyle`
      // seul laisserait les glyphes d'un `itemBuilder` injecté à la couleur
      // ambiante — invisibles sur le fond opaque.
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(
          itemBuilder: (context, ref, selected) =>
              Icon(Icons.folder, key: ValueKey<String>('ic:${ref.id}')),
        ),
        wrap: _scoped(_kIffdPreset),
      );
      await _open(tester);

      final ColorScheme scheme = _scheme(tester);

      /// `IconTheme` RÉELLEMENT en vigueur là où le glyphe est peint — mesuré
      /// DANS la feuille, jamais sur une observation faite au vol par le
      /// builder (le déclencheur invoque le MÊME builder avec
      /// `selected: true` : une trace globale ne saurait pas de qui elle parle).
      Color? iconColor(String id) => IconTheme.of(
        tester.element(
          find.descendant(
            of: find.byKey(ZSubfolderSelectorBar.itemKey(id)),
            matching: find.byKey(ValueKey<String>('ic:$id')),
          ),
        ),
      ).color;

      expect(iconColor('sf1'), scheme.onInverseSurface);
      // CONTRÔLE NÉGATIF : un item NON courant garde la couleur ambiante — sans
      // lui, inverser TOUT le monde serait indiscernable.
      expect(iconColor('sf0'), isNot(scheme.onInverseSurface));
    });
  });

  // -------------------------------------------------------------------------
  // 3. STRUCTURE — feuille modale (point 3), ouverture / fermeture
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — point 3 : la fratrie se déploie en FEUILLE MODALE', () {
    testWidgets('la feuille FLOTTE : elle n\'est pas dans le sous-arbre de la '
        'barre', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await _open(tester);

      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsOneWidget);
      // 🔴 LA garde du changement de forme : en v0.34.0 le panneau était un
      // ENFANT de la barre. Le remettre en ligne rougit ici.
      expect(
        find.descendant(
          of: find.byKey(ZSubfolderSelectorBar.barKey),
          matching: find.byKey(ZSubfolderSelectorBar.sheetKey),
        ),
        findsNothing,
      );
      // Et c'est bien une route modale : un barrier la recouvre.
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('hauteur bornée à 80 % de l\'écran — cap RÉELLEMENT atteint', (
      tester,
    ) async {
      const double h = 800;
      await setScreen(tester, 500, h);
      await pumpDetail(
        tester,
        nav: _spec(
          sheetTitle: _kSheetTitle,
          addAction: () {},
          subfolders: <ZSubfolderRef>[
            for (int i = 0; i < 40; i++)
              ZSubfolderRef(id: 'sf$i', label: 'Sous-dossier $i'),
          ],
        ),
      );
      await _open(tester);

      final double sheet = _size(
        tester,
        find.byKey(ZSubfolderSelectorBar.sheetKey),
      ).height;
      expect(sheet, lessThanOrEqualTo(h * 0.8 + 0.01));
      // 🔴 Borne BASSE indispensable : avec 40 items, une feuille qui ne
      // toucherait pas le plafond signifierait que la contrainte n'est jamais
      // exercée — la garde serait verte sur n'importe quel plafond.
      expect(
        sheet,
        greaterThan(h * 0.5),
        reason: 'avec 40 items le contenu DOIT saturer le plafond',
      );
    });

    testWidgets('fermer SANS choisir : la feuille part ET l\'état se répercute',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await _open(tester);

      final Finder chevron = find.byKey(ZSubfolderSelectorBar.chevronKey);
      expect(tester.widget<Icon>(chevron).icon, Icons.expand_less);

      // Fermeture par le barrier, comme un utilisateur.
      await tester.tapAt(const Offset(250, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
      // 🔴 GARDE MORDANTE : oublier de remettre l'état à `false` après le
      // `await` laisserait le chevron ouvert et `expanded: true` annoncé, sur
      // une feuille disparue. Le rendu de la page serait pourtant correct.
      expect(tester.widget<Icon>(chevron).icon, Icons.expand_more);
      final SemanticsHandle handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(ZSubfolderSelectorBar.triggerKey)),
        isSemantics(isExpanded: false),
      );
      handle.dispose();
    });

    testWidgets('choisir : la feuille se referme, le corps ET la barre suivent',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await _open(tester);

      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf2')));
      await tester.pumpAndSettle();

      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
      expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);
      expect(find.text('Sous-dossier 2'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byKey(ZSubfolderSelectorBar.chevronKey)).icon,
        Icons.expand_more,
      );
    });

    testWidgets('AD-10 : sans `Navigator`, la barre reste INERTE (aucun crash)',
        (tester) async {
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await setScreen(tester, 500, 800);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(500, 800)),
            child: Material(
              child: ZSubfolderSelectorBar(
                spec: _spec(),
                selected: ValueNotifier<String?>(null),
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
      expect(
        reported.any(
          (FlutterErrorDetails d) =>
              d.exception.toString().contains('aucun Navigator'),
        ),
        isTrue,
        reason: 'l\'échec doit rester DÉBOGABLE, jamais silencieux',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 4. STRUCTURE — points 5 et 7 : indentation directionnelle, racine-ITEM
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — point 7 : la racine est un ITEM de la liste', () {
    testWidgets('elle est SÉLECTIONNABLE et ramène le corps à « tous »', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, initialSelectedSubfolderId: 'sf1');
      await _open(tester);

      expect(find.byKey(ZSubfolderSelectorBar.itemKey('')), findsOneWidget);
      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('')));
      await tester.pumpAndSettle();

      // 🔴 Un EN-TÊTE ne se tape pas : rendre la racine en titre rougit ici.
      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
      expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
      expect(find.text(kAllLabel), findsOneWidget);
    });

    testWidgets('elle porte `selected` comme n\'importe quel item', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await _open(tester);

      final SemanticsHandle handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(ZSubfolderSelectorBar.itemKey(''))),
        isSemantics(isSelected: true, label: kAllLabel),
      );
      // Contrôle négatif : poser `selected: true` en dur serait indiscernable.
      expect(
        tester.getSemantics(find.byKey(ZSubfolderSelectorBar.itemKey('sf0'))),
        isSemantics(isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('elle N\'EST PAS indentée — seule la fratrie l\'est', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await _open(tester);

      expect(find.byKey(ZSubfolderSelectorBar.indentKey('')), findsNothing);
      for (final String id in <String>['sf0', 'sf1', 'sf2']) {
        expect(find.byKey(ZSubfolderSelectorBar.indentKey(id)), findsOneWidget);
      }
    });
  });

  group('CR-IFFD-41 — point 5 : indentation 24 dp + filet, DIRECTIONNELS', () {
    /// Décalage SIGNÉ du contenu par rapport à son enveloppe d'indentation, du
    /// côté du DÉBUT de lecture. Positif = décalé vers la droite.
    double delta(WidgetTester tester, String id) {
      final Rect outer = tester.getRect(
        find.byKey(ZSubfolderSelectorBar.indentKey(id)),
      );
      final Rect inner = tester.getRect(
        find.byKey(ZSubfolderSelectorBar.itemKey(id)),
      );
      return inner.left - outer.left;
    }

    testWidgets('LTR : le contenu est repoussé de 24 dp vers la DROITE', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, textDirection: TextDirection.ltr);
      await _open(tester);

      // 24 dp d'indentation + l'épaisseur du filet.
      expect(delta(tester, 'sf0'), inInclusiveRange(24.0, 26.0));
    });

    testWidgets('🔴 RTL RÉEL (via Localizations) : l\'indentation BASCULE', (
      tester,
    ) async {
      // ⚠️ La feuille est rendue dans l'`Overlay` : un `Directionality` posé
      // sous `MaterialApp.home` ne l'atteint pas nativement. On passe donc par
      // le chemin de l'APPLICATION — `WidgetsApp` dérive la `Directionality` de
      // `WidgetsLocalizations.textDirection` AU-DESSUS du `Navigator`.
      await setScreen(tester, 500, 800);
      await tester.pumpWidget(
        MaterialApp(
          // ⚠️ Locale `en` DÉLIBÉRÉE : `DefaultMaterialLocalizations` ne
          // supporte qu'elle, et la direction ne vient PAS de la locale ici —
          // elle vient de `WidgetsLocalizations.textDirection`, que le délégué
          // ci-dessous force en RTL. C'est justement le chemin qu'emprunte
          // `WidgetsApp` pour poser la `Directionality` au-dessus du Navigator.
          locale: const Locale('en'),
          supportedLocales: const <Locale>[Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            _RtlWidgetsLocalizationsDelegate(),
            DefaultMaterialLocalizations.delegate,
          ],
          home: ZStudyFolderDetail(
            title: 'Dossier',
            materialTabLabel: kMatTab,
            notebookTabLabel: kNoteTab,
            progressionTabLabel: kProgTab,
            materialSectionsBuilder: defaultSections,
            notebookBuilder: (_) => const SizedBox.shrink(),
            nav: _spec(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(
          tester.element(find.byKey(ZSubfolderSelectorBar.triggerKey)),
        ),
        TextDirection.rtl,
        reason: 'le harnais RTL doit vraiment être en RTL',
      );

      await _open(tester);
      final Rect outer = tester.getRect(
        find.byKey(ZSubfolderSelectorBar.indentKey('sf0')),
      );
      final Rect inner = tester.getRect(
        find.byKey(ZSubfolderSelectorBar.itemKey('sf0')),
      );
      // 🔴 GARDE MORDANTE : `EdgeInsets.only(left:)` / `Border(left:)`
      // laisseraient l'indentation à GAUCHE en RTL — le décalage de gauche
      // resterait positif et celui de droite nul.
      expect(inner.left - outer.left, lessThan(1.0));
      expect(outer.right - inner.right, inInclusiveRange(24.0, 26.0));
    });

    testWidgets('le filet vertical est DÉRIVÉ du thème (aucun hex)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await _open(tester);

      final Container c = tester.widget<Container>(
        find.byKey(ZSubfolderSelectorBar.indentKey('sf0')),
      );
      final BoxDecoration d = c.decoration! as BoxDecoration;
      final BorderDirectional b = d.border! as BorderDirectional;
      expect(
        b.start.color,
        Theme.of(
          tester.element(find.byKey(ZSubfolderSelectorBar.sheetKey)),
        ).dividerColor,
      );
      // Directionnel par TYPE, en plus de la mesure géométrique ci-dessus.
      expect(d.border, isA<BorderDirectional>());
    });
  });

  // -------------------------------------------------------------------------
  // 5. STRUCTURE — points 8 et 9 : slot d'action, pied d'ajout
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — point 8 : slot d\'action par item', () {
    testWidgets('rendu, cliquable, et l\'hôte peut l\'omettre par item', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      var hits = 0;
      await pumpDetail(
        tester,
        nav: _spec(
          itemActionBuilder: (context, ref, selected) => ref == null
              // La maquette n'en pose pas sur la racine : rendre `null` doit
              // retirer le slot de l'ARBRE, pas le masquer.
              ? null
              : IconButton(
                  onPressed: () => hits++,
                  icon: const Icon(Icons.more_horiz),
                  tooltip: _kActionLabel,
                ),
        ),
      );
      await _open(tester);

      expect(find.byKey(ZSubfolderSelectorBar.itemActionKey('')), findsNothing);
      expect(
        find.byKey(ZSubfolderSelectorBar.itemActionKey('sf0')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip(_kActionLabel).first);
      await tester.pumpAndSettle();
      // 🔴 GARDE MORDANTE : poser l'action DANS la zone tapable de l'item ferait
      // remonter la sélection au lieu de l'action — la feuille se refermerait.
      expect(hits, 1);
      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
    });

    testWidgets('l\'action reste ANNONCÉE au lecteur d\'écran', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          itemActionBuilder: (context, ref, selected) => ref == null
              ? null
              : IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.more_horiz,
                    semanticLabel: _kActionLabel,
                  ),
                ),
        ),
      );
      await _open(tester);

      // 🔴 `excludeSemantics: true` sur l'item — le réflexe hérité de la barre,
      // légitime tant qu'il n'y avait rien d'autre à annoncer — rendrait
      // l'action MUETTE et injoignable. Cette garde le mesure.
      expect(find.bySemanticsLabel(_kActionLabel), findsWidgets);
      // CONTRÔLE NÉGATIF : ouvrir les sémantiques de l'item ne doit pas lui
      // faire PERDRE la sienne — il reste annoncé, et sélectionnable.
      final SemanticsHandle handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(ZSubfolderSelectorBar.itemKey('sf0'))),
        isSemantics(label: 'Sous-dossier 0'),
      );
      handle.dispose();
    });
  });

  group('CR-IFFD-41 — point 9 : pied d\'ajout CÂBLÉ (aucun slot redéclaré)', () {
    testWidgets('les slots PRÉEXISTANTS suffisent, et le libellé est AFFICHÉ', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      var hits = 0;
      await pumpDetail(tester, nav: _spec(addAction: () => hits++));
      await _open(tester);

      final Finder footer = find.byKey(ZSubfolderSelectorBar.footerAddKey);
      expect(footer, findsOneWidget);
      // Deux chemins DISTINCTS pour le libellé : AFFICHÉ et ANNONCÉ. Vider l'un
      // ne fait pas rougir la garde de l'autre.
      expect(
        find.descendant(of: footer, matching: find.text(kAddLabel)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(kAddLabel), findsWidgets);
      // Le glyphe INJECTÉ est honoré (jamais le repli quand l'hôte en fournit).
      expect(
        find.descendant(
          of: footer,
          matching: find.byIcon(Icons.create_new_folder),
        ),
        findsOneWidget,
      );

      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(hits, 1);
      // L'hôte ouvre ensuite SA surface d'édition : la feuille ne doit pas
      // rester empilée derrière.
      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
    });

    testWidgets('la spec n\'a AUCUN champ d\'ajout propre à la feuille', (
      tester,
    ) async {
      // Garde de CONCEPTION : le point 9 devait être CÂBLÉ, pas redéclaré. Un
      // `sheetAddLabel` ajouté à la spec ferait diverger deux sources pour le
      // même libellé — le défaut « seconde source » que ce dépôt combat.
      const ZSubfolderNavSpec spec = ZSubfolderNavSpec(
        subfolders: <ZSubfolderRef>[],
        allSubfoldersLabel: 'x',
        addLabel: 'L',
        addIcon: Icons.add,
      );
      expect(spec.addLabel, 'L');
      expect(spec.addIcon, Icons.add);
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: _spec());
      await _open(tester);
      expect(find.byKey(ZSubfolderSelectorBar.footerAddKey), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 6. AD-13 — planchers BORNÉS PAR LE HAUT
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — AD-13 : ≥ 48 dp, borné par le haut', () {
    testWidgets('items, action et pied de la feuille', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          sheetTitle: _kSheetTitle,
          addAction: () {},
          itemActionBuilder: (context, ref, selected) => ref == null
              ? null
              : const Icon(Icons.more_horiz),
        ),
      );
      await _open(tester);

      final List<Finder> targets = <Finder>[
        find.byKey(ZSubfolderSelectorBar.itemKey('')),
        find.byKey(ZSubfolderSelectorBar.itemKey('sf0')),
        find.byKey(ZSubfolderSelectorBar.itemActionKey('sf0')),
        find.byKey(ZSubfolderSelectorBar.footerAddKey),
      ];
      for (final Finder f in targets) {
        final Size s = _size(tester, f);
        expect(s.height, greaterThanOrEqualTo(48.0));
        // 🔴 Borne HAUTE : sans elle, la garde resterait verte si la cible
        // héritait simplement d'une hauteur imposée par son parent — l'angle
        // mort recensé sur les gardes « ≥ 48 dp » de ce dépôt.
        expect(s.height, lessThanOrEqualTo(96.0));
      }
      // CONTRÔLE NÉGATIF : un descendant volontairement petit de la MÊME
      // surface DOIT échouer au plancher. Il prouve que la mesure lit bien la
      // taille RENDUE et non une contrainte déclarée.
      expect(
        _size(tester, find.byIcon(Icons.more_horiz).first).height,
        lessThan(48.0),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 7. NON-RÉGRESSION — `compact` ignore TOUT de CR-IFFD-41
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — `compact` rend exactement comme avant', () {
    testWidgets('ni feuille, ni titre, ni action, ni habillage, ni inversion', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(
          narrowMode: ZSubfolderNarrowMode.compact,
          sheetTitle: _kSheetTitle,
          addAction: () {},
          itemActionBuilder: (context, ref, selected) =>
              const Icon(Icons.more_horiz),
        ),
        // Préréglage COMPLET posé : s'il fuyait dans `compact`, ce serait ici.
        wrap: _scoped(_kIffdPreset),
      );

      expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
      expect(find.byType(ZSubfolderSelectorBar), findsNothing);
      expect(find.byKey(ZSubfolderSelectorBar.triggerChromeKey), findsNothing);
      expect(find.text(_kSheetTitle), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byKey(ZSubfolderSelectorBar.footerAddKey), findsNothing);
      // La rangée historique : puces `ChoiceChip`, une seule sélectionnée.
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((ChoiceChip c) => c.selected)
            .length,
        1,
      );
      // Et l'API reste intacte.
      expect(ZSubfolderNarrowMode.values, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  // 8. SURVIE DU SCOPE SOUS L'OVERLAY
  // -------------------------------------------------------------------------
  group('CR-IFFD-41 — le `ZcrudScope` de l\'hôte SURVIT dans la feuille', () {
    testWidgets('le résolveur de `colorKey` s\'applique aux items de la feuille',
        (tester) async {
      // `ZcrudScope` est un `InheritedWidget` NU : `showModalBottomSheet` ne
      // capture que les `InheritedTheme`. Sans re-pose explicite, les pastilles
      // d'accent de la feuille perdraient le résolveur de l'hôte — le socle
      // rendrait un accent muet là où la maquette en attend un.
      await setScreen(tester, 500, 800);
      final Set<String> asked = <String>{};
      await pumpDetail(
        tester,
        wrap: (Widget child) => ZcrudScope(
          theme: _kIffdPreset,
          colorKeyResolver: (ColorScheme scheme, String key) {
            asked.add(key);
            return ZColorPair(color: scheme.error, onColor: scheme.onError);
          },
          child: child,
        ),
      );
      asked.clear();
      await _open(tester);

      expect(
        asked,
        containsAll(<String>['primary', 'secondary']),
        reason: 'les pastilles de la feuille doivent interroger le résolveur '
            'de l\'hôte, pas un repli du socle',
      );
      // Et le TOKEN de l'hôte, injecté par ce même scope, agit bien DANS la
      // feuille (chemin distinct de `ThemeData.extensions`).
      expect(find.byKey(ZSubfolderSelectorBar.triggerChromeKey), findsOneWidget);
    });

    test('🔴 STRUCTURE : chaque paramètre de `ZcrudScope` est propagé', () {
      // Garde de CONSTRUCTION, pas de rendu : la re-pose recopie champ par
      // champ (aucun `copyWith` n'existe). Un champ AJOUTÉ à `ZcrudScope` et
      // oublié dans la re-pose serait perdu SILENCIEUSEMENT dans la feuille.
      // On lit donc la liste RÉELLE des paramètres dans la source de
      // `zcrud_core` — jamais une liste recopiée ici, qui dériverait avec elle.
      final Directory root = _repoRoot();
      final File scope = File(
        '${root.path}/packages/zcrud_core/lib/src/presentation/zcrud_scope.dart',
      );
      expect(scope.existsSync(), isTrue, reason: 'source introuvable');
      final String src = scope.readAsStringSync();
      final int start = src.indexOf('const ZcrudScope({');
      expect(start, greaterThan(-1));
      final int end = src.indexOf('});', start);
      final List<String> params = RegExp(r'this\.(\w+)')
          .allMatches(src.substring(start, end))
          .map((Match m) => m.group(1)!)
          .toList();
      // Le compteur DOIT pouvoir varier : un ensemble à un seul élément serait
      // vert sur tout défaut.
      expect(params.length, greaterThan(5));

      final String bar = File(
        '${root.path}/packages/zcrud_study/lib/src/presentation/'
        'z_subfolder_selector_bar.dart',
      ).readAsStringSync();
      final int from = bar.indexOf('Widget _rePoseScope(');
      expect(from, greaterThan(-1));
      final String body = bar.substring(from, bar.indexOf('\n  }', from));
      for (final String p in params) {
        expect(
          body.contains('$p: scope.$p'),
          isTrue,
          reason: '🔴 `$p` n\'est PAS re-posé dans la feuille : le seam de '
              'l\'hôte disparaîtrait sous l\'Overlay',
        );
      }
    });
  });
}

/// Remonte jusqu'au dossier portant `melos.yaml` — ancrage ROBUSTE, jamais un
/// `../` relatif (la convention `melos exec` fixe le cwd au package).
Directory _repoRoot() {
  Directory d = Directory.current;
  while (!File('${d.path}/melos.yaml').existsSync()) {
    final Directory parent = d.parent;
    if (parent.path == d.path) {
      fail('melos.yaml introuvable au-dessus de ${Directory.current.path}');
    }
    d = parent;
  }
  return d;
}

/// `WidgetsLocalizations` RTL — c'est `WidgetsApp` qui en dérive la
/// `Directionality`, AU-DESSUS du `Navigator` (donc de l'`Overlay`).
class _RtlWidgetsLocalizations implements WidgetsLocalizations {
  const _RtlWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;

  @override
  String get reorderItemDown => 'down';

  @override
  String get reorderItemLeft => 'left';

  @override
  String get reorderItemRight => 'right';

  @override
  String get reorderItemToEnd => 'end';

  @override
  String get reorderItemToStart => 'start';

  @override
  String get reorderItemUp => 'up';

  @override
  String get copyButtonLabel => 'copy';

  @override
  String get cutButtonLabel => 'cut';

  @override
  String get lookUpButtonLabel => 'lookUp';

  @override
  String get pasteButtonLabel => 'paste';

  @override
  String get searchWebButtonLabel => 'searchWeb';

  @override
  String get selectAllButtonLabel => 'selectAll';

  @override
  String get shareButtonLabel => 'share';

  @override
  String get noResultsFound => 'noResults';

  @override
  String get radioButtonUnselectedLabel => 'unselected';

  @override
  String get searchResultsFound => 'results';
}

class _RtlWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RtlWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) async =>
      const _RtlWidgetsLocalizations();

  @override
  bool shouldReload(_RtlWidgetsLocalizationsDelegate old) => false;
}
