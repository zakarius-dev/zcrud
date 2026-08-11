/// Seam IA neutre d'évaluation de réponse `ZFlashcardAnswerEvaluationPort`.
///
/// Le port est un contrat pur (`abstract interface class`) : l'application
/// hôte l'implémente avec son propre routeur IA. Aucune mécanique de
/// transport ne fuit dans le domaine — prompts, points de terminaison et
/// clés restent côté application (même patron que le port de génération de
/// contenu du paquet d'étude).
///
/// ## Consultatif, jamais notant
///
/// Le port suggère, il ne note jamais :
/// - sa sortie porte une qualité suggérée, pas une qualité définitive ;
/// - rien ici n'écrit l'état SRS : l'écriture passe uniquement par le seam
///   de révision de session (`zcrud_session`), et ce port n'écrit rien du
///   tout ;
/// - c'est le geste de l'utilisateur sur les boutons de qualité SRS qui vaut
///   notation — la suggestion n'est qu'une pré-sélection.
///
/// ## Jamais appelé pour un QCM ou un vrai/faux
///
/// Ces deux types sont évalués localement et exactement par l'évaluation
/// locale (voir `z_flashcard_local_evaluation.dart`) : la bonne réponse est
/// déjà connue (`ZChoice.isCorrect` / `ZFlashcard.isTrue`), une comparaison
/// ensembliste stricte est exacte et gratuite, là où un appel IA serait
/// coûteux, latent et faillible.
///
/// ## Le plafond d'indices n'est pas l'affaire du port
///
/// `hintsUsed` lui est transmis à titre informatif (le barème peut en tenir
/// compte dans sa prose), mais la pénalité a un propriétaire unique — la
/// couche locale (`zApplyHintCeiling`, voir `z_hint_penalty.dart`), appliquée
/// en dernier sur la valeur rendue. Un port qui rendrait une note haute avec
/// plusieurs indices consommés ne contourne donc pas le plafond.
///
/// `abstract interface class` (invariant AD-4) : frontière inter-paquet, donc
/// jamais `sealed` (l'application implémente librement). `Either<ZFailure,
/// ·>` (invariant AD-5) : un `Left`, un port `null` ou même une exception
/// levée par l'implémentation applicative retombent tous sur la qualité
/// neutre (le seuil de passage de la configuration) côté surface — jamais
/// d'exception propagée (invariant AD-10).
///
/// Ce port vit dans `zcrud_flashcard` plutôt que dans le paquet d'étude, où
/// vit le port de génération de contenu voisin : le paquet d'étude dépend de
/// `zcrud_flashcard`, et loger ce port à côté de son voisin créerait un
/// cycle de dépendances (invariant AD-1).
library;

import 'package:zcrud_core/domain.dart';

import 'z_flashcard_type.dart';

/// Requête immuable d'évaluation d'une réponse rédigée (value-object,
/// `==`/`hashCode` par valeur).
///
/// Ne porte que du contenu neutre : aucun prompt, aucun point de
/// terminaison, aucune clé (invariant AD-12). N'est jamais construite pour
/// un QCM ou un vrai/faux.
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

  /// Réponse rédigée par l'apprenant (texte brut).
  final String userAnswer;

  /// Type de la carte évaluée — jamais [ZFlashcardType.multipleChoice] ni
  /// [ZFlashcardType.trueOrFalse] (évalués localement).
  final ZFlashcardType cardType;

  /// Réponse attendue (`ZFlashcard.answer`), ou `null` si la carte n'en porte
  /// pas — l'application décide alors de son barème.
  final String? expectedAnswer;

  /// Explication pédagogique de la carte (`ZFlashcard.explanation`), ou
  /// `null`.
  final String? explanation;

  /// Temps de réponse mesuré, ou `null`.
  ///
  /// Toujours mesuré côté surface, y compris quand l'affichage du minuteur
  /// est masqué : l'affichage est un réglage d'interface, pas une condition
  /// de mesure.
  final Duration? timeTaken;

  /// Nombre d'indices consommés — informatif seulement.
  ///
  /// Le port n'en tire aucune pénalité : le plafond est appliqué après,
  /// localement, par `zApplyHintCeiling` (propriétaire unique). Le
  /// transmettre permet au barème d'en tenir compte dans sa prose — jamais
  /// dans sa note.
  final int hintsUsed;

  /// Emplacement brut de l'échappatoire (normalisé à la lecture via
  /// [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres applicatifs neutres). Défaut
  /// `const {}`. Normalisée à la lecture : les clés de synchronisation
  /// réservées sont écartées, jamais réémises.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra].
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

/// Sortie consultative typée d'une évaluation (value-object immuable).
///
/// Le port suggère, il ne note jamais : [suggestedQuality] est une
/// proposition, pré-sélectionnée dans l'interface de qualité SRS ; seul le
/// geste de l'utilisateur vaut notation.
///
/// [suggestedQuality] est clampée à la réception par `ZSrsConfig.clampQuality`
/// (unique voie de clamp) puis plafonnée par `zApplyHintCeiling` : ce
/// value-object transporte la valeur brute du port, telle qu'il l'a rendue —
/// la discipline d'échelle est appliquée par le consommateur, en un seul
/// endroit, dans un ordre imposé.
class ZFlashcardAnswerEvaluation {
  /// Construit une évaluation consultative.
  const ZFlashcardAnswerEvaluation({
    required this.feedback,
    required this.suggestedQuality,
    this.isCorrect,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Retour pédagogique prêt à afficher (prose du barème).
  final String feedback;

  /// Qualité suggérée (brute, telle que rendue par le port).
  ///
  /// Peut être hors bornes : le consommateur la fait passer par
  /// `config.clampQuality` puis `zApplyHintCeiling`. Ce value-object ne
  /// clampe pas lui-même — sinon la discipline d'échelle aurait deux
  /// propriétaires, qui pourraient diverger en silence.
  final int suggestedQuality;

  /// Verdict binaire du barème, ou `null` si le barème ne se prononce pas
  /// (nullable par contrat).
  final bool? isCorrect;

  /// Emplacement brut de l'échappatoire (normalisé à la lecture via
  /// [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4) — loge notamment un quota
  /// applicatif.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra].
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

/// Port neutre d'évaluation de réponse rédigée (invariant AD-5 :
/// `Either<ZFailure,·>`).
///
/// L'application hôte l'implémente avec son propre routeur IA. Retourne
/// `ZResult<ZFlashcardAnswerEvaluation>` — jamais une évaluation nue.
///
/// N'est jamais appelé pour [ZFlashcardType.multipleChoice] ni
/// [ZFlashcardType.trueOrFalse].
abstract interface class ZFlashcardAnswerEvaluationPort {
  /// Évalue la réponse rédigée décrite par [request].
  ///
  /// `Left` en cas d'échec (quota, réseau, analyse) — le consommateur
  /// retombe alors sur la qualité neutre (`config.passThreshold`), sans
  /// exception (invariant AD-10) : une implémentation qui lève une exception
  /// est couverte au même titre qu'un `Left`.
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  );
}
