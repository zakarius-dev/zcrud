// CR — un widget host-fourni (champ `widget` ou ornement `.widget`) doit
// pouvoir LIRE le formulaire qui l'entoure : sa propre tranche, et la tranche
// d'un autre champ déclaré, avec mise à jour quand la valeur lue change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Monte [fields] dans un `DynamicEdition` piloté par [controller], avec le
/// [registry] injecté au `ZcrudScope` (seul canal de widgets hôtes).
Future<void> _pumpForm(
  WidgetTester tester, {
  required ZFormController controller,
  required ZWidgetRegistry registry,
  required List<ZFieldSpec> fields,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ZcrudScope(
        widgetRegistry: registry,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'ornement `.widget` : reçoit la valeur COURANTE de son champ et se met '
      'à jour quand elle change', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'mdp': 'v0'},
      visibleFields: <String>['mdp'],
    );
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('suffixe', (c, ctx) => Text('suffixe:${ctx.value}'));

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(
          name: 'mdp',
          type: EditionFieldType.text,
          label: 'Mot de passe',
          suffix: ZFieldAdornment.widget('suffixe'),
        ),
      ],
    );

    expect(find.text('suffixe:v0'), findsOneWidget,
        reason: "l'ornement doit recevoir la valeur de la tranche qu'il orne");

    controller.setValue('mdp', 'v1');
    await tester.pump();

    expect(find.text('suffixe:v1'), findsOneWidget,
        reason: "l'ornement doit refléter la nouvelle valeur");
  });

  testWidgets(
      'ornement `.widget` HISSÉ dans la fiche `large` : se met à jour lui '
      'aussi quand la tranche ornée change', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'mdp': 'v0'},
      visibleFields: <String>['mdp'],
    );
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('suffixe', (c, ctx) => Text('grand:${ctx.value}'));

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(
          name: 'mdp',
          type: EditionFieldType.text,
          label: 'Mot de passe',
          fieldSize: ZFieldSize.large,
          suffix: ZFieldAdornment.widget('suffixe'),
        ),
      ],
    );

    expect(find.text('grand:v0'), findsOneWidget);

    controller.setValue('mdp', 'v1');
    await tester.pump();

    expect(find.text('grand:v1'), findsOneWidget,
        reason: "un ornement hissé hors du builder de tranche ne doit pas "
            'afficher une valeur figée');
  });

  testWidgets(
      'champ `widget` : lit un AUTRE champ du formulaire et se reconstruit '
      'quand cet autre champ change', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'ancien': '', 'action': null},
      visibleFields: <String>['ancien', 'action'],
    );
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('reauth', (c, ctx) {
        final ancien = ctx.valueOf?.call('ancien');
        return Text(
          ancien == null || '$ancien'.isEmpty ? 'inactif' : 'Réauthentifier',
        );
      });

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(name: 'ancien', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'action',
          type: EditionFieldType.widget,
          widgetKind: 'reauth',
        ),
      ],
    );

    expect(find.text('inactif'), findsOneWidget);

    controller.setValue('ancien', 'secret');
    await tester.pump();

    expect(find.text('Réauthentifier'), findsOneWidget,
        reason: 'la lecture cross-champ doit être réactive, pas un instantané');
    expect(find.text('inactif'), findsNothing);
  });

  testWidgets('`valueOf` sur un nom INCONNU rend null sans lever',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'action': null},
      visibleFields: <String>['action'],
    );
    addTearDown(controller.dispose);
    Object? lu = 'sentinelle';
    var leve = false;
    final registry = ZWidgetRegistry()
      ..register('sonde', (c, ctx) {
        try {
          lu = ctx.valueOf?.call('champInexistant');
        } on Object {
          leve = true;
        }
        return const Text('sonde');
      });

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(
          name: 'action',
          type: EditionFieldType.widget,
          widgetKind: 'sonde',
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(leve, isFalse, reason: 'un nom inconnu ne doit jamais lever');
    expect(lu, isNull, reason: 'un nom inconnu rend null');
  });

  testWidgets(
      'GRANULARITÉ : changer un champ que le widget NE LIT PAS ne le '
      'reconstruit pas ; changer celui qu\'il lit le reconstruit', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'lu': 'a', 'ignore': 'x', 'action': null},
      visibleFields: <String>['lu', 'ignore', 'action'],
    );
    addTearDown(controller.dispose);
    var builds = 0;
    final registry = ZWidgetRegistry()
      ..register('compteur', (c, ctx) {
        builds++;
        return Text('lu=${ctx.valueOf?.call('lu')}');
      });

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(name: 'lu', type: EditionFieldType.text),
        ZFieldSpec(name: 'ignore', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'action',
          type: EditionFieldType.widget,
          widgetKind: 'compteur',
        ),
      ],
    );

    final apresMontage = builds;
    expect(apresMontage, greaterThan(0));

    // Tranche JAMAIS lue par le builder : aucun rebuild du champ `widget`.
    controller.setValue('ignore', 'y');
    await tester.pump();
    expect(builds, apresMontage,
        reason: 'un champ non lu ne doit pas reconstruire le widget hôte '
            "(sinon l'abonnement serait global, pas ciblé)");

    // Tranche RÉELLEMENT lue : le champ `widget` se reconstruit.
    controller.setValue('lu', 'b');
    await tester.pump();
    expect(builds, greaterThan(apresMontage),
        reason: 'la tranche lue doit reconstruire le widget hôte');
    expect(find.text('lu=b'), findsOneWidget);
  });

  testWidgets(
      "CONTRE-TÉMOIN : un widget qui n'utilise ni sa valeur ni `valueOf` ne "
      "s'abonne à rien de plus", (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'autre': 'x', 'action': null},
      visibleFields: <String>['autre', 'action'],
    );
    addTearDown(controller.dispose);
    var builds = 0;
    final registry = ZWidgetRegistry()
      ..register('inerte', (c, ctx) {
        builds++;
        return const Text('inerte');
      });

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(name: 'autre', type: EditionFieldType.text),
        ZFieldSpec(
          name: 'action',
          type: EditionFieldType.widget,
          widgetKind: 'inerte',
        ),
      ],
    );

    final apresMontage = builds;
    controller.setValue('autre', 'y');
    await tester.pump();
    expect(builds, apresMontage,
        reason: 'aucune lecture ⇒ aucun abonnement supplémentaire');

    // Sa PROPRE tranche continue de le reconstruire — comportement d'avant.
    controller.setValue('action', 42);
    await tester.pump();
    expect(builds, greaterThan(apresMontage),
        reason: 'la tranche propre reste la frontière de rebuild');
    expect(find.text('inerte'), findsOneWidget);
  });

  testWidgets(
      "ornement `.widget` : reste en LECTURE — son `onChanged` n'écrit pas "
      'dans la tranche ornée', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'mdp': 'v0'},
      visibleFields: <String>['mdp'],
    );
    addTearDown(controller.dispose);
    late ZFieldWidgetContext capture;
    final registry = ZWidgetRegistry()
      ..register('suffixe', (c, ctx) {
        capture = ctx;
        return const Text('suffixe');
      });

    await _pumpForm(
      tester,
      controller: controller,
      registry: registry,
      fields: const <ZFieldSpec>[
        ZFieldSpec(
          name: 'mdp',
          type: EditionFieldType.text,
          suffix: ZFieldAdornment.widget('suffixe'),
        ),
      ],
    );

    capture.onChanged('ÉCRITURE INTERDITE');
    await tester.pump();

    expect(controller.valueOf('mdp'), 'v0',
        reason: "un ornement est un affichage : lire n'est pas écrire");
    expect(tester.takeException(), isNull);
  });
}
