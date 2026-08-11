---
title: zcrud_provider
description: Binding optionnel état/injection provider pour zcrud — complète la matrice multi-gestionnaire.
---

# zcrud_provider

## Rôle

`zcrud_provider` branche l'injection et le cycle de vie du cœur zcrud sur le
package `provider` : `ZcrudProviderScope` monte le `ZFormController` dans un
`ChangeNotifierProvider` (dispose géré automatiquement) et fournit
`ZProviderResolver` pour le seam `ZDependencyResolver` du cœur. La
réactivité reste celle du cœur — un `ChangeNotifier` pur Flutter (invariant
[AD-2](../concepts/invariants.md#ad-2)) — ce paquet ne fait que l'exposer à
l'idiome `provider` (invariant [AD-15](../concepts/invariants.md#ad-15)).

## Quand l'utiliser

- Application déjà organisée autour de `provider`, qui veut que l'injection
  zcrud (resolver, ACL, seams applicatifs) suive le même idiome que le reste
  du code.

## Quand ne pas l'utiliser

- Application sans `provider` : préférez `ZcrudScope` (binding par défaut,
  zéro dépendance, dans `zcrud_core`) ou les bindings `zcrud_get`/
  `zcrud_riverpod`.

## Types clés

| Type | Rôle |
|---|---|
| `ZcrudProviderScope` | Widget de scope : `ChangeNotifierProvider<ZFormController>` + `ZcrudScope`. |
| `ZProviderResolver` | Implémentation `provider` du seam `ZDependencyResolver`, adossée à `context.read<T>()`. |
| `ZProviderApi` | Marqueur de version de l'API publique du paquet. |

## Voir aussi

- [README du paquet](../../packages/zcrud_provider/README.md) — installation, démarrage rapide, API complète.
- `zcrud_core` — `ZcrudScope`, `ZFormController`, `ZDependencyResolver`.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
