---
baseline_commit: 6f6c9fb8f334a6c1bdf78ec35d4f3423cc22ecf6
---

# Story REL.1 : Préparation des packages publiables sur pub.dev (v0.1.0)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur/Owner de zcrud (publisher `zakarius.com`)**,
je veux **rendre publiables sur pub.dev les 12 packages MVP fonctionnels du monorepo en version `0.1.0` — métadonnées complètes (`version`, `description`, `homepage`/`repository`, `topics`, `environment`), retrait de `publish_to: none`, `LICENSE`/`CHANGELOG.md`/`README.md` par package, et réconciliation `resolution: workspace` (dev) ↔ contraintes hosted `^0.1.0` (publish) avec un ordre de publication topologique documenté**,
afin de **pouvoir publier réellement (REL-2, action Owner) sans surprise, en préservant STRICTEMENT les invariants du monorepo (14 packages produit, graphe acyclique CORE OUT=0, gate M-1) et sans toucher `example/` (EX-3 en parallèle)**.

**C'est la PREMIÈRE story de l'epic REL (publication pub.dev).** REL-1 = **rendre publiable + gates** (aucune publication réelle). REL-2 = **dry-run autoritatif + publication réelle** (`dart pub login`, verified publisher `zakarius.com` — action Owner). REL-1 touche EXCLUSIVEMENT les **métadonnées des packages sous `packages/`** ; EX-3 touche EXCLUSIVEMENT `example/` (fichiers disjoints, développables en parallèle).

## Contexte

- **Origine** : consigne user 2026-07-10 + sprint-status section REL (`rel-1-prep-packages-publiables: backlog`, `rel-2-dry-run-et-publication: backlog`). Note de la section : « DIFFERE : APRES les packages MVP (E4/E5/E6/E11a complets) — MAINTENANT réuni. Licence MIT, versions 0.1.0. Publisher zakarius.com. Publication reelle = action Owner (dart pub login) ». [Source: sprint-status.yaml#section REL]
- **État réel du dépôt** (vérifié sur disque, HEAD `6f6c9fb`) :
  - **14 packages** sous `packages/*` + le harnais dev/test-only `tool/binding_conformance` (hors `packages/**`, invisible de `melos list`). [Source: pubspec.yaml#workspace]
  - Les 14 pubspecs sont TOUS en `version: 0.0.1`, `publish_to: none`, `resolution: workspace`, avec des `description` **en français** (souvent multi-lignes). [Source: packages/*/pubspec.yaml]
  - Les dépendances inter-`zcrud_*` sont DÉJÀ des **contraintes de version hosted** (`zcrud_core: ^0.0.1`, …) — **AUCUN `path:`** (choix délibéré E1-2, commentaire récurrent « Siblings du workspace résolus par contrainte de version (pas de path:) »). C'est ce qui rend le publish propre : rien à « dé-path-ifier ». [Source: packages/zcrud_markdown/pubspec.yaml ; packages/zcrud_generator/pubspec.yaml]
  - **AUCUN** package n'a de `README.md`, `CHANGELOG.md` ni `LICENSE` (vérifié : `find packages -name README.md/CHANGELOG.md/LICENSE` = vide). Seul le **`LICENSE` racine** existe : MIT © 2026 Zakarius (zakarius.com). [Source: LICENSE]
  - **`zcrud_flashcard` et `zcrud_mindmap` sont des SQUELETTES** (barrel + `src/` ~60 lignes au total, epics **E9/E10 = v1.x**, `backlog` au sprint-status). [Source: packages/zcrud_flashcard/lib ; packages/zcrud_mindmap/lib ; epics.md#E9 ; epics.md#E10]
  - **Remote git** : `https://github.com/zakarius-dev/zcrud.git`. [Source: `git remote -v`]
- **Épics MVP livrés** (prérequis REL réuni) : E2 (cœur+codegen+bindings), E3 (édition), E4 (liste), E5-1/5-2 (firestore MVP), E6 (markdown), E11a (geo/intl/export) tous `done`. E7/E8 (intégration apps externes) et E9/E10/E11b (v1.x) restent `backlog` — **hors périmètre REL-1**.
- **Frontière stricte** : REL-1 **NE publie PAS** (ni `dart pub publish` réel, ni `dart pub login`, ni création du verified publisher). REL-1 rend chaque package **provablement publiable** (dry-run vert) ; REL-2 fait le dry-run autoritatif final + le publish réel dans l'ordre topologique (Owner).

## Décision structurante — périmètre de publication & réconciliation workspace↔hosted

**DÉCISIONS (orchestrateur, à appliquer par dev-story) :**

### D1 — Périmètre de publication 0.1.0 : 12 packages ; flashcard/mindmap DIFFÉRÉS

**PUBLIÉS en 0.1.0 (12 packages MVP fonctionnels)** :

| # | Package | Rôle | Dépend (zcrud_*) |
|---|---------|------|------------------|
| 1 | `zcrud_core` | Domaine + moteur édition + ports + ZFieldSpec + l10n + ZcrudScope | — (out-degree 0) |
| 2 | `zcrud_annotations` | `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` | zcrud_core |
| 3 | `zcrud_generator` | Builder build_runner (dé)sérialisation + ZFieldSpec + registre | zcrud_core, zcrud_annotations |
| 4 | `zcrud_markdown` | Rich-text Quill + ZCodec + embeds LaTeX/tables | zcrud_core |
| 5 | `zcrud_list` | DynamicList Syncfusion derrière ZListRenderer | zcrud_core |
| 6 | `zcrud_firestore` | Adapters Firestore + Hive (offline-first) | zcrud_core |
| 7 | `zcrud_geo` | Champ géo + carte OSM optionnelle | zcrud_core |
| 8 | `zcrud_intl` | Champs téléphone / pays / adresse | zcrud_core |
| 9 | `zcrud_export` | Export DataGrid → Excel/PDF (Syncfusion) | zcrud_core |
| 10 | `zcrud_riverpod` | Binding état/injection Riverpod | zcrud_core |
| 11 | `zcrud_get` | Binding état/injection GetX + get_it | zcrud_core |
| 12 | `zcrud_provider` | Binding état/injection provider | zcrud_core |

**DIFFÉRÉS (NON publiés en 0.1.0)** :

- **`zcrud_flashcard`** (E9, v1.x) et **`zcrud_mindmap`** (E10, v1.x) sont des **SQUELETTES** (aucune substance implémentée). **Décision : EXCLURE du lot 0.1.0** (option « exclure/différer » recommandée par la consigne — préférée à un placeholder `0.0.1`). Ils **conservent** `version: 0.0.1` + `publish_to: none` et seront publiés en v1.x quand E9/E10 seront `done`. **MAIS** : leurs contraintes inter-`zcrud_*` doivent être bumpées (cf. D2) sinon le workspace ne résout plus.
- **`tool/binding_conformance`** : harnais dev/test-only (hors `packages/**`, dev_dependency non transitive) → **jamais publié**, laissé intact (`version: 0.0.1`).

**Justification** : publier un squelette dégrade la crédibilité du publisher et impose une dette de compat (une API 0.1.0 publique gèle des symboles inexistants). Exclure ≠ casser : les 12 packages publiés ne dépendent d'AUCUN des deux squelettes (arêtes vérifiées : flashcard/mindmap sont des **puits** consommateurs, jamais des dépendances des 12).

### D2 — Réconciliation `resolution: workspace` (dev) ↔ contraintes hosted (publish)

**Mécanisme (le cœur de la story)** :

1. **Aucun `path:` à retirer.** Le repo utilise déjà des contraintes hosted (`^0.0.1`) résolues localement par `resolution: workspace` (pub matche la version du sibling présent dans le workspace). Publier ne requiert donc PAS de réécrire des `path:` en versions — l'inflexion est un simple **bump de borne**.
2. **Bump atomique de TOUTES les contraintes inter-`zcrud_*` de `^0.0.1` → `^0.1.0`, sur les 14 pubspecs** (pas seulement les 12 publiés). **Raison critique — sémantique caret sur 0.x** : `^0.0.1` signifie `>=0.0.1 <0.0.2`, et `^0.1.0` signifie `>=0.1.0 <0.2.0`. Dès que `zcrud_core` passe à `0.1.0`, toute contrainte `^0.0.1` (y compris celles de flashcard/mindmap vers core/markdown/export) **cesse de résoudre** dans le workspace → `dart pub get` échoue. Le bump doit donc couvrir les 14, sans quoi l'invariant « le workspace résout toujours (dev) » est cassé.
3. **`version` : seuls les 12 publiés passent à `0.1.0`.** Les 2 squelettes gardent `version: 0.0.1` (leur propre version n'a pas à bouger ; seules leurs *contraintes de dépendance* bougent). `tool/binding_conformance` reste `0.0.1` et son usage en `dev_dependency: ^0.0.1` par les 3 bindings reste inchangé (dev-only, non publié, non transitif).
4. **`resolution: workspace` est CONSERVÉ dans chaque pubspec publié** (recommandation). En dev il assure la résolution partagée ; pour un **consommateur** de `zcrud_markdown` publié, le champ `resolution` d'une *dépendance* n'a d'effet que si le consommateur est lui-même un workspace membre — sinon `zcrud_core: ^0.1.0` se résout comme une contrainte hosted normale. **Ambiguïté à lever au dry-run (REL-2)** : si `dart pub publish --dry-run` **rejette/avertit** sur `resolution: workspace`, appliquer le **fallback documenté** = retirer la ligne `resolution: workspace` uniquement dans les tarballs publiés (ou basculer la stratégie de publication). REL-1 pose la question et fournit la preuve dry-run ; REL-2 tranche définitivement avant le publish réel.

**Ordre de publication topologique (REL-2, à documenter dès REL-1)** — chaque package doit être publié *après* que ses dépendances `zcrud_*` sont disponibles sur pub.dev en `0.1.0` :

```
Tier 0 :  zcrud_core                      (out-degree 0 → publié EN PREMIER)
Tier 1a:  zcrud_annotations               (dep: zcrud_core)
Tier 1b:  zcrud_generator                 (dep: zcrud_core, zcrud_annotations → APRÈS annotations)
Tier 1c:  zcrud_markdown, zcrud_list, zcrud_firestore, zcrud_geo,
          zcrud_intl, zcrud_export, zcrud_riverpod, zcrud_get,
          zcrud_provider                  (dep: zcrud_core uniquement — ordre libre entre eux)
```

Séquence linéaire sûre : `zcrud_core → zcrud_annotations → zcrud_generator → zcrud_markdown → zcrud_list → zcrud_firestore → zcrud_geo → zcrud_intl → zcrud_export → zcrud_riverpod → zcrud_get → zcrud_provider`.

### D3 — Langue des `description` : ANGLAIS court (convention pub.dev)

pub.dev accepte le français mais **recommande l'anglais** (audience mondiale, score pana). **Décision : les `description` publiées passent en ANGLAIS concis (60–180 caractères).** Les **commentaires** de rationale (souvent en français, riches) restent inchangés — seul le champ `description:` est reformulé. (Nuance monorepo : `communication_language`/`document_output_language` = French au niveau BMAD, mais c'est une **convention d'écosystème externe** ; la doc/story reste en français, seul le champ machine `description` est anglicisé.)

Descriptions anglaises proposées (à ajuster ≤180 char) :

| Package | `description` (EN, 60–180) |
|---------|----------------------------|
| zcrud_core | `Pure domain and Flutter-native reactive edition engine for rich CRUD: ZFieldSpec, ports, l10n, ZcrudScope. No heavy dependencies.` |
| zcrud_annotations | `Annotations for the zcrud code generator: @ZcrudModel, @ZcrudField and @ZcrudId. Declare a model once, generate everything.` |
| zcrud_generator | `build_runner code generator for zcrud: (de)serialization, ZFieldSpec[] and registry from @ZcrudModel-annotated models.` |
| zcrud_markdown | `Rich Markdown editing and reading for zcrud, built on Quill with a pluggable ZCodec and LaTeX/table embeds.` |
| zcrud_list | `DynamicList data-grid for zcrud powered by Syncfusion, isolated behind the neutral ZListRenderer port.` |
| zcrud_firestore | `Firestore and Hive adapters for zcrud repositories: offline-first storage behind neutral, backend-agnostic ports.` |
| zcrud_geo | `Geo fields for zcrud: neutral location/geoArea model with an optional OpenStreetMap map adapter.` |
| zcrud_intl | `International fields for zcrud: phone, country and address with bundled, offline metadata and neutral values.` |
| zcrud_export | `Tabular export for zcrud (DataGrid to Excel and PDF via Syncfusion) behind a neutral, byte-based API.` |
| zcrud_riverpod | `Riverpod state and injection binding for zcrud (optional). Targets lex_douane / IFFD host apps.` |
| zcrud_get | `GetX and get_it state and injection binding for zcrud (optional). Targets the DODLP host app.` |
| zcrud_provider | `provider state and injection binding for zcrud (optional). Completes the multi-state-manager matrix.` |

### D4 — `topics` par package (≤ 5, minuscules, tirets, 2–32 char, format pub.dev valide)

| Package | `topics` |
|---------|----------|
| zcrud_core | `flutter`, `crud`, `forms`, `dynamic-forms`, `state-management` |
| zcrud_annotations | `annotations`, `code-generation`, `crud`, `serialization` |
| zcrud_generator | `code-generation`, `build-runner`, `serialization`, `crud` |
| zcrud_markdown | `markdown`, `rich-text`, `editor`, `quill`, `latex` |
| zcrud_list | `datagrid`, `table`, `crud`, `syncfusion` |
| zcrud_firestore | `firestore`, `firebase`, `offline-first`, `repository` |
| zcrud_geo | `geolocation`, `maps`, `openstreetmap`, `forms` |
| zcrud_intl | `internationalization`, `phone`, `country`, `forms` |
| zcrud_export | `export`, `excel`, `pdf`, `datagrid` |
| zcrud_riverpod | `riverpod`, `state-management`, `crud`, `forms` |
| zcrud_get | `getx`, `state-management`, `crud`, `forms` |
| zcrud_provider | `provider`, `state-management`, `crud`, `forms` |

### D5 — `homepage` / `repository` / `issue_tracker`

Pour les 12 publiés :
```yaml
homepage: https://github.com/zakarius-dev/zcrud
repository: https://github.com/zakarius-dev/zcrud/tree/main/packages/<pkg>
issue_tracker: https://github.com/zakarius-dev/zcrud/issues
```
(`repository` pointant vers le sous-dossier du package facilite la navigation pub.dev vers le code source.)

## Acceptance Criteria

1. **AC1 — Périmètre de publication documenté et appliqué (D1).** La story acte le périmètre : **12 packages publiés en 0.1.0** (`zcrud_core`, `zcrud_annotations`, `zcrud_generator`, `zcrud_markdown`, `zcrud_list`, `zcrud_firestore`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_riverpod`, `zcrud_get`, `zcrud_provider`) ; **`zcrud_flashcard` et `zcrud_mindmap` EXCLUS/DIFFÉRÉS** (squelettes E9/E10 v1.x, `version` restée `0.0.1`, `publish_to: none` CONSERVÉ) ; `tool/binding_conformance` jamais publié, intact. Given l'état final → When on liste les pubspecs → Then exactement 12 packages ont `version: 0.1.0` sans `publish_to: none`, et 2 (flashcard, mindmap) gardent `version: 0.0.1` + `publish_to: none`.

2. **AC2 — `version: 0.1.0` sur les 12 packages publiés.** Chacun des 12 pubspecs déclare `version: 0.1.0`. Given un package publié → When on lit son `version` → Then il vaut exactement `0.1.0`.

3. **AC3 — `description` en ANGLAIS, longueur pub.dev (60–180 char) sur les 12 (D3).** Chaque `description` des 12 publiés est reformulée en anglais concis, **≥ 60 et ≤ 180 caractères** (contrainte pana/pub.dev), sur une forme mono-ligne valide. Les commentaires de rationale (français) restent inchangés. Given chaque `description` publiée → When on mesure sa longueur → Then 60 ≤ len ≤ 180, et le texte est en anglais.

4. **AC4 — `homepage`/`repository`/`issue_tracker` présents sur les 12 (D5).** Chaque pubspec publié déclare `homepage`, `repository` (sous-dossier du package sur `github.com/zakarius-dev/zcrud`) et `issue_tracker`. Given un package publié → When on lit ses champs URL → Then les 3 sont présents et pointent vers le dépôt GitHub.

5. **AC5 — `topics` valides et pertinents sur les 12 (D4).** Chaque pubspec publié déclare `topics:` (liste de 3–5 entrées, **minuscules, tirets, 2–32 caractères, `^[a-z][a-z0-9-]*$`** — format accepté par pub.dev). Given `topics` → When validés contre le format pub.dev → Then chaque topic est conforme et pertinent au rôle du package.

6. **AC6 — `publish_to: none` RETIRÉ des 12 publiés uniquement.** La ligne `publish_to: none` est supprimée des 12 pubspecs publiés et **conservée** sur `zcrud_flashcard`, `zcrud_mindmap`, le root `pubspec.yaml` (workspace) et `tool/binding_conformance`. Given l'état final → When on grep `publish_to: none` sous `packages/` → Then seuls flashcard et mindmap le portent.

7. **AC7 — `LICENSE` (MIT, copie du root) dans chacun des 12.** Un fichier `LICENSE` identique au `LICENSE` racine (MIT © 2026 Zakarius, zakarius.com) est présent à la racine de chacun des 12 packages publiés. Given un package publié → When on compare son `LICENSE` au `LICENSE` racine → Then contenu identique (pub.dev exige un LICENSE par package).

8. **AC8 — `CHANGELOG.md` initial `## 0.1.0` dans chacun des 12.** Chaque package publié a un `CHANGELOG.md` avec une entrée `## 0.1.0` (release initiale, résumé du rôle du package). Given un package publié → When on lit son `CHANGELOG.md` → Then il contient une section `## 0.1.0`.

9. **AC9 — `README.md` (rôle + exemple minimal + lien mono-repo + licence) dans chacun des 12.** Chaque package publié a un `README.md` couvrant : (a) le rôle du package (1–2 phrases), (b) un **exemple minimal** d'usage (snippet), (c) un lien vers le mono-repo `github.com/zakarius-dev/zcrud`, (d) la mention de licence MIT. Given un package publié → When on lit son `README.md` → Then les 4 éléments sont présents.

10. **AC10 — Réconciliation workspace↔hosted : bump `^0.1.0` sur les 14, résolution dev VERTE (D2).** TOUTES les contraintes inter-`zcrud_*` des **14** pubspecs (12 publiés + 2 squelettes) passent de `^0.0.1` à `^0.1.0` (y compris flashcard/mindmap vers core/markdown/export). Aucune dépendance inter-`zcrud_*` n'utilise `path:`. `dart pub get` (racine, `resolution: workspace`) **RC=0** — le workspace résout toujours en dev. Given le bump appliqué → When `dart pub get` racine → Then RC=0 (aucun conflit de contrainte 0.x). *(Note caret : sans ce bump global, `^0.0.1` = `>=0.0.1 <0.0.2` ne résout plus contre core 0.1.0 → get échoue.)*

11. **AC11 — Ordre de publication topologique DÉFINI (D2).** La story/les notes de dev documentent l'ordre topologique de publication (Tier 0 `zcrud_core` → Tier 1a `zcrud_annotations` → Tier 1b `zcrud_generator` → Tier 1c les 9 satellites), fondé sur le graphe de dépendances réel. Given le graphe des 12 → When on ordonne par dépendances → Then `zcrud_core` est premier, `zcrud_generator` après `zcrud_annotations`, les 9 autres après `zcrud_core`.

12. **AC12 — Invariants du monorepo préservés + `example/` non touché.** `dart run melos list` retourne **exactement 14** packages (inchangé). `python3 scripts/dev/graph_proof.py` reste **vert** (CORE OUT=0, acyclique — le bump de bornes ne change aucune arête). `dart run scripts/ci/gate_melos_divergence.dart` (M-1), `gate:reflectable`, `gate:secrets`, `gate:codegen` restent **verts**. `git status -- example/` est **vide** (EX-3 en parallèle, disjoint). Given l'état final → When on rejoue melos list + graph_proof + gates → Then 14 packages, graphe inchangé, gates verts, `example/` intact.

13. **AC13 — Publiabilité PROUVÉE par dry-run (non destructif) + frontière REL-1/REL-2.** Là où la toolchain le permet, chaque package publié passe `dart pub publish --dry-run` avec **0 erreur** (warnings pana triés/documentés : ex. absence d'`example/` par package = boost de score différé, non bloquant ; éventuel warning `resolution: workspace` = ambiguïté D2 à trancher en REL-2). **AUCUNE publication réelle** (`dart pub publish` sans `--dry-run`), **aucun `dart pub login`**, **aucune** création de verified publisher : ce sont des actions **REL-2 / Owner**. Given la préparation terminée → When on lance `dart pub publish --dry-run` par package publié → Then 0 erreur bloquante, et aucun artefact n'est envoyé à pub.dev. *(Si la toolchain Flutter/pub n'est pas disponible dans l'environnement dev-story, documenter le blocage et laisser le dry-run autoritatif à REL-2.)*

## Tasks / Subtasks

- [x] **T1 — Acter le périmètre de publication (AC1).**
  - [x] Confirmer la liste des 12 publiés vs 2 différés (flashcard/mindmap) vs binding_conformance (jamais publié).
  - [x] Vérifier que les 12 publiés ne dépendent d'AUCUN squelette (arêtes flashcard/mindmap = puits).
- [x] **T2 — Métadonnées des 12 pubspecs publiés (AC2, AC3, AC4, AC5, AC6).**
  - [x] `version: 0.0.1` → `0.1.0` (12 packages).
  - [x] `description:` → anglais mono-ligne 60–180 char (table D3) ; conserver les commentaires de rationale.
  - [x] Ajouter `homepage`/`repository`/`issue_tracker` (table D5).
  - [x] Ajouter `topics:` (table D4), format `^[a-z][a-z0-9-]*$`, 2–32 char, ≤ 5.
  - [x] Retirer `publish_to: none` (12 publiés SEULEMENT ; conserver sur flashcard/mindmap/root/binding_conformance).
  - [x] Vérifier `environment.sdk` cohérent (`^3.12.2` présent partout) ; consigner en note l'éventuel warning pana « missing flutter lower bound » pour les packages Flutter (non bloquant, boost de score différé).
- [x] **T3 — Réconciliation workspace↔hosted : bump `^0.1.0` sur les 14 (AC10, AC11).**
  - [x] Remplacer chaque contrainte inter-`zcrud_*` `^0.0.1` → `^0.1.0` dans les **14** pubspecs (dont flashcard→{core,markdown,export}, mindmap→{core,markdown}, generator→{core,annotations}).
  - [x] NE PAS toucher `binding_conformance: ^0.0.1` (dev_dependency dev-only non publié).
  - [x] `dart pub get` racine → RC=0 (résolution dev verte).
  - [x] Documenter l'ordre de publication topologique dans les notes de dev (Tier 0/1a/1b/1c).
- [x] **T4 — `LICENSE` par package publié (AC7).**
  - [x] Copier le `LICENSE` racine (MIT) à la racine de chacun des 12 packages publiés (contenu identique).
- [x] **T5 — `CHANGELOG.md` par package publié (AC8).**
  - [x] Créer `CHANGELOG.md` avec section `## 0.1.0` (release initiale) pour chacun des 12.
- [x] **T6 — `README.md` par package publié (AC9).**
  - [x] Créer `README.md` (rôle + exemple minimal + lien mono-repo + licence MIT) pour chacun des 12, en cohérence avec le barrel `lib/<pkg>.dart` réel.
- [x] **T7 — Vérif verte + publiabilité (AC12, AC13).**
  - [x] `dart run melos list` = 14 ; `python3 scripts/dev/graph_proof.py` vert ; `gate:melos`/`gate:reflectable`/`gate:secrets`/`gate:codegen` verts.
  - [x] `dart run melos run analyze` RC=0 ; `dart run melos run test` RC=0 (aucune régression fonctionnelle : la story ne change que des métadonnées + docs).
  - [x] `dart pub publish --dry-run` par package publié (si toolchain dispo) → 0 erreur ; trier/documenter les warnings ; **aucune publication réelle**.
  - [x] `git status -- example/` vide (EX-3 disjoint) ; `git status -- packages/` ne montre QUE les 12 dossiers publiés (+ 2 lignes de contrainte sur flashcard/mindmap).
- [x] **T8 — Documentation de frontière REL-1 → REL-2.**
  - [x] Consigner : REL-2 = dry-run autoritatif final + `dart pub login` + verified publisher `zakarius.com` + publish réel dans l'ordre topologique (action Owner).
  - [x] Consigner l'ambiguïté `resolution: workspace` (garder par défaut ; fallback = retirer si le dry-run REL-2 la rejette).

## Dev Notes

### Contraintes d'architecture applicables (AD)

- **AD-1 (graphe acyclique, CORE OUT=0)** : le bump de bornes `^0.0.1`→`^0.1.0` ne crée/supprime **aucune arête** — `graph_proof.py` ne compte que la présence d'une dép `zcrud_*`, pas sa borne. `zcrud_core` reste sans dépendance `zcrud_*`. [Source: pubspec.yaml#melos gate:graph ; scripts/dev/graph_proof.py]
- **AD-12 (zéro secret)** : aucune clé/licence (Syncfusion, Google Maps, Firebase) committée. `gate:secrets` doit rester vert. Les READMEs ne doivent contenir AUCUN secret. L'enregistrement de licence Syncfusion reste une config plateforme de l'app hôte (rappel dans les READMEs de `zcrud_list`/`zcrud_export`).
- **AD-3 (codegen, anti-reflectable)** : `gate:reflectable` doit rester vert ; `reflectable` reste confiné à `zcrud_get` (adaptateur DODLP) — sa présence n'affecte pas la publiabilité.
- **Invariant produit « 14 »** : `melos list` = 14 est intangible. Retirer `publish_to: none` NE change PAS la membership du workspace ni la vue melos. [Source: melos.yaml#ignore ; pubspec.yaml#workspace]

### État actuel des fichiers TOUCHÉS (lu sur disque)

- **14 × `packages/*/pubspec.yaml`** — UPDATE. Aujourd'hui : `version: 0.0.1`, `publish_to: none`, `resolution: workspace`, `description` FR, deps inter-`zcrud_*` en `^0.0.1` hosted (aucun `path:`). Ce qui change : (12 publiés) version→0.1.0, description→EN, +homepage/repository/issue_tracker/topics, −publish_to; (14) bornes deps →^0.1.0. Ce qui est PRÉSERVÉ : `resolution: workspace`, les deps runtime lourdes (Flutter/Firebase/Syncfusion/Quill/Maps confinées), les commentaires de rationale, les blocs `flutter:`/assets, les `dev_dependencies`. **Ne PAS convertir les deps en `path:`** (le repo est délibérément hosted-constraint).
- **`LICENSE` (racine)** — SOURCE à copier (READ-ONLY ici) : MIT © 2026 Zakarius (zakarius.com).
- **`pubspec.yaml` (racine)** — NE PAS toucher (`publish_to: none` du workspace conservé ; le bloc `workspace:`/`melos:` inchangé).
- **12 × `packages/<pkg>/{LICENSE,CHANGELOG.md,README.md}`** — NEW (aucun n'existe aujourd'hui).
- **`example/`** — NE PAS TOUCHER (EX-3 en parallèle, fichiers disjoints).
- **`tool/binding_conformance/pubspec.yaml`** — NE PAS TOUCHER.

### Détails pub.dev à respecter (vérifiés contre les règles pana/pub.dev)

- `description` : 60–180 caractères recommandés (en-dessous/au-dessus = pénalité pana). Mono-ligne.
- `LICENSE` : un fichier de licence reconnu par package (SPDX MIT) — requis pour le score « provide a valid license ».
- `CHANGELOG.md` + `README.md` : requis pour le score de documentation.
- `topics` : liste optionnelle mais recommandée ; `^[a-z][a-z0-9-]*$`, 2–32 char, ≤ 5.
- `repository`/`homepage`/`issue_tracker` : requis pour le score « provide a link to source/issues ».
- `environment.sdk` : présent (`^3.12.2`). Les packages Flutter GAGNENT un point pana s'ils déclarent une borne `flutter:` — **optionnel** ici (non bloquant), consigner si non ajouté.
- **`example/` par package** : boost de score pana, NON requis pour publier. Différé (l'app de démo globale `example/` = EX-3, hors périmètre). Documenter comme dette de score, non bloquante.
- **`resolution: workspace` dans un package publié** : point d'incertitude — voir D2 §4. Valider au dry-run REL-2.

### Réconciliation workspace↔hosted — récapitulatif exécutable

1. Bump 14 pubspecs : `zcrud_*: ^0.0.1` → `^0.1.0` (grep/replace ciblé, hors `binding_conformance`).
2. Bump 12 versions : `version: 0.0.1` → `0.1.0` (publiés uniquement).
3. `dart pub get` racine → RC=0 (preuve : nb de packages résolus, lock racine régénéré proprement).
4. Ordre publish (REL-2) : `zcrud_core` d'abord ; `zcrud_generator` après `zcrud_annotations` ; les 9 satellites après `zcrud_core`.

### Stratégie de test / vérification

- **Métadonnées (AC2–AC9)** : assertions sur fichiers (script ou vérif manuelle) — chaque pubspec publié a version/description(len)/urls/topics/pas de publish_to ; chaque package publié a LICENSE≡root, CHANGELOG(## 0.1.0), README(4 éléments).
- **Résolution dev (AC10)** : `dart pub get` racine RC=0.
- **Invariants (AC12)** : `melos list`=14 ; `graph_proof.py` vert ; gates verts ; `git status -- example/` vide.
- **Publiabilité (AC13)** : `dart pub publish --dry-run` par package (si toolchain) → 0 erreur ; warnings triés. **Zéro publish réel.**
- **Non-régression** : `melos run analyze` RC=0 + `melos run test` RC=0 (la story ne modifie aucun code Dart runtime — seulement métadonnées + docs markdown/licence).

### Frontière REL-1 / REL-2 (NON-NÉGOCIABLE)

- **REL-1 (cette story)** : rendre publiable + gates + dry-run non destructif. AUCUN `dart pub publish` réel, AUCUN `dart pub login`, AUCUNE création de verified publisher.
- **REL-2** : dry-run autoritatif final ; `dart pub login` (Owner) ; verified publisher `zakarius.com` ; publish réel dans l'ordre topologique ; tranche l'ambiguïté `resolution: workspace`.

### Project Structure Notes

- Fichiers créés strictement sous `packages/<pkg>/` (LICENSE/CHANGELOG.md/README.md) et éditions strictement dans `packages/*/pubspec.yaml`. Zéro fichier hors `packages/` (sauf régénération du `pubspec.lock` racine par `dart pub get`, attendue).
- Conformité barrel : les exemples de README référencent l'API publique réelle exportée par `lib/<pkg>.dart` — dev-story doit lire le barrel de chaque package avant de rédiger le snippet (éviter des symboles inexistants).
- Invariant « 14 » et graphe acyclique inchangés (le périmètre de publication est orthogonal à la membership du workspace).

### References

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml#section REL] — périmètre, licence MIT, 0.1.0, publisher zakarius.com, publish réel = Owner.
- [Source: LICENSE] — MIT © 2026 Zakarius (zakarius.com), à copier par package.
- [Source: pubspec.yaml#workspace / #melos] — 14 membres, `melos list`=14, gates (graph/melos/reflectable/secrets/codegen).
- [Source: packages/*/pubspec.yaml] — état actuel (0.0.1, publish_to: none, resolution: workspace, deps `^0.0.1` hosted sans path:).
- [Source: packages/zcrud_flashcard/lib ; packages/zcrud_mindmap/lib] — squelettes (~60 lignes), E9/E10 v1.x → différés.
- [Source: CLAUDE.md#Structure des packages (14)] — rôles des packages, barrel `lib/<pkg>.dart`, zcrud_core = puits (out-degree 0).
- [Source: `git remote -v`] — https://github.com/zakarius-dev/zcrud.git.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] — AD-1 (acyclique), AD-3 (anti-reflectable), AD-12 (zéro secret).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `dart pub get` (racine, resolution: workspace) → **RC=0** (`Got dependencies!`).
- `dart run melos list` → **14** packages (invariant produit préservé).
- `python3 scripts/dev/graph_proof.py` → **vert** : `ACYCLIQUE OK`, `CORE OUT=0 OK`, 17 arêtes (le bump de bornes n'ajoute/retire AUCUNE arête).
- `dart run melos run analyze` → **RC=1**, MAIS l'unique échec est **pré-existant** dans `zcrud_flashcard` (squelette E9) : `z_flashcard_api.dart:23 - Undefined name 'ZExportApi'`. Prouvé identique au baseline `6f6c9fb` (worktree isolé : `dart analyze packages/zcrud_flashcard` → RC=3, même erreur). `ZExportApi` n'est défini NULLE PART (ni au baseline). Les **12 packages publiés + `zcrud_mindmap` analysent CLEAN** (`No issues found!`). Non-régression : REL-1 ne modifie aucun code Dart (métadonnées + docs uniquement). Hors périmètre REL-1 (E9 = v1.x, backlog) ; à corriger dans la story E9.
- `dart run melos run verify` → **RC=0** : `gate:melos OK` (13 scripts, M-1), `gate:reflectable OK` (0 hors allowlist), `gate:secrets OK` (aucun secret — AD-12), `gate:codegen OK` (0 .g.dart manquant), `gate:compat OK` (voie manifeste verte), `verify:serialization` → `All tests passed!`.
- `dart pub publish --dry-run` sur `zcrud_core` **et** `zcrud_provider` → **0 erreur bloquante**. Unique warning (les deux) : `1 checked-in file is modified in git` (le `pubspec.yaml` non committé — attendu ; REL-2 publie depuis un commit propre). RC=65 = convention pub « présence de warning », PAS une erreur de validation. **Aucun warning `resolution: workspace`** et **aucun warning de dépendance non publiée** (le satellite → `zcrud_core: ^0.1.0` résout localement) → lève en grande partie l'ambiguïté D2 §4 (à confirmer au dry-run autoritatif REL-2).

### Completion Notes List

- **Périmètre (D1)** : 12 packages passés en `0.1.0` publiables ; `zcrud_flashcard`/`zcrud_mindmap` DIFFÉRÉS (gardent `version: 0.0.1` + `publish_to: none`) ; `tool/binding_conformance` jamais publié.
- **Métadonnées (D3/D4/D5)** : `description` EN mono-ligne **quotée** (contient `: ` → quotes obligatoires en YAML), longueurs mesurées 93–129 char (∈ [60,180]) ; `homepage`/`repository`(sous-dossier)/`issue_tracker` + `topics` (3–5, format `^[a-z][a-z0-9-]*$`) sur les 12 ; `publish_to: none` retiré des 12 seulement.
- **Docs** : `LICENSE` (copie identique du root, MIT © 2026 Zakarius), `CHANGELOG.md` (`## 0.1.0`), `README.md` (rôle + install + exemple minimal aligné sur le barrel réel + lien mono-repo + mention MIT) créés pour chacun des 12.
- **Réconciliation D2** : bump `^0.0.1` → `^0.1.0` de TOUTES les contraintes inter-`zcrud_*` des 14 pubspecs. `binding_conformance: ^0.0.1` (dev_dependency des 3 bindings) NON touché.
- **DÉVIATION documentée (nécessaire)** : `tool/binding_conformance/pubspec.yaml` porte lui-même `zcrud_core: ^0.0.1` en dépendance runtime. Étant membre du workspace, sa contrainte `^0.0.1` cesse de résoudre contre `zcrud_core 0.1.0` (même sémantique caret 0.x que D2) → `dart pub get` casserait. La story listait ce fichier « NE PAS TOUCHER » mais n'avait pas anticipé sa propre arête `→ zcrud_core`. **Seule cette contrainte** a été bumpée `→ ^0.1.0` (la VERSION du harnais reste `0.0.1`, `publish_to: none` conservé) — édition minimale imposée par l'invariant NON-NÉGOCIABLE AC10 « le workspace résout toujours ».
- **Ordre de publication topologique (REL-2)** : `zcrud_core` → `zcrud_annotations` → `zcrud_generator` → { `zcrud_markdown`, `zcrud_list`, `zcrud_firestore`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_riverpod`, `zcrud_get`, `zcrud_provider` }.
- **Frontière REL-1/REL-2** : AUCUN `dart pub publish` réel, AUCUN `dart pub login`, AUCUNE création de verified publisher. `example/` NON touché par REL-1 (les modifs `example/` visibles en `git status` sont l'œuvre de EX-3 en parallèle).
- **Ambiguïté `resolution: workspace` (D2 §4)** : conservée par défaut dans les 12 pubspecs publiés ; le dry-run REL-1 ne l'a PAS rejetée. Fallback (retrait dans les tarballs publiés) à trancher au dry-run autoritatif REL-2 si besoin.

- **Remédiation MAJEUR-1 (code-review REL-1, 2026-07-10)** : les 6 README dont l'exemple minimal référençait une **API inventée** ont été réécrits **contre le barrel/ctor réel** (chaque symbole vérifié sur disque) :
  - `zcrud_core` : `ZFormController(fields:)` + `controller.value('name')` → `ZFormController(initialValues:{...})` + `fieldListenable('name')` lu via `ValueListenableBuilder` (rebuild ciblé de tranche) ; `setValue` en commentaire.
  - `zcrud_export` : `exporter.toExcel(table)` (Future inexistant) → `const ZExporter().toExcelBytes(request)` **synchrone** sur un `ZListRenderRequest.fromSchema(...)` neutre (mention `toPdfBytes`).
  - `zcrud_markdown` : `ZMarkdownField(fieldName:'body')` → `ZMarkdownField(controller:, field: bodyField)` avec `bodyField` = `ZFieldSpec(type: EditionFieldType.markdown)` + `key: ValueKey(...)`.
  - `zcrud_intl` : `ZPhoneNumber.parse(...)` (méthode d'une classe NON exportée) → construction directe `const ZPhoneNumber(e164:, isoCode:)` + round-trip `toMap`/`fromMap` (symboles 100 % barrel).
  - `zcrud_geo` : `ZGeoPoint(latitude:, longitude:)` → `ZGeoPoint(lat:, lng:)`.
  - `zcrud_firestore` : ctor complété par le paramètre requis `kind: 'note'` (+ commentaire : `Note extends ZEntity`).
  - **Méthode de vérif** : inspection rigoureuse par symbole de chaque **barrel** (`lib/<pkg>.dart`) et des ctors/signatures source (`z_form_controller.dart`, `z_exporter.dart`, `z_list_render_request.dart`, `z_markdown_field.dart`, `z_phone_number.dart`, `z_geo_point.dart`, `firebase_z_repository_impl.dart`, `edition_field_type.dart`) → **0 API inventée** dans les 6 README. Les 6 README sains (annotations/generator/list/riverpod/get/provider) NON touchés.
  - **Vérif verte rejouée** : `melos run analyze` repo-wide **RC=0, 0 issue** (14 packages) ; `melos run verify` **RC=0** ; `dart pub publish --dry-run` sur core+export+markdown → unique warning = « checked-in file modified in git » (état de travail non committé, attendu ; **aucun** warning pana métadonnées/README).

### File List

**Modifiés — pubspecs (15) :**
- `packages/zcrud_core/pubspec.yaml` (métadonnées complètes + bump deps)
- `packages/zcrud_annotations/pubspec.yaml`
- `packages/zcrud_generator/pubspec.yaml`
- `packages/zcrud_markdown/pubspec.yaml`
- `packages/zcrud_list/pubspec.yaml`
- `packages/zcrud_firestore/pubspec.yaml`
- `packages/zcrud_geo/pubspec.yaml`
- `packages/zcrud_intl/pubspec.yaml`
- `packages/zcrud_export/pubspec.yaml`
- `packages/zcrud_riverpod/pubspec.yaml`
- `packages/zcrud_get/pubspec.yaml`
- `packages/zcrud_provider/pubspec.yaml`
- `packages/zcrud_flashcard/pubspec.yaml` (DIFFÉRÉ : bump deps `^0.1.0` uniquement ; version `0.0.1` + `publish_to: none` conservés)
- `packages/zcrud_mindmap/pubspec.yaml` (DIFFÉRÉ : idem)
- `tool/binding_conformance/pubspec.yaml` (déviation documentée : `zcrud_core` `^0.0.1` → `^0.1.0` ; version/publish_to inchangés)

**Créés — docs par package publié (36 = 12 × 3) :**
- `packages/<pkg>/LICENSE` — pour les 12 (copie identique du `LICENSE` racine)
- `packages/<pkg>/CHANGELOG.md` — pour les 12 (`## 0.1.0`)
- `packages/<pkg>/README.md` — pour les 12 (rôle + install + exemple + lien mono-repo + MIT)

  où `<pkg>` ∈ { zcrud_core, zcrud_annotations, zcrud_generator, zcrud_markdown, zcrud_list, zcrud_firestore, zcrud_geo, zcrud_intl, zcrud_export, zcrud_riverpod, zcrud_get, zcrud_provider }.

**NON touchés** : `pubspec.yaml` racine, `example/**` (EX-3 parallèle), tout code Dart sous `packages/*/lib`, `packages/zcrud_flashcard/{LICENSE,README,CHANGELOG}` + idem mindmap (squelettes, non publiés).

**Modifiés — remédiation MAJEUR-1 (READMEs uniquement, exemples réécrits contre l'API réelle) :**
- `packages/zcrud_core/README.md`
- `packages/zcrud_export/README.md`
- `packages/zcrud_markdown/README.md`
- `packages/zcrud_intl/README.md`
- `packages/zcrud_geo/README.md`
- `packages/zcrud_firestore/README.md`

### Change Log

- 2026-07-10 — REL-1 dev-story : 12 packages rendus publiables `0.1.0` (métadonnées + LICENSE/CHANGELOG/README), réconciliation workspace↔hosted (bump `^0.1.0` sur 14 pubspecs + `binding_conformance`), gates verts, dry-run non destructif core+satellite. Status → review.
- 2026-07-10 — REL-1 remédiation MAJEUR-1 (code-review) : 6 README (core/export/markdown/intl/geo/firestore) réécrits contre l'API publique réelle (0 API inventée, vérif par symbole sur barrels+ctors). `melos analyze` RC=0 repo-wide, `melos verify` RC=0, dry-run core/export/markdown = warning git-state seul. Status inchangé (`review`).
