# Rétrospective — Epic E-MULTI-EDIT (ME)

Date : 2026-07-18 · Skill : `bmad-retrospective` (invoqué réellement) · Facilitation : Amelia (Developer).
Statut epic à l'ouverture : `epic-me: in-progress`, 3/3 stories `done`, `epic-me-retrospective: optional`.
ME est le **dernier epic du sprint-status** (aucun epic suivant défini) — la préparation « next epic » est traitée comme un backlog de suivis, pas comme un plan de démarrage.

## Périmètre livré

| Story | Taille | Livrable | Package(s) écrit(s) | Code-review |
|-------|--------|----------|---------------------|-------------|
| **me-1** | XL | Capacité moteur générique : `ZListSelectionController` étendu (`batchApply`/`batchDelete`/`batchMove`/`applyCommonField`), `ZBatchAction`/`ZBatchActionBar`, `ZBatchReport`/`ZBatchDeletionReport` ; flag `clearSucceededFromSelection` (défaut `false`) exposé pour me-2 | `zcrud_core` (+ test `zcrud_list`) | APPROUVÉ — 0 HIGH ; 4 MEDIUM (D1..D4) + LOW corrigés |
| **me-2** | XL | `ZMultiFlashcardEditor` split-view, régime BROUILLON DÉCLARÉ (AD-43), consomme me-1 + su-2 (aperçu) + su-9 (génération) ; `ZDiscardChangesGuard` existant | `zcrud_study` (arête `→ zcrud_ui_kit`) | 3 bugs de PRODUCTION (2 MAJEUR + 1 MEDIUM) sous suite verte + 3 tests infalsifiables — tous corrigés |
| **me-3** | M | Branchement sélection dans `ZFlashcardListView` + primitive **manquante** `ZRepetitionStore.deleteByCard` (purge SRS = correction de la dette d'orphelins lex) ; seam `zFlashcardCascadeDeleteRoot` (cascade AD-21/AD-39) | `zcrud_study` + `zcrud_flashcard` | 0 HIGH ; 5 MEDIUM (MED-1..5) + LOW corrigés/renforcés |

**Vérif verte de sortie (rejouée sur disque par le cycle) :** `zcrud_core` 951 · `zcrud_list` 21 · `zcrud_study` 490 · `zcrud_flashcard` 545 ; `melos run analyze` RC=0 ; `melos run verify` RC=0 (`ACYCLIQUE OK`, **CORE OUT=0 OK**, 57 arêtes) ; `graph_proof` inchangé.

## Métriques de qualité

- **Findings totaux** : 0 HIGH · 5 MAJEUR (tous me-2 : BUG-1, BUG-2, FIX-4, FIX-5 + le renfort D3 côté me-1) · 12 MEDIUM · ~10 LOW. **100 % des HIGH/MAJEUR/MEDIUM corrigés** ; 1 seul MEDIUM reporté avec justification écrite (LOW#15 me-2, tradeoff SM-1 assumé — le remède serait pire que le mal).
- **Bugs de PRODUCTION attrapés sous une suite VERTE** : me-2 en a livré 3 (perte de données par snapshot figé, throw AD-10 traversant, commit ré-entrant). Preuve empirique du motif « **la suite verte ne prouve rien** ».
- **CORE OUT=0 tenu sur un epic qui écrit dans le cœur** : me-1 a étendu `zcrud_core` sans ajouter **aucune** dépendance (pubspec inchangé, cascade/repo/destination = seams injectés).

---

## Ce qui a marché (à répéter)

1. **Une capacité générique réutilisée deux fois sans duplication.** me-1 a été conçue dans `zcrud_core` comme moteur pur (seams injectés, keyage par `id` stable, rapport au grain racine). me-2 ET me-3 l'ont **consommée telle quelle** — aucun 2e contrôleur de sélection, aucune 2e validation, aucune 2e barre d'actions. Le flag `clearSucceededFromSelection` (défaut `false`) a été **anticipé par me-1 pour me-2** et effectivement consommé sans redéclaration. C'est le dividende d'un découpage « moteur d'abord, branchements ensuite ».

2. **CORE OUT=0 préservé alors que ME est le SEUL epic autorisé à écrire dans le cœur.** La discipline « une seule story touche `zcrud_core` à la fois » (me-1 en SÉQ strict, me-2/me-3 en consommation pure) + la garde `graph_proof`/`presentation_purity_test` ont tenu : 57 arêtes, `CORE OUT=0 OK`, une seule arête pubspec ajoutée sur tout l'epic (`zcrud_study → zcrud_ui_kit`, acyclique prouvée).

3. **Le code-review multi-lentilles + discipline R3 a attrapé des bugs RÉELS de production sous suites vertes.** me-2 : 3 bugs de production + 3 tests infalsifiables démasqués alors que la story était `review` avec suite verte. La lentille « Réalité du code » + « Tests porteurs » a transformé des espions tautologiques en témoins câblés au vrai canal de persistance. Sans ce filet, la perte de données BUG-1 partait en prod.

4. **me-3 a corrigé une CAUSE, pas un symptôme.** La primitive `ZRepetitionStore.deleteByCard` **manquait** (grep négatif RC=1) — c'était la racine de la dette d'orphelins SRS de lex. Plutôt que documenter le contournement, l'epic a ajouté la primitive idempotente + le seam de composition testable. La dette est corrigée par conception.

5. **La preuve de falsifiabilité rejouée réellement (R3-control).** Chaque garde structurante a été prouvée rougissante par injection puis restaurée par `cp` + `sha256sum -c` (byte-identique) — pas « de mémoire ». Ex. me-1 D3 (mapping positionnel → sélectionne 'Chloé' au lieu de 'Bob'), me-3 MED-4 (garde par-case retiré → delta c2==1 attendu 0).

---

## À améliorer — motifs de défauts RÉCURRENTS formulés en garde-fous réutilisables

Ces cinq motifs sont réapparus à travers l'epic. Chacun est écrit comme un **item de checklist** à passer sur les prochains epics (create-story ET code-review).

1. **[Espion infalsifiable] Un espion qui n'est jamais prouvé captant ne prouve rien.**
   Vu : me-2 FIX-4 (espion appelé directement, jamais câblé au sujet → `writes==witnessed` tautologique) ; me-1 D3 (test AC2 dont le corpus rendait l'assertion vraie quel que soit le code).
   **Garde-fou :** tout espion/fake doit d'abord enregistrer une **écriture témoin prouvant qu'il capte le bon canal** (`writes==1` avant l'assertion à 0), et le sujet + le témoin doivent partager le **même canal réel** de persistance. Une assertion « 0 écriture » est infalsifiable tant que le témoin n'a pas rougi.

2. **[Perte de données par voie non anticipée] Le bug passe toujours par la voie qu'on n'a pas testée.**
   Vu : me-2 BUG-1 (`_rebuild` repartait de `widget.initialCard` figé → champ commun reverté à null à la frappe suivante) ; me-3 MED-1 (rapport AD-39 avalé si la liste se démonte pendant l'`await`).
   **Garde-fou :** pour toute surface d'édition/lot, énumérer explicitement les **voies de fuite** (snapshot figé relu, callback avalé au démontage `!mounted`, auto-save implicite, `didChangeDependencies`, `dispose` qui flush) et prouver l'absence par grep négatif + un test qui exerce la voie (démontage mid-await, revert-puis-frappe). La base de relecture doit être **vivante**, jamais un snapshot de constructeur.

3. **[Asymétrie de robustesse] Un seam capte ses throws, un autre du même flux ne les capte pas.**
   Vu : me-2 BUG-2 (`onCommit` throw traversait alors que `batchApply` captait déjà) ; me-3 MED-3 (`resolveDestination` du picker injecté sans try/catch alors que le seam d'écriture `batchMove` était capté).
   **Garde-fou :** inventorier **tous** les seams injectés d'un flux et vérifier qu'ils ont la **même politique AD-10** (throw → repli défini). Un seul seam non capté dans une chaîne `unawaited`/`await` = traversée de surface. Symétrie de robustesse = invariant, pas cas par cas.

4. **[Contrat « requis » non enforced par assert] Un `String?` optionnel qui devait être obligatoire reste muet.**
   Vu : me-3 MED-5 (`deleteActionLabel` `String?` sans assert → action « supprimer » muette si `deleteRoot` fourni sans label ; récidive de su-9) — alors que me-1 bloquait déjà le couple par `assert(onSelectAll == null || selectAllLabel != null)`.
   **Garde-fou :** tout couplage « si le seam X est fourni, alors le libellé/param Y est requis » doit être **enforced par `assert` au constructeur**, pas laissé à un `?? ''` qui produit une a11y muette. Répliquer le patron d'assert déjà établi en amont (me-1) au lieu de le re-perdre en aval.

5. **[SM-1 mesuré au mauvais grain] Un compteur trop grossier laisse la garde de granularité infalsifiable.**
   Vu : me-3 MED-4 (garde par-case correct mais **aucun compteur dédié par case** → le retirer laissait la suite verte) ; me-2 FIX-9 (dirty recalculé en O(N) à chaque frappe au lieu d'O(1) incrémental).
   **Garde-fou :** le compteur SM-1 doit être au **grain exact de la tranche censée se reconstruire** (case, pas tuile ; champ, pas formulaire) et le test doit prouver `delta(cible)==1` ET `delta(voisins)==0`. Une garde de granularité sans compteur au bon grain est décorative.

---

## Dette technique & suivis (à router / itérer)

| # | Item | Origine | Action |
|---|------|---------|--------|
| DW-ME-1 | **Suppression UNITAIRE non routée par le seam de cascade.** La garantie de purge SRS (`deleteByCard`) est bornée au chemin de LOT ; le menu par item / `onDelete` / prop su-8 ne passe pas par le seam ⇒ risque de ré-introduire un orphelin SRS carte par carte. | me-3 LOW-A (bornage éditorial) | **App-side** : router la suppression unitaire par le **même** `zFlashcardCascadeDeleteRoot`. À câbler à l'intégration DODLP/lex ; consigner comme responsabilité du consommateur. |
| DW-ME-2 | **Validateur qui *lève* (regex invalide) hors try/catch** dans `applyCommonField`. Robustesse AD-10 potentielle : envelopper `ZValidatorCompiler.compile` en `DomainFailure` par racine. | me-1 finding adversarial (hors D1..D4, disposition owner = PASS) | Durcissement AD-10 différé — consigné au ledger. Non bloquant (validation avant écriture reste PASS). |
| DW-ME-3 | **Résumé de ligne stale en split-view** (la liste écoute `orderKeys`, pas les édits de champ). MEDIUM→LOW reporté, tradeoff SM-1 assumé. | me-2 LOW#15 | Documenté, pas de correctif (rafraîchir à la frappe casserait l'objectif produit n°1). Réévaluer si un besoin UX émerge. |
| DW-ME-4 | **Harnais de parité + showcase + `dateRange`** (itération formulaire à venir). | Backlog transverse mentionné hors ME | À planifier dans l'itération formulaire suivante (hors périmètre ME). |
| DW-ME-5 | **2 `info` deprecated** (`hasFlag`/`pipelineOwner`) introduits par les tests a11y porteurs me-1 (idiome a11y existant du dépôt). Non-fatal. | me-1 | Aligner sur l'API a11y non dépréciée lors d'un balayage transverse des tests a11y (non urgent). |

---

## Action items

| # | Action | Catégorie | Owner | Critère de succès |
|---|--------|-----------|-------|-------------------|
| AI-1 | Ajouter les **5 garde-fous ci-dessus** à la checklist de `bmad-create-story` ET aux lentilles de `bmad-code-review` (espion prouvé captant · voie de fuite énumérée · symétrie de robustesse des seams · assert de couplage requis · compteur SM-1 au bon grain). | Process | Orchestrateur | Les 5 items apparaissent dans le prompt de review des prochains epics. |
| AI-2 | Router la **suppression unitaire** de flashcard par `zFlashcardCascadeDeleteRoot` au moment de l'intégration app (DW-ME-1). | Technique | App-side (E7 DODLP / lex) | Grep : tous les chemins de suppression carte passent par le seam ; test de non-orphelin unitaire. |
| AI-3 | Consigner **DW-ME-2** (validateur qui lève) au ledger de dette AD-10 et le traiter au prochain durcissement robustesse du cœur. | Technique | Orchestrateur | Entrée ledger créée ; envelopper `compile` en `DomainFailure` planifié. |
| AI-4 | Sur toute future story écrivant dans `zcrud_core` : **réaffirmer la règle SÉQ** (une seule story touche le cœur à la fois) et rejouer `melos analyze` + `verify` **REPO-WIDE** au gate de commit d'epic. | Process | Orchestrateur | Règle appliquée ; gate repo-wide vert avant `done`. |

---

## Bilan

Epic ME = **succès net**. Un moteur générique (me-1) réutilisé deux fois sans duplication, CORE OUT=0 tenu sur le seul epic écrivant dans le cœur, et un code-review multi-lentilles qui a démontré sa valeur en attrapant 3 bugs de production RÉELS sous suite verte. Les cinq motifs de défauts récurrents — tous de la même famille « la suite verte ne prouve rien » — sont désormais capitalisés en garde-fous réutilisables. Dette résiduelle faible et entièrement tracée (routage unitaire de cascade côté app, durcissement validateur, itération formulaire à venir).
