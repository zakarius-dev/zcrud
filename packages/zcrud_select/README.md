# zcrud_select

Satellite **sélection** de zcrud (AD-48) — présentateur riche `single`/`multiple`
au-dessus du fork MIT vendorisé `awesome_select` (`packages/awesome_select/`,
AD-49).

> **État : présentateur livré (fp-4-1).** `ZSmartSelectPresenter` est implémenté
> et exporté par le barrel. Il supplante le rendu natif des familles
> `select` / `radio` / `checkbox` / `multiselect` / `relation` par un **modal S2
> en bottom-sheet** (radios en mono, checkboxes en multi), avec **recherche**
> optionnelle. Aucun type `awesome_select` / `SmartSelect` / `S2*` ne fuit dans
> l'API publique (AD-40), garanti par `test/z_select_confinement_test.dart`.

## Utilisation

Injecter le présentateur via le scope pour activer le rendu riche :

```dart
ZcrudScope(
  selectPresenter: const ZSmartSelectPresenter(),
  child: /* … */,
)
```

Sans injection, les familles concernées retombent sur leur rendu natif
(non-régression AD-48).

## Modes réellement implémentés

- **Mono** (`select` / `radio` / `relation`) : `SmartSelect.single`, choix unique
  en **radios**, modal **bottom-sheet**.
- **Multi** (`checkbox` / `multiselect`) : `SmartSelect.multiple`, **checkboxes**,
  modal **bottom-sheet**, valeur métier = `List<Object?>`.
- **Recherche** : filtre du modal activé quand le champ est `searchable`.
- **Placeholder d'état vide LOCALISÉ** (FR-26) — via la l10n injectée (clé
  `select`), jamais un littéral anglais du fork.
- **A11y / RTL / thème** (AD-13 / FR-26) : déclencheur à annonce accessible
  unique, cible ≥ 48 dp, couleurs dérivées du `Theme`, insets directionnels.

> Les variantes `page` / `dialog` / `chips` du fork ne sont **pas** exposées :
> le présentateur ne rend qu'un modal bottom-sheet avec radios/checkboxes.

## Dépendances

- `zcrud_core` (unique arête `zcrud_*` sortante — AD-1, CORE OUT=0)
- `awesome_select` (fork MIT privé, feuille dépendue du SEUL `zcrud_select` — AD-49)

Le confinement (allowlist de dépendances + import + « déclarer » du vendor +
zéro fuite S2 au barrel) est gardé par `test/z_select_confinement_test.dart`.

Publié sous licence MIT.
