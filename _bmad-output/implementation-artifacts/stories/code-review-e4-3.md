# Code Review — E4-3 : Recherche (sans accents), filtres, tri & pagination curseur

- **Story** : `_bmad-output/implementation-artifacts/stories/e4-3-recherche-filtres-tri-pagination.md` (10 ACs, statut `review`)
- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` ; chemin pris = skill réel, PAS le fallback disque). Étapes exécutées : step-01 (contexte, baseline = `868438a` = HEAD, diff = working tree non suivi/modifié E4-3) → step-02 (revue adversariale : couches Blind Hunter / Edge Case Hunter / Acceptance Auditor exécutées inline, sous-agents non disponibles dans ce contexte d'agent unique) → step-03 (triage).
- **Périmètre diffé** : `z_search_text.dart` (`zFoldDiacritics`), `z_list_query.dart` (`ZListPage`/`zMatchesSearch`/`zApplyListRequest`/`zDeriveCursor`), `z_list_controller.dart` (`ZListController`/`ZListPaginationMode`), barrel `zcrud_core.dart`, + 3 fichiers de tests.
- **Date** : 2026-07-10
- **Verdict** : **CHANGES REQUESTED** (0 HIGH/MAJEUR ; 1 MEDIUM actionnable ; 4 LOW). Le MEDIUM touche l'invariant central de la story (accumulation sans doublon/stale) sous saisie « search-as-you-type » — à corriger par défaut ou justifier par écrit avant `done` (règle MEDIUM du projet).

---

## Résultats de vérification REJOUÉS réellement sur disque

| Contrôle | Commande | Résultat |
|---|---|---|
| Analyze | `melos run analyze` | **RC=0** — 14 packages, « No issues found! » partout |
| Tests cœur | `flutter test` (zcrud_core) | **RC=0** — **+510** All tests passed |
| Tests liste | `flutter test` (zcrud_list) | **RC=0** — **+11** All tests passed (SM-5 graphe : (a) fermeture core SANS syncfusion, (b) markdown SANS, (c) contrôle positif list AVEC, (d) acyclicité AD-1) |
| Gate merge | `melos run verify` | **RC=0** — `ACYCLIQUE OK`, `CORE OUT=0 OK`, `gate:melos OK`, `gate:reflectable OK`, `gate:secrets OK`, `gate:codegen OK` (0 `.g.dart` manquant), `gate:compat OK`, `verify:serialization` = no-op documenté (E2-10) vert |
| Neutralité | `git ls-files '*.g.dart'` / `ls packages` | **0** `.g.dart` suivi ; **14** packages |
| SM-5 renderer | `git status` sur `z_sf_data_grid_renderer.dart` | **non modifié par E4-3** (fichier E4-1, hors File List E4-3) ; graphe SM-5 vert |

**Points de vigilance adversariaux — vérifiés VERTS :**
- **Recherche sans accents searchable-only** : `zMatchesSearch` n'itère que `field.searchable == true` ; une valeur uniquement dans un champ non-searchable (`city='Lyon'`) ne matche pas (test présent). `zFoldDiacritics` : `Café→cafe`, `ÉÈÊË→eeee`, `Œuvre→oeuvre`, `Straße→strasse`, majuscules via `toLowerCase()` d'abord. Aucun accent Latin précomposé courant non replié détecté.
- **Pagination sans doublon/trou + cas-limite pageSize** : N=5, limit 2, tri `age asc` → 3 pages `[20,21]/[22,23]/[24]`, accumulé = 5 ids uniques, `hasMore` correct, `nextCursor` dérivé de la dernière ligne (values sorts + id). Cas exact-multiple géré sans dup (une page vide finale bénigne — voir LOW-1).
- **Repli 2 déclencheurs sans crash + vraie 1re erreur préservée** : mode `inMemory` (fake ignorant limit/startAfter) → pagine en mémoire ; `Left` sur curseur en `backendCursor` (loadMore) → bascule `_runInMemory` → `ZListReady` (jamais `ZListError`), `takeException()==null`. `Left` 1re page (`startAfter==null`, `failAlways`) → **reste `ZListError`** (non masqué). Ancre introuvable / `values:[9999]` / `id:null` → page vide/saut par values, 0 throw.
- **Tri multi-clés STABLE** : décoration par index d'origine → tie-break final `a.key.compareTo(b.key)` (non nié en `desc`) ; `null` = plus grande valeur (dernier en asc). Tests asc+tie-break, desc, stabilité présents. Filtres défensifs (`_tryCompare` → `null` → « ne matche pas ») : `name < 30` → 0 crash, exclusion.
- **empty vs noResults** : discriminant `_hasActiveQuery` (search non-blanc OU filtres non vides). Jeu vide sans filtre → `ZListEmpty` ; `setSearch('zzz')` sur jeu non vide → `ZListNoResults` ; vide + filtre → `ZListNoResults`.
- **Réactivité AD-2/AD-15** : `ChangeNotifier` + `ValueNotifier` interne exposé en `ValueListenable<ZListViewState>` ; imports = `package:flutter/foundation.dart` + types `zcrud_core` uniquement ; garde `_disposed` sur `_emit` + `if (_disposed) return` après chaque `await`. `dispose()` annule l'abonnement `watchAll` et dispose le notifier.

---

## Findings (triage par sévérité)

### HIGH / MAJEUR
**Aucun.** Pas de doublon/trou sur le chemin nominal, pas de repli qui crashe, pas de repli masquant une vraie erreur de 1re page, pas de recherche qui rate/faux-matche sur valeur brute déterministe.

### MEDIUM

**M-1 — Absence de garde anti-réponse-obsolète (`request-generation`) : sous saisie « search-as-you-type » / réponses async hors-ordre, un commit obsolète peut écraser l'état courant ou dupliquer/mélanger l'accumulé.**
`z_list_controller.dart` — `setSearch`/`setFilters`/`setSort`/`refresh` lancent `_runQuery()` **sans** vérifier `_isLoading` **ni** estampiller la requête. Seul `loadMore()` garde `_isLoading`.
- *Scénario A (stale)* : `setSearch('a')` → `_runQuery` A (lent) ; `setSearch('b')` → `_runQuery` B (rapide). B commit `ready(b)`, puis A revient : `if (_disposed) return;` faux → `_commitBackendPage(a-rows, append:false)` **efface l'accumulé et réinjecte les résultats de « a »** → l'UI affiche « a » alors que `_search=='b'`. C'est le cas canonique de la recherche incrémentale (frappes plus rapides que les réponses d'un backend réellement async ; les tests, sérialisés par `pumpAndSettle`, ne l'exercent pas).
- *Scénario B (dup/trou)* : `setSearch(...)` pendant un `loadMore` en vol → `_resetPagination()` vide `_accumulated`, puis le `_commitPage(append:true)` du `loadMore` en retard fait `_accumulated.addAll(...)` → entrelacement/duplication de lignes.
- *Impact* : viole l'invariant « accumulation sans doublon ni trou » (AC5) et l'exactitude de l'état sous concurrence. Reste **conditionnel** à un backend async + appels rapprochés (verdict PLAUSIBLE ; non couvert par les tests).
- *Correctif suggéré (petit, dans le périmètre)* : compteur monotone `_generation` incrémenté à chaque (re)lancement ; capturer `gen` en début de `_runQuery`/`_runInMemory` et **rejeter tout commit/emit** si `gen != _generation` (en plus du `_disposed`). Alternative/justification acceptable : documenter que la déduplication/débounce de la saisie incombe au binding/app (`zcrud_riverpod`/`zcrud_get`) — mais alors le tracer explicitement ici et dans les Dev Notes.

### LOW / nits

**L-1 — Page vide finale sur taille exacte multiple de `pageSize` (heuristique `rows.length >= limit`).** En `backendCursor`, un jeu de taille multiple de `pageSize` produit un `loadMore` supplémentaire renvoyant une page vide (`hasMore` retombe alors à `false`). **Bénin** : aucun doublon ni trou, une seule requête backend gâchée. Déjà documenté (Completion Notes #3). Correctif possible : `hasMore = rows.length == limit` combiné à un `count()` ou à une sonde « limit+1 » (E5).

**L-2 — Pliage diacritique précomposé uniquement (pas de normalisation NFD/marques combinantes).** `_foldTable` couvre les formes précomposées ; une entrée en forme décomposée (`e` + U+0301) n'est pas repliée (le rune combinant reste). Rare (les données sont majoritairement NFC), mais un `contains` accent-insensible peut alors rater/diverger. Documenter la limite (« table précomposée, aucune normalisation Unicode ») ou ajouter le stripping des marques combinantes U+0300–U+036F.

**L-3 — Bascule d'algorithme en cours de pagination (`backendCursor` → repli in-memory) : cohérence au raccord dépend du tie-break `id`.** Lors d'un repli sur `Left` curseur au milieu de la pagination, le moteur in-memory re-trie tout le jeu et saute par `values`+`id`. Si un backend réel ordonne les lignes à clés de tri égales autrement que par `id`, le raccord peut dupliquer/sauter une ligne frontière. Le contrat `ZCursor` impose `id` en départage : à **garantir côté adaptateur E5** (dernier `orderBy(id)`). Informationnel pour E4-3 (le fake est cohérent).

**L-4 — `ZFilterOp.contains` avec opérande `null` matche toutes les lignes.** `_coerceText(null) == ''` → `folded == ''` → `text.contains('')` toujours vrai (chemin non-Iterable). Défensif mais surprenant ; un `contains` à opérande `null` est probablement une erreur d'appel. Envisager d'exclure (`false`) quand l'opérande replié est vide. Faible impact (usage inhabituel).

---

## Trous de couverture de tests (non bloquants, à consigner)

1. **Concurrence / réponses hors-ordre** (M-1) : aucun test avec repo async retardé exerçant deux `setSearch` successifs, ni `setX` pendant un `loadMore` en vol.
2. **Filtre + tri + curseur COMBINÉS** dans une seule requête (chaque dimension testée isolément ; pas la composition).
3. **Repli in-memory sur `loadMore` au-delà de 2 pages** (mode `inMemory`) et au raccord `backendCursor→repli` sur plusieurs pages.
4. **Curseur en direction `desc`** : `_skipCursor`/`_compareToAnchor` testés seulement en `asc`.
5. **`dispose()` PENDANT une requête en vol** (seulement « dispose puis nouvel appel » couvert).
6. **Recherche multi-mots** : par conception `contains` littéral (l'espace fait partie du terme) — non tokenisé ; comportement à documenter comme extension future si attendu.
7. **Curseur multi-clés avec `values` de longueur ≠ `sorts`** (le `min(...)` défensif n'est pas éprouvé).

---

## Conformité ACs & AD

- **AC1–AC10** : tous **matérialisés et testés** (pliage/idempotence, searchable-only, tous `ZFilterOp` + type incompatible sans crash, tri multi-clés stable + direction, `ZListPage`/`nextCursor`/`hasMore` N pages, repli 2 déclencheurs sans crash + vraie 1re erreur préservée, `ChangeNotifier`/`ValueListenable` + dispose, mapping empty/noResults, SM-5/out-degree 0, barrels + vérif verte). Réserve : AC5/AC7 exacts **sous concurrence** → M-1.
- **AD-1** (out-degree 0), **AD-2/AD-15** (Flutter-native, aucun manager), **AD-8/SM-5** (0 syncfusion/backend, renderer intact), **AD-10** (comparaisons défensives), **AD-11** (`Either`/état dérivé), **AD-16** (curseur neutre + repli documenté sans crash) : **respectés**.

**Recommandation** : corriger **M-1** (garde `_generation`, ~10 lignes) ou le **justifier par écrit** (débounce délégué au binding) ; traiter L-1..L-4 en nits (L-2 mérite au moins une ligne de doc). Re-jouer la vérif verte, puis transition `review → done`.
