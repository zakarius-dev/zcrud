/// Tests ES-7.2 des contrôles user-facing de `ZMindmapView` : zoom piloté/clampé
/// (AC2), mode compact (AC3), plein-écran (AC4), super-racine multi-forêt (AC5),
/// additivité stricte / non-régression E10 (AC6), a11y/thème (AC10).
///
/// Chaque AC load-bearing est accompagné de son **injection** (§ R3) : neutraliser
/// la garde rend le test ROUGE (pouvoir discriminant, R12).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Forêt mono-racine (1 racine) : Root → {Child(content) }.
List<ZMindmapNode> _monoRoot() =>
    ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(
        id: 'r',
        label: 'Root',
        content: 'ROOTCONTENT',
        children: <ZMindmapNode>[
          ZMindmapNode(id: 'c', label: 'Child', content: 'CHILDCONTENT'),
        ],
      ),
    ]);

/// Forêt multi-racine (2 racines) : Alpha ; Beta.
List<ZMindmapNode> _multiRoot() =>
    ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(id: 'a', label: 'Alpha'),
      ZMindmapNode(id: 'b', label: 'Beta'),
    ]);

Widget _host(
  Widget child, {
  ZcrudTheme? theme,
  TextDirection direction = TextDirection.ltr,
}) {
  Widget scoped = SizedBox(width: 800, height: 600, child: child);
  scoped = ZcrudScope(theme: theme, child: scoped);
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: scoped),
    ),
  );
}

void main() {
  // ───────────────────────────── AC2 — ZOOM CLAMPÉ ─────────────────────────
  group('AC2 — zoom user-facing borné + reset', () {
    test(
        'INJ-1 : zoom-in répété est CLAMPÉ à maxScale, zoom-out à minScale, '
        'reset restaure l\'échelle initiale', () {
      final c = ZMindmapViewController(
        initialScale: 1.0,
        minScale: 0.25,
        maxScale: 2.5,
        zoomStep: 0.25,
      );
      addTearDown(c.dispose);

      for (var i = 0; i < 50; i++) {
        c.zoomIn();
      }
      // 🔴 GARDE (INJ-1) : sans `clamp`, 50 zoom-in dépasseraient largement 2.5.
      expect(c.scale.value, lessThanOrEqualTo(2.5));
      expect(c.scale.value, 2.5);

      for (var i = 0; i < 50; i++) {
        c.zoomOut();
      }
      expect(c.scale.value, greaterThanOrEqualTo(0.25));
      expect(c.scale.value, 0.25);

      c.resetZoom();
      expect(c.scale.value, 1.0);
    });

    test('initialScale hors bornes est clampé à la construction', () {
      final c = ZMindmapViewController(initialScale: 99, maxScale: 3);
      addTearDown(c.dispose);
      expect(c.scale.value, 3);
    });

    testWidgets(
        'les boutons zoom pilotent le contrôleur (clampé) via l\'UI graphe',
        (tester) async {
      final c = ZMindmapViewController(maxScale: 2.5, zoomStep: 0.25);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(ZMindmapView(roots: _monoRoot(), controller: c)),
      );
      await tester.pump();

      final zoomIn = find.byKey(const ValueKey<String>('zmindmap-ctl-zoom-in'));
      expect(zoomIn, findsOneWidget);
      for (var i = 0; i < 40; i++) {
        await tester.tap(zoomIn);
      }
      await tester.pump();
      expect(c.scale.value, 2.5); // clampé même via l'UI

      // Une enveloppe Transform externe pilotée existe (zoom non forké graphite).
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ───────────────────────────── AC3 — COMPACT ─────────────────────────────
  group('AC3 — mode compact (masquage du contenu, rebuild ciblé)', () {
    testWidgets(
        'INJ-2 (masquage) : compact masque le contenu (label seul), '
        'non-compact le montre', (tester) async {
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _monoRoot(),
            mode: ZMindmapViewMode.list,
            controller: c,
            nodeContentBuilder: (context, n) =>
                Text('${n.label}##${n.content}'),
          ),
        ),
      );
      await tester.pump();

      // Non-compact : le contenu injecté est rendu.
      expect(find.text('Root##ROOTCONTENT'), findsOneWidget);
      expect(find.text('Child##CHILDCONTENT'), findsOneWidget);

      // Compact ON : contenu masqué, label seul.
      c.toggleCompact();
      await tester.pump();
      // 🔴 GARDE (INJ-2) : si la carte ignore `compact` et appelle toujours le
      // builder, ces `findsNothing` deviennent ROUGES.
      expect(find.text('Root##ROOTCONTENT'), findsNothing);
      expect(find.text('Child##CHILDCONTENT'), findsNothing);
      expect(find.text('Root'), findsOneWidget); // label compact
      expect(find.text('Child'), findsOneWidget);

      // Compact OFF : rendu plein restauré.
      c.toggleCompact();
      await tester.pump();
      expect(find.text('Root##ROOTCONTENT'), findsOneWidget);
    });

    testWidgets(
        'SM-1 : un zoom ne reconstruit PAS les nœuds (tranche zoom isolée)',
        (tester) async {
      final c = ZMindmapViewController(maxScale: 2.5, zoomStep: 0.25);
      addTearDown(c.dispose);
      var contentBuilds = 0;
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _monoRoot(),
            controller: c,
            nodeContentBuilder: (context, n) {
              contentBuilds++;
              return Text(n.label);
            },
          ),
        ),
      );
      await tester.pump();
      final before = contentBuilds;
      expect(before, greaterThan(0));

      // Zoomer : la tranche `scale` ne pilote QUE le Transform externe (child
      // passé une fois) ⇒ aucun nœud reconstruit.
      c.zoomIn();
      c.zoomIn();
      await tester.pump();
      // 🔴 SM-1 : si le zoom était routé par un setState reconstruisant la
      // surface, `contentBuilds` augmenterait (RED).
      expect(contentBuilds, before,
          reason: 'le zoom ne doit pas reconstruire les nœuds (SM-1/AD-2)');
    });
  });

  // ───────────────────────────── AC4 — PLEIN-ÉCRAN ─────────────────────────
  group('AC4 — plein-écran (toggle, défaut off)', () {
    test('INJ-3b : le contrôleur par défaut n\'est PAS plein-écran', () {
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      // 🔴 GARDE (INJ-3b) : faire du plein-écran le défaut rend ceci ROUGE (et
      // casse le layout inline E10 — recoupe AC6).
      expect(c.fullscreen.value, isFalse);
    });

    testWidgets(
        'toggle plein-écran : le WRAPPER maximisé apparaît/disparaît (pas '
        'seulement le libellé du bouton) + affordance de sortie étiquetée',
        (tester) async {
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(ZMindmapView(roots: _monoRoot(), controller: c)),
      );
      await tester.pump();

      final maximizedSurface =
          find.byKey(const ValueKey<String>(kMindmapMaximizedSurfaceKey));

      // Défaut off : l'affordance affiche « entrer », pas « sortir »…
      expect(find.bySemanticsLabel('Plein écran'), findsOneWidget);
      expect(find.bySemanticsLabel('Quitter le plein écran'), findsNothing);
      // 🔴 LOAD-BEARING (MEDIUM-1 ES-7.2) : et le WRAPPER maximisé est ABSENT.
      // Assertion STRUCTURELLE — indépendante du libellé du bouton, qui vit dans
      // `body` (présent dans les deux branches). Sans le wrapper en prod, cette
      // assertion resterait faussement verte sur le seul libellé.
      expect(maximizedSurface, findsNothing);

      c.toggleFullscreen();
      await tester.pump();
      // Plein-écran : l'affordance de SORTIE étiquetée est présente…
      expect(find.bySemanticsLabel('Quitter le plein écran'), findsOneWidget);
      // 🔴 LOAD-BEARING : …ET le wrapper maximisé (`SizedBox.expand` keyé) est
      // réellement monté ⇒ neutraliser le wrapper en prod (INJ-ADV-A) ROUGIT ici.
      expect(maximizedSurface, findsOneWidget);
    });
  });

  // ───────────────────────────── AC5 — SUPER-RACINE ────────────────────────
  group('AC5 — super-racine multi-forêt (opt-in, réutilise usesVirtualRoot)',
      () {
    testWidgets(
        'INJ-3 : > 1 racine + showSuperRoot ON ⇒ super-racine étiquetée ; '
        '1 racine ⇒ JAMAIS', (tester) async {
      // Multi-racine, liste.
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _multiRoot(),
            mode: ZMindmapViewMode.list,
            controller: c,
          ),
        ),
      );
      await tester.pump();

      // OFF : pas de super-racine.
      expect(
        find.byKey(const ValueKey<String>('zmindmap-list-super-root')),
        findsNothing,
      );

      // ON : super-racine étiquetée visible.
      c.toggleSuperRoot();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('zmindmap-list-super-root')),
        findsOneWidget,
      );
      expect(find.text('Toutes les cartes'), findsOneWidget);

      // ─ 1 seule racine + showSuperRoot ON ⇒ JAMAIS de super-racine ─
      final c2 = ZMindmapViewController(showSuperRoot: true);
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _monoRoot(),
            mode: ZMindmapViewMode.list,
            controller: c2,
          ),
        ),
      );
      await tester.pump();
      // 🔴 GARDE (INJ-3) : forcer usesVirtualRoot pour 1 racine rendrait ceci
      // ROUGE.
      expect(
        find.byKey(const ValueKey<String>('zmindmap-list-super-root')),
        findsNothing,
      );
    });

    testWidgets('super-racine affichée aussi dans le graphe (multi-forêt)',
        (tester) async {
      final c = ZMindmapViewController(showSuperRoot: true);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(ZMindmapView(roots: _multiRoot(), controller: c)),
      );
      await tester.pump();
      expect(find.text('Toutes les cartes'), findsWidgets);
    });
  });

  // ───────────────────────── AC6 — ADDITIF STRICT ──────────────────────────
  group('AC6 — additivité stricte (contrôleur optionnel = E10)', () {
    testWidgets('sans contrôleur : aucune barre de contrôles (E10 inchangé)',
        (tester) async {
      await tester.pumpWidget(_host(ZMindmapView(roots: _monoRoot())));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('zmindmap-ctl-zoom-in')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('zmindmap-ctl-fullscreen')),
        findsNothing,
      );
      // Rendu E10 nominal préservé.
      expect(find.text('Root'), findsWidgets);
    });

    test('tous les nouveaux toggles ont un défaut = comportement E10', () {
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      expect(c.compact.value, isFalse);
      expect(c.fullscreen.value, isFalse);
      expect(c.showSuperRoot.value, isFalse);
      expect(c.scale.value, 1.0);
    });
  });

  // ───────────────────────── AC10 — A11Y / THÈME ───────────────────────────
  group('AC10 — a11y / thème des nouveaux contrôles (AD-13/FR-26)', () {
    testWidgets('chaque contrôle : Semantics(button, label externalisé) ≥ 48 dp',
        (tester) async {
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(ZMindmapView(roots: _monoRoot(), controller: c)),
      );
      await tester.pump();

      for (final label in const <String>[
        'Zoom avant',
        'Zoom arrière',
        'Réinitialiser le zoom',
        'Affichage compact',
        'Plein écran',
        'Afficher la racine commune',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget,
            reason: 'libellé a11y externalisé manquant : $label');
      }

      // Cibles ≥ 48 dp : chaque IconButton porte une contrainte min 48×48.
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(buttons, isNotEmpty);
      for (final b in buttons) {
        final cst = b.constraints;
        expect(cst, isNotNull);
        expect(cst!.minWidth, greaterThanOrEqualTo(48));
        expect(cst.minHeight, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('libellés a11y surchargeables (localisation)', (tester) async {
      final c = ZMindmapViewController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(
          ZMindmapView(
            roots: _monoRoot(),
            controller: c,
            viewLabels: const ZMindmapViewLabels(zoomIn: 'ZOOM+'),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('ZOOM+'), findsOneWidget);
    });

    test(
        'scan de conformité : les nouveaux fichiers ES-7.2 ne codent AUCUNE '
        'couleur en dur (FR-26)', () {
      const files = <String>[
        'z_mindmap_view.dart',
        'z_mindmap_view_controls.dart',
        'z_mindmap_markdown_content.dart',
      ];
      for (final name in files) {
        final f = _presentationFile(name);
        final src = _stripComments(f.readAsStringSync());
        // 🔴 GARDE (AC10) : coder `Color(0x…)` ou `Colors.…` rend ceci ROUGE.
        expect(RegExp(r'Color\(0x').hasMatch(src), isFalse,
            reason: 'couleur hex codée en dur dans $name');
        expect(RegExp(r'\bColors\.').hasMatch(src), isFalse,
            reason: 'palette Colors.* codée en dur dans $name');
      }
    });
  });
}

/// Résout un fichier de `lib/src/presentation` (racine workspace OU package).
File _presentationFile(String name) {
  const roots = <String>[
    'lib/src/presentation',
    'packages/zcrud_mindmap/lib/src/presentation',
  ];
  for (final r in roots) {
    final f = File('$r/$name');
    if (f.existsSync()) return f;
  }
  return File('${roots.first}/$name');
}

/// Retire les commentaires pour ne scanner que le code réel.
String _stripComments(String source) {
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('///') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('*')) {
      continue;
    }
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}
