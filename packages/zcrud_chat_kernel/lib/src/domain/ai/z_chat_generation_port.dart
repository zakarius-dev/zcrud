/// Ports IA de la conversation — `ZChatGenerationPort` / `ZChatStreamPort`
/// (invariants AD-5, AD-10, AD-11, AD-12).
///
/// ## Un port de génération unique, paramétré par style
///
/// Une application de chat qui grandit organiquement tend à écrire chaque
/// variante de reformulation comme une fonction et un point d'entrée
/// distincts, qui ne diffèrent souvent **que par le prompt**. Un seul
/// contrat `generate(request)` les couvre ici : le style est une **donnée**
/// ([ZChatGenerationStyle], ouverte par [ZTypeRegistry] — invariant AD-4),
/// pas une signature.
///
/// ## Ce que ces ports ne couvrent pas — ports existants à câbler
///
/// La génération d'**artefacts structurés** depuis des notes a ses propres
/// ports dans ce dépôt :
///
/// | Besoin | Port existant | Chemin |
/// |---|---|---|
/// | Générer des flashcards depuis des notes | `ZFlashcardGenerationPort` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart` |
/// | Générer une carte mentale depuis des notes | `ZMindmapGenerationPort` | `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart` |
///
/// **Aucun style `flashcards`/`mindmap` n'est déclaré ici**, et aucun membre
/// de ce fichier ne génère de carte : ce serait un doublon plus pauvre que
/// l'existant (les ports d'étude portent `typesDistribution`, `maxDepth`,
/// `provenance`, `ZFlashcardSource`). Un hôte branche **les deux** : ces
/// ports-ci pour le texte, ceux de `zcrud_study` pour les artefacts. Le
/// noyau de chat ne peut de toute façon pas en dépendre (une seule arête
/// sortante, `zcrud_core` — invariant AD-1).
///
/// ## Annulation
///
/// Le [ZChatRequestToken] est un **paramètre requis de l'appel**, jamais un
/// champ d'implémentation : voir `z_chat_request_token.dart` pour le défaut
/// (jeton d'instance unique) que cette forme rend inexprimable.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_enums.dart';
import '../z_content_block.dart';
import 'z_chat_compute_effort.dart';
import 'z_chat_context_port.dart';
import 'z_chat_corpus_scope.dart';
import 'z_chat_generation_settings.dart';
import 'z_chat_generation_style.dart';
import 'z_chat_request_token.dart';
import 'z_chat_stream_event.dart';

/// Requête **immuable** de génération (value object, `==`/`hashCode` par
/// valeur) — **partagée** par le port one-shot et le port de streaming.
///
/// Une seule requête pour les deux ports : la différence entre « je veux la
/// réponse » et « je veux la réponse au fil de l'eau » est un **choix de
/// transport**, pas une différence de demande. Trois signatures distinctes
/// portant chacune une copie dérivée des mêmes paramètres serait le coût de
/// l'inverse.
///
/// Ne porte **aucune** mécanique de transport ni de prompt (invariant
/// AD-12) : ni endpoint, ni clé, ni instruction système assemblée.
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
    this.revealThinkingSteps,
    bool? webSearch,
    Map<String, bool> capabilities = const <String, bool>{},
    this.corpusScope,
    this.languageTag,
    this.instructions,
    this.modelId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : context = List<ZChatContextFragment>.unmodifiable(
         ZChatContextFragment.ordered(context),
       ),
       attachmentIds = List<String>.unmodifiable(attachmentIds),
       // Canonicalisation EAGER : la clé réservée du canal ouvert est
       // hissée dans le champ typé (champ typé prioritaire), le reste est
       // rogné/dédupliqué/trié — une requête n'a qu'UNE écriture possible.
       webSearch =
           webSearch ?? ZChatGenerationSettings.hoistedWebSearch(capabilities),
       capabilities = Map<String, bool>.unmodifiable(
         ZChatGenerationSettings.sanitizeCapabilities(capabilities),
       ),
       extra = Map<String, dynamic>.unmodifiable(
         zSanitizeExtra(extra, _reservedKeys),
       );

  /// Style demandé — **ouvert** (invariant AD-4).
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

  /// Longueur attendue — enum **EXISTANT** `ZChatResponseLength`,
  /// jamais redéclaré. `null` ⇒ l'hôte décide.
  final ZChatResponseLength? responseLength;

  /// Biais de longueur d'une régénération — enum **EXISTANT**
  /// `ZChatLengthBias`. `null` ⇒ sans objet.
  final ZChatLengthBias? lengthBias;

  /// Budget de **calcul** demandé (`1..5`), ou `null` (l'hôte décide).
  ///
  /// **Axe orthogonal** à [responseLength] : la verbosité de la réponse et
  /// le budget de raisonnement sont deux demandes indépendantes. Les fusionner
  /// produirait un réglage qui ne veut rien dire — voir la mise en garde sur
  /// les deux sens d'« effort » dans `z_chat_compute_effort.dart`. C'est
  /// l'entier `1..5` commun aux fournisseurs rencontrés ; un préréglage
  /// `low/medium/high` s'y projette.
  final ZChatComputeEffort? computeEffort;

  /// Demande d'exposer les **étapes de raisonnement** (`ZChatThinkingStep`),
  /// ou `null` (l'hôte décide).
  ///
  /// Pendant, côté demande, d'un type qui n'existait que côté réponse. C'est
  /// l'un des réglages du porteur [ZChatGenerationSettings] ; il est déclaré
  /// ici, comme les autres, pour que la projection soit une **bijection** et
  /// non une perte.
  final bool? revealThinkingSteps;

  /// Demande d'activer/couper la **recherche web**, ou `null` (l'hôte
  /// décide). Champ typé parce que c'est une capacité largement répandue
  /// chez les fournisseurs ; réglage du porteur [ZChatGenerationSettings],
  /// déclaré ici, comme les autres, pour que la projection reste une
  /// **bijection**.
  final bool? webSearch;

  /// Capacités booléennes **ouvertes** demandées à l'exécuteur (invariant
  /// AD-4). Clés opaques d'hôte, **canonicalisées à la construction** (la
  /// clé réservée `web_search` vit dans [webSearch], jamais ici).
  ///
  /// Exprimée ≠ honorée : le bouclage est
  /// `ZChatGenerationSettings.auditCapabilities` — un hôte confronte l'écho
  /// des clés comprises par son port à `settings.expressedCapabilityKeys`
  /// pour détecter un repli muet.
  final Map<String, bool> capabilities;

  /// **Portée documentaire** de la génération, ou `null`.
  ///
  /// `null` ⇒ **aucune restriction**. Renseignée, elle s'exprime en **clés
  /// stables** ([ZChatCorpusScope]) et se confronte aux sources rendues par
  /// `ZChatCorpusScope.audit` : c'est ce bouclage — et non la seule présence
  /// du champ — qui fait qu'une restriction **vaut quelque chose**.
  ///
  /// Le socle ne connaît **aucune** valeur de corpus : les clés sont celles
  /// de l'hôte (invariant AD-12).
  final ZChatCorpusScope? corpusScope;

  /// Étiquette de langue BCP-47 (`'fr'`), ou `null`.
  final String? languageTag;

  /// Consigne libre neutre transmise telle quelle à l'implémentation, ou
  /// `null`. **Jamais** un prompt système (AD-12).
  final String? instructions;

  /// Identifiant de modèle **opaque**, transporté verbatim et **jamais
  /// interprété** : aucun catalogue, aucun `switch`, aucun libellé. Le
  /// catalogue de modèles (et son routage) vit entièrement côté app,
  /// comme sur `ZFlashcardGenerationRequest.modelId`.
  final String? modelId;

  /// Échappatoire non typée, **normalisée dès la construction** : les clés
  /// de synchronisation réservées sont écartées et ne peuvent jamais être
  /// réémises.
  final Map<String, dynamic> extra;

  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// **Vue** des réglages portés par cette requête.
  ///
  /// Une **projection**, jamais un second stockage : les réglages restent
  /// des champs de premier niveau, pour que verbosité et budget de calcul
  /// demeurent non confondables. Un porteur stocké en plus aurait créé deux
  /// sources de vérité — deux lectures conformes mais incompatibles d'une
  /// même donnée.
  ///
  /// `settings` et [withSettings] forment un aller-retour **fidèle** :
  /// `r.withSettings(r.settings) == r`.
  ZChatGenerationSettings get settings => ZChatGenerationSettings(
    responseLength: responseLength,
    lengthBias: lengthBias,
    computeEffort: computeEffort,
    revealThinkingSteps: revealThinkingSteps,
    webSearch: webSearch,
    capabilities: capabilities,
  );

  /// Rend une requête **identique**, sauf les réglages, remplacés par ceux de
  /// [settings].
  ///
  /// * `null` ⇒ la requête est rendue **telle quelle** (`identical`) : un hôte
  ///   qui ne règle rien ne paie rien, et le chemin d'exécution est inchangé ;
  /// * un porteur **vide** remet les quatre réglages à « l'hôte décide ».
  ///   C'est délibérément un **remplacement**, pas une fusion : une feuille de
  ///   réglages qui retire un réglage doit pouvoir le retirer.
  ///
  /// C'est le membre par lequel les réglages d'une `ZChatRegenerateAction`
  /// rejoignent la requête effectivement envoyée au port.
  ZChatGenerationRequest withSettings(ZChatGenerationSettings? settings) {
    if (settings == null) return this;
    return ZChatGenerationRequest(
      style: style,
      subject: subject,
      notes: notes,
      conversationId: conversationId,
      sourceMessageId: sourceMessageId,
      context: context,
      attachmentIds: attachmentIds,
      responseLength: settings.responseLength,
      lengthBias: settings.lengthBias,
      computeEffort: settings.computeEffort,
      revealThinkingSteps: settings.revealThinkingSteps,
      webSearch: settings.webSearch,
      capabilities: settings.capabilities,
      corpusScope: corpusScope,
      languageTag: languageTag,
      instructions: instructions,
      modelId: modelId,
      extra: extra,
    );
  }

  /// Rend une requête **identique**, sauf la portée documentaire.
  ///
  /// `null` ⇒ portée **retirée** (aucune restriction). Séparé de
  /// [withSettings] parce que ce sont deux axes distincts : régler la verbosité
  /// ne doit jamais, par effet de bord, élargir ou restreindre le corpus.
  ZChatGenerationRequest withCorpusScope(ZChatCorpusScope? scope) =>
      ZChatGenerationRequest(
        style: style,
        subject: subject,
        notes: notes,
        conversationId: conversationId,
        sourceMessageId: sourceMessageId,
        context: context,
        attachmentIds: attachmentIds,
        responseLength: responseLength,
        lengthBias: lengthBias,
        computeEffort: computeEffort,
        revealThinkingSteps: revealThinkingSteps,
        webSearch: webSearch,
        capabilities: capabilities,
        corpusScope: scope,
        languageTag: languageTag,
        instructions: instructions,
        modelId: modelId,
        extra: extra,
      );

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
          revealThinkingSteps == other.revealThinkingSteps &&
          webSearch == other.webSearch &&
          zJsonEquals(capabilities, other.capabilities) &&
          corpusScope == other.corpusScope &&
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
    revealThinkingSteps,
    webSearch,
    zJsonHash(capabilities),
    corpusScope,
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
/// Invariant AD-5 : `Either<ZFailure, ·>`. Invariant AD-10 : aucune
/// exception ne s'échappe — les échecs typés sont ceux de
/// `z_chat_ai_failure.dart` (dont `ZQuotaExceededFailure`, type existant du
/// cœur).
abstract interface class ZChatGenerationPort {
  /// Génère la réponse pour [request], annulable par [token] — **ce** jeton, et
  /// lui seul.
  Future<ZResult<List<ZContentBlock>>> generate(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  });
}

/// Port de **streaming**.
///
/// `Stream<Either<ZFailure, ZChatStreamEvent>>` est une forme conforme à
/// l'invariant AD-5, cohérente avec le reste des contrats repository du
/// dépôt — et avec la signature d'un backend de référence
/// (`lex_core/lib/domain/repositories/chat_repository.dart`). Ce qui unifie
/// ici trois usages distincts (envoi, régénération, transformation) en une
/// seule signature : l'annulation devient explicite et par requête.
///
/// Le flux **n'émet jamais** d'événement d'erreur : un échec est un `Left`
/// (cf. `z_chat_stream_event.dart`). Un flux coupé avant son
/// [ZChatDoneEvent] se signale par
/// `Left(ZChatStreamInterruptedFailure(requestId: token.requestId, …))`.
///
/// ## Reprise — l'obligation active du client
///
/// Un backend de streaming reprenable expose un protocole où chaque
/// événement porte une [ZChatStreamEvent.sequenceId] monotone, et une
/// reconnexion doit repartir de la dernière position reçue **sous la même
/// identité de requête**, sans quoi le serveur rejoue le tour (message
/// dupliqué, quota consommé deux fois).
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
