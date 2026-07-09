---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 1.4 : Gate de compatibilité de résolution de dépendances (FR-25)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du monorepo zcrud et futur intégrateur de `lex_douane`**,
je veux **un gate de compatibilité qui exécute un dry-run de résolution des dépendances lourdes d'intégration (flutter_quill + awesome_select + analyzer) aux versions cibles alignées sur `lex_douane`, dans un package de compat isolé (hors des 14 membres pur-Dart du workspace), avec les versions retenues documentées**,
afin que **la compatibilité de résolution soit vérifiée avant tout code d'intégration (E7/E8) — sans jamais polluer le graphe pur-Dart du workspace ni tirer Flutter dans les 14 packages — et que toute dérive de versions soit détectée en CI de façon déterministe.**

## Contexte & valeur

E1-1 (workspace melos + `resolution: workspace`), E1-2 (barrels + `src/` + arêtes AD-1 acycliques) et E1-3 (analysis_options partagé, scripts melos durcis, CI `codegen → analyze → test → gates`, 5 gates prouvés par fixture) sont **DONE**. Le workspace résout (14 membres pur-Dart, lockfile unique racine), tout compile, l'acyclicité est prouvée, et la CI GitHub Actions (`.github/workflows/ci.yml`) tourne avec Flutter disponible (`subosito/flutter-action@v2`, `flutter-version: 3.44.4`, fournissant Dart `^3.12.2`).

Cette story **ferme l'épic d'habilitation E1 sur le plan compatibilité** en matérialisant **FR-25** : *« Un développeur peut vérifier la compatibilité des versions avant intégration »* et *« Un dry-run de résolution (flutter_quill + awesome_select + analyzer) contre le workspace lex_douane réussit avant tout code d'intégration »*. Elle est référencée en aval par **E8-3** (« gate de compat OK (FR-25) ») et par **SM-3** (« ≥ 3 écrans admin migrés sans régression de résolution de dépendances »).

**Valeur d'intégrateur explicite** : avant d'écrire une seule ligne d'intégration DODLP (E7) ou lex_douane (E8), on prouve que les versions lourdes que zcrud imposera (Quill pour le rich-text E6, awesome_select pour les champs de sélection, analyzer pour le codegen E2-5) **coexistent** avec les contraintes du consommateur cible — au lieu de le découvrir tard, au moment de la PR d'intégration.

## Décision structurante : voie du dry-run + isolation Flutter/pur-Dart

**Constat d'environnement (vérifié sur disque) :**
- Le chemin de « workspace lex_douane » évoqué dans la Stack (`.../Niger/2018/02-data-extraction`) **n'existe pas** dans cet environnement.
- Le seul artefact `lex_douane` présent localement, `/home/zakarius/DEV/lex_douane_core/pubspec.yaml`, est un **package Dart CLI pur** (`name: lex_douane_core`, `sdk: ^3.10.4`, deps = `path`/`crypto`/`json_annotation`) — **il ne contient ni Flutter, ni flutter_quill, ni awesome_select, ni analyzer**. Ce n'est **pas** le « workspace lex_douane » (application Flutter, le plus récent) dont la Stack tire ses versions.
- Conclusion : **le workspace lex_douane réel n'est pas résoluble de façon fiable en CI** (absent de l'environnement et du runner GitHub).

**Voie retenue (défaut) — MANIFESTE DE CONTRAINTES documenté + dry-run isolé.**
Le gate matérialise un **package de compat isolé** qui **déclare** flutter_quill + awesome_select + analyzer **aux versions cibles de la Stack** (= versions alignées sur lex_douane), puis exécute un **dry-run de résolution** (`flutter pub get --dry-run` — car flutter_quill/awesome_select requièrent le SDK Flutter). Le succès du dry-run prouve que ce triplet **co-résout** sous Dart `^3.12.2` / Flutter cible. Les versions retenues sont **documentées** (manifeste + doc). C'est **déterministe**, **reproductible en CI** (Flutter y est déjà disponible) et **indépendant de la présence du workspace lex_douane**.

**Voie alternative (opportuniste, non bloquante) — dry-run contre le workspace lex_douane réel.**
Si un chemin de workspace lex_douane résoluble est fourni (variable d'env / paramètre), le gate peut **en plus** tenter un `flutter pub get --dry-run` (ou `--dependency-overrides` contre son lockfile) pour valider contre les contraintes réelles. **Cette voie est SKIP/informationnelle** quand le workspace est absent (cas par défaut en CI) : son absence **ne fait jamais échouer** le gate ; seule la voie « manifeste » est autorité de merge.

**Isolation Flutter vs pur-Dart (NON-NÉGOCIABLE).**
Les 14 membres du workspace sont **pur-Dart** (aucun `flutter: sdk: flutter`) ; `dart pub get` / `dart test` / `melos run analyze` doivent le rester (E1-1/E1-2/E1-3). **flutter_quill et awesome_select tirent Flutter** : les déclarer dans un membre du workspace **casserait** la résolution pur-Dart et le graphe AD-1.
→ Le package de compat vit **hors des 14 membres**, sous **`tool/compat_check/`** :
- **absent** du bloc `workspace:` du root `pubspec.yaml` (donc hors résolution partagée, lockfile propre) ;
- **hors** du glob `packages: [packages/**]` de `melos.yaml` (non ciblé par `melos run`) ;
- **hors** du scope de `scripts/dev/graph_proof.py` (qui n'itère que `packages/*/pubspec.yaml`) — donc AD-1 non impacté ;
- **exclu** de l'analyse racine (`analyzer.exclude` de `tool/compat_check/**` si nécessaire pour ne pas exiger Flutter à l'`analyze` pur-Dart).

## État réel en place (hérité, à ne PAS régresser)

- `pubspec.yaml` racine : `name: zcrud_workspace`, `workspace:` = **14 membres**, `sdk: ^3.12.2`, `dev_dependencies: melos ^7.0.0`, `lints ^5.0.0`, `yaml ^3.1.2`. Bloc `melos:` = **SOURCE DE VÉRITÉ** des scripts.
- `melos.yaml` : `name: zcrud`, `packages: [packages/**]`, copie `scripts:` **identique** (gate M-1 `gate:melos` interdit la divergence).
- Scripts melos existants : `generate`, `analyze`, `test`, `gate:graph`, `gate:melos`, `gate:reflectable`, `gate:secrets`, `gate:codegen`, `verify:serialization`, `verify` (enchaîne les 6 gates).
- `.github/workflows/ci.yml` : `codegen → analyze → test → gates (graph/melos/reflectable/secrets/gitleaks/codegen) → prove_gates → slot verify:serialization`. **Flutter disponible** dans le runner (subosito) → un `flutter pub get --dry-run` y est exécutable.
- `scripts/ci/` : `gate_codegen.dart`, `gate_melos_divergence.dart`, `gate_reflectable.dart`, `gate_secret_scan.dart`, `prove_gates.dart`, `verify_serialization.dart`. `scripts/dev/graph_proof.py` (scanne `packages/*/pubspec.yaml` uniquement).
- `.gitignore` : `*.g.dart`, `*.freezed.dart`, `.dart_tool/`, `.env*` ignorés ; `pubspec.lock` commenté (non ignoré par défaut).
- **Aucun** `tool/` à ce stade. **Aucune** dépendance Flutter nulle part dans le repo.
- Stack (autorité des versions, `architecture.md#Stack`) : Dart SDK `^3.12.2`, `flutter_quill ^11.5.x`, `json_serializable ^6.11.2`, `build_runner ^2.4.x` / `source_gen`, `analyzer` (implicite via build/source_gen, **non pinné explicitement dans la table**). **`awesome_select` n'est PAS listé dans la table Stack** (à sourcer — cf. §Ambiguïtés/Dev Notes).

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ Un **package de compat isolé** sous `tool/compat_check/` : `pubspec.yaml` propre (`sdk: flutter`, `environment.sdk: ^3.12.2`) déclarant **flutter_quill + awesome_select + analyzer** aux versions cibles alignées lex_douane/Stack. **Hors** des 14 membres, **hors** `packages/**`, **hors** `graph_proof.py`.
- ✅ Un **script de gate de compat** (Dart, ex. `scripts/ci/gate_compat_resolution.dart`, cohérent avec le pattern `scripts/ci/*.dart` existant) qui : lance le **dry-run** de résolution du package `tool/compat_check/` (`flutter pub get --dry-run`), **échoue (exit≠0)** si la résolution échoue (conflit de version), **passe (exit=0)** sinon ; et **tente** en plus, si un workspace lex_douane résoluble est fourni (env `LEX_WORKSPACE`/param), la voie opportuniste **sans faire échouer** le gate en son absence.
- ✅ **Documentation des versions retenues** : un manifeste/doc listant flutter_quill, awesome_select, analyzer avec la version **pinnée retenue**, sa **source** (Stack / lex_douane), et la **justification**. Renvoi depuis la Stack (`architecture.md`) le cas échéant, sinon doc dédiée sous `tool/compat_check/README.md` ou `docs/`.
- ✅ **Câblage CI** : une étape/job dédié dans `.github/workflows/ci.yml` exécutant le gate de compat (voie manifeste = **bloquante**), après les gates existants. La voie workspace réel reste **informationnelle**.
- ✅ **Script melos** `gate:compat` (ou intégré à `verify`) répliqué **à l'identique** dans les deux blocs (root `pubspec.yaml` **et** `melos.yaml`) pour rester conforme à **M-1** ; le gate M-1 le vérifie.
- ✅ **Fixture de preuve** « échoue sur violation, passe sinon » (cohérent avec le pattern E1-3) : une contrainte volontairement incompatible (ex. `analyzer` épinglé à une borne impossible) fait **échouer** le dry-run ; l'arbre courant **passe**. Fixture isolée, ne polluant ni le workspace ni les autres gates.
- ❌ **Pas** d'ajout de flutter_quill/awesome_select/analyzer à un **membre du workspace** (ni `zcrud_markdown`, ni autre) — ce sera fait dans E6 (Quill) / E2-5 (analyzer via generator) / E3 (select), chacun dans son package. Ici on **résout seulement**, on n'intègre pas.
- ❌ **Pas** de code d'intégration DODLP/lex_douane (→ E7/E8), pas de widgets, pas de codec.
- ❌ **Pas** de modification du scope de `graph_proof.py` (le compat vit hors `packages/`, aucun changement requis) — sauf ajout défensif d'exclusion si un scan futur l'exigeait (documenté sinon).
- ❌ **Ne PAS** ajouter `tool/compat_check/` au bloc `workspace:` ni au glob `packages/**`.
- ❌ **Ne PAS** toucher `sprint-status.yaml` (géré par l'orchestrateur).

## Acceptance Criteria

1. **Package de compat isolé (hors graphe pur-Dart).** Il existe `tool/compat_check/pubspec.yaml` déclarant **flutter_quill**, **awesome_select** et **analyzer** aux versions cibles (§AC 4), avec `environment.sdk: ^3.12.2` et le SDK Flutter. Ce package est **absent** du bloc `workspace:` du root `pubspec.yaml`, **absent** du glob `packages: [packages/**]` de `melos.yaml`, et **non vu** par `scripts/dev/graph_proof.py`. **Non-régression prouvée** : `dart pub get` racine reste RC=0 avec **un seul** `pubspec.lock` racine et **14** membres (`melos list` = 14), aucun membre ne gagne de dépendance Flutter, `melos run analyze` reste RC=0.

2. **Dry-run de résolution (voie manifeste, autorité).** Un gate exécute la résolution en **dry-run** du package `tool/compat_check/` (`flutter pub get --dry-run`, exécuté depuis `tool/compat_check/`) et **réussit** (exit=0) sur les versions retenues : le triplet flutter_quill + awesome_select + analyzer **co-résout** sous Dart `^3.12.2` / Flutter cible. La sortie de résolution (versions effectives) est **capturée/loggée** pour traçabilité. Le gate est **déterministe** et ne dépend **pas** de la présence d'un workspace lex_douane.

3. **Gate échoue sur incompatibilité (preuve par fixture).** Une **fixture** de contrainte volontairement incompatible (ex. `analyzer` borné à une version impossible à co-résoudre avec la version de flutter_quill retenue, ou deux bornes disjointes) fait **échouer** le dry-run (exit≠0) — prouvant que le gate détecte réellement un conflit de résolution. Sur l'arbre courant (contraintes cohérentes) le gate **passe** (exit=0). La fixture est **isolée** (n'altère pas durablement `tool/compat_check/pubspec.yaml`, ne pollue pas le workspace ni les autres gates, ne déclenche pas le scan de secrets).

4. **Versions retenues documentées + tracées à la source.** Un document (ex. `tool/compat_check/README.md` et/ou renvoi depuis `architecture.md#Stack`) liste, pour **chacune** des 3 dépendances, la **version pinnée retenue**, sa **source** (table Stack pour flutter_quill `^11.5.x` ; source explicite pour awesome_select et analyzer, **non pinnés dans la table Stack** — cf. §Ambiguïtés) et une **justification** (alignement lex_douane). Les cibles SDK/Flutter alignées lex_douane (**Dart `^3.12.2`**) sont **documentées** (FR-25, critère 2). Toute divergence entre la version pinnée et la Stack est **signalée** (commentaire), pas silencieuse.

5. **Voie workspace réel opportuniste et non bloquante.** Le gate **tente** une résolution complémentaire contre un workspace lex_douane **si et seulement si** un chemin résoluble est fourni (env `LEX_WORKSPACE` ou paramètre). En **son absence** (cas CI par défaut), cette voie est **SKIP** avec un message clair et **ne fait pas échouer** le gate. Si elle est activée et **échoue par indisponibilité** (workspace absent/illisible), le gate reste **vert** (informationnel) ; seul un **vrai conflit de résolution** détecté par la voie manifeste (AC 2/3) est bloquant. Le comportement des deux voies est documenté.

6. **Câblage CI (bloquant sur la voie manifeste).** `.github/workflows/ci.yml` comporte une **étape dédiée** exécutant le gate de compat, placée après les gates d'architecture existants, **verte** sur l'arbre courant. La voie manifeste y est **bloquante** (échec ⇒ merge bloqué) ; la voie workspace réel y est **informationnelle** (non fournie en CI par défaut ⇒ SKIP propre). L'ordre global `codegen → analyze → test → gates` de E1-3 est préservé (non-régression).

7. **Script melos `gate:compat` conforme M-1.** Un script melos (nom au choix, ex. `gate:compat`) lance le gate localement et est **répliqué à l'identique** dans le bloc `melos:` du root `pubspec.yaml` **et** dans `melos.yaml` (source de vérité = root). Le gate **M-1** (`gate:melos`) **passe** (aucune divergence introduite). Optionnellement le script est chaîné dans `verify`. `melos run gate:compat` (ou équivalent) est **exécutable** et RC=0 sur l'arbre courant quand Flutter est disponible ; si Flutter est absent localement, l'échec est **explicite et documenté** (dépendance toolchain, non un faux vert).

8. **Non-régression E1-1/E1-2/E1-3.** Après l'ajout : `dart pub get` / `melos bootstrap` RC=0, **un seul** `pubspec.lock` racine, `melos list` = **14**, `resolution: workspace` + `sdk: ^3.12.2` intacts, arêtes AD-1 inchangées (`gate:graph` OK, décompte d'arêtes inchangé — `tool/compat_check/` hors scope), `gate:melos`/`gate:reflectable`/`gate:secrets`/`gate:codegen`/`verify:serialization` **tous verts**, `.gitignore` codegen non régressé, aucun `*.g.dart`/`*.freezed.dart` committé. Aucun package pur-Dart ne tire Flutter.

## Tasks / Subtasks

- [x] **Task 1 — Sourcer et arrêter les versions cibles (AC: 4)**
  - [x] Extraire de `architecture.md#Stack` : `flutter_quill ^11.5.x`, Dart `^3.12.2`. Consigner. → `flutter_quill: ^11.5.0` (résout 11.5.1).
  - [x] Déterminer la version cible d'**awesome_select** (absente de la table Stack) : dernière stable publiée `^6.0.0` (résout 6.0.0), compatible flutter_quill ^11.5.x / Flutter cible ; source + justification documentées (README, divergence Stack signalée).
  - [x] Déterminer la contrainte **analyzer** (implicite via `build_runner ^2.4.x`/`source_gen`) : `^7.0.0` (résout 7.7.1), compatible source_gen/build_runner ; documenté.
  - [x] Rédiger le manifeste (versions + source + justification + cible Dart/Flutter) → `tool/compat_check/README.md` + commentaire du `pubspec.yaml`.
- [x] **Task 2 — Package de compat isolé (AC: 1)**
  - [x] Créé `tool/compat_check/pubspec.yaml` : `name: zcrud_compat_check`, `publish_to: none`, `environment: { sdk: ^3.12.2, flutter: ">=3.24.0" }`, `dependencies: { flutter: sdk, flutter_quill ^11.5.0, awesome_select ^6.0.0, analyzer ^7.0.0 }`. **PAS** de `resolution: workspace`.
  - [x] Isolation vérifiée : absent du `workspace:` racine, absent de `packages/**`, non listé par `graph_proof.py` (17 arêtes inchangées). Ajouté `tool/**` à `analyzer.exclude` racine (défensif).
  - [x] `dart pub get` racine RC=0 + `melos list`=14 + `melos run analyze` RC=0 → non-régression confirmée.
- [x] **Task 3 — Gate de compat + voie opportuniste (AC: 2, 5)**
  - [x] `scripts/ci/gate_compat_resolution.dart` : `flutter pub get --dry-run` dans `tool/compat_check` ; exit≠0 si résolution échoue ; versions résolues loggées.
  - [x] Voie opportuniste : `LEX_WORKSPACE` fourni **et** résoluble → dry-run complémentaire (OK/INFO) ; absent/illisible → **SKIP** propre, gate vert. Indisponibilité = informationnel, non bloquant.
  - [x] Toolchain Flutter absente détectée (exit=3, message explicite) — pas de faux vert.
- [x] **Task 4 — Fixture de preuve « échoue/passe » (AC: 3)**
  - [x] Fixture éphémère (`analyzer` borné `>=99.0.0 <100.0.0`) branchée dans `prove_gates.dart` : exit≠0 sur la violation, exit=0 sur l'arbre réel, + preuve du SKIP opportuniste. Isolée (temp dir), non committée en état d'échec.
- [x] **Task 5 — Câblage CI + script melos (AC: 6, 7)**
  - [x] Étape « Gate FR-25 — compat de résolution (voie manifeste, bloquant) » ajoutée dans `ci.yml` après le gate codegen, avant `prove_gates`.
  - [x] `gate:compat` ajouté à l'identique dans root `pubspec.yaml` **et** `melos.yaml` (M-1 vert, 11 scripts) ; chaîné dans `verify`. `gate:melos` OK.
- [x] **Task 6 — Non-régression globale (AC: 8)**
  - [x] `dart pub get` (1 lock racine, 14 membres), `melos run analyze` RC=0, `melos run generate` RC=0, `melos run test` RC=0, `melos run verify` RC=0 (tous gates verts, graph 17 arêtes inchangées), aucun membre pur-Dart ne tire Flutter, aucun `*.g.dart` committé.

## Dev Notes

### Contraintes d'architecture applicables
- **AD-1 (acyclicité + isolation `zcrud_core`)** : le compat vit **hors `packages/`** ⇒ n'entre pas dans le graphe ; `graph_proof.py` (scanne `packages/*/pubspec.yaml`) reste inchangé et son décompte d'arêtes ne bouge pas. Ne **jamais** ajouter flutter_quill/awesome_select à `zcrud_core` ni à aucun membre ici. [Source: architecture.md#Invariants, #Capability→Architecture Map (« Packaging & compat (FR-24, FR-25) → workspace melos → AD-1 »)]
- **AD-15 / pur-Dart du cœur** : les 14 membres restent pur-Dart et sans manager d'état ; flutter_quill (E6) et awesome_select (E3) seront intégrés **plus tard, dans leurs packages respectifs**, pas ici. [Source: architecture.md#Stack notes, CLAUDE.md]
- **M-1 (anti-divergence melos)** : tout nouveau script melos est répliqué à l'identique dans root `pubspec.yaml` **et** `melos.yaml`. [Source: e1-3 story, gate_melos_divergence.dart]
- **SM-5 (isolation des dépendances)** : cohérent — importer un package n'ajoute pas de deps lourdes ; ici on *résout hors workspace*, sans rien ajouter au graphe importable.

### FR-25 — critères d'acceptation source (à couvrir intégralement)
- « Un dry-run de résolution (flutter_quill + awesome_select + analyzer) contre le workspace lex_douane réussit avant tout code d'intégration. » → AC 2 (voie manifeste = substitut déterministe) + AC 5 (voie workspace réel opportuniste).
- « Les cibles SDK/Flutter sont alignées sur lex_douane (Dart `^3.12.2`) et documentées. » → AC 4.
[Source: prd.md#FR-25 (lignes 337-341)]

### Pourquoi la voie « manifeste » est le défaut (et non le workspace réel)
Le workspace lex_douane référencé par la Stack **n'est pas présent** dans cet environnement (le chemin `.../Niger/2018/02-data-extraction` n'existe pas ; `lex_douane_core` local = **CLI pur-Dart**, sans Flutter ni les 3 deps). Un gate de merge doit être **déterministe et hermétique** : il ne peut dépendre d'un workspace externe non versionné et non disponible sur le runner. Le **manifeste de contraintes** (versions pinnées de la Stack, résolues dans un package isolé) reproduit fidèlement l'intention de FR-25 tout en étant **rejouable en CI**. La voie workspace réel reste offerte, opportuniste et non bloquante, pour l'usage local d'un intégrateur qui *a* le workspace.

### Isolation Flutter — pièges à éviter
- Ne **pas** déclarer `resolution: workspace` dans `tool/compat_check/pubspec.yaml` (sinon il rejoint la résolution partagée et tire Flutter dans le lock racine).
- Ne **pas** l'ajouter au `workspace:` racine ni au glob `packages/**`.
- `flutter pub get --dry-run` (pas `dart pub get`) car flutter_quill/awesome_select dépendent du SDK Flutter. `analyzer` seul serait pur-Dart, mais le triplet impose Flutter.
- Exclure `tool/compat_check/**` de l'`analyze` racine si l'analyseur pur-Dart tente de le résoudre (`analyzer.exclude`).

### Testing standards
- Pattern de preuve **identique à E1-3** : un gate = un script `scripts/ci/*.dart` **prouvé par fixture** « exit=0 sur l'arbre réel / exit≠0 sur la violation ». Réutiliser l'esprit de `scripts/ci/prove_gates.dart` (fixtures éphémères, non committées dans la build normale).
- Vérif verte à rejouer avant `review` : `dart pub get` (1 lock, 14 membres) → `melos run analyze` RC=0 → `melos run test` RC=0 → `melos run verify` (gates existants verts) → **nouveau** gate de compat vert (voie manifeste) + fixture prouvant l'échec. [Source: CLAUDE.md « Vérif verte »]
- Le gate dépend de la **toolchain Flutter** ; documenter cette dépendance (AC 7) et s'assurer que la CI (subosito) la fournit.

### Ambiguïtés détectées (résolues par défaut, à confirmer si besoin)
1. **awesome_select absent de la table Stack** → version à sourcer/documenter (Task 1). Défaut : dernière stable compatible flutter_quill ^11.5.x / Flutter cible, **justifiée**. (Ex. `awesome_select ^6.x`, à vérifier au moment du dev.)
2. **analyzer non pinné explicitement** dans la table Stack (implicite via `build_runner ^2.4.x`/`source_gen`) → retenir une borne cohérente avec ces outils ; documenter.
3. **Divergence de SDK observée** : `lex_douane_core` local = `sdk: ^3.10.4`, alors que la Stack/PRD imposent **Dart `^3.12.2`** (aligné sur l'app lex_douane, pas sur ce CLI). **Autorité = architecture/PRD → `^3.12.2`.** Noté pour éviter toute confusion.
4. **Bloquant vs informationnel** : la voie manifeste est **bloquante** (déterministe) ; la voie workspace réel est **informationnelle** (dépend d'un artefact externe). Choix explicite (AC 5/6) — à confirmer si l'on veut la rendre bloquante quand le workspace est fourni.

### Project Structure Notes
- Nouveaux fichiers : `tool/compat_check/pubspec.yaml`, `tool/compat_check/README.md` (manifeste), `scripts/ci/gate_compat_resolution.dart`, éventuelle fixture sous `scripts/ci/fixtures/` ou `tool/compat_check/`.
- Fichiers modifiés : `.github/workflows/ci.yml` (étape gate), root `pubspec.yaml` + `melos.yaml` (script `gate:compat`, M-1), éventuellement `analysis_options.yaml` racine (`exclude` de `tool/compat_check/**`).
- **Aucune** modification des 14 `packages/*/pubspec.yaml`. **Aucune** modification de `graph_proof.py` (hors ajout défensif documenté).

### References
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#FR-25 (l.337-341), #SM-3 (l.380), #SM-5 (l.384)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#Stack (l.145-171), #Capability→Architecture Map (l.242), #AD-1/#AD-15]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E1 Story E1-4 (l.56), #E8-3 (l.132)]
- [Source: _bmad-output/implementation-artifacts/stories/e1-3-lint-analyse-build-runner-gates-ci.md (pattern gate + fixture + M-1)]
- [Source: pubspec.yaml (bloc workspace 14 membres + bloc melos scripts), melos.yaml, .github/workflows/ci.yml, scripts/dev/graph_proof.py, scripts/ci/*.dart]
- [Source: /home/zakarius/DEV/lex_douane_core/pubspec.yaml — constat : CLI pur-Dart, sdk ^3.10.4, pas de Flutter/quill/select/analyzer]
- [Source: CLAUDE.md — « Gate de compatibilité (dry-run vs workspace lex_douane, cf. FR-25/E1-4) », vérif verte, Key Don'ts]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Code, skill `bmad-dev-story`).

### Debug Log References

Vérifications rejouées réellement sur disque (Flutter 3.44.4 / Dart 3.12.2) :
- `flutter pub get --dry-run` (dans `tool/compat_check/`) → RC=0 ; versions résolues : **flutter_quill 11.5.1, awesome_select 6.0.0, analyzer 7.7.1**.
- `gate_compat_resolution.dart` : arbre propre RC=0 ; fixture analyzer `>=99.0.0` RC=1 (VIOLATION FR-25) ; `LEX_WORKSPACE` absent RC=0 (SKIP) ; `LEX_WORKSPACE` illisible RC=0 (INFO) ; `LEX_WORKSPACE` résoluble RC=0 (OK) ; toolchain Flutter absente RC=3 (erreur explicite).
- `prove_gates.dart` → **22 OK, 0 FAIL** (3 nouveaux checks compat: clean/fixture/opportuniste-skip).
- `dart pub get` racine RC=0, **1 seul** `pubspec.lock` racine, `melos list`=**14**.
- `gate:melos` (M-1) RC=0 — **11 scripts** identiques dans les 2 blocs (était 10).
- `graph_proof.py` : **17 arêtes**, CORE OUT=0, ACYCLIQUE, 14 nœuds (inchangé).
- `melos run analyze` RC=0, `melos run generate` RC=0, `melos run test` RC=0, `melos run verify` RC=0 (inclut désormais `gate:compat`).
- Aucun `*.g.dart` suivi ; aucun `sdk: flutter` dans `packages/` ; aucun lock parasite dans `tool/compat_check/`.

### Completion Notes List

- **Voie manifeste (autorité de merge, bloquante)** : le triplet flutter_quill+awesome_select+analyzer co-résout sous Dart ^3.12.2 / Flutter cible dans un package **isolé** `tool/compat_check/` — hors des 14 membres pur-Dart, hors `packages/**`, hors `graph_proof.py`, sans `resolution: workspace`. Aucune pollution du lockfile racine ni du graphe AD-1.
- **Voie workspace réel (opportuniste)** : pilotée par `LEX_WORKSPACE`. Absente en CI par défaut → SKIP propre ; une indisponibilité n'échoue jamais le gate. Seul un vrai conflit de la voie manifeste est bloquant.
- **awesome_select** absent de la table Stack → `^6.0.0` sourcé (dernière stable) et **divergence signalée** dans README + commentaire pubspec (à confirmer contre le workspace lex_douane réel via la voie opportuniste). **analyzer** non pinné dans la Stack → `^7.0.0` épinglé explicitement (compatible source_gen/build_runner).
- Toolchain Flutter requise par le gate → absence signalée **explicitement** (exit=3), jamais un faux vert (AC 7).
- Fixture « échoue/passe » branchée dans `prove_gates.dart` (temp dir éphémère, jamais committée en état d'échec).
- Câblage CI : étape dédiée dans `ci.yml` (bloquante, voie manifeste ; voie réelle informationnelle) + script melos `gate:compat` répliqué à l'identique (M-1) et chaîné dans `verify`.

### File List

Créés :
- `tool/compat_check/pubspec.yaml`
- `tool/compat_check/README.md`
- `scripts/ci/gate_compat_resolution.dart`

Modifiés :
- `pubspec.yaml` (bloc `melos.scripts` : ajout `gate:compat` + chaînage dans `verify`)
- `melos.yaml` (réplique identique M-1 : `gate:compat` + `verify`)
- `.github/workflows/ci.yml` (étape « Gate FR-25 — compat de résolution »)
- `scripts/ci/prove_gates.dart` (bloc de preuve compat : clean/fixture/opportuniste-skip)
- `analysis_options.yaml` (`analyzer.exclude` : `tool/**`)
