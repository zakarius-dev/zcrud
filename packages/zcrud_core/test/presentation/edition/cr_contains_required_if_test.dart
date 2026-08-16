// Deux manques comblés ensemble : montrer un champ quand une option est
// cochée (`ZCondition.contains`), et exiger une valeur seulement quand une
// condition tient (`ZValidatorSpec.requiredIf`).
//
// Ce que ces gardes fixent :
//   (a) un champ conditionné par `contains` apparaît quand l'option est
//       cochée, disparaît quand elle est décochée, et se compose avec
//       `and`/`or`/`not` ;
//   (d) trois champs « requis tant que les deux autres sont vides » REFUSENT
//       la soumission quand les trois sont vides, et l'ACCEPTENT dès qu'un
//       seul est rempli — assertion sur le RÉSULTAT de soumission, pas sur
//       l'affichage ;
//   (e) condition non tenue ⇒ le champ vide est accepté, comme tout champ qui
//       ne déclare pas `required` (règle : seule la famille « requis » porte
//       la présence) ;
//   (f) contre-témoin : un formulaire n'employant ni l'un ni l'autre se
//       comporte exactement comme avant.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _ctrl(Map<String, Object?> values) =>
    ZFormController(initialValues: values, visibleFields: values.keys.toList());

/// Formulaire minimal : la visibilité est le seul sujet, chaque champ est donc
/// rendu par un simple marqueur porteur de son nom.
Widget _form(ZFormController controller, List<ZFieldSpec> fields) => MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          fieldBuilder: (context, ctrl, field) =>
              SizedBox(key: ValueKey<String>('marqueur_${field.name}')),
        ),
      ),
    );

Finder _marqueur(String name) =>
    find.byKey(ValueKey<String>('marqueur_$name'));

void main() {
  group('(a) Un champ suit une option de sélection multiple', () {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'bureaux', type: EditionFieldType.tags),
      ZFieldSpec(name: 'actif', type: EditionFieldType.boolean),
      ZFieldSpec(
        name: 'quotaLome',
        type: EditionFieldType.number,
        condition: ZCondition.contains('bureaux', 'lome'),
      ),
      ZFieldSpec(
        name: 'quotaLomeActif',
        type: EditionFieldType.number,
        condition: ZCondition.and(<ZCondition>[
          ZCondition.contains('bureaux', 'lome'),
          ZCondition.truthy('actif'),
        ]),
      ),
      ZFieldSpec(
        name: 'sansLome',
        type: EditionFieldType.number,
        condition: ZCondition.not(ZCondition.contains('bureaux', 'lome')),
      ),
      ZFieldSpec(
        name: 'lomeOuActif',
        type: EditionFieldType.number,
        condition: ZCondition.or(<ZCondition>[
          ZCondition.contains('bureaux', 'lome'),
          ZCondition.truthy('actif'),
        ]),
      ),
    ];

    testWidgets('coché ⇒ le champ apparaît ; décoché ⇒ il disparaît',
        (tester) async {
      final controller = _ctrl(<String, Object?>{
        'bureaux': <String>[],
        'actif': false,
        'quotaLome': null,
        'quotaLomeActif': null,
        'sansLome': null,
        'lomeOuActif': null,
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_form(controller, fields));
      await tester.pumpAndSettle();

      // Aucune option cochée : seul le champ « sans Lomé » est présent.
      expect(_marqueur('quotaLome'), findsNothing);
      expect(_marqueur('quotaLomeActif'), findsNothing);
      expect(_marqueur('lomeOuActif'), findsNothing);
      expect(_marqueur('sansLome'), findsOneWidget);

      // On coche Lomé (parmi d'autres bureaux).
      controller.setValue('bureaux', <String>['kara', 'lome']);
      await tester.pumpAndSettle();
      expect(_marqueur('quotaLome'), findsOneWidget);
      expect(_marqueur('lomeOuActif'), findsOneWidget);
      expect(_marqueur('sansLome'), findsNothing);
      expect(
        _marqueur('quotaLomeActif'),
        findsNothing,
        reason: 'le ET attend aussi que le dossier soit actif',
      );

      // Le second terme du ET devient vrai.
      controller.setValue('actif', true);
      await tester.pumpAndSettle();
      expect(_marqueur('quotaLomeActif'), findsOneWidget);

      // On décoche Lomé : le champ disparaît, le reste suit ses propres règles.
      controller.setValue('bureaux', <String>['kara']);
      await tester.pumpAndSettle();
      expect(_marqueur('quotaLome'), findsNothing);
      expect(_marqueur('quotaLomeActif'), findsNothing);
      expect(_marqueur('sansLome'), findsOneWidget);
      expect(
        _marqueur('lomeOuActif'),
        findsOneWidget,
        reason: 'le OU tient encore par « actif »',
      );

      // Le champ conserve sa place ordinale canonique quand il revient.
      controller.setValue('bureaux', <String>['lome']);
      await tester.pumpAndSettle();
      expect(controller.visibleFields.value, <String>[
        'bureaux',
        'actif',
        'quotaLome',
        'quotaLomeActif',
        'lomeOuActif',
      ]);
    });

    testWidgets('une valeur qui n\'est pas une collection masque le champ',
        (tester) async {
      final controller = _ctrl(<String, Object?>{
        // Champ à valeur unique : l'appartenance n'y répond jamais `true`.
        'bureaux': 'lome-port',
        'actif': false,
        'quotaLome': null,
        'quotaLomeActif': null,
        'sansLome': null,
        'lomeOuActif': null,
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_form(controller, fields));
      await tester.pumpAndSettle();

      expect(
        _marqueur('quotaLome'),
        findsNothing,
        reason: 'une chaîne ne « contient » pas au sens de cet opérateur',
      );
      expect(_marqueur('sansLome'), findsOneWidget);
    });
  });

  group('(d) « Au moins un des trois » refuse et accepte au bon moment', () {
    // Chaque critère est requis TANT QUE les deux autres sont vides.
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'nts',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[
          ZValidatorSpec.requiredIf(
            ZCondition.and(<ZCondition>[
              ZCondition.isEmpty('cst'),
              ZCondition.isEmpty('marque'),
            ]),
            errorText: 'Renseignez au moins un critère',
          ),
        ],
      ),
      ZFieldSpec(
        name: 'cst',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[
          ZValidatorSpec.requiredIf(
            ZCondition.and(<ZCondition>[
              ZCondition.isEmpty('nts'),
              ZCondition.isEmpty('marque'),
            ]),
            errorText: 'Renseignez au moins un critère',
          ),
        ],
      ),
      ZFieldSpec(
        name: 'marque',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[
          ZValidatorSpec.requiredIf(
            ZCondition.and(<ZCondition>[
              ZCondition.isEmpty('nts'),
              ZCondition.isEmpty('cst'),
            ]),
            errorText: 'Renseignez au moins un critère',
          ),
        ],
      ),
    ];

    Future<(ZSubmissionOutcome<Unit>, int)> soumettre(
      Map<String, Object?> valeurs,
    ) async {
      final controller = _ctrl(valeurs);
      addTearDown(controller.dispose);
      var appels = 0;
      final submit = ZEditionSubmitController<Unit>(
        controller: controller,
        fields: fields,
        onSubmit: (values) async {
          appels++;
          return Right<ZFailure, Unit>(unit);
        },
      );
      addTearDown(submit.dispose);
      return (await submit.submit(), appels);
    }

    test('les trois vides ⇒ soumission REFUSÉE, seam jamais appelé', () async {
      final (outcome, appels) = await soumettre(<String, Object?>{
        'nts': '',
        'cst': '',
        'marque': '',
      });
      expect(outcome.isValidationFailure, isTrue);
      expect(appels, 0);
      expect(
        (outcome.failure! as ZValidationFailure).errors.keys.toSet(),
        <String>{'nts', 'cst', 'marque'},
        reason: 'chacun des trois porte le message tant qu\'aucun n\'est '
            'renseigné',
      );
    });

    test('un seul rempli ⇒ soumission ACCEPTÉE', () async {
      for (final rempli in <String>['nts', 'cst', 'marque']) {
        final (outcome, appels) = await soumettre(<String, Object?>{
          'nts': rempli == 'nts' ? '12345' : '',
          'cst': rempli == 'cst' ? '8703' : '',
          'marque': rempli == 'marque' ? 'Toyota' : '',
        });
        expect(
          outcome.isSuccess,
          isTrue,
          reason: 'la recherche par le seul critère « $rempli » doit passer',
        );
        expect(appels, 1);
      }
    });

    test('une collection vide compte comme vide, une pleine comme remplie',
        () async {
      final (refuse, _) = await soumettre(<String, Object?>{
        'nts': <String>[],
        'cst': '',
        'marque': '',
      });
      expect(refuse.isValidationFailure, isTrue);

      final (accepte, _) = await soumettre(<String, Object?>{
        'nts': <String>['12345'],
        'cst': '',
        'marque': '',
      });
      expect(accepte.isSuccess, isTrue);
    });
  });

  group('(e) Condition non tenue ⇒ le vide est accepté', () {
    const champ = ZFieldSpec(
      name: 'motif',
      type: EditionFieldType.text,
      validators: <ZValidatorSpec>[
        ZValidatorSpec.requiredIf(
          ZCondition.truthy('contentieux'),
          errorText: 'Motif obligatoire',
        ),
        ZValidatorSpec.minLength(4, errorText: 'Trop court'),
      ],
    );
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'contentieux', type: EditionFieldType.boolean),
      champ,
    ];

    test('condition fausse : champ vide accepté, forme toujours vérifiée', () {
      final controller = _ctrl(<String, Object?>{
        'contentieux': false,
        'motif': '',
      });
      addTearDown(controller.dispose);

      expect(
        zValidateFormFields(fields: fields, controller: controller),
        isEmpty,
        reason: 'sans condition tenue, un champ vide se comporte comme un '
            'champ sans `required`',
      );

      controller.setValue('motif', 'ab');
      expect(
        zValidateFormFields(fields: fields, controller: controller),
        <String, String>{'motif': 'Trop court'},
        reason: 'la forme garde son verrou dès que le champ est rempli',
      );
    });

    test('condition vraie : le vide est refusé, comme `required`', () {
      final controller = _ctrl(<String, Object?>{
        'contentieux': true,
        'motif': '',
      });
      addTearDown(controller.dispose);

      expect(
        zValidateFormFields(fields: fields, controller: controller),
        <String, String>{'motif': 'Motif obligatoire'},
      );

      controller.setValue('motif', 'fraude');
      expect(
        zValidateFormFields(fields: fields, controller: controller),
        isEmpty,
      );
    });

    test('un champ masqué ne bloque jamais, même sa condition tenue', () {
      const masque = <ZFieldSpec>[
        ZFieldSpec(name: 'contentieux', type: EditionFieldType.boolean),
        ZFieldSpec(
          name: 'motif',
          type: EditionFieldType.text,
          condition: ZCondition.truthy('jamais'),
          validators: <ZValidatorSpec>[
            ZValidatorSpec.requiredIf(
              ZCondition.truthy('contentieux'),
              errorText: 'Motif obligatoire',
            ),
          ],
        ),
      ];
      final controller = _ctrl(<String, Object?>{
        'contentieux': true,
        'motif': '',
        'jamais': false,
      });
      addTearDown(controller.dispose);

      expect(
        zValidateFormFields(fields: masque, controller: controller),
        isEmpty,
      );
    });

    test('la condition lit aussi la valeur d\'origine du formulaire', () {
      const surBaseline = <ZFieldSpec>[
        ZFieldSpec(
          name: 'motif',
          type: EditionFieldType.text,
          validators: <ZValidatorSpec>[
            ZValidatorSpec.requiredIf(
              ZCondition.truthy('statut', source: ZValueSource.persisted),
              errorText: 'Motif obligatoire',
            ),
          ],
        ),
      ];
      final controller = _ctrl(<String, Object?>{
        'statut': 'clos',
        'motif': '',
      });
      addTearDown(controller.dispose);

      expect(
        zValidateFormFields(fields: surBaseline, controller: controller),
        <String, String>{'motif': 'Motif obligatoire'},
        reason: 'la baseline porte « clos » : la condition tient',
      );

      // La saisie courante change, la valeur d'ORIGINE non.
      controller.setValue('statut', '');
      expect(
        zValidateFormFields(fields: surBaseline, controller: controller),
        <String, String>{'motif': 'Motif obligatoire'},
      );
    });

    test('le champ observé alimente l\'abonnement ciblé du champ dépendant',
        () {
      expect(
        ZCrossFieldValidator.refKeysOf(champ.validators),
        <String>{'contentieux'},
        reason: 'sans cet abonnement, le message n\'apparaîtrait qu\'à la '
            'prochaine frappe sur le champ lui-même',
      );
    });

    testWidgets(
        'le champ se réévalue quand la condition change, et lui seul',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const observes = <ZFieldSpec>[
        ZFieldSpec(name: 'contentieux', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'motif',
          type: EditionFieldType.text,
          validators: <ZValidatorSpec>[
            ZValidatorSpec.requiredIf(
              ZCondition.truthy('contentieux'),
              errorText: 'Motif obligatoire',
            ),
          ],
        ),
        ZFieldSpec(name: 'autre', type: EditionFieldType.text),
      ];
      final controller = _ctrl(<String, Object?>{
        'contentieux': '',
        'motif': '',
        'autre': '',
      });
      addTearDown(controller.dispose);

      final builds = <String, int>{};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: observes,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onBuild: () => builds[field.name] = (builds[field.name] ?? 0) + 1,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final depart = builds['motif']!;

      Future<void> saisir(String champ, String texte) => tester.enterText(
            find.descendant(
              of: find.byKey(ValueKey<String>(champ)),
              matching: find.byType(EditableText),
            ),
            texte,
          );

      // Un champ tiers ne concerne pas la condition : aucune réévaluation.
      await saisir('autre', 'peu importe');
      await tester.pump();
      expect(
        builds['motif'],
        depart,
        reason: 'un champ étranger à la condition ne reconstruit rien',
      );

      // Le champ OBSERVÉ par la condition, lui, la fait rejouer.
      await saisir('contentieux', 'oui');
      await tester.pump();
      expect(
        builds['motif']! > depart,
        isTrue,
        reason: 'sans cette réévaluation, le message n\'apparaîtrait qu\'à la '
            'prochaine frappe sur le champ conditionné',
      );
    });

    test('`requiredIf` reste hors du compilateur champ-local', () {
      expect(
        ZValidatorCompiler.compile(<ZValidatorSpec>[
          const ZValidatorSpec.requiredIf(ZCondition.truthy('contentieux')),
        ]),
        isNull,
        reason: 'un validateur champ-local ne peut pas lire un autre champ',
      );
    });

    test('l\'astérisque « requis » reste réservé à une exigence inconditionnelle',
        () {
      expect(champ.isRequired, isFalse);
      expect(
        const ZFieldSpec(
          name: 'x',
          type: EditionFieldType.text,
          validators: <ZValidatorSpec>[ZValidatorSpec.required()],
        ).isRequired,
        isTrue,
      );
    });

    test('`required` et `requiredIf` cumulés reviennent à `required`', () {
      const cumul = <ZFieldSpec>[
        ZFieldSpec(
          name: 'motif',
          type: EditionFieldType.text,
          validators: <ZValidatorSpec>[
            ZValidatorSpec.required(errorText: 'Toujours requis'),
            ZValidatorSpec.requiredIf(
              ZCondition.truthy('contentieux'),
              errorText: 'Requis si contentieux',
            ),
          ],
        ),
      ];
      final controller = _ctrl(<String, Object?>{
        'contentieux': false,
        'motif': '',
      });
      addTearDown(controller.dispose);
      expect(
        zValidateFormFields(fields: cumul, controller: controller),
        <String, String>{'motif': 'Toujours requis'},
      );
    });
  });

  group('(f) Contre-témoin : sans ces deux nouveautés, rien ne bouge', () {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'email',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[
          ZValidatorSpec.required(errorText: 'manquant'),
          ZValidatorSpec.email(errorText: 'format e-mail'),
        ],
      ),
      ZFieldSpec(
        name: 'telephone',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[
          ZValidatorSpec.pattern(r'^\+228[0-9]{8}$', errorText: 'format tél.'),
        ],
      ),
      ZFieldSpec(
        name: 'complement',
        type: EditionFieldType.text,
        condition: ZCondition.truthy('email'),
      ),
    ];

    test('mêmes verdicts de validation qu\'auparavant', () {
      final controller = _ctrl(<String, Object?>{
        'email': '',
        'telephone': '',
        'complement': '',
      });
      addTearDown(controller.dispose);

      expect(
        zValidateFormFields(fields: fields, controller: controller),
        <String, String>{'email': 'manquant'},
        reason: 'seul `required` porte la présence ; le motif laisse passer '
            'le vide',
      );

      controller.setValue('email', 'awa@example.tg');
      expect(
        zValidateFormFields(fields: fields, controller: controller),
        isEmpty,
      );

      controller.setValue('telephone', '90123456');
      expect(
        zValidateFormFields(fields: fields, controller: controller),
        <String, String>{'telephone': 'format tél.'},
      );
    });

    test('aucun abonnement ciblé supplémentaire n\'est pris', () {
      for (final field in fields) {
        expect(
          ZCrossFieldValidator.refKeysOf(field.validators),
          isEmpty,
          reason: '${field.name} : aucun validateur inter-champs déclaré',
        );
      }
    });

    testWidgets('même visibilité, mêmes places', (tester) async {
      final controller = _ctrl(<String, Object?>{
        'email': '',
        'telephone': '',
        'complement': '',
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_form(controller, fields));
      await tester.pumpAndSettle();
      expect(controller.visibleFields.value, <String>['email', 'telephone']);

      controller.setValue('email', 'awa@example.tg');
      await tester.pumpAndSettle();
      expect(
        controller.visibleFields.value,
        <String>['email', 'telephone', 'complement'],
      );
    });
  });
}
