// CR-CASCADE (2026-08-09) — **DYNAMIQUE** des cascades de choix
// (`ZSelectConfig.choicesSourceKey` + `filterKeys` + `ZChoicesSource`).
//
// Contexte : le mécanisme était câblé (`z_field_widget.dart`, abonnement CIBLÉ
// aux `filterKeys`) et gardé **au rendu initial** seulement — le seul `setValue`
// du fichier `z_select_field_widget_test.dart` portait sur `choicesFromKey`.
// Autrement dit : **aucune garde ne faisait changer un `filterKey`**, donc rien
// ne prouvait qu'une cascade cascade réellement. Ce fichier comble ce trou.
//
// Anti-garde-vacante : les jeux d'options amont/aval sont **disjoints**, et la
// disjonction est **assertée d'abord** (une garde de cascade dont les options
// d'après ressemblent à celles d'avant ne mord sur rien).
//
// Cas couverts (parité des 11 trappes `EditionFieldTypes.widget` de DODLP —
// « agents à la date », « postes à la date », « dossiers par agent/annuler ») :
//  1. dynamique : changement de l'amont ⇒ options recomposées ;
//  2. SM-1 : le voisin non dépendant n'est PAS reconstruit (compteurs de build) ;
//  3. sélection devenue ORPHELINE : décision écrite + gardée ;
//  4. dépendance CIRCULAIRE : pas de boucle, pas d'exception ;
//  5. AD-10 : source en erreur / clé amont absente / options vides ⇒ repli défini ;
//  6. cascade sur un `select` **multiple** (la forme majoritaire chez DODLP).
//
// Aucun backend : les sources de test vivent DANS le test (AD-1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Population d'agents « présents à la date » — reproduit
/// `Cotation.agentsAuxPostesAu(date:)` / `Agent.estPresentAu(date)` de DODLP.
///
/// Les deux jeux sont **volontairement disjoints** (aucune valeur ni aucun
/// libellé commun) : c'est ce qui rend les gardes de ce fichier mordantes.
class _AgentsAtDate extends ZChoicesSource {
  const _AgentsAtDate();

  static const List<ZFieldChoice> jeu2024 = <ZFieldChoice>[
    ZFieldChoice(value: 'a1', label: 'Alpha'),
    ZFieldChoice(value: 'a2', label: 'Beta'),
  ];

  static const List<ZFieldChoice> jeu2025 = <ZFieldChoice>[
    ZFieldChoice(value: 'z9', label: 'Omega'),
    ZFieldChoice(value: 'z8', label: 'Sigma'),
  ];

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) {
    switch (filterContext['date']) {
      case '2024':
        return jeu2024;
      case '2025':
        return jeu2025;
      default:
        // Clé amont absente/nulle ⇒ population vide (repli DODLP : le champ est
        // masqué tant que la date n'est pas saisie — `displayCondition`).
        return const <ZFieldChoice>[];
    }
  }
}

/// Source qui **lève** — chemin défensif AD-10 du dispatcher.
class _ThrowingChoices extends ZChoicesSource {
  const _ThrowingChoices();

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) =>
      throw StateError('source metier en erreur');
}

/// Source « miroir » : rend une option dont le libellé reprend la valeur de
/// l'AUTRE champ du couple. Sert à monter une dépendance **circulaire**.
class _EchoChoices extends ZChoicesSource {
  const _EchoChoices();

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) {
    final parts = filterContext.entries
        .map((e) => '${e.key}=${e.value ?? '-'}')
        .toList(growable: false)
      ..sort();
    return <ZFieldChoice>[
      ZFieldChoice(value: 'echo', label: 'Echo ${parts.join('|')}'),
    ];
  }
}

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  ZChoicesSourceRegistry? choicesRegistry,
  void Function(String name)? onFieldBuild,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        choicesSourceRegistry: choicesRegistry,
        child: DynamicEdition(
          controller: controller,
          fields: fields,
          fieldBuilder: onFieldBuild == null
              ? null
              : (context, ctrl, field) => ZFieldWidget(
                    controller: ctrl,
                    field: field,
                    onBuild: () => onFieldBuild(field.name),
                  ),
        ),
      ),
    ),
  );
}

/// Spec de l'aval : `agent` en `radio` (libellés directement lisibles à l'écran),
/// cascadé sur la tranche `date` via une `ZChoicesSource`.
const ZFieldSpec _agentRadio = ZFieldSpec(
  name: 'agent',
  type: EditionFieldType.radio,
  label: 'Agent',
  config: ZSelectConfig(
    choicesSourceKey: 'agentsAtDate',
    filterKeys: <String>['date'],
  ),
);

ZChoicesSourceRegistry _registryAgents() =>
    ZChoicesSourceRegistry()..register('agentsAtDate', const _AgentsAtDate());

void main() {
  // ── Pré-requis anti-garde-vacante : les deux jeux sont DISJOINTS ───────────
  test('pré-requis : les jeux d\'options amont/aval sont disjoints', () {
    final v2024 = _AgentsAtDate.jeu2024.map((c) => c.value).toSet();
    final v2025 = _AgentsAtDate.jeu2025.map((c) => c.value).toSet();
    final l2024 = _AgentsAtDate.jeu2024.map((c) => c.label).toSet();
    final l2025 = _AgentsAtDate.jeu2025.map((c) => c.label).toSet();
    expect(v2024.intersection(v2025), isEmpty,
        reason: 'sans valeurs disjointes, toute garde de cascade est vacante');
    expect(l2024.intersection(l2025), isEmpty,
        reason: 'sans libellés disjoints, find.text ne discrimine rien');
  });

  group('Cascade via filterKeys — dynamique (CR-CASCADE AC1)', () {
    testWidgets('changement de l\'amont ⇒ options recomposées', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'date': '2024', 'agent': null},
        visibleFields: <String>['date', 'agent'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 'date', type: EditionFieldType.hidden),
          _agentRadio,
        ],
        choicesRegistry: _registryAgents(),
      ));
      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Omega'), findsNothing);

      // L'AMONT change — c'est le geste que plus aucune garde ne faisait.
      controller.setValue('date', '2025');
      await tester.pump();

      expect(find.text('Omega'), findsOneWidget,
          reason: 'les options du nouveau contexte sont montées');
      expect(find.text('Sigma'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing,
          reason: 'les options de l\'ancien contexte ont disparu');
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('cascade sur un select MULTIPLE (forme majoritaire DODLP)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'date': '2024',
          'agentsIds': <Object?>[],
        },
        visibleFields: <String>['date', 'agentsIds'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 'date', type: EditionFieldType.hidden),
          ZFieldSpec(
            name: 'agentsIds',
            type: EditionFieldType.checkbox,
            label: 'Agents',
            multiple: true,
            config: ZSelectConfig(
              choicesSourceKey: 'agentsAtDate',
              filterKeys: <String>['date'],
            ),
          ),
        ],
        choicesRegistry: _registryAgents(),
      ));
      await tester.pump();
      expect(find.text('Alpha'), findsOneWidget);

      controller.setValue('date', '2025');
      await tester.pump();
      expect(find.text('Omega'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });
  });

  group('SM-1 — abonnement CIBLÉ (CR-CASCADE AC2)', () {
    testWidgets(
        'amont change ⇒ SEUL le champ dépendant recompute ; 100 frappes hors '
        'cascade ⇒ 0 recompute', (tester) async {
      final builds = <String, int>{};
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'date': '2024',
          'agent': null,
          'libre': '',
          'voisin': null,
        },
        visibleFields: <String>['date', 'agent', 'libre', 'voisin'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 'date', type: EditionFieldType.hidden),
          _agentRadio,
          ZFieldSpec(name: 'libre', type: EditionFieldType.text, label: 'Libre'),
          // Voisin SANS aucune dépendance à `date` : témoin de non-rebuild.
          ZFieldSpec(
            name: 'voisin',
            type: EditionFieldType.radio,
            label: 'Voisin',
            choices: <ZFieldChoice>[ZFieldChoice(value: 'v', label: 'Voisin1')],
          ),
        ],
        choicesRegistry: _registryAgents(),
        onFieldBuild: (n) => builds[n] = (builds[n] ?? 0) + 1,
      ));
      await tester.pump();

      // Anti-garde-vacante : sans compteur alimenté, TOUTES les assertions
      // SM-1 ci-dessous compareraient `null` à `null` et passeraient à vide.
      expect(builds.keys, containsAll(<String>['agent', 'voisin', 'libre']),
          reason: 'les compteurs de build sont réellement alimentés');

      final agentAvant = builds['agent'] ?? 0;
      final voisinAvant = builds['voisin'] ?? 0;
      final libreAvant = builds['libre'] ?? 0;

      // 1) L'amont change → le dépendant recompute, les voisins NON.
      controller.setValue('date', '2025');
      await tester.pump();
      expect((builds['agent'] ?? 0) > agentAvant, isTrue,
          reason: 'le champ cascadé recompute');
      expect(builds['voisin'], voisinAvant,
          reason: 'un voisin non dépendant ne doit PAS recompute (SM-1)');
      expect(builds['libre'], libreAvant,
          reason: 'le champ texte voisin ne doit PAS recompute (SM-1)');

      // 2) 100 frappes dans un champ hors cascade → 0 recompute du cascadé.
      final agentAvantFrappe = builds['agent'] ?? 0;
      final textField = find.byType(TextField).first;
      for (var i = 0; i < 100; i++) {
        await tester.enterText(textField, 'x' * (i + 1));
      }
      await tester.pump();
      expect(builds['agent'], agentAvantFrappe,
          reason: '100 frappes hors cascade ne reconstruisent pas le cascadé');
      expect(builds['voisin'], voisinAvant);
    });
  });

  group('Sélection devenue ORPHELINE (CR-CASCADE AC3)', () {
    // DÉCISION ÉCRITE (mesurée des deux côtés le 2026-08-09) :
    //   DODLP  — `edition_screen.dart` lit la sélection depuis `item[fieldName]`
    //            indépendamment de `choiceItems` ; grep `removeWhere|retainWhere|
    //            prune|sanitiz` sur le moteur ⇒ **RC=1** : AUCUNE purge.
    //   socle  — grep `prune|sanitiz|invalidSelection|clearIfInvalid|orphan` sur
    //            `lib/` ⇒ **RC=1** : AUCUNE purge non plus.
    // ⇒ Les deux comportements sont IDENTIQUES : la valeur orpheline est
    //   **CONSERVÉE** dans la tranche. Porter les 11 trappes DODLP vers
    //   `filterKeys` ne change donc RIEN sur ce point (parité stricte, aucune
    //   régression pour l'hôte). Ce choix est ici **écrit et gardé** plutôt que
    //   subi : une purge silencieuse serait une perte de donnée non signalée,
    //   et le socle ne peut pas décider seul qu'un id absent de la population
    //   du jour est un id faux (il peut être simplement hors-période).
    testWidgets('la valeur orpheline est CONSERVÉE dans la tranche (parité)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'date': '2024', 'agent': 'a1'},
        visibleFields: <String>['date', 'agent'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 'date', type: EditionFieldType.hidden),
          _agentRadio,
        ],
        choicesRegistry: _registryAgents(),
      ));
      await tester.pump();
      expect(find.text('Alpha'), findsOneWidget);
      expect(controller.valueOf('agent'), 'a1');

      // L'amont change : 'a1' n'est PLUS une option valide (jeux disjoints).
      controller.setValue('date', '2025');
      await tester.pump();

      expect(_AgentsAtDate.jeu2025.map((c) => c.value), isNot(contains('a1')),
          reason: 'pré-requis : la sélection est bien devenue invalide');
      expect(controller.valueOf('agent'), 'a1',
          reason: 'décision écrite : le socle NE PURGE PAS (parité DODLP)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('un select DROPDOWN à valeur orpheline ne lève pas (AD-10)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'date': '2024', 'agent': 'a1'},
        visibleFields: <String>['date', 'agent'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 'date', type: EditionFieldType.hidden),
          ZFieldSpec(
            name: 'agent',
            type: EditionFieldType.select,
            label: 'Agent',
            config: ZSelectConfig(
              choicesSourceKey: 'agentsAtDate',
              filterKeys: <String>['date'],
            ),
          ),
        ],
        choicesRegistry: _registryAgents(),
      ));
      await tester.pump();

      controller.setValue('date', '2025');
      await tester.pump();

      // `DropdownButtonFormField` assert si `value` n'est pas dans `items` : le
      // dispatcher neutralise l'affichage (`current = null`) sans toucher à la
      // tranche. La valeur reste lisible par le modèle, l'écran ne casse pas.
      expect(tester.takeException(), isNull,
          reason: 'aucune exception malgré la valeur hors options');
      expect(controller.valueOf('agent'), 'a1');
    });
  });

  group('Dépendance CIRCULAIRE (CR-CASCADE AC4)', () {
    testWidgets('a↔b via filterKeys : pas de boucle, pas d\'exception',
        (tester) async {
      final builds = <String, int>{};
      final controller = ZFormController(
        initialValues: <String, Object?>{'a': null, 'b': null},
        visibleFields: <String>['a', 'b'],
      );
      addTearDown(controller.dispose);
      final registry = ZChoicesSourceRegistry()
        ..register('echo', const _EchoChoices());
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'a',
            type: EditionFieldType.radio,
            label: 'A',
            config: ZSelectConfig(
              choicesSourceKey: 'echo',
              filterKeys: <String>['b'],
            ),
          ),
          ZFieldSpec(
            name: 'b',
            type: EditionFieldType.radio,
            label: 'B',
            config: ZSelectConfig(
              choicesSourceKey: 'echo',
              filterKeys: <String>['a'],
            ),
          ),
        ],
        choicesRegistry: registry,
        onFieldBuild: (n) => builds[n] = (builds[n] ?? 0) + 1,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final aAvant = builds['a'] ?? 0;
      final bAvant = builds['b'] ?? 0;

      // Écrire dans `a` notifie la tranche `a` : `a` (sa propre tranche) ET `b`
      // (abonné à `a`) recomputent — UNE fois chacun. Recomputer n'ÉCRIT pas,
      // donc la boucle ne se referme jamais : c'est la propriété qui rend une
      // dépendance circulaire inoffensive ici.
      controller.setValue('a', 'echo');
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'aucune exception ni débordement de pile');
      expect((builds['a'] ?? 0) - aAvant, lessThanOrEqualTo(2),
          reason: 'nombre de recomputes BORNÉ (pas de boucle)');
      expect((builds['b'] ?? 0) - bAvant, lessThanOrEqualTo(2),
          reason: 'nombre de recomputes BORNÉ (pas de boucle)');
      expect(find.text('Echo a=echo'), findsOneWidget,
          reason: 'b a bien vu la nouvelle valeur de a');
    });
  });

  group('AD-10 — replis définis (CR-CASCADE AC5)', () {
    testWidgets('source qui LÈVE ⇒ repli sur field.choices, champ non bloqué',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'date': '2024', 'agent': null},
        visibleFields: <String>['date', 'agent'],
      );
      addTearDown(controller.dispose);
      final registry = ZChoicesSourceRegistry()
        ..register('agentsAtDate', const _ThrowingChoices());
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 'date', type: EditionFieldType.hidden),
          ZFieldSpec(
            name: 'agent',
            type: EditionFieldType.radio,
            label: 'Agent',
            config: ZSelectConfig(
              choicesSourceKey: 'agentsAtDate',
              filterKeys: <String>['date'],
            ),
            choices: <ZFieldChoice>[
              ZFieldChoice(value: 'st', label: 'ReplisStatique'),
            ],
          ),
        ],
        choicesRegistry: registry,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'une source métier en erreur ne remonte JAMAIS dans le build');
      expect(find.text('ReplisStatique'), findsOneWidget,
          reason: 'repli défini sur field.choices');
    });

    testWidgets('clé amont ABSENTE du formulaire ⇒ filterContext null, '
        'options vides, champ rendu et non bloqué', (tester) async {
      final controller = ZFormController(
        // `date` n'est PAS une tranche du formulaire : cas d'une cascade dont
        // l'amont n'a pas encore été saisi (DODLP le masque par
        // `displayCondition`; ici on garde le cas NON masqué, le pire).
        initialValues: <String, Object?>{'agent': null},
        visibleFields: <String>['agent'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[_agentRadio],
        choicesRegistry: _registryAgents(),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Omega'), findsNothing);
      // Le champ EXISTE malgré zéro option (jamais un champ « disparu » ni gelé).
      expect(find.text('Agent'), findsOneWidget,
          reason: 'le champ reste monté avec son libellé (jamais bloqué)');

      // …et la cascade repart dès que l'amont est renseigné.
      controller.setValue('date', '2025');
      await tester.pump();
      expect(find.text('Omega'), findsOneWidget,
          reason: 'la tranche amont créée paresseusement alimente la cascade');
    });
  });
}
