/// **CR-IFFD-64** — gardes de `ZDefaultFolderCard`, la sixième carte par
/// défaut de la famille, et des seams neufs de `ZFolderCard`.
///
/// Chaque garde mesure une propriété du LOT, jamais le plancher du SDK :
/// * le contraste est mesuré **end-to-end sur la couleur RÉELLEMENT PEINTE**
///   (bande, liseré, tuile, badge), sur une couleur d'entrée qui **échoue**
///   sans correction (`#FFFF00`) — une garde montée sur une couleur déjà
///   conforme serait verte pour rien ;
/// * les quatre « non mesuré » de la CR sont **mesurés** ici : cumul teinte ×
///   archivé, liseré vs `tintAlpha`, grille étroite (< 160 dp), culling ;
/// * l'hôte **passif** de `ZFolderCard` est verrouillé : même forme, même
///   padding, aucune ombre — le nouveau rendu est strictement opt-in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Couleur de dossier DURE : sans correction, `#FFFF00` mesure 2.13:1 sur
/// thème clair une fois passé par la fenêtre HSL — c'est le cas qui fait
/// exister ce lot.
const Color kHardYellow = Color(0xFFFFFF00);

ZColorPair _fixed(Color c) => ZColorPair(color: c, onColor: const Color(0xFF000000));

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Color folderColor = kHardYellow,
  Brightness brightness = Brightness.light,
  TextDirection dir = TextDirection.ltr,
  double width = 220,
  double? height = 190,
  ZcrudTheme? tokens,
}) async {
  Widget framed = height == null
      ? SingleChildScrollView(child: SizedBox(width: width, child: card))
      : SizedBox(width: width, height: height, child: card);
  framed = ZcrudScope(
    colorKeyResolver: (ColorScheme scheme, String key) => _fixed(folderColor),
    child: framed,
  );
  final ThemeData base = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: tokens == null
          ? base
          : base.copyWith(
              extensions: <ThemeExtension<Object?>>[
                ...base.extensions.values
                    .where((ThemeExtension<dynamic> e) => e is! ZcrudTheme)
                    .cast<ThemeExtension<Object?>>(),
                tokens,
              ],
            ),
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: Center(child: framed)),
      ),
    ),
  );
}

/// La forme réellement posée sur le `Card` rendu.
ShapeBorder? _shape(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card)).shape;

BorderSide _side(WidgetTester tester) =>
    (_shape(tester)! as RoundedRectangleBorder).side;

Color _bandColor(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find.descendant(
        of: find.byKey(ZDefaultFolderCard.accentKey),
        matching: find.byType(ColoredBox),
      ),
    )
    .color;

/// La surface RÉELLEMENT peinte sous les accents : la couleur du `Card`, ou —
/// quand la carte laisse le `CardTheme` décider (carte NEUTRE) — le défaut
/// Material 3 réellement peint. Mesurer contre une couleur nominale absente
/// donnerait un contraste fantôme.
Color _cardSurface(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card)).color ??
    Theme.of(tester.element(find.byType(Card))).colorScheme.surfaceContainerLow;

BoxDecoration _tileDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byKey(ZDefaultFolderCard.iconTileKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  group('🔴 CR-IFFD-64 ① — le rendu de RÉFÉRENCE, sans aucun réglage', () {
    testWidgets('bande 4 dp + liseré 1 dp + tuile 36/8 + glyphe 20', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));

      expect(
        tester.getSize(find.byKey(ZDefaultFolderCard.accentKey)).height,
        ZFolderCardReference.accentBandHeight,
      );
      expect(_side(tester).width, ZFolderCardReference.borderWidth);
      expect(
        (_shape(tester)! as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(ZFolderCardReference.cardRadius),
      );
      expect(
        tester.getSize(find.byKey(ZDefaultFolderCard.iconTileKey)),
        const Size(
          ZFolderCardReference.iconTileSize,
          ZFolderCardReference.iconTileSize,
        ),
      );
      expect(
        _tileDecoration(tester).borderRadius,
        const BorderRadius.all(ZFolderCardReference.iconTileRadius),
      );
      final Icon glyph = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ZDefaultFolderCard.iconTileKey),
          matching: find.byType(Icon),
        ),
      );
      expect(glyph.icon, ZFolderCardReference.glyph);
      expect(glyph.size, ZFolderCardReference.glyphSize);
    });

    testWidgets('padding interne = 12 (la RÉFÉRENCE), jamais `gapM`', (
      WidgetTester tester,
    ) async {
      // `gapM` du thème nu vaut 8 : sans le slot `contentPadding`, la carte
      // par défaut rendrait 8. C'est exactement la leçon CR-IFFD-61 ①.
      await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
      final Iterable<Padding> paddings = tester.widgetList<Padding>(
        find.descendant(
          of: find.byType(ZFolderCard),
          matching: find.byType(Padding),
        ),
      );
      expect(
        paddings.any(
          (Padding p) => p.padding == ZFolderCardReference.contentPadding,
        ),
        isTrue,
        reason:
            '🔴 le padding de référence (12) n\'est pas posé — la carte par '
            'défaut retombe sur `gapM`.',
      );
      expect(ZcrudTheme.of(tester.element(find.byType(Card))).gapM, isNot(12));
    });

    testWidgets('ombre douce de référence posée, élévation native éteinte', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(ZFolderCard),
          matching: find.byType(DecoratedBox),
        ),
      );
      final Iterable<BoxShadow> shadows = boxes
          .map((DecoratedBox b) => b.decoration)
          .whereType<BoxDecoration>()
          .expand((BoxDecoration d) => d.boxShadow ?? const <BoxShadow>[]);
      expect(shadows, isNotEmpty, reason: '🔴 aucune ombre de référence');
      expect(shadows.first.blurRadius, ZFolderCardReference.shadowBlurRadius);
      expect(shadows.first.offset, ZFolderCardReference.shadowOffset);
      expect(tester.widget<Card>(find.byType(Card)).elevation, 0);
    });
  });

  group(
    '🔴 CR-IFFD-64 ② — le CONTRASTE, mesuré sur la couleur RÉELLEMENT peinte',
    () {
      for (final Brightness brightness in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'couleur DURE #FFFF00 — bande, liseré et glyphe ≥ 3.0:1 '
          '(${brightness.name})',
          (WidgetTester tester) async {
            await _pump(
              tester,
              const ZDefaultFolderCard(title: 'Douane'),
              brightness: brightness,
            );
            final Color surface = _cardSurface(tester);
            // La preuve que la garde n'est pas VACANTE : sur thème CLAIR, la
            // couleur brute ÉCHOUE sur cette même surface (en sombre, un jaune
            // vif passe déjà — c'est précisément pourquoi le défaut ne se
            // voyait pas : il est ASYMÉTRIQUE entre les deux luminosités).
            if (brightness == Brightness.light) {
              expect(
                zContrastRatio(kHardYellow, surface),
                lessThan(ZFolderCardReference.minContrast),
                reason: '🔴 sonde cassée : la couleur dure passe déjà brute',
              );
            }
            expect(
              zContrastRatio(_bandColor(tester), surface),
              greaterThanOrEqualTo(ZFolderCardReference.minContrast),
              reason: '🔴 bande d\'accent illisible',
            );
            expect(
              zContrastRatio(_side(tester).color, surface),
              greaterThanOrEqualTo(ZFolderCardReference.minContrast),
              reason: '🔴 liseré illisible',
            );
            // Le glyphe se mesure contre la TUILE (déjà teintée), pas contre
            // la carte : mesurer contre la carte surestimerait le contraste.
            final Color tile = _tileDecoration(tester).color!;
            final Icon glyph = tester.widget<Icon>(
              find.descendant(
                of: find.byKey(ZDefaultFolderCard.iconTileKey),
                matching: find.byType(Icon),
              ),
            );
            expect(
              zContrastRatio(glyph.color!, tile),
              greaterThanOrEqualTo(ZFolderCardReference.minContrast),
              reason: '🔴 glyphe illisible sur sa tuile',
            );
          },
        );
      }

      testWidgets(
        'libellé de badge et sous-titre ≥ 4.5:1 (plancher du TEXTE)',
        (WidgetTester tester) async {
          await _pump(
            tester,
            const ZDefaultFolderCard(
              title: 'Douane',
              subtitle: 'Valeur en douane',
              counts: <ZFolderCardCount>[
                ZFolderCardCount(icon: Icons.style_outlined, label: '12'),
              ],
            ),
            height: 220,
          );
          final Color surface = _cardSurface(tester);
          final Text subtitle = tester.widget<Text>(
            find.byKey(ZDefaultFolderCard.subtitleKey),
          );
          expect(
            zContrastRatio(subtitle.style!.color!, surface),
            greaterThanOrEqualTo(ZFolderCardReference.textMinContrast),
            reason: '🔴 sous-titre sous le plancher AA du texte normal',
          );

          final BoxDecoration badge =
              tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byKey(ZDefaultFolderCard.countsKey),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration;
          final Text label = tester.widget<Text>(
            find.descendant(
              of: find.byKey(ZDefaultFolderCard.countsKey),
              matching: find.text('12'),
            ),
          );
          expect(
            zContrastRatio(label.style!.color!, badge.color!),
            greaterThanOrEqualTo(ZFolderCardReference.textMinContrast),
            reason: '🔴 libellé de badge sous le plancher AA',
          );
          expect(
            badge.borderRadius,
            const BorderRadius.all(ZFolderCardReference.badgeRadius),
          );
        },
      );

      testWidgets(
        '🔴 « non mesuré » n°2 — le liseré est mesuré contre le fond TEINTÉ, '
        'pas contre la surface nue',
        (WidgetTester tester) async {
          // 🔴 Le cas qui DISCRIMINE : une couleur de dossier SOMBRE, teintée à
          // 90 %, rend la carte presque noire. Mesurée contre la surface
          // NOMINALE (claire), cette couleur passe déjà largement le plancher —
          // elle serait donc rendue INCHANGÉE… et invisible sur la carte
          // réellement peinte. Seule la mesure contre la COMPOSITION la
          // corrige. (Une couleur claire ne discrimine pas : sa correction
          // convient aux deux surfaces — garde vacante, mesuré en R3.)
          await _pump(
            tester,
            const ZDefaultFolderCard(title: 'Douane', tintAlpha: 0.9),
            folderColor: const Color(0xFF1A1A2E),
          );
          final Color painted = _cardSurface(tester);
          final Color nominal = Theme.of(
            tester.element(find.byType(Card)),
          ).colorScheme.surfaceContainerLow;
          expect(
            painted,
            isNot(nominal),
            reason: '🔴 sonde cassée : la carte n\'est pas teintée',
          );
          expect(
            zContrastRatio(_side(tester).color, painted),
            greaterThanOrEqualTo(ZFolderCardReference.minContrast),
            reason:
                '🔴 le liseré disparaît dans un fond déjà teinté — c\'est '
                'exactement le cumul que la CR signalait sans le mesurer.',
          );
          expect(
            zContrastRatio(_bandColor(tester), painted),
            greaterThanOrEqualTo(ZFolderCardReference.minContrast),
          );
        },
      );

      testWidgets(
        '🔴 « non mesuré » n°1 — état ARCHIVÉ : aucun cumul d\'atténuations',
        (WidgetTester tester) async {
          // Mesuré côté legacy : IFFD n'a AUCUN rendu d'archivage (recherche
          // négative). Côté socle, l'archivage ajoute un BADGE TEXTUEL et rien
          // d'autre. Cette garde le prouve : teinte et liseré strictement
          // identiques, donc contraste identique — il n'y a rien à cumuler.
          await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
          final Color bandPlain = _bandColor(tester);
          final Color sidePlain = _side(tester).color;
          final Color surfacePlain = _cardSurface(tester);

          await _pump(
            tester,
            const ZDefaultFolderCard(
              title: 'Douane',
              isArchived: true,
              archivedLabel: 'Archivé',
            ),
          );
          expect(_bandColor(tester), bandPlain);
          expect(_side(tester).color, sidePlain);
          expect(_cardSurface(tester), surfacePlain);
          expect(find.text('Archivé'), findsOneWidget);
          expect(
            zContrastRatio(_side(tester).color, _cardSurface(tester)),
            greaterThanOrEqualTo(ZFolderCardReference.minContrast),
          );
        },
      );
    },
  );

  group('🔴 CR-IFFD-64 ③ — priorité paramètre > jeton > référence', () {
    testWidgets('le paramètre `borderSide` PRIME tout', (
      WidgetTester tester,
    ) async {
      const BorderSide mine = BorderSide(color: Color(0xFF123456), width: 3);
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane', borderSide: mine),
        tokens: const ZcrudTheme(
          folderCardBorderSide: BorderSide(color: Color(0xFF00FF00), width: 7),
        ),
      );
      expect(_side(tester), mine);
    });

    testWidgets('le jeton PRIME la référence (liseré, rayon, bande)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane'),
        tokens: const ZcrudTheme(
          folderCardBorderSide: BorderSide(color: Color(0xFF00FF00), width: 7),
          folderCardRadius: Radius.circular(3),
          folderCardAccentHeight: 9,
          folderCardIconTileSize: 44,
        ),
      );
      expect(_side(tester).width, 7);
      expect(
        (_shape(tester)! as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(3)),
      );
      expect(
        tester.getSize(find.byKey(ZDefaultFolderCard.accentKey)).height,
        9,
      );
      expect(
        tester.getSize(find.byKey(ZDefaultFolderCard.iconTileKey)).width,
        44,
      );
    });

    testWidgets('sans jeton ni paramètre, la RÉFÉRENCE s\'applique', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
      expect(_side(tester).width, ZFolderCardReference.borderWidth);
      expect(
        tester.getSize(find.byKey(ZDefaultFolderCard.accentKey)).height,
        ZFolderCardReference.accentBandHeight,
      );
    });
  });

  group('🔴 CR-IFFD-64 ④ — AD-4 : `null` ⇒ ABSENT de l\'arbre', () {
    testWidgets('sous-titre, badges et pied absents par défaut', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
      expect(find.byKey(ZDefaultFolderCard.subtitleKey), findsNothing);
      expect(find.byKey(ZDefaultFolderCard.countsKey), findsNothing);
    });

    testWidgets('une hauteur de bande ≤ 0 SUPPRIME la bande', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane', accentHeight: 0),
      );
      expect(
        find.byKey(ZDefaultFolderCard.accentKey),
        findsNothing,
        reason: '🔴 bande de hauteur nulle laissée dans l\'arbre (nœud inerte)',
      );
    });

    testWidgets('un accent INJECTÉ remplace la bande de référence', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          accent: SizedBox(key: ValueKey<String>('mine'), height: 6),
        ),
      );
      expect(find.byKey(const ValueKey<String>('mine')), findsOneWidget);
      expect(find.byKey(ZDefaultFolderCard.accentKey), findsNothing);
    });

    testWidgets(
      'AD-10 — une clé de couleur INCONNUE ne fait pas échouer le rendu',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: const Scaffold(
              body: SizedBox(
                width: 220,
                height: 190,
                // AUCUN resolver injecté : la clé est inconnue de bout en bout.
                child: ZDefaultFolderCard(
                  title: 'Douane',
                  colorKey: 'clé-parfaitement-inconnue',
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Douane'), findsOneWidget);
        expect(find.byKey(ZDefaultFolderCard.accentKey), findsOneWidget);
      },
    );
  });

  group('🔴 CR-IFFD-64 ⑤ — a11y, RTL, grille étroite, coût de peinture', () {
    testWidgets(
      'AD-13 — l\'information ne passe JAMAIS par la seule couleur',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Douane',
            subtitle: 'Valeur',
            isArchived: true,
            archivedLabel: 'Archivé',
            counts: <ZFolderCardCount>[
              ZFolderCardCount(icon: Icons.style_outlined, label: '12 fiches'),
            ],
            onTap: _noop,
          ),
          height: 240,
        );
        // Chaque canal coloré a son doublon TEXTUEL.
        expect(find.text('Douane'), findsOneWidget);
        expect(find.text('Valeur'), findsOneWidget);
        expect(find.text('Archivé'), findsOneWidget);
        expect(find.text('12 fiches'), findsOneWidget);
        // …et la tuile colorée porte un GLYPHE, pas seulement une couleur.
        expect(
          find.descendant(
            of: find.byKey(ZDefaultFolderCard.iconTileKey),
            matching: find.byType(Icon),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('cible d\'activation ≥ 48 dp, une SEULE annonce de bouton', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane', onTap: _noop),
        height: null,
      );
      expect(
        tester.getSize(find.byType(ZFolderCard)).height,
        greaterThanOrEqualTo(48),
      );
      final Iterable<Semantics> buttons = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((Semantics s) => s.properties.button ?? false);
      expect(buttons.length, 1);
      expect(buttons.single.properties.label, 'Douane');
      handle.dispose();
    });

    testWidgets('un badge est ANNONCÉ exactement une fois', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          counts: <ZFolderCardCount>[
            ZFolderCardCount(
              icon: Icons.style_outlined,
              label: '12',
              semanticLabel: '12 fiches',
            ),
          ],
        ),
        height: 220,
      );
      expect(
        find.bySemanticsLabel('12 fiches'),
        findsOneWidget,
        reason: '🔴 badge muet ou annoncé deux fois',
      );
      handle.dispose();
    });

    testWidgets('RTL — rendu sans exception, extrémités inversées', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          menu: Icon(Icons.more_horiz, key: ValueKey<String>('menu')),
        ),
        dir: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      final double tileX = tester
          .getTopLeft(find.byKey(ZDefaultFolderCard.iconTileKey))
          .dx;
      final double menuX = tester
          .getTopLeft(find.byKey(const ValueKey<String>('menu')))
          .dx;
      expect(
        tileX,
        greaterThan(menuX),
        reason: '🔴 RTL : la tuile de tête doit passer à DROITE du menu',
      );
    });

    testWidgets(
      '🔴 « non mesuré » n°3 — grille ÉTROITE (< 160 dp) : aucun débordement',
      (WidgetTester tester) async {
        // ⚠️ Métrique de mesure : la police de test rend CHAQUE glyphe carré
        // au corps courant — un texte y est ~1.8× plus large qu'avec une
        // police réelle. Les largeurs ci-dessous sont donc un PIRE CAS.
        for (final double width in <double>[120, 130, 140, 158]) {
          await _pump(
            tester,
            const ZDefaultFolderCard(
              title: 'Un titre de dossier délibérément très long',
              subtitle: 'Une matière au nom lui aussi très long',
              counts: <ZFolderCardCount>[
                ZFolderCardCount(
                  icon: Icons.style_outlined,
                  label: '128 fiches',
                ),
                ZFolderCardCount(
                  icon: Icons.folder_outlined,
                  label: '12 sous-dossiers',
                ),
              ],
              footer: Text('Créé par Zakarius'),
            ),
            width: width,
            height: 210,
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                '🔴 débordement à $width dp de large : le sous-titre doit '
                's\'ellipser, les badges défiler, le titre se borner.',
          );
        }
      },
    );

    testWidgets(
      '🔴 « non mesuré » n°3 bis — le badge ARCHIVÉ est INFLEXIBLE dans le '
      'pied de la PRIMITIVE : seuil mesuré, pas affirmé',
      (WidgetTester tester) async {
        // Mécanisme MESURÉ : `ZFolderCard` compose son pied en
        // `[Expanded(counts) | Spacer, gapS, badge]` — le badge n'est ni
        // `Flexible` ni ellipsé, donc en dessous d'une certaine largeur il
        // déborde. C'est une propriété PRÉEXISTANTE de la primitive (mesurée
        // à ~117 dp avec `gapM` = 8) que le padding de RÉFÉRENCE (12) déplace
        // à ~125 dp. Aucune des deux n'est atteignable dans une grille
        // plausible : cette garde verrouille le seuil à 130 dp, police de
        // test (pire cas ~1.8×), soit ≈ 72 dp en métrique réelle.
        for (final double width in <double>[130, 160, 200]) {
          await _pump(
            tester,
            const ZDefaultFolderCard(
              title: 'Un titre de dossier délibérément très long',
              isArchived: true,
              archivedLabel: 'Archivé',
            ),
            width: width,
            height: 210,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '🔴 le badge archivé déborde encore à $width dp',
          );
        }
      },
    );

    testWidgets(
      '🔴 « non mesuré » n°4 — coût de peinture : UNE forme, UNE ombre, '
      'et la liste reste virtualisée',
      (WidgetTester tester) async {
        // ⚠️ Portée DÉCLARÉE : les deux premières assertions mesurent une
        // propriété de CETTE carte (elle ne double ni la forme ni l'ombre —
        // une régression y est injectable et rougit). La troisième mesure le
        // culling de `ListView.builder`, donc une propriété du SDK : elle est
        // là comme CONTEXTE (« le liseré ne coûte pas 2000 peintures »), pas
        // comme garde de notre code.
        await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
        expect(
          find.descendant(
            of: find.byType(ZDefaultFolderCard),
            matching: find.byType(Card),
          ),
          findsOneWidget,
          reason: '🔴 deux `Card` empilés = deux formes et deux liserés peints',
        );
        final Iterable<BoxShadow> shadows = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(ZDefaultFolderCard),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((DecoratedBox b) => b.decoration)
            .whereType<BoxDecoration>()
            .expand((BoxDecoration d) => d.boxShadow ?? const <BoxShadow>[]);
        expect(
          shadows.length,
          1,
          reason: '🔴 ${shadows.length} ombres peintes par carte, pas une',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: ZcrudScope(
                colorKeyResolver: (ColorScheme sc, String k) =>
                    _fixed(kHardYellow),
                child: ListView.builder(
                  itemCount: 2000,
                  itemExtent: 190,
                  itemBuilder: (BuildContext c, int i) =>
                      ZDefaultFolderCard(title: 'Dossier $i'),
                ),
              ),
            ),
          ),
        );
        final int built = tester
            .widgetList(find.byType(ZDefaultFolderCard))
            .length;
        expect(
          built,
          lessThan(20),
          reason:
              '🔴 $built cartes construites sur 2000 : la liste n\'est plus '
              'virtualisée (le liseré n\'a donc PAS un coût de 2000 peintures).',
        );
        expect(built, greaterThan(0));
      },
    );
  });

  group(
    '🔴 CR-IFFD-64 ⑥ — l\'hôte PASSIF de `ZFolderCard` rend le MÊME pixel',
    () {
      testWidgets(
        'aucun liseré, aucune ombre, rayon `radiusM`, padding `gapM`',
        (WidgetTester tester) async {
          await _pump(
            tester,
            const ZFolderCard(title: 'Douane', colorKey: 'a'),
          );
          final RoundedRectangleBorder shape =
              _shape(tester)! as RoundedRectangleBorder;
          final ZcrudTheme theme = ZcrudTheme.of(
            tester.element(find.byType(Card)),
          );
          expect(
            shape.side,
            BorderSide.none,
            reason: '🔴 un liseré est apparu sur un hôte PASSIF',
          );
          expect(shape.borderRadius, BorderRadius.all(theme.radiusM));
          expect(
            tester.widget<Card>(find.byType(Card)).elevation,
            isNull,
            reason: '🔴 l\'élévation native a été éteinte sans jeton',
          );
          final Iterable<Padding> paddings = tester.widgetList<Padding>(
            find.descendant(
              of: find.byType(ZFolderCard),
              matching: find.byType(Padding),
            ),
          );
          expect(
            paddings.any(
              (Padding p) => p.padding == EdgeInsetsDirectional.all(theme.gapM),
            ),
            isTrue,
          );
        },
      );

      testWidgets(
        'CR-LEX-61/73 — `CardTheme.shape` de l\'hôte PRIME encore',
        (WidgetTester tester) async {
          const RoundedRectangleBorder hostShape = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(21)),
            side: BorderSide(color: Color(0xFF00FF00), width: 5),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true).copyWith(
                cardTheme: const CardThemeData(shape: hostShape),
              ),
              home: const Scaffold(
                body: SizedBox(
                  width: 220,
                  height: 190,
                  child: ZFolderCard(title: 'Douane', colorKey: 'a'),
                ),
              ),
            ),
          );
          expect(_shape(tester), hostShape);
        },
      );

      testWidgets(
        '…mais un slot EXPLICITE prime le `CardTheme` (patron CR-IFFD-19)',
        (WidgetTester tester) async {
          const BorderSide mine = BorderSide(color: Color(0xFF123456), width: 2);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(useMaterial3: true).copyWith(
                cardTheme: const CardThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(21)),
                  ),
                ),
              ),
              home: const Scaffold(
                body: SizedBox(
                  width: 220,
                  height: 190,
                  child: ZFolderCard(
                    title: 'Douane',
                    colorKey: 'a',
                    borderSide: mine,
                  ),
                ),
              ),
            ),
          );
          expect(_side(tester), mine);
        },
      );
    },
  );
}

void _noop() {}
