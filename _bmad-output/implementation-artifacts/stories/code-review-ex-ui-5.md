# Code Review — EX-UI.5 : `zcrud_navigation` (politique de présentation PURE)

- **Story** : `ex-ui-5-edition-presentation-policy` — Status: `review`
- **Reviewer** : agent BMAD adversarial (skill `bmad-code-review` chargé ; revue conduite en lecture seule)
- **Date** : 2026-07-16
- **Périmètre revu** : `packages/zcrud_navigation/**` (pubspec, barrel, 3 fichiers domaine, 3 fichiers de test, README, analysis_options) + 1 ligne `workspace:` du `pubspec.yaml` racine.

## Verdict : ✅ APPROVED — aucun finding HIGH ni MEDIUM

Les 6 ACs sont **satisfaits ET testés**. Vérifications vertes rejouées sur disque. Seuls 2 nits **LOW** non bloquants.

---

## Vérifications rejouées (sur disque, pas sur la foi du Dev Record)

| Vérif | Résultat |
|---|---|
| `dart analyze packages/zcrud_navigation` | **No issues found!** (RC=0) |
| `flutter test packages/zcrud_navigation` | **All tests passed!** — **14 tests** |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK / CORE OUT=0 OK** ; arêtes `zcrud_navigation → zcrud_core` + `zcrud_navigation → zcrud_responsive` (2 sortantes, 0 entrante) ; 22 nœuds |
| `dart run melos list` | `zcrud_navigation` présent 1× ; **22** membres (N=21 → N+1) |
| Pureté (`grep import 'package:flutter'` dans `lib/src/domain/`) | **0 import réel** — les 3 occurrences `package:flutter` sont en **dartdoc** |
| Imports interdits (`dartz`/`get`/`flutter_riverpod`/`provider`/`go_router`) | **AUCUN** dans `lib/` |
| `ZWindowSizeClass` redéclaré ? | **NON** — consommé via `import ... show ZWindowSizeClass` |
| `ZFormPresenter`/`ZAdaptivePresenter` anticipés ? | **AUCUN code** — seulement mentionnés en dartdoc comme HORS périmètre (EX-UI.6) |

---

## Couverture des ACs (axes adversariaux)

- **AC1 — Scaffolding** ✅ : pubspec (`name`, `version: 0.2.0`, `publish_to: none`, `resolution: workspace`, `sdk: ^3.12.2`, deps = `flutter`+`zcrud_core:^0.2.0`+`zcrud_responsive:^0.2.0`, `flutter_test` dev, `description`/`homepage`/`repository`/`issue_tracker`/`topics`). `analysis_options.yaml` → `include: ../../analysis_options.yaml`. Barrel + README présents. `- packages/zcrud_navigation` ajouté au bloc `workspace:` racine (l.67) ; `melos.yaml` non touché. `presentation/` non créé — **explicitement permis** par AC1 (« si l'arbo vide n'est pas suivie par git… ne pas bloquer dessus »).
- **AC2 — `ZEditionPresentation { page, sheet, dialog }`** ✅ : enum camelCase, pur, non sérialisé, dartdoc du fallback `@JsonKey`. Testé (`z_edition_presentation_test.dart` fige `.values`).
- **AC3 — `ZFormWeight { light, heavy }`** ✅ : enum (jamais `bool`), pur, dartdoc `light`→dialog / `heavy`→page, défaut `light`. Testé.
- **AC4 — `resolve()` PURE, mapping M3, jamais de throw** ✅ : **switch expression exhaustif** (`ZWindowSizeClass` × `ZFormWeight`), aucun `default`/`throw`, aucun `BuildContext`, entrée toujours `ZWindowSizeClass`. **Table de vérité 3×2 complète et PORTEUSE** : `compact`(light+heavy)→`sheet`, `medium`(light+heavy)→`dialog`, `expanded`+`light`→`dialog`, `expanded`+`heavy`→`page` (6 combinaisons, `expect` sur valeur exacte → casser une case rougit) + déterminisme + défaut `formWeight` omis == `light`.
- **AC5 — Injectable, non-`sealed`, défaut fourni** ✅ : `ZPresentationPolicy.from(resolver)` **ET** sous-classe (`resolve` non-`final`) — les deux **prouvés par test** (`_AlwaysPagePolicy` hors package, resolver custom `compact→dialog`). Défaut `const ZPresentationPolicy()` / `const .material()`.
- **AC6 — Graphe, gates, codegen no-op** ✅ : 2 arêtes sortantes exactes, `CORE OUT=0` intact, DAG. `melos run generate` no-op (aucun `build_runner`/`@ZcrudModel`). analyze RC=0. `melos list` = 22.

---

## Findings

### HIGH — aucun.
### MEDIUM — aucun.

### LOW-1 (nit, non bloquant, pré-existant au template)
`packages/zcrud_navigation/README.md:58` référence `[LICENSE](LICENSE)` mais **aucun fichier `LICENSE`** n'existe dans le package. **Impact** : lien mort dans la doc.
**Nuance** : le package frère `zcrud_responsive` présente **exactement** le même motif (README référence LICENSE, fichier absent) — c'est une incohérence de gabarit **partagée et pré-existante**, non introduite par cette story. `zcrud_core`, lui, a bien un `LICENSE`.
**Correction suggérée** (hors périmètre strict d'EX-UI.5, à traiter globalement) : ajouter un `LICENSE` par package, ou retirer la référence des README des packages qui n'en ont pas.

### LOW-2 (nit)
`lib/src/presentation/` n'est pas créé. **Conforme** à AC1 (dir vide non suivie par git, peuplée par EX-UI.6, sans placeholder). Consigné pour mémoire, **aucune action**.

---

## Conformité AD (ciblée)

AD-30 (politique dérivée du breakpoint, enum + policy injectable) ✅ · AD-1 (acyclique, CORE OUT=0, 2 arêtes sortantes) ✅ · AD-6 (substituable, prouvé) ✅ · AD-4 (jamais `sealed`, prouvé) ✅ · AD-2/AD-15 (aucun gestionnaire d'état/routeur) ✅ · AD-5/AD-14 (pur, testable sans `BuildContext`) ✅ · AD-10 (switch exhaustif, jamais de throw) ✅ · AD-12 (zéro secret) ✅ · NFR-U7 (enums > booléens) ✅ · NFR-U11 (pas de codegen) ✅.

## Recommandation
Story prête pour `done`. Aucun finding HIGH/MEDIUM à corriger. LOW-1 (LICENSE) à traiter au niveau monorepo, hors périmètre d'EX-UI.5.
