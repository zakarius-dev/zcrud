---
title: zcrud_ui_kit
description: Kit de widgets UI transverses — états de contenu, confirmation, notification, garde de saisie et page-shell déclaratif.
---

# zcrud_ui_kit

## Rôle

`zcrud_ui_kit` factorise les patterns UI génériques d'une application CRUD
Flutter : l'état d'un contenu asynchrone en enum ([ZContentState]) plutôt
qu'en combinaisons de `bool`, la tonalité d'une confirmation
([ZConfirmTone]), la sévérité d'un toast servie par un port pluggable
([ZToaster]), une garde anti-perte de saisie ([ZDiscardChangesGuard]), un
index alphabétique cliquable, des transitions de route RTL-aware, et un
**page-shell déclaratif** ([ZPageScaffold] / [ZPageShellBody] /
[ZSearchableAppBar]) qui factorise l'app-bar recherchable, repliable et à
onglets. Il dépend uniquement de `zcrud_core` et consomme ses seams en
lecture seule, sans jamais importer de gestionnaire d'état ni de bibliothèque
UI tierce.

## Quand l'utiliser

- Pour un écran qui a besoin d'un **état de chargement/vide/erreur**
  cohérent, thémé et accessible, sans réécrire trois `bool`.
- Pour une **confirmation destructive** ou un **toast** dark-mode-aware,
  sans coupler l'écran à un gestionnaire d'état.
- Pour une **garde anti-perte de saisie** liée à l'état *dirty* d'un
  `ZFormController`.
- Pour une **app-bar recherchable, repliable et à onglets** — avec ou sans
  `Scaffold` propre selon que l'hôte enveloppe déjà le sien.

## Quand ne pas l'utiliser

- Pour une grille adaptative de cartes : c'est le rôle de
  `zcrud_responsive`.
- Pour le rendu d'une liste de données (`SfDataGrid`) : c'est le rôle de
  `zcrud_list`.

## Types clés

| Type | Rôle |
|---|---|
| `ZContentState` / `ZContentStateView` | État d'un contenu asynchrone en enum et l'aiguilleur `switch` exhaustif qui le rend. |
| `ZConfirmTone` / `ZConfirmDialog` / `showZConfirmDialog` | Tonalité de confirmation en enum et dialog dark-mode-aware associé. |
| `ZToastSeverity` / `ZToaster` / `ZScaffoldMessengerToaster` | Sévérité de toast, port de notification pluggable et son implémentation par défaut. |
| `ZDiscardChangesGuard` | `PopScope` interceptant la sortie tant qu'un état *dirty* injecté est vrai. |
| `ZPageScaffold` / `ZPageShellBody` / `ZSearchableAppBar` | Page-shell déclaratif — deux formes (avec/sans `Scaffold` propre) partageant la même app-bar recherchable, repliable et à onglets. |

## Voir aussi

- [README du paquet](../../packages/zcrud_ui_kit/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
