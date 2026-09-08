/// Politique de **révélation de la réponse** dans l'écran de session assemblé,
/// et sa table unique de résolution.
///
/// La révélation est une affordance d'APPRENTISSAGE : voir la réponse est
/// l'objet même du mode d'apprentissage initial, alors qu'un mode noté la
/// réserve à la correction — l'y offrir avant la soumission viderait la
/// notation de son sens.
///
/// La décision n'est prise qu'à UN endroit ([zStudySessionRevealsAnswer]) :
/// un second aiguillage écrit dans un `build()` divergerait en silence le jour
/// où la règle change, et deux surfaces du même mode se comporteraient
/// différemment.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// Politique de révélation demandée par l'hôte.
enum ZStudySessionRevealPolicy {
  /// Défaut — la révélation suit le mode (cf. [zStudySessionRevealsAnswer]).
  auto,

  /// Révélation offerte quel que soit le mode.
  ///
  /// À réserver aux parcours de consultation : dans un mode noté, elle donne
  /// la réponse avant la soumission.
  always,

  /// Aucune affordance de révélation, quel que soit le mode.
  ///
  /// Restaure exactement le rendu d'un assemblage sans révélation.
  never,
}

/// Vrai si l'écran de session doit porter l'affordance de révélation.
///
/// Table **unique** de cette décision. Le `switch` sur les six [ZReviewMode]
/// est exhaustif et sans `default` : une septième valeur d'enum doit casser la
/// compilation ici plutôt que retomber en silence sur « pas de révélation » —
/// un futur mode d'apprentissage perdrait autrement l'accès à la réponse sans
/// qu'aucun test ne rougisse.
// Cette table N'EST PAS une seconde table de runtime (AD-34) : elle ne
// désigne aucun moteur de session et n'atteint aucune voie d'écriture SRS —
// elle décide d'une affordance d'affichage. C'est pourquoi ce fichier ne
// figure pas dans la liste scannée par la garde « aucun second `switch` sur
// `ZReviewMode` », qui verrouille la DÉSIGNATION du runtime.
bool zStudySessionRevealsAnswer(
  ZReviewMode mode,
  ZStudySessionRevealPolicy policy,
) =>
    switch (policy) {
      ZStudySessionRevealPolicy.always => true,
      ZStudySessionRevealPolicy.never => false,
      ZStudySessionRevealPolicy.auto => switch (mode) {
          ZReviewMode.learn => true,
          ZReviewMode.spaced => false,
          ZReviewMode.list => false,
          ZReviewMode.test => false,
          ZReviewMode.whiteExam => false,
          ZReviewMode.cramming => false,
        },
    };
