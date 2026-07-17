/// Seam IA neutre d'**évaluation de réponse** `ZFlashcardAnswerEvaluationPort`
/// (Story SU-3, AC2/AC3 — AD-35).
///
/// origine: seam IA neutre du domaine flashcard (AD-5/AD-35). Le port est un
/// **contrat pur** (`abstract interface class`) : l'app hôte l'*implements* avec
/// son routeur IA. **Aucune** mécanique de transport ne fuit dans le domaine —
/// prompts, endpoints et clés restent CÔTÉ APP (patron **exact**
/// `z_flashcard_generation_port.dart`).
///
/// 🔒 **ADVISORY STRICT (AD-35)** — la raison d'être de ce fichier. Le port
/// **suggère**, il ne **note** jamais :
/// - sa sortie porte une `suggestedQuality`, pas une qualité ;
/// - **rien ici n'écrit le SRS** (AD-33) : l'écriture passe *uniquement* par le
///   seam `ZSessionReviewer` (`zcrud_session`), et su-3 n'écrit rien du tout ;
/// - c'est le **tap de l'utilisateur** sur `ZSrsQualityButtons` qui vaut
///   notation — la suggestion n'est qu'une **pré-sélection**.
///
/// 🔒 **JAMAIS appelé pour un QCM ou un Vrai/Faux** (AD-35 / AC1). Ces deux
/// types sont évalués **LOCALEMENT et exactement** par `zEvaluateLocally`
/// (`z_flashcard_local_evaluation.dart`) : la bonne réponse est **déjà connue**
/// (`ZChoice.isCorrect` / `ZFlashcard.isTrue`), une comparaison ensembliste
/// stricte est **exacte et gratuite**, là où un appel IA serait **coûteux,
/// latent et faillible**. **Écart ASSUMÉ avec IFFD** (qui les fait passer par
/// l'IA) : ne pas « corriger » vers IFFD.
///
/// 🔒 **Le plafond d'indices n'est PAS l'affaire du port** (AD-36) : `hintsUsed`
/// lui est transmis **à titre INFORMATIF** (« le barème peut en tenir compte
/// dans sa prose »), mais la **pénalité a un propriétaire unique — la couche
/// locale** (`zApplyHintCeiling`, `z_hint_penalty.dart`), appliquée **EN DERNIER
/// sur la valeur rendue**. Un port qui rendrait 5 avec 3 indices **ne contourne
/// pas** le plafond.
///
/// **`abstract interface class` (AD-4)** : frontière inter-package ⇒ **jamais
/// `sealed`** (l'app *implements* librement). **`Either<ZFailure,·>` (AD-5)** :
/// l'`errorKind` **typé** d'AD-35 **EST** le `ZFailure` (hiérarchie existante) —
/// aucun nouveau canal d'erreur n'est inventé. Un `Left`, un port `null` ou même
/// un `throw` de l'impl app retombent tous sur la **qualité neutre**
/// (`config.passThreshold`) côté surface : **jamais d'exception** (AD-10).
///
/// **Foyer imposé par le graphe (AD-1)** : `zcrud_study` **dépend de**
/// `zcrud_flashcard` ⇒ loger ce port à côté de `ZFlashcardGenerationPort`
/// (`zcrud_study`) créerait un **cycle** ; `zcrud_study_kernel` ignore
/// `ZFlashcardType`. `zcrud_flashcard` est donc le **seul** foyer possible — ce
/// n'est pas une préférence, c'est le graphe.
library;

import 'package:zcrud_core/domain.dart';

import 'z_flashcard_type.dart';

/// Requête **immuable** d'évaluation d'une réponse rédigée (value-object,
/// `==`/`hashCode` par valeur) — entrée d'AD-35, **mot pour mot**.
///
/// Ne porte que du **contenu neutre** : aucun prompt, aucun endpoint, aucune clé
/// (AD-12). N'est **jamais** construite pour un QCM/Vrai-Faux (AC1).
class ZFlashcardAnswerEvaluationRequest {
  /// Construit une requête d'évaluation.
  const ZFlashcardAnswerEvaluationRequest({
    required this.question,
    required this.userAnswer,
    required this.cardType,
    this.expectedAnswer,
    this.explanation,
    this.timeTaken,
    this.hintsUsed = 0,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Énoncé de la carte (`ZFlashcard.question`).
  final String question;

  /// Réponse **rédigée** par l'apprenant (texte brut).
  final String userAnswer;

  /// Type de la carte évaluée — **jamais** [ZFlashcardType.multipleChoice] ni
  /// [ZFlashcardType.trueOrFalse] (évalués localement, AC1/AD-35).
  final ZFlashcardType cardType;

  /// Réponse attendue (`ZFlashcard.answer`), ou `null` si la carte n'en porte
  /// pas — l'app décide alors de son barème.
  final String? expectedAnswer;

  /// Explication pédagogique de la carte (`ZFlashcard.explanation`), ou `null`.
  final String? explanation;

  /// Temps de réponse mesuré, ou `null`.
  ///
  /// **Toujours mesuré** côté surface — y compris quand le minuteur est
  /// `ZTimerDisplay.hidden` (AC7) : l'affichage est un réglage d'UI, pas une
  /// condition de mesure.
  final Duration? timeTaken;

  /// Nombre d'indices consommés — 🔒 **INFORMATIF SEULEMENT** (AD-36).
  ///
  /// Le port **n'en tire AUCUNE pénalité** : le plafond est appliqué **après**,
  /// **localement**, par `zApplyHintCeiling` (propriétaire **unique**). Le
  /// transmettre permet au barème d'en « tenir compte dans sa prose » (AD-36
  /// mot pour mot) — jamais dans sa note.
  final int hintsUsed;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres app-specific neutres). Défaut `const {}`.
  /// **Normalisée à la LECTURE (AD-19.1)** : les clés de sync réservées
  /// (`updated_at`/`is_deleted`) sont écartées — jamais réémises.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardAnswerEvaluationRequest &&
          question == other.question &&
          userAnswer == other.userAnswer &&
          cardType == other.cardType &&
          expectedAnswer == other.expectedAnswer &&
          explanation == other.explanation &&
          timeTaken == other.timeTaken &&
          hintsUsed == other.hintsUsed &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        question,
        userAnswer,
        cardType,
        expectedAnswer,
        explanation,
        timeTaken,
        hintsUsed,
        zJsonHash(extra),
      );

  @override
  String toString() => 'ZFlashcardAnswerEvaluationRequest(cardType: $cardType, '
      'hintsUsed: $hintsUsed, timeTaken: $timeTaken)';
}

/// Sortie **ADVISORY** typée d'une évaluation (value-object immuable) — AD-35.
///
/// 🔒 Le port **SUGGÈRE**, il ne **note** jamais : [suggestedQuality] est une
/// *proposition*, pré-sélectionnée dans `ZSrsQualityButtons` ; seul le **tap**
/// de l'utilisateur vaut notation.
///
/// 🔒 [suggestedQuality] est **CLAMPÉE à la réception** par
/// `ZSrsConfig.clampQuality` (unique voie de clamp, AD-46) puis **plafonnée** par
/// `zApplyHintCeiling` (AD-36) : ce VO transporte la valeur **brute** du port,
/// telle qu'il l'a rendue — la discipline d'échelle est appliquée par le
/// consommateur, en un seul endroit, dans un ordre imposé.
///
/// **`quota?` d'AD-35 : NON livré en v1** (arbitrage consigné). Le VO de quota
/// canonique `ZEducationQuotaInfo` vit dans `zcrud_study` — **inatteignable
/// sans cycle** (AD-1) ; le dupliquer serait une **seconde source**. Le spine le
/// note **optionnel** et aucun besoin bi-consommateur n'est démontré
/// (« généricité au juste besoin »). L'échappatoire [extra] (AD-4) le loge le
/// jour où une app en a besoin, **sans** rupture de surface.
class ZFlashcardAnswerEvaluation {
  /// Construit une évaluation advisory.
  const ZFlashcardAnswerEvaluation({
    required this.feedback,
    required this.suggestedQuality,
    this.isCorrect,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Retour pédagogique **prêt à afficher** (prose du barème).
  final String feedback;

  /// Qualité **SUGGÉRÉE** (brute, telle que rendue par le port).
  ///
  /// 🔒 Peut être **hors bornes** : le consommateur la fait passer par
  /// `config.clampQuality` (AD-46) **puis** `zApplyHintCeiling` (AD-36). Ce VO
  /// ne clampe pas lui-même — sinon la discipline d'échelle aurait **deux**
  /// propriétaires, et ils divergeraient en silence.
  final int suggestedQuality;

  /// Verdict binaire du barème, ou `null` si le barème ne se prononce pas
  /// (`isCorrect?` d'AD-35 — nullable **par contrat**).
  final bool? isCorrect;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (AD-4) — loge notamment un `quota` app-specific.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] (AD-19.1).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardAnswerEvaluation &&
          feedback == other.feedback &&
          suggestedQuality == other.suggestedQuality &&
          isCorrect == other.isCorrect &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(feedback, suggestedQuality, isCorrect, zJsonHash(extra));

  @override
  String toString() => 'ZFlashcardAnswerEvaluation(suggestedQuality: '
      '$suggestedQuality, isCorrect: $isCorrect)';
}

/// Port neutre d'**évaluation de réponse rédigée** (AD-5 : `Either<ZFailure,·>`).
///
/// L'app hôte l'*implements* avec son routeur IA. Retourne
/// `ZResult<ZFlashcardAnswerEvaluation>` — **jamais** une évaluation nue.
///
/// 🔒 **N'est JAMAIS appelé** pour [ZFlashcardType.multipleChoice] ni
/// [ZFlashcardType.trueOrFalse] (AD-35/AC1) — la garde centrale de l'AC1 est une
/// **assertion d'ABSENCE d'appel** (`spy.callCount == 0`).
abstract interface class ZFlashcardAnswerEvaluationPort {
  /// Évalue la réponse rédigée décrite par [request].
  ///
  /// `Left` en cas d'échec (quota, réseau, parsing) — l'`errorKind` typé d'AD-35
  /// **est** ce `ZFailure`. Le consommateur retombe alors sur la **qualité
  /// neutre** (`config.passThreshold`), **sans** exception (AD-10) : une impl qui
  /// **throw** est couverte au même titre qu'un `Left`.
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  );
}
