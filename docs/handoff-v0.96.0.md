# Handoff **v0.96.0** — la fiche de détail redevient consultable en corbeille

> **Tag à épingler : `v0.96.0`** — corrige une **régression fonctionnelle** présente en
> production depuis votre bascule, sur les 32 écrans du parc migré. Paquet porteur :
> **`zcrud_screen`** uniquement. Release **strictement additive** pour la vue vivante.

---

## 1. Ce qui était cassé

En vue corbeille, une ligne n'offrait que **restaurer** et **supprimer définitivement**.
Aucune action de consultation — donc aucun moyen de regarder ce qu'on s'apprête à restaurer
ou à détruire.

Votre argument emporte la décision, et il est vérifiable dans le moteur que vous remplacez :
celui-ci conditionne ses actions d'**écriture** à `!trashOnly`, mais **pas** la consultation.
L'asymétrie est délibérée — *écrire* sur un élément supprimé n'a pas de sens, *le lire* en a,
et c'est même là qu'on en a le plus besoin. La purge est irréversible ; la consultation est la
vérification qui la précède.

Votre analyse du contournement impossible était juste, et nous l'avons confirmée :
`openDetails` commençait par `if (!canOpenDetails(entity)) return;`, et `canOpenDetails`
dépendait de `!_trashView`. Une action ajoutée via `trashRowActions` aurait été un **bouton
mort échouant en silence**. Le point de décision était bien à l'intérieur du paquet.

## 2. Ce qui change

L'action **détails** est offerte en vue corbeille, **à la même place, sous la même
gouvernance** qu'en vue vivante : `detailsEnabled` activé et `ZCrudAction.view` accordée sur
la ligne. Un site unique de construction sert désormais les deux vues — même identifiant, même
icône, même position.

`zCrudDetailsOpener` / `detailsOpener` / `openDetails` ne rendent plus un geste inerte en
corbeille : `trashRowActions` n'est donc plus condamné au bouton mort si vous voulez composer
autre chose autour.

**La fiche ouverte depuis la corbeille est strictement en lecture** : aucun bouton
« Modifier », **même pour un usager muni de `update`**. Cela n'a demandé aucun code —
l'édition et la consultation se décidaient déjà séparément, et il suffisait de ne pas toucher
à la condition de l'édition.

**Aucun élargissement au passage** : `edit`, `duplicate`, `softDelete` et la création restent
absents de la corbeille. La vue vivante est inchangée.

## 3. Impact sur votre code

- **Hôte passif** : **rien à faire** — l'action apparaît, gouvernée par l'ACL que vous
  déclarez déjà.
- **Hôte ayant compensé** : si vous aviez posé une action de consultation maison en
  `trashRowActions`, ou si votre coquille en offrait une, **retirez-la** — vous auriez deux
  gestes de consultation sur la même ligne.

## 4. Une note sur la robustesse de la vérification

Une des gardes s'est révélée piégeuse et mérite d'être signalée, parce qu'elle vous concerne
si vous écrivez la vôtre : refuser `view` **au niveau de la collection** vide l'écran entier —
la garde aurait alors été verte pour la mauvaise raison. Il faut refuser `view` sur une
**cible** précise pour éprouver réellement le filtrage par ligne.

Trois dartdocs publics affirmaient l'ancien comportement (`canOpenDetails`, `canOpenEdition`,
`zCrudDetailsOpener`) : corrigées. Et l'asymétrie « on lit, on n'écrit pas » est désormais
écrite au point de décision, avec l'interdiction explicite de réintroduire la condition —
pour qu'elle ne soit pas reprise un jour pour un oubli.

## 5. État des vérifications

`zcrud_screen` : analyze RC=0 strict, **215 tests** (baseline 208, +7), **aucun test
préexistant modifié**. Cinq injections R3, toutes rouges **par assertion** ; restaurations par
copie vérifiées par sha256 ; résidus prouvés absents par grep négatif. Les autres paquets ont
un diff vide.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
