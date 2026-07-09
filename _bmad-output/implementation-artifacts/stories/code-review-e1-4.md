# Code Review — Story E1-4 : Gate de compatibilité de résolution de dépendances (FR-25)

- **Date** : 2026-07-09
- **Reviewer** : bmad-code-review (adversarial, layers Blind Hunter / Edge Case Hunter / Acceptance Auditor exécutés par l'orchestrateur reviewer, model claude-opus-4-8)
- **Baseline** : `8f28755` (arbre non suivi = diff intégral E1-4)
- **Fichiers sous revue** : `tool/compat_check/pubspec.yaml`, `tool/compat_check/README.md`, `scripts/ci/gate_compat_resolution.dart`, `scripts/ci/prove_gates.dart` (étendu), blocs `melos:` de `pubspec.yaml` + `melos.yaml` (ajout `gate:compat`), `.github/workflows/ci.yml`, `analysis_options.yaml` (`exclude: tool/**`).
- **Grounding** : `architecture.md` (Stack, FR-25, AD-1/AD-15), PRD FR-25, `CLAUDE.md`.

## Verdict : **APPROVED** (avec 1 MEDIUM de renforcement recommandé, non bloquant)

Aucun finding HIGH/MAJEUR. Les 8 ACs sont matériellement satisfaits et vérifiés sur disque. Le gate détecte réellement les conflits (prouvé par la fixture du dev **et** par une fixture indépendante du reviewer). Isolation Flutter/pur-Dart intacte. M-1 respecté. Non-régression E1-1/E1-2/E1-3 confirmée.

---

## Vérifications rejouées RÉELLEMENT sur disque (Flutter 3.44.4 / Dart 3.12.2)

| Vérif | Résultat réel |
| --- | --- |
| `python3 scripts/dev/graph_proof.py` | **17 arêtes, 14 nœuds, ACYCLIQUE OK, CORE OUT=0**, RC=0 (inchangé — `tool/` hors scope) |
| `dart run melos list` | **14 membres** (compte grep `zcrud_` = 14) |
| `gate_melos_divergence.dart` (M-1) | **OK — 11 scripts identiques** dans les 2 blocs, RC=0 |
| `gate_compat_resolution.dart` (direct) | **RC=0** ; résolu : flutter_quill 11.5.1, awesome_select 6.0.0, analyzer 7.7.1 ; voie opportuniste SKIP propre |
| `prove_gates.dart` | **22 OK, 0 FAIL** (dont compat/clean, compat/fixture, compat/opportuniste-skip) |
| `melos run verify` | **RC=0** — graph + melos + reflectable + secrets + codegen + compat + verify:serialization tous verts |
| Fixture reviewer indépendante (`flutter_quill >=999.0.0`) | **exit=1 VIOLATION** détectée — le gate n'est pas sensible qu'au seul cas analyzer du dev |
| `analyzer ^7.0.0` + `build_runner ^2.4.0` + `source_gen` + `json_serializable ^6.11.2` (probe reviewer) | **co-résolvent (exit=0)** — la justification README de l'analyzer tient empiriquement aujourd'hui |
| Locks/`.dart_tool` parasites dans `tool/` | **aucun** (README.md + pubspec.yaml seulement) — `--dry-run` n'écrit rien |
| `pubspec.lock` | **un seul, racine** |
| `sdk: flutter` dans `packages/` | **aucun** — les 14 membres restent pur-Dart |

---

## Triage des findings

### HIGH / MAJEUR
_Aucun._

### MEDIUM

**M1 — La branche « analyzer » du triplet FR-25 est quasi-vacue dans le manifeste ; le README affirme plus que le gate ne prouve.**
- **Fichiers** : `tool/compat_check/pubspec.yaml:42`, `tool/compat_check/README.md:32`.
- **Problème** : `analyzer` n'a **aucune contrainte croisée** avec `flutter_quill` ni `awesome_select` (ni l'un ni l'autre ne dépend d'analyzer). Les paquets qui bornent réellement analyzer — `build_runner`/`source_gen`/`json_serializable` — sont **absents** de `tool/compat_check/`. Le dry-run résout donc analyzer **en isolation** (7.7.1) et ne prouve **rien** sur la co-résolution avec le stack de codegen E2-5. Or le README (l.32) justifie `analyzer ^7.0.0` comme « compatible source_gen/build_runner du codegen zcrud (E2-5) » : **cette affirmation n'est pas vérifiée par le gate**. C'est le « faux compat OK » pointé en vigilance adversariale, restreint à la dimension analyzer (le reviewer a vérifié à la main que la co-résolution tient *aujourd'hui*, mais le gate ne la garde pas — une future borne build_runner incompatible passerait inaperçue).
- **Correctif** (au choix, périmètre réduit) :
  1. Ajouter `build_runner: ^2.4.0`, `source_gen`, `json_serializable: ^6.11.2` en `dev_dependencies` de `tool/compat_check/pubspec.yaml` pour que la branche analyzer **co-résolve réellement** contre le stack de codegen (rend la dimension analyzer du triplet non vacue et transforme la claim README en propriété gardée) ; **ou**
  2. Assouplir la formulation du README (l.32) pour indiquer explicitement que la borne analyzer est résolue **isolément** et **non** prouvée contre build_runner/source_gen à ce stade (report du contrôle à E2-5).
- **Statut** : non bloquant pour le merge — la story implémente FR-25 **à la lettre** (« flutter_quill + awesome_select + analyzer ») et la propriété tient empiriquement. À corriger de préférence (renforcement du signal / cohérence doc↔preuve), sinon à justifier par écrit conformément à la politique MEDIUM (CLAUDE.md).

### LOW / nits

**L1 — AC 2 dit « déterministe » mais les contraintes flottent (pas de lockfile).**
- `tool/compat_check/pubspec.yaml` : `^11.5.0` / `^6.0.0` / `^7.0.0` + `--dry-run` sans lock committé ⇒ la résolution flotte dans les bornes caret. Un nouveau `flutter_quill 11.x` (ou une version retirée) peut changer le résultat **sans** modification du repo. C'est probablement l'intention (détection de dérive), mais « déterministe » (AC 2) est surévalué. Correctif : soit committer/verrouiller un lockfile pour le compat, soit documenter que le gate flotte volontairement (drift-detection) plutôt qu'il n'est temporellement déterministe.

**L2 — `awesome_select 6.0.0` : paquet non maintenu.**
- `awesome_select` (dernière stable 6.0.0, ancienne) est un paquet peu/pas maintenu. Le choix « dernière stable » est documenté et la **divergence Stack** est signalée (README l.31), mais le **risque de maintenance** (compat Flutter future, E3) n'est pas mentionné. Informationnel : à confirmer contre le workspace lex_douane réel (voie opportuniste) et à réévaluer en E3.

**L3 — `gate_compat_resolution.dart:44-53` `_logResolved` + `:85` cast `'${manifest.stdout}'`.**
- Purement cosmétique (traçabilité) : le pass/fail repose **uniquement** sur `manifest.exitCode` (correct — pas de faux vert issu du parsing de log). La regex `^[+*!]?\s*(\w+)\s+(\S+)` et le cast String du stdout n'affectent pas la décision. Aucun correctif requis ; nit consigné.

---

## Audit d'acceptation (8 ACs)

| AC | Statut | Preuve |
| --- | --- | --- |
| 1 — Package isolé hors graphe pur-Dart | ✅ | absent de `workspace:`/`packages/**`/`graph_proof.py` ; `melos list`=14 ; graph 17 arêtes ; 1 lock racine ; aucun `sdk: flutter` dans `packages/` ; `analyze` racine exclut `tool/**` |
| 2 — Dry-run manifeste (autorité) | ✅ (cf. L1) | RC=0 ; versions loggées ; indépendant de lex_douane |
| 3 — Échoue sur incompatibilité (fixture) | ✅ | fixture dev (analyzer >=99) exit≠0 **+** fixture reviewer (flutter_quill >=999) exit≠0 ; arbre courant exit=0 ; fixtures éphémères non committées |
| 4 — Versions documentées + tracées | ✅ (cf. M1) | README + commentaire pubspec ; sources Stack/divergences signalées ; cible Dart ^3.12.2 documentée. Réserve M1 sur la claim analyzer↔build_runner |
| 5 — Voie opportuniste non bloquante | ✅ | `LEX_WORKSPACE` absent ⇒ SKIP RC=0 (vérifié) ; illisible ⇒ INFO non bloquant ; logique revue (indispo ≠ échec) |
| 6 — Câblage CI bloquant (voie manifeste) | ✅ | `ci.yml` étape dédiée après gates, avant `prove_gates` ; ordre codegen→analyze→test→gates préservé |
| 7 — Script melos `gate:compat` conforme M-1 | ✅ | répliqué identique (2 blocs) ; `gate:melos` OK 11 scripts ; chaîné dans `verify` ; toolchain absente ⇒ exit=3 explicite (logique `ProcessException→null→exit 3` revue, pas de faux vert) |
| 8 — Non-régression E1-1/E1-2/E1-3 | ✅ | 14 membres, 17 arêtes acycliques, 1 lock, tous gates verts, aucun `.g.dart` committé, aucun package pur-Dart ne tire Flutter |

---

## Conclusion

Implémentation solide, isolée et non régressive ; les gates sont réellement discriminants (double fixture). **APPROVED.** Recommandation : traiter **M1** (renforcer la branche analyzer du gate **ou** aligner le README sur ce qui est réellement prouvé) — petit périmètre, sans régression. L1/L2/L3 optionnels/consignés.
