import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Monte une app avec un bouton PUSH qui pousse une route protégée par
/// [ZDiscardChangesGuard]. La route poussée porte un `AppBar` (donc un
/// `BackButton` → `Navigator.maybePop`, le canal réel qui déclenche `PopScope`).
Widget _harness({
  required ValueListenable<bool> isDirty,
  VoidCallback? onDiscard,
  String? title,
  String? message,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ZDiscardChangesGuard(
                isDirty: isDirty,
                onDiscard: onDiscard,
                title: title,
                message: message,
                child: Scaffold(
                  appBar: AppBar(title: const Text('PAGE')),
                  body: const Center(child: Text('BODY')),
                ),
              ),
            ),
          ),
          child: const Text('PUSH'),
        ),
      ),
    ),
  );
}

Future<void> _openGuardedPage(WidgetTester tester) async {
  await tester.tap(find.text('PUSH'));
  await tester.pumpAndSettle();
  expect(find.text('BODY'), findsOneWidget);
}

void main() {
  testWidgets(
    'propre (isDirty=false) → tentative de sortie pop direct, aucun dialog, '
    'onDiscard non appelé',
    (tester) async {
      var discarded = 0;
      final notifier = ValueNotifier<bool>(false);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _harness(isDirty: notifier, onDiscard: () => discarded++),
      );
      await _openGuardedPage(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Sortie immédiate : la page a disparu, aucun dialog n'a été affiché.
      expect(find.text('BODY'), findsNothing);
      expect(find.byType(ZConfirmDialog), findsNothing);
      expect(discarded, 0);
    },
  );

  testWidgets(
    'sale (isDirty=true) → PopScope intercepte + showZConfirmDialog affiché',
    (tester) async {
      final notifier = ValueNotifier<bool>(true);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_harness(isDirty: notifier, title: 'Perdre ?'));
      await _openGuardedPage(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Sortie bloquée : la page est toujours là ET le dialog s'affiche.
      expect(find.text('BODY'), findsOneWidget);
      expect(find.byType(ZConfirmDialog), findsOneWidget);
      expect(find.text('Perdre ?'), findsOneWidget);
    },
  );

  testWidgets(
    'sale → confirmer ⇒ onDiscard appelé une fois PUIS pop effectué',
    (tester) async {
      var discarded = 0;
      final notifier = ValueNotifier<bool>(true);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _harness(isDirty: notifier, onDiscard: () => discarded++),
      );
      await _openGuardedPage(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Confirme (bouton par défaut MaterialLocalizations : OK).
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(discarded, 1);
      expect(find.text('BODY'), findsNothing); // pop effectué
      expect(find.byType(ZConfirmDialog), findsNothing);
    },
  );

  testWidgets(
    'sale → annuler ⇒ reste (pas de pop) + onDiscard non appelé',
    (tester) async {
      var discarded = 0;
      final notifier = ValueNotifier<bool>(true);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _harness(isDirty: notifier, onDiscard: () => discarded++),
      );
      await _openGuardedPage(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(discarded, 0);
      expect(find.text('BODY'), findsOneWidget); // resté sur la page
      expect(find.byType(ZConfirmDialog), findsNothing);
    },
  );

  testWidgets(
    'sale → barrier dismiss (défaut sûr) ⇒ reste + onDiscard non appelé',
    (tester) async {
      var discarded = 0;
      final notifier = ValueNotifier<bool>(true);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _harness(isDirty: notifier, onDiscard: () => discarded++),
      );
      await _openGuardedPage(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // hors du dialog
      await tester.pumpAndSettle();

      expect(discarded, 0);
      expect(find.text('BODY'), findsOneWidget);
    },
  );
}
