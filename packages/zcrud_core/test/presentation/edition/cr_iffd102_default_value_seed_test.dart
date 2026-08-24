// CR-IFFD-102 — `ZFieldSpec.defaultValue` est APPLIQUÉ par le moteur
// d'édition : toute tranche ABSENTE d'`initialValues` est amorcée avec le
// défaut de sa spec (site unique : `DynamicEdition` →
// `ZFormController.seedDefaultValue`).
//
// Règle absent/nul gardée : une clé FOURNIE dans `initialValues` — même avec
// `null` explicite — est autoritaire et n'est jamais remplacée (le
// discriminant est la présence de la clé, comme la sentinelle du `copyWith`
// généré). Le générateur reste inchangé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'statut', type: EditionFieldType.text, defaultValue: 'brouillon'),
  ZFieldSpec(name: 'poids', type: EditionFieldType.float, defaultValue: 1.5),
  ZFieldSpec(name: 'libre', type: EditionFieldType.text),
];

Future<void> _pump(WidgetTester tester, ZFormController c) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DynamicEdition(controller: c, fields: _fields)),
      ),
    );

void main() {
  testWidgets('🔴 tranche ABSENTE ⇒ amorcée avec `defaultValue`, champ '
      'pristine (non dirty)', (tester) async {
    final c = ZFormController();
    await _pump(tester, c);
    expect(c.valueOf('statut'), 'brouillon');
    expect(c.valueOf('poids'), 1.5);
    expect(c.valueOf('libre'), isNull, reason: 'sans défaut, rien n\'est amorcé');
    expect(c.isDirty.value, isFalse,
        reason: 'un défaut appliqué n\'est pas une modification');
    // Le champ texte AFFICHE le défaut amorcé.
    expect(find.text('brouillon'), findsOneWidget);
    c.dispose();
  });

  testWidgets('🔴 clé PRÉSENTE avec `null` EXPLICITE ⇒ autoritaire, jamais '
      'écrasée par le défaut', (tester) async {
    final c = ZFormController(initialValues: const {'statut': null});
    await _pump(tester, c);
    expect(c.valueOf('statut'), isNull,
        reason: 'null explicite ≠ absent : la clé fournie est autoritaire');
    expect(c.valueOf('poids'), 1.5, reason: 'la tranche absente, elle, est amorcée');
    c.dispose();
  });

  testWidgets('clé présente avec une VALEUR ⇒ conservée telle quelle', (
    tester,
  ) async {
    final c = ZFormController(initialValues: const {'statut': 'validé'});
    await _pump(tester, c);
    expect(c.valueOf('statut'), 'validé');
    c.dispose();
  });

  testWidgets('une écriture d\'hôte AVANT montage n\'est pas écrasée', (
    tester,
  ) async {
    final c = ZFormController()..setValue('statut', 'importé');
    await _pump(tester, c);
    expect(c.valueOf('statut'), 'importé');
    c.dispose();
  });

  testWidgets('le `reset` restaure le DÉFAUT amorcé (baseline = défaut)', (
    tester,
  ) async {
    final c = ZFormController();
    await _pump(tester, c);
    c.setValue('statut', 'modifié');
    expect(c.isDirty.value, isTrue);
    c.reset();
    expect(c.valueOf('statut'), 'brouillon');
    expect(c.isDirty.value, isFalse);
    c.dispose();
  });
}
