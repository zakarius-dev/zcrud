# Story ES-1.1 : [TÊTE BLOQUANTE] Remontée de `ZStudyFolder` vers `zcrud_study_kernel` + refactor non-régressif de `zcrud_flashcard`

Status: review

<!-- Note: Validation optionnelle. Lancer validate-create-story avant dev-story si souhaité. -->

## Story

As a **développeur-mainteneur (Zakarius)**,
I want **remonter `ZStudyFolder` + `validatePlacement` + la hiérarchie 2 niveaux + `ZStudySessionConfig`/`ZStudySessionSelector` (et l'enum `ZReviewMode` associé) de `zcrud_flashcard` vers un nouveau package `zcrud_study_kernel` dépendant du seul `zcrud_core`, en refactorant `zcrud_flashcard` pour en dépendre**,
so that **`zcrud_study`, `zcrud_document` et les futurs satellites puissent accéder au dossier d'étude et à la config de session sans tirer tout `zcrud_flashcard`, sans introduire de cycle ni régresser l'epic E9 déjà livré**.

Périmètre : **création du package `zcrud_study_kernel`** (nouveau, bas-niveau, dépend de `zcrud_core` + `zcrud_annotations` uniquement) + **refactor non-régressif de `zcrud_flashcard`** (dépend désormais du kernel, réexport transitoire depuis son barrel). Aucune autre feature. **Story de tête bloquante** : bloque ES-1.2/1.3/1.4 et tout ES-2..ES-11.

> **Métadonnées** — Taille : **L** · Statut initial : `backlog` · Parallélisation : **SÉQUENTIELLE STRICTE** (tête bloquante — aucune autre story en vol). Packages/fichiers : **nouveau** `packages/zcrud_study_kernel/` ; **refactoré** `packages/zcrud_flashcard/`. **Couvre :** FR-S1, (amorce FR-S2/FR-S3) · **AD :** AD-17, AD-18, AD-1, AD-26 · **SM-S2, SM-S7, NFR-S2, NFR-S10**.

---

## Acceptance Criteria

Repris et affinés depuis `epics.md#Story ES-1.1`, complétés du découplage rendu nécessaire par le couplage réel du code (cf. Dev Notes § « Décision de conception »).

### AC1 — Création du kernel & source unique des types

**Given** le monorepo avec `ZStudyFolder`, `ZStudyFolderHierarchy`/`validatePlacement`, `ZReviewMode`, `ZStudySessionConfig`, `ZStudySessionSelector` définis dans `zcrud_flashcard`
**When** on crée `zcrud_study_kernel` et on y **déplace** ces types
**Then** `zcrud_study_kernel` en est l'**unique source de vérité**, expose un barrel `lib/zcrud_study_kernel.dart`, et **ne dépend que de `zcrud_core` (+ `zcrud_annotations` pour les annotations de codegen)** — **aucune** dépendance vers `zcrud_flashcard`, ni vers un paquet lourd (Firebase/Syncfusion/Quill/Maps), ni vers un gestionnaire d'état.

### AC2 — Refactor non-régressif de `zcrud_flashcard` (réexport transitoire)

**Given** le déplacement effectué
**When** on refactore `zcrud_flashcard`
**Then** `zcrud_flashcard` **dépend de `zcrud_study_kernel`**, **ne définit plus** ces types localement, et son barrel `lib/zcrud_flashcard.dart` les **réexporte transitoirement** (source = kernel) **en préservant exactement la surface publique actuelle** — notamment les clauses `hide ZStudyFolderZcrud` et `hide ZStudySessionConfigZcrud` restent effectives (les extensions de registre générées ne doivent pas fuiter davantage qu'avant).

### AC3 — Acyclicité prouvée repo-wide (gate AD-1)

**Given** le refactor appliqué
**When** on rejoue `melos run generate` puis **`melos run analyze` ET `melos run verify` repo-wide**
**Then** les deux sont **verts (RC=0)** sur l'ensemble des packages (pas seulement par package)
**And** le sous-graphe reste **acyclique** : `zcrud_flashcard → zcrud_study_kernel → zcrud_core` (`scripts/dev/graph_proof.py` OK) — **preuve d'acyclicité archivée** dans les Completion Notes (AD-1/NFR-S2/SM-S2).

### AC4 — Non-régression E9 (nombre de tests ≥ baseline)

**Given** la suite de tests E9 de `zcrud_flashcard` **avant** refactor (baseline mesurée en début de story)
**When** on rejoue `flutter test` sur `zcrud_flashcard` **après** refactor
**Then** **RC=0** et le **nombre de tests exécutés est ≥ à la baseline** — **aucun test supprimé** pour faire passer ; les tests des 4 fichiers déplacés (`z_study_folder_test`, `z_study_folder_hierarchy_test`, `z_study_session_config_test`, `z_study_session_selector_test`) restent verts (mis à jour a minima pour le découplage `types`, cf. AC6, jamais retirés).

### AC5 — Contrôle cross-package des symboles publics

**Given** un package (ou l'app example) qui importait un symbole public de `zcrud_flashcard`
**When** on vérifie les références cross-package
**Then** **aucun symbole public supprimé n'est référencé sans réexport/migration** (contrôle explicite `grep` repo-wide, esprit régression `ZExportApi` E11a-3). *(Note : l'inspection disque en amont n'a trouvé AUCUN consommateur de ces types hors `zcrud_flashcard` — le réexport transitoire du barrel suffit ; à re-confirmer par le dev.)*

### AC6 — Découplage acyclique de `ZStudySessionConfig`/`ZStudySessionSelector` (obligatoire)

**Given** que `ZStudySessionConfig.types` référence `List<ZFlashcardType>?` et que `ZStudySessionSelector.selectFrom(...)` opère sur `ZFlashcard` (**arêtes retour vers `zcrud_flashcard`**)
**When** on remonte ces deux types dans le kernel
**Then** le couplage retour est **neutralisé** de façon à **préserver l'acyclicité** et le **format de persistance byte-identique** :
- `ZStudySessionConfig.types` conserve le **nom de champ `types`** (clé JSON `types` inchangée) mais son type d'élément devient **neutre `String`** (`List<String>?`) — les valeurs persistées (noms d'enum camelCase, ex. `"multipleChoice"`) sont **identiques** au wire actuel (round-trip conservé, AD-10) ;
- `ZStudySessionSelector.selectFrom(...)` opère sur un **port neutre `ZSessionCandidate`** défini dans le kernel (getters `String? folderId`, `String? subFolderId`, `List<String> tagIds`, `String typeKey`) ; le filtre de type compare `config.types.contains(candidate.typeKey)` ;
- `ZFlashcard` (dans `zcrud_flashcard`) **implémente `ZSessionCandidate`** (`String get typeKey => type.name;`) — l'ergonomie typée `ZFlashcardType` est restituée côté flashcard (extension/adaptateur), **jamais** dans le kernel.
**And** aucune API générique de sérialisation n'est introduite (AD-3 : pas de `generics` pour la (dé)sérialisation).

### AC7 — `zcrud_mindmap` inchangé (référence par `folderId` neutre)

**Given** `zcrud_mindmap` qui référence les dossiers
**When** on inspecte ses dépendances après refactor
**Then** il continue de référencer les dossiers par **`folderId` (clé neutre `String`)**, **ne dépend pas** de `ZStudyFolder`/`zcrud_study_kernel`, et **aucun cycle** n'apparaît (AD-18, note de graphe).

### AC8 — Test de résolution / modularité (NFR-S10 / SM-S7)

**Given** une app qui n'importe que `zcrud_flashcard` (ou, à terme, `zcrud_note` seul)
**When** on résout le graphe de dépendances (test de résolution reproductible — `dart pub deps` / `graph_proof.py`)
**Then** l'import **n'ajoute ni examens, ni communauté, ni Firebase** au graphe transitif — la preuve est archivée (assertion outillée, pas seulement narrative).

---

## Tasks / Subtasks

> Ordre **strict** (chaque étape suppose la précédente verte). Les chemins sont **absolus au repo**. Ne **committe pas** au milieu (commit en fin d'epic ES-1, code source uniquement).

### T0 — Mesurer la baseline E9 (avant toute modif) (AC4)
- [x] Depuis la racine : `dart run melos bootstrap` (état propre), puis `flutter test` dans `packages/zcrud_flashcard` — **noter le nombre exact de tests** (RC=0). C'est la baseline non-régression.
- [x] `python3 scripts/dev/graph_proof.py` et `dart run melos run analyze` **verts** avant modif (photo de départ).
- [x] `grep -rnE "ZStudyFolder|ZStudySessionConfig|ZStudySessionSelector|validatePlacement|ZReviewMode" --include="*.dart" packages/ example/ | grep -v packages/zcrud_flashcard/` → **confirmer 0 consommateur externe** (AC5). Consigner le résultat.

### T1 — Créer le squelette du package `zcrud_study_kernel` (AC1)
- [x] Créer `packages/zcrud_study_kernel/pubspec.yaml` :
  - `name: zcrud_study_kernel`, `publish_to: none`, `resolution: workspace`, `version: 0.1.0`, `environment: sdk: ^3.12.2`.
  - `dependencies:` `zcrud_core: ^0.1.0`, `zcrud_annotations: ^0.1.0` (+ `flutter: sdk: flutter` **si et seulement si** le barrel tire transitivement le SDK Flutter via `package:zcrud_core/domain.dart` — vérifier : les fichiers déplacés importent `package:zcrud_core/domain.dart`, surface pur-Dart ; s'aligner sur `zcrud_annotations` qui **n'ajoute pas** Flutter et tourne sous `dart test`. Choisir le runner de test en conséquence — cf. T6).
  - `dev_dependencies:` `zcrud_generator: ^0.1.0`, `build_runner: ^2.5.0`, et `test: ^1.25.0` **ou** `flutter_test: sdk: flutter` selon le point ci-dessus.
  - **PAS de `build.yaml`** : le builder `zcrud_model` s'applique via `auto_apply: dependents` (même convention que `zcrud_flashcard`, qui n'a pas de `build.yaml`). À n'ajouter QUE si `melos run generate` n'émet pas les `.g.dart` attendus.
- [x] Créer l'arborescence `packages/zcrud_study_kernel/lib/src/domain/`.
- [x] Créer le barrel `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (exports posés en T2/T3, en préservant les `hide *Zcrud` — cf. § Vigilance).

### T2 — Déplacer le Groupe A (types SANS arête retour) (AC1)
- [x] Déplacer **verbatim** vers `packages/zcrud_study_kernel/lib/src/domain/` :
  - `z_study_folder.dart` (importe seulement `package:zcrud_annotations/...` + `package:zcrud_core/domain.dart` — **aucun** couplage flashcard).
  - `z_study_folder_hierarchy.dart` (`validatePlacement`, importe `package:zcrud_core/domain.dart` + `z_study_folder.dart` relatif — reste valide, les deux fichiers voyagent ensemble).
  - `z_review_mode.dart` (enum neutre, aucune arête).
- [x] Supprimer les `.g.dart` correspondants de `zcrud_flashcard` (`z_study_folder.g.dart`) — ils seront **régénérés dans le kernel** (gitignorés).
- [x] Barrel kernel : `export 'src/domain/z_study_folder.dart' hide ZStudyFolderZcrud;`, `export 'src/domain/z_study_folder_hierarchy.dart';`, `export 'src/domain/z_review_mode.dart';` (reproduire la politique de `hide` actuelle).

### T3 — Déplacer + découpler le Groupe B/C (`ZStudySessionConfig`/`Selector`) (AC6)
- [x] Créer `packages/zcrud_study_kernel/lib/src/domain/z_session_candidate.dart` : **port neutre** `abstract interface class ZSessionCandidate { String? get folderId; String? get subFolderId; List<String> get tagIds; String get typeKey; }` (pur-Dart, doc en français).
- [x] Déplacer `z_study_session_config.dart` vers le kernel et **neutraliser** :
  - Retirer `import 'z_flashcard_type.dart';` ; **changer le type du champ `types`** de `List<ZFlashcardType>?` → `List<String>?` (**nom `types` inchangé** ⇒ clé JSON `types` inchangée ; valeurs = noms camelCase inchangés).
  - Conserver `import 'z_review_mode.dart';` + `export 'z_review_mode.dart';`, `part 'z_study_session_config.g.dart';`, le mixin `ZExtensible`, `fromMap`/`toMap`/`copyWith`, `==`/`hashCode`, les slots `extension`/`extra` (AD-4). Adapter `copyWith`/`==` au nouveau type d'élément `String`.
- [x] Déplacer `z_study_session_selector.dart` vers le kernel et **neutraliser** :
  - Remplacer `import 'z_flashcard.dart';` par un usage du **port `ZSessionCandidate`** ; `matches(ZSessionCandidate)` / `selectFrom(Iterable<ZSessionCandidate>)` ; le filtre type devient `config.types == null || config.types!.isEmpty || config.types!.contains(card.typeKey)`. Préserver la sémantique ET/plafond `count`/ordre d'entrée (identique à l'actuel).
- [x] Barrel kernel : exporter `z_session_candidate.dart`, `export 'src/domain/z_study_session_config.dart' hide ZStudySessionConfigZcrud;`, `export 'src/domain/z_study_session_selector.dart';`.

### T4 — Adapter `zcrud_flashcard` (dépendance + réexport + implémentation du port) (AC2, AC6)
- [x] `packages/zcrud_flashcard/pubspec.yaml` : ajouter `zcrud_study_kernel: ^0.1.0` aux `dependencies`. Mettre à jour les commentaires d'arêtes AD-1 (flashcard → study_kernel + core + markdown + export + annotations).
- [x] Supprimer les 4 fichiers déplacés de `packages/zcrud_flashcard/lib/src/domain/` (+ leurs `.g.dart`) : `z_study_folder.dart(.g.dart)`, `z_study_folder_hierarchy.dart`, `z_study_session_config.dart(.g.dart)`, `z_study_session_selector.dart`, `z_review_mode.dart`.
- [x] `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : **remplacer** les 4 exports `src/domain/...` par des **réexports transitoires** depuis le kernel, en **préservant les `hide`** :
  - remplacer `export 'src/domain/z_study_folder.dart' hide ZStudyFolderZcrud;` par un export ciblé depuis `package:zcrud_study_kernel/zcrud_study_kernel.dart` (via `show`/`hide` équivalents) — objectif : **surface publique de `zcrud_flashcard` inchangée**.
  - idem pour `z_study_folder_hierarchy`, `z_study_session_config` (`hide ZStudySessionConfigZcrud`), `z_study_session_selector`, `z_review_mode`.
- [x] `ZFlashcard` (`packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart`) : **`implements ZSessionCandidate`** avec `String get typeKey => type.name;` (les getters `folderId`/`subFolderId`/`tagIds` existent déjà — vérifier la conformité de signature, en particulier `List<String> get tagIds` non-nullable).
- [x] Restituer l'ergonomie typée `ZFlashcardType` **côté flashcard** (au choix, non-cassant) : extension `ZStudySessionConfigFlashcardX` sur `ZStudySessionConfig` (`List<ZFlashcardType> get flashcardTypes`, `ZStudySessionConfig withFlashcardTypes(List<ZFlashcardType>)` mappant vers/depuis `String`), à exporter par le barrel flashcard.
- [x] Corriger tout import interne de `zcrud_flashcard` pointant vers les anciens chemins relatifs (aucun trouvé à l'inspection hormis les fichiers déplacés eux-mêmes ; re-vérifier `src/data`, `src/presentation`).

### T5 — Déclarer le package dans le workspace (AC1, AC3)
- [x] `pubspec.yaml` racine : ajouter `- packages/zcrud_study_kernel` à la liste **explicite** `workspace:` (Dart workspace).
- [x] `melos.yaml` : glob `packages/**` déjà auto-découvrant — **rien à ajouter** (confirmer que le package apparaît dans `melos list`).
- [x] `dart run melos bootstrap` **AVANT** tout generate/analyze (résolution du nouveau package). **Ordre critique** (cf. Vigilance).

### T6 — Régénération codegen + vérif verte repo-wide (AC3, AC4)
- [x] `dart run melos run generate` → doit émettre `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.g.dart` et `z_study_session_config.g.dart` (extensions `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud`, `$...FieldSpecs`, `register...`). Vérifier l'enregistrement au `ZcrudRegistry`.
- [x] `dart run melos run analyze` **repo-wide** RC=0.
- [x] `dart run melos run verify` **repo-wide** RC=0 (inclut `graph_proof.py` acyclicité + `gate:secrets` + `verify:serialization`).
- [x] `flutter test` dans `packages/zcrud_study_kernel` (nouveaux tests, cf. Plan de tests) et `packages/zcrud_flashcard` (baseline ≥ T0) RC=0.
- [x] Archiver dans les Completion Notes : baseline vs après (nb de tests), sortie `graph_proof` (arête `zcrud_flashcard → zcrud_study_kernel → zcrud_core`), résultat du test de résolution NFR-S10.

### T7 — Tests de garde du kernel & résolution (AC6, AC7, AC8)
- [x] Écrire les tests du kernel (cf. Plan de tests) : round-trip `ZStudySessionConfig` (JSON byte-identique à E9), `validatePlacement`, sélecteur sur `ZSessionCandidate` factice.
- [x] Écrire/mettre à jour le test de résolution de graphe (NFR-S10/SM-S7) + preuve d'acyclicité.
- [x] Confirmer `zcrud_mindmap` : aucune dépendance kernel (grep pubspec + graph_proof).

---

## Dev Notes

### Décision de conception — POURQUOI ce n'est PAS un simple « déplacer de fichiers » (LIRE EN PREMIER)

L'inspection disque révèle un **couplage retour** que la formulation « remonter les 4 types » masque :

| Type déplacé | Arête retour vers `zcrud_flashcard` | Traitement |
|---|---|---|
| `ZStudyFolder`, `ZStudyFolderHierarchy`/`validatePlacement`, `ZReviewMode` | **Aucune** (imports = `zcrud_core` + `zcrud_annotations` seulement) | **Déplacement verbatim** (Groupe A) |
| `ZStudySessionConfig` | `types: List<ZFlashcardType>?` → dépend de `ZFlashcardType` (flashcard) | **Neutraliser `types` → `List<String>?`** (nom & wire inchangés) |
| `ZStudySessionSelector` | `selectFrom(Iterable<ZFlashcard>)` → dépend de `ZFlashcard` (flashcard) | **Port neutre `ZSessionCandidate`** implémenté par `ZFlashcard` |

Déplacer `ZStudySessionConfig`/`Selector` **verbatim** créerait le cycle interdit `zcrud_flashcard → zcrud_study_kernel → zcrud_flashcard` (viole **AD-1**, échoue `graph_proof.py`). AD-3 **interdit** les generics de sérialisation (pas de `ZStudySessionConfig<T>`) et **interdit** de polluer le kernel avec `ZFlashcardType` (concept flashcard-spécifique → viole la « granularité justifiée » d'**AD-17**). La neutralisation retenue est donc la **seule** compatible AD-1 + AD-3 + AD-17 + AD-26 **et** non-régressive au niveau wire :

- **`types` reste nommé `types`** ⇒ clé JSON `types` inchangée ; le générateur sérialisait déjà l'enum en `name` camelCase, donc `["multipleChoice", ...]` est **byte-identique** ⇒ round-trip et gate `verify:serialization` préservés (AD-10).
- **`ZSessionCandidate`** est un port pur (4 getters) ; `ZFlashcard` l'implémente trivialement (`typeKey => type.name`). Le sélecteur devient réutilisable par tout satellite study sans tirer flashcard.
- L'**ergonomie typée** (`ZFlashcardType`) est restituée **dans `zcrud_flashcard`** via extension — le domaine kernel reste neutre.

> **⚠️ Décision à ratifier par l'orchestrateur/architecte** : cette neutralisation modifie la **forme typée** (non le wire) de `ZStudySessionConfig.types` et la signature de `ZStudySessionSelector.selectFrom`. C'est un choix d'ingénierie imposé par le couplage réel, cohérent avec AD-18 (remontée) + AD-26 (config unique au kernel). Si l'orchestrateur préfère **minimiser le risque**, un **repli documenté** existe : garder `ZStudySessionSelector` **dans `zcrud_flashcard`** (il est intrinsèquement flashcard-lié) et ne remonter que `ZStudyFolder`+hiérarchie+`ZReviewMode`+`ZStudySessionConfig` (neutralisée) — c'est une **déviation partielle assumée** du littéral d'AD-18 mais fidèle à son **esprit** (partager le dossier + la config, pas l'algorithme de sélection flashcard). **Recommandation : Option principale (port neutre, conformité AD-18 pleine).** Consigner le choix retenu dans les Completion Notes.

### Contraintes d'architecture applicables (héritées + extension)

- **AD-1 (acyclique, NON-NÉGOCIABLE)** : `zcrud_study_kernel` ne dépend **que** de `zcrud_core` (+ `zcrud_annotations`). Toute nouvelle arête préserve l'acyclicité ; gate `melos analyze`+`verify` **repo-wide** avant `done`. [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-17, ligne 43]
- **AD-17 (décomposition fine)** : le kernel est bas-niveau, sa granularité doit être justifiée par réutilisation réelle — **ne pas** y remonter `ZFlashcardType`. [Source: #AD-17]
- **AD-18 (remontée option A + refactor non-régressif)** : réexport transitoire toléré, kernel = source unique, `mindmap` référence par `folderId` neutre, preuve d'acyclicité + non-régression E9. [Source: #AD-18, ligne 94-97]
- **AD-26** : **une seule** forme `ZStudySessionConfig` (`@ZcrudModel`, persistable, round-trip) vit dans le kernel ; l'égalité profonde pour une family Riverpod vit dans `zcrud_riverpod` (**pas ici**). [Source: architecture.md ligne 127]
- **AD-19 — HORS PÉRIMÈTRE ICI** : la conversion `ZSyncMeta` hors-entité relève d'**ES-1.3**. **NE PAS** l'entreprendre en ES-1.1 (sauf strict nécessaire au refactor). Déplacer les types dans leur forme actuelle. [Consigne orchestrateur + epics.md#ES-1.3]
- **AD-3 (codegen, `reflectable` banni, pas de generics de sérialisation)** : conserver `@ZcrudModel`/`@ZcrudField`/`@ZcrudId`, `part '*.g.dart'`, valeurs d'enum camelCase. [Source: architecture produit AD-3]
- **AD-10 (désérialisation défensive)** : `fromMap` doit rester tolérant (`mode` inconnu → `spaced`, éléments de `types` inconnus ignorés). Préservé par la neutralisation (String tolère tout ; le filtrage défensif d'enum inconnu, s'il vivait dans le codegen `listEnum`, se déplace côté flashcard lors du mapping typé — vérifier que `types` en `List<String>` conserve le round-trip et que le mapping flashcard `String→ZFlashcardType` ignore les inconnus).
- **AD-4 (extensibilité)** : préserver `extension`/`extra`/`ZExtensible` sur `ZStudySessionConfig`.

### État actuel des fichiers touchés (lus sur disque)

- `packages/zcrud_flashcard/lib/src/domain/z_study_folder.dart` (14 Ko, `@ZcrudModel(kind:'study_folder')`, `part z_study_folder.g.dart`) — **aucune** ref flashcard (uniquement docstring). Déplaçable verbatim.
- `.../z_study_folder_hierarchy.dart` (3 Ko, `validatePlacement`, hiérarchie 2 niveaux) — importe `zcrud_core/domain.dart` + `z_study_folder.dart` relatif.
- `.../z_study_session_config.dart` (9 Ko, `@ZcrudModel(kind:'study_session_config')`) — importe `z_flashcard_type.dart` (**arête retour**) + `z_review_mode.dart` ; `export 'z_review_mode.dart'`. Champs : `mode`(ZReviewMode), `folderId`, `tagIds`, `types`(List\<ZFlashcardType\>?), `count`, `extension`, `extra`.
- `.../z_study_session_selector.dart` (3 Ko, pur, `matches`/`selectFrom`) — importe `z_flashcard.dart` (**arête retour**) ; lit `card.folderId`/`subFolderId`/`tagIds`/`type`.
- `.../z_review_mode.dart` — enum neutre.
- Barrel `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` : exporte déjà les 4 fichiers avec `hide ZStudyFolderZcrud` / `hide ZStudySessionConfigZcrud`.
- `pubspec.yaml` flashcard : deps `zcrud_core`, `zcrud_markdown`, `zcrud_export`, `zcrud_annotations`, `flutter`. dev : `zcrud_generator`, `build_runner`, `flutter_test`. **Pas de `build.yaml`** (codegen via `auto_apply: dependents`).
- **Consommateurs externes** : **0 trouvé** (`grep` repo-wide + `example/`) — le réexport transitoire couvre tout.

### Points de vigilance (sources d'échec probables — À NE PAS RATER)

1. **Ordre `melos bootstrap`** : après T4/T5, lancer `dart run melos bootstrap` **AVANT** `generate`/`analyze`, sinon `zcrud_study_kernel` n'est pas résolu et les imports `package:zcrud_study_kernel/...` échouent faussement.
2. **Régénération codegen** : les `.g.dart` sont **gitignorés** — les supprimer de flashcard et laisser `melos run generate` les recréer **dans le kernel**. Vérifier que `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud`, `$...FieldSpecs` et `register...` sont bien émis côté kernel (sinon `toMap`/registre cassés).
3. **Clauses `hide` du barrel** : la surface publique de `zcrud_flashcard` doit rester **identique**. Les réexports transitoires doivent **reproduire** `hide ZStudyFolderZcrud` / `hide ZStudySessionConfigZcrud`. Décider aussi si le **barrel kernel** exporte ou cache ces extensions de registre — et aligner le réexport flashcard pour ne pas élargir la surface.
4. **`export 'z_review_mode.dart'`** dans le config : `ZReviewMode` doit rester **visible** via `zcrud_flashcard` (réexport) ET via le kernel. Ne pas le masquer.
5. **Flutter vs Dart pour les tests du kernel** : les fichiers déplacés importent `package:zcrud_core/domain.dart` (surface pur-Dart). Si le barrel kernel n'introduit pas le SDK Flutter, tester sous `dart test` (comme `zcrud_annotations`) ; sinon aligner sur `flutter test`. Choisir la dev-dep de test **cohérente** (le gate `verify:serialization` aiguille par présence de `flutter`).
6. **Round-trip wire de `types`** : ne **pas** renommer le champ `types` (garder la clé JSON). Ajouter/adapter un test round-trip prouvant `toMap()`/`fromMap()` byte-identiques à E9.
7. **`List<String> get tagIds` non-nullable** dans `ZSessionCandidate` : vérifier que `ZFlashcard.tagIds` a bien ce type (sinon adapter le port ou le getter).
8. **Ne pas toucher `zcrud_mindmap`** : il doit rester sur `folderId` String ; toute dépendance kernel introduirait un risque de cycle et viole AC7.
9. **Commit** : aucun commit en cours de story (règle epic) ; exclure `.g.dart`/`.freezed.dart`/`pubspec.lock` de package du futur commit d'epic.

### Project Structure Notes

- Nouveau package conforme à la structure canonique : barrel `lib/zcrud_study_kernel.dart`, impl `lib/src/domain/`. Préfixe de types `Z`. Fichiers snake_case. [Source: architecture.md ligne 155, 185]
- Ajout à `pubspec.yaml` racine `workspace:` (explicite) + auto-découverte `melos.yaml` (`packages/**`).
- Aucune variance détectée avec la structure unifiée ; l'ajout d'un port `ZSessionCandidate` est une extension neutre justifiée (découplage AD-1).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-1.1 (lignes 226-260)]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Epic ES-1 (ligne 222-225) ; FR-S1 (ligne 34) ; NFR-S10 (ligne 80)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-17 (ligne 89-92)]
- [Source: architecture.md#AD-18 (ligne 94-97) ; note graphe mindmap `folderId` (ligne 87)]
- [Source: architecture.md#AD-26 `ZStudySessionConfig` unique au kernel (ligne 127)]
- [Source: architecture.md#AD-1 gate repo-wide (ligne 43) ; diagramme `KER[zcrud_study_kernel] --> CORE` (ligne 62)]
- [Source: CLAUDE.md — invariants AD-1/AD-3/AD-4/AD-10, gates CI, règle « melos analyze+verify repo-wide à chaque commit d'epic » (régression `ZExportApi` E11a-3)]
- [Source disque : packages/zcrud_flashcard/lib/src/domain/{z_study_folder,z_study_folder_hierarchy,z_study_session_config,z_study_session_selector,z_review_mode}.dart ; barrel zcrud_flashcard.dart ; pubspec.yaml ; melos.yaml ; pubspec.yaml racine]

---

## Plan de tests

> RC=0 attendu partout. Non-régression = **priorité absolue** (tête bloquante).

### Non-régression E9 (`zcrud_flashcard`) — AC4
- **Baseline** mesurée en T0 (nombre exact de tests avant refactor). Après refactor : `flutter test packages/zcrud_flashcard` **RC=0** et **nb ≥ baseline**.
- Les 4 fichiers de test déplacés/impactés restent verts :
  - `z_study_folder_test.dart` (18) — inchangé (types déplacés mais réexportés via barrel ; import `package:zcrud_flashcard/zcrud_flashcard.dart` inchangé).
  - `z_study_folder_hierarchy_test.dart` (8) — inchangé.
  - `z_study_session_config_test.dart` (15) — **mis à jour a minima** pour `types` neutralisé : soit `types: const <String>['multipleChoice','trueOrFalse']`, soit via l'extension typée `withFlashcardTypes([...])`. **Aucun test retiré** ; assertions de round-trip conservées.
  - `z_study_session_selector_test.dart` (17) — les cartes de test sont des `ZFlashcard` (qui **implémente** `ZSessionCandidate`) ⇒ `selectFrom` les accepte ; adapter la ligne `types: <ZFlashcardType>[...]` de la config. Sémantique (dossier ∧ tags ∧ types, plafond `count`, ordre) **identique**.

### Tests de garde du kernel (`zcrud_study_kernel`) — nouveaux — AC1/AC6
- **Round-trip `ZStudySessionConfig`** : `fromMap(toMap()) == config` ; et **égalité byte du wire** vs corpus E9 (`{"types":["multipleChoice"], ...}`) — prouve la neutralisation non-cassante (AD-10, gate `verify:serialization`).
- **`validatePlacement`** : reprise des cas hiérarchie 2 niveaux (au moins les invariants clés) pour prouver le portage.
- **`ZStudySessionSelector` sur `ZSessionCandidate` factice** (implémentation de test locale au kernel, **sans** dépendre de flashcard) : filtres ET, plafond `count` (`null`/`0`/`<len`), préservation d'ordre — prouve la réutilisabilité neutre.
- **`ZStudyFolder`** : au moins un round-trip + un cas `@ZcrudField` défensif.

### Preuve d'acyclicité & résolution — AC3/AC7/AC8
- **`python3 scripts/dev/graph_proof.py`** RC=0 : sous-graphe `zcrud_flashcard → zcrud_study_kernel → zcrud_core`, **aucun** cycle ; `zcrud_study_kernel` sans arête sortante autre que `zcrud_core`/`zcrud_annotations`.
- **`melos run verify` repo-wide** RC=0 (graph_proof + secrets + serialization).
- **Test de résolution NFR-S10/SM-S7** (reproductible, archivé) : depuis un point n'important que `zcrud_flashcard` (ou le kernel seul), `dart pub deps`/`graph_proof` prouve l'absence de **Firebase / examens / communauté** dans le graphe transitif du kernel. Consigner la sortie.
- **`zcrud_mindmap`** : `grep`/pubspec prouvant **0** dépendance `zcrud_study_kernel` (AC7).

### Contrôle cross-package des symboles — AC5
- `grep -rnE "ZStudyFolder|ZStudySessionConfig|ZStudySessionSelector|ZReviewMode|validatePlacement" --include="*.dart"` repo-wide (hors flashcard/kernel) → **0** référence orpheline (réexport transitoire couvre les rares imports via barrel). Consigner.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story, effort high) — skill BMAD `bmad-dev-story` réellement invoqué.

### Debug Log References

- `dart run melos bootstrap` → 15 packages bootstrapped.
- `dart run melos run generate` → SUCCESS ; kernel émet `z_study_folder.g.dart` + `z_study_session_config.g.dart` (`types` généré en `List<String>` : deser `whereType<String>().toList()`, toMap `this.types`).
- `dart run melos run analyze` (repo-wide) → SUCCESS (corrigés : import inutilisé dans le test hiérarchie kernel ; `@override` sur `folderId`/`subFolderId`/`tagIds` de `ZFlashcard` ; ordre des `export` du barrel flashcard).
- `dart run melos run verify` (repo-wide) → RC=0 (graph_proof + gate:melos + gate:reflectable + gate:secrets + gate:codegen + gate:compat + verify:serialization).

### Completion Notes List

- **Choix de conception retenu : Option principale (port neutre `ZSessionCandidate`)** — conformité AD-18 pleine. `ZStudySessionSelector` remonté au kernel opère sur `ZSessionCandidate` ; le repli « sélecteur laissé dans flashcard » a été ÉCARTÉ (consigne orchestrateur ratifiée).
- **Neutralisation `types`** : `ZStudySessionConfig.types` passe de `List<ZFlashcardType>?` à `List<String>?` (nom de champ `types` et clé JSON inchangés ; valeurs camelCase identiques). Wire **byte-identique** à E9 prouvé par test kernel (`toMap()` == `{'mode','folder_id','tag_ids','types':['multipleChoice','trueOrFalse'],'count'}`). Ergonomie typée `ZFlashcardType` restituée côté flashcard via extension `ZStudySessionConfigFlashcardX` (`flashcardTypes` drop défensif AD-10 + `withFlashcardTypes`).
- **`ZFlashcard implements ZSessionCandidate`** (`typeKey => type.name`) ; getters `folderId`/`subFolderId`/`tagIds` déjà conformes.
- **Non-régression E9** : baseline = **165** tests `zcrud_flashcard` (RC=0) → après refactor **165** tests (RC=0), aucun test supprimé (les 4 fichiers de test des types déplacés restent verts, adaptés a minima pour `types` neutre).
- **Tests de garde kernel** : **38** tests `zcrud_study_kernel` (`dart test`, RC=0) — round-trip byte-identique config, `validatePlacement`, sélecteur sur `ZSessionCandidate` factice (sans dép flashcard), round-trip `ZStudyFolder`, résolution NFR-S10.
- **graph_proof** : `zcrud_flashcard → zcrud_study_kernel → zcrud_core` ; `ACYCLIQUE OK`, `CORE OUT=0 OK`, 23 arêtes, 15 nœuds. Aucune arête `study_kernel → flashcard`.
- **Résolution NFR-S10** (assertion outillée archivée) : fermeture transitive runtime de `zcrud_study_kernel` = `{zcrud_core, zcrud_annotations}` — **aucun** `zcrud_firestore`/`zcrud_flashcard`/satellite lourd.
- **AC5** : `grep` repo-wide → **0** consommateur externe des types déplacés (hors flashcard/kernel) ; réexport transitoire suffit.
- **AC7** : `zcrud_mindmap` inchangé — aucune dépendance kernel (pubspec + `grep` lib vides).
- **Runner de test kernel** : `dart test` retenu (surface pur-Dart via `package:zcrud_core/domain.dart`, aucune fuite du SDK Flutter — même convention que `zcrud_annotations`).
- **Hors-périmètre respecté** : conversion `ZSyncMeta` (AD-19) NON entreprise (relève d'ES-1.3).
- **Déviation mineure vs littéral T3** : `selectFrom` est **générique** `selectFrom<T extends ZSessionCandidate>(Iterable<T>)` (au lieu de `Iterable<ZSessionCandidate>`) pour **préserver le type concret d'entrée** en sortie (un satellite récupère ses propres entités, pas des `ZSessionCandidate` opaques) et garder l'accès `card.question` des tests E9 du sélecteur. Ce n'est PAS un generic de sérialisation (AD-3 respecté) ; strict sur-ensemble du contrat, opère toujours via le port neutre.

### File List

**Créés (`packages/zcrud_study_kernel/`)** :
- `pubspec.yaml`
- `analysis_options.yaml`
- `lib/zcrud_study_kernel.dart` (barrel)
- `lib/src/domain/z_session_candidate.dart` (port neutre — nouveau)
- `test/z_study_session_config_test.dart`
- `test/z_study_folder_test.dart`
- `test/z_study_folder_hierarchy_test.dart`
- `test/z_study_session_selector_test.dart`
- `test/z_kernel_resolution_test.dart` (NFR-S10)

**Déplacés `zcrud_flashcard/lib/src/domain/` → `zcrud_study_kernel/lib/src/domain/`** :
- `z_review_mode.dart` (verbatim)
- `z_study_folder.dart` (verbatim)
- `z_study_folder_hierarchy.dart` (verbatim)
- `z_study_session_config.dart` (déplacé + `types` neutralisé `List<String>`)
- `z_study_session_selector.dart` (déplacé + port `ZSessionCandidate`)

**Créés (`packages/zcrud_flashcard/`)** :
- `lib/src/domain/z_study_session_config_flashcard_x.dart` (ergonomie typée)

**Modifiés (`packages/zcrud_flashcard/`)** :
- `pubspec.yaml` (dep `zcrud_study_kernel`)
- `lib/zcrud_flashcard.dart` (réexport transitoire kernel + extension ; hides préservés)
- `lib/src/domain/z_flashcard.dart` (`implements ZSessionCandidate`, `typeKey`, `@override`)
- `test/z_study_session_config_test.dart` (types neutre + ergonomie typée)
- `test/z_study_session_selector_test.dart` (types en clés String neutres)

**Supprimés (gitignorés, régénérés dans le kernel)** :
- `packages/zcrud_flashcard/lib/src/domain/z_study_folder.g.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_study_session_config.g.dart`

**Modifiés (racine)** :
- `pubspec.yaml` (`workspace:` + `packages/zcrud_study_kernel`)

---

## Questions / clarifications pour l'orchestrateur (à trancher avant/pendant dev-story)

1. **Ratification de la neutralisation** (§ Décision de conception) : Option principale — remonter `ZStudySessionSelector` au kernel via le port neutre `ZSessionCandidate` (conformité AD-18 pleine) — **recommandée**. Repli — laisser le sélecteur dans `zcrud_flashcard` (déviation partielle assumée d'AD-18, moindre risque). Le dev doit choisir et **consigner**.
2. **Runner de test du kernel** : `dart test` (si surface pur-Dart, comme `zcrud_annotations`) vs `flutter test` (si le barrel `zcrud_core` tire transitivement le SDK Flutter). À confirmer empiriquement en T1/T6.
3. **Politique d'export des extensions de registre `*Zcrud`** dans le barrel kernel (exporter vs `hide`) : aligner sur ce que `zcrud_flashcard` masquait déjà (`hide ZStudyFolderZcrud` / `hide ZStudySessionConfigZcrud`) pour **surface publique inchangée**.
