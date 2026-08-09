// LOT 2 — `required` MORD sur une collection vide.
//
// Défaut d'origine mesuré : `_stringOf(o) => o == null ? '' : '$o'`
// (`z_field_widget.dart:253`, `z_submission.dart:272`) projetait `[]` vers la
// chaîne `"[]"`, qui n'est PAS vide ⇒ `FormBuilderValidators.required<String>`
// ACCEPTAIT un champ obligatoire NON rempli (multi-sélection, tags, sous-liste,
// fichiers multiples…).
//
// Ce que ces gardes tiennent :
//  - une `Iterable` / `Map` VIDE bloque `required`, à la soumission ET dans la
//    surface d'erreur révélée du champ ;
//  - la règle vaut pour TOUS les types de champ dont la tranche porte une
//    collection (pas un `kind` privilégié) ;
//  - `false`, `0`, `'0'` restent des valeurs PRÉSENTES (règle déjà en vigueur
//    dans le dépôt pour l'affichage — une seule règle, pas deux) ;
//  - une collection NON vide passe.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFieldSpec _required(String name, EditionFieldType type,
        {bool multiple = false}) =>
    ZFieldSpec(
      name: name,
      type: type,
      label: name,
      multiple: multiple,
      validators: const <ZValidatorSpec>[ZValidatorSpec.required()],
    );

/// Soumission d'un formulaire à un seul champ requis portant [value].
Future<ZSubmissionOutcome<Unit>> _submitOne(
  ZFieldSpec field,
  Object? value, {
  required List<Map<String, Object?>> sink,
}) async {
  final controller = ZFormController(
    initialValues: <String, Object?>{field.name: value},
    visibleFields: <String>[field.name],
  );
  addTearDown(controller.dispose);
  final submit = ZEditionSubmitController<Unit>(
    controller: controller,
    fields: <ZFieldSpec>[field],
    onSubmit: (values) async {
      sink.add(values);
      return Right<ZFailure, Unit>(unit);
    },
  );
  addTearDown(submit.dispose);
  return submit.submit();
}

void main() {
  group('Une collection VIDE bloque `required` (soumission)', () {
    // Le correctif porte sur la PROJECTION DE VALEUR, pas sur un `kind` : il
    // vaut donc uniformément. On le MESURE type par type pour qu'aucune famille
    // ne puisse diverger silencieusement.
    final cases = <String, (EditionFieldType, bool)>{
      'select multiple': (EditionFieldType.select, true),
      'relation multiple': (EditionFieldType.relation, true),
      'tags': (EditionFieldType.tags, true),
      'rowChips': (EditionFieldType.rowChips, true),
      'checkbox groupé': (EditionFieldType.checkbox, true),
      'subItems': (EditionFieldType.subItems, true),
      'dynamicItem': (EditionFieldType.dynamicItem, true),
      'file multiple': (EditionFieldType.file, true),
      'image multiple': (EditionFieldType.image, true),
      'document multiple': (EditionFieldType.document, true),
    };

    for (final entry in cases.entries) {
      test('${entry.key} : `[]` ⇒ soumission REFUSÉE', () async {
        final sink = <Map<String, Object?>>[];
        final outcome = await _submitOne(
          _required('champ', entry.value.$1, multiple: entry.value.$2),
          const <Object>[],
          sink: sink,
        );
        expect(outcome.isValidationFailure, isTrue,
            reason: '${entry.key} : une collection vide n\'est PAS remplie');
        expect(sink, isEmpty, reason: 'onSubmit n\'est jamais appelé');
      });
    }

    test('une `Map` vide ⇒ soumission REFUSÉE', () async {
      final sink = <Map<String, Object?>>[];
      final outcome = await _submitOne(
        _required('champ', EditionFieldType.subItems, multiple: true),
        const <String, Object?>{},
        sink: sink,
      );
      expect(outcome.isValidationFailure, isTrue);
      expect(sink, isEmpty);
    });

    test('un `Set` vide ⇒ soumission REFUSÉE (toute `Iterable`)', () async {
      final sink = <Map<String, Object?>>[];
      final outcome = await _submitOne(
        _required('champ', EditionFieldType.select, multiple: true),
        <Object>{},
        sink: sink,
      );
      expect(outcome.isValidationFailure, isTrue);
      expect(sink, isEmpty);
    });

    test('une collection NON vide PASSE', () async {
      final sink = <Map<String, Object?>>[];
      final outcome = await _submitOne(
        _required('champ', EditionFieldType.select, multiple: true),
        const <Object>['a'],
        sink: sink,
      );
      expect(outcome.isSuccess, isTrue);
      expect(sink, hasLength(1));
    });
  });

  group('Aucune valeur légitime n\'est requalifiée en vide', () {
    // Le dépôt traite DÉJÀ `false` et `0` comme affichables
    // (`DynamicEdition._isEmptyValue`) : la règle de validation s'y ALIGNE, elle
    // n'en invente pas une seconde.
    final present = <String, Object?>{
      '`false`': false,
      '`true`': true,
      '`0` (int)': 0,
      '`0.0` (double)': 0.0,
      '`\'0\'` (chaîne)': '0',
    };
    // NB : `' '` (espace seul) est refusé — mais par le TRIM de
    // `FormBuilderValidators.required`, comportement PRÉ-EXISTANT et inchangé
    // par ce lot (`zValidationText(' ') == ' '`, non vide). Mesuré, pas supposé.

    for (final e in present.entries) {
      test('${e.key} est une valeur PRÉSENTE → soumission acceptée', () async {
        final sink = <Map<String, Object?>>[];
        final outcome = await _submitOne(
          _required('champ', EditionFieldType.boolean),
          e.value,
          sink: sink,
        );
        expect(outcome.isSuccess, isTrue,
            reason: '${e.key} ne doit JAMAIS compter comme non rempli');
        expect(sink, hasLength(1));
      });
    }

    test('`null` et `\'\'` restent vides (aucune régression inverse)', () async {
      for (final v in <Object?>[null, '']) {
        final sink = <Map<String, Object?>>[];
        final outcome = await _submitOne(
          _required('champ', EditionFieldType.text),
          v,
          sink: sink,
        );
        expect(outcome.isValidationFailure, isTrue);
        expect(sink, isEmpty);
      }
    });
  });

  group('Surface d\'erreur du CHAMP (pas seulement la soumission)', () {
    testWidgets(
        'multi-sélection requise vide : l\'erreur est RÉVÉLÉE et ANNONCÉE',
        (tester) async {
      final field = ZFieldSpec(
        name: 'pays',
        type: EditionFieldType.select,
        label: 'Pays',
        multiple: true,
        validators: const <ZValidatorSpec>[
          ZValidatorSpec.required(errorText: 'Champ obligatoire'),
        ],
        choices: const <ZFieldChoice>[
          ZFieldChoice(value: 'tg', label: 'Togo'),
          ZFieldChoice(value: 'bj', label: 'Bénin'),
        ],
      );
      final controller = ZFormController(
        initialValues: <String, Object?>{'pays': const <Object>[]},
        visibleFields: const <String>['pays'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            child: Scaffold(
              body: DynamicEdition(
                controller: controller,
                fields: <ZFieldSpec>[field],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Champ obligatoire'), findsNothing,
          reason: 'pas d\'erreur avant révélation');

      controller.revealErrors();
      await tester.pump();

      expect(find.text('Champ obligatoire'), findsOneWidget,
          reason: 'une multi-sélection vide EST une saisie manquante');
    });
  });
}
