# Handoff **v2.0.0** — les sous-listes s'affichent en table, par défaut

> **Tag à épingler : `v2.0.0`** — 🔴 **rupture visuelle assumée** sur tout champ `subItems` non
> déclaré. Paquet porteur : **`zcrud_core`**.
>
> **Retour arrière en une ligne : `displayMode: ZSubListDisplayMode.inline`.**
> Si vous voulez les capacités « lignes de document » sans la rupture, restez en **v1.9.0**.

---

## 1. Pourquoi le défaut change

Mesuré dans le moteur legacy, la ligne qui tranche :

```dart
child: widget.itemBuilder?.call(item) ?? Container(),
```

**Sans `itemBuilder`, un item legacy s'affiche vide**, et l'édition passe par une fenêtre ouverte
au seul appui long. Le mode legacy est donc **`compact`** — résumé + fenêtre. Le mode `inline`
(sous-formulaires imbriqués à champs vivants) est un mode **natif zcrud, sans contrepartie
legacy**.

Le défaut historique était donc le mauvais pour un hôte qui migre : il livrait, sans déclaration,
une forme que le moteur remplacé n'avait jamais eue.

## 2. Ce qui change

**Trois défauts inversés** : `displayMode` → `compact`, `showSummaryHeaders` → `true`, **et le
repli du widget quand la config est absente** → `compact`. Ce troisième n'était pas demandé mais il
est décisif : le générateur `@ZcrudModel` émet un champ `subItems` **sans config** pour un
sous-modèle. Le laisser sur `inline` aurait fait coexister deux défauts contradictoires — et le
second vise précisément l'hôte qui n'a **rien** déclaré.

**Le rendu tabulaire** : une **seule** `Table` porte l'en-tête et les lignes. L'en-tête ne
*reproduit* donc plus la géométrie des cellules — **c'est la même colonne**, il ne peut plus se
désaligner. Les largeurs **suivent le contenu**, là où le rendu précédent imposait des colonnes
égales puis tronquait. Les valeurs numériques sont cadrées en **fin** — une colonne de montants qui
ne s'aligne pas ne se lit pas.

Aucune dépendance nouvelle : primitives Material seules, aucun `pubspec` touché.

## 3. Ce qui NE change pas

- **Le repli responsive de la v1.4.1 est intact** — même formule, même seuil dérivé. Sous le seuil,
  aucune table n'est construite : la ligne s'empile en couples libellé/valeur. C'était le risque
  principal de ce lot, et il est gardé.
- `showSummaryHeaders: false` rend le résumé défilant historique **au byte près**. Aucune de vos
  déclarations existantes ne change de sens ; **seul le défaut** est inversé.
- Les seams des v1.8.0/v1.9.0 gardent leur applicabilité. **La table cède, jamais le seam.**

## 4. ⚠️ Impact sur votre code

| Votre situation | Effet |
|---|---|
| Vous déclarez `displayMode` | **inchangé** |
| Vous ne déclarez rien | table + fenêtre d'édition — c'est le but |
| Vous êtes en `compact` sans `showSummaryHeaders` | table ; retour exact par `showSummaryHeaders: false` |
| 🔴 **Vous avez compensé** par un seam `itemBuilder`/`listViewBuilder` | **votre compensation tient et empêche la table native** |

Le dernier cas est le seul qui exige une action : votre seam continue de gouverner le rendu, donc
vous ne verrez **pas** la table tant que vous ne l'aurez pas retiré. C'est cohérent — la table cède
au seam — mais cela veut dire qu'un hôte ayant contourné l'ancien rendu ne bénéficie de rien tant
qu'il n'a pas défait son contournement.

## 5. Un seuil, dit explicitement

`ZSubListFieldWidget.summaryTableRowBudget = 60`. Au-delà, le rendu retombe sur une liste construite
à la demande : une table ne virtualise pas. Le seuil est **asserté des deux côtés** et
volontairement **non réglable** — un seuil négociable ne s'asserte plus.

La frontière **AD-8** est écrite en dartdoc : tri, pagination et virtualisation restent au moteur de
liste ; rendre quelques lignes embarquées dans un formulaire est une mise en page. Le budget est la
conséquence assumée de ce refus.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_core` **2307** tests (baseline 2292, +15), 11 `info` identiques · `zcrud_screen` **308** ·
`example` 108.

**Gardes jumelles cherchées et montrées** : `grep` sur `displayMode` / `ZSubListDisplayMode` /
`subItems` dans les tests de **tous** les paquets — six occurrences hors du cœur, aucune portant sur
le défaut. `zcrud_document` (235) et `zcrud_flashcard` (586) rejoués verts.

Vingt injections R3, rouges **par assertion**. Deux faits méritent d'être connus :

🔴 **Une garde d'un CR précédent avait cessé de mordre.** Privée de son repli, une `Table` ne
tronque pas — elle **déborde** (697 dp sur un écran de 360), et le texte reste entier. L'assertion
de troncature restait donc **verte en laissant l'écran illisible** : le mode de défaillance avait
changé, pas le défaut. Une seconde assertion a été ajoutée — la valeur tient dans l'écran — et elle
rougit : `Expected: ≤ <360.5> / Actual: <697.25>`.

Et une autre garde **assertait explicitement des colonnes de largeur égale** — c'est-à-dire la
formulation même du défaut que cette version corrige. Elle a été réécrite pour établir ce qui
compte vraiment (chaque cellule tombe exactement sous son en-tête, les largeurs suivent le contenu)
et prouvée mordante à nouveau.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
