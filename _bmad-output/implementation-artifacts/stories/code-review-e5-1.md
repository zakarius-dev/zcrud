# Code Review — E5-1 : `FirebaseZRepositoryImpl<T>` + traduction `ZDataRequest→Query`

- **Skill** : `bmad-code-review` (chargé depuis disque `.claude/skills/bmad-code-review/SKILL.md`, config résolue via `resolve_customization.py`).
- **Statut story à la revue** : `review` (finie via REPRISE après plantage d'agent — vigilance raccourcis).
- **Périmètre lu** : `packages/zcrud_firestore/{lib/src/data/firebase_z_repository_impl.dart, lib/src/data/z_firestore_api.dart, lib/zcrud_firestore.dart, test/firebase_z_repository_impl_test.dart, pubspec.yaml}` + ports `zcrud_core` (`z_repository`, `z_data_request`, `z_cursor`, `z_sync_meta`, `z_entity`).
- **Vérif verte (orchestrateur, non rejouée ici)** : analyze 0 issue, 22 tests OK, melos verify RC=0, CORE OUT=0, 14 packages.

## Verdicts synthétiques

| Question chaude | Verdict |
|---|---|
| Isolation Firebase (6 types interdits : Query/CollectionReference/DocumentSnapshot/Timestamp/Filter/FirebaseException) prouvée | **OUI** (aucun des 6 en signature publique ; port `zcrud_core` propre). Caveat : le constructeur expose `FirebaseFirestore` — couture DI voulue, hors des 6 types énumérés. |
| AC12 tie-break correct **EN PROD** | **NON (fragile)** — voir MAJEUR-1 : `orderBy('id')` sur champ de corps exclut silencieusement tout doc sans `id` en prod ; le test le masque via `_seedRaw`. |
| AC9 `_guard` couvre **TOUS** les chemins | **NON (partiel)** — voir MEDIUM-1 : les chemins `watch`/`watchAll` construisent la Query hors garde (throw synchrone possible) ; seul `snapshots()` runtime est converti. Chemins Future (get/getAll/count/save/delete) OK. |
| withConverter symétrique save/read | **PARTIEL** — save écrit en **RAW** (`batch.set` + `_encode`), relit via converter ; `getById`/listes lisent en RAW + `_decode`. `toFirestore` du converter jamais utilisé. Symétrie d'encodage OK ; le « round-trip withConverter » de l'AC1 est largement cosmétique (LOW-3). |

---

## MAJEUR-1 — Tie-break `orderBy('id')` sur champ de corps : documents sans `id` invisibles en prod
**Fichier** : `lib/src/data/firebase_z_repository_impl.dart:297` (+ justification 268-281).

`_buildQuery` ajoute systématiquement `q = q.orderBy(_kId)` (champ logique `'id'` stocké dans le **corps** du document). Sémantique Firestore : `orderBy(field)` **exclut** tout document qui ne possède pas ce champ. Donc en prod, tout document dont le corps ne porte pas `id` (données héritées des 3 apps, docs écrits hors zcrud, données migrées, écritures E5-2/directes) **disparaît de toute requête triée ou paginée** — sans erreur, silencieusement.

Le choix a été fait pour contourner le backend de test (`FieldPath.documentId` non servi comme clé de curseur par le fake). C'est exactement le raccourci de reprise à surveiller : on troque une incompatibilité *fake* contre un **risque de perte de données silencieuse en prod**. `FieldPath.documentId` (toujours présent sur chaque doc) était le choix sûr en prod.

**Preuve** : le test AC12 seed via `_seedRaw` (test:101-106) qui injecte TOUJOURS `'id': id` dans le corps → il prouve la pagination *uniquement* dans le monde où tout doc porte `id`, invariant garanti seulement pour les écritures `save` internes. E7 (intégration DODLP) branche l'adaptateur sur une collection **existante**.

**Scénario d'échec** : collection DODLP existante où les docs stockent l'identité comme documentId (corps sans champ `id`) → `getAll(request: sorts)` renvoie `[]` ou une page tronquée ; pagination et `watch` triés perdent des lignes, aucune exception.

**Remède** : (a) utiliser `FieldPath.documentId` pour le tie-break derrière une petite abstraction testable (le fake ne doit pas dicter le choix prod), OU (b) rendre l'invariant explicite et exécutoire : documenter fortement « collection gérée exclusivement par zcrud, tout doc DOIT porter `id` » + backfill/migration à l'onboarding E7, et le tester avec un doc *sans* `id` de corps prouvant le comportement attendu.

## MAJEUR-2 — Filtre serveur `where('is_deleted', isEqualTo: false)` : docs sans le champ invisibles (perte de données legacy)
**Fichier** : `lib/src/data/firebase_z_repository_impl.dart:226` (`_baseQuery`).

Toute lecture/flux/count part de `where('is_deleted', isEqualTo: false)`. Comme MAJEUR-1, l'égalité Firestore **exige la présence du champ** : un document sans `is_deleted` (données héritées/migrées) est **exclu de TOUT** (getAll, watch, getById via le même chemin ? non — getById lit en RAW puis `_isSoftDeleted`, incohérence ci-dessous), sans erreur.

**Incohérence des deux couches de filtrage** : le filtre applicatif `_isSoftDeleted` (`:201`, `data['is_deleted'] == true`) traite un champ **absent** comme *non supprimé* (donc gardé), tandis que le filtre serveur `isEqualTo:false` **rejette** le champ absent. Résultat net : un doc legacy sans `is_deleted` est droppé au serveur avant d'atteindre la couche applicative → **invisible**. `getById` (qui n'utilise que la voie RAW + `_isSoftDeleted`) le rendrait *visible* → comportement divergent get vs getAll/watch pour le même doc.

**Preuve** : `_seedRaw` (test:99-106) écrit toujours `is_deleted`. Aucun test ne seed un doc *sans* `is_deleted`.

**Scénario d'échec** : import/migration d'une collection existante sans `is_deleted` → `getAll()` renvoie `[]` alors que `getById(knownId)` renvoie l'entité. Données « perdues » côté liste/flux.

**Remède** : soit backfill obligatoire `is_deleted=false` documenté + testé (doc sans champ prouvant l'exclusion voulue), soit filtrage soft-delete **applicatif uniquement** (lecture puis exclusion `== true`), soit documenter explicitement la précondition « collection zcrud-native » et aligner les deux couches (get/getAll/watch cohérents). L'ambiguïté #2 a tranché pour l'égalité sans acter cette perte des docs à champ absent.

---

## MEDIUM-1 — AC9 : construction de Query hors `_guard` sur les chemins flux
**Fichier** : `lib/src/data/firebase_z_repository_impl.dart:339,342-343,348` (`watchAll`/`watch`/`_watchQuery`).

`watchAll()` évalue `_baseQuery()` et `watch()` évalue `_buildQuery(_baseQuery(), request)` **synchroniquement**, hors de toute garde, avant de retourner le stream. Ces appels touchent `_firestore.collection(...)`. Une erreur **synchrone** à la construction (ex. la `FirebaseException` que lève `_ThrowingFirestore.collection`, ou un `StateError` d'un champ/valeur invalide) **s'échappe vers l'appelant** au lieu d'être convertie. Seules les erreurs **runtime** de `snapshots()` sont converties via `onError` (`:354-362`). Le test AC9 ne prouve la conversion que pour `getAll` — jamais pour `watch`/`softDelete`/`restore`/`save`/`count`/`getById`.

**Scénario d'échec** : `repo.watch(req)` avec un Firestore qui throw à `collection()` → exception non capturée remonte à l'UI (AC9 « jamais d'exception qui remonte » violé sur ce chemin).

**Remède** : envelopper la construction+abonnement dans un try/catch qui pousse l'erreur dans le `StreamController` (`controller.addError(ServerFailure...)`), et couvrir au moins un chemin flux + un chemin écriture par un test d'injection d'exception.

## MEDIUM-2 — AC13/AC14 : aucun test automatisé dans la suite
**Fichier** : `test/firebase_z_repository_impl_test.dart` (absence).

AC13 exige explicitement « un test/gate vérifie qu'aucun symbole `cloud_firestore` n'apparaît dans une signature publique » et AC14 « un contrôle prouve que `zcrud_core` ne dépend d'aucun paquet Firebase ». La suite (22 tests) n'en contient **aucun** (grep : 0 test isolation/signature) — ils reposent uniquement sur le gate melos `verify` (graphe CORE OUT=0). Pour un invariant AD-5 aussi central, l'absence de test de signature au niveau package est un trou face à une régression future (ex. un futur getter public renvoyant un `DocumentSnapshot`).

**Remède** : ajouter un test/gate de signature (analyse statique du barrel, ou test d'API exportée) ; consigner par écrit si reporté (les MEDIUM reportés doivent être justifiés per CLAUDE.md).

---

## LOW-1 — `mock_exceptions` : dev_dependency morte
`pubspec.yaml:36` déclare `mock_exceptions: ^0.8.0` mais il n'est plus **importé** (uniquement cité en commentaires, test:5/111/113). Dépendance inutile + commentaire d'en-tête trompeur (« Injection d'exception : `mock_exceptions` »). Retirer la dep et corriger le commentaire.

## LOW-2 — AC6 mapping incomplet en test : `isNull` non couvert
Le code mappe `ZFilterOp.isNull → where(isNull:true)` (`:261-262`) mais aucun test ne l'exerce (grep `isNull` en test = 0). AC6 demande le mapping *complet* des `ZFilterOp`. Ajouter un cas `isNull`.

## LOW-3 — withConverter (AC1) largement cosmétique
`_typedCollection.toFirestore` (`:155`) n'est **jamais** utilisé (save écrit en RAW `batch.set`, `:427-429`). `getById` et les listes décodent en RAW + `_decode`. Seule la relecture du retour de `save` (`:433`) passe par le converter. Le second test AC1 (test:148-166) reconstruit un converter **dans le test**, pas celui du repo. L'esprit « round-trip withConverter » de l'AC1 est donc peu exercé — c'est justifié pour les listes (AD-10 : un converter ne peut renvoyer `null` pour écarter un corrompu), mais à acter clairement.

## LOW-4 — `save` = overwrite total qui « ressuscite » et clobbe silencieusement
`save` fait `batch.set(...)` (remplacement complet) et `_encode` réécrit inconditionnellement `is_deleted=false` + `updated_at=now` (`:167-174,424`). Re-sauver une entité soft-deleted la **restaure silencieusement** et écrase tout champ hors `_encode` (méta concurrente incluse). Défendable pour un `save` full-write en E5-1, mais non testé/non documenté comme intentionnel. À documenter (et rappeler que le merge LWW est E5-3).

## LOW-5 — Index composites non fournis/documentés (masqués par le fake)
Une requête `where(is_deleted==false) + where(count>=2) + orderBy(count desc) + orderBy(id)` (test AC7) exige un **index composite** en prod ; sinon `FAILED_PRECONDITION` → `ServerFailure`. `fake_cloud_firestore` ne requiert aucun index → les tests passent, la prod échouerait. Documenter les index requis (ou renvoyer vers la config de déploiement E7).

---

## Points vérifiés CONFORMES (pas de finding)
- **AD-11 / bug #3 & #4** : `_guard` (`:321-334`) mappe `FirebaseException→ServerFailure`, repropage `ZFailure`, mappe le reste ; **zéro** `catch(_){}`. `null≠erreur` : `getById` absent→`NotFoundFailure` (`:383-386`), collection vide→`[]`. OK (hors chemins flux, MEDIUM-1).
- **Bug #1 (immuabilité Query)** : `_applyFilters`/`_buildQuery` réaffectent `q = q.where/orderBy/limit/startAfter` systématiquement ; test AC7 prouve 3 clauses coexistantes. OK.
- **Bug #2 (batch)** : `save` et `_setDeletedFlag` committent via `WriteBatch` (`:427-429,462-467`). Cohérent (mono-écriture, atomique trivial).
- **AD-9 soft-delete hors-entité** : `softDelete`/`restore` ne touchent que `is_deleted`/`updated_at` ; test AC5 prouve champs métier intacts. OK.
- **AD-5 dates** : `updated_at` toujours ISO-8601 String (`_encode` via `ZSyncMeta.toJson`, `_setDeletedFlag` via `toIso8601String`) ; aucun `Timestamp` exposé. OK.
- **AD-10 défensif** : `_decode` (fromMapSafe | try/catch fromMap), `_decodeDocs` écarte corrompus + soft-deleted ; test AC11 : N-1 sans throw + log. OK.
- **AD-16 curseur** : `startAfter([...values, id])` après les `orderBy`, `limit` en dernier. OK (fragilité tie-break = MAJEUR-1).
- **Isolation des 6 types interdits** : aucun en signature publique ; `dispose` idempotent ; pas de secret ni `badCertificateCallback`. OK.

## Recommandation
**Ne pas passer `done` sans traiter MAJEUR-1 et MAJEUR-2** (perte de données silencieuse en prod, masquée par le seeding fake — cœur du risque de reprise). MEDIUM-1/2 à corriger dans le périmètre ou justifier par écrit. LOW selon trivialité.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MAJEUR | ✅ **corrigé (voie b)** | Option (a) `orderBy(FieldPath.documentId)` **prouvée infaisable** sur `fake_cloud_firestore` : `startAfter([...values, id])` lève `key must be String or FieldPath` (le fake appelle `doc.get(FieldPath.documentId)` en interne). Bascule voie (b) : invariant « collection zcrud-native » rendu **exécutoire** (`save`/`_encode` écrivent TOUJOURS le corps `id == doc.id`), dartdoc fort sur la classe + `_buildQuery`. Constat honnête consigné (le fake ne réplique pas l'exclusion prod d'un doc sans corps `id`) ; 2 tests prouvent l'invariant qui neutralise le risque. Migration collections legacy = E7 (différé). |
| 2 | MAJEUR | ✅ **corrigé** | Helper `_isVisible(data)=(is_deleted==false)` appliqué de façon **cohérente** sur getById ET getAll/watch (fin de la divergence) ; filtre serveur conservé, précondition documentée. Test seedant un doc sans `is_deleted` prouvant l'exclusion cohérente sur les 3 chemins. |
| 3 | MEDIUM | ✅ **corrigé** | `watch`/`watchAll` reçoivent un `Query Function()` ; construction + abonnement enveloppés dans `try/catch` (`onListen` → `controller.addError(ServerFailure)`). 2 tests (watch + watchAll via `_ThrowingFirestore`) prouvent l'erreur par le canal du stream, jamais en throw synchrone. |
| 4 | MEDIUM | ✅ **corrigé** | AC13 : test scannant barrel + fichiers exportés (aucun des 6 types Firestore en signature publique, contrôle positif anti-faux-vert). AC14 : test lisant `zcrud_core/pubspec.yaml` prouvant 0 dép Firebase. |
| 5 | LOW-1 | ✅ corrigé | `mock_exceptions` retiré + commentaire corrigé. |
| 6 | LOW-2 | ✅ corrigé | Test `ZFilterOp.isNull → where(isNull:true)`. |
| 7 | LOW-3 | ✅ documenté | Dartdoc `_typedCollection` : `toFirestore` non invoqué, lectures raw+`_decode` défensif (AD-10). |
| 8 | LOW-4 | ✅ documenté + testé | Dartdoc `save` (overwrite « ressuscitant », LWW=E5-3) + test de résurrection. |
| 9 | LOW-5 | ✅ documenté | Dartdoc `_buildQuery` : index composites requis en prod (masqués par le fake) → config déploiement E7. |

**Vérif verte rejouée après remédiation (orchestrateur, sur disque)** : `flutter analyze` **0 issue** · `flutter test` **31/31** (22 + 9 nouveaux) · `melos analyze` RC=0 · `melos verify` RC=0 (**CORE OUT=0 OK**, graphe acyclique) · `melos list=14`.

**Verdict final** : 2 MAJEUR + 2 MEDIUM corrigés avec tests ; 5 LOW traités. Story E5-1 → **done**.
