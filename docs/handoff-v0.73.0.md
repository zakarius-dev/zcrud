# Handoff **v0.73.0** — le stepper en accordéon Material, et un verrou que nous n'avons pas supprimé

> **Tag à épingler : `v0.73.0`** · strictement **additif** — aucune signature cassée, aucun paquet
> nouveau (38). Un hôte qui ne déclare pas le nouveau mode ne voit **rien** changer.
> 🔴 **DODLP : un geste vous attend** au § 3 — sans lui, votre sous-stepper se comportera
> **différemment du legacy**, et volontairement.

---

## 1. Le troisième mode, livré

Votre lecture était juste, et la distinction est fine : ce que vous demandez n'est **ni** le paginé
(une étape, aucun en-tête visible) **ni** le « tout affiché » de v0.66.0 (toutes les étapes
dépliées). C'est **tous les en-têtes visibles, une seule dépliée, en-têtes tapables** — l'accordéon
de `Stepper(type: vertical)`.

Vérifié avant d'écrire : le mode vertical actuel rend des **pastilles**, pas les en-têtes des autres
étapes. Votre constat est exact.

**Votre cas réel est mesuré** : racine paginée + 18 documents ⇒ la fenêtre publiée reste celle de
l'étape **active**, et **2** zones d'édition sont montées — **pas 19**. L'accordéon n'est pas un
« tout affiché » déguisé.

## 2. Trois états sans casser l'API — et deux pistes écartées après mesure

`showAllSteps` est un booléen : il ne peut pas porter trois états. La solution retenue est un champ
**additionnel et nullable** (`stepsDisplay`), avec un état effectif dérivé. **`showAllSteps` reste un
`final bool` réel** — aucune rupture.

🔵 **Deux alternatives écartées, chacune pour une raison mesurée** :
* le patron « nom en `String` » utilisé ailleurs dans le socle existe **uniquement** parce que le
  type concerné vit dans un autre paquet et qu'AD-1 interdit au cœur de l'importer. Cette contrainte
  **ne s'applique pas ici** — les enums voisines sont déjà dans ce fichier ;
* « faire de `showAllSteps` un getter dérivé » est **impossible** : le constructeur est `const`, il
  ne peut rien calculer.

**La contradiction entre les deux canaux a une règle écrite, gardée dans les trois sens** : le
nouveau champ gagne toujours. Le motif est solide — l'ancien drapeau ne sait exprimer que **deux
états sur trois** ; le faire gagner rendrait le troisième **inatteignable**. Et « le dernier écrit
gagne » n'existe pas dans un objet constant.

**Le rail est réutilisé**, pas réécrit : mêmes peintre et même rangée que le mode déplié, avec trois
arguments additifs. Une garde vérifie que les deux modes produisent le **même** nombre de peintres.

## 3. 🔴 Le verrou de validation — nous n'avons pas reproduit votre omission

Votre legacy laisse taper n'importe quel en-tête **sans validation**. Nous avons cherché pourquoi :

> `validateOnNext` n'est lu **nulle part** dans votre `dynamic_stepper.dart` — **zéro occurrence dans
> tout le fichier**. Ce n'est pas une décision de conception, c'est une **omission**.

Nous **honorons** donc `validateOnNext` dans ce mode, par la voie exacte du paginé. La raison est de
principe : sans cela, **changer la forme d'affichage supprimerait silencieusement le verrou de
validation** — un réglage de présentation ne doit pas désactiver une garantie de données.

⇒ **Votre geste** : posez `validateOnNext: false` dans votre configuration imbriquée pour retrouver
la navigation libre du legacy. C'est explicite, et c'est le but : la parité reste atteignable, mais
elle se **déclare**.

## 4. La matrice d'inertie, mise à jour

C'est la règle posée par CR-IFFD-78 — un paramètre est honoré, ou son inertie est **écrite**. Le
nouveau mode la change :

| Canal | En accordéon |
|---|---|
| `allowStepTap`, `validateOnNext` | 🔵 **redeviennent HONORÉS** (ils étaient déclarés inertes en « tout affiché ») |
| `indicatorPosition`, `orientation`, `style`, `stepSpacing`, `errorColor` | restent **inertes**, et c'est écrit au dartdoc du mode |

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans déclarer le nouveau mode, l'arbre rendu est identique (compteur, en-têtes absents, sémantique inchangée), prouvé |
| 🔴 **DODLP** | déclarez le mode accordéon sur votre configuration imbriquée, **et posez `validateOnNext: false`** si vous voulez la navigation libre du legacy |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1630** (+24) · `zcrud_study` 1521 · `zcrud_firestore` 770 · `zcrud_markdown` 516 ·
`zcrud_intl` 202 · `zcrud_select` 135 · `example` 108. **0 erreur, 0 avertissement.**
**Les 1 606 gardes préexistantes sont vertes sans une seule retouche.**

**Accessibilité et performance, mesurées et non supposées** : `ListView.builder` (gardé sur le
délégué **et** par la non-construction du 18ᵉ document), plancher de 48 dp mesuré sur la **contrainte
liante** — jamais sur la taille rendue —, marque de l'étape active **non chromatique** (graisse +
coche), état déplié/replié **annoncé**, et zéro reconstruction structurelle à la frappe.

**R3 — 13 injections, toutes rouges d'ASSERTION**, sha avant **et** après chacune, restauration par
copie, résidus : grep négatif montré.

🟢 **Une rectification d'honnêteté de l'agent sur son propre travail** : son script comptait les
rouges à partir d'un bloc de sortie **tronqué**, et sous-comptait donc. Recompté à la main sur
l'injection principale : **16** rouges, dont les deux gardes de votre cas réel. Il l'a signalé au
lieu de laisser passer un chiffre flatteur.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* Les « autres écarts de parité » de votre CR sont **chez vous** : câblage de `zcrud_markdown`
  (le renderer existe depuis v0.67.0) et seams fichier.
* La couleur d'erreur dans le rail — déclarée inerte, pas implémentée.
* Dettes antérieures : cf. v0.72.0 et les handoffs précédents.
