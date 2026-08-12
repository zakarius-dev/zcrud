---
title: zcrud_chat_material
description: Skin Material pixel-perfect pour le composer du chat zcrud, satellite opt-in sans dépendance tierce.
---

# zcrud_chat_material

## Rôle

`zcrud_chat_material` est le paquet **satellite** qui habille en Material
Design le composer chromatiquement nu de `zcrud_chat` : bouton d'envoi
animé, chips d'effort, badges de compteur, chips de pièces jointes, slider
de budget de calcul. Chaque widget se branche sur un créneau que le socle
expose déjà — ce paquet ne construit ni composer ni feuille de réglages
parallèles, et n'ajoute aucune dépendance tierce (le Material vient du SDK
Flutter lui-même).

## Quand l'utiliser

- Pour obtenir un composer de chat entièrement stylé Material sans écrire
  soi-même les rôles `ColorScheme`, les glyphes et les dimensions conformes
  à l'accessibilité.
- Pour ne monter qu'une seule pièce (le bouton d'envoi, par exemple) sur un
  composer par ailleurs composé à la main.

## Quand ne pas l'utiliser

- Si votre application suit un autre design system (Cupertino, thème
  maison) : composez directement sur les créneaux nus de `zcrud_chat`.
- Pour du rendu Markdown/LaTeX ou une coquille Syncfusion : ce sont les
  rôles des satellites `zcrud_chat_markdown` et `zcrud_chat_syncfusion`.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatMaterialComposer` | Le composer complet assemblé — glyphes, rôles Material et bouton d'envoi. |
| `zChatMaterialSendFab` | Le bouton d'envoi animé, créneau `trailing`. |
| `zChatMaterialEffortChips` | Les chips de palier de longueur de réponse, créneau `tools`. |
| `ZChatMaterialBadge` / `ZChatMaterialToolsBadge` | Le badge compteur, statique ou lié aux réglages actifs. |
| `zChatMaterialAttachmentChips` | La rangée de chips de pièces jointes en attente. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat_material/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — le socle Flutter dont ce paquet habille le composer.
