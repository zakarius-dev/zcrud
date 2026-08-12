---
title: "Offline-first : store local, sync différée, LWW"
description: Comment zcrud compose un store local autoritaire et un distant fire-and-forget, avec merge Last-Write-Wins et voie SRS séparée.
sidebar_position: 7
---

# Offline-first

zcrud implémente l'offline-first comme un **patron de composition**, pas comme une
fonctionnalité d'un backend précis : deux ports neutres (`ZLocalStore`/`ZRemoteStore`,
`zcrud_core`), un dépôt qui les compose (`ZOfflineFirstRepository`, `zcrud_firestore`)
et un orchestrateur qui décide *quand* déclencher la sync (`ZSyncOrchestrator`,
`zcrud_core`). C'est l'application concrète de [l'invariant AD-9](invariants.md#ad-9) :
store local **source de vérité**, distant **fire-and-forget**, merge **Last-Write-Wins**
sur `updatedAt`, suppression en **soft-delete**.

## Les deux ports neutres

`zcrud_core` définit deux contrats abstraits, tous deux backend-agnostiques
([AD-5](invariants.md#ad-5)) — aucune signature n'expose `Box` (Hive) ni
`FirebaseFirestore`/`Timestamp` :

| Port | Rôle | Fait autorité ? |
|---|---|---|
| `ZLocalStore<T>` | cache local | **oui** — les lectures ne touchent jamais le distant |
| `ZRemoteStore<T>` | backend distant | non — best-effort, jamais bloquant |

`ZLocalStore<T>` expose `watchAll`/`getAll`/`getById` (lectures qui excluent les
soft-deleted), `put`/`putMerged` (écritures — `put` **écrase** le document, `putMerged`
**préserve** les clés absentes de l'entité écrite), `softDelete`/`restore` (le
soft-delete métier), `syncEntries` (lecture de synchronisation, tombstones **inclus**)
et `applyMerged` (écriture qui **préserve la méta** — jamais de ré-estampillage
`now()`, réservée à l'application d'un résultat de merge). `purge` existe aussi, mais
pour un usage **distinct** : annuler une écriture strictement locale sans laisser de
tombstone — jamais une voie de suppression utilisateur (cf. [Cas limites](#cas-limites)).

`ZRemoteStore<T>` est le miroir best-effort : `push`/`remoteDelete`/`pull`/`watchAll`
côté utilisateur, `syncEntries`/`applyMerged`/`applyMergedAll` côté sync. La
propagation par lot (`applyMergedAll`) est **bornée** — la limite (≤ 450 écritures,
sûre sous le plafond Firestore de 500) est un détail d'adaptateur et ne vit **jamais**
dans ce port neutre.

## Le dépôt qui compose : local d'abord, distant en fire-and-forget

Le sur-port `ZSyncableRepository<T>` (`zcrud_core`) ajoute une seule méthode,
`sync()`, à un `ZRepository<T>` classique. `ZOfflineFirstRepository<T>`
(`zcrud_firestore`) l'implémente en **composant** un `ZLocalStore<T>` et un
`ZRemoteStore<T>` injectés — jamais de sous-classement de `HiveZLocalStore` ou
`FirestoreZRemoteStore` :

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class InventoryItem implements ZEntity {
  const InventoryItem({required this.itemId, required this.label});

  @override
  String? get id => itemId;

  final String itemId;
  final String label;

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
        itemId: map['id'] as String,
        label: map['label'] as String,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{'id': itemId, 'label': label};
}

Future<ZOfflineFirstRepository<InventoryItem>> buildInventoryRepository(
  ZRemoteStore<InventoryItem> remote,
) async {
  final local = await HiveZLocalStore.openBox<InventoryItem>(
    kind: 'inventoryItem',
    fromMap: InventoryItem.fromMap,
    toMap: (item) => item.toMap(),
  );
  return ZOfflineFirstRepository<InventoryItem>(local: local, remote: remote);
}
```

Une fois composé, le dépôt lit **exclusivement** le local (`watchAll`/`getAll`/
`getById` délèguent tous à `ZLocalStore`, jamais au distant) et écrit **local
d'abord** : la mutation renvoie dès que le local a réussi, puis se propage au
distant en fire-and-forget — un échec distant est loggé et n'invalide **jamais**
un succès local déjà rendu à l'appelant.

## Le merge Last-Write-Wins

`ZLwwResolver` (`zcrud_core`) est une fonction **pure** — aucune I/O, aucune horloge
lue — qui décide, pour un `id` donné, quel côté doit gagner :

- présent seulement en local → pousser vers le distant ;
- présent seulement en distant → adopter dans le local ;
- présent des deux côtés → le plus récent `updatedAt` gagne (`null` est **toujours**
  le plus ancien) ;
- égalité stricte de `updatedAt` (y compris deux `null`) → **le local fait foi** :
  aucune écriture si les états sont déjà identiques, sinon le local réaligne le
  distant.

Ce merge s'applique aussi aux tombstones : un `ZSyncEntry` porte l'entité **et**
son état de soft-delete, donc une suppression se propage exactement comme une
mise à jour.

## Soft-delete et métadonnées hors-entité

Les métadonnées de synchronisation — l'horodatage de merge et le drapeau de
suppression — ne vivent **jamais** dans le corps métier de l'entité. Elles sont
portées par `ZSyncMeta` (`zcrud_core`), persistées en clés **réservées**
snake_case :

| Clé persistée | Rôle |
|---|---|
| `updated_at` | horodatage Last-Write-Wins (ISO-8601, jamais un `Timestamp`) |
| `is_deleted` | drapeau de soft-delete — jamais de purge physique par défaut |

`ZSyncMeta.reservedKeys` est la **définition machine** de ces deux clés : une
entité ne les redéclare jamais dans son propre `toMap`. Si votre modèle porte
malgré tout un champ nommé `updated_at`/`is_deleted` (collision plausible avec un
« dernière modification » applicatif), `ZSyncMeta.collidingReservedKeys` vous
permet de le détecter **avant** l'écriture plutôt que de découvrir la perte en
production.

## Le quand : `ZSyncOrchestrator`

`ZOfflineFirstRepository.sync()` est un appel **one-shot** — le *comment*. Le
*quand* est séparé dans `ZSyncOrchestrator` (`zcrud_core`, Dart pur, aucun import
Flutter ni backend) :

```dart
import 'package:zcrud_core/zcrud_core.dart';

void wireSync(List<ZSyncableRepository<dynamic>> repositories) {
  final orchestrator = ZSyncOrchestrator()..registerAll(repositories);

  // Câblé par l'app sur ses vraies sources login/réseau.
  orchestrator.onLogin();
  orchestrator.onReconnected();
}
```

- `register`/`registerAll` alimentent un registre **par identité** — un même
  dépôt enregistré deux fois n'est synchronisé qu'une fois.
- `onLogin`/`onReconnected` planifient un cycle **débouncé** (400 ms par défaut,
  `kZSyncDefaultDebounce`) : plusieurs déclencheurs dans la fenêtre **coalescent**
  en un seul cycle.
- Chaque cycle est **best-effort tolérant à l'échec partiel** : l'échec d'un
  dépôt est compté et loggé dans le `ZSyncRunReport`, la boucle continue sur les
  autres.
- La couture `isConnected` (optionnelle) fait sauter un cycle proprement plutôt
  que d'échouer ; `enabled` est une porte d'activation globale.
- L'orchestrateur **ne possède pas** les dépôts enregistrés : `dispose()` vide le
  registre mais ne les libère pas — leur cycle de vie reste à la charge de l'app.

`zcrud_firestore` fournit `assembleZStudySyncOrchestrator` comme fabrique de
confort : elle construit un `ZSyncOrchestrator` puis lui enregistre (via
`registerAll`) la **liste injectée** de dépôts que vous lui passez — jamais un
import ou une liste codés en dur dans le paquet.

## État SRS séparé, voie d'écriture unique

Un cas particulier de l'offline-first illustre bien la règle « séparation stricte
des responsabilités » : l'état de répétition espacée (SRS) d'une flashcard n'est
**jamais** un champ de la carte elle-même. `zcrud_flashcard` le persiste dans un
canal séparé, `ZRepetitionStore`, adressé par `flashcardId` — dupliquer ou
partager une carte n'emporte donc jamais l'historique de révision qui va avec.

`ZFlashcardRepository` (`zcrud_flashcard`) compose un `ZSyncableRepository<ZFlashcard>`
(le port carte, offline-first standard) et un `ZRepetitionStore` (le canal SRS) :

```dart
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

Future<void> submitReview(
  ZFlashcardRepository repository,
  String flashcardId,
  String folderId,
  int quality,
) async {
  final result = await repository.reviewCard(
    flashcardId: flashcardId,
    folderId: folderId,
    quality: quality,
  );
  result.fold(
    (failure) => throw StateError('Révision refusée : ${failure.message}'),
    (info) => info, // ZRepetitionInfo mis à jour, déjà persisté.
  );
}
```

`reviewCard` est la **seule** méthode publique qui fait progresser un état SRS —
elle délègue exactement à `scheduler.apply` (par défaut `ZSm2Scheduler`,
l'algorithme SuperMemo-2). `initRepetition`/`resetRepetition` sont les deux
seules autres écritures SRS autorisées, et elles n'appellent **jamais**
`scheduler.apply` : `initRepetition` crée un état neuf via `scheduler.initial`
uniquement s'il est absent (idempotent — un double-appel ne détruit pas
l'historique), `resetRepetition` réinitialise **inconditionnellement**. Aucune
de ces trois méthodes ne touche jamais le port carte : la carte et son SRS
progressent par deux voies d'écriture strictement disjointes.

Le planificateur lui-même est **remplaçable** : `ZSrsScheduler` est une
interface pure et sans état (`apply`/`simulate`/`initial`), jamais scellée —
brancher un autre algorithme ne change ni `ZRepetitionInfo` ni
`ZFlashcardRepository`.

## Cas limites et invariants {#cas-limites}

- **Déconnecté n'est jamais une erreur.** Un `sync()` qui ne peut pas joindre le
  distant (couture `isConnected` à `false`, ou échec distant classé
  best-effort) renvoie `Right(unit)` — jamais un `Left`. Seule une panne
  **locale** (`ZCacheFailure`) est une vraie erreur propagée.
- **`purge` ne propage rien.** Cette primitive retire une entrée du cache local
  **sans** tombstone — utile pour annuler une écriture qui n'a jamais atteint le
  distant. L'utiliser sur une suppression déjà propagée fait **ressusciter** le
  document ailleurs au prochain cycle : la voie de suppression utilisateur reste
  `softDelete`.
- **`applyMerged` ne réestampille jamais `now()`.** C'est ce qui distingue une
  écriture de merge (méta préservée telle quelle) d'une mutation utilisateur
  (`put` réestampille toujours) — les confondre romprait le LWW en ping-pong.
- **`ZSyncOrchestrator` est pur-Dart.** Aucun import Flutter, aucun gestionnaire
  d'état, aucun type backend — il reste utilisable hors d'un `BuildContext` et
  testable sans horloge murale (`timerFactory` injectable).

## Voir aussi

- [Invariant AD-9](invariants.md#ad-9) — la définition canonique de la règle.
- [Invariant AD-5](invariants.md#ad-5) — domaine backend-agnostique.
- [Invariant AD-11](invariants.md#ad-11) — `Either`/`Stream` nus sur les contrats.
- [Catalogue des paquets](../paquets/index.md) — fiches `zcrud_firestore`, `zcrud_flashcard`.
