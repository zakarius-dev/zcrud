/// Requête de rendu **neutre** d'une COQUILLE de conversation — CHAT-3b.
///
/// ## 🔴 Le défaut que ce fichier corrige, mesuré par le lot C6
///
/// La couture de rendu de CHAT-3 est **par BLOC** ([ZChatBlockRenderRequest]).
/// Or `SfAIAssistView` de Syncfusion n'est pas un rendu de bloc : c'est une
/// **coquille de liste**. Faute de couture à ce niveau, l'adaptateur C6 a livré
/// un **widget parallèle** à `ZChatConversationView` — et un hôte qui choisissait
/// Syncfusion **perdait** la région live (`liveAnnouncement`), le dépli inline et
/// `ZChatMessageTile`. Deux vues destinées à diverger : c'est le motif
/// **CR-LEX-78**, un doublon né d'une couture placée au mauvais niveau.
///
/// ## Ce qui traverse la requête, et ce qui n'y entre PAS
///
/// Patron strict de `ZListRenderRequest`
/// (`zcrud_core/lib/src/presentation/list/z_list_render_request.dart`) : un value
/// object **immuable**, sans dépendance lourde, sans widget **déjà construit**.
///
/// 🔴 **Pourquoi [itemBuilder] n'est PAS une entorse à « sans widget ».** Ce
/// n'est pas un widget, c'est une **fabrique paresseuse** — exactement ce que
/// `SliverChildBuilderDelegate` échange avec `ListView.builder`. Porter des
/// widgets **construits** obligerait le socle à matérialiser les N tuiles avant
/// de connaître le viewport (la dette d'IFFD : 0 `ListView.builder` sur
/// 5153 lignes) ; ne rien porter du tout obligerait la coquille à **reconstruire
/// la tuile elle-même**, donc à réimplémenter le dépli inline et la tuile — le
/// doublon qu'on retire. La fabrique est le seul point fixe qui autorise à la
/// fois la virtualisation ET la non-perte.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Fabrique paresseuse d'un élément de la conversation, à l'index donné.
///
/// Fournie **par le socle**, appelée **par la coquille**. Elle produit la tuile
/// complète (`ZChatMessageTile` avec son dépli inline, ou la tuile de la réponse
/// en cours abonnée à la tranche par requête). Une coquille qui l'ignore perd
/// tout ce que le socle garantit — d'où la garde de non-perte.
typedef ZChatShellItemBuilder = Widget Function(BuildContext context, int index);

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
  /// Elles occupent les index `[messages.length, itemCount[`.
  final List<String> activeRequestIds;

  /// Fabrique de l'élément à l'index donné — cf. [ZChatShellItemBuilder].
  final ZChatShellItemBuilder itemBuilder;

  /// Marge **directionnelle** demandée par l'hôte (AD-13). `null` ⇒ la coquille
  /// applique la sienne.
  final EdgeInsetsDirectional? padding;

  /// Liste inversée (dernier message en bas, ancrage naturel d'un chat).
  final bool reverse;

  /// Nombre total d'éléments : messages établis **plus** réponses en cours.
  int get itemCount => messages.length + activeRequestIds.length;

  /// `true` si [index] désigne une réponse **encore en cours** de rédaction.
  bool isStreamingAt(int index) =>
      index >= messages.length && index < itemCount;

  /// Le message établi à [index], ou `null` si l'index désigne une réponse en
  /// cours (ou sort des bornes). **Ne lève jamais** (AD-10) : une coquille
  /// tierce indexe comme elle veut, et un hors-bornes ne doit pas faire tomber
  /// la conversation.
  ZChatMessage? messageAt(int index) =>
      index >= 0 && index < messages.length ? messages[index] : null;

  /// L'identité de requête à [index], ou `null` si l'index n'est pas celui d'une
  /// réponse en cours. **Ne lève jamais** (AD-10).
  String? requestIdAt(int index) => isStreamingAt(index)
      ? activeRequestIds[index - messages.length]
      : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatShellRenderRequest &&
          runtimeType == other.runtimeType &&
          _sameList<ZChatMessage>(messages, other.messages) &&
          _sameList<String>(activeRequestIds, other.activeRequestIds) &&
          identical(itemBuilder, other.itemBuilder) &&
          padding == other.padding &&
          reverse == other.reverse;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    Object.hashAll(messages),
    Object.hashAll(activeRequestIds),
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
}
