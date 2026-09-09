/// Jetons de **chrome de page** : lavis d'app-bar, bouton d'action flottant,
/// puce de choix.
///
/// Ce que cette garde mesure : la **valeur peinte** au site de rendu, jamais le
/// passage du jeton. Chaque groupe porte donc (1) la valeur de référence quand
/// aucun jeton n'est posé — l'inertie —, (2) la valeur du jeton quand il l'est,
/// (3) le rejet d'une valeur invalide au profit de la référence (AD-10), et
/// (4) la primauté du PARAMÈTRE là où il en existe un.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Teinte d'identité posée par le thème : une palette POSÉE s'applique dans les
/// deux profils, donc le chrome est actif sans opt-in `legacy`.
const Color kBase = Color(0xFF335577);
const ZGradientSpec kSpec = ZGradientSpec(
  gradient: LinearGradient(colors: <Color>[kBase, Color(0xFF113355)]),
  onGradient: Color(0xFFFFFFFF),
);

Widget host(Widget child, ZcrudTheme theme) => ZcrudScope(
  theme: theme,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(floatingActionButton: child),
  ),
);

Widget page(Widget child, ZcrudTheme theme) => ZcrudScope(
  theme: theme,
  child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
);

FloatingActionButton fabOf(WidgetTester tester) =>
    tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

/// Décoration **montée** du fond dégradé du bouton — quel que soit son type.
Decoration? fabDeco(WidgetTester tester) {
  final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
    find.ancestor(
      of: find.byType(FloatingActionButton),
      matching: find.byType(DecoratedBox),
    ),
  );
  for (final DecoratedBox b in boxes) {
    final Decoration d = b.decoration;
    if (d is BoxDecoration && d.gradient != null) return d;
    if (d is ShapeDecoration && d.gradient != null) return d;
  }
  return null;
}

/// Rampe d'opacité réellement peinte par le lavis de l'app-bar montée.
List<double> washAlphas(WidgetTester tester) {
  final Iterable<Container> boxes = tester.widgetList<Container>(
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(Container),
    ),
  );
  for (final Container c in boxes) {
    final Decoration? d = c.decoration;
    if (d is BoxDecoration && d.gradient is LinearGradient) {
      return <double>[
        for (final Color col in (d.gradient! as LinearGradient).colors) col.a,
      ];
    }
  }
  fail('aucun lavis peint dans l\'app-bar montée');
}

double? washElevation(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar)).elevation;

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  group('Lavis d\'app-bar — appBarWashAlphas / appBarWashElevation', () {
    testWidgets('sans jeton : la rampe et l\'élévation de RÉFÉRENCE', (
      tester,
    ) async {
      await pumpAt(
        tester,
        page(
          const ZPageScaffold(title: 'Alpha'),
          const ZcrudTheme(signaturePalette: <ZGradientSpec>[kSpec]),
        ),
      );
      expect(washAlphas(tester), ZPageShellReference.appBarWashAlphas);
      expect(washElevation(tester), ZPageShellReference.appBarWashElevation);
    });

    testWidgets('jeton posé : la rampe PEINTE est celle du thème', (
      tester,
    ) async {
      await pumpAt(
        tester,
        page(
          const ZPageScaffold(title: 'Alpha'),
          const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[kSpec],
            appBarWashAlphas: <double>[0.5, 0.25],
            appBarWashElevation: 6,
          ),
        ),
      );
      final List<double> alphas = washAlphas(tester);
      expect(alphas, hasLength(2));
      expect(alphas[0], closeTo(0.5, 0.004));
      expect(alphas[1], closeTo(0.25, 0.004));
      expect(washElevation(tester), 6.0);
    });

    testWidgets(
      'la rampe posée sert AUSSI la mesure de contraste du premier plan',
      (tester) async {
        // Une rampe quasi opaque assombrit la bande de tête au point que le
        // premier plan ambiant ne tient plus 4.5:1 : le chrome doit alors
        // poser un premier plan mesuré. Avec la rampe de référence (15 %) il
        // n'en pose aucun.
        await pumpAt(
          tester,
          page(
            const ZPageScaffold(title: 'Alpha'),
            const ZcrudTheme(signaturePalette: <ZGradientSpec>[kSpec]),
          ),
        );
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).foregroundColor,
          isNull,
          reason: 'à 15 %, la barre garde son premier plan ambiant',
        );
        await pumpAt(
          tester,
          page(
            const ZPageScaffold(title: 'Alpha'),
            const ZcrudTheme(
              signaturePalette: <ZGradientSpec>[kSpec],
              appBarWashAlphas: <double>[1, 1],
            ),
          ),
        );
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).foregroundColor,
          isNotNull,
          reason: 'à 100 %, le premier plan ambiant ne tient plus le plancher '
              '— la mesure doit lire la rampe POSÉE, pas la référence',
        );
      },
    );

    testWidgets('AD-10 : rampe invalide ⇒ la RÉFÉRENCE, jamais une exception', (
      tester,
    ) async {
      for (final List<double> invalide in <List<double>>[
        <double>[],
        <double>[0.3],
        <double>[0.3, 1.4],
        <double>[-0.1, 0.2],
      ]) {
        await pumpAt(
          tester,
          page(
            const ZPageScaffold(title: 'Alpha'),
            ZcrudTheme(
              signaturePalette: const <ZGradientSpec>[kSpec],
              appBarWashAlphas: invalide,
            ),
          ),
        );
        expect(
          washAlphas(tester),
          ZPageShellReference.appBarWashAlphas,
          reason: 'rampe $invalide : le repli doit être la référence',
        );
      }
    });

    testWidgets('AD-10 : élévation négative ⇒ la RÉFÉRENCE', (tester) async {
      await pumpAt(
        tester,
        page(
          const ZPageScaffold(title: 'Alpha'),
          const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[kSpec],
            appBarWashElevation: -3,
          ),
        ),
      );
      expect(washElevation(tester), ZPageShellReference.appBarWashElevation);
    });

    testWidgets(
      'sans lavis, les deux jetons ne touchent RIEN (arbre inchangé)',
      (tester) async {
        await pumpAt(
          tester,
          page(
            const ZPageScaffold(title: 'Alpha'),
            const ZcrudTheme(
              appBarWashAlphas: <double>[0.9, 0.8],
              appBarWashElevation: 9,
            ),
          ),
        );
        final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
        expect(bar.flexibleSpace, isNull);
        expect(bar.elevation, isNull);
        expect(bar.foregroundColor, isNull);
      },
    );
  });

  group('Bouton d\'action flottant — fabShape/Elevation/IconSize/LabelStyle', () {
    const ZcrudTheme nu = ZcrudTheme(signaturePalette: <ZGradientSpec>[kSpec]);

    testWidgets('sans jeton : les métriques de RÉFÉRENCE, à l\'identique', (
      tester,
    ) async {
      await pumpAt(
        tester,
        host(
          const ZGradientFab(onPressed: null, icon: Icons.add, label: 'Neuf'),
          nu,
        ),
      );
      final FloatingActionButton fab = fabOf(tester);
      expect(fab.elevation, ZPageShellReference.fabElevation);
      expect(fab.highlightElevation, ZPageShellReference.fabElevation);
      expect(
        tester.widget<Icon>(find.byType(Icon)).size,
        ZPageShellReference.fabIconSize,
      );
      final TextStyle style = tester.widget<Text>(find.text('Neuf')).style!;
      expect(style.fontWeight, ZPageShellReference.fabLabelWeight);
      expect(style.letterSpacing, ZPageShellReference.fabLabelLetterSpacing);
      final Decoration deco = fabDeco(tester)!;
      expect(deco, isA<BoxDecoration>());
      expect(
        (deco as BoxDecoration).borderRadius,
        BorderRadius.circular(ZPageShellReference.fabCornerRadius),
      );
    });

    testWidgets('sans jeton, forme circulaire : décoration de RÉFÉRENCE', (
      tester,
    ) async {
      await pumpAt(
        tester,
        host(const ZGradientFab(onPressed: null, icon: Icons.add), nu),
      );
      expect((fabDeco(tester)! as BoxDecoration).shape, BoxShape.circle);
      expect(fabOf(tester).shape, const CircleBorder());
    });

    testWidgets('fabElevation posé : élévation PEINTE au repos ET au tap', (
      tester,
    ) async {
      await pumpAt(
        tester,
        host(
          const ZGradientFab(onPressed: null, icon: Icons.add, label: 'Neuf'),
          const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[kSpec],
            fabElevation: 7,
          ),
        ),
      );
      expect(fabOf(tester).elevation, 7.0);
      expect(fabOf(tester).highlightElevation, 7.0);
    });

    testWidgets('fabIconSize posé : taille du glyphe MONTÉ', (tester) async {
      await pumpAt(
        tester,
        host(
          const ZGradientFab(onPressed: null, icon: Icons.add, label: 'Neuf'),
          const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[kSpec],
            fabIconSize: 31,
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 31.0);
    });

    testWidgets(
      'AD-13 : même réduit à 1 dp, le glyphe ne rétrécit PAS la cible tactile',
      (tester) async {
        await pumpAt(
          tester,
          host(
            const ZGradientFab(
              onPressed: null,
              icon: Icons.add,
              tooltip: 'Ajouter',
            ),
            const ZcrudTheme(
              signaturePalette: <ZGradientSpec>[kSpec],
              fabIconSize: 1,
            ),
          ),
        );
        final Size taille = tester.getSize(find.byType(FloatingActionButton));
        expect(taille.width, greaterThanOrEqualTo(48));
        expect(taille.height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets('AD-10 : taille de glyphe non positive ⇒ la RÉFÉRENCE', (
      tester,
    ) async {
      for (final double invalide in <double>[0, -4]) {
        await pumpAt(
          tester,
          host(
            const ZGradientFab(onPressed: null, icon: Icons.add, label: 'Neuf'),
            ZcrudTheme(
              signaturePalette: const <ZGradientSpec>[kSpec],
              fabIconSize: invalide,
            ),
          ),
        );
        expect(
          tester.widget<Icon>(find.byType(Icon)).size,
          ZPageShellReference.fabIconSize,
        );
      }
    });

    testWidgets('AD-10 : élévation négative ⇒ la RÉFÉRENCE', (tester) async {
      await pumpAt(
        tester,
        host(
          const ZGradientFab(onPressed: null, icon: Icons.add, label: 'Neuf'),
          const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[kSpec],
            fabElevation: -2,
          ),
        ),
      );
      expect(fabOf(tester).elevation, ZPageShellReference.fabElevation);
    });

    testWidgets('fabLabelStyle posé : style PEINT du libellé', (tester) async {
      await pumpAt(
        tester,
        host(
          const ZGradientFab(onPressed: null, icon: Icons.add, label: 'Neuf'),
          const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[kSpec],
            fabLabelStyle: TextStyle(
              fontWeight: FontWeight.w300,
              letterSpacing: 2.5,
            ),
          ),
        ),
      );
      final TextStyle style = tester.widget<Text>(find.text('Neuf')).style!;
      expect(style.fontWeight, FontWeight.w300);
      expect(style.letterSpacing, 2.5);
    });

    testWidgets(
      'fabShape posé : la forme du BOUTON et celle de son FOND suivent',
      (tester) async {
        const OutlinedBorder forme = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        );
        for (final String? label in <String?>[null, 'Neuf']) {
          await pumpAt(
            tester,
            host(
              ZGradientFab(onPressed: null, icon: Icons.add, label: label),
              const ZcrudTheme(
                signaturePalette: <ZGradientSpec>[kSpec],
                fabShape: forme,
              ),
            ),
          );
          expect(fabOf(tester).shape, forme, reason: 'label=$label');
          final Decoration deco = fabDeco(tester)!;
          expect(
            deco,
            isA<ShapeDecoration>(),
            reason: 'le FOND doit suivre la forme, sinon un bouton carré '
                'garderait un halo rond (label=$label)',
          );
          expect((deco as ShapeDecoration).shape, forme);
          expect(deco.gradient, kSpec.gradient);
          expect(deco.shadows, hasLength(1));
        }
      },
    );
  });

  group('Puce de choix — choiceChipShape / choiceChipShowCheckmark', () {
    Future<ZChoiceChipStyle> resolve(
      WidgetTester tester,
      ZcrudTheme theme, {
      OutlinedBorder? shape,
      bool? showCheckmark,
    }) async {
      late ZChoiceChipStyle style;
      await tester.pumpWidget(
        ZcrudScope(
          theme: theme,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (BuildContext context) {
                style = ZChoiceChipStyle.resolve(
                  context,
                  shape: shape,
                  showCheckmark: showCheckmark,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return style;
    }

    testWidgets('sans jeton : forme et coche de RÉFÉRENCE', (tester) async {
      final ZChoiceChipStyle s = await resolve(tester, const ZcrudTheme());
      expect(
        s.shape,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ZPageShellReference.chipCornerRadius,
          ),
        ),
      );
      expect(s.showCheckmark, ZPageShellReference.chipShowCheckmark);
    });

    testWidgets('jetons posés : forme et coche du THÈME', (tester) async {
      const OutlinedBorder capsule = StadiumBorder();
      final ZChoiceChipStyle s = await resolve(
        tester,
        const ZcrudTheme(
          choiceChipShape: capsule,
          choiceChipShowCheckmark: true,
        ),
      );
      expect(s.shape, capsule);
      expect(s.showCheckmark, isTrue);
    });

    testWidgets('le PARAMÈTRE prime sur le jeton', (tester) async {
      const OutlinedBorder parJeton = StadiumBorder();
      const OutlinedBorder parParam = RoundedRectangleBorder();
      final ZChoiceChipStyle s = await resolve(
        tester,
        const ZcrudTheme(
          choiceChipShape: parJeton,
          choiceChipShowCheckmark: true,
        ),
        shape: parParam,
        showCheckmark: false,
      );
      expect(s.shape, parParam);
      expect(s.showCheckmark, isFalse);
    });

    testWidgets('la projection `zChipThemeFor` porte les jetons', (
      tester,
    ) async {
      late ChipThemeData data;
      await tester.pumpWidget(
        ZcrudScope(
          theme: const ZcrudTheme(
            choiceChipShape: StadiumBorder(),
            choiceChipShowCheckmark: true,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (BuildContext context) {
                data = zChipThemeFor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(data.shape, const StadiumBorder());
      expect(data.showCheckmark, isTrue);
    });

    testWidgets('la puce MONTÉE porte réellement la forme du jeton', (
      tester,
    ) async {
      await tester.pumpWidget(
        ZcrudScope(
          theme: const ZcrudTheme(choiceChipShape: StadiumBorder()),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ChipTheme(
                  data: zChipThemeFor(context),
                  child: ChoiceChip(
                    label: const Text('Actif'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final Iterable<Material> materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(ChoiceChip),
          matching: find.byType(Material),
        ),
      );
      expect(
        materials.any((Material m) => m.shape is StadiumBorder),
        isTrue,
        reason: 'la forme du jeton doit atteindre le Material de la puce',
      );
    });
  });
}
