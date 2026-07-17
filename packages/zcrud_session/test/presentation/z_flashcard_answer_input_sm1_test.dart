/// AC10 — SM-1 : taper 100 caractères ne reconstruit QUE le champ
/// (NFR-SU2 — **objectif produit n°1** : le bug historique que zcrud existe pour
/// corriger).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Sonde de comptage **DANS LE SOUS-ARBRE VISÉ** (le `contentBuilder`).
///
/// ⚠️ **Leçon D5 de su-2** : la sonde de su-2 mesurait un **sibling** — elle
/// était **structurellement aveugle** (elle n'aurait pas bougé même si le
/// contenu s'était reconstruit 100 fois). Ici la sonde EST le contenu rendu par
/// le slot AD-40 : ce qu'elle compte est exactement ce qu'on prétend mesurer.
class _CountingContent extends StatelessWidget {
  const _CountingContent({required this.content, required this.onBuild});

  final String content;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(content);
  }
}

void main() {
  ZFlashcard writtenCard() => const ZFlashcard(
    question: 'Expliquez le régime du transit douanier.',
    type: ZFlashcardType.openQuestion,
    answer: 'attendu',
  );

  Future<int> pumpAndType(WidgetTester tester, int chars) async {
    var buildCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            contentBuilder: (context, content) =>
                _CountingContent(content: content, onBuild: () => buildCount++),
          ),
        ),
      ),
    );
    final initial = buildCount;

    await tester.tap(find.byKey(_WrittenKeys.field));
    await tester.pump();

    // Frappe caractère par caractère : le chemin RÉEL d'un utilisateur (un seul
    // `enterText` de 100 chars ne prouverait rien — c'est UNE mutation).
    final buffer = StringBuffer();
    for (var i = 0; i < chars; i++) {
      buffer.write('a');
      await tester.enterText(find.byKey(_WrittenKeys.field), buffer.toString());
      await tester.pump();
    }
    return buildCount - initial;
  }

  testWidgets('🔴 100 frappes ⇒ le CONTENU de carte n\'est PAS reconstruit '
      '(sonde DANS le sous-arbre visé — leçon D5)', (tester) async {
    final rebuilds = await pumpAndType(tester, 100);
    expect(
      rebuilds,
      0,
      reason:
          'le slot AD-40 s\'est reconstruit $rebuilds fois pendant la '
          'frappe : la surface fait un `setState` global (R3-I10b)',
    );
  });

  testWidgets(
    '🔬 DISCRIMINANT STRUCTUREL : 200 caractères ne construisent pas 2× plus '
    'que 100 (un seuil absolu peut être « ajusté », ce RAPPORT non)',
    (tester) async {
      // Leçon su-2 D5 : un test qui affirme « < N rebuilds » invite à monter N le
      // jour où il rougit. Un RAPPORT, lui, encode la propriété : « le coût de la
      // frappe ne dépend pas du nombre de frappes ».
      final at100 = await pumpAndType(tester, 100);
      final at200 = await pumpAndType(tester, 200);
      expect(at100, 0);
      expect(
        at200,
        at100,
        reason:
            'le nombre de reconstructions du contenu doit être INDÉPENDANT '
            'du nombre de frappes (100 ⇒ $at100, 200 ⇒ $at200)',
      );
    },
  );

  testWidgets(
    '🔴 le TextEditingController est STABLE entre deux builds (R3-I10)',
    (tester) async {
      final key = GlobalKey();
      Widget host(String title) => MaterialApp(
        home: Scaffold(
          // Un titre différent force un rebuild du parent SANS remplacer
          // l'état (même type + même key ⇒ `State` conservé).
          appBar: AppBar(title: Text(title)),
          body: ZFlashcardAnswerInput(
            key: key,
            card: writtenCard(),
            mode: ZReviewMode.learn,
          ),
        ),
      );

      await tester.pumpWidget(host('a'));
      final first = tester
          .widget<TextFormField>(find.byKey(_WrittenKeys.field))
          .controller;

      await tester.pumpWidget(host('b'));
      await tester.pump();
      final second = tester
          .widget<TextFormField>(find.byKey(_WrittenKeys.field))
          .controller;

      expect(first, isNotNull);
      expect(
        identical(first, second),
        isTrue,
        reason:
            'le controller a été RECRÉÉ au rebuild ⇒ perte de focus et de '
            'curseur à chaque frappe (le bug historique, AD-2)',
      );
    },
  );

  testWidgets(
    '🔴 le focus est CONSERVÉ et le curseur reste en fin de texte après 100 '
    'frappes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(_WrittenKeys.field));
      await tester.pump();

      final buffer = StringBuffer();
      for (var i = 0; i < 100; i++) {
        buffer.write('a');
        await tester.enterText(
          find.byKey(_WrittenKeys.field),
          buffer.toString(),
        );
        await tester.pump();
      }

      final field = tester.widget<TextFormField>(
        find.byKey(_WrittenKeys.field),
      );
      final controller = field.controller!;
      expect(controller.text.length, 100);
      expect(
        controller.selection.baseOffset,
        100,
        reason:
            'le curseur a été renvoyé ailleurs ⇒ une valeur a été ré-injectée '
            'pendant la frappe (saisie à sens unique violée)',
      );

      final focusNode = tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode;
      expect(
        focusNode.hasFocus,
        isTrue,
        reason: 'perte de focus pendant la frappe',
      );
    },
  );

  group('AC10 — 🔴 le builder du slot RÉSOLU est STABLE entre builds (R3-I10c)', () {
    // 🔴 CORRECTION du code-review su-3 — ce test était TAUTOLOGIQUE.
    //
    // Il faisait `const a = ZFlashcardDefaultContent.builder; const b = …;
    // expect(identical(a, b), isTrue)` sur deux tear-offs déclarés **dans le test
    // lui-même** : il testait la **canonicalisation de Dart**, vraie que
    // `ZFlashcardAnswerInput` existe ou non. Puis `find.byType(...)` prouvait la
    // **PRÉSENCE** du widget par défaut, pas son **ASSOCIATION** à un tear-off —
    // une closure `?? (c,s) => ZFlashcardDefaultContent(content: s)` le rend
    // **tout aussi bien**. Injection R3-I10c REJOUÉE sur la prod : **198/198
    // VERTS**. Le verrou était **factice** — et un verrou factice est PIRE qu'un
    // verrou absent, parce qu'il se donne pour une preuve.
    //
    // La résolution vit désormais dans `ZFlashcardAnswerInput.resolveContentBuilder`
    // (`@visibleForTesting`) — la VOIE UNIQUE, et le seul siège lisible du
    // « builder résolu » qu'AC10 prescrit. Ces tests la traversent RÉELLEMENT.

    test(
      '🔴 deux résolutions successives rendent le MÊME builder (identité)',
      () {
        // ⚠️ Ce que ce test lit est le RÉSULTAT DE LA PROD (`?? …` de
        // `resolveContentBuilder`), jamais deux constantes de son cru. Sous
        // l'injection R3-I10c (tear-off → closure), chaque appel réalloue ⇒ ROUGE.
        final first = ZFlashcardAnswerInput.resolveContentBuilder(null);
        final second = ZFlashcardAnswerInput.resolveContentBuilder(null);
        expect(
          identical(first, second),
          isTrue,
          reason:
              '🔴 le builder RÉSOLU est réalloué d\'un appel à l\'autre ⇒ '
              'le sous-arbre du slot AD-40 perd sa stabilité de rebuild '
              '(AC10 : « jamais `?? (c,s) => …` »)',
        );
      },
    );

    test('🔴 le défaut résolu EST le tear-off statique du slot', () {
      // Pin de l'IDENTITÉ ATTENDUE, pas d'une simple stabilité : une closure
      // stable (mémoïsée) satisferait le test ci-dessus mais pas celui-ci.
      expect(
        identical(
          ZFlashcardAnswerInput.resolveContentBuilder(null),
          ZFlashcardDefaultContent.builder,
        ),
        isTrue,
        reason: 'le défaut du slot doit être le tear-off statique stable',
      );
    });

    test('🔒 un builder INJECTÉ est rendu VERBATIM (jamais ré-enveloppé)', () {
      // Une prod qui envelopperait l'injection (`?? …` mis à part) casserait tout
      // autant l'identité — et l'hôte perdrait le contrôle de son slot.
      Widget injected(BuildContext c, String s) => const SizedBox.shrink();
      expect(
        identical(
          ZFlashcardAnswerInput.resolveContentBuilder(injected),
          injected,
        ),
        isTrue,
      );
    });

    testWidgets('et le défaut est bien ATTEINT quand l\'hôte n\'injecte rien', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
            ),
          ),
        ),
      );
      expect(find.byType(ZFlashcardDefaultContent), findsOneWidget);
    });
  });
}

/// Clés du champ de rédaction (miroir des `static const` privées du widget).
abstract final class _WrittenKeys {
  static const ValueKey<String> field = ValueKey<String>('zAnswerField');
}
