/// `ZListTabsStore` — **seam de persistance NEUTRE** de l'onglet actif d'un
/// `ZCrudScreen` **et de sa position de défilement, par onglet**.
///
/// ## Le besoin, nommé
///
/// Un écran à onglets rouvre toujours sur le **premier** onglet, en **haut** de
/// liste. Rien ne plante : l'écran est simplement plus long à parcourir qu'il
/// ne devrait, et l'agent qui suit une catégorie donnée y revient des dizaines
/// de fois par jour. C'est le type d'écart qu'aucun `analyze`, aucun test et
/// aucune capture isolée ne fait apparaître.
///
/// **Deux choses sont perdues, pas une** : l'index de l'onglet, et le
/// **défilement de chaque onglet**. C'est la moitié qu'on oublie en lisant
/// « persistance d'onglet » — un onglet retrouvé en haut de sa liste n'a
/// restitué que la moitié du geste.
///
/// ## Pourquoi ce patron et pas un autre
///
/// Ce port **réutilise le patron `ZSectionCollapseStore` / `ZStepIndexStore`**
/// (repli des sections, étape courante) plutôt que d'ouvrir un troisième style
/// de persistance : même forme (`abstract` + `const`, `load`/`save`, clé de
/// portée opaque), même contrat défensif, même variante mémoire pour les tests.
/// Un hôte qui a déjà branché un stockage clé-valeur pour les sections branche
/// celui-ci **de la même façon**, et `zcrud_screen` ne tire **aucune**
/// dépendance de stockage (invariant AD-1).
///
/// ## Contrat
///
/// * **synchrone** et **défensif** : une implémentation qui lève ne casse pas
///   l'écran — l'appelant absorbe (invariant AD-10) et se comporte comme si
///   rien n'était persisté ;
/// * **écriture par emplacement, jamais par portée entière** : [saveTabIndex]
///   n'écrit que l'index, [saveScrollOffset] n'écrit qu'**un** onglet. Une
///   signature qui remettrait la portée complète à chaque geste ferait qu'un
///   relais naïf effacerait les préférences voisines ;
/// * `null` ⇒ « rien de persisté », **pas** « onglet 0 » ni « offset 0 ». C'est
///   l'appelant qui choisit le repli, et il le documente ;
/// * un index **hors bornes** est ignoré (le jeu d'onglets a pu rétrécir entre
///   deux sessions), un offset négatif ou non fini aussi.
///
/// ## Clé de portée
///
/// La clé est **dérivée par l'écran**, jamais demandée : type d'entité,
/// identité de l'écran (`collectionId`, à défaut son titre) et **jeu
/// d'onglets** (clés de page, dans l'ordre). Deux écrans à onglets ne se
/// marchent donc jamais dessus, et un changement de jeu d'onglets invalide
/// naturellement l'ancienne préférence — un index mémorisé pour d'autres
/// onglets ne peut pas être réappliqué aux nouveaux. `ZCrudScreen.tabsScopeKey`
/// reste la voie d'échappement quand deux écrans partagent les trois.
///
/// Défaut : `ZCrudScreen.tabsStore == null` ⇒ **aucune persistance**, aucune
/// lecture, aucune écriture — comportement historique **strictement inchangé**.
library;

/// Port de (dé)chargement de l'**onglet actif** et de son **défilement**.
///
/// Implémentation concrète **déférée à l'application/binding** — le paquet n'en
/// fournit qu'une variante mémoire ([ZInMemoryListTabsStore]).
abstract class ZListTabsStore {
  /// Contrat `const` (impls immuables).
  const ZListTabsStore();

  /// Charge l'index d'onglet persisté pour [scopeKey]. Rend `null` si rien
  /// n'est persisté. Ne lève **jamais** (invariant AD-10).
  int? loadTabIndex(String scopeKey);

  /// Persiste l'[index] de l'onglet actif pour [scopeKey] — et lui seul.
  /// Ne lève **jamais**.
  void saveTabIndex(String scopeKey, int index);

  /// Charge le défilement persisté de l'onglet [tabIndex] dans [scopeKey].
  /// Rend `null` si rien n'est persisté. Ne lève **jamais**.
  double? loadScrollOffset(String scopeKey, int tabIndex);

  /// Persiste le défilement [offset] de l'onglet [tabIndex] — **cet onglet
  /// seul**, sans toucher aux autres emplacements de [scopeKey].
  /// Ne lève **jamais**.
  void saveScrollOffset(String scopeKey, int tabIndex, double offset);
}

/// Store mémoire (défaut testable) : conserve l'onglet actif et les
/// défilements **par portée** pour la durée de vie de l'instance.
///
/// Ne survit **pas** au redémarrage — la persistance disque relève de
/// l'application, jamais du paquet.
class ZInMemoryListTabsStore extends ZListTabsStore {
  /// Construit un store mémoire vide.
  ZInMemoryListTabsStore();

  final Map<String, int> _index = <String, int>{};
  final Map<String, Map<int, double>> _offsets = <String, Map<int, double>>{};

  @override
  int? loadTabIndex(String scopeKey) => _index[scopeKey];

  @override
  void saveTabIndex(String scopeKey, int index) => _index[scopeKey] = index;

  @override
  double? loadScrollOffset(String scopeKey, int tabIndex) =>
      _offsets[scopeKey]?[tabIndex];

  @override
  void saveScrollOffset(String scopeKey, int tabIndex, double offset) {
    // Écriture d'un SEUL emplacement : les offsets voisins de la même portée
    // sont conservés (c'est le défaut que le contrat du port interdit).
    (_offsets[scopeKey] ??= <int, double>{})[tabIndex] = offset;
  }
}
