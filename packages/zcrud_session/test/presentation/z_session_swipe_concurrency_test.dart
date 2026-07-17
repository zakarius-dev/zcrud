/// 🎯 AC12 (SU-4) — **concurrence : le patron `_generation` est RÉUTILISÉ, jamais
/// réinventé** (AD-10).
///
/// 🔴 **La fenêtre est RÉELLE, lue sur disque** — `onSwipe` est `FutureOr<bool>`
/// et le paquet l'**`await`e** (`card_swiper_state.dart:231`) :
/// ```dart
/// final shouldCancelSwipe = await widget.onSwipe?.call(_currentIndex!, _nextIndex, _detectedDirection) == false;
/// ```
/// ⇒ pendant ce vol, la file peut changer. C'est la **même racine** que le D1
/// MAJEUR de su-3, dont la dartdoc annonçait déjà su-4 : *« en su-4
/// (`onSubmitted` branché sur `ZSessionReviewer.reviewCard`), c'est un SRS faux
/// écrit sur la mauvaise carte, par la voie légitime »*. **C'est maintenant.**
///
/// Les seams sont pilotés par des **`Completer` contrôlés** (jamais un
/// `Future.delayed` au hasard : une temporisation arbitraire rend le test
/// instable ET incapable de cibler l'instant exact de la fenêtre).
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show Right, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardType, ZRepetitionInfo, ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'z_answer_input_harness.dart';
import 'z_swiper_harness.dart';

List<ZSessionItem> _queue() => const <ZSessionItem>[
      ZSessionItem(flashcardId: 'f0', folderId: 'd0'),
      ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
      ZSessionItem(flashcardId: 'f2', folderId: 'd2'),
    ];

ZFlashcard _written(String q) => ZFlashcard(
      question: q,
      type: ZFlashcardType.openQuestion,
      answer: 'réponse',
      explanation: 'explication',
    );

/// Seam SRS **LENT** — le test contrôle l'instant exact de la réponse.
class _SlowReviewer {
  final List<String> started = <String>[];
  final List<Completer<void>> gates = <Completer<void>>[];

  void release(int i) => gates[i].complete();

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    started.add(flashcardId);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return Right<Never, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

void main() {
  group('🎯 AC12 — la fenêtre de concurrence est DISSOUTE : handler SYNCHRONE', () {
    test(
        '🔴 `_handleSwipe` n\'est PAS `async` et ne rend PAS un `Future` — '
        'sinon la fenêtre `await` se rouvre et le jeton redevient obligatoire',
        () {
      // 🔴 **POURQUOI CETTE GARDE EXISTE (mesuré, consigné).** su-4 avait écrit
      // un jeton `_generation` dans le swiper, sur le modèle de su-3. L'injection
      // R3-I17a (le retirer) **ne rougissait AUCUN test** : le handler étant
      // **synchrone**, aucune fenêtre `await` ne s'ouvre — le jeton était
      // **structurellement inatteignable**, et sa dartdoc affirmait « capturé
      // avant l'await » alors qu'aucun `await` n'existait. Défaut **D8 de su-3**
      // (code décoratif + test incapable de rougir) ⇒ le jeton a été **RETIRÉ**.
      //
      // Mais alors l'invariant qui rend la dissolution vraie — la
      // **synchronicité** — n'était gardé par RIEN : un futur dev rendant ce
      // handler `async` (pour attendre un port, par exemple) rouvrirait la
      // fenêtre du D1 MAJEUR de su-3 **en silence**. Cette garde le rougit.
      const path = 'lib/src/presentation/z_session_card_swiper.dart';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path})');

      // On isole la SIGNATURE réelle du handler (hors commentaires).
      final code = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('///'))
          .join('\n');
      final match =
          RegExp(r'\n\s*(\w[\w<>?\s]*?)\s+_handleSwipe\s*\([^)]*\)\s*(async)?\s*\{')
              .firstMatch(code);
      expect(match, isNotNull,
          reason: '🔴 `_handleSwipe` est introuvable : cette garde ne scanne '
              'plus rien et serait verte pour de mauvaises raisons');

      final returnType = match!.group(1)!.trim();
      expect(match.group(2), isNull,
          reason: '🔴 `_handleSwipe` est devenu `async` : le paquet l\'`await`e '
              '(`_handleCompleteSwipe`) ⇒ la file peut changer PENDANT le vol. '
              'Il faut RÉTABLIR le jeton de fraîcheur `_generation` (patron de '
              '`z_flashcard_answer_input.dart:280`) — sinon un effet périmé se '
              'pose sur la mauvaise carte.');
      expect(returnType, 'bool',
          reason: '🔴 `_handleSwipe` rend `$returnType` : rendre un `Future` '
              'rouvre la fenêtre `await` (même raison que ci-dessus)');
    });
  });

  group('🎯 AC12 — double-swipe : un index n\'est JAMAIS émis deux fois', () {
    testWidgets('🔴 deux gestes rapides ⇒ l\'index avance de 1 PAR CARTE',
        (tester) async {
      final indices = <int>[];
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: _queue(),
              cardBuilder: (context, item) =>
                  Center(child: Text(item.flashcardId)),
              passThreshold: 3,
              onIndexChanged: indices.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deux swipes en succession RAPIDE (sans laisser retomber l'animation
      // entre les deux) — le scénario du double-geste.
      await tester.drag(find.text('f0'), const Offset(500, 0));
      await tester.pump();
      await tester.drag(find.text('f0'), const Offset(500, 0),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        indices,
        <int>[1],
        reason: '🔴 `onIndexChanged` a émis deux fois le même index '
            '($indices) : sans le verrou one-shot, l\'hôte compterait deux '
            'cartes là où l\'apprenant n\'en a passé qu\'une',
      );
      expect(indices.toSet(), hasLength(indices.length),
          reason: 'aucun index ne doit être émis en double');
    });

    testWidgets('la navigation complète émet chaque index EXACTEMENT une fois',
        (tester) async {
      final indices = <int>[];
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: _queue(),
              cardBuilder: (context, item) =>
                  Center(child: Text(item.flashcardId)),
              passThreshold: 3,
              onIndexChanged: indices.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(indices, <int>[1, 2]);
    });
  });

  group('🎯 AC12 — `onStackEnd` ré-entrant : une seule émission', () {
    testWidgets('🔴 la fin de pile n\'est notifiée qu\'UNE fois', (tester) async {
      var ends = 0;
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: const <ZSessionItem>[
                ZSessionItem(flashcardId: 'f0', folderId: 'd0'),
              ],
              cardBuilder: (context, item) =>
                  Center(child: Text(item.flashcardId)),
              passThreshold: 3,
              onStackEnd: () => ends++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      // Une seconde tentative sur une pile déjà finie ne doit RIEN ré-émettre
      // (l'écran de fin de su-5 serait sinon poussé deux fois).
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(ends, 1, reason: '🔴 `onEnd` ré-entrant : su-5 pousserait deux '
          'écrans de fin');
    });
  });

  group('🎯 AC12 — seam SRS EN VOL : la note n\'atterrit pas sur la mauvaise '
      'carte', () {
    testWidgets(
        '🔴 la file N\'AVANCE PAS tant que le seam est en vol, et la note reste '
        'attribuée à la carte NOTÉE', (tester) async {
      final reviewer = _SlowReviewer();
      final engine = ZStudySessionEngine(
        queue: _queue(),
        reviewer: reviewer.call,
      );
      addTearDown(engine.dispose);

      // Notation de f0 — le seam part en vol et ne répond pas encore.
      final pending = engine.grade(5);
      await tester.pump();

      expect(reviewer.started, <String>['f0']);
      expect(engine.current?.flashcardId, 'f0',
          reason: '🔴 la file a avancé AVANT la confirmation du seam : sur un '
              'échec, la carte serait perdue (AC5/R3-I9)');

      // Le seam répond : c'est SEULEMENT là que la file avance.
      reviewer.release(0);
      await pending;
      await tester.pump();

      expect(engine.current?.flashcardId, 'f1');
      expect(reviewer.started, <String>['f0'],
          reason: 'aucune écriture parasite');
    });
  });

  group('🎯 AC12 — port d\'évaluation EN VOL pendant un changement de carte', () {
    testWidgets(
        '🔴 une évaluation PÉRIMÉE n\'atteint JAMAIS la nouvelle carte '
        '(jeton `_generation` de su-3, RÉUTILISÉ dans l\'assemblage)',
        (tester) async {
      final port = SlowEvaluationPort();
      final submissions = <ZFlashcardSubmission>[];
      var index = 0;

      // Hôte de PROD : la saisie est FRÈRE de la pile, et sa `card` SUIT l'index
      // courant — c'est exactement ce qui rend l'évaluation « périmée » possible.
      await tester.pumpWidget(
        wrapApp(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: <Widget>[
                Expanded(
                  child: ZSessionCardSwiper(
                    queue: _queue(),
                    cardBuilder: (context, item) =>
                        Center(child: Text(item.flashcardId)),
                    passThreshold: 3,
                    onIndexChanged: (i) => setState(() => index = i),
                  ),
                ),
                ZFlashcardAnswerInput(
                  // 🔒 La carte CHANGE quand la pile avance.
                  card: _written('question $index'),
                  mode: ZReviewMode.learn,
                  evaluationPort: port,
                  srsConfig: const ZSrsConfig(),
                  onQualitySelected: (_) {},
                  onSubmitted: submissions.add,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // (1) On répond à la carte A ; le port part en vol.
      await tester.enterText(find.byType(TextField), 'réponse A');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.submit));
      await tester.pump();
      expect(port.callCount, 1, reason: 'l\'évaluation de A est en vol');

      // (2) …et PENDANT ce vol, l'apprenant swipe : la carte change.
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(index, 1, reason: 'la pile a bien avancé pendant le vol');

      // (3) Le port répond ENFIN — pour la carte A, qui n'est plus à l'écran.
      port.release(0);
      await tester.pumpAndSettle();

      // 🎯 L'AC : le résultat PÉRIMÉ est ignoré. Sans le jeton `_generation`,
      // c'est un SRS FAUX écrit sur la carte B, par la voie légitime.
      expect(
        submissions,
        isEmpty,
        reason: '🔴 une évaluation périmée a été émise après changement de '
            'carte (${submissions.length}) : elle serait attribuée à la carte '
            'suivante. `mounted` NE SUFFIT PAS — le State survit au changement '
            'de widget.',
      );
    });
  });
}
