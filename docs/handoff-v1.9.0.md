# Handoff **v1.9.0** — les sous-listes deviennent des lignes de document

> **Tag à épingler : `v1.9.0`** — release **strictement additive** : rien de déclaré ⇒ rendu et
> données identiques. Paquet porteur : **`zcrud_core`**.
>
> ⚠️ Une **v2.0.0 suit de près**, avec un changement de défaut assumé (§5) : prenez celle-ci si
> vous voulez les capacités sans la rupture.

---

## 1. D'où vient cette release

La v1.8.0 avait porté les sous-listes du moteur legacy. En relisant ensuite un **cinquième** dépôt
portant le même moteur, l'intention réelle est apparue : `subItems`, ce sont **les lignes d'un
document**. Le parent agrège des totaux, les colonnes affichent des valeurs **calculées et jamais
saisies**, et le crochet CRUD est un **normalisateur métier** — il recalcule, refuse un doublon en
le disant à l'utilisateur, et met à jour une tranche voisine du formulaire.

Trois manques en découlaient, tous les trois corrigés ici.

## 2. Une colonne peut être une valeur non éditable

`ZSubListSummaryColumn` + `ZSubListConfig.summaryColumns`. Une colonne dont le `name` n'est pas un
`itemField` lit la donnée de l'item : elle **s'affiche sans devenir saisissable**. C'est exactement
« Montant HT » / « Montant TTC » — calculés par votre crochet, jamais tapés.

Porte `decimals` et un suffixe **localisable**. Non vide, `summaryColumns` remplace `summaryFields`.

**Une seule liste de colonnes, jamais deux.** Le legacy déclare un schéma de colonnes *et* un
schéma de formulaire, qu'il faut ensuite tenir d'accord à la main. Nous ne reproduisons pas cette
dérive.

## 3. Le véto peut enfin dire pourquoi

`ZSubItemCrudOutcome.veto(reasonKey:, reasonFallback:)`. Le motif est localisable, rendu par le
socle, **annoncé aux lecteurs d'écran**. Auparavant un crochet refusait en silence — votre usage
réel, lui, affiche « X existe déjà dans la liste » *avant* de refuser.

## 4. Le crochet peut maintenir l'état du parent

`parentPatch` sur `proceed`/`replace`, et `ZSubItemCrudRequest.parent` pour lire l'état parent.

**Trois arbitrages, et leurs raisons.** Le motif et le correctif passent par l'**issue**, pas par
un `BuildContext` (le crochet est `async` : un contexte capturé serait employé après un `await`,
sur un widget peut-être démonté) ni par le `ZFormController` parent (exposé, il ouvrirait la
réentrance depuis un crochet appelé en pleine mutation). Et **un véto n'applique aucun correctif** :
dans votre propre code, refuser et mettre à jour l'état voisin sont deux branches distinctes.

## 5. Impact sur votre code

- **Hôte passif** : rien à faire. Contre-témoins à **comptes absolus** de widgets — l'un d'eux
  rougit précisément quand un nœud est ajouté à tout le monde.
- Les crochets écrits pour la **v1.8.0** compilent et se comportent à l'identique (additif strict).
- La lecture d'une valeur hors sous-schéma reste **gouvernée par l'opt-in** : un `summaryFields`
  nommant une clé absente rend vide *depuis toujours* ; l'afficher d'office aurait déplacé un hôte
  passif.
- ⚠️ **À venir en v2.0.0** : le mode d'affichage par défaut passera de `inline` à `compact`, avec
  un rendu tabulaire. Mesure faite, c'est `compact` qui correspond au moteur legacy — le défaut
  actuel était le mauvais. Le retour à l'ancien tiendra en une ligne (`displayMode: inline`).

## 6. Ce que nous n'avons pas livré, et pourquoi

Le formatage **monétaire localisé** du legacy (`isCurrency`) exige un port de formatage que le
cœur n'a pas ; l'inventer dans un champ serait le mauvais endroit. `decimals` + suffixe localisable
sont livrés à la place. Le `suffixBuilder(item)` reste une closure, donc hors du domaine `const` —
le chemin passe par `itemTransformer`, documenté. L'alignement et la largeur de colonne relèvent du
rendu tabulaire, traité en v2.0.0.

## 7. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_core` **2292** tests (baseline 2279, +13), 11 `info` identiques au préexistant ·
`zcrud_screen` **308**, non touché.

Neuf injections R3, rouges **par assertion**. Trois méritent d'être citées parce qu'elles font
rougir une garde **et une seule** : le correctif parent appliqué **deux fois**
(`Expected: <1> / Actual: <2>`), la tranche du champ lui-même non protégée du correctif, et l'opt-in
contourné — une valeur hors schéma affichée sans déclaration.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
