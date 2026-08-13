/// **Lot G1+ — capacités avancées du stepper** (directive owner du 2026-08-06 :
/// « ne pas se limiter à ce que DODLP offre aujourd'hui »).
///
/// Trois capacités, chacune assertée sur ce qu'elle CHANGE **et** sur le fait
/// que son défaut ne change **rien** :
/// 1. **étapes conditionnelles** (`ZEditionStep.condition`) — l'étape existe ou
///    n'existe pas, et le « k/N », la navigation et le gate le savent ;
/// 2. **étapes optionnelles** (`ZEditionStep.optional`) — gate relâché sur
///    CETTE étape, strict ailleurs (ce que `validateOnNext: false` ne sait pas
///    faire : il relâche tout) ;
/// 3. **reprise** (`ZStepIndexStore`) — l'étape courante survit au démontage.
///
/// 🔴 Ces gardes n'assèrent JAMAIS un simple « ça se monte » : elles comparent
/// le compte d'étapes rendu, le libellé « k/N », l'identité du champ monté, et
/// la valeur persistée.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));
Finder get _next => find.widgetWithText(FilledButton, 'Next');

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'mode', type: EditionFieldType.text, label: 'Mode'),
  ZFieldSpec(name: 'conteneur', type: EditionFieldType.text, label: 'Conteneur'),
  ZFieldSpec(name: 'fin', type: EditionFieldType.text, label: 'Fin'),
];

/// Étape 1 (« conteneurs ») n'existe QUE si `mode == 'containerised'`.
const List<ZEditionStep> _conditional = <ZEditionStep>[
  ZEditionStep(title: 'Mode', fields: <String>['mode']),
  ZEditionStep(
    title: 'Conteneurs',
    fields: <String>['conteneur'],
    condition: ZCondition.equals('mode', 'containerised'),
  ),
  ZEditionStep(title: 'Fin', fields: <String>['fin']),
];

Widget _host(
  ZFormController controller,
  List<ZEditionStep> steps, {
  ZStepperConfig config = const ZStepperConfig(),
  ZStepIndexStore? store,
  String? formId,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: controller,
          fields: _fields,
          steps: steps,
          config: config,
          stepStore: store,
          formId: formId,
          onComplete: () {},
        ),
      ),
    );

void main() {
  group('capacité 1 — étapes CONDITIONNELLES', () {
    testWidgets('condition FAUSSE : l\'étape est ABSENTE du total et du parcours',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'bulk'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, _conditional));
      await tester.pumpAndSettle();

      // 🔴 Le total le SAIT : 2 étapes, pas 3.
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('1/3'), findsNothing);

      // « Suivant » va directement à « Fin » — l'étape absente n'est pas traversée.
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(_key('fin'), findsOneWidget);
      expect(_key('conteneur'), findsNothing);
    });

    testWidgets('condition VRAIE : l\'étape existe et se traverse',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'containerised'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, _conditional));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('Conteneurs'), findsOneWidget);
      expect(_key('conteneur'), findsOneWidget);
    });

    testWidgets(
        '🔴 la condition bascule EN COURS de saisie : le parcours se recompose',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'bulk'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, _conditional));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      // Le champ de GARDE change : l'étape conditionnelle apparaît, sans que
      // l'hôte n'ait rien recomposé.
      c.setValue('mode', 'containerised');
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget,
          reason: 'l\'étape est apparue sur changement du champ de garde');

      // …et disparaît de nouveau.
      c.setValue('mode', 'bulk');
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets(
        'l\'étape courante est BORNÉE quand des étapes disparaissent derrière',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'containerised'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c.dispose);
      // Dernière étape conditionnelle : on s'y place, puis on la fait
      // disparaître — l'utilisateur doit reculer d'un cran, pas être renvoyé
      // à l'étape 0 (perte de contexte).
      const List<ZEditionStep> steps = <ZEditionStep>[
        ZEditionStep(title: 'Mode', fields: <String>['mode']),
        ZEditionStep(
          title: 'Conteneurs',
          fields: <String>['conteneur'],
          condition: ZCondition.equals('mode', 'containerised'),
        ),
      ];
      await tester.pumpWidget(_host(c, steps));
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      c.setValue('mode', 'bulk');
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      expect(_key('mode'), findsOneWidget);
    });

    testWidgets('DÉFAUT inchangé : sans condition, 3 étapes sur 3',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'bulk'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c.dispose);
      const List<ZEditionStep> nues = <ZEditionStep>[
        ZEditionStep(title: 'Mode', fields: <String>['mode']),
        ZEditionStep(title: 'Conteneurs', fields: <String>['conteneur']),
        ZEditionStep(title: 'Fin', fields: <String>['fin']),
      ];
      await tester.pumpWidget(_host(c, nues));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
    });
  });

  group('capacité 2 — étapes OPTIONNELLES', () {
    const List<ZFieldSpec> requis = <ZFieldSpec>[
      ZFieldSpec(
        name: 'obligatoire',
        type: EditionFieldType.text,
        label: 'Obligatoire',
        validators: <ZValidatorSpec>[
          ZValidatorSpec.required(errorText: 'REQUIS'),
        ],
      ),
      ZFieldSpec(
        name: 'piece',
        type: EditionFieldType.text,
        label: 'Pièce',
        validators: <ZValidatorSpec>[
          ZValidatorSpec.required(errorText: 'REQUIS-PIECE'),
        ],
      ),
      ZFieldSpec(name: 'dernier', type: EditionFieldType.text, label: 'Dernier'),
    ];

    Widget host(ZFormController c, {required bool optional}) => MaterialApp(
          home: Scaffold(
            body: ZStepperEdition(
              controller: c,
              fields: requis,
              steps: <ZEditionStep>[
                ZEditionStep(
                  title: 'Pièces',
                  fields: const <String>['piece'],
                  optional: optional,
                ),
                const ZEditionStep(title: 'Fin', fields: <String>['dernier']),
              ],
              onComplete: () {},
            ),
          ),
        );

    testWidgets('optional:true — on quitte l\'étape malgré un champ invalide',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'piece': '', 'dernier': ''},
        visibleFields: const <String>['piece', 'dernier'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, optional: true));
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(_key('dernier'), findsOneWidget, reason: 'étape suivante atteinte');
      expect(find.text('REQUIS-PIECE'), findsNothing);
    });

    testWidgets('DÉFAUT inchangé — optional:false garde le gate strict',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'piece': '', 'dernier': ''},
        visibleFields: const <String>['piece', 'dernier'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, optional: false));
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(_key('dernier'), findsNothing, reason: 'navigation BLOQUÉE');
      expect(find.text('REQUIS-PIECE'), findsOneWidget,
          reason: 'l\'erreur est RÉVÉLÉE');
    });

    testWidgets(
        '🔴 le relâchement est LOCAL : une étape obligatoire reste gatée',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{
          'obligatoire': '',
          'piece': '',
          'dernier': '',
        },
        visibleFields: const <String>['obligatoire', 'piece', 'dernier'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: c,
            fields: requis,
            steps: const <ZEditionStep>[
              ZEditionStep(
                title: 'Pièces',
                fields: <String>['piece'],
                optional: true,
              ),
              ZEditionStep(title: 'Requis', fields: <String>['obligatoire']),
              ZEditionStep(title: 'Fin', fields: <String>['dernier']),
            ],
            onComplete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Étape optionnelle : franchie.
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(_key('obligatoire'), findsOneWidget);
      // Étape obligatoire : BLOQUÉE — c'est ce qui distingue `optional` d'un
      // `validateOnNext: false` global.
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(_key('dernier'), findsNothing);
      expect(find.text('REQUIS'), findsOneWidget);
    });
  });

  group('capacité 3 — REPRISE (ZStepIndexStore)', () {
    testWidgets('l\'étape atteinte est persistée puis restaurée au remontage',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZInMemoryStepIndexStore store = ZInMemoryStepIndexStore();
      const List<ZEditionStep> steps = <ZEditionStep>[
        ZEditionStep(title: 'Mode', fields: <String>['mode']),
        ZEditionStep(title: 'Conteneurs', fields: <String>['conteneur']),
        ZEditionStep(title: 'Fin', fields: <String>['fin']),
      ];
      final ZFormController c1 = ZFormController(
        initialValues: const <String, Object?>{'mode': 'x'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c1.dispose);
      await tester.pumpWidget(
          _host(c1, steps, store: store, formId: 'cargaison'));
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(store.loadStepIndex('cargaison'), 1);

      // Remontage COMPLET (nouveau controller, nouvel arbre) : on repart à 2/3.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final ZFormController c2 = ZFormController(
        initialValues: const <String, Object?>{'mode': 'x'},
        visibleFields: const <String>['mode', 'conteneur', 'fin'],
      );
      addTearDown(c2.dispose);
      await tester.pumpWidget(
          _host(c2, steps, store: store, formId: 'cargaison'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(_key('conteneur'), findsOneWidget);
    });

    testWidgets('DÉFAUT inchangé — sans store, on repart à l\'étape 1',
        (WidgetTester tester) async {
      _bigView(tester);
      const List<ZEditionStep> steps = <ZEditionStep>[
        ZEditionStep(title: 'Mode', fields: <String>['mode']),
        ZEditionStep(title: 'Fin', fields: <String>['fin']),
      ];
      final ZFormController c1 = ZFormController(
        initialValues: const <String, Object?>{'mode': 'x'},
        visibleFields: const <String>['mode', 'fin'],
      );
      addTearDown(c1.dispose);
      await tester.pumpWidget(_host(c1, steps));
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      final ZFormController c2 = ZFormController(
        initialValues: const <String, Object?>{'mode': 'x'},
        visibleFields: const <String>['mode', 'fin'],
      );
      addTearDown(c2.dispose);
      await tester.pumpWidget(_host(c2, steps));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('AD-10 — un store qui LÈVE ne casse pas le montage',
        (WidgetTester tester) async {
      _bigView(tester);
      const List<ZEditionStep> steps = <ZEditionStep>[
        ZEditionStep(title: 'Mode', fields: <String>['mode']),
        ZEditionStep(title: 'Fin', fields: <String>['fin']),
      ];
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'x'},
        visibleFields: const <String>['mode', 'fin'],
      );
      addTearDown(c.dispose);
      await tester
          .pumpWidget(_host(c, steps, store: const _StoreExplosif()));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget, reason: 'repli sur initialStep');
      // …et la navigation continue de fonctionner malgré un `save` qui lève.
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('un index persisté HORS BORNES est ignoré',
        (WidgetTester tester) async {
      _bigView(tester);
      final ZInMemoryStepIndexStore store = ZInMemoryStepIndexStore();
      // Le formulaire d'hier avait 5 étapes ; celui d'aujourd'hui en a 2.
      store.saveStepIndex('f', 4);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'mode': 'x'},
        visibleFields: const <String>['mode', 'fin'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(
        c,
        const <ZEditionStep>[
          ZEditionStep(title: 'Mode', fields: <String>['mode']),
          ZEditionStep(title: 'Fin', fields: <String>['fin']),
        ],
        store: store,
        formId: 'f',
      ));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
    });
  });

  group('adaptateur — les capacités sont atteignables EN DÉCLARATION PLATE', () {
    test('condition et optional traversent `ZStepFieldConfig`', () {
      const ZCondition cond = ZCondition.equals('mode', 'containerised');
      final ZStepPartition p = zPartitionFieldsIntoSteps(const <ZFieldSpec>[
        ZFieldSpec(
          name: 'conteneur',
          type: EditionFieldType.text,
          config: ZStepFieldConfig(index: 0, title: 'C', condition: cond),
        ),
        ZFieldSpec(
          name: 'piece',
          type: EditionFieldType.text,
          config: ZStepFieldConfig(index: 1, title: 'P'),
        ),
        ZFieldSpec(
          name: 'note',
          type: EditionFieldType.text,
          // Un SEUL champ suffit à déclarer l'étape optionnelle.
          config: ZStepFieldConfig(index: 1, optional: true),
        ),
      ]);
      expect(p.steps[0].condition, cond);
      expect(p.steps[0].optional, isFalse);
      expect(p.steps[1].condition, isNull);
      expect(p.steps[1].optional, isTrue,
          reason: '`optional` est un OU sur l\'étape');
      expect(p.steps[1].fields, <String>['piece', 'note']);
    });

    test('DÉFAUT inchangé : sans annotation, ni condition ni optional', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(const <ZFieldSpec>[
        ZFieldSpec(
          name: 'a',
          type: EditionFieldType.text,
          config: ZStepFieldConfig(index: 0),
        ),
      ]);
      expect(p.steps.single.condition, isNull);
      expect(p.steps.single.optional, isFalse);
    });
  });
}

/// Store d'hôte fautif : lève des DEUX côtés (AD-10).
class _StoreExplosif extends ZStepIndexStore {
  const _StoreExplosif();

  @override
  int? loadStepIndex(String? formId) => throw StateError('load boom');

  @override
  void saveStepIndex(String? formId, int index) =>
      throw StateError('save boom');
}
