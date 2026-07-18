# Code-review me-1 — Capacité moteur sélection + actions de lot (ÉCRIT DANS `zcrud_core`)

Story : `me-1` (FR-SU19). Working tree non committé (baseline SU `de0ea05`).
Revue multi-lentilles : Données / CORE-OUT=0 / AD-44 / A11y / Adversariale.

## Verdict

**APPROUVÉ — corrections appliquées.** Aucun HIGH/MAJEUR résiduel. Les 4 MEDIUM
arbitrés (D1..D4) + les LOW sont corrigés et prouvés verts. CORE OUT=0 et
acyclicité intacts. Vérif verte rejouée REPO-WIDE (RC=0).

## Points CONFIRMÉS (non « corrigés »)

- **CORE OUT=0 : PASS.** `git diff packages/zcrud_core/pubspec.yaml` → vide.
  `graph_proof.py` : `out-degree(zcrud_core)=0`, `ACYCLIQUE OK`, `CORE OUT=0 OK`.
  Le leak import-only `import 'package:zcrud_study'` reste rattrapé par le
  `presentation_purity_test` (dans `flutter test`), pas par `verify` — d'où la
  correction de prose AC7 (LOW ci-dessous). Aucune dep ajoutée au cœur.
- **AD-44 : PASS.** Propriétaire unique (barre reçoit le contrôleur), actions
  déclarées (`onSelected==null ⇒ absente`), move paramétrique, champ commun via
  `ZValidatorCompiler` unique. Duplication `ZBatchAction`/`ZItemAction` imposée
  par l'acyclicité (core→study = cycle) — non touchée.
- **Perte de données : PASS.** id stable, itération sur instantané `toList`,
  rapport au grain racine, best-effort throw-safe, validation avant écriture.

## Dispositions appliquées

### D1 (MEDIUM, a11y) — badge compteur double-annoncé — CORRIGÉ
`z_batch_action.dart` : retrait de `label: countLabel` sur le `Semantics`
conteneur (le `Text` visible annonce le compteur une seule fois). Prose corrigée
(commentaire explicite sur la non-duplication). **Balayage du diff** : un SEUL
motif `Semantics`+`Text` dans les fichiers me-1 (le badge) — corrigé ; les
boutons utilisent `IconButton(tooltip:)`, pas de `Semantics` explicite (RAS).
Test porteur AJOUTÉ (D1) : compte les occurrences du compteur sur l'**arbre
sémantique réel** (`rootSemanticsNode`) ⇒ exactement 1. Rougit sur double annonce.

### D2 (MEDIUM, a11y) — bouton « tout sélectionner » potentiellement muet — CORRIGÉ
`z_batch_action.dart` : `assert(onSelectAll == null || selectAllLabel != null)`
en constructeur ⇒ impossible de construire un bouton actionnable sans nom
accessible (su-9). Dartdoc des deux champs mise à jour. Tests AJOUTÉS : (a)
nom accessible prouvé sur l'arbre sémantique (`getSemantics`, flag bouton +
`tooltip` non vide) ; (b) `onSelectAll` sans `selectAllLabel` ⇒ `AssertionError`.

### D3 (MEDIUM, test) — test RISQUE N°1 infalsifiable — CORRIGÉ (2 volets)
- **(a) Test me-1 rendu HONNÊTE et falsifiable.** Réécriture du test AC2 : la
  sélection `{B,C}` est réellement peuplée ; `C` a « disparu » de la source (le
  seam échoue pour `C`), `B` réussit. Assertions : le seam a agi sur EXACTEMENT
  `{B,C}` (id stable), rapport = B réussi / C échoué (`ZFailure`), B retiré de la
  sélection, C conservé. Commentaire sur-revendiquant « index-vs-position »
  remplacé par une note honnête (le cœur est id-only par construction ; la vraie
  surface vit dans `zcrud_list`). **Falsifiable** : mute « seam visé par
  `other-$id` » ⇒ RED (received `{other-B,other-C}` ≠ `{B,C}`).
- **(b) Protection réelle côté `zcrud_list` — test AJOUTÉ.** La divergence
  `id↔ligne` vit dans `z_sf_data_grid_renderer.dart` (`_syncControllerFromInteraction`,
  keyé par `wanted.contains(entry.value.id)`). Aucun test existant ne rougissait
  si ce mapping devenait positionnel (les tests réordonnaient sur des lignes
  valeur-égales). Test AJOUTÉ « la sélection suit l'id STABLE quand les lignes
  sont RÉORDONNÉES » : sélection id `'2'`, réordonnancement (id `'2'` → index 0,
  id `'3'` réoccupe l'index 1), prouve que la ligne sélectionnée est celle d'id
  `'2'` ('Bob'), jamais l'index 1 ('Chloé'). **Falsifiable** : mute mapping
  positionnel (`rows[1]`) ⇒ RED (sélectionne 'Chloé').

### D4 (MEDIUM) — dé-sélection non-configurable après édition in-place — CORRIGÉ
`z_list_selection.dart` : `applyCommonField` expose désormais
`clearSucceededFromSelection` (défaut **`false`** — édition in-place, éléments
toujours visibles ⇒ sélection conservée pour me-2). `batchDelete`/`batchMove`
gardent le défaut `true`. Tests AJOUTÉS : sélection conservée par défaut ; opt-out
`true` vide les réussies. Le premier rougit si le défaut redevenait `true`.

### LOW — corrigés
- Import `dartz` retiré du test me-1 (`Left/Right/Unit/unit/Either` re-exportés
  par le barrel `zcrud_core` via `domain.dart` — vérifié). `unnecessary_import`
  éliminé.
- Prose AC7 corrigée dans la story : le gardien du leak **import-only** est le
  `presentation_purity_test`/`domain_purity_test` (sous `flutter test`), PAS
  `melos verify` (graph_proof + gates lisent le pubspec) ni `analyze` (résout en
  workspace, `info` non fatal). Invariant effectivement enforced par la CI (946+
  tests).

## Preuves R3 (rougit PAR COMPORTEMENT, restauré cp+SHA-256 OK)

| # | Injection (fichier) | Test | Comportement RED |
|---|---|---|---|
| 1 | retrait `try/catch` (`z_list_selection`) | throw seam capté | `Bad state: boom-a` non capté |
| 2 | court-circuit garde validation | valeur invalide rejetée | `spy.received` non vide (writeRoot appelé) |
| 3 (NEW) | `break` au 1er échec | 1 échec sur 3 (best-effort) | `received={r1,r2}`, r3 non traité |
| 4 (D3a mute) | seam visé par `other-$id` | id disparu (AC2 réécrit) | `received={other-B,other-C}`≠`{B,C}` |
| 5 (D3b mute) | mapping positionnel (`rows[1]`) | sélection suit l'id réordonné | sélectionne 'Chloé' au lieu de 'Bob' |

Toutes restaurations `sha256sum -c` → OK (byte-identique).

## Vérif verte REPO-WIDE (rejouée par l'orchestrateur)

- `dart run melos run analyze` : **RC=0** (32 `info` pré-existants dans
  `zcrud_session`, non liés à me-1 ; les 2 `info` de mes tests — `hasFlag`,
  `pipelineOwner` — sont l'idiome a11y déjà utilisé dans tout le dépôt).
- `dart run melos run verify` : **RC=0** — `ACYCLIQUE OK`, `CORE OUT=0 OK`,
  `out-degree(zcrud_core)=0` ; gates reflectable/secrets/codegen/serialization OK.
- `flutter test` par package : `zcrud_core` **951** (+5), `zcrud_list` **21**
  (+1), `zcrud_flashcard` **541** (inchangé), `zcrud_study` **411** (inchangé) —
  aucune régression reverse-dep.

## Écarts / notes

- Les 2 `info` deprecated (`hasFlag`/`pipelineOwner`) introduits par les tests
  a11y porteurs sont volontairement conservés : ils reproduisent l'idiome des
  tests a11y existants (`z_session_card_swiper_a11y_test`, `z_session_mode_selector_test`,
  etc.). Non-fatal (`analyze` RC=0). Consigné.
- Finding adversarial « validateur qui *lève* (regex invalide) hors try/catch »
  (MEDIUM, hors dispositions arbitrées D1..D4) NON corrigé dans ce périmètre —
  la disposition owner a validé « validation avant écriture » comme PASS. Consigné
  au ledger comme robustesse AD-10 potentielle à durcir ultérieurement (envelopper
  `ZValidatorCompiler.compile` en DomainFailure par racine).
