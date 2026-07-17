/// AC7 — `ZTimerDisplay { hidden, elapsed, countdown }` : le temps est
/// **TOUJOURS mesuré**, affiché **selon l'enum uniquement** (FR-SU4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

/// Sonde de comptage **DANS le sous-arbre du contenu** (leçon su-2 **D5** : une
/// sonde posée sur un **sibling** est structurellement aveugle).
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
  String timerText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(K.timer)).data!;

  group('🔒 AC7 — le temps est mesuré MÊME en `hidden` (garde centrale)', () {
    testWidgets(
      '🔴 (1) hidden ⇒ AUCUN widget de minuteur, MAIS timeTaken > 0 (R3-I7)',
      (tester) async {
        final spy = SpyEvaluationPort();
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              evaluationPort: spy,
              // `hidden` est le DÉFAUT (FR-SU4) — explicite ici pour la lisibilité.
              timerDisplay: ZTimerDisplay.hidden,
            ),
          ),
        );
        expect(
          find.byKey(K.timer),
          findsNothing,
          reason: 'en `hidden`, aucun minuteur ne doit être dans l\'arbre',
        );

        await tester.pump(const Duration(seconds: 3));
        await tester.enterText(find.byKey(K.answerField), 'r');
        await tester.pump();
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        expect(spy.request!.timeTaken, isNotNull);
        expect(
          spy.request!.timeTaken!.inMilliseconds,
          greaterThan(0),
          reason:
              'le Stopwatch n\'est pas armé en `hidden` : masquer le minuteur '
              'est un choix d\'UI, PAS un choix de télémétrie (R3-I7)',
        );
      },
    );

    testWidgets('`hidden` est bien le DÉFAUT (FR-SU4)', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(card: writtenCard(), mode: ZReviewMode.learn),
        ),
      );
      expect(find.byKey(K.timer), findsNothing);
    });
  });

  group(
    'AC7 — elapsed vs countdown : deux textes évoluant en SENS OPPOSÉS',
    () {
      testWidgets('🔴 (2) elapsed CROÎT ; countdown DÉCROÎT', (tester) async {
        // elapsed
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              key: const ValueKey<String>('e'),
              card: writtenCard(),
              mode: ZReviewMode.learn,
              timerDisplay: ZTimerDisplay.elapsed,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final e1 = timerText(tester);
        await tester.pump(const Duration(seconds: 1));
        final e2 = timerText(tester);

        // countdown
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              key: const ValueKey<String>('c'),
              card: writtenCard(),
              mode: ZReviewMode.learn,
              timerDisplay: ZTimerDisplay.countdown,
              timeLimit: const Duration(minutes: 5),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final c1 = timerText(tester);
        await tester.pump(const Duration(seconds: 1));
        final c2 = timerText(tester);

        expect(e1, isNot(e2), reason: 'le temps écoulé doit évoluer');
        expect(c1, isNot(c2), reason: 'le compte à rebours doit évoluer');
        // SENS OPPOSÉS : elapsed monte (00:01 → 00:02), countdown descend
        // (04:59 → 04:58).
        expect(e1.compareTo(e2), lessThan(0), reason: 'elapsed doit CROÎTRE');
        expect(
          c1.compareTo(c2),
          greaterThan(0),
          reason: 'countdown doit DÉCROÎTRE',
        );
      });

      testWidgets(
        '🔴 (4) countdown SANS timeLimit ⇒ dégrade en elapsed (AD-10)',
        (tester) async {
          await tester.pumpWidget(
            host(
              ZFlashcardAnswerInput(
                card: writtenCard(),
                mode: ZReviewMode.learn,
                timerDisplay: ZTimerDisplay.countdown,
                // timeLimit ABSENT : jamais un rebours depuis `null`.
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          final t1 = timerText(tester);
          await tester.pump(const Duration(seconds: 1));
          final t2 = timerText(tester);

          expect(tester.takeException(), isNull);
          expect(
            t1.compareTo(t2),
            lessThan(0),
            reason:
                'sans timeLimit, `countdown` doit se comporter comme `elapsed`',
          );
        },
      );

      testWidgets('countdown ÉPUISÉ s\'arrête à ZÉRO (jamais de négatif)', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              timerDisplay: ZTimerDisplay.countdown,
              timeLimit: const Duration(seconds: 2),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(timerText(tester), '00:00');
        expect(tester.takeException(), isNull);

        // 🔒 La saisie reste POSSIBLE : su-3 n'impose AUCUNE soumission forcée
        // (aucun AC ne l'exige — l'inventer serait du périmètre volé).
        expect(find.byKey(K.answerField), findsOneWidget);
        expect(find.byKey(K.submit), findsOneWidget);
      });
    },
  );

  group('🔒 AC7/SM-1 — le tick ne reconstruit QUE la tranche du minuteur', () {
    testWidgets('🔴 (3) 3 ticks ⇒ le CONTENU de carte n\'est PAS reconstruit '
        '(sonde DANS le sous-arbre visé — R3-I7b)', (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            timerDisplay: ZTimerDisplay.elapsed,
            contentBuilder: (context, content) =>
                _CountingContent(content: content, onBuild: () => buildCount++),
          ),
        ),
      );
      final initial = buildCount;

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // Le minuteur, lui, a bien avancé (le test n'est pas vide de sens).
      expect(timerText(tester), '00:03');
      expect(
        buildCount - initial,
        0,
        reason:
            'le tick a été hissé au niveau de la carte : chaque seconde '
            'reconstruit tout l\'arbre (R3-I7b)',
      );
    });
  });

  group('🔒 AC7 — aucun tick orphelin après dispose', () {
    testWidgets('🔴 (5) après démontage, aucune exception (R3-I7c)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            timerDisplay: ZTimerDisplay.elapsed,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Démontage.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      // Le temps continue de passer : un ticker non annulé tirerait ICI, sur un
      // `ValueNotifier` déjà `dispose`é ⇒ exception.
      await tester.pump(const Duration(seconds: 5));

      expect(
        tester.takeException(),
        isNull,
        reason:
            'un Timer a survécu au dispose (fuite) — il tire sur un état '
            'détruit (R3-I7c)',
      );
    });
  });

  group('🔴 AC7 — `timerDisplay` varie sur un `State` VIVANT (didUpdateWidget)', () {
    // 🔴 ANGLE MORT STRUCTUREL du reste de ce fichier, comblé ici : tous les
    // autres tests montent chaque configuration **À FROID** (un `pumpWidget` par
    // mode, avec des `key` distinctes ⇒ `State` NEUF, `initState` rejoué). AUCUN
    // ne faisait varier `timerDisplay` sur un `State` **vivant** — or le ticker
    // n'était armé qu'en `initState`, et `didUpdateWidget` était **ABSENT**
    // (grep RC=1).
    //
    // ⚠️ `timerDisplay` est une **prop mutable**, et `hidden` est le **DÉFAUT** :
    // tout hôte qui rend le minuteur optionnel tombait dessus.

    /// Monte la surface **au même emplacement, avec la MÊME `key`** ⇒ le `State`
    /// est **conservé** (`initState` n'est PAS rejoué). C'est le point du test.
    Future<void> pumpWith(
      WidgetTester tester,
      ZTimerDisplay display, {
      Duration? timeLimit,
    }) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            key: const ValueKey<String>('surface-stable'),
            card: writtenCard(),
            mode: ZReviewMode.learn,
            timerDisplay: display,
            timeLimit: timeLimit,
          ),
        ),
      );
    }

    String timerText(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(K.timer)).data!;

    testWidgets(
      '🔴 hidden → elapsed à chaud : le minuteur COMPTE (il restait figé à '
      '00:00 POUR TOUJOURS)',
      (tester) async {
        await pumpWith(tester, ZTimerDisplay.hidden);
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.byKey(K.timer),
          findsNothing,
          reason: 'hidden ⇒ pas de minuteur',
        );

        // L'utilisateur active le minuteur dans les réglages de session.
        await pumpWith(tester, ZTimerDisplay.elapsed);
        expect(find.byKey(K.timer), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        expect(
          timerText(tester),
          '00:03',
          reason:
              '🔴 le DÉFAUT EXACT : le ticker n\'était armé qu\'en '
              '`initState` ⇒ l\'affichage restait à 00:00 pendant que le '
              '`Stopwatch` comptait et que `timeTaken` partait au barème — '
              'l\'apprenant CHRONOMÉTRÉ SANS LE VOIR, sans exception ni test rouge',
        );
      },
    );

    testWidgets(
      '🔴 elapsed → hidden : le ticker est ANNULÉ (il survivait au masquage '
      'et tirait 1×/s SANS AUCUN abonné)',
      (tester) async {
        await pumpWith(tester, ZTimerDisplay.elapsed);
        await tester.pump(const Duration(seconds: 2));
        expect(timerText(tester), '00:02');

        await pumpWith(tester, ZTimerDisplay.hidden);
        expect(find.byKey(K.timer), findsNothing);

        // 🔒 DISCRIMINANT : si un `Timer.periodic` survivait, il resterait des
        // timers en attente. `pumpAndSettle` d'un arbre sans animation ne les voit
        // pas — on interroge donc directement l'ordonnanceur de temps virtuel.
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pump(const Duration(seconds: 60));
        expect(tester.takeException(), isNull);

        // Et au retour, l'affichage est RESYNCHRONISÉ sur la mesure, jamais repris
        // là où il s'était arrêté (une reprise à 00:02 MENTIRAIT sur le temps
        // réellement écoulé pendant le masquage : deux horloges qui divergent).
        await pumpWith(tester, ZTimerDisplay.elapsed);
        expect(find.byKey(K.timer), findsOneWidget);
        expect(
          timerText(tester),
          '00:00',
          reason:
              'le temps MURAL du test est ~0 ms (le `Stopwatch` n\'est pas '
              '*fakeable*) : la resynchro sur `_stopwatch` rend donc 00:00 — la '
              'reprise du COMPTEUR SYNTHÉTIQUE aurait rendu 00:02',
        );
      },
    );

    testWidgets(
      '🔒 un rebuild SANS changement ne resynchronise PAS l\'affichage',
      (tester) async {
        // Garde-fou du correctif lui-même : `_syncTicker` ne doit ré-armer que
        // lorsque le ticker est absent — sinon chaque rebuild de l'hôte
        // remettrait l'affichage à la valeur du `Stopwatch` (≈ 0 en test) et le
        // minuteur n'avancerait JAMAIS.
        await pumpWith(tester, ZTimerDisplay.elapsed);
        await tester.pump(const Duration(seconds: 4));
        expect(timerText(tester), '00:04');

        await pumpWith(tester, ZTimerDisplay.elapsed); // rebuild identique
        expect(
          timerText(tester),
          '00:04',
          reason: 'un rebuild neutre ne doit rien resynchroniser',
        );
        await tester.pump(const Duration(seconds: 1));
        expect(timerText(tester), '00:05', reason: 'et le ticker continue');
      },
    );

    testWidgets('🔵 countdown ÉPUISÉ ⇒ le ticker s\'ARRÊTE (il reconstruisait '
        'indéfiniment un 00:00 immuable)', (tester) async {
      await pumpWith(
        tester,
        ZTimerDisplay.countdown,
        timeLimit: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(timerText(tester), '00:01');

      await tester.pump(const Duration(seconds: 1)); // épuisé
      expect(timerText(tester), '00:00');

      // 🔒 DISCRIMINANT : plus aucun timer en attente une fois le rebours à zéro.
      await tester.pump(const Duration(seconds: 30));
      expect(timerText(tester), '00:00');
      expect(tester.takeException(), isNull);
    });
  });
}
