# Code-review ES-4.2 — Runtime de session SRS en cycle (`ZStudySessionEngine`)

**Verdict : APPROVED** (aucun finding HIGH/MAJEUR/MEDIUM). 3 LOW consignés (optionnels).
Revue adversariale effort **high** — workstream A isolé (`packages/zcrud_session/**`).

## Vérif verte CIBLÉE rejouée RÉELLEMENT (RC hors pipe, R15)

| Commande | Attendu | Résultat |
|---|---|---|
| `flutter test` (zcrud_session) | RC=0 | **RC=0 — All tests passed! (20 tests)** |
| `dart analyze packages/zcrud_session` | RC=0 | **RC=0 — No issues found!** |
| `python3 scripts/dev/graph_proof.py` | ACYCLIQUE + CORE OUT=0 | **RC=0 — ACYCLIQUE OK, CORE OUT=0 OK ; noeuds=20/20** |
| `dart run melos list` | 20 | **20** |

Arêtes de `zcrud_session` : **SORTANTES seules** `→ {zcrud_core, zcrud_flashcard, zcrud_study_kernel}` (0 entrante) — AD-1 préservé.

## Axe n°1 — AD-23 « zéro écriture SM-2 PAR CONSTRUCTION » + offsets (PREUVE REJOUÉE)

- **Zéro-apply-parasite (AC2)** : `grep` sur `lib/` ⇒ **aucun** `ZSrsScheduler`/`ZRepetitionStore` en champ, **aucun** `.apply(`/`.put(` ; le seul `.initial(` est `ZSessionState.initial` (état de file, pas scheduler). Le moteur ne détient que `_review` (seam) + `_config` (`ZSrsConfig`, lecture de `passThreshold`). Voie d'écriture SRS unique par construction. **CONFIRMÉ.**
- **INJ-1 rejouée** (2ᵉ `await _review` hors voie unique) → `flutter test` **RC=1** : espion `Expected <3> / Actual <6>` (et `<1>`/`<2>`). Restaurée par édition ciblée → re-vert 20/20. **La garde MORD.**
- **INJ-2 rejouée** (`kLapseOffsetSoft` 2→3) → `flutter test` **RC=1** : golden d'ordre `Expected 'BACDEF' / Actual 'BCADEF'`. Restaurée → re-vert 20/20. **L'offset +2/+4 MORD.**
- **Offset UTILISATEUR (D2), pas la constante brute 3/5 d'IFFD** : `kLapseOffsetSoft=2`/`kLapseOffsetHard=4`, `insertIndex = min(cursor+offset-1, len)`. Golden littéral figé (`'BACDEF'`, `'ACDBEF'`, `'BCDAEF'`, clamp `'YZX'`) — recalculé et vérifié à la main, cohérent avec « dans 2/4 cartes » (lex) et « 2/4 cards later » (IFFD après remove-then-insert). **CONFORME.**
- **Seuil paramétré (AC4)** : `_passThreshold => _config.passThreshold` ; aucun `3` littéral. Vecteur config-custom `passThreshold:4` présent. INJ-3 documentée. **CONFORME.**
- **Atomicité (AC6)** : `grade` invoque le seam D'ABORD ; sur `Left` la file n'est PAS mutée, `error` exposé + `Left` remonté (jamais avalé) ; sur `Right` reducer pur + notify. Vecteur `Left ⇒ file inchangée + error exposée` présent. **CONFORME (AD-5/R6).**

## Autres axes

- **Pureté (AC1, AD-2)** : `z_purity_test.dart` scanne `lib/**`, bannit `flutter_riverpod`/`riverpod`/`get`/`provider`/`flutter/material`/`widgets`/`cupertino`. Imports réels du moteur = `flutter/foundation` + core/flashcard/kernel uniquement. État immuable value-object (`listEquals`, `==`/`hashCode` profonds). `notifyListeners` granulaire (`_setState` compare avant notify). **CONFORME.**
- **AC10** : aucun `.g.dart`, aucun `@ZcrudModel`/`build_runner`. **CONFORME.**
- **Seam typedef** = signature EXACTE de `reviewCard` (`{flashcardId, folderId, quality, now}` → `Future<ZResult<ZRepetitionInfo>>`). Aucun couplage au store. **CONFORME.**
- **Couverture 10 ACs** : chaque AC porte un vecteur discriminant (golden ordre, espion, seuil custom, `Left`/`Right`, listener compteur, reducer immuabilité). Pouvoir discriminant R12 satisfait.

## Findings

### LOW-1 — `cursor` est un état mort (invariant = 0)
`z_study_session_engine.dart:77,100` / `z_session_state.dart:54`. `reduceGrade` retire toujours à `cursor` puis pose `newCursor = min(cursor, len-1)` ; `cursor` valant 0 à l'`initial` et n'étant jamais avancé, il reste **invariablement 0**. `current` renvoie donc toujours `queue[0]`. L'abstraction `cursor` (champ + `insertIndex = cursor+offset-1`) ajoute de la complexité sans effet observable. **Sans impact fonctionnel** (offsets et goldens corrects car `cursor=0`). Simplification possible : traiter explicitement le front de file. **Optionnel.**

### LOW-2 — Discriminant AC2 « zéro apply parasite » repose sur la construction, pas un test
L'espion compte les appels du **seam** ; un `scheduler.apply` parasite coexistant NE ferait PAS bouger ce compteur. La garantie « une seule voie » tient donc *par construction* (aucun scheduler/store injecté — vérifié par grep), pas par un test de surface. Conforme à l'intention explicite de la story (« par construction »), mais la phrase « test de surface refuse un `ZSrsScheduler` » de l'AC2 n'est pas littéralement implémentée. **Consigné, non bloquant.**

### LOW-3 — No-op sur session complète : `Left` retourné mais `state.error` non exposé
`grade` sur file vide renvoie `Left(DomainFailure)` sans passer par `_setState`/`withError` ⇒ `state.error` reste `null` (asymétrique avec le `Left` issu du seam qui, lui, peuple `state.error`). Défensif et sans conséquence (aucune carte à réviser), mais légère incohérence de surface. **Optionnel.**

## Injections R3 — bilan (rejouées par le reviewer)
- INJ-1 (double seam) : **RED confirmé** puis restauré, re-vert 20/20.
- INJ-2 (offset 2→3) : **RED confirmé** (`'BACDEF'/'BCADEF'`) puis restauré, re-vert 20/20.
- INJ-3/INJ-4/INJ-5 : vecteurs présents et cohérents dans la suite (non re-déroulés ici ; INJ-1/INJ-2 = axe central R12 exigé, rejoués RÉELLEMENT).

**Story RESTE VERTE.** Aucun finding bloquant ⇒ prête pour `done` (transition sprint-status par l'orchestrateur).
