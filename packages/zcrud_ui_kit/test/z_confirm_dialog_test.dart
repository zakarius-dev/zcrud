import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Monte un bouton qui ouvre le dialog et capture le résultat du Future.
Widget _harness({
  required void Function(bool) onResult,
  String? title = 'Titre',
  ZConfirmTone tone = ZConfirmTone.neutral,
  String? confirmLabel,
  String? cancelLabel,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final r = await showZConfirmDialog(
              context,
              title: title,
              message: 'Message',
              confirmLabel: confirmLabel,
              cancelLabel: cancelLabel,
              tone: tone,
            );
            onResult(r);
          },
          child: const Text('OPEN'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rend titre + message + 2 actions (labels MaterialLocalizations)',
      (tester) async {
    await tester.pumpWidget(_harness(onResult: (_) {}));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Titre'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    // Labels par défaut = MaterialLocalizations (en : OK / Cancel).
    expect(find.widgetWithText(FilledButton, 'OK'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('title null omet entièrement AlertDialog.title', (tester) async {
    await tester.pumpWidget(_harness(onResult: (_) {}, title: null));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(dialog.title, isNull);
  });

  testWidgets('title fourni conserve exactement le widget titre attendu', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(onResult: (_) {}, title: 'Titre témoin'));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(find.text('Titre témoin'), findsOneWidget);
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Titre témoin');
  });

  testWidgets('sans titre, annuler conserve le résultat false', (tester) async {
    bool? result;
    await tester.pumpWidget(_harness(onResult: (r) => result = r, title: null));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('sans titre, la sémantique déclarée annonce la route', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(onResult: (_) {}, title: null));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final noTitleRoute = find.byKey(
      const ValueKey<String>('z_confirm_dialog_no_title_semantics'),
    );
    expect(noTitleRoute, findsOneWidget);
    expect(
      tester.getSemantics(noTitleRoute),
      matchesSemantics(label: 'Message', scopesRoute: true, namesRoute: true),
    );
  });

  testWidgets('confirmer → Future complète true', (tester) async {
    bool? result;
    await tester.pumpWidget(_harness(onResult: (r) => result = r));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('avec titre, confirmer conserve le résultat true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(_harness(onResult: (r) => result = r));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('annuler → Future complète false', (tester) async {
    bool? result;
    await tester.pumpWidget(_harness(onResult: (r) => result = r));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('barrier dismiss → Future complète false (défaut sûr)',
      (tester) async {
    bool? result;
    await tester.pumpWidget(_harness(onResult: (r) => result = r));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // Tap hors du dialog (barrier).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('labels personnalisés respectés', (tester) async {
    await tester.pumpWidget(_harness(
      onResult: (_) {},
      confirmLabel: 'Supprimer',
      cancelLabel: 'Garder',
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Supprimer'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Garder'), findsOneWidget);
  });

  testWidgets('destructive teinte le bouton de confirmation via ColorScheme.error',
      (tester) async {
    final theme = ThemeData.dark();
    await tester.pumpWidget(_harness(
      onResult: (_) {},
      tone: ZConfirmTone.destructive,
      theme: theme,
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    final bg = btn.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(bg, theme.colorScheme.error);
  });

  testWidgets('neutral teinte le bouton via ColorScheme.primary', (tester) async {
    final theme = ThemeData.light();
    await tester.pumpWidget(_harness(onResult: (_) {}, theme: theme));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    final bg = btn.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(bg, theme.colorScheme.primary);
  });
}
