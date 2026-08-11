/// Sélection des modes offerts par le parcours « Commencer à apprendre »
/// depuis une conversation.
///
/// Ce module ne déclare aucun enum : `ZReviewMode` (`zcrud_study_kernel`)
/// porte déjà l'ensemble des modes de session. Il déclare la sélection —
/// quels modes ce parcours propose, et lesquels il ne propose délibérément
/// pas.
///
/// ## Les modes non proposés ne sont pas nécessairement morts
///
/// [kZChatStudyModesNotLaunched] documente les modes hors de ce parcours,
/// sans préjuger de leur usage ailleurs dans l'application hôte : un mode
/// peut rester atteignable par une autre voie (un autre point d'entrée), ou
/// servir de valeur par défaut à un paramètre qui n'est pas un choix
/// utilisateur. « Non proposé ici » ne veut donc pas dire « supprimable ».
///
/// ## Aucun libellé ici
///
/// Ce module ne porte aucune chaîne d'affichage et aucune couleur : les
/// libellés (« Apprendre », « Réviser », « Test »…) appartiennent à la l10n
/// de l'hôte. Il expose des valeurs d'enum, pas des étiquettes.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Les modes offerts par « Commencer à apprendre », dans leur ordre
/// d'affichage attendu.
///
/// Ordre déterministe : c'est l'ordre que l'hôte doit respecter en affichant
/// les tuiles correspondantes.
const List<ZReviewMode> kZChatStudyLaunchModes = <ZReviewMode>[
  ZReviewMode.learn,
  ZReviewMode.spaced,
  ZReviewMode.whiteExam,
];

/// Les modes délibérément absents de ce parcours.
///
/// Exposé — et pas seulement documenté en prose — pour qu'une garde de
/// machine puisse vérifier la partition
/// (`kZChatStudyLaunchModes` union `kZChatStudyModesNotLaunched` égale
/// `ZReviewMode.values`) : ajouter une valeur à `ZReviewMode` sans la
/// classer ici fait rougir le test au lieu de la laisser filer en silence.
const Set<ZReviewMode> kZChatStudyModesNotLaunched = <ZReviewMode>{
  ZReviewMode.cramming,
  ZReviewMode.list,
  ZReviewMode.test,
};

/// `true` si [mode] est proposé par le parcours « Commencer à apprendre ».
bool zIsChatStudyLaunchMode(ZReviewMode mode) =>
    kZChatStudyLaunchModes.contains(mode);
