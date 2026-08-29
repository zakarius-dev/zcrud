// Garde de la RÉFÉRENCE COULEUR d'annotation (lot Apparence E).
//
// 🔴 La table ci-dessous est RELEVÉE À LA MAIN sur le legacy IFFD (branche
// `main`, fichier `lib/src/presentation/features/documents/widgets/
// document_viewer/color_palette.dart`) et FIGÉE ici. Elle n'est JAMAIS relue
// depuis `ZAnnotationPaletteReference` : une garde qui compare la référence à
// elle-même ne mesure rien. Si la référence dérive, ces tests le disent avec
// les deux listes en regard.
//
// Le contraste de `onColor` est RECALCULÉ ici (via `zContrastRatio`, l'unique
// implémentation du socle) plutôt que cru sur la foi de la dartdoc.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_document/zcrud_document.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Les 40 teintes de la grille legacy, `color_palette.dart:124-163`.
///
/// `:124` s'écrit `Colors.white` chez l'hôte — rendu ici par son hex, la
/// référence n'ayant pas le droit de nommer `Colors`.
const List<int> _kLegacyGrid = <int>[
  // :124-131 — achromatiques.
  0xFFFFFFFF, 0xFFDADADA, 0xFFB2B1B1, 0xFF909090,
  0xFF6F6F6F, 0xFF515151, 0xFF383737, 0xFF060606,
  // :132-139 — pastels.
  0xFFFFA6A6, 0xFFFFDEA6, 0xFFFBFBA6, 0xFFA7FFAB,
  0xFFA6FFF9, 0xFFACA9FF, 0xFFE7A6FF, 0xFFFBA6FB,
  // :140-147 — vives.
  0xFFFF0000, 0xFFFFA200, 0xFFF3F500, 0xFF03FF0F,
  0xFF00FFEF, 0xFF1108FF, 0xFFB900FF, 0xFFF500F3,
  // :148-155 — moyennes.
  0xFFD60000, 0xFFD68800, 0xFFCACC00, 0xFF00D60A,
  0xFF00D6C8, 0xFF0800E0, 0xFF9B00D6, 0xFFCC00CA,
  // :156-163 — sombres.
  0xFF990000, 0xFF996100, 0xFF979900, 0xFF009907,
  0xFF00998F, 0xFF050099, 0xFF6F0099, 0xFF990097,
];

/// La rangée compacte legacy, `color_palette.dart:293-299`.
const List<int> _kLegacyCompact = <int>[
  0xFF03FF0F, 0xFF00FFEF, 0xFF1108FF, 0xFFB900FF,
  0xFFF500F3, 0xFFD60000, 0xFFD68800,
];

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';

List<String> _hexes(List<Color> cs) => cs.map(_hex).toList();

List<String> _hexesOfInts(List<int> vs) => vs
    .map((int v) => '#${v.toRadixString(16).toUpperCase().padLeft(8, '0')}')
    .toList();

/// Hôte minimal : le profil est posé sur le `ZcrudTheme` du `ZcrudScope`.
Widget _host(
  Widget child, {
  ZReferenceProfile? profile,
  ZColorKeyResolver? resolver,
}) {
  final Widget scoped = ZcrudScope(
    theme: ZcrudTheme(referenceProfile: profile),
    colorKeyResolver: resolver,
    child: child,
  );
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 480, height: 600, child: scoped)),
    ),
  );
}

void main() {
  group('table figée — la référence n\'a pas dérivé du legacy', () {
    test('grille : 40 teintes, dans l\'ordre exact de color_palette.dart:124-163',
        () {
      expect(ZAnnotationPaletteReference.colors, hasLength(40));
      expect(
        _hexes(ZAnnotationPaletteReference.colors),
        _hexesOfInts(_kLegacyGrid),
        reason: '🔴 la référence a DÉRIVÉ de la grille legacy '
            '(color_palette.dart:124-163).',
      );
    });

    test('rangée compacte : 7 teintes, color_palette.dart:293-299', () {
      expect(ZAnnotationPaletteReference.compact, hasLength(7));
      expect(
        _hexes(ZAnnotationPaletteReference.compact),
        _hexesOfInts(_kLegacyCompact),
        reason: '🔴 la référence a DÉRIVÉ de la rangée compacte legacy '
            '(color_palette.dart:293-299).',
      );
    });

    test('la rangée compacte est un SOUS-ENSEMBLE strict de la grille', () {
      final Set<String> grid = _hexes(ZAnnotationPaletteReference.colors).toSet();
      for (final String h in _hexes(ZAnnotationPaletteReference.compact)) {
        expect(grid, contains(h),
            reason: '$h n\'appartient pas à la grille — les deux tables ont '
                'divergé.');
      }
      expect(ZAnnotationPaletteReference.compact.length,
          lessThan(ZAnnotationPaletteReference.colors.length));
    });

    test('aucun doublon dans la grille (40 teintes DISTINCTES)', () {
      expect(_hexes(ZAnnotationPaletteReference.colors).toSet(), hasLength(40));
    });
  });

  group('onColor MESURÉ — contraste recalculé, jamais cru sur parole', () {
    test('ratio >= 3.0 (kZNonTextMinContrast) sur les 40 teintes', () {
      final List<String> faibles = <String>[];
      for (final Color c in ZAnnotationPaletteReference.colors) {
        final Color fg = ZAnnotationPaletteReference.foregroundFor(c);
        final double ratio = zContrastRatio(fg, c);
        if (ratio < kZNonTextMinContrast) {
          faibles.add('${_hex(c)} on=${_hex(fg)} ratio=${ratio.toStringAsFixed(2)}');
        }
      }
      expect(faibles, isEmpty,
          reason: '🔴 premier plan illisible sur ces teintes : $faibles');
    });

    test('le plancher réellement atteint est >= 4.5 (borne annoncée : 4.58)',
        () {
      double pire = double.infinity;
      for (final Color c in ZAnnotationPaletteReference.colors) {
        final double r =
            zContrastRatio(ZAnnotationPaletteReference.foregroundFor(c), c);
        if (r < pire) pire = r;
      }
      expect(pire, greaterThanOrEqualTo(4.5),
          reason: 'plancher mesuré = ${pire.toStringAsFixed(2)}');
    });

    test('le premier plan est réellement DÉPARTAGÉ (blanc ET noir apparaissent)',
        () {
      final Set<String> fgs = ZAnnotationPaletteReference.colors
          .map((Color c) => _hex(ZAnnotationPaletteReference.foregroundFor(c)))
          .toSet();
      expect(fgs, hasLength(2),
          reason: '🔴 un premier plan CONSTANT n\'est pas une mesure : $fgs');
      expect(fgs, containsAll(<String>['#FFFFFFFF', '#FF000000']));
    });

    test('foregroundFor prend le MEILLEUR des deux candidats, pas le premier',
        () {
      // Vecteurs figés : deux teintes qui départagent dans les deux sens.
      const Color clair = Color(0xFFFBFBA6); // pastel jaune
      const Color sombre = Color(0xFF060606); // presque noir
      expect(ZAnnotationPaletteReference.foregroundFor(clair),
          const Color(0xFF000000));
      expect(ZAnnotationPaletteReference.foregroundFor(sombre),
          const Color(0xFFFFFFFF));
    });
  });

  group('pairAt — totale et défensive (AD-10)', () {
    test('index négatif, nul, hors-bornes : jamais de levée, toujours dans la '
        'table', () {
      for (final int i in <int>[-1, -41, 0, 39, 40, 1000]) {
        final ZColorPair? p = ZAnnotationPaletteReference.pairAt(i);
        expect(p, isNotNull);
        expect(ZAnnotationPaletteReference.colors, contains(p!.color));
        expect(p.onColor,
            ZAnnotationPaletteReference.foregroundFor(p.color));
      }
    });

    test('palette VIDE ⇒ null (le seul cas nul), jamais une levée', () {
      expect(
        ZAnnotationPaletteReference.pairAt(3, palette: const <Color>[]),
        isNull,
      );
    });

    test('vecteurs d\'indexation figés (abs() % 40)', () {
      expect(_hex(ZAnnotationPaletteReference.pairAt(0)!.color), '#FFFFFFFF');
      expect(_hex(ZAnnotationPaletteReference.pairAt(3)!.color), '#FF909090');
      expect(_hex(ZAnnotationPaletteReference.pairAt(40)!.color), '#FFFFFFFF');
      expect(_hex(ZAnnotationPaletteReference.pairAt(-3)!.color), '#FF909090');
    });
  });

  group('chaîne de résolution — priorité paramètre > hôte > référence > rôle',
      () {
    /// Sonde : lit la couleur rendue pour une `colorKey`/`slotIndex` donnés.
    Future<ZColorPair> resolve(
      WidgetTester tester, {
      required String colorKey,
      required int slotIndex,
      ZReferenceProfile? profile,
      ZColorKeyResolver? resolver,
      List<Color>? swatchColors,
    }) async {
      late ZColorPair captured;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              captured = zResolveAnnotationColor(
                context,
                colorKey,
                slotIndex: slotIndex,
                swatchColors: swatchColors,
              );
              return const SizedBox.shrink();
            },
          ),
          profile: profile,
          resolver: resolver,
        ),
      );
      return captured;
    }

    testWidgets('profil LEGACY EXPLICITE : une clé inconnue prend la RÉFÉRENCE',
        (WidgetTester tester) async {
      // `success` n'est ni une clé d'hôte (aucun resolver) ni un rôle M3.
      final ZColorPair p = await resolve(
        tester,
        colorKey: 'success',
        slotIndex: 3,
        profile: ZReferenceProfile.legacy,
      );
      expect(p, ZAnnotationPaletteReference.pairAt(3));
      expect(_hex(p.color), '#FF909090');
    });

    testWidgets('🔴 DÉFAUT (aucun profil déclaré) : la même clé retombe sur le '
        'RÔLE indexé, exactement comme sous `neutral`',
        (WidgetTester tester) async {
      final ZColorPair defaut =
          await resolve(tester, colorKey: 'success', slotIndex: 3);
      expect(
        ZAnnotationPaletteReference.colors,
        isNot(contains(defaut.color)),
        reason: '🔴 un hôte qui n\'a rien déclaré reçoit la teinte de '
            'référence : le défaut du socle a dérivé vers `legacy`',
      );
      final ZColorPair neutre = await resolve(
        tester,
        colorKey: 'success',
        slotIndex: 3,
        profile: ZReferenceProfile.neutral,
      );
      expect(defaut, neutre,
          reason: 'profil absent et `neutral` explicite doivent être '
              'INDISCERNABLES');
    });

    testWidgets('profil NEUTRAL : la même clé retombe sur le RÔLE indexé',
        (WidgetTester tester) async {
      final ZColorPair p = await resolve(
        tester,
        colorKey: 'success',
        slotIndex: 3,
        profile: ZReferenceProfile.neutral,
      );
      expect(ZAnnotationPaletteReference.colors, isNot(contains(p.color)),
          reason: 'sous neutral la référence ne doit JAMAIS être lue');
      expect(p.onColor, isNotNull);
    });

    testWidgets('un RÔLE Material 3 reste résolu par le thème dans les DEUX '
        'profils (la référence ne l\'écrase pas)',
        (WidgetTester tester) async {
      for (final ZReferenceProfile? profile in <ZReferenceProfile?>[
        null,
        ZReferenceProfile.legacy,
        ZReferenceProfile.neutral,
      ]) {
        final ZColorPair p = await resolve(
          tester,
          colorKey: 'primary',
          slotIndex: 0,
          profile: profile,
        );
        expect(ZAnnotationPaletteReference.colors, isNot(contains(p.color)),
            reason: 'profil $profile : `primary` est un RÔLE, pas une teinte '
                'de la référence.');
      }
    });

    testWidgets('le résolveur HÔTE prime sur la référence (profil legacy)',
        (WidgetTester tester) async {
      const Color injected = Color(0xFF123456);
      final ZColorPair p = await resolve(
        tester,
        colorKey: 'success',
        slotIndex: 3,
        resolver: (ColorScheme scheme, String key) => key == 'success'
            ? const ZColorPair(color: injected, onColor: Color(0xFFFFFFFF))
            : null,
      );
      expect(p.color, injected);
    });

    testWidgets('le PARAMÈTRE prime sur tout, dans les DEUX profils',
        (WidgetTester tester) async {
      const List<Color> override = <Color>[Color(0xFF010203)];
      for (final ZReferenceProfile? profile in <ZReferenceProfile?>[
        ZReferenceProfile.legacy,
        ZReferenceProfile.neutral,
      ]) {
        final ZColorPair p = await resolve(
          tester,
          colorKey: 'success',
          slotIndex: 3,
          profile: profile,
          swatchColors: override,
          resolver: (ColorScheme scheme, String key) => const ZColorPair(
            color: Color(0xFF999999),
            onColor: Color(0xFF000000),
          ),
        );
        expect(p.color, const Color(0xFF010203),
            reason: 'profil $profile : le paramètre doit gagner même contre '
                'un résolveur d\'hôte.');
      }
    });

    testWidgets('une liste de couleurs plus COURTE est cyclée, jamais tronquée',
        (WidgetTester tester) async {
      const List<Color> deux = <Color>[Color(0xFF010101), Color(0xFF020202)];
      expect(
        (await resolve(
          tester,
          colorKey: 'x',
          slotIndex: 5,
          swatchColors: deux,
        ))
            .color,
        const Color(0xFF020202),
      );
      // Une liste VIDE n'est pas un paramètre : la chaîne continue — jusqu'à
      // la référence sous `legacy`, jusqu'au rôle indexé par défaut.
      final ZColorPair vide = await resolve(
        tester,
        colorKey: 'success',
        slotIndex: 3,
        swatchColors: const <Color>[],
        profile: ZReferenceProfile.legacy,
      );
      expect(vide, ZAnnotationPaletteReference.pairAt(3));
      final ZColorPair videParDefaut = await resolve(
        tester,
        colorKey: 'success',
        slotIndex: 3,
        swatchColors: const <Color>[],
      );
      expect(
        videParDefaut,
        await resolve(tester, colorKey: 'success', slotIndex: 3),
        reason: 'une liste vide ne doit rien changer à la chaîne, dans les '
            'deux profils',
      );
    });
  });

  group('palette d\'étude sous LEGACY EXPLICITE — la barre peint la '
      'référence', () {
    testWidgets('les clés non-rôles de ZColorPalette.defaultStudy prennent '
        'EXACTEMENT la référence à leur rang', (WidgetTester tester) async {
      const ZColorPalette palette = ZColorPalette.defaultStudy();
      await tester.pumpWidget(
        _host(
          const ZAnnotationToolbar(),
          profile: ZReferenceProfile.legacy,
        ),
      );

      // `primary`/`secondary`/`tertiary`/`neutral` sont des RÔLES M3 : le
      // thème les résout, la référence ne les touche pas. Les quatre autres
      // tombent sur la référence, à leur rang dans la palette.
      const Map<String, String> attendu = <String, String>{
        'success': '#FF909090', // rang 3
        'warning': '#FF6F6F6F', // rang 4
        'danger': '#FF515151', // rang 5
        'info': '#FF383737', // rang 6
      };
      for (final MapEntry<String, String> e in attendu.entries) {
        final ColoredBox box = tester.widget<ColoredBox>(
          find.byKey(
            ValueKey<String>('$kAnnotationSwatchFillKeyPrefix${e.key}'),
          ),
        );
        expect(_hex(box.color), e.value,
            reason: 'swatch "${e.key}" (rang ${palette.indexOf(e.key)})');
      }
    });

    testWidgets('🔴 par DÉFAUT et sous NEUTRAL, aucune de ces quatre swatches '
        'ne porte une teinte de la référence', (WidgetTester tester) async {
      // Les deux formes du défaut, mesurées séparément : un repli qui
      // divergerait entre elles ne se verrait dans aucune prise isolée.
      for (final ZReferenceProfile? profil in <ZReferenceProfile?>[
        null,
        ZReferenceProfile.neutral,
      ]) {
        await tester.pumpWidget(
          _host(const ZAnnotationToolbar(), profile: profil),
        );
        for (final String key in <String>[
          'success',
          'warning',
          'danger',
          'info',
        ]) {
          final ColoredBox box = tester.widget<ColoredBox>(
            find.byKey(ValueKey<String>('$kAnnotationSwatchFillKeyPrefix$key')),
          );
          expect(
            ZAnnotationPaletteReference.colors,
            isNot(contains(box.color)),
            reason: '🔴 la swatch "$key" a lu la référence (profil $profil) : '
                'le défaut du socle a dérivé vers `legacy`',
          );
        }
      }
    });
  });
}
