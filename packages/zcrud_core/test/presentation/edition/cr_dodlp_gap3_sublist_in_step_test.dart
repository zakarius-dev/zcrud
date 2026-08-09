// CR-DODLP-GAP3 — sous-listes CRUD imbriquées EN ÉTAPE de `ZStepperEdition`.
//
// Le CR demandait « confirmation + exemple ». La confirmation ne vaut que si
// elle est OPPOSABLE : ce fichier monte réellement le cas et l'affirme.
//
//   G1  imbrication  — `subItems` (mode compact, sous-éditeur dialogué) monte
//                      dans une étape ; le stepper reste SEUL ÉCRIVAIN de
//                      `visibleFields` (la sous-liste ne le contamine pas) ;
//   G2  gate d'étape — un `subItems` REQUIS et VIDE bloque « Suivant » (défaut
//                      corrigé : le gate portait sa propre projection de
//                      validation, qui rendait `"[]"`, donc non vide) ;
//   G3  SM-1         — ouvrir le sous-éditeur / ajouter une ligne ne reconstruit
//                      AUCUN autre champ de l'étape ;
//   G4  ACL de ligne — `ZSubListConfig.aclCollectionId` branche réellement
//                      `ZcrudScope.acl` sur les actions de ligne, et son absence
//                      laisse le comportement DP-6 intact (LES DEUX branches) ;
//   G5  mode déplié  — la sous-liste monte aussi sous `showAllSteps: true`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder get _next => find.widgetWithText(FilledButton, 'Suivant');

/// ACL refusant TOUT (y compris la création) — sonde du câblage.
class _DenyAll implements ZAcl {
  const _DenyAll();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) => false;
}

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'poste', type: EditionFieldType.text, label: 'Poste'),
];

/// Sous-liste compacte SANS discriminant ACL (comportement DP-6 historique).
const _subListPlain = ZFieldSpec(
  name: 'mob',
  type: EditionFieldType.subItems,
  label: 'Mobilités',
  config: ZSubListConfig(
    displayMode: ZSubListDisplayMode.compact,
    itemFields: _itemFields,
    summaryFields: <String>['poste'],
  ),
);

/// Même sous-liste, ACL de ligne ACTIVÉE par le discriminant.
const _subListAcl = ZFieldSpec(
  name: 'mob',
  type: EditionFieldType.subItems,
  label: 'Mobilités',
  config: ZSubListConfig(
    displayMode: ZSubListDisplayMode.compact,
    itemFields: _itemFields,
    summaryFields: <String>['poste'],
    aclCollectionId: 'mobilites',
  ),
);

/// Sous-liste REQUISE (gate d'étape).
const _subListRequired = ZFieldSpec(
  name: 'mob',
  type: EditionFieldType.subItems,
  label: 'Mobilités',
  validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQ-MOB')],
  config: ZSubListConfig(
    displayMode: ZSubListDisplayMode.compact,
    itemFields: _itemFields,
    summaryFields: <String>['poste'],
  ),
);

const _autre =
    ZFieldSpec(name: 'autre', type: EditionFieldType.text, label: 'Autre');

Widget _stepper(
  ZFormController c,
  List<ZFieldSpec> fields, {
  ZStepperConfig config = const ZStepperConfig(),
  ZAcl? acl,
  void Function(String name)? onFieldBuild,
}) {
  final body = ZStepperEdition(
    controller: c,
    fields: fields,
    steps: const <ZEditionStep>[
      ZEditionStep(title: 'Historique', fields: <String>['mob', 'autre']),
      ZEditionStep(title: 'Suite', fields: <String>['autre2']),
    ],
    config: config,
    fieldBuilder: onFieldBuild == null
        ? null
        : (context, ctrl, f, mode) => ZFieldWidget(
              controller: ctrl,
              field: f,
              autovalidateMode: mode,
              // Compteur sur la voie de rebuild DU CHAMP (et non sur le canal
              // structurel de `DynamicEdition`, qui ne mesurerait pas le sujet).
              onBuild: () => onFieldBuild(f.name),
            ),
    onComplete: () {},
  );
  return MaterialApp(
    home: acl == null
        ? Scaffold(body: body)
        : ZcrudScope(acl: acl, child: Scaffold(body: body)),
  );
}

ZFormController _controller() => ZFormController(
      initialValues: const <String, Object?>{
        'mob': <Map<String, dynamic>>[],
        'autre': 'x',
        'autre2': 'y',
      },
      visibleFields: const <String>['mob', 'autre', 'autre2'],
    );

const _fieldsPlain = <ZFieldSpec>[
  _subListPlain,
  _autre,
  ZFieldSpec(name: 'autre2', type: EditionFieldType.text, label: 'Autre2'),
];

void main() {
  // ── G1 — imbrication propre + single-writer préservé ───────────────────────

  testWidgets(
      'G1 — `subItems` compact monte dans une étape ; le stepper reste seul '
      'écrivain de visibleFields', (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_stepper(c, _fieldsPlain));
    await tester.pumpAndSettle();

    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    // La fenêtre est EXACTEMENT celle de l'étape 0 : la sous-liste, qui monte
    // ses propres `ZFormController` d'item, n'y a rien injecté ni retiré.
    expect(c.visibleFields.value, <String>['mob', 'autre']);

    // Le sous-éditeur DIALOGUÉ s'ouvre depuis l'étape.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Poste').hitTestable(),
        findsOneWidget);
    // Le dialog n'a PAS déplacé la fenêtre du stepper.
    expect(c.visibleFields.value, <String>['mob', 'autre']);
  });

  // ── G2 — gate d'étape : le requis MORD sur une sous-liste vide ─────────────

  testWidgets(
      'G2 — `subItems` requis et VIDE bloque « Suivant » ; une ligne ajoutée '
      'le débloque', (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_stepper(c, const <ZFieldSpec>[
      _subListRequired,
      _autre,
      ZFieldSpec(name: 'autre2', type: EditionFieldType.text, label: 'Autre2'),
    ]));
    await tester.pumpAndSettle();

    // Branche BLOQUANTE : la tranche porte `[]`.
    expect(c.valueOf('mob'), isEmpty);
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(c.visibleFields.value, <String>['mob', 'autre'],
        reason: 'le gate doit refuser une sous-liste requise sans ligne');
    expect(find.text('REQ-MOB'), findsWidgets);

    // Branche PASSANTE (anti-tautologie : le gate n'est pas « toujours non »).
    c.setValue('mob', <Map<String, dynamic>>[
      <String, dynamic>{'poste': 'Lomé'},
    ]);
    await tester.pumpAndSettle();
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(c.visibleFields.value, <String>['autre2']);
  });

  // ── G3 — SM-1 imbriqué sous stepper ───────────────────────────────────────

  testWidgets(
      'G3 — ouvrir le sous-éditeur et ajouter une ligne ne reconstruit aucun '
      'autre champ de l\'étape', (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    final builds = <String, int>{};
    await tester.pumpWidget(_stepper(c, _fieldsPlain,
        onFieldBuild: (n) => builds[n] = (builds[n] ?? 0) + 1));
    await tester.pumpAndSettle();

    final before = Map<String, int>.from(builds);
    expect(before['autre'], isNotNull);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Poste').hitTestable(), 'Lomé');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    // La ligne EST arrivée dans la tranche parente (le scénario a bien eu lieu
    // — sans quoi la garde serait vacante).
    expect((c.valueOf('mob')! as List).length, 1);
    // …le champ voisin n'a pas été reconstruit une seule fois de plus…
    expect(builds['autre'], before['autre'],
        reason: 'SM-1 : la mutation structurelle de la sous-liste est bornée');
    // …et la sous-liste elle-même n'a pas été re-dispatchée : l'agrégation vers
    // la tranche parente reste HORS de la voie de rebuild du conteneur.
    expect(builds['mob'], before['mob'],
        reason: 'le conteneur ne souscrit pas à sa propre tranche de valeur');
  });

  // ── G4 — ACL de ligne : les DEUX branches ─────────────────────────────────

  testWidgets(
      'G4a — sans `aclCollectionId`, une ACL de scope refusant tout laisse le '
      'bouton d\'ajout (comportement DP-6 inchangé)', (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester
        .pumpWidget(_stepper(c, _fieldsPlain, acl: const _DenyAll()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
      'G4b — avec `aclCollectionId`, la même ACL retire réellement l\'ajout',
      (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_stepper(
      c,
      const <ZFieldSpec>[
        _subListAcl,
        _autre,
        ZFieldSpec(name: 'autre2', type: EditionFieldType.text, label: 'Autre2'),
      ],
      acl: const _DenyAll(),
    ));
    await tester.pumpAndSettle();
    // Le champ EST bien monté (garde non vacante) …
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    // … et c'est l'ACL qui a retiré l'affordance de création.
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets(
      'G4c — avec `aclCollectionId` mais SANS ACL restrictive au scope, '
      'l\'ajout reste offert', (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_stepper(c, const <ZFieldSpec>[
      _subListAcl,
      _autre,
      ZFieldSpec(name: 'autre2', type: EditionFieldType.text, label: 'Autre2'),
    ]));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  // ── G6 — la surface d'erreur ne coûte PAS la granularité ─────────────────

  testWidgets(
      'G6 — sous révélation, le message requis se met à jour SANS reconstruire '
      'le conteneur de sous-liste', (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    var mobDispatch = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[_subListRequired, _autre],
          fieldBuilder: (context, ctrl, f) => ZFieldWidget(
            controller: ctrl,
            field: f,
            autovalidateMode: AutovalidateMode.always,
            // Compteur posé sur la CRÉATION du conteneur de sous-liste (le
            // sujet réel : `fieldBuilder` ne mesurerait que le canal
            // structurel de `DynamicEdition`, pas la voie de rebuild du champ).
            onBuild: f.name == 'mob' ? () => mobDispatch++ : null,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Révélé + vide ⇒ le message EST rendu (sans quoi la suite serait vacante).
    expect(find.text('REQ-MOB'), findsOneWidget);
    final before = mobDispatch;

    c.setValue('mob', <Map<String, dynamic>>[
      <String, dynamic>{'poste': 'Lomé'},
    ]);
    await tester.pumpAndSettle();

    // Le message a disparu : la surface d'erreur est bien réactive…
    expect(find.text('REQ-MOB'), findsNothing);
    // …et le conteneur n'a pas été re-dispatché pour autant (passage par
    // `child:` — c'est ce qui empêche la surface d'erreur de casser SM-1).
    expect(mobDispatch, before);
  });

  // ── G5 — mode « tout affiché » (v0.66.0) ─────────────────────────────────

  testWidgets('G5 — la sous-liste monte aussi en mode déplié `showAllSteps`',
      (tester) async {
    _bigView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_stepper(c, _fieldsPlain,
        config: const ZStepperConfig(showAllSteps: true)));
    await tester.pumpAndSettle();
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    // En déplié, la fenêtre est l'union de TOUTES les étapes.
    expect(c.visibleFields.value, <String>['mob', 'autre', 'autre2']);
  });
}
