/// Mapper **conversation → demande de génération de flashcards** (CHAT-8).
///
/// ## Ce fichier ne définit AUCUN port, AUCUNE provenance, AUCUN DTO de requête
///
/// Tout existe déjà, et le doubler produirait une seconde source APPAUVRIE —
/// le piège CR-LEX-78, déjà payé trois fois dans ce dépôt :
///
/// | Besoin | Ce qui existe DÉJÀ | Où |
/// |---|---|---|
/// | contrat de génération IA | `ZFlashcardGenerationPort` | `zcrud_study` |
/// | requête (contenu, `count`, `typesDistribution`, `provenance`, `modelId`…) | `ZFlashcardGenerationRequest` | `zcrud_study` |
/// | bornage du `count`, répartition par type | `zClampGenerationCount` / `zEvenTypesDistribution` / `zNormalizeTypesDistribution` | `zcrud_study` |
/// | provenance « issue d'une conversation » | `ZConversationSource` (`kind: 'conversation'`, `conversation_id` + `message_id`) | `zcrud_flashcard` |
/// | texte annonçable d'un bloc quelconque | `ZContentBlock.accessibleText()` | `zcrud_chat_kernel` |
///
/// Ce module ne fournit que la **projection** qui manquait : passer d'un
/// `ZChatMessage`/`ZChatConversation` au `ZFlashcardGenerationRequest` que le
/// port attend, provenance comprise.
///
/// ## Pourquoi `accessibleText()` et pas `ZChatMessage.content`
///
/// `content` ne concatène QUE les `ZTextBlock`. Or la matière première d'une
/// flashcard, dans une réponse d'assistant d'étude, est très souvent dans un
/// bloc **non textuel** : `ZKeyDefinitionBlock` (terme/définition — une carte
/// presque déjà écrite), `ZTableBlock`, `ZComparisonTableBlock`,
/// `ZTimelineBlock`. S'appuyer sur `content` jetterait silencieusement
/// exactement ce qu'il fallait apprendre. `accessibleText()` est la
/// **projection textuelle neutre déjà écrite** pour toute la famille OUVERTE de
/// blocs — y compris les blocs d'hôte inconnus du socle (AD-4).
///
/// ## AD-12 — aucun prompt ici
///
/// Le contenu transmis est **neutre** : du texte de conversation, jamais une
/// instruction système, jamais un endpoint, jamais une clé. Le fil de prompt
/// reste CÔTÉ APP, dans l'implémentation du port.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Rôles retenus par défaut pour constituer la matière d'étude.
///
/// `system` est exclu : ce sont des **instructions**, pas du savoir à réviser —
/// en faire des cartes produirait des flashcards sur le prompt. `unknown` est
/// exclu parce qu'un rôle non reconnu (AD-10 : `ZChatRole.fromJson` y retombe)
/// n'a aucune sémantique sur laquelle fonder une carte.
const Set<ZChatRole> kZChatStudyDefaultRoles = <ZChatRole>{
  ZChatRole.user,
  ZChatRole.assistant,
};

/// Séparateur entre deux messages dans le contenu d'une requête de conversation.
///
/// Constante **unique** : deux littéraux `'\n\n'` recopiés divergeraient sans
/// que rien ne rougisse.
const String kZChatStudyMessageSeparator = '\n\n';

/// Projection textuelle **neutre** d'un message (tous blocs confondus).
///
/// Concatène l'`accessibleText()` de chaque bloc, en sautant les vides. Ne lève
/// **jamais** (AD-10) : un message sans bloc rend `''`.
String zChatMessageStudyText(
  ZChatMessage message, {
  ZAccessibleTextResolver? resolver,
}) {
  final List<String> parts = <String>[
    for (final ZContentBlock block in message.contentBlocks)
      if (block.accessibleText(resolver: resolver).trim().isNotEmpty)
        block.accessibleText(resolver: resolver).trim(),
  ];
  return parts.join(kZChatStudyMessageSeparator);
}

/// Projection textuelle **neutre** d'une suite de messages.
///
/// Filtre par [roles] (défaut [kZChatStudyDefaultRoles]) puis joint les textes
/// non vides. L'ordre d'entrée est **préservé** (déterminisme).
String zChatMessagesStudyText(
  Iterable<ZChatMessage> messages, {
  Set<ZChatRole> roles = kZChatStudyDefaultRoles,
  ZAccessibleTextResolver? resolver,
}) {
  final List<String> parts = <String>[
    for (final ZChatMessage m in messages)
      if (roles.contains(m.role))
        if (zChatMessageStudyText(m, resolver: resolver).isNotEmpty)
          zChatMessageStudyText(m, resolver: resolver),
  ];
  return parts.join(kZChatStudyMessageSeparator);
}

/// Provenance d'un **message** précis (`ZConversationSource` — RÉUTILISÉE).
///
/// `id` éphémère (`null`) → `''`, exactement le repli que
/// `ZFlashcardSource.fromJson` applique déjà à un `message_id` absent : la
/// provenance round-trippe donc à l'identique au lieu de faire échouer la
/// génération (AD-10).
ZConversationSource zChatMessageProvenance(ZChatMessage message) =>
    ZConversationSource(
      conversationId: message.conversationId,
      messageId: message.id ?? '',
    );

/// Provenance d'une **conversation entière**.
///
/// `messageId: ''` signifie « la conversation, pas un message précis ». On ne
/// choisit **pas** arbitrairement le dernier message : ce serait une provenance
/// FAUSSE (elle désignerait un message qui n'a pas produit la carte à lui seul).
ZConversationSource zChatConversationProvenance(
  ZChatConversation conversation,
) =>
    ZConversationSource(
      conversationId: conversation.id ?? '',
      messageId: '',
    );

/// Construit la requête de génération d'un **message** (câblage du port).
///
/// `count` et `typesDistribution` traversent les normaliseurs **existants** de
/// `zcrud_study` — jamais une règle de bornage recopiée ici.
ZFlashcardGenerationRequest zChatMessageGenerationRequest(
  ZChatMessage message, {
  int? count,
  String? languageTag,
  Map<ZFlashcardType, int>? typesDistribution,
  List<ZFlashcardType> types = ZFlashcardType.values,
  String? instructions,
  String? modelId,
  Map<String, dynamic> extra = const <String, dynamic>{},
  ZAccessibleTextResolver? resolver,
}) =>
    _request(
      content: zChatMessageStudyText(message, resolver: resolver),
      provenance: zChatMessageProvenance(message),
      count: count,
      languageTag: languageTag,
      typesDistribution: typesDistribution,
      types: types,
      instructions: instructions,
      modelId: modelId,
      extra: extra,
    );

/// Construit la requête de génération d'une **conversation** (câblage du port).
ZFlashcardGenerationRequest zChatConversationGenerationRequest(
  ZChatConversation conversation,
  Iterable<ZChatMessage> messages, {
  int? count,
  String? languageTag,
  Map<ZFlashcardType, int>? typesDistribution,
  List<ZFlashcardType> types = ZFlashcardType.values,
  String? instructions,
  String? modelId,
  Set<ZChatRole> roles = kZChatStudyDefaultRoles,
  Map<String, dynamic> extra = const <String, dynamic>{},
  ZAccessibleTextResolver? resolver,
}) =>
    _request(
      content: zChatMessagesStudyText(
        messages,
        roles: roles,
        resolver: resolver,
      ),
      provenance: zChatConversationProvenance(conversation),
      count: count,
      languageTag: languageTag,
      typesDistribution: typesDistribution,
      types: types,
      instructions: instructions,
      modelId: modelId,
      extra: extra,
    );

/// Fabrique commune — **site unique** de câblage des normaliseurs `zcrud_study`.
///
/// 🔴 AD-19.1 : [extra] est assaini des clés de sync réservées
/// (`ZSyncMeta.reservedKeys`) AVANT d'entrer dans la requête. Le DTO les filtre
/// aussi à la lecture, mais compter là-dessus reviendrait à laisser ce module
/// **émettre** une clé possédée par le store — la garde `reserved-keys` a
/// justement rougi sur cet oubli ailleurs dans le dépôt.
ZFlashcardGenerationRequest _request({
  required String content,
  required ZFlashcardSource provenance,
  required int? count,
  required String? languageTag,
  required Map<ZFlashcardType, int>? typesDistribution,
  required List<ZFlashcardType> types,
  required String? instructions,
  required String? modelId,
  required Map<String, dynamic> extra,
}) {
  final int clamped = zClampGenerationCount(count);
  return ZFlashcardGenerationRequest(
    content: content,
    count: clamped,
    languageTag: languageTag,
    provenance: provenance,
    // `null` reste `null` : la requête documente « l'app/le module de défauts
    // calcule une répartition ». Inventer ici une répartition équitable
    // supprimerait cette distinction — et donc le droit de l'hôte à décider.
    typesDistribution: typesDistribution == null
        ? null
        : zNormalizeTypesDistribution(
            typesDistribution,
            types: types,
            countIfNull: clamped,
          ),
    instructions: instructions,
    modelId: modelId,
    extra: zSanitizeExtra(extra, ZSyncMeta.reservedKeys),
  );
}
