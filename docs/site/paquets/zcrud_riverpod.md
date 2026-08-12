---
title: zcrud_riverpod
description: Binding optionnel état/injection Riverpod pour zcrud — réutilise le cœur réactif sans le réimplémenter.
---

# zcrud_riverpod

## Rôle

`zcrud_riverpod` branche l'injection et le cycle de vie du cœur zcrud sur
Riverpod : `ZcrudRiverpodScope` monte un `ProviderContainer`, expose le
`ZFormController` en `Provider.autoDispose` et fournit `ZRiverpodResolver`
pour le seam `ZDependencyResolver` du cœur. La réactivité elle-même reste
celle du cœur — un `ChangeNotifier` pur Flutter (invariant
[AD-2](../concepts/invariants.md#ad-2)) — ce paquet ne fait que l'exposer à
l'idiome Riverpod (invariant [AD-15](../concepts/invariants.md#ad-15)). Il
fournit aussi des providers génériques pour le domaine study.

## Quand l'utiliser

- Application déjà organisée autour de Riverpod, qui veut que l'injection
  zcrud (resolver, ACL, seams study) suive le même idiome que le reste du
  code.
- Pour dédupliquer des sélections de session study identiques
  structurellement mais reconstruites en mémoire, via `ZSessionConfigKey`.

## Quand ne pas l'utiliser

- Application sans Riverpod : préférez `ZcrudScope` (binding par défaut,
  zéro dépendance, dans `zcrud_core`) ou les bindings `zcrud_get`/
  `zcrud_provider`.
- Pour des providers typés concrets adossés à une entité applicative — ils
  s'instancient côté application, ce paquet reste générique.

## Types clés

| Type | Rôle |
|---|---|
| `ZcrudRiverpodScope` | Widget de scope : `ProviderContainer` + `ZFormController` auto-dispose + `ZcrudScope`. |
| `zFormControllerProvider` | Provider auto-dispose du `ZFormController`. |
| `ZRiverpodResolver` | Implémentation Riverpod du seam `ZDependencyResolver`. |
| `zStudyRepositoryProvider<T>` / `zStudyWatchAllProvider<T>` | Seam de repository et flux nu `watchAll()` pour le domaine study. |
| `ZSessionConfigKey` | Clé de family à égalité profonde, pour la sélection de session sans rebuild superflu. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_riverpod/README.md) — installation, démarrage rapide, API complète.
- `zcrud_core` — `ZcrudScope`, `ZFormController`, `ZDependencyResolver`.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
