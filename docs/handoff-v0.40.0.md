# Handoff **v0.40.0** — CR-IFFD-44 : placer l'ajout, encadrer la barre

> **Tag à épingler : `v0.40.0`** · additif, aucune rupture d'API.
> Les deux défauts sont **conservés à l'identique** — un hôte passif ne bouge pas d'une ligne.

---

## 1. Les deux capacités, et où elles vivent

| Capacité | Emplacement | Défaut |
|---|---|---|
| **`ZSubfolderAddPlacement`** `{ barAndSheet, sheetOnly, barOnly }` | **la spec** (`ZSubfolderNavSpec.addPlacement`) | `barAndSheet` |
| **`subfolderBarPadding`** (`EdgeInsetsGeometry?`) | **le thème** (`ZcrudTheme`) | `null` ⇒ aucune enveloppe |

**Pour la marge, votre argument a été repris tel quel** : les quatre réglages voisins sont déjà des
jetons de thème, et une marge est une décision d'apparence qui n'a rien à faire dans les données de
fratrie.

**Pour le placement, vous ne tranchiez pas — voici pourquoi c'est la spec**, du plus fort au plus faible :

1. le jeton décide de la **présence d'un contrôle interactif** dans l'arbre. Faire dépendre
   l'atteignabilité d'une action d'un thème ferait de l'accessibilité une **conséquence du thème** —
   or un thème doit pouvoir être remplacé sans qu'une action disparaisse. C'est le critère qui avait
   déjà placé `ZSubfolderNavPlacement` hors du thème en `v0.38.0` ;
2. il gouverne le rendu de `addAction`/`addLabel`/`addIcon`, qui vivent **déjà** dans la spec — le
   séparer couperait la capacité en deux canaux d'injection ;
3. un thème est **ambiant** : posé à la racine, il vaudrait pour toutes les fratries de l'application,
   alors que le placement de l'ajout est une décision **par descripteur**.

⚠️ **Le jeton est sans effet hors de la barre de sélection.** La rangée de puces et la sidebar n'ont
pas de feuille : y appliquer `sheetOnly` **retirerait une action sans remplaçante**. Refusé par
construction, et gardé.

## 2. 🔴 L'arbitrage que vous nous laissiez : **dénoncer, pas borner** — mesuré

Vous n'aviez pas mesuré l'effet d'une marge sur la cible tactile. Voici les chiffres :

| écran | marge / côté | déclencheur rendu |
|---|---|---|
| 320 dp | 0 / 24 / 48 | 272 / 224 / 176 **× 48** |
| 320 dp | 96 / **112** / 130 | 80 / **48** / **12** × 48 |
| 400 dp | 0 / 24 / 130 | 352 / 304 / 92 × 48 |

Trois faits : **la hauteur ne bouge jamais** (48 dp, tenue par la contrainte) ; **le `+` ne rétrécit
pas** (48 dp intrinsèques) — c'est le déclencheur qui absorbe **tout** le retrait ; et la rupture
n'arrive qu'au-delà de **112 dp par côté à 320 dp**, soit **70 % de l'écran en marge**.

**Décision : dénoncer en debug**, pas borner.

* **Borner** ferait rendre au socle **autre chose que la marge demandée, en silence** — c'est-à-dire
  le grief même que votre CR corrige.
* **Ne rien faire** serait tenable si le cas était inatteignable. Il ne l'est pas : **12 dp mesurés**.

La garde est **bornée par le haut** : sous une marge déraisonnable, elle assère que le déclencheur
fait **réellement 40 dp** — donc que rien n'a été corrigé en douce.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — les deux défauts conservent le rendu actuel |
| **vous, IFFD** | `addPlacement: ZSubfolderAddPlacement.sheetOnly` (ou `barOnly`), et `subfolderBarPadding` dans votre thème |
| 🔴 **hôte ayant COMPENSÉ** | **retirez votre compensation** : si vous enveloppiez la bande dans votre propre `Padding` pour obtenir la marge, elle **s'additionnera** au jeton |

🟢 **Tripwire recommandé** : si vous compensiez la marge, gardez un test qui **affirme la valeur que
vous obteniez**. Il rougira à l'adoption et vous désignera le doublon.

## 4. 🔴 Un défaut PRÉEXISTANT découvert en mesurant — et que nous n'avons pas corrigé

Le contenu d'élément par défaut est une rangée dont **le libellé ne s'ellipse pas**. À 320 dp avec un
libellé long, **il déborde déjà sans aucune marge** — et 16 dp par côté suffisent à le déclencher.

Nous n'y avons **pas** touché : la correction naturelle lèverait une exception côté rangée de puces,
dont la largeur n'est pas bornée. Nos gardes contournent le bruit avec un libellé court — **c'est une
atténuation de test, pas un correctif**.

⚠️ **C'est un candidat CR à part entière, et il vous concerne** : si vos titres de sous-dossier sont
longs, vous verrez le débordement avant même de poser une marge.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **920** (+24) · `zcrud_core` **1159** (+8) · **0 error, 0 warning**.

**9 injections R3**, toutes rouges d'assertion.

🟢 **Quatre gardes retendues**, dont une qui vous intéresse : *« `sheetOnly` ⇒ le `+` est absent »*
était verte sur une simple clé manquante — **un socle qui rendrait le bouton transparent au lieu de
le retirer serait resté vert**. Elle est doublée d'une mesure géométrique.

🔵 Et une **garde structurelle nouvelle** : un jeton de thème oublié dans `copyWith` ou `lerp`
**compile sans erreur** et ne se voit qu'à la transition de thème suivante. Elle scanne les 54 champs,
**refuse d'être inerte**, et porte sa contre-preuve.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 6. Ce que nous savons ne pas avoir couvert

* Le **débordement de libellé** du § 4 — préexistant, non corrigé, candidat CR.
* **Marge verticale sous un parent à hauteur bornée** : la dénonciation mesure bien les deux axes,
  mais aucun test ne place ce scénario.
* La dénonciation ne surveille **que le déclencheur** et **que sous marge posée** : un parent
  anormalement étroit sans marge reste silencieux, comme avant.
* **`addPlacement` n'est pas relayé aux coquilles d'hôte** : une surface entièrement remplacée lit la
  spec et décide seule — non gardé.
* **Aucun golden** : tout est mesuré en géométrie et en présence d'arbre, jamais en pixels.
