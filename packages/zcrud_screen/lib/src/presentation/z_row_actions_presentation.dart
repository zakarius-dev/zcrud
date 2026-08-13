/// Présentation des **actions de ligne** d'un `ZCrudScreen` : en ligne, en
/// menu de débordement, en menu contextuel, ou adaptatif.
///
/// La déclaration porte deux choses distinctes, et c'est voulu :
/// * **l'affordance visible** — des boutons dans la ligne, ou un unique
///   déclencheur de menu ;
/// * **le geste contextuel** — clic droit sur pointeur, appui long sur
///   tactile, qui **s'ajoute** à l'affordance et ne la remplace jamais.
///
/// Un chemin offert au seul clic droit serait inatteignable au clavier et aux
/// lecteurs d'écran (invariant AD-13) : aucun mode de cette énumération ne
/// retire l'affordance visible.
library;

/// Comment les actions d'une ligne sont présentées à l'utilisateur.
enum ZRowActionsPresentation {
  /// **Défaut, comportement inchangé** : chaque action est un bouton visible
  /// dans la ligne, et aucun geste contextuel n'est posé.
  inline,

  /// Un **unique déclencheur de menu** par ligne remplace les boutons ; les
  /// actions sont les entrées du menu. Aucun geste contextuel.
  ///
  /// La présentation du menu (colonne, grille…) appartient au `ZMenuScope`
  /// ambiant — voir `ZGridMenuRenderer` de `zcrud_menu`.
  menu,

  /// Le déclencheur de menu de [menu], **plus** l'ouverture au clic droit
  /// (pointeur) et à l'appui long (tactile).
  ///
  /// Le déclencheur reste rendu : c'est lui qui garde l'action atteignable
  /// sans geste contextuel (invariant AD-13).
  contextMenu,

  /// **Adaptatif** : boutons en ligne tant que la ligne porte au plus
  /// `inlineActionLimit` actions offertes, déclencheur de menu au-delà — le
  /// geste contextuel étant offert dans les deux cas.
  ///
  /// C'est la forme qui évite à la fois la ligne encombrée de six boutons et
  /// le menu à ouvrir pour une action unique.
  auto,
}

/// À qui appartient l'**appui long** sur une ligne, quand deux fonctions le
/// réclament.
///
/// Le rendu de liste sait, lui aussi, occuper ce geste — la copie du contenu
/// d'une cellule à l'appui long en est le cas courant. Deux fonctions sur le
/// même geste, c'est la première qui gagne l'arène, pas celle que l'utilisateur
/// visait : l'arbitrage est donc **déclaré**, jamais découvert à l'exécution.
///
/// L'écran ne peut pas lire la configuration du rendu de liste (il n'en dépend
/// pas, et ne doit pas), d'où cette déclaration : c'est l'application, qui
/// possède les deux déclarations, qui tranche.
///
/// Dans tous les cas, le **clic droit** reste au menu contextuel (aucune autre
/// fonction ne le réclame) et le déclencheur visible reste offert : arbitrer en
/// faveur de la liste ne retire aucune action, il change seulement le chemin.
enum ZRowLongPressOwner {
  /// L'appui long ouvre le menu contextuel (défaut).
  contextMenu,

  /// L'appui long appartient au rendu de liste (copie de cellule, par
  /// exemple) : le menu contextuel ne s'ouvre plus qu'au clic droit.
  ///
  /// À déclarer dès que la liste active un geste d'appui long — par exemple
  /// `copyCellOnLongPress` du rendu `zcrud_list`.
  list,

  /// L'appui long **ouvre la sélection multiple** : il coche la ligne pressée
  /// et fait apparaître les cases. Le menu contextuel ne s'ouvre plus qu'au
  /// clic droit.
  ///
  /// C'est le motif tactile usuel d'une liste sélectionnable, et le troisième
  /// prétendant au même doigt — d'où sa place ici plutôt qu'un drapeau à part :
  /// deux réglages indépendants auraient permis de déclarer deux propriétaires
  /// à la fois, c'est-à-dire de reproduire exactement le conflit que cette
  /// énumération existe pour empêcher.
  ///
  /// Sans effet si aucune politique de sélection n'est déclarée. Sans effet
  /// non plus sur un rendu de grille (`ZListDataGridLayout`), où les gestes de
  /// ligne appartiennent au backend : y déclarer ce propriétaire retirerait
  /// l'appui long au menu contextuel sans rien ouvrir en échange.
  selection,
}
