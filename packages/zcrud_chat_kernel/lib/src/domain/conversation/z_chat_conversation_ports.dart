/// Ports de **gestion de conversation** — épinglage, recherche, partage,
/// retrait (CHAT-9 ; AD-5, AD-9, AD-10, AD-11).
///
/// origine **MESURÉE sur disque** (lecture seule) :
/// `lex_douane/backend/app/api/v1/chat/conversations.py` (routes) et
/// `lex_douane/backend/app/services/conversation_service.py` (sémantique
/// réelle). Rien n'est modélisé ici qui n'ait été **lu** dans l'un des deux.
///
/// ## 🔴 AD-11 — des PORTS, pas du transport
///
/// lex expose ces capacités en HTTP (`GET /search`, `POST /{id}/pin`,
/// `DELETE /{id}/pin`, `POST /{id}/share`, `GET /shared/{share_id}`). **Aucune**
/// de ces formes n'entre ici : ni verbe HTTP, ni chemin, ni code de statut, ni
/// en-tête. Un hôte Firestore-only, un hôte purement local et un hôte REST
/// implémentent les mêmes interfaces. Le grep négatif **G9-P4** le prouve.
///
/// ## 🔴 Ce que lex fait et qu'on NE copie PAS — mais pas ce qu'on croyait
///
/// Le brief de ce lot annonçait « la suppression de conversation de lex est un
/// hard-delete ». **Mesuré : c'est faux.** `DELETE /conversations/{conv_id}`
/// appelle `soft_delete_conversation`, qui pose `deleted_at`
/// (`conversation_service.py:225-240`) ; `batch_delete_conversations`
/// (`:569-605`) fait de même ; et `search_conversations` (`:606+`) filtre
/// `where("deleted_at", "==", None)`. Sur la **conversation**, lex est
/// conforme à l'esprit d'AD-9.
///
/// Le hard-delete existe bien, mais **ailleurs**, et c'est lui qui diverge :
///
/// | Site lex | Nature | Statut ici |
/// |---|---|---|
/// | `soft_delete_conversation` (`:225`) | soft (`deleted_at`) | **porté** — [ZChatConversationLifecyclePort.retire] |
/// | `batch_delete_conversations` (`:569`) | soft, par lot | **porté** — [ZChatConversationLifecyclePort.retireAll] |
/// | `delete_messages_after` (`:~500`) | **HARD** — `batch.delete(msg.reference)` | **REFUSÉ tel quel** — [ZChatConversationLifecyclePort.trimAfter] est contractuellement SOFT |
/// | `delete_conversation` (`:242`) | **HARD** (purge + messages) | **non porté** — aucune route ne l'appelle chez lex (code écrit et inerte) |
///
/// ⇒ Aucun membre de ce fichier ne promet une purge. Le contrat de
/// [ZChatConversationLifecyclePort] l'écrit noir sur blanc, et la garde
/// **G9-P5** interdit qu'un verbe de purge (`purge`, `hardDelete`, `erase`,
/// `wipe`) apparaisse dans le paquet.
///
/// ## 🔴 AD-10 — « absent » et « désactivé » doivent rester INDISCERNABLES
///
/// C'est le piège que ce lot devait éviter, et il a un site **exact** ici :
/// [ZChatConversationHit.matchingMessages]. lex renvoie littéralement
/// `"matching_messages": None` quand la recherche n'a porté que sur les titres
/// (`include_messages=False`, le **défaut** de la route), et une liste quand
/// elle a porté sur les messages. Modéliser ce champ par une `List` non
/// nullable le remplacerait par `[]` — qui signifierait « on a cherché dans les
/// messages et n'a rien trouvé ». C'est **faux**, silencieusement, et ça
/// changerait ce que l'interface doit afficher. Le champ est donc **nullable**,
/// et la distinction est gardée par **G9-P2**.
///
/// Même règle pour [ZChatShareLink.expiresAt] : lex expire à 7 jours
/// (`conversation_service.py:475+`), mais un hôte sans expiration doit rendre
/// `null` — jamais une date bidon, jamais l'époque zéro.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_conversation.dart';
import '../z_chat_enums.dart';
import '../z_chat_message.dart';

/// Bornes de pagination **mesurées** sur `conversations.py` — transcrites une
/// seule fois, jamais dupliquées dans les deux sens de lecture.
///
/// ⚠️ Ce sont des **défauts**, pas des plafonds imposés : le socle ne peut pas
/// savoir ce que le backend d'un hôte accepte. Il ne **rejette** donc rien —
/// c'est l'adaptateur qui borne, là où la contrainte est réelle (AD-11).
const int kZChatSearchDefaultLimit = 20;

/// Nombre minimal de caractères d'une recherche, tel que lex le déclare
/// (`q: str = Query(..., min_length=2)`).
///
/// Exposé comme **constante consultable**, jamais comme un `assert` : un hôte
/// dont le backend accepte une lettre n'a pas à être cassé par notre socle.
const int kZChatSearchMinQueryLength = 2;

/// Une requête de **recherche** de conversations — immuable, neutre.
///
/// Champs mesurés sur `search_conversations` (route + service). Rien de plus :
/// ni tri, ni filtre de date, ni facette — lex n'en a aucun, et les inventer
/// serait exactement la faute que ce lot doit éviter.
class ZChatConversationQuery {
  /// Construit une requête.
  const ZChatConversationQuery({
    required this.text,
    this.includeMessages = false,
    this.limit = kZChatSearchDefaultLimit,
    this.cursor,
  });

  /// Le terme cherché, **verbatim**.
  ///
  /// Le socle ne le normalise pas : lex passe en minuscules côté serveur
  /// (`query.lower()`), et une normalisation faite deux fois n'est pas
  /// idempotente pour toutes les locales (`İ` turc). L'adaptateur normalise
  /// dans le vocabulaire de SON backend.
  final String text;

  /// `true` pour chercher aussi dans le **corps des messages**.
  ///
  /// Défaut `false` — celui de lex (`include_messages: bool = Query(default=False)`).
  final bool includeMessages;

  /// Nombre maximal de résultats souhaité.
  final int limit;

  /// Curseur de pagination **opaque** (AD-11 : jamais un offset numérique, la
  /// pagination du dépôt est par curseur), ou `null` pour la première page.
  final String? cursor;

  /// `true` si [text] atteint la longueur minimale que lex exige.
  ///
  /// Un hôte peut s'en servir pour ne pas appeler son backend pour rien ; le
  /// socle, lui, n'en fait **rien** — il ne bloque aucune requête.
  bool get meetsMinimumLength => text.trim().length >= kZChatSearchMinQueryLength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatConversationQuery &&
          text == other.text &&
          includeMessages == other.includeMessages &&
          limit == other.limit &&
          cursor == other.cursor;

  @override
  int get hashCode => Object.hash(text, includeMessages, limit, cursor);

  @override
  String toString() =>
      'ZChatConversationQuery(${text.length} chars, '
      'includeMessages: $includeMessages, limit: $limit)';
}

/// Un extrait de message qui a **répondu** à la recherche.
///
/// Forme mesurée sur le `snippet` que lex construit
/// (`conversation_service.py` : `{"message_id", "role", "snippet",
/// "created_at"}`). [snippet] est le texte **déjà découpé par le backend** —
/// le socle ne re-découpe rien : la fenêtre de 200 caractères de lex est une
/// décision de **son** backend, pas une règle de socle.
class ZChatMessageSnippet {
  /// Construit un extrait.
  const ZChatMessageSnippet({
    required this.messageId,
    this.role = ZChatRole.unknown,
    this.snippet = '',
    this.createdAt,
  });

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ou identité vide
  /// ⇒ `null` (un extrait sans message cible n'est pas navigable).
  static ZChatMessageSnippet? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String id = zJsonString(map['message_id']);
    if (id.isEmpty) return null;
    return ZChatMessageSnippet(
      messageId: id,
      role: ZChatRole.fromJson(map['role']),
      snippet: zJsonString(map['snippet']),
      createdAt: zJsonDate(map['created_at']),
    );
  }

  /// Identité du message concerné.
  final String messageId;

  /// Rôle de l'auteur — `unknown` si le backend ne le dit pas.
  final ZChatRole role;

  /// L'extrait textuel, tel que rendu par le backend.
  final String snippet;

  /// Date du message, ou `null` si absente/illisible.
  final DateTime? createdAt;

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'message_id': messageId,
    'role': role.jsonValue,
    'snippet': snippet,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatMessageSnippet &&
          messageId == other.messageId &&
          role == other.role &&
          snippet == other.snippet &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(messageId, role, snippet, createdAt);

  @override
  String toString() => 'ZChatMessageSnippet($messageId, ${snippet.length} chars)';
}

/// Clé persistée des extraits d'une recherche — déclarée **une seule fois**,
/// consommée par le décodage ET par le retrait qui l'empêche de polluer
/// `ZChatConversation.extra`.
const String kZChatMatchingMessagesKey = 'matching_messages';

/// Un résultat de recherche : la conversation, plus **éventuellement** les
/// extraits qui ont répondu.
class ZChatConversationHit {
  /// Construit un résultat.
  const ZChatConversationHit({
    required this.conversation,
    this.matchingMessages,
  });

  /// Décode **défensivement** (AD-10) — ne lève jamais.
  ///
  /// 🔴 `matching_messages` **absent** ou `null` ⇒ [matchingMessages] `null`
  /// (« la recherche par message n'a pas eu lieu »), une **liste vide** ⇒
  /// `const []` (« elle a eu lieu et n'a rien trouvé »). Les deux cas ne sont
  /// pas confondus : c'est tout l'objet de **G9-P2**.
  static ZChatConversationHit? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final Object? rawSnippets = map[kZChatMatchingMessagesKey];
    // 🔴 `matching_messages` est une donnée de RÉSULTAT DE RECHERCHE, pas un
    // champ de la conversation. Sans ce retrait, `ZChatConversation.fromMap`
    // le verserait dans `extra` (il n'est dans aucune clé réservée) : la
    // conversation repartirait en persistance avec les extraits collés dessus,
    // et une conversation trouvée ne serait plus égale à la même conversation
    // lue normalement. Le retrait est fait ICI, une seule fois.
    final Map<String, dynamic> body = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in map.entries)
        if (e.key != kZChatMatchingMessagesKey) e.key: e.value,
    };
    return ZChatConversationHit(
      // `fromMap` applique déjà `zSanitizeExtra` (AD-19.1) : les clés de sync
      // réservées d'un document brut n'entrent jamais dans `extra`.
      conversation: ZChatConversation.fromMap(body),
      matchingMessages: rawSnippets is List
          ? zJsonDecodeList<ZChatMessageSnippet>(
                  rawSnippets,
                  ZChatMessageSnippet.fromJson,
                ) ??
                const <ZChatMessageSnippet>[]
          : null,
    );
  }

  /// La conversation trouvée.
  final ZChatConversation conversation;

  /// Les extraits de messages, ou **`null` si la recherche n'a pas porté sur
  /// les messages** (AD-10 : « absent » ≠ « zéro »).
  final List<ZChatMessageSnippet>? matchingMessages;

  /// `true` si la recherche a effectivement inspecté les messages.
  ///
  /// Ce getter existe pour qu'un hôte n'ait **jamais** à écrire
  /// `hit.matchingMessages?.isEmpty ?? true` — la forme exacte qui aplatit les
  /// deux cas et fait disparaître la distinction que le modèle protège.
  bool get searchedMessages => matchingMessages != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatConversationHit &&
          conversation == other.conversation &&
          ((matchingMessages == null && other.matchingMessages == null) ||
              (matchingMessages != null &&
                  other.matchingMessages != null &&
                  zListEquals(matchingMessages!, other.matchingMessages!)));

  @override
  int get hashCode => Object.hash(
    conversation,
    matchingMessages == null ? null : zListHash(matchingMessages!),
  );

  @override
  String toString() =>
      'ZChatConversationHit(${conversation.id}, '
      'matchingMessages: ${matchingMessages?.length})';
}

/// Le lien de partage produit par [ZChatConversationSharePort.share].
///
/// Forme mesurée sur le retour de `share_conversation`
/// (`{"share_id", "share_url", "expires_at"}`).
///
/// [url] est une chaîne **opaque** : lex rend un chemin relatif (`/shared/…`),
/// un autre hôte rendra une URL absolue ou un lien profond. Le socle ne la
/// parse pas, ne la préfixe pas et n'en déduit rien (AD-11).
class ZChatShareLink {
  /// Construit un lien de partage.
  const ZChatShareLink({required this.shareId, this.url, this.expiresAt});

  /// Décode **défensivement** (AD-10) — identité vide ⇒ `null`.
  static ZChatShareLink? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String id = zJsonString(map['share_id']);
    if (id.isEmpty) return null;
    return ZChatShareLink(
      shareId: id,
      url: zJsonStringOrNull(map['share_url']),
      expiresAt: zJsonDate(map['expires_at']),
    );
  }

  /// Identité opaque du partage.
  final String shareId;

  /// Adresse à communiquer, ou `null` si l'hôte la fabrique lui-même.
  final String? url;

  /// 🔴 Date d'expiration, ou **`null` quand le partage n'expire pas** — ou
  /// quand l'hôte ne le dit pas. Jamais une date inventée : un lien réputé
  /// expiré à tort disparaîtrait de l'interface alors qu'il fonctionne encore.
  final DateTime? expiresAt;

  /// `true` si [expiresAt] est **connu et dépassé** à [now].
  ///
  /// ⚠️ `expiresAt == null` rend **`false`** : « je ne sais pas » n'est pas
  /// « c'est expiré ». C'est le même arbitrage que partout ailleurs dans ce
  /// fichier — un inconnu ne devient jamais une affirmation.
  bool isExpiredAt(DateTime now) {
    final DateTime? at = expiresAt;
    return at != null && !at.isAfter(now);
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'share_id': shareId,
    if (url != null) 'share_url': url,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatShareLink &&
          shareId == other.shareId &&
          url == other.url &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(shareId, url, expiresAt);

  @override
  String toString() => 'ZChatShareLink($shareId, expiresAt: $expiresAt)';
}

/// L'instantané **en lecture seule** d'une conversation partagée.
///
/// lex en fait une **copie physique** des messages dans une collection
/// distincte (`shared_conversations/{share_id}/messages`) : le partage est un
/// gel, pas une vue. Le type le dit — il n'y a ici **aucun** verbe d'écriture,
/// et il ne porte pas d'`id` de conversation d'origine : un lecteur anonyme n'a
/// pas à connaître l'identité privée du document source.
class ZChatSharedConversation {
  /// Construit un instantané partagé.
  const ZChatSharedConversation({
    required this.shareId,
    this.title = '',
    this.messages = const <ZChatMessage>[],
    this.createdAt,
    this.expiresAt,
  });

  /// Identité du partage.
  final String shareId;

  /// Titre gelé au moment du partage.
  final String title;

  /// Messages gelés, dans l'ordre.
  final List<ZChatMessage> messages;

  /// Date de création du partage, ou `null`.
  final DateTime? createdAt;

  /// Date d'expiration, ou `null` (cf. [ZChatShareLink.expiresAt]).
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSharedConversation &&
          shareId == other.shareId &&
          title == other.title &&
          zListEquals(messages, other.messages) &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode =>
      Object.hash(shareId, title, zListHash(messages), createdAt, expiresAt);

  @override
  String toString() =>
      'ZChatSharedConversation($shareId, ${messages.length} messages)';
}

/// Port de **recherche** de conversations (AD-5 : `Either`, jamais une liste
/// nue ; AD-10 : jamais une exception).
///
/// Un hôte qui ne sait pas chercher rend
/// `Left(ZUnsupportedOperationFailure(…, operation: 'searchConversations'))` —
/// type **EXISTANT** du cœur, jamais un booléen `supportsSearch` que l'appelant
/// devrait penser à lire.
abstract interface class ZChatConversationSearchPort {
  /// Cherche les conversations répondant à [query].
  Future<ZResult<List<ZChatConversationHit>>> searchConversations(
    ZChatConversationQuery query,
  );
}

/// Port d'**épinglage** d'une conversation.
///
/// 🔴 **Un verbe, pas deux.** lex a deux routes (`POST /pin`,
/// `DELETE /pin`) et deux méthodes de service quasi identiques
/// (`pin_conversation` / `unpin_conversation`, `:457-473`), qui ne diffèrent
/// que par la valeur écrite. Deux sites d'appel, c'est deux endroits où
/// oublier le filtre `deleted_at` — et deux endroits à corriger. Ici,
/// [setPinned] est le **site unique**, `pinned` est un paramètre. C'est la même
/// discipline que `ZChatActionDispatcher` (garde G-U1).
abstract interface class ZChatConversationPinPort {
  /// Épingle ([pinned] `true`) ou désépingle la conversation [conversationId].
  ///
  /// Rend la conversation **telle que le store la voit après l'écriture** —
  /// pas un `Unit` : l'appelant a besoin du `pinnedAt` réel (horodaté par le
  /// serveur chez lex) pour trier, et le redemander serait un aller-retour de
  /// plus pour une donnée qu'on vient d'écrire.
  Future<ZResult<ZChatConversation>> setPinned(
    String conversationId, {
    required bool pinned,
  });
}

/// Port de **partage** d'une conversation.
///
/// ⚠️ **Aucune révocation.** lex n'expose aucune route pour retirer un partage
/// (grep sur `conversations.py` : `share` n'apparaît qu'en création et en
/// lecture). Déclarer ici un `revokeShare` que rien n'implémente donnerait à
/// l'hôte la certitude fausse que le socle sait défaire un partage. Le manque
/// est **signalé, pas comblé** — un hôte qui sait révoquer le fait par son
/// propre port, hors socle.
abstract interface class ZChatConversationSharePort {
  /// Produit un lien de partage pour [conversationId].
  ///
  /// lex refuse de partager une conversation **vide** (`ValueError`) : un hôte
  /// qui reprend cette règle rend `Left(ZDomainFailure(…))`. Le socle
  /// n'impose pas la règle — il n'a pas les messages sous la main — mais il
  /// laisse la place pour la dire.
  Future<ZResult<ZChatShareLink>> share(String conversationId);

  /// Lit l'instantané public d'un partage.
  ///
  /// Un lien expiré rend `Left` (chez lex : HTTP 410) ; un lien inconnu rend
  /// `Left(ZNotFoundFailure(…))`. Jamais un instantané vide, qui se lirait
  /// comme « conversation sans message ».
  Future<ZResult<ZChatSharedConversation>> sharedConversation(String shareId);
}

/// Port de **cycle de vie** — retrait et élagage, **jamais** purge (AD-9).
///
/// 🔴 Le contrat de ce port est **SOFT dans les trois membres**. Une
/// implémentation qui supprimerait physiquement le document le viole, même si
/// elle compile : `is_deleted`/`updated_at` de `ZSyncMeta` sont l'unique
/// mécanisme de retrait du dépôt, et une purge rend le merge Last-Write-Wins
/// incapable de propager le retrait aux autres appareils (le distant réhydrate
/// ce que le local a effacé).
abstract interface class ZChatConversationLifecyclePort {
  /// Retire [conversationId] — **soft-delete** (`is_deleted = true` dans
  /// `ZSyncMeta`, hors-entité).
  ///
  /// Pendant neutre de `soft_delete_conversation` (`conversation_service.py:225`).
  Future<ZResult<Unit>> retire(String conversationId);

  /// Restaure une conversation retirée.
  ///
  /// 🔴 **Cette opération n'a pas d'équivalent chez lex** — et c'est
  /// précisément ce que le soft-delete rend possible et que le hard-delete
  /// interdit. Elle est donc l'**argument** du choix AD-9, pas un ornement.
  Future<ZResult<Unit>> restore(String conversationId);

  /// Retire tous les messages **postérieurs** à [messageId] — **soft**.
  ///
  /// 🔴 **Le point où l'on refuse lex.** `delete_messages_after` fait
  /// `batch.delete(msg_doc.reference)` : la reprise d'un tour de conversation
  /// détruit irréversiblement les messages, et un autre appareil qui n'a pas
  /// encore synchronisé les réémettra. Ici, les messages sont **marqués
  /// retirés**, jamais effacés.
  ///
  /// Rend le **nombre** de messages retirés — la forme de lex
  /// (`{"deleted": N}`), qui est réellement utile à l'interface.
  Future<ZResult<int>> trimAfter({
    required String conversationId,
    required String messageId,
  });

  /// Retire un **lot** de conversations en une opération — soft, comme
  /// `batch_delete_conversations` (`:569`).
  ///
  /// Rend le nombre effectivement retiré. lex distingue aussi les `not_found`
  /// (inexistants **ou déjà retirés**) ; cette distinction n'est **pas**
  /// portée : lex l'aplatit lui-même en un seul compteur, et la reconstruire
  /// ici serait inventer une information que le backend n'a pas transmise.
  Future<ZResult<int>> retireAll(List<String> conversationIds);
}
