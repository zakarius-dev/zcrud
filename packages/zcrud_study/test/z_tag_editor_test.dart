// Tests DISCRIMINANTS ES-8.1 — `ZTagEditor` : adaptateur MINCE composant les
// primitives kernel DÉJÀ TESTÉES (`normalizeTagTitle`/`dedupeByNormalizedTitle`,
// `orphanTagIds`, `remapColorKey`). Ancrage R20/R24 : les assertions portent sur
// les LIGNES PROPRES au widget (GARDE anti-doublon au call-site de création,
// composition purge-sur-émission, identité du controller DÉTENU, call-site de
// confirmation de suggestion), JAMAIS sur la correction des primitives réutilisées
// (re-tester `orphanTagIds([b],[a])=={b}` serait POWERLESS), NI sur un libellé qui
// survivrait à une purge incomplète.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

Widget _host(
  Widget child, {
  ZcrudTheme? theme,
  TextDirection dir = TextDirection.ltr,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(
        theme: theme,
        child: Scaffold(
          body: SizedBox(width: 800, height: 600, child: child),
        ),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // AC2 — GARDE `normalizeTagTitle` au point de CRÉATION (call-site de l'éditeur).
  // ===========================================================================
  group('AC2 — dédup au point de création', () {
    testWidgets('titre normalisé DUPLIQUÉ ⇒ applique l\'existant, PAS de création',
        (tester) async {
      final created = <ZFlashcardTag>[];
      final applied = <ZFlashcardTag>[];
      const existing = ZFlashcardTag(id: 'e1', title: 'Droit Douanier');

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[existing],
        onCreateTag: created.add,
        onApplyExisting: applied.add,
        addSemanticLabel: 'ADD',
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '  droit   douanier ');
      await tester.tap(find.byTooltip('ADD'));
      await tester.pump();

      // R3-I2 : sans la garde (émettre sans normaliser) ⇒ onCreateTag appelé ⇒ rouge.
      expect(created, isEmpty);
      expect(applied, <ZFlashcardTag>[existing]);
    });

    testWidgets('titre normalisé INÉDIT ⇒ onCreateTag exactement 1× (id null, AD-14)',
        (tester) async {
      final created = <ZFlashcardTag>[];
      final applied = <ZFlashcardTag>[];

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[
          ZFlashcardTag(id: 'e1', title: 'Droit Douanier'),
        ],
        onCreateTag: created.add,
        onApplyExisting: applied.add,
        addSemanticLabel: 'ADD',
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Fiscalité');
      await tester.tap(find.byTooltip('ADD'));
      await tester.pump();

      expect(created.length, 1);
      expect(created.single.title, 'Fiscalité');
      expect(created.single.id, isNull); // AD-14 : id attribué par le repository.
      expect(applied, isEmpty);
    });
  });

  // ===========================================================================
  // AC3 — Intégrité référentielle STRUCTURELLE : suppression n'émet AUCUN orphelin.
  // ===========================================================================
  testWidgets('AC3 — la suppression émet des références SANS orphelin (R3-I3)',
      (tester) async {
    const tags = <ZFlashcardTag>[
      ZFlashcardTag(id: 't', title: 'Cible'),
      ZFlashcardTag(id: 'a', title: 'Alpha'),
      ZFlashcardTag(id: 'b', title: 'Beta'),
    ];
    // Cartes référençant `t` (celui qu'on supprime) + d'autres.
    List<List<String>> cards() => <List<String>>[
          <String>['t', 'a'],
          <String>['b', 't'],
          <String>['a'],
        ];

    List<List<String>>? purged;
    final deleted = <ZFlashcardTag>[];

    await tester.pumpWidget(_host(ZTagEditor(
      existingTags: tags,
      cardTagIds: cards,
      onReferencesPurged: (p) => purged = p,
      onDeleteTag: deleted.add,
      deleteTagSemanticLabel: (t) => 'DEL-${t.id}',
    )));
    await tester.pump();

    await tester.tap(find.byTooltip('DEL-t'));
    await tester.pump();

    expect(deleted.single.id, 't');
    expect(purged, isNotNull);

    // Ancrage R24 : ABSENCE d'orphelin dans les références ÉMISES (pas un libellé).
    final existingAfter = <String>['a', 'b'];
    final orphans = orphanTagIds(
      referencedTagIds: purged!.expand((l) => l),
      existingTagIds: existingAfter,
    );
    expect(orphans, isEmpty,
        reason: 'purge court-circuitée ⇒ `t` reste orphelin (R3-I3)');
    // `t` retiré de CHAQUE liste émise.
    for (final list in purged!) {
      expect(list.contains('t'), isFalse);
    }
    // 🔴 LOAD-BEARING (MEDIUM F1 — préservation, classe ORTHOGONALE à l'orphelin) :
    // les non-orphelins (`a`/`b`) DOIVENT SURVIVRE. Sans cette égalité EXACTE, une
    // sur-purge (`for (final l in cards) <String>[]`) — qui vide TOUT — satisferait
    // encore « aucun orphelin » + « pas de `t` » ⇒ perte silencieuse d'associations
    // carte↔tag non détectée. On fige donc le résultat complet, pas seulement
    // l'absence d'orphelin.
    expect(
      purged,
      equals(<List<String>>[
        <String>['a'],
        <String>['b'],
        <String>['a'],
      ]),
    );
  });

  // ===========================================================================
  // AC5 — Controller de saisie DÉTENU (owned/injected) + notifier LOCAL (SM-1).
  // ===========================================================================
  group('AC5 — réactivité Flutter-native', () {
    testWidgets('POSSÉDÉ : identique sous tempête de rebuilds, disposé au démontage',
        (tester) async {
      late StateSetter storm;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) {
          storm = setState;
          return const ZTagEditor(existingTags: <ZFlashcardTag>[]);
        },
      )));
      await tester.pump();

      TextEditingController controllerOf() =>
          tester.widget<TextField>(find.byType(TextField)).controller!;
      final before = controllerOf();

      for (var i = 0; i < 6; i++) {
        storm(() {});
        await tester.pump();
      }
      // R3-I5 : controller créé dans build() ⇒ non-identique ⇒ rouge.
      expect(identical(before, controllerOf()), isTrue);

      await tester.pumpWidget(_host(const SizedBox.shrink()));
      // Un controller disposé throw en debug sur addListener (ChangeNotifier).
      expect(() => before.addListener(() {}), throwsFlutterError);
    });

    testWidgets('INJECTÉ : utilisé tel quel, JAMAIS disposé par l\'éditeur',
        (tester) async {
      final injected = TextEditingController();
      addTearDown(injected.dispose);

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[],
        inputController: injected,
      )));
      await tester.pump();

      expect(
        identical(
          tester.widget<TextField>(find.byType(TextField)).controller,
          injected,
        ),
        isTrue,
      );

      await tester.pumpWidget(_host(const SizedBox.shrink()));
      // Non disposé ⇒ addListener ne throw pas (R3 : un dispose ici rougirait).
      expect(() => injected.addListener(() {}), returnsNormally);
    });

    testWidgets('frappe = zéro rebuild du sous-arbre de l\'éditeur (SM-1, R3-I6)',
        (tester) async {
      // Sonde : la dérivation DÉRIVÉE de ZTagChips n'est appelée QUE lorsque le
      // sous-arbre de l'éditeur se reconstruit. Une frappe qui lifte l'état via
      // `setState` (au lieu du controller/notifier local) rebuild `editor.build`
      // ⇒ ZTagChips rebuild ⇒ la sonde s'incrémente (R3-I6).
      var derivCalls = 0;
      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[ZFlashcardTag(id: 'a', title: 'A')],
        showUsageCount: true,
        referencingCardsCountOf: (t) {
          derivCalls++;
          return 0;
        },
      )));
      await tester.pump();
      final baseline = derivCalls;
      expect(baseline, greaterThanOrEqualTo(1));

      await tester.enterText(find.byType(TextField), 'abcde');
      await tester.pump();

      // Frappe via le controller local : `editor.build` NON réinvoqué ⇒ sonde stable.
      expect(derivCalls, baseline);
    });
  });

  // ===========================================================================
  // AC6 — A11y : labels INJECTÉS, ≥ 48 dp, directionnel, thème injecté.
  // ===========================================================================
  group('AC6 — a11y / FR-26', () {
    testWidgets('bouton d\'ajout : cible ≥ 48 dp + label sémantique INJECTÉ',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const ZTagEditor(
        existingTags: <ZFlashcardTag>[],
        addSemanticLabel: 'ADD-XYZ',
      )));
      await tester.pump();

      expect(find.bySemanticsLabel('ADD-XYZ'), findsOneWidget);
      final box = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(IconButton),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48.0));
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48.0));
      handle.dispose();
    });

    test('verrou-source : aucune Color/hex/EdgeInsets.only(left) codé en dur', () {
      final src =
          File('lib/src/presentation/z_tag_editor.dart').readAsStringSync();
      expect(src.contains('Colors.'), isFalse);
      expect(RegExp(r'0x[0-9a-fA-F]{6,8}').hasMatch(src), isFalse);
      expect(src.contains('EdgeInsets.only(left'), isFalse);
      expect(src.contains('Alignment.centerLeft'), isFalse);
      expect(src.contains('TextAlign.left'), isFalse);
    });
  });

  // ===========================================================================
  // AC7 — Confirmation EXPLICITE d'une suggestion IA, routée par la MÊME garde.
  // ===========================================================================
  group('AC7 — suggestions IA', () {
    testWidgets('AUCUNE matérialisation à l\'affichage (R3-I10)', (tester) async {
      final created = <ZFlashcardTag>[];
      final applied = <ZFlashcardTag>[];
      final confirmed = <ZFlashcardTag>[];

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[],
        suggestions: const <ZSuggestedTag>[ZSuggestedTag(title: 'Idée A')],
        onCreateTag: created.add,
        onApplyExisting: applied.add,
        onSuggestionConfirmed: confirmed.add,
      )));
      await tester.pump();

      // La suggestion est présentée mais JAMAIS auto-appliquée (R3-I10).
      expect(find.text('Idée A'), findsOneWidget);
      expect(created, isEmpty);
      expect(applied, isEmpty);
      expect(confirmed, isEmpty);
    });

    testWidgets('confirmer une suggestion DUPLIQUÉE ⇒ applique l\'existant (R3-I11)',
        (tester) async {
      final created = <ZFlashcardTag>[];
      final applied = <ZFlashcardTag>[];
      const existing = ZFlashcardTag(id: 'e1', title: 'Droit Douanier');

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[existing],
        suggestions: const <ZSuggestedTag>[ZSuggestedTag(title: 'droit douanier')],
        onCreateTag: created.add,
        onApplyExisting: applied.add,
        confirmSuggestionSemanticLabel: (s) => 'CONFIRM',
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('CONFIRM'));
      await tester.pump();

      // R3-I11 : confirmer en court-circuitant la garde ⇒ doublon créé ⇒ rouge.
      expect(created, isEmpty);
      expect(applied, <ZFlashcardTag>[existing]);
      // Confirmée ⇒ retirée de la zone de suggestions.
      expect(find.text('droit douanier'), findsNothing);
    });

    testWidgets('confirmer une suggestion INÉDITE ⇒ onSuggestionConfirmed 1×',
        (tester) async {
      final confirmed = <ZFlashcardTag>[];
      final created = <ZFlashcardTag>[];

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[],
        suggestions: const <ZSuggestedTag>[ZSuggestedTag(title: 'Nouveau')],
        onSuggestionConfirmed: confirmed.add,
        onCreateTag: created.add,
        confirmSuggestionSemanticLabel: (s) => 'CONFIRM',
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('CONFIRM'));
      await tester.pump();

      expect(confirmed.length, 1);
      expect(confirmed.single.title, 'Nouveau');
      expect(confirmed.single.id, isNull); // AD-14.
      expect(created, isEmpty); // routé par onSuggestionConfirmed, pas onCreateTag.
    });

    testWidgets('rejeter une suggestion ⇒ rien émis, suggestion retirée',
        (tester) async {
      final created = <ZFlashcardTag>[];
      final applied = <ZFlashcardTag>[];
      final rejected = <ZSuggestedTag>[];
      const s = ZSuggestedTag(title: 'À rejeter');

      await tester.pumpWidget(_host(ZTagEditor(
        existingTags: const <ZFlashcardTag>[],
        suggestions: const <ZSuggestedTag>[s],
        onCreateTag: created.add,
        onApplyExisting: applied.add,
        onSuggestionRejected: rejected.add,
        rejectSuggestionSemanticLabel: (x) => 'REJECT',
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('REJECT'));
      await tester.pump();

      expect(rejected, <ZSuggestedTag>[s]);
      expect(created, isEmpty);
      expect(applied, isEmpty);
      expect(find.text('À rejeter'), findsNothing);
    });
  });
}
