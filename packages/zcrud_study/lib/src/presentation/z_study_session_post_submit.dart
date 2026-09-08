/// Politique de **retenue après soumission** dans l'écran de session assemblé,
/// et sa table unique de résolution.
///
/// Soumettre une réponse fait deux choses distinctes : **noter** la carte, et
/// **passer** à la suivante. Les deux sont indissociables dans un mode noté —
/// la correction détaillée y est différée à la fin. Elles ne le sont pas dans
/// un mode d'apprentissage : y enchaîner immédiatement fait disparaître la
/// réponse avant qu'elle ait pu être lue, ce qui retire au mode l'essentiel de
/// ce qu'il apporte.
///
/// La retenue ne touche **que** l'instant du passage : la note part exactement
/// comme avant, au même moment, avec la même valeur, par la même et unique voie
/// d'écriture SRS.
///
/// La décision n'est prise qu'à UN endroit ([zStudySessionHoldsAfterSubmit]) :
/// un second aiguillage écrit dans un `build()` divergerait en silence le jour
/// où la règle change.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// Politique de retenue demandée par l'hôte.
enum ZStudySessionPostSubmitPolicy {
  /// Défaut — la retenue suit le mode (cf. [zStudySessionHoldsAfterSubmit]).
  auto,

  /// La session retient toujours la carte notée jusqu'à l'action de
  /// continuation.
  ///
  /// À réserver aux parcours d'apprentissage : dans un mode chronométré, la
  /// retenue casse la cadence que le mode existe pour imposer.
  hold,

  /// Aucune retenue : la carte notée part immédiatement, quel que soit le mode.
  ///
  /// Restaure exactement le comportement d'un assemblage sans retenue.
  advance,
}

/// Vrai si l'écran de session doit **retenir** la carte après sa notation.
///
/// Table **unique** de cette décision. Le `switch` sur les six [ZReviewMode]
/// est exhaustif et sans `default` : une septième valeur d'enum doit casser la
/// compilation ici plutôt que retomber en silence sur « pas de retenue » — un
/// futur mode d'apprentissage perdrait autrement l'accès à sa correction sans
/// qu'aucun test ne rougisse.
///
/// La retenue ne s'applique qu'aux modes servis par le moteur SRS : c'est le
/// seul chemin où notation et passage partent du même geste. Sur un mode servi
/// par un autre runtime, [ZStudySessionPostSubmitPolicy.hold] reste sans effet.
// Cette table N'EST PAS une seconde table de runtime (AD-34) : elle ne désigne
// aucun moteur de session et n'atteint aucune voie d'écriture SRS — elle décide
// de l'instant du passage. Elle est le pendant, côté écran assemblé, de la
// table `zDefaultAdvanceBehavior` de la surface de saisie : celle-ci ne
// gouverne que le minuteur d'auto-passage INTERNE à la surface (son
// `onAdvance`), et n'a jamais pu atteindre le passage décidé par l'assemblage.
bool zStudySessionHoldsAfterSubmit(
  ZReviewMode mode,
  ZStudySessionPostSubmitPolicy policy,
) =>
    switch (policy) {
      ZStudySessionPostSubmitPolicy.hold => true,
      ZStudySessionPostSubmitPolicy.advance => false,
      ZStudySessionPostSubmitPolicy.auto => switch (mode) {
          ZReviewMode.learn => true,
          ZReviewMode.spaced => false,
          ZReviewMode.list => false,
          ZReviewMode.test => false,
          ZReviewMode.whiteExam => false,
          ZReviewMode.cramming => false,
        },
    };
