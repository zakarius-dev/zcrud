// Doublures PARTAGÉES des gardes de CHAT-2.
//
// 🔴 Source UNIQUE : les recopier dans chaque fichier de garde créerait deux
// définitions divergentes de « ce que fait l'hôte » — la classe de défaut que
// zcrud combat partout ailleurs. Patron :
// `zcrud_chat_kernel/test/support/z_repo_sources.dart`.
//
// ⚠️ Ce fichier n'est PAS un `*_test.dart` : le runner ne l'exécute jamais seul.
library;

import 'dart:async';

import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Une invocation du port de streaming, telle que le contrôleur l'a émise.
typedef ZStreamCall = ({
  ZChatGenerationRequest request,
  ZChatRequestToken token,
});

/// Port de streaming PILOTÉ par le test : chaque appel ouvre un canal distinct.
///
/// 🔴 Un `StreamController` **par appel** : c'est ce qui permet de prouver que
/// deux flux concurrents s'annulent **indépendamment** (le défaut IFFD étant
/// un `CancelToken` d'instance partagé).
class FakeStreamPort implements ZChatStreamPort {
  /// Tous les appels reçus, dans l'ordre — requête ET jeton.
  final List<ZStreamCall> calls = <ZStreamCall>[];

  /// Canaux ouverts, un par appel.
  final List<StreamController<ZResult<ZChatStreamEvent>>> channels =
      <StreamController<ZResult<ZChatStreamEvent>>>[];

  /// Si non `null`, `stream` **lève** — pour prouver AD-10.
  Object? throwOnCall;

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    calls.add((request: request, token: token));
    final Object? boom = throwOnCall;
    if (boom != null) throw boom;
    final StreamController<ZResult<ZChatStreamEvent>> channel =
        StreamController<ZResult<ZChatStreamEvent>>();
    channels.add(channel);
    return channel.stream;
  }

  /// Canal du dernier appel.
  StreamController<ZResult<ZChatStreamEvent>> get last => channels.last;

  /// Canal de l'appel n° [i] (0-indexé).
  StreamController<ZResult<ZChatStreamEvent>> at(int i) => channels[i];

  /// Ferme tous les canaux encore ouverts.
  Future<void> closeAll() async {
    for (final StreamController<ZResult<ZChatStreamEvent>> c in channels) {
      if (!c.isClosed) await c.close();
    }
  }
}

/// Exécuteur d'actions ESPION : compte chaque membre d'effet.
///
/// 🔴 Le compteur est la preuve d'AC « la confirmation PRÉCÈDE l'effet » : un
/// refus doit laisser **tous** les compteurs à zéro.
class SpyExecutor implements ZChatActionExecutor {
  /// Compteur par nom de membre.
  final Map<String, int> calls = <String, int>{};

  /// Impact rendu par l'estimation (le test le règle pour forcer une cascade).
  ZChatActionImpact impact = const ZChatActionImpact(affectedMessageCount: 1);

  /// Identités rendues par les membres qui en rendent.
  List<String> affected = const <String>['m1'];

  /// Si non `null`, chaque membre d'effet rend ce `Left`.
  ZFailure? failWith;

  int _bump(String name) => calls[name] = (calls[name] ?? 0) + 1;

  /// Total des effets RÉELS (l'estimation n'en est pas un).
  int get effectCount => calls.entries
      .where((MapEntry<String, int> e) => e.key != 'estimateImpact')
      .fold<int>(0, (int a, MapEntry<String, int> e) => a + e.value);

  ZResult<T> _result<T>(T value) => failWith == null
      ? Right<ZFailure, T>(value)
      : Left<ZFailure, T>(failWith!);

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async {
    _bump('estimateImpact');
    return Right<ZFailure, ZChatActionImpact>(impact);
  }

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async {
    _bump('editAndResend');
    return _result<List<String>>(affected);
  }

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async {
    _bump('regenerate');
    return _result<List<String>>(affected);
  }

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async {
    _bump('softDeleteMessages');
    return _result<List<String>>(affected);
  }

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async {
    _bump('cancelRequest');
    return _result<Unit>(unit);
  }

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async {
    _bump('renderForCopy');
    return _result<String>('rendu');
  }

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async {
    _bump('executeCustom');
    return _result<List<String>>(affected);
  }
}

/// Fabrique d'identités DÉTERMINISTE (`r0`, `r1`, …).
class SeqIds {
  int _n = 0;

  /// Rend la prochaine identité.
  String next() => 'r${_n++}';
}

/// Contrôleur câblé sur les doublures, prêt à l'emploi.
({
  ZChatController controller,
  FakeStreamPort port,
  SpyExecutor executor,
  SeqIds ids,
  List<ZChatActionPlan> confirmed,
})
buildController({
  bool answer = true,
  int maxResumeAttempts = 2,
  List<ZChatMessage> initialMessages = const <ZChatMessage>[],
  Future<bool> Function(ZChatActionPlan plan)? confirm,
}) {
  final FakeStreamPort port = FakeStreamPort();
  final SpyExecutor executor = SpyExecutor();
  final SeqIds ids = SeqIds();
  final List<ZChatActionPlan> asked = <ZChatActionPlan>[];
  final ZChatController controller = ZChatController(
    streamPort: port,
    actionExecutor: executor,
    confirm: (ZChatActionPlan plan) async {
      asked.add(plan);
      if (confirm != null) return confirm(plan);
      return answer;
    },
    newRequestId: ids.next,
    buildRequest: (ZChatDraft draft) => ZChatGenerationRequest(
      style: ZChatGenerationStyle('test'),
      subject: draft.text,
      attachmentIds: draft.attachmentIds,
    ),
    maxResumeAttempts: maxResumeAttempts,
    initialMessages: initialMessages,
  );
  return (
    controller: controller,
    port: port,
    executor: executor,
    ids: ids,
    confirmed: asked,
  );
}

/// Raccourci : un événement « jeton de texte ».
ZResult<ZChatStreamEvent> tok(String content, {String? seq}) =>
    Right<ZFailure, ZChatStreamEvent>(
      ZChatTokenEvent(content: content, sequenceId: seq),
    );

/// Raccourci : l'événement terminal.
ZResult<ZChatStreamEvent> done({String id = 'm1', String? seq}) =>
    Right<ZFailure, ZChatStreamEvent>(
      ZChatDoneEvent(messageId: id, conversationId: 'c1', sequenceId: seq),
    );

/// Raccourci : un `Left` d'interruption.
ZResult<ZChatStreamEvent> interrupted(String requestId, {bool byUser = false}) =>
    Left<ZFailure, ZChatStreamEvent>(
      ZChatStreamInterruptedFailure(
        'coupure',
        requestId: requestId,
        cancelledByUser: byUser,
      ),
    );
