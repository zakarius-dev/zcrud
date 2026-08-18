# Handoff **v2.5.0** — l'accès à la corbeille devient déclarable

> **Tag à épingler : `v2.5.0`** — release **strictement additive** : sans condition déclarée, rien
> ne change. Paquets porteurs : **`zcrud_core`** et **`zcrud_screen`**.
>
> Cette release ne répond pas à un CR neuf : elle **solde un point différé**, retrouvé par audit.

---

## 1. D'où vient cette livraison

Vos CR antérieurs au 16 août ne portent aucun marqueur de livraison — la pratique de l'encadré ✅
est récente. **22 fichiers** étaient donc dans un état indéterminé : probablement servis, mais nul
ne l'avait vérifié.

Nous les avons audités **contre le code**, un par un. Résultat : **20 livrés** avec preuve à la
ligne, **1 invérifiable** (`cr-exploration-dodlp` est un document de constats, pas une demande), et
**1 réellement ouvert** — le **P3** de `cr-perimetre-non-requetable-2026-08-14` :

> *« Conditionner la vue corbeille. Pouvoir déclarer que la corbeille n'est offerte qu'à certaines
> conditions d'ACL, sans retirer pour autant la mise à la corbeille. »*

Il avait été **sciemment différé** lors du traitement d'origine, et il y serait resté. C'est
exactement ce que l'audit cherchait.

## 2. Ce qui est livré

`ZTrashPolicy` porte une **condition d'accès** qui remplace le critère par défaut. `null` (défaut)
⇒ comportement strictement inchangé.

Le défaut `restore || clear` **reste**, avec son raisonnement : qui peut *supprimer* sans pouvoir ni
restaurer ni purger n'a rien à faire dans la corbeille. La déclaration n'existe que pour les règles
d'autorité que ce critère ne sait pas exprimer — la vôtre.

## 3. 🔴 La limite, et pourquoi elle est gardée

**La condition gouverne l'accès à la VUE, jamais les actions dedans.** Restaurer et purger restent
gouvernés par l'ACL, individuellement.

Ce n'est pas une précaution de rédaction : sans cette limite, une commodité de présentation
deviendrait un **élargissement de droits**. La propriété est donc **gardée adversairement**, et
l'injection qui l'ouvre — une condition accordante qui rendrait aussi les gestes — fait rougir la
garde : `Expected: no matching candidates / Actual: Found 1 widget`.

Concrètement : une corbeille rendue visible à un agent sans droit de restaurer ni de purger lui
montre son contenu et **aucun de ces deux gestes**.

**Défensif (AD-10)** : une condition qui **lève** ⇒ accès **refusé**, jamais accordé.
`visibleWhenEmpty` s'applique **après** la condition — une corbeille vide masquée le reste, quelle
que soit la règle déclarée.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire — contre-témoin à comptes absolus.
- **Vous** : déclarez votre condition dans `ZTrashPolicy` pour exprimer la règle de
  `cotation_role_settings`, sans toucher aux droits de mise à la corbeille.

## 5. Le reste de l'audit — ce que vous pouvez classer

Les 20 CR livrées le sont **avec preuve** (fichier:ligne, et garde nominative quand il y en a une).
Deux méritent une mention, parce qu'un relevé rapide pourrait les croire ouvertes :

- **`cr-theme-tokens-non-cables`** : deux jetons ne sont effectivement pas consommés par la
  décoration de champ, et c'est **délibéré et documenté**. Les câbler ferait basculer silencieusement
  tout hôte passif d'une teinte à une autre (mesuré `#E6E0E9` → `#FEF7FF`), et confondrait deux rôles
  distincts. Votre besoin est servi par un **jeton dédié**, créé exprès.
- **`cr-select-overflow`** : livré depuis longtemps (`isExpanded: true`), avec une garde nominative
  portant la date de votre CR.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_screen` **350** tests (base 345, +5), analyse **propre** · `zcrud_core` **2341**, 11 `info`
inchangés.

Cinq injections R3, **toutes rouges par assertion**, restaurées par copie avec sha256 identiques —
et le périmètre git le confirme : aucun fichier muté ne subsiste comme modifié.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
