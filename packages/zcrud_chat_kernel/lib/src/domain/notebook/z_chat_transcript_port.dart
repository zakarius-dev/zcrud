/// Le **fil** d'une conversation — `ZChatTranscriptPort` (lecture **et**
/// écriture), la règle du fil vierge ([zChatTranscriptOrEmpty]) et une
/// implémentation en mémoire de référence ([ZChatInMemoryTranscript]).
///
/// ## Lecture et écriture, dans le même port
///
/// Un fil qu'on lit sans pouvoir y écrire n'est pas un fil : une
/// conversation tenue dessus est perdue en quittant l'écran. Le port porte
/// donc les deux voies. La lecture est un `Stream<List<ZChatMessage>>`
/// **nu** (invariant AD-11) ; les écritures rendent `ZResult`.
///
/// ## La règle du fil vierge
///
/// L'échec d'une lecture ouvre un fil **vierge**, jamais un écran mort : si
/// le flux source lève avant d'avoir émis, [zChatTranscriptOrEmpty] émet une
/// liste vide ; s'il lève après, le dernier instantané reste celui qui est
/// affiché. L'erreur ne traverse jamais le flux rendu.
///
/// ## Amorcer une fois, rester abonné
///
/// Le consommateur du flux **s'abonne une fois** et reste abonné : le premier
/// instantané amorce le fil, les suivants le tiennent à jour. Rebrancher le
/// fil à chaque instantané couperait une génération en cours.
library;

import 'dart:async';

import 'package:zcrud_core/domain.dart';

import '../z_chat_message.dart';

/// Port du fil d'une conversation — implémenté par l'hôte.
abstract interface class ZChatTranscriptPort {
  /// Les messages de [conversationId], en instantanés successifs, **dans
  /// l'ordre du fil**. Le premier instantané peut être vide (fil neuf).
  Stream<List<ZChatMessage>> messages(String conversationId);

  /// Ajoute [message] en fin de fil et rend le message **tel qu'enregistré**
  /// (identité attribuée, horodatage éventuel).
  Future<ZResult<ZChatMessage>> append(ZChatMessage message);

  /// Remplace le message de même identité et rend le message tel
  /// qu'enregistré. Un message sans identité, ou inconnu, est un `Left`.
  Future<ZResult<ZChatMessage>> update(ZChatMessage message);
}

/// Rend [source] **sans erreur** : une erreur survenue avant tout instantané
/// devient une liste vide ; après, le flux se ferme sur le dernier instantané
/// reçu. Une lecture qui échoue n'est jamais un écran mort.
///
/// Annuler l'abonnement au flux rendu **désabonne [source] immédiatement** —
/// sans attendre un instantané suivant. Un écouteur distant (un `snapshots()`
/// de base de données, par exemple) est donc relâché au `dispose` de
/// l'écran, pas à la prochaine écriture. Le flux rendu est à abonnement
/// unique ; [source] n'est écoutée qu'à l'abonnement ; la pause est propagée.
Stream<List<ZChatMessage>> zChatTranscriptOrEmpty(
  Stream<List<ZChatMessage>> source,
) {
  // Un générateur `async*` suspendu dans son `await for` ne propage le
  // `cancel` à la source qu'au prochain événement : un contrôleur explicite
  // tient l'abonnement et l'annule dans `onCancel`, sans attendre.
  late final StreamController<List<ZChatMessage>> controller;
  StreamSubscription<List<ZChatMessage>>? subscription;
  bool emitted = false;

  void close() {
    if (!controller.isClosed) unawaited(controller.close());
  }

  controller = StreamController<List<ZChatMessage>>(
    onListen: () {
      subscription = source.listen(
        (List<ZChatMessage> snapshot) {
          emitted = true;
          controller.add(snapshot);
        },
        onError: (Object _, StackTrace _) {
          if (!emitted) controller.add(const <ZChatMessage>[]);
          close();
        },
        onDone: close,
        cancelOnError: true,
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () {
      final StreamSubscription<List<ZChatMessage>>? s = subscription;
      subscription = null;
      return s?.cancel();
    },
  );
  return controller.stream;
}

/// Implémentation en mémoire de [ZChatTranscriptPort] — référence du contrat
/// et fil volatil pour les tests.
///
/// Attribue une identité (`<conversationId>:m<n>`) à un message qui n'en a
/// pas ; conserve celle qu'il porte sinon. Les abonnés reçoivent l'instantané
/// courant à l'abonnement, puis chaque changement.
class ZChatInMemoryTranscript implements ZChatTranscriptPort {
  /// Construit un fil vide.
  ZChatInMemoryTranscript();

  final Map<String, List<ZChatMessage>> _byConversation =
      <String, List<ZChatMessage>>{};
  final Map<String, StreamController<List<ZChatMessage>>> _controllers =
      <String, StreamController<List<ZChatMessage>>>{};
  int _sequence = 0;

  List<ZChatMessage> _snapshot(String conversationId) =>
      List<ZChatMessage>.unmodifiable(
        _byConversation[conversationId] ?? const <ZChatMessage>[],
      );

  StreamController<List<ZChatMessage>> _controller(String conversationId) =>
      _controllers.putIfAbsent(
        conversationId,
        () => StreamController<List<ZChatMessage>>.broadcast(),
      );

  void _publish(String conversationId) {
    final StreamController<List<ZChatMessage>>? c =
        _controllers[conversationId];
    if (c != null && !c.isClosed) c.add(_snapshot(conversationId));
  }

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) async* {
    yield _snapshot(conversationId);
    yield* _controller(conversationId).stream;
  }

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) async {
    final ZChatMessage stored = message.id == null
        ? message.copyWith(id: '${message.conversationId}:m${++_sequence}')
        : message;
    _byConversation
        .putIfAbsent(stored.conversationId, () => <ZChatMessage>[])
        .add(stored);
    _publish(stored.conversationId);
    return Right<ZFailure, ZChatMessage>(stored);
  }

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) async {
    final String? id = message.id;
    if (id == null) {
      return const Left<ZFailure, ZChatMessage>(
        ZDomainFailure('cannot update a message without id'),
      );
    }
    final List<ZChatMessage>? list = _byConversation[message.conversationId];
    final int index =
        list?.indexWhere((ZChatMessage m) => m.id == id) ?? -1;
    if (list == null || index < 0) {
      return Left<ZFailure, ZChatMessage>(
        ZNotFoundFailure('message $id not found in transcript'),
      );
    }
    list[index] = message;
    _publish(message.conversationId);
    return Right<ZFailure, ZChatMessage>(message);
  }

  /// Ferme les flux ouverts.
  Future<void> dispose() async {
    for (final StreamController<List<ZChatMessage>> c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }
}
