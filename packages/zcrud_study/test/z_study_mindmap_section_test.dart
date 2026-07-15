// Tests DISCRIMINANTS ES-7.1 — `ZStudyMindmapSection` : adaptateur MINCE de
// composition qui assemble la surface publique DÉJÀ LIVRÉE de `zcrud_mindmap`
// (`ZMindmapView` E10-2 ; `ZMindmapOutlineController`/`ZMindmapOutlineEditor`
// E10-3) comme UNE section de la page study-tools (AD-25/AD-4/AD-28).
//
// Ancrage R20 (motif dominant ES-6) : AC3/AC4 ancrent leurs assertions sur les
// objets/lignes PROPRES à `ZStudyMindmapSection` (identité du controller DÉTENU
// par la section, capturée via le `ZMindmapOutlineEditor` composé ; notifier de
// mode LOCAL), JAMAIS sur une garantie interne des widgets réutilisés.
//
// Pouvoir discriminant (R12) : chaque AC rougit sous l'injection R3 correspondante
// (cf. § « Injections R3 prévues » de la story, R3-I1..I10).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

/// Forêt mono-racine à 2 niveaux (ids STABLES pour comparer par id, DW-ES22-5 :
/// JAMAIS `ZMindmap == ZMindmap`).
List<ZMindmapNode> _forest() => ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(
        id: 'r',
        label: 'Root',
        children: <ZMindmapNode>[
          ZMindmapNode(id: 'c1', label: 'Child1'),
        ],
      ),
    ]);

ZMindmap _mindmap(String folderId) => ZMindmap(
      id: 'mm-$folderId',
      folderId: folderId,
      title: 'Carte $folderId',
      nodes: _forest(),
    );

/// Enveloppe déterministe : `MaterialApp` (thème), direction fixe, `ZcrudScope`
/// (injection zéro-config AD-15), taille bornée (contraintes du graphe/liste).
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

/// Détecte une **dépendance directe** (ligne `  <pkg>:` sous `dependencies:`),
/// en IGNORANT les mentions en commentaire (` # ... `backtick`pkg`backtick`).
bool _hasDirectDep(String pubspec, String pkg) =>
    RegExp('^\\s+$pkg\\s*:', multiLine: true).hasMatch(pubspec);

void main() {
  // ===========================================================================
  // AC1 — Composition lecture par `folderId` (clé NEUTRE), zéro réimpl. graphite.
  // ===========================================================================
  group('AC1 — composition ZMindmapView + clé neutre folderId', () {
    testWidgets('rend EXACTEMENT un ZMindmapView + clé neutre présente',
        (tester) async {
      await tester.pumpWidget(_host(ZStudyMindmapSection(
        folderId: 'f1',
        mindmap: _mindmap('f1'),
        viewMode: ZMindmapViewMode.list,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Zéro réimplémentation : la lecture EST un ZMindmapView (R3-I2).
      expect(find.byType(ZMindmapView), findsOneWidget);
      // Clé NEUTRE dérivée du folderId, jamais l'entité kernel (R3-I1).
      expect(find.byKey(const ValueKey<String>('mindmap:f1')), findsOneWidget);
    });

    testWidgets('deux folderId distincts ⇒ deux clés DISTINCTES (pas de fuite)',
        (tester) async {
      await tester.pumpWidget(_host(ListView(
        children: <Widget>[
          ZStudyMindmapSection(
            folderId: 'fA',
            roots: _forest(),
            viewMode: ZMindmapViewMode.list,
            viewportHeight: 160,
          ),
          ZStudyMindmapSection(
            folderId: 'fB',
            roots: _forest(),
            viewMode: ZMindmapViewMode.list,
            viewportHeight: 160,
          ),
        ],
      )));
      await tester.pump();

      // Discriminant R3-I1 : une clé constante ferait échouer l'UNE des deux.
      expect(find.byKey(const ValueKey<String>('mindmap:fA')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('mindmap:fB')), findsOneWidget);
      expect(find.byType(ZMindmapView), findsNWidgets(2));
    });
  });

  // ===========================================================================
  // AC2 — Flowchart legacy NON porté ; graphite UNIQUEMENT transitif (verrou-source).
  // ===========================================================================
  group('AC2 — verrou-source flowchart legacy / graphite', () {
    test('la section n\'importe NI flutter_flow_chart NI graphview NI graphite',
        () {
      final src = File('lib/src/presentation/z_study_mindmap_section.dart')
          .readAsStringSync();
      // Discriminant R3-I3 : un `import '...graphview...'` rougirait ici.
      expect(src.contains("package:flutter_flow_chart"), isFalse);
      expect(src.contains("package:graphview"), isFalse);
      expect(src.contains("package:graphite"), isFalse);
    });

    test('pubspec zcrud_study : graphite/flow_chart/graphview PAS en dép directe',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      // graphite reste TRANSITIF via zcrud_mindmap (arête AD-1 justifiée).
      expect(_hasDirectDep(pubspec, 'graphite'), isFalse);
      expect(_hasDirectDep(pubspec, 'flutter_flow_chart'), isFalse);
      expect(_hasDirectDep(pubspec, 'graphview'), isFalse);
      // L'arête AUTORISÉE est bien déclarée.
      expect(_hasDirectDep(pubspec, 'zcrud_mindmap'), isTrue);
    });
  });

  // ===========================================================================
  // AC3 — Cycle de vie du controller DÉTENU par la section (owned/injected, R20).
  // ===========================================================================
  group('AC3 — ZMindmapOutlineController owned/injected', () {
    testWidgets(
        'POSSÉDÉ : identique sous tempête de rebuilds, disposé au démontage',
        (tester) async {
      late StateSetter storm;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) {
          storm = setState;
          return ZStudyMindmapSection(
            folderId: 'f',
            roots: _forest(),
            initialMode: ZStudyMindmapMode.edit,
          );
        },
      )));
      await tester.pump();

      // R20 : on capture l'objet DÉTENU par la section via le widget composé.
      ZMindmapOutlineController controllerOf() => tester
          .widget<ZMindmapOutlineEditor>(find.byType(ZMindmapOutlineEditor))
          .controller!;

      final before = controllerOf();

      // Tempête : ≥ 5 rebuilds du parent (R3-I4 : recréation en build ⇒ non-identique).
      for (var i = 0; i < 6; i++) {
        storm(() {});
        await tester.pump();
      }
      final after = controllerOf();
      expect(identical(before, after), isTrue,
          reason: 'controller recréé sous rebuild ⇒ AD-2 violé (R3-I4)');
      expect(before.isDisposed, isFalse);

      // Démontage ⇒ le controller POSSÉDÉ est disposé (exactement une fois).
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(before.isDisposed, isTrue);
    });

    testWidgets('INJECTÉ : utilisé tel quel, JAMAIS disposé par la section',
        (tester) async {
      final injected =
          ZMindmapOutlineController(initialForest: _forest());
      addTearDown(injected.dispose);

      await tester.pumpWidget(_host(ZStudyMindmapSection(
        folderId: 'f',
        roots: _forest(),
        initialMode: ZStudyMindmapMode.edit,
        outlineController: injected,
      )));
      await tester.pump();

      // La section compose l'éditeur sur le controller INJECTÉ (identité).
      final used = tester
          .widget<ZMindmapOutlineEditor>(find.byType(ZMindmapOutlineEditor))
          .controller;
      expect(identical(used, injected), isTrue);

      // Démontage ⇒ controller injecté NON disposé (R3-I5 : dispose ⇒ rouge).
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(injected.isDisposed, isFalse);
    });
  });

  // ===========================================================================
  // AC4 — Bascule lecture ⇄ édition LOCALE ; frontière rebuild SM-1 préservée.
  // ===========================================================================
  testWidgets(
      'AC4 — bascule LOCALE : la section-sonde N\'est PAS reconstruite (R3-I6)',
      (tester) async {
    var probeBuilds = 0;

    final probe = ZStudyToolsSectionSpec(
      id: 'probe',
      title: 'Sonde',
      itemCount: 1,
      emptyState: const SizedBox.shrink(),
      itemBuilder: (context, index) {
        probeBuilds++;
        return const Text('sonde-item');
      },
    );
    final mindmap = ZStudyMindmapSection.sectionSpec(
      id: 'mm',
      title: 'Carte',
      folderId: 'f',
      emptyState: const SizedBox.shrink(),
      roots: _forest(),
      viewMode: ZMindmapViewMode.list,
      viewportHeight: 120,
      // Label INJECTÉ distinctif = ancrage du tap ET de l'assertion AC5.
      enterEditSemanticLabel: 'GO-EDIT-XYZ',
    );

    await tester.pumpWidget(_host(ZStudyToolsPage(
      // Sonde EN PREMIER (on-screen ⇒ build initial comptabilisé, sans quoi le
      // test serait non-discriminant : un item offscreen ne build jamais).
      sections: <ZStudyToolsSectionSpec>[probe, mindmap],
    )));
    await tester.pump();

    final baseline = probeBuilds;
    expect(baseline, greaterThanOrEqualTo(1));
    expect(find.byType(ZMindmapView), findsOneWidget);
    expect(find.byType(ZMindmapOutlineEditor), findsNothing);

    // Bascule via le chrome de la section mindmap (notifier LOCAL).
    await tester.tap(find.byTooltip('GO-EDIT-XYZ'));
    await tester.pump();

    // Seul le sous-arbre de la section mindmap se reconstruit : view → editor.
    expect(find.byType(ZMindmapOutlineEditor), findsOneWidget);
    expect(find.byType(ZMindmapView), findsNothing);
    // R3-I6 : un mode lifté au parent (setState) reconstruirait la sonde.
    expect(probeBuilds, baseline,
        reason: 'la sonde a été reconstruite ⇒ mode non-local (R3-I6)');
  });

  // ===========================================================================
  // AC5 — Chrome : thème/labels/sémantique INJECTÉS, ≥ 48 dp, directionnel.
  // ===========================================================================
  group('AC5 — chrome injecté (FR-26/AD-13)', () {
    testWidgets('label sémantique de bascule INJECTÉ (R3-I7)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(ZStudyMindmapSection(
        folderId: 'f',
        roots: _forest(),
        viewMode: ZMindmapViewMode.list,
        enterEditSemanticLabel: 'EDIT-LABEL-XYZ',
      )));
      await tester.pump();

      // Discriminant R3-I7 : un `'Éditer'` codé en dur ferait disparaître ce label.
      expect(find.bySemanticsLabel('EDIT-LABEL-XYZ'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('cible de bascule ≥ 48 dp portée par la section (R3-I8)',
        (tester) async {
      await tester.pumpWidget(_host(ZStudyMindmapSection(
        folderId: 'f',
        roots: _forest(),
        viewMode: ZMindmapViewMode.list,
      )));
      await tester.pump();

      // Ancrage sur la ConstrainedBox PROPRE à la section (pas la cible par
      // défaut de l'IconButton, qui masquerait le shrink R3-I8).
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
    });

    testWidgets('couleur du chrome ISSUE du thème injecté (FR-26)',
        (tester) async {
      const injectedColor = Color(0xFF123456);
      await tester.pumpWidget(_host(
        ZStudyMindmapSection(
          folderId: 'f',
          roots: _forest(),
          viewMode: ZMindmapViewMode.list,
        ),
        theme: const ZcrudTheme(labelColor: injectedColor),
      ));
      await tester.pump();

      final icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byType(IconButton),
              matching: find.byType(Icon),
            )
            .first,
      );
      // La couleur vient du thème injecté, pas d'un littéral codé en dur.
      expect(icon.color, injectedColor);
    });
  });

  // ===========================================================================
  // AC6 — `nodeContentBuilder` FORWARDÉ ; aucun rich-text (AD-28).
  // ===========================================================================
  group('AC6 — nodeContentBuilder forwardé / pas de zcrud_markdown', () {
    testWidgets('le builder custom est rendu par le ZMindmapView composé (R3-I9)',
        (tester) async {
      await tester.pumpWidget(_host(ZStudyMindmapSection(
        folderId: 'f',
        roots: _forest(),
        viewMode: ZMindmapViewMode.list,
        nodeContentBuilder: (context, node) => Text(
          'CUSTOM-${node.id}',
          key: ValueKey<String>('custom-${node.id}'),
        ),
      )));
      await tester.pump();

      // Discriminant R3-I9 : sans forward, le défaut sûr (label) serait rendu.
      expect(find.byKey(const ValueKey<String>('custom-r')), findsOneWidget);
      expect(find.text('CUSTOM-r'), findsOneWidget);
    });

    test('verrou-source : la section n\'importe PAS zcrud_markdown', () {
      final src = File('lib/src/presentation/z_study_mindmap_section.dart')
          .readAsStringSync();
      // Ancré sur un IMPORT réel (`package:zcrud_markdown`) — la mention en
      // commentaire de doc (« n'importe PAS zcrud_markdown ») ne compte pas.
      expect(src.contains('package:zcrud_markdown'), isFalse);
    });
  });

  // ===========================================================================
  // AC7 — Fabrique sectionSpec(...) → ZStudyToolsSectionSpec (AD-4/AD-25).
  // ===========================================================================
  group('AC7 — fabrique sectionSpec', () {
    test('itemCount == 1 ; addAction transmis ; null = ABSENT (R3-I10)', () {
      void cb() {}
      final withAction = ZStudyMindmapSection.sectionSpec(
        id: 'mm',
        title: 'Carte',
        folderId: 'f',
        emptyState: const SizedBox.shrink(),
        roots: _forest(),
        addAction: cb,
      );
      // Discriminant R3-I10 : `itemCount: 0` ou addAction ignoré rougirait ici.
      expect(withAction.itemCount, 1);
      expect(identical(withAction.addAction, cb), isTrue);

      final withoutAction = ZStudyMindmapSection.sectionSpec(
        id: 'mm2',
        title: 'Carte 2',
        folderId: 'g',
        emptyState: const SizedBox.shrink(),
        roots: _forest(),
      );
      // AD-4 : null = action ABSENTE (jamais un no-op silencieux).
      expect(withoutAction.addAction, isNull);
    });

    testWidgets('rendu dans ZSectionedStudyLayout : la section mindmap est composée',
        (tester) async {
      final spec = ZStudyMindmapSection.sectionSpec(
        id: 'mm',
        title: 'Carte',
        folderId: 'f7',
        emptyState: const SizedBox.shrink(),
        roots: _forest(),
        viewMode: ZMindmapViewMode.list,
        viewportHeight: 200,
      );
      await tester.pumpWidget(_host(ZSectionedStudyLayout(
        sections: <ZStudyToolsSectionSpec>[spec],
      )));
      await tester.pump();

      expect(find.byType(ZStudyMindmapSection), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('mindmap:f7')), findsOneWidget);
      expect(find.byType(ZMindmapView), findsOneWidget);
    });
  });
}
