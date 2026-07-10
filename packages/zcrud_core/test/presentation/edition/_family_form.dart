// Harnais partagé de **formulaire multi-familles** pour les tests E3-3a
// (dispatch, a11y, RTL, L4). Un champ par famille de base + relation + un champ
// non-base (repli) + un champ caché. Route via `DynamicEdition` (donc le
// dispatcher `ZFieldWidget` par défaut).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Options `select`/`radio`/`checkbox` de référence.
const List<ZFieldChoice> refChoices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Option A'),
  ZFieldChoice(value: 'b', label: 'Option B'),
  ZFieldChoice(value: 'c', label: 'Option C'),
];

/// Spécifications couvrant les 6 familles de base + `hidden` + un type de repli.
final List<ZFieldSpec> familyFields = <ZFieldSpec>[
  const ZFieldSpec(name: 'texte', type: EditionFieldType.text, label: 'Texte'),
  const ZFieldSpec(
      name: 'multi', type: EditionFieldType.multiline, label: 'Multi'),
  const ZFieldSpec(name: 'pass', type: EditionFieldType.password, label: 'Pass'),
  const ZFieldSpec(name: 'nb', type: EditionFieldType.number, label: 'Nombre'),
  const ZFieldSpec(name: 'ent', type: EditionFieldType.integer, label: 'Entier'),
  const ZFieldSpec(name: 'dec', type: EditionFieldType.float, label: 'Décimal'),
  const ZFieldSpec(name: 'dt', type: EditionFieldType.dateTime, label: 'Date'),
  const ZFieldSpec(name: 'heure', type: EditionFieldType.time, label: 'Heure'),
  const ZFieldSpec(name: 'bool', type: EditionFieldType.boolean, label: 'Actif'),
  const ZFieldSpec(
      name: 'sel',
      type: EditionFieldType.select,
      label: 'Choix',
      choices: refChoices),
  const ZFieldSpec(
      name: 'rad',
      type: EditionFieldType.radio,
      label: 'Radio',
      choices: refChoices),
  const ZFieldSpec(
      name: 'chk',
      type: EditionFieldType.checkbox,
      label: 'Cases',
      choices: refChoices,
      multiple: true),
  const ZFieldSpec(
      name: 'rel', type: EditionFieldType.relation, label: 'Relation'),
  const ZFieldSpec(
      name: 'cache', type: EditionFieldType.hidden, label: 'Caché'),
  const ZFieldSpec(
      name: 'md', type: EditionFieldType.markdown, label: 'Markdown'),
];

/// Contrôleur pré-rempli pour tous les champs multi-familles.
ZFormController familyController() => ZFormController(
      initialValues: <String, Object?>{for (final f in familyFields) f.name: null},
      visibleFields: <String>[for (final f in familyFields) f.name],
    );

/// Monte le formulaire multi-familles sous un `MaterialApp` ([textDirection]
/// pour le RTL). Les libellés l10n retombent sur la table `en` intégrée sans
/// delegate monté (`label()`), suffisant pour ces tests.
Widget familyApp(
  ZFormController controller, {
  TextDirection textDirection = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: familyFields),
        ),
      ),
    );

/// Agrandit la surface de test pour que **tous** les champs multi-familles soient
/// montés (le `ListView.builder` ne monte sinon que les champs visibles).
void useTallFamilySurface(WidgetTester tester, {double height = 4000}) {
  tester.view.physicalSize = Size(1200, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
