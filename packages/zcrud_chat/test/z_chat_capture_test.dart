// CHAT-10 — comportement de la saisie assistée (dictée / OCR).
//
// Le volet SOURCE (l'envoi direct inexprimable, ≥ 48 dp borné, RTL, zéro
// dépendance) vit dans `z_chat_capture_guard_test.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Port de dictée scripté.
class _Dictation implements ZChatDictationPort {
  _Dictation(this.events);

  /// Ce que `listen` émettra, dans l'ordre.
  List<ZResult<ZChatDictationEvent>> events;
  bool throwOnListen = false;
  int stops = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<ZResult<ZChatDictationEvent>> listen({String? localeId}) {
    if (throwOnListen) throw StateError('plugin non enregistré');
    return Stream<ZResult<ZChatDictationEvent>>.fromIterable(events);
  }

  @override
  Future<void> stop() async => stops++;
}

/// Port de dictée dont le flux reste OUVERT tant que l'appelant ne le ferme pas.
class _OpenDictation implements ZChatDictationPort {
  _OpenDictation(this.stream);

  final Stream<ZResult<ZChatDictationEvent>> stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<ZResult<ZChatDictationEvent>> listen({String? localeId}) => stream;

  @override
  Future<void> stop() async {}
}

/// Port d'OCR scripté.
class _Ocr implements ZChatOcrPort {
  _Ocr(this.answer);

  ZResult<ZUnreviewedText?> answer;
  bool throwOnRecognize = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ZResult<ZUnreviewedText?>> recognize(ZChatOcrRequest request) async {
    if (throwOnRecognize) throw StateError('moteur absent');
    return answer;
  }
}

ZResult<ZChatDictationEvent> _said(String text, {bool isFinal = true}) =>
    Right<ZFailure, ZChatDictationEvent>(
      ZChatDictationEvent(
        text: ZUnreviewedText(text),
        isFinal: isFinal,
        phase: isFinal ? ZChatDictationPhase.done : ZChatDictationPhase.listening,
      ),
    );

/// Monte une surface de relecture RÉELLE autour de [capture] — c'est elle qui
/// « observe » le tampon, condition d'`acceptInto`.
Future<void> mountReview(
  WidgetTester tester,
  ZChatCaptureController capture,
  ZChatController chat, {
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    harness(
      Column(
        children: <Widget>[
          ZChatCaptureBar(
            controller: capture,
            onDictate: () {},
            onScan: () {},
          ),
          ZChatCaptureReviewField(
            capture: capture,
            chat: chat,
            cursorColor: const Color(0xFF2196F3),
          ),
        ],
      ),
      direction: direction,
    ),
  );
}

void main() {
  group('🔴 G10-C1 — une dictée ANNULÉE ou une OCR RATÉE PRÉSERVE la saisie',
      () {
    testWidgets('la dictée dépose dans la RELECTURE, jamais dans le composer',
        (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      chat.composer.text = 'Bonjour';
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[
          _said('article douze', isFinal: false),
          _said('article douze du code'),
        ]),
      );
      await mountReview(tester, capture, chat);

      final ZResult<Unit> r = await capture.startDictation();
      await tester.pump();
      expect(r.isRight(), isTrue);
      expect(chat.composer.text, 'Bonjour',
          reason: '🔴 la transcription a atteint le composer SANS relecture');
      expect(capture.hasPendingReview.value, isTrue);
      capture.dispose();
      chat.dispose();
    });

    testWidgets('ANNULER la relecture ne touche PAS la saisie — le défaut '
        'd\'IFFD n\'est pas rejoué', (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      chat.composer.text = 'Question déjà tapée';
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[
          _said('transcription à jeter'),
        ]),
      );
      await mountReview(tester, capture, chat);
      await capture.startDictation();
      await tester.pump();

      capture.cancelReview();
      await tester.pump();

      expect(chat.composer.text, 'Question déjà tapée',
          reason: '🔴 IFFD `chatbot_conversation_screen.dart:3618-3672` : '
              'l\'annulation y DÉTRUIT la saisie de l\'utilisateur. C\'est le '
              'défaut que ce lot avait ordre de ne pas rejouer.');
      expect(capture.hasPendingReview.value, isFalse);
      capture.dispose();
      chat.dispose();
    });

    testWidgets('une OCR qui ÉCHOUE ne touche ni la saisie ni la relecture en '
        'cours', (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      chat.composer.text = 'Contexte tapé à la main';
      final _Ocr ocr = _Ocr(
        const Left<ZFailure, ZUnreviewedText?>(
          ZChatCaptureFailure(
            'illisible',
            reason: ZChatCaptureRejection.nothingCaptured,
          ),
        ),
      );
      final ZChatCaptureController capture = ZChatCaptureController(ocr: ocr);
      await mountReview(tester, capture, chat);

      final ZResult<Unit> r = await capture.scan(const ZChatOcrRequest.capture());
      await tester.pump();
      expect(r.isLeft(), isTrue);
      expect(chat.composer.text, 'Contexte tapé à la main');
      expect(capture.hasPendingReview.value, isFalse);
      expect(capture.activity.value, ZChatCaptureActivity.idle);
      capture.dispose();
      chat.dispose();
    });

    testWidgets('une OCR ANNULÉE (`Right(null)`) n\'efface pas une relecture '
        'en cours', (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      final _Ocr ocr = _Ocr(
        Right<ZFailure, ZUnreviewedText?>(ZUnreviewedText('première page')),
      );
      final ZChatCaptureController capture = ZChatCaptureController(ocr: ocr);
      await mountReview(tester, capture, chat);
      await capture.scan(const ZChatOcrRequest.capture());
      await tester.pump();
      expect(capture.hasPendingReview.value, isTrue);

      ocr.answer = const Right<ZFailure, ZUnreviewedText?>(null);
      final ZResult<Unit> r = await capture.scan(const ZChatOcrRequest.capture());
      await tester.pump();

      expect(r.isRight(), isTrue, reason: '🔴 une ANNULATION n\'est pas un '
          'échec (lex la range pourtant dans son enum d\'erreurs)');
      expect(capture.hasPendingReview.value, isTrue,
          reason: '🔴 l\'annulation a EFFACÉ le travail de relecture en cours');
      capture.dispose();
      chat.dispose();
    });

    testWidgets('l\'insertion AJOUTE, elle ne remplace jamais',
        (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      chat.composer.text = 'Bonjour';
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[
          _said('quel est le taux'),
        ]),
      );
      await mountReview(tester, capture, chat);
      await capture.startDictation();
      await tester.pump();

      final ZResult<Unit> r = capture.acceptInto(chat);

      expect(r.isRight(), isTrue);
      expect(chat.composer.text, 'Bonjour\n\nquel est le taux');
      expect(chat.canSend.value, isTrue);
      expect(capture.hasPendingReview.value, isFalse,
          reason: 'le brouillon est CONSOMMÉ : pas de ré-injection silencieuse');
      capture.dispose();
      chat.dispose();
    });

    testWidgets('🔴 c\'est le texte CORRIGÉ qui part, pas celui du moteur',
        (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[
          _said('article dis du code'),
        ]),
      );
      await mountReview(tester, capture, chat);
      await capture.startDictation();
      await tester.pump();

      // L'utilisateur corrige la transcription dans le champ éditable.
      await tester.enterText(
        find.byType(EditableText).first,
        'article 10 du code',
      );
      await tester.pump();

      capture.acceptInto(chat);
      expect(chat.composer.text, 'article 10 du code',
          reason: '🔴 le composer a reçu la sortie BRUTE du moteur : la '
              'relecture serait décorative');
      capture.dispose();
      chat.dispose();
    });
  });

  group('🔴 G10-C2 — permission refusée ⇒ `Left` TYPÉ, jamais d\'exception',
      () {
    test('dictée : refus de permission', () async {
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[
          const Left<ZFailure, ZChatDictationEvent>(
            ZChatCaptureFailure(
              'micro refusé',
              reason: ZChatCaptureRejection.permissionDenied,
            ),
          ),
        ]),
      );
      final ZResult<Unit> r = await capture.startDictation();
      expect(r.isLeft(), isTrue);
      expect(capture.lastFailure.value, isA<ZChatCaptureFailure>());
      expect(
        (capture.lastFailure.value! as ZChatCaptureFailure).reason,
        ZChatCaptureRejection.permissionDenied,
      );
      expect(capture.activity.value, ZChatCaptureActivity.idle,
          reason: '🔴 l\'interface resterait bloquée sur « à l\'écoute »');
      capture.dispose();
    });

    test('un port d\'hôte qui LÈVE devient un échec ordinaire (AD-10)',
        () async {
      final _Dictation d = _Dictation(<ZResult<ZChatDictationEvent>>[])
        ..throwOnListen = true;
      final _Ocr o = _Ocr(const Right<ZFailure, ZUnreviewedText?>(null))
        ..throwOnRecognize = true;
      final ZChatCaptureController capture =
          ZChatCaptureController(dictation: d, ocr: o);

      final ZResult<Unit> a = await capture.startDictation();
      final ZResult<Unit> b = await capture.scan(const ZChatOcrRequest.capture());

      for (final ZResult<Unit> r in <ZResult<Unit>>[a, b]) {
        final ZFailure f = r.fold((ZFailure f) => f, (Unit _) => fail('pas de Left'));
        expect(f, isA<ZChatCaptureFailure>());
        expect((f as ZChatCaptureFailure).reason,
            ZChatCaptureRejection.engineError);
      }
      expect(capture.activity.value, ZChatCaptureActivity.idle);
      capture.dispose();
    });

    test('AUCUN port ⇒ `unavailable`, et le chat reste utilisable', () async {
      final ZChatCaptureController capture = ZChatCaptureController();
      final ZResult<Unit> a = await capture.startDictation();
      final ZResult<Unit> b = await capture.scan(const ZChatOcrRequest.capture());
      expect(a.isLeft(), isTrue);
      expect(b.isLeft(), isTrue);
      // `stop` sans port ne lève pas non plus.
      await capture.stopDictation();
      capture.dispose();
    });
  });

  group('🔴 G10-C3 — sans surface de relecture MONTÉE, rien n\'entre dans le '
      'composer', () {
    test('le raccourci « dicter puis insérer sans rien montrer » ÉCHOUE',
        () async {
      final ZChatController chat = buildController().controller;
      chat.composer.text = 'saisie';
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[_said('texte')]),
      );
      // Aucun widget monté : rien n'observe le tampon.
      await capture.startDictation();
      expect(capture.hasPendingReview.value, isTrue);

      final ZResult<Unit> r = capture.acceptInto(chat);

      expect(r.isLeft(), isTrue,
          reason: '🔴 la relecture est l\'INVARIANT du lot : elle ne peut pas '
              'être court-circuitée en ne montrant simplement rien');
      expect(chat.composer.text, 'saisie');
      capture.dispose();
      chat.dispose();
    });

    test('un tampon VIDE ne s\'insère pas non plus', () {
      final ZChatController chat = buildController().controller;
      final ZChatCaptureController capture = ZChatCaptureController();
      expect(capture.acceptInto(chat).isLeft(), isTrue);
      expect(chat.composer.text, isEmpty);
      capture.dispose();
      chat.dispose();
    });
  });

  group('🔴 G10-C4 — l\'ÉTAT D\'ÉCOUTE est ANNONCÉ (AD-13), pas seulement '
      'affiché', () {
    testWidgets('la barre porte une région LIVE dont le libellé suit l\'état',
        (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      // 🔴 Un flux OUVERT : sans lui, le cycle se termine avant le premier
      // `pump` et la garde mesurerait un état d'écoute déjà retombé — verte ou
      // rouge par accident, jamais par mesure.
      final StreamController<ZResult<ZChatDictationEvent>> live =
          StreamController<ZResult<ZChatDictationEvent>>();
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _OpenDictation(live.stream),
        ocr: _Ocr(const Right<ZFailure, ZUnreviewedText?>(null)),
      );
      final SemanticsHandle handle = tester.ensureSemantics();
      await mountReview(tester, capture, chat);

      List<SemanticsNode> announcing(String needle) => collectSemantics(
            tester,
            (SemanticsNode n) => n.label.contains(needle),
          );
      expect(announcing('écoute'), isEmpty,
          reason: 'au repos, rien n\'annonce l\'écoute');
      expect(announcing('Saisie assistée'), isNotEmpty,
          reason: '🔴 GARDE VACUELLE : la barre n\'est pas dans l\'arbre '
              'sémantique du tout — l\'absence d\'annonce d\'écoute ne '
              'prouverait alors rien');

      final Future<ZResult<Unit>> pending = capture.startDictation();
      await tester.pump();
      final List<SemanticsNode> listening = announcing('écoute');
      expect(listening, isNotEmpty,
          reason: '🔴 chez lex, `_isListening` ne pilote qu\'une ICÔNE : un '
              'utilisateur non-voyant ne sait pas que le micro écoute');
      expect(listening.first.flagsCollection.isLiveRegion, isTrue,
          reason: '🔴 un libellé VISIBLE n\'est pas une ANNONCE : sans '
              '`liveRegion`, le lecteur d\'écran ne dit rien tant que le '
              'focus n\'y va pas');

      await live.close();
      await pending;
      await tester.pump();
      expect(announcing('écoute'), isEmpty,
          reason: 'le retour au repos est annoncé aussi');
      handle.dispose();
      capture.dispose();
      chat.dispose();
    });
  });

  group('🔴 G10-C5 — SM-1 : dicter ne reconstruit PAS la liste des messages',
      () {
    testWidgets('30 transcriptions partielles : 0 rebuild de la conversation',
        (WidgetTester tester) async {
      final ZChatController chat = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[ZTextBlock(text: 'réponse')]),
        ],
      ).controller;
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _Dictation(<ZResult<ZChatDictationEvent>>[
          for (int i = 0; i < 30; i++) _said('mot $i', isFinal: i == 29),
        ]),
      );
      int conversationBuilds = 0;
      int reviewBuilds = 0;

      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              Expanded(
                child: ValueListenableBuilder<List<ZChatMessage>>(
                  valueListenable: chat.messages,
                  builder: (BuildContext c, List<ZChatMessage> m, Widget? _) {
                    conversationBuilds++;
                    return ZChatConversationView(controller: chat);
                  },
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: capture.review,
                builder: (BuildContext c, String t, Widget? _) {
                  reviewBuilds++;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );
      final int baseConversation = conversationBuilds;
      final int baseReview = reviewBuilds;

      await capture.startDictation();
      await tester.pump();

      expect(conversationBuilds, baseConversation,
          reason: '🔴 SM-1 : la dictée écrit dans le COMPOSEUR — elle ne doit '
              'pas reconstruire la liste des messages. Chez lex, '
              '`setState(() => _isListening = …)` reconstruit tout le composer '
              'à chaque cycle.');
      expect(reviewBuilds, greaterThan(baseReview),
          reason: '🔴 GARDE VACUELLE : si la tranche de relecture ne bouge pas '
              'non plus, le test ne prouve rien — il mesurerait un arbre mort');

      // 🔴 Second volet : l'INSERTION non plus ne reconstruit pas la liste.
      // C'est le geste le plus tentant à câbler « proprement » par un
      // `attach()` ou un rechargement de conversation — et ce serait
      // reconstruire toute la liste pour ajouter deux mots dans un champ.
      capture.review.seed('texte relu');
      capture.acceptInto(chat);
      await tester.pump();
      expect(conversationBuilds, baseConversation,
          reason: '🔴 SM-1 : insérer un texte relu dans le COMPOSEUR a '
              'reconstruit la liste des MESSAGES');
      expect(chat.composer.text, contains('texte relu'),
          reason: '🔴 GARDE VACUELLE : l\'insertion n\'a rien fait du tout');
      capture.dispose();
      chat.dispose();
    });
  });
}
