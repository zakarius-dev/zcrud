/// Barrel d'API publique de `zcrud_select` — satellite SÉLECTION (AD-48).
///
/// Expose le **présentateur riche** [ZSmartSelectPresenter] (fp-4-1), impl
/// concrète du seam `ZSelectPresenter` (cœur) adossée au fork vendorisé
/// `awesome_select`. À injecter via `ZcrudScope(selectPresenter: const
/// ZSmartSelectPresenter())` pour supplanter le rendu natif des familles
/// `select` / `radio` / `checkbox` / `multiselect` / `relation` par un modal S2
/// responsive + recherche (parité DODLP).
///
/// **Isolation (AD-40/AD-49)** : le fork `awesome_select` (feuille privée
/// vendorisée) est dépendu par ce package et par LUI SEUL ; **aucun** type
/// `awesome_select` / `SmartSelect` / `S2*` ne fuit dans ce barrel — les helpers
/// de conversion restent privés sous `lib/src/`. Gardé par
/// `test/z_select_confinement_test.dart` (volet « zéro fuite S2 au barrel »).
///
/// **Composabilité (AR-4)** : `ZSmartSelectPresenter` est `const`-constructible
/// et **sans side-effect d'import** (aucun `register*()` top-level) — l'injection
/// est toujours explicite.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

/// **Apparence DODLP par défaut** (CR-SELECT-FID) : un hôte qui enrôle
/// [ZSmartSelectPresenter] obtient sans rien configurer la structure et les
/// métriques du `DynamicEdition` de DODLP legacy (carte à bordure douce,
/// rayon 12, `ListTile` + chevron, puces 6/4 en multi). Les **couleurs** sont
/// des **rôles** `ColorScheme` — chaque app garde donc son thème. Pour dévier :
/// `ZSmartSelectPresenter(spec: ZSelectTileSpec(…))`, chaîne
/// `paramètre > jeton > référence` ([ZSelectTileReference]).
export 'src/presentation/z_select_tile_reference.dart'
    show
        ZSelectChoiceStyle,
        ZSelectModalShape,
        ZSelectTileReference,
        ZSelectTileSpec;

/// **Maillon « jeton » de la chaîne** (CR-SELECT-SEAM, 2026-08-09) : la chaîne
/// est désormais complète, `paramètre ([ZSelectTileSpec]) > jeton
/// (`ZcrudTheme.select*`, huit jetons posés dans `zcrud_core`) > référence
/// ([ZSelectTileReference])`. [zSelectTileMetricsOf] est le seul endroit du
/// paquet où les trois maillons se rencontrent ; il est exporté pour qu'un hôte
/// puisse **vérifier** ce que sa configuration produit réellement.
///
/// Les deux convertisseurs de palier sont exportés pour la même raison : ils
/// sont **totaux** (nom inconnu ⇒ `null` ⇒ la référence décide, sans lever).
export 'src/presentation/z_select_tile_metrics.dart'
    show
        ZSelectTileMetrics,
        zSelectChoiceStyleFromToken,
        zSelectModalShapeFromToken,
        zSelectTileMetricsOf;
export 'src/presentation/z_smart_select_presenter.dart'
    show ZSmartSelectPresenter;
