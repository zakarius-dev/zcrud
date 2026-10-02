# Changelog

All notable changes to `zcrud_firestore` are documented in this file.

## 3.59.0 — 2026-10-02

### Ajouté

- `ZDeferredScopedLocalStore.unsignedReadsAreEmpty` vaut `true` par défaut. À `false`, une lecture sans scope échoue et le flux n'émet rien.
- Plusieurs stores différés du même nom de box partagent l'ouverture. `dispose` ne ferme la box qu'au dernier usage.
- Une ouverture en échec est rendue en `Left` et retentée à l'opération suivante.
- `buildUserScopedStudyRepository` et `buildFolderScopedStudyRepository` relaient `isForeign`.

### Corrigé

- `adoptUnscoped` ne ferme pas une box déjà ouverte, ne crée pas la box non cloisonnée si elle n'existe pas, ne remplace pas une entrée plus récente, et passe à l'entrée suivante lorsque `isMine` lève.

### Adaptation

- Un hôte qui fermait, recréait ou comparait les dates lui-même retire cette compensation. Voir `docs/handoff-v3.59.0.md`.

## 3.58.0 — 2026-10-02

### Ajouté

- `HiveZLocalStore.boxNameFor` laisse passer un scope déjà sûr (minuscules, chiffres, `_`, `-`, `~`, sans préfixe `zenc`). Tout autre scope est encodé en hexadécimal préfixé `zenc`, pour rester injectif après la mise en minuscules de Hive.
- `HiveZLocalStore.adoptUnscoped` copie, via `applyMerged`, les entrées pour lesquelles `isMine` est vrai, puis les retire de la box non cloisonnée. `updated_at` n'est pas réestampillé. Un scope vide est refusé.
- `ZOfflineFirstBoxRepository.isForeign` remplace le filtre de rattrapage. Une entrée retenue est journalisée.
- `ZDeferredScopedLocalStore` ouvre la box au premier usage du scope. Un scope absent ne retombe pas sur la box non cloisonnée : les lectures sont vides et les écritures sont refusées.

### Adaptation

- Un scope à casse mixte, ou qui contient un séparateur de chemin, n'ouvre plus `zcrud_<kind>__<scope>`. Les boxes déjà ouvertes sous l'ancien nom ne sont pas renommées. Un scope déjà en minuscules (`uid-a`, `uid~0041`) conserve son nom.
- `isMine` doit rendre faux lorsqu'aucun propriétaire n'est établi. Voir `docs/handoff-v3.58.0.md`.

## 3.57.0 — 2026-10-01

### Ajouté

- `HiveZLocalStore.boxNameFor(kind, {scope})` et `openBox(..., scope:)`. Un scope vide ou absent conserve `zcrud_<kind>`. Un scope non vide ouvre `zcrud_<kind>__<scope>`.
- Le rattrapage d'un dépôt offline-first n'envoie pas une entrée locale dont `user_id`, `userId`, `owner_id` ou `ownerId` est un texte non vide différent de l'utilisateur du dépôt. Une clé absente, un encodage en échec ou un dépôt sans utilisateur laissent l'envoi inchangé.
- `ZFolderScopedLocalStore` filtre un store partagé sur un dossier. `buildFolderScopedStudyRepository` l'applique quand `folderIdOf` est fourni. `clear` ne retire que ce dossier. `dispose` ne libère pas le store interne.

## 3.31.0 — 2026-08-29

### Ajouté

#### Les 23 entités de structure d'étude, servies sans une ligne d'adaptateur

- **`buildStudyStructureRepositories({firestore, collectionPathOf, …})`** → **`ZStudyStructureRepositories`**, un `ZRepository<T>` par entité de structure du noyau d'étude (workspace, principal, organization, orgUnit, program, group, classification, subject, course, programCourse, calendar, period, session, offering, offeringAudience, participation, curriculum, topic, competency, competencyFramework, explanation, roleBinding, shareGrant). Chaque dépôt = le générique `FirebaseZRepositoryImpl.fromRegistry` + le registrar de codegen du noyau. Options du même patron que le satellite chat : `deletionSemantics`, `legacyDeletedKey`, `decodeContext`, `logger`.
- **`buildStudyStructureRegistry({decodeContext})`** — le registre des 23 entités, neuf à chaque appel (jamais de collision avec un registre d'app).
- **Le `kind` est résolu par le registre** (`ZcrudRegistry.kindOf<T>()`), pas écrit dans la fabrique : le fichier de fabrique ne porte **ni un nom de champ, ni une valeur de kind, ni un appel `fromMap`/`toMap`**. Trois gardes de source (`@TestOn('vm')`) le mesurent en lisant les noms de champs dans les `ZFieldSpec` **du noyau** — une garde qui aurait listé elle-même les champs à surveiller aurait hérité de l'angle mort de son auteur.
- **`zStudyAncestorFilter` / `zStudyAncestorRequest` / `kZStudyAncestorIdsKey`** — requête de portée « descendants à toute profondeur », exprimée en `ZFilter` **neutre** (traduit en `arrayContains` par l'adaptateur). Aucun type `cloud_firestore` n'entre dans une signature publique : exposer une `Query` nue aurait franchi AD-5. La clé visée est vérifiée contre ce que `toMap()` du noyau **émet réellement**.

### Mesuré

- La (dé)sérialisation du noyau étant elle-même défensive, un champ persisté d'un type non conforme **ne lève pas** : il retombe sur le défaut du schéma. La voie « document écarté » du dépôt reste donc en réserve ; ce que la garde AD-10 affirme est le contrat réel — lecture jamais en échec, voisin sain intact, valeur illisible jamais franchie telle quelle.
- Aucun harnais de conformité « dépôt mémoire ≡ Firestore » n'existe dans ce paquet (aucun dépôt mémoire non plus) : la garde correspondante est sans objet, elle n'a pas été fabriquée pour la forme.

## 3.22.0 — 2026-08-26

### Ajouté
- **`saveMerging()`** — écriture **fusionnante** (`SetOptions(merge: true)`) : les champs absents de la carte **survivent** dans le document. `save` reste un écrasement total, à l'octet près : la voie historique passe `null` et non un `SetOptions(merge: false)`.

## 3.6.0 — 2026-08-23

### Corrigé
- Octet NUL brut dans un littéral Dart remplacé par `\u0000` (un `grep` sans `-a` voyait un fichier binaire ; `git diff` aussi).

## 0.98.0 — 2026-08-14

### Corrigé

#### Le `collectionId` de `save` est un chemin de collection, et c'est écrit

`FirebaseZRepositoryImpl.save` prend `collectionId` comme **chemin de
collection de remplacement** : renseigné, il détourne l'écriture hors du
`collectionPath` du dépôt. Rien ne le disait, et Firestore ne le signale pas
davantage — il crée toute collection nommée à la volée. Une valeur qui ne
désignait pas un conteneur réel ne provoquait donc aucune erreur : elle
fabriquait un silo, invisible aux lectures de ce dépôt, toutes ancrées sur
`collectionPath`.

La dartdoc de `save` énonce désormais cette redirection et interdit
explicitement d'y passer l'identifiant soumis à `ZAcl.can`. Celle de
`ZOfflineFirstRepository.save` précise le pendant : le paramètre y est
**ignoré**, l'emplacement étant fixé par la topologie des stores injectés —
aucun silo accidentel n'est possible par cette voie.

Aucun changement de comportement : une redirection explicite reste servie à
l'identique.

## 0.97.0 — 2026-08-14

### Corrigé

#### La limite de recherche de Firestore n'est plus seulement documentée

`FirebaseZRepositoryImpl` ne sert pas `ZDataRequest.search` (Firestore n'a ni
`LIKE`, ni plein-texte, ni pliage diacritique) : la limite était consignée dans
la documentation, et les listings assemblés au-dessus offraient malgré tout une
barre de recherche inerte.

L'adaptateur applique désormais le mixin `ZDelegatesSearch` de `zcrud_core` :
il **déclare** qu'il délègue la recherche. Un listing du socle filtre alors le
terme saisi par son propre moteur, le temps de la recherche — au prix d'une
lecture non paginée de la collection, et de rien du tout tant qu'aucun terme
n'est saisi. `ZOfflineFirstRepository` et `ZOfflineFirstBoxRepository`, qui
rendent le snapshot local complet sans traduire la requête, le déclarent
également ; le jeu y étant déjà lu en entier, cette voie n'y coûte aucune
lecture de plus.

Aucune signature ne change, et aucune implémentation hôte du port n'est
touchée : la capacité est un mixin, pas un membre de `ZRepository`.

Sur un gros parc, la voie recommandée reste inchangée : un champ de recherche
normalisé pré-calculé, interrogeable par égalité ou par préfixe.

## 0.91.0 — 2026-08-12

### Ajouté

- `FirebaseZRepositoryImpl` (et sa fabrique `fromRegistry`) accepte un nouveau
  paramètre `omitNullFields` (défaut `false` — comportement actuel inchangé,
  les clés nulles restent écrites). À `true`, les clés à `null` sont retirées
  **récursivement** du corps de l'entité avant chaque écriture (`save`,
  `writeMerged`, `applyMergedAll`) — l'équivalent du `compact(true)` des
  moteurs legacy. Les métadonnées de synchronisation (`updated_at`,
  `is_deleted`) ne sont jamais retirées, y compris un `updated_at` verbatim
  `null` sur la voie de merge. Pourquoi : en écriture fusionnée Firestore
  (`merge: true`), une clé **absente** laisse la valeur distante intacte,
  mais une clé présente à **`null` l'efface** — un parc co-écrit en fusion
  doit garantir qu'aucune clé nulle n'atteint le disque.

## 0.1.0

Initial public release.

- Firestore and Hive adapters for zcrud repositories.
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
