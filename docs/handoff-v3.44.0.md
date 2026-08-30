# Handoff v3.44.0 — la grille de dossiers cesse d'être un secret, et la carte peut remplir sa cellule

> **Date** : 2026-08-30. **Portée** : `zcrud_study`. **Traite** : CR-LEX-93 et CR-LEX-94 (MINEUR).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié.

## 1. CR-LEX-93 — `ZFolderGridReference`

Les deux hôtes réécrivaient les mêmes quatre nombres de grille, et l'un d'eux écrivait le seuil
**840** en dur alors qu'il existe au socle. Les valeurs ont été **vérifiées à la source** dans le
dépôt de référence (`folders_page.dart:450` pour 300/350/840, `:648-649` pour l'espacement 8,
`:652` pour la hauteur 250) et se relisent sur six autres pages du même hôte — c'est bien une
convention, pas un cas isolé. Nuance relevée : une septième page utilise 210 pour **une autre
famille de cartes** ; `cellHeight` reste 250.

Livré : `ZFolderGridReference` (`minItemWidth` 300, `minItemWidthExpanded` 350, `cellHeight` 250,
`spacing` 8) + `minItemWidthFor(width)`, pure, qui consomme `ZWindowSizeThresholds.expandedMinWidth`.
**Aucun widget neuf** : `ZAdaptiveGrid` porte déjà `minItemWidth`/`itemHeight`/`spacing` — la CR
demandait des jetons, pas une surface de plus. L'expression d'usage tient en une ligne, elle est en
dartdoc.

⚠️ **Une garde du socle a dû être resserrée** : `z_subfolder_nav_source_guard_test` bannissait
`ZWindowSizeThresholds` **en entier** hors d'un fichier, alors qu'elle ne défend que le seuil
`mediumMinWidth` (600). Telle quelle, elle aurait obligé la grille à réécrire `840` en littéral —
exactement le défaut qu'elle combat. Motif narrowé à `mediumMinWidth`, R3 rejouée : un second site
de ce seuil la fait toujours rougir.

## 2. CR-LEX-94 — la répartition verticale, et une cause supposée qui était fausse

🔴 **Le `Spacer()` désigné par la CR n'était pas en cause** : c'est un `Spacer` **horizontal**, dans
la rangée du pied, rendu seulement en l'absence de compteurs et de pied. Le vide vient du patron
anti-débordement du régime borné. La mesure a précédé la correction.

Mesuré avant modification, cellule 300 × 250 : pastille → titre **144 dp** ; à hauteur non bornée,
**0 dp** (rien à répartir). Le changement n'est donc **pas neutre** en cellule bornée — c'est le
régime de tout hôte en grille. Livré en **opt-in** : `ZFolderCardBodyPlacement { bottom, top }` via
`bodyPlacement` (défaut `bottom` = pixel d'avant, prouvé par égalité stricte de rects **aux deux
régimes**), transmis tel quel par `ZDefaultFolderCard`. Avec `.top` en cellule de 250 : tête
solidaire (pastille → titre 0, titre → sous-titre 4), vide de 148 sous la tête, pied inchangé, et
le patron anti-débordement tient jusqu'à une cellule de 100 dp.

## 3. Ce qui change pour un hôte

- **Passif : rien** — défaut historique conservé, mesuré à hauteur libre **et** en cellule.
- **Hôte ayant contourné** : les deux peuvent retirer leurs quatre nombres de grille, et le seuil
  `840` écrit en dur. ⚠️ En revanche un contournement de **répartition verticale** ne disparaît pas
  tout seul : il faut passer `bodyPlacement: top`, sinon le vide revient.

**Limite dite** : `bodyPlacement` n'a pas d'étage `ZcrudTheme` (le canal vit dans `zcrud_core`, hors
périmètre de ce lot) — précédence paramètre > défaut, sans jeton.

## 4. Vérification

`zcrud_study` : **1 903 verts** (1 892 + 11), analyze 72 infos préexistantes, 0 neuve ·
`melos run generate` 0 `.g.dart` · `analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 9 injections,
toutes rouges **par assertion** — ⚠️ dont **deux premières versions ressorties vertes**, révélant
des gardes **inertes** : la claim a été reciblée et le test renforcé (cellule serrée, sous-titre
haut) avant de re-rougir · restaurations par copie, sha identiques, grep négatif ·
Balayage des 41 : **41/41 verts** — la garde resserrée n'a fait rougir aucun autre paquet.
