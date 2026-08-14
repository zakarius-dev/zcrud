# Handoff **v1.0.0** — le tri ne perd plus de lignes, et un dépôt peut être en lecture seule

> **Tag à épingler : `v1.0.0`** — release **groupée** : deux CR traités ensemble. Paquets
> porteurs : **`zcrud_core`**, **`zcrud_screen`**. Additive : sans déclaration, un seul
> comportement change — celui qui **perdait des lignes** (§1).

---

## 1. ⚠️ Corrigé — un listing trié sur une date facultative perdait, en silence, les éléments non datés

Sur la voie mémoire, `_runInMemory` retirait `limit` et `startAfter` de la requête, **mais pas
`sorts`**. Le tri partait donc au backend, qui le traduit en `orderBy` — et `orderBy('x')`
**exclut** tout document dépourvu du champ. Un écran triant sur une date facultative perdait
donc ses éléments non datés, sans erreur ni avertissement.

Vous décriviez l'impasse exactement : *déclarer le tri ampute la liste, ne pas le déclarer perd
l'ordre — aucune des deux n'est une migration*. Le tri n'est plus transmis à la source sur cette
voie.

**Aucun réglage `sortAtSource` n'a été ajouté, et la mesure explique pourquoi** : sur cette
voie, `zApplyListRequest` reçoit la requête d'origine — tri intact — et **ré-ordonne tout le
jeu déjà chargé**. Un tri servi par la source n'apporte donc *aucun ordre au rendu* ; son seul
effet observable restant est l'amputation, plus l'exigence d'un index composite. Un réglage dont
le seul effet mesurable est un défaut n'est pas un réglage.

**Qui était touché** : tout écran sur la voie mémoire triant sur un champ absent de certains
documents. Vous n'avez rien à faire pour retrouver vos lignes. **Si vous compensiez** — tri
abandonné, tri ré-appliqué après coup, lignes réinjectées à la main — retirez la compensation.

## 2. Une clause que seule la base sait trancher

`ZFilter.servedBySource(field, op, [value])` déclare qu'une clause part dans la requête mais
**n'est pas ré-évaluée** sur les lignes projetées. Elle règle le cas des champs **calculés,
jamais persistés** : la source sait les trancher, l'entité ne le peut pas. Et elle supprime
l'obligation de « cellule-pont » pour toute clause déjà honorée par le backend.

La règle est unique : *le socle n'évalue jamais une clause servie par la source sur les lignes*
— sautée en conjonction, retirée du OR d'une disjonction (un groupe qui n'en contient que de
celles-là devient inerte).

**Pourquoi un drapeau sur `ZFilter` plutôt qu'une liste `sourceFilters` séparée** : une liste
distincte ne serait servie par **aucun** adaptateur existant. Il aurait fallu modifier
`zcrud_firestore` et tout adaptateur tiers — et d'ici là, la clause n'aurait filtré **rien**, en
silence. C'est le défaut « la barre de recherche est un leurre » corrigé en v0.97.0, à
l'identique. Avec le drapeau, la clause reste dans `filters` et l'adaptateur Firestore la traduit
**sans un seul changement**.

🔴 **Limite assumée, dite sans détour et gardée par un test** : sur la voie `items`, une clause
`servedBySource` **n'est pas appliquée** — la liste que vous fournissez est prise telle quelle,
il n'y a pas de source à qui adresser la promesse. C'est documenté au constructeur, sur
`baseFilters`, au README et aux deux CHANGELOGs.

## 3. Une ressource qui ne s'écrit pas peut enfin passer par un dépôt

`ZCrudSource.readOnlyRepository(depot)` : lecture, pagination, tri et recherche complets, avec
`canWrite`, `supportsTrash` et `supportsPurge` **tous faux** — dépôt `ZPurgeable` compris.

Votre argument a emporté la forme retenue. Nous avons écarté un `writable: false` parce qu'un
paramètre à défaut **se lit par son absence** — ce qui reproduirait précisément le reproche de
votre CR : *« l'invariant ne tient qu'à une omission de configuration »*. Une fabrique nommée est
présente ou ne l'est pas, et `grep readOnlyRepository` énumère votre parc immuable.

L'incapacité est **structurelle** : le dépôt d'écriture est un accesseur distinct du dépôt de
lecture, et il vaut `null`. Il n'y a pas de condition qu'on puisse oublier de vérifier.

**Ce n'est pas une ACL**, et votre distinction est reprise telle quelle dans la documentation :
l'ACL gouverne **qui** peut agir, pas **ce que la ressource permet**. Un journal immuable n'est
pas « un CRUD interdit à tout le monde ».

**Impact** : hôte passif, rien à faire. Si vous subissiez la voie `items` faute de mieux,
basculez et récupérez pagination et recherche. Si vous **omettiez le `registry` exprès** pour
bloquer l'édition, rétablissez-le — la déclaration fait le travail. Et si vous aviez posé une
**ACL refusant `create`/`update`/`delete` à tout le monde**, retirez-la : elle mélangeait les
deux notions et laissait le geste offert à un administrateur.

## 4. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **2021** (baseline 2008), `zcrud_screen` **259** (baseline 244).

Le rouge initial de la garde décisive est cité tel quel :
`Expected: ['d3','d4','d1','d6','d2','d5'] / Actual: ['d3','d4','d1','d6']` — les deux éléments
non datés perdus. Huit injections R3 sur les deux lots, toutes rouges **par assertion**.

Deux points d'honnêteté que nous consignons plutôt que de les lisser :

- une injection est restée **verte** sur le lot lecture seule : les sites d'écran recâblés sont
  inatteignables une fois les capacités à `false`. Le verrou effectif tient aux accesseurs ; le
  reste est de la **défense en profondeur**, présentée comme telle et non comme couverte ;
- un contre-témoin était **déjà vert** avant correction (les écrans à périmètre requêtable
  gardent tri et pagination serveur) : il prouve la non-régression, pas le correctif.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.

---

## À propos du numéro

`v1.0.0` succède à `v0.99.0` par simple continuité de numérotation — ce n'est pas une
déclaration de stabilité d'API. Les tags restent la référence d'épinglage, et les ruptures
continueront d'être annoncées dans les handoffs comme elles l'ont été jusqu'ici.
