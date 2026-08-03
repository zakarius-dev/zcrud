/// CR-IFFD-45 — la fratrie entre l'app-bar et les onglets, et la sélection
/// enfin ADRESSABLE.
///
/// 🔴 **Le piège de ce lot, explicitement évité** (il est le même qu'en
/// CR-IFFD-43, en pire) : une garde « la navigation est PRÉSENTE » est verte
/// dans les **trois** placements — elle ne mesure rien. Et une garde
/// « la valeur du contrôleur suit » est verte même si le widget garde un état
/// parallèle. Les gardes ci-dessous mesurent donc :
///
/// * la **GÉOMÉTRIE** — l'app-bar **grandit réellement** de la hauteur
///   déclarée, le bord bas de la bande est ≤ bord haut du `TabBar` **et** du
///   `TabBarView`, la bande ne sort pas par le haut : c'est exactement le
///   triplet que la voie `subtitle` violait **en silence** ;
/// * l'**UNICITÉ** — une seule surface de navigation dans l'arbre, donc une
///   seule source de sélection ;
/// * l'**ATTEIGNABILITÉ** depuis le 2ᵉ et le 3ᵉ onglet, et le fait qu'**agir**
///   dessus filtre le corps Matériel ;
/// * la **NEUTRALITÉ** des deux placements existants — mesurée sur la hauteur
///   d'app-bar et sur l'absence de créneau, pas sur une intention ;
/// * pour le contrôleur, le **RENDU** (pas la valeur) : piloter depuis
///   l'extérieur change le corps filtré ET l'annonce de la barre ; et après un
///   tap dans l'UI, une écriture de l'hôte reste souveraine — ce qu'un état
///   parallèle ferait rougir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZDisplayStateOwnerMixin, ZcrudScope, ZcrudTheme;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/suf3_harness.dart';

/// Marqueur du slot `aboveTabBar` FOURNI PAR L'HÔTE (cas de composition).
const Key kHostBarSlotKey = ValueKey<String>('host:aboveBar');

/// Rectangle global d'un finder unique.
Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

/// Bascule sur l'onglet portant [label].
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

/// Hauteur totale de l'app-bar rendue (toolbar + `bottom:`).
double _appBarHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AppBar)).height;

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  group('1. NEUTRALITÉ — les deux placements existants ne bougent pas', () {
    testWidgets('le défaut de production reste `withinTab`', (tester) async {
      // Lu sur le socle, jamais recopié.
      expect(kProductionDefaultNavPlacement, ZSubfolderNavPlacement.withinTab);
    });

    testWidgets(
      'défaut ET `aboveTabs` : le créneau `aboveTabBar` du shell reste NUL',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(tester);
        expect(
          tester.widget<ZPageScaffold>(find.byType(ZPageScaffold)).aboveTabBar,
          isNull,
        );
        // …et la hauteur déclarée reste nulle elle aussi : déclarer une hauteur
        // sans créneau ferait grandir l'app-bar pour rien.
        expect(
          tester
              .widget<ZPageScaffold>(find.byType(ZPageScaffold))
              .aboveTabBarHeight,
          isNull,
        );

        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        );
        expect(
          tester.widget<ZPageScaffold>(find.byType(ZPageScaffold)).aboveTabBar,
          isNull,
        );
      },
    );

    testWidgets(
      '🔴 GÉOMÉTRIE : la hauteur d\'app-bar est IDENTIQUE sous `withinTab` et '
      'sous `aboveTabs`, et GRANDIT sous `aboveTabBar`',
      (tester) async {
        // La propriété qui compte n'est pas « le champ est nul » mais « rien
        // n'a bougé à l'écran ». Une bande hissée « au cas où » (même invisible)
        // ferait diverger ces trois mesures.
        await setScreen(tester, 500, 800);

        await pumpDetail(tester);
        final double baseline = _appBarHeight(tester);

        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
        );
        expect(_appBarHeight(tester), baseline);

        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        );
        expect(_appBarHeight(tester), baseline + kZSubfolderNavBandHeight);
      },
    );

    testWidgets(
      'défaut : le SYMPTÔME HISTORIQUE est conservé (nav absente au 2ᵉ onglet)',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(tester);
        await _openTab(tester, kNoteTab);
        expect(find.byType(ZSubfolderNarrowNav), findsNothing);
      },
    );

    testWidgets('`aboveTabs` garde sa bande SOUS le `TabBar`, pas dedans', (
      tester,
    ) async {
      // Garde d'anti-glissement : `aboveTabs` ne doit pas se mettre à emprunter
      // le nouveau créneau. Mesuré sur la géométrie réelle.
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs,
      );
      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      final Rect bar = _rect(tester, find.byType(TabBar));
      expect(nav.top, greaterThanOrEqualTo(bar.bottom));
    });

    testWidgets('le slot `aboveTabBar` de l\'hôte est RELAYÉ tel quel', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        aboveTabBar: const SizedBox(key: kHostBarSlotKey, height: 20),
      );
      expect(find.byKey(kHostBarSlotKey), findsOneWidget);
      // Il est bien DANS l'app-bar, au-dessus du `TabBar`…
      expect(
        _rect(tester, find.byKey(kHostBarSlotKey)).bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBar)).top),
      );
      // …et il n'a PAS entraîné la navigation avec lui (défaut `withinTab`).
      expect(
        _rect(tester, find.byType(ZSubfolderNarrowNav)).top,
        greaterThanOrEqualTo(_rect(tester, find.byType(TabBarView)).top),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('2. `aboveTabBar` — géométrie MESURÉE (le défaut de `subtitle`)', () {
    testWidgets(
      '🔴 bord bas de la bande ≤ bord haut du `TabBar` ET du `TabBarView` ; '
      'aucun chevauchement, rien hors écran',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        );

        final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
        final Rect bar = _rect(tester, find.byType(TabBar));
        final Rect views = _rect(tester, find.byType(TabBarView));

        // (1) LE défaut mesuré de la voie `subtitle` : une bande de 48 dp y
        // recouvrait le `TabBar` de 10 dp, sans aucune exception.
        expect(nav.bottom, lessThanOrEqualTo(bar.top));
        expect(nav.bottom, lessThanOrEqualTo(views.top));
        // (2) L'autre défaut mesuré : une bande haute sortait par le HAUT
        // (rect dy = -6). Le bord haut reste dans l'écran.
        expect(nav.top, greaterThanOrEqualTo(0.0));
        // (3) Elle est DANS l'app-bar (au-dessus du `TabBar` mais sous la
        // toolbar) — donc l'app-bar a bien absorbé sa hauteur.
        expect(
          nav.bottom,
          lessThanOrEqualTo(_rect(tester, find.byType(AppBar)).bottom),
        );
        // (4) Pleine largeur, mesurée contre les vues d'onglets.
        expect(nav.width, views.width);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('l\'app-bar grandit EXACTEMENT de la hauteur déclarée', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      final double baseline = _appBarHeight(tester);

      for (final double declared in <double>[48, 72, 96]) {
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
          subfolderNavBandHeight: declared,
        );
        expect(
          _appBarHeight(tester),
          baseline + declared,
          reason: 'hauteur déclarée $declared dp non absorbée par l\'app-bar',
        );
        // La bande occupe la hauteur DÉCLARÉE, pas la sienne : c'est ce qui
        // rend le débordement bruyant plutôt que silencieux.
        expect(
          _rect(tester, find.byType(ZSubfolderNarrowNav)).height,
          declared,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'hauteur par DÉFAUT : celle du socle, augmentée de la marge de thème',
      (tester) async {
        // 🔴 La hauteur par défaut n'est pas une constante de test : elle est
        // relue sur le rendu. Une bande tronquée (marge non comptée) rougirait.
        await setScreen(tester, 500, 800);
        await pumpDetail(tester);
        final double baseline = _appBarHeight(tester);

        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        );
        expect(_appBarHeight(tester), baseline + kZSubfolderNavBandHeight);

        const double v = 10;
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
          wrap: (Widget child) => ZcrudScope(
            theme: const ZcrudTheme(
              subfolderBarPadding: EdgeInsetsDirectional.symmetric(vertical: v),
            ),
            child: child,
          ),
        );
        expect(
          _appBarHeight(tester),
          baseline + kZSubfolderNavBandHeight + 2 * v,
          reason: 'la marge verticale du thème doit être comptée, pas tronquée',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'la marge de thème n\'est PAS comptée pour la rangée de puces',
      (tester) async {
        // `subfolderBarPadding` n'est posée que par la barre de sélection : la
        // compter en mode `compact` réserverait du vide dans l'app-bar.
        await setScreen(tester, 500, 800);
        await pumpDetail(tester);
        final double baseline = _appBarHeight(tester);

        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
          nav: navSpec(narrowMode: ZSubfolderNarrowMode.compact),
          wrap: (Widget child) => ZcrudScope(
            theme: const ZcrudTheme(
              subfolderBarPadding: EdgeInsetsDirectional.symmetric(vertical: 10),
            ),
            child: child,
          ),
        );
        expect(_appBarHeight(tester), baseline + kZSubfolderNavBandHeight);
        expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
      },
    );

    testWidgets('mode SLIVER : le créneau existe aussi là', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        mode: ZPageAppBarMode.pinned,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
      );
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      expect(nav.bottom, lessThanOrEqualTo(_rect(tester, find.byType(TabBar)).top));
      expect(nav.top, greaterThanOrEqualTo(0.0));
      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('3. UNICITÉ — une seule surface, donc une seule sélection', () {
    for (final double width in <double>[400, 599, 600, 1200]) {
      testWidgets('$width dp — une seule bande, AUCUNE sidebar', (tester) async {
        await setScreen(tester, width, 900);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        );
        // Une nav laissée AUSSI dans l'onglet Matériel en donnerait deux — et
        // deux surfaces branchées sur deux sources possibles.
        expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
        expect(find.byType(ZSubfolderSelectorBar), findsOneWidget);
        // La sidebar est inhissable ici : le créneau est à hauteur FIXE
        // déclarée, elle y serait écrasée à 48 dp.
        expect(find.byType(ZSubfolderSidebar), findsNothing);
        // Indépendance des deux axes : le placement ne se déduit pas du seuil.
        expect(
          _rect(tester, find.byType(ZSubfolderNarrowNav)).bottom,
          lessThanOrEqualTo(_rect(tester, find.byType(TabBar)).top),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('`narrowMode` reste l\'AUTRE axe : `compact` donne des puces', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        nav: navSpec(narrowMode: ZSubfolderNarrowMode.compact),
      );
      expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
      expect(find.byType(ZSubfolderSelectorBar), findsNothing);
      expect(
        _rect(tester, find.byType(ZSubfolderCompactSelector)).bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBar)).top),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('4. ATTEIGNABLE et ACTIONNABLE depuis le 2ᵉ et le 3ᵉ onglet', () {
    for (final String tab in <String>[kNoteTab, kProgTab]) {
      testWidgets('depuis « $tab » : la feuille s\'ouvre et FILTRE le corps', (
        tester,
      ) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        );
        expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);

        await _openTab(tester, tab);
        // Visible ET géométriquement au bon endroit depuis cet onglet.
        expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
        expect(
          _rect(tester, find.byType(ZSubfolderNarrowNav)).bottom,
          lessThanOrEqualTo(_rect(tester, find.byType(TabBar)).top),
        );

        // ACTIONNABLE : le tap atteint réellement le déclencheur (un créneau
        // recouvert par la toolbar, ou de hauteur nulle, rougirait ici).
        await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
        await tester.pumpAndSettle();
        expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsOneWidget);
        await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
        await tester.pumpAndSettle();

        // On n'a PAS quitté l'onglet…
        expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsNothing);
        // …et le corps Matériel a bien été filtré.
        await _openTab(tester, kMatTab);
        expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('empty:null')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cible tactile du déclencheur ≥ 48 dp, en LTR comme en RTL', (
      tester,
    ) async {
      for (final TextDirection dir in TextDirection.values) {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
          textDirection: dir,
        );
        expect(
          tester.getSize(find.byKey(ZSubfolderSelectorBar.triggerKey)).height,
          greaterThanOrEqualTo(48.0),
          reason: 'cible tactile écrasée par la hauteur déclarée ($dir)',
        );
        // La bande borde la page des deux côtés, sans notion de left/right.
        final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
        expect(nav.left, 0);
        expect(nav.width, _rect(tester, find.byType(TabBarView)).width);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('5. COMPOSITION avec le slot `aboveTabBar` de l\'hôte', () {
    testWidgets('les DEUX sont rendus, la nav en PREMIER', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        aboveTabBar: const SizedBox(key: kHostBarSlotKey, height: 24),
        aboveTabBarHeight: 24,
      );

      // GARDE MORDANTE contre une résolution par PRIORITÉ : l'un des deux
      // disparaîtrait silencieusement.
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(find.byKey(kHostBarSlotKey), findsOneWidget);

      final Rect nav = _rect(tester, find.byType(ZSubfolderNarrowNav));
      final Rect host = _rect(tester, find.byKey(kHostBarSlotKey));
      expect(nav.bottom, lessThanOrEqualTo(host.top));
      expect(
        host.bottom,
        lessThanOrEqualTo(_rect(tester, find.byType(TabBar)).top),
      );
      // Aucun `assert` : la composition est un cas NORMAL, pas une panne.
      expect(tester.takeException(), isNull);
    });

    testWidgets('la hauteur déclarée est la SOMME (rien n\'est tronqué)', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      final double baseline = _appBarHeight(tester);

      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        subfolderNavBandHeight: 48,
        aboveTabBar: const SizedBox(key: kHostBarSlotKey, height: 24),
        aboveTabBarHeight: 24,
      );
      expect(_appBarHeight(tester), baseline + 48 + 24);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '🔴 le slot de l\'hôte est mis en page À L\'IDENTIQUE avec et sans la nav',
      (tester) async {
        // Pendant exact de la garde CR-IFFD-43 sur `aboveTabViews` — mais la
        // RÉPONSE est ici l'inverse : le socle pose ce créneau-ci dans une
        // `Column` `stretch`, donc un slot SEUL y reçoit la largeur pleine.
        // Composer sans `stretch` le ferait retomber à sa largeur intrinsèque
        // (0 dp pour ce `SizedBox`) — invisible, et pourtant une régression.
        const Widget slot = SizedBox(key: kHostBarSlotKey, height: 20);

        await setScreen(tester, 500, 800);
        await pumpDetail(tester, aboveTabBar: slot, aboveTabBarHeight: 20);
        final Size reference = tester.getSize(find.byKey(kHostBarSlotKey));
        expect(reference.width, greaterThan(0));

        await pumpDetail(
          tester,
          aboveTabBar: slot,
          aboveTabBarHeight: 20,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        );
        expect(tester.getSize(find.byKey(kHostBarSlotKey)), reference);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('6. Sélection ADRESSABLE — contrôleur externe optionnel', () {
    testWidgets('sans contrôleur : `initialSelectedSubfolderId` fait foi', (
      tester,
    ) async {
      // 🔴 Garde du piège connu : `bind(null)` au montage est un NO-OP
      // (early-return sur `identical`). Si l'amorce interne n'était pas déjà
      // posée à la construction de la liaison, la page repartirait sur la
      // racine et cette garde rougirait.
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, initialSelectedSubfolderId: 'sf2');
      expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);
    });

    testWidgets('PRÉCÉDENCE : le contrôleur PRIME sur l\'amorce de la page', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await tester.pumpWidget(
        const _ControlledHost(
          controllerInitial: 'sf1',
          pageInitial: 'sf2', // contredit délibérément le contrôleur
        ),
      );
      await tester.pumpAndSettle();
      // Deux amorces contradictoires : une seule gagne, et c'est écrit.
      expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('empty:sf2')), findsNothing);
    });

    testWidgets(
      '🔴 le RENDU suit le contrôleur piloté DE L\'EXTÉRIEUR (pas la valeur)',
      (tester) async {
        // Une garde qui mesurerait `controller.value` serait verte même avec un
        // état parallèle dans la page. On mesure donc le corps filtré ET
        // l'annonce de la barre.
        await setScreen(tester, 500, 800);
        await tester.pumpWidget(const _ControlledHost());
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);

        _capturedController!.select('sf2');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('empty:null')), findsNothing);
        // La BARRE annonce le nouveau courant : c'est la même et unique source.
        expect(find.text('Sous-dossier 2'), findsWidgets);

        _capturedController!.selectRoot();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 AUCUN état parallèle : après un tap dans l\'UI, l\'hôte reste souverain',
      (tester) async {
        // C'est LA garde qui distingue « source de vérité » de « miroir ». Si
        // la page gardait son `ValueNotifier` privé en parallèle, le tap
        // l'alimenterait, et l'écriture de l'hôte ensuite ne changerait pas le
        // rendu (ou le ferait diverger de la barre).
        await setScreen(tester, 500, 800);
        await tester.pumpWidget(const _ControlledHost());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
        await tester.pumpAndSettle();

        // (a) Le tap a écrit À LA SOURCE — l'hôte le lit chez lui.
        expect(_capturedController!.value, 'sf1');
        expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);

        // (b) …et l'hôte reprend la main immédiatement après.
        _capturedController!.select('sf2');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('empty:sf1')), findsNothing);
      },
    );

    testWidgets('`onSelectionChanged` constate les DEUX origines', (
      tester,
    ) async {
      final List<String?> seen = <String?>[];
      await setScreen(tester, 500, 800);
      await tester.pumpWidget(_ControlledHost(onSelectionChanged: seen.add));
      await tester.pumpAndSettle();
      // Aucune émission au MONTAGE : constater un changement qui n'a pas eu
      // lieu ferait passer l'amorce pour une action de l'utilisateur.
      expect(seen, isEmpty);

      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
      await tester.pumpAndSettle();
      expect(seen, <String?>['sf1']);

      _capturedController!.select('sf2');
      await tester.pumpAndSettle();
      expect(seen, <String?>['sf1', 'sf2']);

      // Réécrire la MÊME valeur n'émet rien (le contrôleur ne notifie que sur
      // changement réel) — sans quoi l'hôte se réveillerait pour rien.
      _capturedController!.select('sf2');
      await tester.pumpAndSettle();
      expect(seen, <String?>['sf1', 'sf2']);
    });

    testWidgets('`onSelectionChanged` SEUL (sans contrôleur) fonctionne aussi', (
      tester,
    ) async {
      // Observer sans commander : le cas de l'hôte qui veut juste savoir.
      final List<String?> seen = <String?>[];
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: navSpec(onSelectionChanged: seen.add));
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
      await tester.pumpAndSettle();
      expect(seen, <String?>['sf1']);
    });

    testWidgets('RETRAIT du contrôleur en cours de vie : aucun saut d\'état', (
      tester,
    ) async {
      final ValueNotifier<bool> attached = ValueNotifier<bool>(true);
      addTearDown(attached.dispose);
      await setScreen(tester, 500, 800);
      await tester.pumpWidget(_ControlledHost(attached: attached));
      await tester.pumpAndSettle();

      _capturedController!.select('sf2');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);

      // L'hôte retire son pilote : la page redevient propriétaire, et REPREND
      // la dernière valeur rendue (jamais un retour à l'amorce).
      attached.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);

      // …et elle est de nouveau pilotable par l'UI.
      await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('empty:sf0')), findsOneWidget);
    });

    testWidgets('le contrôleur pilote AUSSI la SIDEBAR (≥ 600 dp, `withinTab`)', (
      tester,
    ) async {
      // La capacité n'est pas liée au nouveau placement : elle vaut pour toutes
      // les surfaces, sinon elle serait « aboveTabBar-only ».
      await setScreen(tester, 900, 800);
      await tester.pumpWidget(const _ControlledHost(width: 900));
      await tester.pumpAndSettle();
      expect(find.byType(ZSubfolderSidebar), findsOneWidget);

      _capturedController!.select('sf1');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('7. AD-2 / SM-1 — changer de fratrie ne reconstruit que le corps', () {
    testWidgets(
      'changer de fratrie depuis la bande NE reconstruit PAS l\'onglet ouvert',
      (tester) async {
        // 🔴 La mesure est prise **sur l'onglet Notebook OUVERT** — et c'est ce
        // qui la rend non tautologique : le `TabBarView` construit ses vues
        // paresseusement, donc compter les builds d'une vue jamais visitée
        // resterait à 0 quoi qu'il arrive. Ici la vue EST montée ; et
        // `_zTabBarView` recrée un `Builder` à chaque build de page — un
        // `setState` à l'échelle de la page ferait donc **remonter** ce
        // compteur. C'est exactement l'invariant AD-2/SM-1.
        int notebookBuilds = 0;
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
          notebookBuilder: (context) {
            notebookBuilds++;
            return const Text('NOTE_BODY');
          },
        );

        await _openTab(tester, kNoteTab);
        final int before = notebookBuilds;
        expect(
          before,
          greaterThan(0),
          reason: 'la vue mesurée doit être RÉELLEMENT montée',
        );

        // On change de fratrie SANS quitter l'onglet Notebook.
        await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZSubfolderSelectorBar.itemKey('sf1')));
        await tester.pumpAndSettle();

        expect(notebookBuilds, before);

        // …et le corps Matériel a bien pris le filtre (la sélection n'est pas
        // restée sans effet, ce qui rendrait la mesure ci-dessus creuse).
        await _openTab(tester, kMatTab);
        expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
      },
    );
  });
}

/// Contrôleur capturé du dernier `_ControlledHost` monté (les tests le pilotent
/// « depuis l'extérieur », exactement comme le ferait un hôte).
ZSubfolderSelectionController? _capturedController;

/// Hôte MINIMAL conforme au patron : il **possède** le contrôleur via
/// `ZDisplayStateOwnerMixin`, le crée dans `initState` (jamais dans `build` —
/// le patron le refuserait) et le passe à la spec de navigation.
class _ControlledHost extends StatefulWidget {
  const _ControlledHost({
    this.controllerInitial,
    this.pageInitial,
    this.onSelectionChanged,
    this.attached,
    this.width = 500,
  });

  final String? controllerInitial;
  final String? pageInitial;
  final ValueChanged<String?>? onSelectionChanged;

  /// Permet à un test de DÉBRANCHER le contrôleur en cours de vie.
  final ValueNotifier<bool>? attached;

  final double width;

  @override
  State<_ControlledHost> createState() => _ControlledHostState();
}

class _ControlledHostState extends State<_ControlledHost>
    with ZDisplayStateOwnerMixin<_ControlledHost> {
  late final ZSubfolderSelectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZSubfolderSelectionController(
      owner: this,
      initialValue: widget.controllerInitial,
      debugLabel: 'test:subfolderSelection',
    );
    _capturedController = _controller;
  }

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool>? attached = widget.attached;
    return MaterialApp(
      home: attached == null
          ? _detail(true)
          : ValueListenableBuilder<bool>(
              valueListenable: attached,
              builder: (_, bool on, _) => _detail(on),
            ),
    );
  }

  Widget _detail(bool attached) => ZStudyFolderDetail(
    title: 'Dossier',
    materialTabLabel: kMatTab,
    notebookTabLabel: kNoteTab,
    progressionTabLabel: kProgTab,
    materialSectionsBuilder: defaultSections,
    notebookBuilder: (_) => const Text('NOTE_BODY'),
    initialSelectedSubfolderId: widget.pageInitial,
    subfolderNavPlacement: widget.width >= 600
        ? ZSubfolderNavPlacement.withinTab
        : ZSubfolderNavPlacement.aboveTabBar,
    nav: navSpec(
      selectionController: attached ? _controller : null,
      onSelectionChanged: widget.onSelectionChanged,
    ),
  );
}
