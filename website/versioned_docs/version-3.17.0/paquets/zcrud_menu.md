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
fonctionnel — et, à côté de lui, un rendu en **grille de tuiles**
(`ZGridMenuRenderer`).

Quel que soit le renderer et quel que soit le geste, la **voie de sélection est
unique** : l'entrée reçue est re-résolue dans la liste courante avant d'être
invoquée. Un renderer — y compris un adaptateur tiers — ne peut donc ni
exécuter une entrée désactivée, ni imposer l'effet d'une entrée qu'il aurait
fabriquée lui-même.

## Quand l'utiliser

- Pour tout menu contextuel d'action — item de liste, carte, barre d'app,
  message de conversation — sans reconstruire un `PopupMenuButton` à chaque
  fois.
- Pour une entrée présente mais désactivée avec un motif annoncé à
  l'accessibilité, un état qu'une simple règle d'absence ne sait pas
  exprimer.
- Pour offrir le même menu au **geste contextuel** (clic droit au pointeur,
  appui long au tactile) via `ZContextMenuRegion` : le geste **s'ajoute** à
  l'affordance visible, il ne la remplace jamais — un chemin offert au seul
  clic droit serait inatteignable au clavier et aux lecteurs d'écran
  ([invariant AD-13](../concepts/invariants.md#ad-13)).

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
| `ZGridMenuRenderer` | Rendu en grille de tuiles (colonnes configurables), avec plancher tactile de 48 dp tenu par la disposition. |
| `ZContextMenuRegion` | Ouverture du menu par geste contextuel (clic droit / appui long), en complément de l'affordance visible. |
| `ZMenuScope` | Couture d'injection du `ZMenuRenderer` — un `InheritedWidget` **dédié**, et non un paramètre de `ZcrudScope` : le cœur ne peut pas dépendre d'un satellite ([AD-1](../concepts/invariants.md#ad-1)). Chaîne totale `paramètre appelant > scope hôte > repli` ; scope absent ou renderer absent rendent tous deux `ZDefaultMenuRenderer`, jamais une levée. |
| `ZMenuSurface` | Surface flottante ouverte à une **position** plutôt que sous un déclencheur — le pendant contextuel de `ZDefaultMenuRenderer`, dont hérite tout renderer qui n'implémente pas la sienne. |
| `ZMenuPanelEntry` | Entrée de panneau pour les surfaces de menu composées. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_menu/README.md) — installation, démarrage rapide, API complète.
- [zcrud_screen](zcrud_screen.md) — l'écran CRUD assemblé, qui rend ses actions de ligne en menu et arbitre le propriétaire de l'appui long.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
