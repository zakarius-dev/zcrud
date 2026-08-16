// Gardes du **relais du pli persisté des sections** par les présentateurs de
// `zcrud_screen` (CR DODLP « le pli des sections n'est relayé par aucun
// présentateur », 2026-08-16).
//
// `DynamicEdition` porte le seam complet (`collapseStore` + `formId`) depuis
// longtemps ; ce fichier garde le fait qu'on puisse enfin l'ATTEINDRE depuis
// `presentFormEdition` et `ZFormOnly`. Les quatre critères de recette du CR
// (§6) sont repris littéralement, un groupe chacun.
//
// Le store est un ESPION : la garde (b) affirme une **absence d'appel**, pas
// une absence d'effet visible — un socle qui lirait le store sans en tenir
// compte passerait la seconde et échouerait la première.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

/// Store espion : persiste réellement (pour la garde de survie) **et** journalise
/// chaque appel avec sa portée (pour la garde d'absence et celle d'isolation).
class _StoreEspion extends ZSectionCollapseStore {
  _StoreEspion();

  final Map<String, Set<String>> _parPortee = <String, Set<String>>{};

  /// Portées passées à `loadCollapsed`, dans l'ordre.
  final List<String> lectures = <String>[];

  /// Portées passées à `saveCollapsed`, dans l'ordre.
  final List<String> ecritures = <String>[];

  int get appels => lectures.length + ecritures.length;

  /// Portées vues, tous sens confondus.
  Set<String> get portees => <String>{...lectures, ...ecritures};

  static String cle(String? formId) => formId ?? '<globale>';

  Set<String> etatDe(String? formId) =>
      <String>{...?_parPortee[cle(formId)]};

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
  ZFieldSpec(name: 'salaire', type: EditionFieldType.text, label: 'Salaire'),
  ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
];

const List<ZEditionSection> _sections = <ZEditionSection>[
  ZEditionSection(
    title: 'Finances',
    fields: <String>['salaire'],
    collapsible: true,
  ),
  ZEditionSection(title: 'Identité', fields: <String>['nom']),
];

/// Le champ membre de « Finances » n'est monté que si la section est dépliée :
/// c'est l'observable du pli.
Finder get _champReplie => find.byWidgetPredicate(
      (w) => w is ZFieldWidget && w.field.name == 'salaire',
    );

/// **Relance simulée** : jette TOUT l'arbre, Navigator et routes compris.
///
/// Un simple `pumpWidget(MaterialApp(…))` ne suffirait pas — le même type de
/// widget au même emplacement fait RÉUTILISER l'élément `Navigator`, donc la
/// fenêtre précédente reste ouverte et le remontage n'a jamais lieu (constaté :
/// la garde de survie passait alors sans rien prouver). Pomper un widget d'un
/// autre type force le démontage complet.
Future<void> _relance(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  expect(find.byType(MaterialApp), findsNothing);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

/// Ouvre la fenêtre d'édition et laisse l'arbre s'installer.
Future<void> _ouvrir(
  WidgetTester tester, {
  ZSectionCollapseStore? collapseStore,
  String? formId,
}) async {
  await _pump(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => presentFormEdition(
            context,
            fields: _champs,
            sections: _sections,
            title: 'Fiche',
            collapseStore: collapseStore,
            formId: formId,
          ),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('CR §6.1 — presentFormEdition rouvre les sections dans leur état', () {
    testWidgets(
        'le pli SURVIT à une reconstruction complète de l\'arbre '
        '(relance simulée : nouveau widget, même store)', (tester) async {
      final espion = _StoreEspion();

      // Première session : la section est dépliée, son champ est là.
      await _ouvrir(tester, collapseStore: espion, formId: 'fiche-agent');
      expect(_champReplie, findsOneWidget);

      // L'usager replie « Finances ».
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(_champReplie, findsNothing);
      expect(espion.etatDe('fiche-agent'), <String>{'Finances'});

      // RELANCE : tout l'arbre est jeté (pumpWidget d'un autre widget), seul le
      // store survit — exactement ce qui reste d'une session à la suivante.
      await _relance(tester);
      await _ouvrir(tester, collapseStore: espion, formId: 'fiche-agent');

      // Le pli est retrouvé : le champ n'est PAS monté.
      expect(
        _champReplie,
        findsNothing,
        reason: 'le pli enregistré n\'a pas été relu au remontage',
      );
      // Et il a bien été relu par le store, sous la portée déclarée.
      expect(espion.lectures, contains('fiche-agent'));
    });

    testWidgets('déplier à nouveau efface le pli enregistré', (tester) async {
      final espion = _StoreEspion();
      await _ouvrir(tester, collapseStore: espion, formId: 'fiche-agent');
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(espion.etatDe('fiche-agent'), <String>{'Finances'});

      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(_champReplie, findsOneWidget);
      expect(espion.etatDe('fiche-agent'), isEmpty);
    });
  });

  group('CR §6.2 — sans store déclaré, AUCUN appel', () {
    testWidgets(
        'un store non déclaré n\'est ni lu ni écrit — et le MÊME store déclaré '
        'l\'est (contre-témoin apparié)', (tester) async {
      // (i) Store construit mais NON déclaré : le socle ne doit avoir aucune
      // autre voie vers lui.
      final muet = _StoreEspion();
      await _ouvrir(tester);
      expect(_champReplie, findsOneWidget);
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(_champReplie, findsNothing); // le pli en mémoire marche toujours
      expect(
        muet.appels,
        0,
        reason: 'lectures=${muet.lectures}, écritures=${muet.ecritures}',
      );

      // (ii) Contre-témoin DANS LE MÊME TEST : déclaré, il est appelé. Sans
      // cette moitié, (i) serait vert même si le relais n'existait pas.
      await _relance(tester);
      final declare = _StoreEspion();
      await _ouvrir(tester, collapseStore: declare, formId: 'fiche-agent');
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(declare.appels, greaterThan(0));
      expect(declare.ecritures, contains('fiche-agent'));
    });
  });

  group('CR §6.3 — ZFormOnly se comporte comme presentFormEdition', () {
    testWidgets('le pli survit à une reconstruction complète de l\'arbre',
        (tester) async {
      final espion = _StoreEspion();

      Widget monter() => Scaffold(
            body: ZFormOnly(
              fields: _champs,
              sections: _sections,
              collapseStore: espion,
              formId: 'panneau-profil',
            ),
          );

      await _pump(tester, monter());
      expect(_champReplie, findsOneWidget);
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(espion.etatDe('panneau-profil'), <String>{'Finances'});

      // Relance simulée.
      await _relance(tester);
      await _pump(tester, monter());
      expect(
        _champReplie,
        findsNothing,
        reason: 'ZFormOnly n\'a pas relu le pli enregistré',
      );
      expect(espion.lectures, contains('panneau-profil'));
    });

    testWidgets('sans store déclaré, ZFormOnly n\'appelle rien',
        (tester) async {
      final muet = _StoreEspion();
      await _pump(
        tester,
        Scaffold(
          body: ZFormOnly(fields: _champs, sections: _sections),
        ),
      );
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(_champReplie, findsNothing);
      expect(
        muet.appels,
        0,
        reason: 'lectures=${muet.lectures}, écritures=${muet.ecritures}',
      );
    });
  });

  group('CR §6.4 — formId isole deux formulaires de même titre de section', () {
    testWidgets(
        'replier « Finances » sur la fiche agent laisse la fiche fournisseur '
        'dépliée', (tester) async {
      final espion = _StoreEspion();

      // Fiche agent : on replie.
      await _ouvrir(tester, collapseStore: espion, formId: 'fiche-agent');
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(espion.etatDe('fiche-agent'), <String>{'Finances'});

      // Fiche fournisseur : MÊME titre de section, autre portée.
      await _relance(tester);
      await _ouvrir(tester, collapseStore: espion, formId: 'fiche-fournisseur');
      expect(
        _champReplie,
        findsOneWidget,
        reason: 'le pli de la fiche agent a débordé sur la fiche fournisseur',
      );
      expect(espion.etatDe('fiche-fournisseur'), isEmpty);
      // Les deux portées ont bien été vues, distinctes.
      expect(
        espion.portees,
        containsAll(<String>['fiche-agent', 'fiche-fournisseur']),
      );
    });

    testWidgets('sans formId, la portée globale est celle qui est transmise',
        (tester) async {
      final espion = _StoreEspion();
      await _ouvrir(tester, collapseStore: espion);
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(espion.ecritures, contains('<globale>'));
      expect(espion.etatDe(null), <String>{'Finances'});
    });
  });

  group('site supplémentaire — la voie STEPPER de presentFormEdition', () {
    // Le CR ne nomme que `presentFormEdition` et `ZFormOnly`. Mais le même
    // appel, avec `steps:`, monte un `ZStepperEdition` : sans relais là aussi,
    // un formulaire en étapes perdrait silencieusement son pli.
    const List<ZEditionStep> etapes = <ZEditionStep>[
      ZEditionStep(
        title: 'Navire',
        fields: <String>['salaire'],
        sections: <ZEditionSection>[
          ZEditionSection(
            title: 'Finances',
            fields: <String>['salaire'],
            collapsible: true,
          ),
        ],
      ),
      ZEditionStep(title: 'Escale', fields: <String>['nom']),
    ];

    Future<void> ouvrirEtapes(
      WidgetTester tester, {
      ZSectionCollapseStore? collapseStore,
      String? formId,
    }) async {
      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => presentFormEdition(
                context,
                fields: _champs,
                steps: etapes,
                title: 'Escale',
                collapseStore: collapseStore,
                formId: formId,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('le pli d\'une section d\'étape SURVIT à la relance',
        (tester) async {
      final espion = _StoreEspion();
      await ouvrirEtapes(tester, collapseStore: espion, formId: 'escale');
      expect(_champReplie, findsOneWidget);
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(_champReplie, findsNothing);

      await _relance(tester);
      await ouvrirEtapes(tester, collapseStore: espion, formId: 'escale');
      expect(
        _champReplie,
        findsNothing,
        reason: 'la voie stepper n\'a pas relu le pli enregistré',
      );
    });

    testWidgets(
        'chaque étape reçoit SA portée, dérivée de formId et du titre d\'étape',
        (tester) async {
      final espion = _StoreEspion();
      await ouvrirEtapes(tester, collapseStore: espion, formId: 'escale');
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      // Jamais la portée nue : sinon deux étapes s'effaceraient l'une l'autre.
      expect(espion.ecritures, contains('escale/étape:Navire'));
      expect(espion.portees, isNot(contains('escale')));
    });

    testWidgets('sans store déclaré, la voie stepper n\'appelle rien',
        (tester) async {
      final muet = _StoreEspion();
      await ouvrirEtapes(tester);
      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(_champReplie, findsNothing);
      expect(
        muet.appels,
        0,
        reason: 'lectures=${muet.lectures}, écritures=${muet.ecritures}',
      );
    });
  });
}
