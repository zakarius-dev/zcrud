/// Contrat CR-68 de la coquille de viewer indépendante du moteur de rendu.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_document/zcrud_document.dart';

const _contentKey = ValueKey<String>('document-content');
const _topKey = ValueKey<String>('document-top');
const _bottomKey = ValueKey<String>('document-bottom');
const _loadingKey = ValueKey<String>('document-loading');
const _errorKey = ValueKey<String>('document-error');
const _emptyKey = ValueKey<String>('document-empty');

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('CR-68 — slots et états injectés', () {
    testWidgets('le slot document absent est absent de l’arbre', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ZDocumentViewerChrome()));
      expect(find.byKey(_contentKey), findsNothing);
      expect(
        find.byType(Expanded),
        findsNothing,
        reason: 'aucun conteneur de contenu ne doit être synthétisé',
      );
    });

    testWidgets('les slots haut, contenu et bas sont composés sans moteur', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ZDocumentViewerChrome(
            topBar: SizedBox(key: _topKey),
            document: SizedBox(key: _contentKey),
            bottomBar: SizedBox(key: _bottomKey),
          ),
        ),
      );
      expect(find.byKey(_topKey), findsOneWidget);
      expect(find.byKey(_contentKey), findsOneWidget);
      expect(find.byKey(_bottomKey), findsOneWidget);
    });

    for (final fixture in <({ZDocumentViewerLoadState state, Key key})>[
      (state: ZDocumentViewerLoadState.loading, key: _loadingKey),
      (state: ZDocumentViewerLoadState.error, key: _errorKey),
      (state: ZDocumentViewerLoadState.empty, key: _emptyKey),
    ]) {
      testWidgets(
        'l’état ${fixture.state.name} rend uniquement son slot injecté',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              ZDocumentViewerChrome(
                loadState: fixture.state,
                document: const SizedBox(key: _contentKey),
                loading: const SizedBox(key: _loadingKey),
                error: const SizedBox(key: _errorKey),
                empty: const SizedBox(key: _emptyKey),
              ),
            ),
          );
          expect(find.byKey(fixture.key), findsOneWidget);
          expect(find.byKey(_contentKey), findsNothing);
        },
      );
    }
  });

  group('CR-68 — navigation accessible et directionnelle', () {
    testWidgets('callbacks, libellés injectés, semantics et cibles >= 48 dp', (
      tester,
    ) async {
      var previousCalls = 0;
      var nextCalls = 0;
      await tester.pumpWidget(
        _wrap(
          ZDocumentViewerChrome(
            pageNavigation: ZDocumentPageNavigation(
              previousPageLabel: 'PAGE AVANT',
              nextPageLabel: 'PAGE APRÈS',
              onPreviousPage: () => previousCalls++,
              onNextPage: () => nextCalls++,
            ),
          ),
        ),
      );
      final previous = find.text('PAGE AVANT');
      final next = find.text('PAGE APRÈS');
      final previousTarget = find.ancestor(
        of: previous,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.minHeight == 48,
        ),
      );
      final nextTarget = find.ancestor(
        of: next,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.minHeight == 48,
        ),
      );
      expect(tester.getSize(previousTarget).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(nextTarget).height, greaterThanOrEqualTo(48));
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(previous).label, 'PAGE AVANT');
      expect(tester.getSemantics(next).label, 'PAGE APRÈS');
      semantics.dispose();
      await tester.tap(previous);
      await tester.tap(next);
      expect(previousCalls, 1);
      expect(nextCalls, 1);
    });

    testWidgets('l’ordre de navigation est miroir en RTL', (tester) async {
      const navigation = ZDocumentPageNavigation(
        previousPageLabel: 'PREVIOUS',
        nextPageLabel: 'NEXT',
      );
      await tester.pumpWidget(
        _wrap(const ZDocumentViewerChrome(pageNavigation: navigation)),
      );
      final ltrPrevious = tester.getTopLeft(find.text('PREVIOUS')).dx;
      final ltrNext = tester.getTopLeft(find.text('NEXT')).dx;
      expect(ltrPrevious, lessThan(ltrNext));

      await tester.pumpWidget(
        _wrap(
          const ZDocumentViewerChrome(pageNavigation: navigation),
          direction: TextDirection.rtl,
        ),
      );
      final rtlPrevious = tester.getTopLeft(find.text('PREVIOUS')).dx;
      final rtlNext = tester.getTopLeft(find.text('NEXT')).dx;
      expect(rtlPrevious, greaterThan(rtlNext));
    });
  });

  test(
    'CR-68 — aucun libellé ni moteur tiers n’est introduit dans la coque',
    () {
      final source = File(
        'lib/src/presentation/z_document_viewer_chrome.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('syncfusion')));
      expect(source, isNot(contains('PdfViewer')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains("Text('")));
      expect(source, isNot(contains('Text("')));
    },
  );
}
