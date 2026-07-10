# Code Review — E9-4 : Dépôt offline-first `ZFlashcard` + invariant SRS top-level (`zcrud_flashcard`)

- **Mode** : skill BMAD réel `bmad-code-review` (tool `Skill`, PAS de fallback disque). Workflow step-file (`step-01-gather-context`). Diff source = changements non-committés/untracked vs baseline `04aaaf0` (= HEAD), **scopé aux fichiers E9-4 uniquement**.
- **Story** : `_bmad-output/implementation-artifacts/stories/e9-4-depot-offline-first-invariant-srs.md` (11 ACs, décision archi, Dev Agent Record).
- **Périmètre revu** : `lib/src/data/z_repetition_store.dart`, `lib/src/data/z_flashcard_repository.dart`, `lib/zcrud_flashcard.dart` (exports data/), `pubspec.yaml`, `test/support/fakes.dart`, `test/z_flashcard_repository_test.dart`. Modèles E9-1/2/3 lus en **référence** (non revus). E11b / autres packages : hors périmètre.
- **Reviewer** : agent adversarial (Blind Hunter + Edge-Case Hunter + Acceptance Auditor).

## Verdict

**PRÊT POUR `done`** — 0 finding HIGH/MAJEUR, 0 MEDIUM bloquant. Les 11 ACs sont satisfaits et vérifiés par tests réels. Invariant SRS top-level, voie d'écriture SRS unique et AD-1 confirmés sur disque. Findings restants : 1 MEDIUM **déférable/justifié** (hors scope move) + 4 LOW/nits (optionnels).

## Vérif verte rejouée (réelle, sur disque, flashcard uniquement)

| Gate | Commande | Résultat |
|------|----------|----------|
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | **RC=0** — `wrote 0 outputs` (aucun nouveau `@ZcrudModel` dans `data/`, correct) |
| Analyse | `dart analyze packages/zcrud_flashcard` | **RC=0** — `No issues found!` |
| Tests | `flutter test packages/zcrud_flashcard` | **RC=0** — **135 tests passés** (117 baseline E9-1/2/3 + 18 E9-4) |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK ; CORE OUT=0 OK** ; `zcrud_flashcard → {annotations, core, export, generator, markdown}` — **AUCUNE arête vers `zcrud_firestore`** |
| AD-1 grep | `grep -rE "cloud_firestore\|package:hive\|firebase_core\|zcrud_firestore" packages/zcrud_flashcard/lib` | **0 occurrence** |
| Gate sérialisation | `flutter test --tags serialization-compat` (dans le package) | **`No tests ran.`** → exit 79 → **SKIP** (gate VERT, plus RED) |

## Confirmations adversariales des axes durs

- **INVARIANT SRS top-level** — CONFIRMÉ à deux niveaux. (1) Modèle : `ZFlashcard` ne porte aucun champ SRS → `card.toMap()` ne peut pas en émettre. (2) Dépôt : `reviewCard`/`initRepetition` écrivent **exclusivement** via `_reps.put` (`ZRepetitionStore`), jamais via `_cards`. Test AC2 (`z_flashcard_repository_test.dart:62-84`) relit la map carte après `save + reviewCard` et prouve 0 clé SRS (`interval`/`repetitions`/`ease_factor`/`next_review_date`/`learned_at`/`last_quality`/`repetition_info`) ; l'état n'est lisible que via `ZRepetitionStore` keyed by `flashcardId`. **Vérifié réellement.**
- **Non-duplication au partage** — CONFIRMÉ (`z_flashcard_repository_test.dart:86-108`). Carte B (`copyWith(id:null)` + `save`) obtient un nouvel `id`, `getByCard(b.id)` = `null` (aucun état SRS hérité), l'état SRS de A reste intact. Structurellement garanti : le SRS vit dans un store séparé keyed par `flashcardId`.
- **Voie d'écriture SRS UNIQUE** — CONFIRMÉ. Inventaire des méthodes publiques de `ZFlashcardRepository` : seules `initRepetition` (→ `scheduler.initial` → `put`) et `reviewCard` (→ `scheduler.apply` → `put`) appellent `_reps.put`. Aucune autre API n'avance l'état. `reviewCard == apply(current,quality)` prouvé (`:110-127`), courbe SM-2 cohérente sur deux révisions (`:129-143`), `saveCount==0` pendant `reviewCard` (`:145-151`).
- **Matérialisation éphémère** — CONFIRMÉ (`z_flashcard_repository.dart:118-127`) : délégation à `_cards.save` (AD-14), `id != null` + `folderId`/`subFolderId` conservés + `updatedAt` renseigné (`:163-171`).
- **Carte éphémère sans dossier (null ET '')** — CONFIRMÉ (`:118-125`) : `Left(DomainFailure)` retourné AVANT tout appel `_cards`, sans throw ; `cards.saveCount==0` sur les deux cas (`:174-195`). Carte déjà matérialisée sans folderId → garde NON appliquée (choix documenté, `:197-208`).
- **AD-1** — CONFIRMÉ : grep=0, `ZOfflineFirstRepository` jamais importé (injecté typé sur `ZSyncableRepository<ZFlashcard>`), graphe sans arête vers `zcrud_firestore`, pubspec n'ajoute aucune dép backend.
- **Either/flux nus (AD-11)** — CONFIRMÉ : toutes signatures `ZResult<…>`/`Stream<List<…>>` nues ; aucun `try-catch` nu (le seul `try/finally` — `:226-241` — est la garde de ré-entrance, sans `catch`).
- **Défensif (AD-10)** — CONFIRMÉ : absent → `Right(null)` → repli `scheduler.initial()` (`:173-176`) ; corrompu → `ZRepetitionInfo.fromMap` (jamais throw, `fakes.dart:148-154`, test `:226-239`) ; `getDue` store vide → `Right([])` (`:241-245`).
- **Sync map SRS telle quelle** — CONFIRMÉ : `put` persiste `info.toMap()` sans recalcul ; aucun scheduler à la (dé)sérialisation ni au merge.
- **Garde de ré-entrance sync** — CONFIRMÉ (`:220-224`) : `_syncing` coalesce un cycle en vol (mono-thread Dart, `finally` remet à false).
- **LWW via `ZSyncMeta` hors-entité** — CONFIRMÉ : `ZRepetitionInfo` non-`ZEntity` (clé `flashcardId`, sans `updatedAt`) ; méta estampillée hors-entité par le store à chaque `put`.
- **Changement `pubspec.yaml` (`flutter: sdk: flutter`)** — CORRECT ET SANS RÉGRESSION. Vérifié contre `scripts/ci/verify_serialization.dart:25-40` : `_isFlutterPackage` détecte un `flutter:` sous `dependencies:`. AVANT le fix, le bloc `dependencies` de flashcard n'avait pas de `flutter:` (SDK tiré transitivement via `zcrud_core`) → runner=`dart` → `dart test` tentait de compiler des tests important `flutter_test`/`dart:ui` → échec de compilation (exit ≠ 79) → gate RED. APRÈS, runner=`flutter` → `flutter test --tags serialization-compat` → exit 79 → SKIP VERT. Aucune dépendance runtime lourde ajoutée (le SDK était déjà tiré transitivement) ; même convention que `zcrud_mindmap`. Confirmé empiriquement ci-dessus (SKIP réel).

## Findings

### MEDIUM (déférable / justifié — ne bloque pas `done`)

**M1 — `folderId` dénormalisé du SRS peut devenir périmé après déplacement de carte ; `reviewCard` ignore le `folderId` passé quand un état existe.**
`z_flashcard_repository.dart:163-180`. Le paramètre `folderId` de `reviewCard` n'est utilisé **que** dans le repli `initial()` (`:175`) quand aucun état n'existe. Si un état SRS existe déjà, `apply(current, …)` préserve `current.folderId` (cf. `z_sm2_scheduler.dart:87`) et le `folderId` passé est **silencieusement ignoré**. Conséquence : si une carte est déplacée de dossier (via `save` avec un `folderId` mis à jour côté carte), la ligne SRS conserve l'ancien `folderId`, et `getDue(folderId:…)` (`:191-204`, filtre sur `ZRepetitionInfo.folderId`) classera la carte sous son **ancien** dossier — donc l'omettra de la session du nouveau dossier et la remontera à tort dans l'ancien.
- **Impact** : sélection de session incorrecte APRÈS un déplacement de carte.
- **Justification de déferral** : E9-4 **n'expose aucune opération de déplacement** de carte ; le contrat canonique `reviewCard(current, quality)` ne prend pas de `folderId` (c'est un ajout local pour le cas `initial`). Le comportement est documenté au doc-comment. Aucun AC E9-4 n'est violé.
- **Recommandation** : à traiter quand une opération « move/reparent » sera introduite (E9-5 / session) — soit re-synchroniser le `folderId` de la ligne SRS au déplacement, soit faire remonter le `folderId` du paramètre dans `apply` de façon explicite. Consigner en dette dans la rétro E9.

### LOW / nits (optionnels)

**L1 — `getDue` ne peut pas remonter une carte sans ligne SRS.**
`z_flashcard_repository.dart:191-204`. `getDue` filtre le snapshot de `_reps.getAll()` : une carte n'ayant jamais reçu `initRepetition`/`reviewCard` (aucune ligne SRS) est **invisible** à la sélection de session, même si « jamais révisée = due » conceptuellement. Conforme au libellé AC10 (« filtrés sur le snapshot du store SRS ») — la jointure avec la collection cartes est déférée. **Recommandation** : documenter explicitement que l'inscription d'une carte à l'étude passe par `initRepetition` (ou une future jointure cards×reps), pour éviter la surprise « carte neuve absente de la session ».

**L2 — `initRepetition` n'a pas de garde d'idempotence.**
`z_flashcard_repository.dart:142-151`. Un second appel `initRepetition` sur une carte ayant un historique SRS **écrase** l'état par un état neuf remis à zéro (perte de `repetitions`/`interval`/`learnedAt`). Conforme au contrat canonique (`initRepetition` = créer un état neuf) mais c'est un footgun de perte de données. **Recommandation** : documenter que `initRepetition` est réservé à la première inscription, ou ajouter une garde « n'écrase pas un état existant » (option : `getByCard` puis no-op si présent).

**L3 — Le test d'invariant AC2 utilise une liste de refus (denylist) plutôt qu'une liste blanche.**
`z_flashcard_repository_test.dart:30-38, 76-79`. Le test vérifie l'absence d'un ensemble **fixe** de clés SRS. Une future clé SRS nommée autrement passerait au travers. **Recommandation (nit)** : renforcer en asservissant les clés attendues de la carte (allowlist) ou en dérivant l'ensemble interdit du `$ZRepetitionInfoFieldSpecs`. Non bloquant : l'invariant est déjà garanti structurellement côté modèle.

**L4 — Le coordinateur fait confiance au contrat non-throwing des ports (pas de filet).**
`z_flashcard_repository.dart:118-127, 163-180, 220-242`. `save`/`reviewCard`/`sync` propageraient une exception si un adaptateur de port **violait** son contrat (`ZResult` au lieu de throw). Design volontaire « trust the port », cohérent avec le patron E5 (`ZOfflineFirstRepository`). **Informational** : les adaptateurs concrets (déférés) doivent garantir zéro-throw ; aucune action requise sur E9-4.

## Note d'architecture (validation)

La décision d'archi (option (a) : dépôt dans `zcrud_flashcard/lib/src/data/`, port flashcard-local `ZRepetitionStore` pour contourner la friction `ZRepetitionInfo` non-`ZEntity`, backend concret déféré) est **saine et conforme AD-1** : aucune arête vers `zcrud_firestore`, aucune édition de `zcrud_core` (vérifié — les fichiers `zcrud_core` modifiés dans `git status` relèvent d'E5, pas d'E9-4). Le point de vigilance signalé par la story (une future arête `zcrud_firestore → zcrud_flashcard` si l'adaptateur concret est placé côté firestore) reste **hors E9-4** et à valider à ce moment-là.

---

## Résolution (orchestrateur)

Vérif verte (flashcard) : `dart analyze` RC=0, `flutter test` **135 tests** RC=0, `graph_proof` CORE OUT=0 (aucune arête vers zcrud_firestore), `flutter test --tags serialization-compat` → SKIP (gate vert). Fix `flutter: sdk: flutter` validé sans régression (sweep : flashcard était le seul package fautif).

- **0 HIGH / 0 MAJEUR.**
- **M1 (MEDIUM) — REPORTÉ AVEC JUSTIFICATION ÉCRITE (politique MEDIUM).** `reviewCard` n'actualise pas le `folderId` dénormalisé de la ligne SRS quand un état existe → `getDue(folderId)` pourrait filtrer sur un `folderId` périmé APRÈS un déplacement de carte. **Non corrigible utilement en E9-4** : la story n'expose AUCUNE opération de déplacement (aucun chemin ne rend le `folderId` périmé), aucun AC violé, aucune régression possible dans le périmètre livré. **Rattaché à E9-5/sessions** (là où le déplacement de carte sera introduit) : re-synchroniser le `folderId` SRS au déplacement. Dette consignée.
- **LOW-1/2/3/4 — CONSIGNÉS** (optionnels) : L1 `getDue` remonte via `initRepetition` (inscription) — documenté ; L2 `initRepetition` sans garde d'idempotence — sémantique laissée telle quelle (un reset explicite peut être voulu), footgun documenté, à trancher en E9-5 ; L3 test AC2 denylist→allowlist (nit) ; L4 « trust the port » cohérent E5 (informational).

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert (M1 justifié+rattaché E9-5).
