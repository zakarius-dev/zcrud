// MAJEUR-1 (code-review E3-4) — Place stable DANS UNE GRILLE quand un champ
// conditionnel s'insère AVANT un champ focalisé.
//
// Régression corrigée : `ZResponsiveGrid` enveloppait chaque cellule dans un
// `SizedBox` NON keyé (enfant direct du `Wrap`, multi-enfant NON paresseux qui
// réconcilie ses enfants PAR POSITION). La `ValueKey(name)` étant enfouie sous
// le `SizedBox`, l'insertion d'une cellule conditionnelle AVANT une cellule
// focalisée décalait les `SizedBox` et détruisait l'`Element`/`State` du champ
// focalisé ⇒ focus + curseur perdus (viole AC5/AC6/SM-1/AD-2/FR-1).
//
// Après correctif : la `ValueKey(name)` est portée sur la CELLULE (enfant direct
// du `Wrap`) ⇒ réconciliation PAR CLÉ ⇒ `State` réutilisé, focus + curseur
// préservés. Ce test ÉCHOUE avec l'ancien code (SizedBox non keyé) et PASSE
// après.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Harnais grille : `trig` (garde) · `dependent` (conditionnel, truthy `trig`) ·
/// `target` (focalisé), dans CET ordre canonique ⇒ `dependent` s'insère AVANT
/// `target`. Spans 6/12 (plusieurs cellules ⇒ vraie grille, pas colonne pleine).
class _GridForm {
  final Map<String, int> fieldInits = <String, int>{};
  int formBuilds = 0;

  final List<ZFieldSpec> fields = const <ZFieldSpec>[
    ZFieldSpec(name: 'trig', type: EditionFieldType.text, label: 'Trig'),
    ZFieldSpec(
      name: 'dependent',
      type: EditionFieldType.text,
      label: 'Dependent',
      condition: ZCondition.truthy('trig'),
    ),
    ZFieldSpec(name: 'target', type: EditionFieldType.text, label: 'Target'),
  ];

  final Map<String, ZResponsiveSpan> layout = const <String, ZResponsiveSpan>{
    'trig': ZResponsiveSpan.all(6),
    'dependent': ZResponsiveSpan.all(6),
    'target': ZResponsiveSpan.all(6),
  };

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{
      'trig': '',
      'dependent': '',
      'target': '',
    },
    // Tout visible au départ : le binder masque `dependent` au montage.
    visibleFields: const <String>['trig', 'dependent', 'target'],
  );

  Widget build() => MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            layout: layout,
            gridGutter: 0,
            onStructuralBuild: () => formBuilds++,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onInit: () =>
                  fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

void main() {
  testWidgets(
      'MAJEUR-1 — conditionnel inséré AVANT un champ focalisé dans une grille : '
      'focus + curseur + State préservés', (tester) async {
    // Grande largeur ⇒ breakpoint lg (les spans 6/12 forment de vraies cellules).
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final form = _GridForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Amorçage : `trig` vide ⇒ `dependent` masqué ; `target` monté une seule fois.
    expect(form.controller.visibleFields.value, <String>['trig', 'target']);
    expect(find.byKey(const ValueKey<String>('dependent')), findsNothing);
    expect(form.fieldInits['target'], 1, reason: 'State monté une seule fois');

    final targetEditable = find.descendant(
      of: find.byKey(const ValueKey<String>('target')),
      matching: find.byType(EditableText),
    );
    TextEditingController ctrl() =>
        tester.widget<EditableText>(targetEditable).controller;
    FocusNode focus() => tester.widget<EditableText>(targetEditable).focusNode;

    // Focaliser `target` puis poser un caret AU MILIEU via l'IME simulé.
    await tester.tap(targetEditable);
    await tester.pump();
    expect(focus().hasFocus, isTrue);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ABCDEF',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(ctrl().text, 'ABCDEF');
    expect(ctrl().selection.baseOffset, 3, reason: 'caret médian posé');

    // `trig` devient truthy ⇒ `dependent` S'INSÈRE À L'INDEX 1, AVANT `target`.
    form.controller.setValue('trig', 'x');
    await tester.pumpAndSettle();
    expect(form.controller.visibleFields.value,
        <String>['trig', 'dependent', 'target']);
    expect(find.byKey(const ValueKey<String>('dependent')), findsOneWidget);

    // (1) Le `State` de `target` N'A PAS été recréé (place stable par clé de
    //     cellule) — ÉCHOUE avec l'ancien SizedBox non keyé (init passerait à 2).
    expect(form.fieldInits['target'], 1,
        reason: 'cellule keyée ⇒ Element/State réutilisés malgré le décalage');
    // (2) Focus conservé.
    expect(focus().hasFocus, isTrue,
        reason: 'focus préservé (Wrap réconcilie par clé, pas par position)');
    // (3) Curseur (sélection) + texte préservés (aucune ré-injection).
    expect(ctrl().text, 'ABCDEF');
    expect(ctrl().selection.baseOffset, 3,
        reason: 'caret médian conservé après insertion du conditionnel amont');
  });
}
