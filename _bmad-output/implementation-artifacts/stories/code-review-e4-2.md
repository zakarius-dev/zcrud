# Code Review — Story E4-2 : Colonnes dérivées du schéma + vues + états UI accessibles

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill`, chemin `/home/zakarius/DEV/zcrud/.claude/skills/bmad-code-review`).
- **Story** : `_bmad-output/implementation-artifacts/stories/e4-2-colonnes-derivees-vues-etats.md` (10 ACs, statut `review`).
- **Baseline** : `868438a` (= HEAD ; E4-1 + E4-2 sont dans l'arbre de travail non committé). Revue portée **sur les fichiers E4-2** listés dans le File List de la story.
- **Mode** : full (Blind Hunter + Edge Case Hunter + Acceptance Auditor joués par le reviewer — subagents non imbriqués dans ce Workflow).
- **Date** : 2026-07-10.
- **Verdict** : ✅ **APPROVED** — 0 HIGH, 0 MAJEUR, 0 MEDIUM bloquant. 3 findings LOW (nits/latents, non bloquants ; LOW-1 recommandé dans le périmètre).

---

## 1. Triage par sévérité

| Sévérité | Nombre | Bloquant ? |
|----------|--------|------------|
| HIGH / CRITIQUE | 0 | — |
| MAJEUR | 0 | — |
| MEDIUM | 0 | — |
| LOW / nit | 3 | Non |

Aucune des conditions à plancher MEDIUM du brief n'est déclenchée : renderer **jamais** invoqué hors `ready` (prouvé), **aucune** fuite Syncfusion (SM-5 tenu, graphe CORE OUT=0), `empty` **≠** `noResults` (clés + textes distincts), `deriveColumns` **ne lève jamais**.

---

## 2. Vérifications RÉELLEMENT rejouées (sur disque)

| Gate | Commande | Résultat |
|------|----------|----------|
| Analyze `zcrud_core` | `flutter analyze` | **RC=0** — No issues found |
| Analyze `zcrud_list` | `flutter analyze` | **RC=0** — No issues found |
| Test `zcrud_core` | `flutter test` | **479 tests OK** (dont `test/presentation/list/*`) |
| Test `zcrud_list` | `flutter test` | **11 tests OK** (renderer migré + graphe SM-5 a/b/c/d) |
| Gardes de pureté core | `flutter test test/purity` | **12 tests OK** (`presentation_purity` + `style_purity` + `no_heavy_file_dep`) |
| Graphe AD-1/SM-5 | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK**, 14 nœuds, 17 arêtes |
| gate:reflectable | `dart run …/gate_reflectable.dart` | **RC=0** (0 usage hors allowlist) |
| gate:secrets | `dart run …/gate_secret_scan.dart` | **RC=0** (aucun secret) |
| gate:melos | `dart run …/gate_melos_divergence.dart` | **RC=0** (13 scripts identiques) |
| gate:codegen | `dart run …/gate_codegen.dart` | **RC=0** (1 modèle @ZcrudModel, 0 .g.dart manquant) |
| gate:compat | `dart run …/gate_compat_resolution.dart` | **RC=0** (voie manifeste verte) |
| verify:serialization | `dart run …/verify_serialization.dart` | **RC=0** (aucun test tagué modifié — attendu) |
| `melos list` | — | **14** packages |
| `.g.dart` suivis | `git ls-files '*.g.dart'` | **0** |

> Note contention build_runner (signalée par le dev sur `melos run verify`) : gates rejoués **isolément**, tous verts, aucun hang observé.

---

## 3. Vérification des points de vigilance adversariaux

### 3.1 `deriveColumns` — pur & fidèle (AC1/AC2/AC3) ✅
- **Exclusions** : implémentation en **whitelist** (`_tabularTypes`). Tout type absent est exclu → `subItems`/`dynamicItem`/`file`/`image`/`document`/`location`/`geoArea`/`address`/`signature` exclus, ainsi que `hidden`/`markdown`/`relation`/`richText`/… Les `isId` exclus (`_isVisible` : `if (field.isId) return false`). **Vérifié** par `z_list_column_deriver_test.dart` (liste d'exclus explicite).
- **Inclusions** : les 17 scalaires attendus (`text`…`color`) présents, dans l'ordre. **Vérifié**.
- **Ordre stable** : `order = index d'origine` dans le schéma (pré-filtrage) — test `a=1, b=3` malgré filtrage intermédiaire. ✅
- **Format par type** : `select/radio/checkbox` → `_resolveChoice` (repli `toString`) ; `multiple`/`tags`/`rowChips`/`Iterable` → join `', '` ; `dateTime/time` → ISO si `DateTime` sinon `toString` ; `number/integer/float/boolean` → `toString` ; `null` → `''` ; défaut → `toString`. **Vérifié cas par cas**.
- **Ne lève jamais** : test `format(Object()) returnsNormally`. Pur (aucun `BuildContext`, imports = `foundation` + types core). ✅
- **`ZColumnPolicy`** : additif, ne touche pas `ZFieldSpec`/annotations E2-4. **Précédence `forceExclude > forceInclude > défaut`** exacte dans `_isVisible` (exclude testé en 1er, include en 2nd, puis `isId`, puis whitelist). Test de conflit vert. ✅

### 3.2 Quatre états distincts & accessibles (AC6/AC7/AC8, AD-11) ✅
- `loading`/`empty`/`noResults`/`error` **réellement distincts** : `empty` (clé `list.empty` = "No data yet", `ValueKey('zListEmpty')`) **≠** `noResults` (clé `list.noResults` = "No results match your filters", `ValueKey('zListNoResults')`). Clés l10n + textes + ValueKeys différents. **Vérifié** (`dynamic_list_states_test.dart` : test dédié de distinction).
- `loading` et `error` portent `Semantics(liveRegion: true)` — **rejoué** via `flagsCollection.isLiveRegion == true`. ✅
- `error` affiche le message de la `ZFailure` (`failure.message`, non-null par contrat) préfixé par `list.error`. `Semantics.label` contient bien le message. ✅
- **Aucune chaîne codée en dur** (tout via `label(...)`, clés ajoutées à `_enLabels` **et** `_frLabels`). **Aucune couleur codée en dur** (`Theme.of(context).colorScheme.error`). Garde `style_purity` verte. ✅

### 3.3 Renderer non invoqué hors `ready` (AC7) — critique ✅
- `_renderViaBackend` appelé **uniquement** dans la branche `ZListReady() + ZListDataGridLayout()`. Les 4 états et les vues `builder`/`custom` ne le touchent pas.
- **Rejoué** `dynamic_list_renderer_not_called_test.dart` : compteur = **0** pour loading/empty/noResults/error ; = **1** pour ready+dataGrid. ✅

### 3.4 Vues `builder`/`custom` SANS `zcrud_list` (AC5) ✅
- `builder` → `_ZListBuilderView` = `ListView.builder` **dans le cœur** (`const ValueKey('zListBuilder')`, jamais `ListView(children:)`). `custom` → widget arbitraire. Aucun renderer requis.
- **Rejoué** `dynamic_list_layout_test.dart` : n'importe QUE `zcrud_core` (zéro `zcrud_list`/Syncfusion) et rend Alice/Bob + colonnes dérivées. ✅

### 3.5 SM-5 maintenue (AC9) ✅
- Cœur : **0** import/dep `syncfusion` (nouveaux fichiers `presentation/list/*` limités à `foundation`/`widgets`/`material` + types core). `ZSfDataGridRenderer` = **seule** arête Syncfusion (consomme `ZListColumn` : `label(context, col.header)`, `col.width`, `col.format(row.cells[col.name])`).
- **Rejoué** : graphe CORE OUT=0 ; `sm5_syncfusion_isolation_graph_test.dart` vert (fermeture core/markdown SANS syncfusion + contrôle positif list AVEC `syncfusion_flutter_datagrid` + acyclicité AD-1). ✅

### 3.6 Migration du contrat E4-1 (AC4) ✅
- `ZListRenderRequest.columns` : `List<ZFieldSpec>` → `List<ZListColumn>` + fabrique `fromSchema`. Égalité de valeur profonde préservée (`_listEquals`/`_mapEquals` pur-Dart, AD-1 out-degree 0).
- Tests E4-1 **migrés fonctionnellement** (pas supprimés) : `z_sf_data_grid_renderer_test.dart` vérifie en-têtes résolus + cellules formatées via `fromSchema` ; `dynamic_list_delegation_test.dart` et `z_list_render_request_test.dart` migrés vers `ZListColumn`/`fromSchema`/`.rows`. Le format neutre vit **une seule fois** dans le cœur (plus de `toString` dupliqué dans `zcrud_list`). ✅

### 3.7 Trous de couverture sondés ✅
- **Colonnes toutes exclues** (liste vide) : `deriveColumns` → `[]` ; renderer (`columns == []`), builder et custom rendent sans crash (tests L3 dédiés). ✅
- **`error` sans message** : `ZFailure.message` est `final String` non-null ; message `''` → rendu du préfixe seul, pas de crash (cosmétique uniquement). ✅
- **`custom` retournant `null`** : impossible — signature `Widget Function(...)` non-nullable (null-safety). ✅
- **Policy contradictoire** (`forceInclude ∩ forceExclude`) : `forceExclude` gagne (testé). ✅
- **Noms de colonnes dupliqués** : conservés (2 colonnes), comportement **défini et testé** (pas de dédoublonnage), rendu sans crash. ✅

---

## 4. Findings

### LOW-1 — Double annonce lecteur d'écran sur les vues `empty`/`noResults`/`error` (a11y, AD-13)
**Fichier** : `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart` (`_ZListMessageView` L154-175, `_ZListErrorView` L186-221).
**Constat** : ces vues posent un `Semantics(container: true, label: <texte>)` **au-dessus** de widgets `Text` visibles portant le **même** contenu, **sans** `excludeSemantics: true`. L'arbre sémantique contient alors le nœud conteneur (label) **et** les nœuds enfants `Text` → un lecteur d'écran lit le message **deux fois** (pour `_ZListErrorView` : « préfixe message », puis « préfixe », puis « message »).
**Écart de pattern** : le patron de référence cité par la story (`z_submit_button.dart:61`) pose `Semantics(liveRegion, container)` **sans `label:`** et laisse le `Text` enfant porter le contenu (pas de doublon) ; et `z_date_field_widget.dart:60` utilise `excludeSemantics: true` quand il pose un label au-dessus d'un enfant. `_ZListLoadingView` est correct (l'enfant `CircularProgressIndicator` n'a pas de texte, le `label:` est donc nécessaire et non redondant).
**Impact** : verbosité d'annonce (nuisance), **pas** une perte d'accessibilité — le contenu reste annoncé. Non bloquant.
**Correctif suggéré (trivial, dans le périmètre)** : ajouter `excludeSemantics: true` sur `_ZListMessageView`/`_ZListErrorView`, **ou** retirer le `label:` redondant et laisser les `Text` enfants parler (aligné sur `z_submit_button`).

### LOW-2 — En-têtes de colonnes résolus dans l'espace de noms générique `label()` (latent, systémique)
**Fichier** : `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart:52` (`label(context, col.header)`).
**Constat** : `col.header = field.label ?? field.name` est résolu via le helper l10n générique. Si un `header` coïncide **exactement** (casse comprise) avec une clé du chrome CRUD (`select`, `search`, `confirm`, `empty`, `required`, `loading`, `retry`, `add`, `edit`, `delete`, `close`, `remove`, `next`, `previous`, `rate`, `yes`, `no`…), il est **silencieusement remplacé** par le libellé du chrome (ex. un champ nommé `confirm` → en-tête "Confirm" ; un champ `required` → "This field is required").
**Nuance (abaisse la sévérité)** : comportement **systémique**, identique à tout le moteur d'édition E3 (`z_select/date/boolean/slider/tags/relation_field_widget` résolvent `field.label ?? field.name` via le même `label()`), et **conforme à la décision de conception** de la story (« header = clé non résolue, résolue au rendu via `label(context, header)` »). Ce n'est donc **pas** une régression E4-2 mais une propriété héritée du seam l10n.
**Impact** : latent, réservé aux `name`/`label` en collision exacte avec une clé de chrome ; aucun crash. Non bloquant.
**Piste (hors périmètre E4-2)** : envisager de router les en-têtes applicatifs **uniquement** via `ZcrudScope.labels` (espace métier) plutôt que par la table de chrome générique, ou documenter la réservation de noms — à traiter au niveau du seam l10n, pas de cette story.

### LOW-3 — `_ZListLoadingView` sans `ValueKey` (nit de cohérence)
**Fichier** : `packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart` (`_ZListLoadingView` L132-144).
**Constat** : `empty`/`noResults` (`viewKey`) et `error` (`ValueKey('zListError')`) portent une clé stable ; la vue `loading` n'en a pas (les tests la ciblent via `find.bySemanticsLabel`). Cohérence mineure, aucun impact fonctionnel. Optionnel.

---

## 5. Conformité AD (échantillon vérifié)
- **AD-1** : cœur OUT=0 (graphe), helpers d'égalité pur-Dart (pas de `package:collection`). ✅
- **AD-2/AD-15** : aucun gestionnaire d'état importé ; états via `sealed`/`switch` + `Semantics`, réactivité Flutter-native. ✅
- **AD-4** : `ZColumnPolicy` additif ; enum ouvert (`custom`) exclu par défaut, réinclusible par policy. ✅
- **AD-8** : dérivation neutre dans le cœur, Syncfusion isolé (seule arête `zcrud_list`). ✅
- **AD-10** : `format` défensif (`toString`/`fromJsonSafe`-like, ne lève jamais). ✅
- **AD-11** : `ZListError(ZFailure)` porte la failure ; état `error` annoncé. ✅
- **AD-13** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`center` ; `ListView.builder` ; `rowHeight`/`headerRowHeight` = 48 ; `const` ; `Semantics` explicites. Garde `style_purity` verte. ✅ (voir LOW-1 pour l'annonce redondante).

---

## 6. Décision

✅ **APPROVED.** Les 10 ACs sont satisfaits ; toutes les vérifications de merge sont **rejouées vertes sur disque**. Aucun finding HIGH/MAJEUR/MEDIUM. Les 3 findings LOW sont non bloquants ; **LOW-1** (a11y double-annonce) est le seul recommandé à corriger dans le périmètre car trivial et rattaché à l'invariant headline AD-13, mais reste optionnel selon la politique LOW du projet. LOW-2 est un point de conception systémique à traiter au niveau du seam l10n (hors périmètre E4-2). La story peut passer à `done`.
