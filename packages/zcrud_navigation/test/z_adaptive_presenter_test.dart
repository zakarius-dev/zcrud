// Tests WIDGET du présentateur par défaut pur-Flutter `ZAdaptivePresenter`
// (EX-UI.6, AC2/AC3/AC6) : les 3 modes ouvrent la BONNE surface (page = nouvelle
// route, sheet = bottom-sheet modale, dialog = `Dialog`), le retour de valeur
// remonte via `Navigator.pop`, les tailles max sont appliquées, et le rendu est
// correct sous `Directionality.rtl`. AUCUN `get`/`go_router` — Flutter vanilla.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Contenu opaque du `builder` (le port est form-agnostique).
class _Body extends StatelessWidget {
  const _Body();
  @override
  Widget build(BuildContext context) =>
      const Text('form-body', key: Key('form-body'));
}

/// Monte un `MaterialApp` avec un bouton qui déclenche `present(mode: ...)` et
/// mémorise le `Future` retourné (pour asserter la valeur de retour).
Widget _harness({
  required ZEditionPresentation mode,
  double? maxWidth,
  double? maxHeight,
  TextDirection textDirection = TextDirection.ltr,
  WidgetBuilder? bodyBuilder,
  void Function(Future<Object?> future)? onFuture,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: textDirection,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                final future = const ZAdaptivePresenter().present<Object?>(
                  context,
                  builder: bodyBuilder ?? (_) => const _Body(),
                  mode: mode,
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                );
                onFuture?.call(future);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ZAdaptivePresenter — 3 surfaces Flutter vanilla (AC2)', () {
    testWidgets('page → nouvelle route pleine page (fullscreenDialog)',
        (tester) async {
      await tester.pumpWidget(_harness(mode: ZEditionPresentation.page));
      // Écran d'accueil au sommet : le bouton est visible, le body absent.
      expect(find.text('open'), findsOneWidget);
      expect(find.byKey(const Key('form-body')), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Une nouvelle route est poussée : le body est visible et le bouton
      // d'accueil n'est plus au sommet (masqué par la route pleine page).
      expect(find.byKey(const Key('form-body')), findsOneWidget);
      expect(find.text('open'), findsNothing);
    });

    testWidgets('sheet → bottom-sheet modale présente', (tester) async {
      await tester.pumpWidget(_harness(mode: ZEditionPresentation.sheet));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const Key('form-body')), findsOneWidget);
    });

    testWidgets('dialog → `Dialog` présent', (tester) async {
      await tester.pumpWidget(_harness(mode: ZEditionPresentation.dialog));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('form-body')), findsOneWidget);
    });
  });

  group('ZAdaptivePresenter — retour de valeur via Navigator.pop (AC3)', () {
    for (final mode in ZEditionPresentation.values) {
      testWidgets('mode=$mode : le Future complète avec la valeur poppée',
          (tester) async {
        Future<Object?>? future;
        await tester.pumpWidget(
          _harness(mode: mode, onFuture: (f) => future = f),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Ferme la surface en remontant une valeur.
        final BuildContext bodyCtx =
            tester.element(find.byKey(const Key('form-body')));
        Navigator.of(bodyCtx).pop('result-$mode');
        await tester.pumpAndSettle();

        expect(await future, 'result-$mode');
      });
    }
  });

  group('ZAdaptivePresenter — tailles max explicites (AC3)', () {
    testWidgets('dialog maxWidth=400 → ConstrainedBox borné à 400',
        (tester) async {
      await tester.pumpWidget(
        _harness(mode: ZEditionPresentation.dialog, maxWidth: 400),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Un ConstrainedBox ancêtre du body porte maxWidth == 400.
      final constrained = tester.widgetList<ConstrainedBox>(
        find.ancestor(
          of: find.byKey(const Key('form-body')),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(
        constrained.any((c) => c.constraints.maxWidth == 400),
        isTrue,
      );
    });

    testWidgets('sheet maxHeight=300 → contrainte de hauteur appliquée',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          mode: ZEditionPresentation.sheet,
          maxHeight: 300,
          // Contenu VOLONTAIREMENT haut (600 dp) : sans la contrainte
          // `maxHeight: 300` du code de prod, la bottom-sheet grandirait bien
          // au-delà de 300 → l'assertion `<= 300` devient PORTEUSE (elle
          // rougirait si la contrainte était retirée). Cf. code-review M1.
          bodyBuilder: (_) => const SizedBox(
            height: 600,
            child: Text('form-body', key: Key('form-body')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // La bottom-sheet est bornée à la contrainte demandée malgré un contenu
      // de 600 dp (borne effectivement appliquée, pas coïncidence de contenu).
      final sheetSize = tester.getSize(find.byType(BottomSheet));
      expect(sheetSize.height, lessThanOrEqualTo(300));
    });
  });

  group('ZAdaptivePresenter — RTL (AC6)', () {
    testWidgets('dialog s\'ouvre sans exception sous Directionality.rtl',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          mode: ZEditionPresentation.dialog,
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sheet s\'ouvre sans exception sous Directionality.rtl',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          mode: ZEditionPresentation.sheet,
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
