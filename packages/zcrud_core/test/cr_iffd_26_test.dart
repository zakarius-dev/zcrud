// CR-IFFD-26 — deux limites d'expressivité trouvées en portant un formulaire à
// cascade.
//
// §1 `relation` ignorait `ZFieldChoice.subtitle` : c'était la SEULE des trois
//    familles à ne pas le rendre, alors que c'est celle qui en a le plus besoin
//    — elle liste des ENTITÉS, dont le seul libellé est souvent ambigu.
// §2 `ZDerivation` ne savait pas dire « laisse la cible inchangée » : le retour
//    était écrit inconditionnellement, donc rendre `null` EFFACE.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _app(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

const List<ZFieldChoice> _experts = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Amina Diallo', subtitle: '@amina.d'),
  ZFieldChoice(value: 'b', label: 'Amina Diallo', subtitle: '@a.diallo'),
];

void main() {
  group('CR-IFFD-26 §1 — `relation` rend le sous-titre', () {
    testWidgets('🔴 deux homonymes deviennent DISTINGUABLES au menu',
        (tester) async {
      // Cas réel : une liste d'experts où le libellé est le nom affiché et le
      // sous-titre le `@pseudo`. Sans sous-titre, les deux sont identiques.
      await tester.pumpWidget(_app(
        ZRelationFieldWidget(
          field: const ZFieldSpec(
            name: 'expert',
            type: EditionFieldType.relation,
            label: 'Expert',
          ),
          options: _experts,
          value: null,
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      // Les items d'un menu déroulant ne sont montés qu'à son ouverture.
      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();
      expect(find.text('@amina.d'), findsWidgets);
      expect(find.text('@a.diallo'), findsWidgets);
    });

    testWidgets('une option SANS sous-titre reste rendue à l\'identique',
        (tester) async {
      await tester.pumpWidget(_app(
        ZRelationFieldWidget(
          field: const ZFieldSpec(
            name: 'expert',
            type: EditionFieldType.relation,
            label: 'Expert',
          ),
          options: const <ZFieldChoice>[
            ZFieldChoice(value: 'a', label: 'Sans sous-titre'),
          ],
          value: null,
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();
      expect(find.text('Sans sous-titre'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('CR-IFFD-26 §2 — `zUnchanged` exprime l\'abstention', () {
    late ZFormController controller;

    setUp(() {
      controller = ZFormController(
        initialValues: <String, Object?>{'pays': 'FR', 'ville': 'Lyon'},
        visibleFields: const <String>['pays', 'ville'],
      );
    });

    tearDown(() => controller.dispose());

    List<ZFieldSpec> cascade() => <ZFieldSpec>[
          const ZFieldSpec(name: 'pays', type: EditionFieldType.text),
          ZFieldSpec(
            name: 'ville',
            type: EditionFieldType.text,
            derivedFrom: ZDerivation(
              sources: const <String>['pays'],
              overwrite: ZDerivationOverwrite.always,
              // La règle habituelle d'une cascade d'invalidation.
              value: (v) async {
                final Object? amont = v['pays'];
                if (amont == null || amont == '') return null; // efface
                return zUnchanged; // ne touche à rien
              },
            ),
          ),
        ];

    testWidgets('🔴 source VIDÉE ⇒ la cible est EFFACÉE', (tester) async {
      final engine = ZDerivationEngine(
        controller: controller,
        fields: cascade(),
      );
      addTearDown(engine.dispose);

      controller.setValue('pays', '');
      await tester.pumpAndSettle();
      expect(controller.valueOf('ville'), isNull);
    });

    testWidgets('🔴 source RENSEIGNÉE ⇒ la saisie est PRÉSERVÉE',
        (tester) async {
      // Sans `zUnchanged`, ce cas écrasait « Lyon » — rendre `null` efface, et
      // il n'existait aucune façon de s'abstenir. La cascade restait donc
      // câblée impérativement, c'est-à-dire ce que CR-IFFD-22 avait supprimé.
      final engine = ZDerivationEngine(
        controller: controller,
        fields: cascade(),
      );
      addTearDown(engine.dispose);

      controller.setValue('pays', 'IT');
      await tester.pumpAndSettle();
      expect(controller.valueOf('ville'), 'Lyon',
          reason: 'la saisie de l\'utilisateur doit être laissée tranquille');
    });

    testWidgets('`null` EFFACE toujours — la sémantique d\'avant est intacte',
        (tester) async {
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          const ZFieldSpec(name: 'pays', type: EditionFieldType.text),
          ZFieldSpec(
            name: 'ville',
            type: EditionFieldType.text,
            derivedFrom: ZDerivation(
              sources: const <String>['pays'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async => null,
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      controller.setValue('pays', 'IT');
      await tester.pumpAndSettle();
      expect(controller.valueOf('ville'), isNull);
    });

    testWidgets('l\'abstention se COMPOSE avec `ifPristine`', (tester) async {
      // Les deux conditions sont orthogonales : `ifPristine` porte sur l'état
      // vierge de la CIBLE, `zUnchanged` sur la valeur de la SOURCE.
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          const ZFieldSpec(name: 'pays', type: EditionFieldType.text),
          ZFieldSpec(
            name: 'ville',
            type: EditionFieldType.text,
            derivedFrom: ZDerivation(
              sources: const <String>['pays'],
              overwrite: ZDerivationOverwrite.ifPristine,
              value: (v) async => zUnchanged,
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      controller.setValue('pays', 'IT');
      await tester.pumpAndSettle();
      expect(controller.valueOf('ville'), 'Lyon');
    });

    test('le marqueur est comparé par IDENTITÉ, jamais par égalité', () {
      // Une valeur métier ne doit pas pouvoir se faire passer pour lui, même si
      // elle s'imprime pareil.
      expect(identical(zUnchanged, zUnchanged), isTrue);
      expect(identical('zUnchanged', zUnchanged), isFalse);
      expect(zUnchanged.toString(), 'zUnchanged');
    });
  });
}
