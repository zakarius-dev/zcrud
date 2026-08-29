/// Sélection pure du feedback pédagogique d'une soumission.
///
/// La règle de seau vit ici et nulle part ailleurs, en pur-Dart : aucune
/// `BuildContext`, aucun widget, aucune l10n — la fonction rend une clé
/// ([zFeedbackKeyFor]), jamais un texte directement affichable. C'est ce qui
/// la rend testable hors widget, en test unitaire pur.
///
/// ## Aucune note n'est hors seau, et l'échelle n'est pas redéclarée
///
/// La qualité entrante est clampée par `config.clampQuality` — voie unique
/// du dépôt (invariant AD-10) : une note aberrante venue d'un port
/// d'évaluation (`-3`, `9`) est ramenée dans l'échelle, jamais rejetée par
/// une exception. Les bornes ne sont jamais réécrites ici : `min`/`max`
/// appartiennent à `ZSrsConfig`, et `masteredThreshold` est injecté (son
/// défaut est consommé depuis son propriétaire, `ZSrsConfig.masteredThreshold`,
/// côté appelant — jamais un littéral en dur ni redérivé).
///
/// ## Le seau « mauvais » couvre q0 à q2, jamais seulement q1-q2
///
/// L'échelle canonique de qualité va de 0 à 5. Une note `q0` (blackout
/// total) ne doit tomber dans aucun trou entre les seaux : c'est
/// l'apprenant le plus en difficulté qui, sinon, ne recevrait aucun
/// encouragement — d'où un seau « mauvais » couvrant explicitement `q0-2`.
///
/// Pur-Dart, Flutter-free.
library;

import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;

/// Seau de feedback, dérivé de la qualité clampée — aucune note n'est hors
/// seau.
enum ZFeedbackTier {
  /// Note mauvaise (`q0-2` en échelle canonique) — message de motivation.
  motivation,

  /// Note bonne sans être maîtrisée (`q3`) — message neutre.
  neutral,

  /// Note maîtrisée (`q4-5`) — message d'encouragement.
  encouragement,

  /// Maîtrisée vite et sans indice — palier « exceptionnel ».
  exceptional,

  /// Carte **passée** : l'apprenant a déclaré ne pas savoir, sans produire de
  /// réponse à corriger.
  ///
  /// Ce seau ne se déduit d'aucune note : il n'est atteint que si l'appelant
  /// déclare explicitement la soumission passée
  /// (`zFeedbackTierFor(skipped: true)`, alimenté par
  /// `ZFlashcardSubmission.skipped`). Une note basse seule reste
  /// [motivation] — « s'être trompé » et « ne pas avoir essayé » méritent des
  /// messages différents, et confondre les deux revient à reprocher une
  /// erreur à qui n'a rien tenté.
  skipped,
}

/// Seuils du palier « exceptionnel » — configurables, jamais une durée en
/// dur dans un `build()`.
class ZFeedbackThresholds {
  /// Construit les seuils du palier exceptionnel.
  ///
  /// - [exceptionalUnder] : temps de réponse strictement inférieur exigé
  ///   (défaut 10 secondes) ;
  /// - [exceptionalMaxHints] : nombre d'indices maximal toléré (défaut `0` :
  ///   le moindre indice fait perdre le palier).
  const ZFeedbackThresholds({
    this.exceptionalUnder = const Duration(seconds: 10),
    this.exceptionalMaxHints = 0,
  });

  /// Temps de réponse sous lequel le palier exceptionnel est atteignable
  /// (comparaison **stricte** : `timeTaken < exceptionalUnder`).
  final Duration exceptionalUnder;

  /// Nombre d'indices maximal toléré pour le palier exceptionnel.
  final int exceptionalMaxHints;
}

/// Sélectionne le seau de feedback d'une soumission — fonction pure.
///
/// - [quality] est clampée par `config.clampQuality` (voie unique,
///   invariant AD-10) : `-3` devient `min`, `9` devient `max`, jamais
///   d'exception ;
/// - [timeTaken] et [hintsUsed] aberrants (négatifs) sont refusés pour le
///   palier exceptionnel plutôt que ramenés à zéro (voir plus bas) ;
/// - `q >= masteredThreshold` → [ZFeedbackTier.encouragement], promu en
///   [ZFeedbackTier.exceptional] si `timeTaken < thresholds.exceptionalUnder`
///   et `hintsUsed <= thresholds.exceptionalMaxHints` ;
/// - `q >= config.passThreshold` (mais non maîtrisée) → [ZFeedbackTier.neutral] ;
/// - sinon → [ZFeedbackTier.motivation] (`q0-2` : aucune note hors seau).
///
/// Le seuil de comparaison est `>=` plutôt que `==` sur `passThreshold` : les
/// deux formulations coïncident sur une configuration par défaut
/// (`passThreshold=3`, `masteredThreshold=4`, où `3` est la seule note entre
/// les deux seuils), mais seul le `>=` reste correct sur une échelle
/// tronquée — avec `passThreshold=1`, un `q2` est une réussite et doit
/// recevoir « bon », pas « mauvais » ; un `==` l'enverrait silencieusement en
/// `motivation`. Le `>=` colle par ailleurs à la définition normative des
/// seaux : « bon » signifie réussi mais non maîtrisé.
///
/// ## Une mesure aberrante ne peut pas mériter le palier exceptionnel
///
/// [timeTaken] et [hintsUsed] sont fournis par l'hôte, typiquement mesurés
/// par différence entre deux horodatages. Sur une correction NTP ou un
/// changement d'heure système entre les deux relevés, `timeTaken` peut
/// devenir négatif — et un apprenant ayant peiné cinq minutes recevrait à
/// tort le message « exceptionnel, en un éclair ! ».
///
/// Ces valeurs négatives ne sont pas clampées à zéro : ce serait exactement
/// le bug, `0` signifiant « instantané », la valeur la plus flatteuse de
/// l'échelle. Une entrée aberrante refuse donc le palier exceptionnel
/// (repli sur [ZFeedbackTier.encouragement] — la carte est maîtrisée, le
/// message reste juste et positif), jamais une exception, jamais une perte
/// de fonction.
///
/// ## Le seau « passée » ne se déduit pas d'une note
///
/// [skipped] (défaut `false`) déclare que la carte a été **passée** —
/// l'apprenant a dit ne pas savoir, sans réponse à corriger. Ce fait vient de
/// `ZFlashcardSubmission.skipped` ; aucune note, si basse soit-elle, ne le
/// produit toute seule. Quand il est vrai, il l'emporte : le seau est
/// [ZFeedbackTier.skipped], quelles que soient [quality], [timeTaken] et
/// [hintsUsed]. Une carte passée n'a pas été répondue, donc ni la vitesse ni
/// les indices n'ont de sens à son sujet.
///
/// Laisser [skipped] à son défaut rend exactement le seau qu'une version
/// antérieure de cette fonction rendait, pour toute entrée.
ZFeedbackTier zFeedbackTierFor({
  required int quality,
  required Duration timeTaken,
  required int hintsUsed,
  required ZSrsConfig config,
  required int masteredThreshold,
  ZFeedbackThresholds thresholds = const ZFeedbackThresholds(),
  bool skipped = false,
}) {
  // Fait déclaré, jamais dérivé : il précède toute lecture de la note, sans
  // quoi une carte passée recevrait le message de l'apprenant qui s'est
  // trompé.
  if (skipped) return ZFeedbackTier.skipped;

  // Voie unique de clamp : jamais de bornes réécrites ici, jamais
  // d'exception sur une note aberrante.
  final q = config.clampQuality(quality);

  if (q >= masteredThreshold) {
    // Une mesure aberrante refuse le palier : la ramener à zéro la rendrait
    // au contraire maximalement flatteuse (`0 s` = « en un éclair », `-1`
    // indice = « sans aide »).
    final fastEnough =
        !timeTaken.isNegative && timeTaken < thresholds.exceptionalUnder;
    final unaided = hintsUsed >= 0 && hintsUsed <= thresholds.exceptionalMaxHints;
    // Les deux conditions sont exigées : un indice fait perdre le palier,
    // même sur une réponse fulgurante.
    if (fastEnough && unaided) return ZFeedbackTier.exceptional;
    return ZFeedbackTier.encouragement;
  }
  if (q >= config.passThreshold) return ZFeedbackTier.neutral;
  return ZFeedbackTier.motivation;
}

/// Clé l10n du message d'un seau (`zcrud.session.feedback.<tier>`).
///
/// Cet espace de clés est propre à `zcrud_session` : il ne recoupe pas les
/// tables de libellés du cœur.
String zFeedbackKeyFor(ZFeedbackTier tier) =>
    'zcrud.session.feedback.${tier.name}';
