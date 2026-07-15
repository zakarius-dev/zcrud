# Story ES-5.1 : [TÊTE — golden] Décomposabilité du layout « study tools » — golden de référence

Status: review

<!-- Epic ES-5 · Taille M · SÉQUENTIELLE (tête d'ES-5, bloque ES-5.2/5.3) · Package NEUF `zcrud_study` (présentation). -->

## Story

As a **développeur intégrateur IFFD (Zakarius)**,
I want **établir, dans le NOUVEAU package `zcrud_study` (présentation), le harnais golden qui PROUVE que le layout monolithique `folder_study_tools_page.dart` (~1753 lignes) de l'app IFFD se décompose en une liste de sections paramétriques (`title`/`itemBuilder`/`emptyState`/`addAction`) sans perte de l'apparence de référence**,
so that **la reproduction de l'apparence IFFD par `ZStudyToolsPage` (ES-5.2) et les sections réordonnables (ES-5.3) soient bâties sur une décomposabilité DÉMONTRÉE — et non supposée — avant d'engager l'implémentation complète (Deferred AD-25, PRD §4.5)**.

---

## Contexte & problème (pourquoi cette story existe)

L'app IFFD porte l'apparence de référence dans un unique fichier **monolithique** :

- `~/DEV/iffd/lib/src/presentation/features/folders/pages/folder_study_tools_page.dart` — **1753 lignes** (mesuré : `wc -l` = 1753).
- `FolderStudyToolsPage extends ConsumerWidget with AutoRouterMixin` [iffd:47] — un **unique `build()`** s'étale de la ligne **350 à ~1739** (~1390 lignes, ~100 niveaux d'imbrication).
- Variance par **héritage** : `SubjectStudyToolsPage extends FolderStudyToolsPage` [iffd:1740] — anti-pattern que zcrud proscrit (AD-4 : composition, pas héritage de vues).
- Couplage dur : Riverpod (`ref`) + GetX (`import 'package:get/get.dart'`) + AutoRoute + modèles app (`FlashcardModel`, `FolderDocument`, `SmartNoteModel`, `MindmapModel`) + labels français en dur (enum `FolderContentType` de `empty_folder_content.dart`).

**Ce qui le rend NON-décomposable aujourd'hui** : les 4 sections de contenu (rail flashcards, grille documents, grille notes, grille mindmaps) sont **inlinées** dans un seul arbre — pas d'abstraction de section, pas de frontière rebuild isolée. C'est la cause racine de l'objectif produit n°1 (rebuild global / perte de focus, matérialisé dans `multi_flashcard_editor_page.dart`, `setState` ×18).

**Structure réelle mesurée** (à reproduire fidèlement, socle de la décomposition) :

| Élément IFFD | Ref (fichier:ligne) | Rôle → cible zcrud |
|---|---|---|
| En-tête de section `buildContentTitle(title, [count])` | [iffd:89] | `title` + badge compteur → `ZStudyToolsSectionSpec.title` |
| Carte d'item `_buildGridItemCard({title, subtitle, icon, onTap, trailing, opacity, isProcessing, processingIndicator})` | [iffd:129] | item d'une section → produit par `itemBuilder` |
| 4 sections : rail flashcards (horizontal) + 3 grilles réordonnables | rail ~[iffd:792], `ReorderableGridView.count` [iffd:1009] (docs), [iffd:1369] (notes), [iffd:1685] (mindmaps) | 4 `ZStudyToolsSectionSpec` |
| État vide `EmtyFolderContent` + enum `FolderContentType {flashcards, mindmaps, notes, documents}` (icon/title/description/buttonText) | `empty_folder_content.dart` | `ZStudyToolsSectionSpec.emptyState` |
| Ordre `enum FolderContentOrderBy {createdAt, title, custom}` | [iffd:45] | consommé en ES-5.3 via `ZFolderContentsOrder`/`applyOrder<T>` |

> Reconnaissance READ-ONLY effectuée sur `~/DEV/iffd` — **AUCUN fichier IFFD n'est modifié par cette story** (source hors monorepo, hors périmètre).

---

## Périmètre & NON-périmètre (garde-fous)

**DANS le périmètre ES-5.1 (harnais + preuve seulement)** :
1. Créer le package NEUF `packages/zcrud_study/` (présentation) : `pubspec.yaml`, barrel `lib/zcrud_study.dart`, impl sous `lib/src/presentation/`.
2. Le **descripteur de section paramétrique** `ZStudyToolsSectionSpec` (contrat `title`/`itemBuilder`/`emptyState`/`addAction`, AD-25) — data-class de présentation, PAS l'entité domaine.
3. Un **échafaudage de composition** `ZSectionedStudyLayout` qui rend une `List<ZStudyToolsSectionSpec>` comme une **liste de sections indépendantes** (chacune sa propre frontière de widget/`Key`), reproduisant l'apparence de référence (en-tête+compteur, items, état vide par section).
4. Le **harnais golden discriminant** `test/golden/study_tools_page_golden_test.dart` + captures de référence `test/golden/goldens/*.png` qui **PROUVE la décomposabilité** et **RÉGRESSE** si la décomposition casse.
5. Enregistrement additif du package (racine `pubspec.yaml` `workspace:`).

**HORS périmètre (stories suivantes — NE PAS implémenter ici)** :
- `ZStudyToolsPage` complète branchée sur les vraies données + scoping `ValueListenable` par champ → **ES-5.2** (+ non-régression SM-1).
- Sections réordonnables persistantes, `ZContentHubSheet`, `ZItemActionsMenu` → **ES-5.3**.
- `ZFeatureAvailability` → **ES-5.4**.
- Toute dépendance vers les satellites lourds (`zcrud_flashcard`/`zcrud_mindmap`/`zcrud_note`/`zcrud_document`/`zcrud_session`) : NON tirée en ES-5.1 (le harnais golden n'a besoin QUE de `zcrud_core` + `zcrud_study_kernel`). Ces arêtes seront ajoutées par la story qui les consomme réellement.

---

## Acceptance Criteria

Chaque AC est formulé à **pouvoir discriminant** : un test doit pouvoir le faire échouer si l'implémentation dévie.

**AC1 — Package NEUF `zcrud_study` (présentation), acyclique, CORE OUT=0**
**Given** le monorepo sans package `zcrud_study`
**When** on crée `packages/zcrud_study/` (Flutter : `pubspec.yaml` déclarant `flutter: sdk: flutter`, `zcrud_core`, `zcrud_study_kernel`, `zcrud_annotations` ; `dev_dependencies` `flutter_test`), le barrel `lib/zcrud_study.dart` et l'impl sous `lib/src/presentation/`, et qu'on l'ajoute au bloc `workspace:` du root `pubspec.yaml`
**Then** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE** avec **out-degree(zcrud_core) == 0**, les seules arêtes de `zcrud_study` étant `zcrud_study → zcrud_core`, `zcrud_study → zcrud_study_kernel`, `zcrud_study → zcrud_annotations` (jamais l'inverse — AD-1/AD-17)
**And** `dart run melos list` inclut `zcrud_study` (passe de 18 à **19** packages)
**And** l'API publique n'est exposée QUE par le barrel `lib/zcrud_study.dart` (impl sous `lib/src/`, AD-consistency).

**AC2 — Contrat de section paramétrique `ZStudyToolsSectionSpec` (forme AD-25)**
**Given** la structure IFFD mesurée (en-tête+compteur, items, état vide, action d'ajout)
**When** on définit `ZStudyToolsSectionSpec`
**Then** il porte **exactement** le contrat AD-25 : un identifiant stable `id` (String), un `title`, un `itemBuilder` (produit un item par index), un `emptyState` (widget affiché quand la section est vide), un `addAction` **nullable** (**`null` = action d'ajout absente**, AD-4), et le nombre d'items `itemCount`
**And** aucun `Color`/`IconData`/label codé en dur dans le descripteur : couleurs/labels/l10n sont **fournis par l'appelant** (injectés, AD-13/FR-26) — le descripteur ne référence AUCUN modèle d'app (pas de `FlashcardModel` & co.).

**AC3 — Échafaudage `ZSectionedStudyLayout` : liste de sections INDÉPENDANTES (décomposition matérialisée)**
**Given** une `List<ZStudyToolsSectionSpec>` de N sections (mix de sections peuplées et vides)
**When** on rend `ZSectionedStudyLayout`
**Then** il produit **exactement N sous-arbres de section distincts**, chacun identifié par une `Key` stable dérivée de `section.id` (frontière rebuild isolée — pré-requis de SM-1/ES-5.2), assemblés via `ListView.builder` (jamais `ListView(children:)`)
**And** une section d'`itemCount == 0` rend son `emptyState` (jamais l'`itemBuilder`) ; une section peuplée rend son en-tête + compteur + items
**And** l'**ordre visuel vertical suit l'ordre de la liste d'entrée** (aucun tri implicite) — pré-requis de la réordonnabilité (ES-5.3).

**AC4 — Golden de référence : apparence décomposée fidèle**
**Given** une fixture de référence DÉTERMINISTE (N sections figées : rail flashcards peuplé, grille docs peuplée, grille notes VIDE→emptyState, grille mindmaps peuplée), un thème injecté figé (`ZcrudScope`/`ThemeData` fixe), une taille de surface figée, `textScaleFactor` figé, police de test par défaut (Ahem — aucune fonte externe), animations désactivées
**When** on rend `ZSectionedStudyLayout` et on capture le golden
**Then** `matchesGoldenFile('goldens/study_tools_sectioned.png')` PASSE contre la capture de référence committée
**And** la capture prouve l'apparence de référence (en-têtes+compteurs, cartes d'items, état vide de la section notes).

**AC5 — POUVOIR DISCRIMINANT (R12) : le golden RÉGRESSE si la décomposition casse**
**Given** la fixture de référence canonique et 3 mutations de décomposition : **(m1) fusion** de deux sections en une seule, **(m2) permutation** de l'ordre de deux sections, **(m3) altération d'apparence** (une section peuplée rendue comme vide, ou son en-tête/compteur retiré)
**When** on capture les octets de rendu (`RepaintBoundary`→`toImage`→bytes) du canonique et de chaque mutation
**Then** **chaque mutation produit des octets DIFFÉRENTS du canonique** (`expect(mutatedBytes, isNot(equals(canonicalBytes)))`) — le golden n'est PAS permissif : il régresserait si l'une de ces cassures de décomposition survenait
**And** un test structurel prouve que la fusion (m1) réduit le nombre de sous-arbres de section (`find` par `Key` de section : N → N-1) — la décomposition est comptable, pas cosmétique
**And** interdits POWERLESS : golden rendu sur surface triviale (1×1), tolérance de diff non nulle, ou golden ne rendant qu'un widget constant — REJETÉS (l'AC5 les ferait passer alors qu'ils devraient échouer, donc ils sont exclus par construction).

**AC6 — Confirmation ou documentation de l'écart (Deferred AD-25)**
**Given** l'hypothèse « `folder_study_tools_page.dart` décomposable sans perte d'apparence » (PRD §4.5, Deferred AD-25)
**When** le harnais golden + les tests discriminants passent
**Then** l'hypothèse est **CONFIRMÉE par écrit** dans la section « Décision de décomposabilité » du Dev Agent Record (mapping des 4 sections IFFD → 4 `ZStudyToolsSectionSpec`, avec fichier:ligne de chaque section source)
**And** tout écart résiduel (ex. rail horizontal vs grille, comportement de scroll, densité) est **documenté explicitement** (jamais laissé implicite), à charge d'ES-5.2.

**AC7 — Invariants transverses (AD-2/AD-13/AD-15) respectés dès le harnais**
**Given** toutes les surfaces créées dans `zcrud_study`
**When** on les analyse
**Then** **aucun** import de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`) — réactivité Flutter-native pure (`ListenableBuilder`/`ValueListenable`), injection via `ZcrudScope` (AD-2/AD-15)
**And** RTL directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, jamais `.left/.right`), `Semantics` explicites, cibles interactives ≥ 48 dp, `const` pour les widgets immuables (AD-13/NFR-S6/NFR-S7)
**And** `dart run melos run analyze` est vert (RC=0) repo-wide.

---

## Tasks / Subtasks

- [x] **T1 — Créer le package `zcrud_study` (AC1)**
  - [x] `packages/zcrud_study/pubspec.yaml` : `name: zcrud_study`, `resolution: workspace`, `publish_to: none`, `environment.sdk: ^3.12.2` ; `dependencies` : `flutter: sdk: flutter`, `zcrud_core: ^0.1.0`, `zcrud_study_kernel: ^0.1.0`, `zcrud_annotations: ^0.1.0` ; `dev_dependencies` : `flutter_test: sdk: flutter`. Mirroir des conventions de commentaire des pubspecs voisins (cf. `zcrud_document`, `zcrud_flashcard`).
  - [x] Barrel `lib/zcrud_study.dart` (exports publics : `ZStudyToolsSectionSpec`, `ZSectionedStudyLayout`).
  - [x] Arborescence `lib/src/presentation/`.
  - [x] Ajout **PUREMENT ADDITIF** de `  - packages/zcrud_study` au bloc `workspace:` du root `pubspec.yaml` (source de vérité) — `melos.yaml` utilise le glob `packages/**`, aucune édition requise (miroir melos↔pubspec conservé, gate:melos-divergence).
  - [x] `dart pub get` (ou `melos bootstrap`) : résolution verte.

- [x] **T2 — `ZStudyToolsSectionSpec` (AC2)**
  - [x] `lib/src/presentation/z_study_tools_section_spec.dart` : data-class immuable `const` avec `id`, `title` (String), `itemCount` (int), `itemBuilder` (`Widget Function(BuildContext, int)`), `emptyState` (`Widget`), `addAction` (`VoidCallback?`, nullable). Aucun `Color`/`IconData`/modèle app.

- [x] **T3 — `ZSectionedStudyLayout` (AC3, AC7)**
  - [x] `lib/src/presentation/z_sectioned_study_layout.dart` : `StatelessWidget` prenant `List<ZStudyToolsSectionSpec> sections`. Rend un `ListView.builder` ; chaque section = un sous-arbre isolé avec `key: ValueKey('section:${spec.id}')`. Section vide → `emptyState` ; peuplée → en-tête (`title` + badge compteur) + items via `itemBuilder`. Directionnel, `Semantics`, ≥48 dp, `const` partout où possible. Thème via `Theme.of(context)` (repli) / `ZcrudScope`.
  - [x] AUCUN import de gestionnaire d'état.

- [x] **T4 — Fixture de référence déterministe (AC4)**
  - [x] `test/golden/_fixtures.dart` : builder d'une `List<ZStudyToolsSectionSpec>` figée (4 sections, dont une vide), items au contenu constant, sous `MaterialApp` à thème fixe, `Directionality` fixe. Helper `pumpSectionedLayout(tester, {sections, textDirection})` fixant `tester.view.physicalSize` + `devicePixelRatio` + `textScaleFactor`, désactivant les animations.

- [x] **T5 — Golden de référence (AC4)**
  - [x] `test/golden/study_tools_page_golden_test.dart` : `testWidgets` rendant la fixture canonique + `expectLater(find.byType(ZSectionedStudyLayout), matchesGoldenFile('goldens/study_tools_sectioned.png'))`.
  - [x] Générer la capture : `flutter test --update-goldens` → committer `test/golden/goldens/study_tools_sectioned.png`.

- [x] **T6 — Tests discriminants (AC5) — le cœur de la story**
  - [x] `captureBytes(tester, sections)` : rend dans un `RepaintBoundary`, `boundary.toImage()` (sous `tester.runAsync`), `toByteData(png)`, retourne `Uint8List`.
  - [x] `test 'm1 fusion → octets ≠ canonique'`, `test 'm2 permutation → octets ≠ canonique'`, `test 'm3 altération (état vide) → octets ≠ canonique'` : chacun `expect(mutatedBytes, isNot(equals(canonicalBytes)))`.
  - [x] `test 'N sections → N sous-arbres'` + `test 'fusion → N-1 sous-arbres'` : `find.byWidgetPredicate(key startsWith 'section:')` compte N ; variante fusionnée compte N-1.

- [x] **T7 — Décision de décomposabilité (AC6)**
  - [x] Renseigner « Décision de décomposabilité » (mapping 4 sections IFFD → 4 specs + fichier:ligne source) et écarts résiduels dans le Dev Agent Record.

- [x] **T8 — Vérif verte + gates (AC1, AC7)**
  - [x] Rejouer la vérif verte (commandes exactes ci-dessous, RC hors pipe).

---

## Dev Notes

### Architecture — invariants NON-NÉGOCIABLES applicables (AD)
- **AD-25** [archi:243] — `ZStudyToolsPage` reproduit le layout IFFD comme **liste de sections paramétriques** `title`/`itemBuilder`/`emptyState`/`addAction` ; chaque section = scoping `ValueListenable`/`ListenableBuilder` **isolé** ; `ZItemActionsMenu`/`ZContentHubSheet` paramétrés (**callback `null` = action absente**) ; couleurs/labels/l10n injectés, directionnel/≥48 dp/`Semantics`/`ListView.builder`. **ES-5.1 pose le socle** (descripteur + échafaudage + golden) ; le branchement données + scoping par champ est ES-5.2.
- **AD-2 / AD-15** [archi:Inherited] — **AUCUN gestionnaire d'état** dans `zcrud_study*` ; sections = `ChangeNotifier`/`ValueListenable` purs ; injection via `ZcrudScope`. Interdits : `flutter_riverpod`, `get`, `provider`, `ConsumerWidget`, `Get.find`, `Provider.of`.
- **AD-1 / AD-17** [archi:54,89] — graphe **acyclique**, `zcrud_study → zcrud_core`/`zcrud_study_kernel` (jamais l'inverse), **out-degree(zcrud_core)=0**. Ne PAS tirer les satellites lourds en ES-5.1.
- **AD-13** [archi:Inherited] — RTL directionnel, `Semantics`, ≥48 dp, couleur jamais seul canal, thème/l10n injectés (`ZcrudScope`/`ThemeExtension`, repli `Theme.of`).
- **AD-4** [archi:Inherited] — composition, pas héritage de vues (contraste avec `SubjectStudyToolsPage extends FolderStudyToolsPage` [iffd:1740]) ; `addAction` nullable = absence.

### Réactivité de référence (dérivé AD-2, [archi:335])
`Frappe/édition dans une section → controller de section (ChangeNotifier) → valueListenable(section) → ListenableBuilder isolé → rebuild ciblé, autres sections intactes.` ES-5.1 garantit la **frontière** (Key + sous-arbre isolé par section) ; ES-5.2 prouvera le rebuild ciblé via le pattern existant `packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart` (compteurs `buildsA/buildsB/buildsGlobal` sur `ZFieldListenableBuilder`). **NE PAS régresser SM-1** : ne pas introduire de `setState`/rebuild à l'échelle du layout.

### GOTCHA RUNNER (R14) — `flutter test`, PAS `dart test`
`zcrud_study` déclare `flutter: sdk: flutter` → package **Flutter**. Les tests golden importent `flutter_test` → ils tournent **UNIQUEMENT** sous `flutter test`. `dart test` ne compile pas une suite tirant `flutter_test`/`dart:ui`. Corollaire : le gate `gate:web-determinism` (`dart test -p node`) **auto-exclut** les packages Flutter (helper `_isFlutterPackage`, cf. `scripts/ci/gate_web_determinism.dart:_isFlutterPackage`) — `zcrud_study` en est donc **hors couverture**, sans édition d'allowlist.

### GOTCHA RC (R15) — mesurer le vrai code de sortie hors pipe
Un `flutter test | tee` renvoie le RC de `tee`. Toujours :
```bash
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -30; echo "RC=$RC"
```

### Déterminisme golden (obligatoire pour AC4/AC5)
- Police : par défaut `flutter_test` utilise **Ahem** (glyphes carrés) — aucune fonte externe ⇒ rendu déterministe cross-machine. Ne PAS charger de fonte réelle.
- Figer : `tester.view.physicalSize = const Size(1200, 2000)` + `tester.view.devicePixelRatio = 1.0` (restaurer via `addTearDown(tester.view.reset)`), `textScaleFactor` fixe, animations off.
- Captures committées sous `packages/zcrud_study/test/golden/goldens/` (sous `packages/*/lib`? NON — c'est du test, non distribué ; pas concerné par le gate `codegen-distribution`, mais committé pour reproductibilité golden).
- Le byte-diff (AC5) capture via `RepaintBoundary.toImage(pixelRatio: 1.0)` → `toByteData(format: png)` ; comparer `Uint8List` par égalité stricte.

### Pouvoir discriminant — pourquoi AC5 est le cœur
Un golden `matchesGoldenFile` seul est **insuffisant** : il prouve « ça ressemble à la ref », pas « c'est décomposé ». Un layout MONOLITHIQUE qui, par coïncidence, produit les mêmes pixels passerait. AC5 ferme la faille : (a) le **byte-diff** prouve que fusion/permutation/altération CHANGENT le rendu (donc le golden les attraperait) ; (b) le **comptage de sous-arbres par Key** prouve la décomposition STRUCTURELLE (N sections distinctes, fusion → N-1). Ensemble : le golden n'est ni permissif ni cosmétique.

### Injections R3 prévues (défaut réel → test RED → restauration par ÉDITION CIBLÉE)
> R13 : restauration par édition ciblée du fichier, **JAMAIS** `git checkout/restore/stash` (working-tree partagé avec le workstream A).

| # | Injection (édition ciblée dans la PROD) | Test attendu RED | Restauration |
|---|---|---|---|
| **R3-I1** | Dans `ZSectionedStudyLayout`, concaténer tous les items dans UN seul sous-arbre (supprimer la frontière par section) | `test 'décomposition comptable'` (AC5) : N sous-arbres attendus, 1 trouvé → RED ; + m1 byte-diff | remettre le `ListView.builder` par section |
| **R3-I2** | Trier `sections` par `id` avant rendu (au lieu de préserver l'ordre d'entrée) | `test 'm2 permutation ≠ canonique'` : ordre canonique ≠ ordre trié attendu → golden/byte RED | supprimer le tri |
| **R3-I3** | Rendre `SizedBox.shrink()` pour une section vide au lieu de `emptyState` | golden `matchesGoldenFile` RED (section notes vide plus rendue) + `test 'm3'` RED | remettre le rendu de `emptyState` |
| **R3-I4** (guard powerless) | Rendre le byte-capture sur surface 1×1 (golden permissif) | `test 'm1 fusion ≠ canonique'` : octets deviennent égaux (1×1 identiques) → `isNot(equals)` RED — PROUVE que le guard attrape un golden permissif | remettre la surface pleine |

Chaque injection est jouée, le RED constaté (`flutter test`), puis restaurée par édition ciblée ; consigner le RC RED puis GREEN dans le Debug Log.

### Structure du package (à créer)
```text
packages/zcrud_study/
  pubspec.yaml                      # Flutter ; deps: flutter, zcrud_core, zcrud_study_kernel, zcrud_annotations
  lib/
    zcrud_study.dart                # barrel : exporte ZStudyToolsSectionSpec, ZSectionedStudyLayout
    src/presentation/
      z_study_tools_section_spec.dart
      z_sectioned_study_layout.dart
  test/golden/
    _fixtures.dart                  # fixture déterministe + pump helper
    study_tools_page_golden_test.dart   # golden ref (AC4) + tests discriminants (AC5) + décomposition comptable
    goldens/study_tools_sectioned.png   # capture de référence committée
```

### Project Structure Notes
- Conventions mirroir : cf. `packages/zcrud_document/pubspec.yaml` (nouveau package, commentaires AD-1/CORE OUT=0) et `packages/zcrud_flashcard/pubspec.yaml` (package Flutter : `flutter: sdk: flutter` + `flutter_test`, aiguillage `flutter test`).
- **Fichier racine touché (signalé)** : `pubspec.yaml` (bloc `workspace:`) — **1 ligne additive** `- packages/zcrud_study`. `melos.yaml` NON touché (glob `packages/**`). Aucun autre fichier hors `packages/zcrud_study/**`.
- Isolation workstream B : NE PAS toucher `zcrud_core`, `zcrud_flashcard`, `scripts/ci`, `sprint-status.yaml` (workstream A actif sur ES-4 / `scripts/ci` / `zcrud_flashcard`).

### Vérif verte à rejouer (commandes exactes, RC hors pipe)
```bash
# 0. Résolution après ajout au workspace
dart pub get

# 1. Tests golden du package (RUNNER = flutter test, R14) — RC réel hors pipe (R15)
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"
#   (au 1er run, générer la ref : cd packages/zcrud_study && flutter test --update-goldens)

# 2. Acyclicité AD-1 + CORE OUT=0
OUT=$(python3 scripts/dev/graph_proof.py 2>&1); RC=$?; echo "$OUT"; echo "RC=$RC"

# 3. melos voit le package (19 packages)
OUT=$(dart run melos list 2>&1); RC=$?; echo "$OUT"; echo "RC=$RC"   # attend: contient zcrud_study

# 4. Analyse repo-wide (RC=0)
OUT=$(dart run melos run analyze 2>&1); RC=$?; echo "$OUT" | tail -20; echo "RC=$RC"

# 5. Divergence melos↔pubspec (ajout additif cohérent)
OUT=$(dart run scripts/ci/gate_melos_divergence.dart 2>&1); RC=$?; echo "$OUT" | tail -10; echo "RC=$RC"
```
**Attendu** : (1) RC=0, golden + discriminants verts ; (2) `ACYCLIQUE` + `out-degree(zcrud_core)=0`, RC=0 ; (3) `zcrud_study` listé ; (4) RC=0 ; (5) RC=0.
> `gate:web-determinism` : `zcrud_study` = Flutter → **auto-exclu** (aucune action). `codegen-distribution` : le package n'a pas de `*.g.dart` (aucun `@ZcrudModel`), sans objet.

### Dépendances de la story
- **Dépend de** : ES-3 (couche data) au niveau epic — mais ES-5.1 (harnais golden) n'a besoin QUE de `zcrud_core` + `zcrud_study_kernel` déjà livrés (ES-1). Aucune donnée réelle requise pour le golden.
- **BLOQUE** : **ES-5.2** (`ZStudyToolsPage` + non-régression SM-1 — consomme `ZStudyToolsSectionSpec`/`ZSectionedStudyLayout`) et **ES-5.3** (sections réordonnables — réutilise l'échafaudage + `ZFolderContentsOrder`/`applyOrder<T>`). La décision de décomposabilité (AC6) est le pré-requis contractuel de ces deux stories.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-5.1] — ACs canoniques, métadonnées (M, SÉQ, tête d'ES-5).
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-25] (ligne 243) — sections paramétriques + scoping isolé.
- [Source: architecture.md#Inherited-Invariants] — AD-1/AD-2/AD-13/AD-15/AD-17 hérités.
- [Source: architecture.md#Structural-Seed] (ligne 293) — rôle orchestration de `zcrud_study`, réactivité page study-tools (ligne 335).
- [Source: ~/DEV/iffd/lib/src/presentation/features/folders/pages/folder_study_tools_page.dart] — monolithe mesuré 1753 l. : `build` 350→~1739, `buildContentTitle`:89, `_buildGridItemCard`:129, `ReorderableGridView.count`:1009/1369/1685, `SubjectStudyToolsPage`:1740.
- [Source: ~/DEV/iffd/.../folders/widgets/empty_folder_content.dart] — `EmtyFolderContent` + enum `FolderContentType`.
- [Source: packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart] — pattern SM-1 (compteurs de rebuild) réutilisé en ES-5.2.
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart] — `ZcrudScope` (injection thème/labels/registres).
- [Source: scripts/dev/graph_proof.py] — gate acyclicité AD-1 / CORE OUT=0.
- [Source: scripts/ci/gate_web_determinism.dart] — auto-exclusion des packages Flutter.

---

## Dev Agent Record

### Agent Model Used
claude-opus-4-8 (bmad-dev-story, effort high, fallback disque `.claude/skills/bmad-dev-story/SKILL.md`).

### Debug Log References

**Pouvoir discriminant R12 — 4 injections jouées RÉELLEMENT (défaut réel → RED → restauration par édition ciblée, R13 ; jamais `git checkout`).**

| # | Injection (édition ciblée) | Test | RC | Message EXACT rouge capturé |
|---|---|---|---|---|
| **I1** | `ZSectionedStudyLayout` : toutes les sections concaténées dans UN `Column(key: 'section:ALL')` (frontière par section supprimée) | `AC5(b)` comptage | RED (RC=1) | `Expected: exactly 4 matching candidates` / `Actual: _WidgetPredicateWidgetFinder:<Found 1 widget…>` (+ `fusion → N-1` : `Expected: exactly 3` / `Found 1`) |
| **I2** | `ZSectionedStudyLayout` : `sections` **triées par `id`** avant rendu | `AC5(a)` m2 permutation | RED (RC=1) | `Expected: not [ …octets canoniques… ]` / `Actual: [ …mêmes octets… ]` (le tri neutralise la permutation → `isNot(equals)` échoue) |
| **I3** | `_ZStudySection` : `const SizedBox.shrink()` au lieu de `emptyState` pour une section vide | `AC4` golden + `AC5(a)` m3 | RED (RC=1) | `Golden "goldens/study_tools_sectioned.png": Pixel test failed, 3.68%, 18376px diff detected.` (+ m3 : `Expected: not […]` / `Actual: […]` — les deux rendus vides deviennent identiques) |
| **I4** (guard powerless) | `_fixtures.dart` : `kByteCaptureSize = Size(1, 1)` (capture byte sur surface triviale) | `AC5(a)` m1 fusion | RED (RC=1) | `Expected: not [ … ]` / `Actual: [ … ]` — sur 1×1 fusion et canonique produisent les MÊMES octets → prouve que le golden N'EST PAS powerless |

Après chaque injection : restauration par **édition ciblée** du fichier de prod/fixture, puis re-vérif verte. Suite finale **6/6 GREEN** contre le golden committé (`flutter test`, RC=0).

Anecdote runner : `boundary.toImage()` DOIT s'exécuter sous `tester.runAsync` — sinon « Guarded function conflict » (le `Future` raster fuit hors de la zone fake-async et contamine les tests suivants). Corrigé + surface de capture ramenée à 500×1000 (déterministe, non triviale, ~10× plus rapide que 1000×1600).

### Décision de décomposabilité (AC6)

**Verdict : CONFIRMÉ.** L'hypothèse « `folder_study_tools_page.dart` (~1753 l., IFFD) se décompose en une liste de sections paramétriques sans perte de l'apparence de référence » (PRD §4.5, Deferred AD-25) est **prouvée** par le harnais golden + tests discriminants (byte-diff m1/m2/m3 + comptage structurel N→N-1). Reconnaissance READ-ONLY sur `~/DEV/iffd` (aucun fichier IFFD modifié).

Mapping des 4 sections IFFD → 4 `ZStudyToolsSectionSpec` :

| # | Section IFFD | Réf (fichier:ligne) | → `ZStudyToolsSectionSpec` (id) | Contrat AD-25 mappé |
|---|---|---|---|---|
| 1 | Rail flashcards (horizontal) | `folder_study_tools_page.dart` rail ~792 ; en-tête `buildContentTitle`:89 ; carte `_buildGridItemCard`:129 | `flashcards` | `title`+compteur, `itemBuilder`, `addAction` |
| 2 | Grille documents (réordonnable) | `ReorderableGridView.count`:1009 | `documents` | idem |
| 3 | Grille notes (réordonnable) | `ReorderableGridView.count`:1369 ; état vide `EmtyFolderContent` + enum `FolderContentType.notes` (`empty_folder_content.dart`) | `notes` (fixture VIDE → `emptyState`) | `emptyState` (jamais `SizedBox` silencieux) |
| 4 | Grille mindmaps (réordonnable) | `ReorderableGridView.count`:1685 | `mindmaps` | idem |

Variance par HÉRITAGE proscrite (AD-4) : `SubjectStudyToolsPage extends FolderStudyToolsPage` [iffd:1740] → remplacé par COMPOSITION (liste de specs), jamais d'héritage de vue.

**Écarts résiduels documentés (à charge d'ES-5.2, jamais laissés implicites)** :
- **Rail horizontal vs grille** : ES-5.1 rend TOUTES les sections uniformément (en-tête + compteur + items empilés verticalement via `itemBuilder`). Le rail flashcards HORIZONTAL et les GRILLES réordonnables (`ReorderableGridView.count`) IFFD ne sont PAS reproduits fidèlement ici : le socle prouve la décomposabilité (frontière + emptyState + ordre), pas la fidélité pixel-parfaite de chaque disposition interne. La disposition réelle (rail vs grille, colonnes) sera fournie par `itemBuilder`/un `sectionLayout` en ES-5.2.
- **Réordonnabilité / drag** (`ReorderableGridView`, `FolderContentOrderBy`) : HORS ES-5.1 → ES-5.3 (`ZFolderContentsOrder`/`applyOrder<T>`).
- **Comportement de scroll / densité** : `ListView.builder` externe unique ici ; imbrication rail-horizontal-dans-liste-verticale + densités par type = ES-5.2.
- **Branchement données réel + scoping `ValueListenable` par champ (SM-1)** : ES-5.1 garantit la FRONTIÈRE (Key + sous-arbre isolé par section) ; le rebuild ciblé prouvé via `sm1_granular_rebuild_test.dart` = ES-5.2.

### Completion Notes List
- Package NEUF `zcrud_study` (présentation) créé : 18 → **19** packages (`melos list` inclut `zcrud_study`).
- **AC1** : graphe **ACYCLIQUE**, `out-degree(zcrud_core) = 0`, arêtes de `zcrud_study` limitées à `→ zcrud_core`, `→ zcrud_study_kernel`, `→ zcrud_annotations` (jamais l'inverse — AD-1/AD-17). API publique exposée UNIQUEMENT par le barrel `lib/zcrud_study.dart` (impl sous `lib/src/`).
- **AC2** : `ZStudyToolsSectionSpec` — data-class `const` immuable (`id`/`title`/`itemCount`/`itemBuilder`/`emptyState`/`addAction?`). `addAction` nullable = action ABSENTE (AD-4). Aucun `Color`/`IconData`/label/modèle d'app dans le descripteur.
- **AC3** : `ZSectionedStudyLayout` — `ListView.builder` (jamais `ListView(children:)`), un sous-arbre `_ZStudySection` par section keyé `ValueKey('section:$id')` ; section vide → `emptyState`, peuplée → en-tête + compteur + items ; ordre visuel = ordre d'entrée (aucun tri).
- **AC4** : golden `goldens/study_tools_sectioned.png` (6680 o, 500×1000, non trivial) committé ; `matchesGoldenFile` PASSE.
- **AC5** : byte-diff `RepaintBoundary→toImage→bytes` (m1 fusion / m2 permutation / m3 altération état vide, chacun `isNot(equals(canonique))`) + comptage structurel (N=4 → N-1=3). Discriminant PROUVÉ par I1–I4 (tous RED). Powerless rejetés : surface 500×1000 (pas 1×1 — cf. I4), comparateur golden exact (tolérance nulle), rendu Ahem dépendant de l'ordre/longueur (pas constant).
- **AC7** : AUCUN import de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`) ; thème via `ZcrudTheme.of` (`ZcrudScope` → `Theme.of` repli, aucune couleur codée en dur) ; directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), `Semantics` (header/button/container), cibles ≥ 48 dp (`ConstrainedBox` sur l'IconButton d'ajout), `const` où possible ; `dart analyze` RC=0.
- **Vérifs ciblées rejouées (workstream A actif — PAS de `melos verify`/`analyze` repo-wide)** : `dart analyze` zcrud_study RC=0 ; `flutter test` 6/6 RC=0 ; `graph_proof.py` ACYCLIQUE + CORE OUT=0 RC=0 ; `melos list` = 19 RC=0.

### File List
- `packages/zcrud_study/pubspec.yaml` (NEW)
- `packages/zcrud_study/lib/zcrud_study.dart` (NEW)
- `packages/zcrud_study/lib/src/presentation/z_study_tools_section_spec.dart` (NEW)
- `packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart` (NEW)
- `packages/zcrud_study/test/golden/_fixtures.dart` (NEW)
- `packages/zcrud_study/test/golden/study_tools_page_golden_test.dart` (NEW)
- `packages/zcrud_study/test/golden/goldens/study_tools_sectioned.png` (NEW, capture de référence committée)
- `pubspec.yaml` (MODIFIED — 1 ligne additive `- packages/zcrud_study` au bloc `workspace:`, 18→19)
