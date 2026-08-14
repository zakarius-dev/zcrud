// Gardes du **formulaire seul** et de l'édition en fenêtre rendant une carte
// de valeurs (`ZFormOnly` / `ZFormOnlyController` / `presentFormEdition`).
//
// Contre-témoin : l'écran assemblé (`ZCrudScreen`) est couvert par les gardes
// voisines de ce paquet — elles vérifient que sa voie d'enregistrement est
// inchangée alors que sa normalisation passe désormais par la voie unique
// `zNormalizeFormValues`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

/// Énumération métier : sert la garde de normalisation (camelCase attendu en
/// persistance).
enum Statut { ouvert, clos }

/// Schéma de référence des gardes : un champ de chaque nature mise en jeu.
const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(
    name: 'nom',
    type: EditionFieldType.text,
    validators: <ZValidatorSpec>[
      ZValidatorSpec.required(errorText: 'Nom obligatoire'),
    ],
  ),
  ZFieldSpec(name: 'note', type: EditionFieldType.number),
  ZFieldSpec(name: 'debut', type: EditionFieldType.dateTime),
  ZFieldSpec(
    name: 'statut',
    type: EditionFieldType.select,
    choices: <ZFieldChoice>[
      ZFieldChoice(value: 'ouvert', label: 'Ouvert'),
      ZFieldChoice(value: 'clos', label: 'Clos'),
    ],
  ),
  ZFieldSpec(name: 'archive', type: EditionFieldType.text, readOnly: true),
  ZFieldSpec(
    name: 'motif',
    type: EditionFieldType.text,
    condition: ZCondition.equals('statut', 'clos'),
  ),
];

Map<String, Object?> _seed() => <String, Object?>{
      'nom': 'Awa',
      'note': '12,5',
      'debut': DateTime.utc(2026, 8, 13, 9, 30),
      'statut': Statut.ouvert,
      'archive': 'valeur figée',
      'motif': 'ne doit pas sortir',
    };

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  group('ZFormOnly — le formulaire, et rien d\'autre', () {
    testWidgets('aucune coquille dans son arbre', (tester) async {
      await _pump(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Ma page')),
          body: ZFormOnly(fields: _fields, initialValues: _seed()),
        ),
      );

      // Non-vacuité : le formulaire est bien monté et rend ses champs.
      expect(find.byType(ZFormOnly), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ZFormOnly),
          matching: find.byType(DynamicEdition),
        ),
        findsOneWidget,
      );
      expect(find.text('Awa'), findsOneWidget);

      // La coquille est celle de la PAGE (hors du formulaire), jamais du
      // formulaire lui-même.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ZFormOnly),
          matching: find.byType(Scaffold),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ZFormOnly),
          matching: find.byType(AppBar),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'le contrôleur de la page déclenche la validation et fait apparaître '
      'les erreurs',
      (tester) async {
        final piloted = ZFormOnlyController(
          fields: _fields,
          initialValues: <String, Object?>{'nom': ''},
        );
        addTearDown(piloted.dispose);

        await _pump(
          tester,
          Scaffold(body: ZFormOnly(controller: piloted)),
        );

        // Avant toute soumission : aucun message.
        expect(find.text('Nom obligatoire'), findsNothing);

        // Soumission déclenchée depuis l'EXTÉRIEUR du formulaire (aucun
        // widget du formulaire n'est touché).
        final rendu = piloted.submit();
        await tester.pumpAndSettle();

        expect(rendu, isNull, reason: 'un formulaire invalide ne rend rien');
        expect(piloted.isValid, isFalse);
        expect(find.text('Nom obligatoire'), findsOneWidget);
      },
    );

    test('les valeurs rendues sont normalisées et filtrées', () {
      final piloted = ZFormOnlyController(
        fields: _fields,
        initialValues: _seed(),
      );
      addTearDown(piloted.dispose);

      final valeurs = piloted.submit();
      expect(valeurs, isNotNull);

      // Normalisation : nombre saisi en texte, date, valeur d'énumération.
      expect(valeurs!['note'], 12.5);
      expect(valeurs['debut'], '2026-08-13T09:30:00.000Z');
      expect(valeurs['statut'], 'ouvert');

      // Filtrage : lecture seule et champ masqué par sa condition.
      expect(valeurs.containsKey('archive'), isFalse);
      expect(valeurs.containsKey('motif'), isFalse);
      expect(valeurs['nom'], 'Awa');
    });

    testWidgets('le pilotage possédé est libéré, celui de la page ne l\'est '
        'pas', (tester) async {
      // 1) Pilotage POSSÉDÉ par le formulaire.
      await _pump(tester, Scaffold(body: ZFormOnly(fields: _fields)));
      final possede = tester
          .widget<DynamicEdition>(find.byType(DynamicEdition))
          .controller;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      // Un second `dispose` sur un contrôleur déjà libéré lève : c'est la
      // preuve qu'il l'a bien été au démontage.
      expect(possede.dispose, throwsFlutterError);

      // 2) Pilotage FOURNI par la page : il survit au démontage.
      final fourni = ZFormOnlyController(fields: _fields);
      await _pump(tester, Scaffold(body: ZFormOnly(controller: fourni)));
      final interne =
          tester.widget<DynamicEdition>(find.byType(DynamicEdition)).controller;
      expect(identical(interne, fourni.form), isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      fourni.form.setValue('nom', 'toujours vivant');
      expect(fourni.form.valueOf('nom'), 'toujours vivant');
      expect(fourni.dispose, returnsNormally);
    });
  });

  group('presentFormEdition — la fenêtre rend une carte de valeurs', () {
    testWidgets('enregistrer rend les valeurs normalisées', (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                rendu = await presentFormEdition(
                  context,
                  fields: _fields,
                  initialValues: _seed(),
                  title: 'Réglages',
                  submitLabel: 'Enregistrer',
                  discardLabel: 'Annuler',
                );
                termine = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Réglages'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(termine, isTrue);
      expect(rendu, isNotNull);
      expect(rendu!['note'], 12.5);
      expect(rendu!['debut'], '2026-08-13T09:30:00.000Z');
      expect(rendu!['statut'], 'ouvert');
      expect(rendu!.containsKey('archive'), isFalse);
      expect(rendu!.containsKey('motif'), isFalse);
    });

    testWidgets('un formulaire invalide ne rend RIEN ; renoncer rend null',
        (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                rendu = await presentFormEdition(
                  context,
                  fields: _fields,
                  initialValues: <String, Object?>{'nom': ''},
                  title: 'Réglages',
                  submitLabel: 'Enregistrer',
                  discardLabel: 'Annuler',
                );
                termine = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // La fenêtre est toujours là, l'erreur est affichée, et RIEN n'a été
      // rendu à l'appelant (assertion sur le résultat, pas sur l'affichage).
      expect(termine, isFalse);
      expect(rendu, isNull);
      expect(find.text('Nom obligatoire'), findsOneWidget);

      // Renoncer : la fenêtre se ferme et rend `null`.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(termine, isTrue);
      expect(rendu, isNull);
    });
  });
}
