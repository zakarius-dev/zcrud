/// **G1 — bout en bout** : une liste PLATE annotée, passée par
/// [zPartitionFieldsIntoSteps], est consommée par [ZStepperEdition]
/// **inchangé**.
///
/// La suite unitaire (`z_step_partition_test.dart`) prouve la composition ; ici
/// on prouve les deux choses qu'elle ne peut PAS voir :
/// * que le `List<ZEditionStep>` produit est réellement **montable** (le
///   contrat de la fonction ne vaut rien si le stepper le refuse) ;
/// * qu'un champ dont le slot `config` porte l'annotation d'étape **rend
///   toujours son widget normal** — l'occupation du slot ne casse pas le
///   dispatcher (`field.config is ZTextConfig` y répond simplement `false`).
///
/// Aucun `ZEditionStep` n'est écrit à la main dans ce fichier : c'est justement
/// le 1:1 que G1 réclamait.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Déclaration **plate**, façon DODLP — l'ordre de déclaration entrelace
/// volontairement les étapes.
const List<ZFieldSpec> _flat = <ZFieldSpec>[
  ZFieldSpec(
    name: 'nom',
    type: EditionFieldType.text,
    label: 'Nom',
    config: ZStepFieldConfig(index: 0, title: 'Identité', icon: Icons.person),
  ),
  ZFieldSpec(
    name: 'poste',
    type: EditionFieldType.text,
    label: 'Poste',
    config: ZStepFieldConfig(index: 1, title: 'Affectation'),
  ),
  ZFieldSpec(
    name: 'matricule',
    type: EditionFieldType.text,
    label: 'Matricule',
    config: ZStepFieldConfig(index: 0),
  ),
];

Finder _key(String name) => find.byKey(ValueKey<String>(name));

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
      'la liste plate annotée se monte telle quelle dans `ZStepperEdition`',
      (WidgetTester tester) async {
    _bigView(tester);
    final ZStepPartition partition = zPartitionFieldsIntoSteps(_flat);
    final ZFormController controller = ZFormController(
      initialValues: const <String, Object?>{
        'nom': '',
        'poste': '',
        'matricule': '',
      },
      visibleFields: const <String>['nom', 'poste', 'matricule'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: controller,
          fields: _flat,
          steps: partition.steps,
          config: const ZStepperConfig(style: ZStepStyle.icons),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Étape 0 : titre dérivé du PREMIER champ qui le portait, icône itou.
    expect(find.text('Identité'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    // Ses DEUX champs sont montés — dont `matricule`, déclaré en dernier.
    expect(_key('nom'), findsOneWidget);
    expect(_key('matricule'), findsOneWidget);
    // Le champ de l'étape 1 ne l'est pas.
    expect(_key('poste'), findsNothing);
    // 🔴 Un champ dont le slot `config` porte l'annotation rend quand même son
    // widget d'édition normal.
    expect(
      find.descendant(of: _key('nom'), matching: find.byType(EditableText)),
      findsOneWidget,
    );

    // Navigation : l'étape 1 monte son champ, l'étape 0 démonte les siens.
    await tester.tap(find.widgetWithText(FilledButton, 'Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Affectation'), findsOneWidget);
    expect(_key('poste'), findsOneWidget);
    expect(_key('nom'), findsNothing);
  });

  testWidgets('une partition VIDE laisse l\'hôte rendre son formulaire normal',
      (WidgetTester tester) async {
    _bigView(tester);
    const List<ZFieldSpec> nus = <ZFieldSpec>[
      ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    ];
    final ZStepPartition partition = zPartitionFieldsIntoSteps(nus);
    expect(partition.isEmpty, isTrue);

    final ZFormController controller = ZFormController(
      initialValues: const <String, Object?>{'a': ''},
      visibleFields: const <String>['a'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: partition.isEmpty
            ? DynamicEdition(controller: controller, fields: nus)
            : ZStepperEdition(
                controller: controller,
                fields: nus,
                steps: partition.steps,
              ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_key('a'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Suivant'), findsNothing);
  });
}
