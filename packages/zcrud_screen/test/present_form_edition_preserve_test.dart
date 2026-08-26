// Gardes du mode FUSIONNANT de `presentFormEdition` (`preserveInitialValues`).
//
// Le défaut visé : la carte rendue par la fenêtre est la projection du
// formulaire (`zNormalizeFormValues`), qui part d'une carte VIDE et n'itère que
// sur les champs déclarés, actifs et modifiables. Une application qui réécrit
// cette carte telle quelle sur un document existant, par un enregistrement en
// écrasement total, perd donc TOUT ce que le catalogue ne déclare pas —
// identifiant compris : la mise à jour devient une création.
//
// Le premier groupe est le TÉMOIN de cette perte : il l'assert explicitement,
// sans l'option. Il doit rester vert après le lot — c'est lui qui donne son
// sens au correctif, et lui qui rougirait si le mode fusionnant devenait le
// défaut.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

/// Catalogue de référence : un champ modifiable, un champ numérique (dont la
/// NORMALISATION distingue la valeur du formulaire de la valeur initiale), un
/// champ `readOnly`, et un champ masqué par une condition non satisfaite.
const List<ZFieldSpec> _catalogue = <ZFieldSpec>[
  ZFieldSpec(name: 'titre', type: EditionFieldType.text, label: 'Titre'),
  ZFieldSpec(name: 'tonnage', type: EditionFieldType.number, label: 'Tonnage'),
  ZFieldSpec(name: 'archive', type: EditionFieldType.text, readOnly: true),
  ZFieldSpec(
    name: 'statut',
    type: EditionFieldType.select,
    label: 'Statut',
    choices: <ZFieldChoice>[
      ZFieldChoice(value: 'ouvert', label: 'Ouvert'),
      ZFieldChoice(value: 'clos', label: 'Clos'),
    ],
  ),
  ZFieldSpec(
    name: 'motif',
    type: EditionFieldType.text,
    label: 'Motif',
    condition: ZCondition.equals('statut', 'clos'),
  ),
];

/// Le document tel qu'il vient du dépôt : les champs du catalogue **et** les
/// clés techniques qu'aucun `ZFieldSpec` ne déclare (le cas mesuré chez les
/// hôtes : `id`, `folderId`, `subFolderId`).
Map<String, Object?> _document() => <String, Object?>{
      'id': 'doc-42',
      'folderId': 'dossier-7',
      'subFolderId': 'sous-dossier-3',
      'titre': 'Rapport',
      // String : la projection du formulaire rend un `num` — c'est ce qui
      // distingue « la valeur vient du formulaire » de « elle vient du fond ».
      'tonnage': '12,5',
      'archive': 'valeur figée',
      'statut': 'ouvert',
      'motif': 'ne doit pas sortir',
    };

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

Widget _opener(
  Future<Map<String, dynamic>?> Function(BuildContext context) open,
  void Function(Map<String, dynamic>? rendu) onDone,
) =>
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onDone(await open(context)),
          child: const Text('ouvrir'),
        ),
      ),
    );

/// Ouvre la fenêtre, enregistre, et rend la carte remise à l'appelant.
Future<Map<String, dynamic>?> _ouvrirEtEnregistrer(
  WidgetTester tester, {
  required List<ZFieldSpec> fields,
  required Map<String, Object?> initialValues,
  bool? preserveInitialValues,
}) async {
  Map<String, dynamic>? rendu;
  var termine = false;
  await _pump(
    tester,
    _opener(
      (context) => preserveInitialValues == null
          // L'appel de l'AVANT-LOT, à l'identique : le paramètre n'est pas
          // seulement `false`, il n'est pas écrit. C'est ce qui fait de la
          // garde d'inertie autre chose qu'une paraphrase du défaut.
          ? presentFormEdition(
              context,
              fields: fields,
              initialValues: initialValues,
              title: 'Document',
              submitLabel: 'Enregistrer',
              discardLabel: 'Annuler',
            )
          : presentFormEdition(
              context,
              fields: fields,
              initialValues: initialValues,
              preserveInitialValues: preserveInitialValues,
              title: 'Document',
              submitLabel: 'Enregistrer',
              discardLabel: 'Annuler',
            ),
      (valeurs) {
        rendu = valeurs;
        termine = true;
      },
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();
  expect(termine, isTrue, reason: 'la fenêtre ne s\'est pas refermée');
  return rendu;
}

void main() {
  group('presentFormEdition — TÉMOIN : ce que la voie par défaut PERD', () {
    testWidgets(
        '(a) sans l\'option, les clés non déclarées sont ABSENTES du rendu',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
      );

      expect(rendu, isNotNull);
      // Assertions EXPLICITES sur les clés manquantes : c'est le chemin de
      // perte de données, nommé clé par clé.
      expect(rendu!.containsKey('id'), isFalse,
          reason: 'l\'identifiant sortirait ⇒ le témoin ne mord plus');
      expect(rendu.containsKey('folderId'), isFalse);
      expect(rendu.containsKey('subFolderId'), isFalse);
      // Et aussi : le champ `readOnly` et le champ masqué par une condition.
      expect(rendu.containsKey('archive'), isFalse);
      expect(rendu.containsKey('motif'), isFalse);
      // Ce qui SORT : les seuls champs déclarés, actifs et modifiables.
      expect(rendu.keys.toSet(), <String>{'titre', 'tonnage', 'statut'});
    });

    testWidgets('(b) `preserveInitialValues: false` = exactement ce rendu-là',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
        preserveInitialValues: false,
      );

      expect(rendu, isNotNull);
      expect(rendu!.keys.toSet(), <String>{'titre', 'tonnage', 'statut'});
      expect(rendu['titre'], 'Rapport');
      expect(rendu['tonnage'], 12.5);
      expect(rendu['statut'], 'ouvert');
    });
  });

  group('presentFormEdition — INERTIE de la voie par défaut', () {
    testWidgets(
        '(c) sur un formulaire SANS clé étrangère, le rendu est inchangé',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: <String, Object?>{
          'titre': 'Rapport',
          'tonnage': '12,5',
          'statut': 'ouvert',
        },
      );

      expect(rendu, <String, dynamic>{
        'titre': 'Rapport',
        'tonnage': 12.5,
        'statut': 'ouvert',
      });
    });

    testWidgets(
        '(d) sur un formulaire QUI en porte, le rendu est inchangé lui aussi',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
      );

      expect(rendu, <String, dynamic>{
        'titre': 'Rapport',
        'tonnage': 12.5,
        'statut': 'ouvert',
      });
    });
  });

  group('presentFormEdition — le mode FUSIONNANT', () {
    testWidgets('(e) les clés non déclarées SURVIVENT, telles quelles',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
        preserveInitialValues: true,
      );

      expect(rendu, isNotNull);
      expect(rendu!['id'], 'doc-42');
      expect(rendu['folderId'], 'dossier-7');
      expect(rendu['subFolderId'], 'sous-dossier-3');
    });

    testWidgets(
        '(f) une clé DÉCLARÉE est écrasée par le formulaire, jamais par le fond',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
        preserveInitialValues: true,
      );

      // Le fond porte la String '12,5' ; le formulaire, lui, projette un `num`.
      // La valeur rendue tranche la précédence sans ambiguïté.
      expect(rendu!['tonnage'], 12.5);
      expect(rendu['tonnage'], isA<num>());
      expect(rendu['tonnage'], isNot('12,5'));
      expect(rendu['titre'], 'Rapport');
    });

    testWidgets(
        '(g) une SAISIE de l\'utilisateur écrase la valeur initiale du fond',
        (tester) async {
      // Catalogue réduit à un unique champ éditable : la saisie est alors
      // adressable sans ambiguïté, et la clé étrangère reste observable.
      const champs = <ZFieldSpec>[
        ZFieldSpec(name: 'titre', type: EditionFieldType.text, label: 'Titre'),
      ];
      Map<String, dynamic>? rendu;
      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: champs,
            initialValues: const <String, Object?>{
              'id': 'doc-42',
              'titre': 'Rapport',
            },
            preserveInitialValues: true,
            title: 'Document',
            submitLabel: 'Enregistrer',
            discardLabel: 'Annuler',
          ),
          (valeurs) => rendu = valeurs,
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rapport révisé');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(rendu, isNotNull);
      expect(rendu!['titre'], 'Rapport révisé');
      expect(rendu!['id'], 'doc-42');
    });

    testWidgets(
        '(h) un champ `readOnly` et un champ MASQUÉ gardent leur valeur du fond',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
        preserveInitialValues: true,
      );

      // Arbitrage de cette voie : ce que le formulaire n'a pas décidé n'est pas
      // pour autant effacé du document. Un `readOnly` retiré de la carte serait
      // effacé par une écriture en écrasement total — exactement le défaut visé.
      expect(rendu!['archive'], 'valeur figée');
      expect(rendu['motif'], 'ne doit pas sortir');
    });

    testWidgets('(i) aucune clé n\'est perdue : le rendu est le document ENTIER',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: _document(),
        preserveInitialValues: true,
      );

      expect(rendu!.keys.toSet(), _document().keys.toSet());
      expect(rendu.length, 8);
    });

    testWidgets('(j) un fond ABSENT ou vide ne change rien au rendu',
        (tester) async {
      final rendu = await _ouvrirEtEnregistrer(
        tester,
        fields: _catalogue,
        initialValues: const <String, Object?>{},
        preserveInitialValues: true,
      );

      expect(rendu!.keys.toSet(), <String>{'titre', 'tonnage', 'statut'});
    });
  });
}
