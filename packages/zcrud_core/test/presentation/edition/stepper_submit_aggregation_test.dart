// E3-6 — LOW-1 : agrégation stepper « toutes étapes » câblée à la soumission.
//
// Prouve que `ZEditionSubmitController.submit()` valide le CATALOGUE COMPLET des
// champs (toutes les étapes d'un `ZStepperEdition`), pas seulement l'étape
// courante : un `required` invalide dans une étape NON courante bloque la
// soumission (onSubmit non appelé) et son erreur compte dans l'agrégat.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  // Catalogue multi-étapes : le required invalide vit dans l'étape 2 (NON
  // courante quand on est à l'étape 0).
  const fields = <ZFieldSpec>[
    ZFieldSpec(
      name: 's0_name',
      type: EditionFieldType.text,
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS0')],
    ),
    ZFieldSpec(name: 's1_free', type: EditionFieldType.text),
    ZFieldSpec(
      name: 's2_final',
      type: EditionFieldType.text,
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS2')],
    ),
  ];

  const steps = <ZEditionStep>[
    ZEditionStep(title: 'Étape 0', fields: <String>['s0_name']),
    ZEditionStep(title: 'Étape 1', fields: <String>['s1_free']),
    ZEditionStep(title: 'Étape 2', fields: <String>['s2_final']),
  ];

  testWidgets(
      'LOW-1 — submit() agrège TOUTES les étapes : un required invalide dans une '
      'étape NON courante bloque la soumission et compte dans l\'agrégat',
      (tester) async {
    // Étape courante = 0 ; on remplit SON required, mais s2_final (étape 2,
    // non montée) reste vide.
    final c = ZFormController(
      initialValues: <String, Object?>{
        's0_name': 'Alice', // étape courante valide
        's1_free': '',
        's2_final': '', // étape NON courante : required vide
      },
      visibleFields: const <String>['s0_name'], // stepper : seule l'étape 0.
    );
    addTearDown(c.dispose);

    var calls = 0;
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields, // catalogue COMPLET (toutes étapes).
      onSubmit: (values) async {
        calls++;
        return Right<ZFailure, Unit>(unit);
      },
    );
    addTearDown(submit.dispose);

    // Monte un stepper réel sur le MÊME controller (l'onComplete de la dernière
    // étape route vers submit — câblage stepper→submit prouvé).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: c,
          fields: fields,
          steps: steps,
          onComplete: () {
            submit.submit();
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Appel direct de submit() (l'app câble onComplete dessus) : l'agrégat DOIT
    // couvrir l'étape 2 non courante.
    final outcome = await submit.submit();

    expect(calls, 0, reason: 'onSubmit NON appelé : étape non courante invalide');
    expect(outcome.isValidationFailure, isTrue);
    expect(submit.state.value.status, ZSubmissionStatus.failure);

    // L'erreur de l'étape NON courante (s2_final) figure dans l'agrégat ; celle
    // de l'étape courante remplie (s0_name) n'y est pas.
    final failure = submit.state.value.failure! as ZValidationFailure;
    expect(failure.errors.containsKey('s2_final'), isTrue,
        reason: 'l\'agrégation couvre bien une étape non courante');
    expect(failure.errors['s2_final'], 'REQUIS2');
    expect(failure.errors.containsKey('s0_name'), isFalse,
        reason: 'étape courante remplie ⇒ pas dans l\'agrégat');
  });

  testWidgets(
      'LOW-1 — toutes les étapes valides ⇒ submit() délègue à onSubmit une fois',
      (tester) async {
    final c = ZFormController(
      initialValues: <String, Object?>{
        's0_name': 'Alice',
        's1_free': 'x',
        's2_final': 'ok', // étape non courante désormais valide
      },
      visibleFields: const <String>['s0_name'],
    );
    addTearDown(c.dispose);

    var calls = 0;
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) async {
        calls++;
        return Right<ZFailure, Unit>(unit);
      },
    );
    addTearDown(submit.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: c,
          fields: fields,
          steps: steps,
          onComplete: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final outcome = await submit.submit();

    expect(calls, 1, reason: 'toutes les étapes valides ⇒ soumission déléguée');
    expect(outcome.isSuccess, isTrue);
  });
}
