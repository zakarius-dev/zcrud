/// Adaptateur **SSE** du port de streaming — `ZChatSseStreamPort`,
/// `ZChatSseOpener`, `ZChatSseLineDecoder`, [zChatSseJsonLineDecoder].
///
/// ## Deux fonctions de l'hôte, tout le reste est porté
///
/// Pour brancher un backend SSE sur `ZChatStreamPort`, un hôte fournit :
///
/// 1. un **ouvreur** ([ZChatSseOpener]) — comment il ouvre son POST
///    (URL, authentification, charge utile) et rend le flux d'octets de la
///    réponse ;
/// 2. un **décodeur de ligne** ([ZChatSseLineDecoder]) — comment une ligne de
///    données devient un `ZChatStreamEvent`. Pour un backend qui émet un
///    objet JSON par ligne avec un discriminant `type`, le décodeur
///    [zChatSseJsonLineDecoder] suffit.
///
/// L'adaptateur porte le reste : décodage des octets ([zChatSseLines]),
/// annulation par jeton, fermeture de la source, conversion des conditions
/// de transport en `Left` typé (invariant AD-5), et la règle du port —
/// un flux qui s'arrête sans fin propre est une
/// `ZChatStreamInterruptedFailure`.
///
/// ## Fin propre, fin subie, annulation
///
/// * fin **propre** : un `ZChatDoneEvent` a été décodé, **ou** la sentinelle
///   `data: [DONE]` a été reçue — le flux rendu se ferme sans `Left` ;
/// * fin **subie** : la source se termine ou lève avant l'un des deux —
///   dernier élément `Left(ZChatStreamInterruptedFailure(cancelledByUser:
///   false))`, avec le nombre d'événements déjà rendus ;
/// * **annulation** du jeton : la source est libérée immédiatement et le
///   dernier élément est `Left(ZChatStreamInterruptedFailure(cancelledByUser:
///   true))` — le même signal que le port de référence.
///
/// ## Tolérance (invariant AD-10)
///
/// Un décodeur qui rend `null` **saute** la ligne ; un décodeur qui **lève**
/// la saute aussi, sans tuer le flux (la ligne fautive est perdue, jamais
/// les suivantes). Un ouvreur qui lève rend un seul `Left`
/// (`ZChatStreamInterruptedFailure`, zéro événement reçu).
library;

import 'dart:async';
import 'dart:convert';

import 'package:zcrud_core/domain.dart';

import '../../domain/ai/z_chat_ai_failure.dart';
import '../../domain/ai/z_chat_generation_port.dart';
import '../../domain/ai/z_chat_request_token.dart';
import '../../domain/ai/z_chat_stream_event.dart';
import 'z_chat_sse_line.dart';

/// Ouvre le flux d'**octets** d'une génération, tel que l'hôte sait le faire.
///
/// Le socle ne fait aucune requête : c'est ici que vivent l'URL,
/// l'authentification et la traduction de [ZChatGenerationRequest] en charge
/// utile. Le [ZChatRequestToken] est transmis pour que l'hôte puisse, s'il le
/// souhaite, transporter `requestId`/`lastSequenceId` vers son backend ; il
/// n'a **pas** à écouter `whenCancelled` — l'adaptateur annule l'abonnement
/// au flux rendu dès l'annulation, et appelle [ZChatSseStreamPort.onClose].
typedef ZChatSseOpener = Future<Stream<List<int>>> Function(
  ZChatGenerationRequest request,
  ZChatRequestToken token,
);

/// Décode **une** ligne SSE en événement de flux.
///
/// Reçoit **toutes** les lignes — données, séparateurs, champs de protocole —
/// pour qu'un décodeur qui accumule un événement multi-lignes puisse le
/// borner. Rend :
///
/// * `null` — la ligne ne produit aucun événement (séparateur, commentaire,
///   fragment accumulé, sentinelle `[DONE]`…) ;
/// * `Right(event)` — un événement à émettre ; un `ZChatDoneEvent` marque la
///   fin propre du flux ;
/// * `Left(failure)` — une trame d'erreur typée du backend, émise telle
///   quelle ; le flux **continue** (c'est le backend qui décide s'il ferme).
///
/// Un décodeur qui copie [ZChatSseLine.sequenceId] dans l'événement rend la
/// reprise (`ZChatRequestToken.resumeFrom`) possible ; sans cela, l'appelant
/// ne connaît pas sa position.
typedef ZChatSseLineDecoder = ZResult<ZChatStreamEvent>? Function(
  ZChatSseLine line,
);

/// Décodeur pour un backend qui émet **un objet JSON par ligne de données**,
/// avec le discriminant `type` de `ZChatStreamEvent.fromJson`.
///
/// * lignes non-données, sentinelle `[DONE]`, JSON illisible, objet sans
///   `type` ⇒ `null` (ligne sautée — jamais une erreur, invariant AD-10) ;
/// * sans `sequence_id`/`id` dans l'objet, la position SSE courante
///   ([ZChatSseLine.sequenceId]) est portée sur l'événement : la reprise ne
///   dépend pas de ce que le backend répète dans sa charge utile ;
/// * sans `type` dans l'objet mais avec un `event:` SSE dans le bloc, le nom
///   d'événement tient lieu de discriminant (usage courant du protocole).
ZChatSseLineDecoder zChatSseJsonLineDecoder({
  ZTypeRegistry? typeRegistry,
  ZSourceRegistry? sourceRegistry,
}) {
  return (ZChatSseLine line) {
    if (!line.isData || line.isDone) return null;
    final Map<String, dynamic>? map = zJsonMap(
      zJsonGuard<Object?>(() => jsonDecode(line.value) as Object?),
    );
    if (map == null) return null;
    final Map<String, dynamic> enriched = <String, dynamic>{
      ...map,
      if (!map.containsKey('sequence_id') &&
          !map.containsKey('id') &&
          line.sequenceId != null)
        'id': line.sequenceId,
      if (!map.containsKey(kZChatStreamEventTypeKey) && line.eventName != null)
        kZChatStreamEventTypeKey: line.eventName,
    };
    final ZChatStreamEvent? event = ZChatStreamEvent.fromJson(
      enriched,
      typeRegistry: typeRegistry,
      sourceRegistry: sourceRegistry,
    );
    return event == null ? null : Right<ZFailure, ZChatStreamEvent>(event);
  };
}

/// `ZChatStreamPort` sur un transport **Server-Sent Events**, paramétré par
/// l'ouvreur et le décodeur de l'hôte.
///
/// Sans état : deux appels concurrents de [stream] ouvrent deux sources,
/// portent deux jetons, et s'annulent indépendamment. L'instance peut être
/// `const` et partagée.
class ZChatSseStreamPort implements ZChatStreamPort {
  /// Construit l'adaptateur.
  ///
  /// [onClose] est appelé **une fois par requête**, avec son jeton, à la
  /// libération de la source (fin, `[DONE]`, annulation, erreur). C'est le
  /// point où l'hôte coupe ce que l'annulation de l'abonnement ne coupe pas
  /// d'elle-même.
  const ZChatSseStreamPort({
    required this.open,
    required this.decode,
    this.onClose,
  });

  /// L'ouvreur de l'hôte.
  final ZChatSseOpener open;

  /// Le décodeur de ligne de l'hôte.
  final ZChatSseLineDecoder decode;

  /// Rappel de libération, par requête.
  final void Function(ZChatRequestToken token)? onClose;

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    late final StreamController<ZResult<ZChatStreamEvent>> out;
    StreamSubscription<ZChatSseLine>? lines;
    int received = 0;
    bool graceful = false;
    bool closed = false;

    void emit(ZResult<ZChatStreamEvent> r) {
      if (!closed && !out.isClosed) out.add(r);
    }

    void finish({ZFailure? failure}) {
      if (closed) return;
      closed = true;
      final StreamSubscription<ZChatSseLine>? s = lines;
      lines = null;
      unawaited(s?.cancel());
      if (failure != null && !out.isClosed) {
        out.add(Left<ZFailure, ZChatStreamEvent>(failure));
      }
      if (!out.isClosed) unawaited(out.close());
    }

    ZChatStreamInterruptedFailure interrupted(String message) =>
        ZChatStreamInterruptedFailure(
          message,
          requestId: token.requestId,
          eventsReceived: received,
          cancelledByUser: token.isCancelled,
        );

    void onLine(ZChatSseLine line) {
      if (closed) return;
      if (line.isDone) graceful = true;
      ZResult<ZChatStreamEvent>? decoded;
      try {
        decoded = decode(line);
      } catch (_) {
        // Un décodeur qui lève perd SA ligne, jamais le flux (AD-10).
        decoded = null;
      }
      if (decoded == null) return;
      decoded.fold(
        (ZFailure _) {},
        (ZChatStreamEvent e) {
          received++;
          if (e is ZChatDoneEvent) graceful = true;
        },
      );
      emit(decoded);
    }

    Future<void> start() async {
      if (token.isCancelled) {
        finish(failure: interrupted('cancelled before open'));
        return;
      }
      final Stream<List<int>> bytes;
      try {
        bytes = await open(request, token);
      } catch (error) {
        if (closed) return;
        onClose?.call(token);
        finish(failure: interrupted('open threw: $error'));
        return;
      }
      if (closed) {
        // L'abonné est parti pendant l'ouverture : la source n'est jamais
        // écoutée, mais l'hôte doit pouvoir couper ce qu'il a ouvert.
        onClose?.call(token);
        return;
      }
      lines = zChatSseLines(
        bytes,
        token: token,
        onClose: () => onClose?.call(token),
      ).listen(
        onLine,
        onError: (Object error, StackTrace _) {
          finish(failure: interrupted('stream error: $error'));
        },
        onDone: () {
          if (closed) return;
          if (token.isCancelled) {
            finish(failure: interrupted('cancelled'));
          } else if (graceful) {
            finish();
          } else {
            finish(failure: interrupted('stream ended before done'));
          }
        },
        cancelOnError: true,
      );
    }

    out = StreamController<ZResult<ZChatStreamEvent>>(
      onListen: () => unawaited(start()),
      onPause: () => lines?.pause(),
      onResume: () => lines?.resume(),
      onCancel: () => finish(),
    );
    return out.stream;
  }
}
