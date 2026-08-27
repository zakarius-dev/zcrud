// L9 — mode vocal continu : la boucle « écouter → transcrire → soumettre →
// énoncer → réécouter », et surtout SES CONDITIONS D'ARRÊT.
//
// 🔴 Une boucle vocale qui ne s'arrête pas est un défaut GRAVE : micro ouvert,
// énoncé qui couvre l'utilisateur, batterie. Les quatre chemins d'arrêt sont
// donc gardés un par un, et chacun est INJECTABLE dans `lib/` (cf. `r3.txt`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Port de dictée PILOTÉ : un canal ouvert par appel, et des compteurs.
///
/// Le canal reste OUVERT tant que le test (ou `stop`) ne le ferme pas : c'est
/// ce qui rend un arrêt « pendant une attente asynchrone » réellement
/// atteignable, plutôt que simulé par un flux déjà terminé.
class _Dictation implements ZChatDictationPort {
  final List<StreamController<ZResult<ZChatDictationEvent>>> channels =
      <StreamController<ZResult<ZChatDictationEvent>>>[];

  /// Nombre d'appels à `stop`.
  int stops = 0;

  /// Si non `null`, `listen` émet CE `Left` puis se termine.
  ZFailure? failWith;

  StreamController<ZResult<ZChatDictationEvent>> get last => channels.last;

  /// `true` si au moins un canal a encore un abonné.
  bool get anySubscribed =>
      channels.any((StreamController<ZResult<ZChatDictationEvent>> c) =>
          c.hasListener && !c.isClosed);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<ZResult<ZChatDictationEvent>> listen({String? localeId}) {
    final StreamController<ZResult<ZChatDictationEvent>> channel =
        StreamController<ZResult<ZChatDictationEvent>>();
    channels.add(channel);
    final ZFailure? boom = failWith;
    if (boom != null) {
      channel.add(Left<ZFailure, ZChatDictationEvent>(boom));
      unawaited(channel.close());
    }
    return channel.stream;
  }

  /// Émet une transcription finale et FERME le canal — un tour d'écoute.
  Future<void> say(String text) async {
    last.add(
      Right<ZFailure, ZChatDictationEvent>(
        ZChatDictationEvent(
          text: ZUnreviewedText(text),
          isFinal: true,
          phase: ZChatDictationPhase.done,
        ),
      ),
    );
    await pumpEventQueue();
    await last.close();
    await pumpEventQueue();
  }

  @override
  Future<void> stop() async {
    stops++;
    for (final StreamController<ZResult<ZChatDictationEvent>> c in channels) {
      if (!c.isClosed) await c.close();
    }
  }
}

/// Maillon de synthèse PILOTÉ : compteurs, et échec sur demande.
class _Speech implements ZChatSpeechPort {
  final List<String> spoken = <String>[];
  int stops = 0;
  ZFailure? failWith;

  /// Si non `null`, `speak` ATTEND ce futur — la fenêtre pendant laquelle un
  /// arrêt peut être demandé.
  Completer<void>? gate;

  @override
  String get sourceKind => 'test';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ZResult<ZChatSpeechDelivery>> speak(ZChatSpeechRequest request) async {
    spoken.add(request.text);
    final Completer<void>? hold = gate;
    if (hold != null) await hold.future;
    final ZFailure? boom = failWith;
    if (boom != null) return Left<ZFailure, ZChatSpeechDelivery>(boom);
    return Right<ZFailure, ZChatSpeechDelivery>(
      ZChatSpeechDelivery(sourceKind: sourceKind),
    );
  }

  @override
  Future<void> stop() async => stops++;
}

/// Export minimal — la narration passe par lui, il n'est jamais réécrit ici.
ZChatExportService _export() => ZChatExportService();

/// Tout le câblage d'une session, prêt à l'emploi.
({
  ZChatController chat,
  FakeStreamPort port,
  ZChatCaptureController capture,
  ZChatDiffusionService diffusion,
  _Dictation dictation,
  _Speech speech,
  ZChatVoiceSessionController voice,
})
_rig({bool withDictation = true, bool withSpeech = true}) {
  final ({
    ZChatController controller,
    FakeStreamPort port,
    SpyExecutor executor,
    SeqIds ids,
    List<ZChatActionPlan> confirmed,
  })
  built = buildController();
  final _Dictation dictation = _Dictation();
  final _Speech speech = _Speech();
  final ZChatCaptureController capture = ZChatCaptureController(
    dictation: withDictation ? dictation : null,
  );
  final ZChatDiffusionService diffusion = ZChatDiffusionService(
    exportService: _export(),
    speech: withSpeech ? speech : null,
  );
  return (
    chat: built.controller,
    port: built.port,
    capture: capture,
    diffusion: diffusion,
    dictation: dictation,
    speech: speech,
    voice: ZChatVoiceSessionController(
      chat: built.controller,
      capture: capture,
      diffusion: diffusion,
    ),
  );
}

/// Monte une surface de relecture RÉELLE : c'est elle qui « observe » le
/// tampon, condition d'`acceptInto` — la session n'ouvre AUCUNE dérogation.
void _observeReview(ZChatCaptureController capture) {
  void noop() {}
  capture.review.addListener(noop);
  addTearDown(() => capture.review.removeListener(noop));
}

/// Termine le tour en vol : réponse puis événement terminal.
Future<void> _answer(FakeStreamPort port, String text) async {
  port.last.add(tok(text));
  port.last.add(const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent()));
  await port.last.close();
  await pumpEventQueue();
}

void main() {
  group('🔴 L9-G1 — INERTIE, en absolu : sans session, l\'arbre est celui '
      'd\'hier', () {
    testWidgets('la `Column` du composer n\'a QU\'UN enfant, et aucune couche '
        'de clavier observante n\'existe', (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      addTearDown(chat.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(controller: chat, cursorColor: const Color(0xFF000000)),
        ),
      );

      // Absolu : UN enfant — l'ancre — et rien d'autre. Pas une comparaison
      // entre deux arbres, dont l'injection déplacerait les deux.
      final Column column = tester.widget<Column>(
        find
            .descendant(
              of: find.byType(ZChatComposer),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(column.children, hasLength(1));
      expect(column.children.single, isA<Row>());

      // Aucun bandeau de session.
      expect(find.byType(ZChatVoiceSessionBanner), findsNothing);

      // Aucune couche de clavier « observante » (celle de la session est la
      // SEULE du composer à combiner `canRequestFocus: false` et
      // `skipTraversal: true`).
      final Iterable<Focus> observing = tester
          .widgetList<Focus>(
            find.descendant(
              of: find.byType(ZChatComposer),
              matching: find.byType(Focus),
            ),
          )
          .where(
            (Focus f) => f.canRequestFocus == false && f.skipTraversal == true,
          );
      expect(observing, isEmpty);
    });
  });

  group('🔴 L9-G2 — la BOUCLE enchaîne réellement ses étapes, et RECOMMENCE',
      () {
    test('écouter → transcrire → soumettre → énoncer → RÉÉCOUTER, deux tours',
        () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);

      final Future<ZResult<Unit>> session = r.voice.start();
      await pumpEventQueue();
      expect(r.dictation.channels, hasLength(1), reason: '1 — le micro écoute');
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.listening);

      await r.dictation.say('première question');
      await pumpEventQueue();
      // 2 + 3 — la transcription est passée par la RELECTURE puis par `send()`.
      expect(r.port.calls, hasLength(1));
      expect(r.port.calls.single.request.subject, 'première question');
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.submitting);
      expect(r.speech.spoken, isEmpty, reason: 'rien n\'est énoncé avant la réponse');

      await _answer(r.port, 'réponse une');
      await pumpEventQueue();
      // 5 — la réponse est énoncée…
      expect(r.speech.spoken, hasLength(1));
      expect(r.speech.spoken.single, contains('réponse une'));
      // 6 — …et le micro se RÉOUVRE : un second canal d'écoute.
      expect(r.dictation.channels, hasLength(2), reason: 'la boucle réécoute');
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.listening);

      // Second tour COMPLET — la boucle n'est pas un enchaînement câblé une
      // seule fois.
      await r.dictation.say('seconde question');
      await pumpEventQueue();
      expect(r.port.calls, hasLength(2));
      expect(r.port.calls.last.request.subject, 'seconde question');
      await _answer(r.port, 'réponse deux');
      await pumpEventQueue();
      expect(r.speech.spoken, hasLength(2));
      expect(r.speech.spoken.last, contains('réponse deux'));
      expect(r.dictation.channels, hasLength(3));

      await r.voice.stop();
      expect(await session, isA<Right<ZFailure, Unit>>());
      r.voice.dispose();
    });
  });

  group('🔴 L9-G3 — ARRÊT n° 1 : TOUTE FRAPPE au clavier arrête la session',
      () {
    testWidgets('une seule touche suffit, et elle n\'est PAS consommée',
        (WidgetTester tester) async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: r.chat,
            cursorColor: const Color(0xFF000000),
            focusNode: node,
            voice: r.voice,
          ),
        ),
      );
      unawaited(r.voice.start());
      await tester.pump();
      expect(r.voice.active.value, isTrue);
      expect(r.dictation.channels, hasLength(1));

      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(r.voice.active.value, isFalse, reason: 'la frappe a arrêté la session');
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.idle);
      expect(r.dictation.stops, greaterThanOrEqualTo(1),
          reason: 'le micro est refermé, pas seulement l\'état remis à zéro');
      expect(r.dictation.anySubscribed, isFalse);

      // La couche OBSERVE, elle n'intercepte pas : le champ garde son rôle de
      // destinataire du clavier.
      expect(node.hasPrimaryFocus, isTrue);
      r.voice.dispose();
    });
  });

  group('🔴 L9-G4 — ARRÊT n° 2 : l\'ÉCHEC D\'UN PORT arrête PROPREMENT', () {
    test('dictée en échec ⇒ session arrêtée, micro fermé, `Left` typé, rien '
        'ne lève', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);
      r.dictation.failWith = const ZChatCaptureFailure(
        'micro indisponible',
        reason: ZChatCaptureRejection.unavailable,
      );

      final ZResult<Unit> outcome = await r.voice.start();

      expect(outcome, isA<Left<ZFailure, Unit>>());
      expect(r.voice.active.value, isFalse,
          reason: 'la session n\'est JAMAIS laissée « en écoute » derrière une panne');
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.idle);
      expect(r.voice.lastFailure.value, isA<ZChatCaptureFailure>());
      expect(r.dictation.stops, greaterThanOrEqualTo(1));
      expect(r.dictation.anySubscribed, isFalse);
      expect(r.port.calls, isEmpty, reason: 'rien n\'a été soumis');
      r.voice.dispose();
    });

    test('synthèse en échec ⇒ même arrêt, après un tour complet', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);
      r.speech.failWith = const ZDomainFailure('moteur muet');

      final Future<ZResult<Unit>> session = r.voice.start();
      await pumpEventQueue();
      await r.dictation.say('une question');
      await pumpEventQueue();
      await _answer(r.port, 'une réponse');
      await pumpEventQueue();

      expect(await session, isA<Left<ZFailure, Unit>>());
      expect(r.voice.active.value, isFalse);
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.idle);
      expect(r.voice.lastFailure.value, const ZDomainFailure('moteur muet'));
      expect(r.dictation.channels, hasLength(1),
          reason: 'la boucle ne réécoute PAS après l\'échec');
      expect(r.dictation.anySubscribed, isFalse);
      r.voice.dispose();
    });
  });

  group('🔴 L9-G5 — ARRÊT n° 3 : la DESTRUCTION ferme le flux — AUCUN '
      'abonnement ne survit', () {
    test('`dispose()` du contrôleur en pleine écoute : micro fermé, canal sans '
        'abonné, aucune reprise', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);

      unawaited(r.voice.start());
      await pumpEventQueue();
      expect(r.dictation.anySubscribed, isTrue, reason: 'le micro écoute');

      r.voice.dispose();
      await pumpEventQueue();

      expect(r.dictation.stops, greaterThanOrEqualTo(1),
          reason: 'la destruction ARRÊTE le port, elle ne se contente pas d\'oublier');
      expect(r.dictation.anySubscribed, isFalse,
          reason: 'aucun abonnement ne survit à la destruction');
      expect(r.dictation.channels, hasLength(1),
          reason: 'la boucle ne rouvre pas un micro après la destruction');
      expect(r.port.calls, isEmpty);
    });

    testWidgets('la destruction du COMPOSER arrête la session',
        (WidgetTester tester) async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);

      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: r.chat,
            cursorColor: const Color(0xFF000000),
            voice: r.voice,
          ),
        ),
      );
      unawaited(r.voice.start());
      await tester.pump();
      expect(r.voice.active.value, isTrue);
      expect(r.dictation.anySubscribed, isTrue);

      // Le composer disparaît — l'écran est fermé.
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(r.voice.active.value, isFalse,
          reason: 'une session sans zone de saisie n\'a plus de destination');
      expect(r.dictation.anySubscribed, isFalse);
      expect(r.dictation.stops, greaterThanOrEqualTo(1));
      r.voice.dispose();
    });
  });

  group('🔴 L9-G6 — ARRÊT n° 4 : un arrêt demandé PENDANT UNE ATTENTE est '
      'HONORÉ — la boucle ne redémarre pas', () {
    test('arrêt pendant l\'attente de la réponse : la réponse ARRIVÉE '
        'entre-temps n\'est PAS énoncée, et le micro ne se rouvre pas',
        () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);

      // 🔬 L'ENTRELACEMENT RÉEL, et non un arrêt commodément placé : l'arrêt
      // tombe À L'INSTANT où le tour se termine — le cas d'une frappe pendant
      // que la réponse arrive. Le `whenComplete` de l'attente de tour est
      // asynchrone (microtâche), ce listener-ci est synchrone : la boucle
      // reprend donc APRÈS l'arrêt, avec une réponse fraîche disponible.
      //
      // Sans cette précaution, la clause « rien n'est énoncé » serait SUBSUMÉE
      // par la condition de boucle (aucune réponse neuve ⇒ rien à énoncer de
      // toute façon), et aucune injection ne pourrait la faire rougir.
      void onSettled() {
        if (r.chat.activeRequests.value.isEmpty) unawaited(r.voice.stop());
      }

      final Future<ZResult<Unit>> session = r.voice.start();
      await pumpEventQueue();
      r.chat.activeRequests.addListener(onSettled);
      addTearDown(() => r.chat.activeRequests.removeListener(onSettled));
      await r.dictation.say('une question');
      await pumpEventQueue();
      expect(r.port.calls, hasLength(1), reason: 'le tour est EN VOL');

      await _answer(r.port, 'réponse tardive');
      await pumpEventQueue();

      // La réponse EXISTE bel et bien — la garde ne se contente pas d'un fil
      // vide, sinon elle regarderait à côté.
      expect(
        r.chat.messages.value.any(
          (ZChatMessage m) => m.role == ZChatRole.assistant,
        ),
        isTrue,
      );
      expect(await session, isA<Right<ZFailure, Unit>>());
      expect(r.speech.spoken, isEmpty,
          reason: 'un arrêt demandé ne se fait pas écraser par la reprise');
      expect(r.dictation.channels, hasLength(1),
          reason: 'la boucle ne réécoute PAS après un arrêt demandé');
      expect(r.voice.active.value, isFalse);
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.idle);
      r.voice.dispose();
    });

    test('arrêt pendant l\'ÉNONCÉ : la boucle ne réécoute pas non plus',
        () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);
      final Completer<void> speaking = Completer<void>();
      r.speech.gate = speaking;

      final Future<ZResult<Unit>> session = r.voice.start();
      await pumpEventQueue();
      await r.dictation.say('une question');
      await pumpEventQueue();
      await _answer(r.port, 'une réponse');
      await pumpEventQueue();
      expect(r.speech.spoken, hasLength(1), reason: 'l\'énoncé est EN COURS');
      expect(r.dictation.channels, hasLength(1));

      await r.voice.stop();
      speaking.complete();
      await pumpEventQueue();

      expect(await session, isA<Right<ZFailure, Unit>>());
      expect(r.dictation.channels, hasLength(1),
          reason: 'la reprise après l\'énoncé ne rouvre pas le micro');
      expect(r.speech.stops, greaterThanOrEqualTo(1),
          reason: 'l\'énoncé en cours est interrompu, pas laissé courir');
      expect(r.voice.active.value, isFalse);
      r.voice.dispose();
    });

    test('arrêt pendant l\'ÉCOUTE : la transcription en cours n\'est NI '
        'insérée NI envoyée', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);

      final Future<ZResult<Unit>> session = r.voice.start();
      await pumpEventQueue();
      // L'utilisateur a DÉJÀ dicté quelque chose — le tampon n'est pas vide,
      // sinon `acceptInto` refuserait de lui-même et la garde regarderait à
      // côté.
      r.dictation.last.add(
        Right<ZFailure, ZChatDictationEvent>(
          ZChatDictationEvent(
            text: ZUnreviewedText('phrase interrompue'),
            isFinal: false,
            phase: ZChatDictationPhase.listening,
          ),
        ),
      );
      await pumpEventQueue();
      expect(r.capture.review.value, 'phrase interrompue');

      await r.voice.stop();
      await pumpEventQueue();

      expect(await session, isA<Right<ZFailure, Unit>>());
      expect(r.chat.composer.text, isEmpty,
          reason: 'une écoute interrompue n\'écrit pas dans la saisie');
      expect(r.port.calls, isEmpty,
          reason: 'et surtout, elle n\'ENVOIE pas');
      expect(r.voice.active.value, isFalse);
      r.voice.dispose();
    });
  });

  group('🔴 L9-G7 — PORT ABSENT ⇒ session INDISPONIBLE, et RIEN NE LÈVE', () {
    test('sans moteur de dictée : `isAvailable` faux, `Left` typé, aucun port '
        'touché', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig(withDictation: false);
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);

      expect(r.voice.isAvailable, isFalse);
      final ZResult<Unit> outcome = await r.voice.start();

      expect(outcome, isA<Left<ZFailure, Unit>>());
      expect(r.voice.lastFailure.value, isA<ZUnsupportedOperationFailure>());
      expect(r.voice.active.value, isFalse);
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.idle);
      // Le socle ne demande AUCUNE permission et ne sollicite aucun moteur :
      // un port absent est une capacité absente, pas une panne à provoquer.
      expect(r.dictation.channels, isEmpty);
      expect(r.speech.spoken, isEmpty);
      r.voice.dispose();
    });

    test('sans moteur de synthèse : même verdict', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig(withSpeech: false);
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);

      expect(r.voice.isAvailable, isFalse);
      expect(await r.voice.start(), isA<Left<ZFailure, Unit>>());
      expect(r.voice.active.value, isFalse);
      expect(r.dictation.channels, isEmpty,
          reason: 'le micro n\'est pas ouvert pour une session qui ne pourra '
              'jamais répondre');
      r.voice.dispose();
    });
  });

  group('🔴 L9-G8 — GRANULARITÉ : un changement d\'état de session ne touche '
      'NI le champ, NI son focus, NI son texte', () {
    testWidgets('démarrer la session ne reconstruit pas `EditableText`',
        (WidgetTester tester) async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      // Sonde de RECONSTRUCTION : un créneau d'hôte n'est résolu que dans le
      // `build` du composer. Son compteur mesure donc ce que l'identité
      // d'élément ne voit pas — un rebuild à l'échelle du formulaire.
      int slotBuilds = 0;

      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: r.chat,
            cursorColor: const Color(0xFF000000),
            focusNode: node,
            voice: r.voice,
            leading: (BuildContext context, ZChatComposerSlot slot) {
              slotBuilds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'ma question');
      await tester.pump();
      node.requestFocus();
      await tester.pump();

      final Element before = tester.element(find.byType(EditableText));
      final TextSelection selection = r.chat.composer.selection;
      final int buildsBefore = slotBuilds;
      expect(node.hasFocus, isTrue);

      unawaited(r.voice.start());
      await tester.pump();

      expect(slotBuilds, buildsBefore,
          reason: '🔴 le COMPOSER ENTIER a été reconstruit par un changement '
              'de phase : c\'est le rebuild global (AD-2) que ce paquet '
              'existe pour supprimer');

      expect(
        identical(tester.element(find.byType(EditableText)), before),
        isTrue,
        reason: '🔴 le champ a été RECONSTRUIT par le démarrage de la session '
            'vocale : le bug historique que zcrud existe pour corriger (AD-2)',
      );
      expect(node.hasFocus, isTrue,
          reason: '🔴 le focus a sauté au démarrage de la session');
      expect(r.chat.composer.text, 'ma question',
          reason: '🔴 le texte en cours a été perdu');
      expect(r.chat.composer.selection, selection,
          reason: '🔴 le curseur a bougé');

      // 🟢 LE VERT TÉMOIN : sans lui, une session INERTE rendrait la garde
      // ci-dessus verte pour rien — le champ ne serait pas reconstruit parce
      // que rien ne se serait passé.
      expect(r.voice.phase.value, ZChatVoiceSessionPhase.listening,
          reason: '🔴 la session n\'a PAS démarré : la garde de granularité '
              'serait verte pour rien');

      // 🔬 CONTRE-PREUVE : le matcher d'identité SAIT distinguer.
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            key: const ValueKey<String>('autre'),
            controller: r.chat,
            cursorColor: const Color(0xFF000000),
            voice: r.voice,
          ),
        ),
      );
      expect(
        identical(tester.element(find.byType(EditableText)), before),
        isFalse,
        reason: '🔴 `identical` rend vrai même sur un élément neuf : la mesure '
            'de granularité ne discrimine rien',
      );
      r.voice.dispose();
    });
  });

  group('🔴 L9-G9 — l\'ÉTAT DE SESSION est ANNONCÉ (AD-13), et l\'affordance '
      'fait ≥ 48 dp', () {
    testWidgets('région LIVE dont le libellé suit la phase, et vient des DEUX '
        'tables', (WidgetTester tester) async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      _observeReview(r.capture);
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: r.chat,
            cursorColor: const Color(0xFF000000),
            voice: r.voice,
          ),
        ),
      );
      List<SemanticsNode> announcing(String needle) => collectSemantics(
        tester,
        (SemanticsNode n) => n.label.contains(needle),
      );

      // 🟢 VERT TÉMOIN : le bandeau EST monté. Sans cette clause, « rien
      // n'annonce l'écoute » serait vrai pour un bandeau simplement absent, et
      // la garde ne mesurerait rien.
      expect(find.byType(ZChatVoiceSessionBanner), findsOneWidget);
      expect(announcing('écoute'), isEmpty,
          reason: 'au repos, rien n\'annonce l\'écoute — et rien ne parle '
              'd\'un mode vocal qui ne tourne pas');

      unawaited(r.voice.start());
      await tester.pump();

      final List<SemanticsNode> listening = announcing('écoute');
      expect(listening, isNotEmpty,
          reason: '🔴 un utilisateur qui n\'entend pas ne sait pas que le '
              'micro écoute');
      expect(listening.first.flagsCollection.isLiveRegion, isTrue,
          reason: '🔴 un libellé VISIBLE n\'est pas une ANNONCE : sans '
              '`liveRegion`, le lecteur d\'écran ne dit rien tant que le '
              'focus n\'y va pas');

      // La cible d'arrêt, apparue avec la session, est bornée par le BAS.
      final Finder stop = find.byWidgetPredicate(
        (Widget w) => w is ZChatCaptureAction && w.label == 'Arrêter le mode vocal',
      );
      expect(stop, findsOneWidget);
      final Size size = tester.getSize(stop);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));

      await r.voice.stop();
      handle.dispose();
      r.voice.dispose();
    });

    testWidgets('un hôte qui traduit obtient SES libellés — aucune chaîne en '
        'dur', (WidgetTester tester) async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: r.chat,
            cursorColor: const Color(0xFF000000),
            voice: r.voice,
          ),
          labels: <String, String>{
            kZChatLabelVoiceSpeaking: 'Reading the answer',
            kZChatLabelStopVoiceSession: 'Stop voice mode',
          },
        ),
      );
      _observeReview(r.capture);
      unawaited(r.voice.start());
      await tester.pump();
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) => n.label.contains('Stop voice mode'),
        ),
        isNotEmpty,
        reason: '🔴 le libellé du socle a écrasé celui de l\'hôte (FR-26)',
      );
      // Les CLÉS neuves sont déclarées dans les DEUX tables : la liste
      // exhaustive et les replis. Une clé dans l'une seulement laisse soit un
      // libellé sans repli, soit un repli qu'aucun hôte ne peut découvrir.
      for (final String key in <String>[
        kZChatLabelVoiceSession,
        kZChatLabelVoiceSubmitting,
        kZChatLabelVoiceSpeaking,
        kZChatLabelStopVoiceSession,
      ]) {
        expect(kZChatLabelKeys, contains(key));
        expect(kZChatLabelFallbacks.containsKey(key), isTrue);
      }
      await r.voice.stop();
      handle.dispose();
      r.voice.dispose();
    });
  });

  group('🔴 L9-G10 — COEXISTENCE : la session PASSE PAR la dictée ponctuelle, '
      'elle ne la court-circuite pas', () {
    test('sans surface de relecture montée, la session N\'ENVOIE RIEN et '
        's\'arrête', () async {
      final ({
        ZChatController chat,
        FakeStreamPort port,
        ZChatCaptureController capture,
        ZChatDiffusionService diffusion,
        _Dictation dictation,
        _Speech speech,
        ZChatVoiceSessionController voice,
      })
      r = _rig();
      addTearDown(r.chat.dispose);
      addTearDown(r.capture.dispose);
      addTearDown(r.diffusion.dispose);
      // ⚠️ AUCUN `_observeReview` ici : rien n'affiche le tampon.

      final Future<ZResult<Unit>> session = r.voice.start();
      await pumpEventQueue();
      await r.dictation.say('une phrase jamais montrée');
      await pumpEventQueue();

      // 🟢 VERT TÉMOIN : la transcription a BIEN été déposée — la garde ne
      // constate pas simplement qu'il ne s'est rien passé.
      expect(r.capture.review.value, 'une phrase jamais montrée');

      // Mesuré AVANT d'attendre la session : une session qui aurait envoyé
      // resterait suspendue sur un tour en vol, et l'attente masquerait le
      // défaut derrière une expiration.
      expect(r.port.calls, isEmpty,
          reason: '🔴 le mode vocal ouvre une voie d\'envoi SANS relecture : '
              'exactement ce que `ZUnreviewedText` rend inexprimable ailleurs');
      expect(r.chat.composer.text, isEmpty);
      expect(await session, isA<Left<ZFailure, Unit>>());
      expect(r.voice.active.value, isFalse);
      expect(r.voice.lastFailure.value, isA<ZDomainFailure>());
      r.voice.dispose();
    });
  });
}
