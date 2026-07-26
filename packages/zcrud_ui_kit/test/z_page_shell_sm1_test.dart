import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  // AC6 (SM-1) — la frappe ne reconstruit PAS le corps d'onglet.
  testWidgets('AC6: taper 20 caractères ne rebuild pas le corps', (tester) async {
    var bodyBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: ZPageScaffold(
        title: 'T',
        search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
        tabs: [
          ZPageTab(
            label: 'A',
            contentBuilder: (_) {
              bodyBuilds++;
              return const Text('CORPS');
            },
          ),
          ZPageTab(
            label: 'B',
            contentBuilder: (_) => const Text('B'),
          ),
        ],
      ),
    ));

    // Ouvre la recherche (action délibérée, hors frappe).
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    final buildsBeforeTyping = bodyBuilds;
    expect(buildsBeforeTyping, greaterThan(0),
        reason: 'le corps a été construit au moins une fois');

    // Tape 20 caractères, un par un.
    const text = 'abcdefghijklmnopqrst';
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(find.byType(TextField), text.substring(0, i));
      await tester.pump();
    }

    // Le compteur du corps NE bouge PAS pendant la frappe (rebuild granulaire).
    expect(bodyBuilds, buildsBeforeTyping,
        reason: 'la frappe ne doit reconstruire que la tranche app-bar (SM-1)');
  });
}
