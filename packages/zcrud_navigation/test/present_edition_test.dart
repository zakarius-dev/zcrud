// Tests WIDGET du helper `presentEdition` (EX-UI.6, AC5) : il DÉRIVE le mode du
// breakpoint courant (largeur mesurée via `ZWindowSizeClass.of` de
// `zcrud_responsive`) puis délègue au présentateur. On capte le mode via un
// présentateur enregistreur injecté (indépendant du rendu) ET on vérifie la
// surface réelle. Table M3 : <600 → sheet ; 600..839 → dialog ; ≥840 light →
// dialog ; ≥840 heavy → page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Présentateur enregistreur (capte le `mode` sans dépendre du rendu).
class _RecordingPresenter implements ZFormPresenter {
  ZEditionPresentation? lastMode;

  @override
  Future<T?> present<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
  }) {
    lastMode = mode;
    return Future<T?>.value(null);
  }
}

/// Monte `presentEdition` sous une largeur d'écran forcée via `MediaQuery`.
Future<ZEditionPresentation?> _resolveModeAtWidth(
  WidgetTester tester, {
  required double width,
  required ZFormWeight formWeight,
}) async {
  final recording = _RecordingPresenter();
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (context) {
            // Appel direct dans le build (pas de tap requis) — présentateur
            // injecté en paramètre (aucune surface réelle ouverte).
            presentEdition<void>(
              context,
              builder: (_) => const Text('body'),
              formWeight: formWeight,
              presenter: recording,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return recording.lastMode;
}

void main() {
  group('presentEdition — dérivation du mode par la largeur (AC5)', () {
    testWidgets('largeur < 600 → sheet', (tester) async {
      expect(
        await _resolveModeAtWidth(tester,
            width: 400, formWeight: ZFormWeight.light),
        ZEditionPresentation.sheet,
      );
    });

    testWidgets('600 ≤ largeur < 840 → dialog', (tester) async {
      expect(
        await _resolveModeAtWidth(tester,
            width: 700, formWeight: ZFormWeight.light),
        ZEditionPresentation.dialog,
      );
    });

    testWidgets('largeur ≥ 840 + light → dialog', (tester) async {
      expect(
        await _resolveModeAtWidth(tester,
            width: 1000, formWeight: ZFormWeight.light),
        ZEditionPresentation.dialog,
      );
    });

    testWidgets('largeur ≥ 840 + heavy → page', (tester) async {
      expect(
        await _resolveModeAtWidth(tester,
            width: 1000, formWeight: ZFormWeight.heavy),
        ZEditionPresentation.page,
      );
    });
  });

  group('presentEdition — surface réelle via le seam (AC5, intégration)', () {
    testWidgets('largeur < 600 (défaut ZAdaptivePresenter) → BottomSheet ouvert',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => presentEdition<void>(
                      context,
                      builder: (_) => const Text('body', key: Key('body')),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const Key('body')), findsOneWidget);
    });
  });
}
