---
title: zcrud_firestore
description: Adaptateurs Firestore et Hive offline-first pour les ports neutres du cœur zcrud.
---

# zcrud_firestore

## Rôle

`zcrud_firestore` implémente les ports du cœur (`ZRepository<T>`,
`ZLocalStore<T>`, `ZRemoteStore<T>`) contre Firestore et Hive. `cloud_firestore`
et `hive` ne sont importés que dans ce paquet (invariant
[AD-5](../concepts/invariants.md#ad-5)) : toutes les signatures publiques
restent `ZResult<…>` / `Stream<List<T>>` nues. Il fournit l'adaptateur
Firestore, les deux stores offline-first, les dépôts composites à merge
Last-Write-Wins (invariant [AD-9](../concepts/invariants.md#ad-9)), un
résolveur de chemins bi-topologie, un exécuteur de cascade borné, et des
utilitaires de migration de corpus legacy.

## Quand l'utiliser

- Persistance d'entités `zcrud` sur Firestore, avec ou sans cache Hive
  offline-first.
- Intégration d'une collection Firestore préexistante gérée par une
  application legacy : `ZDeletionSemantics.absentMeansAlive` lève la
  précondition de backfill sur le drapeau `is_deleted`.
- Suppression en cascade d'un dossier et de sa descendance, bornée et
  observable (`ZFirestoreCascadeBatcher`).

## Quand ne pas l'utiliser

- Backend ni Firestore ni Hive : implémentez directement les ports
  `ZRepository<T>`/`ZLocalStore<T>`/`ZRemoteStore<T>` de `zcrud_core` pour
  votre backend.
- Recherche plein texte ou accent-insensible **sur un gros parc** : Firestore
  n'a ni `LIKE`, ni index plein-texte, ni pliage diacritique. Les trois dépôts
  de ce paquet le **déclarent** en appliquant le mixin `ZDelegatesSearch` de
  `zcrud_core` — la barre de recherche d'un listing du socle n'est donc pas
  inerte : `ZListController` bascule sur son propre moteur (terme, portée de
  colonnes, pliage, tri) le temps d'une recherche active. Le prix est une
  **lecture non paginée** de la collection à chaque terme saisi, raisonnable
  jusqu'à quelques milliers de lignes seulement. Au-delà, la voie honnête reste
  un champ de recherche **normalisé pré-calculé** côté application,
  interrogeable par égalité ou par préfixe : le dépôt sert alors la recherche
  et n'applique pas le mixin.

## Types clés

| Type | Rôle |
|---|---|
| `FirebaseZRepositoryImpl<T>` | Adaptateur Firestore concret de `ZRepository<T>`. |
| `ZDeletionSemantics` | Sémantique de lecture du drapeau `is_deleted` (`strict` / `absentMeansAlive`). |
| `HiveZLocalStore<T>` / `FirestoreZRemoteStore<T>` | Stores offline-first local et distant. |
| `ZOfflineFirstRepository<T>` / `ZOfflineFirstBoxRepository<T>` | Dépôts composites à merge Last-Write-Wins. |
| `ZFirestorePathResolver` | Résolveur de chemins bi-topologie (plate / imbriquée / globale), entrée neutre → `String`. |
| `ZFirestoreCascadeBatcher` | Exécuteur borné (≤ 450 écritures/lot) de la cascade de suppression. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_firestore/README.md) — installation, démarrage rapide, sémantiques de suppression détaillées, API complète.
- `zcrud_core` — les ports neutres implémentés par ce paquet.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
