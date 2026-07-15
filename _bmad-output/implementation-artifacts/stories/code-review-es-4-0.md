# Code-review ES-4.0 — Plancher constant du gate de rétro-compat sérialisation

Reviewer : bmad-code-review (adversarial, effort high). Skill invoqué via tool `Skill` (bmad-code-review) — PAS de fallback disque.
Story : `es-4-0-plancher-gate-serialisation.md` (8 ACs, INJ-1..INJ-4).
Fichiers revus (diff = 2 fichiers, +197 / −3, aucun autre) : `scripts/ci/verify_serialization.dart`, `scripts/ci/prove_gates.dart`.

## VERDICT : APPROVED — `review` → prêt pour `done`

Le plancher est LOAD-BEARING (mord réellement), placé anti-PIÈGE-A (avant l'early-return), inconditionnel, littéral constant, et la preuve committée est NON-POWERLESS (rougit quand la garde saute). Aucun finding HIGH/MAJEUR/MEDIUM. Squelette ES-3.5 intact. Runs verts REJOUÉS réellement sur disque (RC capturé HORS pipe, R15).

## Preuves REJOUÉES (RC hors pipe, foreground)

| # | Commande | RC | Résultat |
|---|----------|----|----------|
| Baseline analyze | `dart analyze` des 2 scripts | 0 | 1 `info` `prefer_interpolation` prove_gates.dart:295 — **PRÉ-EXISTANT** (commit ES-2.0 6d86942, concat délibérée `'AIza'+…` pour éviter un littéral-secret ; HORS diff ES-4.0) → non bloquant |
| Baseline no-env | `verify_serialization.dart` | 0 | corpus vert, plancher muet |
| Baseline switch | `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 verify_serialization.dart` | 0 | corpus vert, plancher muet |
| **Axe 1 — FLOOR mord** | `--packages <dir vide>` (SANS switch) | **1** | bannière `❌ FLOOR VIOLATION` nommant les **3 socles** {zcrud_firestore, zcrud_generator, zcrud_study_kernel} |
| prove_gates | `prove_gates.dart` (foreground) | 0 | **43 OK, 0 FAIL** (41→43) ; `serialization-floor/fixture-exit-population` [OK] + `contre-epreuve-arbre-reel` [OK] |
| `--packages=X` (forme `=`) | `--packages=<vide>` | 1 | FLOOR — parsing des 2 formes OK |

## Axe n°1 (CŒUR anti-faux-vert) — le plancher est LOAD-BEARING : PROUVÉ

- **RC=1 inconditionnel** : `--packages <vide>` SANS `ZCRUD_REQUIRE_SERIALIZATION_COMPAT` → RC=1 (R16). En CI le mécanisme ordinaire (skip) est non-fatal hors interrupteur ⇒ tout RC=1 hors switch ⟺ le plancher. Vérifié.
- **`_floorRequired` = littéral CONSTANT** (`const Set<String> {...}`, l.117-121), JAMAIS dérivé de la population — pas de tautologie POWERLESS. Confirmé par lecture + grep.
- **Placement anti-PIÈGE-A — INJECTION REJOUÉE** : j'ai déplacé (édition ciblée) le bloc plancher APRÈS `if (withTests.isEmpty) exit(0)`. Résultat : `--packages <vide>` retombe dans le NO-OP → **RC=0** (faux-vert ré-ouvert). Restauré par édition ciblée → `--packages <vide>` re-donne **RC=1**. ⇒ Le placement AVANT l'early-return est bien LOAD-BEARING (le contrôle actuel est à l.280-286, avant l'early-return l.288).
- **INJ-4 — preuve NON-POWERLESS REJOUÉE** : bloc `if (floorMissing.isNotEmpty){…exit(1);}` commenté → `prove_gates.dart` foreground → `serialization-floor/fixture-exit-population` devient **[FAIL]** (exit=0, bannière FLOOR: false), RESULTAT **42 OK, 1 FAIL**, RC=1. Restauré → 43 OK. ⇒ La preuve committée rougit quand la garde saute (R12).

## Autres axes (effort high)

1. **RC=1 inconditionnel (R16)** : OK — la preuve prove_gates passe par `_verifyNoSwitch` (copie env, RETIRE la seule var-interrupteur, `includeParentEnvironment:false`), RC=1 imputable au plancher SEUL.
2. **Squelette INCHANGÉ (additivité stricte)** : `git diff` = purement additif. Les 3 SEULES suppressions sont : signature `void main()`→`main(List<String> args)`, littéral `Directory('packages')`→paramétrable, et la string NO-OP `pas de packages/`→`pas de $packagesDir/`. `_declaresCompatTag` (opt-in D7), `_isFlutterPackage`, la boucle d'exécution, `exit 79`→skip, interrupteur ES-3.5, `_banner` ES-1.4 : INTACTS.
3. **Sélectivité (AC4)** : plancher = EXACTEMENT les 3 socles. Structurellement garanti — `_floorRequired.difference(payable)` ne peut nommer QUE des membres du littéral const ; un package hors-plancher ne peut JAMAIS être forcé dans le plancher. La bannière empty-dir nomme exactement les 3, jamais un 4e. Non-régression ES-3.5 : un tag-declarer hors-plancher sans corpus reste `skipped`→RC=1 sous interrupteur (code opt-in inchangé, exercé vert sur l'arbre réel).
4. **`--packages`** : parsing `--packages X` ET `--packages=X` (l.240-248), défaut `packages`, NO-OP `exit(0)` si dossier absent (l.251-258). Les 2 formes REJOUÉES → RC=1 sur vide.
5. **prove_gates** : 41→43 OK, RC=0. Fixture `floor_empty_population` créée SOUS `tmp` (`Directory.systemTemp.createTempSync`), nettoyée par `tmp.deleteSync(recursive:true)` dans le `finally` existant ; `exit(rc)` HORS du `try`. Interrupteur retiré via `_verifyNoSwitch` (isolation R2). Aucune fixture résiduelle sur disque (vérifié).
6. **info analyze prove_gates.dart:295** : PRÉ-EXISTANT (ES-2.0, non introduit par ES-4.0) → non bloquant.
7. **Couverture 8 ACs** : tous discriminants et vérifiés. Nuance INJ-3 : la branche « tag-declarer hors-plancher sans corpus → skip → RC=1 sous interrupteur » n'est PAS entièrement isolée dans prove_gates (exigerait des packages-fixtures résolvables sous le verrou de parallélisation). Acceptable : (a) la sélectivité du plancher est prouvée (le decoy n'est jamais nommé) ; (b) le path opt-in est du code ES-3.5 INCHANGÉ (diff additif), exercé vert sur l'arbre réel with/without interrupteur. → consigné LOW/justifié, non bloquant.

## Findings

- **HIGH / MAJEUR / MEDIUM : AUCUN.**
- **LOW-1 (justifié, non bloquant)** — INJ-3 branche skip-sous-interrupteur non entièrement isolée en fixture prove_gates (faute de packages-fixtures résolvables). Couverte par diff-additif + selectivité const-literal + runs arbre-réel verts. Aucune action requise dans le périmètre ES-4.0.
- **LOW-2 (info pré-existant)** — `prefer_interpolation` prove_gates.dart:295 : hérité d'ES-2.0, concaténation délibérée anti-secret-littéral. Hors périmètre.

## État final sur disque

- 2 fichiers modifiés (`verify_serialization.dart`, `prove_gates.dart`) ; toutes les injections restaurées par édition ciblée (R13, jamais `git checkout`).
- Aucun résidu : `packages/*/dart_test.yaml` propres (pas de résidu INJ-1), aucun `.zcrud_gate_dist_*`, aucun `floor_empty_population`.
- `sprint-status.yaml`, `packages/**`, `pubspec.yaml` NON touchés (isolation workstream A respectée).
- Décision : story ES-4.0 → `done` ; DW-ES35-1 → ✅ SOLDÉE (édition ciblée du sprint-status par l'ORCHESTRATEUR, pas par la story).
