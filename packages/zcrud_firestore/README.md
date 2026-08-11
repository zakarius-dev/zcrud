# zcrud_firestore

Adaptateurs Firestore et Hive pour les ports neutres du cœur — aucun type
backend ne fuit dans une signature publique (invariant AD-5).

## Aperçu {#apercu}

`zcrud_firestore` implémente les ports déclarés par `zcrud_core`
(`ZRepository<T>`, `ZLocalStore<T>`, `ZRemoteStore<T>`) contre Firestore et
Hive. `cloud_firestore` et `hive` ne sont importés que dans ce paquet ;
toutes les signatures publiques restent `ZResult<…>` / `Stream<List<T>>`
nues — l'injection d'une instance `FirebaseFirestore` ou d'une `Box` Hive au
constructeur est la seule couture voulue vers le backend.

Ce paquet fournit :

- l'**adaptateur Firestore** [FirebaseZRepositoryImpl] — CRUD, curseur,
  soft-delete/restore, comptage, décodage défensif ;
- les **deux stores offline-first** — [HiveZLocalStore] (local, source de
  vérité) et [FirestoreZRemoteStore] (distant, fire-and-forget) — et les
  **dépôts composites** qui les fusionnent avec un merge Last-Write-Wins
  ([ZOfflineFirstRepository]/[ZOfflineFirstBoxRepository]) ;
- un **résolveur de chemins** bi-topologie et des **fabriques** prêtes à
  l'emploi pour les topologies imbriquée et utilisateur-scopée ;
- un **exécuteur de cascade** borné à 450 écritures/lot pour le soft-delete
  d'un dossier et de sa descendance ;
- des utilitaires **study** : codec de normalisation legacy, migrateur de
  corpus, fabrique d'orchestrateur de synchronisation.

**Utilisez ce paquet** dès que votre application persiste des entités
`zcrud` sur Firestore, avec ou sans cache Hive offline-first.
**N'utilisez pas ce paquet** si votre backend n'est ni Firestore ni Hive :
implémentez directement les ports `ZRepository<T>`/`ZLocalStore<T>`/
`ZRemoteStore<T>` de `zcrud_core` pour votre backend.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// `Note` est un modèle applicatif : il étend `ZEntity` (zcrud_core) et
// fournit `fromMap`/`toMap`. Le dépôt expose des ports neutres
// (`ZResult<…>` / `Stream<List<T>>`) — aucun type cloud_firestore ne fuit.
final repo = FirebaseZRepositoryImpl<Note>(
  firestore: FirebaseFirestore.instance,
  collectionPath: 'notes',
  kind: 'note', // discriminant du registre pour la (dé)sérialisation
  fromMap: Note.fromMap,
  toMap: (n) => n.toMap(),
);
```

## Concepts clés {#concepts-cles}

- **Isolation backend (invariant [AD-5](../../docs/site/concepts/invariants.md#ad-5))** —
  `Query`/`Timestamp`/`DocumentSnapshot`/`FirebaseException`/`Box`/`HiveError`
  ne quittent jamais ce paquet. Un consommateur qui n'importe pas
  `zcrud_firestore` ne tire ni `cloud_firestore` ni `hive`.
- **Offline-first, local source de vérité (invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9))** —
  [ZOfflineFirstRepository]/[ZOfflineFirstBoxRepository] composent un
  [ZLocalStore] autoritaire et un [ZRemoteStore] best-effort : une écriture
  hors-ligne réussit toujours localement (`Right`), le push distant est
  fire-and-forget, et le merge suit Last-Write-Wins sur `updatedAt`.
- **Décodage défensif (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  un document corrompu ou non décodable est écarté et loggé, jamais propagé
  en exception : une page de N documents dont un est corrompu retourne N-1
  entités.
- **Corbeille et sémantiques de suppression** — voir la section dédiée
  ci-dessous ; c'est le point d'attention le plus fréquent lors de
  l'intégration d'une collection préexistante.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `FirebaseZRepositoryImpl<T>` | Adaptateur Firestore concret de `ZRepository<T>` — CRUD, curseur, soft-delete/restore, comptage. |
| `ZDeletionSemantics` | Sémantique de lecture du drapeau `is_deleted` (`strict` / `absentMeansAlive`). |
| `ZFirestoreLog` | Callback de journalisation neutre de l'adaptateur Firestore. |
| `HiveZLocalStore<T>` | Adaptateur Hive concret de `ZLocalStore<T>` — store local, source de vérité offline-first. |
| `FirestoreZRemoteStore<T>` | Adaptateur Firestore concret de `ZRemoteStore<T>`, par composition sur `FirebaseZRepositoryImpl`. |
| `ZOfflineFirstRepository<T>` | Dépôt composite : store local + store distant + merge Last-Write-Wins, injection libre des deux stores. |
| `ZOfflineFirstBoxRepository<T>` | Variante prête à l'emploi composant directement `HiveZLocalStore` + `FirestoreZRemoteStore` pour une topologie donnée. |
| `ZFirestorePathResolver` / `ZFirestorePathRule` / `ZFirestoreTopology` | Résolveur de chemins bi-topologie (plate / imbriquée / globale) — entrée neutre, sortie `String`. |
| `buildFolderScopedStudyRepository<T>` / `buildUserScopedStudyRepository<T>` | Fabriques prêtes à l'emploi pour les topologies imbriquée et utilisateur-scopée. |
| `ZFirestoreCascadeBatcher` / `ZCascadeReport` | Exécuteur borné (≤ 450 écritures/lot) de la cascade de suppression d'un dossier et de sa descendance. |
| `ZFirestoreAppFileResolver` (et types associés) | Résolution des pièces jointes (`AppFile`) vers les alias de champs legacy. |
| `ZStudyLegacyCodec` | Normaliseur pur de `Map` : camelCase↔snake_case, mapping de statuts legacy, dates millis. |
| `ZLegacyStudyMigrator` / `ZDocumentMigrationOutcome` / `ZLegacyMigrationReport` | Migrateur de corpus legacy flat→canonique, idempotent, avec mode simulation. |
| `assembleZStudySyncOrchestrator` | Fabrique de câblage d'un `ZSyncOrchestrator` à partir d'une liste de dépôts injectée. |

## Cas limites et invariants {#cas-limites}

### Sémantiques de suppression et corbeille

Le drapeau de soft-delete `is_deleted` peut être lu selon deux sémantiques,
opt-in au constructeur de [FirebaseZRepositoryImpl] via `deletionSemantics` :

- **[ZDeletionSemantics.strict]** (défaut, comportement historique
  inchangé) — le filtre serveur `where('is_deleted', isEqualTo: false)`
  exige la présence du champ. Un document sans `is_deleted` est exclu de
  **tous** les chemins de lecture. Cette sémantique suppose une collection
  gérée **exclusivement** par zcrud (précondition « collection
  zcrud-native ») : brancher l'adaptateur sur une collection préexistante
  impose un backfill (`id` de corps + `is_deleted:false` sur chaque
  document).
- **[ZDeletionSemantics.absentMeansAlive]** (opt-in, zéro migration de
  données) — un document sans `is_deleted` est considéré **non supprimé**
  (le sens métier legacy : absent = vivant). Le coût est un filtrage
  **client** plutôt que serveur (Firestore ne sait pas exprimer
  `!= true OU absent` en une clause), donc chaque page lit aussi les
  documents supprimés avant de les écarter — acceptable tant que la
  corbeille reste marginale. `count()` perd l'agrégat serveur (décompte
  client, même raison). L'auto-réparation à l'écriture demeure : chaque
  `save` pose `is_deleted:false`, le parc converge vers `strict` au fil des
  écritures. Un paramètre `legacyDeletedKey` optionnel désigne, dans ce
  mode uniquement, une clé de soft-delete legacy supplémentaire (ex.
  `'deleted'`) traitée comme équivalente à `is_deleted`.

Dans les **deux** sémantiques, `ZDataRequest.deletedScope`
(`ZDeletedScope.aliveOnly` / `includeDeleted` / `deletedOnly`, défini dans
`zcrud_core`) est honoré sur [getAll]/[watch]/[count] de
[FirebaseZRepositoryImpl] : clauses `where` en mode `strict`, filtrage
client en mode `absentMeansAlive` (`deletedOnly` y inclut alors les
documents dont `legacyDeletedKey == true`).

### Autres cas limites

- **Le corps `id` est une précondition structurelle** — tout document écrit
  par [FirebaseZRepositoryImpl.save] porte systématiquement un champ de
  corps `id` (clé de départage du tri/curseur) ; un document sans ce champ
  disparaît silencieusement des lectures triées/paginées (sémantique
  Firestore de `orderBy`).
- **Dates ISO-8601 par défaut, `Timestamp` opt-in par champ** — le décodage
  normalise tout horodatage (`Timestamp` natif, `DateTime`,
  `{_seconds,_nanoseconds}`) en `String` ISO avant d'appeler le `fromMap`
  injecté ; un champ peut être hinté en `Timestamp` natif via l'artefact
  généré `$XxxTimestampFields` (`zcrud_generator`, `persistAs:
  ZPersistAs.timestamp`), passé au paramètre `timestampFields`.
- **Recherche accent-insensible non servie** — Firestore n'a ni `LIKE`, ni
  full-text, ni pliage diacritique natif : `ZDataRequest.search` n'est donc
  pas honoré ici (préfixe/égalité ou champ normalisé pré-calculé requis côté
  application).
- **Un `Left` distant en synchronisation offline-first est assimilé à
  « offline »** — best-effort assumé : la distinction réseau vs. erreur
  serveur (permission, quota) n'est pas encore typée séparément ; le drop
  est toujours loggé, jamais silencieux.
- **La cascade est bornée et son bornage est observable** — `deleteCascade`
  découpe `N` écritures en `ceil(N/450)` lots séquentiels, chacun committé
  atomiquement ; le nombre de lots effectivement exécutés est exposé via
  `ZCascadeReport.batchCount`. Une panne de `commit()` est remontée en
  `Left(ZServerFailure)`, jamais avalée.
- **Le codec et le migrateur legacy ne jettent jamais** — `ZStudyLegacyCodec`
  et `ZLegacyStudyMigrator` sont des normaliseurs purs et défensifs
  (invariant AD-10) : une entrée hostile ne fait jamais échouer la
  migration, elle produit un rapport auditable.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_firestore.md`](../../docs/site/paquets/zcrud_firestore.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — les ports neutres (`ZRepository`, `ZLocalStore`, `ZRemoteStore`, `ZDataRequest`, `ZSyncOrchestrator`) implémentés par ce paquet.
- `zcrud_generator` — génère l'artefact `$XxxTimestampFields` consommé par `timestampFields`.

## Licence {#licence}

MIT — voir la racine du dépôt.
