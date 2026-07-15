# Code-review ES-4.3 — Runtimes cramming/liste (`ZLinearSessionState`)

**Verdict : APPROUVÉ** (0 HIGH/MAJEUR, 0 MEDIUM, 1 LOW optionnel). Revue adversariale, effort high, workstream A isolé (`packages/zcrud_session/**`). La story reste `review` ; transition `done` par l'orchestrateur après gate repo-wide.

## Vérif verte CIBLÉE (RC capturé HORS pipe, R15 ; runner `flutter test`, R14)

| # | Commande | Attendu | RC réel | Résultat |
|---|----------|---------|---------|----------|
| 1 | `dart analyze .` (zcrud_session) | 0 | **0** | No issues found! |
| 2 | `flutter test` | 0 | **0** | All tests passed — **37 tests** (17 ES-4.3 + 20 ES-4.2, zéro régression) |
| 3 | `python3 scripts/dev/graph_proof.py` | ACYCLIQUE + CORE OUT=0 | **0** | ACYCLIQUE OK / CORE OUT=0 OK (INCHANGÉ) |
| 4 | `dart run melos list` | 20 | **0** | **20** (INCHANGÉ) |
| 5 | `find lib -name '*.g.dart'` | vide | — | **0** (AC8) |

## Injections R3 REJOUÉES RÉELLEMENT (pouvoir discriminant R12) — chacune ROUGE, restaurée par édition ciblée (R13), retour au vert prouvé

- **INJ-1 — zéro-SM2 PAR CONSTRUCTION (AC2a, CŒUR AD-23).** Ajout `ZSessionReviewer? _reviewInj;` dans le CODE du runtime → `flutter test test/z_linear_no_srs_test.dart` **RC=1**. Message exact : `lib/src/domain/z_linear_session_state.dart:176 → ZSessionReviewer dans « ZSessionReviewer? _reviewInj; // INJ-1 »` → « symbole(s) SRS détecté(s) … AD-23 est violée ». Restauré → vert.
- **INJ-2 — progression linéaire stricte (AC3, CŒUR).** `advanceLinear` curseur `+2` → `flutter test test/z_linear_session_test.dart` **RC=1**. Golden : `Expected ['A','B','C','D','E','F'] / Actual ['A','C','E']`. Restauré (`+1`) → vert.
- **INJ-4 — offset cramming +2/+4 (AC4).** `requeueCramming` offset soft `kLapseOffsetSoft + 1` → `flutter test test/z_linear_session_test.dart` **RC=1**. Golden : `Expected ['B','A','C','D','E','F'] / Actual ['B','C','A','D','E','F']`. Restauré → vert.
- **INJ-3 — pureté (AC1).** Non-rejouée manuellement ici (garde `z_purity_test.dart` d'ES-4.2 balaie `lib/**`, verte sur le fichier neuf, tests 30-31). Discriminance déjà établie en dev-story ; import banni ⇒ scan rouge par construction du test existant.

**Restauration finale prouvée : `flutter test` RC=0 (37), `dart analyze` RC=0.**

## Preuve zéro-SM2 PAR CONSTRUCTION (AC2, cœur AD-23)

- `ZLinearSessionState` ne déclare **AUCUN** champ `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ; constructeur `({required queue, mode, config})` **sans aucun** paramètre review/scheduler. Amorçage via le **ctor public** `ZSessionState(queue:…, cursor:0,…)` et NON `.initial` (motif banni évité par construction, l.165-172) — subtilité vérifiée : la dartdoc NOMME librement les concepts SRS, le scan ignore les lignes `///`/`//` (l.59), aucun faux négatif par concaténation (le symbole apparaîtrait littéralement pour être utilisé ; INJ-1 le prouve). Aucun `.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZRepetitionInfo` dans le code.

## Goldens linéaires figés en LITTÉRAUX (non dérivés) — vérifiés

- **AC3 list** : `current [A,B,C,D,E,F]`, `cursor [1..6]`, `reviewed [1..6]`, `isComplete@6`, `lapses=0`, file jamais ré-ordonnée. Littéraux (test l.42-49).
- **AC4 cramming** : `answer(A,q=1)` → `[B,A,C,D,E,F]` (+2) ; `answer(B,q=2)` → `[A,C,D,B,E,F]` (+4) ; réussite `q=3` consomme → `[B,C]` ; clamp `[X,Y,Z]`+`answer(q=2)` → `[Y,Z,X]`. Littéraux figés (l.74-108). Trace de reduce re-vérifiée à la main : `insertIndex = min(cursor+offset-1, queue.length)` cohérente avec chaque golden.
- **AC5 seuil** : `passThreshold` LU de `ZSrsConfig` (`_config.passThreshold`, l.230), jamais `3` littéral ; vecteur `passThreshold:4` ⇒ `q=3` re-bouclé, défaut ⇒ `q=3` consommé.
- **AC6 assert** : `spaced`/`learn`/`whiteExam`/`test` ⇒ `AssertionError` (4 vecteurs paramétrés) ; `list`/`cramming` `returnsNormally`.
- **AC7 granularité** : `_setState` notifie ssi value-object `!=` ; 1 notif/transition, 0 sur no-op (list complet et cramming complet).

## Axes adversariaux

- **Pureté (AC1/AD-2)** : imports = `dart:math`, `flutter/foundation`, `ZSrsConfig`, `ZReviewMode`, fichiers locaux. AUCUN riverpod/get/provider/material/widgets. `z_purity_test` vert.
- **Composition (anti-inertie AD-4)** : réutilise `ZSessionItem`/`ZSessionState`(+`copyWith`/`==`)/`kLapseOffsetSoft|Hard|SoftMaxQuality`/`ZReviewMode`/`ZSrsConfig`. `reduceGrade` NON réutilisé (reducers linéaires dédiés). `z_study_session_engine.dart` touché en LECTURE seule (import `show` des 3 constantes) — non modifié.
- **AD-1** : aucune nouvelle arête (deps ES-4.2 : `zcrud_core`/`zcrud_flashcard`/`zcrud_study_kernel`), graphe INCHANGÉ, CORE OUT=0, melos=20, aucun `.g.dart`.
- **Couverture 8 ACs** : chaque AC a un vecteur discriminant (aucun POWERLESS).

## Findings

### LOW-1 (optionnel) — `advance()` n'est pas mode-conscient
`advance()` (l.209-211) appelle inconditionnellement `advanceLinear`. En mode `cramming`, un appel à `advance()` (au lieu de `answer()`) ferait avancer le curseur linéairement sans retirer la carte courante — état incohérent (carte de tête jamais consommée). Non atteignable par les chemins testés ni les ACs ; `answer()` est l'entrée universelle mode-consciente et la dartdoc de `advance()` la restreint explicitement au mode `list`. Le binding (ES-9/ES-10) appelle la méthode adaptée au mode. **Nit** : un `assert(_state.mode == ZReviewMode.list)` dans `advance()` (miroir de la garde constructeur) durcirait le contrat. Consigné, non bloquant.

**Aucun finding HIGH/MAJEUR/MEDIUM.** Story prête pour `done` après gate repo-wide de l'orchestrateur.
