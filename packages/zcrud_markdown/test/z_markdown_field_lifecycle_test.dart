// Tests de cycle de vie (AC3, anti-fuite AI-E5-4) et RTL/a11y (AC6) de
// `ZMarkdownField` (E6-1).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

List<Map<String, dynamic>> _delta(String text) => <Map<String, dynamic>>[
      <String, dynamic>{'insert': '$text\n'},
    ];

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

QuillController _quillOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

/// Fenêtre de test interne du champ (compteur d'encodages + abonnement actif).
ZMarkdownFieldDebug _debugOf(WidgetTester tester) =>
    tester.state<State<ZMarkdownField>>(find.byType(ZMarkdownField))
        as ZMarkdownFieldDebug;

/// Draine les timers Quill (toolbar `Timer.run(0)` + curseur clignotant) puis
/// démonte l'arbre avant la vérification d'invariants de fin de test.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  const field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

  group('AC3 — controller stable + cycle de vie propre (anti-fuite)', () {
    testWidgets(
        'N cycles montage/démontage : initState==N, aucune fuite, zéro throw',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);

      var inits = 0;
      const cycles = 6;

      for (var i = 0; i < cycles; i++) {
        await tester.pumpWidget(_host(
          ZMarkdownField(
            key: ValueKey('${field.name}-$i'),
            controller: controller,
            field: field,
            onInit: () => inits++,
          ),
        ));

        // Frappe réelle → le listener pousse dans la tranche.
        _quillOf(tester).replaceText(
          0,
          0,
          'x',
          const TextSelection.collapsed(offset: 1),
        );
        // Laisse s'exécuter le Timer.run(0) de la toolbar avant démontage.
        await tester.pump(const Duration(milliseconds: 50));

        // Démonte (dispose du QuillController + retrait du listener).
        await tester.pumpWidget(_host(const SizedBox.shrink()));
        await tester.pump();

        // Après démontage : muter la tranche partagée ne réveille AUCUN
        // listener fantôme sur un controller disposé (fuite AI-E5-4).
        controller.setValue('notes', _delta('post-$i'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      // Un initState par montage : le controller n'est ni partagé ni recréé
      // au rebuild (créé/détruit proprement à chaque cycle).
      expect(inits, cycles);
    });

    testWidgets(
        'LOW-1 — abonnement document.changes RÉELLEMENT annulé au dispose '
        '(preuve directe, pas un proxy)',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(field.name),
          controller: controller,
          field: field,
        ),
      ));

      // Capture la fenêtre de debug du State AVANT démontage (l'objet State
      // persiste en mémoire tant qu'on en tient une référence).
      final dbg = _debugOf(tester);

      // Abonnement ACTIF pendant la vie du widget…
      expect(dbg.debugDocSubscriptionActive, isTrue,
          reason: 'abonnement document.changes absent au montage');

      // …et une frappe RÉELLE l'exerce (le listener tourne → encode).
      _quillOf(tester).replaceText(
        0,
        0,
        'y',
        const TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(dbg.debugDocChangeCount, greaterThan(0),
          reason: 'le listener de mutation n\'a jamais tourné (mal branché)');

      await tester.pump(const Duration(milliseconds: 50));

      // Démonte → dispose() DOIT annuler l'abonnement et le remettre à null.
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pump();

      // PREUVE DIRECTE du retrait : l'abonnement n'est plus actif. Un
      // `removeListener`/`cancel` oublié ferait échouer CET invariant (le
      // proxy « setValue post-démontage sans throw » ne le pouvait pas).
      expect(dbg.debugDocSubscriptionActive, isFalse,
          reason: 'abonnement document.changes NON annulé au dispose (fuite)');
    });
  });

  group('AC6 — RTL + a11y (AD-13)', () {
    testWidgets('rendu sous TextDirection.rtl sans casse', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _delta('مرحبا')},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(field.name),
          controller: controller,
          field: field,
        ),
        dir: TextDirection.rtl,
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(QuillEditor), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('Semantics explicites sur éditeur + toolbar', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      const labelled =
          ZFieldSpec(name: 'notes', type: EditionFieldType.text, label: 'Notes');

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(labelled.name),
          controller: controller,
          field: labelled,
        ),
      ));

      // Éditeur annoncé comme champ de saisie…
      expect(
        find.bySemanticsLabel('Notes'),
        findsWidgets,
      );
      // …et la toolbar porte une étiquette dédiée.
      expect(find.bySemanticsLabel('Notes toolbar'), findsOneWidget);
      handle.dispose();
      await _settle(tester);
    });

    testWidgets('LOW-2 — cible interactive ≥ 48 dp : conteneur ET boutons réels',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(field.name),
          controller: controller,
          field: field,
        ),
      ));

      // (1) Le conteneur toolbar respecte la hauteur de cible minimale.
      final size = tester.getSize(find.byType(QuillSimpleToolbar));
      expect(size.height, greaterThanOrEqualTo(48.0));

      // (2) Preuve DIRECTE (LOW-2) : les surfaces interactives RÉELLES — les
      // `IconButton` que rend `QuillSimpleToolbar` sous `toolbarSize: 48` —
      // occupent chacune au moins 48 dp de haut. On mesure au moins un vrai
      // bouton (pas seulement le conteneur).
      final buttons = find.descendant(
        of: find.byType(QuillSimpleToolbar),
        matching: find.byType(IconButton),
      );
      expect(buttons, findsWidgets,
          reason: 'la toolbar devrait rendre des boutons interactifs');
      final buttonSize = tester.getSize(buttons.first);
      expect(buttonSize.height, greaterThanOrEqualTo(48.0),
          reason: 'un bouton toolbar réel < 48 dp (cible tactile AD-13)');
      await _settle(tester);
    });
  });
}
