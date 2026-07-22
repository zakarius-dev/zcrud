// CR-IFFD-22 — fermeture des deux limites déclarées à la livraison du moteur.
//
// 1. `options` dérivées : le moteur les publiait dans une tranche que le champ
//    NE LISAIT PAS. Une spec pouvait donc déclarer `options` et ne rien voir —
//    une capacité annoncée que personne n'exécute, exactement le défaut que
//    CR-IFFD-18 a sanctionné.
// 2. `visible` sous `ZStepperEdition` : non appliquée. Le stepper est le seul
//    écrivain de `visibleFields` ; la limite est SIGNALÉE plutôt que masquée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _app(ZFormController c, List<ZFieldSpec> fields) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: DynamicEdition(controller: c, fields: fields),
        ),
      ),
    );

/// `pays` (texte) → `ville` (select) dont les OPTIONS sont dérivées.
List<ZFieldSpec> _paysVille({String? choicesFromKey}) => <ZFieldSpec>[
      const ZFieldSpec(name: 'pays', type: EditionFieldType.text, label: 'Pays'),
      ZFieldSpec(
        name: 'ville',
        type: EditionFieldType.select,
        label: 'Ville',
        config: choicesFromKey == null
            ? const ZSelectConfig()
            : ZSelectConfig(choicesFromKey: choicesFromKey),
        derivedFrom: ZDerivation(
          sources: const <String>['pays'],
          overwrite: ZDerivationOverwrite.always,
          options: (v) async => v['pays'] == 'FR'
              ? const <ZFieldChoice>[
                  ZFieldChoice(value: 'paris', label: 'Paris'),
                  ZFieldChoice(value: 'lyon', label: 'Lyon'),
                ]
              : const <ZFieldChoice>[ZFieldChoice(value: 'rome', label: 'Rome')],
        ),
      ),
    ];

void main() {
  group('CR-IFFD-22 — les options dérivées sont RÉELLEMENT lues', () {
    testWidgets('🔴 sans aucun câblage d\'hôte, les options arrivent',
        (tester) async {
      // C'est LE point : `derivedFrom.options` doit suffire. Avant, il fallait
      // que l'hôte branche lui-même `choicesFromKey` sur la clé du canal — et
      // s'il l'oubliait, la tranche était écrite sans que personne ne la lise.
      final c = ZFormController(
        initialValues: <String, Object?>{'pays': '', 'ville': null},
        visibleFields: const <String>['pays', 'ville'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, _paysVille()));
      await tester.pumpAndSettle();

      c.setValue('pays', 'FR');
      await tester.pumpAndSettle();

      expect(
        c.valueOf(ZDerivationChannels.optionsKey('ville')),
        isA<List<ZFieldChoice>>(),
        reason: 'le moteur publie bien la tranche',
      );
      // Et surtout : le champ la CONSOMME.
      await tester.tap(find.byKey(const ValueKey<String>('ville')));
      await tester.pumpAndSettle();
      expect(find.text('Paris'), findsWidgets);
      expect(find.text('Rome'), findsNothing);
    });

    testWidgets('changer la source RECALCULE les options affichées',
        (tester) async {
      final c = ZFormController(
        initialValues: <String, Object?>{'pays': 'FR', 'ville': null},
        visibleFields: const <String>['pays', 'ville'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, _paysVille()));
      await tester.pumpAndSettle();

      c.setValue('pays', 'IT');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('ville')));
      await tester.pumpAndSettle();
      expect(find.text('Rome'), findsWidgets);
      expect(find.text('Paris'), findsNothing);
    });

    testWidgets('un `choicesFromKey` EXPLICITE reste prioritaire',
        (tester) async {
      // L'hôte qui câble à la main garde le dernier mot : le socle ne doit pas
      // écraser une intention exprimée.
      final c = ZFormController(
        initialValues: <String, Object?>{
          'pays': 'FR',
          'ville': null,
          'mesOptions': const <ZFieldChoice>[
            ZFieldChoice(value: 'x', label: 'Choix maison'),
          ],
        },
        visibleFields: const <String>['pays', 'ville'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _app(c, _paysVille(choicesFromKey: 'mesOptions')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('ville')));
      await tester.pumpAndSettle();
      expect(find.text('Choix maison'), findsWidgets);
      expect(find.text('Paris'), findsNothing);
    });

    testWidgets('AD-10 — une tranche corrompue ne casse pas le rendu',
        (tester) async {
      final c = ZFormController(
        initialValues: <String, Object?>{'pays': 'FR', 'ville': null},
        visibleFields: const <String>['pays', 'ville'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, _paysVille()));
      await tester.pumpAndSettle();

      c.setValue(ZDerivationChannels.optionsKey('ville'), 'pas une liste');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('un champ SANS `derivedFrom.options` est intact', (tester) async {
      // Non-régression : le repli statique reste le comportement par défaut.
      final c = ZFormController(
        initialValues: <String, Object?>{'v': null},
        visibleFields: const <String>['v'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[
        ZFieldSpec(
          name: 'v',
          type: EditionFieldType.select,
          label: 'V',
          choices: <ZFieldChoice>[ZFieldChoice(value: 's', label: 'Statique')],
        ),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('v')));
      await tester.pumpAndSettle();
      expect(find.text('Statique'), findsWidgets);
    });
  });
}
