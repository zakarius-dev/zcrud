// CR-IFFD-98 — `ZNumberConfig.minValueKey`/`maxValueKey` sont HONORÉS.
//
// Constat d'origine (vérifié) : déclarés dans le domaine, jamais lus par la
// présentation — une borne dynamique référencée sur un autre champ ne bornait
// rien. Mécanisme reproduit : celui des bornes cross-champ existantes
// (validateur lisant la tranche référencée à l'invocation + abonnement CIBLÉ
// re-validant le champ borné quand la référence change).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZFieldSpec _bounded = ZFieldSpec(
  name: 'valeur',
  type: EditionFieldType.float,
  config: ZNumberConfig(minValueKey: 'plancher', maxValueKey: 'plafond'),
);

void main() {
  testWidgets('🔴 une saisie SOUS la borne min dynamique est signalée ; la '
      'borne vient bien de l\'autre champ', (tester) async {
    final c = ZFormController(initialValues: const {'plancher': 10});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ZFieldWidget(controller: c, field: _bounded)),
    ));
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    expect(find.text('Valeur trop petite'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    expect(find.text('Valeur trop petite'), findsNothing);
    c.dispose();
  });

  testWidgets('🔴 REVALIDATION quand le champ référencé change — sans '
      're-saisie du champ borné', (tester) async {
    final c = ZFormController(initialValues: const {'plancher': 10});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ZFieldWidget(controller: c, field: _bounded)),
    ));
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    expect(find.text('Valeur trop petite'), findsOneWidget);
    // La borne descend : l'erreur doit disparaître SANS toucher au champ.
    c.setValue('plancher', 1);
    await tester.pump();
    expect(find.text('Valeur trop petite'), findsNothing);
    // La borne remonte : l'erreur revient.
    c.setValue('plancher', 100);
    await tester.pump();
    expect(find.text('Valeur trop petite'), findsOneWidget);
    c.dispose();
  });

  testWidgets('borne MAX dynamique honorée ; référence ABSENTE ⇒ non '
      'bloquant (AD-10)', (tester) async {
    final c = ZFormController(initialValues: const {'plafond': 20});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ZFieldWidget(controller: c, field: _bounded)),
    ));
    // `plancher` n'a aucune valeur : la borne min est indéterminée ⇒ aucune
    // erreur min ; seule la borne max mord.
    await tester.enterText(find.byType(TextField), '50');
    await tester.pump();
    expect(find.text('Valeur trop grande'), findsOneWidget);
    expect(find.text('Valeur trop petite'), findsNothing);
    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();
    expect(find.text('Valeur trop grande'), findsNothing);
    c.dispose();
  });

  testWidgets('référence NON NUMÉRIQUE ⇒ non bloquant, jamais une exception', (
    tester,
  ) async {
    final c = ZFormController(initialValues: const {'plancher': 'libre'});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ZFieldWidget(controller: c, field: _bounded)),
    ));
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    expect(find.text('Valeur trop petite'), findsNothing);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
}
