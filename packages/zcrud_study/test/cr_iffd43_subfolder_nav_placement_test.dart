/// CR-IFFD-43 — la navigation de fratrie n'est plus prisonnière d'un onglet.
///
/// 🔴 **Le piège de ce lot, explicitement évité** : une garde qui vérifie « la
/// navigation est PRÉSENTE » est verte dans les DEUX placements — elle ne mesure
/// rien. Les gardes ci-dessous mesurent le **symptôme rapporté** :
/// * la navigation est rendue **UNE SEULE FOIS** ;
/// * elle est **géométriquement au-dessus** de la zone d'onglets (bord bas ≤
///   bord haut du `TabBarView`) — pas seulement « quelque part dans l'arbre » ;
/// * elle est **atteignable depuis le 2ᵉ ET le 3ᵉ onglet** (c'est là que l'hôte
///   la perdait), et **agir** dessus depuis un autre onglet **filtre** bien le
///   corps Matériel ;
/// * le placement est **indépendant du point de rupture** (mesuré aux deux
///   largeurs réelles, jamais via un flag).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/suf3_harness.dart';

/// Marqueur du slot `aboveTabViews` FOURNI PAR L'HÔTE (cas de conflit).
const Key kHostSlotKey = ValueKey<String>('host:above');

/// Rectangle global d'un finder unique.
Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

/// Bascule sur l'onglet d'indice [i] (0 = Matériel, 1 = Notebook, 2 = Progression).
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

void main() {
  // ---------------------------------------------------------------------------
  group('1. DÉFAUT `withinTab` — rendu STRICTEMENT inchangé', () {
    testWidgets('le défaut de production EST `withinTab`', (tester) async {
      // Lu sur le socle, jamais recopié : si le défaut basculait, la garde
      // rougirait au lieu de mesurer une constante de test.
      expect(kProductionDefaultNavPlacement, ZSubfolderNavPlacement.withinTab);
    });

    testWidgets(
      'défaut : le créneau `aboveTabViews` du shell reste NUL (aucun wrapper)',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(tester);
        final ZPageScaffold shell = tester.widget<ZPageScaffold>(
          find.byType(ZPageScaffold),
        );
        // GARDE MORDANTE : hisser la nav « au cas où » (ou emballer le créneau
        // dans un `SizedBox.shrink` inerte) rendrait ce champ non nul.
        expect(shell.aboveTabViews, isNull);
      },
    );

    testWidgets('défaut < 600 dp : la nav est DANS l\'onglet Matériel', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      // Elle est SOUS le `TabBarView` (donc dans l'onglet) — pas au-dessus.
      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      final Rect views = _rect(tester, find.byType(TabBarView));
      expect(nav.top, greaterThanOrEqualTo(views.top));
    });

    testWidgets('défaut ≥ 600 dp : la SIDEBAR est rendue (inchangé)', (
      tester,
    ) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);
      expect(find.byType(ZSubfolderSidebar), findsOneWidget);
      expect(find.byType(ZSubfolderNarrowNav), findsNothing);
    });

    testWidgets(
      'défaut : le SYMPTÔME HISTORIQUE est conservé (nav absente au 2ᵉ onglet)',
      (tester) async {
        // 🔴 Garde de NON-RÉGRESSION à l'envers : le défaut ne doit RIEN
        // corriger. Si `withinTab` se mettait à hisser la navigation, cette
        // garde rougirait — c'est elle qui protège les hôtes existants.
        await setScreen(tester, 500, 800);
        await pumpDetail(tester);
        await _openTab(tester, kNoteTab);
        expect(find.byType(ZSubfolderNarrowNav), findsNothing);
      },
    );

    testWidgets('défaut : `aboveTabViews` de l\'hôte est RELAYÉ tel quel', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        aboveTabViews: const SizedBox(key: kHostSlotKey, height: 20),
      );
      expect(find.byKey(kHostSlotKey), findsOneWidget);
      // Le chaînon (b) : le slot est bien AU-DESSUS des vues d'onglets.
      expect(
        _rect(tester, find.byKey(kHostSlotKey)).bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top),
      );
      // …et il n'a PAS entraîné la navigation avec lui.
      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      expect(nav.top, greaterThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top));
    });
  });

  // ---------------------------------------------------------------------------
  group('2. `aboveTabs` — UNE seule navigation, AU-DESSUS des onglets', () {
    testWidgets('rendue EXACTEMENT une fois, au-dessus du `TabBarView`', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );

      // (1) UNE SEULE fois — une nav laissée aussi dans l'onglet Matériel en
      // donnerait deux, avec deux sources de sélection.
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);

      // (2) AU-DESSUS : bord bas de la nav ≤ bord haut des vues d'onglets,
      // et bord haut ≥ bord bas de la `TabBar` (donc entre les deux).
      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      final Rect views = _rect(tester, find.byType(TabBarView));
      final Rect bar = _rect(tester, find.byType(TabBar));
      expect(nav.bottom, lessThanOrEqualTo(views.top));
      expect(nav.top, greaterThanOrEqualTo(bar.bottom));

      // (3) Bande PLEINE LARGEUR — mesurée contre la largeur des VUES
      // d'onglets (« elle borde la page comme le contenu »), pas contre une
      // constante : une bande centrée sur son contenu rougirait ici.
      expect(nav.width, views.width);
    });

    testWidgets('VISIBLE depuis le 2ᵉ ET le 3ᵉ onglet', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );

      await _openTab(tester, kNoteTab);
      expect(find.text('NOTE_BODY'), findsOneWidget);
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(
        _rect(tester, find.byType(ZSubfolderNarrowNav)).bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top),
      );

      await _openTab(tester, kProgTab);
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(
        _rect(tester, find.byType(ZSubfolderNarrowNav)).bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top),
      );
    });

    testWidgets('la feuille modale s\'ouvre DEPUIS LE 3ᵉ ONGLET', (
      tester,
    ) async {
      // Le point d'ancrage a changé : une surface flottante n'a pas le même
      // contexte selon son point d'ancrage (Navigator, Directionality).
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );
      await _openTab(tester, kProgTab);

      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'changer de fratrie DEPUIS le 2ᵉ onglet FILTRE le corps Matériel',
      (tester) async {
        // 🔴 La garde qui mesure le besoin réel : voir la nav ne sert à rien si
        // agir dessus depuis un autre onglet ne change pas le contenu.
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        );
        // Départ : racine ⇒ marqueur `empty:null`.
        expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);

        await _openTab(tester, kNoteTab);
        await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
        await tester.pumpAndSettle();

        // La barre annonce le nouveau courant, sans quitter l'onglet Notebook.
        expect(find.text('Sous-dossier 1'), findsWidgets);
        expect(find.text('NOTE_BODY'), findsOneWidget);

        await _openTab(tester, kMatTab);
        expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('empty:null')), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('3. Forme LARGE sous `aboveTabs` — arbitrage MESURÉ', () {
    testWidgets('≥ 600 dp : la BANDE est hissée, AUCUNE sidebar, AUCUN throw', (
      tester,
    ) async {
      await setScreen(tester, 1200, 900);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );

      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      // La sidebar est structurellement inhissable (hauteur NON bornée dans le
      // créneau) : la rendre là lèverait un `RenderFlex ... unbounded`.
      expect(find.byType(ZSubfolderSidebar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '🔴 MESURE de l\'impossibilité : la sidebar dans un créneau à hauteur NON '
      'bornée lève une assertion de layout',
      (tester) async {
        // C'est la preuve qui FONDE l'arbitrage, rejouée ici pour qu'elle ne
        // reste pas une affirmation de rapport.
        final ValueNotifier<String?> selected = ValueNotifier<String?>(null);
        addTearDown(selected.dispose);
        // Le layout casse en cascade ; `takeException` n'en résume qu'un
        // agrégat. On intercepte donc les détails BRUTS le temps du pump.
        final List<String> errors = <String>[];
        final void Function(FlutterErrorDetails)? previous =
            FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) =>
            errors.add(details.exceptionAsString());
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  // Géométrie EXACTE du créneau `aboveTabViews` : enfant non
                  // flexible d'une `Column` dont le frère porte l'`Expanded`.
                  SizedBox(
                    width: 300,
                    child: ZSubfolderSidebar(
                      spec: navSpec(),
                      collapsed: false,
                      width: 300,
                      minWidth: 300,
                      maxWidth: 400,
                      selected: selected,
                      onSelect: (_) {},
                      onToggleCollapsed: () {},
                      onWidthChanged: (_) {},
                      onWidthChangeEnd: () {},
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        );
        FlutterError.onError = previous;
        expect(errors, isNotEmpty);
        expect(
          errors.any((String e) => e.contains('unbounded')),
          isTrue,
          reason: 'attendu une contrainte de hauteur NON bornée : $errors',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('4. Conflit `aboveTabViews` de l\'hôte + `aboveTabs`', () {
    testWidgets('COMPOSITION : les DEUX sont rendus, la nav en PREMIER', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        aboveTabViews: const SizedBox(key: kHostSlotKey, height: 24),
      );

      // GARDE MORDANTE contre une résolution par PRIORITÉ : l'un des deux
      // disparaîtrait silencieusement.
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(find.byKey(kHostSlotKey), findsOneWidget);

      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      final Rect host = _rect(tester, find.byKey(kHostSlotKey));
      final Rect views = _rect(tester, find.byType(TabBarView));
      // Ordre DOCUMENTÉ : navigation d'abord, slot de l'hôte ensuite…
      expect(nav.bottom, lessThanOrEqualTo(host.top));
      // …et les deux au-dessus des vues d'onglets.
      expect(host.bottom, lessThanOrEqualTo(views.top));

      // Aucun `assert` : la composition est un cas NORMAL, pas une panne.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'le slot de l\'hôte est mis en page À L\'IDENTIQUE avec et sans '
      '`aboveTabs`',
      (tester) async {
        // 🔴 Garde issue d'une R3 : un `crossAxisAlignment.stretch` avait été
        // écrit dans la composition. Il ne rougissait nulle part — pourtant il
        // changeait la LARGEUR du slot de l'hôte selon qu'il demandait ou non
        // `aboveTabs`. Ce widget n'a pas de largeur propre : c'est exactement
        // le cas qui distingue les deux traitements.
        const Widget slot = SizedBox(key: kHostSlotKey, height: 20);

        await setScreen(tester, 500, 800);
        await pumpDetail(tester, aboveTabViews: slot);
        final Size reference = tester.getSize(find.byKey(kHostSlotKey));

        await pumpDetail(
          tester,
          aboveTabViews: slot,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        );
        expect(tester.getSize(find.byKey(kHostSlotKey)), reference);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('5. Le placement NE DÉPEND PAS du point de rupture', () {
    for (final double width in <double>[400, 599, 600, 1200]) {
      testWidgets('$width dp — `aboveTabs` hisse la nav', (tester) async {
        await setScreen(tester, width, 900);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        );
        expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
        // 🔴 Le cœur de l'indépendance des DEUX AXES : si le placement était
        // déduit du seuil (« aboveTabs seulement sous 600 »), les largeurs
        // 600 et 1200 rougiraient ici.
        expect(
          _rect(tester, find.byType(ZSubfolderNarrowNav)).bottom,
          lessThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top),
        );
      });

      testWidgets('$width dp — `withinTab` garde la nav DANS l\'onglet', (
        tester,
      ) async {
        await setScreen(tester, width, 900);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.withinTab,
        );
        final Rect views = _rect(tester, find.byType(TabBarView));
        final Finder navFinder = width < 600
            ? find.byType(ZSubfolderNarrowNav)
            : find.byType(ZSubfolderSidebar);
        expect(navFinder, findsOneWidget);
        expect(_rect(tester, navFinder).top, greaterThanOrEqualTo(views.top));
      });
    }

    testWidgets(
      '`narrowMode` reste l\'AUTRE axe : `compact` hissé donne des puces',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
          nav: navSpec(narrowMode: ZSubfolderNarrowMode.compact),
        );
        expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
        expect(find.byType(ZSubfolderSelectorBar), findsNothing);
        final Rect chips = _rect(tester, find.byType(ZSubfolderCompactSelector));
        final Rect views = _rect(tester, find.byType(TabBarView));
        expect(chips.bottom, lessThanOrEqualTo(views.top));
        // L'AUTRE surface du socle borde elle aussi la page (mesurée, pas
        // supposée : c'est ce qui a montré inerte l'étirement explicite).
        expect(chips.width, views.width);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('6. Mode SLIVER — le créneau existe aussi là', () {
    testWidgets('`aboveTabs` en mode sliver : nav unique au-dessus des vues', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        mode: ZPageAppBarMode.pinned,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(
        _rect(tester, find.byType(ZSubfolderNarrowNav)).bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('7. RTL & a11y de la bande hissée (AD-13)', () {
    testWidgets('RTL : la bande hissée reste pleine largeur et annoncée', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        textDirection: TextDirection.rtl,
      );
      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      expect(nav.left, 0);
      expect(nav.width, _rect(tester, find.byType(TabBarView)).width);
      // Cible tapable ≥ 48 dp mesurée sur le DÉCLENCHEUR lui-même (pas sur une
      // contrainte du parent).
      expect(
        tester.getSize(find.byKey(ZSubfolderSelectorBar.triggerKey)).height,
        greaterThanOrEqualTo(48.0),
      );
    });
  });
}
