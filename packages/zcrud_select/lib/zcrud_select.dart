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

export 'src/presentation/z_smart_select_presenter.dart'
    show ZSmartSelectPresenter;
