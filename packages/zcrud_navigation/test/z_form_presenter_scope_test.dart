// Tests WIDGET du seam `ZFormPresenterScope` (EX-UI.6, AC1/AC4) : sans scope,
// `of()` renvoie le défaut `ZAdaptivePresenter` (jamais de throw) ; avec un
// présentateur EXTERNE injecté (prouve le port non-`sealed`, AD-4), `presentEdition`
// l'utilise. Le seam est LOCAL à `zcrud_navigation` — `ZcrudScope` de `zcrud_core`
// n'est pas touché.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Présentateur EXTERNE au package (implémente le port hors de son fichier) :
/// compile et se substitue ⇒ prouve que `ZFormPresenter` n'est PAS `sealed`
/// (AD-4/NFR-U9). Enregistre le `mode` reçu sans ouvrir de surface réelle.
class _RecordingPresenter implements ZFormPresenter {
  ZEditionPresentation? lastMode;
  int calls = 0;

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
    calls++;
    lastMode = mode;
    return Future<T?>.value(null);
  }
}

void main() {
  testWidgets('of() sans scope → défaut ZAdaptivePresenter (jamais de throw)',
      (tester) async {
    late ZFormPresenter resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = ZFormPresenterScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved, isA<ZAdaptivePresenter>());
  });

  testWidgets('maybeOf() sans scope → null', (tester) async {
    late ZFormPresenterScope? scope;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            scope = ZFormPresenterScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(scope, isNull);
  });

  testWidgets(
      'présentateur externe injecté via le scope → utilisé par presentEdition',
      (tester) async {
    final recording = _RecordingPresenter();

    await tester.pumpWidget(
      MaterialApp(
        home: ZFormPresenterScope(
          presenter: recording,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => presentEdition<void>(
                    context,
                    builder: (_) => const Text('body'),
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
    await tester.pump();

    // Le seam a résolu l'impl EXTERNE (pas le défaut) : elle a été appelée.
    expect(recording.calls, 1);
    expect(recording.lastMode, isNotNull);
    // Aucune surface réelle ouverte (l'impl enregistre seulement).
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('of() résout l\'impl injectée par le scope le plus proche',
      (tester) async {
    final recording = _RecordingPresenter();
    late ZFormPresenter resolved;

    await tester.pumpWidget(
      MaterialApp(
        home: ZFormPresenterScope(
          presenter: recording,
          child: Builder(
            builder: (context) {
              resolved = ZFormPresenterScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(identical(resolved, recording), isTrue);
  });
}
