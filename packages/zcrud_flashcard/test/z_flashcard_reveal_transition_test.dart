/// AC2 — `ZRevealTransition { flip3d, fade }` : flip 3D **MAISON**, un test par
/// valeur de l'enum (SU-2).
///
/// Les deux valeurs doivent produire des **arbres de widgets distincts** : c'est
/// ce qui rend l'enum falsifiable. Un câblage qui ignorerait la valeur (ex. `fade`
/// branché sur le chemin `flip3d`) laisserait passer un test qui se contenterait
/// de vérifier « la réponse s'affiche » — ici, la **rotation Y** discrimine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const ZFlashcard _card = ZFlashcard(question: 'Q', answer: 'A');

Future<void> _pump(WidgetTester tester, ZRevealTransition transition) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: _card,
                revealTransition: transition,
              ),
            ),
          ),
        ),
      ),
    );

/// Vrai si [m] porte une **rotation autour de Y** non nulle.
///
/// Pour `rotateY(θ)` : `entry(0,2) = sin θ` et `entry(2,0) = -sin θ`. On ne teste
/// QUE ces coefficients hors-diagonale — une translation, une mise à l'échelle ou
/// la seule perspective (`setEntry(3, 2, …)`) ne les touchent pas. La garde ne
/// peut donc pas confondre le flip avec un `Transform` interne de Material.
bool hasYRotation(Matrix4 m) =>
    m.entry(0, 2).abs() > 1e-6 || m.entry(2, 0).abs() > 1e-6;

/// Vrai si l'arbre courant porte, quelque part, une rotation Y.
bool anyYRotation(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .any((t) => hasYRotation(t.transform));

/// Vrai si l'arbre courant porte une opacité en cours de variation.
bool anyPartialOpacity(WidgetTester tester) => tester
    .widgetList<Opacity>(find.byType(Opacity))
    .any((o) => o.opacity > 0.0 && o.opacity < 1.0);

void main() {
  test('AC2 — ZRevealTransition est un ENUM à exactement 2 valeurs', () {
    // « Un enum, JAMAIS un booléen » (convention du spine). Si une 3ᵉ valeur
    // apparaît, ce test rougit et force un cas de rendu dédié — le `switch` de
    // production, lui, casse la COMPILATION (exhaustif, sans `default`).
    expect(ZRevealTransition.values, hasLength(2));
    expect(ZRevealTransition.values,
        containsAll(<Object>[ZRevealTransition.flip3d, ZRevealTransition.fade]));
  });

  group('AC2 — un test par valeur de l\'enum', () {
    // Exigé mot pour mot par l'epic : CHAQUE valeur révèle bel et bien.
    for (final transition in ZRevealTransition.values) {
      testWidgets('${transition.name} — le tap révèle la réponse',
          (tester) async {
        await _pump(tester, transition);
        expect(find.text('A'), findsNothing);

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pumpAndSettle();

        expect(find.text('A'), findsOneWidget);
        expect(find.text('Q'), findsNothing);
      });
    }
  });

  group('AC2 — flip3d : rotation Y MAISON à mi-course', () {
    testWidgets('à mi-animation, un Transform porte une rotation Y',
        (tester) async {
      await _pump(tester, ZRevealTransition.flip3d);
      expect(anyYRotation(tester), isFalse,
          reason: 'au repos, aucune rotation ne doit être appliquée');

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump(); // démarre le controller
      await tester.pump(const Duration(milliseconds: 50)); // 50/250 = 20 %

      expect(anyYRotation(tester), isTrue,
          reason: 'flip3d SANS rotation Y à mi-course : l\'enum est ignoré '
              '(chemin `fade` câblé sur `flip3d` ?)');

      await tester.pumpAndSettle();
    });

    testWidgets('la matrice porte une PERSPECTIVE (setEntry(3, 2, …))',
        (tester) async {
      // Sans perspective, `rotateY` ne produit qu'un écrasement horizontal :
      // il n'y a aucun volume, donc aucun « flip 3D ».
      await _pump(tester, ZRevealTransition.flip3d);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rotating = tester
          .widgetList<Transform>(find.byType(Transform))
          .where((t) => hasYRotation(t.transform))
          .toList();
      expect(rotating, isNotEmpty);
      expect(rotating.any((t) => t.transform.entry(3, 2) != 0.0), isTrue,
          reason: 'aucune perspective : le flip est plat, pas 3D');

      await tester.pumpAndSettle();
    });

    testWidgets(
      'la face BASCULE à mi-course (θ = π/2) et non à la fin',
      (tester) async {
        await _pump(tester, ZRevealTransition.flip3d);
        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pump();

        // Avant mi-course : la face QUESTION est encore présentée.
        await tester.pump(const Duration(milliseconds: 50)); // 20 %
        expect(find.text('Q'), findsOneWidget);
        expect(find.text('A'), findsNothing);

        // Après mi-course : la face RÉPONSE a pris le relais.
        await tester.pump(const Duration(milliseconds: 100)); // 60 %
        expect(find.text('A'), findsOneWidget);
        expect(find.text('Q'), findsNothing);

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'la face ARRIÈRE est CONTRE-ROTÉE (sinon elle s\'afficherait en miroir)',
      (tester) async {
        // Piège classique du flip maison : sans `..rotateY(π)` sur la face
        // arrière, le dos apparaît inversé horizontalement. Discriminant : à
        // 60 % (θ = 0.6π), la rotation NETTE appliquée au dos doit être
        // θ + π (soit sin(1.6π) < 0), et non θ seul (sin(0.6π) > 0).
        await _pump(tester, ZRevealTransition.flip3d);
        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150)); // 60 %

        final back = tester
            .widgetList<Transform>(find.byType(Transform))
            .where((t) => hasYRotation(t.transform))
            .toList();
        expect(back, isNotEmpty);
        expect(
          back.any((t) => t.transform.entry(0, 2) < 0),
          isTrue,
          reason: 'la face arrière n\'est PAS contre-rotée : le dos de la carte '
              's\'affiche EN MIROIR (sin(0.6π) > 0 ⇒ contre-rotation absente)',
        );

        await tester.pumpAndSettle();
      },
    );
  });

  group('AC2 — fade : AUCUNE rotation, une opacité qui varie', () {
    testWidgets('à mi-animation, aucune rotation Y n\'est appliquée',
        (tester) async {
      await _pump(tester, ZRevealTransition.fade);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(anyYRotation(tester), isFalse,
          reason: 'fade AVEC rotation Y : l\'enum est ignoré (chemin `flip3d` '
              'câblé sur `fade` ?)');

      await tester.pumpAndSettle();
    });

    testWidgets('à mi-animation, une opacité intermédiaire est appliquée',
        (tester) async {
      await _pump(tester, ZRevealTransition.fade);
      expect(anyPartialOpacity(tester), isFalse,
          reason: 'au repos, la face doit être pleinement opaque');

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(anyPartialOpacity(tester), isTrue,
          reason: 'fade sans variation d\'opacité : il n\'y a aucun fondu');

      await tester.pumpAndSettle();
    });
  });

  group('AC2 — les deux valeurs produisent des arbres DISTINCTS', () {
    testWidgets('flip3d ⇒ rotation ET pas de fondu ; fade ⇒ l\'inverse',
        (tester) async {
      await _pump(tester, ZRevealTransition.flip3d);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final flipRotates = anyYRotation(tester);
      final flipFades = anyPartialOpacity(tester);
      await tester.pumpAndSettle();

      await _pump(tester, ZRevealTransition.fade);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final fadeRotates = anyYRotation(tester);
      final fadeFades = anyPartialOpacity(tester);
      await tester.pumpAndSettle();

      expect(flipRotates, isTrue);
      expect(fadeRotates, isFalse);
      expect(fadeFades, isTrue);
      expect(flipFades, isFalse);
    });
  });

  group('🔴 D13 — `transitionDuration` : la branche de didUpdateWidget est '
      'RÉELLEMENT exercée', () {
    // ⚠️ Aucun test ne touchait `transitionDuration` : supprimer purement et
    // simplement la branche `didUpdateWidget` qui l'applique laissait 328/328
    // VERT. Le paramètre était donc du code non gardé — une future
    // « simplification » l'aurait retiré sans que rien ne bronche.

    Future<void> pumpDuree(WidgetTester tester, Duration duree) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(
                    card: _card,
                    transitionDuration: duree,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets(
      'une durée CHANGÉE à chaud s\'applique au controller EXISTANT',
      (tester) async {
        await pumpDuree(tester, const Duration(milliseconds: 250));
        // Changement à chaud : c'est `didUpdateWidget` qui doit reporter la
        // nouvelle durée SUR le controller déjà créé (jamais le recréer, AD-2).
        await pumpDuree(tester, const Duration(milliseconds: 800));

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // ⚠️ `hasRunningAnimations` ne discrimine pas (le ripple de l'`InkWell`
        // tourne aussi) : on lit l'ARBRE. À 400 ms d'un flip de 800 ms, la
        // rotation est à mi-course ; d'un flip de 250 ms, elle est retombée sur
        // l'identité (cf. contre-preuve ci-dessous).
        expect(anyYRotation(tester), isTrue,
            reason: 'à 400 ms le flip est DÉJÀ terminé : la nouvelle durée '
                '(800 ms) n\'a pas été reportée sur le controller — '
                '`didUpdateWidget` ignore `transitionDuration`');

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'CONTRE-PREUVE — la sonde a du POUVOIR : avec la durée COURTE, le flip '
      'est bien terminé au même instant',
      (tester) async {
        // Sans ce cas, l'assertion `isTrue` ci-dessus resterait verte si le
        // widget animait toujours plus longtemps que la fenêtre observée.
        await pumpDuree(tester, const Duration(milliseconds: 250));

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(anyYRotation(tester), isFalse,
            reason: 'la sonde ne distingue PAS les deux durées : elle ne prouve '
                'rien sur l\'application de `transitionDuration`');
      },
    );
  });

  group('AC2/AD-2 — le AnimationController est STABLE', () {
    testWidgets('un rebuild ne recrée pas le controller (aucun ticker fuité)',
        (tester) async {
      await _pump(tester, ZRevealTransition.flip3d);
      final state1 = tester.state(find.byType(ZFlashcardReviewCard));

      // Rebuild du parent avec les mêmes propriétés.
      await _pump(tester, ZRevealTransition.flip3d);
      final state2 = tester.state(find.byType(ZFlashcardReviewCard));

      expect(identical(state1, state2), isTrue,
          reason: 'le State a été recréé : le controller (et le ValueNotifier) '
              'le seraient aussi à chaque rebuild — AD-2 violé');
      // `SingleTickerProviderStateMixin` LÈVE si un second controller est créé
      // sans que le premier soit disposé : le test échouerait ici.
      expect(tester.takeException(), isNull);
    });
  });
}
