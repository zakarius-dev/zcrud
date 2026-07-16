import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Enfant qui compte ses builds — sert à prouver que le sous-arbre protégé
/// n'est PAS reconstruit au flip *dirty* (SM-1).
class _CountingChild extends StatefulWidget {
  const _CountingChild(this.onBuild);
  final VoidCallback onBuild;
  @override
  State<_CountingChild> createState() => _CountingChildState();
}

class _CountingChildState extends State<_CountingChild> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return Scaffold(
      appBar: AppBar(title: const Text('PAGE')),
      body: const Center(child: Text('BODY')),
    );
  }
}

Widget _harness({
  required ValueListenable<bool> isDirty,
  required VoidCallback onChildBuild,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ZDiscardChangesGuard(
                isDirty: isDirty,
                child: _CountingChild(onChildBuild),
              ),
            ),
          ),
          child: const Text('PUSH'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'flips dirty↔clean répétés : canPop suit !dirty (tranche PopScope re-run) '
    'tandis que le child protégé n\'est jamais reconstruit (SM-1), puis sortie '
    'directe sans dialog en état propre',
    (tester) async {
      var childBuilds = 0;
      final notifier = ValueNotifier<bool>(true);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _harness(isDirty: notifier, onChildBuild: () => childBuilds++),
      );
      await tester.tap(find.text('PUSH'));
      await tester.pumpAndSettle();
      expect(find.text('BODY'), findsOneWidget);

      final buildsAfterMount = childBuilds;

      // `canPop` du PopScope DE LA GARDE (descendant direct, pas un PopScope
      // framework d'une route). Sa valeur EST le signal porteur : une garde
      // qui ne réagirait pas au flip (ou câblerait mal `canPop:!dirty`) ferait
      // rougir ce test — cf. spot-check R3 orchestrateur.
      final guardPopScope = find.descendant(
        of: find.byType(ZDiscardChangesGuard),
        matching: find.byType(PopScope<Object?>),
      );
      bool canPop() =>
          tester.widgetList<PopScope<Object?>>(guardPopScope).first.canPop;

      // À l'état initial (dirty=true), la sortie est bloquée.
      expect(canPop(), isFalse);

      // Flips répétés : à CHAQUE flip la tranche `ValueListenableBuilder` DOIT
      // re-tourner et `canPop` suivre `!dirty` (assertion PORTEUSE). Le
      // sous-arbre protégé `child`, lui, est passé via le paramètre `child` du
      // `ValueListenableBuilder` (instance stable) : il n'est jamais reconstruit
      // (SM-1) — `childBuilds` reste au compteur de montage à travers 3 flips.
      for (final dirty in <bool>[false, true, false]) {
        notifier.value = dirty;
        await tester.pump();
        expect(canPop(), !dirty,
            reason: 'canPop doit suivre !dirty (tranche re-run à chaque flip)');
        expect(childBuilds, buildsAfterMount,
            reason: 'child jamais reconstruit malgré 3 re-run de la tranche');
      }

      // État final propre ⇒ sortie directe, aucun dialog.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ZConfirmDialog), findsNothing);
      expect(find.text('BODY'), findsNothing);
    },
  );

  testWidgets(
    'flip clean→dirty : la garde intercepte la sortie et affiche le dialog',
    (tester) async {
      var childBuilds = 0;
      final notifier = ValueNotifier<bool>(false);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _harness(isDirty: notifier, onChildBuild: () => childBuilds++),
      );
      await tester.tap(find.text('PUSH'));
      await tester.pumpAndSettle();

      // Devient sale (saisie utilisateur).
      notifier.value = true;
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ZConfirmDialog), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);
    },
  );

  testWidgets('garde rendue sous Directionality.rtl sans exception',
      (tester) async {
    final notifier = ValueNotifier<bool>(true);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ZDiscardChangesGuard(
            isDirty: notifier,
            child: const Scaffold(body: Center(child: Text('BODY'))),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('BODY'), findsOneWidget);
  });

  test('le fichier source n\'importe AUCUN gestionnaire d\'état (AD-2/AD-15)',
      () {
    // Lecture robuste quel que soit le cwd (racine du repo via `melos test`
    // OU racine du package) — sinon un chemin relatif au cwd fait rougir la
    // suite depuis la racine (code-review EX-UI.10 L-1).
    String readSource(String basename) {
      for (final base in const <String>[
        'lib/src/presentation',
        'packages/zcrud_ui_kit/lib/src/presentation',
      ]) {
        final f = File('$base/$basename');
        if (f.existsSync()) return f.readAsStringSync();
      }
      throw StateError('Fichier source introuvable : $basename');
    }

    final source = readSource('z_discard_changes_guard.dart');
    // Cible les directives `import` uniquement (la prose du dartdoc cite ces
    // managers pour documenter leur neutralisation — sans les importer).
    final imports = source
        .split('\n')
        .where((l) => l.trimLeft().startsWith('import '))
        .join('\n');
    expect(imports.contains('flutter_riverpod'), isFalse);
    expect(imports.contains('package:get/'), isFalse);
    expect(imports.contains('package:provider/'), isFalse);
    // Le type ValueListenable vient de flutter/foundation : aucun import
    // zcrud_core n'est requis dans le garde.
    expect(imports.contains('package:zcrud_core'), isFalse);
  });
}
