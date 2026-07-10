# Code Review — E5-2 : `ZLocalStore` (Hive) + `ZRemoteStore`

- Skill : `bmad-code-review` (invoqué via tool `Skill` ; step-file `steps/step-01-gather-context.md` chargé).
- Mode : revue ADVERSARIALE (learning E5-1 : « le fake masque la sémantique prod »).
- Baseline : `8f2569b` (frontmatter story). Statut story : `review`.
- Périmètre lu : ports `zcrud_core` (`z_local_store.dart`, `z_remote_store.dart`, barrel), adaptateurs `zcrud_firestore` (`hive_z_local_store.dart`, `firestore_z_remote_store.dart`, barrel, `pubspec.yaml`), tests (`hive_z_local_store_test.dart`, `firestore_z_remote_store_test.dart`), et l'adaptateur composé E5-1 (`firebase_z_repository_impl.dart`).

## Verdict global

**APPROUVÉ sous réserve** (aucun HIGH/MAJEUR). L'implémentation reproduit fidèlement les corrections débogées d'E5-1 : invariant corps `id`, `_isVisible` cohérent get/getAll/watch, décodage défensif AD-10, soft-delete hors-entité, isolation AD-5. Les stockage/tests utilisent Hive **sur disque réel** (`Hive.init(tmpdir)` + `jsonEncode/jsonDecode`), donc la sérialisation JSON prod est réellement exercée — le piège « fake en mémoire » est en grande partie évité. Restent 2 MEDIUM (cycle de vie du flux ; trou de test réouverture) et 3 LOW.

## Verdicts ciblés (demandés)

| Contrôle | Verdict | Preuve |
|---|---|---|
| Isolation Hive/Firebase (ports Dart pur, aucun type backend en signature publique, barrels propres, CORE OUT=0) | **OUI** | `z_local_store.dart`/`z_remote_store.dart` n'importent que `dartz show Unit` + types core neutres ; `Box` seulement en param de constructeur (indent 4, couture DI) et champs privés ; `firestore_z_remote_store.dart` n'importe même pas `cloud_firestore` ; barrels sans export backend ; `grep` imports hive/firebase dans `zcrud_core/lib` = 0. |
| `_isVisible` cohérent get / getAll / watch | **OUI** | `_isVisible(map)=map['is_deleted']==false` unique, routé par `getById` (hive:305), `_readVisible→_snapshot` (getAll hive:290 + watch hive:268). `is_deleted` absent → exclu partout (test `legacy1`). |
| Construction du flux gardée (throw synchrone converti) | **OUI** | `watchAll` : `_snapshot()` seed + `_box.watch().listen(...)` sous `try/catch` dans `onListen` → `controller.addError(_toFailure(e))` (hive:266-282). Le piège MEDIUM-1 d'E5-1 est traité. |
| Défensif prouvé sur cas RÉELS (pas seed propre) | **OUI** | Test AC5 sème 3 corrompus réels (JSON tronqué, valeur int non-String, `count` de mauvais type via `_seedRaw`) parmi 2 valides → `{ok1,ok2}` sans throw + logs non vides. `fromMapSafe` injecté prouvé (test dédié). |
| Frontière E5-2 respectée (aucun merge LWW / cascade ≤450 / orchestrateur / débounce) | **OUI** | Aucune méthode `sync()`/`merge()` ; `clear()` = purge de maintenance documentée (pas une voie de suppression métier) ; frontière E5-3/E5-4 documentée dans les 4 dartdocs. |

## Findings

### MEDIUM-1 — `watchAll()` : abonnement `box.watch()` + `StreamController` non libérés à l'annulation (pas de `onCancel`)
`hive_z_local_store.dart:263-286`. Le `StreamController` est créé avec `onListen:` **sans** `onCancel:`. Quand un consommateur annule son abonnement (ex. `.first`, changement d'écran), ni le `StreamController` ni la `StreamSubscription<BoxEvent>` de `_box.watch()` ne sont libérés — ils ne le sont **qu'au `dispose()`**. Sur un store à durée de vie longue (typiquement un singleton par kind), chaque `watchAll()` empile un contrôleur + un abonnement dans `_controllers`/`_subs` qui continuent de recevoir `_snapshot()` à chaque mutation (bufferisés sur un contrôleur single-subscription sans auditeur). Croissance non bornée.
- **Scénario** : un `ZListController` ré-abonne `watchAll()` à chaque (re)build d'écran sans disposer le store partagé → N abonnements `box.watch()` vivants recalculant `_snapshot()` sur chaque `put`.
- **Parité** : le même défaut existe dans E5-1 (`firebase_z_repository_impl.dart:412`, `snapshots().listen`) qui a passé la revue — un correctif cohérent (ajout d'un `onCancel` fermant le contrôleur + annulant la sub, dans les DEUX adaptateurs) est préférable à une correction isolée.
- **Remède** : `onCancel: () { unawaited(sub.cancel()); _subs.remove(sub); unawaited(controller.close()); _controllers.remove(controller); }` (ou documenter explicitement le contrat « un `watchAll()` = un cycle de vie borné par `dispose()` »). Reportable si justifié par la parité E5-1 (à corriger avec E5-1 hors périmètre E5-2).

### MEDIUM-2 — Trou de test « fake masque la prod » : aucune réouverture de box (persistance disque non prouvée)
`hive_z_local_store_test.dart`. Tous les tests opèrent dans **une seule session de box ouverte** ; après `box.put(...)` les lectures sont servies par le cache mémoire de Hive. Aucun test ne fait **close → reopen (même nom de box) → getById** pour prouver que l'entité survit réellement au cycle disque (fichier `.hive` relu et re-décodé). Le test `openBox` (factory) ouvre puis dispose (ferme) mais **ne rouvre jamais**. La sérialisation JSON elle-même EST couverte (jsonEncode/jsonDecode en session), mais un défaut ne se manifestant qu'à la réouverture (nom de box dérivé, corruption d'écriture, encodage de clé) passerait inaperçu — exactement la vigilance demandée pour cette story.
- **Remède** : ajouter un test `put → box.close()/Hive.close() → réouvrir zcrud_<kind> → getById restitue l'égal` (via `HiveZLocalStore.openBox` ou une nouvelle box de même nom). Faible coût, ferme le trou de fidélité prod.

### LOW-1 — Exceptions levées DANS le callback de `box.watch().listen` contournent le canal d'erreur
`hive_z_local_store.dart:269-270`. `onError:` n'intercepte que les erreurs du flux `box.watch()` lui-même, **pas** celles levées par le callback `(_) => controller.add(_snapshot())`. Si `_snapshot()` levait pendant un événement (ex. box fermée en cours de flux), l'erreur deviendrait une erreur asynchrone non gérée au lieu de `controller.addError`. Faible probabilité (décodage défensif ne throw pas ; une box fermée ferme aussi le flux `watch`). Parité E5-1 (`_decodeDocs` défensif). Remède : envelopper le corps du listener (`try { controller.add(_snapshot()); } catch (e,s) { controller.addError(_toFailure(e)); }`).

### LOW-2 — `dispose()` `void` + fermeture de box possédée non observable → test masqué par un `sleep(100ms)`
`hive_z_local_store.dart:394` (`unawaited(_box.close())`) et test `openBox` (`await Future.delayed(100ms)` avant `tearDown`/`Hive.close()`). Le contrat de port `dispose():void` rend la fermeture de la box **possédée** non attendable ; le test compense par un délai fixe pour éviter une double-fermeture concurrente. Pas un bug prod (l'app dispose au shutdown), mais le test est **temporellement fragile** (risque de flakiness sous charge). Remède possible : exposer un `Future<void> closeOwnedBox()` interne testable, ou synchroniser le `tearDown` sur l'état de la box plutôt que sur un délai.

### LOW-3 — `put` ressuscite une entité soft-deletée sans le documenter
`hive_z_local_store.dart:152-159` : `_encode` réécrit inconditionnellement `is_deleted:false`. Comme en E5-1 (LOW-4, « save ⇒ vivant »), un `put` sur un `id` soft-deleté le **rend de nouveau visible**. Comportement légitime et cohérent avec E5-1, mais le dartdoc de `HiveZLocalStore.put` ne le mentionne pas (E5-1 le documentait explicitement). Remède : une ligne de dartdoc sur `put`/`_encode` (« re-`put` d'une entité soft-deletée la ressuscite »).

## Points vérifiés SANS finding (adversarial)

- **AD-11 CacheFailure/ServerFailure** : local `_guard` → `Left(CacheFailure)` (jamais ServerFailure) ; remote délègue à E5-1 → `ServerFailure`. `null≠erreur` : clé absente → `NotFoundFailure`, box vide → `Right([])`. Zéro `catch(_){}` (uniquement `on ZFailure`/`on HiveError`/`on Object` typés + loggés).
- **Invariant clé↔corps** : `_encode` écrit toujours `map['id']=id` ; `box.put(id, jsonEncode(map))` ; test prouve `map['id']==clé` (éphémère et id fourni).
- **Soft-delete hors-entité** : `_setDeletedFlag` bascule `is_deleted`/`updated_at` (ISO-8601 via `DateTime.toUtc().toIso8601String()`) sans toucher aux champs métier (test le prouve : `title`/`count` intacts) ; jamais de `box.delete`.
- **Composition remote (AC11/12)** : `FirestoreZRemoteStore` délègue intégralement (`push→save`, `remoteDelete→softDelete`, `pull→getAll`, `watchAll→watchAll`) — composition, pas héritage (AD-4) ; n'importe pas `cloud_firestore` (test le prouve).
- **Isolation pubspec** : `hive`/`hive_flutter` uniquement dans `zcrud_firestore/pubspec.yaml` ; `zcrud_core/pubspec.yaml` sans hive/firebase (test AC3) ; CORE OUT=0.
- **Key Don'ts** : aucun secret ; dates ISO-8601 ; pas d'UI (RTL/ListView N/A) ; pas de `ListView(children)`.
- **Frontière** : aucune amorce de merge/cascade/débounce n'a fuité.

## Recommandation

Passer `done` après : (a) décision sur MEDIUM-1 (correction `onCancel` cohérente E5-1/E5-2 **ou** justification écrite de report par parité), (b) ajout du test de réouverture de box (MEDIUM-2). LOW-1..3 : correction si triviale, sinon consignés.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MEDIUM | ✅ **corrigé (Hive + parité Firestore E5-1)** | `onCancel` ajouté au `StreamController` dans `hive_z_local_store.dart:watchAll` ET `firebase_z_repository_impl.dart:_watchQuery` : annule l'abonnement source (`box.watch()`/`snapshots()`), le retire de `_subs`/`_controllers`, ferme — libération dès l'annulation du flux (plus seulement au `dispose()`), idempotent. 2 tests anti-fuite Hive (`activeSourceSubscriptions`/`activeStreamControllers` → 0 après cancel ; 5 cycles → 0). |
| 2 | MEDIUM | ✅ **corrigé** | Test persistance disque réelle : `put → box.close() → réouverture même chemin → getById/getAll restitue l'égal` (round-trip `.hive` JSON, pas cache en-session). |
| 3 | LOW-1 | ✅ corrigé | Corps du `listen` enveloppé try/catch → `controller.addError(_toFailure(...))` (Hive + parité Firestore). |
| 4 | LOW-2 | ✅ documenté | Dartdoc `dispose` (fermeture fire-and-forget, contrat port `void`) ; `sleep(100ms)` du test remplacé par attente déterministe sur `closedForTest`. |
| 5 | LOW-3 | ✅ documenté | Dartdoc `put`/`_encode` : re-`put` d'une entité soft-deletée la ressuscite (cohérent E5-1, merge LWW = E5-3). |

**Vérif verte rejouée (orchestrateur, sur disque)** : `melos analyze` RC=0 (0 issue) · `flutter test` zcrud_firestore **58/58** (dont close/reopen + 2 anti-fuite) · non-régression E5-1 (tests MAJEUR watch/dispose OK) · `melos verify` RC=0 (**CORE OUT=0**, ACYCLIQUE) · `melos list=14`.

**Verdict final** : 2 MEDIUM corrigés (dont parité E5-1) + 3 LOW traités. Story E5-2 → **done**.
