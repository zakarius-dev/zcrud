/// **CR-IFFD-60** — le déclencheur de fratrie : FOND, BORDURE et ÉLÉVATION
/// sont COMPOSABLES (ils ne se combinaient pas : `filled`/`outlined` étaient
/// exclusifs, l'élévation n'existait pas).
///
/// Ce que ces gardes mesurent — et pourquoi sous cette forme :
///
/// * « le fond est posé » se mesure en **couleur PEINTE** du bon rôle (pixel
///   capturé), jamais en présence d'une décoration ;
/// * la composition se mesure **les trois attributs posés ENSEMBLE** — une
///   garde par attribut isolé raterait une exclusivité résiduelle, qui est LE
///   défaut de cette CR ;
/// * l'encre se mesure par l'**ordre des couches** (le `Material` du chrome
///   est l'ancêtre d'encre de l'`InkWell`) ET par le **splash réellement
///   peint** ;
/// * la neutralité `flat` se mesure par l'**arbre** (même nombre d'éléments),
///   pas par l'apparence.
///
/// ## Arbitrage élévation (MESURÉ, sonde CR-IFFD-60)
///
/// Sous `aboveTabBar`, le déclencheur est bord à bord au-dessus du `TabBar`
/// (écart 0 dp) et la zone n'est PAS rognée par le `PreferredSize` : une
/// `BoxShadow` (blur 8, offset (0, 4)) a réellement repeint la bande du
/// `TabBar` (796 pixels modifiés sur 3 lignes échantillonnées, delta max
/// 254/255). L'élévation est donc TONALE M3 (voile `surfaceTint`), jamais une
/// ombre portée — `Material.elevation` reste à 0 par construction.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

const Key _kProbeKey = ValueKey<String>('cr60:probe');

/// Enveloppe : `RepaintBoundary` (capture de pixels) + `ZcrudScope` (le token
/// passe par le scope, comme chez l'hôte — pas par `ThemeData.extensions`).
Widget Function(Widget) _scoped(ZcrudTheme theme) => (Widget child) =>
    RepaintBoundary(key: _kProbeKey, child: ZcrudScope(theme: theme, child: child));

Finder get _chrome => find.byKey(ZSubfolderSelectorBar.triggerChromeKey);

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(ZSubfolderSelectorBar.triggerKey)))
        .colorScheme;

/// Couleur RÉELLEMENT PEINTE en [global] (coordonnées logiques, dpr forcé à 1
/// par `setScreen`) — lue sur l'image du `RepaintBoundary` de test, donc après
/// TOUTES les couches de peinture (fond, voile tonal, bordure).
Future<Color> _pixelAt(WidgetTester tester, Offset global) async {
  final Rect bounds = tester.getRect(find.byKey(_kProbeKey));
  final Offset local = global - bounds.topLeft;
  late final Color color;
  await tester.runAsync(() async {
    final ui.Image image =
        await captureImage(tester.element(find.byKey(_kProbeKey)));
    final ByteData data = (await image.toByteData())!;
    final int x = local.dx.round().clamp(0, image.width - 1);
    final int y = local.dy.round().clamp(0, image.height - 1);
    final int i = (y * image.width + x) * 4;
    color = Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  });
  return color;
}

/// Égalité de couleur PEINTE à ±1 par canal (arrondi de rasterisation).
void _expectPainted(Color actual, Color expected, String reason) {
  bool close(double a, double b) => (a - b).abs() <= 1.5 / 255.0;
  expect(
    close(actual.r, expected.r) &&
        close(actual.g, expected.g) &&
        close(actual.b, expected.b),
    isTrue,
    reason: '$reason — peint $actual, attendu $expected',
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. NEUTRALITÉ — mesurée sur l'ARBRE, pas l'apparence
  // -------------------------------------------------------------------------
  group('CR-IFFD-60 — neutralité littérale', () {
    testWidgets('flat + retraits EXPLICITES (`none`/`none`) ⇒ MÊME arbre que '
        'sans aucun jeton', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      final int baseline = tester.allWidgets.length;
      expect(_chrome, findsNothing);

      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerFill: ZSubfolderTriggerFill.none,
            subfolderTriggerBorder: ZSubfolderTriggerBorder.none,
          ),
        ),
      );
      expect(_chrome, findsNothing);
      // Même ARBRE (à l'enveloppe de test près : RepaintBoundary + ZcrudScope),
      // pas seulement même apparence — c'est la garde CR-IFFD-41, étendue.
      expect(tester.allWidgets.length, baseline + 2);
    });

    testWidgets('`filled` + `fill: none` ⇒ plus RIEN à peindre, chrome ABSENT '
        'de l\'arbre', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerVariant: ZSubfolderTriggerVariant.filled,
            subfolderTriggerFill: ZSubfolderTriggerFill.none,
          ),
        ),
      );
      expect(_chrome, findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 2. COMPOSITION — les TROIS attributs posés ENSEMBLE (le défaut de la CR)
  // -------------------------------------------------------------------------
  group('CR-IFFD-60 — fond + bordure + élévation COMPOSENT', () {
    testWidgets('les trois ensemble : fond PEINT du bon rôle, voile tonal '
        'gradué par l\'élévation, bordure du bon rôle — sur UN SEUL chrome', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            // Variante ABSENTE : les trois attributs tiennent seuls.
            subfolderTriggerFill: ZSubfolderTriggerFill.surfaceContainerLow,
            subfolderTriggerBorder: ZSubfolderTriggerBorder.outline,
            subfolderTriggerElevation: 3,
          ),
        ),
      );

      expect(_chrome, findsOneWidget);
      final ColorScheme scheme = _scheme(tester);

      // FOND + ÉLÉVATION, mesurés ENSEMBLE en couleur PEINTE : le pixel au
      // centre du déclencheur doit être le rôle demandé TEINTÉ par le voile
      // tonal M3 — ni le rôle nu (élévation ignorée), ni un autre rôle.
      final Color expected = ElevationOverlay.applySurfaceTint(
        scheme.surfaceContainerLow,
        scheme.surfaceTint,
        3,
      );
      final Color painted =
          await _pixelAt(tester, tester.getCenter(_chrome));
      _expectPainted(painted, expected, 'fond teinté (rôle + voile tonal)');
      // Contrôle négatif : le voile CHANGE réellement le rôle nu — sinon la
      // garde précédente serait verte avec une élévation inerte.
      expect(expected, isNot(scheme.surfaceContainerLow));

      // BORDURE, sur le MÊME chrome (composition, pas exclusivité).
      final Material m = tester.widget<Material>(_chrome);
      final RoundedRectangleBorder shape = m.shape! as RoundedRectangleBorder;
      expect(shape.side.color, scheme.outline);
      expect(shape.side, isNot(BorderSide.none));

      // Et JAMAIS d'ombre portée (arbitrage mesuré — cf. en-tête de fichier).
      expect(m.elevation, 0);
    });

    testWidgets('élévation SEULE sur `flat` : le voile tonal est un fond '
        'translucide — le chrome existe, sans bordure ni rôle de fond', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(const ZcrudTheme(subfolderTriggerElevation: 2)),
      );
      expect(_chrome, findsOneWidget);
      final Material m = tester.widget<Material>(_chrome);
      // Voile translucide (alpha ni 0 ni plein) : la teinte se pose sur un
      // fond invisible, pas sur un rôle matérialisé.
      expect(m.color, isNotNull);
      expect(m.color!.a, greaterThan(0.0));
      expect(m.color!.a, lessThan(1.0));
      expect((m.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(m.elevation, 0);
    });
  });

  // -------------------------------------------------------------------------
  // 3. PRÉCÉDENCE — les jetons RAFFINENT la variante, attribut par attribut
  // -------------------------------------------------------------------------
  group('CR-IFFD-60 — précédence jeton > variante, attribut par attribut', () {
    testWidgets('`filled` + jeton bordure : le FOND de la variante est '
        'CONSERVÉ, la bordure du jeton s\'AJOUTE', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerVariant: ZSubfolderTriggerVariant.filled,
            subfolderTriggerBorder: ZSubfolderTriggerBorder.outlineVariant,
          ),
        ),
      );
      final ColorScheme scheme = _scheme(tester);
      final Material m = tester.widget<Material>(_chrome);
      expect(m.color, scheme.surfaceContainerHighest,
          reason: 'le jeton bordure ne touche PAS au fond de la variante');
      expect(
        (m.shape! as RoundedRectangleBorder).side.color,
        scheme.outlineVariant,
      );
    });

    testWidgets('`outlined` + jeton fond : la BORDURE de la variante est '
        'CONSERVÉE, le fond du jeton s\'AJOUTE — la référence `Card.outlined` '
        'de la CR', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerVariant: ZSubfolderTriggerVariant.outlined,
            subfolderTriggerFill: ZSubfolderTriggerFill.surfaceContainer,
          ),
        ),
      );
      final ColorScheme scheme = _scheme(tester);
      final Material m = tester.widget<Material>(_chrome);
      expect(
        (m.shape! as RoundedRectangleBorder).side.color,
        scheme.outlineVariant,
        reason: 'le jeton fond ne touche PAS à la bordure de la variante',
      );
      // Fond mesuré PEINT (pas la propriété) : couleur du bon rôle au centre.
      final Color painted =
          await _pixelAt(tester, tester.getCenter(_chrome));
      _expectPainted(painted, scheme.surfaceContainer, 'fond du jeton');
    });

    testWidgets('`outlined` + `border: none` + jeton fond : le retrait '
        'explicite PRIME sur la bordure de la variante', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerVariant: ZSubfolderTriggerVariant.outlined,
            subfolderTriggerBorder: ZSubfolderTriggerBorder.none,
            subfolderTriggerFill: ZSubfolderTriggerFill.surfaceContainerHighest,
          ),
        ),
      );
      final Material m = tester.widget<Material>(_chrome);
      expect((m.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(m.color, _scheme(tester).surfaceContainerHighest);
    });
  });

  // -------------------------------------------------------------------------
  // 4. ENCRE — ordre des couches + splash réellement peint (piège B-53)
  // -------------------------------------------------------------------------
  group('CR-IFFD-60 — l\'encre reste visible sur le fond choisi', () {
    testWidgets('le `Material` du chrome est l\'ANCÊTRE D\'ENCRE de '
        'l\'`InkWell`, et le splash y est réellement PEINT au-dessus du fond '
        'opaque', (tester) async {
      await setScreen(tester, 500, 800);
      // `splashFactory` DÉTERMINISTE (InkSplash peint un cercle observable —
      // l'InkSparkle M3 par défaut passe par un shader, non observable ici).
      // Le choix du splash appartient à l'hôte ; la COUCHE de peinture, au
      // socle : c'est elle qui est gardée.
      final Widget detail = ZStudyFolderDetail(
        title: 'Dossier',
        materialTabLabel: kMatTab,
        notebookTabLabel: kNoteTab,
        progressionTabLabel: kProgTab,
        materialSectionsBuilder: defaultSections,
        notebookBuilder: (_) => const SizedBox.shrink(),
        nav: navSpec(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: ZcrudScope(
            theme: const ZcrudTheme(
              // Fond OPAQUE : le cas qui avalait l'encre en B-53.
              subfolderTriggerVariant: ZSubfolderTriggerVariant.filled,
              subfolderTriggerBorder: ZSubfolderTriggerBorder.outlineVariant,
              subfolderTriggerElevation: 1,
            ),
            child: detail,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. ORDRE DES COUCHES : l'ancêtre d'encre de l'InkWell est le chrome —
      // pas le Material ambiant sous le fond (où l'encre serait invisible).
      final MaterialInkController ink = Material.of(
        tester.element(find.byKey(ZSubfolderSelectorBar.triggerKey)),
      );
      final RenderObject chromeRender = tester.renderObject(_chrome);
      RenderObject? node = ink as RenderObject;
      bool underChrome = false;
      while (node != null) {
        if (node == chromeRender) {
          underChrome = true;
          break;
        }
        node = node.parent;
      }
      expect(
        underChrome,
        isTrue,
        reason: 'l\'encre doit se peindre SUR le Material du chrome (donc '
            'au-dessus du fond), pas sur un Material ambiant situé dessous',
      );

      // 2. SPLASH RÉELLEMENT DESSINÉ sur cette couche.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ZSubfolderSelectorBar.triggerKey)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        ink as RenderObject,
        paints..circle(),
        reason: 'aucun cercle d\'encre peint : le splash est avalé',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  // -------------------------------------------------------------------------
  // 5. SOUS `aboveTabBar` — l'arbitrage tonal tient LÀ où il a été mesuré
  // -------------------------------------------------------------------------
  group('CR-IFFD-60 — élévation sous `aboveTabBar`', () {
    testWidgets('bord à bord au-dessus du TabBar (le terrain mesuré), '
        'élévation demandée ⇒ voile tonal PEINT, `Material.elevation` reste 0',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderTriggerFill: ZSubfolderTriggerFill.surfaceContainerHighest,
            subfolderTriggerBorder: ZSubfolderTriggerBorder.outlineVariant,
            subfolderTriggerElevation: 3,
          ),
        ),
      );

      // Le terrain de la mesure : déclencheur bord à bord au-dessus du TabBar.
      final Rect chromeRect = tester.getRect(_chrome);
      final Rect tabBarRect = tester.getRect(find.byType(TabBar));
      expect(tabBarRect.top - chromeRect.bottom, 0.0,
          reason: 'le terrain mesuré : toute ombre portée descendante se '
              'projetterait sur le TabBar');

      final Material m = tester.widget<Material>(_chrome);
      expect(m.elevation, 0,
          reason: 'JAMAIS d\'ombre portée ici — arbitrage mesuré (sonde '
              'CR-IFFD-60 : 796 pixels de la bande TabBar repeints par une '
              'BoxShadow blur 8 / offset (0,4), non rognée par PreferredSize)');

      // …et le relief demandé est bien RENDU (tonal), pas ignoré.
      final ColorScheme scheme = _scheme(tester);
      final Color painted =
          await _pixelAt(tester, tester.getCenter(_chrome));
      _expectPainted(
        painted,
        ElevationOverlay.applySurfaceTint(
          scheme.surfaceContainerHighest,
          scheme.surfaceTint,
          3,
        ),
        'voile tonal sous aboveTabBar',
      );
    });
  });
}
