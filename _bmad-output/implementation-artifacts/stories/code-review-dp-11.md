# Code Review — DP-11 : Hint de persistance `timestamp` (gap B14)

- **Skill** : `bmad-code-review` (VRAI skill invoqué ; step-file architecture, step-01 gather-context).
- **Mode** : revue adversariale, périmètre DP-11 STRICT (3 packages : `zcrud_annotations`, `zcrud_generator`, `zcrud_firestore`). Autres stories DP en vol (DP-1/3/7/8) **exclues**.
- **Story** : `_bmad-output/implementation-artifacts/stories/dp-11-timestamp-persistance-hint.md` (9 ACs), status `review`.
- **Date** : 2026-07-11.

## Fichiers revus (périmètre DP-11 uniquement)

- `packages/zcrud_annotations/lib/src/domain/annotations/z_persist_as.dart` (NEW, enum `ZPersistAs`)
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart` (param `persistAs`)
- `packages/zcrud_annotations/lib/zcrud_annotations.dart` (export)
- `packages/zcrud_annotations/test/annotations_const_test.dart`
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` (`persistAsTimestamp` + `_emitTimestampFields`)
- `packages/zcrud_generator/test/models/article.dart` (fixture) + `zcrud_model_generator_test.dart`
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` (`_timestampFields`/`_encode`/`_applyTimestampHints`/`_inject`)
- `packages/zcrud_firestore/test/timestamp_hint_test.dart` (NEW)

## Vérif verte rejouée réellement sur disque

| Vérif | Résultat réel | RC |
|---|---|---|
| `melos run generate` | SUCCESS (build_runner tous packages) | **0** |
| `dart analyze` zcrud_annotations | `No issues found!` | **0** |
| `dart analyze` zcrud_generator | `No issues found!` | **0** |
| `dart analyze` zcrud_firestore | `No issues found!` | **0** |
| `dart test` zcrud_annotations | `All tests passed!` — **9/9** | **0** |
| `dart test` zcrud_generator | `All tests passed!` — **84/84** (dont 4 artefact B14 + collision de clé) | **0** |
| `flutter test` zcrud_firestore | `All tests passed!` — **82/82** (dont 8 DP-11 + non-régression E5) | **0** |
| `python3 scripts/dev/graph_proof.py` | `ACYCLIQUE OK` / `CORE OUT=0 OK` — 19 arêtes, 14 nœuds | **0** |

Garde AD-5 rejouée manuellement : le **type** `cloud_firestore.Timestamp` n'apparaît **nulle part** hors `zcrud_firestore/lib/src/data`. Les occurrences du littéral « Timestamp » dans `zcrud_annotations`/`zcrud_generator` et dans le `.g.dart` généré (`$ArticleTimestampFields`, dartdoc) sont **exclusivement** des identifiants camelCase et du dartdoc — **aucun type ni import backend**. `$ArticleTimestampFields = <String>{'created_at'}` / `$AuthorTimestampFields = <String>{}` : littéraux `String` purs. **AD-5 confiné : confirmé.**

## Findings par sévérité

### MAJEUR-1 — Le hint n'est PAS appliqué sur le chemin d'écriture de merge offline-first (`_mergedMap`) : format sur disque incohérent, but B14 (orderBy/range/index) défait pour les écritures synchronisées

- **Fichier** : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:731` (`_mergedMap`), à comparer à `:230` (`_encode`) qui, lui, appelle `_applyTimestampHints`.
- **Constat** : la conversion ISO→`Timestamp` est appliquée **uniquement** dans `_encode` (chemin `save` → `_remote.push`). Le chemin de propagation de synchronisation offline-first — `sync()` → `_remote.applyMergedAll(toPush)` → `applyMergedAll`/`writeMerged` → `_mergedMap` (`z_offline_first_repository.dart:275`) — **n'applique pas** le hint : il écrit `created_at` en **String ISO-8601**.
- **Scénario de défaillance concret** (architecture AD-9, le cas nominal, pas un edge) :
  1. Utilisateur **hors-ligne** : `save(E)` → écriture locale Hive (ISO), aucune poussée distante. Reconnexion → `sync()` classe `E` en `pushLocalToRemote` → `applyMergedAll` → `_mergedMap` → sur Firestore `created_at` = **String ISO**.
  2. Utilisateur **en ligne** : `save(F)` → `push` → `_encode` → sur Firestore `created_at` = **Timestamp**.
  3. La **même collection** contient désormais `created_at` en **types mixtes** (`Timestamp` ET `String`).
- **Impact** : Firestore ordonne les types **séparément** (le groupe `Timestamp` et le groupe `String` ne s'entrelacent pas). Un `orderBy('created_at')` ne produit **pas** l'ordre chronologique attendu, et une requête de plage `where('created_at', isGreaterThanOrEqualTo: <Timestamp>)` **exclut silencieusement** tous les documents stockés en `String` (et inversement). C'est **exactement** l'objectif métier de B14 (« requêtes `orderBy`/plage temporelle, index, interop », story « so that ») qui est **partiellement défait**, et la « migration change silencieusement le format sur disque » que la story voulait éliminer est **réintroduite** — le format sur disque devient **non-déterministe** selon que l'écriture a transité par `save` ou par la sync. Dans AD-9, le chemin merge est un chemin d'écriture distant **primaire** (potentiellement majoritaire), pas marginal.
- **Nuance de conformité** : AC4 est libellé « Dans le chemin d'écriture (`_encode`) » et la note de complétion (`dp-11...md:137`) documente explicitement cette décision de portée. **Au sens littéral des ACs, l'implémentation est conforme** ; il n'y a **ni perte de données** (la lecture `_inject` tolère bi-format) **ni throw**. Le gap est un **écart d'intention** surfacé par la revue : les ACs sous-spécifient par rapport au but de la story parce qu'ils traitent `_mergedMap` (E5-3) comme hors périmètre alors que c'est le chemin d'écriture distant dominant d'AD-9.
- **Recommandation** : appliquer `_applyTimestampHints(map)` **aussi** dans `_mergedMap`, en fin de méthode (après la pose de `updated_at`/`is_deleted`). C'est **sûr et idempotent** : `_mergedMap` part de `_toMap(entry.entity)` (ISO), la conversion ne touche que les clés de `_timestampFields` (jamais `updated_at`/`is_deleted`, exclues de l'ensemble → AC8 préservé), aucun ping-pong (lecture `_inject` renormalise). Ajouter un test `writeMerged`/`applyMergedAll` prouvant `created_at is Timestamp` sur disque + `updated_at is String` verbatim. **Alternative** (si l'on préfère assumer la dette) : amender explicitement la story (AC4/AC8) pour acter « ISO sur le chemin sync » comme dette documentée avec follow-up tracké — mais cela laisse le but interop de B14 à moitié atteint. **Reco = corriger dans le périmètre** (changement minime, sûr, testable).

### LOW-1 — `persistAs: timestamp` sur un champ non-date silencieusement toléré

- **Fichier** : `zcrud_model_generator.dart:157` (collecte de la clé sans contrôle de type) / `firebase_z_repository_impl.dart:244` (`_applyTimestampHints`).
- **Constat** : si un champ **non-`DateTime`** est annoté `persistAs: timestamp`, le générateur collecte quand même sa clé ; à l'écriture, `_applyTimestampHints` tente `DateTime.tryParse` — String parsable → convertie ; sinon **laissée inchangée** (défensif). Aucun avertissement de générateur. Comportement sûr (jamais de throw, AD-10) mais l'erreur de déclaration est absorbée en silence. Optionnel : émettre un warning de génération si le type de champ n'est pas `DateTime`/`DateTime?`.

## Position sur le point à trancher (`_encode` vs `_mergedMap`)

**Tranché : incohérence de format sur disque réelle — à corriger** (cf. MAJEUR-1). La tolérance de lecture bi-format (`_inject`) garantit **l'absence de perte de données** et le **round-trip** correct côté zcrud — sur ce plan, l'implémentation est **sûre**. Mais la sûreté en lecture ne couvre **pas** le but de B14, qui est le **format sur disque** pour l'interop/les requêtes Firestore natives (`orderBy`/plage/index). Comme le chemin de sync (`_mergedMap`) écrit en ISO alors que `save` écrit en `Timestamp`, une collection réelle en offline-first se retrouve avec des types **mixtes**, et les requêtes de plage/tri Firestore deviennent **silencieusement incorrectes** pour la fraction synchronisée. Ce n'est donc **pas** un simple choix de portée neutre : c'est une **incohérence de format sur disque** qui affaiblit la raison d'être de la feature. Reco : uniformiser en appliquant le hint dans `_mergedMap`.

## Points vérifiés et CONFORMES

- **AC1/AC6 — pureté & confinement** : `ZPersistAs` pur-Dart (aucun import backend) ; `ZcrudField` reste `const` pur-données ; surfaces publiques ajoutées = `Set<String>` nus ; `Timestamp` (type) absent de `zcrud_annotations`, `zcrud_generator/lib`, et du code généré (littéraux String seulement). `zcrud_core` **non modifié** par DP-11.
- **AC2 — lecture statique** : `reader.read('persistAs').revive().accessor.split('.').last == 'timestamp'`, garde `.isNull` pour l'absent ; **jamais** `reflectable`.
- **AC3/AC7 — artefact & rétro-compat** : `$ArticleTimestampFields == {'created_at'}` (snake_case, = clés `toMap`) ; `$AuthorTimestampFields` vide ; `toMap` reste ISO malgré le hint ; défaut `timestampFields = const <String>{}` ⇒ `_encode`/`_inject` court-circuitent (early-return) ⇒ **zéro régression** E5-1..E5-4 (82/82 verts).
- **AC5 — décodage défensif bi-format** : `_inject` est le **funnel unique** traversé par `_decode` (getById/getAll/watch/`syncEntriesAll`) **et** `_typedCollection.fromFirestore` (round-trip `save`). `Timestamp`→ISO avant `_fromMap` ; String laissée telle quelle ; aucun throw (AD-10). Pas de double conversion / ping-pong (écriture `_encode` une fois, lecture `_inject` une fois).
- **AC8 — ZSyncMeta intacte** : `updated_at`/`is_deleted` hors `_timestampFields` ; `_applyTimestampHints` appliqué **après** la pose des méta et n'itère que les clés d'entité ⇒ LWW ISO préservé (test AC8 : `updated_at is String`, `created_at is Timestamp`).
- **AC9 — Hive inchangé** : `hive_z_local_store.dart` non modifié (local ISO, AD-9).

## Verdict

**CHANGES REQUESTED** — 1 finding **MAJEUR** (MAJEUR-1, chemin de merge sync), 1 **LOW**. Aucun HIGH/critique, zéro régression, vérif intégralement verte (analyze RC=0 ×3, tests 9+84+82, graph ACYCLIQUE/CORE OUT=0). AD-5 confiné et prouvé. Le noyau du feature (annotation → artefact neutre → consommation Firestore, écriture + lecture bi-format) est solide et bien testé ; le seul écart significatif est l'uniformité du format sur disque entre `save` et la propagation de synchronisation offline-first — à trancher/corriger avant `done` (reco : appliquer le hint dans `_mergedMap`, ou acter la dette par amendement explicite de la story).

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze` annotations/generator/firestore RC=0 ; `dart test` annotations 9 / generator 84 ; `flutter test` firestore **83** (+1) ; graph CORE OUT=0.

- **MAJEUR-1 (format mixte sur disque) — CORRIGÉ.** `_applyTimestampHints` est désormais appliqué AUSSI dans `_mergedMap` (voie sync/merge offline-first : `writeMerged`/`applyMergedAll`), pas seulement `_encode` (save). Le format disque est uniforme (Timestamp partout pour les clés hintées) → `orderBy`/plage Firestore corrects sur toute la collection. `_applyTimestampHints` est idempotent et n'affecte jamais `ZSyncMeta` (`updated_at`/`is_deleted` ∉ `_timestampFields`, LWW intact). **Test ajouté** : `writeMerged` produit un `Timestamp` sur `created_at` ET conserve `updated_at` String / `is_deleted` bool.
- **LOW-1 (persistAs sur champ non-date toléré silencieusement) — CONSIGNÉ** (optionnel) : `_applyTimestampHints` tryParse défensif ; warning de génération reportable.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert. AD-5 confiné, rétro-compat E5 préservée.
