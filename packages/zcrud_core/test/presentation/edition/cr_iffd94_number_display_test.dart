// CR-IFFD-94 — le port `ZNumberDisplayFormatter` est CONSOMMÉ par la famille
// nombre en LECTURE et par le RÉSUMÉ de sous-liste.
//
// Constat d'origine (vérifié) : `domain/ports/` n'avait aucun symétrique
// numérique de `z_date_display_formatter.dart` — `12.0` s'affichait « 12.0 »
// sans recours. Étalon gardé : SANS port, le rendu reste exactement celui-là.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _Guillemets extends ZNumberDisplayFormatter {
  const _Guillemets();
  @override
  String? format(num value, {String? localeTag}) => '«$value»';
}

Widget _host({required Widget child, ZNumberDisplayFormatter? port}) =>
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(numberDisplayFormatter: port, child: child),
      ),
    );

void main() {
  testWidgets('🔴 fiche de lecture : sans port `12.0` s\'affiche « 12.0 » '
      '(rendu inchangé) ; avec port, la projection', (tester) async {
    const field = ZFieldSpec(name: 'montant', type: EditionFieldType.float);
    final c = ZFormController(initialValues: const {'montant': 12.0});
    await tester.pumpWidget(_host(
      child: ZFieldWidget(controller: c, field: field, readMode: true),
    ));
    expect(find.text('12.0'), findsOneWidget);

    await tester.pumpWidget(_host(
      port: const _Guillemets(),
      child: ZFieldWidget(controller: c, field: field, readMode: true),
    ));
    await tester.pump();
    expect(find.text('«12.0»'), findsOneWidget);
    expect(find.text('12.0'), findsNothing);
    c.dispose();
  });

  testWidgets('le suffixe neutre `ZNumberConfig` est apposé APRÈS le port '
      '(pourcentage)', (tester) async {
    const field = ZFieldSpec(
      name: 'taux',
      type: EditionFieldType.float,
      config: ZNumberConfig(isPercentage: true),
    );
    final c = ZFormController(initialValues: const {'taux': 42.5});
    await tester.pumpWidget(_host(
      port: const _Guillemets(),
      child: ZFieldWidget(controller: c, field: field, readMode: true),
    ));
    expect(find.text('«42.5» %'), findsOneWidget);
    c.dispose();
  });

  testWidgets('🔴 résumé de sous-liste : sans port, cellule inchangée '
      '(« 12.5 ») ; avec port, la projection', (tester) async {
    const field = ZFieldSpec(
      name: 'lignes',
      type: EditionFieldType.subItems,
      config: ZSubListConfig(
        itemFields: <ZFieldSpec>[
          ZFieldSpec(name: 'amount', type: EditionFieldType.float),
        ],
        summaryFields: <String>['amount'],
      ),
    );
    final c = ZFormController(initialValues: const {
      'lignes': [
        {'amount': 12.5},
      ],
    });
    await tester.pumpWidget(_host(
      child: DynamicEdition(controller: c, fields: const [field]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('12.5'), findsOneWidget);

    await tester.pumpWidget(_host(
      port: const _Guillemets(),
      child: DynamicEdition(controller: c, fields: const [field]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('«12.5»'), findsOneWidget);
    expect(find.text('12.5'), findsNothing);
    c.dispose();
  });
}
