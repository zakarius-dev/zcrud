---
title: zcrud_chat_firestore
description: Dépôt Firestore des routeurs IA du chat — une fabrique sur le repository générique, un point d'accroche pour les collections legacy.
---

# zcrud_chat_firestore

## Rôle

`zcrud_chat_firestore` branche l'entité `ZChatRouter` de
[zcrud_chat_kernel](zcrud_chat_kernel.md) sur Firestore, **sans adaptateur
spécifique** : la fabrique `buildChatRouterFirestoreRepository` construit un
`ZRepository<ZChatRouter>` sur le repository Firestore générique de
[zcrud_firestore](zcrud_firestore.md) — le codec est celui du noyau, la
forme sur le fil est la forme canonique. Le paquet est un **puits du
graphe** : il dépend de `zcrud_core`, `zcrud_chat_kernel` et
`zcrud_firestore`, et aucun de ces trois ne dépend de lui
([AD-1](../concepts/invariants.md#ad-1)).

Ce qu'il apporte en propre est le **point d'accroche** dont un hôte a besoin
pour une collection qui lui préexiste : un codec legacy optionnel, la
sémantique de suppression au choix de l'hôte, et un tri **défensif** des
documents — un document étranger ou illisible est écarté et journalisé,
jamais décodé en routeur vide actif.

## Quand l'utiliser

- Pour persister le [catalogue de routeurs](../concepts/routage-par-tache.md)
  dans Firestore et le servir à `ZChatRepositoryRouteCatalogSource` — ou à
  un `ZCrudScreen<ZChatRouter>` d'administration.
- Pour brancher une **collection legacy** de configurations IA sans la
  réécrire : le codec de l'hôte traduit sa forme historique vers la forme
  canonique à la lecture, et inversement à l'écriture.

## Quand ne pas l'utiliser

- Si le catalogue vient d'un backend HTTP : `ZChatRemoteRouteCatalogSource`
  (kernel) suffit, sans Firestore.
- Pour persister autre chose que des routeurs : ce paquet ne porte que cette
  entité — les conversations et messages passent par les ports du kernel,
  implémentés par l'application.

## La recette

```dart
import 'package:zcrud_chat_firestore/zcrud_chat_firestore.dart';

final routeurs = buildChatRouterFirestoreRepository(
  firestore: FirebaseFirestore.instance,
  collectionPath: 'ai_routers',        // le nom appartient à l'hôte
  deletionSemantics: ZDeletionSemantics.absentMeansAlive, // collection legacy
  toCanonical: maFormeVersCanonique,   // optionnel — codec legacy, lecture
  toLegacy: canoniqueVersMaForme,      // optionnel — codec legacy, écriture
);
```

## Collection legacy : `absentMeansAlive` {#collection-legacy}

Sur une collection dont les documents ont été écrits **avant** l'adoption de
ce dépôt — sans `is_deleted` ni `updated_at` — déclarer
`deletionSemantics: ZDeletionSemantics.absentMeansAlive`, sinon **aucun
routeur n'est lu** : la sémantique `strict` (le défaut) exige le drapeau
`is_deleted` sur chaque document, côté serveur. Chaque `save` pose
`is_deleted: false` et `updated_at` : la collection converge vers la forme
stricte au fil des écritures, et l'hôte bascule sur `strict` une fois tous
les documents réécrits. `legacyDeletedKey` déclare, en plus, un drapeau de
suppression historique propre à l'hôte.

## Le codec legacy {#codec-legacy}

`toCanonical` reçoit la map **brute** du document (identifiant déjà injecté,
horodatages normalisés) et rend la map canonique que le noyau sait lire ;
`toLegacy` fait l'inverse à l'écriture. Les métadonnées de synchronisation
(`is_deleted`, `updated_at`) sont ajoutées **après** lui et ne passent
jamais par le codec. Un codec qui lève n'est jamais fatal
([AD-10](../concepts/invariants.md#ad-10)) : le document est écarté à la
lecture, l'écriture retombe sur la forme canonique. Sans codec, la forme
canonique est lue et écrite telle quelle.

## Types clés

| Type | Rôle |
|---|---|
| `buildChatRouterFirestoreRepository` | La fabrique : `ZRepository<ZChatRouter>` sur le repository Firestore générique, avec codec legacy et sémantique de suppression au choix. |
| `ZChatRouterMapCodec` | Transformation pure map → map, les deux sens du codec legacy. |
| `zChatRouterShapeIssue` | Le prédicat du tri défensif : pourquoi une map ne peut pas être un routeur, ou `null`. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat_firestore/README.md) — installation, démarrage rapide, API complète.
- [Routage par tâche](../concepts/routage-par-tache.md) — le catalogue que ce dépôt alimente.
- [zcrud_chat_kernel](zcrud_chat_kernel.md) — l'entité `ZChatRouter` et ses sources de catalogue.
- [zcrud_firestore](zcrud_firestore.md) — le repository générique sous-jacent.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
