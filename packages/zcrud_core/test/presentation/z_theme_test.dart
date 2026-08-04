// AC5/AC6 : `ZcrudTheme` (ThemeExtension) résolu via scope > extension >
// fallback dérivé ; copyWith/lerp ; repli dérivé de ColorScheme (light≠dark).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZcrudTheme _custom() => const ZcrudTheme(
  fieldBorderColor: Color(0xFF112233),
  errorColor: Color(0xFF445566),
  labelColor: Color(0xFF778899),
  surfaceColor: Color(0xFFAABBCC),
);

void main() {
  test('fallback DÉRIVE tout du ColorScheme (light ≠ dark, AC5/AC6)', () {
    final light = ZcrudTheme.fallback(ThemeData.light());
    final dark = ZcrudTheme.fallback(ThemeData.dark());
    // Dérivation prouvée : les couleurs changent avec le ColorScheme.
    expect(light.surfaceColor, ThemeData.light().colorScheme.surface);
    expect(dark.surfaceColor, ThemeData.dark().colorScheme.surface);
    expect(light.surfaceColor, isNot(dark.surfaceColor));
    expect(light.errorColor, ThemeData.light().colorScheme.error);
    expect(light.fieldBorderColor, ThemeData.light().colorScheme.outline);
    expect(light.fieldBorderColor, isNot(dark.fieldBorderColor));
  });

  test('copyWith : identité + surcharge ciblée (AC5)', () {
    final base = _custom();
    expect(base.copyWith().fieldBorderColor, base.fieldBorderColor);
    expect(base.copyWith().gapM, base.gapM);
    expect(base.copyWith().badgeRadius, base.badgeRadius);
    final changed = base.copyWith(
      gapM: 42,
      errorColor: const Color(0xFF000001),
    );
    expect(changed.gapM, 42);
    expect(changed.errorColor, const Color(0xFF000001));
    expect(changed.fieldBorderColor, base.fieldBorderColor);
  });

  test('lerp(a,b,0) == a sur tokens clés ; lerp(a,b,1) == b (AC5)', () {
    final a = _custom();
    final b = a.copyWith(gapM: 100, surfaceColor: const Color(0xFF010101));
    final at0 = a.lerp(b, 0);
    final at1 = a.lerp(b, 1);
    expect(at0.gapM, a.gapM);
    expect(at0.surfaceColor, a.surfaceColor);
    expect(at1.gapM, b.gapM);
    expect(at1.surfaceColor, b.surfaceColor);
    expect(a.lerp(null, 0.5).gapM, a.gapM); // other non ZcrudTheme → this
  });

  test('G1/G2/G3 : tokens VIS opt-in, héritage lerp et extrêmes', () {
    const base = ZcrudTheme();
    final changed = base.copyWith(
      accentBarHeight: 6,
      gradientBegin: AlignmentDirectional.topStart,
      gradientEnd: AlignmentDirectional.bottomEnd,
      cardShadowBlurRadius: 12,
      cardShadowOffset: const Offset(1, 2),
      cardShadowAlpha: .3,
      cardTintAlpha: .2,
      iconContainerSize: 48,
      iconContainerRadius: const Radius.circular(9),
      countPillPadding: const EdgeInsetsDirectional.all(5),
      countPillRadius: const Radius.circular(7),
      countPillIconSize: 18,
      celebrationDuration: const Duration(milliseconds: 300),
      celebrationCurve: Curves.easeIn,
      flipDuration: const Duration(milliseconds: 180),
      flipCurve: Curves.easeOut,
    );
    expect(base.accentBarHeight, isNull);
    expect(base.gradientBegin, isNull);
    expect(base.cardShadowOffset, isNull);
    expect(base.countPillPadding, isNull);
    expect(base.celebrationCurve, isNull);
    expect(base.copyWith().flipDuration, isNull);
    final inherited = base.lerp(const ZcrudTheme(gapM: 10), .5);
    expect(inherited.iconContainerRadius, isNull);
    expect(inherited.accentBarHeight, isNull);
    expect(inherited.gradientBegin, isNull);
    expect(inherited.gradientEnd, isNull);
    expect(inherited.cardShadowBlurRadius, isNull);
    expect(inherited.cardShadowOffset, isNull);
    expect(inherited.cardShadowAlpha, isNull);
    expect(inherited.cardTintAlpha, isNull);
    expect(inherited.iconContainerSize, isNull);
    expect(inherited.countPillPadding, isNull);
    expect(inherited.countPillRadius, isNull);
    expect(inherited.countPillIconSize, isNull);
    expect(inherited.celebrationDuration, isNull);
    expect(inherited.celebrationCurve, isNull);
    expect(inherited.flipDuration, isNull);
    expect(inherited.flipCurve, isNull);
    // Une DIMENSION absente peut légitimement partir de zéro : une barre
    // d'accent qui « grandit depuis rien » est un rendu plausible.
    expect(base.lerp(changed, 0).accentBarHeight, isZero);
    expect(base.lerp(changed, 1).accentBarHeight, changed.accentBarHeight);

    // 🔴 GARDE MAJEUR-1 (CR epic VIS) — une DURÉE, elle, ne doit JAMAIS être
    // matérialisée à zéro. `Duration.zero` n'est pas une absence : c'est une
    // valeur INVALIDE (animation dégénérée ; `ConfettiController` lève sur une
    // durée non strictement positive). MESURÉ avant correction : `t=0.0`
    // rendait `0:00:00.000000`, si bien qu'un thème animé vers un préréglage
    // traversait un instant où toute célébration construite plantait.
    // Un côté `null` signifie « le consommateur applique SON défaut » — valeur
    // que le thème ignore : on rend donc l'autre côté, seul réellement connu.
    for (final double t in <double>[0.0, 0.25, 0.5, 1.0]) {
      expect(
        base.lerp(changed, t).celebrationDuration,
        changed.celebrationDuration,
        reason: 'durée nulle d\'un côté ⇒ jamais zéro, jamais interpolée (t=$t)',
      );
      expect(base.lerp(changed, t).flipDuration, changed.flipDuration);
      expect(
        changed.lerp(base, t).celebrationDuration,
        changed.celebrationDuration,
        reason: 'symétrique : l\'absence côté cible ne doit pas non plus valoir 0',
      );
    }
    // `null` des deux côtés reste `null` (héritage préservé).
    expect(
      base.lerp(const ZcrudTheme(), .5).celebrationDuration,
      isNull,
    );
    expect(base.lerp(changed, 1).gradientEnd, changed.gradientEnd);
    expect(base.lerp(changed, 1).countPillPadding, changed.countPillPadding);
    expect(base.lerp(changed, 1).flipCurve, changed.flipCurve);
  });

  testWidgets('of() : scope.theme l\'emporte (AC5-a)', (tester) async {
    final custom = _custom();
    late ZcrudTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: ZcrudScope(
          theme: custom,
          child: Builder(
            builder: (context) {
              resolved = ZcrudTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(identical(resolved, custom), isTrue);
  });

  testWidgets('of() : sans scope-theme → ThemeData.extension (AC5-b)', (
    tester,
  ) async {
    final ext = _custom();
    late ZcrudTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[ext]),
        home: ZcrudScope(
          child: Builder(
            builder: (context) {
              resolved = ZcrudTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(identical(resolved, ext), isTrue);
  });

  testWidgets('of() : ni scope ni extension → fallback dérivé (AC5-c)', (
    tester,
  ) async {
    late ZcrudTheme resolved;
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ZcrudScope(
          child: Builder(
            builder: (context) {
              theme = Theme.of(context);
              resolved = ZcrudTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolved.surfaceColor, theme.colorScheme.surface);
    expect(resolved.errorColor, theme.colorScheme.error);
  });

  // ---------------------------------------------------------------------------
  // CR-IFFD-41 — tokens de LOOK de la navigation de fratrie
  // ---------------------------------------------------------------------------
  group('CR-IFFD-41 — tokens nullables : absence ⇒ rendu inchangé', () {
    test('les quatre tokens sont `null` par DÉFAUT', () {
      const ZcrudTheme t = ZcrudTheme();
      // 🔴 C'est LA condition de la neutralité : un défaut non nul imposerait
      // la maquette d'un hôte à tous les autres.
      expect(t.subfolderTriggerVariant, isNull);
      expect(t.subfolderTriggerCollapsedIcon, isNull);
      expect(t.subfolderTriggerExpandedIcon, isNull);
      expect(t.subfolderSelectedEmphasis, isNull);
    });

    test('copyWith transporte chaque token', () {
      final ZcrudTheme t = const ZcrudTheme().copyWith(
        subfolderTriggerVariant: ZSubfolderTriggerVariant.outlined,
        subfolderTriggerCollapsedIcon: Icons.arrow_drop_down,
        subfolderTriggerExpandedIcon: Icons.arrow_drop_up,
        subfolderSelectedEmphasis: ZSubfolderSelectedEmphasis.inverted,
      );
      expect(t.subfolderTriggerVariant, ZSubfolderTriggerVariant.outlined);
      expect(t.subfolderTriggerCollapsedIcon, Icons.arrow_drop_down);
      expect(t.subfolderTriggerExpandedIcon, Icons.arrow_drop_up);
      expect(t.subfolderSelectedEmphasis, ZSubfolderSelectedEmphasis.inverted);
    });

    test('lerp de deux défauts RESTE nul — l\'héritage n\'est pas GELÉ', () {
      // Même invariant que `badgeRadius` : Flutter interpole le thème à CHAQUE
      // transition. Matérialiser une valeur ici figerait le repli du
      // consommateur dès la première transition, sans que le rendu immédiat
      // change — la régression n'apparaîtrait qu'au changement suivant.
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme r = a.lerp(const ZcrudTheme(), t);
        expect(r.subfolderTriggerVariant, isNull, reason: 't=$t');
        expect(r.subfolderTriggerCollapsedIcon, isNull, reason: 't=$t');
        expect(r.subfolderTriggerExpandedIcon, isNull, reason: 't=$t');
        expect(r.subfolderSelectedEmphasis, isNull, reason: 't=$t');
      }
    });

    test('lerp de tokens DISCRETS bascule au point milieu', () {
      const ZcrudTheme a = ZcrudTheme(
        subfolderTriggerVariant: ZSubfolderTriggerVariant.outlined,
        subfolderSelectedEmphasis: ZSubfolderSelectedEmphasis.inverted,
      );
      const ZcrudTheme b = ZcrudTheme(
        subfolderTriggerVariant: ZSubfolderTriggerVariant.filled,
        subfolderSelectedEmphasis: ZSubfolderSelectedEmphasis.highlight,
      );
      // Le compteur DOIT pouvoir varier : mesurer une seule extrémité serait
      // vert sur tout défaut.
      expect(
        a.lerp(b, 0.0).subfolderTriggerVariant,
        ZSubfolderTriggerVariant.outlined,
      );
      expect(
        a.lerp(b, 0.49).subfolderTriggerVariant,
        ZSubfolderTriggerVariant.outlined,
      );
      expect(
        a.lerp(b, 0.51).subfolderTriggerVariant,
        ZSubfolderTriggerVariant.filled,
      );
      expect(
        a.lerp(b, 1.0).subfolderSelectedEmphasis,
        ZSubfolderSelectedEmphasis.highlight,
      );
    });

    test('AUCUNE couleur n\'est portée par ces tokens', () {
      // Garde de CONCEPTION : le jour où quelqu'un voudra « juste » ajouter un
      // `subfolderSelectedColor`, ceci le nommera. L'inversion est un couple de
      // RÔLES du `ColorScheme`, résolu par le consommateur — pas deux hex.
      const ZcrudTheme t = ZcrudTheme(
        subfolderTriggerVariant: ZSubfolderTriggerVariant.outlined,
        subfolderSelectedEmphasis: ZSubfolderSelectedEmphasis.inverted,
      );
      expect(t.subfolderTriggerVariant, isNot(isA<Color>()));
      expect(t.subfolderSelectedEmphasis, isNot(isA<Color>()));
      expect(ZSubfolderTriggerVariant.values, hasLength(3));
      expect(ZSubfolderSelectedEmphasis.values, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // CR-IFFD-44 — marge EXTÉRIEURE de la barre de fratrie
  // ---------------------------------------------------------------------------
  group('CR-IFFD-44 — `subfolderBarPadding`', () {
    test('`null` par DÉFAUT ⇒ aucune enveloppe chez le consommateur', () {
      expect(const ZcrudTheme().subfolderBarPadding, isNull);
    });

    test('copyWith transporte le token', () {
      expect(
        const ZcrudTheme()
            .copyWith(
              subfolderBarPadding: const EdgeInsetsDirectional.only(start: 12),
            )
            .subfolderBarPadding,
        const EdgeInsetsDirectional.only(start: 12),
      );
    });

    test('🔴 lerp de deux `null` RESTE `null` — l\'héritage n\'est pas GELÉ',
        () {
      // Le piège déjà rencontré ici : matérialiser `EdgeInsets.zero` figerait
      // « pas d'enveloppe dans l'arbre » dès la PREMIÈRE transition de thème,
      // sans que le rendu immédiat change — la régression n'apparaîtrait qu'au
      // changement suivant.
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(
          a.lerp(const ZcrudTheme(), t).subfolderBarPadding,
          isNull,
          reason: 't=$t',
        );
      }
    });

    test('lerp INTERPOLE réellement (ce n\'est pas une bascule)', () {
      const ZcrudTheme a = ZcrudTheme(
        subfolderBarPadding: EdgeInsetsDirectional.only(start: 0),
      );
      const ZcrudTheme b = ZcrudTheme(
        subfolderBarPadding: EdgeInsetsDirectional.only(start: 40),
      );
      // Trois points DISTINCTS : une bascule au point milieu resterait verte
      // sur les seules extrémités.
      expect(a.lerp(b, 0).subfolderBarPadding, b.lerp(a, 1).subfolderBarPadding);
      expect(
        (a.lerp(b, 0.5).subfolderBarPadding! as EdgeInsetsDirectional).start,
        20,
      );
      expect(
        (a.lerp(b, 1).subfolderBarPadding! as EdgeInsetsDirectional).start,
        40,
      );
    });

    test('🔴 lerp PRÉSERVE la nature DIRECTIONNELLE (AD-13)', () {
      // Une interpolation contre un `EdgeInsets` physique dégraderait un inset
      // directionnel en inset physique : la marge cesserait de basculer en RTL
      // pendant la transition de thème — un défaut qui ne se verrait QUE là.
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme(
        subfolderBarPadding: EdgeInsetsDirectional.only(start: 40),
      );
      for (final double t in <double>[0.25, 0.5, 1]) {
        expect(
          a.lerp(b, t).subfolderBarPadding,
          isA<EdgeInsetsDirectional>(),
          reason: 't=$t (null → directionnel)',
        );
        expect(
          b.lerp(a, t).subfolderBarPadding,
          isA<EdgeInsetsDirectional>(),
          reason: 't=$t (directionnel → null)',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // CR-IFFD-46 — marge de la FEUILLE + alignement de son TITRE
  // ---------------------------------------------------------------------------
  group('CR-IFFD-46 — `subfolderSheetPadding` (marge CONTINUE)', () {
    test('`null` par DÉFAUT ⇒ aucune enveloppe chez le consommateur', () {
      expect(const ZcrudTheme().subfolderSheetPadding, isNull);
    });

    test('copyWith transporte le token', () {
      expect(
        const ZcrudTheme()
            .copyWith(
              subfolderSheetPadding: const EdgeInsetsDirectional.only(top: 12),
            )
            .subfolderSheetPadding,
        const EdgeInsetsDirectional.only(top: 12),
      );
    });

    test('🔴 lerp de deux `null` RESTE `null` — l\'héritage n\'est pas GELÉ',
        () {
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(
          a.lerp(const ZcrudTheme(), t).subfolderSheetPadding,
          isNull,
          reason: 't=$t',
        );
      }
    });

    test('lerp INTERPOLE réellement (ce n\'est pas une bascule)', () {
      const ZcrudTheme a = ZcrudTheme(
        subfolderSheetPadding: EdgeInsetsDirectional.only(start: 0),
      );
      const ZcrudTheme b = ZcrudTheme(
        subfolderSheetPadding: EdgeInsetsDirectional.only(start: 40),
      );
      expect(
        (a.lerp(b, 0.5).subfolderSheetPadding! as EdgeInsetsDirectional).start,
        20,
      );
      expect(
        (a.lerp(b, 1).subfolderSheetPadding! as EdgeInsetsDirectional).start,
        40,
      );
    });

    test('🔴 lerp PRÉSERVE la nature DIRECTIONNELLE (AD-13)', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme(
        subfolderSheetPadding: EdgeInsetsDirectional.only(start: 40),
      );
      for (final double t in <double>[0.25, 0.5, 1]) {
        expect(a.lerp(b, t).subfolderSheetPadding, isA<EdgeInsetsDirectional>());
        expect(b.lerp(a, t).subfolderSheetPadding, isA<EdgeInsetsDirectional>());
      }
    });

    test('🔴 les DEUX marges de fratrie sont INDÉPENDANTES', () {
      // Une garde qui ne mesurerait qu'un seul token resterait verte si les
      // deux étaient câblés sur le MÊME champ — défaut invisible au rendu tant
      // que l'hôte n'en règle qu'un.
      const ZcrudTheme t = ZcrudTheme(
        subfolderBarPadding: EdgeInsetsDirectional.only(start: 4),
      );
      expect(t.subfolderSheetPadding, isNull);
      expect(
        t
            .copyWith(
              subfolderSheetPadding: const EdgeInsetsDirectional.only(start: 9),
            )
            .subfolderBarPadding,
        const EdgeInsetsDirectional.only(start: 4),
      );
    });
  });

  group('CR-IFFD-46 — `subfolderSheetTitleAlign` (token DISCRET)', () {
    test('`null` par DÉFAUT ⇒ repli `TextAlign.start` chez le consommateur', () {
      expect(const ZcrudTheme().subfolderSheetTitleAlign, isNull);
    });

    test('copyWith transporte le token', () {
      expect(
        const ZcrudTheme()
            .copyWith(subfolderSheetTitleAlign: TextAlign.center)
            .subfolderSheetTitleAlign,
        TextAlign.center,
      );
    });

    test('🔴 lerp de deux `null` RESTE `null` — le repli n\'est pas GELÉ', () {
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(
          a.lerp(const ZcrudTheme(), t).subfolderSheetTitleAlign,
          isNull,
          reason: 't=$t',
        );
      }
    });

    test('lerp BASCULE au point milieu (aucun alignement intermédiaire)', () {
      const ZcrudTheme a = ZcrudTheme(subfolderSheetTitleAlign: TextAlign.start);
      const ZcrudTheme b = ZcrudTheme(subfolderSheetTitleAlign: TextAlign.end);
      expect(a.lerp(b, 0.25).subfolderSheetTitleAlign, TextAlign.start);
      expect(a.lerp(b, 0.75).subfolderSheetTitleAlign, TextAlign.end);
    });
  });
}
