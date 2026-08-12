---
title: zcrud_menu
description: Menus contextuels à déclencheur et contenu découplés pour zcrud, déclarés en données.
---

# zcrud_menu

## Rôle

`zcrud_menu` fournit `ZActionMenu`, un menu contextuel dont le déclencheur et
les entrées sont déclarés en données (`ZMenuTrigger`, `ZMenuEntry`) plutôt
qu'en widgets construits. Le rendu passe par le port `ZMenuRenderer`,
injectable, avec un repli zéro-dépendance (`ZDefaultMenuRenderer`) toujours
fonctionnel.

## Quand l'utiliser

- Pour tout menu contextuel d'action — item de liste, carte, barre d'app,
  message de conversation — sans reconstruire un `PopupMenuButton` à chaque
  fois.
- Pour une entrée présente mais désactivée avec un motif annoncé à
  l'accessibilité, un état qu'une simple règle d'absence ne sait pas
  exprimer.

## Quand ne pas l'utiliser

- Dans `zcrud_core` : le cœur ne dépend d'aucun satellite (invariant AD-1),
  un menu qui y vit reste construit en dur tant que la couture n'y est pas
  déplacée.

## Types clés

| Type | Rôle |
|---|---|
| `ZActionMenu` | Point d'entrée unique du menu contextuel. |
| `ZMenuEntry` / `ZMenuEntryIds` | Entrée déclarée en données ; vocabulaire canonique d'identités. |
| `ZMenuTrigger` | Description immuable du déclencheur. |
| `ZMenuRenderer` / `ZDefaultMenuRenderer` | Port de rendu et son repli zéro-dépendance. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_menu/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
