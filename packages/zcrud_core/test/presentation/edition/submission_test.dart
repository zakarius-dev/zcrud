// E3-6 — Soumission agrégée + états UI (AC1, AC3, AC4, AC5, AC6).
//
// Valide la voie de soumission : validation agrégée bloquante (onSubmit NON
// appelé + état échec-validation), snapshot de valeurs PURES passé au seam,
// contrat `Either<ZFailure,T>` (Right/Left/exception enveloppée), état
// `inProgress` + garde de ré-entrance, état `failure` applicatif.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _ctrl(Map<String, Object?> values) =>
    ZFormController(initialValues: values, visibleFields: values.keys.toList());

void main() {
  test('AC1 — validation agrégée bloque : onSubmit NON appelé + état échec validation',
      () async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(
        name: 'a',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'requis')],
      ),
    ];
    final c = _ctrl(<String, Object?>{'a': ''});
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

    final outcome = await submit.submit();

    expect(calls, 0, reason: 'onSubmit jamais appelé si invalide');
    expect(outcome.isValidationFailure, isTrue);
    expect(submit.state.value.status, ZSubmissionStatus.failure);
    expect(submit.state.value.isValidationFailure, isTrue,
        reason: 'échec de validation distinct de l’échec applicatif');
  });

  test('AC3 — onSubmit reçoit un snapshot de valeurs PURES (jamais un callback/Widget)',
      () async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'nom', type: EditionFieldType.text),
      const ZFieldSpec(name: 'age', type: EditionFieldType.number),
    ];
    final c = _ctrl(<String, Object?>{'nom': '', 'age': null});
    addTearDown(c.dispose);
    c.setValue('nom', 'Ada');
    c.setValue('age', 42);

    Map<String, Object?>? captured;
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) async {
        captured = values;
        return Right<ZFailure, Unit>(unit);
      },
    );
    addTearDown(submit.dispose);

    final outcome = await submit.submit();

    expect(outcome.isSuccess, isTrue);
    expect(captured, <String, Object?>{'nom': 'Ada', 'age': 42});
    // Aucune entrée non sérialisable (données pures — AD-3).
    for (final v in captured!.values) {
      expect(v is Function, isFalse);
      expect(v is Widget, isFalse);
    }
    // Snapshot immuable.
    expect(() => captured!['x'] = 1, throwsUnsupportedError);
  });

  test('AC4 — Left(ZFailure) ⇒ état échec applicatif portant ce ZFailure', () async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'a', type: EditionFieldType.text),
    ];
    final c = _ctrl(<String, Object?>{'a': 'ok'});
    addTearDown(c.dispose);
    const failure = ZServerFailure('boom');
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) async => const Left<ZFailure, Unit>(failure),
    );
    addTearDown(submit.dispose);

    final outcome = await submit.submit();

    expect(outcome.status, ZSubmissionStatus.failure);
    expect(outcome.isValidationFailure, isFalse);
    expect(submit.state.value.failure, failure);
  });

  test('AC4 — exception jetée par onSubmit ⇒ enveloppée en ZFailure (jamais non typée)',
      () async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'a', type: EditionFieldType.text),
    ];
    final c = _ctrl(<String, Object?>{'a': 'ok'});
    addTearDown(c.dispose);
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) async => throw StateError('kaboom'),
    );
    addTearDown(submit.dispose);

    final outcome = await submit.submit();

    expect(outcome.status, ZSubmissionStatus.failure);
    expect(submit.state.value.failure, isA<ZServerFailure>());
    expect(submit.state.value.isValidationFailure, isFalse);
  });

  test('AC5 — inProgress pendant l’attente + garde de ré-entrance (pas de double soumission)',
      () async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'a', type: EditionFieldType.text),
    ];
    final c = _ctrl(<String, Object?>{'a': 'ok'});
    addTearDown(c.dispose);
    final gate = Completer<ZResult<Unit>>();
    var calls = 0;
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) {
        calls++;
        return gate.future;
      },
    );
    addTearDown(submit.dispose);

    final first = submit.submit();
    expect(submit.state.value.status, ZSubmissionStatus.inProgress);

    // Seconde invocation concurrente ⇒ ignorée.
    final ignored = await submit.submit();
    expect(ignored.status, ZSubmissionStatus.inProgress);
    expect(calls, 1, reason: 'onSubmit appelé une seule fois');

    gate.complete(Right<ZFailure, Unit>(unit));
    await first;
    expect(submit.state.value.status, ZSubmissionStatus.success);
    expect(c.isDirty.value, isFalse, reason: 'markPristine après succès');
  });

  testWidgets('AC5/AC6 — bouton : inProgress désactivé+spinner ; échec ⇒ message liveRegion réactivé',
      (tester) async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'a', type: EditionFieldType.text),
    ];
    final c = _ctrl(<String, Object?>{'a': 'ok'});
    addTearDown(c.dispose);
    var gate = Completer<ZResult<Unit>>();
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) => gate.future,
    );
    addTearDown(submit.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZSubmitButton<Unit>(controller: submit, label: 'Enregistrer'),
      ),
    ));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // inProgress : spinner + bouton désactivé.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    // Échec applicatif ⇒ message accessible + bouton réactivé.
    gate.complete(const Left<ZFailure, Unit>(ZServerFailure('serveur indisponible')));
    await tester.pump();
    expect(find.text('serveur indisponible'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    // La surface d’erreur est sous un noeud liveRegion (AD-11/AC6).
    final liveRegions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.liveRegion ?? false);
    expect(liveRegions, isNotEmpty);

    // Nouvel essai possible (bouton réactivé).
    gate = Completer<ZResult<Unit>>();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(Right<ZFailure, Unit>(unit));
    await tester.pump();
  });
}
