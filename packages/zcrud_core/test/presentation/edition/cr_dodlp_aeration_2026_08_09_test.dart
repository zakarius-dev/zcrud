// CR-DODLP-AERATION (2026-08-09) — « aération réelle PARTOUT, modèle DODLP ».
//
// Le lot précédent (CR-DODLP-DEFAULTS) avait porté le défaut d'aération à 12 dp,
// mais ce défaut était **presque inerte** : l'espacement ne vivait que dans
// `_membersLayout` (voie GROUPÉE, hors grille) et n'était appliqué qu'aux types
// « blocs ». La voie PLATE (`_buildFlat`) — le cas courant — n'insérait AUCUN
// espace, et les types compacts (ceux que DODLP aère réellement) n'en recevaient
// jamais.
//
// Mesure à la SOURCE DODLP (lecture seule, `dodlp-otr`) :
// - `models.dart:722` `withSpaceer` ⇒ `{text, float, number, timestamp, time,
//   dateTime, phoneNumber}` (types de SAISIE) ;
// - `edition_screen.dart:4192-4210` ⇒ `<Widget>[SizedBox(height: 8)] + fields…`
//   : le `8` est un espaceur de TÊTE de formulaire, **pas** un écart entre deux
//   champs ; le seul écart inter-champ réel est le `SizedBox(height: 12)` posé
//   après un champ `withSpaceer` (et seulement hors `readOnly`).
// ⇒ La métrique DODLP inter-champ est **12**, unique. D'où : écart UNIFORME de
//   12 dp entre deux champs consécutifs, sur les DEUX voies de rendu.
//
// Ces gardes couvrent : la voie plate, l'uniformité (types compacts inclus),
// l'échappatoire `interFieldGap: 0`, l'absence d'espace autour des en-têtes et
// après le dernier champ, la neutralité en grille, la préservation du FOCUS sous
// aération active, et l'invariance SM-1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(growable: false),
    );

/// Écart vertical RÉEL entre le bas du champ [a] et le haut du champ [b].
/// Mesuré sur `ValueKey(name)`, qui reste collée au champ (le `Padding`
/// d'aération est un cran AU-DESSUS) : la valeur retournée est donc un vrai vide
/// entre deux boîtes, jamais un padding interne au champ.
double _gap(WidgetTester tester, String a, String b) {
  final fa = find.byKey(ValueKey<String>(a));
  final fb = find.byKey(ValueKey<String>(b));
  expect(fa, findsOneWidget);
  expect(fb, findsOneWidget);
  return tester.getTopLeft(fb).dy - tester.getBottomLeft(fa).dy;
}

Future<void> _pump(
  WidgetTester tester, {
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  List<ZEditionSection> sections = const <ZEditionSection>[],
  Map<String, ZResponsiveSpan> layout = const <String, ZResponsiveSpan>{},
  double gridGutter = 8,
  double? interFieldGap,
  ZcrudTheme? extension,
  VoidCallback? onStructuralBuild,
  bool shrinkWrap = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: extension == null
            ? const <ThemeExtension<dynamic>>[]
            : <ThemeExtension<dynamic>>[extension],
      ),
      home: Scaffold(
        body: DynamicEdition(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          controller: controller,
          fields: fields,
          sections: sections,
          layout: layout,
          gridGutter: gridGutter,
          interFieldGap: interFieldGap,
          onStructuralBuild: onStructuralBuild,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // ── 1. Voie PLATE : le défaut n'est plus inerte ────────────────────────────
  group('CR-DODLP-AERATION — voie PLATE', () {
    // Ni section repliable ni grille ⇒ `_grouped == false` ⇒ `_buildFlat`.
    const flat = <ZFieldSpec>[
      ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
      ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
      ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
    ];

    testWidgets('DÉFAUT ⇒ 12 dp entre DEUX CHAMPS COMPACTS consécutifs',
        (tester) async {
      // 🔴 C'est LE défaut corrigé : avant ce lot, `_buildFlat` n'insérait aucun
      // espace, et `zFieldGapAfter(text)` valait 0 même dans la voie groupée.
      final c = _controller(<String, Object?>{'a': '1', 'b': '2', 'c': '3'});
      addTearDown(c.dispose);
      await _pump(tester, controller: c, fields: flat);
      expect(zFieldGapReference, 12);
      expect(_gap(tester, 'a', 'b'), zFieldGapReference);
      expect(_gap(tester, 'b', 'c'), zFieldGapReference);
    });

    testWidgets('le jeton de thème pilote la voie plate', (tester) async {
      final c = _controller(<String, Object?>{'a': '1', 'b': '2', 'c': '3'});
      addTearDown(c.dispose);
      await _pump(
        tester,
        controller: c,
        fields: flat,
        extension: const ZcrudTheme(fieldGap: 30),
      );
      expect(_gap(tester, 'a', 'b'), 30);
    });

    testWidgets('`interFieldGap: 0` ⇒ AUCUN espace, même face à un jeton',
        (tester) async {
      // Échappatoire promise aux hôtes : le rendu d'avant, à l'identique.
      final c = _controller(<String, Object?>{'a': '1', 'b': '2', 'c': '3'});
      addTearDown(c.dispose);
      await _pump(
        tester,
        controller: c,
        fields: flat,
        interFieldGap: 0,
        extension: const ZcrudTheme(fieldGap: 30),
      );
      expect(_gap(tester, 'a', 'b'), 0);
      expect(_gap(tester, 'b', 'c'), 0);
    });

    testWidgets('AUCUN espace terminal après le DERNIER champ', (tester) async {
      // 🔴 Mesurer `getBottomLeft(ValueKey('c'))` NE SUFFIT PAS : la boîte du
      // champ exclut son propre écart (l'inset vit un cran au-dessus), donc un
      // espace terminal y resterait INVISIBLE — garde vacante (constaté sous
      // l'injection R3 « écart ajouté après le dernier champ »). On mesure donc
      // la HAUTEUR TOTALE du `ListView` en `shrinkWrap` : elle contient, elle,
      // tout espace terminal. 3 champs ⇒ exactement DEUX écarts (24), jamais
      // trois (36).
      double totalHeight() =>
          tester.getSize(find.byType(ListView).first).height;

      final c1 = _controller(<String, Object?>{'a': '1', 'b': '2', 'c': '3'});
      addTearDown(c1.dispose);
      await _pump(
        tester,
        controller: c1,
        fields: flat,
        interFieldGap: 0,
        shrinkWrap: true,
      );
      final without = totalHeight();

      final c2 = _controller(<String, Object?>{'a': '1', 'b': '2', 'c': '3'});
      addTearDown(c2.dispose);
      await _pump(tester, controller: c2, fields: flat, shrinkWrap: true);
      final with_ = totalHeight();

      expect(with_ - without, 2 * zFieldGapReference,
          reason: '3 champs ⇒ 2 écarts, jamais 3 (rien après le dernier)');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('a'))).dy,
        isNot(0),
        reason: 'la mesure porte bien sur un contenu réellement monté',
      );
    });

    testWidgets('AUCUN espace ajouté autour d\'un EN-TÊTE de section',
        (tester) async {
      // L'en-tête porte déjà 16 dp de tête / 8 dp de pied ; l'écart ne doit ni
      // s'y ajouter avant (après le champ précédent) ni après.
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
        ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
      ];
      const sections = <ZEditionSection>[
        // NON repliable ⇒ la voie reste PLATE (`_grouped` faux).
        ZEditionSection(title: 'S', fields: <String>['b']),
      ];
      final c1 = _controller(<String, Object?>{'a': '1', 'b': '2'});
      addTearDown(c1.dispose);
      await _pump(
        tester,
        controller: c1,
        fields: fields,
        sections: sections,
        interFieldGap: 0,
      );
      final without = _gap(tester, 'a', 'b');

      final c2 = _controller(<String, Object?>{'a': '1', 'b': '2'});
      addTearDown(c2.dispose);
      await _pump(tester, controller: c2, fields: fields, sections: sections);
      final with_ = _gap(tester, 'a', 'b');

      expect(find.text('S'), findsOneWidget, reason: 'en-tête bien monté');
      expect(with_, without,
          reason: 'un en-tête s\'intercale ⇒ aucun écart ajouté');
      expect(without, greaterThan(0), reason: 'la mesure n\'est pas vide');
    });
  });

  // ── 2. Voie GROUPÉE : uniformité (les compacts aussi) ─────────────────────
  group('CR-DODLP-AERATION — voie GROUPÉE, écart UNIFORME', () {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
      ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
    ];
    const sections = <ZEditionSection>[
      ZEditionSection(
        title: 'S',
        fields: <String>['a', 'b'],
        collapsible: true,
      ),
    ];

    testWidgets(
        'deux champs COMPACTS reçoivent l\'écart (la table « blocs » ne '
        'gouverne plus)', (tester) async {
      // 🔴 Avant ce lot : `zFieldGapAfter(text, base: 12) == 0` ⇒ écart NUL ici.
      // La table type-dépendante existe toujours (contrat public inchangé) mais
      // `DynamicEdition` ne la consulte plus.
      expect(zFieldGapAfter(EditionFieldType.text, base: 12), 0,
          reason: 'la fonction publique garde EXACTEMENT son contrat');
      final c = _controller(<String, Object?>{'a': '1', 'b': '2'});
      addTearDown(c.dispose);
      await _pump(tester, controller: c, fields: fields, sections: sections);
      expect(_gap(tester, 'a', 'b'), zFieldGapReference);
    });

    testWidgets('`interFieldGap: 0` ⇒ aucun espace en voie groupée non plus',
        (tester) async {
      final c = _controller(<String, Object?>{'a': '1', 'b': '2'});
      addTearDown(c.dispose);
      await _pump(
        tester,
        controller: c,
        fields: fields,
        sections: sections,
        interFieldGap: 0,
        extension: const ZcrudTheme(fieldGap: 30),
      );
      expect(_gap(tester, 'a', 'b'), 0);
    });
  });

  // ── 3. Voie GRILLE : rien ne s'additionne au gutter ────────────────────────
  group('CR-DODLP-AERATION — voie GRILLE', () {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
      ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
    ];
    const layout = <String, ZResponsiveSpan>{
      'a': ZResponsiveSpan.all(12),
      'b': ZResponsiveSpan.all(12),
    };

    testWidgets('l\'écart inter-rangées reste le gutter SEUL', (tester) async {
      // Spans pleine largeur ⇒ une rangée par champ ⇒ l'écart mesuré est
      // exactement `runGutter` (repli sur `gridGutter`). Si l'aération fuyait
      // dans la grille, on lirait `gutter + 12`.
      final c1 = _controller(<String, Object?>{'a': '1', 'b': '2'});
      addTearDown(c1.dispose);
      await _pump(
        tester,
        controller: c1,
        fields: fields,
        layout: layout,
        gridGutter: 20,
      );
      expect(_gap(tester, 'a', 'b'), 20);

      // Et l'écart demandé explicitement n'y change rien non plus.
      final c2 = _controller(<String, Object?>{'a': '1', 'b': '2'});
      addTearDown(c2.dispose);
      await _pump(
        tester,
        controller: c2,
        fields: fields,
        layout: layout,
        gridGutter: 20,
        interFieldGap: 40,
      );
      expect(_gap(tester, 'a', 'b'), 20,
          reason: 'la grille reste gouvernée par son SEUL gutter');
    });
  });

  // ── 4. FOCUS préservé SOUS AÉRATION ACTIVE (AC6 / AD-2 / SM-1) ────────────
  testWidgets(
      'CR-DODLP-AERATION — voie plate : un conditionnel qui s\'insère AVANT un '
      'champ focalisé ne lui coûte ni State, ni focus, ni caret — AVEC '
      'l\'aération active', (tester) async {
    // 🔴 Le risque exact que ce test verrouille : l'aération aurait pu être
    // rendue par une LIGNE d'espacement à part dans le `ListView.builder`. Une
    // ligne non keyée dans un sliver PARESSEUX est réconciliée par POSITION et
    // double `itemCount` : l'insertion d'un conditionnel décale alors les
    // `Element` et détruit le `State` du champ focalisé. La forme retenue
    // (`Padding` toujours émis, keyé `field:<name>` à la racine de l'item)
    // laisse `itemCount` et l'indexation strictement inchangés.
    final fieldInits = <String, int>{};
    final controller = ZFormController(
      initialValues: const <String, Object?>{
        'trig': '',
        'dependent': '',
        'target': '',
      },
      visibleFields: const <String>['trig', 'dependent', 'target'],
    );
    addTearDown(controller.dispose);

    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'trig', type: EditionFieldType.text, label: 'Trig'),
      ZFieldSpec(
        name: 'dependent',
        type: EditionFieldType.text,
        label: 'Dependent',
        condition: ZCondition.truthy('trig'),
      ),
      ZFieldSpec(name: 'target', type: EditionFieldType.text, label: 'Target'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            // Aucune section repliable, aucune grille ⇒ voie PLATE.
            // `interFieldGap` non fourni ⇒ AÉRATION ACTIVE (12 dp par défaut).
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onInit: () =>
                  fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // L'aération est bien ACTIVE pendant ce scénario (sinon la garde serait
    // vacante : elle prouverait la préservation du focus SANS aération).
    expect(_gap(tester, 'trig', 'target'), zFieldGapReference);

    expect(controller.visibleFields.value, <String>['trig', 'target']);
    expect(fieldInits['target'], 1);

    final targetEditable = find.descendant(
      of: find.byKey(const ValueKey<String>('target')),
      matching: find.byType(EditableText),
    );
    TextEditingController ctrl() =>
        tester.widget<EditableText>(targetEditable).controller;
    FocusNode focus() => tester.widget<EditableText>(targetEditable).focusNode;

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
    expect(ctrl().selection.baseOffset, 3);

    // `dependent` s'INSÈRE à l'index 1, AVANT `target` : tous les index en aval
    // sont décalés.
    controller.setValue('trig', 'x');
    await tester.pumpAndSettle();
    expect(
      controller.visibleFields.value,
      <String>['trig', 'dependent', 'target'],
    );

    expect(fieldInits['target'], 1,
        reason: 'State RÉUTILISÉ malgré le décalage d\'index');
    expect(focus().hasFocus, isTrue, reason: 'focus PRÉSERVÉ');
    expect(ctrl().text, 'ABCDEF');
    expect(ctrl().selection.baseOffset, 3, reason: 'caret PRÉSERVÉ');
    // L'aération est toujours là après le décalage.
    expect(_gap(tester, 'dependent', 'target'), zFieldGapReference);

    // …et au RETRAIT du conditionnel (index qui re-décalent en sens inverse,
    // et `dependent` était le voisin porteur d'un écart).
    controller.setValue('trig', '');
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['trig', 'target']);
    expect(fieldInits['target'], 1, reason: 'State toujours réutilisé');
  });

  // ── 4bis. Le champ dont l'écart BASCULE (dernier ⇄ non-dernier) ───────────
  testWidgets(
      'CR-DODLP-AERATION — un champ dont l\'écart passe de 0 à 12 (il cesse '
      'd\'être le dernier) garde son State, son focus et son caret',
      (tester) async {
    // 🔴 Scénario que seule cette garde atteint : `a` est le DERNIER champ tant
    // que `b` est masqué ⇒ écart `0` ; dès que `b` apparaît, `a` prend l'écart
    // `12`. Si le `Padding` d'aération n'était émis QUE lorsque l'écart est non
    // nul, la FORME du sous-arbre de `a` (et la clé de son item) changerait à ce
    // basculement ⇒ `Element` recréé ⇒ focus et caret perdus PENDANT LA FRAPPE.
    // D'où : `Padding` TOUJOURS émis, seule sa valeur varie.
    final fieldInits = <String, int>{};
    final controller = ZFormController(
      initialValues: const <String, Object?>{'a': '', 'b': ''},
      visibleFields: const <String>['a', 'b'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
              ZFieldSpec(
                name: 'b',
                type: EditionFieldType.text,
                label: 'B',
                condition: ZCondition.truthy('a'),
              ),
            ],
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onInit: () =>
                  fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['a']);
    expect(fieldInits['a'], 1);

    final editable = find.descendant(
      of: find.byKey(const ValueKey<String>('a')),
      matching: find.byType(EditableText),
    );
    TextEditingController ctrl() =>
        tester.widget<EditableText>(editable).controller;
    FocusNode focus() => tester.widget<EditableText>(editable).focusNode;

    await tester.tap(editable);
    await tester.pump();
    expect(focus().hasFocus, isTrue);

    // Une frappe rend `b` visible ⇒ l'écart de `a` bascule 0 → 12.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['a', 'b']);
    expect(_gap(tester, 'a', 'b'), zFieldGapReference,
        reason: 'l\'écart a bien BASCULÉ (la garde n\'est pas vacante)');
    expect(fieldInits['a'], 1, reason: 'State de `a` RÉUTILISÉ au basculement');
    expect(focus().hasFocus, isTrue, reason: 'focus PRÉSERVÉ au basculement');
    expect(ctrl().text, 'x');
    expect(ctrl().selection.baseOffset, 1, reason: 'caret PRÉSERVÉ');
  });

  // ── 5. SM-1 : l'aération ne reconstruit rien de plus ──────────────────────
  testWidgets(
      'CR-DODLP-AERATION — SM-1 : taper 100 caractères ne déclenche AUCUN '
      'rebuild structurel, aération active', (tester) async {
    var structural = 0;
    final controller = _controller(<String, Object?>{'a': '', 'b': ''});
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller: controller,
      fields: const <ZFieldSpec>[
        ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
        ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
      ],
      onStructuralBuild: () => structural++,
    );
    expect(_gap(tester, 'a', 'b'), zFieldGapReference,
        reason: 'aération réellement active pendant la mesure');
    final baseline = structural;

    final editable = find.descendant(
      of: find.byKey(const ValueKey<String>('a')),
      matching: find.byType(EditableText),
    );
    await tester.tap(editable);
    await tester.pump();
    final buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write('x');
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: buffer.toString(),
          selection: TextSelection.collapsed(offset: buffer.length),
        ),
      );
      await tester.pump();
    }
    expect(structural, baseline,
        reason: '100 frappes ⇒ zéro rebuild de niveau formulaire');
  });
}
