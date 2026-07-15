# Code-Review ES-4.4 — Moteur d'examen blanc `ZWhiteExamSessionEngine`

**Revue adversariale (effort high) — orchestrateur workstream A (isolation stricte).**
**Verdict : APPROUVÉ — vert. 0 HIGH / 0 MAJEUR / 0 MEDIUM bloquant. 1 LOW (observation, non-bloquant).**

Story : `es-4-4-examen-blanc-session-engine.md` (8 ACs, INJ-1..INJ-4). Status entrant : `review`.

---

## Vérif verte CIBLÉE rejouée (RC hors pipe, R15)

| Étape | Commande | Résultat | RC |
|---|---|---|---|
| Analyse | `dart analyze` (zcrud_session) | No issues found | **0** |
| Tests | `flutter test` (zcrud_session, R14) | All tests passed — **54 tests** | **0** |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK, CORE OUT=0 OK** | **0** |
| Inventaire | `dart run melos list` | **20 packages** (inchangé) | **0** |

Barrel : **1 seul export additif** (`z_white_exam_session_engine.dart`, l.26) ; les 5 exports ES-4.2/4.3 intacts. Le package `zcrud_session` est entièrement non-suivi (neuf ES-4.2→4.4) → `z_study_session_engine.dart`/`z_linear_session_state.dart`/`z_session_state.dart`/`z_session_item.dart`/`pubspec.yaml` non modifiés vs socle. Aucun `.g.dart`. Aucune arête `zcrud_exam` (D9). Aucune nouvelle dépendance (imports = `flutter/foundation`, `zcrud_flashcard`/`ZSrsConfig`, `zcrud_study_kernel`/`ZReviewMode`+`ZStudySessionResult`, `z_session_item` — tous déjà déps ES-4.2).

---

## Axe n°1 — Machine à états + scoring + zéro-SM2 (R12) : injections REJOUÉES

Toutes rejouées réellement sur disque, chacune ROUGE puis RESTAURÉE par édition ciblée (R13), RC hors pipe (R15).

| Inj | Garde | Édition | Test | RC | Preuve capturée |
|---|---|---|---|---|---|
| **INJ-2** | Machine à états (AC2, CŒUR) | garde `answer()` → `return;` muet | `flutter test test/z_white_exam_session_test.dart` | **1** | `Expected: throws <Instance of 'StateError'>` / `Actual: <Closure: () => void>` — 2 tests rouges (answer avant start, answer après submit) |
| **INJ-4** | Scoring déterministe (AC3, CŒUR) | frontière `>=` → `>` (l.224) | idem | **1** | golden `correct: 3` → `Actual: …correct: 2`, + reducer pur `Expected <3> Actual <2>`, + qualités répétées `Expected <3> Actual <0>` |
| **INJ-1** | Zéro-SM2 PAR CONSTRUCTION (AC4a, CŒUR AD-23) | champ `final ZSessionReviewer _review` ajouté | `flutter test test/z_white_exam_no_srs_test.dart` | **1** | `symbole(s) SRS détecté(s)… (AD-23) est violée : …z_white_exam_session_engine.dart:272 → ZSessionReviewer` |

Après restauration des 3 injections : `dart analyze` RC=0, `flutter test` RC=0 (**54 tests verts**). *(INJ-3 pureté déjà couverte par le scan permanent `z_purity_test.dart` qui balaie `lib/**` ; non rejouée séparément — garde active et verte.)*

### AC2 — machine à états (vérifié)
7 cas figés par `throwsStateError` + chemin nominal : answer/submit hors running lèvent, start hors setup lève (couvre double-start, retour arrière `submitted→running` interdit, answer après submit, double-submit). Le double-submit vérifie en plus `same(first)` (score figé immuable). Aucune transition illégale n'est un no-op muet (R6 respecté).

### AC3/AC5 — scoring (cœur)
Golden LITTÉRAL figé `ZStudySessionResult(mode: whiteExam, total: 5, correct: 3, byQuality: {5:1,3:1,2:1,0:1,4:1})`, comparé par égalité profonde de value-object. `correct = quality >= passThreshold` avec `passThreshold` LU de `ZSrsConfig` (jamais `3` littéral — vecteur `passThreshold:4 → correct:2` le prouve). Le scoring COMPOSE `ZStudySessionResult` (ES-2.7) — aucune duplication.

### AC4 — zéro-SM2 par construction
Aucun champ/paramètre `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore` ; aucun `.apply(`/`.initial(`/`.put(`/`reviewCard`/`ZRepetitionInfo` dans le code. Double garde : scan de source (a) + preuve de type (b, construction sans reviewer compile et court). INJ-1 confirme que le scan MORD.

---

## Autres axes (effort high)

1. **Pureté (AC1, AD-2)** : `extends ChangeNotifier`, import `package:flutter/foundation.dart` seul ; aucun riverpod/get/provider/material/widgets. `_setState` notifie uniquement sur changement réel (`next == _state` profond) → AC7 = 5 notifications exactes. **OK**.
2. **Value-object dédié** : `ZWhiteExamState` propre (phase/queue/cursor/answers/result), `==`/`hashCode` profonds (`listEquals`/`Object.hashAll`), `copyWith`. NE clone PAS `ZSessionState`. Reducers PURS top-level `startExam`/`recordAnswer`/`scoreWhiteExam`, déterministes, aucune horloge (`DateTime.now()` absent). **OK**.
3. **Aucune dépendance `zcrud_exam` (D9)** ; graphe INCHANGÉ, CORE OUT=0, melos=20, aucune nouvelle arête, aucun `.g.dart`. **OK (AD-1)**.
4. **Composition** : réutilise `ZStudySessionResult`/`ZSessionItem`/`ZReviewMode.whiteExam`/`ZSrsConfig.passThreshold` ; ne modifie pas `z_study_session_engine.dart`/`z_linear_session_state.dart`. Queue rendue `List.unmodifiable` au constructeur (bonus robustesse). **OK**.
5. **Couverture des 8 ACs** : tous discriminants (AC1 via scan permanent, AC8 via graph/melos orchestrateur). Aucun AC POWERLESS. **OK**.

---

## Findings

### LOW-1 — `answer()` n'a pas de borne haute de curseur (over-answer possible)
`answer()` (l.316-324) ne garde que `phase == running` ; il ne vérifie pas `cursor < queue.length`. Un appelant peut donc enregistrer plus de réponses qu'il n'y a de cartes : `cursor` dépasse `queue.length`, `answers.length > queue.length`, et `total` du scoring peut excéder la taille de la file.

- **Non-bloquant, sous-jacent délibéré** : `current` (l.122-123) renvoie `null` hors borne et `remaining` (l.129) est borné par `math.max(0, …)` — l'auteur a anticipé `cursor > length`. AC3 définit `total` comme « réponses enregistrées » (et non `queue.length`), ce qui *légitime* le comportement. La soumission est pilotée par le binding (minuteur, D6-gotcha) ; l'UI n'appelle pas `answer()` sur une carte `null`.
- **Recommandation (optionnelle, hors périmètre strict)** : si l'on veut faire respecter la borne « strictement linéaire 0→N » côté domaine (esprit R6), ajouter `if (_state.cursor >= _state.queue.length) throw StateError(...)` dans `answer()`, avec un test discriminant. À défaut, consigner comme choix assumé. **Aucune régression, aucun AC cassé → reporté sans blocage.**

Aucun finding HIGH/MAJEUR/MEDIUM.

---

## Conclusion
Story **verte**, invariants CŒUR (machine à états mordante, scoring golden déterministe, zéro-SM2 PAR CONSTRUCTION) prouvés par injections rejouées réellement. AD-1/AD-2/AD-4/AD-23 et R6/R12/R13/R14/R15 respectés. **Prête pour `done`** (gates REPO-WIDE `melos analyze`/`melos verify` délégués à l'orchestrateur au gate de commit d'epic, workstream B actif). Le LOW-1 est une observation non-bloquante laissée à l'arbitrage de l'orchestrateur.
