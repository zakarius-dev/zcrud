# Code Review — E5-4 `ZSyncOrchestrator` (zcrud_core)

- **Mode d'exécution** : skill BMAD réel `bmad-code-review` invoqué via le tool `Skill` (step-file architecture, step-01-gather-context). Revue non-interactive (subagent d'orchestration) sur cible figée E5-4.
- **Périmètre** : fichiers E5-4 uniquement — `z_sync_orchestrator.dart`, `z_sync_run_report.dart`, barrel `zcrud_core.dart` (2 exports additifs), tests `z_sync_orchestrator_test.dart` / `z_sync_run_report_test.dart`. Modifs zcrud_firestore/flashcard/mindmap et fichiers sync/ E5-3 NON revus.
- **Story** : `_bmad-output/implementation-artifacts/stories/e5-4-zsyncorchestrator.md` (13 ACs).

## Vérif rejouée réellement sur disque

| Gate | Commande | Résultat réel |
|---|---|---|
| Analyze | `dart analyze packages/zcrud_core` | **No issues found!** RC=0 |
| Tests | `flutter test packages/zcrud_core` | **All tests passed! 604** (TEST_RC=0) |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK / CORE OUT=0 OK** RC=0 |
| Pureté | `domain_purity_test.dart` (inclus dans les 604) | vert (aucun import Flutter/backend/état) |

Édition strictement ADDITIVE confirmée : 2 fichiers src + 2 tests neufs + 2 lignes d'export ; aucun contrat E5-1/2/3 modifié, 0 régression.

## Analyse par axe adversarial

- **Pureté Dart (AC1/AC12)** — ✅ Imports = `dart:async`, `package:dartz` (Right), `z_failure`, `z_syncable_repository`, `z_sync_run_report`. Aucun backend/état/connectivité/Flutter. Registre typé `ZSyncableRepository<dynamic>` (générique effacé, jamais un adaptateur concret). Signatures publiques n'exposent que types neutres. `CORE OUT=0`. **Conforme.**
- **Débounce trailing / coalescence N→1 (AC3/AC9)** — ✅ `_schedule` annule+réarme ; test prouve 3 timers, 2 premiers `isCancelled`, dernier armé, 1 seul cycle au flush. Pas de fuite : `cancel()` sur réarmement, gate, et dispose. **Conforme.**
- **Échec partiel (AC5)** — ✅ Itération sur copie défensive `_repos.toList(growable:false)` ; chaque `repo.sync()` sous `try { … result.fold(…) } on Object catch` → un `Left` OU un `throw` (y compris `Error`) est loggé + compté `failed`, boucle poursuivie ; un `throw` synchrone/async d'un dépôt ne casse pas la boucle (`sync()` async → rejet capté par `await`). **Conforme.**
- **Best-effort (AC8)** — ✅ `syncNow()` → `Right<ZFailure,ZSyncRunReport>` toujours ; échec partiel dans le rapport, jamais `Left` global. **Conforme.**
- **Gate `enabled` (AC7)** — ✅ `set enabled(false)` annule le pending ; `_schedule`/`_runCycle` gardés ; réactivation permet de re-planifier (n'arme pas rétroactivement — correct). **Conforme.**
- **`syncNow()` rapport exact (AC8)** — ✅ `attempted == succeeded + failed`, mix 3/2/1 prouvé, registre vide → `empty`. **Conforme.**
- **Dette E5-3 réseau/serveur (AC10)** — ✅ `Left(ServerFailure)` compté `failed` + collecté dans `failures` + loggé, jamais noyé en "offline" ; couture `isConnected` = point d'injection réseau réel ; frontière (distinction fine = évolution future) dartdoc-ée. **Conforme.**
- **`dispose()` (AC11)** — ✅ Annule timer, vide registre, idempotent, inerte post-dispose ; **ne dispose PAS** les dépôts (test `repo.disposed == false`). Pas de fuite de `Timer`. **Conforme.**
- **Testabilité sans Timer réel (AC9)** — ✅ Fabrique `ZSyncTimerFactory` injectable + `flushPending()` awaitable ; suite 100 % sans `Timer`/`Future.delayed` réel. **Conforme.**

## Findings

### MEDIUM-1 — Une couture `isConnected` (ou `logger`) qui `throw` échappe à l'orchestrateur ; unhandled async error dans la voie débouncée
`z_sync_orchestrator.dart:275` — `if (isConnected != null && !await isConnected())` — l'appel `await isConnected()` **n'est pas** protégé par try/catch. Scénario concret : l'app câble sur la couture une vraie source réseau (le cas d'usage explicite de l'AC10, ex. un platform-channel / plugin connectivité) dont l'appel **lève** (permission plateforme, canal non prêt).
- Voie `syncNow()`/`flushPending()` : l'exception remonte, le `Future` **rejette** au lieu de renvoyer `Right(report)` — viole l'invariant « best-effort intégral, jamais de propagation » martelé par la story.
- Voie **débouncée** (pire) : `unawaited(_runCycleAndLog())` (ligne 213) → `_runCycle` throw → future non-awaité en erreur → **unhandled asynchronous error** remonté au Zone handler (en Flutter : `FlutterError.onError`/crash debug). L'orchestrateur, qui garantit « AUCUNE exception ne s'échappe », laisse fuiter ici.

Même faille théorique si le `logger` injecté `throw` dans le bloc `on Object catch` (ligne 300) ou dans `_runCycleAndLog` (ligne 257) — non rattrapé. Le cas `isConnected` est le plus plausible.

**Impact** : robustesse best-effort compromise dès qu'une couture app se comporte mal ; en prod la voie fire-and-forget produit une erreur asynchrone non gérée. **Aucun test** ne couvre une couture qui throw (lacune de couverture).
**Reco** : envelopper `await isConnected()` dans un try/catch (traiter un throw comme cycle sauté + log, ou « supposer connecté » + log — décision produit), afin qu'aucune exception ne s'échappe ni des voies await ni de la voie fire-and-forget. Ajouter un test `isConnected: () async => throw …` prouvant `Right(empty)` + trace. Optionnellement idem pour un logger défensif.
*(Politique CLAUDE.md : MEDIUM à corriger par défaut si possible dans le périmètre, sinon justifier par écrit avant `done`.)*

### LOW-1 — Pas de garde de ré-entrance : des cycles peuvent se chevaucher
`z_sync_orchestrator.dart:271` — rien n'empêche deux `_runCycle` concurrents : un cycle débouncé fire-and-forget encore en vol (dépôt lent sur `await repo.sync()`) pendant qu'un `syncNow()` ou un nouveau cycle démarre. Deux itérations appellent `repo.sync()` **en parallèle** sur le même dépôt.
**Impact** : `sync()` E5-3 est best-effort/LWW donc tolérant, mais un double-déclenchement peut marteler inutilement le backend et fausser marginalement des rapports concurrents. Hors périmètre strict des ACs (aucun ne l'exige).
**Reco** : optionnel — un flag `_running` (coalescer/ignorer un cycle si un est déjà en vol) ou documenter explicitement que les cycles peuvent se chevaucher. À consigner comme dette si non traité.

### LOW-2 — Perte de l'enforcement analyseur `@visibleForTesting` (membres test-only publics) — lié au POINT (5)
`registeredCount` (l.178) et `flushPending()` (l.246) sont **entièrement publics**, gardés seulement par une docstring « test only ». Sans `@visibleForTesting`, l'analyseur n'émettra **aucun** avertissement si du code applicatif les appelle en prod.
**Impact** : mineur (surface API élargie sans garde outillée).
**Reco** : acceptable en l'état (voir POINT (5)). Si `package:meta` est déjà résolu transitivement et que le lint `depend_on_referenced_packages` le tolère, `@visibleForTesting` (from `package:meta`, **hors** `foundation`) passerait la garde `domain_purity` — mais la contrainte « pubspec gelé » justifie de s'en abstenir. Note seulement.

## POINT (5) — Verdict sur la déviation technique (foundation/meta bannis → docstrings + `_listEquals` maison)

**Verdict : ACCEPTABLE — équivalent admis, aucun finding bloquant.**

1. **Contrainte réelle & justifiée.** La garde `domain_purity_test.dart` interdit `package:flutter/` (donc `foundation`). `package:meta` n'est PAS dans la liste `_forbidden`, mais l'utiliser comme dépendance directe violerait « pubspec gelé » (et sans déclaration → lint `depend_on_referenced_packages`). Le retrait de `@visibleForTesting`/`@immutable`/`listEquals` est donc la voie correcte pour rester pur-Dart + pubspec inchangé. `CORE OUT=0` et `domain_purity` restent verts — objectif atteint.
2. **`@visibleForTesting` → docstring** : perte réelle mais purement advisory (aucun impact runtime). AC2 admet explicitement « ou équivalent » ; AC9 vise la testabilité (fabrique + `flushPending`), remplie. Consigné en LOW-2, non bloquant.
3. **`@immutable` → docstring** : annotation advisory ; la classe est de facto immuable (tous champs `final`, ctors `const`). Sans conséquence.
4. **`_listEquals` maison — CORRECT.** Vérifié (`z_sync_run_report.dart:82-89`) : (a) court-circuit `identical(a,b)` ; (b) garde de longueur `a.length != b.length` ; (c) comparaison **ordonnée** élément par élément via `!=` (les `ZFailure` ont `==`/`hashCode`). Null-safety : paramètres non-nullables `List<ZFailure>` → aucun risque de null. **Cohérent avec `hashCode`** qui utilise `Object.hashAll(failures)` (sensible à l'ordre, comme l'égalité). Aucune divergence equals/hashCode. Test `==/hashCode incluant failures` vert.

Conclusion POINT (5) : la substitution est un **équivalent admis** (AC2 « ou équivalent » + esprit AC9), `_listEquals` est **correct**. Seule réserve : LOW-2 (perte d'enforcement analyseur), non bloquante.

## Verdict global

**Prêt pour `done` après traitement du MEDIUM-1** (correction recommandée par défaut, ou justification écrite si reportée) — les LOW sont optionnels/consignables.

- 0 finding HIGH/MAJEUR. Tous les 13 ACs matériellement satisfaits, vérif verte réelle (analyze RC=0 · 604 tests · CORE OUT=0). Édition strictement additive, isolation pur-Dart respectée.
- 1 MEDIUM (robustesse d'une couture app qui throw — voie fire-and-forget unhandled) : à corriger dans le périmètre (petit try/catch + 1 test) ou justifier.
- 2 LOW (ré-entrance ; enforcement `@visibleForTesting`) : optionnels.

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_core` RC=0, `flutter test packages/zcrud_core` **606 tests** (+2), `graph_proof` CORE OUT=0 / ACYCLIQUE OK.

- **MEDIUM-1 — CORRIGÉ.** `await isConnected()` entouré d'un `try/catch` : une couture réseau qui `throw` est assimilée à « hors-ligne » (cycle sauté, loggé), jamais une erreur async échappée (la voie débouncée est `unawaited`). Wrapper `_safeLog` introduit : tous les `_log` du cycle passent par lui → un **logger défaillant** ne casse plus le cycle best-effort. **2 tests ajoutés** : (1) `isConnected` qui throw → `syncNow()` rend `Right(report vide)`, 0 `sync()`, aucune exception, voie débouncée idem ; (2) logger qui throw sur un échec → le cycle poursuit (2e dépôt exécuté).
- **LOW-1 (ré-entrance) — CONSIGNÉ** (optionnel) : cycles chevauchants tolérables (LWW) ; garde de ré-entrance reportable en E9-4 si le martèlement backend devient réel.
- **LOW-2 (`registeredCount`/`flushPending` publics) — CONSIGNÉ** : enforcement analyseur sacrifié faute de `package:meta` (pubspec gelé, domain_purity) ; docstrings « test only » explicites, choix assumé (équivalent admis par AC2/AC9).

**Point (5) (docstrings + `_listEquals` maison)** : validé par le reviewer comme équivalent admis et `_listEquals` correct. Rien à corriger.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
