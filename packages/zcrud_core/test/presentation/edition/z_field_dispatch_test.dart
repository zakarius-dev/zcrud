// AC1/AC2/AC3/AC4 (E3-3a) + AC14 (E3-3b-1/-2/-3) — Dispatch par type : famille
// dédiée par famille de base, familles-feuilles avancées (tags/rowChips/rating/
// slider/color) + imbriquées (subItems→subList, dynamicItem) + rendu custom
// (`signature`→signature dédié ; `widget`→freeWidget via registre), point
// d'extension `registryOrFallback` (repli SANS registre) ; famille dédiée
// `file` (E3-3c : `file`/`image`/`document` → `ZAppFileField`) ; le SEUL type
// encore non servi (`stepper` → E3-5) reste en repli contrôlé. Exhaustivité
// 0-default prouvée sur les 39 `EditionFieldType.values`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Types de base attendus → type de widget dédié rendu par le dispatcher.
const Map<EditionFieldType, Type> _baseWidget = <EditionFieldType, Type>{
  EditionFieldType.text: ZTextFieldWidget,
  EditionFieldType.multiline: ZTextFieldWidget,
  EditionFieldType.password: ZTextFieldWidget,
  EditionFieldType.number: ZNumberFieldWidget,
  EditionFieldType.integer: ZNumberFieldWidget,
  EditionFieldType.float: ZNumberFieldWidget,
  EditionFieldType.dateTime: ZDateFieldWidget,
  EditionFieldType.time: ZDateFieldWidget,
  EditionFieldType.boolean: ZBooleanFieldWidget,
  EditionFieldType.select: ZSelectFieldWidget,
  EditionFieldType.radio: ZSelectFieldWidget,
  EditionFieldType.checkbox: ZSelectFieldWidget,
  EditionFieldType.relation: ZRelationFieldWidget,
};

/// Familles de base → valeur d'enum `EditionFamily` attendue (classification).
const Map<EditionFieldType, EditionFamily> _baseFamily =
    <EditionFieldType, EditionFamily>{
  EditionFieldType.text: EditionFamily.text,
  EditionFieldType.multiline: EditionFamily.text,
  EditionFieldType.password: EditionFamily.text,
  EditionFieldType.number: EditionFamily.number,
  EditionFieldType.integer: EditionFamily.number,
  EditionFieldType.float: EditionFamily.number,
  EditionFieldType.dateTime: EditionFamily.date,
  EditionFieldType.time: EditionFamily.date,
  EditionFieldType.boolean: EditionFamily.boolean,
  EditionFieldType.select: EditionFamily.select,
  EditionFieldType.radio: EditionFamily.select,
  EditionFieldType.checkbox: EditionFamily.select,
  EditionFieldType.relation: EditionFamily.relation,
};

/// Familles-feuilles avancées (E3-3b-1 + imbriquées E3-3b-2) → famille + widget
/// dédié attendus.
const Map<EditionFieldType, EditionFamily> _advancedFamily =
    <EditionFieldType, EditionFamily>{
  EditionFieldType.tags: EditionFamily.tags,
  EditionFieldType.rowChips: EditionFamily.rowChips,
  EditionFieldType.rating: EditionFamily.rating,
  EditionFieldType.slider: EditionFamily.slider,
  EditionFieldType.color: EditionFamily.color,
  EditionFieldType.subItems: EditionFamily.subList,
  EditionFieldType.dynamicItem: EditionFamily.dynamicItem,
  EditionFieldType.signature: EditionFamily.signature,
};

const Map<EditionFieldType, Type> _advancedWidget = <EditionFieldType, Type>{
  EditionFieldType.tags: ZTagsFieldWidget,
  EditionFieldType.rowChips: ZRowChipsFieldWidget,
  EditionFieldType.rating: ZRatingFieldWidget,
  EditionFieldType.slider: ZSliderFieldWidget,
  EditionFieldType.color: ZColorFieldWidget,
  EditionFieldType.subItems: ZSubListFieldWidget,
  EditionFieldType.dynamicItem: ZDynamicItemFieldWidget,
  EditionFieldType.signature: ZSignatureFieldWidget,
};

/// `widget` (freeWidget) : famille dédiée servie par le registre — SANS registre
/// enregistré → repli contrôlé (comme `registryOrFallback`).
const EditionFieldType _freeWidgetType = EditionFieldType.widget;

/// Types servis **ailleurs** via `ZWidgetRegistry` (E6/E11a/`icon`/`custom`) :
/// famille `registryOrFallback` ; SANS registre → repli contrôlé.
const List<EditionFieldType> _registryTypes = <EditionFieldType>[
  EditionFieldType.markdown,
  EditionFieldType.inlineMarkdown,
  EditionFieldType.html,
  EditionFieldType.inlineHtml,
  EditionFieldType.richText,
  EditionFieldType.location,
  EditionFieldType.geoArea,
  EditionFieldType.phoneNumber,
  EditionFieldType.country,
  EditionFieldType.address,
  EditionFieldType.icon,
  EditionFieldType.custom,
];

/// Famille fichier dédiée (E3-3c) : `file`/`image`/`document` → `EditionFamily.file`
/// + widget `ZAppFileField` (jamais le repli, même sans picker injecté).
const Map<EditionFieldType, EditionFamily> _fileFamily =
    <EditionFieldType, EditionFamily>{
  EditionFieldType.file: EditionFamily.file,
  EditionFieldType.image: EditionFamily.file,
  EditionFieldType.document: EditionFamily.file,
};

/// Types encore non servis ici → repli contrôlé jusqu'à leur story
/// (`stepper` → E3-5 est désormais le SEUL type en `unsupported`).
const List<EditionFieldType> _stillUnsupported = <EditionFieldType>[
  EditionFieldType.stepper,
];

Widget _mount(EditionFieldType type) {
  // Nom (donc `ValueKey`/place) UNIQUE par type : force un `State` neuf du
  // dispatcher entre deux `pumpWidget` successifs.
  final name = 'f_${type.name}';
  final controller = ZFormController(
    initialValues: <String, Object?>{name: null},
    visibleFields: <String>[name],
  );
  addTearDown(controller.dispose);
  final field = ZFieldSpec(name: name, type: type, label: 'F', choices: const [
    ZFieldChoice(value: 'a', label: 'A'),
    ZFieldChoice(value: 'b', label: 'B'),
  ]);
  return MaterialApp(
    home: Scaffold(
      body: DynamicEdition(controller: controller, fields: <ZFieldSpec>[field]),
    ),
  );
}

void main() {
  test('familyOf classe les 39 EditionFieldType sans throw (exhaustif)', () {
    // La classification est TOTALE : aucune valeur ne lève ni ne reste non
    // classée. (Le switch de `familyOf` est exhaustif SANS default : un futur
    // type casserait la compilation — prouvé ici côté runtime.)
    for (final type in EditionFieldType.values) {
      final family = familyOf(type); // ne throw jamais
      expect(EditionFamily.values.contains(family), isTrue);
    }
    expect(EditionFieldType.values.length, 39,
        reason: 'catalogue canonique = 39 types');
  });

  test('partition exhaustive 39 = base(13)+hidden(1)+feuilles(8)+freeWidget(1)'
      '+registre(12)+file(3)+unsupported(1) (AC14/E3-3c)', () {
    expect(_baseFamily.length, 13);
    expect(_advancedFamily.length, 8);
    expect(_registryTypes.length, 12);
    expect(_fileFamily.length, 3);
    expect(_stillUnsupported.length, 1);
    final all = <EditionFieldType>{
      ..._baseFamily.keys,
      EditionFieldType.hidden,
      ..._advancedFamily.keys,
      _freeWidgetType,
      ..._registryTypes,
      ..._fileFamily.keys,
      ..._stillUnsupported,
    };
    // Aucun doublon + couverture totale des 39 valeurs.
    expect(all.length, 39);
    expect(all, EditionFieldType.values.toSet());
  });

  test('0 default : chaque type → sa famille attendue', () {
    for (final entry in _baseFamily.entries) {
      expect(familyOf(entry.key), entry.value);
      expect(familyOf(entry.key), isNot(EditionFamily.unsupported));
    }
    for (final entry in _advancedFamily.entries) {
      expect(familyOf(entry.key), entry.value,
          reason: '${entry.key} → feuille ${entry.value} (jamais repli)');
      expect(familyOf(entry.key), isNot(EditionFamily.unsupported));
    }
    for (final type in _registryTypes) {
      expect(familyOf(type), EditionFamily.registryOrFallback,
          reason: '$type → registryOrFallback');
    }
    expect(familyOf(_freeWidgetType), EditionFamily.freeWidget,
        reason: 'widget → freeWidget (jamais unsupported)');
    expect(familyOf(_freeWidgetType), isNot(EditionFamily.unsupported));
    for (final entry in _fileFamily.entries) {
      expect(familyOf(entry.key), EditionFamily.file,
          reason: '${entry.key} → file (E3-3c, jamais unsupported)');
      expect(familyOf(entry.key), isNot(EditionFamily.unsupported));
    }
    for (final type in _stillUnsupported) {
      expect(familyOf(type), EditionFamily.unsupported,
          reason: '$type reste le SEUL unsupported (stepper → E3-5)');
    }
    // `stepper` est le SEUL type classé `unsupported`.
    final unsupported = EditionFieldType.values
        .where((t) => familyOf(t) == EditionFamily.unsupported)
        .toList();
    expect(unsupported, <EditionFieldType>[EditionFieldType.stepper]);
    expect(familyOf(EditionFieldType.hidden), EditionFamily.hidden);
  });

  testWidgets('chaque type de base → son widget dédié (jamais le repli)',
      (tester) async {
    for (final entry in _baseWidget.entries) {
      await tester.pumpWidget(_mount(entry.key));
      await tester.pump();
      expect(find.byType(entry.value), findsOneWidget,
          reason: '${entry.key} → ${entry.value}');
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing,
          reason: '${entry.key} ne doit pas retomber sur le repli');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('chaque feuille avancée → son widget dédié (jamais le repli) '
      '(AC14/E3-3b-1)', (tester) async {
    for (final entry in _advancedWidget.entries) {
      await tester.pumpWidget(_mount(entry.key));
      await tester.pump();
      expect(find.byType(entry.value), findsOneWidget,
          reason: '${entry.key} → ${entry.value}');
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing,
          reason: '${entry.key} ne doit pas retomber sur le repli');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('famille fichier (`file`/`image`/`document`) → ZAppFileField '
      '(jamais le repli) (E3-3c)', (tester) async {
    for (final type in _fileFamily.keys) {
      await tester.pumpWidget(_mount(type));
      await tester.pump();
      expect(find.byType(ZAppFileField), findsOneWidget,
          reason: '$type → ZAppFileField');
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing,
          reason: '$type ne doit pas retomber sur le repli');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('registryOrFallback SANS registre → repli contrôlé (AC2/AC14)',
      (tester) async {
    for (final type in _registryTypes) {
      await tester.pumpWidget(_mount(type));
      await tester.pump();
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget,
          reason: '$type sans registre → repli');
      expect(tester.takeException(), isNull, reason: '$type ne doit pas throw');
      expect(find.byType(ErrorWidget), findsNothing);
    }
  });

  testWidgets('freeWidget (`widget`) SANS registre → repli contrôlé (AC11)',
      (tester) async {
    await tester.pumpWidget(_mount(_freeWidgetType));
    await tester.pump();
    // La famille dédiée est bien montée…
    expect(find.byType(ZFreeWidgetFieldWidget), findsOneWidget);
    // …et retombe sur le repli faute de builder enregistré (jamais un throw).
    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('types encore non servis → repli contrôlé, aucune exception '
      '(AC14 frontières)', (tester) async {
    for (final type in _stillUnsupported) {
      await tester.pumpWidget(_mount(type));
      await tester.pump();
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget,
          reason: '$type → repli contrôlé (hors E3-3b-1)');
      expect(tester.takeException(), isNull, reason: '$type ne doit pas throw');
      expect(find.byType(ErrorWidget), findsNothing);
    }
  });

  testWidgets('hidden → SizedBox.shrink zéro-taille, pas de crash (AC4)',
      (tester) async {
    await tester.pumpWidget(_mount(EditionFieldType.hidden));
    await tester.pump();
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    expect(tester.takeException(), isNull);
    final hidden = find.byType(ZFieldWidget, skipOffstage: false);
    expect(hidden, findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.getSize(hidden).height, 0.0);
  });
}
