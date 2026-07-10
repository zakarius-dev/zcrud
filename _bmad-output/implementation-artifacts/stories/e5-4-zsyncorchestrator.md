# Story 5.4: `ZSyncOrchestrator` — le *quand* de l'offline-first

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **intégrateur d'application zcrud** (DODLP/lex_douane) qui a déjà des dépôts offline-first (E5-3),
I want un **orchestrateur de synchronisation** `ZSyncOrchestrator` (dans `zcrud_core`, Dart pur) qui **tient un registre** de dépôts `ZSyncableRepository` et **déclenche leur `sync()`** aux bons moments — au **login** et à la **reconnexion réseau**, avec un **débounce ~400 ms** — de façon **best-effort** et **tolérante à l'échec partiel** (le `sync()` d'un dépôt qui échoue **n'arrête pas** les autres, l'erreur est **tracée**, pas de propagation d'exception),
so that le *quand* (l'orchestration temporelle : cadencement, débounce, coalescence des rafales de déclenchement, gate d'activation) soit **strictement séparé** du *comment* (le merge LWW / soft-delete / propagation bornée, déjà livré par chaque dépôt en E5-3), sans qu'aucun **gestionnaire d'état** ni type **backend** n'entre dans `zcrud_core`, et **sans dépendre d'un vrai `Timer` temps-réel** dans les tests (couture d'horloge/scheduler injectable + flush synchrone).

## Contexte épic (E5)

**E5 — Backend Firestore & offline-first (`zcrud_firestore`).** Objectif : adaptateur Firestore débogué + patron offline-first. Couvre FR-12/FR-13. AD-5/AD-9/AD-11.
Phase : **E5-1/E5-2 = MVP** (repo Firestore + `ZLocalStore`/`ZRemoteStore`) ; **E5-3/E5-4 = v1.x** — leur consommateur est la **donnée d'étude E9** (aucun écran MVP ne les requiert ; harnais de validation livré avec E9-4). [Source: epics.md#E5, ligne 96]

**E5-4 est la DERNIÈRE story d'E5.** Elle pose **le *quand*** au-dessus du **comment** livré par E5-3 :

- **E5-1 (done)** — `FirebaseZRepositoryImpl<T>` : adaptateur Firestore pur-distant.
- **E5-2 (done)** — ports neutres `ZLocalStore<T>`/`ZRemoteStore<T>` + adaptateurs Hive/Firestore.
- **E5-3 (done)** — `ZSyncableRepository<T>` (sur-port ajoutant `Future<ZResult<Unit>> sync()`) + `ZOfflineFirstRepository<T>` (compose local+distant, merge **LWW** sur `updatedAt`, tombstones, soft-delete hors-entité, propagation bornée ≤ 450, **`Right(unit)` si déconnecté**). `sync()` est un **appel one-shot** ; **rien** dans E5-3 ne décide *quand* l'appeler ni sur *quels* dépôts.

> **Frontière que E5-4 franchit — assumée en toutes lettres par E5-3 :** *« E5-4 : `ZSyncOrchestrator` (déclenche `sync()` d'un **ensemble** de dépôts enregistrés sur login/reconnexion **débouncée ~400 ms**, best-effort, **échec partiel toléré**). Hors périmètre [E5-3] — E5-3 n'a **ni** débounce **ni** registre multi-dépôts. »* [Source: e5-3-offline-first-lww-soft-delete.md, « Frontière de story », lignes 185-190 ; z_syncable_repository.dart:19-23]

## Frontière de portée — E5-3 vs E5-4 (NON négociable)

| | E5-3 (livrée) | E5-4 (cette story) |
|---|---|---|
| **Le *comment*** ✅ | composition local+distant ; merge LWW ; propagation soft-delete ; `sync()` **par dépôt** ; `Right(unit)` si déconnecté ; lot ≤ 450 | — (délégué, **jamais** re-implémenté) |
| **Le *quand*** ❌ | **PAS là** | `ZSyncOrchestrator` : **registre** de `ZSyncableRepository` ; déclenchement au **login** + **reconnexion** ; **débounce ~400 ms** (coalescence des rafales) ; **best-effort** ; **échec partiel toléré** ; **gate** d'activation ; couture connectivité |

E5-4 **n'introduit aucune** logique de merge, aucun accès store, aucun type backend, aucun `LWW`. Elle **appelle** `repo.sync()` et ne fait **que** décider *quand* et *sur quels dépôts*. [Source: architecture.md#AD-9, ligne 100 ; canonical-schema.md#§7, ligne 307]

## Décision d'architecture tranchée dans cette story — placement de `ZSyncOrchestrator`

**Retenu : `ZSyncOrchestrator` vit dans `zcrud_core`** (`lib/src/domain/sync/z_sync_orchestrator.dart`), Dart pur. Justification :

1. **Backend-agnostique par nature.** L'orchestrateur ne connaît que le sur-port neutre `ZSyncableRepository<T>` (déjà dans `zcrud_core`) et appelle sa seule méthode `sync()`. Il **ne touche jamais** un store, un `WriteBatch`, un `Box`, un `Timestamp`, une limite Firestore. La borne `450` (backend-spécifique, AD-5) reste **exclusivement** dans `zcrud_firestore` — E5-4 **ne la voit pas**.
2. **Le débounce est du pur `dart:async`.** Le cadencement s'obtient avec un `Timer` de `dart:async` — SDK Dart, **aucune dépendance** ajoutée. `dart:async` est **déjà** importé dans `zcrud_core` (`z_list_controller.dart`, `z_row_action.dart`, `z_app_file_field_widget.dart`). [Vérifié sur disque.]
3. **Aucun gestionnaire d'état, aucune connectivité-plugin.** L'orchestrateur **n'importe pas** `connectivity_plus`, `get`, `flutter_riverpod`, `provider`. La **source** du signal réseau/login est fournie par l'**app** via des **coutures** (méthodes de déclenchement + seam `isConnected` optionnel), exactement comme E5-3 injecte `isConnected` (AD-2/AD-6/AD-15). Le binding manager-spécifique (ex. `StudySyncManager` keepAlive côté DODLP/lex, canonique §7) branchera ces coutures — **hors** de `zcrud_core`.
4. **Cohérent canonique/architecture.** *« `ZSyncOrchestrator` sépare le quand du comment »* (AD-9) et *« `ZSyncOrchestrator` (porte `StudySyncManager`, keepAlive) : déclenche `sync()` d'un ensemble de repos enregistrés sur login + reconnexion débouncée, best-effort (un échec n'arrête pas les autres) »* (canonique §7, ligne 307). Le contrat est **domaine**, l'orchestrateur donc **core**.

**Faisabilité d'isolation confirmée** : `zcrud_core/pubspec.yaml` reste inchangé (aucune dépendance ajoutée) ; le gate `graph_proof.py` (`CORE OUT=0`) reste vert ; aucun symbole `hive`/`cloud_firestore`/gestionnaire-d'état n'apparaît. **E5-4 est le SEUL workstream core-writer en vol** (autorisé à éditer `zcrud_core` : uniquement l'ajout du nouveau fichier + un export barrel).

## Constat de conception préalable (à lire AVANT de coder)

1. **Le débounce doit coalescer les rafales.** Login puis 3 événements « connectivité rétablie » en 200 ms ne doivent produire **qu'un seul** cycle de sync (trailing debounce : chaque déclenchement **réarme** le timer ; le cycle part `debounce` après le **dernier** déclenchement). Sinon on martèle Firestore.

2. **Un vrai `Timer` de 400 ms rend les tests lents et flaky.** → l'orchestrateur **doit** être testable **sans horloge murale** : (a) **couture de fabrique de timer** injectable (défaut = `Timer` réel ; test = fabrique contrôlable qui capture le callback et le déclenche à la demande) **et** (b) méthode **`flushPending()`** (`@visibleForTesting`) qui exécute **immédiatement** un cycle en attente. Le test pilote le temps, pas `Future.delayed`.

3. **Échec partiel = itération protégée.** Le cycle itère le registre ; **chaque** `repo.sync()` est encapsulé (`try/catch` + garde du `Left`). Un `Left`/une exception d'un dépôt est **loggé** et **n'interrompt pas** la boucle : les dépôts suivants sont **quand même** synchronisés. Aucune exception ne remonte hors de l'orchestrateur.

4. **`sync()` d'E5-3 avale déjà l'offline en `Right(unit)`.** L'orchestrateur reçoit donc `Right(unit)` même quand le distant est injoignable — normal. Le rôle « offline » de l'orchestrateur est **en amont** : ne **pas déclencher** de cycle quand `isConnected?.call() == false` (court-circuit → aucun `sync()` appelé, résultat `Right(unit)`), pour ne pas réveiller inutilement les dépôts. La distinction fine **réseau vs serveur** (permission/quota) — **dette E5-4 héritée d'E5-3** (MEDIUM-2 de `code-review-e5-3.md`) — est traitée ici **au niveau du déclenchement** (l'app câble une **vraie** source de connectivité sur la couture) et **non** en modifiant la sémantique de `repo.sync()` (qui resterait additive/non-cassante) : voir AC10 + Ambiguïtés.

## Acceptance Criteria

### Contrats & orchestration (dans `zcrud_core`, Dart pur — AD-5/AD-9/AD-11/AD-2)

1. **`ZSyncOrchestrator` — nouveau composant core, Dart pur.** Nouveau fichier `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart`, exporté par le barrel `zcrud_core.dart` (ordre alpha, après `z_sync_meta.dart`). **Aucun** import backend (`hive`/`cloud_firestore`/`firebase_core`) ni gestionnaire d'état (`get`/`flutter_riverpod`/`provider`) ni plugin connectivité (`connectivity_plus`). Seuls imports autorisés : `dart:async` (Timer), `package:dartz` (`Unit`), et les types core (`ZSyncableRepository`, `ZResult`/`ZFailure`, `Unit`). `zcrud_core/pubspec.yaml` **inchangé** ; `graph_proof.py` `CORE OUT=0` reste vert. *(AD-1, AD-5, AD-15)*

2. **Registre de dépôts `ZSyncableRepository`.** L'orchestrateur expose `void register(ZSyncableRepository repo)` et `void unregister(ZSyncableRepository repo)`. Le registre est un ensemble **sans doublon par identité** (ré-`register` du même instance = no-op ; un dépôt n'est **jamais** synchronisé deux fois par cycle). Un accès en lecture testable expose le **nombre** de dépôts enregistrés (`@visibleForTesting int get registeredCount` ou équivalent). Le type stocké est le **sur-port neutre** `ZSyncableRepository` (générique effacé côté registre — l'orchestrateur n'a besoin que d'appeler `sync()`), **jamais** un type concret d'adaptateur. *(AD-4, AD-9)*

3. **Déclenchement débouncé ~400 ms (login + reconnexion).** L'orchestrateur expose des **déclencheurs** sémantiques — a minima `void onLogin()` et `void onReconnected()` (ou un `void requestSync({ZSyncTrigger reason})` couvrant les deux motifs) — qui **planifient** un cycle de sync après un **débounce** de **`400 ms` par défaut** (constante nommée, surchargeable par le constructeur : `Duration debounce = const Duration(milliseconds: 400)`). **Trailing debounce** : plusieurs déclencheurs dans la fenêtre **réarment** le timer et **coalescent** en **un seul** cycle, planifié `debounce` après le **dernier** déclencheur. Un test **avec fabrique de timer contrôlable** prouve que **N déclencheurs rapprochés → 1 seul cycle** (chaque `repo.sync()` appelé **exactement une fois**). *(AD-9 ; canonical-schema.md#§7 « reconnexion débouncée 400 ms »)*

4. **Séparation stricte *quand* / *comment*.** L'orchestrateur **n'appelle QUE** `repo.sync()` sur les dépôts enregistrés — **aucune** référence à `ZLocalStore`/`ZRemoteStore`/`ZLwwResolver`/`applyMerged`/merge/lot/`450`. Un test/inspection prouve que la **seule** interaction avec un dépôt passe par `sync()` (dépôt espion : `sync()` est la **seule** méthode invoquée par un cycle). *(AD-9, séparation quand/comment)*

5. **Best-effort + échec partiel toléré (cœur de la story).** Un cycle itère **tous** les dépôts enregistrés ; **chaque** `sync()` est isolé : un dépôt renvoyant `Left(ZFailure)` **ou** levant une **exception** est **loggé** (via le log injecté, jamais no-op muet en prod côté app) et **n'interrompt pas** le cycle — les dépôts suivants sont **quand même** synchronisés. **Aucune** exception ne s'échappe de l'orchestrateur. Un test **multi-dépôts** avec un dépôt central qui échoue (Left) **et** un qui **throw** prouve que **tous** les autres dépôts ont **quand même** vu leur `sync()` appelé, et que l'erreur a été **tracée** (log capturé). *(AD-9 « un échec n'arrête pas les autres » ; AD-11 jamais de `catch(_){}` muet)*

6. **`Right(unit)` si déconnecté — pas de déclenchement inutile.** Couture connectivité **optionnelle** `Future<bool> Function()? isConnected` (défaut `null` — jamais court-circuité, comme E5-3). Quand un cycle s'exécute et que `isConnected != null && !await isConnected()` : **aucun** `repo.sync()` n'est appelé, le cycle se termine **proprement** en **`Right(unit)`** (loggé « hors-ligne — cycle sauté »). Un test prouve que `isConnected()==false` → **zéro** appel `sync()` + résultat `Right(unit)`. *(AD-9, AD-11 ; miroir de la couture E5-3)*

7. **Gate d'activation.** Drapeau `bool enabled` (défaut **`true`**) — canonique §7 : *« Gate par un flag d'activation »*. `enabled == false` → tout déclencheur **ne planifie rien** et tout cycle est **no-op** (`Right(unit)`, aucun `sync()`, aucun timer armé). Modifiable après construction (`set enabled(bool)`), ce qui **annule** un cycle en attente si passé à `false`. Un test prouve que `enabled=false` → aucun cycle même après flush. *(canonical-schema.md#§7, ligne 307)*

8. **Cycle immédiat non-débouncé `syncNow()` (pour login-forcé / test / E9).** `Future<ZResult<ZSyncRunReport>> syncNow()` exécute **immédiatement** (sans débounce) un cycle best-effort sur tous les dépôts et **retourne** un rapport agrégé **`ZSyncRunReport`** (value object neutre : `int attempted`, `int succeeded`, `int failed`, éventuellement la liste des `ZFailure` collectées — **jamais** de type backend). Best-effort : `syncNow()` renvoie **`Right(report)`** même si des dépôts ont échoué (l'échec partiel est **dans** le rapport, pas un `Left` global) ; un `Left` global n'est réservé **à rien** au niveau orchestrateur (best-effort intégral). Un test prouve `attempted=3, succeeded=2, failed=1` sur un mix succès/échec **sans** interruption. *(AD-9, AD-11)*

9. **Débounce testable SANS `Timer` temps-réel.** Deux coutures **obligatoires** : (a) **fabrique de timer injectable** `ZSyncTimerFactory` (typedef `ZCancelableTimer Function(Duration, void Function())` ou équivalent), défaut = wrapper sur `Timer` de `dart:async` ; en test on injecte une fabrique qui **capture** `(durée, callback)` sans horloge réelle et permet de **déclencher** le callback à la demande. (b) **`@visibleForTesting Future<void> flushPending()`** : exécute **immédiatement** le cycle actuellement planifié (le cas échéant) et **annule** le timer en attente, de manière **awaitable** (pour observer le rapport). Les tests **n'utilisent JAMAIS** un vrai délai de 400 ms (`Future.delayed`/`Timer` réel interdits dans la suite de débounce). *(Testabilité — objectif non-négociable de la story)*

10. **Dette E5-3 (réseau vs serveur) traitée au bon niveau + tracée.** L'orchestrateur adresse la **dette MEDIUM-2 d'E5-3** (« tout `Left(ServerFailure)` distant assimilé à offline ») **sans** modifier la sémantique additive de `repo.sync()` : la **couture `isConnected`** est le **point d'injection** de la **vraie** source réseau de l'app (l'app câble sa connectivité authentique — le « login/reconnexion » du canonique) ; ainsi un cycle ne part que lorsque le réseau est réellement présent, et une erreur serveur applicative (permission/quota) remontée par un dépôt est **collectée dans `ZSyncRunReport.failed` + loggée** (visible), **jamais** silencieusement noyée en « offline » au niveau orchestrateur. Le dartdoc **documente explicitement** cette frontière : distinction fine par-dépôt réseau/serveur = évolution future (nécessiterait un changement de contrat `sync()`, **hors** périmètre additif E5-4). Un test prouve qu'un dépôt renvoyant un `Left(ServerFailure)` est **compté `failed`** dans le rapport (pas masqué). *(code-review-e5-3.md MEDIUM-2 ; AD-11)*

11. **Cycle de vie propre (`dispose`).** `void dispose()` **annule** tout timer en attente, **vide** le registre (ou le rend inerte) et rend l'orchestrateur inerte (déclencheurs post-`dispose` = no-op, aucun timer relancé, aucune fuite de `Timer`). `dispose()` **ne** dispose **pas** les dépôts enregistrés (leur cycle de vie appartient à l'app/binding — l'orchestrateur n'en est **pas** propriétaire). Un test prouve qu'après `dispose()`, un `onReconnected()` n'arme aucun timer et `flushPending()` est un no-op. *(AD-2 lifecycle ; AD-9)*

### Isolation & vérif

12. **ISOLATION AD-5/AD-15 — aucun type backend ni gestionnaire d'état ne fuit.** Aucune signature publique de `ZSyncOrchestrator`/`ZSyncRunReport` n'expose `Box`/`Timestamp`/`Filter`/`FirebaseException`/`WidgetRef`/`GetxController`/`Ref` ni aucun symbole `hive`/`cloud_firestore`/`get`/`flutter_riverpod`/`provider`. Les seuls types publics : `ZSyncableRepository`, `ZResult`/`ZFailure`, `Unit`, `Duration`, primitifs, et les nouveaux `ZSyncRunReport`/typedefs de couture. Le gate de signatures publiques (miroir E5-3 AC14) couvre le nouveau fichier. *(AD-5, AD-15)*

13. **Vérif verte + gates CI.** `melos run generate` OK (sans effet : pas de codegen dans `zcrud_core`) → `dart analyze packages/zcrud_core` RC=0 → `flutter test packages/zcrud_core` RC=0 (+ repo-wide au gate d'epic). Gates CI (anti-`reflectable`, scan de secrets, contrôle codegen, rétro-compat sérialisation, graphe `CORE OUT=0`, gate:compat) **verts** avant `review`. **Aucune régression** des tests E5-1/E5-2/E5-3 : E5-4 est un **ajout** (nouveau fichier + un export barrel), il ne modifie **aucun** contrat existant. *(Stack ; AD-1)*

## Tasks / Subtasks

- [x] **T1. Value object `ZSyncRunReport` (core, pur)** (AC: 8, 12) — fichier dédié `z_sync_run_report.dart` (réutilisable E9), invariant assert `attempted == succeeded + failed`, `==`/`hashCode`/`toString`, égalité de liste PUR-DART (`_listEquals`, sans `foundation`).
- [x] **T2. Coutures de temps & log (core, pur)** (AC: 5, 9) — `ZCancelableTimer`/`ZSyncTimerFactory` (défaut = wrapper `Timer` réel `_RealCancelableTimer`) + `ZSyncOrchestratorLog`/`_noopLog` (miroir E5-3).
- [x] **T3. `ZSyncOrchestrator` — registre + gate + connectivité** (AC: 1, 2, 6, 7, 11) — ctor complet ; `Set<ZSyncableRepository<dynamic>>` (identité) ; `registeredCount` (test-only) ; `set enabled` annule le timer ; `dispose()` inerte, ne dispose pas les dépôts.
- [x] **T4. Déclenchement débouncé + coalescence** (AC: 3, 9) — `onLogin()`/`onReconnected()` → `_schedule` (trailing debounce, réarme+annule) ; `flushPending()` awaitable.
- [x] **T5. Cycle best-effort + échec partiel** (AC: 4, 5, 6, 8, 10) — `_runCycle` iteration protégée (copie du registre, `try/on Object catch`, `fold`) ; `syncNow()` → `Right(report)` ; voie débouncée fire-and-forget + log résumé.
- [x] **T6. Barrel + isolation** (AC: 1, 12) — exports `z_sync_orchestrator.dart` + `z_sync_run_report.dart` (ordre alpha après `z_sync_meta.dart`) ; `graph_proof.py` `CORE OUT=0` vert ; `domain_purity_test` vert (pur-Dart strict).
- [x] **T7. Tests core (unitaires purs, SANS Timer réel)** (AC: tous) — fabrique `_FakeTimerFactory`/`_FakeTimer` (aucun `Future.delayed`/`Timer` réel) ; `_SpyRepo` (`noSuchMethod → UnimplementedError` prouvant AC4) ; 20 tests orchestrateur + 4 tests report.
- [x] **T8. Non-régression + gates** (AC: 13) — `dart analyze packages/zcrud_core` RC=0 ; `flutter test packages/zcrud_core` 604 pass (580 + 24) ; E5-3 non touché ; `graph_proof.py` `CORE OUT=0`.
- [x] **T9. Documentation & frontière** (AC: 4, 10) — dartdoc complet (quand vs comment, débounce/coalescence, best-effort/échec partiel, offline, gate, couture `isConnected` = vraie source réseau/dette E5-3 MEDIUM-2, non-propriété au dispose, renvoi `StudySyncManager`).

## Dev Notes

### Contexte architectural (à respecter absolument)

- **AD-9 (offline-first standardisé).** *« … `ZSyncOrchestrator` sépare le quand du comment. »* E5-4 = **le quand** : registre + débounce + best-effort + échec partiel. Le **comment** (`sync()` per-dépôt) est **livré, immuable, appelé tel quel**. [Source: architecture.md#AD-9, ligne 100]
- **AD-5 (domaine backend-agnostique).** `ZSyncOrchestrator` vit dans `zcrud_core` **sans** type backend ; la borne `450`/`WriteBatch` (Firestore) reste dans `zcrud_firestore` — E5-4 **ne la voit jamais**. [Source: architecture.md#AD-5, lignes 79-80]
- **AD-2/AD-6/AD-15 (aucun gestionnaire d'état dans le cœur).** L'orchestrateur **n'importe** ni `get`, ni `flutter_riverpod`, ni `provider`, ni `connectivity_plus`. La source login/réseau est **injectée** par l'app via coutures ; le binding manager-spécifique (`StudySyncManager` keepAlive) vit **hors** de `zcrud_core`. [Source: architecture.md#AD-15 ; CLAUDE.md « Key Don'ts »]
- **AD-11 (erreurs & flux nus).** `ZResult<T> = Either<ZFailure,T>` ; `syncNow()` → `ZResult<ZSyncRunReport>`. **Jamais** `catch(_){}` muet : chaque échec de dépôt est **loggé** (log injecté) et **compté**. [Source: architecture.md#AD-11 ; z_failure.dart:93]
- **Dette E5-3 (MEDIUM-2) à intégrer.** `code-review-e5-3.md` : *« la distinction réseau vs serveur (pour ne re-Right que le réseau) est portée par E5-4 (ZSyncOrchestrator + typage connectivité). »* → E5-4 la traite **au déclenchement** (couture `isConnected` = vraie source réseau de l'app) + **rend visibles** les échecs serveur dans `ZSyncRunReport.failed`, **sans** casser le contrat additif de `sync()`. [Source: code-review-e5-3.md MEDIUM-2 & « Résolution »]

### Signatures EXACTES à réutiliser (citées depuis le disque)

**`ZSyncableRepository<T extends ZEntity>`** (`packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart`) — **seule** surface que l'orchestrateur touche :
```
abstract class ZSyncableRepository<T extends ZEntity> extends ZRepository<T> {
  Future<ZResult<Unit>> sync(); // Right(unit) si déconnecté (best-effort, AD-9)
}
```
> L'orchestrateur stocke des `ZSyncableRepository` **avec generic effacé** (`ZSyncableRepository<dynamic>` / borne `ZEntity`) — il n'a besoin que de `sync()`. Vérifier que le registre n'exige **pas** de connaître `T`.

**`ZResult<T>`** (`packages/zcrud_core/lib/src/domain/failures/z_failure.dart:93`) : `typedef ZResult<T> = Either<ZFailure, T>;`. `Unit`/`unit`/`Right`/`Left` viennent de `package:dartz`.

**`ZFailure`** (`.../failures/z_failure.dart`) : hiérarchie avec `==`/`hashCode` + `.message`. `ZSyncRunReport.failures` collecte des `ZFailure` (neutres).

**Pattern de log injecté** — miroir **exact** d'E5-3 (`z_offline_first_repository.dart:35-41`) :
```
typedef ZSyncOrchestratorLog = void Function(String message, {Object? error, StackTrace? stackTrace});
void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}
```

**Pattern de couture connectivité** — miroir **exact** d'E5-3 (`z_offline_first_repository.dart:57,68,206-210`) : `Future<bool> Function()? isConnected` (défaut `null` → jamais court-circuité).

### Débounce — squelette de référence (à adapter, pas à copier tel quel)

```
// trailing debounce, timer réarmé à chaque déclencheur
void _schedule() {
  if (!_enabled) return;
  _pending?.cancel();
  _pending = _timerFactory(_debounce, () { _pending = null; _runCycleFireAndForget(); });
}

Future<ZSyncRunReport> _runCycle() async {
  if (!_enabled) return const ZSyncRunReport.empty();
  final connected = _isConnected == null ? true : await _isConnected!();
  if (!connected) { _log('sync: hors-ligne — cycle sauté (Right)'); return const ZSyncRunReport.empty(); }
  var ok = 0, failed = 0; final failures = <ZFailure>[];
  for (final repo in _repos.toList(growable: false)) { // copie : safe vs unregister concurrent
    try {
      final r = await repo.sync();
      r.fold((f) { failed++; failures.add(f); _log('sync repo échoué: ${f.message}'); }, (_) => ok++);
    } on Object catch (e, s) { failed++; _log('sync repo en exception', error: e, stackTrace: s); }
  }
  return ZSyncRunReport(attempted: ok + failed, succeeded: ok, failed: failed, failures: failures);
}
```
> **Attention** : le callback du timer est **synchrone** (`void`) mais `_runCycle` est `async` → pour la voie débouncée on **fire-and-forget** `_runCycle()` (log du résumé, pas de retour) ; pour `syncNow()`/`flushPending()` on **await** `_runCycle()`.

### Testabilité — fabrique de timer contrôlable (référence)

```
class _FakeTimer implements ZCancelableTimer { // ou impl minimal
  _FakeTimer(this.duration, this.callback);
  final Duration duration; final void Function() callback;
  bool _cancelled = false; bool get isCancelled => _cancelled;
  void fire() { if (!_cancelled) callback(); }
  @override void cancel() => _cancelled = true;
}
// fabrique injectée : capture le dernier timer créé pour le piloter
```
> **Alternative acceptable** : `package:fake_async` (`fakeAsync((async) { ...; async.elapse(400ms); })`) si déjà dispo côté dev_dependencies — mais la **couture de fabrique + `flushPending()`** reste **exigée** (AC9) pour ne pas dépendre d'un vrai `Timer` et rendre le débounce pilotable dans un test unitaire pur.

### Réutilisation E5-3 (à imiter, PAS réinventer)

- **Log injecté no-op** (`ZOfflineFirstLog`/`_noopLog`) → même forme pour `ZSyncOrchestratorLog`.
- **Couture `isConnected`** (défaut `null`, court-circuit `Right`) → même sémantique, au niveau **cycle**.
- **`try/catch` best-effort** (`_bestEffortRemote`, `z_offline_first_repository.dart:178-190`) → même esprit : logguer + **avaler** l'échec **d'un** dépôt sans casser la boucle (mais ici on **compte** l'échec dans le rapport).

### Frontière de story (ne PAS déborder)

- **E5-4 (cette story)** : `ZSyncOrchestrator` (registre + débounce 400 ms + login/reconnexion + best-effort + échec partiel + gate + couture connectivité + `syncNow`/`flushPending`) + `ZSyncRunReport`, **dans `zcrud_core`**.
- **HORS périmètre** : (a) **modifier `repo.sync()`** ou la sémantique offline d'E5-3 (additif, gelé) ; (b) une **vraie source de connectivité** (`connectivity_plus`) ou un **listener** temps-réel — c'est le **binding applicatif** (`StudySyncManager` keepAlive, DODLP/lex) qui câble login/réseau sur les coutures, **hors core** ; (c) la **cascade domaine** parent→enfants (E9) ; (d) la distinction fine réseau/serveur **par changement de contrat** `sync()` (évolution future documentée).

### Project Structure Notes

- **Nouveaux (core)** : `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart` (+ éventuel `z_sync_run_report.dart`) ; export au barrel `zcrud_core.dart` (ordre alpha, après `z_sync_meta.dart` ligne 94).
- **Modifiés (core)** : `packages/zcrud_core/lib/zcrud_core.dart` (exports).
- **Tests** : `packages/zcrud_core/test/domain/sync/z_sync_orchestrator_test.dart` (+ `z_sync_run_report_test.dart` si fichier dédié).
- **Aucun** ajout de dépendance à `zcrud_core/pubspec.yaml`. **Aucune** modification de `zcrud_firestore`. Nommage : types publics préfixés `Z` ; fichiers snake_case ; impl sous `lib/src/`.

### Testing standards

- Framework : `flutter_test` (le package `zcrud_core` teste sous `flutter test`). **Tests unitaires purs** : aucun I/O, **aucun `Timer` réel**, aucun `Future.delayed` dans la suite débounce → fabrique de timer contrôlable + `flushPending()`.
- Couverture obligatoire mappée aux ACs : registre (AC2), débounce/coalescence N→1 (AC3), séparation quand/comment (AC4), échec partiel Left+throw sans interruption (AC5), offline→0 sync (AC6), gate enabled=false (AC7), `syncNow` report agrégé (AC8), testabilité sans Timer (AC9), échec serveur compté `failed` (AC10), dispose inerte + dépôts non disposés (AC11), isolation signatures (AC12).
- Gates CI (E1-3/E2-10) : anti-`reflectable`, scan de secrets, contrôle codegen, rétro-compat sérialisation, graphe `CORE OUT=0`, gate:compat — **verts avant `review`** ; `melos run analyze` **ET** `flutter test` **repo-wide** au gate d'epic (une régression cross-package ne se voit que repo-wide).

### References

- [Source: epics.md#E5 Story E5-4 (ligne 101)] déclenche `sync()` des dépôts enregistrés (login/reconnexion débouncée), best-effort ; sépare quand/comment ; `Right(unit)` si déconnecté ; **échec partiel** (un dépôt échoue → les autres continuent, erreur tracée, pas d'arrêt global) (AD-9).
- [Source: architecture.md#AD-9 (lignes 97-100)] offline-first standardisé ; `ZSyncOrchestrator` sépare le *quand* du *comment*.
- [Source: architecture.md#AD-5 (lignes 79-80)] domaine backend-agnostique ; borne `450`/`WriteBatch` restent hors `zcrud_core`.
- [Source: architecture.md#AD-11] `Either`/flux nus ; jamais de `catch(_){}` muet.
- [Source: architecture.md#AD-15 ; CLAUDE.md] aucun gestionnaire d'état dans le cœur ; coutures d'injection.
- [Source: docs/canonical-schema.md#§7 (ligne 307)] `ZSyncOrchestrator` (porte `StudySyncManager`, keepAlive) : déclenche `sync()` d'un ensemble de repos enregistrés sur login + reconnexion débouncée, best-effort (un échec n'arrête pas les autres) ; sépare quand/comment ; **gate par un flag d'activation**.
- [Source: docs/canonical-schema.md#§4 (ligne 166)] `StudySyncManager` (keepAlive) : QUAND (login + reconnexion débouncée 400 ms, best-effort) délégué au COMMENT (merge/listener) de chaque repo.
- [Source: packages/zcrud_core/lib/src/domain/ports/z_syncable_repository.dart] sur-port `sync()` — **seule** surface appelée ; frontière E5-3/E5-4 en dartdoc.
- [Source: packages/zcrud_firestore/lib/src/data/z_offline_first_repository.dart:35-41,57,178-190,206-210] patrons à imiter : log injecté no-op, couture `isConnected`, `try/catch` best-effort, court-circuit offline `Right(unit)`.
- [Source: e5-3-offline-first-lww-soft-delete.md « Frontière de story » lignes 185-190] E5-4 = registre multi-dépôts + débounce, explicitement hors E5-3.
- [Source: code-review-e5-3.md MEDIUM-2 & « Résolution »] dette réseau vs serveur portée par E5-4 (couture connectivité + visibilité des échecs dans le rapport).
- [Source: packages/zcrud_core/lib/src/domain/failures/z_failure.dart:93] `typedef ZResult<T> = Either<ZFailure,T>`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart analyze packages/zcrud_core` → **No issues found!** (RC=0).
- `flutter test packages/zcrud_core` → **All tests passed! 604** (580 pré-existants + 24 nouveaux ; 0 régression).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK**.
- `domain_purity_test.dart` → **vert** (correction : `@visibleForTesting`/`@immutable`/`listEquals` de `package:flutter/foundation.dart` retirés — la couche `lib/src/domain` reste PUR-DART, `package:dartz` seul externe autorisé ; annotations remplacées par docstrings « test only », `listEquals` par `_listEquals` maison).

### Completion Notes List

- **Placement confirmé** : `zcrud_core` Dart pur (Q1) — `CORE OUT=0` préservé, `pubspec.yaml` inchangé, aucun import backend/manager/connectivité **ni Flutter**.
- **API de déclenchement** : `onLogin()`/`onReconnected()` sémantiques retenus (Q2).
- **`syncNow()`** retourne `ZResult<ZSyncRunReport>` (Q3) — best-effort intégral (jamais `Left` global, l'échec partiel est **dans** le rapport).
- **Testabilité** : couture fabrique de timer injectable + `flushPending()` awaitable (Q4) — **aucun** `Timer`/`Future.delayed` réel dans la suite débounce.
- **Dette E5-3 MEDIUM-2** : traitée au **déclenchement** (couture `isConnected` = vraie source réseau app) + échecs serveur **comptés `failed` + loggés** (jamais noyés) — sans modifier `sync()` (Q5).
- **`dispose()`** non-propriétaire des dépôts (Q6) — prouvé par test (`repo.disposed == false`).
- **Édition strictement ADDITIVE** : nouveau code uniquement (2 fichiers src + 2 tests + 2 lignes d'export barrel) ; aucun contrat E5-1/E5-2/E5-3 modifié.

### File List

**Nouveaux (zcrud_core)**
- `packages/zcrud_core/lib/src/domain/sync/z_sync_orchestrator.dart`
- `packages/zcrud_core/lib/src/domain/sync/z_sync_run_report.dart`
- `packages/zcrud_core/test/domain/sync/z_sync_orchestrator_test.dart`
- `packages/zcrud_core/test/domain/sync/z_sync_run_report_test.dart`

**Modifiés (zcrud_core)**
- `packages/zcrud_core/lib/zcrud_core.dart` (2 exports additifs E5-4 : `z_sync_orchestrator.dart`, `z_sync_run_report.dart`)

## Questions / Ambiguïtés détectées (pour dev-story / code-review)

1. **Placement de `ZSyncOrchestrator` : `zcrud_core` (retenu) vs `zcrud_firestore`.** Retenu : **`zcrud_core`** — l'orchestrateur est **backend-agnostique** (ne touche que le sur-port neutre `ZSyncableRepository.sync()` + un `Timer` de `dart:async`), aucune dépendance ajoutée, `CORE OUT=0` préservé. La borne `450` (Firestore) **reste** dans `zcrud_firestore`. À **confirmer en dev-story** : re-jouer `graph_proof.py` après ajout ; si un import backend s'avérait nécessaire (il ne devrait pas), **re-trancher** vers `zcrud_firestore`. **E5-4 est le seul core-writer en vol** (édition core autorisée : nouveau fichier + export barrel).
2. **API de déclenchement : `onLogin()`/`onReconnected()` (retenu) vs `requestSync({ZSyncTrigger reason})` unique.** Retenu : exposer **des méthodes sémantiques** (lisibilité côté binding). Alternative : une seule `requestSync(reason)` + enum `ZSyncTrigger { login, reconnected, manual }`. Les deux sont débouncées de la même façon ; à trancher en code-review (impact API publique).
3. **`syncNow()` retourne `ZSyncRunReport` (retenu) vs `ZResult<Unit>` simple.** Retenu : un **rapport agrégé** rend l'**échec partiel testable et visible** (attempted/succeeded/failed + `failures`). Alternative minimaliste : `Right(unit)` best-effort + log seul. Le rapport est plus riche pour E9 ; à confirmer (surface API).
4. **Débounce : couture de fabrique de timer + `flushPending()` (retenu) vs `package:fake_async`.** Retenu : **fabrique injectable + flush synchrone** (indépendant de toute dep de test). `fake_async` reste utilisable en complément si présent, mais la couture est **exigée** (AC9). À confirmer que `fake_async` n'est pas imposé.
5. **Dette E5-3 réseau/serveur : traitée au déclenchement (couture `isConnected`) + visibilité dans `ZSyncRunReport.failed` (retenu) vs changement de contrat `sync()`.** Retenu : **ne pas** modifier `sync()` (additif E5-3 gelé) ; l'orchestrateur (a) ne déclenche que si la **vraie** source réseau de l'app dit « connecté », (b) **compte et logge** les échecs serveur (jamais noyés). La distinction fine par-dépôt (retourner `Left` sur permission/quota) reste une **évolution future** documentée. À trancher explicitement en code-review.
6. **`dispose()` ne dispose PAS les dépôts (retenu).** L'orchestrateur n'est **pas propriétaire** des `ZSyncableRepository` (leur cycle de vie appartient à l'app/binding). Alternative : `dispose(disposeRepos: false)` paramétrable. Retenu = non-propriété stricte ; à confirmer.
