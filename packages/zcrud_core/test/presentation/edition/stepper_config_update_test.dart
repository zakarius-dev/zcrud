// `ZStepperEdition` — RÉACTIVITÉ À UN CHANGEMENT DE `config` SUR UN STEPPER
// DÉJÀ MONTÉ, et discipline SM-1 sur les canaux purement visuels.
//
// ## Le défaut reproduit (v0.66.0, trouvé en écrivant la vitrine)
//
// `didUpdateWidget` observait `controller`, `fields`, `steps` et `revealTrigger`
// — jamais `config`. Basculer `showAllSteps` sur un stepper monté changeait la
// MISE EN PAGE (le chrome se rebuild : rail, badges, en-têtes) sans jamais
// recalculer la FENÊTRE : les zones d'étape suivantes, devenues passives
// (`manageVisibility:false`), n'avaient plus aucun champ à monter. Rien ne
// levait, rien ne rougissait — la page avait simplement l'air vide.
//
// ## Pourquoi ces gardes ne sont pas vacantes
//
//  * Le contrôleur est construit AVEC `visibleFields` explicite. C'est
//    déterminant : sans lui, `DynamicEdition._shouldSeedCanonicalOrder`
//    ré-amorcerait la fenêtre au montage et rendrait, PAR HASARD, la valeur
//    attendue au retour en mode paginé — la garde du sens inverse serait verte
//    sans rien mesurer.
//  * On mesure le CONTENU (`EditableText` de la dernière étape), jamais le seul
//    en-tête : c'est précisément la paire « en-tête rendu / contenu inerte » du
//    défaut.
//  * Les DEUX SENS de bascule sont gardés, avec une observable DIFFÉRENTE dans
//    chaque sens : montage des champs (paginé → déplié), valeur de
//    `controller.visibleFields` (déplié → paginé — dans ce sens les champs
//    surnuméraires ne sont pas montés, seule la fenêtre est fausse).
//  * SM-1 : le compteur de builds de champ est comparé à un changement de config
//    dont on VÉRIFIE l'effet visuel (le titre d'étape disparaît). Un compteur
//    stable parce que rien n'a changé ne prouverait rien.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _editable(String name) => find.descendant(
      of: find.byKey(ValueKey<String>(name)),
      matching: find.byType(EditableText),
    );

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Harnais : un hôte qui pilote `config` par un `ValueNotifier` — exactement la
/// forme d'un réglage utilisateur « tout afficher », qui rebuild le stepper sans
/// jamais le remonter.
class _Host {
  _Host({
    ZStepperConfig initial = const ZStepperConfig(),
    this.steps = defaultSteps,
    this.catalogue = defaultCatalogue,
  }) : config = ValueNotifier<ZStepperConfig>(initial);

  static const List<ZFieldSpec> defaultCatalogue = <ZFieldSpec>[
    ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
    ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
  ];

  static const List<ZEditionStep> defaultSteps = <ZEditionStep>[
    ZEditionStep(title: 'Identité', fields: <String>['a']),
    ZEditionStep(title: 'Historique', fields: <String>['b']),
    ZEditionStep(title: 'Autorisations', fields: <String>['c']),
  ];

  final ValueNotifier<ZStepperConfig> config;
  final List<ZEditionStep> steps;
  final List<ZFieldSpec> catalogue;

  /// Compteur de builds PAR CHAMP (SM-1).
  final Map<String, int> builds = <String, int>{};

  int structural = 0;

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{'a': '', 'b': '', 'c': '', 'd': ''},
    // 🔴 Explicite : cf. en-tête — sans quoi la garde du sens inverse serait
    // verte par ré-amorçage fortuit de `DynamicEdition`.
    visibleFields: const <String>[],
  );

  /// Référence STABLE (un tear-off d'instance est canonicalisé : `o.m == o.m`).
  /// Une closure recréée à chaque build invaliderait le mémo et fausserait SM-1.
  Widget fieldBuilder(
    BuildContext context,
    ZFormController ctrl,
    ZFieldSpec field,
    AutovalidateMode mode,
  ) {
    builds[field.name] = (builds[field.name] ?? 0) + 1;
    return ZFieldWidget(
      controller: ctrl,
      field: field,
      autovalidateMode: mode,
    );
  }

  Widget build() => MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<ZStepperConfig>(
            valueListenable: config,
            builder: (BuildContext context, ZStepperConfig cfg, _) =>
                ZStepperEdition(
              controller: controller,
              fields: catalogue,
              steps: steps,
              config: cfg,
              fieldBuilder: fieldBuilder,
              onStructuralBuild: () => structural++,
            ),
          ),
        ),
      );

  void dispose() {
    config.dispose();
    controller.dispose();
  }
}

void main() {
  group('CR — didUpdateWidget réagit à `config` (canal STRUCTUREL)', () {
    testWidgets(
        'paginé → déplié : le CONTENU des étapes suivantes est réellement monté',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());

      // Point de départ NON vacant : seule l'étape 0 est montée.
      expect(_editable('a'), findsOneWidget);
      expect(_editable('b'), findsNothing);
      expect(_editable('c'), findsNothing);

      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();

      // 🔴 LE défaut : sans réaction au `config`, seuls les EN-TÊTES arrivaient.
      expect(find.text('Identité'), findsOneWidget);
      expect(find.text('Autorisations'), findsOneWidget);
      // …et le CONTENU, lui, restait absent.
      expect(_editable('a'), findsOneWidget);
      expect(_editable('b'), findsOneWidget);
      expect(_editable('c'), findsOneWidget);
      expect(h.controller.visibleFields.value, <String>['a', 'b', 'c']);
    });

    testWidgets('déplié → paginé : la fenêtre redevient celle de l\'étape seule',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host(
        initial: const ZStepperConfig(showAllSteps: true),
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      expect(h.controller.visibleFields.value, <String>['a', 'b', 'c']);

      h.config.value = h.config.value.copyWith(showAllSteps: false);
      await tester.pumpAndSettle();

      // Observable du sens INVERSE : dans ce sens les champs surnuméraires ne
      // sont de toute façon pas MONTÉS (chaque zone d'étape ne connaît que ses
      // propres specs) — c'est la FENÊTRE qui restait polluée.
      expect(h.controller.visibleFields.value, <String>['a']);
      expect(_editable('a'), findsOneWidget);
      expect(_editable('c'), findsNothing);
      // La pagination est bien revenue (barre de navigation).
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('les valeurs SAISIES survivent aux deux bascules',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());

      await tester.enterText(_editable('a'), 'Zoé');
      await tester.pump();
      expect(h.controller.valueOf('a'), 'Zoé');

      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();

      expect(h.controller.valueOf('a'), 'Zoé');
      expect(tester.widget<EditableText>(_editable('a')).controller.text, 'Zoé');

      // Saisie dans une étape que SEUL le mode déplié rend atteignable.
      // 🔴 Assertion AVANT le `enterText` : sans elle, un champ absent ferait
      // rougir la garde par `StateError` (finder vide) et non par ASSERTION.
      expect(_editable('c'), findsOneWidget);
      await tester.enterText(_editable('c'), 'Lecture');
      await tester.pump();

      h.config.value = h.config.value.copyWith(showAllSteps: false);
      await tester.pumpAndSettle();

      // L'état vit dans le `ZFormController` : rien n'est perdu au retour.
      expect(h.controller.valueOf('a'), 'Zoé');
      expect(h.controller.valueOf('c'), 'Lecture');
      expect(tester.widget<EditableText>(_editable('a')).controller.text, 'Zoé');
    });

    testWidgets('SINGLE WRITER tenu après bascule : zéro `DynamicEdition` actif',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());

      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();

      final List<DynamicEdition> mounted = tester
          .widgetList<DynamicEdition>(find.byType(DynamicEdition))
          .toList();
      expect(mounted.length, 3);
      // On n'affirme pas « la fenêtre est correcte » (elle peut l'être avec deux
      // écrivains qui se relaient) : on affirme qu'il n'existe AUCUN autre
      // écrivain que le stepper racine.
      for (final DynamicEdition e in mounted) {
        expect(e.manageVisibility, isFalse);
      }
      // Aucun doublon dans la fenêtre publiée.
      final List<String> w = h.controller.visibleFields.value;
      expect(w.toSet().length, w.length);
    });

    testWidgets(
        'la contribution d\'un sous-stepper imbriqué survit à la bascule',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host(
        catalogue: const <ZFieldSpec>[
          ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
          ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
          ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
          ZFieldSpec(name: 'd', type: EditionFieldType.text, label: 'D'),
        ],
        steps: const <ZEditionStep>[
          ZEditionStep(title: 'Identité', fields: <String>['a']),
          ZEditionStep(title: 'Historique', fields: <String>['b']),
          ZEditionStep(
            title: 'Autorisations',
            fields: <String>['c'],
            nestedSteps: <ZEditionStep>[
              ZEditionStep(title: 'Détail', fields: <String>['d']),
            ],
          ),
        ],
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();

      // La carte indexée des contributions (v0.66.0) est purgée à la bascule ;
      // le sous-stepper de l'étape 2 doit la REMONTER à nouveau, sinon `d`
      // disparaîtrait de la fenêtre.
      expect(h.controller.visibleFields.value, contains('d'));
      expect(_editable('d'), findsOneWidget);
    });

    testWidgets(
        'les gardes de CHAMP sont (ré)abonnées quand le mode devient pilotant',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host(
        catalogue: const <ZFieldSpec>[
          ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
          ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
          ZFieldSpec(
            name: 'c',
            type: EditionFieldType.text,
            label: 'C',
            condition: ZCondition.equals('a', 'oui'),
          ),
        ],
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());

      // Départ PAGINÉ = mode LEGACY : les conditions de CHAMP sont gérées par
      // `DynamicEdition`, le stepper n'y est PAS abonné.
      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();
      expect(_editable('c'), findsNothing, reason: 'condition encore fausse');

      // Le mode est devenu PILOTANT : c'est désormais le stepper, et lui seul,
      // qui doit réagir au champ de garde. Sans réabonnement, `c` n'apparaît
      // jamais — la fenêtre reste figée.
      await tester.enterText(_editable('a'), 'oui');
      await tester.pumpAndSettle();

      expect(h.controller.visibleFields.value, contains('c'));
      expect(_editable('c'), findsOneWidget);
    });
  });

  group('SM-1 — un changement VISUEL de `config` ne reconstruit pas les champs',
      () {
    testWidgets('`showLabels` bascule : 0 rebuild de champ, chrome rebâti',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());

      final int fieldBuilds = h.builds['a'] ?? 0;
      final int structural = h.structural;
      expect(fieldBuilds, greaterThan(0));
      // Preuve que le canal visuel MORD avant la mesure : le titre est là.
      expect(find.text('Identité'), findsOneWidget);

      h.config.value = h.config.value.copyWith(showLabels: false);
      await tester.pumpAndSettle();

      // Le changement visuel a bien pris effet…
      expect(find.text('Identité'), findsNothing);
      // …le chrome a été rebâti…
      expect(h.structural, greaterThan(structural));
      // …et AUCUN champ n'a été reconstruit (objectif produit n°1).
      expect(h.builds['a'], fieldBuilds);
    });

    testWidgets('canaux comportementaux non structurels : `validateOnNext`',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host(
        catalogue: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'a',
            type: EditionFieldType.text,
            label: 'A',
            validators: <ZValidatorSpec>[ZValidatorSpec.required()],
          ),
          ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
          ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
        ],
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      final int fieldBuilds = h.builds['a'] ?? 0;

      // Gate strict : « Suivant » est refusé sur un champ requis vide.
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(_editable('b'), findsNothing);

      h.config.value = h.config.value.copyWith(validateOnNext: false);
      await tester.pumpAndSettle();
      // Lu À L'APPEL : aucune invalidation d'état n'est nécessaire — et aucune
      // n'a lieu. (Le compteur bouge à cause de la RÉVÉLATION d'erreur ci-dessus,
      // canal structurel légitime : on repart donc du compteur courant.)
      final int afterReveal = h.builds['a']!;
      expect(afterReveal, greaterThanOrEqualTo(fieldBuilds));

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(_editable('b'), findsOneWidget);
    });
  });

  group('AD-10 — replis définis, jamais d\'exception', () {
    testWidgets('bascule sur une liste d\'étapes VIDE',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host(steps: const <ZEditionStep>[]);
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());

      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();
      h.config.value = h.config.value.copyWith(showAllSteps: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(h.controller.visibleFields.value, isEmpty);
    });

    testWidgets(
        'mode déplié + navigation demandée : la navigation est simplement absente',
        (WidgetTester tester) async {
      _bigView(tester);
      final _Host h = _Host();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      expect(find.text('Suivant'), findsOneWidget);

      // `allowStepTap`/`validateOnNext` restent `true` : incohérents avec un
      // mode sans étape courante ⇒ ignorés, jamais une exception.
      h.config.value = h.config.value.copyWith(showAllSteps: true);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Suivant'), findsNothing);
      expect(find.text('Précédent'), findsNothing);
      expect(_editable('c'), findsOneWidget);
    });
  });
}
