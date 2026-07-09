---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 1.2 : Squelettes de packages avec API/barrel

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du monorepo zcrud**,
je veux **doter chacun des 14 packages d'un barrel d'API public (`lib/<pkg>.dart`), d'une arborescence d'implémentation sous `lib/src/{domain,data,presentation}` adaptée à son rôle, et des dépendances inter-packages `zcrud_*` conformes au graphe acyclique AD-1**,
afin que **chaque package compile (`dart analyze` RC=0), que le graphe de dépendances déclaré soit prouvé acyclique avec `zcrud_core` sans aucune arête sortante ni dépendance lourde/gestionnaire d'état, et que les stories de cœur/feature (E2, E3, E4…) démarrent sur des packages structurés et importables les uns les autres.**

## Contexte & valeur

E1-1 a posé l'ossature de résolution : root `pubspec.yaml` en `resolution: workspace`, `melos.yaml`, et pour chaque package un `pubspec.yaml` **minimal** + un placeholder `lib/<pkg>.dart`. **La résolution passe déjà** (`melos bootstrap` RC=0, 14 membres, lockfile unique). E1-1 a **délibérément différé** à E1-2 : les barrels d'API réels, l'arbo `lib/src/{domain,data,presentation}`, les **arêtes inter-packages**, la **compilation effective** et la **preuve d'acyclicité** (cf. E1-1 §« Ambiguïté à trancher » et §« Ce qu'il ne faut PAS faire ici »).

**Frontière E1-1 / E1-2 (verrouillée, à respecter) :** **E1-1 = la résolution passe ; E1-2 = ça compile, l'API/barrel existe, et les arêtes du graphe AD-1 sont déclarées et prouvées acycliques.** Cette story matérialise le socle structurel sur lequel FR-24 (importation sélective, graphe acyclique documenté) repose : un consommateur pourra tirer `zcrud_core` seul, ou `zcrud_list` (+ `zcrud_core` transitif), sans jamais embarquer Firebase/Syncfusion/Quill/Maps par le cœur.

**Ce qui rendra la story vérifiable :** chaque package expose un barrel qui n'exporte que depuis `lib/src/` ; les 13 satellites déclarent `zcrud_core` ; `zcrud_generator` déclare `zcrud_annotations` ; `zcrud_core` ne déclare **aucune** dépendance `zcrud_*` ni lourde ni manager ; un extracteur de graphe prouve l'acyclicité ; `dart analyze` (par package) et `melos run analyze` (14 packages) sont RC=0 ; la résolution workspace (lockfile unique, `melos list` = 14) reste intacte.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ Barrels `lib/<pkg>.dart` réels (uniquement des `export 'src/…';`, zéro déclaration d'impl dans le barrel).
- ✅ Arbo `lib/src/{domain,data,presentation}` **adaptée au rôle** de chaque package (pas de triade imposée là où le rôle ne la justifie pas — voir tableau Dev Notes).
- ✅ Arêtes inter-packages **`zcrud_*` uniquement**, conformes au graphe AD-1 (backbone `→ zcrud_core` + `generator → annotations` + arêtes de composition optionnelles documentées).
- ✅ Placeholders **minimaux** par package (un symbole réel, préfixe `Z`, sans logique métier) suffisant pour que le barrel exporte ≥ 1 déclaration et que l'analyse passe.
- ❌ **Pas** de logique de domaine / moteur d'édition / codecs / ports réels (→ E2, E3, E4, E6…).
- ❌ **Pas** de dépendance lourde tierce (Firebase, Syncfusion, `flutter_quill`, Google/OSM Maps, Hive) ni de gestionnaire d'état (`flutter_riverpod`/`riverpod*`, `get`, `provider`) dans **aucun** pubspec — réservées à leurs feature-stories (E4/E5/E6/E9/E10/E11) et aux bindings (E2-9/E7/E8).
- ❌ **Pas** de gates CI / lint anti-`reflectable` / scan de secrets (→ E1-3).
- ❌ **Ne PAS** créer/ajouter `example/` au workspace (différé, cf. E1-1).
- ❌ **Ne PAS** toucher `sprint-status.yaml` (géré par l'orchestrateur).

## Acceptance Criteria

1. **Barrel d'API public par package (14/14).** Chaque `packages/<pkg>/lib/<pkg>.dart` est un **barrel** : il ne contient que des directives `export 'src/…';` (et éventuellement une directive `library;` + doc), **aucune** déclaration d'implémentation (classe/fonction/variable) définie directement dans le barrel. Chaque barrel exporte **au moins un symbole réel** défini sous `lib/src/`.

2. **Implémentation sous `lib/src/` (14/14).** Toute déclaration publique d'un package vit sous `packages/<pkg>/lib/src/`. L'arbo suit le mapping `lib/src/{domain,data,presentation}/` **selon le rôle du package** (cf. tableau Dev Notes) : un package domaine-only (ex. `zcrud_annotations`) n'est pas tenu de créer `presentation/`. Au minimum, chaque package a un fichier réel sous `lib/src/` que son barrel exporte.

3. **Backbone AD-1 — tout satellite dépend de `zcrud_core`.** Les **13** packages satellites (`zcrud_annotations`, `zcrud_generator`, `zcrud_markdown`, `zcrud_list`, `zcrud_mindmap`, `zcrud_flashcard`, `zcrud_firestore`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_riverpod`, `zcrud_get`, `zcrud_provider`) déclarent une dépendance sur `zcrud_core` sous `dependencies:` (résolue **par le workspace**, contrainte de version type `^0.0.1`, sans `path:` sauf nécessité — cf. Dev Notes). `zcrud_core` ne déclare **aucune** dépendance vers un package `zcrud_*`.

4. **Arêtes internes complémentaires conformes au graphe AD-1.** `zcrud_generator` déclare une dépendance sur `zcrud_annotations`. Les arêtes de **composition** du graphe AD-1 (`zcrud_mindmap → zcrud_markdown`, `zcrud_flashcard → zcrud_markdown`, `zcrud_flashcard → zcrud_export`) sont soit **déclarées** (conformes au graphe), soit **explicitement différées** à leur feature-story avec justification écrite dans les Completion Notes. **Aucune** arête déclarée ne contredit le graphe mermaid AD-1 (aucune arête entrante sur `zcrud_core` en sens inverse, aucune arête absente du graphe).

5. **`zcrud_core` isolé (AD-1 + AD-15).** `packages/zcrud_core/pubspec.yaml` ne contient **aucune** dépendance vers : `firebase_core`/`cloud_firestore`/toute `firebase*`, `syncfusion_*`, `flutter_quill`, `google_maps_flutter`/`flutter_osm_plugin`, `hive`, **ni** `flutter_riverpod`/`riverpod*`/`get`/`provider`. Vérifiable par `grep`.

6. **Aucune dépendance lourde tierce introduite (global).** À ce stade, **aucun** des 14 pubspecs n'ajoute de dépendance lourde tierce (Firebase, Syncfusion, `flutter_quill`, Maps, Hive) ni de gestionnaire d'état. Les seules nouvelles arêtes sont **inter-packages `zcrud_*`**. (Une dépendance `flutter` SDK n'est ajoutée que si le placeholder d'un package Flutter l'exige réellement — voir Dev Notes ; à défaut, rester pur-Dart.)

7. **Graphe déclaré acyclique et cœur à out-degree nul (AD-1).** Le graphe orienté construit à partir des sections `dependencies:` restreintes aux nœuds `zcrud_*` est **acyclique** (une détection de cycle / tri topologique réussit) **et** `zcrud_core` a un **out-degree = 0** sur les arêtes `zcrud_*`. La preuve est **reproductible** (script d'extraction + assertion fournis dans la Stratégie de tests).

8. **Chaque package compile (RC=0).** `dart analyze` exécuté **dans chaque** `packages/<pkg>/` retourne RC=0 sans erreur ni warning bloquant ; `melos run analyze` sur les 14 packages retourne **SUCCESS** (RC=0). Aucun `depend_on_referenced_packages` ni import non résolu.

9. **Résolution workspace préservée (non-régression E1-1).** Après ajout des arêtes : `dart pub get` racine RC=0, `melos bootstrap` RC=0, **un seul** `pubspec.lock` racine (aucun `pubspec.lock` par-package), `melos list` énumère **exactement 14** packages (liste canonique). La contrainte `sdk: ^3.12.2` (14/14) et la config melos (root `pubspec.yaml` + `melos.yaml`) restent intactes.

10. **Hygiène préservée.** Le `.gitignore` codegen (`*.g.dart`, `*.freezed.dart`) n'est pas régressé ; aucun `*.g.dart`/`*.freezed.dart` n'est committé (aucun modèle annoté à ce stade — codegen = E2).

## Tasks / Subtasks

- [x] **Task 1 — Barrels d'API + arbo `lib/src/` par package (AC: 1, 2)**
  - [x] Pour chacun des 14 packages, remplacer le placeholder `lib/<pkg>.dart` par un **barrel** ne contenant que des `export 'src/…';` (option : `library;` + doc de package). Zéro déclaration d'impl dans le barrel.
  - [x] Créer sous `lib/src/` l'arbo `{domain,data,presentation}` **adaptée au rôle** (cf. tableau Dev Notes), avec au moins un fichier réel exporté par le barrel.
  - [x] Y déposer un **placeholder minimal** (symbole préfixe `Z`, ex. un marqueur/constante de version d'API, sans logique métier ni dépendance lourde) pour que l'analyse ait quelque chose de concret et que le barrel exporte ≥ 1 déclaration. La substance réelle relève de E2+.
- [x] **Task 2 — Backbone AD-1 : tout satellite → `zcrud_core` (AC: 3, 6)**
  - [x] Ajouter `zcrud_core` sous `dependencies:` des **13** satellites, résolu par le workspace (contrainte `^0.0.1` ; **pas** de `path:` sauf si pub l'exige — documenter le choix retenu).
  - [x] Vérifier que `zcrud_core/pubspec.yaml` ne déclare **aucune** dépendance `zcrud_*`.
  - [x] Si un import réel de `zcrud_core` est ajouté dans un placeholder satellite, éviter le lint `depend_on_referenced_packages` (dépendance déclarée ⇔ import présent).
- [x] **Task 3 — Arêtes internes complémentaires (AC: 4)**
  - [x] Ajouter `zcrud_annotations` sous `dependencies:` de `zcrud_generator`.
  - [x] **Décider et consigner** : déclarer maintenant `zcrud_mindmap → zcrud_markdown`, `zcrud_flashcard → zcrud_markdown`, `zcrud_flashcard → zcrud_export` (conforme au graphe, tout interne, aucune dep lourde) **ou** les différer à leur feature-story. Toute arête déclarée **doit** figurer dans le graphe mermaid AD-1 ; tout report **doit** être justifié dans les Completion Notes.
- [x] **Task 4 — Isolation du cœur (AC: 5)**
  - [x] Confirmer par `grep` que `zcrud_core/pubspec.yaml` n'a ni Firebase/Syncfusion/Quill/Maps/Hive, ni `flutter_riverpod`/`riverpod*`/`get`/`provider`.
- [x] **Task 5 — Preuve d'acyclicité reproductible (AC: 7)**
  - [x] Fournir un extracteur de graphe (script shell/dart de la Stratégie de tests) qui lit les `dependencies:` `zcrud_*` de chaque pubspec, construit l'adjacence, détecte les cycles (DFS/tri topo) et vérifie `out-degree(zcrud_core) == 0`. Consigner la sortie.
- [x] **Task 6 — Vérification verte + non-régression (AC: 8, 9, 10)**
  - [x] `dart pub get` (racine) RC=0 ; `melos bootstrap` RC=0 ; confirmer lockfile unique et `melos list` = 14.
  - [x] `dart analyze` par package RC=0 ; `melos run analyze` RC=0 (SUCCESS sur 14).
  - [x] Vérifier `.gitignore` (codegen) non régressé ; aucun `*.g.dart`/`*.freezed.dart` committé.
  - [x] Rejouer la séquence complète de la section « Stratégie de tests » et consigner les RC réels.

## Dev Notes

### Contraintes d'architecture (NON-NÉGOCIABLES)

- **AD-1 (dépendances acycliques)** — Le cœur ne dépend de rien ; tout satellite pointe vers `zcrud_core` (et éventuellement un autre satellite déjà **en amont**) ; jamais l'inverse ; toute nouvelle arête préserve l'acyclicité. Mapping répertoires : `lib/src/{domain,data,presentation}/` ; API publique = `lib/<pkg>.dart` (barrel), impl sous `src/`.
  [Source: architecture.md#AD-1 ; architecture.md#Invariants-&-Rules (graphe mermaid)]
- **Graphe de dépendances canonique (mermaid AD-1)** — arêtes autorisées :
  ```text
  zcrud_annotations   -> zcrud_core
  zcrud_generator     -> zcrud_annotations,  zcrud_core        (dev/build tool)
  zcrud_markdown      -> zcrud_core
  zcrud_list          -> zcrud_core
  zcrud_mindmap       -> zcrud_core,          zcrud_markdown
  zcrud_flashcard     -> zcrud_core,          zcrud_markdown,   zcrud_export
  zcrud_firestore     -> zcrud_core
  zcrud_geo           -> zcrud_core
  zcrud_intl          -> zcrud_core
  zcrud_export        -> zcrud_core
  zcrud_riverpod      -> zcrud_core
  zcrud_get           -> zcrud_core
  zcrud_provider      -> zcrud_core
  zcrud_core          -> (rien)
  ```
  Toute arête déclarée dans un pubspec **doit** appartenir à cet ensemble. `zcrud_core` reste un puits (out-degree 0).
  [Source: architecture.md#Invariants-&-Rules]
- **AD-14 (pureté des couches)** — le `domain/` de `zcrud_core` est **Dart pur** (aucune dépendance Flutter/Firebase/Hive). `zcrud_core` **autorise** Flutter ailleurs (moteur d'édition = widgets), mais au stade squelette on ne tire Flutter que si un placeholder l'exige réellement. Préférer des placeholders **pur-Dart** partout où c'est possible pour garder `dart analyze` (sans Flutter) vert.
  [Source: architecture.md#AD-14]
- **AD-15 (multi-gestionnaire par bindings)** — `zcrud_core` n'importe **aucun** gestionnaire d'état. Les bindings (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`) sont des membres du workspace mais restent des **coquilles** : leurs deps managers (`flutter_riverpod`/`riverpod*`, `get`, `provider`) sont ajoutées à leur story dédiée (E2-9/E7/E8), **pas ici**. Ici ils ne déclarent que `zcrud_core`.
  [Source: architecture.md#AD-15]
- **AD-12 (zéro secret)** — ne rien introduire (sans objet direct ici).
  [Source: architecture.md#AD-12]

### Stack imposée (rappel — aucune version lourde ajoutée ici)

| Élément | Contrainte | Ajoutée en E1-2 ? |
| --- | --- | --- |
| Dart SDK | `^3.12.2` | déjà présent (E1-1), inchangé |
| melos | `^7.0.0` | déjà présent, inchangé |
| deps lourdes (Firebase/Syncfusion/Quill/Maps/Hive) | leurs feature-stories | ❌ non |
| managers (riverpod/get/provider) | bindings E2-9/E7/E8 | ❌ non |

[Source: architecture.md#Stack]

### Rôle → arbo `lib/src/` recommandée (adaptée, pas imposée)

> La triade `{domain,data,presentation}` n'est **pas** obligatoire pour tous : créer les sous-dossiers **pertinents au rôle**. Au minimum un fichier réel sous `lib/src/`. Placeholders `Z*` minimaux.

| Package | Rôle (CLAUDE.md / Seed) | Sous-dossiers `src/` pertinents | Barrel exporte |
| --- | --- | --- | --- |
| `zcrud_core` | domaine pur + moteur + ports + seams | `domain/`, `data/`, `presentation/` | ≥1 placeholder (ex. `domain/`) |
| `zcrud_annotations` | `@ZcrudModel/@ZcrudField/@ZcrudId` | `domain/` (annotations pur-Dart) | placeholder annotation |
| `zcrud_generator` | builder build_runner (dev tool) | `src/` (builder) | placeholder builder |
| `zcrud_markdown` | Quill + ZCodec + embeds | `domain/`, `presentation/` | placeholder codec/embed |
| `zcrud_list` | DynamicList (port dans core) | `presentation/` | placeholder renderer |
| `zcrud_mindmap` | ZMindmap + view | `domain/`, `presentation/` | placeholder |
| `zcrud_flashcard` | ZFlashcard + SRS | `domain/`, `data/`, `presentation/` | placeholder |
| `zcrud_firestore` | adapters Firestore/Hive | `data/` | placeholder adapter |
| `zcrud_geo` | champs géo | `domain/`, `presentation/` | placeholder |
| `zcrud_intl` | téléphone/pays/devise | `domain/`, `data/` | placeholder |
| `zcrud_export` | PDF/Excel | `data/`, `presentation/` | placeholder |
| `zcrud_riverpod` | binding Riverpod (coquille) | `presentation/` (binding) | placeholder binding |
| `zcrud_get` | binding GetX (coquille) | `presentation/` (binding) | placeholder binding |
| `zcrud_provider` | binding provider (coquille) | `presentation/` (binding) | placeholder binding |

[Source: CLAUDE.md#Structure-des-packages ; architecture.md#Structural-Seed]

### Dépendance inter-packages sous pub workspaces (décision technique)

- Sous `resolution: workspace` (pub natif ≥ Dart 3.5, melos 7), un package référence un **sibling** en l'ajoutant sous `dependencies:` par **nom + contrainte de version** (les packages sont en `version: 0.0.1`, donc `zcrud_core: ^0.0.1`). Pub le résout depuis le workspace — **pas besoin de `path:`**. Préférer cette forme (moins de couplage chemin, aligné pub workspaces).
- **Fallback** : si la résolution refuse la contrainte de version (ex. package sans `version:`), basculer sur `zcrud_core: {path: ../zcrud_core}` et **documenter** le choix dans les Completion Notes. Ne pas mélanger inutilement les deux styles.
- Rappel : sous pub workspaces un seul `pubspec.lock` racine ; ne pas réintroduire de lockfile par-package.

### Frontière E1-1 / E1-2 (héritée, à ne pas rejouer)

- E1-1 a livré : root workspace, `melos.yaml`, 14 pubspecs minimaux (`resolution: workspace`, `^3.12.2`), 14 placeholders `lib/<pkg>.dart`, lockfile unique, `.gitignore` codegen. **Ne pas** re-créer ni régresser cela.
- E1-2 livre : barrels réels, arbo `src/`, arêtes `zcrud_*`, compilation, preuve d'acyclicité.
- **Écart connu (melos 7.8 + pub workspaces)** : la config des scripts melos est lue depuis le **root `pubspec.yaml`** (bloc `melos:`), `melos.yaml` en conserve une copie ignorée (AC 3 de E1-1). Ne pas « corriger » cette duplication ici (garde-fou CI = E1-3, finding M-1). Toute évolution de script se fait dans le root `pubspec.yaml`.
  [Source: story E1-1 — Completion Notes]

### FR couvertes

- **FR-24** (importation sélective, graphe acyclique **documenté et effectif**) — matérialisé et **prouvé** ici (barrels + arêtes + acyclicité).
  [Source: prd.md#FR-24 ; epics.md#E1 (Story E1-2)]

### Ce qu'il ne faut PAS faire ici (rappel anti-empiètement)

- ❌ Logique de domaine / ports réels / moteur d'édition / codecs (→ E2, E3, E4, E6).
- ❌ Deps lourdes tierces ou managers d'état dans un pubspec (→ feature-stories / bindings).
- ❌ Gates CI / lint anti-`reflectable` / scan secrets (→ E1-3).
- ❌ `example/` (→ ultérieur). ❌ Toucher `sprint-status.yaml`.

### Project Structure Notes

- Arbo cible par package après E1-2 :
  ```text
  packages/<pkg>/
    pubspec.yaml            # + dependencies: zcrud_* (arêtes AD-1)
    lib/
      <pkg>.dart           # BARREL : export 'src/…'; uniquement
      src/
        {domain|data|presentation}/…   # impl (placeholders Z* minimaux)
  ```
- **Variance assumée** : `example/` reste hors workspace (cf. E1-1). Ne pas l'ajouter.
- **Conflit potentiel à surveiller** : un placeholder Flutter (ex. widget) tirerait `flutter` SDK et casserait `dart analyze` pur ; préférer pur-Dart au stade squelette (AC 6). Si un binding/presentation exige Flutter, ajouter `flutter: sdk: flutter` **uniquement** à ce package et le noter.

### Ambiguïtés à trancher par le dev (documentées)

1. **Arêtes de composition satellite→satellite** (`mm→md`, `fc→md`, `fc→exp`) : les déclarer maintenant (conforme au graphe, tout interne) **ou** les différer jusqu'à ce que le code consommateur existe (évite une dépendance déclarée-mais-inutilisée). Les deux sont acceptables tant que (a) toute arête déclarée est dans le graphe AD-1, (b) l'acyclicité + l'isolation du cœur tiennent, (c) le choix est justifié. Le **backbone `→ zcrud_core` + `generator → annotations` est, lui, obligatoire** ici.
2. **Import réel vs dépendance déclarée** : si un placeholder satellite n'importe pas encore `zcrud_core`, la dépendance déclarée reste valide (pas d'erreur d'analyse), mais veiller à ne pas déclencher un lint inverse le jour où l'import est ajouté. Le plus simple : un placeholder qui `import 'package:zcrud_core/zcrud_core.dart';` et référence son symbole, rendant l'arête « utilisée » et l'acyclicité tangible.
3. **Version vs path pour les siblings** : voir §« Dépendance inter-packages ». Choix par défaut = contrainte de version résolue par workspace.

### Testing standards

Story structurelle : pas de framework de test unitaire requis (les tests widget/unitaires démarrent en E2/E3). La preuve d'acceptation = commandes de build/RC + **script d'extraction de graphe** prouvant l'acyclicité et l'out-degree nul du cœur. Aucun `*_test.dart` attendu ici.

## Stratégie de tests (vérification d'acceptation)

Exécuter depuis la racine du dépôt et consigner chaque RC/sortie.

> ⚠️ **SUPERSEDED (code-review E1-2, findings L-1/L-2)** : les recettes shell d'exemple ci-dessous, si rejouées **verbatim**, produisent des **faux positifs** :
> - **§1** exclut `library ` (espace final) mais les barrels utilisent `library;` → fausse alerte « IMPL DANS BARREL » (les barrels sont réellement propres).
> - **§7** : le `awk` fait `gsub(/[: ].*/,"")` **avant** la dé-indentation → il vide les lignes indentées, 0 arête extraite, et `tsort` d'un graphe **vide** renvoie un faux `ACYCLIQUE OK`.
> - **§9** : `grep 'sdk: ..3.12.2'` ne matche pas `^3.12.2`.
> **Preuve d'acyclicité et out-degree cœur faisant AUTORITÉ : `python3 scripts/dev/graph_proof.py`** (RC=0, 17 arêtes, `ACYCLIQUE OK`, `CORE OUT=0 OK`), et pour §9 : `grep -c 'sdk: \^3.12.2' packages/*/pubspec.yaml`. Les blocs ci-dessous sont conservés à titre illustratif.

1. **Barrels propres (AC 1)** — aucun barrel ne définit d'impl (heuristique : le barrel ne contient que `library`/`export`/commentaires) :
   ```bash
   for f in packages/*/lib/*.dart; do
     grep -vE '^\s*(//|/\*|\*|library |export )|^\s*$' "$f" && echo "IMPL DANS BARREL: $f"
   done
   # attendu : aucune ligne "IMPL DANS BARREL"
   # et chaque barrel exporte >=1 fichier src :
   grep -rl "export 'src/" packages/*/lib/*.dart | wc -l   # attendu : 14
   ```
2. **Impl sous src/ (AC 2)** :
   ```bash
   for p in packages/*/; do find "$p/lib/src" -name '*.dart' | head -1 | grep -q . \
     || echo "PAS DE SRC: $p"; done   # attendu : aucun "PAS DE SRC"
   ```
3. **Backbone → zcrud_core (AC 3)** — 13 satellites déclarent zcrud_core, le cœur non :
   ```bash
   grep -l 'zcrud_core' packages/*/pubspec.yaml | grep -v 'zcrud_core/pubspec.yaml' | wc -l  # attendu : 13
   grep -E 'zcrud_(annotations|generator|markdown|list|mindmap|flashcard|firestore|geo|intl|export|riverpod|get|provider)' packages/zcrud_core/pubspec.yaml \
     && echo "VIOLATION: core a une arete zcrud_*" || echo "core OK (out-degree 0)"
   ```
4. **generator → annotations (AC 4)** :
   ```bash
   grep -q 'zcrud_annotations' packages/zcrud_generator/pubspec.yaml && echo OK
   ```
5. **Isolation du cœur (AC 5)** — aucune dep lourde ni manager :
   ```bash
   grep -Ei 'firebase|cloud_firestore|syncfusion|flutter_quill|google_maps|flutter_osm|hive|flutter_riverpod|riverpod|(^|[^_])get:|provider' \
     packages/zcrud_core/pubspec.yaml && echo "VIOLATION cœur" || echo "cœur isolé OK"
   ```
6. **Aucune dep lourde globale (AC 6)** :
   ```bash
   grep -Eli 'firebase|cloud_firestore|syncfusion|flutter_quill|google_maps|flutter_osm|hive' packages/*/pubspec.yaml \
     && echo "VIOLATION dep lourde" || echo "aucune dep lourde OK"
   ```
7. **Acyclicité + out-degree cœur (AC 7)** — extracteur de graphe reproductible (exemple ; le dev peut l'implémenter en dart) :
   ```bash
   # Construit "src dst" pour chaque arête zcrud_* puis détecte un cycle via tsort.
   edges() {
     for p in packages/*/; do
       s=$(basename "$p")
       awk '/^dependencies:/{d=1;next} /^[a-z]/{d=0} d && /zcrud_/{gsub(/[: ].*/,"");gsub(/^[ -]+/,"");print}' "$p/pubspec.yaml" \
         | while read dst; do [ -n "$dst" ] && echo "$dst $s"; done
     done
   }
   edges | tsort >/dev/null && echo "ACYCLIQUE OK" || echo "CYCLE DETECTE"
   # out-degree(core) == 0 : aucune arête source=zcrud_core
   edges | awk '$2=="zcrud_core"{c++} END{print (c?"CORE OUT>0 VIOLATION":"CORE OUT=0 OK")}'
   ```
   Critère : `ACYCLIQUE OK` **et** `CORE OUT=0 OK`. (tsort échoue/booucle sur un cycle.)
8. **Compilation par package (AC 8)** :
   ```bash
   for p in packages/*/; do (cd "$p" && dart analyze); done   # chaque RC=0, "No issues found!"
   melos run analyze                                           # attendu : SUCCESS (14)
   ```
9. **Résolution workspace préservée (AC 9)** :
   ```bash
   dart pub get                          # RC=0
   melos bootstrap                       # RC=0
   ls pubspec.lock && find packages -name pubspec.lock   # unique racine, 0 par-package
   melos list | wc -l                    # 14
   grep -rl 'sdk: ..3.12.2' packages/*/pubspec.yaml | wc -l   # 14
   ```
10. **Hygiène codegen (AC 10)** :
    ```bash
    grep -E '\*\.g\.dart|\*\.freezed\.dart' .gitignore    # présents
    git status --porcelain | grep -E '\.g\.dart|\.freezed\.dart' && echo "NE PAS COMMITTER" || echo "propre"
    ```

**Definition of green** : AC 1–2 sans violation ; backbone = 13 + cœur out-degree 0 ; `generator→annotations` présent ; cœur isolé + aucune dep lourde globale ; `ACYCLIQUE OK` + `CORE OUT=0 OK` ; `dart analyze` par package RC=0 et `melos run analyze` SUCCESS ; `dart pub get`/`melos bootstrap` RC=0, lockfile unique, `melos list`=14, SDK 14/14 ; `.gitignore` non régressé.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E1] — Story E1-2 : chaque package compile ; impl sous `src/` ; graphe déclaré acyclique (AD-1) ; `zcrud_core` sans Firebase/Syncfusion/Maps ni gestionnaire d'état. Couvre FR-24.
- [Source: architecture.md#AD-1] — direction de dépendance acyclique ; cœur puits ; barrel `lib/<pkg>.dart` + impl `lib/src/`.
- [Source: architecture.md#Invariants-&-Rules] — graphe mermaid des arêtes autorisées (ANN→CORE, GEN→ANN/CORE, MM→MD, FC→MD/EXP, …).
- [Source: architecture.md#AD-14] — pureté des couches (`domain/` pur-Dart), Flutter autorisé hors domaine dans le cœur.
- [Source: architecture.md#AD-15] — bindings coquilles ; cœur sans manager d'état ; deps managers différées.
- [Source: architecture.md#Stack ; architecture.md#Structural-Seed] — versions, arbo workspace, rôles des 14 packages.
- [Source: prd.md#FR-24] — importation sélective / graphe acyclique documenté.
- [Source: CLAUDE.md#Structure-des-packages ; CLAUDE.md#Key-Don'ts] — rôles des packages, conventions barrel/src, interdits (managers dans le cœur, deps lourdes, `ListView(children:)`, directionnalité…).
- [Source: story E1-1 (e1-1-workspace-melos-resolution-workspace.md)] — frontière E1-1/E1-2, écart melos 7.8/pub workspaces, `.gitignore` déjà conforme.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill invoqué via le tool `Skill`).

### Debug Log References

- Extracteur de graphe reproductible : `scripts/dev/graph_proof.py` (voir File List). Sortie consignée dans Completion Notes.
- **Bug dans le script d'exemple de la story (Stratégie de tests §7)** : l'`awk` fourni fait `gsub(/[: ].*/,"")` **avant** de retirer l'indentation `^[ -]+`. Comme les lignes de dépendance sont indentées (`  zcrud_core: ^0.0.1`), le premier `gsub` matche dès la première espace de tête et **vide toute la ligne** → 0 arête extraite, et `tsort` d'un graphe vide renvoie faussement « ACYCLIQUE OK ». Corrigé par un extracteur robuste (Python + variante shell utilisant `match($0,/zcrud_[a-z_]+/)`), qui isole d'abord le token `zcrud_*`. Idem §9 : le motif `sdk: ..3.12.2` (deux jokers) ne matche pas `sdk: ^3.12.2` (un seul caractère `^` avant `3`) → recompté avec `sdk: \^3\.12\.2` = 14/14.

### Completion Notes List

**Décision — 3 arêtes de composition satellite→satellite : DÉCLARÉES (pas différées).**
`zcrud_mindmap → zcrud_markdown`, `zcrud_flashcard → zcrud_markdown`, `zcrud_flashcard → zcrud_export` sont déclarées maintenant car (a) toutes trois figurent explicitement dans le graphe mermaid AD-1, (b) elles sont **tout-interne `zcrud_*`** sans aucune dépendance lourde tierce, (c) le placeholder consommateur importe et référence réellement le marqueur de la dépendance (`ZMarkdownApi.version`, `ZExportApi.version`), donc aucune dépendance déclarée-mais-inutilisée et aucun risque de lint inverse. L'acyclicité et l'isolation du cœur tiennent (prouvées ci-dessous).

**Décision — résolution des siblings par CONTRAINTE DE VERSION (`^0.0.1`), pas de `path:`.**
Sous `resolution: workspace`, `dart pub get` racine résout les 13 arêtes `zcrud_* : ^0.0.1` depuis les membres du workspace sans aucun `path:` (RC=0). Le fallback `path:` n'a pas été nécessaire.

**Décision — placeholders pur-Dart, aucun SDK Flutter ajouté.**
Chaque package expose un marqueur `Z<Pkg>Api` (classe `abstract final` avec `static const String version = '0.0.1'`). Les 13 satellites `import 'package:zcrud_core/zcrud_core.dart';` et référencent `ZCoreApi.version` (+ marqueurs des autres deps déclarées), rendant chaque arête AD-1 effectivement **utilisée** (acyclicité tangible, zéro import mort, pas de `depend_on_referenced_packages`). Aucun package n'a eu besoin de `flutter: sdk: flutter` → `dart analyze` reste vert partout.

**Preuve d'acyclicité (reproductible)** — `python3 scripts/dev/graph_proof.py` (RC=0) :
- 17 arêtes `zcrud_*` extraites, **identiques** à l'ensemble autorisé du graphe mermaid AD-1 (13 × `→ zcrud_core` + `generator→annotations` + `mindmap→markdown` + `flashcard→markdown` + `flashcard→export`).
- Tri topologique de Kahn : 14/14 nœuds ordonnés → `ACYCLIQUE OK`. Variante shell `edges | tsort` → `ACYCLIQUE OK`.
- `out-degree(zcrud_core) = 0` → `CORE OUT=0 OK` (le cœur est un puits).

**Résultats de vérification réels (rejoués sur disque) :**
- `dart pub get` (racine) → **RC=0** (siblings résolus par version).
- `dart analyze` par package (14/14) → **RC=0**, « No issues found! » partout.
- `dart run melos run analyze` → **RC=0**, `SUCCESS` sur 14.
- `dart run melos bootstrap` → **RC=0**, « 14 packages bootstrapped ».
- `dart run melos list` → **14** packages.
- Lockfile : **1** seul `pubspec.lock` racine, **0** lock par-package.
- SDK `^3.12.2` : **14/14** ; `resolution: workspace` : **14/14** (non-régression E1-1 OK).
- Barrels : **0** impl dans un barrel, **14/14** exportent `src/…`.
- Backbone : **13** satellites déclarent `zcrud_core` ; cœur **0** arête `zcrud_*`.
- Isolation cœur (AC5) & absence de dep lourde (AC6) : aucune dépendance réelle hors `zcrud_*` (les seuls hits `grep` Firebase/Syncfusion/Hive sont dans le texte de `description:`, pas dans `dependencies:` — vérifié en scopant l'extraction aux lignes de dépendance).
- `.gitignore` codegen intact (`*.g.dart`/`*.freezed.dart`) ; aucun fichier généré sur disque.

**Frontière E1-1/E1-2 respectée** : root `pubspec.yaml`, `melos.yaml`, bloc `melos:` (source de vérité des scripts) et duplication assumée non touchés ; aucun `example/` ajouté ; `sprint-status.yaml` non modifié (géré par l'orchestrateur).

### File List

**Barrels d'API réécrits (14) :**
- `packages/zcrud_core/lib/zcrud_core.dart`
- `packages/zcrud_annotations/lib/zcrud_annotations.dart`
- `packages/zcrud_generator/lib/zcrud_generator.dart`
- `packages/zcrud_markdown/lib/zcrud_markdown.dart`
- `packages/zcrud_list/lib/zcrud_list.dart`
- `packages/zcrud_mindmap/lib/zcrud_mindmap.dart`
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`
- `packages/zcrud_firestore/lib/zcrud_firestore.dart`
- `packages/zcrud_geo/lib/zcrud_geo.dart`
- `packages/zcrud_intl/lib/zcrud_intl.dart`
- `packages/zcrud_export/lib/zcrud_export.dart`
- `packages/zcrud_riverpod/lib/zcrud_riverpod.dart`
- `packages/zcrud_get/lib/zcrud_get.dart`
- `packages/zcrud_provider/lib/zcrud_provider.dart`

**Placeholders `lib/src/` créés (14) :**
- `packages/zcrud_core/lib/src/domain/z_core_api.dart`
- `packages/zcrud_annotations/lib/src/domain/z_annotations_api.dart`
- `packages/zcrud_generator/lib/src/z_generator_api.dart`
- `packages/zcrud_markdown/lib/src/domain/z_markdown_api.dart`
- `packages/zcrud_list/lib/src/presentation/z_list_api.dart`
- `packages/zcrud_mindmap/lib/src/domain/z_mindmap_api.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_api.dart`
- `packages/zcrud_firestore/lib/src/data/z_firestore_api.dart`
- `packages/zcrud_geo/lib/src/domain/z_geo_api.dart`
- `packages/zcrud_intl/lib/src/domain/z_intl_api.dart`
- `packages/zcrud_export/lib/src/data/z_export_api.dart`
- `packages/zcrud_riverpod/lib/src/presentation/z_riverpod_api.dart`
- `packages/zcrud_get/lib/src/presentation/z_get_api.dart`
- `packages/zcrud_provider/lib/src/presentation/z_provider_api.dart`

**Pubspecs modifiés (13 satellites — bloc `dependencies:` `zcrud_*`) :**
- `packages/zcrud_annotations/pubspec.yaml`, `packages/zcrud_generator/pubspec.yaml`, `packages/zcrud_markdown/pubspec.yaml`, `packages/zcrud_list/pubspec.yaml`, `packages/zcrud_mindmap/pubspec.yaml`, `packages/zcrud_flashcard/pubspec.yaml`, `packages/zcrud_firestore/pubspec.yaml`, `packages/zcrud_geo/pubspec.yaml`, `packages/zcrud_intl/pubspec.yaml`, `packages/zcrud_export/pubspec.yaml`, `packages/zcrud_riverpod/pubspec.yaml`, `packages/zcrud_get/pubspec.yaml`, `packages/zcrud_provider/pubspec.yaml`
- (`packages/zcrud_core/pubspec.yaml` **inchangé** — aucune arête `zcrud_*`, out-degree 0.)

**Outillage de preuve (nouveau) :**
- `scripts/dev/graph_proof.py` — extracteur de graphe AD-1 + preuve d'acyclicité (Kahn) + assertion `out-degree(zcrud_core)==0`.

**Fichier story :**
- `_bmad-output/implementation-artifacts/stories/e1-2-squelettes-packages-api-barrel.md` (frontmatter `baseline_commit`, tasks cochées, Status, Dev Agent Record, File List).
