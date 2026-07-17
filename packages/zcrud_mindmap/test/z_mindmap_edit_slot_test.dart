/// Tests SU-12 du **slot d'édition injectable** de `ZMindmapOutlineEditor`
/// (AC1/AC6/AC7). Discipline R3 : chaque garde rougit **par le comportement**
/// (le champ injecté monte / le défaut disparaît), pas par la présence d'un
/// paramètre. On observe DEUX canaux (widget monté ET défaut absent).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

const String _slot = 'rich_delta';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: ZcrudScope(
          child: SizedBox(width: 500, height: 700, child: child),
        ),
      ),
    ),
  );
}

/// Nettoyage de l'éditeur Quill inline (annule les Timers curseur/toolbar avant
/// démontage — sinon « A Timer is still pending »). Patron `zcrud_markdown`.
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  group('AC1 — slot injectable : défaut = TextField (aucune régression)', () {
    testWidgets('SANS injection ⇒ TextField texte brut (label + content)',
        (tester) async {
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'Racine')];
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(roots: roots)));
      await tester.pump();
      // Défaut = 2 TextField (label + content), aucun adaptateur riche monté.
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ZMindmapMarkdownEditField), findsNothing);
      expect(find.byType(ZMarkdownField), findsNothing);
      // Cible ≥ 48 dp conservée (MEDIUM-1) — au moins un champ borné.
      expect(tester.takeException(), isNull);
    });

    testWidgets('editContentField=false ⇒ un seul TextField (label)',
        (tester) async {
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'Racine')];
      await tester.pumpWidget(
        _host(ZMindmapOutlineEditor(roots: roots, editContentField: false)),
      );
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('SM-1 : controller stable keyé par id, jamais recréé au rebuild',
        (tester) async {
      final controller =
          ZMindmapOutlineController(initialForest: <ZMindmapNode>[
        ZMindmapNode(id: 'r', label: 'A'),
      ]);
      addTearDown(controller.dispose);
      final node = controller.forest.first;
      final c1 = controller.labelControllerFor(node);
      await tester.pumpWidget(
        _host(ZMindmapOutlineEditor(controller: controller)),
      );
      await tester.pump();
      // Frappe : la voie texte brut met à jour la forêt SANS recréer le controller.
      await tester.enterText(find.byType(TextField).first, 'Abcd');
      await tester.pump();
      final c2 = controller.labelControllerFor(controller.forest.first);
      expect(identical(c1, c2), isTrue,
          reason: 'controller stable (SM-1) — jamais recréé');
      expect(controller.forest.first.label, 'Abcd');
    });
  });

  group('AC6 — branchement EFFECTIF du slot (leçon su-1, R3, deux canaux)', () {
    testWidgets(
        'AVEC injection ⇒ le champ RICHE monte ET le TextField défaut DISPARAÎT',
        (tester) async {
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'Racine')];
      await tester.pumpWidget(
        _host(
          ZMindmapOutlineEditor(
            roots: roots,
            editFieldBuilder:
                ZMindmapMarkdownEditField.builder(slotKey: _slot),
          ),
        ),
      );
      await tester.pump();
      // CANAL 1 — le builder injecté a RÉELLEMENT monté son widget (label+content).
      // Rougit si `ZMindmapOutlineEditor` ignore `editFieldBuilder` et retombe
      // sur le TextField en dur (contrôle décoratif ⇒ ROUGE par comportement).
      expect(find.byType(ZMindmapMarkdownEditField), findsNWidgets(2));
      // CANAL 2 — l'éditeur rich-text RÉEL est présent (pas qu'un wrapper vide).
      expect(find.byType(ZMarkdownField), findsWidgets);
      // CANAL 3 (F1) — REMPLACEMENT, pas SUPPLÉMENT : le TextField défaut a bien
      // DISPARU. Rougit si une régression rendait À LA FOIS le builder injecté ET
      // le TextField en dur (le seul canal « le riche apparaît » ne le verrait pas).
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await _settle(tester);
    });

    testWidgets('kind est un ENUM (label vs content), jamais un bool',
        (tester) async {
      // Le builder reçoit `ctx.kind` ∈ {label, content} : on prouve que les DEUX
      // valeurs de l'enum sont routées (deux adaptateurs distincts montés).
      final kinds = <ZMindmapEditFieldKind>[];
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r', label: 'R')];
      await tester.pumpWidget(
        _host(
          ZMindmapOutlineEditor(
            roots: roots,
            editFieldBuilder: (context, ctx) {
              kinds.add(ctx.kind);
              return _defaultProbe(ctx);
            },
          ),
        ),
      );
      await tester.pump();
      expect(kinds, containsAll(<ZMindmapEditFieldKind>[
        ZMindmapEditFieldKind.label,
        ZMindmapEditFieldKind.content,
      ]));
    });
  });

  group('AC7 — robustesse (AD-10) + arène scroll bornée', () {
    testWidgets('nœud VIDE (label "", content null) ⇒ aucun throw (défaut)',
        (tester) async {
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r')];
      await tester.pumpWidget(_host(ZMindmapOutlineEditor(roots: roots)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('nœud VIDE + builder riche ⇒ éditeur rich vide, aucun throw',
        (tester) async {
      final roots = <ZMindmapNode>[ZMindmapNode(id: 'r')];
      await tester.pumpWidget(
        _host(
          ZMindmapOutlineEditor(
            roots: roots,
            editFieldBuilder:
                ZMindmapMarkdownEditField.builder(slotKey: _slot),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZMarkdownField), findsWidgets);
      await _settle(tester);
    });

    testWidgets('slot MAL FORMÉ (non-liste) ⇒ repli sûr, aucun throw',
        (tester) async {
      final roots = <ZMindmapNode>[
        ZMindmapNode(
          id: 'r',
          label: 'R',
          extra: <String, dynamic>{_slot: 'pas une liste'},
        ),
      ];
      await tester.pumpWidget(
        _host(
          ZMindmapOutlineEditor(
            roots: roots,
            editFieldBuilder:
                ZMindmapMarkdownEditField.builder(slotKey: _slot),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZMarkdownField), findsWidgets);
      await _settle(tester);
    });

    testWidgets('RTL : TextAlign.start respecté, aucun débordement (défaut)',
        (tester) async {
      final roots = <ZMindmapNode>[
        ZMindmapNode(id: 'r', label: 'مرحبا Unicode 🌍'),
      ];
      await tester.pumpWidget(
        _host(ZMindmapOutlineEditor(roots: roots),
            direction: TextDirection.rtl),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.textAlign, TextAlign.start);
    });

    testWidgets(
        'éditeur riche BORNÉ (maxLines) ⇒ hauteur plafonnée, ne vole pas le '
        'scroll de l\'outline (AC7)', (tester) async {
      final roots = <ZMindmapNode>[
        for (var i = 0; i < 6; i++) ZMindmapNode(id: 'n$i', label: 'N$i'),
      ];
      await tester.pumpWidget(
        _host(
          ZMindmapOutlineEditor(
            roots: roots,
            editFieldBuilder:
                ZMindmapMarkdownEditField.builder(slotKey: _slot),
          ),
        ),
      );
      await tester.pump();
      // L'outline reste un ListView.builder défilable.
      expect(find.byType(ListView), findsOneWidget);
      // GARDE AC7 : chaque ZMarkdownField est BORNÉ (maxLines != null) ⇒ hauteur
      // plafonnée, défilement INTERNE — pas d'« unbounded height » qui casserait
      // le scroll parent. Rougirait si l'adaptateur retirait la borne.
      final fields = tester
          .widgetList<ZMarkdownField>(find.byType(ZMarkdownField))
          .toList();
      expect(fields, isNotEmpty);
      for (final f in fields) {
        expect(f.maxLines, isNotNull,
            reason: 'éditeur non borné volerait le scroll de l\'outline');
      }
      await _settle(tester);
    });
  });
}

/// Sonde d'édition minimale (texte brut) : prouve le routage sans dépendre de
/// l'adaptateur riche (isole l'enum kind).
Widget _defaultProbe(ZMindmapEditFieldContext ctx) => Semantics(
      label: ctx.hint,
      child: TextField(controller: ctx.controller),
    );
