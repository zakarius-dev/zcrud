// CHAT-10 — comportement des ports de saisie assistée (dictée / OCR).
//
// Ce fichier ne lit AUCUNE source : il exerce le contrat. Le volet SOURCE
// (l'envoi direct est inexprimable, aucune dépendance tierce) vit dans
// `z_chat_capture_guard_test.dart`, qui porte `@TestOn('vm')`.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Le seul puits admis — il capte ce qu'on lui dépose, comme le ferait une
/// surface de relecture.
class _Sink implements ZChatReviewSink {
  final List<String> seeded = <String>[];

  @override
  void seed(String seed) => seeded.add(seed);
}

/// Un port de dictée d'hôte, entièrement scripté.
class _FakeDictation implements ZChatDictationPort {
  _FakeDictation(this._events, {this.available = true});

  final List<ZResult<ZChatDictationEvent>> _events;
  final bool available;
  int stopCalls = 0;
  String? seenLocale;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<ZResult<ZChatDictationEvent>> listen({String? localeId}) {
    seenLocale = localeId;
    return Stream<ZResult<ZChatDictationEvent>>.fromIterable(_events);
  }

  @override
  Future<void> stop() async => stopCalls++;
}

/// Un port d'OCR d'hôte, entièrement scripté.
class _FakeOcr implements ZChatOcrPort {
  _FakeOcr(this._answer, {this.available = true});

  final ZResult<ZUnreviewedText?> _answer;
  final bool available;
  ZChatOcrRequest? seen;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ZResult<ZUnreviewedText?>> recognize(ZChatOcrRequest request) async {
    seen = request;
    return _answer;
  }
}

void main() {
  group('🔴 G10-K1 — un texte capturé n\'expose AUCUNE `String`', () {
    test('le contenu ne sort QUE par un dépôt dans une surface éditable', () {
      final ZUnreviewedText text = ZUnreviewedText('position 0805');
      final _Sink sink = _Sink();
      text.depositInto(sink);
      expect(sink.seeded, <String>['position 0805']);
      // Les métadonnées, elles, sont publiques — c'est tout ce qui l'est.
      expect(text.length, 13);
      expect(text.isBlank, isFalse);
      expect(text.isLarge, isFalse);
    });

    test('🔴 `toString()` ne FUIT pas le contenu', () {
      // Volet comportemental de l'invariant : sans lui, `debugPrint('$t')`
      // suffirait à contourner tout le fichier. La garde SOURCE jumelle
      // (G10-S1) interdit d'ajouter un getter public ; celle-ci interdit la
      // fuite par la représentation, qui est la forme qu'un auteur pressé
      // écrit sans y penser.
      const String secret = 'SECRET-DICTE-A-NE-PAS-FUIR';
      final ZUnreviewedText text = ZUnreviewedText(secret);
      expect(text.toString(), isNot(contains(secret)));
      expect(text.toString(), contains('unreviewed'));
      // Le canal indirect : un événement de dictée ne doit pas le fuiter non
      // plus (il interpole `text` dans SON `toString()`).
      final ZChatDictationEvent event = ZChatDictationEvent(
        text: text,
        isFinal: true,
        phase: ZChatDictationPhase.done,
      );
      expect(event.toString(), isNot(contains(secret)));
    });

    test('une capture VIDE ne dépose rien — un composeur ne reçoit pas du '
        'blanc pour lui faire croire que le moteur a compris', () {
      final _Sink sink = _Sink();
      ZUnreviewedText('   \n  ').depositInto(sink);
      expect(sink.seeded, isEmpty);
      expect(ZUnreviewedText('  ').isBlank, isTrue);
    });

    test('le normaliseur d\'hôte est appliqué UNE fois, à la construction', () {
      int calls = 0;
      final ZUnreviewedText text = ZUnreviewedText(
        'huit cent cinq',
        normalizer: (String raw) {
          calls++;
          return raw.replaceAll('huit cent cinq', '0805');
        },
      );
      final _Sink a = _Sink();
      final _Sink b = _Sink();
      text.depositInto(a);
      text.depositInto(b);
      expect(calls, 1, reason: '🔴 normaliser à CHAQUE dépôt le rendrait non '
          'idempotent — « 0805 » redeviendrait autre chose au second passage');
      expect(a.seeded.single, '0805');
      expect(b.seeded.single, '0805');
    });

    test('sans normaliseur, le texte est VERBATIM — jamais un défaut inventé',
        () {
      final _Sink sink = _Sink();
      ZUnreviewedText('huit cent cinq').depositInto(sink);
      expect(sink.seeded.single, 'huit cent cinq');
    });

    test('le volume est ANNONCÉ, jamais TRONQUÉ (défaut n°2 : ne rien '
        'détruire)', () {
      final String huge = 'x' * (kZChatCaptureLargeTextThreshold + 1);
      final ZUnreviewedText text = ZUnreviewedText(huge);
      expect(text.isLarge, isTrue);
      final _Sink sink = _Sink();
      text.depositInto(sink);
      expect(sink.seeded.single.length, huge.length,
          reason: '🔴 le socle a TRONQUÉ : il a détruit de la capture à la '
              'place de l\'utilisateur');
    });
  });

  group('🔴 G10-K2 — AD-5/AD-10 : permission refusée ⇒ `Left` TYPÉ', () {
    test('la dictée rend un `Left(ZChatCaptureFailure)`, jamais une exception',
        () async {
      final _FakeDictation port = _FakeDictation(
        <ZResult<ZChatDictationEvent>>[
          const Left<ZFailure, ZChatDictationEvent>(
            ZChatCaptureFailure(
              'micro refusé',
              reason: ZChatCaptureRejection.permissionDenied,
            ),
          ),
        ],
      );
      final List<ZResult<ZChatDictationEvent>> got =
          await port.listen().toList();
      expect(got, hasLength(1));
      final ZFailure failure = got.single.fold(
        (ZFailure f) => f,
        (ZChatDictationEvent _) => fail('un refus de permission a été rendu '
            'comme un SUCCÈS'),
      );
      expect(failure, isA<ZChatCaptureFailure>());
      expect(
        (failure as ZChatCaptureFailure).reason,
        ZChatCaptureRejection.permissionDenied,
      );
    });

    test('l\'OCR aussi — et l\'ANNULATION reste une VALEUR, pas une erreur',
        () async {
      final _FakeOcr denied = _FakeOcr(
        const Left<ZFailure, ZUnreviewedText?>(
          ZChatCaptureFailure(
            'caméra refusée',
            reason: ZChatCaptureRejection.permissionDenied,
          ),
        ),
      );
      final ZResult<ZUnreviewedText?> refus =
          await denied.recognize(const ZChatOcrRequest.capture());
      expect(refus.isLeft(), isTrue);

      final _FakeOcr cancelled =
          _FakeOcr(const Right<ZFailure, ZUnreviewedText?>(null));
      final ZResult<ZUnreviewedText?> annule =
          await cancelled.recognize(const ZChatOcrRequest.capture());
      expect(
        annule.fold((ZFailure _) => 'left', (ZUnreviewedText? t) => t),
        isNull,
        reason: '🔴 lex range `cancelled` dans le MÊME enum que `error` : '
            'chaque appelant doit alors se souvenir qu\'un de ses cas '
            'd\'erreur n\'en est pas un. Ici c\'est `Right(null)`.',
      );
    });

    test('la cause d\'origine est TRANSPORTÉE, jamais réinterprétée', () {
      const ZFailure cause = ZDomainFailure('MissingPluginException');
      const ZChatCaptureFailure failure = ZChatCaptureFailure(
        'moteur absent',
        reason: ZChatCaptureRejection.unavailable,
        cause: cause,
      );
      expect(failure.cause, same(cause));
      expect(failure, isA<ZFailure>());
      expect(
        failure,
        const ZChatCaptureFailure(
          'moteur absent',
          reason: ZChatCaptureRejection.unavailable,
          cause: cause,
        ),
      );
      expect(
        failure,
        isNot(const ZChatCaptureFailure(
          'moteur absent',
          reason: ZChatCaptureRejection.engineError,
          cause: cause,
        )),
      );
    });

    test('🔴 la famille de rejets est EXACTEMENT celle LUE chez lex — ni plus, '
        'ni moins', () {
      expect(
        ZChatCaptureRejection.values.toSet(),
        <ZChatCaptureRejection>{
          ZChatCaptureRejection.unavailable,
          ZChatCaptureRejection.permissionDenied,
          ZChatCaptureRejection.nothingCaptured,
          ZChatCaptureRejection.engineError,
        },
        reason: '🔴 ÉGALITÉ D\'ENSEMBLE. Chaque motif AJOUTÉ sans avoir été '
            'mesuré chez un hôte réel oblige TOUS les hôtes à répondre à une '
            'question que leur moteur ne pose pas. Les quatre ci-dessus sont '
            'lus dans `speech_recognition_service.dart` et `ocr_service.dart`. '
            '`cancelled` est ABSENT à dessein : c\'est `Right(null)`. '
            '`listening`/`done` aussi : c\'est `ZChatDictationPhase`.',
      );
      expect(
        ZChatDictationPhase.values.toSet(),
        <ZChatDictationPhase>{
          ZChatDictationPhase.listening,
          ZChatDictationPhase.done,
        },
      );
    });
  });

  group('🔴 G10-K2b — l\'INDISPONIBILITÉ est une réponse, pas une panne', () {
    test('`isAvailable()` rend `false` sans lever — l\'hôte masque '
        'l\'affordance au lieu de promettre un geste mort', () async {
      final _FakeDictation dictation = _FakeDictation(
        const <ZResult<ZChatDictationEvent>>[],
        available: false,
      );
      final _FakeOcr ocr = _FakeOcr(
        const Right<ZFailure, ZUnreviewedText?>(null),
        available: false,
      );
      expect(await dictation.isAvailable(), isFalse);
      expect(await ocr.isAvailable(), isFalse);
      // …et `stop()` reste appelable même sans moteur (best-effort, AD-10).
      await dictation.stop();
      expect(dictation.stopCalls, 1);
    });
  });

  group('🔴 G10-K3 — la locale reste celle de l\'HÔTE', () {
    test('`null` est transmis tel quel — jamais remplacé par `fr_FR`',
        () async {
      final _FakeDictation port =
          _FakeDictation(const <ZResult<ZChatDictationEvent>>[]);
      await port.listen().toList();
      expect(port.seenLocale, isNull,
          reason: '🔴 lex code `\'fr_FR\'` en repli (`chat_input.dart:371`) : '
              'acceptable dans une app francophone, jamais dans un socle '
              'multi-consommateurs');
      await port.listen(localeId: 'ar_SA').toList();
      expect(port.seenLocale, 'ar_SA');
    });
  });

  group('🔴 G10-K4 — la demande d\'OCR distingue capture et octets', () {
    test('les deux flux VIVANTS de lex, et pas un de plus', () async {
      expect(ZChatOcrSource.values, hasLength(2));
      final _FakeOcr port = _FakeOcr(
        Right<ZFailure, ZUnreviewedText?>(ZUnreviewedText('lu')),
      );
      await port.recognize(const ZChatOcrRequest.capture());
      expect(port.seen!.source, ZChatOcrSource.capture);
      expect(port.seen!.bytes, isNull);
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      await port.recognize(ZChatOcrRequest.bytes(bytes));
      expect(port.seen!.source, ZChatOcrSource.bytes);
      expect(port.seen!.bytes, same(bytes));
    });
  });
}
