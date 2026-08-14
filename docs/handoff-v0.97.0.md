# Handoff **v0.97.0** — sur la voie dépôt, la recherche filtre enfin

> **Tag à épingler : `v0.97.0`** — lève le blocage qui retenait **27 écrans** hors de la voie
> dépôt. Paquets porteurs : **`zcrud_core`**, **`zcrud_screen`**, **`zcrud_firestore`**.
> Release **additive** : aucune implémentation existante de `ZRepository` ne casse, et la voie
> `items` est strictement inchangée.

---

## 1. Ce qui était cassé

Sur `ZCrudSource.repository(...)` servi par Firestore, la barre de recherche s'affichait et
**ne filtrait rien** : un terme sans correspondance rendait **la totalité** des documents.
Votre formule était juste — une barre inerte est pire qu'une barre absente, parce que l'usager
en conclut que la liste ne contient pas ce qu'il cherche.

Et le reproche ne visait pas Firestore : l'adaptateur **documentait** honnêtement sa limite
(ni `LIKE`, ni full-text, ni pliage diacritique natif). Le défaut était que **l'assemblage
offrait la barre quand même**.

## 2. Une capacité déclarée, pas devinée

`ZRepository` peut désormais **déclarer qu'il délègue la recherche** au socle, via le mixin
**`ZDelegatesSearch`**. Quand une recherche est active sur une telle source, le contrôleur
emprunte le chemin mémoire — celui qu'il empruntait déjà en repli d'échec curseur — et
recherche, tri, filtres et pliage diacritique s'appliquent pleinement.

`FirebaseZRepositoryImpl` le déclare : sa limite n'est plus seulement documentée, elle est
**exploitable par le socle**. C'est le principe de `ZPurgeable` — vous l'aviez reconnu
vous-mêmes dans votre CR.

**Deux choix de conception qui méritent d'être explicités :**

- **Un mixin marqueur, pas un getter sur le port.** `ZRepository` est majoritairement satisfait
  par `implements` — y compris à l'intérieur du socle — et `implements` exige *tous* les
  membres, corps par défaut compris. Un getter aurait cassé ce qu'il fallait préserver. Preuve
  de non-rupture : un dépôt minimal implémentant le port **sans un mot** sur la recherche
  compile et se comporte comme avant.
- **Le sens est inversé volontairement** : on déclare la *délégation*, jamais la capacité. Un
  mixin « je sers la recherche » aurait fait basculer **par défaut tous** les dépôts existants
  vers le chemin mémoire — une régression de performance silencieuse sur l'ensemble d'un parc.

## 3. Le mode de pagination se déclare aussi

`ZListQueryPolicy.paginationMode` expose le mode depuis l'écran assemblé : un écran dont le jeu
tient en mémoire déclare `inMemory` et retrouve recherche, tri et filtres complets, sans
quitter la déclaration. C'est l'échappatoire immédiate que vous demandiez en P1.

## 4. ⚠️ Le coût, dit sans détour

Le chemin mémoire **charge tout le jeu** (`getAll` sans limite). C'est acceptable pour un écran
dont les données tiennent en mémoire, coûteux sinon. Deux garanties bornent cela :

- la bascule ne se produit **que** lorsqu'un terme de recherche est réellement actif (non vide
  après `trim`) — mesuré par assertion sur la requête émise : `limit` passe de 2 à `null`, puis
  **revient à 2** dès le terme effacé ;
- aucun plafond n'a été fabriqué. Nous n'inventons pas un mécanisme que personne n'a demandé ;
  le coût est documenté au point d'usage, à vous de choisir la voie selon la taille du jeu.

Le README de `zcrud_screen` porte un tableau des trois voies : ce qui filtre, sur quelle voie,
à quel coût.

## 5. Effets de bord traités

- **Le décorateur de corbeille perdait la capacité** : une recherche en vue corbeille serait
  redevenue un leurre. Corrigé.
- Les dépôts **offline-first** déclarent aussi la délégation — sans lecture supplémentaire,
  puisqu'ils rendent déjà le snapshot complet.

## 6. Impact sur votre code

- **Hôte passif** : **rien à faire**. Aucune implémentation de `ZRepository` ne casse ; sans
  déclaration, le comportement est exactement celui d'avant.
- **Hôte ayant compensé** : si vous aviez commencé un **champ de recherche normalisé
  pré-calculé** pour contourner (avec le backfill de l'historique que cela suppose), vous
  pouvez l'abandonner — sauf si vous le vouliez aussi pour une recherche **serveur** paginée,
  qui reste hors de portée du socle.
- **Implémenteurs d'un `ZRepository` maison** qui ne sert pas `search` : ajoutez
  `with ZDelegatesSearch<T>` pour que le socle compose avec votre limite.

## 7. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **1959** (+9), `zcrud_screen` **225** (+10), `zcrud_firestore` **810** (+5).

Cinq injections R3, toutes rouges **par assertion**. Le rouge initial de la garde décisive est
cité tel quel : `Expected: ZListNoResults / Actual: ZListReady(rows: 3)` — un terme absent
rendait bien trois lignes sur trois. Une garde s'est révélée **tautologique** à l'injection et
a été réécrite avant d'être comptée.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
