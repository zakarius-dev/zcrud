/// Énumérations **neutres** du modèle de conversation IA (AD-3, AD-10, AD-13).
///
/// origine: lex_core (module « Assistant ») — `domain/enums/chat_enums.dart`,
/// `response_confidence.dart:22-35`, `source_freshness.dart:15-24`,
/// `chat_source.dart:6-15`.
///
/// **Trois règles tiennent tout ce fichier :**
///
/// 1. **Valeurs persistées en camelCase** (convention `Naming & Consistency`
///    du dépôt) — lex persiste `off_topic`/`as_is`/`general_knowledge` en
///    snake_case ; ces formes restent **acceptées EN LECTURE** (alias), jamais
///    réémises. C'est le principe de Postel, et c'est la condition du « portable
///    rapidement » : un document lex existant se relit **typé**, pas en repli.
/// 2. **Aucun parse ne lève** (AD-10) : chaque `fromJson` est un `switch`
///    **total** avec repli documenté. ⛔ Ne JAMAIS remplacer par
///    `values.byName(raw)` — qui lève `ArgumentError` sur une valeur inconnue
///    et détruirait le message parent (garde **G3**).
/// 3. **Zéro présentation** (AD-13/FR-26) : pas de `label`, pas de `colorValue`,
///    pas de `iconName`. lex en porte (`chat_enums.dart:34-53`) ; ce sont des
///    préoccupations d'affichage, elles restent **app-side** — un socle partagé
///    ne peut ni traduire ni thématiser à la place de ses hôtes.
library;

/// Rôle de l'auteur d'un message.
///
/// lex ne connaît que `user`/`assistant` et **coerce tout le reste en `user`**
/// (`chat_message.dart:92-93`) : un message `system` relu devient un message
/// utilisateur, silencieusement. zcrud ajoute donc `system` **et** un repli
/// explicite [ZChatRole.unknown] — un rôle non reconnu reste *reconnaissable
/// comme non reconnu*, au lieu d'être maquillé en rôle légitime.
enum ZChatRole {
  /// Message rédigé par l'utilisateur.
  user,

  /// Message produit par l'assistant.
  assistant,

  /// Message d'amorçage/instruction système.
  system,

  /// Rôle absent ou non reconnu — repli **explicite**, jamais `user`.
  unknown;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** (repli [ZChatRole.unknown]) — ne lève jamais.
  static ZChatRole fromJson(Object? raw) {
    switch (raw) {
      case 'user':
        return ZChatRole.user;
      case 'assistant':
        return ZChatRole.assistant;
      case 'system':
        return ZChatRole.system;
      default:
        return ZChatRole.unknown;
    }
  }
}

/// **LONGUEUR** attendue de la réponse de l'assistant.
///
/// ## 🔴 FAUX-AMI `WorkflowEffort` — deux concepts, jamais fusionnés (D2)
///
/// | Dépôt | Symbole | Valeurs | Sens **réel** |
/// |---|---|---|---|
/// | lex_douane | `WorkflowEffort` — `packages/lex_core/lib/domain/enums/chat_enums.dart:20-26` | `concis`/`standard`/`detaille` | **LONGUEUR de la réponse** (labels UI Mini/Plus/Pro) |
/// | IFFD | `WorkflowEffort` — `lib/src/domain/models/ai/ai_models.dart:119-122` | `low`/`medium`/`high` | **EFFORT DE CALCUL** du routeur de modèles |
///
/// **Même nom, deux concepts.** Les fusionner produirait un enum vide de sens :
/// `standard` (longueur) n'a aucune correspondance dans `low`/`medium`/`high`
/// (budget de calcul), et un hôte qui migrerait de l'un vers l'autre écrirait
/// des documents que l'autre relirait de travers **sans aucun signal**.
///
/// ⛔ **Le symbole `WorkflowEffort` — et tout symbole `*Effort*` du chat — est
/// INTERDIT dans `packages/*/lib`.** Une garde par **grep négatif**
/// (`z_chat_naming_guard_test.dart`, **G16**) échoue s'il réapparaît par
/// copier-coller depuis l'un ou l'autre dépôt.
///
/// Le concept IFFD (effort de calcul) n'est **pas** un champ de message mais un
/// **paramètre d'appel** : s'il est retenu, il naîtra en CHAT-1 sous un nom
/// distinct (`ZChatComputeEffort`), **jamais** sous `Effort` seul.
enum ZChatResponseLength {
  /// Réponse courte.
  concise,

  /// Longueur par défaut.
  standard,

  /// Réponse développée.
  detailed;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli [ZChatResponseLength.standard].
  ///
  /// **Alias de lecture lex** : `'concis'` → [concise], `'detaille'` →
  /// [detailed] (`chat_enums.dart:56-61`).
  static ZChatResponseLength fromJson(Object? raw) {
    switch (raw) {
      case 'concise':
      case 'concis':
        return ZChatResponseLength.concise;
      case 'detailed':
      case 'detaille':
        return ZChatResponseLength.detailed;
      case 'standard':
      default:
        return ZChatResponseLength.standard;
    }
  }
}

/// Biais de longueur d'une **régénération** (« plus court / tel quel / plus
/// long »), orthogonal à [ZChatResponseLength].
///
/// origine: `RegenerateLengthBias` (`chat_enums.dart:69-96`).
enum ZChatLengthBias {
  /// Régénérer plus court.
  shorter,

  /// Conserver la longueur courante.
  asIs,

  /// Régénérer plus long.
  longer;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli [ZChatLengthBias.asIs] ; alias de lecture `as_is`.
  static ZChatLengthBias fromJson(Object? raw) {
    switch (raw) {
      case 'shorter':
        return ZChatLengthBias.shorter;
      case 'longer':
        return ZChatLengthBias.longer;
      case 'asIs':
      case 'as_is':
      default:
        return ZChatLengthBias.asIs;
    }
  }
}

/// Appréciation binaire d'une réponse (pouce haut / bas).
enum ZChatFeedbackRating {
  /// Réponse jugée utile.
  up,

  /// Réponse jugée inutile.
  down;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli `null` (absence de feedback ≠ feedback neutre).
  static ZChatFeedbackRating? fromJson(Object? raw) {
    switch (raw) {
      case 'up':
        return ZChatFeedbackRating.up;
      case 'down':
        return ZChatFeedbackRating.down;
      default:
        return null;
    }
  }
}

/// Motif catégorisé d'un feedback négatif.
///
/// origine: `FeedbackCategory` (`chat_enums.dart:120-150`) — lex a déjà fait le
/// choix **label-in-l10n** (aucun libellé dans l'enum) : on le conserve.
enum ZChatFeedbackCategory {
  /// Réponse inexacte.
  inaccurate,

  /// Réponse incomplète.
  incomplete,

  /// Réponse hors sujet.
  offTopic,

  /// Citation erronée.
  wrongCitation,

  /// Ton inadapté.
  inappropriateTone;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli `null` ; alias de lecture snake_case de lex
  /// (`off_topic`, `wrong_citation`, `inappropriate_tone`).
  static ZChatFeedbackCategory? fromJson(Object? raw) {
    switch (raw) {
      case 'inaccurate':
        return ZChatFeedbackCategory.inaccurate;
      case 'incomplete':
        return ZChatFeedbackCategory.incomplete;
      case 'offTopic':
      case 'off_topic':
        return ZChatFeedbackCategory.offTopic;
      case 'wrongCitation':
      case 'wrong_citation':
        return ZChatFeedbackCategory.wrongCitation;
      case 'inappropriateTone':
      case 'inappropriate_tone':
        return ZChatFeedbackCategory.inappropriateTone;
      default:
        return null;
    }
  }
}

/// Nature d'une suggestion de relance.
///
/// origine: `SuggestionType` (`chat_enums.dart:152-181`).
enum ZChatSuggestionType {
  /// Question de suivi.
  followUp,

  /// Sujet connexe.
  relatedTopic,

  /// Approfondissement.
  deepDive;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli `null` ; alias snake_case de lex.
  static ZChatSuggestionType? fromJson(Object? raw) {
    switch (raw) {
      case 'followUp':
      case 'follow_up':
        return ZChatSuggestionType.followUp;
      case 'relatedTopic':
      case 'related_topic':
        return ZChatSuggestionType.relatedTopic;
      case 'deepDive':
      case 'deep_dive':
        return ZChatSuggestionType.deepDive;
      default:
        return null;
    }
  }
}

/// Nature de l'action portée par une suggestion.
///
/// origine: `SuggestionActionType` (`chat_enums.dart:183-206`).
enum ZChatSuggestionActionType {
  /// Envoyer un message.
  sendMessage,

  /// Naviguer vers une destination.
  navigate,

  /// Copier un contenu.
  copy;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli `null` ; alias snake_case de lex.
  static ZChatSuggestionActionType? fromJson(Object? raw) {
    switch (raw) {
      case 'sendMessage':
      case 'send_message':
        return ZChatSuggestionActionType.sendMessage;
      case 'navigate':
        return ZChatSuggestionActionType.navigate;
      case 'copy':
        return ZChatSuggestionActionType.copy;
      default:
        return null;
    }
  }
}

/// Statut d'usage d'une source dans la réponse.
///
/// origine: `SourceUsageStatus` (`chat_source.dart:6-15`).
enum ZChatSourceUsageStatus {
  /// Source effectivement citée.
  cited,

  /// Source consultée mais non citée.
  consulted,

  /// Connaissance générale non sourcée.
  generalKnowledge;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli `null` ; alias de lecture `general_knowledge`.
  ///
  /// Le **défaut métier** ([ZChatSourceUsageStatus.cited]) est appliqué par
  /// `ZChatSource.usageStatus`, pas ici : distinguer « absent » de « cité » est
  /// nécessaire pour que la valeur brute fasse un round-trip sans perte.
  static ZChatSourceUsageStatus? fromJson(Object? raw) {
    switch (raw) {
      case 'cited':
        return ZChatSourceUsageStatus.cited;
      case 'consulted':
        return ZChatSourceUsageStatus.consulted;
      case 'generalKnowledge':
      case 'general_knowledge':
        return ZChatSourceUsageStatus.generalKnowledge;
      default:
        return null;
    }
  }
}

/// Fraîcheur d'un jeu de données cité.
///
/// origine: `DatasetFreshness` (`source_freshness.dart:15-24`).
enum ZChatDatasetFreshness {
  /// Catalogue et contenu concordent.
  fresh,

  /// Divergence détectée — contenu potentiellement périmé.
  stale,

  /// Indéterminé — état **NEUTRE**, jamais alarmant.
  unknown;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli [ZChatDatasetFreshness.unknown].
  static ZChatDatasetFreshness fromJson(Object? raw) {
    switch (raw) {
      case 'fresh':
        return ZChatDatasetFreshness.fresh;
      case 'stale':
        return ZChatDatasetFreshness.stale;
      default:
        return ZChatDatasetFreshness.unknown;
    }
  }
}

/// Palier de confiance **dérivé** d'une réponse (jamais persisté seul : il se
/// recalcule depuis `ZChatResponseConfidence`).
///
/// origine: `ConfidenceLevel` (`response_confidence.dart:22-31`) —
/// `eleve`/`modere`/`aVerifier` renommés en anglais neutre.
enum ZChatConfidenceLevel {
  /// Signaux fortement positifs et concordants.
  high,

  /// Signaux partiellement positifs.
  moderate,

  /// Signaux absents/dégradés ⇒ à confirmer. **Repli fail-safe.**
  toVerify;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli [ZChatConfidenceLevel.toVerify].
  ///
  /// 🔴 Le repli est **`toVerify`, jamais `high`** : en l'absence de signal
  /// lisible, un socle ne doit **jamais** sur-affirmer.
  static ZChatConfidenceLevel fromJson(Object? raw) {
    switch (raw) {
      case 'high':
        return ZChatConfidenceLevel.high;
      case 'moderate':
        return ZChatConfidenceLevel.moderate;
      default:
        return ZChatConfidenceLevel.toVerify;
    }
  }
}

/// Sens explicable d'un facteur de confiance.
///
/// origine: `ConfidenceFactorSense` (`response_confidence.dart:35`).
enum ZChatConfidenceFactorSense {
  /// Le facteur soutient la confiance.
  positive,

  /// Le facteur est sans effet (ou non évalué).
  neutral,

  /// Le facteur dégrade la confiance.
  negative;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — repli [ZChatConfidenceFactorSense.neutral].
  static ZChatConfidenceFactorSense fromJson(Object? raw) {
    switch (raw) {
      case 'positive':
        return ZChatConfidenceFactorSense.positive;
      case 'negative':
        return ZChatConfidenceFactorSense.negative;
      default:
        return ZChatConfidenceFactorSense.neutral;
    }
  }
}
