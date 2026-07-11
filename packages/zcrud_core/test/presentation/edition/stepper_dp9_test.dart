// DP-9 — `ZStepperConfig` appliqué + steppers IMBRIQUÉS (parité DODLP B11/M12/M16).
//   - AC5/AC8/AC9 : styles numbered/icons/dots/progressBar, showLabels/showSubtitles ;
//   - AC10 : allowStepTap (retour libre, saut avant gated, false non interactif) ;
//   - AC12 : gate validateOnNext configurable (défaut strict / false libre) ;
//   - AC11/AC13/AC14/AC16 : nesting sur controller unique, visibleFields = union
//     du chemin actif, va-et-vient préserve l'état, SM-1 dans une sous-étape ;
//   - AC15 : a11y/RTL pour top/start/bottom.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));
Finder _editable(String name) =>
    find.descendant(of: _key(name), matching: find.byType(EditableText));
Finder get _next => find.widgetWithText(FilledButton, 'Suivant');

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Harnais simple 2 étapes (styles / gate / tap) ────────────────────────────

class _Simple {
  _Simple({this.config = const ZStepperConfig()});
  final ZStepperConfig config;

  final List<ZFieldSpec> fields = const <ZFieldSpec>[
    ZFieldSpec(
      name: 'a',
      type: EditionFieldType.text,
      label: 'A',
      validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'RA')],
    ),
    ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
  ];

  late final List<ZEditionStep> steps = const <ZEditionStep>[
    ZEditionStep(
      title: 'Étape A',
      fields: <String>['a'],
      icon: Icons.person,
      subtitle: 'Sous-titre A',
    ),
    ZEditionStep(title: 'Étape B', fields: <String>['b'], icon: Icons.map),
  ];

  int complete = 0;

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{'a': '', 'b': ''},
    visibleFields: const <String>['a', 'b'],
  );

  Widget build([TextDirection dir = TextDirection.ltr]) => MaterialApp(
        home: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: ZStepperEdition(
              controller: controller,
              fields: fields,
              steps: steps,
              config: config,
              onComplete: () => complete++,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

void main() {
  // ── Bloc A/B : styles & métadonnées ────────────────────────────────────────

  testWidgets('AC5 — style numbered (défaut) : « k/N » + titre conservés',
      (tester) async {
    _bigView(tester);
    final f = _Simple();
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Étape A'), findsOneWidget);
  });

  testWidgets('AC8 — style icons : icône d\'étape rendue (repli numéro si null)',
      (tester) async {
    _bigView(tester);
    final f = _Simple(config: const ZStepperConfig(style: ZStepStyle.icons));
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person), findsOneWidget, reason: 'icône étape 0');
    expect(find.byIcon(Icons.map), findsNothing, reason: 'icône étape 1 non montée');
  });

  testWidgets('AC9 — showSubtitles affiche le sous-titre ; défaut ne l\'affiche pas',
      (tester) async {
    _bigView(tester);
    final off = _Simple();
    addTearDown(off.dispose);
    await tester.pumpWidget(off.build());
    await tester.pumpAndSettle();
    expect(find.text('Sous-titre A'), findsNothing, reason: 'défaut showSubtitles=false');

    final on = _Simple(config: const ZStepperConfig(showSubtitles: true));
    addTearDown(on.dispose);
    await tester.pumpWidget(on.build());
    await tester.pumpAndSettle();
    expect(find.text('Sous-titre A'), findsOneWidget);
  });

  testWidgets('AC5 — style dots : N marqueurs ; showLabels:false masque le titre',
      (tester) async {
    _bigView(tester);
    final f = _Simple(
      config: const ZStepperConfig(style: ZStepStyle.dots, showLabels: false),
    );
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    // Deux marqueurs d'étape sémantiques (un par étape).
    expect(find.bySemanticsLabel('Étape 1 sur 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Étape 2 sur 2'), findsOneWidget);
    expect(find.text('Étape A'), findsNothing, reason: 'titres masqués');
  });

  testWidgets('AC5 — style progressBar', (tester) async {
    _bigView(tester);
    final f = _Simple(config: const ZStepperConfig(style: ZStepStyle.progressBar));
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.5, 0.0001), reason: 'étape 1/2');
  });

  // ── AC12 : gate configurable ───────────────────────────────────────────────

  testWidgets('AC12 — validateOnNext:true (défaut) bloque + révèle', (tester) async {
    _bigView(tester);
    final f = _Simple();
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('a'), findsOneWidget, reason: 'toujours étape 0 (bloqué)');
    expect(find.text('RA'), findsOneWidget, reason: 'required révélé');
  });

  testWidgets('AC12 — validateOnNext:false ⇒ navigation LIBRE (aucune validation)',
      (tester) async {
    _bigView(tester);
    final f = _Simple(config: const ZStepperConfig(validateOnNext: false));
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    // 'a' required vide, mais navigation libre ⇒ avance sans erreur.
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(_key('b'), findsOneWidget, reason: 'avance librement');
    expect(find.text('RA'), findsNothing, reason: 'aucune erreur révélée');
  });

  // ── AC10 : allowStepTap ────────────────────────────────────────────────────

  testWidgets('AC10 — dots tapable : retour arrière libre, saut avant gated',
      (tester) async {
    _bigView(tester);
    final f = _Simple(config: const ZStepperConfig(style: ZStepStyle.dots));
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();

    // Saut avant vers étape 1 : gate (a required vide) ⇒ bloqué.
    await tester.tap(find.bySemanticsLabel('Étape 2 sur 2'));
    await tester.pumpAndSettle();
    expect(_key('a'), findsOneWidget, reason: 'saut avant gated ⇒ reste étape 0');
    expect(find.text('RA'), findsOneWidget);

    // Remplir puis sauter en avant.
    await tester.enterText(_editable('a'), 'x');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Étape 2 sur 2'));
    await tester.pumpAndSettle();
    expect(_key('b'), findsOneWidget, reason: 'saut avant autorisé après remplissage');

    // Retour arrière libre par tap.
    await tester.tap(find.bySemanticsLabel('Étape 1 sur 2'));
    await tester.pumpAndSettle();
    expect(_key('a'), findsOneWidget, reason: 'retour arrière inconditionnel');
  });

  testWidgets('AC10 — allowStepTap:false ⇒ indicateur non interactif',
      (tester) async {
    _bigView(tester);
    final f = _Simple(
      config: const ZStepperConfig(style: ZStepStyle.dots, allowStepTap: false),
    );
    addTearDown(f.dispose);
    await tester.pumpWidget(f.build());
    await tester.pumpAndSettle();
    // Aucun marqueur tapable (les dots ne sont pas enveloppés d'InkResponse).
    expect(find.byType(InkResponse), findsNothing,
        reason: 'indicateur non interactif');

    // Contre-preuve : allowStepTap:true expose des InkResponse par étape.
    final on = _Simple(config: const ZStepperConfig(style: ZStepStyle.dots));
    addTearDown(on.dispose);
    await tester.pumpWidget(on.build());
    await tester.pumpAndSettle();
    expect(find.byType(InkResponse), findsWidgets, reason: 'tapable');
  });

  // ── AC15 : a11y / positions directionnelles ────────────────────────────────

  testWidgets('AC15 — positions top/start/bottom : rendu sans exception LTR & RTL',
      (tester) async {
    _bigView(tester);
    for (final pos in ZStepIndicatorPosition.values) {
      for (final dir in TextDirection.values) {
        final f = _Simple(
          config: ZStepperConfig(
            indicatorPosition: pos,
            orientation: pos == ZStepIndicatorPosition.start
                ? ZStepOrientation.vertical
                : ZStepOrientation.horizontal,
            style: ZStepStyle.dots,
          ),
        );
        addTearDown(f.dispose);
        await tester.pumpWidget(f.build(dir));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'position $pos direction $dir sans exception/overflow');
        expect(find.bySemanticsLabel(RegExp(r'Étape 1 sur 2')), findsWidgets);
      }
    }
  });

  // ── Bloc C : steppers imbriqués ────────────────────────────────────────────

  group('Nesting (AC11/AC12/AC13/AC14)', () {
    // Parent : étape 0 (direct p0 required) ; étape 1 = nested [sub0{n0 required},
    // sub1{n1 libre}] ; étape 2 (p2 libre).
    List<ZFieldSpec> nestedFields() => const <ZFieldSpec>[
          ZFieldSpec(
            name: 'p0',
            type: EditionFieldType.text,
            label: 'P0',
            validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'RP0')],
          ),
          ZFieldSpec(
            name: 'n0',
            type: EditionFieldType.text,
            label: 'N0',
            validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'RN0')],
          ),
          ZFieldSpec(name: 'n1', type: EditionFieldType.text, label: 'N1'),
          ZFieldSpec(name: 'p2', type: EditionFieldType.text, label: 'P2'),
        ];

    List<ZEditionStep> nestedSteps() => const <ZEditionStep>[
          ZEditionStep(title: 'P0', fields: <String>['p0']),
          ZEditionStep(
            title: 'P1',
            fields: <String>[],
            nestedSteps: <ZEditionStep>[
              ZEditionStep(title: 'N0', fields: <String>['n0']),
              ZEditionStep(title: 'N1', fields: <String>['n1']),
            ],
          ),
          ZEditionStep(title: 'P2', fields: <String>['p2']),
        ];

    ZFormController makeController() => ZFormController(
          initialValues: <String, Object?>{
            for (final f in nestedFields()) f.name: '',
          },
          visibleFields: <String>[for (final f in nestedFields()) f.name],
        );

    Widget host(ZFormController c, {VoidCallback? onComplete}) => MaterialApp(
          home: Scaffold(
            body: ZStepperEdition(
              controller: c,
              fields: nestedFields(),
              steps: nestedSteps(),
              onComplete: onComplete,
            ),
          ),
        );

    testWidgets('AC11/AC13 — sous-stepper sur controller unique ; visibleFields = '
        'union du chemin actif', (tester) async {
      _bigView(tester);
      final c = makeController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();

      // Étape 0 : fenêtre = [p0].
      expect(c.visibleFields.value, <String>['p0']);
      expect(find.byType(Form), findsNothing);

      // Remplir p0 et avancer vers l'étape parente 1 (nested monté à sub0).
      await tester.enterText(_editable('p0'), 'x');
      await tester.pump();
      await tester.tap(_next);
      await tester.pumpAndSettle();

      // Fenêtre = union : parent step1 direct (vide) + nested sub0 = [n0].
      expect(c.visibleFields.value, <String>['n0']);
      expect(_key('n0'), findsOneWidget);
      expect(find.byType(Form), findsNothing, reason: 'aucun Form imbriqué');

      // Naviguer le NESTED vers sub1 via son « Suivant ». Dans l'arbre, le nav du
      // nested (imbriqué dans le contenu) précède le nav du parent → `.first` =
      // nested, `.last` = parent. n0 required rempli pour lever le gate nested.
      await tester.enterText(_editable('n0'), 'y');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Suivant').first);
      await tester.pumpAndSettle();

      // Nested à sub1 ⇒ fenêtre = [n1].
      expect(c.visibleFields.value, <String>['n1']);
      expect(_key('n1'), findsOneWidget);
    });

    testWidgets('AC12 — gate parent honore la sous-étape active du nested',
        (tester) async {
      _bigView(tester);
      final c = makeController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();

      await tester.enterText(_editable('p0'), 'x');
      await tester.pump();
      await tester.tap(_next); // → parent step1, nested sub0 (n0 required)
      await tester.pumpAndSettle();
      expect(_key('n0'), findsOneWidget);

      // Parent « Suivant » (dernier bouton de l'arbre) : gate honore n0 (sous-étape
      // active) ⇒ bloqué car n0 vide + erreur révélée dans le nested.
      await tester.tap(find.widgetWithText(FilledButton, 'Suivant').last);
      await tester.pumpAndSettle();
      expect(_key('n0'), findsOneWidget, reason: 'parent bloqué (nested invalide)');
      expect(find.text('RN0'), findsOneWidget, reason: 'erreur nested révélée');

      // Remplir n0 ⇒ parent peut avancer vers l'étape 2.
      await tester.enterText(_editable('n0'), 'y');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Suivant').last);
      await tester.pumpAndSettle();
      expect(_key('p2'), findsOneWidget, reason: 'parent avance vers étape 2');
      expect(c.visibleFields.value, <String>['p2']);
    });

    testWidgets('AC14 — va-et-vient parent↔nested préserve les valeurs ; controller '
        'jamais recréé', (tester) async {
      _bigView(tester);
      final c = makeController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();

      await tester.enterText(_editable('p0'), 'valeur-p0');
      await tester.pump();
      await tester.tap(_next);
      await tester.pumpAndSettle();

      // Saisir dans la sous-étape nested.
      await tester.enterText(_editable('n0'), 'valeur-n0');
      await tester.pump();

      // Revenir à l'étape parente 0 (nav parent = dernier « Précédent » de l'arbre).
      await tester.tap(find.widgetWithText(OutlinedButton, 'Précédent').last);
      await tester.pumpAndSettle();
      expect(_key('p0'), findsOneWidget);
      expect(tester.widget<EditableText>(_editable('p0')).controller.text,
          'valeur-p0');

      // Les tranches nested survivent malgré le démontage.
      expect(c.valueOf('n0'), 'valeur-n0');

      // Re-avancer : la sous-étape réaffiche sa valeur (même controller).
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(_editable('n0')).controller.text,
          'valeur-n0');
      expect(identical(c, c), isTrue);
    });
  });

  // ── Nesting profondeur ≥ 2 ─────────────────────────────────────────────────

  testWidgets('AC11 — nesting de nesting (profondeur ≥ 2) sur controller unique',
      (tester) async {
    _bigView(tester);
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'l0', type: EditionFieldType.text, label: 'L0'),
      ZFieldSpec(name: 'l2', type: EditionFieldType.text, label: 'L2'),
    ];
    // Racine → étape avec nested → sous-étape avec nested (profondeur 2).
    const steps = <ZEditionStep>[
      ZEditionStep(
        title: 'R0',
        fields: <String>['l0'],
        nestedSteps: <ZEditionStep>[
          ZEditionStep(
            title: 'M0',
            fields: <String>[],
            nestedSteps: <ZEditionStep>[
              ZEditionStep(title: 'D0', fields: <String>['l2']),
            ],
          ),
        ],
      ),
    ];
    final c = ZFormController(
      initialValues: const <String, Object?>{'l0': '', 'l2': ''},
      visibleFields: const <String>['l0', 'l2'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(controller: c, fields: fields, steps: steps),
      ),
    ));
    await tester.pumpAndSettle();

    // Union du chemin actif complet : l0 (racine direct) + l2 (feuille profonde).
    expect(c.visibleFields.value.toSet(), <String>{'l0', 'l2'});
    expect(_key('l0'), findsOneWidget);
    expect(_key('l2'), findsOneWidget);
    expect(find.byType(Form), findsNothing);
  });

  // ── AC16 : SM-1 dans une sous-étape imbriquée ──────────────────────────────

  testWidgets('AC16 — 100 frappes dans un champ de sous-étape imbriquée : chrome '
      'non reconstruit, focus conservé, aucun Form', (tester) async {
    _bigView(tester);

    final builds = <String, int>{};
    var rootChrome = 0;

    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'top', type: EditionFieldType.text, label: 'Top'),
      ZFieldSpec(name: 'deep', type: EditionFieldType.text, label: 'Deep'),
      ZFieldSpec(name: 'sibling', type: EditionFieldType.text, label: 'Sib'),
    ];
    const steps = <ZEditionStep>[
      ZEditionStep(
        title: 'R0',
        fields: <String>['top'],
        nestedSteps: <ZEditionStep>[
          ZEditionStep(title: 'S0', fields: <String>['deep', 'sibling']),
        ],
      ),
    ];
    final c = ZFormController(
      initialValues: const <String, Object?>{'top': '', 'deep': '', 'sibling': ''},
      visibleFields: const <String>['top', 'deep', 'sibling'],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: c,
          fields: fields,
          steps: steps,
          onStructuralBuild: () => rootChrome++,
          fieldBuilder: (context, ctrl, field, mode) => ZFieldWidget(
            controller: ctrl,
            field: field,
            autovalidateMode: mode,
            onBuild: () => builds[field.name] = (builds[field.name] ?? 0) + 1,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Form), findsNothing, reason: 'aucun Form à aucun niveau');

    final target = _editable('deep');
    await tester.tap(target);
    await tester.pump();

    final baseChrome = rootChrome;
    final baseDeep = builds['deep']!;
    final baseSibling = builds['sibling']!;

    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(String.fromCharCode(97 + (i % 26)));
      await tester.enterText(target, buffer.toString());
      await tester.pump();
      expect(tester.widget<EditableText>(target).focusNode.hasFocus, isTrue,
          reason: 'focus conservé frappe $i');
    }

    expect(rootChrome, baseChrome, reason: 'chrome racine non reconstruit (SM-1)');
    expect(builds['deep'], baseDeep + total, reason: 'seul le champ cible');
    expect(builds['sibling'], baseSibling, reason: 'voisin non reconstruit');
    expect(c.valueOf('deep'), buffer.toString());
    expect(tester.widget<EditableText>(target).controller.selection.baseOffset,
        total, reason: 'curseur en fin');
  });
}
