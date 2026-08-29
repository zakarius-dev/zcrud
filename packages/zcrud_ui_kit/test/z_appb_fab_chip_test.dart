/// Bouton d'action flottant d'identité et style transversal des puces.
///
/// ## Table figée — relevé du chrome de référence
///
/// | Mesure | Valeur | Source |
/// |---|---|---|
/// | rayon du fond du bouton étendu | 20 | `lib/src/presentation/features/subjects/pages/subjects_page.dart:341` |
/// | ombre : opacité / flou / décalage | `0.4` / `20` / `(0, 8)` | `subjects_page.dart:348-353` |
/// | élévation du bouton sur son fond | `0` (repos **et** tap) | `subjects_page.dart:360-361` |
/// | taille du glyphe du bouton étendu | 22 | `subjects_page.dart:373` |
/// | graisse / interlettrage du libellé | `w600` / `0.3` | `subjects_page.dart:377-380` |
/// | dégradé du bouton | tête de palette (`667eea → 764ba2`) | `subjects_page.dart:344-346`, identique à `lib/src/presentation/features/administration/pages/accademic_years_page.dart:662-665` |
/// | rayon d'une puce de choix | 12 | `lib/src/presentation/features/documents/widgets/folder_document_pages_selection_dialog.dart:437-439` |
/// | coche de sélection | absente | `folder_document_pages_selection_dialog.dart:435` |
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

BoxDecoration? fabDecoration(WidgetTester tester) {
  final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
    find.ancestor(
      of: find.byType(FloatingActionButton),
      matching: find.byType(DecoratedBox),
    ),
  );
  for (final DecoratedBox b in boxes) {
    final Decoration d = b.decoration;
    if (d is BoxDecoration && d.gradient != null) return d;
  }
  return null;
}

FloatingActionButton fabOf(WidgetTester tester) =>
    tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

Widget host(Widget child, {ZcrudTheme? theme}) {
  final Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(floatingActionButton: child),
  );
  return theme == null ? app : ZcrudScope(theme: theme, child: app);
}

void main() {
  group('Apparence B — ZGradientFab', () {
    testWidgets(
      'sans clé, le bouton étendu porte la teinte de TÊTE de la palette et '
      'les métriques figées',
      (tester) async {
        await tester.pumpWidget(
          host(
            const ZGradientFab(
              onPressed: null,
              icon: Icons.add,
              label: 'Nouveau',
            ),
          ),
        );
        final BoxDecoration deco = fabDecoration(tester)!;
        expect(
          deco.gradient,
          ZSignaturePaletteReference.gradients.first.gradient,
          reason: 'le bouton doit porter la tête de palette, pas un index',
        );
        expect(deco.borderRadius, BorderRadius.circular(20));
        final BoxShadow ombre = deco.boxShadow!.single;
        expect(ombre.blurRadius, 20.0);
        expect(ombre.offset, const Offset(0, 8));
        expect(
          ombre.color.toARGB32(),
          ZSignaturePaletteReference.gradients.first.gradient.colors.first
              .withValues(alpha: 0.4)
              .toARGB32(),
          reason: 'l\'ombre reprend la teinte de base, pas du gris',
        );
        final FloatingActionButton fab = fabOf(tester);
        expect(fab.elevation, 0.0);
        expect(fab.highlightElevation, 0.0);
        expect(fab.backgroundColor, Colors.transparent);
        expect(
          fab.foregroundColor,
          ZSignaturePaletteReference.gradients.first.onGradient,
          reason: 'premier plan MESURÉ, jamais un blanc décrété',
        );
        expect(
          tester.widget<Icon>(find.byType(Icon)).size,
          22.0,
        );
        final Text libelle = tester.widget<Text>(find.text('Nouveau'));
        expect(libelle.style!.fontWeight, FontWeight.w600);
        expect(libelle.style!.letterSpacing, 0.3);
      },
    );

    testWidgets(
      'le premier plan du bouton est MESURÉ : sur une teinte claire il n\'est '
      'PAS blanc',
      (tester) async {
        // Ancrage délibéré sur un dégradé CLAIR. Sur la tête de palette
        // (violet sombre) la mesure rend du blanc, ce qui rendrait un blanc
        // décrété indiscernable d'un blanc mesuré — la garde ne mordrait pas.
        final ZGradientSpec clair = ZSignaturePaletteReference.gradients
            .firstWhere(
              (ZGradientSpec s) =>
                  s.onGradient.toARGB32() != 0xFFFFFFFF,
              orElse: () => throw StateError(
                'Aucun dégradé de référence ne rend un premier plan non '
                'blanc : la garde serait hors d\'atteinte.',
              ),
            );
        await tester.pumpWidget(
          host(
            const ZGradientFab(
              onPressed: null,
              icon: Icons.add,
              label: 'Nouveau',
            ),
            theme: ZcrudTheme(signaturePalette: <ZGradientSpec>[clair]),
          ),
        );
        expect(fabOf(tester).foregroundColor, clair.onGradient);
        expect(
          fabOf(tester).foregroundColor!.toARGB32(),
          isNot(0xFFFFFFFF),
          reason:
              'Un blanc décrété passerait ici — c\'est exactement ce que la '
              'garde doit refuser.',
        );
      },
    );

    testWidgets('sans label, le fond est CIRCULAIRE', (tester) async {
      await tester.pumpWidget(
        host(const ZGradientFab(onPressed: null, icon: Icons.add)),
      );
      expect(fabDecoration(tester)!.shape, BoxShape.circle);
      expect(fabOf(tester).shape, const CircleBorder());
    });

    testWidgets(
      'sous ZReferenceProfile.neutral : bouton Material NU — aucun conteneur, '
      'aucune ombre, aucune couleur posée',
      (tester) async {
        await tester.pumpWidget(
          host(
            const ZGradientFab(
              onPressed: null,
              icon: Icons.add,
              label: 'Nouveau',
            ),
            theme: const ZcrudTheme(
              referenceProfile: ZReferenceProfile.neutral,
            ),
          ),
        );
        expect(fabDecoration(tester), isNull);
        final FloatingActionButton fab = fabOf(tester);
        expect(fab.backgroundColor, isNull);
        expect(fab.foregroundColor, isNull);
        expect(fab.elevation, isNull);
        expect(
          tester.widget<Icon>(find.byType(Icon)).size,
          isNull,
          reason: 'même la taille du glyphe redevient celle du SDK',
        );
      },
    );

    testWidgets('gradientKey vide : bouton nu, MÊME sous legacy', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ZGradientFab(
            onPressed: null,
            icon: Icons.add,
            label: 'Nouveau',
            gradientKey: '',
          ),
        ),
      );
      expect(fabDecoration(tester), isNull);
    });

    testWidgets('signatureKey indexe la palette comme le chrome de page', (
      tester,
    ) async {
      const String identite = 'Section 3';
      await tester.pumpWidget(
        host(
          const ZGradientFab(
            onPressed: null,
            icon: Icons.add,
            signatureKey: identite,
          ),
        ),
      );
      expect(
        fabDecoration(tester)!.gradient,
        ZSignaturePaletteReference
            .gradients[zPaletteIndexFor(identite, 5)]
            .gradient,
      );
    });

    testWidgets('la cible tactile reste ≥ 48 dp (AD-13)', (tester) async {
      await tester.pumpWidget(
        host(
          const ZGradientFab(
            onPressed: null,
            icon: Icons.add,
            tooltip: 'Ajouter',
          ),
        ),
      );
      final Size taille = tester.getSize(find.byType(FloatingActionButton));
      expect(taille.width, greaterThanOrEqualTo(48));
      expect(taille.height, greaterThanOrEqualTo(48));
    });
  });

  group('Apparence B — ZChoiceChipStyle', () {
    Future<ZChoiceChipStyle> resolve(
      WidgetTester tester, {
      ZcrudTheme? theme,
      String? signatureKey,
    }) async {
      late ZChoiceChipStyle style;
      Widget app = MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            style = ZChoiceChipStyle.resolve(
              context,
              signatureKey: signatureKey,
            );
            return const SizedBox();
          },
        ),
      );
      if (theme != null) app = ZcrudScope(theme: theme, child: app);
      await tester.pumpWidget(app);
      return style;
    }

    testWidgets('legacy : rayon 12, pas de coche, teinte = tête de palette', (
      tester,
    ) async {
      final ZChoiceChipStyle style = await resolve(tester);
      expect(
        style.shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      expect(style.showCheckmark, isFalse);
      expect(
        style.selectedColor,
        ZSignaturePaletteReference.gradients.first.gradient.colors.first,
      );
    });

    testWidgets('neutral : la teinte de sélection devient ColorScheme.primary', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        ZcrudScope(
          theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                scheme = Theme.of(context).colorScheme;
                final ZChoiceChipStyle s = ZChoiceChipStyle.resolve(context);
                expect(s.selectedColor, scheme.primary);
                // La forme, elle, est un SCALAIRE : elle ne bouge pas.
                expect(
                  s.shape,
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(scheme.primary, isNotNull);
    });

    testWidgets('signatureKey indexe la palette', (tester) async {
      const String identite = 'Section 3';
      final ZChoiceChipStyle style = await resolve(
        tester,
        signatureKey: identite,
      );
      expect(
        style.selectedColor,
        ZSignaturePaletteReference
            .gradients[zPaletteIndexFor(identite, 5)]
            .gradient
            .colors
            .first,
      );
    });

    testWidgets('le jeton signaturePalette prime sur la référence', (
      tester,
    ) async {
      const Color teinte = Color(0xFF123456);
      final ZChoiceChipStyle style = await resolve(
        tester,
        theme: const ZcrudTheme(
          signaturePalette: <ZGradientSpec>[
            ZGradientSpec(
              gradient: LinearGradient(
                colors: <Color>[teinte, Color(0xFF654321)],
              ),
              onGradient: Color(0xFFFFFFFF),
            ),
          ],
        ),
      );
      expect(style.selectedColor, teinte);
    });

    testWidgets(
      'le libellé sélectionné tient 4.5:1 contre la teinte, pour les 5 '
      'entrées de la palette — recalculé',
      (tester) async {
        for (int i = 0; i < ZSignaturePaletteReference.gradients.length; i++) {
          final ZChoiceChipStyle style = await resolve(
            tester,
            theme: ZcrudTheme(
              signaturePalette: <ZGradientSpec>[
                ZSignaturePaletteReference.gradients[i],
              ],
            ),
          );
          expect(
            zContrastRatio(style.selectedLabelColor, style.selectedColor),
            greaterThanOrEqualTo(kZTextMinContrast),
            reason:
                'libellé illisible sur la teinte $i : '
                '${zContrastRatio(style.selectedLabelColor, style.selectedColor).toStringAsFixed(2)}',
          );
        }
      },
    );

    testWidgets(
      'le premier plan est réellement DÉPARTAGÉ : il bascule entre une teinte '
      'très sombre et une teinte très claire',
      (tester) async {
        Future<int> premierPlanPour(Color teinte) async {
          final ZChoiceChipStyle style = await resolve(
            tester,
            theme: ZcrudTheme(
              signaturePalette: <ZGradientSpec>[
                ZGradientSpec(
                  gradient: LinearGradient(colors: <Color>[teinte, teinte]),
                  onGradient: teinte,
                ),
              ],
            ),
          );
          return style.selectedLabelColor.toARGB32();
        }

        final int surSombre = await premierPlanPour(const Color(0xFF101010));
        final int surClair = await premierPlanPour(const Color(0xFFF5F5F5));
        expect(
          surSombre,
          isNot(surClair),
          reason:
              'Un premier plan constant ne serait pas mesuré, seulement '
              'décrété.',
        );
        expect(surSombre, const Color(0xFFFFFFFF).toARGB32());
        expect(surClair, const Color(0xFF000000).toARGB32());
      },
    );

    testWidgets(
      'sur les 5 teintes de référence, la mesure retient le NOIR — là où un '
      'blanc décrété tomberait sous le plancher',
      (tester) async {
        for (int i = 0; i < ZSignaturePaletteReference.gradients.length; i++) {
          final Color teinte = ZSignaturePaletteReference
              .gradients[i]
              .gradient
              .colors
              .first;
          final ZChoiceChipStyle style = await resolve(
            tester,
            theme: ZcrudTheme(
              signaturePalette: <ZGradientSpec>[
                ZSignaturePaletteReference.gradients[i],
              ],
            ),
          );
          expect(style.selectedLabelColor.toARGB32(), 0xFF000000);
          // Contre-preuve: le blanc, lui, ne tiendrait PAS le plancher.
          expect(
            zContrastRatio(const Color(0xFFFFFFFF), teinte),
            lessThan(kZTextMinContrast),
            reason:
                'Si le blanc tenait le plancher sur la teinte $i, préférer le '
                'noir ne prouverait rien.',
          );
        }
      },
    );

    testWidgets('zChipThemeFor projette les quatre créneaux, et eux seuls', (
      tester,
    ) async {
      late ChipThemeData data;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              data = zChipThemeFor(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(data.showCheckmark, isFalse);
      expect(
        data.shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      expect(
        data.selectedColor,
        ZSignaturePaletteReference.gradients.first.gradient.colors.first,
      );
      // Créneaux délibérément NON renseignés: ils restent au thème de l'hôte.
      expect(data.backgroundColor, isNull);
      expect(data.labelStyle, isNull);
      expect(data.side, isNull);
      expect(data.padding, isNull);
    });
  });
}
