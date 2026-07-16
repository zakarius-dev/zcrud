import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _rtl(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('états rendus sous RTL sans exception + Semantics présents',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_rtl(
      const ZEmptyState(
        icon: Icons.inbox_outlined,
        title: 'Vide',
        message: 'Aucun élément',
      ),
    ));
    expect(tester.takeException(), isNull);
    // Le container Semantics porte le label combiné titre+message.
    expect(find.bySemanticsLabel('Vide. Aucun élément'), findsOneWidget);

    await tester.pumpWidget(_rtl(const ZLoadingState(message: 'Chargement')));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_rtl(const ZErrorState(message: 'Erreur')));
    expect(tester.takeException(), isNull);

    handle.dispose();
  });

  testWidgets('CTA a une cible tactile ≥ 48 dp', (tester) async {
    await tester.pumpWidget(_rtl(
      ZEmptyState(
        message: 'Vide',
        actionLabel: 'Ajouter',
        onAction: () {},
      ),
    ));
    final size = tester.getSize(find.widgetWithText(TextButton, 'Ajouter'));
    expect(size.height, greaterThanOrEqualTo(48.0));
    expect(size.width, greaterThanOrEqualTo(48.0));
  });

  testWidgets('dialog rendu sous RTL sans exception + actions ≥ 48 dp',
      (tester) async {
    await tester.pumpWidget(_rtl(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showZConfirmDialog(
            context,
            title: 'Titre',
            message: 'Message',
          ),
          child: const Text('OPEN'),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final confirmSize = tester.getSize(find.byType(FilledButton));
    expect(confirmSize.height, greaterThanOrEqualTo(48.0));
    expect(confirmSize.width, greaterThanOrEqualTo(48.0));
  });
}
