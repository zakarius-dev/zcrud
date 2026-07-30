# Handoff **v0.29.0** — CR-IFFD-37

> **Tag à épingler : `v0.29.0`**
> `belowSubtitle` coûte désormais **0 dp**. Vous pouvez le sortir de `counts`.

## 🔴 Impact — lisez d'abord votre ligne

| Vous êtes… | Action |
|---|---|
| **hôte passif** (`belowSubtitle == null`) | **rien** — chemin strictement inchangé, aucune golden touchée |
| **vous** (sous-titre laissé dans `counts`, contournement F2) | **déplacez-le vers `belowSubtitle`** — il tient à votre densité de 210 dp |
| **hôte ayant augmenté sa hauteur de cellule** (ex. 260 dp) pour absorber le coût | **RETIREZ cette compensation** — vos cartes seraient trop hautes d'environ 50 dp |

⚠️ **Trois widgets touchés, dont deux au-delà de la cible littérale de votre CR** : `ZFolderCard`,
`ZStudyToolsItemCard` et `ZStudyNoteCard`.

---

## 1. Vous aviez raison, y compris sur la piste à écarter

Votre seconde piste était la bonne : *« permettre au slot de participer à la contrainte de hauteur
plutôt que de s'y ajouter »*. Cause racine confirmée à la source : le bloc titre + sous-titre était une
`Column` dont **tous les enfants sont inflexibles** — sous contraintes lâches, elle prend sa hauteur
naturelle et déborde, alors que `counts` vit dans un `Expanded`, donc dans une zone déjà bornée.

Votre première piste ne pouvait effectivement pas suffire : le gap ne pèse que **8 dp** sur un coût
mesuré entre **130 et 210 dp**. Votre mesure avec `gapS` était juste.

### Coût vertical mesuré, avant et après

| Carte | sans slot | **avant** | **après** | coût du slot |
|---|---|---|---|---|
| `ZFolderCard` | 90 dp | **220 dp** (KO à 210 : *overflow 10 px*) | **90 dp** | 130 → **0** |
| `ZStudyToolsItemCard` | 70 dp | **260-300 dp** (KO à 210 : 66 px) | **70 dp** | ≈ 210 → **0** |
| `ZStudyNoteCard` | 70 dp | idem | **70 dp** | idem → **0** |

🔴 **`ZStudyToolsItemCard` était plus gravement atteinte que `ZFolderCard`** — nous ne l'avions pas
anticipé. Sa structure n'a pas de patron d'ancrage bas, mais elle portait la même colonne inflexible.
`ZStudyNoteCard` est corrigée **par le socle** : c'est un passe-plat pur depuis CR-LEX-78 — vérifié,
pas supposé, et gardé par un test.

---

## 2. Trois solutions plus simples ont été écartées, chacune sur mesure

- **Gouverner l'espacement** : 8 dp sur 130 — votre constat.
- **Rendre titre et sous-titre également flexibles** : jamais de débordement, mais `RenderFlex` ne
  redistribue pas la part inutilisée. Le titre se serait fait tronquer à 50 % de la place **même
  quand le sous-titre n'en consomme que le quart** — précisément en grille dense.
- **Sortir le gap du flexible** : mesuré, un `SizedBox` inflexible de 8 dp suffisait à déborder de
  2 px là où il restait 6 dp. D'où un `Padding` **interne** au flexible.

Retenu : en régime **borné** seulement, le titre garde la priorité (borné par `ConstrainedBox`, comme
le faisait déjà le régime sans slot) et le sous-titre devient un `Flexible` *loose* portant son propre
espacement. Plus aucun enfant inflexible ne peut excéder la contrainte — le débordement devient
**structurellement impossible**. Le régime non borné reste le chemin historique, verbatim.

---

## 3. Ce que votre CR nous apprend sur nos gardes

**Nous avons livré CR-IFFD-28 correctement, et elle était inutilisable.** Le slot respectait le contrat
des cartes sœurs, il était testé, sa sémantique était juste. Nos gardes vérifiaient présence, position
et sémantique — **jamais le coût vertical à densité contrainte**. Le défaut n'était pas dans le code,
il était dans ce que nos tests regardaient.

Votre formule le dit mieux que nous : *« le slot existe, il est correct, et il est inutilisable à notre
densité. Aucune lecture du handoff ne pouvait le dire. »*

La garde décisive reproduit désormais votre mesure : carte montée dans une cellule de **210 dp**,
absence d'exception de layout vérifiée — avec un **contrôle négatif** (la même carte sans le slot dans
une hauteur moindre), sans quoi elle ne prouverait pas que le coût vient bien du slot.

🟢 **Et votre règle a de nouveau payé.** Vous avez gardé le sous-titre dans `counts` malgré notre
handoff annonçant CR-28 livrée. Vous aviez raison : un débordement de 30 px sur chaque carte d'une
grille se voit, une impropriété de slot non. C'est la troisième fois que « ne jamais retirer un
contournement sur la foi d'un handoff » vous évite une régression — nous ne pouvons que vous
encourager à la maintenir.

---

## 4. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **780 tests** (770 + 10).

Injections R3, toutes de vrais échecs d'assertion : bloc remis en colonne inflexible ⇒
`RenderFlex overflowed by 10.0 px` sur `ZFolderCard` et **66 px** sur l'item et la façade ; titre
désancré ; chemin nouveau rendu inconditionnel ; `ExcludeSemantics` posé sur le slot.

⚠️ **Une injection n'a pas mordu, et ce n'était pas un défaut de garde** — nous le signalons parce que
la distinction compte : forcer le chemin borné en régime non borné ne produit aucune différence
observable, le repli AD-10 l'absorbant et un `Flexible` *loose* sous contrainte infinie étant un enfant
ordinaire. Il n'y avait donc **pas de régression à détecter**. L'injection a été durcie jusqu'à
produire une vraie rupture (`Expanded` + repli retiré), et la garde l'a attrapée.

Deux pièges de test neutralisés, qui pourraient vous servir : `Center` fournit un maximum **fini de
600 dp** — tester un régime non borné exige un `SingleChildScrollView`, sinon on reteste le régime
borné ; et l'`InkWell` de la carte activable **fusionne** le nœud sémantique du slot avec celui de
`counts`, d'où un matcher par motif plutôt qu'une égalité stricte.

---

## 5. Tripwire recommandé

Gardez un test qui **affirme le débordement à 210 dp**. Il rougira sur cette version et vous désignera
le contournement à retirer — plutôt que de nous croire sur parole. C'est exactement ce qui vous a servi
trois fois.
