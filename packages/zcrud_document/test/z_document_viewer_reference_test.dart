// Garde de la RÉFÉRENCE SCALAIRE du chrome de lecture (lot Apparence E).
//
// Deux propriétés, et deux seulement :
//
//  (1) INERTIE ABSOLUE sous profil `neutral`. Les trois signatures figées
//      ci-dessous ont été relevées par une sonde jetable AVANT le lot, sur le
//      code d'origine, et comparées ici par ÉGALITÉ DE CHAÎNE — jamais par un
//      `contains`, jamais par un `<=`. Elles portent, pour chaque nœud
//      retenu : le type de widget, sa taille au dixième de point, et les
//      propriétés que le lot pourrait faire bouger (couleur, taille, marge,
//      contraintes, rayon d'encre, épaisseur de filet, texte, glyphe).
//      Un hôte qui pose `referenceProfile: neutral` doit retrouver EXACTEMENT
//      l'arbre d'avant le lot.
//
//  (2) Sous profil `legacy` (le DÉFAUT), la géométrie est celle de la
//      référence auditée — et le plancher tactile de 48 dp (AD-13) survit à
//      la fidélité.
//
// 🔴 La table de scalaires est relevée à la main sur le legacy IFFD (branche
// `main`) et FIGÉE ici avec ses `fichier:ligne` ; elle n'est jamais relue
// depuis `ZDocumentViewerReference`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_document/zcrud_document.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

// ── Table figée des mesures legacy ────────────────────────────────────────
// Chemin commun : lib/src/presentation/features/documents/widgets/
//                 document_viewer/
const double _kLegacyBarHeight = 56; // bottom_toolbar.dart:44 (:167)
const double _kLegacyBarIconSize = 20; // bottom_toolbar.dart:135
const double _kLegacySwatchSize = 40; // color_palette.dart:302-303
const double _kLegacyDividerThickness = 1; // bottom_toolbar.dart:174-176
const double _kLegacyPanelCornerRadius = 12; // color_palette.dart:108
const double _kWcagTouchTarget = 48; // AD-13 — jamais une valeur legacy

/// Nœuds retenus par la signature : tout ce que ce lot peut ajouter ou
/// modifier. La plomberie interne d'`InkWell`/`TextButton` (Focus,
/// MouseRegion, Actions…) appartient au SDK et n'est pas gelée : elle bougerait
/// à chaque montée de Flutter, et une garde qu'on ignore ne garde rien.
const Set<String> _kept = <String>{
  'ColoredBox',
  'DecoratedBox',
  'SizedBox',
  'ConstrainedBox',
  'Padding',
  'Icon',
  'Divider',
  'Text',
  'InkWell',
  'Column',
  'Row',
  'Wrap',
  'Align',
  'Center',
  'Stack',
  'Expanded',
  'ListView',
  'Semantics',
  'Material',
  'IconButton',
  'TextButton',
};

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';
String _hexN(Color? c) => c == null ? 'null' : _hex(c);

String signature(WidgetTester tester, Finder root) {
  final StringBuffer buffer = StringBuffer();
  final List<Element> elements = <Element>[];
  void walk(Element e) {
    elements.add(e);
    e.visitChildren(walk);
  }

  walk(tester.element(root));
  for (final Element e in elements) {
    final Widget w = e.widget;
    final String name = w.runtimeType.toString();
    if (!_kept.contains(name)) continue;
    final RenderObject? ro = e.renderObject;
    String rect = '-';
    if (ro is RenderBox && ro.hasSize) {
      rect = '${ro.size.width.toStringAsFixed(1)}x'
          '${ro.size.height.toStringAsFixed(1)}';
    }
    final List<String> props = <String>[];
    if (w is ColoredBox) props.add('color=${_hex(w.color)}');
    if (w is SizedBox) props.add('w=${w.width} h=${w.height}');
    if (w is ConstrainedBox) props.add('c=${w.constraints}');
    if (w is Padding) props.add('pad=${w.padding}');
    if (w is Icon) props.add('icon=${w.icon?.codePoint} size=${w.size}');
    if (w is Divider) {
      props.add('h=${w.height} t=${w.thickness} c=${_hexN(w.color)}');
    }
    if (w is Text) props.add('t=${w.data}');
    if (w is InkWell) props.add('br=${w.borderRadius}');
    if (w is DecoratedBox) props.add('deco=${w.decoration}');
    buffer.writeln('$name|$rect|${props.join(' ')}');
  }
  return buffer.toString();
}

Widget _host(Widget child, {ZReferenceProfile? profile}) {
  final Widget scoped = profile == null
      ? child
      : ZcrudScope(
          theme: ZcrudTheme(referenceProfile: profile),
          child: child,
        );
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 480, height: 600, child: scoped)),
    ),
  );
}

const ZDocumentViewerChrome _chrome = ZDocumentViewerChrome(
  topBar: Text('TOP'),
  bottomBar: Text('BOT'),
  document: Text('DOC'),
  pageNavigation: ZDocumentPageNavigation(
    previousPageLabel: 'PREV',
    nextPageLabel: 'NEXT',
  ),
);

List<ZDocumentAnnotation> _annotations() => const <ZDocumentAnnotation>[
      ZDocumentAnnotation(
        id: 'a1',
        docId: 'd',
        page: 3,
        colorKey: 'warning',
        text: 'un extrait',
      ),
      ZDocumentAnnotation(id: 'a2', docId: 'd', page: 4, colorKey: 'primary'),
    ];

Widget _panel() => ZAnnotationPanel(
      annotations: _annotations(),
      onSelect: (_) {},
    );

// ── Signatures relevées AVANT le lot (sonde jetable, code d'origine) ──────
// Largeur 480, hauteur 600, `MaterialApp > Scaffold > Center > SizedBox`.

const String _kChromeBefore = '''
ColoredBox|480.0x600.0|color=#FFFEF7FF
Column|480.0x600.0|
Text|480.0x20.0|t=TOP
Divider|480.0x1.0|h=1.0 t=null c=#FFCAC4D0
SizedBox|480.0x1.0|w=null h=1.0
Center|480.0x1.0|
Padding|480.0x1.0|pad=EdgeInsets.zero
ConstrainedBox|480.0x1.0|c=BoxConstraints(0.0<=w<=Infinity, h=1.0)
DecoratedBox|480.0x1.0|deco=BoxDecoration(border: Border(bottom: BorderSide(color: Color(alpha: 1.0000, red: 0.7922, green: 0.7686, blue: 0.8157, colorSpace: ColorSpace.sRGB))))
Padding|480.0x1.0|pad=EdgeInsets(0.0, 0.0, 0.0, 1.0)
ConstrainedBox|480.0x0.0|c=BoxConstraints(biggest)
Expanded|480.0x494.0|
Text|480.0x494.0|t=DOC
DecoratedBox|480.0x64.0|deco=BoxDecoration(color: Color(alpha: 1.0000, red: 0.9686, green: 0.9490, blue: 0.9804, colorSpace: ColorSpace.sRGB))
Padding|480.0x64.0|pad=EdgeInsetsDirectional(8.0, 8.0, 8.0, 8.0)
Row|464.0x48.0|
Semantics|110.4x48.0|
ConstrainedBox|110.4x48.0|c=BoxConstraints(48.0<=w<=Infinity, 48.0<=h<=Infinity)
TextButton|110.4x48.0|
Semantics|110.4x48.0|
ConstrainedBox|110.4x48.0|c=BoxConstraints(64.0<=w<=Infinity, 40.0<=h<=Infinity)
Material|110.4x48.0|
InkWell|110.4x48.0|br=null
Semantics|110.4x48.0|
Semantics|110.4x48.0|
Padding|110.4x48.0|pad=EdgeInsetsDirectional(12.0, 8.0, 16.0, 8.0)
Align|82.4x32.0|
Row|82.4x20.0|
Icon|18.0x18.0|icon=57694 size=null
Semantics|18.0x18.0|
SizedBox|18.0x18.0|w=18.0 h=18.0
Center|18.0x18.0|
Text|56.4x20.0|t=PREV
Semantics|110.4x48.0|
ConstrainedBox|110.4x48.0|c=BoxConstraints(48.0<=w<=Infinity, 48.0<=h<=Infinity)
TextButton|110.4x48.0|
Semantics|110.4x48.0|
ConstrainedBox|110.4x48.0|c=BoxConstraints(64.0<=w<=Infinity, 40.0<=h<=Infinity)
Material|110.4x48.0|
InkWell|110.4x48.0|br=null
Semantics|110.4x48.0|
Semantics|110.4x48.0|
Padding|110.4x48.0|pad=EdgeInsetsDirectional(12.0, 8.0, 16.0, 8.0)
Align|82.4x32.0|
Row|82.4x20.0|
Icon|18.0x18.0|icon=57695 size=null
Semantics|18.0x18.0|
SizedBox|18.0x18.0|w=18.0 h=18.0
Center|18.0x18.0|
Text|56.4x20.0|t=NEXT
Divider|480.0x1.0|h=1.0 t=null c=#FFCAC4D0
SizedBox|480.0x1.0|w=null h=1.0
Center|480.0x1.0|
Padding|480.0x1.0|pad=EdgeInsets.zero
ConstrainedBox|480.0x1.0|c=BoxConstraints(0.0<=w<=Infinity, h=1.0)
DecoratedBox|480.0x1.0|deco=BoxDecoration(border: Border(bottom: BorderSide(color: Color(alpha: 1.0000, red: 0.7922, green: 0.7686, blue: 0.8157, colorSpace: ColorSpace.sRGB))))
Padding|480.0x1.0|pad=EdgeInsets(0.0, 0.0, 0.0, 1.0)
ConstrainedBox|480.0x0.0|c=BoxConstraints(biggest)
Text|480.0x20.0|t=BOT
''';

const String _kPanelBefore = '''
ListView|480.0x600.0|
Semantics|480.0x600.0|
Semantics|480.0x56.0|
Material|480.0x56.0|
InkWell|480.0x56.0|br=null
Semantics|480.0x56.0|
Semantics|480.0x56.0|
ConstrainedBox|480.0x56.0|c=BoxConstraints(0.0<=w<=Infinity, 48.0<=h<=Infinity)
Padding|480.0x56.0|pad=EdgeInsetsDirectional(12.0, 8.0, 12.0, 8.0)
Row|456.0x40.0|
Icon|20.0x20.0|icon=61186 size=20.0
Semantics|20.0x20.0|
SizedBox|20.0x20.0|w=20.0 h=20.0
Center|20.0x20.0|
SizedBox|8.0x0.0|w=8.0 h=null
ColoredBox|24.0x24.0|color=#FFE6E0E9
SizedBox|24.0x24.0|w=24.0 h=24.0
SizedBox|4.0x0.0|w=4.0 h=null
Text|99.8x20.0|t=warning
SizedBox|8.0x0.0|w=8.0 h=null
Expanded|292.3x40.0|
Column|292.3x40.0|
Text|256.5x20.0|t=highlight · page 3
Text|142.5x20.0|t=un extrait
Semantics|480.0x56.0|
Material|480.0x56.0|
InkWell|480.0x56.0|br=null
Semantics|480.0x56.0|
Semantics|480.0x56.0|
ConstrainedBox|480.0x56.0|c=BoxConstraints(0.0<=w<=Infinity, 48.0<=h<=Infinity)
Padding|480.0x56.0|pad=EdgeInsetsDirectional(12.0, 8.0, 12.0, 8.0)
Row|456.0x40.0|
Icon|20.0x20.0|icon=61186 size=20.0
Semantics|20.0x20.0|
SizedBox|20.0x20.0|w=20.0 h=20.0
Center|20.0x20.0|
SizedBox|8.0x0.0|w=8.0 h=null
ColoredBox|24.0x24.0|color=#FFEADDFF
SizedBox|24.0x24.0|w=24.0 h=24.0
SizedBox|4.0x0.0|w=4.0 h=null
Text|99.8x20.0|t=primary
SizedBox|8.0x0.0|w=8.0 h=null
Expanded|292.3x40.0|
Column|292.3x40.0|
Text|256.5x20.0|t=highlight · page 4
Text|128.3x20.0|t=(no text)
''';

/// Les huit fonds de swatch relevés AVANT le lot, dans l'ordre de
/// `ZColorPalette.defaultStudy().keys`.
const List<String> _kToolbarSwatchesBefore = <String>[
  '#FFEADDFF', // primary   — rôle M3
  '#FFE8DEF8', // secondary — rôle M3
  '#FFFFD8E4', // tertiary  — rôle M3
  '#FFF9DEDC', // success   — slot indexé (rang 3)
  '#FFE6E0E9', // warning   — slot indexé (rang 4)
  '#FFEADDFF', // danger    — slot indexé (rang 5)
  '#FFE8DEF8', // info      — slot indexé (rang 6)
  '#FFE6E0E9', // neutral   — rôle M3
];

void main() {
  group('table figée des scalaires legacy (fichier:ligne)', () {
    test('la référence n\'a pas dérivé', () {
      expect(ZDocumentViewerReference.barHeight, _kLegacyBarHeight,
          reason: 'bottom_toolbar.dart:44 (_toolBarSectionHeight = 56.0)');
      expect(ZDocumentViewerReference.barIconSize, _kLegacyBarIconSize,
          reason: 'bottom_toolbar.dart:135 (size: 20)');
      expect(ZDocumentViewerReference.swatchSize, _kLegacySwatchSize,
          reason: 'color_palette.dart:302-303 (ToolbarItem 40x40)');
      expect(ZDocumentViewerReference.dividerThickness,
          _kLegacyDividerThickness,
          reason: 'bottom_toolbar.dart:174-176 (thickness: 1)');
      expect(ZDocumentViewerReference.panelCornerRadius,
          _kLegacyPanelCornerRadius,
          reason: 'color_palette.dart:108 (BorderRadius.circular(12))');
      expect(ZDocumentViewerReference.minTouchTarget, _kWcagTouchTarget,
          reason: 'AD-13 — plancher tactile, PAS une valeur legacy');
    });

    test('le fichier de référence scalaire ne porte AUCUNE couleur', () {
      // Ce que la garde de style vérifie par le disque, énoncé ici comme
      // contrat : la référence GÉOMÉTRIE ne doit jamais devenir une porte
      // d'entrée pour un hex (elle n'est pas dans la liste d'exemption).
      expect(zDocumentLegacyOrNeutral<double>(null, 1, 2), 1);
      expect(
        zDocumentLegacyOrNeutral<double>(ZReferenceProfile.legacy, 1, 2),
        1,
      );
      expect(
        zDocumentLegacyOrNeutral<double>(ZReferenceProfile.neutral, 1, 2),
        2,
      );
    });

    test('la pastille legacy est plus petite que la cible tactile', () {
      // C'est ce qui rend l'application de la référence COMPATIBLE avec AD-13 :
      // la pastille rétrécit, la cible non.
      expect(ZDocumentViewerReference.swatchSize,
          lessThan(ZDocumentViewerReference.minTouchTarget));
      expect(ZDocumentViewerReference.barHeight,
          lessThan(3 * ZDocumentViewerReference.minTouchTarget));
    });
  });

  group('INERTIE ABSOLUE sous profil neutral — arbre STRICTEMENT identique '
      'à celui d\'avant le lot', () {
    testWidgets('ZDocumentViewerChrome', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(_chrome, profile: ZReferenceProfile.neutral),
      );
      expect(
        signature(tester, find.byType(ZDocumentViewerChrome)),
        _kChromeBefore,
        reason: '🔴 le profil neutral n\'est PLUS inerte : l\'arbre du chrome '
            'diffère de celui relevé avant le lot.',
      );
    });

    testWidgets('ZAnnotationPanel', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(_panel(), profile: ZReferenceProfile.neutral),
      );
      expect(
        signature(tester, find.byType(ZAnnotationPanel)),
        _kPanelBefore,
        reason: '🔴 le profil neutral n\'est PLUS inerte : l\'arbre du panneau '
            'diffère de celui relevé avant le lot.',
      );
    });

    testWidgets('ZAnnotationToolbar — fonds de swatch et taille de pastille',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZAnnotationToolbar(), profile: ZReferenceProfile.neutral),
      );
      final ZColorPalette palette = ZColorPalette.defaultStudy();
      final List<String> rendus = <String>[];
      for (final String key in palette.keys) {
        final Finder fill =
            find.byKey(ValueKey<String>('$kAnnotationSwatchFillKeyPrefix$key'));
        rendus.add(_hex(tester.widget<ColoredBox>(fill).color));
        // La pastille reprend la pleine cible, comme avant le lot.
        expect(tester.getSize(fill), const Size(48, 48), reason: 'swatch $key');
      }
      expect(rendus, _kToolbarSwatchesBefore,
          reason: '🔴 le profil neutral n\'est PLUS inerte : les fonds de '
              'swatch diffèrent de ceux relevés avant le lot.');
    });
  });

  group('profil legacy (le DÉFAUT) — la géométrie de référence est peinte', () {
    testWidgets('la pastille rétrécit à la taille de référence, la CIBLE reste '
        'à 48 dp', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const ZAnnotationToolbar()));
      final ZColorPalette palette = ZColorPalette.defaultStudy();
      for (final String key in palette.keys) {
        expect(
          tester.getSize(
            find.byKey(ValueKey<String>('$kAnnotationSwatchFillKeyPrefix$key')),
          ),
          const Size(_kLegacySwatchSize, _kLegacySwatchSize),
          reason: 'pastille $key',
        );
        expect(
          tester.getSize(
            find.byKey(ValueKey<String>('$kAnnotationSwatchKeyPrefix$key')),
          ),
          const Size(_kWcagTouchTarget, _kWcagTouchTarget),
          reason: 'CIBLE $key — AD-13 prime sur la fidélité',
        );
      }
    });

    testWidgets('le filet du chrome porte l\'épaisseur de référence',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_chrome));
      final Iterable<Divider> dividers =
          tester.widgetList<Divider>(find.byType(Divider));
      expect(dividers, hasLength(2));
      for (final Divider d in dividers) {
        expect(d.thickness, _kLegacyDividerThickness);
        expect(d.height, _kLegacyDividerThickness);
      }
    });

    testWidgets('les glyphes de navigation prennent la taille de référence, '
        'et la barre son plancher', (WidgetTester tester) async {
      await tester.pumpWidget(_host(_chrome));
      for (final IconData glyph in <IconData>[
        Icons.chevron_left,
        Icons.chevron_right,
      ]) {
        expect(tester.widget<Icon>(find.byIcon(glyph)).size,
            _kLegacyBarIconSize);
      }
      // Le plancher est POSÉ (un ConstrainedBox de la bonne valeur existe)…
      final Finder plancher = find.byWidgetPredicate((Widget w) =>
          w is ConstrainedBox && w.constraints.minHeight == _kLegacyBarHeight);
      expect(plancher, findsOneWidget);
      // …et il ne comprime RIEN : la barre reste au-dessus de ce que deux
      // cibles de 48 dp et 8 dp de marge exigent. C'est le cœur de l'arbitrage
      // « la référence est un plancher, AD-13 est le sol ».
      expect(tester.getSize(plancher).height,
          greaterThanOrEqualTo(_kWcagTouchTarget + 16));
    });

    testWidgets('l\'encre d\'une entrée de panneau prend le rayon de référence',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(_panel()));
      for (final InkWell ink in tester.widgetList<InkWell>(
        find.descendant(
          of: find.byType(ZAnnotationPanel),
          matching: find.byType(InkWell),
        ),
      )) {
        expect(
          ink.borderRadius,
          BorderRadius.circular(_kLegacyPanelCornerRadius),
        );
      }
    });
  });

  group('priorité PARAMÈTRE > référence, dans les deux profils', () {
    testWidgets('swatchSize posé l\'emporte, même sous neutral',
        (WidgetTester tester) async {
      for (final ZReferenceProfile profile in ZReferenceProfile.values) {
        await tester.pumpWidget(
          _host(const ZAnnotationToolbar(swatchSize: 30), profile: profile),
        );
        expect(
          tester.getSize(
            find.byKey(
              const ValueKey<String>('${kAnnotationSwatchFillKeyPrefix}primary'),
            ),
          ),
          const Size(30, 30),
          reason: 'profil $profile',
        );
      }
    });

    testWidgets('entryCornerRadius posé l\'emporte, même sous neutral',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZAnnotationPanel(
            annotations: _annotations(),
            onSelect: (_) {},
            entryCornerRadius: 3,
          ),
          profile: ZReferenceProfile.neutral,
        ),
      );
      final InkWell ink = tester.widgetList<InkWell>(
        find.descendant(
          of: find.byType(ZAnnotationPanel),
          matching: find.byType(InkWell),
        ),
      ).first;
      expect(ink.borderRadius, BorderRadius.circular(3));
    });

    testWidgets('navigationIconSize / navigationBarMinHeight posés l\'emportent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZDocumentViewerChrome(
            pageNavigation: ZDocumentPageNavigation(
              previousPageLabel: 'P',
              nextPageLabel: 'N',
            ),
            navigationIconSize: 11,
            navigationBarMinHeight: 99,
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.chevron_left)).size, 11);
      expect(
        find.byWidgetPredicate(
            (Widget w) => w is ConstrainedBox && w.constraints.minHeight == 99),
        findsOneWidget,
      );
    });
  });
}
