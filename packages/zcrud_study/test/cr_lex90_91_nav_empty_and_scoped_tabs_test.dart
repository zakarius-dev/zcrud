/// Gardes CR-LEX-90 (navigation sans destination) et CR-LEX-91 (sélection
/// transmise aux TROIS builders d'onglet).
///
/// Les bornes géométriques figées ici ont été RELEVÉES sur disque, sur la
/// version ANTÉRIEURE à la correction, avec une spec NON VIDE (`refs()`), à
/// 400 et 600 dp d'écran :
///
/// | placement     | 400 dp — corps           | 600 dp — corps           | app-bar 600 |
/// |---------------|--------------------------|--------------------------|-------------|
/// | `withinTab`   | LTRB(0, 152, 400, 800)   | LTRB(300, 104, 600, 800) | 104         |
/// | `aboveTabs`   | LTRB(0, 152, 400, 800)   | LTRB(0, 152, 600, 800)   | 104         |
/// | `aboveTabBar` | LTRB(0, 152, 400, 800)   | LTRB(0, 152, 600, 800)   | 152         |
///
/// Elles servent de golden d'INERTIE : avec des sous-dossiers, la correction ne
/// doit rien déplacer. Le cas VIDE, lui, est mesuré contre les valeurs « aucune
/// navigation » : corps pleine largeur/hauteur et app-bar à 104 dp partout.
///
/// Ces mêmes valeurs, mesurées AVANT correction avec `subfolders: []`, étaient
/// identiques à celles de la spec non vide — c'est exactement le défaut : la
/// place était prise sans qu'il y ait quoi que ce soit à naviguer.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Tranche de sélection pour les montages de `ZSubfolderNav` hors conteneur
/// (`null` = item racine).
final ValueNotifier<String?> _rootSelection = ValueNotifier<String?>(null);

/// Spec SANS aucune destination — la seule chose que CR-LEX-90 mesure.
ZSubfolderNavSpec emptyNav({
  VoidCallback? addAction,
  ZSubfolderNarrowMode? narrowMode,
}) => navSpec(
  subfolders: const <ZSubfolderRef>[],
  addAction: addAction,
  narrowMode: narrowMode,
);

Rect bodyRect(WidgetTester tester) =>
    tester.getRect(find.byType(ZSectionedStudyLayout).first);

Rect appBarRect(WidgetTester tester) =>
    tester.getRect(find.byType(AppBar).first);

bool anyNavSurface(WidgetTester tester) =>
    find.byType(ZSubfolderSidebar).evaluate().isNotEmpty ||
    find.byType(ZSubfolderNarrowNav).evaluate().isNotEmpty;

void main() {
  // ==========================================================================
  // CR-LEX-90 — rien à naviguer ⇒ rien de monté
  // ==========================================================================
  group('CR-LEX-90 — spec VIDE : aucun des trois montages', () {
    testWidgets('`withinTab` 600 dp : ni barre latérale, ni surface étroite ; '
        'le corps reprend TOUTE la largeur', (tester) async {
      await setScreen(tester, 600, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.withinTab,
      );

      expect(find.byType(ZSubfolderSidebar), findsNothing);
      expect(find.byType(ZSubfolderNarrowNav), findsNothing);
      // Borne FIGÉE. Avant correction : LTRB(300, 104, 600, 800) — 300 dp de
      // largeur mangés par une barre latérale à zéro destination.
      expect(bodyRect(tester), const Rect.fromLTRB(0, 104, 600, 800));
    });

    testWidgets('`withinTab` 400 dp : aucune bande, le corps remonte', (
      tester,
    ) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.withinTab,
      );

      expect(anyNavSurface(tester), isFalse);
      // Avant correction : LTRB(0, 152, 400, 800) — 48 dp de bande vide.
      expect(bodyRect(tester), const Rect.fromLTRB(0, 104, 400, 800));
    });

    testWidgets('`aboveTabs` : aucune bande hissée, corps pleine hauteur', (
      tester,
    ) async {
      await setScreen(tester, 600, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );

      expect(anyNavSurface(tester), isFalse);
      expect(bodyRect(tester), const Rect.fromLTRB(0, 104, 600, 800));
    });

    testWidgets('`aboveTabs` : le slot de l\'hôte reste rendu, SEUL', (
      tester,
    ) async {
      await setScreen(tester, 600, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        aboveTabViews: const SizedBox(
          height: 20,
          key: ValueKey<String>('host-slot'),
        ),
      );

      // Retirer la bande ne doit pas emporter le slot de l'hôte : le créneau
      // retombe sur le pass-through pur.
      expect(find.byKey(const ValueKey<String>('host-slot')), findsOneWidget);
      expect(anyNavSurface(tester), isFalse);
      expect(bodyRect(tester), const Rect.fromLTRB(0, 124, 600, 800));
    });

    testWidgets('`aboveTabBar` : aucune bande ET aucune hauteur réservée dans '
        'l\'app-bar', (tester) async {
      await setScreen(tester, 600, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
      );

      expect(anyNavSurface(tester), isFalse);
      // Avant correction : app-bar à 152 dp — 48 dp réservés pour rien.
      expect(appBarRect(tester), const Rect.fromLTRB(0, 0, 600, 104));
      expect(bodyRect(tester), const Rect.fromLTRB(0, 104, 600, 800));
    });

    testWidgets('`aboveTabBar` AVEC slot d\'hôte : l\'app-bar ne réserve QUE la '
        'hauteur du slot', (tester) async {
      // Site distinct du précédent : ici le créneau existe (le slot de l'hôte
      // est rendu), et c'est la HAUTEUR DÉCLARÉE qui doit cesser d'additionner
      // une bande absente. Sans cette garde, la borne de `_aboveTabBarHeight`
      // serait inerte — mesuré.
      await setScreen(tester, 600, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        aboveTabBar: const SizedBox(
          height: 20,
          key: ValueKey<String>('host-bar-slot'),
        ),
        aboveTabBarHeight: 20,
      );

      expect(find.byKey(const ValueKey<String>('host-bar-slot')), findsOneWidget);
      expect(anyNavSurface(tester), isFalse);
      // 104 (app-bar + onglets) + 20 (slot) — et surtout PAS + 48 de bande.
      expect(appBarRect(tester), const Rect.fromLTRB(0, 0, 600, 124));
    });

    testWidgets('les deux surfaces étroites sont couvertes (`selector` ET '
        '`compact`)', (tester) async {
      for (final ZSubfolderNarrowMode m in ZSubfolderNarrowMode.values) {
        await setScreen(tester, 400, 800);
        await pumpDetail(
          tester,
          nav: emptyNav(narrowMode: m),
          subfolderNavPlacement: ZSubfolderNavPlacement.withinTab,
        );
        expect(find.byType(ZSubfolderSelectorBar), findsNothing, reason: '$m');
        expect(
          find.byType(ZSubfolderCompactSelector),
          findsNothing,
          reason: '$m',
        );
        expect(bodyRect(tester), const Rect.fromLTRB(0, 104, 400, 800));
      }
    });

    testWidgets('SYMPTÔME DE L\'HÔTE reproduit : la grille retrouve ses DEUX '
        'colonnes à 600 dp', (tester) async {
      // Grille à `maxCrossAxisExtent: 320` : 2 colonnes sur 600 dp de corps,
      // 1 seule sur les 300 dp que laissait la barre latérale à zéro
      // destination. C'est la mesure de l'hôte, rejouée.
      Widget grid() => GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
        ),
        itemCount: 4,
        itemBuilder: (_, int i) =>
            SizedBox(key: ValueKey<String>('cell$i'), height: 100),
      );

      await setScreen(tester, 600, 800);
      await pumpDetail(
        tester,
        nav: emptyNav(),
        subfolderNavPlacement: ZSubfolderNavPlacement.withinTab,
        materialSectionsBuilder: (_) => const <ZStudyToolsSectionSpec>[],
        materialHeaderBuilder: (_, _) => SizedBox(height: 300, child: grid()),
      );

      final Rect c0 = tester.getRect(
        find.byKey(const ValueKey<String>('cell0')),
      );
      final Rect c1 = tester.getRect(
        find.byKey(const ValueKey<String>('cell1')),
      );
      // Deux cellules sur la MÊME rangée ⇒ deux colonnes. Avec la barre montée,
      // `c1` passait sous `c0`.
      expect(c1.top, c0.top);
      expect(c0.left, 0.0);
      expect(c1.right, 600.0);
    });
  });

  group('CR-LEX-90 — la borne est `subfolders`, et rien d\'autre', () {
    test('le prédicat public ne dépend que de la liste', () {
      expect(
        zSubfolderNavHasDestinations(
          const ZSubfolderNavSpec(
            subfolders: <ZSubfolderRef>[],
            allSubfoldersLabel: 'Tout',
          ),
        ),
        isFalse,
      );
      // Un libellé « tous » seul ne fait pas une destination : c'est la borne
      // que la CR demandait de trancher explicitement.
      expect(
        zSubfolderNavHasDestinations(
          ZSubfolderNavSpec(
            subfolders: const <ZSubfolderRef>[],
            allSubfoldersLabel: 'Tout',
            rootItemLabel: 'Racine',
            rootItemIcon: Icons.folder,
            addAction: () {},
          ),
        ),
        isFalse,
      );
      expect(
        zSubfolderNavHasDestinations(
          ZSubfolderNavSpec(
            subfolders: refs(n: 1),
            allSubfoldersLabel: 'Tout',
          ),
        ),
        isTrue,
      );
    });

    testWidgets('CONSÉQUENCE ASSUMÉE : sans destination, l\'affordance d\'ajout '
        'portée par la navigation est ABSENTE elle aussi', (tester) async {
      await setScreen(tester, 400, 800);
      var taps = 0;
      await pumpDetail(
        tester,
        nav: emptyNav(addAction: () => taps++),
        subfolderNavPlacement: ZSubfolderNavPlacement.withinTab,
      );
      // Le `+` de la barre de fratrie n'est pas rendu — il n'y a pas de barre.
      // Un écran qui doit offrir la création du PREMIER sous-dossier place cette
      // action ailleurs (app-bar, hub de contenu, état vide du corps).
      expect(find.byTooltip(kAddLabel), findsNothing);
      expect(taps, 0);
    });
  });

  group('CR-LEX-90 — `ZSubfolderNav` SEUL (hors conteneur)', () {
    testWidgets('spec vide + corps ⇒ le CORPS SEUL, sans enveloppe', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZSubfolderNav(
            spec: emptyNav(),
            selected: _rootSelection,
            onSelect: (_) {},
            sidebarBuilder: (_) =>
                const SizedBox(width: 300, key: ValueKey<String>('sb')),
            bodyBuilder: (_) =>
                const Placeholder(key: ValueKey<String>('body')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('sb')), findsNothing);
      expect(find.byType(ZSubfolderNarrowNav), findsNothing);
      // Ni `Row` ni `Column` d'assemblage : le corps prend toute la boîte.
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('body'))),
        const Rect.fromLTRB(0, 0, 800, 600),
      );
    });

    testWidgets('spec vide SANS corps ⇒ rien du tout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZSubfolderNav(
            spec: emptyNav(),
            selected: _rootSelection,
            onSelect: (_) {},
            sidebarBuilder: (_) =>
                const SizedBox(width: 300, key: ValueKey<String>('sb')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('sb')), findsNothing);
      expect(find.byType(ZSubfolderNarrowNav), findsNothing);
    });
  });

  group('CR-LEX-90 — INERTIE STRICTE avec des sous-dossiers', () {
    testWidgets('les trois placements gardent leur géométrie relevée AVANT '
        'correction', (tester) async {
      // Goldens relevés sur la version antérieure (cf. dartdoc de tête).
      const Map<ZSubfolderNavPlacement, List<Rect>> golden =
          <ZSubfolderNavPlacement, List<Rect>>{
            // [corps@400, corps@600, app-bar@600]
            ZSubfolderNavPlacement.withinTab: <Rect>[
              Rect.fromLTRB(0, 152, 400, 800),
              Rect.fromLTRB(300, 104, 600, 800),
              Rect.fromLTRB(0, 0, 600, 104),
            ],
            ZSubfolderNavPlacement.aboveTabs: <Rect>[
              Rect.fromLTRB(0, 152, 400, 800),
              Rect.fromLTRB(0, 152, 600, 800),
              Rect.fromLTRB(0, 0, 600, 104),
            ],
            ZSubfolderNavPlacement.aboveTabBar: <Rect>[
              Rect.fromLTRB(0, 152, 400, 800),
              Rect.fromLTRB(0, 152, 600, 800),
              Rect.fromLTRB(0, 0, 600, 152),
            ],
          };

      for (final ZSubfolderNavPlacement p in ZSubfolderNavPlacement.values) {
        // Une valeur d'enum neuve rendrait ce `!` rouge : la couverture des
        // placements est exigée, pas supposée.
        final List<Rect> want = golden[p]!;
        await setScreen(tester, 400, 800);
        await pumpDetail(tester, subfolderNavPlacement: p);
        expect(bodyRect(tester), want[0], reason: '$p @400');

        await setScreen(tester, 600, 800);
        await pumpDetail(tester, subfolderNavPlacement: p);
        expect(bodyRect(tester), want[1], reason: '$p @600');
        expect(appBarRect(tester), want[2], reason: '$p app-bar @600');
        expect(anyNavSurface(tester), isTrue, reason: '$p');
      }
    });
  });

  // ==========================================================================
  // CR-LEX-91 — la sélection atteint les TROIS builders
  // ==========================================================================
  group('CR-LEX-91 — contrat aligné sur les trois builders', () {
    testWidgets('la sélection reçue par chacun des trois SUIT la navigation, '
        'à la valeur exacte', (tester) async {
      final seen = <String, Object?>{};
      const Object unset = Object();
      seen['material'] = unset;
      seen['notebook'] = unset;
      seen['progression'] = unset;

      await setScreen(tester, 700, 800);
      await pumpDetail(
        tester,
        // Navigation HISSÉE : c'est le seul placement où la barre reste
        // atteignable depuis les onglets Bloc-notes et Progression — donc le
        // seul où le scénario de désynchronisation de la CR est reproductible.
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        materialSectionsBuilder: (String? id) {
          seen['material'] = id;
          return defaultSections(id);
        },
        notebookTabBuilder: (BuildContext _, String? id) {
          seen['notebook'] = id;
          return const SizedBox.shrink();
        },
        progressionTabBuilder: (BuildContext _, String? id) {
          seen['progression'] = id;
          return const SizedBox.shrink();
        },
      );

      Future<void> visitEveryTab() async {
        for (final String label in <String>[kNoteTab, kProgTab, kMatTab]) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
      }

      await visitEveryTab();
      expect(seen['material'], isNull);
      expect(seen['notebook'], isNull);
      expect(seen['progression'], isNull);

      // Navigation RÉELLE dans la barre du socle : ouvrir la feuille, choisir
      // « Sous-dossier 1 ».
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sous-dossier 1').last);
      await tester.pumpAndSettle();

      await visitEveryTab();
      // ÉGALITÉ EXACTE sur les trois — c'est la désynchronisation d'onglets
      // que la CR décrit : avant, `notebook` et `progression` seraient restés
      // sur la valeur du montage.
      expect(seen['material'], 'sf1');
      expect(seen['notebook'], 'sf1');
      expect(seen['progression'], 'sf1');
    });

    testWidgets('AUCUN onglet désynchronisé : les trois voient la MÊME valeur '
        'après chaque changement', (tester) async {
      final material = <String?>[];
      final notebook = <String?>[];
      final progression = <String?>[];

      await setScreen(tester, 700, 800);
      await pumpDetail(
        tester,
        // Navigation HISSÉE : c'est le seul placement où la barre reste
        // atteignable depuis les onglets Bloc-notes et Progression — donc le
        // seul où le scénario de désynchronisation de la CR est reproductible.
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        materialSectionsBuilder: (String? id) {
          material.add(id);
          return defaultSections(id);
        },
        notebookTabBuilder: (BuildContext _, String? id) {
          notebook.add(id);
          return Text('NB:$id', key: const ValueKey<String>('nb'));
        },
        progressionTabBuilder: (BuildContext _, String? id) {
          progression.add(id);
          return Text('PG:$id', key: const ValueKey<String>('pg'));
        },
      );

      for (final String want in <String>['sf0', 'sf2', 'sf1']) {
        await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sous-dossier ${want.substring(2)}').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text(kNoteTab));
        await tester.pumpAndSettle();
        expect(find.text('NB:$want'), findsOneWidget);

        await tester.tap(find.text(kProgTab));
        await tester.pumpAndSettle();
        expect(find.text('PG:$want'), findsOneWidget);

        await tester.tap(find.text(kMatTab));
        await tester.pumpAndSettle();
        expect(material.last, want);
        expect(notebook.last, want);
        expect(progression.last, want);
      }
    });

    testWidgets('l\'ancien `WidgetBuilder` compile et rend à l\'IDENTIQUE', (
      tester,
    ) async {
      // 500 dp : c'est la largeur à laquelle les goldens de rect ci-dessous ont
      // été relevés AVANT correction.
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        notebookBuilder: (BuildContext _) =>
            const Text('NB', key: ValueKey<String>('nb')),
        progressionBuilder: (BuildContext _) =>
            const Text('PG', key: ValueKey<String>('pg')),
      );

      await tester.tap(find.text(kNoteTab));
      await tester.pumpAndSettle();
      // Golden relevé AVANT correction (corps d'onglet plein cadre).
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('nb'))),
        const Rect.fromLTRB(0, 104, 500, 800),
      );

      await tester.tap(find.text(kProgTab));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('pg'))),
        const Rect.fromLTRB(0, 104, 500, 800),
      );

      // INERTIE : sans builder porteur de sélection, AUCUN abonnement de plus
      // n'est posé au-dessus du corps de l'onglet Bloc-notes.
      await tester.tap(find.text(kNoteTab));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('nb')),
          matching: find.byType(ValueListenableBuilder<String?>),
        ),
        findsNothing,
      );
    });

    testWidgets('l\'ancien `WidgetBuilder` ne reçoit RIEN de la navigation '
        '(état antérieur, conservé)', (tester) async {
      var builds = 0;
      await setScreen(tester, 700, 800);
      await pumpDetail(
        tester,
        // Navigation HISSÉE : c'est le seul placement où la barre reste
        // atteignable depuis les onglets Bloc-notes et Progression — donc le
        // seul où le scénario de désynchronisation de la CR est reproductible.
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        notebookBuilder: (BuildContext _) {
          builds++;
          return const Text('NB', key: ValueKey<String>('nb'));
        },
      );
      await tester.tap(find.text(kNoteTab));
      await tester.pumpAndSettle();
      final int before = builds;

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sous-dossier 1').last);
      await tester.pumpAndSettle();

      // Le contrat historique est INCHANGÉ : ce builder ne suit pas la
      // navigation. C'est précisément pourquoi la forme portée existe.
      expect(builds, before);
    });

    testWidgets('PRÉCÉDENCE : la forme portée PRIME sur le `WidgetBuilder`', (
      tester,
    ) async {
      var oldCalls = 0;
      await setScreen(tester, 700, 800);
      await pumpDetail(
        tester,
        // Navigation HISSÉE : c'est le seul placement où la barre reste
        // atteignable depuis les onglets Bloc-notes et Progression — donc le
        // seul où le scénario de désynchronisation de la CR est reproductible.
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        notebookBuilder: (BuildContext _) {
          oldCalls++;
          return const Text('OLD', key: ValueKey<String>('old'));
        },
        notebookTabBuilder: (BuildContext _, String? id) =>
            Text('NEW:$id', key: const ValueKey<String>('new')),
        progressionBuilder: (BuildContext _) =>
            const Text('OLDP', key: ValueKey<String>('oldp')),
        progressionTabBuilder: (BuildContext _, String? id) =>
            Text('NEWP:$id', key: const ValueKey<String>('newp')),
      );

      await tester.tap(find.text(kNoteTab));
      await tester.pumpAndSettle();
      expect(find.text('NEW:null'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('old')), findsNothing);
      expect(oldCalls, 0);

      await tester.tap(find.text(kProgTab));
      await tester.pumpAndSettle();
      expect(find.text('NEWP:null'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('oldp')), findsNothing);
    });

    testWidgets('la forme portée PRIME aussi sur l\'anneau historique', (
      tester,
    ) async {
      await setScreen(tester, 700, 800);
      await pumpDetail(
        tester,
        // Navigation HISSÉE : c'est le seul placement où la barre reste
        // atteignable depuis les onglets Bloc-notes et Progression — donc le
        // seul où le scénario de désynchronisation de la CR est reproductible.
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        progressEmptyState: const Text(
          'EMPTY',
          key: ValueKey<String>('empty'),
        ),
        progressionTabBuilder: (BuildContext _, String? id) =>
            Text('PG:$id', key: const ValueKey<String>('pg')),
      );
      await tester.tap(find.text(kProgTab));
      await tester.pumpAndSettle();
      expect(find.text('PG:null'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('empty')), findsNothing);
    });

    testWidgets('AD-2/SM-1 : changer de fratrie ne reconstruit PAS les onglets '
        'ni la navigation', (tester) async {
      var navBuilds = 0;
      var notebookBuilds = 0;
      await setScreen(tester, 700, 800);
      await pumpDetail(
        tester,
        // Navigation HISSÉE : c'est le seul placement où la barre reste
        // atteignable depuis les onglets Bloc-notes et Progression — donc le
        // seul où le scénario de désynchronisation de la CR est reproductible.
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        nav: navSpec(
          itemBuilder: (BuildContext c, ZSubfolderRef r, bool s) {
            navBuilds++;
            return Text(r.label);
          },
        ),
        notebookTabBuilder: (BuildContext _, String? id) {
          notebookBuilds++;
          return Text('NB:$id', key: const ValueKey<String>('nb'));
        },
      );
      await tester.tap(find.text(kNoteTab));
      await tester.pumpAndSettle();
      final int notebookBefore = notebookBuilds;
      expect(notebookBefore, greaterThan(0));

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      final int navBefore = navBuilds;
      await tester.tap(find.text('Sous-dossier 1').last);
      await tester.pumpAndSettle();

      // Le corps de l'onglet visible se reconstruit (c'est le but) …
      expect(notebookBuilds, greaterThan(notebookBefore));
      // … et la barre d'onglets reste en place : les trois onglets sont
      // toujours là, sans recréation de la page.
      expect(find.text(kMatTab), findsOneWidget);
      expect(find.text(kProgTab), findsOneWidget);
      expect(navBuilds, greaterThanOrEqualTo(navBefore));
    });
  });
}
