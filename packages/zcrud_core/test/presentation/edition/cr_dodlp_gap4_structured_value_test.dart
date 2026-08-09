// CR-DODLP-GAP4 — champ CUSTOM écrivant une valeur STRUCTURÉE (map).
//
// Verdict mesuré AVANT toute écriture : le socle portait déjà l'essentiel —
// `ZFieldWidgetContext.onChanged` est un `ValueChanged<Object?>` (donc une map
// s'écrit telle quelle), `zValidationText` faisait déjà mordre `required` sur
// une map vide sous `DynamicEdition` et à la soumission, et la granularité
// AD-2 valait déjà. Le gap réel était ÉTROIT et unique : le **gate d'étape** de
// `ZStepperEdition` portait sa propre projection de validation, qui rendait
// `"{}"` — non vide — et laissait donc passer « Suivant ».
//
//   D1  la map écrite arrive TELLE QUELLE dans la tranche (aucun encodage) ;
//   D2  `required` mord sur `{}` et se tait sur une map garnie (deux branches) ;
//   D3  le gate d'étape refuse `{}` et accepte une map garnie (deux branches) ;
//   D4  AD-2/SM-1 : changer une entrée ne reconstruit QUE ce champ ;
//   D5  la map traverse la soumission sans altération (AD-3) ;
//   D6  la règle de vacuité du dépôt est EXPORTÉE (un hôte n'en réinvente pas
//       une seconde qui divergerait de `required`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _perms = ZFieldSpec(
  name: 'perms',
  type: EditionFieldType.custom,
  label: 'Permissions',
  validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQ-PERM')],
);

const _autre =
    ZFieldSpec(name: 'autre', type: EditionFieldType.text, label: 'Autre');

/// Éditeur composite MINIMAL : il n'existe que pour prouver le contrat de
/// tranche. Ce n'est pas un éditeur de permissions — celui-là est métier.
ZWidgetRegistry _registry({void Function()? onBuild, Map<String, Object?>? write}) {
  return ZWidgetRegistry()
    ..register('custom', (context, ctx) {
      onBuild?.call();
      return TextButton(
        key: const ValueKey<String>('composite'),
        onPressed: () => ctx.onChanged(
          write ??
              const <String, Object?>{
                'agent': <String>['read', 'update'],
              },
        ),
        child: Text('entrées=${(ctx.value as Map<Object?, Object?>?)?.length}'),
      );
    });
}

void main() {
  // ── D1/D2 — tranche + requis sous `DynamicEdition` ────────────────────────

  testWidgets(
      'D1/D2 — la map est déposée telle quelle ; `required` mord sur `{}` et '
      'se tait dès qu\'elle est garnie', (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{'perms': <String, Object?>{}},
      visibleFields: const <String>['perms'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ZcrudScope(
        widgetRegistry: _registry(),
        child: Scaffold(
          body: DynamicEdition(
            controller: c,
            fields: const <ZFieldSpec>[_perms],
            fieldBuilder: (context, ctrl, f) => ZFieldWidget(
              controller: ctrl,
              field: f,
              autovalidateMode: AutovalidateMode.always,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Branche VIDE : le message est là, et le champ est bien monté.
    expect(find.byKey(const ValueKey<String>('composite')), findsOneWidget);
    expect(find.text('REQ-PERM'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('composite')));
    await tester.pumpAndSettle();

    // D1 : la MAP, pas sa stringification.
    final v = c.valueOf('perms');
    expect(v, isA<Map<String, Object?>>());
    expect((v! as Map<String, Object?>)['agent'], <String>['read', 'update']);
    // Branche GARNIE : le message a disparu (anti-tautologie).
    expect(find.text('REQ-PERM'), findsNothing);
  });

  // ── D3 — gate d'étape, LES DEUX branches ──────────────────────────────────

  testWidgets(
      'D3 — le gate d\'étape refuse une map REQUISE vide et accepte une map '
      'garnie', (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{
        'perms': <String, Object?>{},
        'autre': 'x',
      },
      visibleFields: const <String>['perms', 'autre'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ZcrudScope(
        widgetRegistry: _registry(),
        child: Scaffold(
          body: ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[_perms, _autre],
            steps: const <ZEditionStep>[
              ZEditionStep(title: 'Autorisations', fields: <String>['perms']),
              ZEditionStep(title: 'Suite', fields: <String>['autre']),
            ],
            onComplete: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Suivant'));
    await tester.pumpAndSettle();
    expect(c.visibleFields.value, <String>['perms'],
        reason: 'une map requise VIDE ne doit pas franchir le gate');

    await tester.tap(find.byKey(const ValueKey<String>('composite')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Suivant'));
    await tester.pumpAndSettle();
    expect(c.visibleFields.value, <String>['autre']);
  });

  // ── D4 — AD-2/SM-1 ────────────────────────────────────────────────────────

  testWidgets(
      'D4 — écrire une entrée de la map ne reconstruit QUE le champ composite',
      (tester) async {
    _bigView(tester);
    var composite = 0;
    var autre = 0;
    final c = ZFormController(
      initialValues: const <String, Object?>{
        'perms': <String, Object?>{},
        'autre': 'x',
      },
      visibleFields: const <String>['perms', 'autre'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ZcrudScope(
        widgetRegistry: _registry(onBuild: () => composite++),
        child: Scaffold(
          body: DynamicEdition(
            controller: c,
            fields: const <ZFieldSpec>[_perms, _autre],
            fieldBuilder: (context, ctrl, f) {
              if (f.name == 'autre') autre++;
              return ZFieldWidget(controller: ctrl, field: f);
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final compositeBefore = composite;
    final autreBefore = autre;

    await tester.tap(find.byKey(const ValueKey<String>('composite')));
    await tester.pumpAndSettle();

    // Le scénario a bien eu lieu…
    expect((c.valueOf('perms')! as Map<Object?, Object?>).length, 1);
    // …le champ composite s'est recomposé…
    expect(composite, greaterThan(compositeBefore));
    // …et le voisin n'a pas bougé d'un rebuild.
    expect(autre, autreBefore);
  });

  // ── D5 — soumission ───────────────────────────────────────────────────────

  test('D5 — la map traverse la soumission sans altération', () async {
    final c = ZFormController(
      initialValues: const <String, Object?>{'perms': <String, Object?>{}},
      visibleFields: const <String>['perms'],
    );
    addTearDown(c.dispose);
    Map<String, Object?>? seen;
    final submit = ZEditionSubmitController<int>(
      controller: c,
      fields: const <ZFieldSpec>[_perms],
      onSubmit: (values) async {
        seen = values;
        return const Right<ZFailure, int>(1);
      },
    );
    addTearDown(submit.dispose);

    // Map vide ⇒ REFUS de soumettre (le seam n'est pas appelé).
    final refused = await submit.submit();
    expect(refused.status, ZSubmissionStatus.failure);
    expect(seen, isNull);

    c.setValue('perms', const <String, Object?>{
      'agent': <String>['read'],
    });
    final ok = await submit.submit();
    expect(ok.status, ZSubmissionStatus.success);
    expect(seen!['perms'], const <String, Object?>{
      'agent': <String>['read'],
    });
  });

  // ── D6 — règle de vacuité exportée ────────────────────────────────────────

  test('D6 — `zIsEmptyValue`/`zValidationText` sont la règle UNIQUE, exportée',
      () {
    expect(zIsEmptyValue(const <String, Object?>{}), isTrue);
    expect(zIsEmptyValue(const <String, Object?>{'a': 1}), isFalse);
    // La projection qui fait mordre `required` : une map vide devient `''`.
    expect(zValidationText(const <String, Object?>{}), '');
    expect(zValidationText(const <String, Object?>{'a': 1}), isNotEmpty);
    // Le piège inverse : `false`/`0` sont des valeurs PRÉSENTES.
    expect(zIsEmptyValue(false), isFalse);
    expect(zIsEmptyValue(0), isFalse);
  });
}
