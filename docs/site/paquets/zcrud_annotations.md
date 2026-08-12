---
title: zcrud_annotations
description: Annotations déclaratives (@ZcrudModel, @ZcrudField, @ZcrudId, @ZcrudIgnore) consommées par le générateur zcrud.
---

# zcrud_annotations

## Rôle

`zcrud_annotations` porte quatre annotations `const` pur-données —
`@ZcrudModel`, `@ZcrudField`, `@ZcrudId`, `@ZcrudIgnore` — et l'enum `ZPersistAs`. Aucun
comportement : `zcrud_generator` les lit **statiquement** au `build_runner`
pour émettre la (dé)sérialisation, le `ZFieldSpec[]` et l'enregistrement au
`ZcrudRegistry`. Le modèle annoté est la source unique de vérité du schéma
(invariant [AD-3](../concepts/invariants.md#ad-3)).

## Quand l'utiliser

- Pour déclarer un **modèle de domaine** qui doit piloter à la fois un
  formulaire d'édition et une colonne de liste, depuis une seule définition.
- Pour marquer un champ date comme persisté en `Timestamp` Firestore natif
  plutôt qu'en chaîne ISO-8601 (`@ZcrudField(persistAs: ZPersistAs.timestamp)`).
- Pour exclure explicitement un champ de la persistance générée
  (`@ZcrudIgnore()`) : un champ non annoté dont le type n'est pas sérialisable
  est refusé au build plutôt que perdu en silence — le marqueur assume
  l'exclusion, au point de déclaration.

## Quand ne pas l'utiliser

- Seul, sans `zcrud_generator` en `dev_dependency` : les annotations n'ont
  aucun effet runtime, elles ne sont lues qu'au moment du codegen.
- Pour un modèle qui n'a pas besoin d'édition/liste générées — un modèle de
  transport interne peut rester un simple `@JsonSerializable`.

## Types clés

| Type | Rôle |
|---|---|
| `ZcrudModel` | Annotation de classe : modèle sérialisable et enregistrable, porte le contrat `fromMap` obligatoire. |
| `ZcrudField` | Annotation de champ : projette chaque paramètre dans le `ZFieldSpec` correspondant. |
| `ZcrudId` | Marqueur du champ identifiant (`id`) d'un modèle. |
| `ZcrudIgnore` | Marqueur d'exclusion : le champ n'est pas écrit par le codegen (canal manuel, collaborateur d'exécution, valeur dérivée). |
| `ZPersistAs` | Hint de format de persistance d'un champ date (`iso8601` / `timestamp`). |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_annotations/README.md) — installation, démarrage rapide, API complète.
- `zcrud_generator` — le générateur qui lit ces annotations.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
