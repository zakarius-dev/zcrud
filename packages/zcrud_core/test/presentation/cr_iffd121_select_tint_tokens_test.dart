/// 🔴 Gardes des **deux jetons d'état renseigné** du déclencheur de sélection :
/// `ZcrudTheme.selectTileSelectedBorderColor` / `selectTileSelectedBorderWidth`.
///
/// Ils ouvrent l'**échappatoire** de la réaction à l'état : le consommateur
/// (`zcrud_select`) teinte et épaissit la bordure d'un déclencheur qui porte
/// une valeur dès qu'une teinte par type de champ est servie ; poser ces deux
/// jetons aux valeurs de repos rend cette bordure insensible à l'état.
///
/// Ce que `zcrud_core` doit tenir **seul** :
///
/// 1. **aucun hôte passif ne bouge** — les deux sont absents de
///    [ZcrudTheme.fallback] ;
/// 2. **les 4 sites** sont câblés (déclaration, constructeur, `copyWith`,
///    `lerp`) — la garde structurelle `z_theme_four_sites_guard_test` couvre la
///    présence, celle-ci couvre le **comportement** ;
/// 3. **`lerp` par FAMILLE** — `_lerpNullableColor` pour la couleur (une
///    couleur ne se matérialise pas par-dessus le repli du consommateur),
///    `_lerpNullableFloor` pour l'épaisseur (`0` serait une bordure ABSENTE,
///    pas une absence de réglage).
///
/// 🔴 **Anti-tautologie** : toute valeur attendue est un **littéral** posé par
/// le test, jamais une constante du code sous test — les constantes de repli du
/// déclencheur vivent d'ailleurs dans un autre paquet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('jetons `selectTileSelectedBorder*`', () {
    // ══════════════════════════════════════════════════════════════════════
    // 1. HÔTE PASSIF INCHANGÉ — absents du repli
    // ══════════════════════════════════════════════════════════════════════

    test(
      'T-1 — les 2 jetons sont ABSENTS de `fallback()` (clair ET sombre) : '
      'une application qui n\'a rien déclaré ne voit aucune bordure changer',
      () {
        for (final ThemeData base in <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ]) {
          final ZcrudTheme f = ZcrudTheme.fallback(base);
          expect(
            f.selectTileSelectedBorderColor,
            isNull,
            reason:
                '🔴 le repli POSE une teinte d\'état renseigné : tout hôte, '
                'résolveur de dégradé ou non, verrait ses déclencheurs '
                'remplis changer de couleur sans l\'avoir demandé — et le '
                'repli sur la couleur de REPOS deviendrait inatteignable.',
          );
          expect(
            f.selectTileSelectedBorderWidth,
            isNull,
            reason:
                '🔴 le repli POSE une épaisseur d\'état renseigné : la bordure '
                's\'épaissirait SEULE (sans couleur pour la rendre lisible) '
                'chez une application sans résolveur de teinte.',
          );
        }
        // Anti-vacuité : le repli pose BIEN d'autres jetons — la garde ne
        // mesure donc pas un `fallback()` vide.
        expect(
          ZcrudTheme.fallback(ThemeData.light()).gapM,
          isNotNull,
          reason: '🔴 `fallback()` rendu vide : la garde ne mesure plus rien',
        );
      },
    );

    // ══════════════════════════════════════════════════════════════════════
    // 2. copyWith — propage réellement les deux valeurs
    // ══════════════════════════════════════════════════════════════════════

    test('T-2 — `copyWith` propage les 2 valeurs', () {
      final ZcrudTheme t = const ZcrudTheme().copyWith(
        selectTileSelectedBorderColor: const Color(0xFF123456),
        selectTileSelectedBorderWidth: 1.5,
      );
      expect(t.selectTileSelectedBorderColor, const Color(0xFF123456));
      expect(t.selectTileSelectedBorderWidth, 1.5);
      // Anti-vacuité : la source était bien vide — un `copyWith` inerte
      // rendrait `null`, pas la valeur posée.
      expect(const ZcrudTheme().selectTileSelectedBorderColor, isNull);
      expect(const ZcrudTheme().selectTileSelectedBorderWidth, isNull);
    });

    test(
      'T-3 — `copyWith` sans argument CONSERVE les 2 valeurs (elles ne sont '
      'ni écrasées ni oubliées du corps)',
      () {
        const ZcrudTheme posed = ZcrudTheme(
          selectTileSelectedBorderColor: Color(0xFF00FF00),
          selectTileSelectedBorderWidth: 2.5,
        );
        final ZcrudTheme t = posed.copyWith();
        expect(t.selectTileSelectedBorderColor, const Color(0xFF00FF00));
        expect(t.selectTileSelectedBorderWidth, 2.5);
      },
    );

    // ══════════════════════════════════════════════════════════════════════
    // 3. lerp — par FAMILLE, chacune avec son anti-vacuité
    // ══════════════════════════════════════════════════════════════════════

    test('T-4 — `lerp` de deux `null` reste `null` : le repli n\'est pas GELÉ',
        () {
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme l = a.lerp(const ZcrudTheme(), t);
        expect(l.selectTileSelectedBorderColor, isNull, reason: 't=$t');
        expect(l.selectTileSelectedBorderWidth, isNull, reason: 't=$t');
      }
    });

    test(
      'T-5 — COULEUR : `Color.lerp` nu est proscrit — un côté `null` rend '
      'l\'autre ENTIER, jamais une couche translucide',
      () {
        const ZcrudTheme vide = ZcrudTheme();
        const ZcrudTheme plein = ZcrudTheme(
          selectTileSelectedBorderColor: Color(0xFFAA0000),
        );
        // 🔴 `Color.lerp(null, c, t)` part du TRANSPARENT : à t = 0,25 il rend
        // `c` à 25 % d'opacité — une bordure fantôme, moitié teinte moitié
        // fond, que personne n'a choisie. Le helper du fichier rend `c` ENTIER
        // dès que l'autre côté ne se prononce pas.
        for (final double t in <double>[0, 0.01, 0.25, 0.5, 0.99, 1]) {
          final Color? l = vide.lerp(plein, t).selectTileSelectedBorderColor;
          expect(
            l,
            const Color(0xFFAA0000),
            reason: '🔴 couleur DÉLAVÉE à t=$t : `Color.lerp` nu au lieu du '
                'helper nullable.',
          );
          expect(
            l!.a,
            1.0,
            reason: '🔴 opacité $t : une bordure translucide en transition.',
          );
        }
        // Sens inverse (le `null` est du côté `other`).
        expect(
          plein.lerp(vide, 0.25).selectTileSelectedBorderColor,
          const Color(0xFFAA0000),
        );
        // Deux côtés posés ⇒ interpolation RÉELLE (anti-vacuité : le helper
        // n'est pas un simple « rends toujours `a` »).
        const ZcrudTheme autre = ZcrudTheme(
          selectTileSelectedBorderColor: Color(0xFF0000AA),
        );
        final Color? melange =
            plein.lerp(autre, 0.5).selectTileSelectedBorderColor;
        expect(melange, isNot(const Color(0xFFAA0000)));
        expect(melange, isNot(const Color(0xFF0000AA)));
      },
    );

    test(
      'T-6 — ÉPAISSEUR : `lerp` de PLANCHER — un côté `null` ne matérialise '
      'JAMAIS `0` (une bordure ABSENTE en pleine transition)',
      () {
        const ZcrudTheme vide = ZcrudTheme();
        // Littéral du test, PAS `ZSelectTileReference.selectedBorderWidth`
        // (autre paquet) : une garde tautologique suivrait la référence au
        // lieu de la mesurer.
        const ZcrudTheme plein = ZcrudTheme(selectTileSelectedBorderWidth: 1.5);
        // 🔴 t = 0 est le point où `_lerpNullableDouble` rendrait `0`.
        expect(
          vide.lerp(plein, 0).selectTileSelectedBorderWidth,
          1.5,
          reason: '🔴 `0` matérialisé : bordure ABSENTE en transition.',
        );
        expect(vide.lerp(plein, 0).selectTileSelectedBorderWidth, isNot(0));
        // Sens inverse (le `null` est du côté `other`, à t = 1).
        expect(plein.lerp(vide, 1).selectTileSelectedBorderWidth, 1.5);
        // Deux côtés posés ⇒ interpolation CONTINUE réelle.
        const ZcrudTheme autre = ZcrudTheme(selectTileSelectedBorderWidth: 3.5);
        expect(plein.lerp(autre, 0.5).selectTileSelectedBorderWidth, 2.5);
        // Anti-vacuité : les deux bornes DIFFÈRENT.
        expect(
          plein.selectTileSelectedBorderWidth,
          isNot(autre.selectTileSelectedBorderWidth),
        );
      },
    );

    test(
      'T-7 — `selectTileEmptyAdornmentAlpha` : absent du repli, propagé par '
      '`copyWith`, `lerp` de PLANCHER (`0` = pastille INVISIBLE)',
      () {
        for (final ThemeData base in <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ]) {
          expect(
            ZcrudTheme.fallback(base).selectTileEmptyAdornmentAlpha,
            isNull,
            reason: '🔴 le repli pose une opacité de pastille : le '
                'consommateur ne peut plus dériver son atténuation de '
                'référence, et tout hôte qui a posé un jeton de pastille voit '
                'son état vide changer.',
          );
        }
        expect(
          const ZcrudTheme()
              .copyWith(selectTileEmptyAdornmentAlpha: 0.045)
              .selectTileEmptyAdornmentAlpha,
          0.045,
        );
        expect(
          const ZcrudTheme(selectTileEmptyAdornmentAlpha: 0.045)
              .copyWith()
              .selectTileEmptyAdornmentAlpha,
          0.045,
        );
        // `lerp` de PLANCHER : un côté `null` ne matérialise JAMAIS `0` — une
        // pastille TOTALEMENT invisible le temps d'une transition de thème.
        const ZcrudTheme vide = ZcrudTheme();
        const ZcrudTheme plein =
            ZcrudTheme(selectTileEmptyAdornmentAlpha: 0.045);
        expect(
          vide.lerp(plein, 0).selectTileEmptyAdornmentAlpha,
          0.045,
          reason: '🔴 `0` matérialisé : pastille INVISIBLE en transition.',
        );
        expect(vide.lerp(plein, 0).selectTileEmptyAdornmentAlpha, isNot(0));
        expect(plein.lerp(vide, 1).selectTileEmptyAdornmentAlpha, 0.045);
        expect(vide.lerp(vide, 0.5).selectTileEmptyAdornmentAlpha, isNull);
      },
    );
  });

  group('pastille d\'ornement — atténuation d\'ÉTAT', _pillGuards);
}

/// 🔴 Gardes du **paramètre d'atténuation d'état** de la pastille d'ornement
/// (`zResolveTintedAdornment(..., backgroundAlpha:)`).
///
/// **Ce qui est défendu** : un présentateur peut estomper la pastille pour
/// signaler un état — mais il ne peut **jamais** en créer une. La condition
/// d'existence reste le jeton `adornmentIconBackgroundAlpha` de l'application,
/// et lui seul (opt-in strict, dans les deux directions).
const ZFieldSpec _champTeinte = ZFieldSpec(
  name: 'quand',
  type: EditionFieldType.text,
  leading: ZFieldAdornment.icon('date'),
);

const Color _bleuLisible = Color(0xFF1732AB);

ZGradientSpec? _resolveurBleu(ColorScheme scheme, String key) =>
    key == zFieldTypeTintKey(EditionFieldType.text)
        ? const ZGradientSpec(
            gradient: LinearGradient(colors: <Color>[_bleuLisible, _bleuLisible]),
            onGradient: Color(0xFFFFFFFF),
          )
        : null;

Future<Widget?> _pumpOrnement(
  WidgetTester tester, {
  ZcrudTheme? theme,
  double? backgroundAlpha,
}) async {
  late Widget? resolu;
  await tester.pumpWidget(MaterialApp(
    home: ZcrudScope(
      gradientResolver: _resolveurBleu,
      theme: theme,
      child: Builder(
        builder: (BuildContext context) {
          resolu = zResolveTintedAdornment(
            context,
            _champTeinte.leading,
            field: _champTeinte,
            backgroundAlpha: backgroundAlpha,
          ).child;
          return const SizedBox.shrink();
        },
      ),
    ),
  ));
  return resolu;
}

BoxDecoration _decoration(Widget? ornement) {
  expect(ornement, isA<Center>());
  final DecoratedBox box = (ornement! as Center).child! as DecoratedBox;
  return box.decoration as BoxDecoration;
}

void _pillGuards() {
  const ZcrudTheme pastille = ZcrudTheme(
    adornmentIconBackgroundAlpha: 0.12,
    adornmentIconBackgroundRadius: Radius.circular(8),
    adornmentIconSize: 18,
  );

  testWidgets(
    'P-1 — `backgroundAlpha` ne CRÉE jamais de pastille : sans le jeton '
    'd\'opacité, l\'ornement reste l\'icône NUE',
    (WidgetTester tester) async {
      final Widget? sans = await _pumpOrnement(tester, backgroundAlpha: 0.9);
      expect(
        sans,
        isA<Icon>(),
        reason: '🔴 une pastille apparaît sur demande d\'un présentateur : '
            'l\'opt-in strict du canal est rompu, et toute application sans '
            'jeton de pastille voit ses ornements changer.',
      );
      // Anti-vacuité : le MÊME arbre, jeton posé, produit bien une pastille.
      final Widget? avec = await _pumpOrnement(tester, theme: pastille);
      expect(avec, isA<Center>());
    },
  );

  testWidgets(
    'P-2 — `backgroundAlpha` remplace l\'opacité du jeton, et rien d\'autre',
    (WidgetTester tester) async {
      final Widget? plein = await _pumpOrnement(tester, theme: pastille);
      final Widget? estompe = await _pumpOrnement(
        tester,
        theme: pastille,
        backgroundAlpha: 0.045,
      );
      final BoxDecoration dPlein = _decoration(plein);
      final BoxDecoration dEstompe = _decoration(estompe);
      expect(dPlein.color!.a, closeTo(0.12, 1e-6));
      expect(
        dEstompe.color!.a,
        closeTo(0.045, 1e-6),
        reason: '🔴 l\'atténuation demandée est ignorée : la pastille ne peut '
            'pas signaler d\'état.',
      );
      // La TEINTE, le rayon et la géométrie ne changent pas — seule l'opacité.
      expect(dPlein.borderRadius, dEstompe.borderRadius);
      for (final String canal in <String>['r', 'g', 'b']) {
        final double p = canal == 'r'
            ? dPlein.color!.r
            : canal == 'g'
                ? dPlein.color!.g
                : dPlein.color!.b;
        final double e = canal == 'r'
            ? dEstompe.color!.r
            : canal == 'g'
                ? dEstompe.color!.g
                : dEstompe.color!.b;
        expect(e, closeTo(p, 1e-6),
            reason: '🔴 l\'atténuation a changé la TEINTE (canal $canal), pas '
                'seulement l\'opacité.');
      }
      // Anti-vacuité : les deux opacités DIFFÈRENT bien.
      expect(dPlein.color!.a, isNot(closeTo(0.045, 1e-6)));
    },
  );

  testWidgets(
    'P-3 — `backgroundAlpha: null` ⇒ opacité du jeton, à l\'identique',
    (WidgetTester tester) async {
      final BoxDecoration a = _decoration(
        await _pumpOrnement(tester, theme: pastille),
      );
      final BoxDecoration b = _decoration(
        await _pumpOrnement(tester, theme: pastille, backgroundAlpha: null),
      );
      expect(a.color, b.color);
      expect(a.borderRadius, b.borderRadius);
    },
  );
}
