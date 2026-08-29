/// Chrome d'identité de l'app-bar sous le profil `legacy`, opt-in de l'hôte.
///
/// Le profil est déclaré explicitement par chaque montage de ce fichier
/// ([kLegacy]) : sans lui, le socle rend son défaut neutre, mesuré par
/// `z_appb_page_chrome_inertia_test.dart`.
///
/// Ce que cette garde établit :
/// * la teinte peinte est **exactement** le premier arrêt du dégradé de
///   palette signature indexé par l'identité — recalculé ici, jamais relu
///   depuis le code testé ;
/// * la rampe d'opacité est **exactement** celle relevée dans le chrome de
///   référence, et sa table est figée en littéral dans ce fichier ;
/// * le premier plan de la barre tient le plancher WCAG 2.2 §1.4.3 AA (4.5:1)
///   contre la bande la plus dense du lavis, **recalculé** pour les cinq
///   dégradés en thème clair et en thème sombre ;
/// * l'ordre de priorité **clé explicite > clé de signature > titre** est
///   respecté, et un seam d'hôte l'emporte partout.
///
/// ## Table figée — relevé du chrome de référence
///
/// | Mesure | Valeur | Source |
/// |---|---|---|
/// | rampe d'opacité du lavis | `0.15 / 0.10 / 0.05 / 0.02` | `lib/src/presentation/core/widgets/dynamic_searcheable_app_bar.dart:216-219` |
/// | orientation du lavis | `topCenter → bottomCenter` | `dynamic_searcheable_app_bar.dart:213-214` |
/// | élévation sous lavis | `0` | `dynamic_searcheable_app_bar.dart:205` |
/// | fond de la barre sous lavis | transparent (le lavis compose sur la surface) | `dynamic_searcheable_app_bar.dart:206-208` |
/// | couleur du titre sous lavis | héritée (`titleLarge`, aucune couleur posée) | `dynamic_searcheable_app_bar.dart:254-256` |
/// | palette signature (5 teintes de base) | voir `_basesL1` | `lib/src/utils/functions/forms_utils.dart:57-63` |
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Rampe d'opacité relevée à la main dans le chrome de référence
/// (`dynamic_searcheable_app_bar.dart:216-219`). Figée ici : jamais relue
/// depuis `ZPageShellReference`, sinon la garde suivrait la dérive au lieu de
/// la signaler.
const List<double> kRampe = <double>[0.15, 0.10, 0.05, 0.02];

/// Les cinq teintes de base de la palette signature, relevées à la main dans
/// `forms_utils.dart:57-63` (premier arrêt de chaque dégradé).
const List<int> _basesL1 = <int>[
  0xFF667EEA,
  0xFF11998E,
  0xFFF093FB,
  0xFF4FACFE,
  0xFFFA709A,
];

LinearGradient? gradientOf(WidgetTester tester) {
  final Iterable<Container> containers = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(AppBar).first,
          matching: find.byType(Container),
        ),
      )
      .where((Container c) {
        final Decoration? d = c.decoration;
        return d is BoxDecoration && d.gradient is LinearGradient;
      });
  if (containers.isEmpty) return null;
  return (containers.first.decoration! as BoxDecoration).gradient!
      as LinearGradient;
}

AppBar appBarOf(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar).first);

/// Thème CRUD posant l'opt-in d'habillage de référence. Ce fichier mesure le
/// rendu *sous* ce profil : il doit donc le déclarer, comme le fera l'hôte.
const ZcrudTheme kLegacy = ZcrudTheme(
  referenceProfile: ZReferenceProfile.legacy,
);

/// [scope] à `false` ne monte AUCUN `ZcrudScope` : réservé aux cas où
/// l'appelant en pose déjà un au-dessus (un scope interne masquerait le seam
/// de l'hôte, `maybeOf` ne remontant qu'au plus proche).
Widget host(
  Widget child, {
  Brightness brightness = Brightness.light,
  ZcrudTheme? theme = kLegacy,
  bool scope = true,
}) {
  final Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness),
    home: child,
  );
  return (!scope || theme == null)
      ? app
      : ZcrudScope(theme: theme, child: app);
}

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  /// Une identité par index de palette, calculée et non devinée.
  Map<int, String> identitiesPerIndex(int length) {
    final Map<int, String> out = <int, String>{};
    for (int i = 0; out.length < length && i < 4000; i++) {
      final String candidate = 'Section $i';
      out.putIfAbsent(zPaletteIndexFor(candidate, length), () => candidate);
    }
    return out;
  }

  group('Apparence B — lavis d\'identité de l\'app-bar (profil legacy)', () {
    test('la palette de référence porte bien les 5 teintes de base figées', () {
      final List<int> lues = ZSignaturePaletteReference.gradients
          .map((ZGradientSpec s) => s.gradient.colors.first.toARGB32())
          .toList();
      expect(
        lues,
        _basesL1,
        reason:
            'La palette signature a DÉRIVÉ du relevé de référence '
            '(forms_utils.dart:57-63).',
      );
    });

    testWidgets(
      'les 4 arrêts du lavis valent EXACTEMENT la teinte de base indexée, '
      'déclinée sur la rampe figée — pour les 5 index',
      (tester) async {
        final Map<int, String> identites = identitiesPerIndex(5);
        expect(identites.length, 5);
        for (final MapEntry<int, String> e in identites.entries) {
          await pumpAt(tester, host(ZPageScaffold(title: e.value)));
          final LinearGradient? g = gradientOf(tester);
          expect(g, isNotNull, reason: 'aucun lavis pour « ${e.value} »');
          final Color base =
              ZSignaturePaletteReference.gradients[e.key].gradient.colors.first;
          expect(
            g!.colors.map((Color c) => c.toARGB32()).toList(),
            <int>[
              for (final double a in kRampe)
                base.withValues(alpha: a).toARGB32(),
            ],
            reason:
                'lavis erroné pour « ${e.value} » (index attendu ${e.key})',
          );
        }
      },
    );

    testWidgets('le lavis est VERTICAL, donc identique en RTL', (tester) async {
      await pumpAt(tester, host(const ZPageScaffold(title: 'Alpha')));
      final LinearGradient ltr = gradientOf(tester)!;
      expect(ltr.begin, Alignment.topCenter);
      expect(ltr.end, Alignment.bottomCenter);
      await pumpAt(
        tester,
        host(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: ZPageScaffold(title: 'Alpha'),
          ),
        ),
      );
      expect(gradientOf(tester)!.colors, ltr.colors);
      expect(gradientOf(tester)!.begin, ltr.begin);
    });

    testWidgets('l\'élévation de la barre passe à 0 sous le lavis', (
      tester,
    ) async {
      await pumpAt(tester, host(const ZPageScaffold(title: 'Alpha')));
      expect(appBarOf(tester).elevation, 0.0);
    });

    testWidgets(
      'le premier plan tient 4.5:1 contre la bande la plus dense du lavis '
      '— 5 dégradés × 2 luminosités, recalculé',
      (tester) async {
        final Map<int, String> identites = identitiesPerIndex(5);
        for (final Brightness b in Brightness.values) {
          for (final String identite in identites.values) {
            await pumpAt(
              tester,
              host(ZPageScaffold(title: identite), brightness: b),
            );
            final BuildContext ctx = tester.element(find.byType(AppBar).first);
            final ThemeData theme = Theme.of(ctx);
            final LinearGradient g = gradientOf(tester)!;
            final Color surface =
                AppBarTheme.of(ctx).backgroundColor ??
                theme.colorScheme.surface;
            final Color bande = Color.alphaBlend(g.colors.first, surface);
            final Color premierPlan =
                appBarOf(tester).foregroundColor ??
                AppBarTheme.of(ctx).foregroundColor ??
                theme.colorScheme.onSurface;
            expect(
              zContrastRatio(premierPlan, bande),
              greaterThanOrEqualTo(kZTextMinContrast),
              reason:
                  'contraste insuffisant sur « $identite » ($b) : '
                  '${zContrastRatio(premierPlan, bande).toStringAsFixed(2)}',
            );
          }
        }
      },
    );

    testWidgets(
      'CONTRE-PREUVE de non-vacuité : le lavis change RÉELLEMENT la bande '
      '(elle diffère de la surface nue)',
      (tester) async {
        await pumpAt(tester, host(const ZPageScaffold(title: 'Alpha')));
        final BuildContext ctx = tester.element(find.byType(AppBar).first);
        final Color surface = Theme.of(ctx).colorScheme.surface;
        final Color bande = Color.alphaBlend(
          gradientOf(tester)!.colors.first,
          surface,
        );
        expect(bande.toARGB32(), isNot(surface.toARGB32()));
      },
    );

    testWidgets('le mode sliver porte le MÊME lavis que le mode fixe', (
      tester,
    ) async {
      await pumpAt(tester, host(const ZPageScaffold(title: 'Alpha')));
      final LinearGradient fixe = gradientOf(tester)!;
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(
            title: 'Alpha',
            mode: ZPageAppBarMode.floatingPinned,
            body: SizedBox(height: 2000),
          ),
        ),
      );
      expect(gradientOf(tester)!.colors, fixe.colors);
    });
  });

  group('Apparence B — ordre de priorité du chrome', () {
    const ZGradientSpec hote = ZGradientSpec(
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF010203), Color(0xFF040506)],
      ),
      onGradient: Color(0xFFFEFDFC),
    );

    testWidgets(
      'gradientKey EXPLICITE prime sur la clé dérivée du titre : dégradé du '
      'seam à saturation pleine, onGradient posé, élévation NON touchée',
      (tester) async {
        await pumpAt(
          tester,
          host(
            const ZPageScaffold(title: 'Alpha', gradientKey: 'dossier-42'),
            theme: const ZcrudTheme(),
          ),
        );
        // Sans resolver hôte, la clé libre `dossier-42` ne résout RIEN : le
        // titre ne reprend PAS la main pour autant.
        expect(gradientOf(tester), isNull);
        expect(appBarOf(tester).elevation, isNull);

        await pumpAt(
          tester,
          ZcrudScope(
            theme: kLegacy,
            gradientResolver: (ColorScheme s, String k) =>
                k == 'dossier-42' ? hote : null,
            child: host(
              const ZPageScaffold(title: 'Alpha', gradientKey: 'dossier-42'),
              scope: false,
            ),
          ),
        );
        expect(gradientOf(tester)!.colors, hote.gradient.colors);
        expect(appBarOf(tester).foregroundColor, hote.onGradient);
        expect(
          appBarOf(tester).elevation,
          isNull,
          reason:
              'Le chemin historique (clé explicite) ne doit pas gagner une '
              'élévation qu\'il n\'avait pas.',
        );
      },
    );

    testWidgets('signatureKey prime sur le titre', (tester) async {
      const String identite = 'Section 3';
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(title: 'Alpha', signatureKey: identite),
        ),
      );
      final Color attendue = ZSignaturePaletteReference
          .gradients[zPaletteIndexFor(identite, 5)]
          .gradient
          .colors
          .first;
      expect(
        gradientOf(tester)!.colors.first.toARGB32(),
        attendue.withValues(alpha: kRampe.first).toARGB32(),
      );
    });

    testWidgets(
      'le seam de l\'hôte prime sur la référence pour la clé DÉRIVÉE — mais '
      'le RENDU reste le lavis (la priorité choisit la teinte, pas la façon '
      'de la peindre)',
      (tester) async {
        await pumpAt(
          tester,
          ZcrudScope(
            theme: kLegacy,
            gradientResolver: (ColorScheme s, String k) =>
                k == zSignatureKey('Alpha') ? hote : null,
            child: host(
              const ZPageScaffold(title: 'Alpha'),
              scope: false,
            ),
          ),
        );
        final LinearGradient g = gradientOf(tester)!;
        expect(
          g.colors.map((Color c) => c.toARGB32()).toList(),
          <int>[
            for (final double a in kRampe)
              hote.gradient.colors.first.withValues(alpha: a).toARGB32(),
          ],
          reason:
              'La teinte doit venir du seam, la rampe du lavis rester celle '
              'du chemin dérivé.',
        );
        // La référence n'a PAS servi : contre-preuve explicite.
        expect(
          g.colors.first.toARGB32(),
          isNot(
            ZSignaturePaletteReference
                .gradients[zPaletteIndexFor('Alpha', 5)]
                .gradient
                .colors
                .first
                .withValues(alpha: kRampe.first)
                .toARGB32(),
          ),
        );
      },
    );

    testWidgets('le jeton signaturePalette prime sur la référence', (
      tester,
    ) async {
      const ZGradientSpec unique = ZGradientSpec(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0A0B0C), Color(0xFF0D0E0F)],
        ),
        onGradient: Color(0xFFFFFFFF),
      );
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(title: 'Alpha'),
          theme: const ZcrudTheme(
            signaturePalette: <ZGradientSpec>[unique],
          ),
        ),
      );
      expect(
        gradientOf(tester)!.colors.first.toARGB32(),
        const Color(0xFF0A0B0C).withValues(alpha: kRampe.first).toARGB32(),
      );
    });

    testWidgets(
      'jeton signaturePalette VIDE : aucune teinte, même sous legacy',
      (tester) async {
        await pumpAt(
          tester,
          host(
            const ZPageScaffold(title: 'Alpha'),
            theme: const ZcrudTheme(signaturePalette: <ZGradientSpec>[]),
          ),
        );
        expect(gradientOf(tester), isNull);
      },
    );
  });
}
