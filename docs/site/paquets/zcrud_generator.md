---
title: zcrud_generator
description: Générateur build_runner qui lit @ZcrudModel et émet (dé)sérialisation, ZFieldSpec[] et enregistrement.
---

# zcrud_generator

## Rôle

`zcrud_generator` est le générateur `build_runner` du moteur codegen zcrud.
Il lit **statiquement** les modèles annotés `@ZcrudModel`/`@ZcrudField`
(`zcrud_annotations`) — jamais `reflectable`, jamais d'exécution — et émet
dans le `part '<file>.g.dart'` la (dé)sérialisation défensive, le
`ZFieldSpec[]` du schéma et l'enregistrement au `ZcrudRegistry`. Le modèle
annoté reste la source unique de vérité (invariant
[AD-3](../concepts/invariants.md#ad-3)).

## Quand l'utiliser

- Dès qu'un modèle de votre application porte `@ZcrudModel` : ajoutez ce
  paquet en `dev_dependency` aux côtés de `build_runner`.
- Pour un champ date qui doit être persisté en `Timestamp` Firestore natif
  plutôt qu'en chaîne ISO-8601 (`ZPersistAs.timestamp`) : le générateur
  collecte l'artefact neutre que `zcrud_firestore` consomme.

## Quand ne pas l'utiliser

- En `dependency` (runtime) : ce paquet n'a rien à offrir hors du
  `build_runner`, et tirerait `analyzer`/`build` dans le build de
  l'application.
- Pour un modèle qui n'a pas besoin d'édition/liste générées.

## Types clés

| Type | Rôle |
|---|---|
| `zcrudModelBuilder` | Fabrique de `Builder` référencée par `build.yaml` — point d'entrée `build_runner`. |
| `ZGeneratorApi` | Marqueur de version de l'API publique du paquet. |

## Voir aussi

- [README du paquet](../../packages/zcrud_generator/README.md) — installation, contrat `fromMap`, API complète.
- `zcrud_annotations` — les annotations lues par ce générateur.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
