// Tests widget de `ZMarkdownField` (E6-1) — couvre AC1–AC5, AC9, AC10.
//
// STRATÉGIE : les frappes utilisateur sont simulées via le `QuillController`
// RÉEL rendu par le widget (`QuillEditor.controller` / `.focusNode` sont des
// membres PUBLICS de `flutter_quill`) — `controller.replaceText(...)` emprunte
// EXACTEMENT la voie de frappe interne (mutation de document → notifyListeners →
// listener du widget → `ZFormController.setValue`). Aucun type Quill n'est
// exposé par `ZMarkdownField` : les tests atteignent le controller par le widget
// Quill que le champ REND (légitime dans le package qui dépend de Quill).
//
// TEARDOWN : chaque test rendant un `QuillEditor` démonte l'arbre en fin de
// corps (`_settle`) pour annuler le Timer de clignotement du curseur Quill AVANT
// la vérification d'invariants du binding (sinon « A Timer is still pending »).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Delta JSON neutre d'un texte simple (ce que `ZMarkdownField` stocke/lit).
List<Map<String, dynamic>> _delta(String text) => <Map<String, dynamic>>[
      <String, dynamic>{'insert': '$text\n'},
    ];

/// Monte [child] avec les localisations Material (le champ ajoute lui-même le
/// délégué Quill via `Localizations.override`).
Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

/// Draine les timers Quill puis démonte l'arbre avant la vérification
/// d'invariants de fin de test :
/// - la toolbar (`QuillToolbarArrowIndicatedButtonList`) planifie un
///   `Timer.run(0)` en `initState` (détection de dépassement de scroll) ; on
///   pompe une tranche pour le laisser s'exécuter ;
/// - le `QuillEditor` focalisé maintient un `Timer.periodic` de clignotement du
///   curseur → annulé au dispose de l'arbre.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Le `QuillController` réel rendu par le champ (via le widget `QuillEditor`),
/// éventuellement scellé au sous-arbre du champ [ofKey] (formulaire multi-champs).
QuillController _quillOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(QuillEditor)
      : find.descendant(
          of: find.byKey(ofKey),
          matching: find.byType(QuillEditor),
        );
  return tester.widget<QuillEditor>(finder).controller;
}

FocusNode _focusOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(QuillEditor)
      : find.descendant(
          of: find.byKey(ofKey),
          matching: find.byType(QuillEditor),
        );
  return tester.widget<QuillEditor>(finder).focusNode;
}

/// Fenêtre de test interne du champ (compteur d'encodages + abonnement actif).
ZMarkdownFieldDebug _debugOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(ZMarkdownField)
      : find.byKey(ofKey);
  return tester.state<State<ZMarkdownField>>(finder) as ZMarkdownFieldDebug;
}

void main() {
  const fieldA = ZFieldSpec(name: 'notes', type: EditionFieldType.text);
  const fieldB = ZFieldSpec(name: 'autre', type: EditionFieldType.text);

  group('AC1 — édition → tranche neutre', () {
    testWidgets('une frappe met à jour valueOf(name) en Delta JSON neutre',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));

      _quillOf(tester).replaceText(
        0,
        0,
        'Bonjour',
        const TextSelection.collapsed(offset: 7),
      );
      await tester.pump();

      final value = controller.valueOf('notes');
      expect(value, isA<List<Map<String, dynamic>>>());
      expect(value, _delta('Bonjour'));

      await _settle(tester);
    });
  });

  group('AC2 / SM-1 — rebuild ciblé, controller stable, focus/sélection', () {
    testWidgets(
        'taper N caractères ne reconstruit QUE ce champ (voisin + global figés), '
        'controller jamais recréé, focus + curseur au milieu préservés',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _delta('AC')},
      );
      addTearDown(controller.dispose);

      var initA = 0;
      var buildA = 0;
      var buildB = 0;
      var globalBuilds = 0;

      await tester.pumpWidget(_host(
        Column(
          children: <Widget>[
            // Compteur GLOBAL : rebâti seulement si le controller notifie
            // globalement (ce qui ne doit JAMAIS arriver sur setValue — AD-2).
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                globalBuilds++;
                return const SizedBox.shrink();
              },
            ),
            ZMarkdownField(
              key: ValueKey(fieldA.name),
              controller: controller,
              field: fieldA,
              onInit: () => initA++,
              onBuild: () => buildA++,
            ),
            ZMarkdownField(
              key: ValueKey(fieldB.name),
              controller: controller,
              field: fieldB,
              onBuild: () => buildB++,
            ),
          ],
        ),
      ));

      final quill = _quillOf(tester, ofKey: const ValueKey('notes'));
      final focus = _focusOf(tester, ofKey: const ValueKey('notes'));
      focus.requestFocus();
      await tester.pump();

      // Place le curseur AU MILIEU ('AC' → offset 1, entre A et C).
      quill.updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.pump();

      final buildAAfterFocus = buildA;
      final buildBBefore = buildB;
      final globalBefore = globalBuilds;

      // Tape 100 caractères, un par un, AU point d'insertion courant.
      for (var i = 0; i < 100; i++) {
        final at = quill.selection.baseOffset;
        quill.replaceText(
          at,
          0,
          'x',
          TextSelection.collapsed(offset: at + 1),
        );
        await tester.pump();
      }

      // Controller JAMAIS recréé (State stable) — un seul initState.
      expect(initA, 1, reason: 'QuillController/State recréé (AD-2 violé)');
      // Le champ courant s'est bien reconstruit…
      expect(buildA, greaterThan(buildAAfterFocus));
      // …mais le VOISIN, jamais.
      expect(buildB, buildBBefore, reason: 'rebuild du voisin (SM-1 violé)');
      // …et AUCUN rebuild GLOBAL du formulaire.
      expect(globalBuilds, globalBefore,
          reason: 'notifyListeners global sur frappe (AD-2 violé)');
      // Focus conservé pendant toute la frappe.
      expect(focus.hasFocus, isTrue);
      // Curseur cohérent avec l'insertion au milieu (jamais remis à 0).
      expect(quill.selection.baseOffset, 101); // 1 (départ) + 100 frappes
      // Même instance de controller à la fin.
      expect(
        identical(_quillOf(tester, ofKey: const ValueKey('notes')), quill),
        isTrue,
      );

      await _settle(tester);
    });
  });

  group('MED-1 — sélection seule ⇒ AUCUN encodage (efficacité)', () {
    testWidgets(
        'déplacer le curseur / changer la sélection ne déclenche NI encodage '
        'NI setValue ; seule une frappe (changement de contenu) le fait',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _delta('abcdef')},
      );
      addTearDown(controller.dispose);

      var setValueCalls = 0;
      controller.fieldListenable('notes').addListener(() => setValueCalls++);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));

      final quill = _quillOf(tester);
      final dbg = _debugOf(tester);
      _focusOf(tester).requestFocus();
      await tester.pump();

      // Une frappe RÉELLE (changement de contenu) : encode + setValue.
      quill.replaceText(0, 0, 'X', const TextSelection.collapsed(offset: 1));
      await tester.pump();

      final encodesAfterType = dbg.debugDocChangeCount;
      final setValueAfterType = setValueCalls;
      final valueAfterType = controller.valueOf('notes');
      expect(encodesAfterType, greaterThan(0),
          reason: 'une frappe doit déclencher un encodage');
      expect(setValueAfterType, greaterThan(0),
          reason: 'une frappe doit pousser la tranche (SM-1)');

      // 20 déplacements de curseur / sélections PURS (aucun changement de
      // contenu) : le flux `document.changes` NE DOIT PAS émettre.
      for (var offset = 0; offset < 20; offset++) {
        quill.updateSelection(
          TextSelection.collapsed(offset: offset % 7),
          ChangeSource.local,
        );
        await tester.pump();
      }
      // Une sélection étendue (range) : toujours aucun contenu modifié.
      quill.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
        ChangeSource.local,
      );
      await tester.pump();

      // Compteur d'encodage INCHANGÉ, aucun setValue superflu, valeur intacte.
      expect(dbg.debugDocChangeCount, encodesAfterType,
          reason: 'MED-1 : la sélection seule a déclenché un encodage O(doc)');
      expect(setValueCalls, setValueAfterType,
          reason: 'la sélection seule a poussé la tranche (setValue superflu)');
      expect(controller.valueOf('notes'), valueAfterType);

      await _settle(tester);
    });
  });

  group('AC4 — décodage défensif (AD-10)', () {
    Future<void> pumpWithSeed(WidgetTester tester, Object? seed) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': seed},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));
    }

    final corruptSeeds = <String, Object?>{
      'null': null,
      'liste vide': <Object?>[],
      'map vide (type inattendu)': <String, Object?>{},
      'string JSON tronqué': '[{"insert":"oops',
      'string vide': '',
      'string non-JSON': 'pas du tout du json',
      'op non-Map': <Object?>['juste une string'],
      'op sans insert (retain seul)': <Object?>[
        <String, Object?>{'retain': 3},
      ],
      'nombre brut': 42,
    };

    corruptSeeds.forEach((label, seed) {
      testWidgets('$label → éditeur VIDE, aucun throw', (tester) async {
        await pumpWithSeed(tester, seed);
        expect(tester.takeException(), isNull);
        // Document vide = seul le '\n' terminal.
        expect(_quillOf(tester).document.toPlainText(), '\n');
        await _settle(tester);
      });
    });
  });

  group('AC5 — thème injecté (FR-26, zéro couleur en dur)', () {
    testWidgets('la bordure reflète ZcrudScope.theme.fieldBorderColor',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      const custom = Color(0xFF123456);

      await tester.pumpWidget(_host(
        ZcrudScope(
          theme: const ZcrudTheme(fieldBorderColor: custom),
          child: ZMarkdownField(
            key: ValueKey(fieldA.name),
            controller: controller,
            field: fieldA,
          ),
        ),
      ));

      final border = tester
          .widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.byType(QuillEditor),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      expect((border.border! as Border).top.color, custom);

      await _settle(tester);
    });
  });

  group('AC9 — toolbar presets optionnelle', () {
    testWidgets('showToolbar:false → aucune toolbar', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
          showToolbar: false,
        ),
      ));
      expect(find.byType(QuillSimpleToolbar), findsNothing);
      await _settle(tester);
    });

    testWidgets('showToolbar:true → toolbar sur le MÊME controller',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));
      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
      final toolbar =
          tester.widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar));
      expect(identical(toolbar.controller, _quillOf(tester)), isTrue);
      await _settle(tester);
    });
  });

  group('AC10 — sync guardée hors focus', () {
    testWidgets('valeur externe HORS focus → reflétée dans l\'éditeur',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));

      controller.setValue('notes', _delta('Rechargé'));
      await tester.pump();

      expect(_quillOf(tester).document.toPlainText(), 'Rechargé\n');
      await _settle(tester);
    });

    testWidgets(
        'valeur externe PENDANT le focus → JAMAIS ré-injectée (sélection préservée)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _delta('local')},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));

      final quill = _quillOf(tester);
      _focusOf(tester).requestFocus();
      await tester.pump();
      quill.updateSelection(
        const TextSelection.collapsed(offset: 2),
        ChangeSource.local,
      );
      await tester.pump();

      // Reseed EXTERNE pendant l'édition.
      controller.setValue('notes', _delta('ECRASE'));
      await tester.pump();

      // Le document n'a PAS été ré-injecté (priorité à l'édition en cours)…
      expect(quill.document.toPlainText(), 'local\n');
      // …et le curseur est intact (jamais remis à 0).
      expect(quill.selection.baseOffset, 2);

      await _settle(tester);
    });
  });
}
