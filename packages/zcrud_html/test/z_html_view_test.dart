/// 🎯 fp-4-3 (AC5, AD-40) — rendu `ZHtmlView` DÉFENSIF (AD-10) : HTML valide /
/// vide / corrompu / non-`String` ⇒ AUCUN `throw`, rendu présent ; et grep
/// négatif d'un type tiers dans le barrel public.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_html/zcrud_html.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('🎯 AC5 — rendu HTML défensif (AD-10, jamais de throw)', () {
    testWidgets('HTML valide ⇒ rendu présent, aucun throw', (tester) async {
      await tester.pumpWidget(
        _host(const ZHtmlView(html: '<p>Bonjour <b>monde</b></p>', label: 'x')),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZHtmlView), findsOneWidget);
    });

    testWidgets('HTML vide ⇒ rendu présent, aucun throw', (tester) async {
      await tester.pumpWidget(_host(const ZHtmlView(html: '')));
      expect(tester.takeException(), isNull);
      expect(find.byType(ZHtmlView), findsOneWidget);
    });

    testWidgets('HTML `null` ⇒ rendu vide, aucun throw', (tester) async {
      await tester.pumpWidget(_host(const ZHtmlView(html: null)));
      expect(tester.takeException(), isNull);
      expect(find.byType(ZHtmlView), findsOneWidget);
    });

    testWidgets('HTML corrompu (balises non fermées / exotiques) ⇒ pas de throw',
        (tester) async {
      await tester.pumpWidget(
        _host(const ZHtmlView(
          html: '<div><span>oops <b>gras <img src="x" '
              '<<<&nbsp;&<script>alert(1)</script>',
        )),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZHtmlView), findsOneWidget);
    });
  });

  group('🎯 AD-40 — aucun type tiers dans le barrel public', () {
    test('🔴 grep NÉGATIF : le barrel n\'importe/ré-exporte aucun type tiers',
        () {
      final File barrel = File('lib/zcrud_html.dart').existsSync()
          ? File('lib/zcrud_html.dart')
          : File('packages/zcrud_html/lib/zcrud_html.dart');
      expect(barrel.existsSync(), isTrue, reason: 'barrel introuvable');
      final String src = barrel.readAsStringSync();
      // On grep les DIRECTIVES `import`/`export 'package:<tiers>'` (pas les
      // mentions de prose en doc-commentaire) : c'est la fuite de TYPE réelle.
      final RegExp thirdPartyDirective = RegExp(
        r'''(import|export)\s+['"]package:(html_editor_enhanced|flutter_html)/''',
      );
      expect(thirdPartyDirective.hasMatch(src), isFalse,
          reason: '🔴 le barrel ne doit ni importer ni ré-exporter un paquet '
              'tiers confiné (html_editor_enhanced/flutter_html)');
      // Contrôle positif : le barrel expose bien l'API neutre attendue.
      expect(src.contains('registerZHtmlFields'), isTrue);
      expect(src.contains('ZHtmlView'), isTrue);
    });
  });
}
