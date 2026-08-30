# Handoff v3.43.0 — le dégradé retrouve sa géométrie directionnelle

> **Date** : 2026-08-30. **Portée** : `zcrud_study`. **Traite** : CR-LEX-92 (MINEUR, invariant AD-13).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié.

## 1. Le défaut

Deux chemins divergents à quelques fichiers d'écart dans le même paquet :
`z_folder_card_chrome.dart` recomposait le dégradé avec `ZcrudTheme.gradientBegin`/`gradientEnd`,
tandis que `ZDefaultFolderCard` rendait le `ZGradientSpec` **verbatim**. Or un `LinearGradient`
sans `begin`/`end` prend `Alignment.centerLeft`/`centerRight`, **non directionnels** : le dégradé
cessait de se miroiter en RTL et les deux jetons de thème devenaient morts, sans un avertissement.
Migrer vers la carte par défaut faisait donc perdre le support RTL **en silence** — chez l'hôte,
seuls deux tests écrits pour une autre raison l'ont vu.

**Quatre autres sites verbatim** ont été trouvés au-delà de celui signalé par la CR : segment de
`ZFolderProgressBar`, pastille de `ZStudyUnitPicker`, bande et puce de type de
`ZDefaultFlashcardCard`. Tous traités du même geste.

## 2. Ce que le socle livre

Une composition **unique** (`z_gradient_geometry.dart`, interne), consommée par les cinq surfaces
et par le chrome : les jetons de géométrie sont appliqués au spec **quand celui-ci ne déclare pas
la sienne**.

**Borne de détection, mesurée et assumée** : `ZGradientSpec` ne porte que `gradient` et
`onGradient` — aucun `begin`/`end` propre, donc aucun moyen typé de distinguer « non déclaré » de
« déclaré aux défauts ». Les jetons ne s'appliquent donc qu'à un `LinearGradient` dont `begin`/`end`
valent **exactement** les défauts du constructeur Flutter ; toute autre géométrie est celle de
l'appelant et n'est jamais écrasée. Les gradients non linéaires passent verbatim. Corriger cela
vraiment demanderait des `begin`/`end` nullables sur `ZGradientSpec` — évolution additive de
`zcrud_core`, hors périmètre de ce lot.

Détail qui vaut d'être noté : les défauts sont **lus** sur un `LinearGradient` construit à vide
plutôt que nommés en dur — la garde de source AD-13 du paquet interdit d'écrire
`Alignment.centerLeft` dans `lib/`, et elle a mordu sur la première rédaction.

## 3. Ce qui change pour un hôte

- **Passif : rien** — sans jeton de géométrie posé, le rendu est **strictement identique**, prouvé
  par égalité stricte du `BoxDecoration` figée avant modification.
- **Hôte ayant contourné** : celui qui portait la géométrie directionnelle dans son propre
  `ZGradientSpec` peut la retirer si son thème pose les jetons ; s'il la garde, elle **prime**
  toujours (gardé) — son éventuel tripwire ne rougira donc pas, et c'est voulu.
- ⚠️ **Seul changement de comportement** : `ZFolderCardGradientAccent` écrasait jusqu'ici **toute**
  géométrie venue du résolveur, y compris explicite ; elle est désormais respectée. Un hôte qui
  posait des jetons **et** une géométrie explicite en comptant sur l'écrasement verra sa géométrie
  explicite l'emporter.

## 4. Vérification

`zcrud_study` : **1 892 verts** (1 887 + 5), analyze 72 infos préexistantes, 0 neuve ·
`melos run generate` 0 `.g.dart` · `analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 4 injections,
toutes rouges **par assertion** — dont celle qui reproduit exactement le symptôme mesuré par l'hôte
(`Expected AlignmentDirectional.centerStart / Actual Alignment.centerLeft`) ; restaurations par
copie, sha identiques, grep négatif · Balayage des 41 : **41/41 verts**.
