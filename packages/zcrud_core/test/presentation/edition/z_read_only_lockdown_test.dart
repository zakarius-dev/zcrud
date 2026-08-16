// LOT 3 — **la lecture seule verrouille vraiment**.
//
// Trois défauts mesurés, corrigés ici :
//  1. `DynamicEdition._permittedFormActions` filtrait sur l'ACL SEULE et
//     ignorait `readOnly` : les actions d'ÉCRITURE restaient offertes sur un
//     formulaire en lecture ;
//  2. `ZAppFileField` émettait TOUJOURS sa barre d'actions d'acquisition,
//     seulement grisée (`enabled: actionsEnabled`) — ces boutons n'auraient
//     jamais dû être montés ;
//  3. `DynamicEdition._effective` ne force `readOnly: true` que sur les specs de
//     PREMIER NIVEAU : les sous-champs d'un `subItems` inline et d'un
//     `dynamicItem` restaient ÉDITABLES et FOCALISABLES en lecture globale.
//
// Les actions de LECTURE (consulter, historique, réessai de RÉSOLUTION) restent
// disponibles : la lecture seule coupe l'écriture, pas la consultation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_app_file_resolver.dart';
import '../../support/fake_file_picker.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

Widget _form({
  required List<ZFieldSpec> fields,
  required ZFormController controller,
  bool readOnly = false,
  List<ZFormAction> actions = const <ZFormAction>[],
  ZFilePicker? picker,
  ZAppFileResolver? resolver,
}) =>
    MaterialApp(
      home: ZcrudScope(
        // ACL permissive DÉCLARÉE : le socle refuse par défaut, et ce fichier
        // mesure le VERROU de la lecture seule, pas celui de l'ACL.
        acl: const ZAllowAllAcl(),
        filePicker: picker,
        appFileResolver: resolver,
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            readOnly: readOnly,
            formActions: actions,
          ),
        ),
      ),
    );

ZFormAction _action(String id, ZCrudAction perm) => ZFormAction(
      id: id,
      label: id,
      requiredPermission: perm,
      onInvoke: () {},
    );

void main() {
  group('1 — les actions de FORMULAIRE', () {
    final actions = <ZFormAction>[
      _action('Consulter', ZCrudAction.view),
      _action('Historique', ZCrudAction.history),
      _action('Enregistrer', ZCrudAction.update),
      _action('Supprimer', ZCrudAction.delete),
      _action('Dupliquer', ZCrudAction.copy),
      _action('Archiver', ZCrudAction.archive),
      _action('Publier', ZCrudAction.publish),
      _action('Vider', ZCrudAction.clear),
      _action('Valider', ZCrudAction.validate),
      _action('Restaurer', ZCrudAction.restore),
      _action('Créer', ZCrudAction.create),
    ];

    testWidgets('en ÉDITION : toutes les actions permises sont offertes',
        (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'t': ''},
        visibleFields: const <String>['t'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
        ],
        controller: controller,
        actions: actions,
      ));
      await tester.pump();

      for (final a in actions) {
        expect(find.text(a.id), findsOneWidget, reason: '${a.id} en édition');
      }
    });

    testWidgets(
        'en LECTURE SEULE : les actions d\'ÉCRITURE DISPARAISSENT, celles de '
        'LECTURE restent', (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'t': ''},
        visibleFields: const <String>['t'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
        ],
        controller: controller,
        readOnly: true,
        actions: actions,
      ));
      await tester.pump();

      // Lecture : conservées.
      expect(find.text('Consulter'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      // Écriture : ABSENTES DE L'ARBRE (pas simplement grisées).
      for (final id in const <String>[
        'Enregistrer',
        'Supprimer',
        'Dupliquer',
        'Archiver',
        'Publier',
        'Vider',
        'Valider',
        'Restaurer',
        'Créer',
      ]) {
        expect(find.text(id), findsNothing, reason: '$id est une ÉCRITURE');
      }
    });

    testWidgets(
        'lecture seule + AUCUNE action de lecture ⇒ aucune zone d\'actions rendue',
        (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'t': ''},
        visibleFields: const <String>['t'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
        ],
        controller: controller,
        readOnly: true,
        actions: <ZFormAction>[_action('Supprimer', ZCrudAction.delete)],
      ));
      await tester.pump();

      expect(find.text('Supprimer'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    test('classification lecture/écriture — table EXPLICITE (domaine pur)', () {
      expect(ZCrudAction.view.mutatesData, isFalse);
      expect(ZCrudAction.history.mutatesData, isFalse);
      for (final a in const <ZCrudAction>[
        ZCrudAction.create,
        ZCrudAction.update,
        ZCrudAction.delete,
        ZCrudAction.restore,
        ZCrudAction.copy,
        ZCrudAction.archive,
        ZCrudAction.publish,
        ZCrudAction.clear,
        ZCrudAction.validate,
      ]) {
        expect(a.mutatesData, isTrue, reason: '${a.name} écrit');
      }
    });
  });

  group('2 — la barre d\'actions du champ FICHIER', () {
    testWidgets('en ÉDITION : les boutons de source sont MONTÉS', (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'p': null},
        visibleFields: const <String>['p'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'p',
            type: EditionFieldType.document,
            label: 'Pièce',
            config: FileFieldConfig(
                allowedSources: <ZFileSource>[ZFileSource.filePicker]),
          ),
        ],
        controller: controller,
        picker: FakeFilePicker(const <AppFile>[]),
      ));
      await tester.pump();

      expect(find.byTooltip('Pick a file'), findsOneWidget);
    });

    testWidgets(
        'en LECTURE SEULE : la barre d\'acquisition N\'EST PLUS ÉMISE '
        '(ni grisée, ni présente)', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'p': const AppFile(
              name: 'p.pdf', mimeType: 'application/pdf', localPath: '/p'),
        },
        visibleFields: const <String>['p'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'p',
            type: EditionFieldType.document,
            label: 'Pièce',
            config: FileFieldConfig(
                allowedSources: <ZFileSource>[ZFileSource.filePicker]),
          ),
        ],
        controller: controller,
        readOnly: true,
        picker: FakeFilePicker(const <AppFile>[]),
      ));
      await tester.pump();

      expect(find.byTooltip('Pick a file'), findsNothing,
          reason: 'acquérir un fichier est une ÉCRITURE');
      expect(find.byTooltip('Remove file'), findsNothing,
          reason: 'supprimer un fichier est une ÉCRITURE');
      // …mais le champ et sa valeur restent VISIBLES (la lecture seule ne
      // masque ni le libellé ni le contenu).
      expect(find.text('Pièce'), findsOneWidget);
      expect(find.text('p.pdf'), findsOneWidget);
    });

    testWidgets(
        'en LECTURE SEULE, le réessai de RÉSOLUTION (action de lecture) reste '
        'offert', (tester) async {
      final resolver = FakeAppFileResolver(failure: FakeResolveFailure.exception);
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'p': <Object>['ref-1'],
        },
        visibleFields: const <String>['p'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'p',
            type: EditionFieldType.document,
            label: 'Pièce',
            multiple: true,
            config: FileFieldConfig(
                allowedSources: <ZFileSource>[ZFileSource.filePicker]),
          ),
        ],
        controller: controller,
        readOnly: true,
        resolver: resolver,
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Retry loading'), findsOneWidget,
          reason: 'recharger n\'écrit RIEN — c\'est une lecture');
      expect(find.byTooltip('Remove file'), findsNothing,
          reason: 'retirer la référence EST une écriture');
    });
  });

  group('3 — la lecture seule DESCEND dans les sous-champs', () {
    testWidgets('subItems (inline) : les sous-champs deviennent readOnly',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'f1': 'valeur'},
          ],
        },
        visibleFields: const <String>['items'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'items',
            type: EditionFieldType.subItems,
            label: 'Items',
            // Mode inline DÉCLARÉ : ces gardes descendent dans les sous-champs
            // **déballés**. `compact` étant devenu le défaut, ne rien déclarer
            // les ferait porter sur une table de résumé.
            config: ZSubListConfig(
              itemFields: _itemFields,
              displayMode: ZSubListDisplayMode.inline,
            ),
          ),
        ],
        controller: controller,
        readOnly: true,
      ));
      await tester.pumpAndSettle();

      // En consultation, les sous-champs ne sont pas des champs de saisie
      // neutralisés : ce sont des FICHES. La propriété gardée — aucune
      // mutation possible — est donc affirmée sur l'absence TOTALE de surface
      // de saisie, ce qui est strictement plus fort que `readOnly: true`.
      expect(find.byType(TextField), findsNothing,
          reason: 'un item consulté en lecture seule n\'est pas éditable');
      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(_itemFields.length));
      expect(find.text('valeur'), findsOneWidget);
    });

    testWidgets('dynamicItem : les sous-champs deviennent readOnly',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'item': <String, dynamic>{'f1': 'valeur'},
        },
        visibleFields: const <String>['item'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'item',
            type: EditionFieldType.dynamicItem,
            label: 'Item',
            config: ZSubListConfig(itemFields: _itemFields),
          ),
        ],
        controller: controller,
        readOnly: true,
      ));
      await tester.pumpAndSettle();

      // Même règle que pour la sous-liste : fiche, et aucune surface de saisie.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(_itemFields.length));
      expect(find.text('valeur'), findsOneWidget);
    });

    testWidgets('en ÉDITION, les sous-champs restent éditables (non-régression)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'f1': 'valeur'},
          ],
        },
        visibleFields: const <String>['items'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_form(
        fields: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'items',
            type: EditionFieldType.subItems,
            label: 'Items',
            // Mode inline DÉCLARÉ : ces gardes descendent dans les sous-champs
            // **déballés**. `compact` étant devenu le défaut, ne rien déclarer
            // les ferait porter sur une table de résumé.
            config: ZSubListConfig(
              itemFields: _itemFields,
              displayMode: ZSubListDisplayMode.inline,
            ),
          ),
        ],
        controller: controller,
      ));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.readOnly, isFalse);
    });
  });

  group('4 — astérisque requis : jamais en lecture seule', () {
    // ⚠️ La garde porte sur un champ dont la spec est `readOnly: true` SANS mode
    // lecture GLOBAL. C'est le seul chemin où `ZFieldLabel` est effectivement
    // MONTÉ : en mode lecture global, une famille « fiche-able » bascule sur
    // `ZReadOnlyFieldCard` et `ZFieldLabel` n'existe plus dans l'arbre — une
    // garde posée là serait VACANTE (elle passerait faute de sujet, pas grâce à
    // la règle). Mesuré : sous injection de `showStar = field.isRequired`, une
    // garde en mode global restait VERTE.
    Future<int> starCount(WidgetTester tester, {required bool readOnly}) async {
      final spec = ZFieldSpec(
        name: 't',
        type: EditionFieldType.text,
        label: 'Nom',
        readOnly: readOnly,
        validators: const <ZValidatorSpec>[ZValidatorSpec.required()],
      );
      final controller = ZFormController(
        initialValues: const <String, Object?>{'t': ''},
        visibleFields: const <String>['t'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
          _form(fields: <ZFieldSpec>[spec], controller: controller));
      await tester.pumpAndSettle();
      return find
          .byWidgetPredicate((w) =>
              w is RichText && w.text.toPlainText().contains('*'))
          .evaluate()
          .length;
    }

    testWidgets('champ requis ÉDITABLE : l\'astérisque est rendu',
        (tester) async {
      expect(await starCount(tester, readOnly: false), greaterThan(0));
    });

    testWidgets('même champ requis en LECTURE SEULE : AUCUN astérisque',
        (tester) async {
      // Le libellé reste rendu (rien n'est masqué) — seul l'astérisque tombe.
      expect(await starCount(tester, readOnly: true), 0,
          reason: 'la lecture seule ne demande rien à l\'utilisateur');
      expect(find.text('Nom'), findsWidgets,
          reason: 'le libellé n\'est JAMAIS perdu en lecture seule');
    });
  });
}
