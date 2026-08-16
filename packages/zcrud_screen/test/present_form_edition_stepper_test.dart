// Gardes de la **voie stepper** de `presentFormEdition` : un formulaire
// présenté en fenêtre peut être rendu en étapes, dont le nombre peut dépendre
// des données, sans que le contrat de sortie change d'un iota.
//
// Contre-témoin permanent : `z_form_only_test.dart` garde la voie à plat. Ici,
// le contre-témoin est REJOUÉ (`sans étapes, rien ne change`) pour que la
// preuve ne dépende pas d'un autre fichier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

/// Catalogue de référence : trois champs, répartis sur deux étapes. `quai`
/// porte le seul validateur — c'est lui qui sert la garde de l'étape non
/// visitée.
const List<ZFieldSpec> _catalogue = <ZFieldSpec>[
  ZFieldSpec(name: 'navire', type: EditionFieldType.text, label: 'Nom du navire'),
  ZFieldSpec(
    name: 'quai',
    type: EditionFieldType.text,
    label: 'Quai',
    validators: <ZValidatorSpec>[
      ZValidatorSpec.required(errorText: 'Quai obligatoire'),
    ],
  ),
  ZFieldSpec(name: 'tonnage', type: EditionFieldType.number, label: 'Tonnage'),
];

const List<ZEditionStep> _steps = <ZEditionStep>[
  ZEditionStep(title: 'Navire', fields: <String>['navire']),
  ZEditionStep(title: 'Escale', fields: <String>['quai', 'tonnage']),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

/// Monte un bouton « ouvrir » qui appelle [open] et retient son résultat.
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

void main() {
  group('presentFormEdition — la voie stepper', () {
    testWidgets('(a) le formulaire présenté peut rendre des ÉTAPES',
        (tester) async {
      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: _catalogue,
            steps: _steps,
            initialValues: const <String, Object?>{'quai': 'A3'},
            title: 'Escale',
            submitLabel: 'Enregistrer',
            discardLabel: 'Annuler',
          ),
          (_) {},
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      // L'assistant est monté…
      expect(find.byType(ZStepperEdition), findsOneWidget);
      // …la première étape est affichée…
      expect(find.text('Nom du navire'), findsOneWidget);
      // …et la seconde ne l'est PAS (c'est bien un assistant, pas une liste
      // plate déguisée).
      //
      // `textContaining` et non `text` : le libellé d'un champ REQUIS est un
      // `Text.rich` portant le marqueur d'obligation en `WidgetSpan` — son
      // texte brut vaut « Quai\uFFFC ». Un `find.text('Quai')` y serait
      // TAUTOLOGIQUE : il ne trouverait rien, formulaire monté ou pas.
      expect(find.textContaining('Quai'), findsNothing);
      expect(find.text('Tonnage'), findsNothing);
    });

    testWidgets(
        '(b) le NOMBRE d\'étapes dépend des données (liste variable, pas const)',
        (tester) async {
      // Le cas legacy : une étape par type de document présent. Le jeu de
      // documents n'est connu qu'à l'appel.
      Future<void> ouvrirAvec(List<String> documents) async {
        final champs = <ZFieldSpec>[
          for (final doc in documents)
            ZFieldSpec(
              name: 'doc_$doc',
              type: EditionFieldType.text,
              label: 'Référence $doc',
            ),
        ];
        final etapes = <ZEditionStep>[
          for (final doc in documents)
            ZEditionStep(title: doc, fields: <String>['doc_$doc']),
        ];
        await _pump(
          tester,
          _opener(
            (context) => presentFormEdition(
              context,
              fields: champs,
              steps: etapes,
              // Toutes les étapes dépliées : leur NOMBRE est alors observable
              // à l'écran, sans dépendre d'un libellé de navigation.
              stepperConfig:
                  const ZStepperConfig(stepsDisplay: ZStepsDisplay.allExpanded),
              title: 'Documents',
              submitLabel: 'Enregistrer',
              discardLabel: 'Annuler',
            ),
            (_) {},
          ),
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();
      }

      await ouvrirAvec(<String>['Facture', 'Connaissement', 'Certificat']);
      for (final doc in <String>['Facture', 'Connaissement', 'Certificat']) {
        expect(find.text(doc), findsOneWidget, reason: 'étape $doc absente');
      }

      // La fenêtre précédente est refermée : le `Navigator` est conservé d'un
      // `pumpWidget` à l'autre, sa route resterait empilée.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Mêmes appel et mêmes types, un seul document : une seule étape.
      await ouvrirAvec(<String>['Facture']);
      expect(find.text('Facture'), findsOneWidget);
      expect(find.text('Connaissement'), findsNothing);
      expect(find.text('Certificat'), findsNothing);
    });

    testWidgets(
        '(c) la soumission rend les valeurs de TOUTES les étapes, normalisées',
        (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: _catalogue,
            steps: _steps,
            initialValues: const <String, Object?>{
              'navire': 'Aurore',
              'quai': 'A3',
              'tonnage': '12,5',
            },
            title: 'Escale',
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
      // La seconde étape n'a jamais été affichée…
      expect(find.textContaining('Quai'), findsNothing);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(termine, isTrue);
      expect(rendu, isNotNull);
      expect(rendu!['navire'], 'Aurore');
      // …et ses valeurs sortent tout de même, normalisées ('12,5' ⇒ 12.5).
      expect(rendu!['quai'], 'A3');
      expect(rendu!['tonnage'], 12.5);
    });

    testWidgets(
        '(d) un champ INVALIDE dans une étape NON VISITÉE empêche la soumission',
        (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: _catalogue,
            steps: _steps,
            // `quai` est requis et vide — il vit dans la SECONDE étape.
            initialValues: const <String, Object?>{
              'navire': 'Aurore',
              'quai': '',
            },
            title: 'Escale',
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
      // Preuve que l'étape fautive n'a JAMAIS été montée (le libellé d'un champ
      // requis porte un marqueur en `WidgetSpan` : seule une recherche par
      // SOUS-CHAÎNE mord ici).
      expect(find.textContaining('Quai'), findsNothing);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Assertion sur le RÉSULTAT, pas sur l'affichage : rien n'est rendu et la
      // fenêtre reste ouverte.
      expect(termine, isFalse);
      expect(rendu, isNull);
      expect(find.byType(ZStepperEdition), findsOneWidget);
    });

    testWidgets('(e) CONTRE-TÉMOIN : sans étapes, rien ne change',
        (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: _catalogue,
            initialValues: const <String, Object?>{
              'navire': 'Aurore',
              'quai': 'A3',
              'tonnage': '12,5',
            },
            title: 'Escale',
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

      // Aucun assistant, et TOUS les champs sont là — le formulaire à plat.
      expect(find.byType(ZStepperEdition), findsNothing);
      expect(find.text('Nom du navire'), findsOneWidget);
      expect(find.textContaining('Quai'), findsOneWidget);
      expect(find.text('Tonnage'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(termine, isTrue);
      expect(rendu, <String, dynamic>{
        'navire': 'Aurore',
        'quai': 'A3',
        'tonnage': 12.5,
      });
    });

    testWidgets('(f) renoncer rend `null`, étapes ou pas', (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: _catalogue,
            steps: _steps,
            initialValues: const <String, Object?>{'quai': 'A3'},
            title: 'Escale',
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
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(termine, isTrue);
      expect(rendu, isNull);
    });
  });

  group('presentFormEdition — le corps composé par l\'appelant', () {
    testWidgets('`bodyBuilder` monte le corps ; le contrat de sortie est intact',
        (tester) async {
      Map<String, dynamic>? rendu;
      var termine = false;

      await _pump(
        tester,
        _opener(
          (context) => presentFormEdition(
            context,
            fields: _catalogue,
            initialValues: const <String, Object?>{
              'navire': 'Aurore',
              'quai': 'A3',
              'tonnage': '12,5',
            },
            bodyBuilder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Rappel réglementaire'),
                ZFormOnly(controller: controller, shrinkWrap: true),
              ],
            ),
            title: 'Escale',
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
      expect(find.text('Rappel réglementaire'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(termine, isTrue);
      expect(rendu, <String, dynamic>{
        'navire': 'Aurore',
        'quai': 'A3',
        'tonnage': 12.5,
      });
    });

    testWidgets('deux corps déclarés ⇒ assertion en développement',
        (tester) async {
      Object? leve;

      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                try {
                  presentFormEdition(
                    context,
                    fields: _catalogue,
                    steps: _steps,
                    bodyBuilder: (context, controller) =>
                        ZFormOnly(controller: controller),
                  );
                } catch (error) {
                  leve = error;
                }
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(leve, isA<AssertionError>());
    });
  });
}
