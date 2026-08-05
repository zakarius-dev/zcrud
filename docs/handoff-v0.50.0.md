# Handoff **v0.50.0** — CR-IFFD-68 : le pied s'empile sous les compteurs

> **Tag à épingler : `v0.50.0`** · additif, aucune rupture d'API.
> 🔴 **Un geste est requis de votre côté** : § 5 — **retirez votre `countsSlot` maison**.
> Le garder ET passer un `footer` produirait une **double pile**.

---

## 1. Votre CR est juste sur toute la ligne — et c'est la première depuis longtemps

Confirmé à la source : `counts` et `footer` étaient bien deux `Expanded` d'une même `Row`
(`z_folder_card.dart:348-357`), et **aucun réglage n'existait** (grep négatif vide). Vous aviez
aussi raison sur ce que vous **n'avez pas** demandé : le défilement des compteurs et le rendu
d'un badge étaient déjà conformes.

### 🔵 Et le coût de votre contournement n'était pas théorique — vous l'aviez déjà payé
En lisant votre dépôt (lecture seule), nous avons trouvé que votre fichier d'adoption documente
lui-même que **la première version de votre `countsSlot` rendait des badges jaune pâle sur
blanc, « proprement illisibles »**, avant que vous ne re-portiez `zReadableTintOn` à la main.

C'est exactement l'argument de votre CR, et il est mesuré : le contournement fait sortir du
plancher que `ZDefaultFolderCard` garantit. **Il n'a plus lieu d'être.**

---

## 2. 🔴 Le défaut retenu : `below` — et c'est votre piste « adaptatif » que les chiffres ont tuée

Vous suggériez un défaut **adaptatif** (empilé en étroit, côte à côte en large) en déclarant ne
pas l'avoir éprouvé. Nous l'avons éprouvé. **Le point d'équilibre existe** et vaut
`2 × rangée + gapS` — mais il est inutilisable comme défaut :

| Mesure | Valeur |
|---|---|
| rangée de compteurs (votre corpus réel) | **569 dp** |
| largeur de carte où le côte à côte rend enfin **4 badges sur 4** | **1200 dp** (≈ **740 dp** corrigé de la métrique de police réelle) |

Trois raisons de ne pas en faire le défaut :
1. **aucune cellule de grille n'approche 740 dp** ;
2. l'équilibre dépend des **libellés** — 350 dp pour des libellés courts, **> 900 dp** pour
   cinq badges verbeux : un seuil fixe ne peut pas être juste pour tout le monde ;
3. 🔴 **notre premier seuil (480) RÉINTRODUISAIT le défaut à 600 dp** — 2 badges sur 4. Nous
   l'avons mesuré, puis **rejeté notre propre solution** plutôt que de la livrer.

⇒ Défaut **`below`** (empilé). `adaptive` reste **offert**, avec son **seuil réglable**, pour
qui connaît ses libellés.

### Ce que ça donne
| à 320 dp | avant | après |
|---|---|---|
| badges visibles | **2** sur 4 | **4** sur 4 |
| fenêtre des compteurs | **146 dp** | **296 dp** |

Coût : **+18 dp** exactement en hauteur libre, **zéro** en cellule bornée.

---

## 3. Le badge « Archivé » — le point que vous ne pouviez pas mesurer

Vous le signaliez sans corpus d'archive. Tranché **par mesure** : le laisser sur la ligne des
compteurs **recrée l'amputation** — côte à côte + pied + archivé, la fenêtre tombe à
**95,8 dp** et **1 badge sur 4**. Il **suit donc la dernière ligne de la pile** : 296 dp,
4 sur 4.

`ExcludeSemantics` **préservé** : « Archivé » est annoncé **exactement une fois** (garde qui
parcourt réellement l'arbre sémantique, pas qui cherche un widget).

---

## 4. Vos deux autres « non mesuré », mesurés

* **Échelle de texte** : ×1 / ×1.5 / ×2 × {190, 210} dp × {320, 600} dp × 3 dispositions ⇒
  **zéro `RenderFlex overflowed`**. L'empilement ne casse pas ; il coûte une ligne de titre à
  ×1.5/×2 en cellule bornée, rien à ×1.
  🔵 Et il **confirme votre intuition sur l'aggravation** : à ×2 et 320 dp, le côte à côte ne
  montre **plus aucun badge entier**.
* **Plancher de contraste** : sur `#FFFF00`, les 4 badges restent peints **par la carte**,
  libellé **et** glyphe ≥ 4,5:1 contre leur propre fond, **couleur identique dans les deux
  dispositions**. C'est la raison d'être de votre CR : elle est tenue.

---

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| 🔴 **vous, IFFD** | **RETIREZ votre `countsSlot` maison** et passez `counts` + `footer` normalement. Garder les deux produirait une **double pile**. Vous récupérez du même coup le plancher de contraste sur vos badges — celui que vous aviez dû re-porter à la main. |
| **hôte passif de la primitive `ZFolderCard`** | rien — **à aucune largeur**, gardé |
| **hôte passif de `ZDefaultFolderCard`** | rien, **sauf** s'il passe `counts` **ET** `footer` : dans ce cas son pied descend sous les compteurs (c'est la correction) |
| **hôte voulant l'ancien rendu** | `footerPlacement: beside` (paramètre) ou le jeton équivalent |

🟢 **Tripwire recommandé** : un test qui affirme votre `countsSlot` maison — il rougira quand
vous le retirerez, et vous confirmera que le socle a bien pris le relais.

---

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0 + corpus de
sérialisation, 36 paquets) · `dart pub get` résolu (91 contraintes).

`zcrud_study` **1368** (+23) · `zcrud_core` **1244** (+8) · voisins inchangés : flashcard 586,
session 565, study_kernel 383, exam 79, chat_study 67 · **0 erreur, 0 avertissement**.

🟢 **Goldens verts et NON régénérés.** Le golden neutre monte la primitive **sans `footer`** —
il n'y a donc rien à empiler : c'est la preuve la plus directe que la primitive ne bouge pas.

**R3 — 10 injections, 10 ROUGE-ASSERTION**, dont : badge « Archivé » remis sur la ligne des
compteurs · `ExcludeSemantics` retiré · `zReadableTintOn` retiré · seuil adaptatif abaissé.

🟢 **Une garde VACANTE démasquée de plus** : « hauteur identique dans les 3 dispositions »
restait **verte** sous injection, parce que la ligne fantôme s'ajoutait aux trois à la fois.
Réécrite en **mesure absolue** (bas-des-compteurs → bas-de-carte = 12 dp), elle rougit.
Second piège consigné : les jetons posés via `MaterialApp.theme` passent par un `AnimatedTheme`
— deux gardes de jeton se mesuraient l'une l'autre.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 7. Ce que nous savons ne pas avoir couvert

* La conversion « police de test → police réelle » du seuil de 740 dp porte un **modèle**
  (documenté à la constante) ; les **tests**, eux, mesurent des rects réels.
* Aucune mesure sur appareil.
* Mesures faites à **4 badges** alors que votre corpus peut en porter **5** — le seuil
  d'équilibre s'en trouverait déplacé vers le haut, ce qui **renforce** le choix de `below`.
* Rappel des dettes ouvertes de v0.49.0, toujours non traitées : la **corruption LaTeX-bloc**
  de `ZMarkdownCodec` (candidat CR prioritaire), le défaut de couleur du **champ de recherche**
  sous dégradé, et les **deux gardes inertes** de `ZMindmapView`.
