# Code-review E5-3 — offline-first LWW + soft-delete + `ZSyncMeta`

**Mode d'exécution** : skill réel `bmad-code-review` invoqué via le tool `Skill` (workflow step-file). Périmètre = fichiers de la story E5-3 **uniquement** (`zcrud_core` + `zcrud_firestore`). `zcrud_flashcard`/`zcrud_mindmap` (autres workstreams en vol) exclus.

**Story** : `_bmad-output/implementation-artifacts/stories/e5-3-offline-first-lww-soft-delete.md` (15 ACs).

## Vérif rejouée réellement sur disque

| Vérif | Résultat réel |
|---|---|
| `dart analyze packages/zcrud_core` | **RC=0** — No issues found |
| `dart analyze packages/zcrud_firestore` | **RC=0** — No issues found |
| `flutter test packages/zcrud_core` | **RC=0 — 580 tests** (conforme au Dev Agent Record) |
| `flutter test packages/zcrud_firestore` | **RC=0 — 73 tests** (conforme) |
| `python3 scripts/dev/graph_proof.py` | **CORE OUT=0 OK**, ACYCLIQUE OK, 14 nœuds |

Isolation AD-5 : re-vérifiée sur disque — `z_offline_first_repository.dart`, `z_sync_entry.dart`, `z_lww_resolver.dart`, `z_syncable_repository.dart` n'importent **aucun** `hive`/`cloud_firestore`/`firebase_core`, aucun type backend en signature. `zcrud_core/pubspec.yaml` inchangé. Conforme AC6/AC14.

---

## Findings

### MAJEUR-1 — La propagation distante de `save`/`softDelete`/`restore` est **awaited**, pas « fire-and-forget »
**Fichier** : `packages/zcrud_firestore/lib/src/data/z_offline_first_repository.dart:108` (save), `:121` (softDelete), `:136` (restore).

Les trois écritures font `await localRes.fold(..., (v) => _bestEffortRemote(() => _remote.push(v), ...))`. Le `await` sur `_bestEffortRemote` **attend la fin de l'opération réseau** avant que la méthode ne complète son `Future`. Le résultat retourné est bien `Right(localResult)` (correct), **mais** l'appelant reste bloqué sur l'aller-retour distant.

- **Contradiction AC9** : « renvoie `Right(localResult)` **dès** le succès local ; **puis** propage au distant en **fire-and-forget** ». Le dartdoc de la classe dit aussi « renvoie le résultat local **DÈS** son succès ». Le code, lui, attend le distant.
- **Impact réel** : hors-ligne « propre » (timeout réseau ~30-60 s), `save()`/`softDelete()`/`restore()` **bloquent le temps du timeout** avant de rendre la main, alors que le local a déjà réussi. C'est exactement la latence que le patron offline-first (AD-9, « distant fire-and-forget ») promet d'éviter. Le test AC9 ne l'attrape pas : `_ThrowingFirestore.collection()` lève **synchroniquement** → l'échec est instantané, donc le test **ne distingue pas** awaited vs non-awaited (cf. LOW-2).
- **Reco** : `unawaited(_bestEffortRemote(...))` (import `dart:async`) après avoir capturé le succès local, et `return localRes;` immédiatement. `_bestEffortRemote` avale déjà tout `Left`/exception → `unawaited` est sûr. Adapter les 3 méthodes. Ajuster/ajouter un test avec un distant à latence non-synchrone (ex. `Future.delayed`) pour prouver la non-blocance.
- **Nuance honnête pour l'orchestrateur** : défaut de **latence/contrat**, pas de **correction de donnée** (le `Right` local est juste). Trivialement corrigeable. Classé MAJEUR car il touche l'invariant offline-first (AD-9) et le libellé explicite de l'AC9.

### MEDIUM-1 (point a) — Lectures request-portées : filtres/tri/pagination **silencieusement ignorés**
**Fichier** : `z_offline_first_repository.dart:83` (`watch(req)`), `:86` (`getAll({request})`), `:92-95` (`count({request})`).

`watch(req)` et `getAll({request})` délèguent à `_local.watchAll()`/`_local.getAll()` **sans** utiliser `request` ; `count({request})` renvoie la **longueur totale visible**, pas un compte filtré. Un appelant du contrat `ZRepository<T>` qui passe un filtre/tri reçoit **l'intégralité** du snapshot visible (ou le compte total) sans aucun signal.

- **Impact** : divergence **silencieuse** vs le contrat `ZRepository`. Sur une liste filtrée, l'UI afficherait toutes les entités (bug fonctionnel, pas fuite : la donnée locale appartient à l'utilisateur). Le port `ZLocalStore` n'expose effectivement pas de requête → contrainte architecturale réelle, et la story documente la dette (Completion Notes). Mais le drop est **muet**.
- **Reco (MEDIUM par défaut, sinon justifier)** : au minimum rendre le drop **explicite** — logguer/documenter au niveau méthode « `request` ignoré (filtrage local hors périmètre E5-3) », ou `assert(request == null)` en debug, et tracer pour E9 (consommateur). Ne pas laisser un appelant croire à tort que son filtre est appliqué.

### MEDIUM-2 (point c) — `sync()` assimile **tout** `Left(ServerFailure)` distant à « offline » → `Right(unit)`
**Fichier** : `z_offline_first_repository.dart:203-212` (lecture distante `null` → `Right(unit)`), `:244-248` (push `Left` avalé).

Toute erreur distante (y compris **permission-denied**, **quota**, règles de sécurité mal configurées, endpoint invalide) devient `Left(ServerFailure)` → traitée comme « déconnecté » → `sync()` renvoie `Right(unit)` (loggé seulement). La sync **rapporte un succès** alors qu'elle **ne converge jamais**, et un défaut de configuration serait **invisible** aux appelants tant qu'E5-4 n'apporte pas une vraie source de connectivité.

- **Impact** : masquage d'une vraie panne serveur en « offline ». Documenté comme Ambiguïté #4 de la story, cohérent avec le choix AD-9 « best-effort » / AD-11 « `ServerFailure` distant = offline ».
- **Reco (MEDIUM — décision explicite demandée en review)** : acceptable pour E5-3 **si** (1) le log est de sévérité élevée et non no-op par défaut en prod, et (2) une note de dette explicite renvoie à E5-4 pour distinguer « réseau injoignable » d'« erreur serveur applicative » (ex. ne `Right(unit)` que sur un sous-ensemble d'erreurs réseau, remonter permission/quota). À trancher : le laisser tel quel + note, ou restreindre dès maintenant. Position argumentée ci-dessous.

### LOW-1 — `applyMergedAll` : `id==null` en cours de boucle laisse les lots précédents committés (écriture partielle) et l'erreur est ensuite avalée
**Fichier** : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` — méthode `applyMergedAll` (bloc « Sync offline-first (E5-3) »).

Sur un changeset > 450, si une entrée `id==null` apparaît dans un lot postérieur, la méthode `return Left(DomainFailure)` **après** avoir déjà committé les lots précédents → propagation partielle. De plus, dans `sync()` ce `Left` (bug de programmation) est avalé en `Right(unit)` comme s'il s'agissait d'un « offline ». En pratique inatteignable (la sync ne pousse que des entités matérialisées), d'où LOW. Reco : valider les `id` non-null **avant** d'ouvrir le premier lot (fail-fast, zéro écriture partielle), ou documenter la garantie « atomicité par lot, pas cross-lot ».

### LOW-2 — Le test AC9 ne prouve pas réellement le « fire-and-forget »
**Fichier** : `packages/zcrud_firestore/test/z_offline_first_repository_test.dart:293-314`.

`_ThrowingFirestore.collection()` lève **synchroniquement** → l'échec distant est instantané, donc le test passe que la propagation soit `await`-ée (MAJEUR-1) ou non. Le test valide « le succès local survit à un échec distant » mais **pas** la non-blocance. Reco : ajouter un distant à latence asynchrone (`Future.delayed`) et asserter que `save()` complète **avant** la fin du délai (supporte le fix MAJEUR-1).

### LOW-3 — `save(item, {collectionId})` ignore `collectionId`
**Fichier** : `z_offline_first_repository.dart:104`.

Le paramètre `collectionId` du contrat `ZRepository.save` est dropé (store mono-collection par instance). Vraisemblablement **par design**, mais non documenté au niveau méthode. Reco : dartdoc « `collectionId` non pertinent (un store = un agrégat) » ou `assert`.

---

## Positions argumentées sur les points adverses

**(a) Lectures request-portées non traduites** — **Faille mineure réelle, pas bloquante (MEDIUM-1).** Ce n'est pas une fuite de données (donnée locale = donnée de l'utilisateur) mais une **divergence silencieuse** du contrat `ZRepository` : un filtre passé est ignoré sans signal. La contrainte est réelle (`ZLocalStore` n'a pas de requête filtrée) et la dette est documentée. Acceptable pour E5-3 **à condition de rendre le drop explicite** (log/assert/doc) et de le tracer pour E9. Ne justifie pas de bloquer `done`, mais mérite mieux qu'un silence.

**(b) Tie-break LWW « local fait foi » à `updatedAt` égal** — **Déterministe ; divergence uniquement pathologique, acceptable.** Pour un couple (local, remote) donné, `resolve` est totalement déterministe (`noop` si états identiques, sinon `pushLocalToRemote`). Le seul scénario de divergence inter-appareils est : deux appareils avec des **corps différents** au **même timestamp à la milliseconde près** — chacun réécrit le serveur avec son propre local sans jamais adopter l'autre. C'est **astronomiquement rare** et **inhérent au LWW-sur-timestamp** (aucune stratégie de tie-break ne résout un conflit de contenu à horodatage strictement égal sans horloge logique/vector clock, hors périmètre). Le choix « local autoritaire » est cohérent avec AD-9. **Aucun finding** ; reco légère : documenter le caveat multi-appareils dans le dartdoc du résolveur. L'alternative « précédence-tombstone » n'aiderait que le cas delete-vs-edit à égalité stricte et introduirait une asymétrie ; le choix retenu est défendable.

**(c) `ServerFailure` distant = offline → `Right(unit)`** — **Risque réel d'avaler une vraie erreur serveur (MEDIUM-2).** Le risque est concret (permission/quota/misconfig masqués en « offline », sync « réussie » mais jamais convergente). C'est un **choix de conception assumé** (AD-9 best-effort, AD-11, Ambiguïté #4) et défendable pour un `sync()` one-shot best-effort re-tenté par E5-4. Condition d'acceptation : log de sévérité **non triviale** (pas no-op muet en prod) + note de dette explicite pour qu'E5-4 différencie réseau-injoignable vs erreur-applicative. À trancher explicitement en review ; ma reco = acceptable **avec** ces deux garde-fous, sinon restreindre le `Right(unit)` aux erreurs réseau.

**(d) Invariants AD** — **Respectés.** `zcrud_core` reste Dart pur (aucun type hive/cloud_firestore en signature, `CORE OUT=0`) ; tout retourne `Either<ZFailure,T>`/`Stream<List<T>>` nu ; désérialisation défensive AD-10 vérifiée (`_rawMap`/`_decodeEntity`/`_decode` écartent+loggent, jamais de throw ; test « 1 corrompu parmi N → N-1 ») ; `applyMerged` écrit la méta **verbatim** sans `now()` (anti-ping-pong prouvé par les tests AC4/AC10-v) ; soft-delete **hors-entité** (`ZSyncMeta`, `is_deleted`/`updated_at` ISO-8601, jamais `box.delete`/`doc.delete`) ; borne `450` **locale à `zcrud_firestore`** (`kMaxBatchWrites`), jamais dans le cœur. **Cascade/lot** : atomicité **par lot** (≤450), pas cross-changeset — inhérent à la limite Firestore 500 et documenté ; seul bémol = écriture partielle sur chemin d'erreur `id==null` inatteignable (LOW-1).

---

## Verdict

**Corrections requises avant `done`.**

- **MAJEUR-1** (propagation awaited ≠ fire-and-forget) : correction **obligatoire** avant `done` (règle CLAUDE.md : HIGH/MAJEUR obligatoire) — passer en `unawaited()` sur `save`/`softDelete`/`restore` + test de non-blocance (LOW-2).
- **MEDIUM-1** (request ignoré silencieusement) et **MEDIUM-2** (`ServerFailure`→offline) : à corriger **par défaut** dans le périmètre (rendre explicite / garde-fous), sinon **justifier par écrit** le report.
- **LOW-1/2/3** : optionnels (corriger si trivial, sinon consigner).

Une fois MAJEUR-1 corrigé + MEDIUM triés, re-jouer la vérif verte (analyze RC=0 + `flutter test` core & firestore + `melos analyze`/`verify` repo-wide au gate de commit d'epic) avant transition `done`.

---

## Résolution (orchestrateur)

Re-vérif verte après correctifs : `dart analyze packages/zcrud_core` RC=0, `dart analyze packages/zcrud_firestore` RC=0, `flutter test packages/zcrud_firestore` **74 tests** (+1), `flutter test packages/zcrud_core` 580 tests, `graph_proof` CORE OUT=0 / ACYCLIQUE OK.

- **MAJEUR-1 — CORRIGÉ.** `save`/`softDelete`/`restore` ne `await` plus la propagation distante : `localRes.fold(...)` non-async + `unawaited(_bestEffortRemote(...))` → retour immédiat du résultat local (fire-and-forget strict, AD-9). `restore` extrait dans `_propagateRestore(id)`. **Test de non-blocance ajouté** (`_SlowRemote` retarde `push` derrière un `Completer` ; assertion : `save()` rend la main avec `pushCompleted==false`, puis la propagation s'achève après ouverture de la porte).
- **MEDIUM-1 — CORRIGÉ.** `watch(request)`/`getAll({request})`/`count({request})` loggent désormais explicitement (`_requestDroppedNote`) le drop de filtre/tri/pagination (jamais silencieux) ; dette de traduction requête→cache local **tracée pour E9**.
- **MEDIUM-2 — CORRIGÉ (log renforcé + dette E5-4 documentée).** L'assimilation `Left(ServerFailure)` distant → offline/`Right(unit)` est conservée (choix AD-9/Ambiguïté #4) mais le log signale explicitement qu'elle **englobe permission/quota** (⚠️) et renvoie la distinction réseau/serveur à **E5-4** (`ZSyncOrchestrator` + typage connectivité). Commentaire de dette inscrit en clair dans `sync()`.
- **LOW-1/2/3 — CONSIGNÉS** (optionnels) : écriture partielle inter-lots inatteignable en pratique (validation d'id en amont possible en E5-4) ; `collectionId` ignoré par design ; couverture de test fire-and-forget désormais assurée par le nouveau test MAJEUR-1.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert. Dettes E9 (traduction requête) et E5-4 (distinction réseau/serveur) tracées.
