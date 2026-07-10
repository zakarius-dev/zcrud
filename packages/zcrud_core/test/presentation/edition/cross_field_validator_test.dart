// E3-6 — Validateurs inter-champs (AC10 match, AC11 min/maxKey, AC12 live).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('AC10 — match(refKey) : égalité à la valeur du champ référencé', () {
    final c = ZFormController(initialValues: <String, Object?>{
      'password': 'secret',
      'confirm': 'secret',
    });
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'confirm',
      type: EditionFieldType.password,
      validators: <ZValidatorSpec>[
        ZValidatorSpec.match('password', errorText: 'ne correspond pas'),
      ],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;

    expect(v('autre'), 'ne correspond pas');
    expect(v('secret'), isNull);

    // La closure lit `valueOf(refKey)` à l'invocation (runtime, pas figé).
    c.setValue('password', 'change');
    expect(v('secret'), 'ne correspond pas');
    expect(v('change'), isNull);
  });

  test('AC11 — minKey/maxKey par refKey (comparaison numérique)', () {
    final c = ZFormController(initialValues: <String, Object?>{
      'debut': '5',
      'fin': '3',
    });
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'fin',
      type: EditionFieldType.number,
      validators: <ZValidatorSpec>[
        ZValidatorSpec.minKey('debut', errorText: 'avant le début'),
      ],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;

    expect(v('3'), 'avant le début'); // 3 < 5
    expect(v('5'), isNull);
    expect(v('7'), isNull);
  });

  test('MEDIUM-1 — minKey sur DATES ISO : plage inversée = erreur, correcte = null',
      () {
    // Exemple NORMATIF d'AC11 : `dateFin.minKey('dateDebut')`.
    final c = ZFormController(initialValues: <String, Object?>{
      'dateDebut': '2026-05-10',
    });
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'dateFin',
      type: EditionFieldType.dateTime,
      validators: <ZValidatorSpec>[
        ZValidatorSpec.minKey('dateDebut', errorText: 'fin avant début'),
      ],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;

    // Plage INVERSÉE (fin < début) ⇒ ERREUR (avant : passait silencieusement).
    expect(v('2026-01-01'), 'fin avant début');
    // Plage correcte (fin >= début) ⇒ null.
    expect(v('2026-06-01'), isNull);
    expect(v('2026-05-10'), isNull, reason: 'égalité ⇒ valide pour min');
  });

  test('MEDIUM-1 — maxKey sur DATES ISO : dépassement = erreur, dans borne = null',
      () {
    final c = ZFormController(initialValues: <String, Object?>{
      'dateFin': '2026-05-10',
    });
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'dateDebut',
      type: EditionFieldType.dateTime,
      validators: <ZValidatorSpec>[
        ZValidatorSpec.maxKey('dateFin', errorText: 'début après fin'),
      ],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;

    expect(v('2026-09-01'), 'début après fin'); // début > fin
    expect(v('2026-01-01'), isNull);
    expect(v('2026-05-10'), isNull, reason: 'égalité ⇒ valide pour max');
  });

  test('MEDIUM-1 — minKey sur DateTime déjà typé (valeur non textuelle)', () {
    final c = ZFormController(initialValues: <String, Object?>{
      'dateDebut': DateTime(2026, 5, 10),
    });
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'dateFin',
      type: EditionFieldType.dateTime,
      validators: <ZValidatorSpec>[ZValidatorSpec.minKey('dateDebut')],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;
    expect(v('2026-01-01'), isNotNull, reason: 'plage inversée détectée');
    expect(v('2026-06-01'), isNull);
  });

  test('MEDIUM-1 — num toujours honoré (priorité numérique sur date)', () {
    final c = ZFormController(initialValues: <String, Object?>{'debut': '5'});
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'fin',
      type: EditionFieldType.number,
      validators: <ZValidatorSpec>[ZValidatorSpec.minKey('debut')],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;
    expect(v('3'), isNotNull); // 3 < 5
    expect(v('9'), isNull);
  });

  test('MEDIUM-1 — types non comparables (texte libre) ⇒ non bloquant', () {
    final c = ZFormController(initialValues: <String, Object?>{'ref': 'bonjour'});
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'v',
      type: EditionFieldType.text,
      validators: <ZValidatorSpec>[ZValidatorSpec.minKey('ref')],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;
    // Ni num, ni DateTime des deux côtés ⇒ référence indéterminée ⇒ pas d'erreur.
    expect(v('aardvark'), isNull);
    expect(v('zzz'), isNull);
  });

  test('AC11 — référence indéterminée / non numérique ⇒ non bloquant', () {
    final c = ZFormController(initialValues: <String, Object?>{'ref': 'abc'});
    addTearDown(c.dispose);
    const field = ZFieldSpec(
      name: 'v',
      type: EditionFieldType.number,
      validators: <ZValidatorSpec>[ZValidatorSpec.minKey('ref')],
    );
    final v = ZCrossFieldValidator.compileField(field, c)!;
    expect(v('3'), isNull, reason: 'ref non numérique ⇒ ne rejette pas');

    final c2 = ZFormController(initialValues: <String, Object?>{});
    addTearDown(c2.dispose);
    final v2 = ZCrossFieldValidator.compileField(field, c2)!;
    expect(v2('3'), isNull, reason: 'ref absente ⇒ ne rejette pas');
  });

  test('refKeysOf ne remonte que les specs inter-champs', () {
    const specs = <ZValidatorSpec>[
      ZValidatorSpec.required(),
      ZValidatorSpec.match('password'),
      ZValidatorSpec.minKey('debut'),
      ZValidatorSpec.min(3), // littéral ⇒ pas un refKey
    ];
    expect(ZCrossFieldValidator.refKeysOf(specs), <String>{'password', 'debut'});
  });

  testWidgets('AC12 — le champ dépendant se réévalue quand le champ RÉFÉRENCÉ change ; '
      'taper dans un champ TIERS ne le reconstruit pas', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'password', type: EditionFieldType.password),
      ZFieldSpec(
        name: 'confirm',
        type: EditionFieldType.password,
        validators: <ZValidatorSpec>[ZValidatorSpec.match('password')],
      ),
      ZFieldSpec(name: 'email', type: EditionFieldType.text),
    ];
    final c = ZFormController(
      initialValues: <String, Object?>{'password': '', 'confirm': '', 'email': ''},
      visibleFields: const <String>['password', 'confirm', 'email'],
    );
    addTearDown(c.dispose);

    final builds = <String, int>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: c,
          fields: fields,
          fieldBuilder: (context, ctrl, field) => ZFieldWidget(
            controller: ctrl,
            field: field,
            onBuild: () =>
                builds[field.name] = (builds[field.name] ?? 0) + 1,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final confirmBuilds0 = builds['confirm']!;

    // Taper dans un champ TIERS (email) ⇒ confirm NON reconstruit (SM-1).
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('email')),
        matching: find.byType(EditableText),
      ),
      'a@b.c',
    );
    await tester.pump();
    expect(builds['confirm'], confirmBuilds0,
        reason: 'un champ tiers ne reconstruit pas le champ dépendant');

    // Modifier le champ RÉFÉRENCÉ (password) ⇒ confirm se réévalue (rebuild).
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('password')),
        matching: find.byType(EditableText),
      ),
      'zzz',
    );
    await tester.pump();
    expect(builds['confirm']! > confirmBuilds0, isTrue,
        reason: 'le champ dépendant se réévalue quand le référencé change');
  });
}
