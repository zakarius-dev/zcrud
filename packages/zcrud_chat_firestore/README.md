# zcrud_chat_firestore

Adaptateurs Firestore du catalogue de routeurs IA du chat — satellite opt-in,
puits du graphe (invariant AD-1).

## Aperçu {#apercu}

Ce paquet ne redéclare aucun symbole existant. L'entité `ZChatRouter`, son
codec et son schéma d'édition vivent dans `zcrud_chat_kernel` ; le repository
Firestore générique (`FirebaseZRepositoryImpl`), le décodage défensif, le
soft-delete et les sémantiques de suppression vivent dans `zcrud_firestore`.
Le générique sert l'entité **sans adaptateur spécifique**.

`zcrud_chat_firestore` fournit uniquement le **point d'accroche** :

- `buildChatRouterFirestoreRepository` — la fabrique qui branche le dépôt sur
  une collection, sous le `kind` du routeur ;
- l'accroche d'un **codec legacy** (`toCanonical` / `toLegacy`) pour une
  collection qui préexiste au dépôt — la casse, les renommages et les
  regroupements propres à l'hôte restent chez l'hôte ;
- la **sémantique de suppression** choisie par l'hôte ;
- un tri défensif des documents (`zChatRouterShapeIssue`).

`zcrud_firestore` ne dépend jamais de `zcrud_chat*` : un consommateur
Firestore sans chat n'en porte pas le poids. Symétriquement, le noyau du chat
ne connaît pas Firestore.

**Utilisez ce paquet** si vos routeurs IA sont persistés dans Firestore.

**N'utilisez pas ce paquet** si votre catalogue de routeurs est servi par un
endpoint applicatif : implémentez `ZChatRouteCatalogPort` sur ce transport,
sans tirer Firestore.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

Collection **née avec le dépôt** (chaque document porte `is_deleted`) :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zcrud_chat_firestore/zcrud_chat_firestore.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

final ZRepository<ZChatRouter> routers = buildChatRouterFirestoreRepository(
  firestore: FirebaseFirestore.instance,
  collectionPath: appConfig.routersCollection,
);
```

Collection **préexistante** (documents écrits avant le dépôt, en camelCase,
sans `is_deleted` ni `updated_at`) — l'hôte apporte son codec, en 6 lignes :

```dart
final ZRepository<ZChatRouter> routers = buildChatRouterFirestoreRepository(
  firestore: FirebaseFirestore.instance,
  collectionPath: appConfig.routersCollection,
  deletionSemantics: ZDeletionSemantics.absentMeansAlive, // sinon : 0 lu
  toCanonical: myRouterCodec.toCanonical, // camelCase → routes[] canoniques
  toLegacy: myRouterCodec.toLegacy,       // inverse, à l'écriture
);
```

Le catalogue du chat se branche ensuite sur ce dépôt comme sur n'importe quel
`ZRepository<ZChatRouter>` (implémentation de `ZChatRouteCatalogPort` côté
hôte, ou `ZChatInMemoryRouteCatalog` alimenté par `getAll`).

## Concepts clés {#concepts-cles}

- **Le générique suffit** — `FirebaseZRepositoryImpl<ZChatRouter>` est
  construit avec `kind: kZChatRouterKind`, `fromMap: ZChatRouter.fromMap`,
  `toMap: ZChatRouter.toMap`. Il n'existe aucune ligne Firestore propre au
  routeur ; une entité future suivra le même chemin.
- **Forme sur le fil** — celle de `ZChatRouter.toMap()` : `routes` en
  **liste** `{task_key, model_provider_id?, model_id?, fallbacks?, …}`,
  `is_active` toujours émis, `params`/`extension` si non vides. Les
  métadonnées `is_deleted` / `updated_at` sont posées par le dépôt
  ([AD-9](../../docs/site/concepts/invariants.md#ad-9)), jamais par le codec.
- **Codec legacy en amont** — `toCanonical` reçoit la map brute du document
  (identifiant sous `id`, horodatages déjà en ISO-8601) et rend la forme
  canonique ; `toLegacy` reçoit `toMap()` et rend la forme écrite. Un codec
  qui lève n'est jamais fatal : le document est écarté à la lecture,
  l'écriture retombe sur la forme canonique.
- **Sémantique de suppression** — sur une collection sans `is_deleted`,
  `ZDeletionSemantics.strict` (défaut du générique) ne lit **rien** : le
  filtre serveur exige la présence du drapeau. Déclarer
  `ZDeletionSemantics.absentMeansAlive` ; chaque `save` pose ensuite
  `is_deleted:false` + `updated_at`, et la collection converge vers la forme
  stricte.
- **Tri défensif ([AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  le codec du noyau ne lève jamais ; sans garde, un document étranger à la
  collection deviendrait un routeur vide, actif. `zChatRouterShapeIssue`
  écarte (et journalise via `logger`) un document sans aucune clé du schéma
  ou dont une clé porte un type illisible ; les autres documents ne sont
  jamais affectés.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `buildChatRouterFirestoreRepository` | Fabrique un `ZRepository<ZChatRouter>` sur une collection Firestore ; accroche du codec legacy, sémantique de suppression, parseur d'extension, journal. |
| `ZChatRouterMapCodec` | Type des deux transformations de map d'un codec legacy (`toCanonical`, `toLegacy`). |
| `zChatRouterShapeIssue` | Prédicat défensif : décrit pourquoi une map canonique ne peut pas être un routeur, ou `null`. |

## Cas limites et invariants {#cas-limites}

- **Aucun nom de collection par défaut** — `collectionPath` est requis ; le
  nom appartient à l'hôte.
- **`getById` d'un document supprimé, corrompu ou absent** rend
  `Left(ZNotFoundFailure)` ; `restore` rend le document visible à nouveau.
- **`legacyDeletedKey`** n'est honorée qu'en `absentMeansAlive` (le mode
  strict lit exclusivement `is_deleted`, par clauses serveur).
- **Aucun code généré** dans ce paquet ; **aucune arête**
  `zcrud_firestore → zcrud_chat*` — les deux sont vérifiés par une garde de
  source.

## Voir aussi {#voir-aussi}

- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat_kernel` — `ZChatRouter`, `ZChatRouteSpec`, `ZChatRouteCatalogPort`.
- `zcrud_firestore` — `FirebaseZRepositoryImpl`, `ZDeletionSemantics`, `ZStudyLegacyCodec` (patron de codec legacy).

## Licence {#licence}

MIT — voir la racine du dépôt.
