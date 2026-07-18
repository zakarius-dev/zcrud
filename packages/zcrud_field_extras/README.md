# zcrud_field_extras

Satellite **champs spécialisés** de zcrud (AD-53) — PIN / autocomplete / table
éditable / icon, servis par le `ZWidgetRegistry` du cœur, avec des dépendances
légères confinées à l'impl.

> **État : squelette de substrat (fp-1-2).** Coquille conforme, gardée et
> résolue offline. Les adaptateurs (et leurs dépendances confinées — `pinput` /
> …) seront écrits aux **Finitions**.

## Dépendances

- `zcrud_core` (unique arête `zcrud_*` sortante — AD-1, CORE OUT=0)

Confinement (allowlist de dépendances + import) gardé par
`test/z_field_extras_confinement_test.dart`. Publié sous licence MIT.
