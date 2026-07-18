# Code-review — fp-3-1 (showcase socle + états + banc SM-1 + harnais axes, `example/`)

**Dispositif** : Workflow multi-lentilles (3 lentilles : vrai dispatcher, banc SM-1, états/réalité) + phase R3. Rapports : `$CLAUDE_JOB_DIR/tmp/cr-fp-3-1/`.

**Verdict** : **0 défaut de CODE.** Le socle showcase, les états transverses, les gaps « ABSENT » et le banc SM-1 sont **honnêtes et falsifiables** (R3 : SM-1 réellement non-tautologique — invariance du voisin RÉEL `a1Text2` + focus + `find.byType(Form)==findsNothing` ; champs rendus par les VRAIS adaptateurs via `DynamicEdition`→`ZFieldWidget`, `ZUnsupportedFieldWidget findsNothing`). `flutter test example` = **83 verts**, `dart analyze example` RC=0. Aucun package touché.

## Findings & résolutions

| # | Sévérité | Finding | Statut |
|---|---|---|---|
| 1 | MAJEUR | Completion Notes fausses vs disque : affirmaient `markdown_demo_test`/`offline_demo_test` « git clean / NON corrigé / analyze RC≠0 ». | **CORRIGÉ (prose réconciliée par l'orchestrateur)** — ces notes étaient VRAIES à l'écriture (l'agent dev de fp-3-1 a respecté sa frontière), mais l'**orchestrateur** a corrigé ces 2 fichiers ensuite via une **remédiation example distincte** (fakes réalignés sur le port réel `ZLocalStore`, `!` justifié — aucune assertion affaiblie). Notes mises à jour pour refléter l'état réel (analyze RC=0, 83 tests, les 2 fichiers hors File List fp-3-1 = remédiation séparée). Aucun défaut de code. |
| 2 | LOW | AC8 « `melos list` == 14 » périmé (réel 29 — monorepo agrandi par les satellites). Isolation elle-même OK (`zcrud_example` hors glob). | **CORRIGÉ** (prose 14→29). |
| 3 | LOW | Completion Note référence un symbole inexistant `_readModeCard`/`ZReadOnlyFieldCard` (impl réelle = `bool _readOnly` + `setState`). | **CORRIGÉ** (prose). |
| 4 | LOW | Banc SM-1 : le check curseur (`selection.baseOffset==100`) est porté par `enterText` cumulatif (curseur toujours en fin) ⇒ n'attrape pas un reset curseur MID-STREAM. Les checks porteurs (invariance voisin, focus, no-Form) restent sains ⇒ falsifiabilité globale intacte. | **CONSIGNÉ (justifié)** — la préservation du curseur mid-stream est une propriété du **widget texte de `zcrud_core`** (non injectable en scope example-only, cf. lentille), testée au niveau cœur. Le banc example prouve la GRANULARITÉ SM-1 (le vrai objet de fp-3-1), pas la mécanique curseur du champ texte. Hors périmètre example. |

## Vérif verte (rejouée par l'orchestrateur)
`flutter test example` = **83 passed, RC=0** ; `dart analyze example` RC=0 (1 info deprecation pré-existante non fatale) ; `git status packages/` inchangé côté fp-3-1 (aucun package modifié). R3 : 4/4 injections confirmées, arbre à l'identique.

**Statut** : `done` (findings prose corrigés ; LOW SM-1 curseur consigné/justifié).
