// Remédiation des findings LOW du code-review E3-3a (a11y/correction, AD-13/AD-2).
//
//  - L-1 : le déclencheur date/heure n'expose QU'UN seul nœud sémantique
//    (bouton + libellé + valeur) — plus de double annonce du lecteur d'écran.
//  - L-4 : en `readOnly`, chaque radio est réellement DÉSACTIVÉ (sémantique
//    `disabled`), pas un no-op visuellement/sémantiquement actif.
//  - L-3 : un `select`/`relation` reflète un changement de valeur EXTERNE
//    programmatique (le contrôle affiche la valeur courante de la tranche),
//    sans rebuild global (borné par `ZFieldListenableBuilder`, AD-2).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const List<ZFieldChoice> _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Option A'),
  ZFieldChoice(value: 'b', label: 'Option B'),
  ZFieldChoice(value: 'c', label: 'Option C'),
];

ZFormController _controller(List<ZFieldSpec> fields) => ZFormController(
      initialValues: <String, Object?>{for (final f in fields) f.name: null},
      visibleFields: <String>[for (final f in fields) f.name],
    );

Widget _app(ZFormController controller, List<ZFieldSpec> fields) => MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: fields),
      ),
    );

/// Collecte récursivement les `SemanticsData` satisfaisant [test] sous le
/// sous-arbre du formulaire (racine non dépréciée via `getSemantics`).
List<SemanticsData> _collect(
  WidgetTester tester,
  bool Function(SemanticsData) test,
) {
  final root = tester.getSemantics(find.byType(DynamicEdition));
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (test(data)) out.add(data);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return out;
}

void main() {
  // ── L-1 : UN SEUL nœud sémantique bouton sur le déclencheur date ──────────
  testWidgets('L-1 : déclencheur date = un seul nœud sémantique (annonce unique)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final fields = <ZFieldSpec>[
      const ZFieldSpec(
          name: 'dt', type: EditionFieldType.dateTime, label: 'Date'),
    ];
    final controller = _controller(fields);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, fields));
    await tester.pumpAndSettle();

    // Un seul nœud « bouton » portant le libellé du champ (aucune double
    // annonce : la sémantique descendante du bouton Material + Text est exclue).
    final buttons = _collect(
      tester,
      (d) => d.flagsCollection.isButton && d.label.contains('Date'),
    );
    expect(buttons.length, 1,
        reason: 'un unique nœud bouton (pas de Semantics superposé)');
    // Le nœud cohérent porte libellé + valeur (placeholder l10n courant).
    expect(buttons.single.label, 'Date');
    expect(buttons.single.value, isNotEmpty,
        reason: 'la valeur (placeholder/valeur courante) est annoncée');

    handle.dispose();
  });

  // ── L-4 : radio readOnly réellement désactivé (sémantique disabled) ───────
  testWidgets('L-4 : radio en readOnly est DÉSACTIVÉ (pas d\'interaction)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final fields = <ZFieldSpec>[
      const ZFieldSpec(
          name: 'rad',
          type: EditionFieldType.radio,
          label: 'Radio',
          choices: _choices,
          readOnly: true),
    ];
    final controller = _controller(fields);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, fields));
    await tester.pumpAndSettle();

    // Tap sur une option : AUCUN changement (le groupe est inerte car désactivé).
    await tester.tap(find.text('Option A'));
    await tester.pump();
    expect(controller.valueOf('rad'), isNull,
        reason: 'readOnly ⇒ pas de sélection possible');

    // Sémantique DISABLED : les radios exposent un état activable NON activé.
    final radios = _collect(
      tester,
      (d) => d.flagsCollection.isInMutuallyExclusiveGroup,
    );
    expect(radios, isNotEmpty, reason: 'les radios sont présents');
    for (final d in radios) {
      expect(d.flagsCollection.isEnabled, Tristate.isFalse,
          reason: 'readOnly ⇒ radio sémantiquement disabled');
    }

    handle.dispose();
  });

  testWidgets('L-4 : radio NON readOnly reste interactif (contre-preuve)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final fields = <ZFieldSpec>[
      const ZFieldSpec(
          name: 'rad',
          type: EditionFieldType.radio,
          label: 'Radio',
          choices: _choices),
    ];
    final controller = _controller(fields);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, fields));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Option A'));
    await tester.pump();
    expect(controller.valueOf('rad'), 'a',
        reason: 'hors readOnly ⇒ sélection appliquée');

    // Contre-preuve sémantique : les radios sont ACTIVÉS (état enabled).
    final radios = _collect(
      tester,
      (d) => d.flagsCollection.isInMutuallyExclusiveGroup,
    );
    expect(radios, isNotEmpty);
    expect(radios.every((d) => d.flagsCollection.isEnabled == Tristate.isTrue),
        isTrue,
        reason: 'hors readOnly ⇒ radios sémantiquement enabled');

    handle.dispose();
  });

  // ── L-3 : select reflète un changement de valeur EXTERNE programmatique ───
  testWidgets('L-3 : select reflète une valeur externe (programmatique)',
      (tester) async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(
          name: 'sel',
          type: EditionFieldType.select,
          label: 'Choix',
          choices: _choices),
    ];
    final controller = _controller(fields);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, fields));
    await tester.pumpAndSettle();

    // Aucune valeur au départ : l'item sélectionné n'est pas affiché.
    expect(find.text('Option B'), findsNothing);

    // Mutation EXTERNE de la tranche (aucune interaction utilisateur).
    controller.setValue('sel', 'b');
    await tester.pump();

    // Le contrôle AFFICHE désormais la valeur courante de la tranche (L-3).
    expect(find.text('Option B'), findsWidgets,
        reason: 'le dropdown reflète la valeur externe');

    // Non-régression : une valeur externe ultérieure est aussi reflétée.
    controller.setValue('sel', 'c');
    await tester.pump();
    expect(find.text('Option C'), findsWidgets);
  });

  testWidgets('L-3 : la sélection UTILISATEUR du select fonctionne toujours',
      (tester) async {
    final fields = <ZFieldSpec>[
      const ZFieldSpec(
          name: 'sel',
          type: EditionFieldType.select,
          label: 'Choix',
          choices: _choices),
    ];
    final controller = _controller(fields);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, fields));
    await tester.pumpAndSettle();

    // Ouvre le menu et choisit une option.
    await tester.tap(find.byType(DropdownButtonFormField<Object?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option C').last);
    await tester.pumpAndSettle();

    expect(controller.valueOf('sel'), 'c');
    expect(find.text('Option C'), findsWidgets);
  });
}
