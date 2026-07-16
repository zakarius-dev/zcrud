// EX-UI.11 AC1 — `ZGetFormPresenter implements ZFormPresenter` exécute les 3
// modes `ZEditionPresentation` en idiome GetX. Harnais D8 : `Get.testMode = true`
// + `GetMaterialApp` (fournit le Navigator/overlay GetX), un bouton capture un
// vrai `BuildContext` puis appelle `present(context, …)`. Assertions via l'état
// global `Get` (isDialogOpen/isBottomSheetOpen) + `find.byType(Dialog)`/find.byKey.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

const _contentKey = Key('ex-ui-11-presented-content');

/// Contenu opaque poussé par le présentateur (form-agnostique : le port ne
/// l'inspecte jamais). Un `TextButton` referme la surface via `Get.back`.
Widget _content(BuildContext context) => Center(
      key: _contentKey,
      child: TextButton(
        onPressed: () => Get.back<String>(result: 'ok'),
        child: const Text('fermer'),
      ),
    );

/// Monte un `GetMaterialApp` avec un bouton déclencheur qui capture un vrai
/// `BuildContext` et appelle `present` selon [mode]. Le `Future` résultant est
/// stocké dans [onFuture] pour être asservi.
Widget _harness(
  ZEditionPresentation mode, {
  void Function(Future<String?> future)? onFuture,
}) {
  const presenter = ZGetFormPresenter();
  return GetMaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              final future = presenter.present<String>(
                context,
                builder: _content,
                mode: mode,
              );
              onFuture?.call(future);
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => Get.testMode = true);

  testWidgets('mode page → route poussée, contenu affiché (AC1)',
      (tester) async {
    await tester.pumpWidget(_harness(ZEditionPresentation.page));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsOneWidget);
    // Route poussée en plein écran : le déclencheur n'est plus visible.
    expect(find.text('ouvrir'), findsNothing);
  });

  testWidgets('mode dialog → contenu dans un Dialog + Get.isDialogOpen (AC1)',
      (tester) async {
    await tester.pumpWidget(_harness(ZEditionPresentation.dialog));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsOneWidget);
    expect(Get.isDialogOpen, isTrue);
    // Le contenu vit bien sous un `Dialog` (surface centrée modale).
    expect(
      find.ancestor(
        of: find.byKey(_contentKey),
        matching: find.byType(Dialog),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mode sheet → Get.isBottomSheetOpen, contenu affiché (AC1)',
      (tester) async {
    await tester.pumpWidget(_harness(ZEditionPresentation.sheet));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsOneWidget);
    expect(Get.isBottomSheetOpen, isTrue);
  });

  testWidgets('le Future complète sur Get.back(result:) (AC1)', (tester) async {
    Future<String?>? presented;
    await tester.pumpWidget(
      _harness(
        ZEditionPresentation.dialog,
        onFuture: (f) => presented = f,
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    // Fermeture programmatique via le bouton du contenu (Get.back(result:'ok')).
    await tester.tap(find.text('fermer'));
    await tester.pumpAndSettle();

    expect(await presented, 'ok');
    expect(Get.isDialogOpen, isFalse);
  });
}
