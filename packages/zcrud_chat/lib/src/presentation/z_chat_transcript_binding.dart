/// La **persistance du fil** d'une conversation — `ZChatTranscriptBinding`.
///
/// ## Une mécanique, deux compositions
///
/// Le pont entre un [ZChatTranscriptPort] et un [ZChatController] est le
/// même pour un fil de travail (notebook) et pour une conversation simple :
///
/// * **flux → messages** : un abonnement unique au fil du dépôt ; le premier
///   instantané **amorce** le contrôleur (`attach`), les suivants sont
///   relayés à [onChanged] sans rebrancher le fil — un `attach` annulerait
///   toute requête en vol ;
/// * **envoi → persistance** : chaque message nouveau du fil du contrôleur
///   est ajouté au dépôt (`append`), chaque message connu qui change y est
///   mis à jour (`update`) ; ce qui vient du dépôt n'y retourne pas.
///
/// `ZChatNotebookController` et `ZChatConversationController` **composent**
/// cette pièce ; aucun des deux ne la réécrit.
///
/// ## Règle du fil vierge
///
/// Une lecture qui échoue ouvre un fil **vide**, jamais un écran mort : un
/// flux qui lève avant tout instantané amorce le contrôleur sur la liste
/// vide ; un port dont `messages` lève à l'appel vaut la même chose.
///
/// ## Échecs : publiés, jamais levés
///
/// Chaque `Left` d'écriture — et chaque exception du port — est publié sur la
/// tranche [lastFailure] ; le fil affiché n'en est pas affecté.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_controller.dart';

/// Reçoit un instantané **postérieur à l'amorce** : le fil tel que le dépôt
/// le voit, et les identités des messages qui diffèrent de l'instantané
/// précédent. N'est jamais appelé pour le premier instantané.
typedef ZChatTranscriptSnapshotListener =
    void Function(List<ZChatMessage> snapshot, Set<String> changedMessageIds);

/// Le pont entre le fil d'un dépôt et le fil d'un contrôleur de conversation.
class ZChatTranscriptBinding {
  /// Ouvre le fil de [conversationId] sur [transcript] et le lie à [chat].
  ///
  /// L'abonnement est pris ici, une fois ; il est tenu jusqu'à [dispose].
  /// [onChanged] reçoit chaque instantané après le premier. Le contrôleur
  /// [chat] n'est **pas** détenu : son propriétaire le libère après cette
  /// pièce.
  ZChatTranscriptBinding({
    required ZChatTranscriptPort transcript,
    required ZChatController chat,
    required String conversationId,
    ZChatTranscriptSnapshotListener? onChanged,
    // Un paramètre nommé ne peut pas s'appeler `_x` : les formels privés
    // sont interdits en Dart, et rendre ces champs publics élargirait la
    // surface de la pièce. Même arbitrage que `ZChatController`.
    // ignore: prefer_initializing_formals
  })  : _transcript = transcript,
        // ignore: prefer_initializing_formals
        _chat = chat,
        // ignore: prefer_initializing_formals
        _conversationId = conversationId,
        // ignore: prefer_initializing_formals
        _onChanged = onChanged {
    _chat.messages.addListener(_onThreadChanged);
    Stream<List<ZChatMessage>> source;
    try {
      source = transcript.messages(conversationId);
    } catch (error) {
      // Un port qui lève à l'appel vaut une lecture qui échoue avant tout
      // instantané : `zChatTranscriptOrEmpty` en fait un fil vide.
      source = Stream<List<ZChatMessage>>.error(error);
    }
    // UN abonnement. `zChatTranscriptOrEmpty` applique la règle du fil
    // vierge et relâche la source immédiatement à l'annulation.
    _subscription = zChatTranscriptOrEmpty(source).listen(_onSnapshot);
  }

  final ZChatTranscriptPort _transcript;
  final ZChatController _chat;
  final String _conversationId;
  final ZChatTranscriptSnapshotListener? _onChanged;

  StreamSubscription<List<ZChatMessage>>? _subscription;
  bool _attached = false;
  bool _disposed = false;

  /// Dernier instantané reçu du dépôt.
  List<ZChatMessage> _latest = const <ZChatMessage>[];

  /// Messages déjà écrits au dépôt, par identité, tels qu'écrits.
  final Map<String, ZChatMessage> _written = <String, ZChatMessage>{};

  final ValueNotifier<ZFailure?> _lastFailure = ValueNotifier<ZFailure?>(null);

  /// Identité de la conversation liée.
  String get conversationId => _conversationId;

  /// Le dernier instantané reçu du dépôt (vide avant l'amorce).
  List<ZChatMessage> get latest => _latest;

  /// `true` dès que le premier instantané a amorcé le contrôleur.
  bool get isAttached => _attached;

  /// Dernier échec d'écriture au dépôt, ou `null`.
  ValueListenable<ZFailure?> get lastFailure => _lastFailure;

  void _onSnapshot(List<ZChatMessage> snapshot) {
    if (_disposed) return;
    if (!_attached) {
      _attached = true;
      _latest = snapshot;
      // Base d'écriture : ce qui vient du dépôt n'y retourne pas.
      for (final ZChatMessage m in snapshot) {
        final String? id = m.id;
        if (id != null) _written[id] = m;
      }
      _chat.attach(conversationId: _conversationId, messages: snapshot);
      return;
    }
    // Instantanés suivants : relayés avec les identités qui ont changé. Le
    // fil du contrôleur n'est PAS rebranché.
    final Map<String, ZChatMessage> before = <String, ZChatMessage>{
      for (final ZChatMessage m in _latest)
        if (m.id != null) m.id!: m,
    };
    _latest = snapshot;
    final Set<String> changed = <String>{
      for (final ZChatMessage m in snapshot)
        if (m.id != null && before[m.id!] != m) m.id!,
    };
    _onChanged?.call(snapshot, changed);
  }

  /// Écrit au dépôt ce que le fil du contrôleur a de neuf : un message
  /// inconnu est ajouté, un message connu qui a changé est mis à jour.
  void _onThreadChanged() {
    if (_disposed) return;
    for (final ZChatMessage m in _chat.messages.value) {
      final String? id = m.id;
      if (id == null) continue;
      final ZChatMessage? known = _written[id];
      if (known == m) continue;
      _written[id] = m;
      unawaited(_write(
        () => known == null ? _transcript.append(m) : _transcript.update(m),
      ));
    }
  }

  /// Un port qui lève — à l'appel ou dans son futur — vaut un `Left` : rien
  /// ne remonte dans la notification du fil.
  Future<void> _write(Future<ZResult<ZChatMessage>> Function() call) async {
    ZResult<ZChatMessage> result;
    try {
      result = await call();
    } catch (error) {
      result = Left<ZFailure, ZChatMessage>(
        ZDomainFailure('chat transcript port threw ${error.runtimeType}'),
      );
    }
    if (_disposed) return;
    result.fold(
      (ZFailure f) => _lastFailure.value = f,
      (ZChatMessage _) {},
    );
  }

  /// Annule l'abonnement au dépôt, cesse d'écouter le contrôleur et ferme la
  /// tranche d'échec. Ne libère pas le contrôleur.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _chat.messages.removeListener(_onThreadChanged);
    _lastFailure.dispose();
  }
}
