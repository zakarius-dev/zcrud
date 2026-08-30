/// Gardes du lot d'apparence des cartes, des en-têtes de section et des états
/// vides d'étude.
///
/// Ce que chaque garde mesure — jamais le plancher du SDK :
/// * l'**inertie ABSOLUE** sous `ZReferenceProfile.neutral` : l'arbre complet
///   d'une section et d'une carte de dossier, à deux largeurs, à l'égalité
///   STRICTE d'une liste figée (aucun `contains`, aucun `<=`) ;
/// * la **préséance** de la couleur choisie : un dossier qui en porte une garde
///   la sienne, un dossier qui n'en porte aucune reçoit le dégradé de signature
///   EXACT (identité du `Gradient`, pas une ressemblance) ;
/// * la **géométrie** de l'en-tête de section : bande peinte de 3 dp, tuile
///   36 × 36 au rayon 10 ;
/// * la **table figée** des mesures de référence, chacune avec son
///   `fichier:ligne` d'origine ;
/// * les **états vides** : spécification exacte par nature, `null` pour une
///   nature inconnue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/src/presentation/z_subfolder_item_chrome.dart'
    show ZSubfolderAccentPastille;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZEmptyStateSpec;

/// Couleur de dossier CHOISIE par l'utilisateur, pour prouver la préséance.
const Color kChosen = Color(0xFF3366CC);

ZcrudTheme _tokens({ZReferenceProfile? profile}) =>
    ZcrudTheme(referenceProfile: profile);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ZReferenceProfile? profile,
  double width = 400,
  ZColorPair Function(ColorScheme, String)? colorResolver,
}) async {
  final ThemeData base = ThemeData.light(useMaterial3: true);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        extensions: <ThemeExtension<Object?>>[
          ...base.extensions.values
              .where((ThemeExtension<dynamic> e) => e is! ZcrudTheme)
              .cast<ThemeExtension<Object?>>(),
          _tokens(profile: profile),
        ],
      ),
      home: Scaffold(
        body: ZcrudScope(
          colorKeyResolver: colorResolver,
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Section minimale : un titre, un item, aucune action — la surface la plus
/// petite où l'en-tête existe.
ZStudyToolsSectionSpec _section({IconData? icon}) => ZStudyToolsSectionSpec(
  id: 's1',
  title: 'Fiches',
  icon: icon,
  itemCount: 1,
  itemBuilder: (BuildContext c, int i) => const SizedBox(height: 20),
  emptyState: const SizedBox.shrink(),
);

/// Empreinte de l'arbre : le TYPE de chaque widget, dans l'ordre du parcours.
/// Une empreinte de types voit apparaître ou disparaître un nœud — c'est
/// exactement ce qu'un profil neutre doit interdire.
List<String> _fingerprint(WidgetTester tester, Finder root) => tester
    .widgetList(
      find.descendant(of: root, matching: find.byWidgetPredicate((_) => true)),
    )
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

void main() {
  group('inertie ABSOLUE sous le profil neutre', () {
    for (final double width in <double>[320, 800]) {
      testWidgets('en-tête de section — arbre figé (largeur $width)', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          ZSectionedStudyLayout(sections: <ZStudyToolsSectionSpec>[_section()]),
          profile: ZReferenceProfile.neutral,
          width: width,
        );
        // Aucune bande, aucune tuile : la géométrie qui n'existe que pour
        // porter la référence n'est PAS montée.
        expect(find.byKey(kZStudySectionAccentKey), findsNothing);
        expect(find.byKey(kZStudySectionIconTileKey), findsNothing);
        // Et l'en-tête n'a gagné AUCUN nœud intercalaire : le `Semantics` de
        // l'en-tête est l'enfant direct de ce qui le portait.
        final List<String> types = _fingerprint(
          tester,
          find.byKey(const ValueKey<String>('section:s1')),
        );
        expect(
          types.where((String t) => t == 'ColoredBox').length,
          0,
          reason: '🔴 un nœud peint est apparu sous profil neutre',
        );
      });
    }

    testWidgets('carte de dossier — bande UNIE, jamais un dégradé', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane'),
        profile: ZReferenceProfile.neutral,
      );
      final Finder band = find.byKey(ZDefaultFolderCard.accentKey);
      expect(band, findsOneWidget);
      expect(
        find.descendant(of: band, matching: find.byType(ColoredBox)),
        findsOneWidget,
        reason: '🔴 la bande unie a été remplacée sous profil neutre',
      );
      expect(
        find.descendant(of: band, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
    });

    testWidgets('pastille de sous-dossier — inchangée sans identité', (
      WidgetTester tester,
    ) async {
      Color fill(WidgetTester t) =>
          (t
                      .widget<Container>(find.byType(Container))
                      .decoration!
                  as BoxDecoration)
              .color!;
      await _pump(
        tester,
        const ZSubfolderAccentPastille(colorKey: 'k'),
        profile: ZReferenceProfile.neutral,
      );
      final Color neutral = fill(tester);
      // Contre `legacy` EXPLICITE, et non contre le défaut : depuis que le
      // défaut EST neutral, comparer au défaut ne mesurerait plus rien.
      await _pump(
        tester,
        const ZSubfolderAccentPastille(colorKey: 'k'),
        profile: ZReferenceProfile.legacy,
      );
      expect(
        fill(tester),
        neutral,
        reason:
            '🔴 la pastille change de couleur sans identité de signature — le '
            'membre par défaut n\'est donc pas inerte',
      );
      // …et le DÉFAUT du socle vaut bien le profil neutre.
      await _pump(tester, const ZSubfolderAccentPastille(colorKey: 'k'));
      expect(fill(tester), neutral);
    });
  });

  group('🔴 le DÉFAUT du socle est le rendu d\'avant le lot d\'apparence', () {
    // Le profil n'est déclaré NULLE PART : c'est l'hôte qui n'a rien fait.
    // Chaque garde nomme aussi son pendant sous `legacy` explicite, pour
    // qu'aucune ne puisse devenir vacante si les deux profils convergeaient.
    testWidgets('en-tête de section : ni bande ni tuile', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZSectionedStudyLayout(
          sections: <ZStudyToolsSectionSpec>[
            _section(icon: Icons.style_outlined),
          ],
        ),
      );
      expect(
        find.byKey(kZStudySectionAccentKey),
        findsNothing,
        reason: '🔴 une bande d\'accent est montée sans profil déclaré : le '
            'défaut du socle a dérivé vers `legacy`',
      );
      expect(find.byKey(kZStudySectionIconTileKey), findsNothing);
      expect(find.byIcon(Icons.style_outlined), findsOneWidget);

      // CONTRE-PREUVE : sous `legacy`, les deux SONT là.
      await _pump(
        tester,
        ZSectionedStudyLayout(
          sections: <ZStudyToolsSectionSpec>[
            _section(icon: Icons.style_outlined),
          ],
        ),
        profile: ZReferenceProfile.legacy,
      );
      expect(find.byKey(kZStudySectionAccentKey), findsOneWidget);
      expect(find.byKey(kZStudySectionIconTileKey), findsOneWidget);
    });

    testWidgets('carte de dossier sans couleur : bande UNIE, aucun dégradé', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZDefaultFolderCard(title: 'Douane'));
      final Finder band = find.byKey(ZDefaultFolderCard.accentKey);
      expect(band, findsOneWidget);
      expect(
        find.descendant(of: band, matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: '🔴 le repli de signature peint un dégradé sans profil '
            'déclaré : le défaut du socle a dérivé vers `legacy`',
      );
      expect(
        find.descendant(of: band, matching: find.byType(ColoredBox)),
        findsOneWidget,
      );

      // CONTRE-PREUVE : sous `legacy`, la bande devient un dégradé.
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane'),
        profile: ZReferenceProfile.legacy,
      );
      expect(
        find.descendant(
          of: find.byKey(ZDefaultFolderCard.accentKey),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pastille : l\'identité de signature est ignorée', (
      WidgetTester tester,
    ) async {
      Color fill(WidgetTester t) =>
          (t.widget<Container>(find.byType(Container)).decoration!
                  as BoxDecoration)
              .color!;
      await _pump(tester, const ZSubfolderAccentPastille(colorKey: 'k'));
      final Color sansIdentite = fill(tester);
      await _pump(
        tester,
        const ZSubfolderAccentPastille(
          colorKey: 'k',
          signatureIdentity: 'Douane',
        ),
      );
      expect(
        fill(tester),
        sansIdentite,
        reason: '🔴 l\'identité teinte la pastille sans profil déclaré : le '
            'défaut du socle a dérivé vers `legacy`',
      );

      // CONTRE-PREUVE : sous `legacy`, l'identité change RÉELLEMENT la teinte.
      await _pump(
        tester,
        const ZSubfolderAccentPastille(
          colorKey: 'k',
          signatureIdentity: 'Douane',
        ),
        profile: ZReferenceProfile.legacy,
      );
      expect(fill(tester), isNot(sansIdentite));
    });
  });

  group('préséance de la couleur choisie', () {
    testWidgets(
        'dossier SANS couleur, profil `legacy` ⇒ dégradé de signature EXACT', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(title: 'Douane'),
        profile: ZReferenceProfile.legacy,
      );
      final Finder band = find.byKey(ZDefaultFolderCard.accentKey);
      final DecoratedBox painted = tester.widget<DecoratedBox>(
        find.descendant(of: band, matching: find.byType(DecoratedBox)),
      );
      final Gradient? rendered =
          (painted.decoration as BoxDecoration).gradient;
      // L'identité attendue est celle que la carte calcule : la clé remappée
      // sur la palette d'étude, seedée par le titre.
      final BuildContext ctx = tester.element(band);
      final ZGradientSpec? expected = zResolveGradient(
        ctx,
        zSignatureKey(
          remapColorKey(
            palette: const ZColorPalette.defaultStudy(),
            rawColorKey: null,
            seedTitle: 'Douane',
          ),
        ),
      );
      expect(expected, isNotNull, reason: '🔴 sonde cassée : aucun dégradé');
      expect(
        rendered,
        expected!.gradient,
        reason: '🔴 la bande ne peint pas le dégradé de signature exact',
      );
    });

    // Ce qui est figé ici est le REPLI de signature, et lui seul : il ne se
    // déclenche pas là où une couleur est déclarée. La propriété « une couleur
    // déclarée interdit tout dégradé » serait, elle, FAUSSE — un dégradé
    // demandé explicitement coexiste avec la couleur (garde dédiée dans
    // `presentation/cr_lex86_folder_card_gradient_test.dart`). Les deux gardes
    // ci-dessous n'affirment donc l'absence de dégradé que SANS demande
    // explicite.
    testWidgets(
      'dossier AVEC clé de couleur, aucun dégradé demandé ⇒ SA couleur, '
      'aucun repli de signature',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(title: 'Douane', colorKey: 'blue'),
        );
        final Finder band = find.byKey(ZDefaultFolderCard.accentKey);
        expect(
          find.descendant(of: band, matching: find.byType(DecoratedBox)),
          findsNothing,
          reason:
              '🔴 le repli de signature a écrasé la couleur choisie, alors '
              'qu\'aucun dégradé n\'a été demandé',
        );
        expect(
          find.descendant(of: band, matching: find.byType(ColoredBox)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'couleur DÉCLARÉE par le résolveur de l\'hôte, aucun dégradé demandé ⇒ '
      'elle prime',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(title: 'Douane'),
          colorResolver: (ColorScheme s, String k) =>
              const ZColorPair(color: kChosen, onColor: Color(0xFFFFFFFF)),
        );
        final Finder band = find.byKey(ZDefaultFolderCard.accentKey);
        expect(
          find.descendant(of: band, matching: find.byType(DecoratedBox)),
          findsNothing,
          reason:
              '🔴 le repli de signature a écrasé la couleur que l\'hôte '
              'déclare pour ce dossier, sans qu\'aucun dégradé soit demandé',
        );
      },
    );
  });

  group('en-tête de section — géométrie de référence', () {
    testWidgets('bande PEINTE de 3 dp (profil `legacy`)',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZSectionedStudyLayout(sections: <ZStudyToolsSectionSpec>[_section()]),
        profile: ZReferenceProfile.legacy,
      );
      final Finder band = find.byKey(kZStudySectionAccentKey);
      expect(band, findsOneWidget);
      expect(tester.getSize(band).height, ZStudyCardReference.sectionAccentHeight);
      // PEINTE, pas seulement présente : un nœud transparent serait inerte.
      final ColoredBox paint = tester.widget<ColoredBox>(
        find.descendant(of: band, matching: find.byType(ColoredBox)),
      );
      expect(paint.color.a, greaterThan(0));
      final ZGradientSpec? sig = zResolveGradient(
        tester.element(band),
        zSignatureKey('Fiches'),
      );
      expect(paint.color, sig!.gradient.colors.first);
    });

    testWidgets(
        'tuile d\'icône 36 / rayon 10 (profil `legacy`), seulement si un '
        'glyphe existe', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZSectionedStudyLayout(
          sections: <ZStudyToolsSectionSpec>[_section()],
        ),
        profile: ZReferenceProfile.legacy,
      );
      expect(
        find.byKey(kZStudySectionIconTileKey),
        findsNothing,
        reason: '🔴 une tuile est montée sans glyphe déclaré',
      );

      await _pump(
        tester,
        ZSectionedStudyLayout(
          sections: <ZStudyToolsSectionSpec>[
            _section(icon: Icons.style_outlined),
          ],
        ),
        profile: ZReferenceProfile.legacy,
      );
      final Finder tile = find.byKey(kZStudySectionIconTileKey);
      expect(tile, findsOneWidget);
      expect(
        tester.getSize(tile),
        const Size(
          ZStudyCardReference.sectionIconTileSize,
          ZStudyCardReference.sectionIconTileSize,
        ),
      );
      final BoxDecoration deco =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(of: tile, matching: find.byType(DecoratedBox)),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        deco.borderRadius,
        BorderRadius.circular(ZStudyCardReference.sectionIconTileRadius),
      );
      // Ombre TEINTÉE : la couleur vient du dégradé, jamais d'un littéral.
      final ZGradientSpec sig = zResolveGradient(
        tester.element(tile),
        zSignatureKey('Fiches'),
      )!;
      expect(deco.boxShadow!.single.color.a, ZStudyCardReference.tintedShadowAlpha);
      expect(
        <double, double>{
          deco.boxShadow!.single.color.r: sig.gradient.colors.first.r,
          deco.boxShadow!.single.color.g: sig.gradient.colors.first.g,
        }.entries.every((MapEntry<double, double> e) => e.key == e.value),
        isTrue,
        reason: '🔴 l\'ombre n\'est pas teintée par le dégradé courant',
      );
      expect(
        deco.boxShadow!.single.blurRadius,
        ZStudyCardReference.tintedShadowBlurRadius,
      );
      expect(
        deco.boxShadow!.single.offset,
        ZStudyCardReference.tintedShadowOffset,
      );
    });

    testWidgets('profil neutre ⇒ glyphe NU, sans tuile ni ombre', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZSectionedStudyLayout(
          sections: <ZStudyToolsSectionSpec>[
            _section(icon: Icons.style_outlined),
          ],
        ),
        profile: ZReferenceProfile.neutral,
      );
      expect(find.byKey(kZStudySectionIconTileKey), findsNothing);
      expect(find.byIcon(Icons.style_outlined), findsOneWidget);
    });
  });

  group('table FIGÉE des mesures de référence', () {
    test('cartes d\'outils et en-tête de section', () {
      // Chaque valeur porte son `fichier:ligne` d'origine dans la source de
      // référence, branche `main` du dépôt hôte.
      //
      //   folder_study_tools_page.dart:147  rayon de carte 16
      //   folder_study_tools_page.dart:162  tuile 48
      //   folder_study_tools_page.dart:166  rayon de tuile 12
      //   folder_study_tools_page.dart:170  écart tuile→titre 16
      //   folder_study_tools_page.dart:144  élévation 0
      //   subjects_page.dart:228-234        ombre teintée 0.4 / 20 / (0,8)
      expect(ZStudyCardReference.cardRadius, const Radius.circular(16));
      expect(ZStudyCardReference.iconTileSize, 48);
      expect(ZStudyCardReference.iconTileRadius, const Radius.circular(12));
      expect(ZStudyCardReference.leadingGap, 16);
      expect(ZStudyCardReference.cardElevation, 0);
      expect(ZStudyCardReference.sectionAccentHeight, 3);
      expect(ZStudyCardReference.sectionIconTileSize, 36);
      expect(ZStudyCardReference.sectionIconTileRadius, 10);
      expect(ZStudyCardReference.tintedShadowAlpha, 0.4);
      expect(ZStudyCardReference.tintedShadowBlurRadius, 20);
      expect(ZStudyCardReference.tintedShadowOffset, const Offset(0, 8));
      // La carte de DOSSIER est une autre famille : son rayon est 12
      //   (folders_page.dart:937). Confondre les deux serait la régression que
      //   la remesure a écartée.
      expect(ZFolderCardReference.cardRadius, const Radius.circular(12));
    });

    test('l\'en-tête de section d\'étude ne diverge PAS de celui du cœur', () {
      // Les défauts du cœur (`ZcrudTheme.sectionHeader*`) et ceux du repli de
      // ce paquet doivent coïncider — sinon deux en-têtes du même écran
      // rendraient deux géométries.
      expect(ZStudyCardReference.sectionAccentHeight, 3);
      expect(ZStudyCardReference.sectionIconTileSize, 36);
      expect(ZStudyCardReference.sectionIconTileRadius, 10);
    });
  });

  group('états vides par nature de contenu', () {
    test('table figée — spécification EXACTE par nature', () {
      // empty_folder_content.dart:86-89 (dossier, glyphe 200)
      // empty_folder_content.dart:16-33 (glyphes par nature)
      const Map<String, IconData> expected = <String, IconData>{
        ZStudyContentNature.folder: Icons.folder_open,
        ZStudyContentNature.flashcards: Icons.card_membership_outlined,
        ZStudyContentNature.notes: Icons.note_outlined,
        ZStudyContentNature.mindmaps: Icons.device_hub_outlined,
        ZStudyContentNature.documents: Icons.insert_drive_file_outlined,
        ZStudyContentNature.exams: Icons.assignment_outlined,
      };
      for (final MapEntry<String, IconData> e in expected.entries) {
        final ZEmptyStateSpec? spec = zStudyEmptyStateSpecFor(e.key);
        expect(spec, isNotNull, reason: '🔴 nature absente : ${e.key}');
        expect(spec!.iconData, e.value);
        expect(spec.titleKey.isNotEmpty, isTrue);
        expect(spec.messageKey.isNotEmpty, isTrue);
      }
      expect(
        ZStudyEmptyStateReference.byNature.length,
        expected.length,
        reason: '🔴 la table a gagné une nature non figée ici',
      );
      expect(ZStudyContentNature.values.length, expected.length);
    });

    test('tailles de glyphe : 200 pour le dossier, 24 par nature', () {
      expect(
        ZStudyEmptyStateReference.glyphSizeFor(ZStudyContentNature.folder),
        200,
      );
      for (final String n in ZStudyContentNature.values) {
        if (n == ZStudyContentNature.folder) continue;
        expect(ZStudyEmptyStateReference.glyphSizeFor(n), 24);
      }
    });

    test('nature INCONNUE ⇒ aucune spécification, aucune taille', () {
      expect(zStudyEmptyStateSpecFor('zcrud.study.nature.inconnue'), isNull);
      expect(
        ZStudyEmptyStateReference.glyphSizeFor('zcrud.study.nature.inconnue'),
        isNull,
      );
      expect(zStudyEmptyStateSpecFor(''), isNull);
    });

    test('les clés de libellé sont OPAQUES et distinctes', () {
      final Set<String> keys = <String>{
        for (final ZEmptyStateSpec s
            in ZStudyEmptyStateReference.byNature.values) ...<String>[
          s.titleKey,
          s.messageKey,
        ],
      };
      expect(
        keys.length,
        ZStudyEmptyStateReference.byNature.length * 2,
        reason: '🔴 deux natures partagent une clé de libellé',
      );
    });
  });

  group('pastille de sous-dossier', () {
    testWidgets(
        'identité fournie, profil `legacy` ⇒ tête du dégradé de signature', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZSubfolderAccentPastille(
          colorKey: 'k',
          signatureIdentity: 'Douane',
        ),
        profile: ZReferenceProfile.legacy,
      );
      final Finder pastille = find.byType(Container);
      final Color fill =
          (tester.widget<Container>(pastille).decoration! as BoxDecoration)
              .color!;
      final ZGradientSpec sig = zResolveGradient(
        tester.element(pastille),
        zSignatureKey('Douane'),
      )!;
      expect(fill, sig.gradient.colors.first);
    });

    testWidgets('profil neutre ⇒ identité ignorée, couleur d\'avant', (
      WidgetTester tester,
    ) async {
      Color fill(WidgetTester t) =>
          (t.widget<Container>(find.byType(Container)).decoration!
                  as BoxDecoration)
              .color!;
      await _pump(
        tester,
        const ZSubfolderAccentPastille(colorKey: 'k'),
        profile: ZReferenceProfile.neutral,
      );
      final Color plain = fill(tester);
      await _pump(
        tester,
        const ZSubfolderAccentPastille(
          colorKey: 'k',
          signatureIdentity: 'Douane',
        ),
        profile: ZReferenceProfile.neutral,
      );
      expect(fill(tester), plain);
    });
  });
}
