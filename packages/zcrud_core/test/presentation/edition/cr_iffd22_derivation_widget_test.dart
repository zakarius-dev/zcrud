// CR-IFFD-22 — câblage END-TO-END des dérivations dans `DynamicEdition`.
//
// Prouve que les cibles se branchent sur les canaux EXISTANTS :
//   • `visible` → canal STRUCTUREL `controller.visibleFields` (composé en ET
//     avec `ZFieldSpec.condition`, jamais en concurrence) ;
//   • `options` → tranche lue par `ZSelectConfig.choicesFromKey` (rendu radio) ;
//   • `value`   → tranche du champ (widget rebuild CIBLÉ) ;
//   • SM-1 (AD-2) — une dérivation ne reconstruit QUE les champs concernés :
//     un champ tiers n'est ni reconstruit ni ré-initialisé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

/// Harnais instrumenté (mêmes compteurs que `conditional_visibility_test`).
class _Harness {
  _Harness(this.fields, {Map<String, Object?>? initial, List<String>? visible})
      : controller = ZFormController(
          initialValues: initial,
          visibleFields: visible,
        );

  final List<ZFieldSpec> fields;
  final ZFormController controller;
  final Map<String, int> fieldBuilds = <String, int>{};
  final Map<String, int> fieldInits = <String, int>{};
  int formBuilds = 0;

  Widget build() => MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            onStructuralBuild: () => formBuilds++,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onInit: () =>
                  fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
              onBuild: () =>
                  fieldBuilds[field.name] = (fieldBuilds[field.name] ?? 0) + 1,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

void main() {
  testWidgets('visible — la dérivation pilote le canal EXISTANT visibleFields',
      (tester) async {
    final h = _Harness(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'flag', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'dep',
          type: EditionFieldType.text,
          derivedFrom: ZDerivation(
            sources: const <String>['flag'],
            overwrite: ZDerivationOverwrite.always,
            visible: (v) => v['flag'] == 'go',
          ),
        ),
        const ZFieldSpec(name: 'other', type: EditionFieldType.text),
      ],
      initial: const <String, Object?>{'flag': '', 'dep': '', 'other': ''},
      visible: const <String>['flag', 'dep', 'other'],
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    // Amorçage : `visible` est calculé dès l'attache ⇒ `dep` masqué.
    expect(h.controller.visibleFields.value, <String>['flag', 'other']);
    expect(_key('dep'), findsNothing);

    await tester.enterText(_key('flag'), 'go');
    await tester.pumpAndSettle();
    expect(h.controller.visibleFields.value, <String>['flag', 'dep', 'other']);
    expect(_key('dep'), findsOneWidget);

    // PLACE ordinale préservée (réinsertion à l'index canonique).
    await tester.enterText(_key('flag'), 'stop');
    await tester.pumpAndSettle();
    expect(h.controller.visibleFields.value, <String>['flag', 'other']);
  });

  testWidgets('visible ET condition — les deux se COMPOSENT (jamais l’une OU l’autre)',
      (tester) async {
    final h = _Harness(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'a', type: EditionFieldType.text),
        const ZFieldSpec(name: 'b', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'dep',
          type: EditionFieldType.text,
          // Voie DÉCLARATIVE pur-données (par défaut).
          condition: const ZCondition.truthy('a'),
          // Échappatoire IMPÉRATIVE (calcul non exprimable en ZCondition).
          derivedFrom: ZDerivation(
            sources: const <String>['b'],
            overwrite: ZDerivationOverwrite.always,
            visible: (v) => (v['b'] as String? ?? '').length > 2,
          ),
        ),
      ],
      initial: const <String, Object?>{'a': '', 'b': '', 'dep': ''},
      visible: const <String>['a', 'b', 'dep'],
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    expect(h.controller.visibleFields.value, <String>['a', 'b']);

    // Condition seule satisfaite ⇒ TOUJOURS masqué (ET, pas OU).
    await tester.enterText(_key('a'), 'x');
    await tester.pumpAndSettle();
    expect(h.controller.visibleFields.value, <String>['a', 'b']);

    // Les deux satisfaites ⇒ visible.
    await tester.enterText(_key('b'), 'xyz');
    await tester.pumpAndSettle();
    expect(h.controller.visibleFields.value, <String>['a', 'b', 'dep']);

    // Condition retombée ⇒ masqué de nouveau.
    await tester.enterText(_key('a'), '');
    await tester.pumpAndSettle();
    expect(h.controller.visibleFields.value, <String>['a', 'b']);
  });

  testWidgets('options — les choix dérivés sont RENDUS (canal choicesFromKey)',
      (tester) async {
    final h = _Harness(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'pays', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'ville',
          type: EditionFieldType.radio,
          config: ZSelectConfig(
            choicesFromKey: ZDerivationChannels.optionsKey('ville'),
          ),
          derivedFrom: ZDerivation(
            sources: const <String>['pays'],
            overwrite: ZDerivationOverwrite.always,
            options: (v) async => v['pays'] == 'fr'
                ? const <ZFieldChoice>[
                    ZFieldChoice(value: 'lyon', label: 'Lyon'),
                  ]
                : const <ZFieldChoice>[
                    ZFieldChoice(value: 'gand', label: 'Gand'),
                  ],
          ),
        ),
      ],
      initial: const <String, Object?>{'pays': 'fr', 'ville': null},
      visible: const <String>['pays', 'ville'],
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    expect(find.text('Lyon'), findsOneWidget);

    await tester.enterText(_key('pays'), 'be');
    await tester.pumpAndSettle();
    expect(find.text('Gand'), findsOneWidget);
    expect(find.text('Lyon'), findsNothing);
  });

  testWidgets(
      'bounds — la borne dérivée est CONSOMMÉE par ZValidatorSpec.minKey',
      (tester) async {
    final h = _Harness(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'commande', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'quantite',
          type: EditionFieldType.number,
          // Canal EXISTANT : la borne est lue dans la tranche compagne écrite
          // par le moteur (aucun nouveau canal de validation).
          validators: <ZValidatorSpec>[
            ZValidatorSpec.minKey(
              ZDerivationChannels.minKey('quantite'),
              errorText: 'sous le minimum',
            ),
          ],
          derivedFrom: ZDerivation(
            sources: const <String>['commande'],
            overwrite: ZDerivationOverwrite.always,
            bounds: (v) => ZFieldBounds(min: v['commande'] == 'gros' ? 10 : 1),
          ),
        ),
      ],
      initial: const <String, Object?>{'commande': '', 'quantite': '5'},
      visible: const <String>['commande', 'quantite'],
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    // Borne dérivée = 1 ⇒ 5 est valide.
    await tester.enterText(_key('quantite'), '5');
    h.controller.revealErrors();
    await tester.pumpAndSettle();
    expect(find.text('sous le minimum'), findsNothing);

    // La source change ⇒ borne dérivée = 10 ⇒ 5 devient invalide, SANS que le
    // champ n'ait été retouché (l'abonnement `refKey` re-valide tout seul).
    await tester.enterText(_key('commande'), 'gros');
    await tester.pumpAndSettle();
    expect(
      h.controller.valueOf(ZDerivationChannels.minKey('quantite')),
      10,
    );
    expect(find.text('sous le minimum'), findsOneWidget);
  });

  testWidgets('SM-1 — une dérivation ne reconstruit QUE les champs concernés',
      (tester) async {
    final h = _Harness(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'src', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'dst',
          type: EditionFieldType.text,
          derivedFrom: ZDerivation(
            sources: const <String>['src'],
            overwrite: ZDerivationOverwrite.always,
            value: (v) async => 'Examen: ${v['src']}',
          ),
        ),
        const ZFieldSpec(name: 'other', type: EditionFieldType.text),
      ],
      initial: const <String, Object?>{'src': '', 'dst': '', 'other': ''},
      visible: const <String>['src', 'dst', 'other'],
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    final formBuildsBefore = h.formBuilds;
    final otherBuildsBefore = h.fieldBuilds['other']!;
    final otherInitsBefore = h.fieldInits['other']!;
    final dstBuildsBefore = h.fieldBuilds['dst']!;

    await tester.enterText(_key('src'), 'Dossier 7');
    await tester.pumpAndSettle();

    // La dérivation a bien écrit la cible…
    expect(h.controller.valueOf('dst'), 'Examen: Dossier 7');
    expect(h.fieldBuilds['dst'], greaterThan(dstBuildsBefore));
    // …SANS reconstruire le champ tiers ni le formulaire (SM-1 / AD-2).
    expect(h.fieldBuilds['other'], otherBuildsBefore);
    expect(h.fieldInits['other'], otherInitsBefore);
    expect(h.formBuilds, formBuildsBefore);
  });

  testWidgets('dispose du formulaire ⇒ moteur détaché (aucun listener fuité)',
      (tester) async {
    var calls = 0;
    final h = _Harness(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'src', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'dst',
          type: EditionFieldType.text,
          derivedFrom: ZDerivation(
            sources: const <String>['src'],
            overwrite: ZDerivationOverwrite.always,
            value: (v) async {
              calls++;
              return v['src'];
            },
          ),
        ),
      ],
      initial: const <String, Object?>{'src': '', 'dst': ''},
      visible: const <String>['src', 'dst'],
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    h.controller.setValue('src', 'a');
    await tester.pumpAndSettle();
    expect(calls, 1);

    // Démonte le formulaire : `DynamicEdition.dispose` doit disposer le moteur.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();
    h.controller.setValue('src', 'b');
    await tester.pumpAndSettle();
    expect(calls, 1, reason: 'aucun listener résiduel après démontage');
  });
}
