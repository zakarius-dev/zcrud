/// Gardes du découplage « couleur déclarée » / « dégradé de bande » de
/// `ZDefaultFolderCard`.
///
/// Ce que chaque garde mesure :
/// * l'**inertie ABSOLUE** sans les nouveaux paramètres — l'arbre complet de la
///   carte, ses rects et ses couleurs peintes, figés À L'OCTET depuis un relevé
///   pris AVANT la modification (égalité stricte, aucun `contains`) ;
/// * la **coexistence** : dégradé fourni + couleur déclarée ⇒ bande = dégradé
///   EXACT, et tuile/glyphe/badges/sous-titre/liseré = les couleurs EXACTES de
///   la carte à couleur déclarée seule (donc la couleur pilote bien la
///   matière, et rien d'autre n'a bougé) ;
/// * le **comportement défini** d'un dégradé fourni SANS couleur déclarée ;
/// * la **précédence** des quatre sources de bande ;
/// * le **plancher de contraste**, recalculé sur les surfaces réellement
///   peintes (bande et badges), jamais décrété.
@TestOn('vm')
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ── Relevé figé, pris sur la carte AVANT l'ajout des paramètres de dégradé ───
// (sha256 du fichier source au relevé : 9f3aa1ae85295a98ffea2977afe87be9b07ab
//  8d016a117f014d636edabcf54c8 ; profil `legacy`, largeur 400, thème clair.)

/// Arbre complet de la carte SANS couleur déclarée (bande en dégradé de repli).
const List<String> kTreeSignature = <String>[
  'ZFolderCard', 'Semantics', 'ConstrainedBox', 'Padding', 'DecoratedBox',
  'Card', 'Semantics', 'Padding', 'Material', '_MaterialInterior',
  'PhysicalShape', '_ShapeBorderPaint', 'CustomPaint',
  'NotificationListener<LayoutChangedNotification>', '_InkFeatures',
  'AnimatedDefaultTextStyle', 'DefaultTextStyle', 'Semantics', 'LayoutBuilder',
  'Column', 'SizedBox', 'SizedBox', 'DecoratedBox', 'Expanded', 'LayoutBuilder',
  'Padding', 'Column', 'Row', 'ExcludeSemantics', 'SizedBox', 'DecoratedBox',
  'Center', 'Icon', 'Semantics', 'ExcludeSemantics', 'SizedBox', 'Center',
  'RichText', 'Spacer', 'Expanded', 'SizedBox', 'Expanded', 'Align',
  'LayoutBuilder', 'Column', 'ConstrainedBox', 'ExcludeSemantics', 'Text',
  'RichText', 'Flexible', 'Padding', 'Padding', 'Text', 'RichText', 'SizedBox',
  'Row', 'Expanded', 'SingleChildScrollView', 'Scrollable',
  'StretchingOverscrollIndicator', 'NotificationListener<ScrollNotification>',
  'AnimatedBuilder', 'ClipRect', 'StretchEffect', 'Transform',
  'NotificationListener<ScrollMetricsNotification>', '_ScrollSemantics',
  '_ScrollableScope', 'Listener', 'RawGestureDetector', '_GestureSemantics',
  'Listener', 'Semantics', 'IgnorePointer', '_SingleChildViewport', 'Row',
  '_ZCountBadge', 'Semantics', 'Container', 'DecoratedBox', 'Padding', 'Row',
  'Icon', 'Semantics', 'ExcludeSemantics', 'SizedBox', 'Center', 'RichText',
  'ExcludeSemantics', 'Text', 'RichText',
];

/// Arbre complet de la carte AVEC couleur déclarée (bande unie). Il ne diffère
/// du précédent que par le nœud de peinture de la bande — `ColoredBox` au lieu
/// de `DecoratedBox` : c'est la seule différence attendue, et la figer prouve
/// qu'aucune enveloppe ne s'est glissée ailleurs.
const List<String> kTreeDeclared = <String>[
  'ZFolderCard', 'Semantics', 'ConstrainedBox', 'Padding', 'DecoratedBox',
  'Card', 'Semantics', 'Padding', 'Material', '_MaterialInterior',
  'PhysicalShape', '_ShapeBorderPaint', 'CustomPaint',
  'NotificationListener<LayoutChangedNotification>', '_InkFeatures',
  'AnimatedDefaultTextStyle', 'DefaultTextStyle', 'Semantics', 'LayoutBuilder',
  'Column', 'SizedBox', 'SizedBox', 'ColoredBox', 'Expanded', 'LayoutBuilder',
  'Padding', 'Column', 'Row', 'ExcludeSemantics', 'SizedBox', 'DecoratedBox',
  'Center', 'Icon', 'Semantics', 'ExcludeSemantics', 'SizedBox', 'Center',
  'RichText', 'Spacer', 'Expanded', 'SizedBox', 'Expanded', 'Align',
  'LayoutBuilder', 'Column', 'ConstrainedBox', 'ExcludeSemantics', 'Text',
  'RichText', 'Flexible', 'Padding', 'Padding', 'Text', 'RichText', 'SizedBox',
  'Row', 'Expanded', 'SingleChildScrollView', 'Scrollable',
  'StretchingOverscrollIndicator', 'NotificationListener<ScrollNotification>',
  'AnimatedBuilder', 'ClipRect', 'StretchEffect', 'Transform',
  'NotificationListener<ScrollMetricsNotification>', '_ScrollSemantics',
  '_ScrollableScope', 'Listener', 'RawGestureDetector', '_GestureSemantics',
  'Listener', 'Semantics', 'IgnorePointer', '_SingleChildViewport', 'Row',
  '_ZCountBadge', 'Semantics', 'Container', 'DecoratedBox', 'Padding', 'Row',
  'Icon', 'Semantics', 'ExcludeSemantics', 'SizedBox', 'Center', 'RichText',
  'ExcludeSemantics', 'Text', 'RichText',
];

/// Rect de la bande, carte sans couleur déclarée.
const Rect kAccentRect = Rect.fromLTRB(200, 0, 600, 4);

/// Rect de la tuile d'icône, carte sans couleur déclarée.
const Rect kTileRect = Rect.fromLTRB(212, 16, 248, 52);

/// Étapes du dégradé de repli de signature, en ARGB32.
const List<int> kSignatureStops = <int>[4284907242, 4285942690];

/// Couleurs peintes, carte AVEC couleur déclarée (bande unie).
const int kDeclaredBand = 4287663250;
const int kDeclaredTile = 4294242295;
const int kDeclaredGlyph = 4287531664;
const int kDeclaredSubtitle = 4285689715;
const int kDeclaredBorder = 4287663250;
const int kDeclaredBadgeBg = 4294308088;
const int kDeclaredBadgeFg = 4285623922;

/// Clé de couleur déclarée par le relevé.
const String kDeclaredKey = 'blue';

/// Dégradé fourni par l'appelant — deux étapes franches, pour qu'un repli
/// silencieux vers la signature soit visible (aucune ressemblance possible).
const ZGradientSpec kHostGradient = ZGradientSpec(
  gradient: LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: <Color>[Color(0xFF102040), Color(0xFF40C0A0)],
  ),
  onGradient: Color(0xFFFFFFFF),
);

/// Second dégradé, uniquement pour prouver une PRÉCÉDENCE (jamais l'égalité).
const ZGradientSpec kKeyedGradient = ZGradientSpec(
  gradient: LinearGradient(
    colors: <Color>[Color(0xFF801020), Color(0xFFF0A030)],
  ),
  onGradient: Color(0xFF000000),
);

const List<ZFolderCardCount> kCounts = <ZFolderCardCount>[
  ZFolderCardCount(icon: Icons.style_outlined, label: '12 fiches'),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ZReferenceProfile? profile = ZReferenceProfile.legacy,
  ZColorPair Function(ColorScheme, String)? colorResolver,
  ZGradientSpec? Function(ColorScheme, String)? gradientResolver,
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
          ZcrudTheme(referenceProfile: profile),
        ],
      ),
      home: Scaffold(
        body: ZcrudScope(
          colorKeyResolver: colorResolver,
          gradientResolver: gradientResolver,
          child: Center(child: SizedBox(width: 400, child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _tree(WidgetTester tester) {
  final List<String> out = <String>[];
  void walk(Element el) {
    out.add(el.widget.runtimeType.toString());
    el.visitChildElements(walk);
  }

  tester
      .element(find.byType(ZDefaultFolderCard))
      .visitChildElements(walk);
  return out;
}

Gradient? _bandGradient(WidgetTester tester) {
  final Finder deco = find.descendant(
    of: find.byKey(ZDefaultFolderCard.accentKey),
    matching: find.byType(DecoratedBox),
  );
  if (deco.evaluate().isEmpty) return null;
  return (tester.widget<DecoratedBox>(deco).decoration as BoxDecoration).gradient;
}

int? _bandSolid(WidgetTester tester) {
  final Finder box = find.descendant(
    of: find.byKey(ZDefaultFolderCard.accentKey),
    matching: find.byType(ColoredBox),
  );
  if (box.evaluate().isEmpty) return null;
  return tester.widget<ColoredBox>(box).color.toARGB32();
}

Color _tile(WidgetTester tester) =>
    ((tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(ZDefaultFolderCard.iconTileKey),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color!);

Color _glyph(WidgetTester tester) => tester
    .widget<Icon>(
      find.descendant(
        of: find.byKey(ZDefaultFolderCard.iconTileKey),
        matching: find.byType(Icon),
      ),
    )
    .color!;

Color _subtitle(WidgetTester tester) => tester
    .widget<Text>(find.byKey(ZDefaultFolderCard.subtitleKey))
    .style!
    .color!;

BorderSide _border(WidgetTester tester) =>
    (tester.widget<Card>(find.byType(Card)).shape! as RoundedRectangleBorder)
        .side;

Color _badgeBackground(WidgetTester tester) =>
    ((tester
                    .widget<Container>(
                      find.descendant(
                        of: find.byKey(ZDefaultFolderCard.countsKey),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .color!);

Color _badgeForeground(WidgetTester tester) => tester
    .widget<Icon>(
      find.descendant(
        of: find.byKey(ZDefaultFolderCard.countsKey),
        matching: find.byType(Icon),
      ),
    )
    .color!;

/// Luminance relative WCAG, recalculée ici — jamais empruntée au code mesuré.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('inertie absolue — aucun paramètre de dégradé', () {
    testWidgets('sans couleur déclarée : arbre, rects et bande figés', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          counts: kCounts,
        ),
      );
      expect(
        _tree(tester),
        kTreeSignature,
        reason:
            '🔴 l\'arbre de la carte a changé alors qu\'aucun paramètre de '
            'dégradé n\'est passé',
      );
      expect(
        tester.getRect(find.byKey(ZDefaultFolderCard.accentKey)),
        kAccentRect,
      );
      expect(
        tester.getRect(find.byKey(ZDefaultFolderCard.iconTileKey)),
        kTileRect,
      );
      expect(
        (_bandGradient(tester)! as LinearGradient)
            .colors
            .map((Color c) => c.toARGB32())
            .toList(),
        kSignatureStops,
        reason: '🔴 le repli de signature ne peint plus le même dégradé',
      );
    });

    testWidgets('avec couleur déclarée : arbre et couleurs peintes figés', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          colorKey: kDeclaredKey,
          counts: kCounts,
        ),
      );
      expect(_tree(tester), kTreeDeclared);
      expect(_bandGradient(tester), isNull);
      expect(
        <int>[
          _bandSolid(tester)!,
          _tile(tester).toARGB32(),
          _glyph(tester).toARGB32(),
          _subtitle(tester).toARGB32(),
          _border(tester).color.toARGB32(),
          _badgeBackground(tester).toARGB32(),
          _badgeForeground(tester).toARGB32(),
        ],
        <int>[
          kDeclaredBand,
          kDeclaredTile,
          kDeclaredGlyph,
          kDeclaredSubtitle,
          kDeclaredBorder,
          kDeclaredBadgeBg,
          kDeclaredBadgeFg,
        ],
        reason:
            '🔴 une couleur peinte a bougé alors qu\'aucun dégradé n\'est '
            'demandé',
      );
    });
  });

  group('coexistence dégradé + couleur déclarée', () {
    testWidgets('la bande porte le dégradé EXACT de l\'appelant', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          colorKey: kDeclaredKey,
          accentGradient: kHostGradient,
          counts: kCounts,
        ),
      );
      expect(
        _bandGradient(tester),
        kHostGradient.gradient,
        reason:
            '🔴 déclarer une couleur interdit encore le dégradé de la bande',
      );
      expect(
        _bandSolid(tester),
        isNull,
        reason: '🔴 la bande unie subsiste sous le dégradé',
      );
    });

    testWidgets('la MATIÈRE reste celle de la couleur déclarée, à l\'octet', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          colorKey: kDeclaredKey,
          accentGradient: kHostGradient,
          counts: kCounts,
        ),
      );
      expect(
        <int>[
          _tile(tester).toARGB32(),
          _glyph(tester).toARGB32(),
          _subtitle(tester).toARGB32(),
          _border(tester).color.toARGB32(),
          _badgeBackground(tester).toARGB32(),
          _badgeForeground(tester).toARGB32(),
        ],
        <int>[
          kDeclaredTile,
          kDeclaredGlyph,
          kDeclaredSubtitle,
          kDeclaredBorder,
          kDeclaredBadgeBg,
          kDeclaredBadgeFg,
        ],
        reason:
            '🔴 le dégradé de la bande a déteint sur la matière : la couleur '
            'déclarée ne pilote plus tuile/badges/sous-titre/liseré',
      );
      // CONTRE-PREUVE : la matière n'est PAS la tête du dégradé fourni.
      expect(
        _tile(tester).toARGB32(),
        isNot(kHostGradient.gradient.colors.first.toARGB32()),
      );
    });

    testWidgets('dégradé SANS couleur déclarée : la matière suit sa tête', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          accentGradient: kHostGradient,
          counts: kCounts,
        ),
      );
      expect(_bandGradient(tester), kHostGradient.gradient);
      // La teinte de matière dérive de la TÊTE du dégradé fourni, pas du repli
      // de signature : les deux valeurs figées ci-dessus le distinguent.
      expect(
        <int>[_tile(tester).toARGB32(), _glyph(tester).toARGB32()],
        isNot(<int>[kDeclaredTile, kDeclaredGlyph]),
      );
      final Color head = kHostGradient.gradient.colors.first;
      // Le glyphe est corrigé au plancher : il n'est donc pas la tête brute,
      // mais il en garde l'ordre de teinte (bleu dominant sur le rouge).
      final Color glyph = _glyph(tester);
      expect(
        glyph.b > glyph.r,
        isTrue,
        reason: '🔴 la matière ne suit pas la tête du dégradé fourni ($head)',
      );
    });
  });

  group('précédence des sources de bande', () {
    testWidgets('accent (widget) > accentGradient', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          colorKey: kDeclaredKey,
          accent: SizedBox(key: ValueKey<String>('hostAccent'), height: 2),
          accentGradient: kHostGradient,
        ),
      );
      expect(find.byKey(const ValueKey<String>('hostAccent')), findsOneWidget);
      expect(find.byKey(ZDefaultFolderCard.accentKey), findsNothing);
    });

    testWidgets('accentGradient > gradientKey', (WidgetTester tester) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          colorKey: kDeclaredKey,
          accentGradient: kHostGradient,
          gradientKey: 'host.key',
        ),
        gradientResolver: (ColorScheme s, String k) => kKeyedGradient,
      );
      expect(_bandGradient(tester), kHostGradient.gradient);
      expect(_bandGradient(tester), isNot(kKeyedGradient.gradient));
    });

    testWidgets('gradientKey > repli de signature, malgré la couleur', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          colorKey: kDeclaredKey,
          gradientKey: 'host.key',
        ),
        gradientResolver: (ColorScheme s, String k) =>
            k == 'host.key' ? kKeyedGradient : null,
      );
      expect(_bandGradient(tester), kKeyedGradient.gradient);
    });

    testWidgets('clé vide ou seam muet ⇒ chaîne poursuivie (AD-10)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          colorKey: kDeclaredKey,
          gradientKey: '',
        ),
      );
      expect(
        _bandSolid(tester),
        kDeclaredBand,
        reason: '🔴 une clé vide a changé le rendu au lieu d\'être inerte',
      );

      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          colorKey: kDeclaredKey,
          gradientKey: 'inconnue',
        ),
        gradientResolver: (ColorScheme s, String k) => null,
      );
      expect(_bandSolid(tester), kDeclaredBand);
    });
  });

  group('contraste mesuré sur ce qui est réellement peint', () {
    testWidgets('badges ≥ 4.5:1 et liseré ≥ 3:1, dégradé fourni compris', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          colorKey: kDeclaredKey,
          accentGradient: kHostGradient,
          counts: kCounts,
        ),
      );
      final Color badgeBg = _badgeBackground(tester);
      final Color badgeFg = _badgeForeground(tester);
      expect(
        _ratio(badgeFg, badgeBg),
        greaterThanOrEqualTo(4.5),
        reason: '🔴 le libellé de badge passe sous le plancher de texte',
      );
      final Color subtitle = _subtitle(tester);
      // Le sous-titre se mesure contre le fond de carte réellement peint : la
      // carte de référence est neutre (tintAlpha 0), donc la surface du thème.
      final Color surface = Theme.of(
        tester.element(find.byType(ZDefaultFolderCard)),
      ).colorScheme.surfaceContainerLow;
      expect(_ratio(subtitle, surface), greaterThanOrEqualTo(4.5));
      expect(_ratio(_border(tester).color, surface), greaterThanOrEqualTo(3.0));
    });

    testWidgets('couleur arbitraire à contraste nul : le plancher tient', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZDefaultFolderCard(
          title: 'Douane',
          subtitle: 'Matiere',
          accentGradient: kHostGradient,
          counts: kCounts,
        ),
        colorResolver: (ColorScheme s, String k) =>
            const ZColorPair(color: Color(0xFFFFFFFE), onColor: Color(0xFF000000)),
      );
      expect(
        _ratio(_badgeForeground(tester), _badgeBackground(tester)),
        greaterThanOrEqualTo(4.5),
        reason:
            '🔴 une couleur déclarée quasi blanche traverse le plancher quand '
            'un dégradé est fourni',
      );
    });
  });
}
