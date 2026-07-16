/// État d'un contenu asynchrone, modélisé par un **enum** (NFR-U7, AD-32).
///
/// `ZContentState` remplace les combinaisons de booléens multi-état
/// (`isLoading` / `hasError` / `isEmpty`) que les applications historiques
/// (dodlp, iffd) manipulaient à la main : un `enum` scellé rend l'espace d'états
/// **explicite et exhaustif** (un `switch` sans `default` détecte à froid tout
/// palier oublié), là où trois `bool` autorisent des combinaisons incohérentes
/// (p. ex. `isLoading && hasError`).
///
/// Type **UI-pur, non persisté** : aucune (dé)sérialisation, aucun `@JsonKey`,
/// aucun `*.g.dart` (D2/D6). Les valeurs sont en **camelCase** (convention
/// d'enum du monorepo).
enum ZContentState {
  /// État neutre initial, avant tout chargement (rien à afficher encore).
  idle,

  /// Chargement en cours.
  loading,

  /// Chargement terminé sans donnée à afficher.
  empty,

  /// Chargement terminé en échec.
  error,

  /// Contenu prêt : le rendu est délégué au consommateur (via un `successBuilder`).
  success,
}
