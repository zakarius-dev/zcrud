/// Contrat CR-68 de la coquille de viewer indépendante du moteur de rendu.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudLabels, ZcrudScope;
import 'package:zcrud_document/zcrud_document.dart';

import 'support/z_sources.dart';

const _contentKey = ValueKey<String>('document-content');
const _topKey = ValueKey<String>('document-top');
const _bottomKey = ValueKey<String>('document-bottom');
const _loadingKey = ValueKey<String>('document-loading');
const _errorKey = ValueKey<String>('document-error');
const _emptyKey = ValueKey<String>('document-empty');

class _RecordingOcrPort implements ZDocumentOcrPort {
  _RecordingOcrPort({required this.available, required this.result});

  final bool available;
  final ZResult<ZDocumentText> result;
  final List<ZDocumentOcrRequest> requests = <ZDocumentOcrRequest>[];

  @override
  bool get isAvailable => available;

  @override
  Future<ZResult<ZDocumentText>> recognize(ZDocumentOcrRequest request) async {
    requests.add(request);
    return result;
  }
}

/// Port qui VIOLE son contrat : il lève au lieu de rendre un `Left`.
class _ThrowingOcrPort implements ZDocumentOcrPort {
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<ZResult<ZDocumentText>> recognize(ZDocumentOcrRequest request) async {
    calls += 1;
    throw StateError('moteur OCR indisponible');
  }
}

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    );

/// Variante portant un registre de libellés — réservée aux gardes de l10n,
/// pour ne pas modifier l'arbre mesuré par les gardes d'inertie.
Widget _wrapWithLabels(Widget child, ZcrudLabels labels) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: ZcrudScope(labels: labels, child: Scaffold(body: child)),
  ),
);

String _elementTree(Element root) {
  final buffer = StringBuffer();

  void visit(Element element, int depth) {
    buffer
      ..write('  ' * depth)
      ..writeln(element.widget.runtimeType);
    element.visitChildren((child) => visit(child, depth + 1));
  }

  visit(root, 0);
  return buffer.toString();
}

void main() {
  testWidgets('P2-F — arbre passif strictement figé', (tester) async {
    await tester.pumpWidget(_wrap(const ZDocumentViewerChrome()));

    final tree = _elementTree(
      tester.element(find.byType(ZDocumentViewerChrome)),
    );
    expect(tree, 'ZDocumentViewerChrome\n  ColoredBox\n    Column\n');
    expect(find.byType(ButtonStyleButton), findsNothing);
  });

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

  group('P2-F — action reconnaître le texte', () {
    testWidgets('absente quand le port est indisponible', (tester) async {
      final port = _RecordingOcrPort(
        available: false,
        result: Right<ZFailure, ZDocumentText>(ZDocumentText()),
      );
      await tester.pumpWidget(_wrap(ZDocumentViewerChrome(ocrPort: port)));

      // `isAvailable == false` équivaut à l'absence de port : ni action, ni
      // appel — l'arbre reste celui de la coque passive.
      expect(find.byIcon(Icons.document_scanner_outlined), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(
        _elementTree(tester.element(find.byType(ZDocumentViewerChrome))),
        'ZDocumentViewerChrome\n  ColoredBox\n    Column\n',
      );
      expect(port.requests, isEmpty);
    });

    testWidgets('présente et appelée UNE fois avec la requête exacte', (
      tester,
    ) async {
      final port = _RecordingOcrPort(
        available: true,
        result: Right<ZFailure, ZDocumentText>(ZDocumentText()),
      );
      await tester.pumpWidget(
        _wrap(
          ZDocumentViewerChrome(
            documentId: 'document-42',
            source: 'documents/42.pdf',
            ocrPort: port,
          ),
        ),
      );

      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pump();

      expect(port.requests, hasLength(1));
      // La requête est comparée en VALEUR : un identifiant recomposé, tronqué
      // ou une source substituée ferait rougir cette assertion.
      expect(
        port.requests.single,
        ZDocumentTextRequest(
          documentId: 'document-42',
          source: 'documents/42.pdf',
        ),
      );
    });

    testWidgets('Right transmet le texte et n’émet aucun échec', (
      tester,
    ) async {
      final text = ZDocumentText(
        pages: const <ZDocumentPageText>[
          ZDocumentPageText(page: 4, text: 'texte reconnu'),
        ],
      );
      final port = _RecordingOcrPort(
        available: true,
        result: Right<ZFailure, ZDocumentText>(text),
      );
      final recognized = <ZDocumentText>[];
      final failures = <ZFailure>[];
      await tester.pumpWidget(
        _wrap(
          ZDocumentViewerChrome(
            documentId: 'document-42',
            source: 'documents/42.pdf',
            ocrPort: port,
            onTextRecognized: recognized.add,
            onTextRecognitionFailed: failures.add,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pump();

      expect(recognized, <ZDocumentText>[text]);
      expect(failures, isEmpty);
    });

    testWidgets('Left notifie l’hôte sans callback de succès ni levée', (
      tester,
    ) async {
      const failure = ZServerFailure('OCR indisponible');
      final port = _RecordingOcrPort(
        available: true,
        result: const Left<ZFailure, ZDocumentText>(failure),
      );
      final recognized = <ZDocumentText>[];
      final failures = <ZFailure>[];
      await tester.pumpWidget(
        _wrap(
          ZDocumentViewerChrome(
            documentId: 'document-err',
            source: 'documents/err.pdf',
            document: const SizedBox(key: _contentKey),
            error: const SizedBox(key: _errorKey),
            ocrPort: port,
            onTextRecognized: recognized.add,
            onTextRecognitionFailed: failures.add,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(port.requests, hasLength(1));
      expect(recognized, isEmpty);
      expect(failures, <ZFailure>[failure]);
      // Le corps reste piloté par l'hôte : la coque ne bascule PAS sur son
      // slot d'erreur de sa propre initiative.
      expect(find.byKey(_contentKey), findsOneWidget);
      expect(find.byKey(_errorKey), findsNothing);
    });

    testWidgets('Left sans canal d’hôte part à FlutterError.onError', (
      tester,
    ) async {
      const failure = ZServerFailure('OCR indisponible');
      final port = _RecordingOcrPort(
        available: true,
        result: const Left<ZFailure, ZDocumentText>(failure),
      );

      await tester.pumpWidget(_wrap(ZDocumentViewerChrome(ocrPort: port)));
      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pump();

      // Sans `onTextRecognitionFailed`, l'échec n'est pas avalé : il part au
      // rapporteur de Flutter, que le binding de test collecte ici. On lit
      // `takeException()` plutôt que d'écraser `FlutterError.onError` — un
      // override manuel entre en conflit avec le binding et masquerait
      // l'assertion sous une erreur d'infrastructure.
      expect(tester.takeException(), same(failure));
    });

    testWidgets('un port qui LÈVE est converti en échec, jamais propagé', (
      tester,
    ) async {
      final port = _ThrowingOcrPort();
      final recognized = <ZDocumentText>[];
      final failures = <ZFailure>[];

      await tester.pumpWidget(
        _wrap(
          ZDocumentViewerChrome(
            ocrPort: port,
            onTextRecognized: recognized.add,
            onTextRecognitionFailed: failures.add,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pump();

      expect(port.calls, 1);
      expect(recognized, isEmpty);
      // La levée est convertie en échec ORDINAIRE pour l'hôte…
      expect(failures, hasLength(1));
      expect(failures.single, isA<ZDomainFailure>());
      // …et reste débogable : elle est relayée avec sa pile, jamais avalée,
      // jamais propagée à l'arbre (le pompage ci-dessus n'a pas jeté).
      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('le libellé vient du registre, l’icône est remplaçable', (
      tester,
    ) async {
      final port = _RecordingOcrPort(
        available: true,
        result: Right<ZFailure, ZDocumentText>(ZDocumentText()),
      );
      await tester.pumpWidget(
        _wrapWithLabels(
          ZDocumentViewerChrome(
            ocrPort: port,
            recognizeTextIcon: Icons.abc,
          ),
          ZcrudLabels(<String, String>{
            kZDocumentRecognizeTextLabelKey: 'Reconnaître le texte',
          }),
        ),
      );

      expect(find.byIcon(Icons.abc), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_outlined), findsNothing);
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Reconnaître le texte',
      );
    });
  });

  test(
    'CR-68 — aucun libellé ni moteur tiers n’est introduit dans la coque',
    () {
      // 🔴 P0D3 : le CODE seul est scanné (commentaires dépouillés) — la
      // dartdoc de ce fichier (et celle du chantier de documentation en
      // cours) peut légitimement CITER `syncfusion`/`Colors.`/`Text('` pour
      // expliquer pourquoi la coque les BANNIT. Un grep sur la source BRUTE
      // mordrait sur sa propre documentation.
      final source = stripCommentsOf(
        File('lib/src/presentation/z_document_viewer_chrome.dart'),
      );
      expect(source, isNot(contains('syncfusion')));
      expect(source, isNot(contains('PdfViewer')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains("Text('")));
      expect(source, isNot(contains('Text("')));
    },
  );
}
