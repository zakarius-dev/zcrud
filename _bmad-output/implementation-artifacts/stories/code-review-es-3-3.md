# Code-review ES-3.3 — Cascade de suppression déclarative et bornée

Revue adversariale (bmad-code-review, effort high). Story : `es-3-3-cascade-suppression-declarative-bornee.md` (Status: review → **APPROUVÉ, done-ready**).

## Verdict

**APPROUVÉ.** Les 12 ACs sont couverts par des tests à **pouvoir discriminant réel** (R12), pas par l'existence. Le cœur (bornage ≤ 450, AC8) est prouvé par observation de `report.batchCount` et par injection R3-a rejouée indépendamment. Le changement additif `topologyOf` est **purement additif** et sans fuite backend. **Aucun finding HIGH / MAJEUR / MEDIUM.** 3 findings LOW (nits documentaires / couverture), non bloquants.

## Vérif verte RÉELLE (rejouée sur disque)

| Étape | Commande | Résultat |
|-------|----------|----------|
| kernel VM | `dart test test/z_cascade_registry_test.dart` | **+11 All tests passed** |
| kernel JS | `dart test -p node …` | **+11 All tests passed** (web-safe) |
| batcher | `flutter test test/z_firestore_cascade_batcher_test.dart` | **+12 All tests passed** |
| ES-3.2 non-régression | `flutter test test/z_firestore_path_resolver_test.dart` | **+11 All tests passed** (incl. AD-5 aucun type cloud_firestore en signature) |
| analyze | `dart analyze zcrud_study_kernel zcrud_firestore zcrud_flashcard` | **No issues found!** |
| graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK · 34 arêtes / 18 nœuds** (inchangé) |
| surface-guard | `flutter test test/z_kernel_surface_guard_test.dart` (flashcard) | **+5 All tests passed** |

## Injection adversariale rejouée par le reviewer (pouvoir discriminant du CŒUR)

- **R3-a (AC8 bornage, CŒUR)** : retiré `&& ops < _maxBatchWrites` de la boucle de flush → `451 ⇒ batchCount 1` (Expected 2, **Actual 1**), 900 et 901 également ROUGES. **RESTAURÉ par édition ciblée → +12 vert.** Le bornage est donc PROUVÉ discriminant, pas POWERLESS (`fake_cloud_firestore` n'impose pas la limite 500 ; seul `batchCount` observé fait foi — piège central d'AC8 correctement contré).

## Audit du changement ADDITIF `topologyOf` (demandé)

`ZFirestorePathResolver.topologyOf(String kind) → ZResult<ZFirestoreTopology>` (l.155-166) :
- **Purement additif** : nouvelle méthode isolée ; `resolveCollection`, `resolveDoc`, l'enum `ZFirestoreTopology`, `ZFirestorePathRule` — **aucune signature ES-3.2 modifiée**. Les 11 tests ES-3.2 (`z_firestore_path_resolver_test.dart`) restent VERTS, dont l'assertion « aucun type cloud_firestore importé ni en signature (AD-5) » et l'anti-réflexion.
- **Cohérent avec les règles déclaratives** : lit `_rules[kind]`, `Left(DomainFailure)` explicite si kind inconnu (même contrat d'erreur que `resolveCollection`).
- **Aucune fuite backend** : le retour `ZFirestoreTopology` est un **enum Dart neutre** défini dans `zcrud_firestore` (déjà public via `ZFirestorePathRule.topology` en ES-3.2) — pas un type `cloud_firestore`. Utilisé uniquement en interne par le batcher pour choisir sa stratégie (nested ⇒ sous-collection ; flat/global ⇒ `where(FK)`), sans coder de chemin (AD-20/AD-21 respectés).

**Conclusion audit : conforme, additif, non-régressif, sans fuite.**

## Couverture des 12 axes adversariaux

1. **Bornage ≤ 450 réel (AC8)** — OK. Double boucle `while(start<len){ … while(start<len && ops<_maxBatchWrites) … commit; batchCount++ }`. `_maxBatchWrites = FirebaseZRepositoryImpl.kMaxBatchWrites` (450) **réutilisé**, non re-hardcodé (vérifié l.128 + l.246 source). Bornes 450/451/900/901 observées sur `batchCount`. Injection rejouée = ROUGE.
2. **Anti two-owners (AC3/R3-f)** — OK. Garde à la construction (`_index`, l.119-126) : `ArgumentError` explicite citant l'arête + les deux owners ; doublon identique dédupliqué (`seen.add`). Test discriminant présent (owners différents ⇒ throws ; même owner ⇒ 1 arête).
3. **Terminaison BFS (R3-g)** — OK à DEUX niveaux. Kernel : `Set<String> visited` sur les kinds (l.161) — self-edge `folder→folder` + cycle `a→b→a` terminent (tests AC5). Batcher : `Set<String> expanded` sur les couples `kind id` (l.184) — cycle d'INSTANCES borné ; test AC7 exerce réellement un sous-dossier `f2` de niveau 2. Dev a prouvé R3-g par timeout RC=124.
4. **Soft-delete hors-entité (AC9)** — OK. `batch.set(ref, {kIsDeleted, kUpdatedAt}, merge:true)` (l.233-240) ; l'entité n'est **jamais décodée** (le batcher n'a que l'`id`) ⇒ fuite structurellement impossible. Test : `title` survit, `is_deleted`+`updated_at` posés. R3-c (retrait merge) prouvé ROUGE.
5. **Panne NON avalée (AC10)** — OK. `_guard` unique (l.263-276) enveloppe **énumération ET flush** ; `FirebaseException`/`ZFailure`/`Object` → **Left**, jamais `catch(_){}→Right`. AC10 invariant (« jamais Right sur panne ») tenu. Snapshot AVANT soft-delete respecté (`_collectTargets` complète avant `_flushBounded`).
6. **Anti-réflexion (AC4)** — OK. Zéro `runtimeType`/`.toString(` dans le code des deux fichiers (grep vérifié ; l'override `String toString()` de `ZCascadeReport` ne contient pas le token `.toString(` — le guard `_codeOnly` cible bien l'**appel** `.toString(`, pas la déclaration). Grep discriminant load-bearing.
7. **AD-11 zéro-fuite backend** — OK. Aucune signature de retour publique n'expose `WriteBatch`/`Query`/`Timestamp`/`FieldValue`/`CollectionReference`. `deleteCascade → ZResult<ZCascadeReport>` ; `ZCascadeReport`/`ZCascadeLog` neutres. Le ctor injectant `FirebaseFirestore` est la **couture assumée** de l'adapter (précédent `FirebaseZRepositoryImpl`, confinée à `zcrud_firestore`) — pas une fuite domaine. Barrel `export` ne ré-exporte aucun type cloud_firestore.
8. **AD-1/AD-17** — OK. `graph_proof` ACYCLIQUE + CORE OUT=0, **34 arêtes inchangées** ; le batcher réutilise `zcrud_firestore → zcrud_study_kernel` d'ES-3.2 ; registre kernel pur-Dart sans arête neuve.
9. **Snapshot-avant-suppression (fix lex F1)** — OK. `_collectTargets` énumère toutes les cibles `(chemin, id)` sans aucune écriture, puis `_flushBounded` écrit — pas de lecture d'un état déjà muté.
10. **Couverture 12 ACs** — chaque AC a un test à pouvoir discriminant réel (voir tableau). Aucun POWERLESS détecté ; AC8 observe `batchCount`, AC7 relit `is_deleted` sur chaque enfant réel.

## Findings

### LOW-1 — `_guard` ne journalise pas le « nb de lots committés » sur panne (doc vs impl)
`z_firestore_cascade_batcher.dart:263-276`. La story (D8/AC10) annonce « nb de lots committés loggé » et « un état à moitié appliqué est signalé ». En pratique `_guard` log l'exception mais **pas** le `batchCount` déjà committé (local à `_flushBounded`, perdu au throw). **Impact nul sur la correction** : l'invariant AC10 (« jamais Right sur panne ») est tenu ; le retry offline-first est idempotent (merge). Simple écart d'observabilité doc↔impl. Correction optionnelle : surfacer le nombre de lots committés dans le log/`ServerFailure`.

### LOW-2 — AC10 : panne testée uniquement au 1er lot (1 écriture)
`z_firestore_cascade_batcher_test.dart:351-377`. La story mentionne « au 1er ou au N-ième lot » ; seul le 1er lot (single write) est exercé. Le `_guard` enveloppant toute la boucle `await batch.commit()`, chaque commit est structurellement couvert — le gap est de couverture, pas de garantie. Correction optionnelle : ajouter un cas où le 2ᵉ lot échoue (≥ 451 écritures) attendant `Left`.

### LOW-3 — AC5 self-edge : assertion isolée faible (`isNotEmpty`)
`z_cascade_registry_test.dart:226-232`. Le test ne prouve la garde que par « ne boucle pas » (`isNotEmpty`). Son pouvoir discriminant vient de l'injection R3-g (timeout RC=124, rejouée par le dev), pas de l'assertion. Acceptable (le cycle `a→b→a` du même group renforce). Nit.

## Statut

Aucun finding bloquant. LOW-1/2/3 optionnels (consignés, non corrigés — sans impact correction/régression). Story **done-ready** après édition ciblée du sprint-status par l'orchestrateur.
