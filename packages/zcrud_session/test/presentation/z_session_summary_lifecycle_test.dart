/// 🎯 AC9 (SU-5) — **robustesse & cycle de vie** (AD-10) : jamais de crash,
/// jamais d'exception — et **la branche de repli est ATTEINTE**.
///
/// 🔴 **Défaut consigné, interdit de récidive** : « branche de repli jamais
/// atteinte ». Le cas « session vide » n'assère donc **pas** seulement l'absence
/// d'exception (qui serait vraie même si le widget rendait un écran **blanc**) :
/// il **OBSERVE le rendu**. Un `takeException() isNull` sur un écran vide est
/// une **preuve creuse**.
///
/// 🔴 **Leçon su-4 (HIGH)** : la pile qui **crashait sur le chemin NOMINAL**
/// (`reduceGrade` retirant une carte à chaque réussite ⇒ `RangeError`). Ici, le
/// chemin nominal ET les bords sont exercés.
@TestOn('vm')
library;

import 'package:confetti/confetti.dart' show ConfettiWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

Widget _wrap(
  Widget child, {
  bool reduceMotion = false,
}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(home: Scaffold(body: child)),
    );

ZSessionSummaryView _view({
  required ZStudySessionResult result,
  Duration duration = const Duration(minutes: 1),
  ZSummaryCelebration celebration = ZSummaryCelebration.none,
  VoidCallback? onFinish,
  Key? key,
}) =>
    ZSessionSummaryView(
      key: key,
      result: result,
      duration: duration,
      config: const ZSrsConfig(),
      onFinish: onFinish ?? () {},
      celebration: celebration,
    );

String _valueOf(WidgetTester tester, ValueKey<String> key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// Hôte MINIMAL reproduisant l'assemblage réel : la pile de su-4, puis l'écran
/// de fin de su-5 **poussé par `onStackEnd`** (la voie UNIQUE, arbitrage A6).
///
/// C'est le rôle que tiendra l'app (su-10) : su-5 ne pousse rien lui-même — il
/// est une PRÉSENTATION pure (D1).
class _StackEndHost extends StatefulWidget {
  const _StackEndHost({required this.onEnd});

  final VoidCallback onEnd;

  @override
  State<_StackEndHost> createState() => _StackEndHostState();
}

class _StackEndHostState extends State<_StackEndHost> {
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _view(
        result: const ZStudySessionResult(
          total: 1,
          correct: 1,
          byQuality: <String, int>{'5': 1},
        ),
      );
    }
    return ZSessionCardSwiper(
      queue: const <ZSessionItem>[
        ZSessionItem(flashcardId: 'a', folderId: 'f'),
      ],
      cardBuilder: (context, item) => const SizedBox(
        width: 100,
        height: 100,
        child: Text('carte'),
      ),
      passThreshold: 3,
      onStackEnd: () {
        widget.onEnd();
        setState(() => _finished = true);
      },
    );
  }
}

void main() {
  group('🎯 AC9 — session VIDE (`total == 0`, `byQuality == {}`)', () {
    testWidgets(
        '🔴 le rendu est OBSERVABLE — pas un écran blanc, pas une division par '
        'zéro', (tester) async {
      await tester.pumpWidget(
        _wrap(_view(result: const ZStudySessionResult())),
      );
      await tester.pump();

      // 🔴 La branche de repli est ATTEINTE et OBSERVÉE (jamais un simple
      // `takeException() isNull`, qui serait vrai sur un écran BLANC).
      expect(find.byType(ZStudyProgressRings), findsOneWidget);
      expect(find.byType(ZSessionQualityBreakdown), findsOneWidget);
      expect(find.byKey(ZSessionSummaryView.finishButtonKey), findsOneWidget);
      expect(_valueOf(tester, ZSessionSummaryView.totalValueKey), '0');
      expect(_valueOf(tester, ZSessionSummaryView.masteredValueKey), '0');

      // L'anneau est VIDE (contrat existant : `total == 0` ⇒ ratio 0).
      final rings =
          tester.widget<ZStudyProgressRings>(find.byType(ZStudyProgressRings));
      expect(rings.data.ratio, 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Terminer » reste ACTIONNABLE sur une session vide',
        (tester) async {
      var finishes = 0;
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(),
            onFinish: () => finishes++,
          ),
        ),
      );
      await tester.pump();
      // Le contrôle est TAPÉ (jamais seulement constaté présent).
      await tester.tap(find.byKey(ZSessionSummaryView.finishButtonKey));
      await tester.pump();
      expect(finishes, 1);
    });
  });

  group('🎯 AC9 — corpus INCOHÉRENT / CORROMPU (AD-10)', () {
    testWidgets('🔴 `byQuality` avec clé HORS échelle (`{\'9\': 2}`) : signalée, '
        'jamais comptée en « maîtrisées »', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(
              total: 3,
              correct: 2,
              byQuality: <String, int>{'9': 2, '5': 1},
            ),
          ),
        ),
      );
      await tester.pump();

      // Le breakdown la SIGNALE à part (contrat existant, R6)…
      expect(
        find.byKey(const ValueKey<String>(
          '${ZSessionQualityBreakdown.unknownKeyPrefix}9',
        )),
        findsOneWidget,
        reason: 'la clé hors échelle doit être signalée, jamais fusionnée',
      );
      // …et `masteredCount` ne la compte PAS (q5 seul ⇒ 1, écrit à la main).
      expect(
        _valueOf(tester, ZSessionSummaryView.masteredValueKey),
        '1',
        reason: '🔴 une note que l\'échelle ne reconnaît pas ne peut pas être '
            '« maîtrisée » (2 + 1 = 3 serait le défaut)',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('`result` incohérent (`correct > total`) : ratio CLAMPÉ, aucun '
        'crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(
              total: 2,
              correct: 99,
              byQuality: <String, int>{'5': 99},
            ),
          ),
        ),
      );
      await tester.pump();
      final rings =
          tester.widget<ZStudyProgressRings>(find.byType(ZStudyProgressRings));
      expect(rings.data.ratio, 1.0, reason: 'contrat existant : clamp [0,1]');
      expect(tester.takeException(), isNull);
    });

    testWidgets('durée NÉGATIVE ⇒ `00:00` (jamais `-1:-30`, jamais d\'exception)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(total: 1),
            duration: const Duration(seconds: -90),
          ),
        ),
      );
      await tester.pump();
      expect(_valueOf(tester, ZSessionSummaryView.durationValueKey), '00:00');
      expect(tester.takeException(), isNull);
    });

    testWidgets('durée ZÉRO et durée > 1 h s\'affichent sans déborder',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(total: 1),
            duration: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      expect(_valueOf(tester, ZSessionSummaryView.durationValueKey), '00:00');

      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(total: 1),
            duration: const Duration(hours: 2, minutes: 5, seconds: 9),
          ),
        ),
      );
      await tester.pump();
      // 2 h 5 min 9 s = 125 min 9 s (jamais tronqué à `05:09`).
      expect(_valueOf(tester, ZSessionSummaryView.durationValueKey), '125:09');
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 aucun DÉBORDEMENT sur un écran étroit (le contenu défile)',
        (tester) async {
      // 🚫 Leçon su-2 : un débordement RÉEL se corrige dans le WIDGET, jamais en
      // modifiant le test. On monte donc un écran délibérément petit.
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(
              total: 8,
              correct: 6,
              byQuality: <String, int>{'0': 1, '2': 1, '3': 3, '4': 2, '5': 1},
            ),
            celebration: ZSummaryCelebration.subtle,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 un `RenderFlex overflow` est un défaut RÉEL du widget',
      );
    });
  });

  group('🎯 AC9 — DÉMONTAGE (controllers disposés, aucun crash)', () {
    testWidgets('démontage EN PLEIN milieu de l\'animation d\'entrée',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(total: 2, correct: 2),
            celebration: ZSummaryCelebration.subtle,
          ),
        ),
      );
      // On coupe l'arbre AU MILIEU de l'animation (600 ms au total).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'un `AnimationController` non disposé lèverait « A '
            'TickerProvider was disposed »',
      );
    });

    testWidgets(
        '🔴 T5 — démontage EN PLEIN TIR de confetti : aucun `notifyListeners` '
        'post-dispose', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(total: 2, correct: 2),
            celebration: ZSummaryCelebration.confetti,
          ),
        ),
      );
      // 🚫 JAMAIS `pumpAndSettle` ici (T2 : relance inconditionnelle).
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsOneWidget);

      // Le tir dure 800 ms : on démonte à ~50 ms, en pleine vie du système.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // T5 : Flutter démonte les ENFANTS d'abord ⇒ `_ConfettiWidgetState
      // .dispose()` a retiré son listener AVANT que notre `dispose()` n'appelle
      // `ConfettiController.dispose()` (lequel fait `notifyListeners()` AVANT
      // `super.dispose()`). Aucun `setState` sur un State démonté.
      expect(tester.takeException(), isNull);
    });

    testWidgets('démontage IMMÉDIAT (avant tout frame) — aucun crash',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(),
            celebration: ZSummaryCelebration.confetti,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('démontage sous Reduce Motion (aucun confetti à disposer)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            result: const ZStudySessionResult(total: 1),
            celebration: ZSummaryCelebration.confetti,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('🎯 AC9 — `onStackEnd` RÉ-ENTRANT : l\'écran est poussé UNE seule fois',
      () {
    testWidgets(
        '🔴 ASSEMBLAGE RÉEL : `onStackEnd` (su-4) → l\'écran de fin est poussé '
        'UNE seule fois, même en tapant encore', (tester) async {
      // ⚠️ **Ce test garde l'ASSEMBLAGE, pas le latch.** Le latch `_stackEnded`
      // de su-4 a DÉJÀ son test (`z_session_card_swiper_test.dart` : «
      // `onStackEnd` est émis en fin de pile, une SEULE fois »). Le RE-tester
      // ici serait une garde REDONDANTE, qui divergerait avec le temps (leçon
      // E10). Ce qui appartient à su-5, c'est : la voie `onStackEnd` → écran de
      // fin est-elle UNIQUE, et su-5 n'en ouvre-t-il pas une seconde ?
      //
      // 🔴 Un premier jet assérait `expect(pushes, lessThanOrEqualTo(1))` : une
      // assertion **INFALSIFIABLE** (vraie même à 0 poussée, donc vraie même si
      // l'écran de fin n'apparaissait JAMAIS). C'est le défaut « preuve creuse »
      // exactement — remplacé ici par un compte EXACT sur un rendu OBSERVÉ.
      var ends = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 600,
            child: _StackEndHost(onEnd: () => ends++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZSessionSummaryView), findsNothing,
          reason: 'la pile n\'est pas finie : aucun écran de fin');

      // Une seule carte : la première avancée termine la pile.
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(ends, 1);
      expect(
        find.byType(ZSessionSummaryView),
        findsOneWidget,
        reason: '🔴 la voie `onStackEnd` → écran de fin doit RÉELLEMENT pousser '
            'l\'écran (sinon ce test serait vert sur un écran jamais affiché)',
      );

      // …et le bilan est complet (la branche est ATTEINTE, pas seulement sans
      // exception).
      expect(find.byKey(ZSessionSummaryView.finishButtonKey), findsOneWidget);
      expect(ends, 1, reason: '🔴 le latch one-shot de su-4 est CONSOMMÉ : '
          'aucune seconde poussée, l\'écran ne se dédouble pas');
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔒 un `ZSessionSummaryView` reconstruit sur un NOUVEAU `result` '
        'reste cohérent (aucun état rémanent)', (tester) async {
      const key = ValueKey<String>('summary');
      await tester.pumpWidget(
        _wrap(
          _view(
            key: key,
            result: const ZStudySessionResult(
              total: 2,
              correct: 1,
              byQuality: <String, int>{'1': 1, '5': 1},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_valueOf(tester, ZSessionSummaryView.masteredValueKey), '1');

      // Le `result` change SOUS le même `key` (même `State` réutilisé) : les
      // stats doivent SUIVRE, sans rémanence.
      await tester.pumpWidget(
        _wrap(
          _view(
            key: key,
            result: const ZStudySessionResult(
              total: 4,
              correct: 4,
              byQuality: <String, int>{'4': 2, '5': 2},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_valueOf(tester, ZSessionSummaryView.totalValueKey), '4');
      expect(
        _valueOf(tester, ZSessionSummaryView.masteredValueKey),
        '4',
        reason: 'q4(2) + q5(2) = 4 — écrit à la main',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
