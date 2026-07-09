---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 1.3 : Lint, analyse, build_runner & gates CI (SM-6)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du monorepo zcrud**,
je veux **un `analysis_options` partagé, des scripts melos durcis (generate/analyze/test) et un pipeline GitHub Actions qui exécute codegen → analyse → tests puis fait échouer le merge sur toute violation des gates de qualité (anti-`reflectable` dans le moteur, secret committé, modèle annoté sans `.g.dart`, cycle de dépendance AD-1, divergence des blocs de scripts melos)**,
afin que **l'hygiène et les invariants d'architecture soient vérifiés automatiquement à chaque push — sans dépendre d'une revue humaine — et que chaque gate soit prouvé « échoue sur violation, passe sinon » par une fixture dédiée.**

## Contexte & valeur

E1-1 (workspace melos + `resolution: workspace`) et E1-2 (barrels + arbo `src/` + arêtes AD-1 acycliques) sont **DONE**. La résolution passe (14 membres, lockfile unique), tout compile (`melos run analyze` RC=0 sur 14), et l'acyclicité est prouvée par `scripts/dev/graph_proof.py`. **Il n'existe encore aucune automatisation CI ni aucun `analysis_options`.** Cette story ferme l'épic d'habilitation E1 sur le plan **outillage & gates** : elle transforme les vérifications aujourd'hui **manuelles et rejouées à la main** en **gates de merge automatiques**, couvrant **SM-6** (« la qualité et l'hygiène sont vérifiées à chaque push ») et matérialisant les gates d'architecture E1-3/E2-10 exigés par le CLAUDE.md et l'architecture.

Elle porte **deux dettes explicitement reportées** des code-reviews E1-1 et E1-2 (voir §Dette portée) :
- **M-1** (code-review E1-1) : garde-fou CI **anti-divergence** entre le bloc `melos:` du **root `pubspec.yaml`** (source de vérité des scripts) et le bloc `scripts:` de `melos.yaml` (copie ignorée sous pub workspaces).
- **L-3** (code-review E1-2) : **durcir `scripts/dev/graph_proof.py`** pour couvrir aussi `dev_dependencies:` / `dependency_overrides:` (angle mort actuel), et l'**intégrer comme gate CI d'acyclicité AD-1**.

**Ce qui rendra la story vérifiable :** un `analysis_options.yaml` racine partagé inclus par chaque package ; `melos run generate|analyze|test` durcis et fonctionnels ; un workflow `.github/workflows/*.yml` exécutant, dans l'ordre imposé, **codegen → analyze → test → gates** ; et, pour **chacun** des gates (anti-`reflectable`, scan de secrets, contrôle codegen, acyclicité AD-1, anti-divergence melos), une **fixture de violation** prouvant que le gate **échoue** (exit≠0) sur l'entrée fautive et **passe** (exit=0) sur l'arbre courant.

## État réel en place (hérité, à ne PAS régresser)

- `pubspec.yaml` racine : `name: zcrud_workspace`, `workspace:` = 14 membres, `dev_dependencies: melos ^7.0.0`, **bloc `melos:` = SOURCE DE VÉRITÉ des scripts** (`generate` filtré `dependsOn: build_runner`, `analyze` = `dart analyze .`, `test` filtré `dirExists: test`).
- `melos.yaml` : `name: zcrud`, `packages: [packages/**]`, **copie `scripts:` identique mais IGNORÉE** par melos ≥ 7 sous pub workspaces (les deux fichiers portent déjà un commentaire d'avertissement renvoyant à ce gate M-1).
- `scripts/dev/graph_proof.py` : extracteur de graphe AD-1 (Kahn + assertion `out-degree(zcrud_core)==0`), **ne lit que `dependencies:`** (angle mort L-3), `sys.exit(0/1)`.
- 14 packages avec barrels `lib/<pkg>.dart` + impl `lib/src/`, tous pur-Dart (aucun `flutter: sdk: flutter`), aucune dep lourde, aucun manager d'état.
- **Aucun** `analysis_options.yaml` (racine ni package). **Aucun** `.github/workflows/`. `.github/agents/` existe (fichiers BMAD, hors sujet).
- Toolchain local : `dart 3.12.2 (stable)` (satisfait `^3.12.2`), `flutter` présent (`/home/zakarius/flutter/bin/flutter`).
- **Aucun** modèle `@ZcrudModel`, **aucun** import `reflectable`, **aucun** `.g.dart` à ce stade (annotations = E2-4, générateur = E2-5). ⇒ les gates codegen/reflectable opèrent aujourd'hui sur une entrée **vide** : ils doivent être **corrects par construction** et **prouvés par fixture**, pas par la présence de vrais modèles.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ `analysis_options.yaml` racine partagé + `include` par package.
- ✅ Durcissement des scripts melos `generate`/`analyze`/`test` + ajout d'un script d'orchestration des gates (ex. `melos run verify` ou équivalent) — répliqué à l'identique dans les **deux** blocs (root `pubspec.yaml` **et** `melos.yaml`) pour rester conforme à M-1.
- ✅ Workflow GitHub Actions exécutant **codegen → analyze → test → gates**.
- ✅ Gate **anti-`reflectable`** ciblant les packages du moteur, **excluant** l'adaptateur `ReflectableCodec` DODLP (chemin allowlisté).
- ✅ Gate **scan de secrets** (échoue si clé/token committé ; couvre notamment la forme de clé Google Maps `AIza…` liée à E1-5).
- ✅ Gate **contrôle codegen** (aucun modèle annoté sans `.g.dart` correspondant après codegen).
- ✅ Gate **acyclicité AD-1** = `graph_proof.py` **durci** (L-3 : `dependencies:` + `dev_dependencies:` + `dependency_overrides:`), branché en CI.
- ✅ Gate **anti-divergence melos** (M-1).
- ✅ **Slot CI** pour la suite de **rétro-compatibilité de sérialisation** (E2-10, AD-10) : câbler l'étape/le job dans le workflow comme **partie du gate de merge**, en **placeholder no-op** que **E2-10 remplira** (ne pas écrire les tests de désérialisation défensive ici).
- ✅ Une **fixture de violation par gate** prouvant l'échec, isolée de la build normale (hors `packages/` du workspace).
- ❌ **Pas** de code de domaine, d'annotations, de générateur, de modèles réels (→ E2). Le gate codegen doit fonctionner **sans** eux.
- ❌ **Pas** d'écriture des tests de désérialisation défensive E2-10 (seulement le slot CI).
- ❌ **Pas** de révocation de clé Maps (→ E1-5) : le scan de secrets **détecte** la forme de clé, il ne gère pas la révocation.
- ❌ **Pas** le dry-run de compat de dépendances flutter_quill+awesome_select+analyzer (→ E1-4).
- ❌ **Ne PAS** ajouter `example/` au workspace. ❌ **Ne PAS** toucher `sprint-status.yaml` (géré par l'orchestrateur).

## Acceptance Criteria

1. **`analysis_options` partagé + include par package.** Un `analysis_options.yaml` **racine** définit la baseline de lint commune (ensemble de règles + `analyzer.errors`/`exclude` du codegen `*.g.dart`/`*.freezed.dart`). Chaque package `packages/<pkg>/` possède un `analysis_options.yaml` qui **inclut** la baseline racine (via `include:` relatif ou `package:`), de sorte que `dart analyze` par package et `melos run analyze` (14 packages) restent **RC=0** sans nouvel avertissement bloquant (non-régression E1-2). Aucun package pur-Dart n'est cassé par l'ajout (la baseline reste analysable sans SDK Flutter là où le package est pur-Dart).

2. **Scripts melos durcis et fonctionnels.** Les scripts `generate`, `analyze`, `test` du bloc `melos:` (root `pubspec.yaml`) sont durcis et **réellement exécutables** : `melos run analyze` RC=0 ; `melos run generate` RC=0 (no-op propre tant qu'aucun package n'a `build_runner`) ; `melos run test` RC=0 (no-op propre tant qu'aucun package n'a de dossier `test/`). Un script d'orchestration des gates (nom au choix, ex. `verify`) enchaîne les gates localement (mêmes gates que la CI). **M-1** : toute évolution des scripts est répliquée à l'identique dans `melos.yaml`, et le **gate anti-divergence** (AC 8) le garantit.

3. **Workflow GitHub Actions dans le bon ordre.** Un fichier `.github/workflows/<ci>.yml` se déclenche sur `push` et `pull_request` (au moins vers la branche par défaut) et exécute, **dans cet ordre** : setup toolchain (Dart/Flutter fournissant Dart `^3.12.2`) → résolution (`dart pub get` / `melos bootstrap`) → **codegen** (`melos run generate`) → **analyze** (`melos run analyze`) → **test** (`melos run test`) → **tous les gates** (AC 4–8) → **slot rétro-compat sérialisation** (AC 9). Le job est **vert** sur l'arbre courant. Le codegen précède analyze/test (CLAUDE.md).

4. **Gate anti-`reflectable` (AD-3).** Un gate échoue (exit≠0) si un fichier Dart d'un package **moteur** zcrud importe/référence `reflectable` (`import 'package:reflectable/...'`, `@Reflector`, `reflectable`), **à l'exclusion** du chemin de l'adaptateur `ReflectableCodec` DODLP (allowlist explicite et documentée, cf. Dev Notes — l'adaptateur est la seule exception AD-3 autorisée). Sur l'arbre courant (zéro reflectable) le gate **passe**. Une **fixture** contenant un import `reflectable` hors allowlist fait **échouer** le gate (prouvé).

5. **Gate scan de secrets (AD-12).** Un gate échoue (exit≠0) si un secret/clé/token est committé dans le dépôt (couvre au minimum la forme de **clé Google Maps** `AIza[0-9A-Za-z_\-]{35}` — la clé historiquement fuitée, cf. E1-5 — ainsi qu'un jeu de motifs génériques : clés AWS, tokens, `PRIVATE KEY`, `badCertificateCallback => true`). Sur l'arbre courant (aucun secret) le gate **passe**. Une **fixture** contenant une fausse clé/`AIza…` factice fait **échouer** le gate (prouvé). Le scan n'échoue pas sur les fixtures des autres gates ni sur ses propres motifs de définition (auto-exclusion documentée).

6. **Gate contrôle codegen (AD-3).** Après `melos run generate`, un gate échoue (exit≠0) s'il existe un **modèle annoté** (`@ZcrudModel`/`@ZcrudField` — ou, en attendant E2-4, la convention d'annotation retenue) **sans** fichier `.g.dart` correspondant généré (part `*.g.dart` manquante), ou si l'arbre de travail présente un `.g.dart` **obsolète/divergent** après régénération (`git diff` non vide sur le généré). Sur l'arbre courant (aucun modèle annoté) le gate **passe** (0 modèle ⇒ 0 manquant). Une **fixture** « modèle annoté sans `.g.dart` » fait **échouer** le gate (prouvé). *(Le gate doit être robuste au fait que `.g.dart` est gitignoré : il vérifie la présence **après** codegen, pas dans git.)*

7. **Gate acyclicité AD-1 durci (L-3).** `scripts/dev/graph_proof.py` est étendu pour extraire les arêtes `zcrud_*` de `dependencies:`, **`dev_dependencies:` ET `dependency_overrides:`** (angle mort actuel comblé), et est **branché comme gate CI** : exit≠0 sur cycle ou `out-degree(zcrud_core) > 0`. Sur l'arbre courant le gate **passe** (`ACYCLIQUE OK`, `CORE OUT=0 OK`, 17 arêtes inchangées — les 3 arêtes de composition + 13 backbone + generator→annotations). Une **fixture** introduisant un cycle **ou** une arête `zcrud_*` sous `dev_dependencies:` créant un cycle fait **échouer** le gate (prouvé). La non-régression du décompte d'arêtes runtime actuel est vérifiée.

8. **Gate anti-divergence melos (M-1).** Un gate échoue (exit≠0) si le bloc `scripts:` de `melos.yaml` **diverge** du bloc `melos: scripts:` du root `pubspec.yaml` (comparaison sémantique des scripts : mêmes clés, `exec`, `description`, `packageFilters`). Sur l'arbre courant (blocs identiques) le gate **passe**. Une **fixture** (ou un test injectant une divergence contrôlée) fait **échouer** le gate (prouvé), sans modifier durablement les fichiers réels.

9. **Slot CI rétro-compatibilité de sérialisation (E2-10, AD-10).** Le workflow comporte une étape/un job **dédié** « rétro-compat sérialisation » **rattaché au gate de merge**, exécuté après les tests. À ce stade c'est un **placeholder no-op vert** (aucun test défensif écrit ici) **explicitement documenté** comme « à remplir par E2-10 ». La structure permet à E2-10 d'y brancher sa suite **sans** modifier le workflow (ex. le slot exécute une commande/tag de test conventionnel que E2-10 alimentera). L'intention (rattachement à E1-3) est tracée en commentaire.

10. **Chaque gate est prouvé « échoue sur violation, passe sinon ».** Pour **chacun** des gates AC 4–8, une **fixture de violation** existe (hors `packages/` du workspace, ex. sous `scripts/ci/fixtures/` ou `test/ci/`) et une procédure reproductible (script/commande, ou test Dart) démontre : (a) gate **exit=0** sur l'arbre réel, (b) gate **exit≠0** quand pointé sur la fixture. Les fixtures **ne polluent pas** la build normale (exclues du workspace/analyse) et **ne déclenchent pas** le scan de secrets sur les autres gates.

11. **Non-régression E1-1/E1-2.** Après l'ajout : `dart pub get` / `melos bootstrap` RC=0, **un seul** `pubspec.lock` racine, `melos list` = **14**, `resolution: workspace` + `sdk: ^3.12.2` intacts (14/14), barrels et arêtes AD-1 inchangés, `.gitignore` codegen (`*.g.dart`/`*.freezed.dart`) non régressé, aucun `*.g.dart`/`*.freezed.dart` committé. Le bloc `melos:` du root `pubspec.yaml` reste la source de vérité des scripts.

## Tasks / Subtasks

- [x] **Task 1 — `analysis_options` partagé racine + include par package (AC: 1)**
  - [x] Créer `analysis_options.yaml` racine : baseline de lint (linter rules + `analyzer.exclude` de `**/*.g.dart`, `**/*.freezed.dart`, et des fixtures CI). Choix : `package:lints/recommended.yaml` (pur-Dart) — cf. Completion Notes.
  - [x] Ajouter dans chaque `packages/<pkg>/analysis_options.yaml` un `include: ../../analysis_options.yaml` (relatif), sans introduire de dépendance Flutter dans un package pur-Dart.
  - [x] Rejouer `dart analyze` par package + `melos run analyze` → **RC=0** partout (aucun nouvel avertissement bloquant). Consigné.
- [x] **Task 2 — Durcir les scripts melos + orchestrateur de gates (AC: 2)**
  - [x] Durcir `generate`/`analyze`/`test` (root `pubspec.yaml`) : `generate`/`test` en `run: melos exec` avec filtre => no-op PROPRE (0 exception) même sans package `build_runner`/`test`. Répliqué **à l'identique** dans `melos.yaml` (M-1).
  - [x] Ajouter un script d'orchestration `verify` enchaînant les gates AC 4–8 + slot E2-10 localement (réutilisé par la CI).
  - [x] Vérifier `melos run generate|analyze|test|verify` RC=0.
- [x] **Task 3 — Gate anti-`reflectable` + fixture (AC: 4, 10)**
  - [x] `scripts/ci/gate_reflectable.dart` scanne `packages/*/lib/**` pour `package:reflectable`/`@Reflector`, avec **allowlist** `*/reflectable_codec.dart` (ReflectableCodec DODLP, E2-6/E7).
  - [x] Fixture (éphémère, `prove_gates.dart`) : `import 'package:reflectable/reflectable.dart';` hors allowlist → exit≠0 ; arbre réel → exit=0 ; même import DANS `reflectable_codec.dart` → exit=0.
- [x] **Task 4 — Gate scan de secrets + fixture (AC: 5, 10)**
  - [x] `scripts/ci/gate_secret_scan.dart` (repli local) + gitleaks (autorité CI, `.gitleaks.toml`) couvrant `AIza…`, AWS `AKIA…`, PEM, tokens Slack, `badCertificateCallback => true`. Exclut `.git/`, code généré, prose Markdown, définitions de motifs + harnais.
  - [x] Fixture : faux `AIza`+35 chars → exit≠0 ; `badCertificateCallback => true` → exit≠0 ; arbre réel → exit=0.
- [x] **Task 5 — Gate contrôle codegen + fixture (AC: 6, 10)**
  - [x] `scripts/ci/gate_codegen.dart` : après `generate`, tout `@ZcrudModel` (application réelle, pas mention en doc-comment) doit avoir son `.g.dart` sur disque. Convention `@ZcrudModel` + `part '<file>.g.dart';`.
  - [x] Fixture : `@ZcrudModel` sans `.g.dart` (dossier temp hors workspace) → exit≠0 ; arbre réel (0 modèle) → exit=0.
- [x] **Task 6 — Durcir `graph_proof.py` (L-3) + brancher en gate (AC: 7, 10)**
  - [x] Bloc étendu à `dependencies:` + `dev_dependencies:` + `dependency_overrides:` (fermeture sur clé top-level, Kahn, assertion out-degree conservées). Arêtes dédupliquées (set) — pas de double-comptage. Argv `[ROOT]` pour fixtures.
  - [x] Sortie inchangée sur l'arbre réel : **17 arêtes**, `ACYCLIQUE OK`, `CORE OUT=0 OK`.
  - [x] Fixture : arête `zcrud_*` sous `dev_dependencies:` créant un cycle → exit≠0 ; idem sous `dependency_overrides:` → exit≠0.
- [x] **Task 7 — Gate anti-divergence melos M-1 + fixture (AC: 8, 10)**
  - [x] `scripts/ci/gate_melos_divergence.dart` : comparaison sémantique (clés + `run`/`exec`/`description`/`packageFilters`, canonicalisation triée) de `pubspec.yaml#melos.scripts` vs `melos.yaml#scripts`. Overrides `--pubspec`/`--melos` pour fixtures.
  - [x] Fixture : divergence injectée (copies de travail) → exit≠0 ; arbre réel → exit=0 (fichiers réels intacts).
- [x] **Task 8 — Workflow GitHub Actions (AC: 3, 9)**
  - [x] `.github/workflows/ci.yml` : triggers `push`/`pull_request` (main) ; `subosito/flutter-action@v2` (Dart `^3.12.2`) ; `dart pub get` ; `generate` → `analyze` → `test` → gates (graph, melos, reflectable, secrets, gitleaks, codegen, prove_gates) → **slot rétro-compat sérialisation**.
  - [x] Réutilise les mêmes commandes que `melos run verify` (source unique).
  - [x] Slot E2-10 documenté (commentaire + convention `verify:serialization` auto-découvrant les tests taggés `serialization-compat`).
- [x] **Task 9 — Vérification verte + non-régression + preuves fixtures (AC: 10, 11)**
  - [x] Rejoué : `dart pub get` RC=0, `melos list`=14, lockfile unique, SDK 14/14, `resolution: workspace` 14/14, barrels 14, arêtes AD-1 = 17, `.gitignore` codegen OK, 0 `.g.dart` committé.
  - [x] Chaque gate : exit=0 (réel) **et** exit≠0 (fixture) capturés (`prove_gates.dart` : 13 OK, 0 FAIL).
  - [x] Aucune fixture n'entre dans le workspace/l'analyse (éphémères, `analyzer.exclude` + gitleaks allowlist) ni ne déclenche un autre gate à tort.

## Dev Notes

### Contraintes d'architecture (NON-NÉGOCIABLES)

- **AD-3 (reflectable banni, sauf `ReflectableCodec` DODLP ; freezed non imposé)** — le gate anti-reflectable applique cette règle ; **seule** exception = l'adaptateur `ReflectableCodec` (E2-6/E7), à allowlister par chemin. Le contrôle codegen matérialise « modèle = source unique de vérité » (pas de modèle annoté orphelin).
  [Source: architecture.md#AD-3 ; CLAUDE.md#Key-Don'ts ; epics.md#E1 (Story E1-3)]
- **AD-10 (évolution additive & désérialisation défensive)** — le **gate de rétro-compat de sérialisation** (E2-10) est **rattaché au merge en E1-3** : ici on câble le **slot** CI, E2-10 fournit la suite (documents historiques/tronqués/champs inconnus ne cassent jamais le parent).
  [Source: architecture.md#AD-10 ; epics.md#E2 (Story E2-10) « rattaché à E1-3 »]
- **AD-12 (zéro secret)** — le scan de secrets fait échouer tout commit d'une clé/token ; couvre la forme `AIza…` (clé Maps historiquement fuitée, E1-5) et `badCertificateCallback => true`. Le scan **détecte** ; la **révocation** relève d'E1-5.
  [Source: architecture.md#AD-12 ; epics.md#E1 (Story E1-5)]
- **AD-1 (dépendances acycliques)** — le gate d'acyclicité (`graph_proof.py` durci) garde le cœur puits (out-degree 0) et le graphe acyclique, y compris sur les arêtes déclarées en `dev_dependencies:`/`dependency_overrides:` (angle mort L-3).
  [Source: architecture.md#AD-1 ; architecture.md#Invariants-&-Rules ; code-review-e1-2.md#L-3]
- **AD-15 / AD-2** — ne rien importer de gestionnaire d'état dans `zcrud_core` ; sans objet direct ici, mais la baseline lint ne doit pas contraindre à ajouter un manager. Ne pas tirer Flutter dans un package pur-Dart via `analysis_options`.
  [Source: architecture.md#AD-15]
- **Ordre codegen → analyze → test** — la CI régénère le code **avant** analyze/test (le généré est gitignoré et recréé après clone/pull).
  [Source: CLAUDE.md#Build-&-Development-Commands ; CLAUDE.md#Vérif-verte]

### Dette portée d'E1-1/E1-2 (rattachement explicite au périmètre)

- **M-1 (code-review E1-1, MEDIUM reporté vers E1-3)** — double source de vérité des scripts melos. Le contournement melos ≥ 7 + pub workspaces fait autorité au **root `pubspec.yaml`** (bloc `melos:`) ; `melos.yaml` en garde une **copie ignorée**. Les deux fichiers portent déjà un avertissement renvoyant à ce gate. **Cette story livre le garde-fou CI anti-divergence (AC 8).** Toute évolution de script se fait dans le root `pubspec.yaml` et est répliquée dans `melos.yaml`.
  [Source: code-review-e1-1.md#M-1 ; pubspec.yaml (bloc melos:) ; melos.yaml (bloc scripts:)]
- **L-3 (code-review E1-2, LOW reporté vers E1-3)** — `graph_proof.py` n'inspecte que `dependencies:` (`scripts/dev/graph_proof.py:20`), angle mort sur `dev_dependencies:`/`dependency_overrides:` (usage naturel d'un build tool). **Cette story durcit le script et le branche en gate CI (AC 7).**
  [Source: code-review-e1-2.md#L-3 ; scripts/dev/graph_proof.py]

### Décision — baseline de lint (`analysis_options` partagé)

- **Choix par défaut recommandé :** baseline **pur-Dart portable** — `include: package:lints/recommended.yaml` **ou** `package:flutter_lints/flutter.yaml` selon la nature du package. Contrainte forte : les packages sont **pur-Dart** aujourd'hui (aucun `flutter: sdk: flutter`), donc une baseline racine tirant `flutter_lints` **casserait `dart analyze`** sur les packages sans Flutter. **Recommandation :** baseline racine minimale **sans dépendance de package** (règles inline + `analyzer.exclude`), OU baseline `lints` (pur-Dart) référencée par `include:` relatif. Éviter d'imposer `flutter_lints` globalement tant que les packages restent pur-Dart. **À trancher par le dev** (cf. §Ambiguïtés) — mais **ne pas régresser** `melos run analyze` (14/14 RC=0).
- Exclure impérativement du lint : `**/*.g.dart`, `**/*.freezed.dart`, et le répertoire de **fixtures CI**.
  [Source: architecture.md#Stack (analyzer/json_serializable) ; CLAUDE.md#gitignore-codegen]

### Décision — mécanisme des gates (script Dart vs plugin analyzer vs grep CI)

- **Historique probant :** les code-reviews E1-1/E1-2 ont **répétément** pris en défaut des recettes **shell/awk/grep** (regex SDK `..3.12.2`, `awk gsub` vidant les lignes, motif `library ` vs `library;`). **Signal fort : préférer des gates en Dart** (`scripts/ci/*.dart`), **testables unitairement** et cross-plateforme, plutôt que des `grep` fragiles enfouis dans le YAML CI.
- **Recommandation retenue :** gates anti-reflectable, contrôle codegen, anti-divergence melos = **scripts Dart** sous `scripts/ci/`, chacun `exit(0/1)`, invoqués par `melos run verify` **et** par la CI. Gate d'acyclicité = **`graph_proof.py`** (déjà éprouvé, durci pour L-3) — mixité Python/Dart assumée et documentée. Scan de secrets = outil dédié en CI + repli local (§suivant).
- Chaque gate écrit une sortie déterministe (comme `graph_proof.py`) pour faciliter le débogage et la preuve fixture.
  [Source: code-review-e1-1.md ; code-review-e1-2.md (recettes shell buggées) ; scripts/dev/graph_proof.py (patron de gate déterministe)]

### Décision — scan de secrets (outil)

- **À trancher (cf. §Ambiguïtés).** Options : (a) **gitleaks** (GitHub Action, référence de facto, config `.gitleaks.toml`) ; (b) **trufflehog** ; (c) **script Dart/regex** maison. **Recommandation :** **gitleaks** comme autorité CI **+ un repli local léger** (script Dart regex ciblant les formes connues : `AIza[0-9A-Za-z_\-]{35}`, `AKIA[0-9A-Z]{16}`, `-----BEGIN … PRIVATE KEY-----`, `badCertificateCallback\s*=>\s*true`) exécuté par `melos run verify` pour reproductibilité hors CI. Exclure `.git/`, `*.g.dart`, la story et les **définitions de motifs** (auto-exclusion pour éviter l'auto-détection). La fixture prouve l'échec sur une clé factice.
  [Source: architecture.md#AD-12 ; epics.md#E1-5 (clé Maps fuitée)]

### Décision — contrôle codegen sans modèles réels

- À E1-3, **aucun** `@ZcrudModel` n'existe (annotations = E2-4, générateur = E2-5). Le gate doit donc : (1) être **correct par construction** (0 modèle ⇒ 0 orphelin ⇒ passe) ; (2) être **prouvé** par une **fixture** simulant « annoté sans `.g.dart` » (mini-dossier hors workspace, détection par motif d'annotation + absence du `part *.g.dart`, sans exiger le vrai générateur). Le gate final (post-E2-5) vérifiera aussi que `melos run generate` puis `git diff` sur le généré est **vide** (généré à jour). Convention d'annotation cible à confirmer avec E2-4 : `@ZcrudModel` sur la classe, `part '<file>.g.dart';`.
  [Source: epics.md#E2 (Stories E2-4, E2-5) ; architecture.md#AD-3 ; CLAUDE.md#gitignore-codegen]

### Stack / toolchain (rappel)

| Élément | Contrainte | Rôle en E1-3 |
| --- | --- | --- |
| Dart SDK | `^3.12.2` | runner CI + local (3.12.2 en place) |
| melos | `^7.0.0` | orchestration scripts/gates |
| Flutter | présent localement | runner CI si un package tire Flutter (aucun aujourd'hui) — setup pour pérennité (E3 tirera Flutter) |
| analyzer / lints | via `analysis_options` | baseline partagée |
| build_runner / source_gen | `^2.4.x` | ciblé par `generate` (aucun package aujourd'hui) |

[Source: architecture.md#Stack]

### Project Structure Notes

- Arbo cible après E1-3 :
  ```text
  analysis_options.yaml               # baseline lint partagée (NEW)
  .github/workflows/<ci>.yml          # pipeline codegen→analyze→test→gates (NEW)
  scripts/
    dev/graph_proof.py                # DURCI (L-3 : + dev_dependencies/overrides)
    ci/
      <anti_reflectable>.dart         # gate (NEW)
      <secret_scan>.dart              # repli local du scan (NEW) + gitleaks en CI
      <codegen_check>.dart            # gate (NEW)
      <melos_divergence>.dart         # gate M-1 (NEW)
      fixtures/                       # fixtures de violation, HORS workspace (NEW)
  packages/<pkg>/analysis_options.yaml # include baseline racine (NEW ×14)
  pubspec.yaml (bloc melos:)          # scripts durcis (source de vérité) + script verify
  melos.yaml (bloc scripts:)          # copie identique (M-1)
  ```
- **Variance assumée :** `scripts/ci/fixtures/` **ne fait pas partie du workspace** (`workspace:` inchangé, `packages: [packages/**]` de melos ne l'inclut pas) et est **exclu** de l'analyse (`analyzer.exclude`) et du scan de secrets croisé. Ne pas l'ajouter à `workspace:`.
- **Conflit à surveiller :** un `include:` `analysis_options` qui tirerait `flutter_lints` casserait l'analyse pure-Dart. Rester portable (cf. §Décision lints).
- **`.github/agents/` existe déjà** (fichiers BMAD) : ne pas y toucher ; le workflow va sous `.github/workflows/`.

### Ambiguïtés à trancher par le dev (documenter le choix dans Completion Notes)

1. **Outil de scan de secrets** : gitleaks (recommandé, autorité CI) vs trufflehog vs script Dart seul. Recommandation : gitleaks + repli Dart local.
2. **Mécanisme de lint custom anti-reflectable** : script Dart maison (recommandé, testable) vs plugin `custom_lint`/`analyzer` plugin (plus lourd, différable) vs grep CI (déconseillé — historique de fragilité). Recommandation : script Dart.
3. **Baseline lint** : `lints` (pur-Dart) vs `flutter_lints` vs règles inline sans dépendance de package. Contrainte : ne pas casser l'analyse pure-Dart ni tirer Flutter globalement.
4. **Chemin allowlist `ReflectableCodec`** : réserver un chemin conventionnel (ex. `packages/zcrud_core/lib/src/data/codecs/reflectable_codec.dart` ou le package d'adaptateur cible) même s'il n'existe pas encore (créé en E2-6/E7) ; documenter pour cohérence future.
5. **Runner CI** : `dart-lang/setup-dart` (suffit aujourd'hui, tout pur-Dart) vs `flutter-action` (pérennité E3+). Recommandation : Flutter pour éviter une migration ultérieure, tant que Dart résolu = `^3.12.2`.
6. **Slot E2-10** : convention de branchement (tag de test `@Tags(['serialization-compat'])` exécuté par un step dédié, ou script `melos run verify:serialization` no-op aujourd'hui). Choisir une convention stable qu'E2-10 remplira sans toucher au workflow.

### Testing standards (Stratégie de tests)

Story d'outillage : la preuve d'acceptation combine **commandes build/RC** et **fixtures de violation par gate**. Aucun test widget/unitaire de domaine (→ E2+). Les gates en Dart **peuvent** porter un `*_test.dart` minimal validant leur logique (recommandé pour la robustesse, cf. historique des recettes shell buggées).

**Preuves à rejouer et consigner (RC réels) :**

1. **Baseline lint (AC 1)** — `melos run analyze` RC=0 (14) ; `dart analyze` par package RC=0. Vérifier `analyzer.exclude` couvre `*.g.dart`/fixtures.
2. **Scripts melos (AC 2)** — `melos run generate|analyze|test|verify` RC=0 (no-op propre où attendu).
3. **Gate anti-reflectable (AC 4, 10)** :
   - arbre réel → gate **exit=0** ;
   - fixture `import 'package:reflectable/reflectable.dart';` (hors allowlist) → gate **exit≠0** ;
   - même fichier **dans** le chemin allowlist → **exit=0** (exception AD-3 respectée).
4. **Gate scan de secrets (AC 5, 10)** :
   - arbre réel → **exit=0** ;
   - fixture `const k = 'AIza<35 chars factices>';` → **exit≠0** ;
   - vérifier que les motifs de définition et les autres fixtures ne déclenchent pas de faux positif.
5. **Gate contrôle codegen (AC 6, 10)** :
   - arbre réel (0 modèle annoté) → **exit=0** ;
   - fixture « `@ZcrudModel` sans `.g.dart` » → **exit≠0** ;
   - (post-E2-5, hors story) `generate` puis `git diff` généré vide.
6. **Gate acyclicité durci (AC 7, 10)** :
   - `python3 scripts/dev/graph_proof.py` sur l'arbre réel → **RC=0**, `ACYCLIQUE OK`, `CORE OUT=0 OK`, 17 arêtes ;
   - fixture : pubspec avec arête `zcrud_*` sous `dev_dependencies:` créant un cycle → **RC≠0** (prouve que le bloc est désormais lu) ;
   - fixture : arête `zcrud_*` en `dependency_overrides:` détectée.
7. **Gate anti-divergence melos (AC 8, 10)** :
   - arbre réel (blocs identiques) → **exit=0** ;
   - divergence injectée (copie de travail) → **exit≠0** ; restaurer.
8. **Workflow (AC 3, 9)** — relecture du YAML : ordre codegen→analyze→test→gates→slot rétro-compat ; triggers `push`/`pull_request` ; slot E2-10 présent et documenté. (Exécution réelle du workflow = via `act` optionnel ou validation locale des mêmes commandes `melos run verify`.)
9. **Non-régression (AC 11)** — `dart pub get`/`melos bootstrap` RC=0 ; `melos list`=14 ; 1 lockfile racine, 0 par-package ; SDK 14/14 ; `resolution: workspace` 14/14 ; `graph_proof.py` 17 arêtes inchangées ; `.gitignore` codegen intact ; aucun `*.g.dart` committé.

**Definition of green :** AC 1–11 satisfaits ; les 5 gates AC 4–8 prouvés « exit=0 réel / exit≠0 fixture » ; workflow ordonné codegen→analyze→test→gates→slot E2-10 ; non-régression E1-1/E1-2 verte ; M-1 et L-3 clos.

### References

- [Source: epics.md#E1 (Story E1-3)] — AC : `analysis_options` partagé ; scripts melos (analyze/test/build_runner) ; CI GitHub Actions ; gate anti-`reflectable` (lint custom) ; scan de secrets ; contrôle codegen. Couvre SM-6.
- [Source: architecture.md#AD-3] — reflectable banni (sauf `ReflectableCodec` DODLP) ; freezed non imposé ; type non enregistré → throw.
- [Source: architecture.md#AD-10] — évolution additive & désérialisation défensive ; gate rétro-compat sérialisation.
- [Source: architecture.md#AD-12] — zéro secret ; `badCertificateCallback => true` interdit.
- [Source: architecture.md#AD-1 ; architecture.md#Invariants-&-Rules] — graphe acyclique ; cœur puits.
- [Source: architecture.md#Stack] — Dart `^3.12.2`, melos `^7.0.0`, analyzer/lints, build_runner `^2.4.x`.
- [Source: epics.md#E2 (Story E2-10)] — suite CI de désérialisation défensive, « fait partie du gate de merge (rattaché à E1-3) ».
- [Source: epics.md#E1 (Story E1-5)] — clé Google Maps fuitée ; le scan détecte la forme `AIza…`, la révocation est E1-5.
- [Source: code-review-e1-1.md#M-1] — garde-fou CI anti-divergence des blocs de scripts melos.
- [Source: code-review-e1-2.md#L-3] — durcir `graph_proof.py` (`dev_dependencies`/`dependency_overrides`) + gate CI.
- [Source: pubspec.yaml (bloc melos:) ; melos.yaml (bloc scripts:)] — source de vérité des scripts + copie ignorée.
- [Source: scripts/dev/graph_proof.py] — patron de gate déterministe (Kahn + assertion out-degree) à durcir.
- [Source: CLAUDE.md#Build-&-Development-Commands ; CLAUDE.md#Key-Don'ts ; CLAUDE.md#Gates-CI] — ordre codegen→analyze→test ; interdits ; gates E1-3/E2-10.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill invoqué via le tool `Skill`).

### Debug Log References

- Deux faux positifs détectés et corrigés en cours de dev :
  1. `gate:codegen` déclenché par `@ZcrudModel` mentionné en doc-comment (`/// ... `@ZcrudModel` ...`) du barrel `zcrud_annotations` → regex durcie en application réelle (`^\s*@ZcrudModel`, multiline).
  2. `gate:secrets` déclenché par un commentaire du harnais `prove_gates.dart` contenant le motif `badCertificateCallback => true` → auto-exclusion du harnais + commentaire reformulé.
- `melos run generate`/`test` levaient `NoPackageFoundScriptException` (RC=0 mais bruyant) quand aucun package ne matche le filtre → reformulés en `run: melos exec --depends-on/--dir-exists -- …` = no-op **propre** (0 exception, RC=0).

### Remédiation code-review E1-3 (2026-07-09, passe post-review)

Correction des findings de `code-review-e1-3.md` (1 HIGH, 3 MEDIUM + 2 LOW robustesse), tous reproduits par le reviewer, prouvés par fixtures aux **formes RÉELLES** :

- **H-1 (HIGH, clos)** — `scripts/ci/gate_secret_scan.dart:29→33` : l'ancien motif `badCertificateCallback\s*=>\s*true` ne matchait que le littéral impossible. Nouveau motif couvrant la **forme d'affectation réelle** Dart : `badCertificateCallback\s*(=>\s*true|=\s*\([^)]*\)\s*(=>\s*true|\{\s*return\s+true))` (affectation `= (cert, host, port) => true`, corps `= (...) { return true; }`, et forme directe `=> true`). Fixture `prove_gates.dart` remplacée par la forme d'affectation réelle + variante corps-bloc. Repli local reconfirmé : `client.badCertificateCallback = (X509Certificate…) => true;` → **RC=1**.
- **M-1 (MEDIUM, clos)** — `scripts/ci/gate_reflectable.dart:19-22` : allowlist basename-only remplacée par un **chemin conventionnel scopé** au binding DODLP (`zcrud_get/lib/src/data/codecs/reflectable_codec.dart`) ; `zcrud_core` (et tout package listé dans `_neverExemptPackages`) n'est **jamais** exempté quel que soit le nom de fichier. Fixture : `packages/zcrud_core/…/reflectable_codec.dart` important reflectable → **REJETÉ (RC=1)** ; chemin scopé DODLP → toléré (RC=0).
- **M-2 (MEDIUM, clos)** — `scripts/ci/gate_secret_scan.dart:33` : suppression de l'allowlist d'extensions figée ; le repli scanne désormais **tous les fichiers texte** (saut défensif des binaires par détection d'octet NUL, exclusions `.git`/`.dart_tool`/`build`/caches/fixtures conservées, prose Markdown `.md`/`.markdown` hors périmètre). Fixtures : `AIza…` dans `.txt` **et** dans un fichier **sans extension** → **REJETÉ (RC=1)**. Non-régression : arbre réel toujours `gate:secrets OK` (aucun secret dans les fichiers texte hors-md).
- **M-3 (MEDIUM, clos)** — `scripts/ci/gate_reflectable.dart:46` : scan étendu de `/lib/` à `lib/ + bin/ + tool/ + test/ + example/` des packages moteur. Fixture **éphémère dans l'arbre réel** `packages/zcrud_core/bin/…` (le filtre de répertoire ne s'active qu'avec le root réel `packages`) → **REJETÉ (RC=1)**, nettoyée inconditionnellement dans le `finally`.
- **L-1 (LOW, clos — trivial)** — `scripts/ci/gate_codegen.dart:19` : regex durcie pour capter l'annotation **aliasée par préfixe d'import** `@z.ZcrudModel` : `^\s*@(?:[A-Za-z_][A-Za-z0-9_]*\.)?ZcrudModel\b`. Fixture aliasée sans `.g.dart` → RC=1. (La clause AC 6 « `.g.dart` obsolète via `git diff` » reste **non implémentée à dessein** : incohérente avec `.g.dart` gitignoré — à reclarifier en E2-5, cf. note du reviewer.)
- **L-2 (LOW, clos — trivial)** — `scripts/dev/graph_proof.py` : l'out-degree du cœur ne compte plus que les arêtes **runtime** (`dependencies:`) — un futur `dev_dependencies`/`dependency_overrides` légitime ne déclenche plus un faux `CORE OUT>0` (le cycle reste fatal quel que soit le bloc). Garde-fou « scanner a trouvé des packages » basé sur `len(pkgs)>0` (au lieu de `len(edges)>0`, qui cassait sur un arbre sans arête). Non-régression : **17 arêtes, CORE OUT=0, 14 nœuds, ACYCLIQUE OK, RC=0**.
- **L-3 / L-4 (informational)** : L-3 (wiring `GITHUB_TOKEN` de l'action gitleaks) — non traité (config CI/secrets d'org, hors périmètre disque de cette passe, consigné). L-4 (arête `path:` renommée) — non exploitable (pub interdit un nom divergent), consigné.

**Preuve rejouée** : `dart run scripts/ci/prove_gates.dart` = **19 OK / 0 FAIL, RC=0** ; `melos run verify` **RC=0** ; `melos run analyze` **RC=0 (14/14)**. Aucune fixture laissée committée (fixtures temp + nettoyage `finally` de la fixture bin réelle vérifié).

### Completion Notes List

**Ambiguïtés tranchées (recommandations de la story appliquées) :**

1. **Scan de secrets** : gitleaks = autorité CI (`.gitleaks.toml`, `useDefault=true`, allowlist des fichiers de motifs/harnais/fixtures) **+ repli Dart local** `scripts/ci/gate_secret_scan.dart` (reproductible hors réseau, sert les fixtures).
2. **Anti-reflectable** : **script Dart** `scripts/ci/gate_reflectable.dart` (pas de grep shell), testable, avec allowlist `*/reflectable_codec.dart`.
3. **Baseline lint** : `package:lints/recommended.yaml` **pur-Dart**. `lints` déclaré une seule fois en `dev_dependencies` du root (package_config partagé sous pub workspaces ⇒ résolvable depuis chaque membre). Flutter NON tiré globalement. `include: ../../analysis_options.yaml` relatif par package. `dart analyze` reste vert 14/14.
4. **Allowlist ReflectableCodec** : reconnaissance par nom de fichier conventionnel réservé `*/reflectable_codec.dart` (l'adaptateur naît en E2-6/E7).
5. **Runner CI** : `subosito/flutter-action@v2` (pérennité E3+), `flutter-version: 3.44.4` fournissant Dart 3.12.2 (`^3.12.2`).
6. **Slot E2-10** : `scripts/ci/verify_serialization.dart` (script `verify:serialization`) auto-découvre les tests taggés `serialization-compat` dans chaque `packages/*/test/` ⇒ E2-10 branche sa suite **sans toucher au workflow**. No-op vert aujourd'hui.

**M-1 (clos)** : garde-fou CI anti-divergence `scripts/ci/gate_melos_divergence.dart` (comparaison sémantique canonicalisée des deux blocs `scripts:`). Preuve : blocs identiques → exit=0 ; divergence injectée (copie) → exit≠0.

**L-3 (clos)** : `scripts/dev/graph_proof.py` durci pour lire `dependencies:` + `dev_dependencies:` + `dependency_overrides:` (arêtes dédupliquées). Non-régression : **17 arêtes**, `ACYCLIQUE OK`, `CORE OUT=0 OK`, RC=0. Preuve L-3 : cycle via `dev_dependencies:` → exit≠0 ; via `dependency_overrides:` → exit≠0.

**Preuves fixtures (RC réel/violation)** — `dart run scripts/ci/prove_gates.dart` = **19 OK, 0 FAIL** (post-remédiation code-review) :

| Gate | Arbre réel | Fixture violation (formes réelles) |
|------|-----------|-------------------|
| reflectable (AD-3) | exit=0 | exit=1 (import hors allowlist) ; allowlist **scopée** `zcrud_get/lib/src/data/codecs/reflectable_codec.dart` → exit=0 ; **cœur** `zcrud_core/…/reflectable_codec.dart` → exit=1 (M-1) ; **bin/** d'un package moteur → exit=1 (M-3) |
| secrets (AD-12) | exit=0 | exit=1 (AIza factice `.dart`) ; exit=1 (**affectation** `badCertificateCallback = (…) => true`, H-1) ; exit=1 (corps `= (…) { return true; }`, H-1) ; exit=1 (AIza dans `.txt`, M-2) ; exit=1 (AIza sans extension, M-2) |
| codegen (AD-3) | exit=0 | exit=1 (`@ZcrudModel` sans `.g.dart`) ; exit=1 (`@z.ZcrudModel` **aliasé** sans `.g.dart`, L-1) |
| melos M-1 | exit=0 | exit=1 (divergence injectée) |
| graph AD-1 (L-3) | exit=0 (17 arêtes, CORE OUT=0 runtime) | exit=1 (cycle dev_deps) ; exit=1 (cycle overrides) |

**Contrainte fixtures** : aucune fixture n'est committée à l'état de violation — `prove_gates.dart` crée des fixtures **éphémères** (temp dirs) créées → gate exécuté → asserties → nettoyées. Reproductible à volonté, inerte au repos.

**Vérif verte (RC exacts rejoués sur disque)** :
- `dart pub get` RC=0 ; `melos list` = 14 ; lockfile unique `./pubspec.lock` ; SDK `^3.12.2` 14/14 ; `resolution: workspace` 14/14 ; 14 barrels ; 14 `analysis_options.yaml` ; 0 `.g.dart` committé ; `.gitignore` codegen intact.
- `melos run generate` RC=0 (no-op propre) ; `melos run analyze` RC=0 (14) ; `melos run test` RC=0 (no-op propre) ; `melos run verify` RC=0 ; `python3 scripts/dev/graph_proof.py` RC=0 (17 arêtes).
- Workflow `.github/workflows/ci.yml` : YAML valide ; ordre codegen→analyze→test→gates→slot E2-10 vérifié ; `.gitleaks.toml` TOML valide.

**Écarts vs story** : aucun. Périmètre respecté (pas de code domaine/annotations/générateur ; slot E2-10 seulement ; pas de révocation Maps ; pas de dry-run E1-4 ; `sprint-status.yaml` non touché).

### File List

**Créés :**
- `analysis_options.yaml` (baseline lint partagée racine)
- `packages/<pkg>/analysis_options.yaml` × 14 (include de la baseline)
- `.github/workflows/ci.yml` (pipeline codegen→analyze→test→gates→slot E2-10)
- `.gitleaks.toml` (config/allowlist de l'autorité CE gitleaks)
- `scripts/ci/gate_reflectable.dart` (gate AD-3)
- `scripts/ci/gate_secret_scan.dart` (gate AD-12, repli local)
- `scripts/ci/gate_codegen.dart` (gate AD-3 codegen)
- `scripts/ci/gate_melos_divergence.dart` (gate M-1)
- `scripts/ci/verify_serialization.dart` (slot E2-10, AD-10)
- `scripts/ci/prove_gates.dart` (harnais de preuve fixtures, AC 10)

**Modifiés :**
- `pubspec.yaml` (dev_deps `lints`/`yaml` ; bloc `melos: scripts:` durci + scripts `gate:*`/`verify`/`verify:serialization`)
- `melos.yaml` (bloc `scripts:` répliqué à l'identique — M-1)
- `scripts/dev/graph_proof.py` (durci L-3 : dev_dependencies + dependency_overrides + argv ROOT + dédup)

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-07-09 | 0.1 | Implémentation E1-3 (SM-6) : baseline lint partagée, scripts melos durcis + `verify`, 5 gates CI (anti-reflectable AD-3, secrets AD-12, codegen AD-3, acyclicité AD-1 durcie L-3, anti-divergence melos M-1), workflow GitHub Actions ordonné + slot E2-10, preuves fixtures (13 OK/0 FAIL). Status → review. |
| 2026-07-09 | 0.2 | Remédiation code-review E1-3 : H-1 (badCertificateCallback forme d'affectation réelle), M-1 (allowlist reflectable scopée + cœur jamais exempté), M-2 (secrets scan tous fichiers texte hors binaires/prose), M-3 (scan reflectable bin/tool/test/example), L-1 (`@z.ZcrudModel` aliasé), L-2 (graph_proof out-degree runtime-only + garde `len(pkgs)`). Fixtures aux formes réelles → **19 OK/0 FAIL**. `verify`/`analyze` RC=0. Reste Status: review. |
