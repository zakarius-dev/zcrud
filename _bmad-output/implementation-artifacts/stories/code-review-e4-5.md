# Code Review — Story E4-5 : Sous-listes / relations imbriquées (`ZSubListScreen`) & onglets de catégorisation (`ZTabbedList`)

- **Date** : 2026-07-10
- **Reviewer** : bmad-code-review (claude-opus-4-8) — chemin pris : **tool `Skill` → `bmad-code-review`** (step-file architecture, steps 01→02 ; step-02 exécuté en mode reviewer unique adversarial, subagents non disponibles dans ce contexte → les trois couches Blind Hunter / Edge Case Hunter / Acceptance Auditor ont été jouées inline par le reviewer).
- **Story** : `_bmad-output/implementation-artifacts/stories/e4-5-sous-listes-relations-onglets.md` (10 ACs, statut `review`).
- **Baseline** : `868438a` (frontmatter story). Diff = arbre de travail (E4 non commité).
- **Périmètre revu** :
  - `packages/zcrud_core/lib/src/presentation/list/z_list_controller.dart` (`baseFilters` additif)
  - `packages/zcrud_core/lib/src/presentation/list/z_sub_list_screen.dart` (nouveau)
  - `packages/zcrud_core/lib/src/presentation/list/z_tabbed_list.dart` (nouveau)
  - `packages/zcrud_core/lib/src/presentation/list/z_list_tab.dart` (nouveau)
  - `packages/zcrud_core/lib/zcrud_core.dart` (barrel : 3 exports)
  - tests `test/presentation/list/{z_list_controller_base_filters,z_sub_list_screen,z_tabbed_list}_test.dart`

## Verdict : **APPROVED**

Aucune fuite de relation inter-parents, aucune sélection partagée entre onglets, aucune fuite de contrôleur, aucune duplication d'E3-3b-2. SM-5 maintenue. Vérif verte réellement rejouée. Trois findings **LOW** (cosmétiques / défensifs / documentés), zéro HIGH / MAJEUR / MEDIUM.

## Triage par sévérité

| Sévérité | Nb | Statut |
|----------|----|--------|
| HIGH / CRITIQUE | 0 | — |
| MAJEUR | 0 | — |
| MEDIUM | 0 | — |
| LOW / nit | 3 | consignés (non bloquants) |

---

## Vérification adversariale des points de vigilance

### 1. Relation persistante — pas de fuite inter-parents (CRITIQUE) — ✅ VÉRIFIÉ, aucune fuite

- **Point d'émission UNIQUE** confirmé : `_buildRequest` (`z_list_controller.dart:188-201`) est le **seul** constructeur de `ZDataRequest`. Il compose `filters: baseFilters.isEmpty ? _filters : [...baseFilters, ..._filters]` (socle en tête). `_runQuery` (l.203-209) construit le `request` **une fois** et le passe à la fois à `repository.getAll` (backend, l.216) **et** à `_runInMemory` (l.212 mode inMemory + l.227 repli sur échec curseur). `_runInMemory` fait `request.copyWith(limit:null, startAfter:null)` — **préserve les filtres**. La relation est donc portée sur **tous** les chemins.
- **Aucun chemin utilisateur n'efface la relation** : `setFilters` (l.155) remplace **`_filters`** (filtres utilisateur) uniquement — `baseFilters` est `final` et re-ANDé à chaque `_buildRequest`. `setSearch`/`setSort`/`loadMore`/`refresh` passent tous par `_buildRequest`. Il n'existe aucun setter de `baseFilters` : socle immuable.
- **Rejoué réellement** : suite `z_list_controller_base_filters_test.dart` (6 tests) verte — relation ANDée dès la 1ʳᵉ requête ; `setFilters` **compose** (`[relation, userFilter]`, pas de remplacement) ; `setSearch`/`setSort` conservent la relation ; `loadMore` (page `startAfter != null`) porte encore la relation ; composition honorée **en mode inMemory** ; rétro-compat (`baseFilters` vide ⇒ requêtes strictement E4-3).
- **Widget** : `z_sub_list_screen_test.dart` AC1 (seuls les enfants de `p1`, `p2` absents) + AC3a/AC7 (recherche `App` masque Banana **sans** faire apparaître Cherry/Date de `p2`) verts. **Aucun chemin de fuite trouvé.**

### 2. Onglets — état/sélection indépendants — ✅ VÉRIFIÉ

- **Contrôleurs non recréés au switch** : `_KeepAliveTabPage` (`AutomaticKeepAliveClientMixin`, `wantKeepAlive => true`, `super.build` appelé) enveloppe chaque page ; clé stable `ValueKey('zTab_<labelKey>')`. Test AC5 : **compteur de création = 1** après A→B→A (recherche `o1` + sélection `{o1}` intactes au retour). Vert.
- **Sélections disjointes** : test AC6 — `{o1}` dans A, `{x1}` dans B, retour A ⇒ `{o1}` (pas `{x1}`). Vert. `ZTabbedList` ne détient/partage **aucune** `ZListSelectionController` (grep confirmé) : chaque onglet crée la sienne dans son `builder`. Pas de state partagé au niveau du widget → **aucune fuite structurelle possible** ; l'isolation est réelle (et, pour l'app, garantie par convention « une sélection par builder », documentée dans les docstrings).
- **Reset sur changement de relation intra-`ZSubListScreen`** : `didUpdateWidget` (l.172-187) recrée le contrôleur + `selection?.clearSelection()` sur changement de `parentField`/`parentId`/`repository`. Test AC8b vert (parentId p1→p2 ⇒ sélection vidée, enfants de p2 affichés). Persistance par `id` intra-relation prouvée (AC8a). LOW-3 (E4-4) correctement tranché.

### 3. Réutilisation E4-3/E4-4 (pas de duplication) — ✅ VÉRIFIÉ

- `ZSubListScreen.build` délègue intégralement à `DynamicList<T>` (`fields/state/layout/renderer/rowActions/entityFor/actionAclMode/selection/collectionId`) + `_controller.setSearch`. **Rien de réimplémenté** : pas de moteur de recherche/pagination/mapping/action local. `ZListController` est réutilisé tel quel (élargi d'un seul champ additif).
- Mini-CRUD prouvé dans la sous-liste : recherche sans accents (AC3a), `ZAcl` masque `delete` (AC3b, `_DenyAcl`), soft-delete exclut / restore réinclut **en restant parent-filtré** (AC3c via `watchMutations`), sélection stable au rebuild (AC3d). Tous verts.

### 4. Anti-duplication E3-3b-2 — ✅ VÉRIFIÉ

- `git status` : `presentation/edition/families/` et `domain/edition/z_sub_list_config.dart` **non modifiés**. Les nouveaux fichiers vivent exclusivement sous `presentation/list/`. Aucun import de `z_sub_list_field_widget`/`z_dynamic_item_field_widget`/`ZSubListConfig`. La distinction champ-inline (E3-3b-2) vs écran-liste-relié (E4-5) est respectée et documentée dans la docstring de `z_sub_list_screen.dart`.

### 5. SM-5 maintenue — ✅ VÉRIFIÉ

- Grep sur les 3 nouveaux fichiers : **0** `syncfusion` / `cloud_firestore` / `firebase` / `hive` / gestionnaire d'état en **import** (les seules occurrences sont des lignes de **commentaire** de docstring). Imports réels limités à `package:flutter/{material,widgets}.dart` + types `zcrud_core`.
- Chrome onglets = `TabBar`/`TabBarView` pur-Flutter Material. `ZSfDataGridRenderer`/`zcrud_list` **inchangés** (non touchés par le diff). Tests en layout `builder` (`ZListBuilderLayout`) → SM-5 **exécutable sans `zcrud_list`**.
- `melos run verify` : **`out-degree(zcrud_core) = 0 (runtime)`**, **`ACYCLIQUE OK`**, **`CORE OUT=0 OK`**. Graphe SM-5 vert (suite `zcrud_list` : `ZSfDataGridRenderer` seule arête Syncfusion). `pubspec.yaml` `zcrud_core` inchangé (0 dépendance ajoutée, AD-1).

### 6. Réactivité (AD-2/AD-15) & cycle de vie — ✅ VÉRIFIÉ

- `ZSubListScreen` : contrôleur possédé dans le `State`, créé en `initState`, `dispose()` propre, recréé+disposé en `didUpdateWidget`. Écoute la **seule** tranche `controller.state` via `ValueListenableBuilder` (rebuild ciblé). Pas de `setState` global.
- `ZTabbedList` : `TabController` disposé (`dispose` + `didUpdateWidget` sur changement de longueur, listener retiré avant dispose). Pages keep-alive disposées uniquement au démontage du `ZTabbedList` (pas au switch) → pas de fuite ni de recréation.
- **Garde anti-fuite au démontage pendant chargement** : `_runQuery`/`_runInMemory` rejettent tout commit/émission si `_disposed || gen != _generation` (garde M-1, l.219/250) ; `_emit` re-vérifie `_disposed`. Un `dispose()` pendant un chargement d'onglet ne provoque ni « emit après dispose » ni fuite.

---

## Findings

### LOW-1 — Texte de recherche « fantôme » après changement de `parentId` (cosmétique)
`z_sub_list_screen.dart:216,242-243` — la barre `_SubListSearchBar` est un `TextField` **non contrôlé** à clé fixe `ValueKey('zSubListSearch')`. Sur changement de `parentId` (`didUpdateWidget`), le contrôleur est recréé avec `_search = null` (liste correctement **non filtrée** sur le nouveau parent), mais le `TextField` conserve sa position/clé et **garde le texte saisi** précédemment. Résultat : la boîte affiche une requête obsolète alors que la liste montre tous les enfants du nouveau parent.
- **Impact** : purement **cosmétique** — aucune donnée erronée ni fuite (la liste est correcte) ; l'incohérence se corrige à la frappe suivante. Non bloquant.
- **Piste** : effacer le champ sur changement de relation (ex. `TextEditingController` détenu par le `State` et `.clear()` dans `didUpdateWidget`), ou re-keyer la barre sur `parentId`.

### LOW-2 — `labelKey` dupliqué entre onglets ⇒ collision de `ValueKey` (défensif)
`z_tabbed_list.dart:144` — les pages du `TabBarView` sont keyées `ValueKey('zTab_${tab.labelKey}')`. Deux onglets partageant le même `labelKey` produisent des clés **identiques** entre frères ⇒ erreur Flutter « Multiple widgets used the same key ». Requiert une mauvaise configuration côté app, mais aucun `assert` ne le signale.
- **Impact** : erreur seulement en cas de config app invalide. Non bloquant.
- **Piste** : `assert` d'unicité des `labelKey` (ou keyer sur l'index) — nit défensif.

### LOW-3 — `didUpdateWidget` ne recycle pas le contrôleur sur changement de props non-relationnelles (documenté)
`z_sub_list_screen.dart:172-187` — seul `parentField`/`parentId`/`repository` déclenche la recréation. Un changement dynamique de `pageSize`/`schema`/`toRow`/`watchMutations` reste **silencieux** (contrôleur inchangé). C'est l'hypothèse « props stables » explicitement documentée (Dev Notes #5), cohérente avec le périmètre.
- **Impact** : nul dans l'usage prévu (props stables). Nit / documentation.

---

## Trous de couverture (non bloquants)

1. **`showSearch:true` + changement de `parentId`** non testé → c'est le scénario de LOW-1 (texte fantôme). AC8b teste le changement de parent **sans** barre de recherche.
2. **`ZTabbedList` avec `tabs` vide / à un seul onglet** non testé. (Vérifié par lecture : `initialIndex.clamp(0,0)` + `TabController(length:0)` ne lèvent pas — `length==0` autorisé — mais aucun test ne le fige.)
3. **`baseFilters` + recherche + pagination combinés dans un fake filtrant** : la persistance sur `loadMore` est prouvée avec `_RecordingRepo` (qui n'applique pas le filtre, ne vérifie que le transport) ; la combinaison relation+recherche+`loadMore` sur un fake **filtrant réellement** (`_FakeChildRepo`) n'est pas exercée bout à bout. Couverture indirecte suffisante (transport prouvé + filtrage prouvé séparément), mais non combinée.
4. **`dispose` pendant chargement d'onglet** non testé explicitement ici (garde M-1 couverte par la suite E4-3).

---

## Résultats de vérification RÉELLEMENT rejoués

| Contrôle | Commande | Résultat |
|----------|----------|----------|
| Analyze | `dart run melos run analyze` | **RC=0** — 14 pkgs, « No issues found! » partout |
| Tests cœur | `flutter test` (zcrud_core) | **RC=0 — 562 tests passés** (dont 17 nouveaux E4-5) |
| Tests liste (SM-5 graphe) | `flutter test` (zcrud_list) | **RC=0 — 20 tests passés** |
| Verify | `dart run melos run verify` | **RC=0** — `CORE OUT=0 OK`, `ACYCLIQUE OK`, gates reflectable/secrets/codegen/compat verts ; `verify:serialization` passant (corpus AD-10) + SKIP pour list/riverpod/provider/annotations |
| Packages | `melos list` | **14** |
| Code généré suivi | `git ls-files '*.g.dart'` | **0** |
| Pureté nouveaux fichiers | grep syncfusion/backend/état | **0 import** (occurrences uniquement en commentaire) |
| Anti-dup E3-3b-2 | `git status` families/ + z_sub_list_config | **non modifiés** |
| RTL/a11y (AD-13) | grep left/right/only(left) | **0 violation** ; `Tab(height:48)`, `EdgeInsetsDirectional`, `TextAlign.start`, libellés via seam l10n |
| Barrel | grep exports | 3 exports (`z_list_tab`, `z_sub_list_screen`, `z_tabbed_list`) présents |

**Non-régression** : suites E4-1/E4-2/E4-3/E4-4 et E3-3b-2 vertes (élargissement `baseFilters` **additif** rétro-compatible ; `DynamicList`/renderer/E3 inchangés).

---

## Conclusion

Les deux surfaces de composition (`ZSubListScreen`, `ZTabbedList`) sont des **assembleurs minces** qui réutilisent E4-1..E4-4 sans réinventer de machinerie. La garantie critique — **la relation parent ne peut jamais fuiter** (point d'émission unique, socle immuable ANDé sur tous les chemins backend + in-memory + loadMore) — est correctement conçue et **prouvée par les tests**. Sélections isolées par onglet, état préservé au switch (contrôleur non recréé), aucune duplication d'E3-3b-2, SM-5 intacte, vérif verte réelle. Les 3 findings sont **LOW** (cosmétique / défensif / documenté).

**Verdict : APPROVED.** Correction des LOW **optionnelle** (LOW-1 recommandée si la barre de recherche intégrée est utilisée avec des changements de parent dynamiques). Prêt pour `done` puis rétrospective E4.
