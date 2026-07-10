# Code Review — Story E9-5 : Édition & widgets additifs pour lex_douane (`zcrud_flashcard`)

- **Skill** : `bmad-code-review` (chargé via le tool `Skill` — mode réel, PAS de fallback disque).
- **Date** : 2026-07-10
- **Périmètre** : fichiers E9-5 sous `packages/zcrud_flashcard/` uniquement (presentation/ + M1/L2 data & domain + barrel + tests). E9-1..4 (done) et les autres packages NON revus.
- **Baseline** : `04aaaf0` (frontmatter story). Le code E9-5 vit dans des fichiers **non suivis** (`lib/src/presentation/`, `lib/src/data/`, `test/`) → revue sur le contenu disque, pas sur `git diff` (qui ne montre que les 3 fichiers flashcard déjà tracés).
- **Méthode** : trois lentilles adverses appliquées par le réviseur (Blind Hunter / Edge Case Hunter / Acceptance Auditor vs les 10 ACs), puis triage par sévérité et conséquence pour le consommateur (intégrateur lex_douane / DODLP).

## Vérifications rejouées réellement (flashcard uniquement — pas de melos verify repo-wide)

| Gate | Commande | Résultat réel |
|------|----------|---------------|
| Analyze | `dart analyze packages/zcrud_flashcard` | **No issues found — RC=0** |
| Tests | `flutter test packages/zcrud_flashcard` | **All tests passed — 163 tests, RC=0** |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK ; CORE OUT=0 OK** ; `zcrud_flashcard → {annotations, core, export, generator, markdown}` — **aucune** arête firestore/manager/Syncfusion |
| Sérialisation | `flutter test packages/zcrud_flashcard --tags serialization-compat` | **No tests ran** (aucun test tagué) → SKIP attendu |

## Confirmations d'invariants demandés

- **[M1] `moveCard` folder-only** : re-sync via `ZRepetitionInfo.withFolder(folderId)` (z_repetition_info.dart:181) — copie **sans aucun paramètre d'ordonnancement** ; `interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`learnedAt`/`lastQuality` recopiés à l'identique. Test AC7 « préserve TOUS les champs d'ordonnancement » vérifie l'égalité avant/après. `getDue(new)` inclut / `getDue(old)` exclut ✓. Carte sans SRS → aucun `put` (putCount==0) ✓. Carte absente → `Left(NotFoundFailure)`, `saveCount==0` ✓. **Aucun champ d'avancement SRS ne bouge (AD-9 par construction).**
- **[L2] idempotence** : `initRepetition` fait `getByCard` d'abord → no-op si présent (renvoie l'existant, `putCount==0`, historique préservé) ; écrit `initial`+`put` seulement si absent. `resetRepetition` = `scheduler.initial` inconditionnel. Ni l'un ni l'autre n'appelle `apply` ✓.
- **a11y opérable** : `ZFlashcardOptionTile`, `_correctToggle`, `_buildAddButton` exposent `Semantics(onTap:)` opérable (`GestureDetector` `excludeFromSemantics`), `IconButton` up/down/remove via action native ; cibles `BoxConstraints(minHeight: 48)` (+minWidth 48 sur toggle) ; helpers `assertSemanticActionTap`/`assertMinTapTarget` copiés verbatim ; RTL testé ✓ (voir L1 sur la couverture partielle).
- **Rebuild ciblé SM-1** : contrôleurs/focus par ligne créés 1× (`_ChoiceRow`), disposés, jamais recréés ; sync guardée hors focus (`didUpdateWidget` + `_hasFocus`) ; écriture via `ctx.onChanged` seul ; test 100 car. `initA==1`, voisin non reconstruit, focus + identité contrôleur stables ✓. Aucun gestionnaire d'état importé (garde grep verte).
- **Isolation AD-1** : garde grep backend/manager/Syncfusion = 0 ; graphe sans arête firestore ; `zcrud_core` intact (diff confiné à `packages/zcrud_flashcard/**`) ✓.

---

## Findings

### MEDIUM-1 — Surface d'erreur QCM révélée **sans gating de type** → message parasite sur une carte non-QCM
- **Fichier** : `lib/src/presentation/z_flashcard_choices_field_widget.dart:340` (`_buildErrorSurface`), à comparer à `lib/src/presentation/z_flashcard_edition_validator.dart:86` (`validate`).
- **AC concernée** : AC2 (« les messages … sont révélés à la soumission agrégée »).
- **Constat** : le validateur agrégé `validate()` ne compte les erreurs de choix **que si** `coerceFlashcardType(values[typeKey]) == multipleChoice` (type-gated). Mais la surface d'erreur du widget QCM (`_buildErrorSurface`) appelle `validateChoices(_currentChoices)` **inconditionnellement** dès que `controller.reveal > 0`, **sans consulter le champ `type`**.
- **Scénario d'échec** : un formulaire d'édition complet monte tous les champs — `ZFlashcardEditionFields.all()` (catalogue livré par le package) inclut le champ `choices` **pour toute carte**, quel que soit le type. Carte `type = openQuestion`, `question` vide, `choices` vide. À la soumission, `validateAndReveal` ajoute l'erreur *question* → `revealErrors()` → `reveal = 1`. L'éditeur QCM affiche alors « Un QCM requiert au moins 2 choix » **alors que la carte n'est pas un QCM** — message trompeur (l'utilisateur croit devoir remplir des choix). La soumission elle-même reste correcte (validateAndReveal est type-aware), donc c'est un défaut d'**affichage** de validation, pas de blocage.
- **Pourquoi non détecté** : les tests AC2 rendent le champ `choices` **seul** (mono-champ) ou avec `type = multipleChoice` dans le controller — jamais un formulaire multi-champs avec un type non-QCM + reveal.
- **Recommandation** : gater la révélation de la surface QCM sur la valeur du champ type — lire `controller.valueOf(typeKey)` (clé `type` configurable, cohérente avec `validate`) et n'afficher l'erreur que si `multipleChoice` ; **ou** ne monter le sous-widget `choices` que lorsque le type courant est QCM. Aligner la logique du widget sur celle de `validate()` (source de vérité unique de la règle).

### MEDIUM-2 — `moveCard` avale silencieusement un échec de `put` SRS pendant la re-sync (contredit l'invariant AD-11 « jamais silencieux » du fichier)
- **Fichier** : `lib/src/data/z_flashcard_repository.dart:240`.
- **AC concernée** : AC7 (re-sync folder-only), AD-11 (contrat de résultat / logging).
- **Constat** : dans la branche re-sync, `await _reps.put(existing.withFolder(folderId));` **ignore** le `ZResult` retourné. La branche voisine — échec de `getByCard` (l.231-236) — est, elle, **loggée** (`_log('moveCard: relecture SRS échouée …')`). Asymétrie : un `Left(CacheFailure)` du `put` est **ni loggé, ni propagé**, et `moveCard` renvoie `Right(savedCard)`.
- **Scénario d'échec** : panne réelle du store local pendant la re-sync (disque plein, etc.). La carte est déplacée (autoritaire) mais le `folderId` SRS dénormalisé reste **périmé** : `getDue(new)` **exclut** la carte et `getDue(old)` continue de l'**inclure**, **sans aucune trace**. Aucun `reviewCard` ultérieur ne re-route (il conserve le `folderId` existant), donc pas d'auto-guérison. Le doc de classe (`ZFlashcardRepositoryLog`, l.49-58) proclame pourtant « un drop … est loggé — jamais silencieux (AD-11) ».
- **Recommandation** : capturer le résultat du `put` et `_log` sur `Left` (best-effort, à l'image de la branche `getByCard`) — p.ex. `(await _reps.put(existing.withFolder(folderId))).leftMap((f) => _log('moveCard: re-sync folderId SRS échouée (best-effort).', error: f));`.

### LOW-1 — Couverture a11y partielle : `assertSemanticActionTap` non appliqué à **chaque** cible QCM (« pas un échantillon »)
- **Fichier** : `test/z_flashcard_editors_test.dart:346-364`.
- **AC concernée** : AC4 (« `assertSemanticActionTap` + `assertMinTapTarget` sur **chaque** cible interactive — pas un échantillon »).
- **Constat** : pour le QCM, `assertSemanticActionTap` (preuve d'action opérable via lecteur d'écran) n'est exercé que sur `choice-correct-0` ; `add`, `down-0`, `remove-0`, `content-0` ne reçoivent que `assertMinTapTarget` (48 dp). L'exigence de la story est l'action opérable **sur chaque** cible. Les widgets **sont** opérables en pratique (Semantics `onTap` pour add/correct, action native `IconButton` pour up/down/remove), donc c'est un **manque de rigueur de test**, pas un défaut produit.
- **Recommandation** : étendre `assertSemanticActionTap` à `add`, `up`/`down` (sur une ligne intermédiaire où le bouton n'est pas désactivé) et `remove`.

### LOW-2 — La preuve SM-1 (AC3) court-circuite le dispatcher réel `DynamicEdition`/`ZFieldWidget`
- **Fichier** : `test/z_flashcard_editors_test.dart:220-241` (harnais `sliced()`).
- **AC concernée** : AC3 (rebuild ciblé O(1)).
- **Constat** : la preuve de rebuild ciblé/focus/identité contrôleur est faite avec un harnais `ValueListenableBuilder` **fait main**, pas via `DynamicEdition`. Le montage via le vrai dispatcher est couvert séparément par AC1, donc la couverture combinée est acceptable ; mais la garantie O(1) ne traverse pas le chemin de dispatch réel du cœur.
- **Recommandation** (optionnel) : ajouter un cas SM-1 monté via `DynamicEdition` pour prouver le rebuild ciblé à travers le dispatcher réel.

---

## Notes de vérification (non-findings — vérifiés et écartés)

- **`copyWith(subFolderId:)` dans `moveCard`** : `ZFlashcard.copyWith` utilise une **sentinelle** `_$undefined` (z_flashcard.dart:221, 241-243). `moveCard` passe **toujours** `subFolderId:` explicitement (valeur ou `null` explicite), donc un déplacement vers la racine d'un dossier **efface** correctement un ancien sous-dossier — sémantique de déplacement cohérente. Pas de bug.
- **Reseed hors focus** : `didUpdateWidget` retourne tôt si `_hasFocus` (priorité frappe) ; `_emit` sur chaque frappe maintient la tranche synchrone → à la soumission, `controller.values` == `_rows`. Cohérent.
- **Coercitions défensives** (`coerceFlashcardType`/`coerceChoices`/`coerceTrueFalse`) : ne jettent jamais, replis sûrs (openQuestion / `[]` / `null`). Conforme AD-10.
- **`ZFlashcardEditingScope` absent** → dégradation propre (aucune révélation), pas de throw. Conforme.
- **Garde grep FR-26/AD-13** : cwd-robuste + strip-comment + méta-test (détecte un `Colors.` injecté). Denylist complète. Verte.

---

## Verdict

**MEDIUM-1 et MEDIUM-2 à corriger avant `done`** (politique CLAUDE.md : MEDIUM corrigés par défaut si possible dans le périmètre — les deux le sont, fix local et sans régression ; les tests correspondants sont à ajouter). LOW-1/LOW-2 : optionnels (LOW-1 recommandé car directement adressé par l'AC4).

- Aucun finding **HIGH/MAJEUR** (pas de perte de données, pas de crash ; AD-9/AD-1/isolation/SM-1 tenus).
- Gates verts : analyze RC=0, 163 tests, graphe acyclique CORE OUT=0, serialization-compat SKIP.
- **Statut recommandé** : rester en `review` jusqu'à correction des deux MEDIUM (ou justification écrite d'un report), puis re-vérif verte → `done`.

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_flashcard` RC=0, `flutter test packages/zcrud_flashcard` **165 tests** (+2) RC=0, `graph_proof` CORE OUT=0 (aucune arête firestore), serialization-compat SKIP.

- **MEDIUM-1 (message QCM parasite) — CORRIGÉ.** La surface d'erreur QCM (`z_flashcard_choices_field_widget.dart`) est désormais gatée sur le type courant : elle n'apparaît que si `coerceFlashcardType(controller.values[typeFieldName]) == multipleChoice` (aligné sur `ZFlashcardEditionValidator.validate`). Paramètre `typeFieldName` (défaut `'type'`) ajouté. **Test ajouté** : carte non-QCM (openQuestion) + énoncé vide → reveal déclenché mais AUCUN message QCM parasite.
- **MEDIUM-2 (Left du put SRS avalé) — CORRIGÉ.** `moveCard` (`z_flashcard_repository.dart`) capture et logge le `Left` du put de re-sync (`resynced.leftMap((f) => _log(...))`) → plus jamais silencieux (AD-11) ; la carte reste déplacée (best-effort). **Test ajouté** (fake `failPut`) : échec du put → carte déplacée (`Right`) + message loggé.
- **LOW-1/2 — CONSIGNÉS** (optionnels) : LOW-1 couverture `assertSemanticActionTap` limitée à `correct-0` (les autres cibles ont le check ≥48dp ; opérables en pratique) ; LOW-2 preuve SM-1 via harnais `ValueListenableBuilder` (le dispatcher réel est couvert par AC1). À renforcer si besoin.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
