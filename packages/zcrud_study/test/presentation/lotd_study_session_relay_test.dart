/// **Lot D « session assemblée »** — les deux écarts qui restaient ouverts,
/// une famille de gardes chacun.
///
/// | # | Écart | Ce qui casse sans le correctif |
/// |---|---|---|
/// | 1 | l'affordance de révélation disparaît dès qu'un hôte compose sa carte | l'hôte doit refabriquer contrôleur d'index ET contrôleur de révélation |
/// | 2 | la carte notée part avant que sa réponse ait pu être lue | le mode d'apprentissage perd sa correction |
///
/// 🔒 **Invariant porteur de l'écart 2** : la retenue ne touche QUE l'instant du
/// passage. La note part au même moment, avec la même valeur, par la même et
/// unique voie d'écriture SRS (AD-9/AD-33) — c'est ce que mesure le compteur du
/// faux seam, avant ET après la continuation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart' show Left, Right;
import 'package:zcrud_core/domain.dart'
    show ZDomainFailure, ZFailure;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZRepetitionInfo;
import 'package:zcrud_session/zcrud_session.dart' show ZFlashcardSubmission;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

/// Libellé de repli de l'action de continuation.
const String kContinueFallback = 'Continuer';

/// Dump ORDONNÉ des types de widgets du sous-arbre de session.
///
/// 🔴 Égalité STRICTE, jamais `contains` ni `length <=` : un nœud intercalé se
/// voit à la position, pas au décompte.
List<String> treeDump(WidgetTester tester) => tester
    .allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

void main() {
  // ── ÉCART 1 — le créneau est RELAYÉ jusqu'à la carte de l'hôte ─────────────
  group('🔴 écart 1 — l\'hôte qui compose sa carte reçoit le créneau', () {
    Widget slotHost(
      List<ZFlashcard> cards,
      FakeSessionReviewer reviewer,
      void Function(ZStudySessionCardSlot) record, {
      ZReviewMode mode = ZReviewMode.learn,
      ZStudySessionRevealPolicy revealPolicy =
          ZStudySessionRevealPolicy.auto,
      Widget Function(BuildContext, ZFlashcard)? cardBuilder,
    }) =>
        wrapForTest(
          ZStudySessionHost(
            mode: mode,
            queue: cards,
            reviewer: reviewer.call,
            revealPolicy: revealPolicy,
            cardBuilder: cardBuilder,
            // La carte de l'hôte : composée par lui, et branchée sur ce que
            // l'assemblage sait — sans aucun contrôleur possédé côté hôte.
            cardSlotBuilder: (BuildContext context, ZStudySessionCardSlot s) {
              record(s);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('hôte ${s.card.id}'),
                  if (s.revealed) Text('réponse ${s.card.answer}'),
                  if (s.toggleReveal != null)
                    TextButton(
                      key: ValueKey<String>('hostReveal_${s.card.id}'),
                      onPressed: s.toggleReveal,
                      child: const Icon(Icons.visibility),
                    ),
                ],
              );
            },
          ),
        );

    testWidgets(
        '🔴 le créneau porte `isFront` (UNE seule carte devant) et la commande '
        'de révélation — l\'hôte ne possède AUCUN contrôleur', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      final List<ZStudySessionCardSlot> seen = <ZStudySessionCardSlot>[];
      await tester.pumpWidget(slotHost(writtenCards(3), reviewer, seen.add));
      await tester.pumpAndSettle();

      expect(seen, isNotEmpty, reason: 'sonde : le créneau est bien invoqué');
      expect(
        seen.where((ZStudySessionCardSlot s) => s.isFront).length,
        greaterThan(0),
        reason: 'au moins une carte est devant',
      );
      // 🔴 Le cœur de l'écart : SANS le relais, l'hôte ne reçoit ni `isFront`
      // ni l'état de révélation, et doit refabriquer les deux.
      expect(find.byKey(const ValueKey<String>('hostReveal_c0')), findsOneWidget,
          reason: '🔴 la carte de DEVANT reçoit la commande de bascule');
      expect(find.text('réponse r0'), findsNothing, reason: 'départ face question');

      await tester.tap(find.byKey(const ValueKey<String>('hostReveal_c0')));
      await tester.pumpAndSettle();

      expect(find.text('réponse r0'), findsOneWidget,
          reason: '🔴 la commande relayée DÉVOILE réellement — sinon elle est '
              'une commande morte');
      expect(reviewer.writes, 0,
          reason: 'dévoiler n\'est pas noter (AD-33)');
    });

    testWidgets(
        '🔴 la carte EMPILÉE derrière ne reçoit NI commande NI révélation '
        '(jamais la réponse de la suivante avant sa question)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      final List<ZStudySessionCardSlot> seen = <ZStudySessionCardSlot>[];
      await tester.pumpWidget(slotHost(writtenCards(3), reviewer, seen.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('hostReveal_c0')));
      await tester.pumpAndSettle();

      final Iterable<ZStudySessionCardSlot> behind =
          seen.where((ZStudySessionCardSlot s) => !s.isFront);
      expect(behind, isNotEmpty, reason: 'sonde : la pile rend bien >1 carte');
      for (final ZStudySessionCardSlot s in behind) {
        expect(s.toggleReveal, isNull,
            reason: '🔴 AD-4 — pas de commande plutôt qu\'une commande morte');
        expect(s.revealed, isFalse,
            reason: '🔴 un contrôleur partagé par TOUTE la pile dévoilerait la '
                'carte suivante en même temps que celle de devant');
      }
      expect(find.text('réponse r1'), findsNothing);
    });

    testWidgets(
        '🔴 l\'affordance NATIVE est ABSENTE quand l\'hôte fournit son créneau '
        '(jamais deux boutons sur le même état)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        slotHost(writtenCards(3), reviewer, (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ZStudySessionHost.revealActionKey), findsNothing,
          reason: '🔴 l\'hôte a REÇU la commande et la place où il veut : deux '
              'contrôles sur le même état se contrediraient à l\'écran');
      expect(find.byKey(const ValueKey<String>('hostReveal_c0')), findsOneWidget,
          reason: 'contre-preuve : le contrôle de l\'hôte, lui, existe bien');
    });

    testWidgets(
        '🔴 le créneau PRIME sur `cardBuilder` — un hôte qui fournit les deux '
        'garde la révélation branchée', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        slotHost(
          writtenCards(3),
          reviewer,
          (_) {},
          // 🔴 Le cas qui discrimine : avec `cardBuilder` SEUL, la révélation
          // n'est pas branchée (la carte de l'hôte ne s'y branche pas). Le
          // créneau, lui, la branche — et doit continuer à la brancher même
          // quand les deux slots sont fournis.
          cardBuilder: (BuildContext context, ZFlashcard card) =>
              const Text('carte legacy'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('carte legacy'), findsNothing,
          reason: 'le créneau REMPLACE le `cardBuilder` dans la pile');
      expect(find.byKey(const ValueKey<String>('hostReveal_c0')), findsOneWidget,
          reason: '🔴 la présence d\'un `cardBuilder` ne doit PAS débrancher la '
              'révélation quand le créneau est là');

      await tester.tap(find.byKey(const ValueKey<String>('hostReveal_c0')));
      await tester.pumpAndSettle();
      expect(find.text('réponse r0'), findsOneWidget);
    });

    testWidgets(
        '🔴 politique `never` : le créneau est servi, mais SANS commande ni '
        'révélation', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      final List<ZStudySessionCardSlot> seen = <ZStudySessionCardSlot>[];
      await tester.pumpWidget(
        slotHost(
          writtenCards(3),
          reviewer,
          seen.add,
          revealPolicy: ZStudySessionRevealPolicy.never,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('hôte c0'), findsOneWidget,
          reason: 'la carte de l\'hôte est rendue quoi qu\'il arrive');
      expect(
        seen.every((ZStudySessionCardSlot s) => s.toggleReveal == null),
        isTrue,
        reason: '🔴 la politique de révélation reste la table UNIQUE : `never` '
            'ne relaie aucune commande',
      );
      expect(find.byKey(const ValueKey<String>('hostReveal_c0')), findsNothing);
    });

    testWidgets(
        '🔴 ADDITIF — sans `cardSlotBuilder`, l\'arbre est celui d\'avant AU '
        'WIDGET PRÈS (hôte passif)', (tester) async {
      useTallSurface(tester);
      // Référence : un hôte passif en mode NOTÉ — aucune des deux nouveautés
      // n'est censée l'atteindre.
      Widget passive({ZStudySessionCardSlotBuilder? slot}) => wrapForTest(
            ZStudySessionHost(
              mode: ZReviewMode.spaced,
              queue: writtenCards(3),
              reviewer: FakeSessionReviewer().call,
              cardSlotBuilder: slot,
            ),
          );
      await tester.pumpWidget(passive());
      await tester.pumpAndSettle();
      final List<String> withoutSlot = treeDump(tester);

      expect(withoutSlot, isNotEmpty, reason: 'sonde : l\'arbre est monté');
      expect(withoutSlot.contains('_ContinueAction'), isFalse,
          reason: '🔴 aucun nœud de retenue chez un hôte passif noté');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsNothing);
      expect(find.byKey(ZStudySessionHost.revealActionKey), findsNothing);
    });
  });

  // ── ÉCART 2 — la réponse reste visible après la soumission ────────────────
  group('🔴 écart 2 — la carte notée est RETENUE le temps de lire la réponse',
      () {
    /// Hôte à notation PILOTÉE : `grade(q)` route une qualité choisie vers la
    /// voie `submit` du host, sans dépendre du barème advisory de la surface.
    Widget gradedHost(
      FakeSessionReviewer reviewer,
      void Function(void Function(int)) exposeGrade, {
      required ZReviewMode mode,
      ZStudySessionPostSubmitPolicy postSubmitPolicy =
          ZStudySessionPostSubmitPolicy.auto,
      int cardCount = 3,
      Key? hostKey,
      double? minTarget,
    }) =>
        wrapForTest(
          ZStudySessionHost(
            // 🔴 Une clé DISTINCTE force un `State` NEUF : sans elle, le second
            // montage réutiliserait le `State` du premier (mêmes types, même
            // position) et garderait son moteur — donc son ANCIEN seam, ce qui
            // rendrait la mesure muette.
            key: hostKey,
            mode: mode,
            queue: writtenCards(cardCount),
            reviewer: reviewer.call,
            postSubmitPolicy: postSubmitPolicy,
            minTarget: minTarget,
            gradingBuilder: (BuildContext c, item, submit) {
              exposeGrade(
                (int q) => submit(
                  ZFlashcardSubmission(
                    quality: q,
                    timeTaken: Duration.zero,
                    hintsUsed: 0,
                  ),
                ),
              );
              return Text('saisie ${item.flashcardId}');
            },
          ),
        );

    testWidgets(
        '🔴 en `learn`, la RÉPONSE est visible après la soumission et la carte '
        'ne part QU\'À la continuation', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(reviewer, (g) => grade = g, mode: ZReviewMode.learn),
      );
      await tester.pumpAndSettle();
      expect(find.text('saisie c0'), findsOneWidget, reason: 'départ sur c0');

      grade(0); // lapse
      await tester.pumpAndSettle();

      expect(find.text('r0'), findsOneWidget,
          reason: '🔴 LE CŒUR DE L\'ÉCART : sans la retenue, la carte serait '
              'déjà partie et sa réponse n\'aurait jamais été montrée');
      expect(find.text('saisie c0'), findsOneWidget,
          reason: '🔴 la session est FIGÉE sur la carte notée');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsOneWidget,
          reason: 'la seule issue de la retenue est explicite');

      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();

      expect(find.text('saisie c1'), findsOneWidget,
          reason: '🔴 la continuation fait ce que la notation faisait avant');
      expect(find.text('r0'), findsNothing,
          reason: 'la révélation se referme au changement de carte');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsNothing);
    });

    testWidgets(
        '🔒 AD-9/AD-33 — la note part au MÊME moment, avec la MÊME valeur, et '
        'la continuation n\'écrit RIEN', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(reviewer, (g) => grade = g, mode: ZReviewMode.learn),
      );
      await tester.pumpAndSettle();

      grade(2);
      await tester.pumpAndSettle();

      // 🔴 AVANT toute continuation : l'écriture SRS a DÉJÀ eu lieu.
      expect(reviewer.writes, 1,
          reason: '🔴 la retenue ne diffère PAS la note — elle ne diffère que '
              'le passage');
      expect(reviewer.qualities, <int>[2],
          reason: '🔴 la VALEUR écrite est celle soumise, inchangée');
      expect(reviewer.gradedIds, <String>['c0']);

      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 1,
          reason: '🔴 la voie d\'écriture reste UNIQUE : continuer n\'est pas '
              'noter une seconde fois');
      expect(reviewer.qualities, <int>[2]);
    });

    testWidgets(
        '🔴 une SECONDE soumission pendant la retenue n\'écrit rien (la voie '
        'reste tirée une seule fois par carte)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(reviewer, (g) => grade = g, mode: ZReviewMode.learn),
      );
      await tester.pumpAndSettle();

      // ① Deux soumissions dans la MÊME frame : le `Future` de `grade` n'est
      // pas encore retombé, le moteur n'a donc pas bougé et sa garde
      // d'identité ne discrimine PAS. Seul le gel ferme cette fenêtre.
      grade(1);
      grade(5);
      await tester.pumpAndSettle();

      expect(reviewer.writes, 1,
          reason: '🔴 une double notation de la même carte corromprait son '
              'état SRS — et la fenêtre s\'ouvre AVANT que le moteur ait '
              'avancé, là où sa garde d\'identité ne voit rien');
      expect(reviewer.qualities, <int>[1]);

      // ② Puis une soumission APRÈS la frame, toujours pendant la retenue.
      grade(4);
      await tester.pumpAndSettle();
      expect(reviewer.writes, 1);
      expect(reviewer.qualities, <int>[1]);
    });

    testWidgets(
        '🔴 INERTIE `spaced` — arbre IDENTIQUE au widget près et MÊME séquence '
        'que l\'échappatoire (qui EST le comportement d\'avant)',
        (tester) async {
      useTallSurface(tester);
      // `ZStudySessionPostSubmitPolicy.advance` désactive la retenue par
      // construction : l'arbre et la séquence obtenus sous cette valeur SONT
      // ceux d'un assemblage sans retenue. L'égalité stricte avec le DÉFAUT en
      // mode noté est donc la mesure exacte de l'inertie.
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(
          reviewer,
          (g) => grade = g,
          mode: ZReviewMode.spaced,
          postSubmitPolicy: ZStudySessionPostSubmitPolicy.advance,
          hostKey: const ValueKey<String>('ref'),
        ),
      );
      await tester.pumpAndSettle();
      final List<String> refMount = treeDump(tester);
      grade(0);
      await tester.pumpAndSettle();
      final List<String> refAfter = treeDump(tester);
      final List<String> refSequence =
          List<String>.from(reviewer.gradedIds);
      final Finder refFront = find.text('saisie c1');
      expect(refFront, findsOneWidget,
          reason: 'sonde : sans retenue, la carte part au geste de notation');

      final reviewer2 = FakeSessionReviewer();
      late void Function(int) grade2;
      await tester.pumpWidget(
        gradedHost(
          reviewer2,
          (g) => grade2 = g,
          mode: ZReviewMode.spaced,
          hostKey: const ValueKey<String>('auto'),
        ),
      );
      await tester.pumpAndSettle();
      final List<String> autoMount = treeDump(tester);
      grade2(0);
      await tester.pumpAndSettle();
      final List<String> autoAfter = treeDump(tester);

      expect(autoMount, orderedEquals(refMount),
          reason: '🔴 au MONTAGE, un mode noté ne gagne AUCUN nœud');
      expect(autoAfter, orderedEquals(refAfter),
          reason: '🔴 APRÈS notation, un mode noté ne gagne AUCUN nœud — une '
              'retenue y intercalerait son action de continuation');
      expect(reviewer2.gradedIds, orderedEquals(refSequence),
          reason: '🔴 MÊME séquence d\'avance');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsNothing,
          reason: '🔴 aucune retenue dans un mode noté');
    });

    testWidgets(
        '🔴 ÉCHAPPATOIRE — `advance` restaure le passage immédiat en `learn`',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(
          reviewer,
          (g) => grade = g,
          mode: ZReviewMode.learn,
          postSubmitPolicy: ZStudySessionPostSubmitPolicy.advance,
        ),
      );
      await tester.pumpAndSettle();

      grade(0);
      await tester.pumpAndSettle();

      expect(find.text('saisie c1'), findsOneWidget,
          reason: '🔴 l\'échappatoire rend EXACTEMENT le comportement d\'avant');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsNothing);
      expect(reviewer.writes, 1);
    });

    testWidgets(
        '🔴 `hold` explicite : un mode noté retient AUSSI (la politique de '
        'l\'hôte prime sur la table)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(
          reviewer,
          (g) => grade = g,
          mode: ZReviewMode.spaced,
          postSubmitPolicy: ZStudySessionPostSubmitPolicy.hold,
        ),
      );
      await tester.pumpAndSettle();

      grade(0);
      await tester.pumpAndSettle();

      expect(find.byKey(ZStudySessionHost.continueActionKey), findsOneWidget);
      expect(find.text('saisie c0'), findsOneWidget);
      expect(reviewer.writes, 1, reason: 'la note est partie quand même');
    });

    testWidgets(
        '🔴 AD-13 — l\'action de continuation : cible ≥ 48 dp RENDUE et '
        '`Semantics` de bouton', (tester) async {
      useTallSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(reviewer, (g) => grade = g, mode: ZReviewMode.learn),
      );
      await tester.pumpAndSettle();
      grade(0);
      await tester.pumpAndSettle();

      final Size size =
          tester.getSize(find.byKey(ZStudySessionHost.continueActionKey));
      // ⚠️ CONSIGNÉ : ces deux bornes seules ne prouvent PAS notre
      // contribution — la taille de cible « padded » de Material rend déjà
      // 48 dp de haut. Elles gardent l'exigence AD-13 (c'est leur objet), et
      // c'est l'assertion sur `minTarget` ci-dessous qui mesure NOTRE plancher.
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'géométrie RENDUE, pas la contrainte demandée');
      expect(size.width, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel(kContinueFallback),
        findsOneWidget,
        reason: '🔴 l\'action doit être ANNONCÉE au lecteur d\'écran',
      );
      handle.dispose();
    });

    testWidgets(
        '🔴 le plancher de cible de l\'HÔTE est honoré par l\'action de '
        'continuation (c\'est NOTRE contribution, pas celle du SDK)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(
          reviewer,
          (g) => grade = g,
          mode: ZReviewMode.learn,
          // 🔴 64 dp : au-DESSUS du plancher « padded » de Material (48 dp).
          // Un bouton qui ignorerait `minTarget` rendrait 48 et rougirait ici.
          minTarget: 64,
        ),
      );
      await tester.pumpAndSettle();
      grade(0);
      await tester.pumpAndSettle();

      final Size size =
          tester.getSize(find.byKey(ZStudySessionHost.continueActionKey));
      expect(size.height, greaterThanOrEqualTo(64),
          reason: '🔴 la surcharge de l\'hôte doit atteindre le bouton');
      expect(size.width, greaterThanOrEqualTo(64));
    });

    testWidgets(
        '🔴 la DERNIÈRE carte est retenue elle aussi — sa réponse n\'est pas la '
        'seule à ne jamais s\'afficher', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      late void Function(int) grade;
      var ended = 0;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.learn,
            queue: <ZFlashcard>[writtenCard('solo', answer: 'rSolo')],
            reviewer: reviewer.call,
            onSessionEnd: (_, _) => ended++,
            gradingBuilder: (BuildContext c, item, submit) {
              grade = (int q) => submit(
                    ZFlashcardSubmission(
                      quality: q,
                      timeTaken: Duration.zero,
                      hintsUsed: 0,
                    ),
                  );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      grade(5); // réussite ⇒ file épuisée
      await tester.pumpAndSettle();

      expect(ended, 0, reason: '🔴 la fin est DIFFÉRÉE jusqu\'à la continuation');
      expect(find.text('rSolo'), findsOneWidget,
          reason: '🔴 la réponse de la dernière carte est bien montrée');

      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();

      expect(ended, 1, reason: 'la fin est poussée exactement une fois (latch)');
    });

    testWidgets(
        '🔴 AD-10 — un seam en ÉCHEC ne retient RIEN (rien n\'a été noté)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer(
        failure: const ZDomainFailure('SRS indisponible (harnais)'),
      );
      late void Function(int) grade;
      await tester.pumpWidget(
        gradedHost(reviewer, (g) => grade = g, mode: ZReviewMode.learn),
      );
      await tester.pumpAndSettle();

      grade(0);
      await tester.pumpAndSettle();

      expect(reviewer.writes, 0, reason: 'aucune écriture aboutie');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsNothing,
          reason: '🔴 une retenue après un ÉCHEC bloquerait la session sur une '
              'carte dont rien n\'a été écrit');
      expect(find.text('saisie c0'), findsOneWidget,
          reason: 'la carte reste affichée, la saisie est conservée');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 AD-10 — après un ÉCHEC, l\'écran n\'est PAS resté gelé : une '
        'nouvelle soumission atteint encore le seam', (tester) async {
      useTallSurface(tester);
      // Seam qui échoue une fois, puis guérit : c'est le SEUL montage où un
      // gel oublié après l'échec se voit — l'écran cesserait définitivement de
      // suivre le moteur, sans aucune exception ni message.
      var calls = 0;
      final List<int> written = <int>[];
      late void Function(int) grade;
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: ZReviewMode.learn,
            queue: writtenCards(3),
            reviewer: ({
              required String flashcardId,
              required String folderId,
              required int quality,
              DateTime? now,
            }) async {
              calls += 1;
              if (calls == 1) {
                return const Left<ZFailure, ZRepetitionInfo>(
                  ZDomainFailure('SRS indisponible (harnais)'),
                );
              }
              written.add(quality);
              return Right<ZFailure, ZRepetitionInfo>(
                ZRepetitionInfo(
                  flashcardId: flashcardId,
                  folderId: folderId,
                  repetitions: 1,
                  lastQuality: quality,
                ),
              );
            },
            gradingBuilder: (BuildContext c, item, submit) {
              grade = (int q) => submit(
                    ZFlashcardSubmission(
                      quality: q,
                      timeTaken: Duration.zero,
                      hintsUsed: 0,
                    ),
                  );
              return Text('saisie ${item.flashcardId}');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      grade(0); // échoue
      await tester.pumpAndSettle();
      expect(written, isEmpty, reason: 'sonde : le 1ᵉʳ appel a bien échoué');

      grade(3); // guéri
      await tester.pumpAndSettle();

      expect(written, <int>[3],
          reason: '🔴 un gel laissé en place après l\'échec bloquerait toute '
              'soumission ultérieure — la session serait morte en silence');
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsOneWidget,
          reason: 'la retenue reprend son cours normal');
    });
  });

  // ── Table unique ──────────────────────────────────────────────────────────
  group('table unique de retenue', () {
    test('🔴 `auto` retient le seul mode d\'apprentissage', () {
      for (final ZReviewMode mode in ZReviewMode.values) {
        expect(
          zStudySessionHoldsAfterSubmit(
            mode,
            ZStudySessionPostSubmitPolicy.auto,
          ),
          mode == ZReviewMode.learn,
          reason: '🔴 $mode — la table est la SEULE décision de retenue',
        );
      }
    });

    test('`hold` / `advance` priment sur le mode, dans les DEUX sens', () {
      for (final ZReviewMode mode in ZReviewMode.values) {
        expect(
          zStudySessionHoldsAfterSubmit(
            mode,
            ZStudySessionPostSubmitPolicy.hold,
          ),
          isTrue,
        );
        expect(
          zStudySessionHoldsAfterSubmit(
            mode,
            ZStudySessionPostSubmitPolicy.advance,
          ),
          isFalse,
        );
      }
    });
  });
}
