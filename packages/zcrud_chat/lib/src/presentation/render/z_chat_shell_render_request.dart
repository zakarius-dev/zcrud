/// Requête de rendu neutre d'une coquille de conversation.
///
/// ## Pourquoi ce port existe séparément du rendu par bloc
///
/// La couture de rendu par bloc ([ZChatBlockRenderRequest]) ne couvre pas le
/// cas d'une coquille de liste tierce (un widget qui remplace le conteneur
/// défilant entier, pas seulement un message). Sans couture à ce niveau, un
/// adaptateur qui remplace la liste perdrait la région live d'accessibilité,
/// le dépli inline et `ZChatMessageTile` — deux vues indépendantes destinées
/// à diverger. Cette requête ferme ce niveau.
///
/// ## Ce qui traverse la requête, et ce qui n'y entre pas
///
/// Suit le patron strict de `ZListRenderRequest` (`zcrud_core`) : un value
/// object immuable, sans dépendance lourde, sans widget déjà construit.
///
/// [itemBuilder] n'est pas une entorse à « sans widget » : c'est une fabrique
/// paresseuse, exactement ce que `SliverChildBuilderDelegate` échange avec
/// `ListView.builder`. Porter des widgets déjà construits obligerait le socle
/// à matérialiser toutes les tuiles avant de connaître le viewport ; ne rien
/// porter du tout obligerait la coquille à reconstruire la tuile elle-même,
/// donc à réimplémenter le dépli inline. La fabrique est le seul point fixe
/// qui autorise à la fois la virtualisation et la non-perte de
/// fonctionnalité.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Fabrique paresseuse d'un élément de la conversation, à l'index donné.
///
/// Fournie **par le socle**, appelée **par la coquille**. Elle produit la tuile
/// complète (`ZChatMessageTile` avec son dépli inline, ou la tuile de la réponse
/// en cours abonnée à la tranche par requête). Une coquille qui l'ignore perd
/// tout ce que le socle garantit — d'où la garde de non-perte.
typedef ZChatShellItemBuilder =
    Widget Function(BuildContext context, int index);

/// Un élément du fil dans l'ordre d'affichage : un message établi, ou un
/// tour encore en vol.
class ZChatShellSlot {
  /// Message établi.
  const ZChatShellSlot.message(this.message) : requestId = null;

  /// Tour en vol, identifié par [requestId].
  const ZChatShellSlot.streaming(this.requestId) : message = null;

  /// Message établi, ou `null` si l'élément est un tour en vol.
  final ZChatMessage? message;

  /// Identité de la requête en vol, ou `null` si l'élément est un message.
  final String? requestId;
}

/// Fil d'affichage : messages établis, tours ancrés insérés à leur index,
/// tours sans ancre après le dernier message.
///
/// [streamAnchors] donne, pour une requête, l'index d'insertion dans
/// [messages] (`0` avant le premier, `messages.length` après le dernier).
/// Une requête absente de la carte va en fin. Plusieurs requêtes au même
/// index restent dans l'ordre de [activeRequestIds].
List<ZChatShellSlot> zChatThreadSlots({
  required List<ZChatMessage> messages,
  required List<String> activeRequestIds,
  Map<String, int> streamAnchors = const <String, int>{},
}) {
  final Map<int, List<String>> buckets = <int, List<String>>{};
  final List<String> tail = <String>[];
  for (final String id in activeRequestIds) {
    final int? at = streamAnchors[id];
    if (at == null) {
      tail.add(id);
      continue;
    }
    final int index = at.clamp(0, messages.length);
    (buckets[index] ??= <String>[]).add(id);
  }
  final List<ZChatShellSlot> slots = <ZChatShellSlot>[];
  for (int i = 0; i < messages.length; i++) {
    final List<String>? before = buckets[i];
    if (before != null) {
      for (final String id in before) {
        slots.add(ZChatShellSlot.streaming(id));
      }
    }
    slots.add(ZChatShellSlot.message(messages[i]));
  }
  final List<String>? end = buckets[messages.length];
  if (end != null) {
    for (final String id in end) {
      slots.add(ZChatShellSlot.streaming(id));
    }
  }
  for (final String id in tail) {
    slots.add(ZChatShellSlot.streaming(id));
  }
  return slots;
}

/// Ce qu'une coquille reçoit pour rendre le CADRE d'une conversation.
///
/// Immuable, égalité de **valeur** (les fonctions sont comparées par identité) —
/// cohérent avec `ZListRenderRequest` et [ZChatBlockRenderRequest].
class ZChatShellRenderRequest {
  /// Construit une requête de rendu de coquille.
  const ZChatShellRenderRequest({
    required this.messages,
    required this.activeRequestIds,
    required this.itemBuilder,
    this.streamAnchors = const <String, int>{},
    this.padding,
    this.reverse = false,
  });

  /// Messages **établis**, dans l'ordre chronologique.
  ///
  /// Donnée neutre : une coquille tierce y lit ce que son modèle exige (rôle,
  /// horodatage, identité) sans que le socle ait à connaître ce modèle. C'est
  /// ainsi que `AssistMessage.request`/`.response` se construit sans qu'aucun
  /// type Syncfusion n'apparaisse ici.
  final List<ZChatMessage> messages;

  /// Identités des requêtes **en vol**, dans l'ordre de lancement.
  ///
  /// Leur place dans le fil dépend de [streamAnchors]. Sans ancre, elles
  /// suivent le dernier message.
  final List<String> activeRequestIds;

  /// Index d'insertion de chaque requête ancrée, dans [messages].
  ///
  /// Une requête absente est rendue après le dernier message. `0` la place
  /// avant le premier message.
  final Map<String, int> streamAnchors;

  /// Fabrique de l'élément à l'index donné — cf. [ZChatShellItemBuilder].
  final ZChatShellItemBuilder itemBuilder;

  /// Marge directionnelle demandée par l'hôte (invariant AD-13). `null`
  /// signifie que la coquille applique la sienne.
  final EdgeInsetsDirectional? padding;

  /// Liste inversée (dernier message en bas, ancrage naturel d'un chat).
  final bool reverse;

  /// Nombre total d'éléments : messages établis **plus** réponses en cours.
  int get itemCount => messages.length + activeRequestIds.length;

  /// Éléments dans l'ordre d'affichage. Même ordre que [itemBuilder].
  List<ZChatShellSlot> get slots => zChatThreadSlots(
    messages: messages,
    activeRequestIds: activeRequestIds,
    streamAnchors: streamAnchors,
  );

  /// `true` si [index] désigne une réponse **encore en cours** de rédaction.
  bool isStreamingAt(int index) {
    final List<ZChatShellSlot> laid = slots;
    return index >= 0 && index < laid.length && laid[index].requestId != null;
  }

  /// Le message établi à [index], ou `null` si l'index désigne une réponse en
  /// cours (ou sort des bornes). Ne lève jamais (invariant AD-10) : une
  /// coquille tierce indexe comme elle veut, et un hors-bornes ne doit pas
  /// faire tomber la conversation.
  ZChatMessage? messageAt(int index) {
    final List<ZChatShellSlot> laid = slots;
    if (index < 0 || index >= laid.length) return null;
    return laid[index].message;
  }

  /// L'identité de requête à [index], ou `null` si l'index n'est pas celui
  /// d'une réponse en cours. Ne lève jamais (invariant AD-10).
  String? requestIdAt(int index) {
    final List<ZChatShellSlot> laid = slots;
    if (index < 0 || index >= laid.length) return null;
    return laid[index].requestId;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatShellRenderRequest &&
          runtimeType == other.runtimeType &&
          _sameList<ZChatMessage>(messages, other.messages) &&
          _sameList<String>(activeRequestIds, other.activeRequestIds) &&
          _sameAnchors(streamAnchors, other.streamAnchors) &&
          identical(itemBuilder, other.itemBuilder) &&
          padding == other.padding &&
          reverse == other.reverse;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    Object.hashAll(messages),
    Object.hashAll(activeRequestIds),
    _anchorsHash(streamAnchors),
    itemBuilder,
    padding,
    reverse,
  );

  @override
  String toString() =>
      'ZChatShellRenderRequest(items: $itemCount, active: '
      '${activeRequestIds.length}, reverse: $reverse)';

  /// Égalité élément par élément — aucun `package:collection` (AD-1).
  static bool _sameList<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameAnchors(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry<String, int> entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _anchorsHash(Map<String, int> anchors) {
    final List<String> keys = anchors.keys.toList()..sort();
    return Object.hashAll(<Object?>[
      for (final String key in keys) Object.hash(key, anchors[key]),
    ]);
  }
}
