/// **CR-IFFD-40** — la navigation de fratrie ne perd plus le « où suis-je ».
///
/// Défaut mesuré sur appareil : sous le seuil de bascule, la fratrie était rendue
/// par une rangée de puces défilant horizontalement. Après **un seul balayage**,
/// la pastille sélectionnée sortait du champ visible — rien n'était inaccessible,
/// c'est **l'état courant** qui était perdu.
///
/// Arbitrage appliqué : ajout du mode [ZSubfolderNarrowMode.selector], **DÉFAUT**
/// sous le seuil ; [ZSubfolderNarrowMode.compact] reste une valeur valide au
/// rendu inchangé (changement de COMPORTEMENT par défaut, **sans rupture d'API**).
///
/// Ce fichier garde AUSSI le seam de **SURFACE** (`ZSubfolderNavRenderer`), qui
/// répond à la cause racine nommée par l'hôte : `itemBuilder` construit un
/// ÉLÉMENT, jamais le CONTENEUR.
///
/// ⚠️ **CR-IFFD-41 a changé la FORME du déploiement** — la fratrie s'ouvre
/// désormais en feuille modale, plus en ligne. Les gardes ci-dessous portent sur
/// des propriétés qui, elles, n'ont PAS changé (l'élément courant reste sous les
/// yeux, la fratrie ne se déploie qu'à la demande, le repli n'est jamais vide,
/// `compact` est intact). La forme elle-même est gardée par
/// `cr_iffd41_subfolder_sheet_test.dart`.
///
/// `panelKey` désigne toujours la liste de la fratrie ; elle vit maintenant dans
/// l'`Overlay` — `find.byKey` la trouve donc encore, mais elle n'est plus
/// descendante de la barre (c'est CR-IFFD-41 qui le mesure).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Beaucoup de sous-dossiers : c'est la condition du défaut d'origine (une
/// rangée plus large que l'écran).
List<ZSubfolderRef> _manyRefs() => <ZSubfolderRef>[
  for (int i = 0; i < 12; i++)
    ZSubfolderRef(id: 'sf$i', label: 'Sous-dossier $i', count: i),
];

/// Rectangle de la fenêtre logique.
Rect _screen(WidgetTester tester) =>
    Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

/// `true` si [finder] est ENTIÈREMENT dans le champ visible.
bool _fullyVisible(WidgetTester tester, Finder finder) {
  final Rect r = tester.getRect(finder);
  final Rect s = _screen(tester);
  return r.left >= s.left - 0.01 &&
      r.right <= s.right + 0.01 &&
      r.top >= s.top - 0.01 &&
      r.bottom <= s.bottom + 0.01;
}

/// Hauteur RENDUE d'un widget (mesure sur le `RenderBox`, jamais une lecture de
/// la contrainte déclarée : une contrainte peut être écrasée par le parent).
double _renderedHeight(WidgetTester tester, Finder finder) =>
    (tester.renderObject(finder) as RenderBox).size.height;

void main() {
  setUp(_HostRenderer.observedModes.clear);

  // ---------------------------------------------------------------------------
  // 1. LE DÉFAUT ET SA CORRECTION — l'élément courant reste sous les yeux
  // ---------------------------------------------------------------------------
  group('CR-IFFD-40 — l\'élément courant ne sort plus du champ visible', () {
    testWidgets(
      '🔴 CONTRE-PREUVE (le défaut) : en `compact`, l\'élément SÉLECTIONNÉ est '
      'HORS du champ visible',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          nav: navSpec(
            subfolders: _manyRefs(),
            narrowMode: ZSubfolderNarrowMode.compact,
          ),
          initialSelectedSubfolderId: 'sf11',
        );

        // C'est le défaut rapporté, MESURÉ : la puce active est peinte à droite
        // de l'écran. Si un jour cette attente devient `isTrue`, c'est que la
        // rangée de puces s'est mise à ramener la sélection — et la garde
        // suivante ne prouverait plus rien de neuf.
        expect(
          _fullyVisible(tester, find.text('Sous-dossier 11')),
          isFalse,
          reason: 'le défaut d\'origine doit rester reproductible en `compact`',
        );
      },
    );

    testWidgets(
      'DÉFAUT (`selector`) : l\'élément sélectionné est visible SANS défiler',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          nav: navSpec(subfolders: _manyRefs()),
          initialSelectedSubfolderId: 'sf11',
        );

        expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);
        expect(find.text('Sous-dossier 11'), findsOneWidget);
        expect(
          _fullyVisible(tester, find.text('Sous-dossier 11')),
          isTrue,
          reason: 'l\'élément courant doit être lisible sans aucun geste',
        );
      },
    );

    testWidgets('barre FERMÉE : AUCUN défileur — rien à balayer', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: navSpec(subfolders: _manyRefs()));

      // GARDE MORDANTE : rendre la fratrie DANS la barre (rangée défilante)
      // ferait réapparaître un `Scrollable` ici — c'est LE défaut corrigé.
      expect(
        find.descendant(
          of: find.byType(ZSubfolderSelectorBar),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // La fratrie n'est pas seulement invisible : elle est ABSENTE de l'arbre.
      expect(find.text('Sous-dossier 5'), findsNothing);
    });

    testWidgets('l\'élément courant SURVIT à une ouverture puis fermeture', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: navSpec(subfolders: _manyRefs()),
        initialSelectedSubfolderId: 'sf11',
      );

      Future<void> toggle() async {
        await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
        await tester.pumpAndSettle();
      }

      await toggle(); // ouverture
      expect(find.byKey(ZSubfolderSelectorBar.panelKey), findsOneWidget);
      expect(
        _fullyVisible(tester, find.byKey(ZSubfolderSelectorBar.triggerKey)),
        isTrue,
        reason: 'la barre reste en place quand la fratrie se déploie',
      );

      // Fermeture par le MÊME geste que l'ouverture : depuis CR-IFFD-41 le
      // second tap traverse le barrier modal, ce qui referme la feuille.
      await toggle(); // fermeture
      expect(find.byKey(ZSubfolderSelectorBar.panelKey), findsNothing);
      expect(find.text('Sous-dossier 11'), findsOneWidget);
      expect(
        _fullyVisible(tester, find.text('Sous-dossier 11')),
        isTrue,
      );
    });

    testWidgets('la fratrie ne se déploie QU\'À LA DEMANDE, et se referme '
        'après un choix', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      expect(find.byKey(ZSubfolderSelectorBar.panelKey), findsNothing);
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ZSubfolderSelectorBar.panelKey), findsOneWidget);

      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
      await tester.pumpAndSettle();

      // Choisir REFERME : la barre revient à sa ligne unique, montrant le
      // nouvel élément courant. Et la sélection a bien filtré le corps.
      expect(find.byKey(ZSubfolderSelectorBar.panelKey), findsNothing);
      expect(find.text('Sous-dossier 1'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
    });

    testWidgets('l\'affordance d\'ouverture est un CHEVRON visible, qui '
        'change d\'état', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      final Finder chevron = find.byKey(ZSubfolderSelectorBar.chevronKey);
      expect(chevron, findsOneWidget);
      expect(_fullyVisible(tester, chevron), isTrue);
      final IconData closed = tester.widget<Icon>(chevron).icon!;

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : un chevron figé ne dirait pas si la fratrie est
      // déployée — l'affordance serait décorative.
      expect(tester.widget<Icon>(chevron).icon, isNot(closed));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. REPLI « tous » — jamais un vide
  // ---------------------------------------------------------------------------
  group('CR-IFFD-40 — repli explicite, jamais un vide', () {
    testWidgets('aucune sélection ⇒ `allSubfoldersLabel` (libellé INJECTÉ)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      expect(find.text(kAllLabel), findsOneWidget);
    });

    testWidgets('AD-10 : un id sélectionné INCONNU retombe sur le repli', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, initialSelectedSubfolderId: 'ghost-id');

      // GARDE MORDANTE : lire `subfolders.firstWhere(...)` sans repli lèverait,
      // et un `label` calculé sans repli rendrait une ligne VIDE.
      expect(tester.takeException(), isNull);
      expect(find.text(kAllLabel), findsOneWidget);
    });

    testWidgets('la ligne n\'est JAMAIS vide : elle porte toujours du texte', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: navSpec(subfolders: const <ZSubfolderRef>[]));

      // Zéro sous-dossier : cas le plus proche du vide, et pourtant le repli
      // s'affiche.
      final Iterable<Text> texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(ZSubfolderSelectorBar.triggerKey),
          matching: find.byType(Text),
        ),
      );
      expect(texts, isNotEmpty);
      expect(
        texts.any((Text t) => (t.data ?? '').trim().isNotEmpty),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. NON-RÉGRESSION du mode `compact` demandé EXPLICITEMENT
  // ---------------------------------------------------------------------------
  group('CR-IFFD-40 — `compact` explicite rend EXACTEMENT comme avant', () {
    testWidgets('même conteneur, mêmes puces, mêmes informations', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: navSpec(
          addAction: () {},
          narrowMode: ZSubfolderNarrowMode.compact,
        ),
      );

      // Conteneur historique : `SingleChildScrollView` HORIZONTAL clé
      // `compactKey`.
      final Finder scroller = find.byKey(
        ZSubfolderCompactSelector.compactKey,
      );
      expect(scroller, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scroller).scrollDirection,
        Axis.horizontal,
      );
      // Racine + 3 sous-dossiers, en puces `ChoiceChip`, racine sélectionnée.
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((ChoiceChip c) => c.selected)
            .length,
        1,
      );
      // Mêmes informations qu'avant : libellés, compteurs, bouton « Ajouter »
      // à sa clé historique.
      expect(find.text(kAllLabel), findsOneWidget);
      for (int i = 0; i < 3; i++) {
        expect(find.text('Sous-dossier $i'), findsOneWidget);
        expect(find.text('$i'), findsWidgets);
      }
      expect(
        find.byKey(const ValueKey<String>('suf3:compact:add')),
        findsOneWidget,
      );
      // Et AUCUNE trace de la nouvelle surface.
      expect(find.byType(ZSubfolderSelectorBar), findsNothing);
    });

    testWidgets('la valeur d\'enum `compact` reste VALIDE (aucune rupture)', (
      tester,
    ) async {
      // Garde de COMPILATION autant que de rendu : un hôte qui nomme la valeur
      // continue de compiler, et son `switch` à DEUX bras sur
      // `ZSubfolderLayoutMode` (patron documenté) n'est pas cassé — c'est
      // pourquoi `ZSubfolderNarrowMode` est un type SÉPARÉ.
      expect(ZSubfolderNarrowMode.values, hasLength(2));
      expect(ZSubfolderLayoutMode.values, hasLength(2));
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: navSpec(narrowMode: ZSubfolderNarrowMode.compact),
      );
      expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
    });

    testWidgets('le DÉFAUT du socle est `selector` (mesuré sur la spec)', (
      tester,
    ) async {
      const ZSubfolderNavSpec spec = ZSubfolderNavSpec(
        subfolders: <ZSubfolderRef>[],
        allSubfoldersLabel: 'x',
      );
      // GARDE MORDANTE : remettre `compact` en défaut rougit ICI, avant même
      // qu'un rendu soit pompé.
      expect(spec.narrowMode, ZSubfolderNarrowMode.selector);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. A11Y — 48 dp BORNÉ PAR LE HAUT, RTL RÉEL, annonce de l'élément courant
  // ---------------------------------------------------------------------------
  group('CR-IFFD-40 — AD-13', () {
    testWidgets('cible de la barre ≥ 48 dp, et BORNÉE PAR LE HAUT', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      final double h = _renderedHeight(
        tester,
        find.byKey(ZSubfolderSelectorBar.triggerKey),
      );
      // Borne BASSE : notre plancher.
      expect(h, greaterThanOrEqualTo(48.0));
      // Borne HAUTE : sans elle, la garde resterait verte si la barre héritait
      // simplement de la hauteur d'un parent (c'est exactement l'angle mort
      // relevé sur les gardes « ≥ 48 dp » de ce dépôt).
      expect(h, lessThanOrEqualTo(96.0));

      // CONTRÔLE NÉGATIF : la MÊME mesure, appliquée à un descendant
      // volontairement petit de la MÊME surface (le glyphe du chevron, 24 dp),
      // DOIT échouer au plancher. Sans lui, rien ne prouverait que la mesure
      // lit la taille RENDUE plutôt qu'une hauteur imposée par le parent — c'est
      // l'angle mort constaté sur les gardes « ≥ 48 dp » de ce dépôt.
      final double glyph = _renderedHeight(
        tester,
        find.byKey(ZSubfolderSelectorBar.chevronKey),
      );
      expect(glyph, lessThan(48.0));
    });

    testWidgets('chaque item du panneau déployé fait ≥ 48 dp', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();

      final Finder items = find.byWidgetPredicate(
        (Widget w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'suf3:selector:item:',
            ),
      );
      // D'ABORD prouver qu'il y en a : une boucle sur zéro item serait verte.
      expect(items, findsWidgets);
      for (final Element e in items.evaluate()) {
        expect(
          (e.renderObject! as RenderBox).size.height,
          greaterThanOrEqualTo(48.0),
        );
      }
    });

    testWidgets('RTL RÉEL : le chevron passe de l\'autre côté du libellé', (
      tester,
    ) async {
      // Mesure faite sur la BARRE, qui est en ligne : la `Directionality` posée
      // par le harnais s'y applique directement. Le RTL de la FEUILLE (surface
      // flottante, donc hors de ce `Directionality`) est mesuré séparément dans
      // `cr_iffd41_subfolder_sheet_test.dart`, via un
      // `LocalizationsDelegate<WidgetsLocalizations>`.
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, textDirection: TextDirection.ltr);
      final double ltrChevron = tester
          .getCenter(find.byKey(ZSubfolderSelectorBar.chevronKey))
          .dx;
      final double ltrLabel = tester.getCenter(find.text(kAllLabel)).dx;
      expect(ltrChevron, greaterThan(ltrLabel));

      await pumpDetail(tester, textDirection: TextDirection.rtl);
      final double rtlChevron = tester
          .getCenter(find.byKey(ZSubfolderSelectorBar.chevronKey))
          .dx;
      final double rtlLabel = tester.getCenter(find.text(kAllLabel)).dx;
      // GARDE MORDANTE : un `EdgeInsets.only(left:)` ou un `Row` non
      // directionnel laisserait le chevron du même côté dans les deux sens.
      expect(rtlChevron, lessThan(rtlLabel));
    });

    testWidgets('Semantics : la barre ANNONCE l\'élément courant, une seule '
        'fois, et suit la sélection', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);

      expect(find.bySemanticsLabel(kAllLabel), findsOneWidget);

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf2')));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : annoncer un libellé figé (ou le seul repli) laisserait
      // « ALL_SUBFOLDERS » annoncé après un changement de sélection.
      expect(find.bySemanticsLabel('Sous-dossier 2'), findsOneWidget);
      expect(find.bySemanticsLabel(kAllLabel), findsNothing);
    });

    testWidgets('l\'item du panneau porte `selected` (a11y ET surbrillance)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, initialSelectedSubfolderId: 'sf1');
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();

      final SemanticsHandle handle = tester.ensureSemantics();

      expect(
        tester.getSemantics(find.byKey(ZSubfolderSelectorBar.itemKey('sf1'))),
        isSemantics(isSelected: true, label: 'Sous-dossier 1'),
      );
      // GARDE MORDANTE : poser `selected: true` en dur (ou l'omettre) rendrait
      // ces deux attentes indiscernables.
      expect(
        tester.getSemantics(find.byKey(ZSubfolderSelectorBar.itemKey('sf0'))),
        isSemantics(isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('slot « Ajouter » : absent par défaut, présent si fourni', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      expect(find.byKey(ZSubfolderSelectorBar.addKey), findsNothing);

      var hits = 0;
      await pumpDetail(tester, nav: navSpec(addAction: () => hits++));
      final Finder add = find.byKey(ZSubfolderSelectorBar.addKey);
      expect(add, findsOneWidget);
      expect(
        (tester.renderObject(add) as RenderBox).size.height,
        greaterThanOrEqualTo(48.0),
      );
      await tester.tap(add);
      await tester.pump();
      expect(hits, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. PARITÉ DU SEAM D'ÉLÉMENT sur la nouvelle surface
  // ---------------------------------------------------------------------------
  group('CR-IFFD-40 — la surface par défaut honore `itemBuilder`', () {
    testWidgets('élément courant ET items du panneau viennent du builder', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      final modes = <ZSubfolderLayoutMode?>{};
      await pumpDetail(
        tester,
        nav: navSpec(
          itemBuilder: (context, ref, selected) {
            modes.add(ZSubfolderLayoutMode.maybeOf(context));
            return Text(
              'CUSTOM:${ref.id}',
              key: ValueKey<String>('custom:${ref.id}'),
            );
          },
        ),
      );

      // Élément courant (racine ⇒ sentinelle d'id vide, MÊME convention que
      // partout ailleurs).
      expect(find.byKey(const ValueKey<String>('custom:')), findsOneWidget);
      // Le chrome par défaut a bien été REMPLACÉ.
      expect(find.text(kAllLabel), findsNothing);

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      for (final String id in <String>['sf0', 'sf1', 'sf2']) {
        expect(find.byKey(ValueKey<String>('custom:$id')), findsOneWidget);
      }
      // Le scope de mode est posé AU-DESSUS des items : un builder existant
      // (patron `switch` de CR-IFFD-31) rend donc à l'identique.
      // `maybeOf` et non `of` : le repli de `of` masquerait un scope absent.
      expect(modes, <ZSubfolderLayoutMode?>{ZSubfolderLayoutMode.compact});
    });

    testWidgets('chrome par défaut : pastille d\'accent ET compteur rendus', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, initialSelectedSubfolderId: 'sf1');

      // `refs()` : sf1 porte `colorKey` et `count: 1` — les MÊMES informations
      // que la sidebar et que la rangée de puces (parité R-SUF2).
      expect(find.text('Sous-dossier 1'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(ZSubfolderSelectorBar.triggerKey),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AD-2/SM-1 : ouvrir la fratrie NE reconstruit PAS le corps', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      var builds = 0;
      await pumpDetail(
        tester,
        materialSectionsBuilder: (String? id) {
          builds++;
          return defaultSections(id);
        },
      );
      final int before = builds;

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : porter le dépli dans un `setState` de la page (ou
      // au-dessus du corps) ferait remonter ce compteur.
      expect(builds, before);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. SEAM DE SURFACE — `ZSubfolderNavRenderer`
  // ---------------------------------------------------------------------------
  group('CR-IFFD-40 — seam de SUBSTITUTION DE SURFACE', () {
    testWidgets('sans coquille injectée : rendu STRICTEMENT inchangé', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);

      // Scope PRÉSENT mais `renderer: null` : chemin distinct, MÊME rendu.
      await pumpDetail(
        tester,
        wrap: (Widget child) =>
            ZSubfolderNavRendererScope(renderer: null, child: child),
      );
      expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);

      // Coquille PRÉSENTE qui DÉCLINE (`null`) : encore le même rendu.
      await pumpDetail(
        tester,
        wrap: (Widget child) => ZSubfolderNavRendererScope(
          renderer: const _DecliningRenderer(),
          child: child,
        ),
      );
      expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);
    });

    testWidgets('coquille injectée : elle REMPLACE la surface du socle', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: (Widget child) => ZSubfolderNavRendererScope(
          renderer: const _HostRenderer(),
          child: child,
        ),
      );

      expect(find.byKey(_HostRenderer.surfaceKey), findsOneWidget);
      // GARDE MORDANTE : rendre la coquille À CÔTÉ de la surface du socle
      // (au lieu de la remplacer) laisserait les deux dans l'arbre.
      expect(find.byType(ZSubfolderSelectorBar), findsNothing);
      expect(find.byType(ZSubfolderCompactSelector), findsNothing);
    });

    testWidgets('la coquille ne peut PAS perdre le seam d\'ÉLÉMENT', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: navSpec(
          itemBuilder: (context, ref, selected) => Text(
            'CUSTOM:${ref.id}',
            key: ValueKey<String>('custom:${ref.id}'),
          ),
        ),
        wrap: (Widget child) => ZSubfolderNavRendererScope(
          renderer: const _HostRenderer(),
          child: child,
        ),
      );

      // La coquille RAPPELLE la fabrique du socle : l'`itemBuilder` de l'hôte
      // est honoré même sous une surface tierce, et le mode y est lisible.
      for (final String id in <String>['', 'sf0', 'sf1', 'sf2']) {
        expect(find.byKey(ValueKey<String>('custom:$id')), findsOneWidget);
      }
      expect(_HostRenderer.observedModes, <ZSubfolderLayoutMode?>{
        ZSubfolderLayoutMode.compact,
      });
    });

    testWidgets('la coquille pilote RÉELLEMENT la sélection (tranche + rappel)',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: (Widget child) => ZSubfolderNavRendererScope(
          renderer: const _HostRenderer(),
          child: child,
        ),
      );

      await tester.tap(find.byKey(_HostRenderer.pickKey('sf2')));
      await tester.pumpAndSettle();
      // La requête neutre suffit à piloter la page : le corps a filtré.
      expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);
    });

    testWidgets('AD-10 : une coquille qui LÈVE n\'emporte pas la navigation', (
      tester,
    ) async {
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: (Widget child) => ZSubfolderNavRendererScope(
          renderer: const _ThrowingRenderer(),
          child: child,
        ),
      );

      // La surface du socle est rendue : le défaut fonctionnel est ATTEINT.
      expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);
      // Et l'échec reste DÉBOGABLE (console + rapports de crash de l'hôte).
      expect(
        reported.any(
          (FlutterErrorDetails d) => d.exception.toString().contains('boom'),
        ),
        isTrue,
      );
    });
  });
}

/// Coquille qui DÉCLINE systématiquement (`null` = « garde la surface du socle »).
class _DecliningRenderer extends ZSubfolderNavRenderer {
  const _DecliningRenderer();

  @override
  Widget? buildNav(BuildContext context, ZSubfolderNavRenderRequest request) =>
      null;
}

/// Coquille qui LÈVE — cas AD-10.
class _ThrowingRenderer extends ZSubfolderNavRenderer {
  const _ThrowingRenderer();

  @override
  Widget? buildNav(BuildContext context, ZSubfolderNavRenderRequest request) =>
      throw StateError('boom');
}

/// Coquille d'hôte RÉALISTE : une colonne à elle, qui RAPPELLE la fabrique
/// d'item du socle et pilote la sélection par la requête neutre.
class _HostRenderer extends ZSubfolderNavRenderer {
  const _HostRenderer();

  static const Key surfaceKey = ValueKey<String>('host:surface');

  static Key pickKey(String id) => ValueKey<String>('host:pick:$id');

  /// Modes observés par la fabrique du socle rappelée depuis la coquille.
  static final Set<ZSubfolderLayoutMode?> observedModes =
      <ZSubfolderLayoutMode?>{};

  @override
  Widget buildNav(BuildContext context, ZSubfolderNavRenderRequest request) {
    return Column(
      key: surfaceKey,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ZSubfolderRef? ref in <ZSubfolderRef?>[
          null,
          ...request.spec.subfolders,
        ])
          GestureDetector(
            key: pickKey(ref?.id ?? ''),
            onTap: () => request.onSelect(ref?.id),
            child: Builder(
              builder: (BuildContext inner) {
                observedModes.add(ZSubfolderLayoutMode.maybeOf(inner));
                return request.itemContentBuilder(inner, ref, false);
              },
            ),
          ),
      ],
    );
  }
}
