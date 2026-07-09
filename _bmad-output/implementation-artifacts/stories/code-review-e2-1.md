# Code Review — Story E2-1 : Contrats de base (ZEntity / ZNode / ZSyncable / ZSyncMeta / ZFailure)

- **Date** : 2026-07-09
- **Skill invoqué** : `bmad-code-review` (chemin pris : **tool `Skill` réel** — `Skill({skill:"bmad-code-review", args:"review E2-1"})`, workflow step-file `.claude/skills/bmad-code-review/steps/step-01..04`).
- **Story** : `_bmad-output/implementation-artifacts/stories/e2-1-contrats-de-base.md` (10 ACs, statut `review`, baseline `8f28755`).
- **Reviewer** : agent adversarial (3 lentilles fusionnées : Blind Hunter / Edge Case Hunter / Acceptance Auditor).
- **Périmètre revu** :
  - `packages/zcrud_core/lib/src/domain/contracts/{z_entity,z_node,z_syncable}.dart`
  - `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`
  - `packages/zcrud_core/lib/src/domain/failures/z_failure.dart`
  - `packages/zcrud_core/lib/zcrud_core.dart` (barrel), `packages/zcrud_core/pubspec.yaml`
  - `packages/zcrud_core/test/**` (5 fichiers)

---

## Verdict : **APPROVED** ✅

Story techniquement solide, conforme aux 10 ACs et aux invariants AD-1/AD-4/AD-5/AD-10/AD-11/AD-14/AD-16.
**0 finding HIGH/MAJEUR, 0 MEDIUM.** Quelques observations LOW/nit et trous de couverture mineurs, tous non bloquants.

### Décompte par sévérité

| Sévérité | Nb |
|---|---|
| HIGH / MAJEUR | 0 |
| MEDIUM | 0 |
| LOW / nit | 4 |

---

## Vérifications RÉELLEMENT rejouées sur disque

| Vérif | Commande | Résultat réel |
|---|---|---|
| Analyze | `dart run melos run analyze` | **RC=0** — `zcrud_core: No issues found!` (14 packages ; 2 lints pré-existants hors périmètre : `zcrud_generator` `directives_ordering`, `zcrud_flashcard` 1 issue — **non introduits par E2-1**) |
| Tests | `cd packages/zcrud_core && dart test` | **RC=0** — **34 tests** « All tests passed! » |
| Verify (gates + graphe) | `dart run melos run verify` | **RC=0** — graph_proof : **17 arêtes**, `out-degree(zcrud_core)=0`, ACYCLIQUE OK, CORE OUT=0 ; gates melos/reflectable/secrets/codegen/compat tous OK |
| Pureté (grep) | `grep -rE "package:flutter\|dart:ui\|cloud_firestore\|package:firebase\|package:hive\|flutter_riverpod\|package:riverpod\|package:get/\|package:provider/" packages/zcrud_core/lib/` | **0 occurrence** — seul import externe du domaine : `package:dartz/dartz.dart` (dans `failures/z_failure.dart`) |

> Note : les RC ci-dessus sont les **vrais codes de sortie melos** (relance avec redirection fichier, pas via pipe `| tail`).

---

## Analyse adversariale des points de vigilance

### 1. Correction & cohérence `==`/`hashCode` — **OK**
- `ZFailure` base : `==` sur `(runtimeType, message)`, `hashCode = Object.hash(runtimeType, message)` — **cohérents** (mêmes champs des deux côtés).
- `DomainFailure`/`CacheFailure`/`ServerFailure` : sans champ propre → héritent de la base ; discrimination par `runtimeType` correcte (`DomainFailure('x') != CacheFailure('x')`).
- `NotFoundFailure` : `==` **et** `hashCode` incluent tous deux `id` + `entity` + `message` + `runtimeType` — **aucun champ oublié**, alignement `==`/`hashCode` exact.
- `ZSyncMeta` : `==` sur `(runtimeType, updatedAt, isDeleted)`, `hashCode = Object.hash(updatedAt, isDeleted)` — cohérent (classe non sous-classée, absence de `runtimeType` dans le hash sans conséquence).
- **Aucun cas trouvé** de deux instances égales à hashCode divergents (ni l'inverse). Symétrie base↔sous-classe vérifiée (`other is NotFoundFailure` d'un côté, `runtimeType==` de l'autre → tous deux `false`).

### 2. JSON défensif `ZSyncMeta` (AD-10) — **OK**
- `fromJson` : `_parseIso(json['updated_at'])` renvoie `null` si non-`String` **ou** ISO mal formé (`DateTime.tryParse`) ; `is_deleted` via garde `is bool ? … : false`. **Aucun chemin ne throw.**
- Éprouvé mentalement : `{}`, `{'updated_at':'garbage'}`, `{'updated_at':12345}`, `{'updated_at':null}`, `{'is_deleted':'true'}`, `{'is_deleted':1}` → tous dégradent en défauts sûrs. Tous couverts par `z_sync_meta_test.dart`.

### 3. `copyWith` sentinelle — **OK**
- `const Object _unset = Object();` + `identical(updatedAt, _unset)` distingue sans ambiguïté « omis » (conserve) de `null` explicite (reset). Les 3 branches (omis / null / nouvelle valeur) sont testées. **Reset-null réel possible.**

### 4. `ZFailure` `abstract` (non `sealed`) — **OK (conforme AD-4)**
- Déclarée `abstract class ZFailure` — **jamais `sealed`**. Aucun `switch` exhaustif ne présuppose la fermeture (recherche : 0 pattern-matching sur `ZFailure`). Extensibilité inter-package prouvée par `_AppSpecificFailure` (test AC6).

### 5. Pureté AD-1/AD-5/AD-14 — **OK**
- Grep pureté propre (cf. tableau). Re-export barrel **curaté** : `export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;` — **pas de fuite globale** de dartz. `pubspec.yaml` : `dartz ^0.10.1` uniquement, **aucune** dépendance `zcrud_*` (out-degree 0 préservé, confirmé par graph_proof).

### 6. `ZEntity.id` nullable / `ZNode.id` non-null — **OK**
- `ZEntity` : `String? get id`, `isEphemeral => id == null` (conforme canonique §2.1). `ZNode` : `String get id` (non-null). Cohérent avec le schéma canonique (id `String` opaque). `isEphemeral` correct (testé aux deux valeurs).

---

## Findings

### LOW / nit

**L1 — `ZSyncMeta.copyWith(updatedAt)` typé `Object?` : perte de sûreté au compile-time**
`z_sync_meta.dart:57` — Le paramètre sentinelle `Object? updatedAt = _unset` autorise un appel `copyWith(updatedAt: 'foo')` qui **compile** puis lève un `TypeError` au runtime sur `updatedAt as DateTime?`. C'est le compromis idiomatique du pattern sentinelle ; risque réel très faible (API interne du domaine, aucun site d'appel fautif). *Correctif optionnel* : documenter le contrat, ou adopter un sentinelle typé (`Object?`→wrapper) — non requis.

**L2 — Couverture d'égalité `ZFailure` inégale selon les sous-classes (AC7 « pour chaque sous-classe »)**
`z_failure_test.dart` — réflexivité (`a==a`) et symétrie explicites testées seulement pour `DomainFailure` ; `CacheFailure`/`ServerFailure` ne sont testées que « égales à elles-mêmes par valeur ». La couverture reste suffisante (le matcher `equals()` exerce réflexivité/symétrie et `NotFoundFailure` a ses tests de champs), mais la lettre de l'AC7 (« réflexive et symétrique … pour chaque sous-classe ») n'est pas littéralement instrumentée partout. *Correctif optionnel* : factoriser un helper d'égalité appliqué aux 4 sous-classes.

**L3 — Round-trip `ZSyncMeta` testé uniquement en UTC ; cas `DateTime` local non couvert**
`z_sync_meta_test.dart` — le round-trip `toJson→fromJson` n'est éprouvé qu'avec `DateTime.utc(...)`. Vérifié manuellement : un `DateTime` **local** round-trip aussi correctement (`toIso8601String()` sans `Z` → `tryParse` rend un local, `isUtc` préservé, donc `==` DateTime vrai) — **pas de bug**, mais absence de test explicite du chemin local et du cas chaîne vide `''`. *Correctif optionnel* : ajouter un cas local + `''`.

**L4 (observation infra, pré-existant E1 — DEFER) — `verify:serialization` affiche `ERROR: No tests match … serialization-compat` tout en laissant `melos verify` à RC=0**
La sous-étape `verify:serialization` de `melos run verify` imprime « No tests ran / ERROR: No tests match the requested tag selectors » (aucun test taggé `serialization-compat` à ce stade — attendu, documenté comme no-op dans la story). Le gate agrégé reste **RC=0**. Non introduit par E2-1 (outillage E1). *Risque forward* : si une future version de `dart test`/melos traite « no-match » comme un échec, le gate casserait. À surveiller lors de E2-5 (premier modèle sérialisé) — hors périmètre E2-1.

---

## Conformité ACs (Acceptance Auditor)

| AC | Sujet | Statut |
|---|---|---|
| 1 | Pureté Dart du domaine (grep, out-degree 0) | ✅ |
| 2 | `ZEntity` id opaque nullable + `isEphemeral` | ✅ |
| 3 | `ZNode` id non-null, topologie différée | ✅ |
| 4 | `ZSyncable` clé LWW `updatedAt` nullable | ✅ |
| 5 | `ZSyncMeta` hors-entité, JSON défensif, copyWith sentinelle, `==`/`hashCode` | ✅ |
| 6 | `ZFailure` `abstract` (non `sealed`), 4 sous-classes, extensibilité tierce | ✅ |
| 7 | Égalité de valeur `ZFailure` testée (discrimination type/champ) | ✅ (voir L2) |
| 8 | `dartz` câblé + re-export curaté + `ZResult<T>` + smoke test via barrel seul | ✅ |
| 9 | Emplacements + barrel (exports + `ZCoreApi` conservé) | ✅ |
| 10 | Vérif verte (generate/analyze/test) + backend-agnostique | ✅ |

**Aucune violation d'AC.** `Equatable` : 0 occurrence (convention canonique §5 respectée). `ZCoreApi` toujours exporté (non-régression E1-2).

---

## Trous de couverture de test détectés (synthèse)

- **Aucun trou bloquant.** Cas positifs et négatifs d'égalité couverts ; JSON corrompu couvert (map vide, type faux, ISO invalide).
- Manques mineurs (LOW) : symétrie/réflexivité explicites non répétées pour `CacheFailure`/`ServerFailure` (L2) ; round-trip `ZSyncMeta` local + chaîne vide non testés (L3) ; pas de test `Set`/`Map` de dédup pour `ZSyncMeta` (le pattern est validé pour `ZFailure`).
- L'égalité `Either`/`Left`/`Right` (dartz) n'est pas testée en valeur — non requis par les ACs (les contrats zcrud n'en dépendent pas).

---

## Recommandation

**APPROVED** — la story peut passer à `done` après édition ciblée du sprint-status par l'orchestrateur.
Findings LOW L1–L3 : optionnels (à corriger si triviaux, sinon consignés). L4 : DEFER (outillage E1, à revoir en E2-5). Aucun MEDIUM/HIGH à corriger avant `done`.
