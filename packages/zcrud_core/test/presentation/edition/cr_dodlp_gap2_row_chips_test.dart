// CR-DODLP-GAP2 — « select en mode chips ».
//
// Verdict mesuré AVANT toute écriture : le mono-choix en puces existait déjà
// (`EditionFieldType.rowChips`), et c'est exactement ce que le legacy DODLP
// demande (`s2choiceType: S2ChoiceType.chips` sur `gradeMillitaire`/`gradeOTR` :
// mono, options statiques, `required`). Aucun mode d'affichage n'a donc été
// ajouté à `ZSelectConfig` — un canal de plus aurait dupliqué ce widget.
//
// Deux écarts empêchaient la substitution d'être une vraie équivalence :
//   C1/C2  choix DYNAMIQUES — `rowChips` ne lisait que `field.choices` ;
//   C3/C4  MULTI            — la forme « toutes les options visibles, chacune
//                             bascule » (parité `FormBuilderFilterChips`)
//                             n'existait nulle part (`FilterChip` absent du
//                             paquet avant ce lot).
//   C5/C6  AD-13            — l'état sélectionné n'est pas porté par la seule
//                             couleur, et la cible reste ≥ 48 dp.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'AAA'),
  ZFieldChoice(value: 'b', label: 'BBB'),
  ZFieldChoice(value: 'c', label: 'CCC'),
];

Widget _host(ZFormController c, List<ZFieldSpec> fields) => MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: c, fields: fields),
      ),
    );

void main() {
  // ── C1/C2 — choix dynamiques, LES DEUX branches ───────────────────────────

  testWidgets(
      'C1 — sans `ZSelectConfig`, `rowChips` rend EXACTEMENT `field.choices` '
      '(rétro-compat stricte)', (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{'g': 'a'},
      visibleFields: const <String>['g'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
          name: 'g',
          type: EditionFieldType.rowChips,
          label: 'Grade',
          choices: _choices),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('AAA'), findsOneWidget);
  });

  testWidgets(
      'C2 — avec `choicesFromKey`, `rowChips` rend les choix DYNAMIQUES et '
      'les suit quand la tranche source change', (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{
        'src': <ZFieldChoice>[ZFieldChoice(value: 'z', label: 'ZZZ')],
        'g': null,
      },
      visibleFields: const <String>['g'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
        name: 'g',
        type: EditionFieldType.rowChips,
        label: 'Grade',
        choices: _choices,
        config: ZSelectConfig(choicesFromKey: 'src'),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('ZZZ'), findsOneWidget);
    expect(find.text('AAA'), findsNothing,
        reason: 'la source dynamique REMPLACE les choix statiques');

    // Le canal est VIVANT : un changement de la tranche source recompose.
    c.setValue('src',
        const <ZFieldChoice>[ZFieldChoice(value: 'y', label: 'YYY')]);
    await tester.pumpAndSettle();
    expect(find.text('YYY'), findsOneWidget);
    expect(find.text('ZZZ'), findsNothing);
  });

  // ── C3/C4 — multi-sélection ───────────────────────────────────────────────

  testWidgets(
      'C3 — `multiple: true` rend un FilterChip par option et écrit une LISTE',
      (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{'ops': <Object?>[]},
      visibleFields: const <String>['ops'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
        name: 'ops',
        type: EditionFieldType.rowChips,
        label: 'Opérations',
        multiple: true,
        choices: _choices,
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNWidgets(3));
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('AAA'));
    await tester.pumpAndSettle();
    expect(c.valueOf('ops'), <Object?>['a']);

    // Deuxième coche : la précédente est CONSERVÉE (le piège d'un mono déguisé).
    await tester.tap(find.text('CCC'));
    await tester.pumpAndSettle();
    expect(c.valueOf('ops'), <Object?>['a', 'c']);

    // Décoche : retrait ciblé, la liste reste une liste.
    await tester.tap(find.text('AAA'));
    await tester.pumpAndSettle();
    expect(c.valueOf('ops'), <Object?>['c']);
  });

  testWidgets('C4 — `multiple: false` (défaut) reste MONO : le second choix '
      'remplace le premier', (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{'g': null},
      visibleFields: const <String>['g'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
          name: 'g',
          type: EditionFieldType.rowChips,
          label: 'Grade',
          choices: _choices),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AAA'));
    await tester.pumpAndSettle();
    expect(c.valueOf('g'), 'a');
    await tester.tap(find.text('BBB'));
    await tester.pumpAndSettle();
    expect(c.valueOf('g'), 'b', reason: 'mono : jamais une liste');
  });

  // ── C5/C6 — AD-13 ─────────────────────────────────────────────────────────

  testWidgets(
      'C5 — AD-13 : l\'état sélectionné est porté par la SÉMANTIQUE, pas par '
      'la seule couleur (mono ET multi)', (tester) async {
    _bigView(tester);
    final handle = tester.ensureSemantics();
    final c = ZFormController(
      initialValues: const <String, Object?>{
        'g': 'a',
        'ops': <Object?>['b'],
      },
      visibleFields: const <String>['g', 'ops'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
          name: 'g',
          type: EditionFieldType.rowChips,
          label: 'Grade',
          choices: <ZFieldChoice>[
            ZFieldChoice(value: 'a', label: 'MONO-ON'),
            ZFieldChoice(value: 'b', label: 'MONO-OFF'),
          ]),
      ZFieldSpec(
          name: 'ops',
          type: EditionFieldType.rowChips,
          label: 'Ops',
          multiple: true,
          choices: <ZFieldChoice>[
            ZFieldChoice(value: 'a', label: 'MULTI-OFF'),
            ZFieldChoice(value: 'b', label: 'MULTI-ON'),
          ]),
    ]));
    await tester.pumpAndSettle();

    Tristate selectedOf(String text) => tester
        .getSemantics(find.text(text))
        .flagsCollection
        .isSelected;

    // Les quatre cas : les deux familles, les deux états. Une garde posée sur
    // une seule branche laisserait passer « toujours sélectionné ».
    expect(selectedOf('MONO-ON'), Tristate.isTrue);
    expect(selectedOf('MONO-OFF'), Tristate.isFalse);
    expect(selectedOf('MULTI-ON'), Tristate.isTrue);
    expect(selectedOf('MULTI-OFF'), Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('C6 — AD-13 : cible ≥ 48 dp, hauteur INTRINSÈQUE de la puce',
      (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{'ops': <Object?>['a']},
      visibleFields: const <String>['ops'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
          name: 'ops',
          type: EditionFieldType.rowChips,
          label: 'Ops',
          multiple: true,
          choices: _choices),
    ]));
    await tester.pumpAndSettle();

    for (final t in <String>['AAA', 'BBB', 'CCC']) {
      final box = tester.renderObject<RenderBox>(
          find.ancestor(of: find.text(t), matching: find.byType(FilterChip)));
      // La contrainte de hauteur reçue est NON BORNÉE : la hauteur mesurée est
      // donc celle que la puce se donne, jamais une hauteur imposée par un
      // parent complaisant (c'est ce qui rend la mesure signifiante).
      expect(box.constraints.hasBoundedHeight, isFalse);
      expect(box.size.height, greaterThanOrEqualTo(48.0));
    }
  });

  // ── C7 — lecture seule ────────────────────────────────────────────────────

  testWidgets('C7 — `readOnly` : une puce multi n\'est pas basculable',
      (tester) async {
    _bigView(tester);
    final c = ZFormController(
      initialValues: const <String, Object?>{'ops': <Object?>['a']},
      visibleFields: const <String>['ops'],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, const <ZFieldSpec>[
      ZFieldSpec(
        name: 'ops',
        type: EditionFieldType.rowChips,
        label: 'Ops',
        multiple: true,
        readOnly: true,
        choices: _choices,
      ),
    ]));
    await tester.pumpAndSettle();
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.onSelected, isNull);
    }
    await tester.tap(find.text('BBB'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(c.valueOf('ops'), <Object?>['a']);
  });
}
