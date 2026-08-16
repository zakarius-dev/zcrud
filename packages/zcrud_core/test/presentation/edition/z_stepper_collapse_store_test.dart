// Gardes du **relais du pli persisté des sections par `ZStepperEdition`**
// (CR DODLP « le pli des sections n'est relayé par aucun présentateur »,
// 2026-08-16 — site que le CR ne nomme PAS).
//
// Une `ZEditionStep` porte ses propres `sections`, donc ses propres sections
// repliables : sans relais, un formulaire présenté en étapes perdait son pli
// alors que le même formulaire à plat le gardait.
//
// Le point délicat n'est pas le relais mais la PORTÉE. `saveCollapsed` remplace
// la portée entière ; sous une portée commune à toutes les étapes, replier une
// section de l'étape 2 effacerait le pli enregistré à l'étape 1. Mesuré avant
// écriture du code, sur deux `DynamicEdition` à sections disjointes partageant
// un `formId` : `{A}` puis `{C}` — `A` disparu. D'où une portée dérivée par
// étape, que ce fichier garde explicitement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Store espion : persiste **et** journalise les portées qu'on lui présente.
class _StoreEspion extends ZSectionCollapseStore {
  _StoreEspion();

  final Map<String, Set<String>> _parPortee = <String, Set<String>>{};
  final List<String> lectures = <String>[];
  final List<String> ecritures = <String>[];

  int get appels => lectures.length + ecritures.length;
  Set<String> get portees => <String>{...lectures, ...ecritures};

  static String cle(String? formId) => formId ?? '<globale>';

  Set<String> etatDe(String portee) => <String>{...?_parPortee[portee]};

  @override
  Set<String> loadCollapsed(String? formId) {
    lectures.add(cle(formId));
    return <String>{...?_parPortee[cle(formId)]};
  }

  @override
  void saveCollapsed(String? formId, Set<String> collapsed) {
    ecritures.add(cle(formId));
    _parPortee[cle(formId)] = <String>{...collapsed};
  }
}

const List<ZFieldSpec> _champs = <ZFieldSpec>[
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
  ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
];

/// Deux étapes, chacune avec UNE section repliable — de titres **différents**,
/// pour que l'effacement croisé soit visible s'il survenait.
const List<ZEditionStep> _etapes = <ZEditionStep>[
  ZEditionStep(
    title: 'Navire',
    fields: <String>['a'],
    sections: <ZEditionSection>[
      ZEditionSection(title: 'Alpha', fields: <String>['a'], collapsible: true),
    ],
  ),
  ZEditionStep(
    title: 'Escale',
    fields: <String>['b'],
    sections: <ZEditionSection>[
      ZEditionSection(title: 'Beta', fields: <String>['b'], collapsible: true),
    ],
  ),
];

Finder get _next => find.widgetWithText(FilledButton, 'Next');
Finder get _previous => find.widgetWithText(OutlinedButton, 'Previous');

Finder _champ(String nom) => find.byWidgetPredicate(
      (w) => w is ZFieldWidget && w.field.name == nom,
    );

ZFormController _controleur() => ZFormController(
      initialValues: <String, Object?>{'a': '', 'b': ''},
      visibleFields: const <String>['a', 'b'],
    );

Future<void> _monter(
  WidgetTester tester, {
  required ZFormController controller,
  ZSectionCollapseStore? collapseStore,
  String? formId,
}) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ZStepperEdition(
        controller: controller,
        fields: _champs,
        steps: _etapes,
        collapseStore: collapseStore,
        formId: formId,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Jette tout l'arbre : le remontage est alors réel, pas un simple rebuild.
Future<void> _relance(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  expect(find.byType(MaterialApp), findsNothing);
}

void main() {
  group('ZStepperEdition — relais du pli des sections d\'étape', () {
    testWidgets('le pli d\'une section d\'étape SURVIT à un remontage complet',
        (tester) async {
      final espion = _StoreEspion();
      final controller = _controleur();
      addTearDown(controller.dispose);

      await _monter(tester, controller: controller, collapseStore: espion,
          formId: 'escale');
      expect(_champ('a'), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(_champ('a'), findsNothing);

      await _relance(tester);
      await _monter(tester, controller: controller, collapseStore: espion,
          formId: 'escale');
      expect(
        _champ('a'),
        findsNothing,
        reason: 'le stepper n\'a pas relu le pli enregistré au remontage',
      );
    });

    testWidgets(
        'chaque étape a SA portée : replier à l\'étape 2 n\'efface PAS le pli '
        'de l\'étape 1', (tester) async {
      final espion = _StoreEspion();
      final controller = _controleur();
      addTearDown(controller.dispose);

      await _monter(tester, controller: controller, collapseStore: espion,
          formId: 'escale');

      // Étape 1 : replie « Alpha ».
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(espion.etatDe('escale/étape:Navire'), <String>{'Alpha'});

      // Étape 2 : replie « Beta ». Sous une portée COMMUNE, cette écriture
      // remplacerait {Alpha} par {Beta}.
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(_champ('b'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(espion.etatDe('escale/étape:Escale'), <String>{'Beta'});

      // Le pli de l'étape 1 est intact dans le store…
      expect(
        espion.etatDe('escale/étape:Navire'),
        <String>{'Alpha'},
        reason: 'le pli de l\'étape 1 a été effacé par celui de l\'étape 2',
      );
      // …et à l'écran, au retour.
      await tester.tap(_previous);
      await tester.pumpAndSettle();
      expect(
        _champ('a'),
        findsNothing,
        reason: '« Alpha » est revenue dépliée : la portée n\'isole pas',
      );
    });

    testWidgets('la portée NUE n\'est jamais présentée au store',
        (tester) async {
      final espion = _StoreEspion();
      final controller = _controleur();
      addTearDown(controller.dispose);

      await _monter(tester, controller: controller, collapseStore: espion,
          formId: 'escale');
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(
        espion.portees,
        <String>{'escale/étape:Navire', 'escale/étape:Escale'},
      );
      expect(espion.portees, isNot(contains('escale')));
    });

    testWidgets('sans formId, la portée reste dérivée du titre de l\'étape',
        (tester) async {
      final espion = _StoreEspion();
      final controller = _controleur();
      addTearDown(controller.dispose);

      await _monter(tester, controller: controller, collapseStore: espion);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(espion.etatDe('étape:Navire'), <String>{'Alpha'});
      expect(espion.portees, isNot(contains('<globale>')));
    });

    testWidgets(
        'sans store déclaré, AUCUN appel — et le même store déclaré, si '
        '(contre-témoin apparié)', (tester) async {
      // (i) non déclaré : rien ne doit l'atteindre.
      final muet = _StoreEspion();
      final c1 = _controleur();
      addTearDown(c1.dispose);
      await _monter(tester, controller: c1);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(_champ('a'), findsNothing); // le pli en mémoire fonctionne
      expect(
        muet.appels,
        0,
        reason: 'lectures=${muet.lectures}, écritures=${muet.ecritures}',
      );

      // (ii) déclaré : il est appelé. Sans cette moitié, (i) serait vert même
      // si le relais n'existait pas.
      await _relance(tester);
      final declare = _StoreEspion();
      final c2 = _controleur();
      addTearDown(c2.dispose);
      await _monter(tester, controller: c2, collapseStore: declare,
          formId: 'escale');
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(declare.appels, greaterThan(0));
      expect(declare.ecritures, contains('escale/étape:Navire'));
    });
  });

  group('ZStepperEdition — sous-stepper imbriqué', () {
    const List<ZEditionStep> imbriquees = <ZEditionStep>[
      ZEditionStep(
        title: 'Racine',
        fields: <String>[],
        nestedSteps: <ZEditionStep>[
          ZEditionStep(
            title: 'Fille',
            fields: <String>['a'],
            sections: <ZEditionSection>[
              ZEditionSection(
                title: 'Alpha',
                fields: <String>['a'],
                collapsible: true,
              ),
            ],
          ),
        ],
      ),
    ];

    testWidgets('la portée du sous-stepper se DÉRIVE de celle de son étape',
        (tester) async {
      final espion = _StoreEspion();
      final controller = _controleur();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: controller,
            fields: _champs,
            steps: imbriquees,
            collapseStore: espion,
            formId: 'escale',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(
        espion.etatDe('escale/étape:Racine/étape:Fille'),
        <String>{'Alpha'},
      );
    });
  });
}
