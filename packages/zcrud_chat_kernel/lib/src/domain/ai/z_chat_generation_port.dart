/// Ports IA de la conversation — `ZChatGenerationPort` / `ZChatStreamPort`
/// (CHAT-1, AD-5/AD-10/AD-11/AD-12).
///
/// ## Un port de génération UNIQUE, paramétré par style
///
/// IFFD écrit **sept** variantes de reformulation comme sept fonctions et sept
/// endpoints (`iffd/lib/src/domain/repositories/ai_repository.dart:36-47` et
/// `:253-286`), qui ne diffèrent **que par le prompt**. Un seul contrat
/// `generate(request)` les couvre : le style est une **donnée**
/// ([ZChatGenerationStyle], ouverte par [ZTypeRegistry] — AD-4), pas une
/// signature.
///
/// ## 🔴 CE QUE CES PORTS NE COUVRENT PAS — ports EXISTANTS à câbler
///
/// La génération d'**artefacts structurés** depuis des notes a **déjà** ses
/// ports dans ce dépôt, et ils n'ont **aucun consommateur** :
///
/// | Besoin IFFD | Port **EXISTANT** | Chemin |
/// |---|---|---|
/// | `generateFlashcardsFromNotes` | `ZFlashcardGenerationPort` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart` |
/// | `generateMindmapFromNotes` | `ZMindmapGenerationPort` | `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart` |
///
/// ⛔ **Aucun style `flashcards`/`mindmap` n'est déclaré ici**, et aucun membre
/// de ce fichier ne génère de carte : ce serait un doublon **plus pauvre** que
/// l'existant (les ports d'étude portent `typesDistribution`, `maxDepth`,
/// `provenance`, `ZFlashcardSource`), c'est-à-dire le motif CR-LEX-78 à la
/// lettre. Un hôte branche **les deux** : ces ports-ci pour le texte, ceux de
/// `zcrud_study` pour les artefacts. Le noyau de chat ne peut de toute façon
/// pas en dépendre (AD-1 : une seule arête sortante, `zcrud_core`) — garde
/// **G17**. Garde **G-C7** : ni style ni membre de génération d'artefact ici.
///
/// ## Annulation
///
/// Le [ZChatRequestToken] est un **paramètre requis de l'appel**, jamais un
/// champ d'implémentation : voir `z_chat_request_token.dart` pour le défaut
/// IFFD (jeton d'instance unique) que cette forme rend inexprimable.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_enums.dart';
import '../z_content_block.dart';
import 'z_chat_compute_effort.dart';
import 'z_chat_context_port.dart';
import 'z_chat_generation_style.dart';
import 'z_chat_request_token.dart';
import 'z_chat_stream_event.dart';

/// Requête **immuable** de génération (value object, `==`/`hashCode` par
/// valeur) — **partagée** par le port one-shot et le port de streaming.
///
/// Une seule requête pour les deux ports : la différence entre « je veux la
/// réponse » et « je veux la réponse au fil de l'eau » est un **choix de
/// transport**, pas une différence de demande. lex, qui a trois signatures
/// (`sendMessage`, `regenerateMessage`, `transformMessage`) portant chacune
/// une copie dérivée des mêmes huit paramètres, montre ce que coûte l'inverse.
///
/// Ne porte **aucune** mécanique de transport ni de prompt (AD-12) : ni
/// endpoint, ni clé, ni instruction système assemblée.
class ZChatGenerationRequest {
  /// Construit une requête.
  ZChatGenerationRequest({
    required this.style,
    this.subject = '',
    this.notes = '',
    this.conversationId,
    this.sourceMessageId,
    List<ZChatContextFragment> context = const <ZChatContextFragment>[],
    List<String> attachmentIds = const <String>[],
    this.responseLength,
    this.lengthBias,
    this.computeEffort,
    this.languageTag,
    this.instructions,
    this.modelId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : context = List<ZChatContextFragment>.unmodifiable(
         ZChatContextFragment.ordered(context),
       ),
       attachmentIds = List<String>.unmodifiable(attachmentIds),
       extra = Map<String, dynamic>.unmodifiable(
         zSanitizeExtra(extra, _reservedKeys),
       );

  /// Style demandé — **ouvert** (AD-4).
  final ZChatGenerationStyle style;

  /// Sujet/thème de la demande (`''` si sans objet).
  final String subject;

  /// **Matière première** de la génération : notes d'étude, explication à
  /// retravailler, ou texte du tour de conversation. Une seule fente, parce que
  /// du point de vue du contrat c'est le même rôle — le style dit quoi en
  /// faire.
  final String notes;

  /// Conversation concernée, ou `null`.
  final String? conversationId;

  /// Message source d'une transformation/régénération, ou `null`.
  final String? sourceMessageId;

  /// Fragments de contexte d'étude, **déjà ordonnés** par
  /// [ZChatContextFragment.ordered] à la construction : deux requêtes bâties
  /// avec les mêmes fragments dans un ordre différent sont **égales**, et le
  /// contexte soumis au modèle est reproductible.
  final List<ZChatContextFragment> context;

  /// Identités opaques des pièces jointes.
  final List<String> attachmentIds;

  /// Longueur attendue — enum **EXISTANT** `ZChatResponseLength` (CHAT-0),
  /// jamais redéclaré. `null` ⇒ l'hôte décide.
  final ZChatResponseLength? responseLength;

  /// Biais de longueur d'une régénération — enum **EXISTANT**
  /// `ZChatLengthBias` (CHAT-0). `null` ⇒ sans objet.
  final ZChatLengthBias? lengthBias;

  /// Budget de **calcul** demandé (`1..5`), ou `null` (l'hôte décide).
  ///
  /// 🔴 **Axe ORTHOGONAL** à [responseLength] : la verbosité de la réponse et
  /// le budget de raisonnement sont deux demandes indépendantes. Les fusionner
  /// produirait un réglage qui ne veut rien dire — cf. le faux-ami
  /// `WorkflowEffort`, documenté dans `z_chat_compute_effort.dart`. C'est
  /// l'entier `1..5` commun aux DEUX backends (lex `chat.py:261`, IFFD
  /// `base_request.py:104`) ; l'enum `low/medium/high` d'IFFD s'y projette.
  final ZChatComputeEffort? computeEffort;

  /// Étiquette de langue BCP-47 (`'fr'`), ou `null`.
  final String? languageTag;

  /// Consigne libre neutre transmise telle quelle à l'implémentation, ou
  /// `null`. **Jamais** un prompt système (AD-12).
  final String? instructions;

  /// Identifiant de modèle **OPAQUE**, transporté VERBATIM et **jamais
  /// interprété** : aucun catalogue, aucun `switch`, aucun libellé. Le
  /// catalogue de modèles (et son routage) vit entièrement côté app
  /// (AD-15/AD-35), comme sur `ZFlashcardGenerationRequest.modelId`.
  final String? modelId;

  /// Échappatoire non typée, **normalisée EAGER à la construction** (AD-19.1 :
  /// les clés de sync réservées sont écartées et ne peuvent jamais être
  /// réémises).
  final Map<String, dynamic> extra;

  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatGenerationRequest &&
          style == other.style &&
          subject == other.subject &&
          notes == other.notes &&
          conversationId == other.conversationId &&
          sourceMessageId == other.sourceMessageId &&
          zListEquals(context, other.context) &&
          zListEquals(attachmentIds, other.attachmentIds) &&
          responseLength == other.responseLength &&
          lengthBias == other.lengthBias &&
          computeEffort == other.computeEffort &&
          languageTag == other.languageTag &&
          instructions == other.instructions &&
          modelId == other.modelId &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    style,
    subject,
    notes,
    conversationId,
    sourceMessageId,
    zListHash(context),
    zListHash(attachmentIds),
    responseLength,
    lengthBias,
    computeEffort,
    languageTag,
    instructions,
    modelId,
    zJsonHash(extra),
  );

  @override
  String toString() =>
      'ZChatGenerationRequest(style: ${style.kind}, '
      'conversationId: $conversationId)';
}

/// Port **one-shot** de génération de texte, paramétré par style.
///
/// Rend une **liste de [ZContentBlock]** — la famille ouverte que ce package
/// porte déjà — et non une `String` : c'est le seam large. Une réponse
/// purement textuelle est un `[ZTextBlock(...)]` ; une réponse structurée
/// (tableau, chronologie, diagramme, bloc d'hôte enregistré) n'exige **aucun**
/// changement d'API. Le socle n'a pas à trancher aujourd'hui ce que le
/// fournisseur d'un hôte saura produire demain.
///
/// AD-5 : `Either<ZFailure, ·>`. AD-10 : aucune exception ne s'échappe — les
/// échecs typés sont ceux de `z_chat_ai_failure.dart` (dont
/// `ZQuotaExceededFailure`, type EXISTANT du cœur).
abstract interface class ZChatGenerationPort {
  /// Génère la réponse pour [request], annulable par [token] — **ce** jeton, et
  /// lui seul.
  Future<ZResult<List<ZContentBlock>>> generate(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  });
}

/// Port de **streaming** — forme de lex, portée au socle **telle quelle**.
///
/// `Stream<Either<ZFailure, ZChatStreamEvent>>` est exactement la signature de
/// `lex_core/lib/domain/repositories/chat_repository.dart:24` (`sendMessage`),
/// `:94` (`regenerateMessage`) et `:110` (`transformMessage`) — un dépôt qui
/// porte 16 `Either<Failure, T>`. Elle est conforme AD-5 et n'a pas à être
/// réinventée. Ce qui change : **trois** signatures deviennent **une**, et
/// l'annulation devient explicite et par requête.
///
/// ⚠️ Le flux **n'émet jamais** d'événement d'erreur : un échec est un `Left`
/// (cf. `z_chat_stream_event.dart`, garde **G-C2**). Un flux coupé avant son
/// [ZChatDoneEvent] se signale par
/// `Left(ZChatStreamInterruptedFailure(requestId: token.requestId, …))`.
///
/// ## 🔴 REPRISE — l'obligation active du client
///
/// Le protocole de lex est **reprenable** : chaque événement porte une
/// [ZChatStreamEvent.sequenceId] monotone, et une reconnexion doit repartir de
/// la dernière position reçue **sous la même identité de requête**, sans quoi
/// le serveur rejoue le tour (message dupliqué, quota consommé deux fois).
///
/// Aucune signature supplémentaire n'est nécessaire : la reprise **est** le
/// jeton.
///
/// ```dart
/// var token = ZChatRequestToken(monIdDeTour);
/// String? derniere;
/// await for (final e in port.stream(req, token: token)) {
///   e.fold(
///     (f) => coupure = f,
///     (ev) { derniere = ev.sequenceId ?? derniere; rendre(ev); },
///   );
/// }
/// if (coupure is ZChatStreamInterruptedFailure && derniere != null) {
///   // MÊME requestId, nouvelle tentative, annulable indépendamment.
///   token = token.resumeFrom(derniere!);
///   await for (final e in port.stream(req, token: token)) { … }
/// }
/// ```
///
/// Une implémentation qui **ignore** `token.lastSequenceId` rejouera le tour
/// entier à la reconnexion. Un hôte dont le transport n'est pas reprenable ne
/// verra jamais ce champ renseigné (`null` = depuis le début) : le contrat lui
/// coûte zéro.
abstract interface class ZChatStreamPort {
  /// Diffuse la réponse à [request], annulable par [token] — **ce** jeton, et
  /// lui seul. Deux appels concurrents portent deux jetons distincts : annuler
  /// l'un **n'affecte pas** l'autre (garde comportementale du lot).
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  });
}
