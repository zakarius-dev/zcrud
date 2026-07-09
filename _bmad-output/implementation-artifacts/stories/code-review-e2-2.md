# Code Review — Story E2-2 : Ports données (ZRepository / ZDataRequest / ZDataState / ZCursor / ZAcl)

- **Skill invoqué** : `bmad-code-review` (via tool `Skill`, args `review E2-2`) — steps disque `.claude/skills/bmad-code-review/steps/step-01..03`.
- **Cible de revue** : arbre non suivi (baseline `8f28755` = HEAD ; tout `packages/` est untracked). Diff = les 5 fichiers lib + barrel + 5 tests + purity test de la story.
- **Mode** : full (spec `e2-2-ports-donnees.md`, 10 ACs, statut `review`).
- **Grounding** : architecture.md (AD-1/4/5/11/14/16), canonical-schema.md §5/§7, CLAUDE.md, E2-1 (`z_entity.dart`, `z_failure.dart`).
- **Date** : 2026-07-09.

---

## Vérifications RÉELLES rejouées sur disque

| Contrôle | Commande | Résultat |
|---|---|---|
| Analyse package | `dart analyze` (zcrud_core) | **RC=0** — « No issues found! » |
| Tests package | `dart test` (zcrud_core) | **RC=0 — 74 tests passés** (60 E2-1 + 14 E2-2) |
| Analyse workspace | `melos run analyze` | (couvert par verify, 14 pkgs) |
| Verify workspace | `melos run verify` | **RC=0** |
| Graphe AD-1 | `graph_proof.py` (dans verify) | **17 arêtes, 14 nœuds, ACYCLIQUE OK, CORE OUT=0 OK** |
| Gates CI | melos/reflectable/secrets/codegen/compat | **tous OK** ; `verify:serialization` no-op (aucun tag `serialization-compat`, toléré) |
| Packages | `melos list` | **14** (non-régression) |
| Neutralité (AD-5) | grep `Timestamp\|DocumentSnapshot\|QuerySnapshot\|CollectionReference\|FirebaseException\|cloud_firestore\|firebase\|hive\|flutter\|dart:ui` en CODE sur les 5 fichiers | **0 occurrence** |
| Nommage (finding #15) | grep `\b(DataRequest\|DataState\|ZQuery)\b` en CODE sous `lib/src/domain/` | **0 occurrence** |
| Flux nus (AD-11) | grep `Either<...Stream\|ZResult<Stream` dans `z_repository.dart` | **0 occurrence** (flux `Stream<List<T>>` nus) |

Verdict de conformité architecturale : **AD-1 (out-degree 0), AD-4 (`sealed` intra vs `abstract` ouvert), AD-5 (backend-agnostique), AD-11 (Either + flux nus), AD-14 (invariants documentés côté repo), AD-16 (curseur neutre + ZAcl app-supplied) : tous respectés.** Finding readiness #15 (nommage 100 % `Z`, `ZQuery` fusionné dans `ZDataRequest`) : **résolu**.

---

## Triage des findings

| Sévérité | Nb |
|---|---|
| HIGH / MAJEUR | 0 |
| MEDIUM | 3 |
| LOW / nit | 3 |
| Dismiss (faux positifs écartés) | 2 |

Aucun finding critique/majeur. Les 3 MEDIUM sont des **lacunes de couverture / robustesse du fake de référence**, non bloquantes (les ACs sont techniquement satisfaits et la robustesse curseur relève explicitement des consommateurs E4-3 / implémenteur E5), mais recommandées.

---

## MEDIUM

### M1 — `watch(ZDataRequest)` du contrat n'est jamais exercé par les tests
- **Fichier** : `test/domain/z_repository_contract_test.dart` (couverture) ; impl fake lignes 123-127.
- **Problème** : le fake implémente `watch(ZDataRequest)` (seed `_applyRequest(request)` puis re-broadcast mappé), mais **aucun test** ne l'appelle. Seul `watchAll()` est testé (lignes 218-234). Or `watch(request)` est le flux **filtré/trié/paginé** — le plus riche et le plus susceptible de régresser (application du filtre à chaque émission, cohérence avec `getAll`). AC3 le liste comme surface du contrat ; AC9 exige de prouver le contrat « en intégralité ».
- **Correctif suggéré** : ajouter un test `watch(ZDataRequest(filters:[...]))` : abonnement → mutation → vérifier que l'émission suivante applique bien le filtre (et diffère de `watchAll`).
- **Décision** : non bloquant (le flux nu est prouvé via `watchAll` ; la sémantique broadcast complète est portée par E5). Recommandé pour fermer AC9.

### M2 — Le repli in-memory du curseur ignore `values` et ne couvre pas le curseur `id: null`
- **Fichier** : `test/domain/z_repository_contract_test.dart:104-108` (`_applyRequest`).
- **Problème** : le repli saute via `rows.indexWhere((p) => p.id == cursor.id)` — **uniquement l'`id`**, jamais `values`. Or `ZCursor.id` est **optionnel** (`z_cursor.dart:33`, testé `id: null` dans `z_cursor_test.dart:14`) et la docstring `ZCursor` (lignes 23-25) promet un repli « jusqu'à l'ancre (`[id]` **puis** `[values]`) ». Avec un curseur **sans id** (repli par `values` seules, cas légitime), `indexWhere` renvoie `-1` → `anchor >= 0` faux → **aucun saut** → la « page suivante » **re-renvoie silencieusement la page 1** (pas de crash, mais pagination cassée). Ce fake étant la **preuve de suffisance/neutralité** (AC9), sa preuve du repli par `values` est incomplète.
- **Correctif suggéré** : dans le fake, gérer le fallback `values` quand `id` est absent/introuvable (comparer positionnellement `cursor.values` aux clés de tri de la ligne) ; ajouter un test de pagination avec `ZCursor(values: [...], id: null)`.
- **Décision** : non bloquant — le chemin `id` (nominal Firestore) est prouvé et l'impl robuste appartient à E5/E4-3. À consigner comme dette pour E4-3 (« curseur invalide → repli documenté, pas de crash »).

### M3 — Branches non couvertes : curseur invalide, tri multi-clés (départage), page au-delà de la fin
- **Fichier** : `test/domain/z_repository_contract_test.dart` (`_applyRequest` lignes 90-113).
- **Problème** : trois branches du fake ne sont jamais exercées :
  1. **Tri multi-clés / départage** : la boucle `for (final sort in request.sorts)` avec continuation quand `c == 0` (lignes 92-100) n'est testée qu'avec **un seul** `ZSort('age')` (âges distincts) — le tie-break (2ᵉ clé) n'est jamais atteint.
  2. **Curseur invalide** (`id` inexistant) : `indexWhere` → `-1` → renvoie la page depuis le début, sans test (recoupe M2).
  3. **Page au-delà de la fin** : `startAfter` = dernier élément → attendu liste vide, non testé.
- **Correctif suggéré** : un test tri à 2 clés avec égalité sur la 1ʳᵉ ; un test curseur invalide (pas de crash) ; un test page finale vide.
- **Décision** : non bloquant (AC5 prouvé sur le chemin nominal) ; renforce la valeur du fake comme référence. Recommandé.

---

## LOW / nits

### L1 — Deux `_listEquals` divergents : profond dans `z_data_request.dart`, superficiel dans `z_cursor.dart` / `z_data_state.dart`
- **Fichiers** : `z_cursor.dart:60-67` et `z_data_state.dart:130-137` comparent `a[i] != b[i]` (superficiel) ; `z_data_request.dart:202-209` compare via `_deepEquals` (profond, gère les `List` imbriquées).
- **Conséquence** : un `ZCursor.values` contenant une `List` imbriquée (ex. `values: [[1,2]]`) ne serait **pas** comparé en profondeur → `==` faux alors que sémantiquement égal, avec `hashCode` (via `Object.hashAll`) cohérent avec le superficiel donc pas de rupture du contrat hash/==. Impact réel **quasi nul** : `ZCursor.values` porte des **clés d'ordre scalaires** (String/int/date), les listes imbriquées y sont irréalistes.
- **Correctif** : harmoniser sur `_deepEquals` (ou documenter explicitement que `values` sont scalaires). Cosmétique.

### L2 — `ZDataLoaded` autorise `items: []` (invariant « non vide » non gardé)
- **Fichier** : `z_data_state.dart:52-58`.
- **Problème** : la docstring dit « non vide par convention — sinon `ZDataEmpty` » mais rien n'empêche `const ZDataLoaded(items: [])`, ce qui chevauche `ZDataEmpty` et peut router deux états UI différents pour la même réalité.
- **Correctif** : `assert(items.isNotEmpty)` (uniquement en debug, sans casser `const` via `assert` dans le constructeur), ou laisser la présentation trancher. Optionnel.

### L3 — `_listEquals` dupliqué à l'identique dans 3 fichiers
- **Fichiers** : `z_cursor.dart`, `z_data_request.dart`, `z_data_state.dart`.
- **Note** : duplication assumée pour éviter `package:collection` (AD-1, out-degree 0) — choix **légitime** au stade contrats. Consigné comme nit ; une factorisation dans un `src/domain/_internal/collections.dart` privé (non exporté) réduirait la dette sans ajouter de dépendance. Non actionné.

---

## Findings écartés (dismiss)

- **Sentinelle `copyWith` : casts `as String?`/`as int?`/`as ZCursor?`** (`z_data_request.dart:165-168`) — faux positif : pattern sentinelle standard ; les types publics `Object? = _unset` sont contraints à l'appel typé. Pas d'exposition réelle.
- **Phantom type `T` sur `ZDataLoading<T>`/`ZDataEmpty<T>`** — faux positif : requis pour l'exhaustivité `sealed` et l'unification de type dans un `switch<T>` ; conforme à l'usage Dart des états génériques.

---

## Verdict : ✅ APPROVED

- **0 HIGH/MAJEUR.** Les 16 AD applicables sont respectés (neutralité backend AD-5, flux nus AD-11, `sealed` vs `abstract` AD-4, curseur/ACL neutres AD-16, out-degree 0 AD-1, invariants documentés côté repo AD-14). Finding readiness #15 résolu (100 % `Z`, `ZQuery` fusionné).
- **Vérif verte réelle** : analyze RC=0, 74 tests, verify RC=0 (graph 17 arêtes / CORE OUT=0 / ACYCLIQUE), 14 packages, greps neutralité/nommage/flux-nus à 0.
- **Les 3 MEDIUM sont des recommandations de couverture/robustesse non bloquantes** : ACs techniquement satisfaits, robustesse curseur (repli `values`, curseur invalide) explicitement dévolue aux consommateurs **E4-3** / implémenteur **E5**. À consigner comme dette de test ; leur correction dans le périmètre E2-2 (ajout de tests, sans toucher au contrat) est **souhaitable avant `done`** si sans régression, sinon justifiée par renvoi à E4-3/E5.
- **LOW/nits** optionnels.

**Aucune modification de code ni de `sprint-status.yaml` effectuée par cette revue.**
