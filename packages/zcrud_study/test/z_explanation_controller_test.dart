// Lot P1-D — `ZExplanationController` : voie progressive, voie one-shot,
// historique de versions, fraîcheur.
//
// Runner R14 : `flutter test`. Aucun accès disque.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _messages = ZExplanationMessages(
  unexpectedError: 'MSG_INATTENDU',
  emptyResult: 'MSG_VIDE',
);

/// Clés d'opération INJECTÉES par le test — vocabulaire d'un hôte fictif,
/// délibérément sans rapport avec un quelconque nom de traitement du socle.
const _operations = ZExplanationOperationKeys(
  summarize: 'OP_CONDENSER',
  regenerate: 'OP_REFAIRE',
  elaborate: 'OP_DEVELOPPER',
  restyle: 'OP_STYLE',
);

/// Port one-shot app-side, qui MÉMORISE les requêtes reçues.
class _RecordingPort implements ZAiExplanationPort {
  _RecordingPort({this.result, this.throws = false});

  final ZResult<String>? result;
  final bool throws;
  final List<ZAiExplanationRequest> seen = <ZAiExplanationRequest>[];

  @override
  Future<ZResult<String>> explain(ZAiExplanationRequest request) async {
    seen.add(request);
    if (throws) throw StateError('boom');
    return result ?? Right<ZFailure, String>('one-shot:${request.content}');
  }
}

/// Port progressif app-side pilotable événement par événement.
class _ControllablePort implements ZAiExplanationStreamPort {
  _ControllablePort({this.available = true});

  final bool available;
  final List<ZAiExplanationRequest> seen = <ZAiExplanationRequest>[];
  late StreamController<ZResult<ZGenerationProgress>> controller;

  @override
  bool get isAvailable => available;

  @override
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  ) {
    seen.add(request);
    controller = StreamController<ZResult<ZGenerationProgress>>();
    return controller.stream;
  }

  void emit(String text, {bool isDone = false}) => controller.add(
        Right<ZFailure, ZGenerationProgress>(
          ZGenerationProgress(text: text, isDone: isDone),
        ),
      );

  void fail(ZFailure failure) => controller.add(
        Left<ZFailure, ZGenerationProgress>(failure),
      );
}

ZExplanationController _build({
  _RecordingPort? port,
  ZAiExplanationStreamPort? streamPort,
  List<ZExplanationVersion> initial = const <ZExplanationVersion>[],
}) =>
    ZExplanationController(
      port: port ?? _RecordingPort(),
      messages: _messages,
      streamPort: streamPort,
      operations: _operations,
      initialVersions: initial,
    );

void main() {
  group('voie PROGRESSIVE — texte cumulé, tranche isolée', () {
    test('3 événements ⇒ texte cumulé EXACT, tranche notifiée 3 fois',
        () async {
      final stream = _ControllablePort();
      final c = _build(streamPort: stream);
      var sliceNotifications = 0;
      var controllerNotifications = 0;
      c.streamingText.addListener(() => sliceNotifications++);
      c.addListener(() => controllerNotifications++);

      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      // Le passage en `generating` a notifié le contrôleur UNE fois, et remis
      // la tranche à '' (une notification de tranche).
      final sliceAtStart = sliceNotifications;
      final controllerAtStart = controllerNotifications;

      stream.emit('Le ');
      await pumpEventQueue();
      stream.emit('Le chat ');
      await pumpEventQueue();
      stream.emit('Le chat dort.');
      await pumpEventQueue();

      expect(c.streamingText.value, 'Le chat dort.');
      expect(sliceNotifications - sliceAtStart, 3,
          reason: 'une notification de tranche PAR fragment');
      expect(controllerNotifications - controllerAtStart, 0,
          reason: 'le contrôleur NE notifie PAS pendant les fragments : la '
              'surface hôte ne se reconstruit pas');
      expect(c.versions, isEmpty,
          reason: 'aucune version tant que le flux n\'est pas terminé');

      await stream.controller.close();
      await pumpEventQueue();
      expect(c.status, ZExplanationStatus.ready);
      expect(c.versions.single.text, 'Le chat dort.');
      c.dispose();
    });

    test('isDone ⇒ version committée sans attendre la fermeture', () async {
      final stream = _ControllablePort();
      final c = _build(streamPort: stream);
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      stream.emit('final', isDone: true);
      await pumpEventQueue();
      expect(c.status, ZExplanationStatus.ready);
      expect(c.currentText, 'final');
      await stream.controller.close();
      c.dispose();
    });

    test('Left EN COURS de flux ⇒ failed, version précédente INTACTE',
        () async {
      final stream = _ControllablePort();
      final c = _build(
        streamPort: stream,
        initial: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
        ],
      );
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      stream.emit('partiel…');
      await pumpEventQueue();
      stream.fail(const ZDomainFailure('quota'));
      await pumpEventQueue();

      expect(c.status, ZExplanationStatus.failed);
      expect(c.lastFailure, isA<ZDomainFailure>());
      expect(c.errorMessage, 'quota');
      expect(c.versions, hasLength(1),
          reason: 'aucune version ajoutée par un flux en échec');
      expect(c.currentText, 'V1',
          reason: 'la version courante n\'est pas écrasée');
      expect(c.streamingText.value, 'V1',
          reason: 'la tranche revient sur la version courante, pas sur le '
              'texte partiel abandonné');
      await stream.controller.close();
      c.dispose();
    });

    test('erreur de FLUX (onError) ⇒ failed sans ZFailure fabriqué', () async {
      final stream = _ControllablePort();
      final c = _build(streamPort: stream);
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      stream.controller.addError(StateError('transport'));
      await pumpEventQueue();
      expect(c.status, ZExplanationStatus.failed);
      expect(c.lastFailure, isNull);
      expect(c.errorMessage, 'MSG_INATTENDU');
      await stream.controller.close();
      c.dispose();
    });

    test('ANNULATION : un flux abandonné n\'écrase pas la version courante',
        () async {
      final stream = _ControllablePort();
      final c = _build(
        streamPort: stream,
        initial: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
        ],
      );
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      stream.emit('en cours…');
      await pumpEventQueue();

      c.abandon();
      // Événements TARDIFS, postérieurs à l'abandon : le jeton a changé.
      stream.emit('texte périmé', isDone: true);
      await pumpEventQueue();
      await stream.controller.close();
      await pumpEventQueue();

      expect(c.versions, hasLength(1));
      expect(c.currentText, 'V1');
      expect(c.status, ZExplanationStatus.ready);
      expect(c.streamingText.value, 'V1');
      c.dispose();
    });
  });

  group('voie ONE-SHOT — inchangée sans port de flux', () {
    test('sans port de flux, c\'est `explain` du port one-shot qui sert',
        () async {
      final port = _RecordingPort();
      final c = _build(port: port);
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      expect(port.seen, hasLength(1));
      expect(c.currentText, 'one-shot:sujet');
      expect(c.status, ZExplanationStatus.ready);
      c.dispose();
    });

    test('port de flux INDISPONIBLE ⇒ repli one-shot, flux jamais sollicité',
        () async {
      final port = _RecordingPort();
      final stream = _ControllablePort(available: false);
      final c = _build(port: port, streamPort: stream);
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      expect(stream.seen, isEmpty);
      expect(port.seen, hasLength(1));
      expect(c.currentText, 'one-shot:sujet');
      c.dispose();
    });

    test('Left ⇒ failed avec lastFailure ; exception ⇒ failed sans', () async {
      final failing = _RecordingPort(
        result: Left<ZFailure, String>(const ZDomainFailure('refus')),
      );
      final c1 = _build(port: failing);
      c1.explain(const ZAiExplanationRequest(content: 'x'));
      await pumpEventQueue();
      expect(c1.status, ZExplanationStatus.failed);
      expect(c1.lastFailure, isA<ZDomainFailure>());
      expect(c1.errorMessage, 'refus');
      c1.dispose();

      final throwing = _RecordingPort(throws: true);
      final c2 = _build(port: throwing);
      c2.explain(const ZAiExplanationRequest(content: 'x'));
      await pumpEventQueue();
      expect(c2.status, ZExplanationStatus.failed);
      expect(c2.lastFailure, isNull);
      expect(c2.errorMessage, 'MSG_INATTENDU');
      c2.dispose();
    });

    test('texte VIDE ⇒ empty, historique INTACT', () async {
      final port = _RecordingPort(result: Right<ZFailure, String>('   '));
      final c = _build(
        port: port,
        initial: const <ZExplanationVersion>[ZExplanationVersion(text: 'V1')],
      );
      c.explain(const ZAiExplanationRequest(content: 'x'));
      await pumpEventQueue();
      expect(c.status, ZExplanationStatus.empty);
      expect(c.versions, hasLength(1));
      expect(c.currentText, 'V1');
      expect(c.errorMessage, 'MSG_VIDE');
      c.dispose();
    });
  });

  group('HISTORIQUE de versions', () {
    test('régénérer ⇒ NOUVELLE version, l\'ancienne reste accessible et '
        '`select` la restaure EXACTEMENT', () async {
      var call = 0;
      final port = _RecordingPort();
      final c = ZExplanationController(
        port: port,
        messages: _messages,
        operations: _operations,
      );
      // Deux générations successives via le port enregistreur (contenu
      // différent ⇒ textes différents).
      c.explain(const ZAiExplanationRequest(content: 'A'));
      await pumpEventQueue();
      call++;
      c.regenerate();
      await pumpEventQueue();

      expect(call, 1);
      expect(c.versions, hasLength(2));
      expect(c.currentIndex, 1);
      expect(c.versions.first.text, 'one-shot:A');
      expect(c.versions.first.operation, isNull,
          reason: 'la version initiale ne porte aucune opération');
      expect(c.versions[1].operation, 'OP_REFAIRE');

      c.select(0);
      expect(c.currentIndex, 0);
      expect(c.current, equals(c.versions.first),
          reason: '`select` restaure la version À L\'IDENTIQUE');
      expect(c.currentText, 'one-shot:A');

      c.redo();
      expect(c.currentIndex, 1);
      c.undo();
      expect(c.currentIndex, 0);
      expect(c.canUndo, isFalse);
      c.dispose();
    });

    test('la liste rendue est NON MODIFIABLE', () async {
      final c = _build(
        initial: const <ZExplanationVersion>[ZExplanationVersion(text: 'V1')],
      );
      expect(
        () => c.versions.add(const ZExplanationVersion(text: 'pirate')),
        throwsUnsupportedError,
      );
      c.dispose();
    });

    test('`select` hors bornes est SANS EFFET', () async {
      final c = _build(
        initial: const <ZExplanationVersion>[ZExplanationVersion(text: 'V1')],
      );
      c
        ..select(-1)
        ..select(7);
      expect(c.currentIndex, 0);
      c.dispose();
    });
  });

  group('OPÉRATIONS — même port, `operation` différente', () {
    test('restyle ⇒ requête portant operation ET style VERBATIM', () async {
      final port = _RecordingPort();
      final c = _build(port: port);
      c.explain(const ZAiExplanationRequest(content: 'sujet', routeId: 'r'));
      await pumpEventQueue();
      c.restyle('STYLE_HOTE_42');
      await pumpEventQueue();

      expect(port.seen, hasLength(2));
      final second = port.seen.last;
      expect(second.operation, 'OP_STYLE');
      expect(second.style, 'STYLE_HOTE_42');
      expect(second.routeId, 'r', reason: 'la route voyage avec la requête');
      expect(second.content, 'one-shot:sujet',
          reason: 'le texte courant est la MATIÈRE du traitement');
      expect(c.versions.last.style, 'STYLE_HOTE_42');
      c.dispose();
    });

    test('condenser/développer portent le TEXTE COURANT ; refaire repart de '
        'la demande d\'origine', () async {
      final port = _RecordingPort();
      final c = _build(port: port);
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      c.summarize();
      await pumpEventQueue();
      expect(port.seen.last.operation, 'OP_CONDENSER');
      expect(port.seen.last.content, 'one-shot:sujet');

      c.elaborate();
      await pumpEventQueue();
      expect(port.seen.last.operation, 'OP_DEVELOPPER');

      c.regenerate();
      await pumpEventQueue();
      expect(port.seen.last.operation, 'OP_REFAIRE');
      expect(port.seen.last.content, 'sujet',
          reason: 'refaire repart de la requête d\'ORIGINE, jamais du texte '
              'déjà produit');
      c.dispose();
    });

    test('clé d\'opération NON injectée ⇒ méthode SANS EFFET', () async {
      final port = _RecordingPort();
      final c = ZExplanationController(
        port: port,
        messages: _messages,
        // Aucune clé : l'hôte n'offre aucun traitement.
      );
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      c
        ..summarize()
        ..elaborate()
        ..regenerate()
        ..restyle('x');
      await pumpEventQueue();
      expect(port.seen, hasLength(1),
          reason: 'aucun traitement ne part sans sa clé');
      expect(c.canSummarize, isFalse);
      expect(c.canRestyle, isFalse);
      c.dispose();
    });

    test('anti-double-soumission : une seule requête en vol', () async {
      final stream = _ControllablePort();
      final port = _RecordingPort();
      final c = _build(port: port, streamPort: stream);
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await pumpEventQueue();
      c.explain(const ZAiExplanationRequest(content: 'autre'));
      await pumpEventQueue();
      expect(stream.seen, hasLength(1));
      await stream.controller.close();
      c.dispose();
    });
  });
}
