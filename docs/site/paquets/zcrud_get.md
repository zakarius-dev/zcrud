---
title: zcrud_get
description: Binding optionnel état/injection GetX + get_it pour zcrud, y compris les présentateurs UI manager et le composeur de champs.
---

# zcrud_get

## Rôle

`zcrud_get` branche l'injection et le cycle de vie de zcrud sur GetX/get_it :
`ZcrudGetScope` crée/scope/dispose le `ZFormController` selon ce lifecycle,
`ZGetResolver` résout les dépendances via `get_it`. Il fournit aussi des
implémentations GetX des ports UI (présentateur, toaster), le point de
composition unique du registre de widgets, et la seule exception
`reflectable` du monorepo.

## Quand l'utiliser

- Pour une application GetX + get_it consommant zcrud.
- Pour brancher un présentateur GetX (`Get.to`/`Get.bottomSheet`/`Get.dialog`)
  ou un toaster GetX (`Get.snackbar`) sur les ports purs de `zcrud_navigation`
  et `zcrud_ui_kit`.
- Pour adapter un modèle historique `reflectable` au `ZcrudRegistry`.

## Quand ne pas l'utiliser

- Avec Riverpod (`zcrud_riverpod`) ou `provider` (`zcrud_provider`) : chaque
  idiome de gestion d'état a son propre binding, jamais partagé.

## Types clés

| Type | Rôle |
|---|---|
| `ZcrudGetScope` | Scope de binding GetX/get_it. |
| `ZGetResolver` | Résolution de dépendances via `get_it`. |
| `ZGetFormPresenter` / `ZGetToaster` | Implémentations GetX des ports UI purs. |
| `registerZcrudFormFields` | Point de composition unique des widgets d'édition des satellites. |
| `ReflectableCodec` | Adaptateur `reflectable` vers le `ZcrudRegistry`. |

## Voir aussi

- [README du paquet](../../packages/zcrud_get/README.md) — installation, démarrage rapide, API complète.
- Matrice de paramètres de `ZGetFormPresenter` : `packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md`.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
