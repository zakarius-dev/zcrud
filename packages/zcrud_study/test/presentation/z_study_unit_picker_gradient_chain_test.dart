/// La pastille de palette signature de `ZStudyUnitPicker` passe par la chaîne
/// de résolution COMPLÈTE du socle, et pas par la fonction pure.
///
/// ## Le défaut visé
///
/// Appeler `zSignatureGradientFor(identity)` — fonction PURE, sans contexte —
/// court-circuite les trois maillons que `zResolveGradient` consulte avant la
/// référence : le seam hôte `ZcrudScope.gradientResolver`, le jeton
/// `ZcrudTheme.signaturePalette`, et la stratégie d'index
/// `ZcrudTheme.signaturePaletteIndexStrategy`. Une application ne peut alors
/// teinter cette pastille ni par seam ni par jeton — elle n'a AUCUNE prise.
///
/// L'arbitrage de profil (`zLegacyOr`) ne se rejoue pas non plus par-dessus :
/// il vit DANS `zResolveGradient` et ne gouverne que le DERNIER maillon (la
/// référence). Le rejouer à l'extérieur annulerait, sous le profil `neutral`,
/// une palette que l'hôte a délibérément posée par jeton ou par seam.
///
/// ## Ce que ces gardes mesurent
///
/// La décoration du `RenderDecoratedBox` **monté** — donc la géométrie et les
/// couleurs réellement remises au moteur de rendu — et non une valeur passée à
/// un constructeur. Aucune rastérisation : `toImage()` pend sous ce harnais.
///
/// ## Inertie ABSOLUE
///
/// Sans seam ni jeton, la pastille est identique à aujourd'hui sous les DEUX
/// profils : le dégradé de référence indexé par `titleHash` sous `legacy`,
/// **aucune pastille du tout** sous `neutral` (le défaut).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderDecoratedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZGradientSpec,
        ZPaletteIndexStrategy,
        ZReferenceProfile,
        ZSignaturePaletteReference,
        ZcrudScope,
        ZcrudTheme,
        zPaletteIndexFor,
        zSignatureGradientFor,
        zSignatureKey;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const String _kId = 'racine';

ZStudyRef _unit(String id) =>
    ZStudyRef(type: kZStudyRefTypeOrgUnit, id: id, label: 'Racine');

/// L'identité exacte que le sélecteur dérive d'une référence — recopiée ici
/// parce que la garde doit pouvoir prédire la CLÉ attendue par le seam.
String _identity(ZStudyRef ref) => '${ref.type.length}:${ref.type}:${ref.id}';

/// Dégradés de test, DISTINCTS de toute entrée de la palette de référence :
/// une égalité ne peut donc pas être vraie par coïncidence.
ZGradientSpec _spec(Color a, Color b) => ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[a, b]),
      onGradient: const Color(0xFF000000),
    );

final ZGradientSpec kSeamSpec =
    _spec(const Color(0xFF010203), const Color(0xFF040506));
final List<ZGradientSpec> kTokenPalette = <ZGradientSpec>[
  _spec(const Color(0xFF111111), const Color(0xFF222222)),
  _spec(const Color(0xFF333333), const Color(0xFF444444)),
  _spec(const Color(0xFF555555), const Color(0xFF666666)),
  _spec(const Color(0xFF777777), const Color(0xFF888888)),
  _spec(const Color(0xFF999999), const Color(0xFFAAAAAA)),
  _spec(const Color(0xFFBBBBBB), const Color(0xFFCCCCCC)),
  _spec(const Color(0xFFDDDDDD), const Color(0xFFEEEEEE)),
];

Widget _host(
  Widget child, {
  ZcrudTheme? extension,
  ZGradientSpec? Function(ColorScheme, String)? resolver,
}) {
  final ThemeData base = ThemeData();
  final ThemeData theme = base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      extension ?? ZcrudTheme.fallback(base),
    ],
  );
  final Widget body = Scaffold(
    body: SizedBox(width: 800, height: 600, child: child),
  );
  return MaterialApp(
    theme: theme,
    home: resolver == null
        ? body
        : ZcrudScope(gradientResolver: resolver, child: body),
  );
}

Widget _picker() => ZStudyUnitPicker(
      roots: <ZStudyUnitNode>[ZStudyUnitNode(ref: _unit(_kId))],
      onSelect: (_) {},
      searchEnabled: false,
    );

Finder _badge() =>
    find.byKey(const ValueKey<String>('zStudyUnitPicker.badge:$_kId'));

/// Couleurs RÉELLEMENT remises au moteur de rendu : la décoration du
/// `RenderDecoratedBox` MONTÉ, jamais la propriété d'un `Container` déclaré.
List<Color> _paintedColors(WidgetTester tester) {
  final RenderDecoratedBox box = tester.renderObject<RenderDecoratedBox>(
    find.descendant(of: _badge(), matching: find.byType(DecoratedBox)),
  );
  final BoxDecoration deco = box.decoration as BoxDecoration;
  final LinearGradient gradient = deco.gradient! as LinearGradient;
  return gradient.colors;
}

List<Color> _colorsOf(ZGradientSpec spec) =>
    (spec.gradient as LinearGradient).colors;

ZcrudTheme _themed({
  ZReferenceProfile? profile,
  List<ZGradientSpec>? palette,
  ZPaletteIndexStrategy? strategy,
}) {
  final ThemeData base = ThemeData();
  return ZcrudTheme.fallback(base).copyWith(
    referenceProfile: profile,
    signaturePalette: palette,
    signaturePaletteIndexStrategy: strategy,
  );
}

void main() {
  group('🎨 pastille signature du sélecteur d\'unités — chaîne COMPLÈTE', () {
    testWidgets('le SEAM hôte `gradientResolver` PEINT la pastille',
        (WidgetTester tester) async {
      final List<String> keys = <String>[];
      await tester.pumpWidget(_host(
        _picker(),
        resolver: (ColorScheme scheme, String key) {
          keys.add(key);
          return key == zSignatureKey(_identity(_unit(_kId)))
              ? kSeamSpec
              : null;
        },
      ));
      await tester.pumpAndSettle();
      expect(keys, contains(zSignatureKey(_identity(_unit(_kId)))),
          reason: '🔴 le seam n\'est jamais interrogé pour cette pastille : '
              'clés reçues = $keys');
      expect(_paintedColors(tester), _colorsOf(kSeamSpec));
    });

    testWidgets('le seam PRIME le jeton — et le profil `neutral` ne l\'annule '
        'PAS', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        _picker(),
        extension: _themed(
          profile: ZReferenceProfile.neutral,
          palette: kTokenPalette,
        ),
        resolver: (ColorScheme scheme, String key) => kSeamSpec,
      ));
      await tester.pumpAndSettle();
      expect(_paintedColors(tester), _colorsOf(kSeamSpec));
    });

    testWidgets('le jeton `signaturePalette` PEINT la pastille — sous '
        '`neutral` aussi, le profil ne gouverne que la RÉFÉRENCE',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        _picker(),
        extension: _themed(
          profile: ZReferenceProfile.neutral,
          palette: kTokenPalette,
        ),
      ));
      await tester.pumpAndSettle();
      final int index = zPaletteIndexFor(
        _identity(_unit(_kId)),
        kTokenPalette.length,
      );
      expect(_paintedColors(tester), _colorsOf(kTokenPalette[index]));
    });

    testWidgets('la stratégie d\'index du thème est HONORÉE',
        (WidgetTester tester) async {
      final String identity = _identity(_unit(_kId));
      final int titleHash = zPaletteIndexFor(identity, kTokenPalette.length);
      final int fnv = zPaletteIndexFor(
        identity,
        kTokenPalette.length,
        strategy: ZPaletteIndexStrategy.stableFnv,
      );
      // Sans cette inégalité la garde serait VACUELLE : les deux stratégies
      // rendraient la même entrée et n'importe quel câblage passerait.
      expect(fnv, isNot(titleHash),
          reason: 'palette/identité mal choisies — la garde ne distingue '
              'plus les deux stratégies');

      await tester.pumpWidget(_host(
        _picker(),
        extension: _themed(
          palette: kTokenPalette,
          strategy: ZPaletteIndexStrategy.stableFnv,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_paintedColors(tester), _colorsOf(kTokenPalette[fnv]));
    });
  });

  group('🔒 INERTIE ABSOLUE — sans seam ni jeton, le rendu d\'aujourd\'hui',
      () {
    testWidgets('profil `legacy` : le dégradé de RÉFÉRENCE indexé par '
        '`titleHash`', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        _picker(),
        extension: _themed(profile: ZReferenceProfile.legacy),
      ));
      await tester.pumpAndSettle();
      final ZGradientSpec expected =
          zSignatureGradientFor(_identity(_unit(_kId)))!;
      expect(_paintedColors(tester), _colorsOf(expected));
      // …et c'est bien une entrée de la palette de RÉFÉRENCE, pas une couleur
      // fabriquée ailleurs.
      expect(ZSignaturePaletteReference.gradients, contains(expected));
    });

    testWidgets('profil par DÉFAUT (`neutral`) : AUCUNE pastille montée',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_picker()));
      await tester.pumpAndSettle();
      expect(_badge(), findsNothing);
    });

    testWidgets('profil `neutral` EXPLICITE : AUCUNE pastille montée',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        _picker(),
        extension: _themed(profile: ZReferenceProfile.neutral),
      ));
      await tester.pumpAndSettle();
      expect(_badge(), findsNothing);
    });
  });
}
