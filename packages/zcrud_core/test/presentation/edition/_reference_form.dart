// Harnais partagé de **formulaire de référence** pour les tests E3-1 (SM-1
// plein-format + UJ-2). Fabrique un `ZFormController` + `List<ZFieldSpec>` de
// ≥ 30 champs répartis en ≥ 3 sections, avec des compteurs de build par champ
// et un compteur de build de niveau formulaire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Nombre de champs par section (3 sections × 12 = 36 champs ≥ 30).
const int fieldsPerSection = 12;

/// Titres des 3 sections de référence.
const List<String> sectionTitles = <String>['Identité', 'Contact', 'Notes'];

/// Nom déterministe du champ `index` de la `section` (0-based).
String fieldName(int section, int index) => 'f_${section}_$index';

/// Résultat de la fabrique : contrôleur, specs, sections et compteurs branchés.
class ReferenceForm {
  /// [validatorsByField] attache des `ZValidatorSpec` champ-locaux à quelques
  /// champs (E3-2 / AC7 : SM-1 avec validation active). Défaut : aucun (les
  /// tests E3-1 restent inchangés).
  ReferenceForm({
    this.validatorsByField = const <String, List<ZValidatorSpec>>{},
  });

  /// Validateurs déclaratifs par nom de champ (E3-2).
  final Map<String, List<ZValidatorSpec>> validatorsByField;

  /// Compteurs de build par champ (nom → nombre d'exécutions du slice builder).
  final Map<String, int> fieldBuilds = <String, int>{};

  /// Compteurs d'`initState` par champ (preuve UJ-2 : State non recréé).
  final Map<String, int> fieldInits = <String, int>{};

  /// Compteur de build de niveau formulaire (builder structurel).
  int formBuilds = 0;

  late final List<ZFieldSpec> fields = <ZFieldSpec>[
    for (var s = 0; s < sectionTitles.length; s++)
      for (var i = 0; i < fieldsPerSection; i++)
        ZFieldSpec(
          name: fieldName(s, i),
          type: EditionFieldType.text,
          label: 'Champ $s.$i',
          validators: validatorsByField[fieldName(s, i)] ??
              const <ZValidatorSpec>[],
        ),
  ];

  late final List<ZEditionSection> sections = <ZEditionSection>[
    for (var s = 0; s < sectionTitles.length; s++)
      ZEditionSection(
        title: sectionTitles[s],
        fields: <String>[
          for (var i = 0; i < fieldsPerSection; i++) fieldName(s, i),
        ],
      ),
  ];

  late final ZFormController controller = ZFormController(
    initialValues: <String, Object?>{for (final f in fields) f.name: ''},
    visibleFields: <String>[for (final f in fields) f.name],
  );

  /// Total de champs (≥ 30).
  int get fieldCount => fields.length;

  /// Construit un `DynamicEdition` instrumenté (compteurs branchés par champ et
  /// au niveau formulaire). Route via le **dispatcher** `ZFieldWidget` (E3-3a) :
  /// les preuves E3-1/E3-2 (SM-1/UJ-2/stabilité) sont ainsi rejouées À TRAVERS
  /// le nouveau chemin de dispatch. La place stable (`ValueKey(name)`) est
  /// garantie par `DynamicEdition._buildField` (KeyedSubtree) — le builder ne la
  /// pose plus lui-même.
  Widget buildForm() => DynamicEdition(
        controller: controller,
        fields: fields,
        sections: sections,
        onStructuralBuild: () => formBuilds++,
        fieldBuilder: (context, ctrl, field) => ZFieldWidget(
          controller: ctrl,
          field: field,
          onInit: () =>
              fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
          onBuild: () =>
              fieldBuilds[field.name] = (fieldBuilds[field.name] ?? 0) + 1,
        ),
      );

  void dispose() => controller.dispose();
}

/// Agrandit la surface de test pour que **tous** les champs soient montés
/// (comptage déterministe des voisins). À appeler avant `pumpWidget`.
void useTallSurface(WidgetTester tester, {double height = 6000}) {
  tester.view.physicalSize = Size(1000, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Localise l'`EditableText` interne du champ [name] (place stable `ValueKey`).
Finder editableOf(String name) => find.descendant(
      of: find.byKey(ValueKey<String>(name)),
      matching: find.byType(EditableText),
    );
