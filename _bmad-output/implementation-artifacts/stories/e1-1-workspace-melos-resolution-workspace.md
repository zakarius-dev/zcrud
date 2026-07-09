---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 1.1 : Workspace melos + resolution workspace

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du monorepo zcrud**,
je veux **un workspace melos initialisé avec une résolution de dépendances unifiée (`resolution: workspace`) déclarant les 14 packages et alignée sur Dart `^3.12.2`**,
afin que **tous les packages partagent un unique lockfile cohérent, que `melos bootstrap` résolve sans conflit de version, et que les stories suivantes (squelettes E1-2, cœur E2, etc.) démarrent sur des fondations acycliques stables.**

## Contexte & valeur

Cette story est la **toute première du chemin critique MVP** (E1 → E2 → …). Elle ne livre aucun code fonctionnel, mais **l'habilitation** qui rend le reste implémentable : un workspace Dart/Flutter où chaque package est résolu ensemble contre un lockfile unique, éliminant les divergences de version qui sont la cause racine du portage manuel dans les 3 apps historiques (DODLP, IFFD, DLCFTI).

**Périmètre strict de CETTE story** : l'ossature du workspace (root `melos.yaml`, root `pubspec.yaml` en `resolution: workspace`, et un `pubspec.yaml` **minimal** par package suffisant pour que la résolution passe). Le remplissage du code de chaque package — barrels `lib/<pkg>.dart`, arbo `lib/src/{domain,data,presentation}`, dépendances **inter-packages**, compilation réelle et graphe acyclique vérifié — appartient à **E1-2** (« Squelettes de packages avec API/barrel »). Ne pas empiéter dessus.

**Ce qui rendra la story vérifiable** : `dart pub get` / `melos bootstrap` réussissent au niveau racine, le lockfile unique est produit, les 14 membres du workspace sont reconnus, et la contrainte `sdk: ^3.12.2` est présente et cohérente partout.

## Acceptance Criteria

1. **Root `pubspec.yaml` workspace.** Un `pubspec.yaml` existe à la racine du dépôt avec `name` (ex. `zcrud_workspace`), `publish_to: none`, `environment: sdk: ^3.12.2`, et un bloc `workspace:` listant **exactement les 14** chemins de packages (`packages/zcrud_core`, `packages/zcrud_annotations`, `packages/zcrud_generator`, `packages/zcrud_markdown`, `packages/zcrud_list`, `packages/zcrud_mindmap`, `packages/zcrud_flashcard`, `packages/zcrud_firestore`, `packages/zcrud_geo`, `packages/zcrud_intl`, `packages/zcrud_export`, `packages/zcrud_riverpod`, `packages/zcrud_get`, `packages/zcrud_provider`).
2. **`resolution: workspace` sur chaque membre.** Chacun des 14 `packages/<pkg>/pubspec.yaml` déclare `resolution: workspace`, un `name` conforme (`zcrud_<domaine>`), et `environment: sdk: ^3.12.2`. Aucun membre ne déclare une contrainte SDK incompatible avec `^3.12.2`.
3. **`melos.yaml` présent et cohérent.** Un `melos.yaml` racine existe avec `name: zcrud`, un `packages:` en glob (`packages/**`), et les scripts melos référencés par les stories aval au moins **déclarés** (`bootstrap` implicite ; les scripts `generate`/`analyze`/`test` peuvent être des stubs minimaux, leur durcissement complet relève d'E1-3). Le `melos.yaml` est compatible melos `^7.0.0`.
4. **`melos bootstrap` résout sans conflit.** Depuis la racine, `melos bootstrap` (ou son délégué `dart pub get` sous pub workspaces) se termine **RC=0**, sans erreur de résolution ni conflit de version, et matérialise l'environnement du workspace.
5. **Lockfile unique.** La résolution produit **un seul** `pubspec.lock` à la racine du workspace (les packages membres n'ont pas de lockfile propre) — matérialisant la résolution partagée `resolution: workspace`.
6. **14 membres reconnus.** Une commande melos d'inspection (ex. `melos list`) énumère **exactement 14** packages, correspondant nominativement à la liste de l'AC 1 (aucun manquant, aucun en trop, aucun doublon).
7. **Dart `^3.12.2` documenté et effectif.** La contrainte SDK `^3.12.2` (alignée sur le workspace lex_douane, cf. Stack de l'architecture) est la source unique en racine et répétée sur chaque membre ; le `dart --version` de l'environnement (≥ 3.12.2, < 4.0.0) satisfait la contrainte.
8. **Fondations non-régressives pour E1-2/E1-3.** Chaque `packages/<pkg>/` contient au minimum le `pubspec.yaml` (AC 2) et un placeholder inoffensif (`lib/<pkg>.dart` vide ou dossier `lib/`) suffisant pour que la résolution passe **sans** préjuger de l'API publique (remplie en E1-2). Aucune dépendance lourde (Firebase/Syncfusion/Quill/Maps) ni gestionnaire d'état n'est ajoutée à `zcrud_core` à ce stade (AD-1, AD-15) — les pubspecs restent quasi vides.
9. **`.gitignore` codegen.** Le `.gitignore` racine exclut le code généré (`*.g.dart`, `*.freezed.dart`) et les lockfiles de package superflus, conformément aux conventions du repo (déjà partiellement en place — vérifier/compléter, ne pas régresser).

## Tasks / Subtasks

- [x] **Task 1 — Root `pubspec.yaml` en mode workspace (AC: 1, 7)**
  - [x] Créer `/pubspec.yaml` : `name: zcrud_workspace`, `publish_to: none`, `environment: sdk: ^3.12.2`.
  - [x] Ajouter le bloc `workspace:` avec les 14 chemins `packages/<pkg>` (ordre = ordre de la Structural Seed de l'architecture).
  - [x] Ajouter `dev_dependencies` minimales du workspace si nécessaire pour la résolution (ex. `melos`), sans polluer les packages.
- [x] **Task 2 — `pubspec.yaml` minimal par package (AC: 2, 8)**
  - [x] Pour chacun des 14 packages : créer `packages/<pkg>/pubspec.yaml` avec `name: <pkg>`, `description`, `publish_to: none` (ou version SemVer 0.0.1), `resolution: workspace`, `environment: sdk: ^3.12.2`.
  - [x] Ajouter un placeholder `packages/<pkg>/lib/<pkg>.dart` vide (ou commentaire de barrel `// Barrel — rempli en E1-2`) pour éviter un package sans `lib/`.
  - [x] **Ne PAS** déclarer de dépendances inter-packages ni de deps lourdes ici (réservé E1-2). `zcrud_core` reste sans Firebase/Syncfusion/Quill/Maps ni manager d'état (AD-1, AD-15).
- [x] **Task 3 — `melos.yaml` racine (AC: 3)**
  - [x] Créer `/melos.yaml` : `name: zcrud`, `packages: [packages/**]`.
  - [x] Déclarer les scripts aval (`generate`, `analyze`, `test`) au moins en stubs cohérents avec les commandes du CLAUDE.md (`dart run build_runner build --delete-conflicting-outputs`, `dart analyze`, `flutter test`). Le durcissement (gates CI) relève d'E1-3.
  - [x] Vérifier la compatibilité du schéma `melos.yaml` avec melos `^7.0.0` (pub workspaces : `melos bootstrap` délègue à `dart pub get`).
- [x] **Task 4 — Bootstrap & résolution (AC: 4, 5, 6)**
  - [x] Lancer `dart pub get` puis `melos bootstrap` à la racine ; corriger toute erreur de résolution jusqu'à RC=0.
  - [x] Confirmer qu'**un seul** `pubspec.lock` racine est produit et qu'aucun `pubspec.lock` par-package ne subsiste.
  - [x] Lancer `melos list` (ou `--long`) et vérifier l'énumération des 14 packages.
- [x] **Task 5 — `.gitignore` & hygiène (AC: 9)**
  - [x] Vérifier/compléter `.gitignore` : `*.g.dart`, `*.freezed.dart`, `.dart_tool/`, `packages/*/pubspec.lock` si applicable, ne pas régresser l'existant.
- [x] **Task 6 — Vérification verte (tous AC)**
  - [x] Rejouer la séquence de la section « Stratégie de tests » et consigner les RC réels.

## Dev Notes

### Contraintes d'architecture (NON-NÉGOCIABLES)

- **AD-1 (dépendances acycliques)** : `zcrud_core` ne déclare **aucune** dépendance vers un autre package zcrud ni vers Firebase/Syncfusion/Quill/Maps. Tout satellite pointera vers `zcrud_core` (jamais l'inverse) — mais **ces arêtes sont posées en E1-2**, pas ici. Ici, les pubspecs restent quasi vides pour ne pas créer prématurément d'arête.
  [Source: architecture.md#AD-1]
- **AD-12 (zéro secret)** : aucune clé/secret dans un package. Sans objet directement ici (pas de config plateforme), mais ne rien introduire.
  [Source: architecture.md#AD-12]
- **AD-15 (multi-gestionnaire)** : `zcrud_core` n'importe **aucun** gestionnaire d'état. Les bindings (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`) existent comme membres du workspace mais restent des coquilles ; leurs deps (riverpod/get/provider) sont ajoutées quand leur story arrive (E2-9/E7/E8), pas ici.
  [Source: architecture.md#AD-15]

### Stack imposée (versions exactes)

| Élément | Contrainte | Source |
| --- | --- | --- |
| Dart SDK | `^3.12.2` | architecture.md#Stack |
| melos | `^7.0.0` (env local : 7.4.1) | architecture.md#Stack |

> **Pub workspaces (Dart ≥ 3.5) + melos 7** : `resolution: workspace` est une fonctionnalité **native de pub** ; melos 7 délègue `bootstrap` à `dart pub get` racine. Le `workspace:` du root pubspec est la source de vérité de la résolution ; `packages:` de `melos.yaml` sert le ciblage des scripts (`melos run`, `melos exec`). Les deux doivent lister le même ensemble.

### Les 14 packages (Structural Seed — ordre canonique)

`zcrud_core`, `zcrud_annotations`, `zcrud_generator`, `zcrud_markdown`, `zcrud_list`, `zcrud_mindmap`, `zcrud_flashcard`, `zcrud_firestore`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_riverpod`, `zcrud_get`, `zcrud_provider`.
[Source: architecture.md#Structural-Seed ; CLAUDE.md#Structure-des-packages]

### FR couvertes

- **FR-24** (importation sélective, graphe acyclique documenté) — posé structurellement ici, vérifié en E1-2.
- **FR-25** (gate de compat, cibles SDK alignées lex_douane `^3.12.2` documentées) — la partie « SDK aligné & documenté » est satisfaite ici ; le dry-run flutter_quill+awesome_select+analyzer est **E1-4**.
  [Source: prd.md#FR-24, prd.md#FR-25]

### Ce qu'il ne faut PAS faire ici (anti-empiètement)

- ❌ Pas de barrels d'API réels ni d'arbo `lib/src/{domain,data,presentation}` complète (→ E1-2).
- ❌ Pas de dépendances inter-packages ni de deps lourdes/managers d'état (→ E1-2, E2-9, E5, E6…).
- ❌ Pas de gates CI / lint anti-`reflectable` / scan de secrets (→ E1-3).
- ❌ Pas de dry-run de compat lex_douane (→ E1-4). Pas de révocation clé Maps (→ E1-5).
- ❌ Ne PAS toucher `sprint-status.yaml` (géré par l'orchestrateur).

### Project Structure Notes

- Arborescence cible (cf. Structural Seed) :
  ```text
  zcrud/
    melos.yaml
    pubspec.yaml            # workspace (resolution: workspace)
    pubspec.lock            # UNIQUE, racine
    packages/
      zcrud_core/ … zcrud_provider/   # 14 membres, chacun resolution: workspace
    example/                # présent dans la seed ; création différée (non requis par les AC) — NE PAS l'ajouter au workspace tant qu'il n'a pas de pubspec
  ```
- **Variance assumée** : `example/` figure dans la Structural Seed mais n'est **pas** un des 14 packages CRUD et n'est pas requis par cette story. Ne pas l'inclure dans `workspace:`/`packages:` tant qu'il n'existe pas (sinon la résolution échouera). À traiter ultérieurement (banc d'intégration, E7).
- **Convention lockfile** : sous `resolution: workspace`, un lockfile unique racine est attendu ; c'est le comportement pub natif, pas une option melos.

### Ambiguïté à trancher par le dev (documentée)

- **Chevauchement E1-1 / E1-2** : pour que `melos bootstrap` (AC 4) résolve, les 14 dossiers de packages doivent exister avec un `pubspec.yaml` valide **dès E1-1**. E1-1 crée donc des pubspecs **minimaux** + placeholder `lib/`. E1-2 remplit ensuite barrels/`src/`/deps inter-packages/compilation. La frontière retenue : **E1-1 = la résolution passe ; E1-2 = ça compile et l'API existe.** Si dev-story juge plus propre de créer les `lib/<pkg>.dart` (vides) ici, c'est acceptable tant qu'aucune API ni dépendance n'est introduite.

### Testing standards

Aucun framework de test unitaire requis pour cette story d'habilitation : la vérification est **commande-de-build/RC** (résolution, énumération, contrainte SDK). Les tests widget/unitaires démarrent en E2/E3. La preuve d'acceptation = la séquence de commandes ci-dessous, RC=0, sorties conformes.

## Stratégie de tests (vérification d'acceptation)

Exécuter depuis la racine du dépôt et consigner chaque RC/sortie :

1. **SDK conforme `^3.12.2` (AC 7)**
   ```bash
   dart --version   # attendu : >= 3.12.2 et < 4.0.0
   ```
2. **`resolution: workspace` + 14 membres déclarés (AC 1, 2)**
   ```bash
   # Le root pubspec liste 14 membres :
   grep -A20 '^workspace:' pubspec.yaml | grep -c 'packages/zcrud_'   # attendu : 14
   # Chaque membre déclare resolution: workspace :
   grep -rl 'resolution: workspace' packages/*/pubspec.yaml | wc -l   # attendu : 14
   # Chaque membre déclare le SDK ^3.12.2 :
   grep -rl 'sdk: ..3.12.2' packages/*/pubspec.yaml | wc -l           # attendu : 14
   ```
3. **Résolution sans conflit (AC 4)**
   ```bash
   dart pub get            # RC attendu : 0, aucune erreur de version
   melos bootstrap         # RC attendu : 0
   ```
   Critère : sortie sans « version solving failed » ni conflit ; terminaison RC=0.
4. **Lockfile unique (AC 5)**
   ```bash
   ls pubspec.lock                       # présent en racine
   find packages -name pubspec.lock      # attendu : AUCUN résultat
   ```
5. **Énumération des 14 packages (AC 6)**
   ```bash
   melos list           # attendu : 14 noms, = liste canonique, sans doublon/manquant
   melos list --long    # inspection nominative
   ```
   Vérifier nominativement contre : `zcrud_core, zcrud_annotations, zcrud_generator, zcrud_markdown, zcrud_list, zcrud_mindmap, zcrud_flashcard, zcrud_firestore, zcrud_geo, zcrud_intl, zcrud_export, zcrud_riverpod, zcrud_get, zcrud_provider`.
6. **Dry-run de résolution (garde-fou FR-25 partiel, AC 7)**
   ```bash
   dart pub get --dry-run   # RC attendu : 0 (aucun changement destructif inattendu)
   ```
7. **Hygiène codegen (AC 9)**
   ```bash
   grep -E '\*\.g\.dart|\*\.freezed\.dart' .gitignore   # présents
   ```

**Definition of green** : toutes les commandes ci-dessus produisent les sorties attendues et RC=0 pour `dart pub get`, `melos bootstrap`, `melos list`, `dart pub get --dry-run`.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E1] — Story E1-1, AC melos.yaml + pubspec workspace, 14 packages, Dart ^3.12.2.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-1] — direction de dépendance acyclique.
- [Source: architecture.md#AD-12] — zéro secret. [Source: architecture.md#AD-15] — multi-gestionnaire, cœur sans manager d'état.
- [Source: architecture.md#Stack] — Dart `^3.12.2`, melos `^7.0.0`.
- [Source: architecture.md#Structural-Seed] — arborescence workspace, `resolution: workspace`, liste des 14 packages.
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#FR-24] — importation sélective / graphe acyclique documenté.
- [Source: prd.md#FR-25] — gate de compat, cibles SDK alignées lex_douane `^3.12.2`.
- [Source: CLAUDE.md#Build-&-Development-Commands] — commandes melos (`dart pub get`, `melos bootstrap`, `melos run generate/analyze/test`, `dart pub get --dry-run`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`)

### Debug Log References

Vérification verte rejouée réellement (RC réels) :

| Commande | Sortie / RC |
| --- | --- |
| `dart --version` | `Dart SDK version: 3.12.2 (stable)` → satisfait `^3.12.2` (≥3.12.2, <4.0.0) |
| `dart pub get` | `Changed 38 dependencies!` — **RC=0** (aucun conflit de version) |
| `dart pub get --dry-run` | `No dependencies would change.` — **RC=0** |
| `melos bootstrap` | `-> 14 packages bootstrapped` — SUCCESS |
| `melos list` | 14 noms (liste canonique, sans doublon/manquant) — RC=0 |
| lockfile racine | `pubspec.lock` présent en racine ; `find packages -name pubspec.lock` → **0** |
| `grep -A20 '^workspace:' pubspec.yaml \| grep -c 'packages/zcrud_'` | **14** |
| `grep -rl 'resolution: workspace' packages/*/pubspec.yaml \| wc -l` | **14** |
| `grep -rl 'sdk: \^3.12.2' packages/*/pubspec.yaml \| wc -l` | **14** |
| `dart analyze` | `No issues found!` — **RC=0** |
| `melos run analyze` | 14 packages `No issues found!` → `SUCCESS` — RC=0 |
| `grep -E '\*\.g\.dart\|\*\.freezed\.dart' .gitignore` | présents (non régressés) |

### Completion Notes List

- Les 9 ACs sont satisfaits. Périmètre E1-1 strict respecté : squelette de workspace uniquement, aucune dépendance inter-packages, aucune dep lourde (Firebase/Syncfusion/Quill/Maps) ni gestionnaire d'état ajouté à `zcrud_core` (AD-1, AD-15).
- **Écart documenté (melos 7.8 + pub workspaces)** : la version de melos résolue via le `dev_dependency` du workspace (7.8.2) lit sa configuration de scripts depuis le **root `pubspec.yaml`** sous la clé `melos:` lorsqu'un pub workspace est présent — `melos run analyze` renvoyait `NoScriptException` tant que la config vivait uniquement dans `melos.yaml`. Résolution : le `melos.yaml` racine est conservé (AC 3 — `name: zcrud`, `packages: [packages/**]`, scripts `generate`/`analyze`/`test`) ET la même config `melos:` (name + scripts) est ajoutée au root `pubspec.yaml` pour que les scripts soient réellement fonctionnels. `melos run analyze` passe désormais sur les 14 packages.
- `.gitignore` déjà conforme (`*.g.dart`, `*.freezed.dart`, `pubspec_overrides.yaml`, `.melos_tool/`, lockfiles de package neutralisés par défaut) — aucune régression nécessaire.
- Aucun test unitaire (story d'habilitation) : la preuve d'acceptation est la séquence de commandes build/RC ci-dessus.
- `sprint-status.yaml` **non modifié** (géré par l'orchestrateur, conformément à la consigne).

### File List

Créés :
- `pubspec.yaml` (root workspace : `resolution` via bloc `workspace:` des 14 membres + `dev_dependencies: melos` + config `melos:` fonctionnelle)
- `melos.yaml` (root : `name: zcrud`, `packages: [packages/**]`, scripts `generate`/`analyze`/`test`)
- `pubspec.lock` (unique, racine — généré par la résolution partagée)
- `packages/<pkg>/pubspec.yaml` et `packages/<pkg>/lib/<pkg>.dart` pour les 14 packages : `zcrud_core`, `zcrud_annotations`, `zcrud_generator`, `zcrud_markdown`, `zcrud_list`, `zcrud_mindmap`, `zcrud_flashcard`, `zcrud_firestore`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_riverpod`, `zcrud_get`, `zcrud_provider`

Modifiés :
- _(aucun — `.gitignore` vérifié conforme, non modifié)_
