# Story 2.3: Branchement de la sélection multiple sur la liste de flashcards

Status: review

<!-- Note: Validation optionnelle. Lancer validate-create-story avant dev-story si souhaité. -->

## Story

As an utilisateur,
I want sélectionner plusieurs flashcards directement dans ma liste,
so that je les supprime (ou déplace / retague) par paquets sans ouvrir un éditeur — et sans jamais laisser derrière moi un état SRS orphelin.

**Couvre :** FR-SU19 (branchement sur la liste). **Ligne sprint-status :** `[M][SÉQ — après me-2 ; dépend su-8 + me-1] FR-SU19 (branchement) la liste CONSOMME le contrôleur de me-1 (n'en redéclare aucun) ; suppression par lot = cascade AD-21 (purge SRS, corrige la dette d'orphelins lex) ; liste reste fonctionnelle SANS sélection (aucune régression de su-8)`

---

## Contexte d'implémentation (à lire AVANT de coder)

### Où vit `ZFlashcardListView` — placement PROUVÉ acyclique (package touché)

`grep -rln "class ZFlashcardListView" packages/*/lib` ⇒ **`packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart`** (RC=0). **me-3 branche donc dans `zcrud_study`, PAS dans `zcrud_core`/`zcrud_list`.** Le moteur de sélection (me-1) vit déjà dans `zcrud_core` et est **fini** — me-3 le **CONSOMME**, ne réécrit aucun contrôleur, aucune action de lot.

**Acyclicité (AD-1, CORE OUT=0 inchangé).** Toutes les arêtes utilisées existent déjà : `zcrud_study → zcrud_core` (contrôleur me-1) et `zcrud_study → zcrud_flashcard` (`ZFlashcard`, `ZRepetitionInfo`, `ZRepetitionStore`) — vérifié `pubspec.yaml` (`zcrud_core: ^0.2.1`, `zcrud_flashcard: ^0.2.1`). **Jamais l'inverse.** me-3 n'ajoute **aucune** nouvelle arête. `graph_proof` reste vert par construction.

### Les acquis à CONSOMMER (livrés, verts — ne PAS les refaire) — vérifiés sur disque

- **me-1 — `ZListSelectionController`** (`packages/zcrud_core/lib/src/presentation/list/z_list_selection.dart`) : `ChangeNotifier` pur, mode `ZListSelectionMode` (**enum**, pas de booléen), sélection keyée par **`id` STABLE** (jamais index). API à consommer telle quelle :
  - `Future<ZBatchDeletionReport> batchDelete({required Future<ZResult<Unit>> Function(String rootId) deleteRoot})` — **seam INJECTÉ**, `await`é **par racine**, la cascade AD-21 et la borne ≤ 450 sont la **propriété du seam**, pas du cœur. Racines réussies retirées de la sélection, échouées conservées, tout `throw` capté (AD-10).
  - `batchMove({required String? attachmentField, required Object? destination, required moveRoot})` — champ de rattachement **PARAMÉTRIQUE** (jamais `folder_id` en dur) ; `attachmentField` null/vide ⇒ chaque racine rapportée en échec, **aucune écriture**.
  - `applyCommonField(...)` — hors périmètre me-3 (édition groupée de champ).
- **me-1 — `ZBatchAction` / `ZBatchActionBar`** (`z_batch_action.dart`) : barre de présentation `const`, actions **DÉCLARÉES en données** (`ZBatchActionKind` enum, action **absente si non fournie** — jamais grisée), `ZcrudTheme.of` (repli `Theme.of`), `countLabelBuilder` injecté. À CONSOMMER, pas à recréer.
- **me-1 — `ZBatchDeletionReport` (= `ZBatchReport`)** (`z_batch_deletion_report.dart`) : `succeededRootIds : Set<String>`, `failures : Map<String, ZFailure>`, `failedCount`, `failedRootIds`. **L'appelant reçoit TOUJOURS les racines échouées** — un lot n'est jamais silencieusement partiel.
- **su-8 — `ZFlashcardListView`** (`zcrud_study`) : grille virtualisée `ZAdaptiveGrid.builder`, recherche normalisée, filtres, tri, **ordre manuel** (`ZFolderContentsOrder` + `applyOrder`, AD-38), menu par item (`ZItemActionsMenu`, actions `null ⇒ absente`). **Sa dartdoc constructeur affirme explicitement : « ne précâble rien — aucun `selectionController`, aucun paramètre » (lignes 31-32).** me-3 lève cette limite de façon **STRICTEMENT ADDITIVE**.
- **me-2 — `ZMultiFlashcardEditor`** consomme DÉJÀ `ZListSelectionController` + `ZBatchActionBar` (pattern : `final ZListSelectionController? selection;` injecté, sinon `_selection = ZListSelectionController(mode: multiple)` créé en interne et **disposé**). **Réutiliser ce pattern de propriété unique** pour la liste (cohérence me-2 ↔ me-3).

### LE point dur n°1 — la primitive de purge SRS MANQUE (racine de la dette d'orphelins lex)

`grep -n "delete\|remove" packages/zcrud_flashcard/lib/src/data/z_repetition_store.dart` ⇒ `ZRepetitionStore` expose `getByCard` / `put` / `getAll` / `sync` — **AUCUNE suppression** (grep `deleteByCard|purgeForCard|removeByCard` sur `packages/*/lib` ⇒ **RC=1**, n'existe nulle part). **C'est exactement la dette d'orphelins de lex** : on supprimait la carte, l'état SRS **survivait faute de primitive de purge**. me-3 corrige la cause, pas seulement le symptôme :

1. **Ajouter au port `ZRepetitionStore` (zcrud_flashcard) :** `Future<ZResult<Unit>> deleteByCard(String flashcardId)` — purge idempotente (absence ⇒ `Right(unit)`, jamais d'échec, AD-10). Additif, aucun adaptateur Firestore concret n'existe dans le monorepo (`grep -rln repetition packages/zcrud_firestore/lib` ⇒ vide) : les implémenteurs concrets vivent app-side ; les fakes de test l'implémentent.
2. **Fournir un seam de cascade study-side** `zFlashcardCascadeDeleteRoot({required deleteCard, required ZRepetitionStore repetitionStore})` (nouveau fichier `zcrud_study`) qui **compose** `deleteCard(rootId)` **PUIS** `repetitionStore.deleteByCard(rootId)` et renvoie le `Future<ZResult<Unit>> Function(String rootId)` attendu par `batchDelete`. **C'est le point de composition unique de la purge SRS.** Le widget ne l'importe pas ; l'app l'assemble et l'injecte.

### CORE OUT=0 / isolation deps (AD-1, AD-11, AD-16) — le seam reste INJECTÉ

`grep -nE "ZRepetitionStore|ZRepository|zcrud_firestore|ZLocalStore|ZRemoteStore" z_flashcard_list_view.dart` ⇒ **RC=1** (aucun store dans la vue aujourd'hui). **Invariant à préserver :** la vue reste **PURE** — la suppression/purge n'entre QUE par un callback injecté. L'import de `ZRepetitionStore` est autorisé **uniquement** dans le seam builder study-side (`zcrud_study → zcrud_flashcard`, arête existante), **jamais** dans le widget. Garde de pureté récursive existante : `packages/zcrud_study/test/presentation/z_widgets_purity_test.dart`.

---

## Acceptance Criteria

### AC1 — Branchement : la liste CONSOMME le contrôleur me-1 (propriétaire UNIQUE, AD-44)
**Given** `ZFlashcardListView` (su-8) et la capacité moteur (me-1)
**When** la sélection multiple est activée (nouveau paramètre additif fourni)
**Then** la liste **consomme** un `ZListSelectionController` — **propriétaire unique** détenu par la surface de liste (injecté et alors utilisé tel quel, sinon créé **et disposé** en interne — pattern me-2). Le **MÊME** contrôleur (identité `identical`) alimente les cases à cocher **et** la `ZBatchActionBar` — **aucun 2e état de sélection n'est déclaré** par un widget d'action.

### AC2 — Aucune régression su-8 : la liste reste 100 % fonctionnelle SANS sélection (dégradation propre)
**Given** aucun câblage de sélection (paramètres additifs absents / `null`)
**When** la liste s'affiche et s'utilise
**Then** elle est **identique à su-8** : **zéro** case à cocher, **zéro** `ZBatchActionBar`, menus par item / drag / boutons a11y / recherche / filtres / tri / ordre manuel **inchangés**. Les tests su-8 existants restent **verts sans modification**.

### AC3 — Actions de lot DÉCLARÉES en données (AD-44) : delete/move + slot custom, absente si non fournie
**Given** le mode sélection actif
**When** la barre d'actions se compose
**Then** `delete`, `move` et le **slot d'actions personnalisées** sont **déclarés** : une action **absente** (seam non fourni) est **absente** de la barre (jamais grisée). « Déplacer » réaffecte le **champ de rattachement DÉCLARÉ par le modèle** (via `batchMove(attachmentField:)` — jamais `folder_id` codé en dur), destination fournie par un **sélecteur injecté**.

### AC4 — Suppression par lot = `batchDelete` awaited + rapport AD-39 (jamais silencieusement partiel)
**Given** une sélection non vide et une action « supprimer »
**When** elle s'exécute
**Then** elle appelle `controller.batchDelete(deleteRoot: <seam cascade injecté>)`, **`await`é par racine**, et retourne un `ZBatchDeletionReport`. Les racines réussies sont **retirées de la sélection**, les échouées **y restent**, **aucun `throw`** ne remonte (AD-10). L'appelant reçoit **toujours** `succeededRootIds` **et** `failures`.

### AC5 — Purge SRS FALSIFIABLE : chaque carte supprimée voit son état SRS purgé (dette lex corrigée)
**Given** un seam de cascade composant suppression carte + `ZRepetitionStore.deleteByCard`
**When** un lot de **N** cartes ayant chacune un `ZRepetitionInfo` est supprimé
**Then** l'état SRS de **chacune** des N cartes est **purgé** (compte **EXACT** : N `deleteByCard` sur les **bons** `id`, aucun état SRS survivant), prouvé par un **espion (fake `ZRepetitionStore`) PROUVÉ captant AVANT** (témoin : une carte au SRS présent, un `deleteByCard` témoin le retire ⇒ assert store vide pour cet `id` — sinon l'assertion « purgé » serait infalsifiable). **Injection R3 rougissante par le COMPORTEMENT** : si la branche `deleteByCard` est sautée (carte supprimée sans purge — le bug lex), le test **ROUGIT** (un `ZRepetitionInfo` survit).

### AC6 — Échec partiel RAPPORTÉ, jamais avalé (AD-39), les autres racines continuent
**Given** un lot dont la cascade d'**une** racine échoue (`Left(ZFailure)` sur la suppression **ou** la purge SRS)
**When** le lot s'exécute
**Then** cette racine figure dans `report.failedRootIds` **avec sa cause**, les **autres** racines sont **supprimées ET leur SRS purgé** (`succeededCount == N-1`), et le lot **n'est jamais silencieusement partiel**. Une purge SRS qui échoue **après** la suppression de la carte est rapportée comme échec de la racine (pas avalée).

### AC7 — Borne AD-21 ≤ 450 respectée par délégation (dépassement découpé côté seam)
**Given** la cascade par racine (carte = **racine** ; cascade = {carte + `ZRepetitionInfo`} ≈ 2 écritures ≪ 450)
**When** un lot de M racines est supprimé
**Then** `batchDelete` **`await`e racine par racine** (M cascades atomiques successives, pas un plan monolithique non borné) et la **borne ≤ 450 par cascade** reste la **propriété du seam/batcher injecté** (`ZFirestoreCascadeBatcher` app-side, AD-21). me-3 **ne réimplémente aucun batcher** et n'émet aucun plan > 450.

### AC8 — SM-1 : rebuild granulaire, `enum` pour l'état de sélection (pas de booléen)
**Given** le mode sélection actif
**When** l'utilisateur entre/sort du mode ou coche **une** carte
**Then** **seules** la tuile concernée et la barre se reconstruisent (écoute de tranche via `ListenableBuilder`/`ValueListenableBuilder` sur le contrôleur) — **jamais** toute la liste (aucun `setState` à l'échelle liste). L'état de sélection est porté par l'**enum** `ZListSelectionMode`, **jamais** un booléen. Prouvé par un compteur de builds (cocher 1 carte ⇒ 1 tuile reconstruite, pas N).

### AC9 — a11y / RTL / l10n (AD-13) : cibles ≥ 48 dp, directionnel, annonce UNIQUE
**Given** le mode sélection actif
**When** un lecteur d'écran explore la liste
**Then** les cases à cocher ont une cible **≥ 48 dp**, un layout **directionnel** (jamais `EdgeInsets.only(left/right)` etc.), et un `Semantics` annonce **le mode sélection + le nombre sélectionné** via une **source unique** (**pas de double annonce**). Tous les libellés sont **INJECTÉS** (aucun libellé/couleur en dur).

### AC10 — Robustesse (AD-10) : tous les cas-limites ont un résultat DÉFINI
**Given** l'un des cas suivant
**When** il survient
**Then** le résultat est défini, **aucun `throw`** : liste **vide** · sélection **vide** (`batchDelete` no-op, rapport vide) · suppression **pendant un filtre/tri actif** (la sélection keyée par **`id` stable** ne perd **aucun `id` non visible** — leçon su-8 : jamais d'index/position) · dépassement 450 (délégué au seam borné, AC7) · **échec de purge SRS d'une carte** (rapporté, les autres continuent, AC6) · `attachmentField` absent sur « déplacer » (rapporté, aucune écriture).

### AC11 — Isolation deps / CORE OUT=0 : le widget reste PUR, le seam est INJECTÉ
**Given** l'implémentation
**When** on inspecte les imports
**Then** `z_flashcard_list_view.dart` n'importe **aucun** store concret (`ZRepetitionStore`, `ZRepository`, `zcrud_firestore`, `ZLocalStore`, `ZRemoteStore`) — prouvé par la **garde de pureté récursive** (`z_widgets_purity_test.dart`) **+** un **grep négatif dédié** (commande + RC dans le File List). L'import de `ZRepetitionStore` est confiné au **seam builder study-side**. `graph_proof` vert, acyclicité et CORE OUT=0 **inchangés**.

---

## Tasks / Subtasks

- [x] **T1 — Primitive de purge SRS (zcrud_flashcard)** (AC5, AC6)
  - [x] Ajouter `Future<ZResult<Unit>> deleteByCard(String flashcardId)` au port `ZRepetitionStore` (dartdoc : purge **idempotente**, absence ⇒ `Right(unit)`, jamais d'échec sur absence — AD-10).
  - [x] Mettre à jour tout implémenteur/fake in-repo (compilation) ; **aucun** adaptateur Firestore concret n'existe (vérifié) — ne rien inventer côté persistance.
- [x] **T2 — Seam de cascade study-side** (AC4, AC5, AC7)
  - [x] Nouveau fichier `zcrud_study` : `zFlashcardCascadeDeleteRoot({required Future<ZResult<Unit>> Function(String) deleteCard, required ZRepetitionStore repetitionStore})` ⇒ compose `deleteCard(rootId)` **puis** `repetitionStore.deleteByCard(rootId)` (short-circuit sur `Left` de la suppression carte ; purge SRS `await`ée ; renvoie `Left` si la purge échoue). Export barrel.
- [x] **T3 — Branchement additif dans `ZFlashcardListView`** (AC1, AC2, AC3, AC8, AC9)
  - [x] Nouveaux paramètres **optionnels** (défaut absent = comportement su-8) : contrôleur de sélection (injecté ou créé+disposé, propriétaire unique) ; seams `onBatchDelete`/`onBatchMove` ; slot d'actions custom ; libellés de sélection injectés. Mettre à jour la dartdoc constructeur (retirer « ne précâble rien »).
  - [x] Cases à cocher par tuile (≥ 48 dp, directionnel, `ValueKey(id)`), écoute de tranche sur le contrôleur (SM-1), `Semantics` de mode+compte à **source unique**.
  - [x] Composer la `ZBatchActionBar` me-1 (actions déclarées, absente si seam `null`) — jamais un 2e état de sélection.
- [x] **T4 — Tests porteurs** (tous les ACs) — voir « Stratégie de preuve » ci-dessous.
  - [x] AC1 identité contrôleur · AC2 non-régression (zéro case/barre sans câblage + su-8 verts) · AC3 action absente si seam null + move param · **AC5 purge SRS falsifiable (espion prouvé captant AVANT, compte exact, R3 rougissant)** · AC6 échec partiel rapporté · AC7 await par racine · AC8 granularité (compteur builds) · AC9 a11y (finder ≥48dp + Semantics unique) · AC10 cas-limites · AC11 grep négatif + purity guard.
- [x] **T5 — Vérif verte + gates** (repo-wide)
  - [x] `melos run generate` (T1 modifie un port — régénérer si `*.g.dart` impacté) + committer les `*.g.dart` de `packages/*/lib`. → **aucun `*.g.dart` impacté** : `deleteByCard` est ajouté à une classe **abstraite** (aucun `part`/codegen) et le seam est une fonction pure — rien à régénérer.
  - [x] `dart analyze` RC=0 · `flutter test` **par package** (`zcrud_flashcard`, `zcrud_study`) RC=0 · `melos run analyze` **ET** `melos run verify` **REPO-WIDE** (détecte une régression cross-package).

---

## Stratégie de preuve — purge SRS AD-21/AD-39 FALSIFIABLE (LE point dur)

> **Leçon su-10 (même famille) : un grade SRS était SILENCIEUSEMENT sauté — l'espion ne captait pas le bon canal.** Reproduire = échec de revue. **La prose ment** : asserter le comportement réel, jamais la dartdoc.

**Étage (a) — espion PROUVÉ captant AVANT l'assertion.** Le fake `ZRepetitionStore` enregistre les `deleteByCard(id)` reçus. **Témoin d'abord** : semer un `ZRepetitionInfo` pour la carte `A`, appeler la cascade sur `A`, **assert `store.getByCard('A') == null` ET `deletedIds == ['A']`** — preuve que l'espion capte réellement le bon canal (sinon les étages suivants seraient infalsifiables).

**Étage (b) — compte EXACT sur un lot.** Semer un SRS pour chacune de N cartes sélectionnées ; `batchDelete(deleteRoot: zFlashcardCascadeDeleteRoot(...))`. **Assert** : `deletedIds` = **exactement** les N `id` sélectionnés (les **bons** `id`, pas des voisins — leçon su-8/me-1), `report.succeededCount == N`, `report.failedCount == 0`, et **aucun** `ZRepetitionInfo` ne survit.

**Étage (c) — R3 rougissant par le COMPORTEMENT.** Le test doit **ROUGIR** si la branche purge est retirée du seam (`deleteCard` seul, sans `deleteByCard`) : la carte disparaît mais un `ZRepetitionInfo` **survit** ⇒ assertion « aucun SRS survivant » RED. Consigner l'injection (SHA/diff) dans le Dev Agent Record — **on ne modifie JAMAIS un test pour taire le défaut**.

**Étage (d) — échec partiel rapporté (AD-39).** Fake store faisant échouer `deleteByCard('K')` (une racine) : **assert** `report.failedRootIds == {'K'}` avec cause, `succeededCount == N-1`, SRS des N-1 purgé, la carte `K` **pas** silencieusement « réussie ». Idem si `deleteCard('K')` échoue en amont : purge SRS de `K` **non tentée** (short-circuit), racine rapportée échouée.

**Chasse aux voies de fuite (leçon su-8 : le HIGH passait par une voie NON anticipée).** Prouver l'**absence** (grep négatif, commande + RC) :
- pas d'import de store concret dans la vue (purity guard + grep) — AC11 ;
- pas de cascade **non awaited** (fire-and-forget) : `batchDelete` `await`e par racine — asserter l'ordre/complétude ;
- pas de dépassement 450 émis par me-3 (aucun plan monolithique — délégation par racine, AC7) ;
- pas de sélection keyée par index : réordonner/filtrer pendant une sélection ne perd **aucun `id` non visible** (AC10).

---

## Dev Notes

### État actuel du fichier UPDATE `z_flashcard_list_view.dart` (lu intégralement, 984 lignes)
- `StatefulWidget` avec `_ZFlashcardListViewState` ; controller de recherche **STABLE** (créé une fois, disposé — le recréer perdrait focus/sélection : bug historique n°1). **Réutiliser cette discipline** pour le contrôleur de sélection.
- Tuiles construites via `_buildTile` → `ZItemActionsMenu` ; actions `null ⇒ absente` (jamais grisée) — **même sémantique** à réutiliser pour les actions de lot.
- **À préserver end-to-end** (au-delà des ACs) : virtualisation `ZAdaptiveGrid.builder`, recherche débouncée qui **prime**, ordre manuel `applyOrder` (AD-38), `contentBuilder` AD-40, badges type/source à repli sur clé. Le mode sélection est **additif** : il ne doit **rien** casser de ces comportements.

### Frontières (hors périmètre me-3)
- **PAS** de nouvelle capacité moteur (me-1 est fini — on consomme). **PAS** le multi-éditeur (me-2). **PAS** `applyCommonField` (édition groupée de champ commun). **PAS** de régression su-8.
- **PAS** d'adaptateur Firestore concret pour `ZRepetitionStore` (n'existe pas dans le monorepo ; app-side). La borne ≤ 450 est **propriété du seam injecté**, pas de me-3.

### Project Structure Notes
- Packages touchés : **`zcrud_study`** (branchement + seam builder) et **`zcrud_flashcard`** (primitive `deleteByCard` sur le port). **Aucune** écriture dans `zcrud_core`/`zcrud_list` (me-1 fini). me-3 = **seul workstream en vol** (SÉQ strict). Acyclicité et CORE OUT=0 **inchangés** — aucune arête ajoutée.
- Nomenclature `Z*`, snake_case fichiers, barrel `lib/zcrud_study.dart` / `lib/zcrud_flashcard.dart`, `Either<ZFailure,T>` / `Unit`, enums camelCase.

### Écarts tranchés (mode NON-INTERACTIF — option conservatrice, consignée)
1. **Primitive `ZRepetitionStore.deleteByCard` ajoutée (zcrud_flashcard).** Le port n'avait **aucune** suppression (grep RC=1) — c'est la **cause** de la dette d'orphelins lex. Option conservatrice : corriger la **cause** (primitive idempotente additive) plutôt que reléguer la purge à une composition app-side qui, sans primitive, ne pourrait pas purger. Additif, aucun adaptateur concret impacté dans le monorepo.
2. **Seam de cascade `zFlashcardCascadeDeleteRoot` fourni côté `zcrud_study`** (pas laissé entièrement à l'app) : il matérialise et **rend testable** (falsifiable) la composition carte+SRS, tout en gardant le **widget pur** (seam injecté). C'est ce qui **corrige** effectivement la dette lex plutôt que de la re-documenter.
3. **Pattern de propriété de la sélection = celui de me-2** (`ZListSelectionController?` injecté, sinon créé+disposé), pour cohérence me-2 ↔ me-3 et propriétaire unique AD-44.
4. **Borne ≤ 450 non réimplémentée par me-3** : `batchDelete` await par racine, chaque cascade (≈ 2 écritures) est ≪ 450 ; la composition d'un lot volumineux reste bornée côté seam/batcher app-side (AD-21, arbitrage T7 « rapport à l'élément racine »). AC7 le spécifie et le teste par délégation.

### References
- [Source: epics.md#Story 2.3] `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md` (l. 693-720)
- [Source: ARCHITECTURE-SPINE.md#AD-44] sélection possédée par la liste, actions déclarées, lot dérivé du `ZFieldSpec`
- [Source: ARCHITECTURE-SPINE.md#AD-39] suppression persistée : cascade AD-21 awaited + rapport par élément racine
- [Source: ARCHITECTURE-SPINE.md#AD-43] frontière brouillon/persistance (liste = **directe**, persiste immédiatement)
- [Source: ARCHITECTURE-SPINE.md#Invariants hérités] AD-1, AD-2/AD-15, AD-10, AD-13, AD-21
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#l.226] `ZFirestoreCascadeBatcher` borne ≤ 450/lot (app-side)
- [Source: z_list_selection.dart] `batchDelete`/`batchMove`/`ZBatchDeletionReport` (me-1, `zcrud_core`)
- [Source: z_flashcard_list_view.dart] su-8 (`zcrud_study`, 984 l.) — fichier UPDATE
- [Source: z_repetition_store.dart] `ZRepetitionStore` (zcrud_flashcard) — **sans** suppression avant me-3
- [Source: z_multi_flashcard_editor.dart] me-2 — pattern de propriété du contrôleur de sélection
- [Source: CLAUDE.md] invariants zcrud, gates repo-wide, discipline R3

---

## Dev Agent Record

### Agent Model Used
Opus 4.8 (1M context) — `claude-opus-4-8[1m]`

### Debug Log References
- `flutter test` `zcrud_flashcard` → **545** tests, RC=0 (> 541 attendu).
- `flutter test` `zcrud_study` → **483** tests, RC=0 (> 462 attendu).
- `dart run melos run analyze` → RC=0 (SUCCESS ; une `warning unused_import` transitoire dans le test de purge a été corrigée avant clôture).
- `dart run melos run verify` → RC=0 (codegen-distribution + corpus `serialization-compat`).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK** (57 arêtes ; aucune nouvelle).

#### Code-review me-3 — remédiation (post-review)
- Rapport détaillé : `_bmad-output/implementation-artifacts/stories/code-review-me-3.md`.
- 0 HIGH/MAJEUR ; **5 MEDIUM corrigés** (MED-1..5, chacun avec un test porteur rouge→vert) ; **LOW-A/LOW-B** corrigés (éditorial « la prose ment ») ; **LOW-C/LOW-D** renforcés (assertions cheap ajoutées).
- `flutter test` `zcrud_study` → **490** tests, RC=0 (+7 porteurs : MED-1 delete/move, MED-2, MED-3, MED-4, MED-5 ×2).
- `flutter test` `zcrud_flashcard` → **545** tests, RC=0 (inchangé — aucune modif de ce package en remédiation).
- `dart analyze packages/zcrud_study packages/zcrud_flashcard` (= gate `melos run analyze` `dart analyze .`) → **RC=0** (42 infos pré-existantes en fichiers non touchés ; 0 introduite par la remédiation ; `z_flashcard_list_view.dart` NON flaggé). NB : `flutter analyze` rend RC=1 sur ces infos (fatal-infos implicite) — le gate projet est `dart analyze`, RC=0.
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK** (57 arêtes, aucune nouvelle arête).
- Falsifiabilité MED-4 vérifiée par R3-control : garde `if (now != _selected)` retiré ⇒ le porteur MED-4 ROUGIT (delta c2/c3 == 1 attendu 0), garde restauré ⇒ vert.

### Completion Notes List
- **T1 — Primitive de purge SRS (cause de la dette d'orphelins lex).** Ajout de `deleteByCard(String flashcardId) → Future<ZResult<Unit>>` au port **abstrait** `ZRepetitionStore` (idempotent : absence ⇒ `Right(unit)` ; panne réelle ⇒ `Left(CacheFailure)` rapporté, AD-10/AD-39). **Un seul implémenteur in-repo** (`grep -rn "implements ZRepetitionStore"` ⇒ **1** hit) : `FakeRepetitionStore` (`zcrud_flashcard/test/support/fakes.dart`), doté de `deleteByCard` + espion `deletedIds` (ordre + id) + couture `failDeleteFor`. Aucun adaptateur Firestore concret (vérifié) — rien inventé côté persistance.
- **T2 — Seam de cascade study-side.** `zFlashcardCascadeDeleteRoot({deleteCard, repetitionStore})` (`zcrud_study/lib/src/data/z_flashcard_cascade_delete.dart`) compose `deleteCard(rootId)` **puis** `repetitionStore.deleteByCard(rootId)`, **short-circuit** sur `Left` de la carte (SRS d'une carte vivante jamais détruit), renvoie le `Left` de la purge si elle échoue. Placé dans **`lib/src/data/`** (et non `presentation/`) : il importe `ZRepetitionStore`, symbole **banni de la présentation** par la garde de pureté — le widget reste PUR (seam injecté). Exporté au barrel.
- **T3 — Branchement additif.** Nouveau param **optionnel** `ZFlashcardListView.selection` (bundle `ZFlashcardListSelection` : contrôleur injecté ou **créé+disposé** propriétaire unique ; seams `deleteRoot`/`move`=`ZFlashcardListBatchMove` ; `customActions` ; libellés injectés ; `onBatchResult`). `null` ⇒ **exactement su-8** (zéro case, zéro barre). Case par tuile = `_SelectionCheckbox` **stateful** écoutant la **tranche** `selectedIds` et ne se reconstruisant (`setState`) **que si SON appartenance change** (SM-1 granulaire) ; ≥ 48 dp ; `Semantics` label injecté ; keyée par `id` STABLE (jamais index) ; **absente** pour une carte éphémère (`id == null`). Barre = `ZBatchActionBar` me-1 (actions déclarées, absente si seam `null`) ; compteur = **source unique** (`countLabelBuilder`). `didUpdateWidget` réconcilie le contrôleur sans le recréer quand la config est stable.
- **Cascade AD-21/AD-39 prouvée FALSIFIABLE** (4 étages) : **(a)** espion `_SpyStore` **prouvé captant AVANT** (témoin : cascade sur `A` ⇒ `store.has('A')==false` + `deletedIds==['A']`) ; **(b)** compte **EXACT** sur un lot (les **bons** N id purgés, `succeeded==N`, `srsCount==0`) ; **(c)** **R3 rougissant PAR LE COMPORTEMENT** : un seam AMPUTÉ de la purge (`(id)=>del.call(id)`) laisse les N `ZRepetitionInfo` **survivre** ⇒ la sonde « 0 survivant » de (b) rougirait ; **(d)** échec partiel : purge `K` KO ⇒ `failedRootIds=={K}` (cause), A/B purgés (`succeeded==N-1`), `K` **reste** en base + **reste sélectionné** ; short-circuit : carte `K` KO ⇒ `deleteByCard('K')` **jamais tenté**.
- **Voies de fuite fermées** (su-8) : suppression **sous filtre actif** ⇒ ids **non visibles** sélectionnés bien tous supprimés (keyage par id, jamais index) ; **await par racine** (M cascades discrètes, aucun plan monolithique > 450) ; **annulation** du sélecteur de destination ⇒ aucune écriture ; sélection **vide** ⇒ `batchDelete` no-op (rapport vide).
- **Non-régression su-8** : `z_flashcard_list_view_test.dart` (67 tests des 3 fichiers su-8) + `z_widgets_purity_test.dart` **verts sans modification** ; paramètres 100 % additifs.
- **AC11 / CORE OUT=0** : `grep -nE "ZRepetitionStore|ZRepository|zcrud_firestore|ZLocalStore|ZRemoteStore" z_flashcard_list_view.dart` ⇒ **RC=1** (ABSENT) + garde de pureté récursive verte ; aucune arête pubspec ajoutée.

### File List
**Modifiés**
- `packages/zcrud_flashcard/lib/src/data/z_repetition_store.dart` (ajout `deleteByCard` au port abstrait)
- `packages/zcrud_flashcard/test/support/fakes.dart` (`FakeRepetitionStore.deleteByCard` + espion `deletedIds` + `failDeleteFor`)
- `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart` (branchement sélection additif : configs `ZFlashcardListSelection`/`ZFlashcardListBatchMove`/`ZFlashcardBatchMoveDestination`, barre de lot, `_SelectionCheckbox`, cycle de vie contrôleur ; **code-review** : MED-1 rapport AD-39 inconditionnel (delete+move), MED-2 `didUpdateWidget` de `_SelectionCheckbox` (resync au swap de contrôleur), MED-3 try/catch autour de `resolveDestination` (AD-10), MED-5 assert `deleteRoot⇒deleteActionLabel` + retrait du `?? ''`, LOW-B dartdoc case reformulée)
- `packages/zcrud_study/lib/zcrud_study.dart` (export du seam de cascade)
- `packages/zcrud_study/lib/src/data/z_flashcard_cascade_delete.dart` (**code-review LOW-A** : bornage de la prose « dette d'orphelins corrigée » au chemin de LOT + note de routage de la suppression unitaire)
- `packages/zcrud_study/test/presentation/z_flashcard_list_view_selection_test.dart` (**code-review** : +7 tests porteurs MED-1..5 + renforts LOW-C (ordre await) / LOW-D (sémantique du compteur))

**Créés**
- `packages/zcrud_study/lib/src/data/z_flashcard_cascade_delete.dart` (seam `zFlashcardCascadeDeleteRoot`)
- `packages/zcrud_flashcard/test/z_repetition_store_delete_test.dart` (primitive `deleteByCard` : témoin, idempotence, panne)
- `packages/zcrud_study/test/presentation/z_flashcard_list_view_selection_test.dart` (me-3 : cascade falsifiable 4 étages + AC1..AC11 widget)
