---
title: zcrud_field_extras
description: Champs spécialisés zcrud (PIN/OTP, autocomplétion, table éditable) servis via le ZWidgetRegistry.
---

# zcrud_field_extras

## Rôle

`zcrud_field_extras` enregistre trois widgets d'édition riches — PIN/OTP,
autocomplétion et table éditable — dans le `ZWidgetRegistry` de
`zcrud_core`, sous des `kind` alignés sur `EditionFieldType`. L'enrôlement
est explicite (bootstrap), jamais un effet de bord d'import ; sans lui, ces
champs dégradent proprement plutôt que de planter.

## Quand l'utiliser

- Pour un champ PIN/OTP segmenté avec cible tactile et progression
  accessible intégrées.
- Pour une autocomplétion texte simple, sans dépendance tierce.
- Pour une petite table éditée intégralement en mémoire (pas de persistance
  via `@ZcrudModel`).

## Quand ne pas l'utiliser

- Pour une table dont le contenu doit être persisté par le générateur zcrud
  : cette combinaison n'est pas supportée aujourd'hui.
- Pour un besoin de « tags riches » : `EditionFieldType.tags` route vers la
  famille native du cœur, pas vers ce registre.

## Types clés

| Type | Rôle |
|---|---|
| `registerZFieldExtrasFields` | Enrôle les trois builders dans un `ZWidgetRegistry`. |
| `ZPinFieldWidget` | Champ PIN/OTP segmenté. |
| `ZAutocompleteFieldWidget` | Champ texte auto-complété natif Flutter. |
| `ZEditableTableFieldWidget` | Table éditable virtualisée, en mémoire. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_field_extras/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
