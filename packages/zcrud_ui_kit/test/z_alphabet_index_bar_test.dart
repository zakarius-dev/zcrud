import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Lit un fichier source de présentation quel que soit le cwd (racine du repo
/// ou racine du package) — le scan ne doit dépendre que des directives `import`.
String _readSource(String basename) {
  for (final base in const [
    'lib/src/presentation',
    'packages/zcrud_ui_kit/lib/src/presentation',
  ]) {
    final f = File('$base/$basename');
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError('Fichier source introuvable : $basename');
}

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('rend les 26 lettres A→Z par défaut (AC1)', (tester) async {
    await tester.pumpWidget(_host(ZAlphabetIndexBar(onLetter: (_) {})));

    for (final letter in kZDefaultAlphabet) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(kZDefaultAlphabet.length, 26);
    expect(kZDefaultAlphabet.first, 'A');
    expect(kZDefaultAlphabet.last, 'Z');
  });

  testWidgets('rend le jeu de lettres injecté (AC1)', (tester) async {
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: (_) {}, letters: const ['1', '2', '#']),
    ));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('ZAlphabetIndexBar est un StatelessWidget (AC1)', (tester) async {
    await tester.pumpWidget(_host(ZAlphabetIndexBar(onLetter: (_) {})));
    expect(find.byType(ZAlphabetIndexBar), findsOneWidget);
    // ignore: avoid_dynamic_calls
    final w = tester.widget(find.byType(ZAlphabetIndexBar));
    expect(w, isA<StatelessWidget>());
  });

  testWidgets('tap sur lettre active → onLetter appelé 1× avec la bonne lettre'
      ' (AC2)', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(
        onLetter: calls.add,
        activeLetters: const {'M'},
        enableScrub: false,
      ),
    ));

    await tester.tap(find.text('M'));
    expect(calls, ['M']);
  });

  testWidgets('tap sur lettre inerte → onLetter NON appelé (AC2)',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(
        onLetter: calls.add,
        activeLetters: const {'M'},
        enableScrub: false,
      ),
    ));

    // 'A' n'est pas dans activeLetters → inerte (onTap: null).
    await tester.tap(find.text('A'), warnIfMissed: false);
    expect(calls, isEmpty);
  });

  testWidgets('activeLetters == null → toutes actives (AC2)', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: calls.add, enableScrub: false),
    ));
    await tester.tap(find.text('Q'));
    expect(calls, ['Q']);
  });

  testWidgets(
      'tap en config PAR DÉFAUT (enableScrub non fourni ⇒ true) → onLetter '
      'appelé : le GestureDetector de scrub ne vole pas le tap (AC2/M-1)',
      (tester) async {
    final calls = <String>[];
    // PAS de enableScrub:false → on teste le parcours réellement livré (défaut
    // true), où la colonne est enveloppée d'un GestureDetector de scrub : une
    // régression d'arène de gestes avalant le tap rougirait ce test.
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: calls.add, activeLetters: const {'M'}),
    ));

    await tester.tap(find.text('M'));
    expect(calls, ['M']);
  });

  testWidgets(
      'scrub vertical (enableScrub par défaut) → onLetter émis pour les lettres '
      'survolées (AC2)', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: calls.add),
    ));

    // Un glissé vertical sur la barre doit émettre au moins une lettre (le
    // GestureDetector onVerticalDrag* est câblé quand enableScrub est vrai).
    final bar = find.byType(ZAlphabetIndexBar);
    final center = tester.getCenter(bar);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.up();
    await tester.pump();
    expect(calls, isNotEmpty,
        reason: 'le scrub par défaut doit émettre des lettres');
  });

  testWidgets('currentLetter → Semantics(selected: true) + mise en évidence'
      ' (AC3)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: (_) {}, currentLetter: 'C'),
    ));

    // La lettre courante porte selected: true (canal a11y non-couleur).
    expect(
      tester.getSemantics(find.bySemanticsLabel('C')),
      isSemantics(isSelected: true),
    );

    // Canal non-couleur additionnel : graisse bold sur la lettre courante.
    final currentText = tester.widget<Text>(find.text('C'));
    expect(currentText.style?.fontWeight, FontWeight.bold);
    // Une lettre non-courante reste en graisse normale.
    final otherText = tester.widget<Text>(find.text('D'));
    expect(otherText.style?.fontWeight, FontWeight.normal);

    handle.dispose();
  });

  testWidgets('Semantics(button/enabled) par lettre + cible ≥ 48 dp (AC4)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(
        onLetter: (_) {},
        activeLetters: const {'B'},
        enableScrub: false,
      ),
    ));

    expect(
      tester.getSemantics(find.bySemanticsLabel('B')),
      isSemantics(isButton: true, isEnabled: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('A')),
      isSemantics(isButton: true, isEnabled: false),
    );

    // Cible tactile ≥ 48 dp en LARGEUR par lettre (colonne de scrub
    // accessible ; un index A→Z à 48 dp de haut par lettre dépasserait tout
    // écran — AD-13 admet la zone de scrub ≥ 48 dp de large comme cible).
    final size = tester.getSize(
      find.ancestor(
        of: find.text('B'),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(size.width, greaterThanOrEqualTo(48.0));

    handle.dispose();
  });

  testWidgets('rendu sous Directionality.rtl sans exception (AC4)',
      (tester) async {
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: (_) {}, currentLetter: 'C'),
      direction: TextDirection.rtl,
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('letters vide → SizedBox.shrink() (D4)', (tester) async {
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(onLetter: (_) {}, letters: const []),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsNothing);
    final shrink = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(ZAlphabetIndexBar),
        matching: find.byType(SizedBox),
      ),
    );
    expect(shrink.width, 0.0);
    expect(shrink.height, 0.0);
  });

  testWidgets('currentLetter hors de letters → aucune mise en évidence, pas de'
      ' throw (D4)', (tester) async {
    await tester.pumpWidget(_host(
      ZAlphabetIndexBar(
        onLetter: (_) {},
        letters: const ['A', 'B'],
        currentLetter: 'Z',
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text('A')).style?.fontWeight,
        FontWeight.normal);
  });

  test('le fichier source n\'importe AUCUN manager ni routeur (AC1/AD-2)', () {
    final source = _readSource('z_alphabet_index_bar.dart');
    final imports = source
        .split('\n')
        .where((l) => l.trimLeft().startsWith('import '))
        .join('\n');
    expect(imports.contains('flutter_riverpod'), isFalse);
    expect(imports.contains('package:get/'), isFalse);
    expect(imports.contains('package:provider/'), isFalse);
    expect(imports.contains('go_router'), isFalse);
    expect(imports.contains('WidgetRef'), isFalse);
  });
}
