import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Lit un fichier source de présentation quel que soit le cwd (racine du repo
/// ou racine du package).
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

/// Pousse une route `slide` sous [direction] et retourne le signe de l'offset
/// horizontal du `SlideTransition` entrant en cours d'animation.
Future<double> _slideDxDuringPush(
  WidgetTester tester,
  TextDirection direction,
) async {
  await tester.pumpWidget(
    MaterialApp(
      // Clé unique par direction : force un arbre neuf (sinon l'élément Navigator
      // est réutilisé entre les deux appels et conserve sa pile de routes).
      key: ValueKey(direction),
      // La direction doit envelopper le Navigator/Overlay (au-dessus de `home`),
      // sinon les routes poussées la lisent au niveau app (LTR par défaut).
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                zPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('NEXT')),
                ),
              ),
              child: const Text('GO'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('GO'));
  await tester.pump(); // démarre la transition
  await tester.pump(const Duration(milliseconds: 50)); // mi-animation

  final slide = tester.widget<SlideTransition>(
    find.ancestor(
      of: find.text('NEXT'),
      matching: find.byType(SlideTransition),
    ).first,
  );
  final dx = slide.position.value.dx;
  await tester.pumpAndSettle();
  return dx;
}

void main() {
  testWidgets('la route slide part d\'un offset de signe OPPOSÉ LTR vs RTL'
      ' (AC5, en contexte)', (tester) async {
    final ltrDx = await _slideDxDuringPush(tester, TextDirection.ltr);
    final rtlDx = await _slideDxDuringPush(tester, TextDirection.rtl);

    // LTR : entre depuis la droite (+) ; RTL : depuis la gauche (-).
    expect(ltrDx, greaterThan(0.0));
    expect(rtlDx, lessThan(0.0));
    // Signes opposés (inversion matérialisée en contexte).
    expect(ltrDx.sign, -rtlDx.sign);
  });

  testWidgets('la route fade produit un FadeTransition (insensible direction)'
      ' (AC5)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  zPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('NEXT')),
                    transition: ZRouteTransition.fade,
                  ),
                ),
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.ancestor(
        of: find.text('NEXT'),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
    // Aucune composante de slide pour la transition fade de zPageRoute.
    expect(
      find.ancestor(
        of: find.text('NEXT'),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  test('le fichier source n\'importe AUCUN routeur (go_router) ni manager (AC6)',
      () {
    final source = _readSource('z_transitions.dart');
    final lines = source.split('\n');
    final imports =
        lines.where((l) => l.trimLeft().startsWith('import ')).join('\n');
    expect(imports.contains('go_router'), isFalse);
    expect(imports.contains('flutter_riverpod'), isFalse);
    expect(imports.contains('package:get/'), isFalse);
    expect(imports.contains('package:provider/'), isFalse);
    // Aucun USAGE de types routeur : scan des lignes de CODE uniquement (la prose
    // du dartdoc cite ces types pour documenter leur neutralisation — dette
    // EX-UI.9 : ne jamais scanner les commentaires).
    final code = lines
        .where((l) {
          final t = l.trimLeft();
          return !t.startsWith('///') && !t.startsWith('//') &&
              !t.startsWith('*') && !t.startsWith('/*');
        })
        .join('\n');
    expect(code.contains('CustomTransitionPage'), isFalse);
    expect(code.contains('GoRouterState'), isFalse);
  });
}
