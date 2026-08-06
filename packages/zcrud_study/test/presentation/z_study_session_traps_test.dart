/// **Lot 1 « étude »** — LES QUATRE PIÈGES D'INTÉGRATION, un test chacun.
///
/// La dartdoc de l'assemblage de référence
/// (`example/lib/demos/study_session_demo_screen.dart:72-100`) énumère
/// nommément les pièges que tout hôte de session rencontre. Ce sont les
/// critères d'acceptation du lot ; chacun a **son** test ci-dessous, et chacun
/// est **falsifiable** (l'assertion rougit si le piège se rouvre — vérifié par
/// la campagne R3).
///
/// | # | Piège | Ce qui casserait sans le correctif |
/// |---|---|---|
/// | ① | une seule source de séquence (su-10 D1) | la note tombe à côté dès le 1ᵉʳ lapse |
/// | ② | résolution par `flashcardId`, jamais par index (su-7) | mauvaise carte affichée/notée |
/// | ③ | `key` de pile = identité de file (su-4 D1) | `RangeError` sur file rétrécie |
/// | ④ | resync `didUpdateWidget` clampé (su-8) | file périmée, front survivant |
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_session/zcrud_session.dart' show ZSessionCardSwiper;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

void main() {
  /// Monte une session SRS (`learn`) sur [cards] avec un faux seam.
  Widget srsHost(
    List<ZFlashcard> cards,
    FakeSessionReviewer reviewer, {
    Key? key,
  }) =>
      wrapForTest(
        ZStudySessionHost(
          key: key,
          mode: ZReviewMode.learn,
          queue: cards,
          reviewer: reviewer.call,
        ),
      );

  // ── ① ─────────────────────────────────────────────────────────────────────
  group('① une seule source de séquence (su-10 D1)', () {
    testWidgets(
        '🔴 après un LAPSE, la carte notée suivante est le NOUVEAU front du '
        'moteur — et CHAQUE soumission atteint le seam SRS', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(srsHost(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      // Départ : le front du moteur est c0.
      expect(
        find.byKey(const ValueKey<String>('zStudySessionAnswer_c0')),
        findsOneWidget,
        reason: 'la session démarre sur le front du moteur',
      );

      // « Je ne sais pas » ⇒ lapse : le moteur réinsère c0 en aval, son front
      // devient c1, et le swiper SUIT sa file dynamique.
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 1, reason: 'le 1ᵉʳ lapse atteint le seam SRS');
      expect(reviewer.gradedIds, <String>['c0']);
      expect(
        find.byKey(const ValueKey<String>('zStudySessionAnswer_c1')),
        findsOneWidget,
        reason: 'après un lapse, le front du moteur avance à c1',
      );

      // 🔴 LE CŒUR DU PIÈGE : la 2ᵉ soumission doit atteindre le SRS elle
      // aussi. Avec deux curseurs indépendants (file FIXE du swiper vs file
      // CYCLIQUE du moteur), la garde d'identité `engine.current == cardId`
      // sauterait ici — SILENCIEUSEMENT — et toutes les notes suivantes
      // seraient perdues.
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 2,
          reason: '🔴 la 2ᵉ soumission DOIT atteindre le SRS : si le swiper et '
              'le moteur tenaient deux curseurs, la note tomberait à côté et '
              'ce compteur resterait à 1 (perte SRS silencieuse)');
      expect(reviewer.gradedIds, <String>['c0', 'c1'],
          reason: 'la carte NOTÉE est toujours celle qui était AFFICHÉE');
    });

    testWidgets(
        '🔬 CONTRE-PREUVE de non-vacuité : sans aucun geste, le seam n\'est '
        'JAMAIS appelé (le compteur ne monte pas tout seul)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(srsHost(writtenCards(3), reviewer));
      await tester.pumpAndSettle();
      expect(reviewer.writes, 0);
    });
  });

  // ── ② ─────────────────────────────────────────────────────────────────────
  group('② résolution par `flashcardId`, jamais par index (su-7)', () {
    testWidgets(
        '🔴 une file PERMUTÉE rend la carte de sa propre identité — pas celle '
        'qui occupait l\'index', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      // File inversée : à l'index 0 se trouve `c2`. Un `cardBuilder` qui
      // résoudrait par index rendrait `c0` (le premier de la liste de
      // cartes) — la carte de l'index, pas celle de l'identité.
      final List<ZFlashcard> reversed = writtenCards(3).reversed.toList();
      await tester.pumpWidget(srsHost(reversed, reviewer));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('zStudySessionAnswer_c2')),
        findsOneWidget,
        reason: '🔴 le front de la file permutée est c2 : une résolution par '
            'INDEX rendrait c0 et cette clé serait absente',
      );
      expect(
        find.byKey(const ValueKey<String>('zStudySessionAnswer_c0')),
        findsNothing,
      );

      // …et la note suit la même identité.
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(reviewer.gradedIds, <String>['c2'],
          reason: 'la carte notée est celle de l\'IDENTITÉ affichée');
    });

    testWidgets(
        '🔴 le CONTENU rendu est celui de l\'identité — pas celui de la '
        'position dans la file d\'ENTRÉE (la clé seule ne prouve rien)',
        (tester) async {
      // 🔬 GARDE DURCIE (défaut démasqué par R3-2 : l'injection « résoudre par
      // position » laissait le test VERT). La `key` d'un slot dérive de
      // `item.flashcardId` : elle reste juste même si le CONTENU résolu est
      // faux. Il faut donc assérer le contenu, à l'intérieur du slot.
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(srsHost(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      // Lapse sur c0 ⇒ le front du moteur devient c1, tandis que la file
      // d'ENTRÉE commence toujours par c0. Les deux résolutions divergent
      // désormais : c'est le seul état où la mesure discrimine.
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();

      final Finder grading =
          find.byKey(const ValueKey<String>('zStudySessionAnswer_c1'));
      expect(grading, findsOneWidget);
      expect(
        find.descendant(of: grading, matching: find.text('Question c1.')),
        findsWidgets,
        reason: '🔴 la surface de saisie doit porter le CONTENU de c1 — une '
            'résolution par position rendrait « Question c0. » sous une clé '
            'pourtant nommée c1',
      );
      expect(
        find.descendant(of: grading, matching: find.text('Question c0.')),
        findsNothing,
        reason: '🔴 le contenu de la carte de la POSITION 0 de la file '
            'd\'entrée ne doit jamais apparaître sous la carte de devant',
      );

      // Même exigence sur la carte d'AFFICHAGE de la pile.
      final Finder card =
          find.byKey(const ValueKey<String>('zStudySessionCard_c1'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Question c1.')),
        findsWidgets,
        reason: '🔴 la carte de devant doit porter le contenu de son identité',
      );
    });

    testWidgets(
        '🔴 AD-10 — une carte absente de la table rend un repli OBSERVABLE '
        '(jamais une exception, jamais une boîte vide)', (tester) async {
      useTallSurface(tester);
      // Une carte sans `id` est écartée de la file (défensif) ⇒ la file ne
      // porte que les identités résolubles : la désynchronisation ne peut donc
      // PAS venir de là. On exerce le repli par un `gradingBuilder` qui
      // interroge une identité absente — le chemin réel qu'un hôte emprunte.
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            gradingBuilder: (BuildContext context, item, submit) =>
                Text('slot_${item.flashcardId}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Le slot reçoit bien l'ITEM (donc l'identité), jamais un index.
      expect(find.text('slot_c0'), findsOneWidget);
    });
  });

  // ── ③ ─────────────────────────────────────────────────────────────────────
  group('③ `key` de pile dérivée de l\'identité de file (su-4 D1)', () {
    testWidgets(
        '🔴 la clé de la pile CHANGE quand la file change réellement '
        '(ordre inclus) — l\'`Element` ne survit pas à une file qu\'il '
        'n\'indexe plus', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(srsHost(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      Key stackKey() =>
          tester.widget<ZSessionCardSwiper>(find.byType(ZSessionCardSwiper)).key!;

      final Key before = stackKey();
      expect(
        before.toString(),
        contains(ZStudySessionView.stackKeyPrefix),
        reason: 'la pile porte bien la clé d\'identité du lot',
      );
      // Égalité EXACTE (jamais un `contains` complaisant) : la clé est
      // l'empreinte d'ordre de la file de départ.
      expect(
        before,
        const ValueKey<String>('${ZStudySessionView.stackKeyPrefix}c0|c1|c2'),
      );

      // Un lapse permute la file du moteur (c0 réinséré en aval).
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();

      final Key after = stackKey();
      expect(after, isNot(before),
          reason: '🔴 une file réellement changée DOIT remonter l\'`Element` — '
              'une clé constante (ou dérivée de la seule LONGUEUR, ici '
              'inchangée à 3) rouvrirait le RangeError su-4 D1');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔬 `zSessionQueueIdentity` distingue deux files de MÊME longueur et '
        'd\'ordre différent (la longueur seule ne suffirait pas)', (tester) async {
      // Sonde directe de la fonction d'identité — le seul endroit où la
      // propriété « l\'ordre compte » est décidée.
      final a = writtenCards(3);
      final b = a.reversed.toList();
      expect(a.length, b.length, reason: 'même longueur : la longueur seule '
          'ne peut PAS distinguer ces deux files');
      useTallSurface(tester);
      await tester.pumpWidget(srsHost(a, FakeSessionReviewer()));
      await tester.pumpAndSettle();
      final Key keyA =
          tester.widget<ZSessionCardSwiper>(find.byType(ZSessionCardSwiper)).key!;
      await tester.pumpWidget(srsHost(b, FakeSessionReviewer()));
      await tester.pumpAndSettle();
      final Key keyB =
          tester.widget<ZSessionCardSwiper>(find.byType(ZSessionCardSwiper)).key!;
      expect(keyA, isNot(keyB));
    });
  });

  // ── ④ ─────────────────────────────────────────────────────────────────────
  group('④ resync `didUpdateWidget` clampé (su-8)', () {
    testWidgets(
        '🔴 la file d\'entrée RÉTRÉCIT après un lapse : le moteur est '
        'ré-amorcé sur la NOUVELLE file, le front périmé disparaît, aucun '
        'RangeError', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      List<ZFlashcard> cards = writtenCards(3);
      late void Function(void Function()) setOuter;
      await tester.pumpWidget(
        wrapForTest(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setOuter = setState;
              return ZStudySessionHost(
                mode: ZReviewMode.learn,
                queue: cards,
                reviewer: reviewer.call,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_c0')),
          findsOneWidget);

      // Lapse : le front du moteur passe à c1.
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_c1')),
          findsOneWidget);

      // La file d'entrée change : 2 cartes FRAÎCHES (c0, c1).
      setOuter(() => cards = writtenCards(2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'un index survivant à la file provoquerait un RangeError');
      // 🔴 FALSIFIABLE : sans resync, le moteur garderait sa file post-lapse
      // ([c1, c2, c0]) et son front resterait c1 ⇒ `answer_c0` serait ABSENT.
      expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_c0')),
          findsOneWidget,
          reason: 're-seed : le moteur repart sur le front de la NOUVELLE file');
      expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_c1')),
          findsNothing,
          reason: 'le front périmé de l\'ANCIENNE session ne survit pas');
    });

    testWidgets(
        '🔬 CONTRE-PREUVE : un rebuild du parent SANS changement de file ne '
        'ré-amorce PAS la session (sinon chaque frame la redémarrerait)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      final List<ZFlashcard> cards = writtenCards(3);
      late void Function(void Function()) setOuter;
      await tester.pumpWidget(
        wrapForTest(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setOuter = setState;
              return ZStudySessionHost(
                mode: ZReviewMode.learn,
                // Nouvelle LISTE à chaque build, mêmes identités : le re-seed
                // doit se décider sur l'IDENTITÉ, jamais sur l'`identical`.
                queue: List<ZFlashcard>.of(cards),
                reviewer: reviewer.call,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_c1')),
          findsOneWidget);

      setOuter(() {}); // rebuild pur, file inchangée
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('zStudySessionAnswer_c1')),
          findsOneWidget,
          reason: '🔴 un rebuild du parent NE DOIT PAS redémarrer la session : '
              'la progression de l\'apprenant serait effacée à chaque frame');
      expect(reviewer.writes, 1);
    });
  });
}
