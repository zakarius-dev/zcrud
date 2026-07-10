// E3-5 — `ZStepperEdition` : sectionnement d'UN `ZFormController` en étapes.
//   - AC1 : un seul controller partagé (setValue visible depuis toute étape) ;
//   - AC2 : AUCUN `Form` ancêtre sur toutes les étapes (find.byType(Form) rien) ;
//   - AC3/AC4/AC5/AC6 : validation PAR ÉTAPE (bloque/autorise/révèle ; précédent
//     inconditionnel) ;
//   - AC7/AC8/AC9 : état PRÉSERVÉ en va-et-vient (controller unique) ;
//   - AC13 : composition avec un champ conditionnel dans une étape.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Harnais : 3 étapes sur UN controller.
/// - Étape 0 : `s0_name` (required 'REQUIS0'), `s0_note` (libre).
/// - Étape 1 : `s1_flag` (garde), `s1_cond` (conditionnel required 'REQUIS1'),
///   `s1_free` (libre).
/// - Étape 2 : `s2_final` (required 'REQUIS2').
class _StepperForm {
  final List<ZFieldSpec> fields = const <ZFieldSpec>[
    ZFieldSpec(
      name: 's0_name',
      type: EditionFieldType.text,
      label: 'Nom',
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS0')],
    ),
    ZFieldSpec(name: 's0_note', type: EditionFieldType.text, label: 'Note'),
    ZFieldSpec(name: 's1_flag', type: EditionFieldType.text, label: 'Flag'),
    ZFieldSpec(
      name: 's1_cond',
      type: EditionFieldType.text,
      label: 'Conditionnel',
      condition: ZCondition.truthy('s1_flag'),
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS1')],
    ),
    ZFieldSpec(name: 's1_free', type: EditionFieldType.text, label: 'Libre'),
    ZFieldSpec(
      name: 's2_final',
      type: EditionFieldType.text,
      label: 'Final',
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS2')],
    ),
  ];

  final List<ZEditionStep> steps = const <ZEditionStep>[
    ZEditionStep(title: 'Étape 0', fields: <String>['s0_name', 's0_note']),
    ZEditionStep(
      title: 'Étape 1',
      fields: <String>['s1_flag', 's1_cond', 's1_free'],
    ),
    ZEditionStep(title: 'Étape 2', fields: <String>['s2_final']),
  ];

  int completeCount = 0;

  late final ZFormController controller = ZFormController(
    initialValues: <String, Object?>{for (final f in fields) f.name: ''},
    visibleFields: <String>[for (final f in fields) f.name],
  );

  Widget build({bool withComplete = true}) => MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: controller,
            fields: fields,
            steps: steps,
            onComplete: withComplete ? () => completeCount++ : null,
          ),
        ),
      );

  void dispose() => controller.dispose();
}

Finder _key(String name) => find.byKey(ValueKey<String>(name));
Finder _editable(String name) =>
    find.descendant(of: _key(name), matching: find.byType(EditableText));
Finder get _next => find.widgetWithText(FilledButton, 'Suivant');
Finder get _finish => find.widgetWithText(FilledButton, 'Terminer');
Finder get _previous => find.widgetWithText(OutlinedButton, 'Précédent');

void main() {
  testWidgets('AC1 — un seul controller partagé : setValue visible depuis '
      'toute étape ; jamais recréé', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    final ctrl = form.controller;
    // Écrit une valeur d'un champ d'une étape ULTÉRIEURE (non montée) : elle vit
    // dans le MÊME controller.
    ctrl.setValue('s2_final', 'depuis-étape-0');

    // Étape 0 montée : ses champs sont là ; ceux d'autres étapes non.
    expect(_key('s0_name'), findsOneWidget);
    expect(_key('s2_final'), findsNothing);

    // Remplir le required de l'étape 0 puis avancer jusqu'à l'étape 2.
    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();
    await tester.enterText(_editable('s1_free'), 'x');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();

    // Étape 2 : le champ réaffiche la valeur écrite AVANT son montage (même
    // controller, tranche jamais recréée).
    expect(_key('s2_final'), findsOneWidget);
    expect(tester.widget<EditableText>(_editable('s2_final')).controller.text,
        'depuis-étape-0');
    expect(identical(form.controller, ctrl), isTrue);
  });

  testWidgets('AC2 — AUCUN Form ancêtre sur toutes les étapes', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    expect(find.byType(Form), findsNothing, reason: 'étape 0 sans Form');

    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(find.byType(Form), findsNothing, reason: 'étape 1 sans Form');

    await tester.tap(_previous);
    await tester.pumpAndSettle();
    expect(find.byType(Form), findsNothing, reason: 'retour étape 0 sans Form');
  });

  testWidgets('AC4 — étape courante invalide ⇒ « suivant » bloqué + erreur '
      'révélée (sans interaction préalable)', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Aucune erreur avant tentative (le champ n'a jamais été touché).
    expect(find.text('REQUIS0'), findsNothing);

    await tester.tap(_next);
    await tester.pumpAndSettle();

    // Toujours étape 0 (bloqué) + message révélé sous le champ.
    expect(_key('s0_name'), findsOneWidget);
    expect(_key('s1_flag'), findsNothing);
    expect(find.text('REQUIS0'), findsOneWidget,
        reason: 'required vide révélé à la transition bloquée');
  });

  testWidgets('AC3 — un required d\'une étape ULTÉRIEURE vide ne bloque PAS la '
      'transition depuis l\'étape courante', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // s2_final (required) reste vide ; on remplit seulement le required de l'ét.0.
    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();

    // Transition autorisée (l'étape 2 n'est pas validée ici).
    expect(_key('s1_flag'), findsOneWidget);
    expect(find.text('REQUIS2'), findsNothing);
  });

  testWidgets('AC5 — étape valide ⇒ « suivant » avance ; dernière étape ⇒ '
      'onComplete (pas de soumission ici)', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('s1_flag'), findsOneWidget);

    // Étape 1 : s1_cond masqué (s1_flag vide) ⇒ pas de blocage.
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('s2_final'), findsOneWidget);

    // Dernière étape : bouton « Terminer ». Vide ⇒ bloqué + erreur.
    expect(_finish, findsOneWidget);
    await tester.tap(_finish);
    await tester.pumpAndSettle();
    expect(form.completeCount, 0);
    expect(find.text('REQUIS2'), findsOneWidget);

    // Rempli ⇒ onComplete délégué (E3-6).
    await tester.enterText(_editable('s2_final'), 'ok');
    await tester.pump();
    await tester.tap(_finish);
    await tester.pumpAndSettle();
    expect(form.completeCount, 1);
  });

  testWidgets('AC6 — « précédent » est inconditionnel (depuis une étape '
      'invalide, il recule sans blocage)', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();
    // Étape 1 montée ; rendre s1_cond visible + invalide.
    await tester.enterText(_editable('s1_flag'), 'on');
    await tester.pump();
    expect(_key('s1_cond'), findsOneWidget);

    // « suivant » bloqué (s1_cond required vide).
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('s1_flag'), findsOneWidget, reason: 'toujours étape 1');
    expect(find.text('REQUIS1'), findsOneWidget);

    // « précédent » recule quand même vers l'étape 0, sans erreur.
    await tester.tap(_previous);
    await tester.pumpAndSettle();
    expect(_key('s0_name'), findsOneWidget);
    expect(find.text('REQUIS1'), findsNothing);
  });

  testWidgets('AC7/AC8/AC9 — va-et-vient conserve les valeurs (controller '
      'unique ; buffer texte réaffiché ; tranches non détruites)',
      (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Saisir dans un champ libre + remplir le required.
    await tester.enterText(_editable('s0_note'), 'mémo-important');
    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();

    // Avancer (champs de l'étape 0 démontés).
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('s0_note'), findsNothing);
    // La tranche survit (AC9) même démontée.
    expect(form.controller.valueOf('s0_note'), 'mémo-important');

    // Revenir : valeurs restaurées, buffer texte réaffiché (AC8).
    await tester.tap(_previous);
    await tester.pumpAndSettle();
    expect(form.controller.valueOf('s0_note'), 'mémo-important');
    expect(tester.widget<EditableText>(_editable('s0_note')).controller.text,
        'mémo-important');
    expect(tester.widget<EditableText>(_editable('s0_name')).controller.text,
        'Alice');
  });

  testWidgets('AC13 — composition conditionnelle : champ masqué n\'empêche pas '
      'la transition ; visible + invalide la bloque', (tester) async {
    final form = _StepperForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    await tester.enterText(_editable('s0_name'), 'Alice');
    await tester.pump();
    await tester.tap(_next);
    await tester.pumpAndSettle();

    // s1_cond masqué (s1_flag vide) : « suivant » passe (required masqué non
    // validé — AC13).
    expect(_key('s1_cond'), findsNothing);
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('s2_final'), findsOneWidget);

    // Retour + rendre s1_cond visible : il bloque désormais.
    await tester.tap(_previous);
    await tester.pumpAndSettle();
    await tester.enterText(_editable('s1_flag'), 'on');
    await tester.pump();
    expect(_key('s1_cond'), findsOneWidget);
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('s1_flag'), findsOneWidget, reason: 'bloqué par s1_cond visible');
    expect(find.text('REQUIS1'), findsOneWidget);
  });
}
