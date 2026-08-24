---
title: zcrud_chat_material
description: Habillage Material du chat zcrud — composer, feuille de réglages riche par défaut et feuille d'outils, satellite opt-in sans dépendance tierce.
---

# zcrud_chat_material

## Rôle

`zcrud_chat_material` est le paquet **satellite** qui habille en Material
Design les surfaces chromatiquement nues de `zcrud_chat` : le composer
(bouton d'envoi animé, chips d'effort, badges, chips de pièces jointes,
slider de budget), la **feuille de réglages** et la **feuille d'outils**.
Chaque widget se branche sur un créneau que le socle expose déjà — ce paquet
ne construit ni composer ni feuilles parallèles, et n'ajoute aucune
dépendance tierce (le Material vient du SDK Flutter lui-même).

## Quand l'utiliser

- Pour obtenir un composer de chat entièrement stylé Material sans écrire
  soi-même les rôles `ColorScheme`, les glyphes et les dimensions conformes
  à l'accessibilité.
- Pour une feuille de réglages **riche sans rien déclarer** — les neuf
  familles standard habillées d'office, chacune remplaçable une à une.
- Pour ne monter qu'une seule pièce (le bouton d'envoi, par exemple) sur un
  composer par ailleurs composé à la main.

## Quand ne pas l'utiliser

- Si votre application suit un autre design system (Cupertino, thème
  maison) : composez directement sur les créneaux nus de `zcrud_chat`.
- Pour du rendu Markdown/LaTeX ou une coquille Syncfusion : ce sont les
  rôles des satellites `zcrud_chat_markdown` et `zcrud_chat_syncfusion`.

## La feuille de réglages, riche par défaut {#feuille-reglages}

`ZChatMaterialSettingsSheet` rend les **neuf familles standard** de la
feuille de réglages du socle — en-tête, préréglages, longueur de réponse,
biais de longueur, budget de calcul, révélation du raisonnement, capacités,
corpus, entrée inconnue — en tuiles Material complètes, sans qu'un hôte
n'écrive un seul builder. Chaque famille reste **remplaçable une à une**
(priorité paramètre > défaut : un builder d'hôte gagne, rien ne
s'additionne), et les builders lisent et écrivent le même
`ZChatSettingsController` que la feuille nue — un seul état, celui qui part
dans la requête.

Ce que l'hôte garde : ses **libellés** (`ZChatMaterialSettingsLabels` — un
libellé absent signifie une affordance absente, jamais un texte du socle),
ses catalogues (corpus, capacités, préréglages), ses sections et `onClose`.
La feuille nue du cœur (`ZChatSettingsSheet`) est inchangée : ce défaut
riche ne joue que pour qui monte la feuille Material.

## La feuille d'outils Material {#feuille-outils}

`ZChatMaterialToolsSheet` habille la feuille d'outils déclarative de
[zcrud_chat](zcrud_chat.md#feuille-outils) : elle rend le catalogue résolu
d'un `ZChatToolController` en **une tuile par nature** d'outil
(`ZChatMaterialToolTile`) — interrupteur pour une bascule, pas-à-pas pour un
cycle, choix pour une sélection — et consulte d'abord les `kindBuilders` de
l'hôte pour toute nature qu'il invente ; une nature que personne ne sait
rendre est absente, jamais une exception.

Une entrée fermée par une exclusion est **grisée avec sa raison** : le jeton
de raison du catalogue est traduit par `ZChatMaterialToolLabels.reasonOf` —
sans traduction, l'entrée reste grisée, sans texte d'explication fabriqué.
La recherche n'apparaît que lorsque le catalogue la recommande.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatMaterialComposer` | Le composer complet assemblé — glyphes, rôles Material et bouton d'envoi. |
| `ZChatMaterialSettingsSheet` / `ZChatMaterialSettingsLabels` | La feuille de réglages riche par défaut : neuf familles habillées, remplaçables une à une ; libellés à la main de l'hôte. |
| `ZChatMaterialToolsSheet` / `ZChatMaterialToolTile` / `ZChatMaterialToolLabels` | La feuille d'outils Material : une tuile par nature, natures d'hôte par `kindBuilders`, raison de grisage traduite par `reasonOf`. |
| `zChatMaterialSendFab` | Le bouton d'envoi animé, créneau `trailing`. |
| `zChatMaterialEffortChips` | Les chips de palier de longueur de réponse, créneau `tools`. |
| `ZChatMaterialBadge` / `ZChatMaterialToolsBadge` | Le badge compteur, statique ou lié aux réglages actifs. |
| `zChatMaterialAttachmentChips` | La rangée de chips de pièces jointes en attente. |
| `zChatMaterialBudgetSlider` / `zChatMaterialUnknownEntryTile` | Le slider de budget de calcul et la tuile d'entrée inconnue, prêts à brancher sur la feuille nue. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat_material/README.md) — installation, démarrage rapide, API complète.
- [zcrud_chat](zcrud_chat.md) — le socle Flutter dont ce paquet habille le composer et les feuilles.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
