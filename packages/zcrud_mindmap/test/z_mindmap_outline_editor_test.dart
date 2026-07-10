/// Tests widget de `ZMindmapOutlineEditor` / `ZMindmapOutlineController` (E10-3).
///
/// Couvre AC1..AC6, avec en **invariant central** la preuve anti-bug-lex (AC2) :
/// éditer un nœud PUIS sauvegarder → la forêt émise par `onSave` reflète
/// RÉELLEMENT l'édition (jamais l'arbre d'origine). Idem add/delete/indent/
/// outdent/reorder + cohérence de `level`. Plus : rebuild granulaire / zéro perte
/// de focus (SM-1), a11y ≥ 48 dp, RTL/directionnel, thème injecté, état vide,
/// isolation (aucun gestionnaire d'état).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Forêt mono-racine : Root → { Child1 → Grand1 ; Child2 }.
List<ZMindmapNode> _forest() => ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(
        id: 'r',
        label: 'Root',
        children: <ZMindmapNode>[
          ZMindmapNode(
            id: 'c1',
            label: 'Child1',
            children: <ZMindmapNode>[
              ZMindmapNode(id: 'g1', label: 'Grand1'),
            ],
          ),
          ZMindmapNode(id: 'c2', label: 'Child2'),
        ],
      ),
    ]);

/// Deux racines : Alpha ; Beta.
List<ZMindmapNode> _twoRoots() =>
    ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(id: 'a', label: 'Alpha'),
      ZMindmapNode(id: 'b', label: 'Beta'),
    ]);

/// Enveloppe l'éditeur dans un `MaterialApp`/`Scaffold` (+ scope optionnel). La
/// surface de test est agrandie par [_tw] pour que toutes les lignes de l'outline
/// (label + content + actions, grandes) soient construites — sinon le
/// `ListView.builder` virtualise et les nœuds profonds ne sont pas montés.
Widget _host(
  Widget child, {
  ZcrudTheme? theme,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: ZcrudScope(theme: theme, child: child)),
    ),
  );
}

/// Finder d'un `TextField` par le texte courant de son controller (unicité).
Finder _fieldWithText(String text) => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == text,
    );

/// Parcours : vérifie que chaque enfant a `level == parent.level + 1`.
bool _levelsCoherent(List<ZMindmapNode> roots) {
  bool ok = true;
  void visit(ZMindmapNode n, int expected) {
    if (n.level != expected) ok = false;
    for (final c in n.children) {
      visit(c, n.level + 1);
    }
  }

  for (final r in roots) {
    visit(r, 0);
  }
  return ok;
}

/// `testWidgets` avec une **surface agrandie** (1000×3000) : les lignes de
/// l'outline sont grandes ; sur la surface 800×600 par défaut, le
/// `ListView.builder` virtualiserait les nœuds profonds (non montés → non
/// trouvables). Réinitialise la vue en fin de test.
void _tw(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await body(tester);
  });
}

void main() {
  group('AC1 — outline indenté éditable', () {
    _tw('une ligne par nœud (DFS) via ListView.builder, champs présents',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(roots: _forest())));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);
      // 4 nœuds → au moins 4 champs label peuplés.
      expect(_fieldWithText('Root'), findsOneWidget);
      expect(_fieldWithText('Child1'), findsOneWidget);
      expect(_fieldWithText('Grand1'), findsOneWidget);
      expect(_fieldWithText('Child2'), findsOneWidget);
    });

    _tw('forêt vide → affordance « ajouter une racine », pas de crash',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: const <ZMindmapNode>[],
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Ajouter une racine'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Ajouter une racine'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.length, 1);
      expect(saved!.first.level, 0);
    });
  });

  group('AC2 — LA SAUVEGARDE APPLIQUE RÉELLEMENT LES MODIFICATIONS (bug lex)', () {
    _tw('★ édition de label → save → la forêt émise contient le label édité',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _forest(),
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // (2) taper un NOUVEAU label dans le champ de 'c1'.
      await tester.enterText(_fieldWithText('Child1'), 'ChildEdited');
      await tester.pump();

      // (3) déclencher la sauvegarde.
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      // (4) la forêt reçue contient le label édité — JAMAIS l'ancien.
      expect(saved, isNotNull);
      expect(ZMindmapTreeOps.findNode(saved!, 'c1')!.label, 'ChildEdited');
      expect(ZMindmapTreeOps.findNode(saved!, 'c1')!.label, isNot('Child1'));
      // Les autres nœuds intacts.
      expect(ZMindmapTreeOps.findNode(saved!, 'r')!.label, 'Root');
    });

    _tw('édition de content → save → content réellement appliqué',
        (tester) async {
      List<ZMindmapNode>? saved;
      final controller = ZMindmapOutlineController(initialForest: _forest());
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        controller: controller,
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // Édition « live » de content (source de vérité = forêt du contrôleur).
      controller.editContent('g1', 'Nouveau contenu');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(ZMindmapTreeOps.findNode(saved!, 'g1')!.content, 'Nouveau contenu');
    });

    _tw('addChild via l\'UI → save → l\'enfant existe réellement',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'Root')],
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Ajouter un enfant'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      expect(saved, isNotNull);
      final root = ZMindmapTreeOps.findNode(saved!, 'r')!;
      expect(root.children.length, 1);
      expect(root.children.first.level, 1);
    });

    _tw('addSibling via l\'UI → save → le frère existe au même niveau',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _forest(), // Root → {c1→g1, c2}
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // Rows DFS : [r, c1, g1, c2]. addSibling de c1 (index 1).
      await tester.tap(find.bySemanticsLabel('Ajouter un frère').at(1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      final root = ZMindmapTreeOps.findNode(saved!, 'r')!;
      // c1, c2 + le nouveau frère = 3 enfants ; tous level 1.
      expect(root.children.length, 3);
      expect(root.children.every((c) => c.level == 1), isTrue);
    });

    _tw('delete via l\'UI → save → le nœud a disparu', (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: <ZMindmapNode>[
          ZMindmapNode(
            id: 'r',
            label: 'Root',
            children: <ZMindmapNode>[ZMindmapNode(id: 'c1', label: 'Child1', level: 1)],
          ),
        ],
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // Rows [r, c1] : delete c1 (index 1).
      await tester.tap(find.bySemanticsLabel('Supprimer').at(1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      expect(ZMindmapTreeOps.findNode(saved!, 'c1'), isNull);
      expect(ZMindmapTreeOps.findNode(saved!, 'r')!.children, isEmpty);
    });

    _tw('indent via l\'UI → save → reparentage + level cohérent',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _twoRoots(), // [Alpha, Beta] racines
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // Rows [a, b] : indent b (index 1) → devient enfant de a.
      await tester.tap(find.bySemanticsLabel('Indenter').at(1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      // 1 racine (a) ; b enfant de a au niveau 1.
      expect(saved!.length, 1);
      expect(saved!.first.id, 'a');
      expect(ZMindmapTreeOps.findNode(saved!, 'b')!.level, 1);
      expect(_levelsCoherent(saved!), isTrue);
    });

    _tw('outdent via l\'UI → save → remontée en racine + level cohérent',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: <ZMindmapNode>[
          ZMindmapNode(
            id: 'r',
            label: 'Root',
            children: <ZMindmapNode>[ZMindmapNode(id: 'c1', label: 'Child1', level: 1)],
          ),
        ],
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // Rows [r, c1] : outdent c1 (index 1) → devient racine.
      await tester.tap(find.bySemanticsLabel('Désindenter').at(1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      expect(saved!.length, 2);
      expect(ZMindmapTreeOps.findNode(saved!, 'c1')!.level, 0);
      expect(_levelsCoherent(saved!), isTrue);
    });

    _tw('moveDown / moveUp via l\'UI → save → ordre de fratrie réordonné',
        (tester) async {
      List<ZMindmapNode>? saved;
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _twoRoots(), // [Alpha, Beta]
        onSave: (f) => saved = f,
      )));
      await tester.pump();

      // moveDown Alpha (index 0) → ordre [Beta, Alpha].
      await tester.tap(find.bySemanticsLabel('Descendre').at(0));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pump();

      expect(saved!.map((n) => n.id).toList(), <String>['b', 'a']);
    });

    _tw('cohérence de level après indent PUIS outdent d\'un sous-arbre',
        (tester) async {
      // Contrôleur direct : indent c2 sous c1, puis outdent → forêt cohérente.
      final controller = ZMindmapOutlineController(initialForest: _forest());
      addTearDown(controller.dispose);

      controller.indent('c2'); // c2 devient enfant de c1
      controller.outdent('c2'); // c2 remonte frère de c1
      final saved = controller.forest;

      expect(_levelsCoherent(saved), isTrue);
      // normalizeLevels renvoie identical si déjà cohérent (structural sharing).
      expect(
        identical(ZMindmapTreeOps.normalizeLevels(saved), saved),
        isTrue,
      );
    });
  });

  group('AC3 — réactivité Flutter-native, rebuild granulaire, zéro perte de focus', () {
    _tw('taper plusieurs caractères : focus conservé, controller stable',
        (tester) async {
      final controller = ZMindmapOutlineController(initialForest: _forest());
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(controller: controller)));
      await tester.pump();

      final node = ZMindmapTreeOps.findNode(controller.forest, 'c1')!;
      final before = controller.labelControllerFor(node);

      final field = _fieldWithText('Child1');
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, 'Bonjour');
      await tester.pump();

      // Le TextEditingController de la ligne n'est PAS recréé (identité stable).
      final after = controller.labelControllerFor(node);
      expect(identical(before, after), isTrue);
      expect(after.text, 'Bonjour');

      // La forêt du contrôleur est déjà à jour (source de vérité live).
      expect(ZMindmapTreeOps.findNode(controller.forest, 'c1')!.label, 'Bonjour');

      // Le champ focalisé conserve son focus après la frappe (pas de reset). Le
      // champ affiche désormais 'Bonjour' (le controller stable porte le texte).
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: _fieldWithText('Bonjour'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    });

    _tw('édition de label ne notifie PAS (pas de rebuild global de l\'outline)',
        (tester) async {
      final controller = ZMindmapOutlineController(initialForest: _forest());
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.editLabel('c1', 'X');
      controller.editLabel('c1', 'XY');
      expect(notifications, 0); // édition de texte = zéro notification (SM-1).

      controller.addChild('r'); // mutation structurelle → notifie.
      expect(notifications, 1);
    });
  });

  group('AC4 — a11y (Semantics externalisés, ≥ 48 dp) + RTL/directionnel', () {
    _tw('boutons d\'action portent les labels a11y externalisés',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(roots: _forest())));
      await tester.pump();

      for (final label in <String>[
        'Ajouter un enfant',
        'Ajouter un frère',
        'Supprimer',
        'Indenter',
        'Désindenter',
        'Monter',
        'Descendre',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets);
      }
      expect(find.bySemanticsLabel('Titre'), findsWidgets);
    });

    _tw('libellés surchargeables (localisation via ZMindmapOutlineLabels)',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _forest(),
        labels: const ZMindmapOutlineLabels(delete: 'Remove node'),
      )));
      await tester.pump();
      expect(find.bySemanticsLabel('Remove node'), findsWidgets);
      expect(find.bySemanticsLabel('Supprimer'), findsNothing);
    });

    _tw('cibles interactives ≥ 48 dp', (tester) async {
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(roots: _forest())));
      await tester.pump();

      final size = tester.getSize(find.bySemanticsLabel('Supprimer').first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    _tw('les champs éditables (label/content) sont ≥ 48 dp de haut (MEDIUM-1)',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(roots: _forest())));
      await tester.pump();

      final count = tester.widgetList(find.byType(TextField)).length;
      expect(count, greaterThan(0));
      for (var i = 0; i < count; i++) {
        final size = tester.getSize(find.byType(TextField).at(i));
        expect(size.height, greaterThanOrEqualTo(48),
            reason: 'un champ éditable doit rester une cible ≥ 48 dp (AD-13)');
      }
    });

    _tw('indentation directionnelle dérivée de level (RTL sans crash)',
        (tester) async {
      await tester.pumpWidget(_host(
        ZMindmapOutlineEditor(roots: _forest()),
        direction: TextDirection.rtl,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // La ligne de 'g1' (level 2) porte un padding directionnel start = 2*step.
      final rowFinder = find.byKey(const ValueKey<String>('zmindmap-outline-g1'));
      expect(rowFinder, findsOneWidget);
      final padding = tester.widget<Padding>(
        find.descendant(of: rowFinder, matching: find.byType(Padding)).first,
      );
      final resolved = padding.padding;
      expect(resolved, isA<EdgeInsetsDirectional>());
      expect((resolved as EdgeInsetsDirectional).start, 2 * 24.0);
    });
  });

  group('AC5 — thème injecté consommé (FR-26)', () {
    _tw('la couleur d\'icône dérive du token ZcrudTheme injecté',
        (tester) async {
      const injected = Color(0xFF123456);
      await tester.pumpWidget(_host(
        ZMindmapOutlineEditor(roots: _forest()),
        theme: const ZcrudTheme(labelColor: injected),
      ));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline).first);
      expect(icon.color, injected);
    });
  });

  group('AC6 — isolation architecturale (grep de garde)', () {
    // Résolution robuste au cwd : la garde tourne aussi bien depuis la racine
    // du workspace (`flutter test packages/zcrud_mindmap`) que depuis le package
    // (`flutter test`). Miroir de `_presentationDir()` dans le test de conformité.
    String resolve(String relative) {
      for (final prefix in const <String>['', 'packages/zcrud_mindmap/']) {
        if (File('$prefix$relative').existsSync()) return '$prefix$relative';
      }
      return relative;
    }

    final files = <String>[
      'lib/src/presentation/z_mindmap_outline_controller.dart',
      'lib/src/presentation/z_mindmap_outline_editor.dart',
      'lib/src/presentation/z_mindmap_outline_labels.dart',
    ].map(resolve).toList();

    // Retire les commentaires (`//`, `///`) : le grep de garde vise le CODE, pas
    // la documentation (qui peut légitimement nommer les API interdites).
    String codeOnly(String src) {
      final b = StringBuffer();
      for (final line in src.split('\n')) {
        final i = line.indexOf('//');
        b.writeln(i >= 0 ? line.substring(0, i) : line);
      }
      return b.toString();
    }

    test('aucun gestionnaire d\'état ni API manager (AD-2/AD-15)', () {
      for (final path in files) {
        final src = codeOnly(File(path).readAsStringSync());
        for (final banned in <String>[
          'flutter_riverpod',
          'package:get/',
          'package:provider',
          'WidgetRef',
          'Get.find',
          'Get.put',
          'Provider.of',
        ]) {
          expect(src.contains(banned), isFalse,
              reason: '$path ne doit pas contenir "$banned"');
        }
      }
    });

    test('aucune API non-directionnelle ni couleur codée en dur (AD-13/FR-26)', () {
      for (final path in files) {
        final src = codeOnly(File(path).readAsStringSync());
        for (final banned in <String>[
          'EdgeInsets.only(',
          'Alignment.centerLeft',
          'Alignment.centerRight',
          'Positioned(left',
          'Positioned(right',
          'TextAlign.left',
          'TextAlign.right',
          'Colors.',
          'Color(0x', // MEDIUM-2 : littéral couleur hex interdit (FR-26)
        ]) {
          expect(src.contains(banned), isFalse,
              reason: '$path ne doit pas contenir "$banned"');
        }
      }
    });
  });
}
