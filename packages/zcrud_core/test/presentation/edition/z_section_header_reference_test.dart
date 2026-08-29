// GARDE — INERTIE ABSOLUE de l'en-tête de section sous le profil `neutral`,
// et rendu de RÉFÉRENCE sous le profil `legacy` (le défaut).
//
// C'est la garde de l'ÉCHAPPATOIRE. Les signatures ci-dessous ont été relevées
// AVANT le lot (socle sans profil, sans palette signature) et sont FIGÉES ici :
// sous `neutral`, l'arbre rendu doit leur être STRICTEMENT ÉGAL — même
// enchaînement de widgets, mêmes rectangles au dixième de point, mêmes insets.
// Une inégalité, si petite soit-elle, signifie que l'hôte qui a demandé le
// profil neutre subit quand même la référence.
//
// Le pendant `legacy` vérifie que la bande et la tuile SONT bien là, et que la
// couleur de la bande est EXACTEMENT `gradients[hash % 5].colors.first` — pas
// « une couleur », pas « une teinte proche ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
  ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
  ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
];

const _sections = <ZEditionSection>[
  ZEditionSection(title: 'Alpha', fields: <String>['a']),
  ZEditionSection(title: 'Beta', fields: <String>['b'], icon: Icons.folder),
  ZEditionSection(title: 'Gamma', fields: <String>['c'], collapsible: true),
];

/// Types de widget RETENUS dans la signature : ceux qui portent la géométrie
/// ou une décoration. La plomberie d'`InkWell` (Focus, MouseRegion, Actions…)
/// est écartée — elle appartient au SDK, pas à ce paquet, et sa dérive ne
/// dirait rien du lot. Tout ce que le lot peut ajouter (Column, SizedBox,
/// ColoredBox, DecoratedBox, Center) est, lui, RETENU.
const Set<String> _retenus = <String>{
  'Padding',
  'Row',
  'Column',
  'Text',
  'Icon',
  'SizedBox',
  'ColoredBox',
  'DecoratedBox',
  'ConstrainedBox',
  'Expanded',
  'Spacer',
  'ClipRRect',
  'Center',
  'RichText',
  '_SectionHeader',
  '_CollapsibleSectionHeader',
};

class _Fige {
  const _Fige({required this.entete, required this.repliable});
  final String entete;
  final String repliable;
}

/// Signatures relevées AVANT le lot, socle nu (aucun profil, aucune palette).
const Map<String, _Fige> _avant = <String, _Fige>{
  '320.0': _Fige(
    entete: r'''
ROOT _SectionHeader
  _SectionHeader 12.0,12.0 296.0x44.0
    Padding 12.0,12.0 296.0x44.0 pad=EdgeInsetsDirectional(16.0, 16.0, 16.0, 8.0)
      Text 28.0,28.0 264.0x20.0 text=Alpha
        RichText 28.0,28.0 264.0x20.0
ROOT _SectionHeader
  _SectionHeader 12.0,112.0 296.0x48.0
    Padding 12.0,112.0 296.0x48.0 pad=EdgeInsetsDirectional(16.0, 16.0, 16.0, 8.0)
      Row 28.0,128.0 264.0x24.0
        Padding 28.0,128.0 32.0x24.0 pad=EdgeInsetsDirectional(0.0, 0.0, 8.0, 0.0)
          Icon 28.0,128.0 24.0x24.0 icon=IconData(U+0E2A3) color=null size=null
                SizedBox 28.0,128.0 24.0x24.0 h=24.0 w=24.0
                  Center 28.0,128.0 24.0x24.0
                    RichText 28.0,128.0 24.0x24.0
        Expanded 60.0,130.0 232.0x20.0
          Text 60.0,130.0 232.0x20.0 text=Beta
            RichText 60.0,130.0 232.0x20.0
''',
    repliable: r'''
ROOT _CollapsibleSectionHeader
  _CollapsibleSectionHeader 12.0,216.0 296.0x48.0
                                    ConstrainedBox 12.0,216.0 296.0x48.0
                                      Padding 12.0,216.0 296.0x48.0 pad=EdgeInsetsDirectional(16.0, 8.0, 16.0, 8.0)
                                        Row 28.0,224.0 264.0x32.0
                                          Expanded 28.0,230.0 240.0x20.0
                                            Text 28.0,230.0 240.0x20.0 text=Gamma
                                              RichText 28.0,230.0 240.0x20.0
                                          Icon 268.0,228.0 24.0x24.0 icon=IconData(U+0E245) color=null size=null
                                                SizedBox 268.0,228.0 24.0x24.0 h=24.0 w=24.0
                                                  Center 268.0,228.0 24.0x24.0
                                                    RichText 268.0,228.0 24.0x24.0
''',
  ),
  '480.0': _Fige(
    entete: r'''
ROOT _SectionHeader
  _SectionHeader 12.0,12.0 456.0x44.0
    Padding 12.0,12.0 456.0x44.0 pad=EdgeInsetsDirectional(16.0, 16.0, 16.0, 8.0)
      Text 28.0,28.0 424.0x20.0 text=Alpha
        RichText 28.0,28.0 424.0x20.0
ROOT _SectionHeader
  _SectionHeader 12.0,112.0 456.0x48.0
    Padding 12.0,112.0 456.0x48.0 pad=EdgeInsetsDirectional(16.0, 16.0, 16.0, 8.0)
      Row 28.0,128.0 424.0x24.0
        Padding 28.0,128.0 32.0x24.0 pad=EdgeInsetsDirectional(0.0, 0.0, 8.0, 0.0)
          Icon 28.0,128.0 24.0x24.0 icon=IconData(U+0E2A3) color=null size=null
                SizedBox 28.0,128.0 24.0x24.0 h=24.0 w=24.0
                  Center 28.0,128.0 24.0x24.0
                    RichText 28.0,128.0 24.0x24.0
        Expanded 60.0,130.0 392.0x20.0
          Text 60.0,130.0 392.0x20.0 text=Beta
            RichText 60.0,130.0 392.0x20.0
''',
    repliable: r'''
ROOT _CollapsibleSectionHeader
  _CollapsibleSectionHeader 12.0,216.0 456.0x48.0
                                    ConstrainedBox 12.0,216.0 456.0x48.0
                                      Padding 12.0,216.0 456.0x48.0 pad=EdgeInsetsDirectional(16.0, 8.0, 16.0, 8.0)
                                        Row 28.0,224.0 424.0x32.0
                                          Expanded 28.0,230.0 400.0x20.0
                                            Text 28.0,230.0 400.0x20.0 text=Gamma
                                              RichText 28.0,230.0 400.0x20.0
                                          Icon 428.0,228.0 24.0x24.0 icon=IconData(U+0E245) color=null size=null
                                                SizedBox 428.0,228.0 24.0x24.0 h=24.0 w=24.0
                                                  Center 428.0,228.0 24.0x24.0
                                                    RichText 428.0,228.0 24.0x24.0
''',
  ),
  '800.0': _Fige(
    entete: r'''
ROOT _SectionHeader
  _SectionHeader 12.0,12.0 776.0x44.0
    Padding 12.0,12.0 776.0x44.0 pad=EdgeInsetsDirectional(16.0, 16.0, 16.0, 8.0)
      Text 28.0,28.0 744.0x20.0 text=Alpha
        RichText 28.0,28.0 744.0x20.0
ROOT _SectionHeader
  _SectionHeader 12.0,112.0 776.0x48.0
    Padding 12.0,112.0 776.0x48.0 pad=EdgeInsetsDirectional(16.0, 16.0, 16.0, 8.0)
      Row 28.0,128.0 744.0x24.0
        Padding 28.0,128.0 32.0x24.0 pad=EdgeInsetsDirectional(0.0, 0.0, 8.0, 0.0)
          Icon 28.0,128.0 24.0x24.0 icon=IconData(U+0E2A3) color=null size=null
                SizedBox 28.0,128.0 24.0x24.0 h=24.0 w=24.0
                  Center 28.0,128.0 24.0x24.0
                    RichText 28.0,128.0 24.0x24.0
        Expanded 60.0,130.0 712.0x20.0
          Text 60.0,130.0 712.0x20.0 text=Beta
            RichText 60.0,130.0 712.0x20.0
''',
    repliable: r'''
ROOT _CollapsibleSectionHeader
  _CollapsibleSectionHeader 12.0,216.0 776.0x48.0
                                    ConstrainedBox 12.0,216.0 776.0x48.0
                                      Padding 12.0,216.0 776.0x48.0 pad=EdgeInsetsDirectional(16.0, 8.0, 16.0, 8.0)
                                        Row 28.0,224.0 744.0x32.0
                                          Expanded 28.0,230.0 720.0x20.0
                                            Text 28.0,230.0 720.0x20.0 text=Gamma
                                              RichText 28.0,230.0 720.0x20.0
                                          Icon 748.0,228.0 24.0x24.0 icon=IconData(U+0E245) color=null size=null
                                                SizedBox 748.0,228.0 24.0x24.0 h=24.0 w=24.0
                                                  Center 748.0,228.0 24.0x24.0
                                                    RichText 748.0,228.0 24.0x24.0
''',
  ),
};

String _sig(String typeName) {
  final StringBuffer buf = StringBuffer();
  for (final Element root in find
      .byElementPredicate(
        (Element e) => e.widget.runtimeType.toString() == typeName,
      )
      .evaluate()) {
    buf.writeln('ROOT ${root.widget.runtimeType}');
    void walk(Element e, int d) {
      final Widget w = e.widget;
      if (_retenus.contains(w.runtimeType.toString()) || d == 1) {
        final RenderObject? ro = e.renderObject;
        String r = '';
        if (ro is RenderBox && ro.hasSize && ro.attached) {
          final Offset o = ro.localToGlobal(Offset.zero);
          r = ' ${o.dx.toStringAsFixed(1)},${o.dy.toStringAsFixed(1)} '
              '${ro.size.width.toStringAsFixed(1)}x'
              '${ro.size.height.toStringAsFixed(1)}';
        }
        String extra = '';
        if (w is DecoratedBox) extra = ' deco=${w.decoration}';
        if (w is ColoredBox) extra = ' color=${w.color}';
        if (w is Padding) extra = ' pad=${w.padding}';
        if (w is SizedBox) extra = ' h=${w.height} w=${w.width}';
        if (w is Icon) extra = ' icon=${w.icon} color=${w.color} size=${w.size}';
        if (w is Text) extra = ' text=${w.data}';
        buf.writeln('${'  ' * d}${w.runtimeType}$r$extra');
      }
      e.visitChildren((Element c) => walk(c, d + 1));
    }

    walk(root, 1);
  }
  return buf.toString();
}

Future<void> _monte(WidgetTester tester, double width, {ZcrudTheme? theme}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final ZFormController controller =
      ZFormController(initialValues: const <String, Object?>{'a': 'x'});
  addTearDown(controller.dispose);
  Widget child = DynamicEdition(
    controller: controller,
    fields: _fields,
    sections: _sections,
  );
  if (theme != null) child = ZcrudScope(theme: theme, child: child);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

/// Premier arrêt du dégradé signature du titre — recalculé par le test, jamais
/// relu depuis le rendu.
Color _attenduPour(String titre) => ZSignaturePaletteReference
    .gradients[titre.hashCode.abs() % 5]
    .gradient
    .colors
    .first;

Finder _enteteDe(String titre) => find.ancestor(
      of: find.text(titre),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w.runtimeType.toString() == '_SectionHeader' ||
            w.runtimeType.toString() == '_CollapsibleSectionHeader',
      ),
    );

void main() {
  for (final double width in <double>[320, 480, 800]) {
    final _Fige fige = _avant['$width']!;

    testWidgets(
        '🔴 INERTIE ABSOLUE (w=$width) : sous `neutral`, l\'arbre de '
        '`_SectionHeader` est STRICTEMENT celui d\'avant le lot',
        (tester) async {
      await _monte(
        tester,
        width,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
      );
      expect(_sig('_SectionHeader'), fige.entete);
    });

    testWidgets(
        '🔴 INERTIE ABSOLUE (w=$width) : sous `neutral`, l\'arbre de '
        '`_CollapsibleSectionHeader` est STRICTEMENT celui d\'avant le lot',
        (tester) async {
      await _monte(
        tester,
        width,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
      );
      expect(_sig('_CollapsibleSectionHeader'), fige.repliable);
    });

    testWidgets('sous `neutral`, AUCUNE bande ni tuile n\'est montée '
        '(w=$width)', (tester) async {
      await _monte(
        tester,
        width,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
      );
      for (final String titre in <String>['Alpha', 'Beta', 'Gamma']) {
        expect(
          find.descendant(
            of: _enteteDe(titre),
            matching: find.byType(ColoredBox),
          ),
          findsNothing,
          reason: 'bande de référence montée sous `neutral` pour « $titre »',
        );
      }
      expect(
        find.ancestor(
          of: find.byIcon(Icons.folder),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('legacy (défaut) : bande de 3 dp, couleur EXACTE du dégradé '
      'signature indexé par le titre', (tester) async {
    await _monte(tester, 480);
    for (final String titre in <String>['Alpha', 'Beta', 'Gamma']) {
      final Finder bande = find.descendant(
        of: _enteteDe(titre),
        matching: find.byType(ColoredBox),
      );
      expect(bande, findsOneWidget, reason: 'aucune bande pour « $titre »');
      expect(
        tester.widget<ColoredBox>(bande).color,
        _attenduPour(titre),
        reason: 'couleur de bande erronée pour « $titre »',
      );
      expect(
        tester.getSize(bande).height,
        3.0,
        reason: 'hauteur de bande erronée pour « $titre »',
      );
    }
  });

  testWidgets('legacy (défaut) : tuile d\'icône 36 dp, rayon 10',
      (tester) async {
    await _monte(tester, 480);
    final Finder tuile = find.ancestor(
      of: find.byIcon(Icons.folder),
      matching: find.byType(DecoratedBox),
    );
    expect(tuile, findsOneWidget);
    expect(tester.getSize(tuile), const Size(36, 36));
    final BoxDecoration deco =
        tester.widget<DecoratedBox>(tuile).decoration as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(10));
    expect(deco.gradient, isA<LinearGradient>());
    // Le lavis reprend le dégradé signature de la section, jamais une teinte
    // inventée : on compare la CHROMATICITÉ, l'alpha étant volontairement bas.
    final Color premier = (deco.gradient! as LinearGradient).colors.first;
    expect(premier.withValues(alpha: 1.0), _attenduPour('Beta'));
    expect(premier.a, lessThan(1.0));
  });

  testWidgets('les SCALAIRES restent remplaçables jeton par jeton, sous legacy',
      (tester) async {
    await _monte(
      tester,
      480,
      theme: const ZcrudTheme(
        sectionHeaderAccentHeight: 7,
        sectionHeaderIconTileSize: 44,
        sectionHeaderIconTileRadius: 21,
      ),
    );
    final Finder bande = find.descendant(
      of: _enteteDe('Alpha'),
      matching: find.byType(ColoredBox),
    );
    expect(tester.getSize(bande).height, 7.0);
    final Finder tuile = find.ancestor(
      of: find.byIcon(Icons.folder),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(tuile), const Size(44, 44));
    expect(
      (tester.widget<DecoratedBox>(tuile).decoration as BoxDecoration)
          .borderRadius,
      BorderRadius.circular(21),
    );
  });

  testWidgets(
      '🔴 un scalaire posé ne RESSUSCITE pas la bande sous `neutral` : '
      "c'est la COULEUR qui décide de la présence", (tester) async {
    await _monte(
      tester,
      480,
      theme: const ZcrudTheme(
        referenceProfile: ZReferenceProfile.neutral,
        sectionHeaderAccentHeight: 7,
        sectionHeaderIconTileSize: 44,
      ),
    );
    for (final String titre in <String>['Alpha', 'Beta', 'Gamma']) {
      expect(
        find.descendant(
          of: _enteteDe(titre),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    }
    expect(_sig('_SectionHeader'), _avant['480.0']!.entete);
  });

  testWidgets(
      'un `topAccent` DÉCLARÉ l\'emporte sur la référence (paramètre > jeton '
      '> référence)', (tester) async {
    final ZFormController controller =
        ZFormController(initialValues: const <String, Object?>{'a': 'x'});
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: _fields,
              sections: const <ZEditionSection>[
                ZEditionSection(
                  title: 'Alpha',
                  fields: <String>['a'],
                  style: ZEditionSectionStyle(
                    topAccent: BorderSide(color: Color(0xFF123456), width: 9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final Finder bande = find.descendant(
      of: _enteteDe('Alpha'),
      matching: find.byType(ColoredBox),
    );
    expect(bande, findsOneWidget);
    expect(tester.widget<ColoredBox>(bande).color, const Color(0xFF123456));
    expect(tester.getSize(bande).height, 9.0);
  });
}
