/// `ZScreenMode` — les **trois états** d'un `ZCrudScreen` : écran complet,
/// fiche de détail, consultation verrouillée.
///
/// Ces trois états remplacent le booléen `readOnly`, qui ne savait exprimer
/// que deux d'entre eux — et pas celui dont les applications ont le plus
/// besoin : consulter **le formulaire entier** d'un élément, puis revenir à
/// son édition quand le droit de modification existe.
library;

/// Les trois modes d'un `ZCrudScreen`.
///
/// | Mode | Créer | Consulter la fiche | Éditer | Corbeille |
/// |---|---|---|---|---|
/// | [full] | oui | selon `detailsEnabled` | oui | oui |
/// | [details] | non | **oui** | oui si `ZCrudAction.update` | non |
/// | [locked] | non | non | non | non |
///
/// Le mode gouverne les **gestes offerts**, jamais les droits : l'ACL tranche
/// toujours en dernier. Déclarer [details] n'accorde pas l'édition à qui ne
/// l'a pas ; déclarer [full] ne fait apparaître aucun bouton refusé.
///
/// 🔴 **Consulter n'est pas un mode d'écran** : c'est un **geste de ligne**.
/// Un écran complet — qui crée, met à la corbeille et restaure — ouvre ses
/// fiches en déclarant `ZCrudScreen.detailsEnabled: true`, sans changer de
/// mode. Basculer en [details] pour obtenir la consultation retirerait la
/// création et la corbeille de tout l'écran.
enum ZScreenMode {
  /// Écran complet — création, édition, corbeille, selon l'ACL et la source
  /// (comportement par défaut, inchangé).
  ///
  /// La **fiche de détail** s'y ajoute par déclaration
  /// (`ZCrudScreen.detailsEnabled: true`) : chaque ligne s'ouvre alors en
  /// consultation, **sans** que l'écran perde la création ni la corbeille.
  full,

  /// **Écran de consultation** : la liste ne crée rien et n'a pas de corbeille,
  /// mais chaque ligne s'ouvre en **consultation du formulaire entier** — tous
  /// ses champs, rendus en lecture seule, et non les seules colonnes affichées.
  ///
  /// Le retour vers l'édition reste offert : l'action « modifier » est rendue
  /// **si et seulement si** l'ACL autorise `ZCrudAction.update`, et la fiche
  /// elle-même porte la bascule (`ZCrudEditionScope.onEditOf`).
  ///
  /// À choisir quand l'écran **entier** est un écran de consultation. Pour un
  /// écran complet dont on veut aussi les fiches, c'est
  /// `ZCrudScreen.detailsEnabled` qu'il faut, pas ce mode.
  details,

  /// **Consultation verrouillée** : ni création, ni consultation de fiche, ni
  /// édition, ni corbeille — les actions de ligne fournies par l'application
  /// restent rendues (elles lui appartiennent).
  ///
  /// C'est l'exact équivalent de l'ancien `readOnly: true`.
  locked,
}
