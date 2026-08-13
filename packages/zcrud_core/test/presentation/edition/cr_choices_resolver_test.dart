// Choix dérivés d'un autre champ (CR DODLP 2026-08-13) —
// `ZFieldSpec.choicesResolver` : consulté au rendu, prioritaire sur `choices` ;
// changer la dépendance change les options ET ne reconstruit QUE le champ
// dépendant (garde SM-1 : compteur de builds à 0 rebuild supplémentaire sur un
// champ non concerné) ; résolveur en erreur → repli statique (invariant AD-10) ;
// `==`/`copyWith` restent cohérents (closure exclue de l'égalité).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Options du champ dépendant, par valeur de la tranche `date`.
List<ZFieldChoice> _postesResolver(Object? Function(String) valueOf) {
  final date = valueOf('date');
  return date == 'd2'
      ? const <ZFieldChoice>[ZFieldChoice(value: 'b', label: 'Beta')]
      : const <ZFieldChoice>[ZFieldChoice(value: 'a', label: 'Alpha')];
}

void main() {
  late ZFormController controller;
  var dependentBuilds = 0;
  var unrelatedBuilds = 0;

  Widget app() {
    final dependent = const ZFieldSpec(
      name: 'poste',
      type: EditionFieldType.rowChips,
      choices: <ZFieldChoice>[ZFieldChoice(value: 'x', label: 'Statique')],
    ).copyWith(choicesResolver: _postesResolver);
    const unrelated = ZFieldSpec(
      name: 'autre',
      type: EditionFieldType.rowChips,
      choices: <ZFieldChoice>[ZFieldChoice(value: 'u', label: 'Ailleurs')],
    );
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            ZFieldWidget(
              controller: controller,
              field: dependent,
              onBuild: () => dependentBuilds++,
            ),
            ZFieldWidget(
              controller: controller,
              field: unrelated,
              onBuild: () => unrelatedBuilds++,
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    dependentBuilds = 0;
    unrelatedBuilds = 0;
    controller = ZFormController(
      initialValues: const <String, Object?>{'date': 'd1'},
      visibleFields: const <String>['poste', 'autre'],
    );
  });

  tearDown(() => controller.dispose());

  testWidgets('le résolveur est consulté au rendu, PRIORITAIRE sur `choices`',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget,
        reason: 'options du résolveur pour date=d1');
    expect(find.text('Statique'), findsNothing,
        reason: 'les choix statiques sont supplantés');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'changer la dépendance change les options ET ne reconstruit QUE le '
      'champ dépendant (garde SM-1)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final dependentBefore = dependentBuilds;
    final unrelatedBefore = unrelatedBuilds;

    controller.setValue('date', 'd2');
    await tester.pump();

    // Les options ont changé — au rendu, sans reconstruire le catalogue.
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    // SM-1 : SEUL le champ dont le résolveur lit `date` s'est reconstruit.
    expect(dependentBuilds, greaterThan(dependentBefore),
        reason: 'le champ dépendant DOIT se reconstruire');
    expect(unrelatedBuilds - unrelatedBefore, 0,
        reason: 'zéro rebuild supplémentaire sur un champ non concerné');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'une tranche JAMAIS lue par le résolveur ne le reconstruit pas '
      '(abonnement ciblé aux seules tranches lues)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final dependentBefore = dependentBuilds;

    controller.setValue('sans_rapport', 42);
    await tester.pump();

    expect(dependentBuilds - dependentBefore, 0,
        reason: 'le résolveur ne lit pas cette tranche');
    expect(tester.takeException(), isNull);
  });

  testWidgets('résolveur en ERREUR → repli statique, jamais un throw au '
      'rendu (invariant AD-10)', (tester) async {
    final field = const ZFieldSpec(
      name: 'poste',
      type: EditionFieldType.rowChips,
      choices: <ZFieldChoice>[ZFieldChoice(value: 'x', label: 'Statique')],
    ).copyWith(
      choicesResolver: (valueOf) => throw StateError('hôte défaillant'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZFieldWidget(controller: controller, field: field),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Statique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('`==`/`hashCode` EXCLUENT la closure ; `copyWith` la préserve', () {
    const base = ZFieldSpec(name: 'p', type: EditionFieldType.select);
    final a = base.copyWith(choicesResolver: _postesResolver);
    final b = base.copyWith(
      choicesResolver: (valueOf) => const <ZFieldChoice>[],
    );
    expect(a, equals(b),
        reason: 'deux specs ne diffèrent jamais par l\'identité d\'une closure');
    expect(a.hashCode, b.hashCode);
    expect(a.copyWith(label: 'l').choicesResolver, same(_postesResolver),
        reason: 'copyWith préserve le résolveur');
  });
}
