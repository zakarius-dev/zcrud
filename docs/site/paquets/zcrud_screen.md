---
title: zcrud_screen
description: Écran CRUD assemblé et déclaratif — liste, création, édition, sauvegarde et corbeille à partir d'une déclaration.
---

# zcrud_screen

## Rôle

`zcrud_screen` fournit `ZCrudScreen<T>` : la pièce qui **assemble** les briques
zcrud existantes (`DynamicList`/`ZTabbedList`, `ZRowAction`, `presentEdition` +
`ZPresentationPolicy`, `DynamicEdition`/`ZFormController`, `ZRepository` +
`ZDataRequest.deletedScope`) en un écran CRUD complet, à partir d'une
déclaration (`title` + `ZCrudSource`). Quand le type est enregistré au
`ZcrudRegistry`, les champs, les cellules et la reconstruction d'entité se
**dérivent** du schéma généré ; l'ACL vient du `ZcrudScope` ambiant et le mode
de présentation du breakpoint.

## Quand l'utiliser

- Pour un écran « liste dont on crée, édite et met à la corbeille les
  éléments » — le cas nominal d'un paquet qui s'appelle zcrud — sans réécrire
  le câblage écran par écran.
- Pour les variantes en lecture seule, **par déclaration** : `readOnly: true`,
  `canCreate: false`, `trash: ZTrashMode.none`, ou une source
  `ZCrudSource.items(rows)` sans callbacks.
- En cohabitation avec un chemin de données hôte (`ZCrudSource.items` +
  callbacks `onSave`/`onSoftDelete`/`onRestore`).

## Quand ne pas l'utiliser

- Pour une vue qui n'est pas une liste (carte géographique, organigramme) :
  composez directement `DynamicList`/`ZListController`/`presentEdition` —
  l'assemblage est mince, descendre d'un cran ne fait rien perdre.

## Types clés

| Type | Rôle |
|---|---|
| `ZCrudScreen<T>` | Écran CRUD assemblé et déclaratif. |
| `ZCrudSource<T>` | Source déclarative : `.repository(…)` ou `.items(…)`. |
| `ZTrashMode` | Activation de la corbeille (`auto`/`none`). |
| `ZCrudEditionBuilder<T>` | Formulaire applicatif, voie d'échappement de l'édition dérivée. |
| `ZCrudItemBuilder<T>` | Tuile de liste, voie d'échappement du rendu par défaut. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_screen/README.md) — installation, démarrage rapide, API complète.
- [zcrud_core](zcrud_core.md) — les briques assemblées (liste, édition, registre, ACL).
- [zcrud_navigation](zcrud_navigation.md) — `presentEdition` et la politique de présentation.
- [zcrud_list](zcrud_list.md) — backend de **rendu** Syncfusion (`ZListRenderer`), à injecter pour le layout `dataGrid`.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
