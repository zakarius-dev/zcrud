// CR-LEX-20 — `ZMindmapOutlineEditor` capturait son contrôleur en `initState`
// (`late final`) sans `didUpdateWidget` : un contrôleur **remplacé** par
// l'appelant était **IGNORÉ**. L'éditeur continuait d'écouter et de muter
// l'ancien, sans erreur ni signal.
//
// C'est le défaut AD-2 que ce socle existe pour éliminer — dans l'un de ses
// propres widgets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

Widget _app(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

ZMindmapOutlineController _ctl(String label) => ZMindmapOutlineController(
      initialForest: <ZMindmapNode>[ZMindmapNode(id: 'n_$label', label: label)],
    );

void main() {
  group('🔴 CR-LEX-20 — un contrôleur REMPLACÉ est pris en compte', () {
    testWidgets('le nouveau contrôleur devient la source affichée',
        (tester) async {
      final a = _ctl('ALPHA');
      addTearDown(a.dispose);
      final b = _ctl('BETA');
      addTearDown(b.dispose);

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: a)));
      await tester.pumpAndSettle();
      expect(find.text('ALPHA'), findsWidgets);

      // Remplacement par l'appelant — c'est ici que l'éditeur restait sourd.
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: b)));
      await tester.pumpAndSettle();
      expect(find.text('BETA'), findsWidgets,
          reason: 'le contrôleur injecté après coup doit être adopté');
      expect(find.text('ALPHA'), findsNothing,
          reason: 'l\'ancien ne doit plus piloter le rendu');
    });

    testWidgets('une mutation du NOUVEAU contrôleur est reflétée',
        (tester) async {
      // Preuve que l'éditeur ÉCOUTE bien le nouveau, pas seulement qu'il l'a lu.
      final a = _ctl('ALPHA');
      addTearDown(a.dispose);
      final b = _ctl('BETA');
      addTearDown(b.dispose);

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: a)));
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: b)));
      await tester.pumpAndSettle();

      b.addRoot();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('un contrôleur INCHANGÉ n\'est ni recréé ni libéré',
        (tester) async {
      // Non-régression SM-1 : un rebuild ordinaire ne doit rien reconstruire.
      final a = _ctl('ALPHA');
      addTearDown(a.dispose);
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: a)));
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: a)));
      await tester.pumpAndSettle();
      expect(find.text('ALPHA'), findsWidgets);
      // S'il avait été disposé, toute mutation lèverait.
      expect(a.addRoot, returnsNormally);
    });
  });

  group('🔴 La propriété du cycle de vie est respectée', () {
    testWidgets('un contrôleur INJECTÉ n\'est JAMAIS disposé par l\'éditeur',
        (tester) async {
      // Il appartient à l'appelant : le libérer parce qu'il en fournit un autre
      // détruirait un objet dont l'éditeur n'a pas la charge.
      final a = _ctl('ALPHA');
      addTearDown(a.dispose);
      final b = _ctl('BETA');
      addTearDown(b.dispose);

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: a)));
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: b)));
      await tester.pumpAndSettle();

      // `a` doit rester UTILISABLE — s'il avait été disposé, ceci lèverait.
      expect(a.addRoot, returnsNormally,
          reason: 'l\'ancien contrôleur injecté appartient toujours à l\'appelant');
    });

    testWidgets('passer d\'injecté à `null` redonne un contrôleur POSSÉDÉ',
        (tester) async {
      final a = _ctl('ALPHA');
      addTearDown(a.dispose);

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: a)));
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(
        roots: <ZMindmapNode>[ZMindmapNode(id: 'n_solo', label: 'SOLO')],
      )));
      await tester.pumpAndSettle();

      expect(find.text('SOLO'), findsWidgets);
      expect(a.addRoot, returnsNormally,
          reason: 'l\'ancien injecté n\'a pas été libéré par l\'éditeur');
    });

    testWidgets('le contrôleur POSSÉDÉ est libéré au démontage', (tester) async {
      await tester.pumpWidget(_app(ZMindmapOutlineEditor(
        roots: <ZMindmapNode>[ZMindmapNode(id: 'n1', label: 'A')],
      )));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'aucune fuite ni double-dispose au démontage');
    });
  });
}
