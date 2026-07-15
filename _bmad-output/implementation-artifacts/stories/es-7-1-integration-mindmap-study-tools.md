---
baseline_commit: f29368c7a229bd17dfc5ab2ab37156a0407ccd6f
---
# Story ES-7.1 : Intégration mindmap dans study-tools (`ZStudyMindmapSection`)

Status: review

<!-- Skill : bmad-create-story (tool Skill, préfixe bmad-*) — INVOQUÉ RÉELLEMENT (pas de fallback disque). -->
<!-- Sprint-status NON touché par cette étape (édition ciblée réservée à l'orchestrateur). -->

## Story

As a **utilisateur**,
I want **visualiser/éditer la carte mentale d'un dossier composée dans `ZStudyToolsPage` par `folderId`**,
so that **retrouver mes mindmaps dans le layout study-tools sans dupliquer le moteur graphite**.

## Contexte & décision de séquencement (LIRE EN PREMIER)

**Périmètre validé sur disque** — ES-7.1 écrit **uniquement** `packages/zcrud_study/` (présentation). Elle
**compose** la surface publique **DÉJÀ LIVRÉE** de `zcrud_mindmap` :

- `ZMindmapView` (E10-2, lecture, graphite `DirectGraph` + vue liste a11y équivalente) —
  `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart`.
- `ZMindmapOutlineController` + `ZMindmapOutlineEditor` (E10-3, édition outline, forêt = source de vérité
  unique, `ChangeNotifier` pur, `TextEditingController` stables par `id`) —
  `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_{controller,editor}.dart`.

**DÉPENDANCE envers ES-7.2 : NON (aucune).** ES-7.1 ne consomme **aucun symbole que ES-7.2 doit livrer
d'abord**. Les AC d'ES-7.1 (« composer `ZMindmapView`/`ZMindmapOutlineController` **existants** ») portent
sur l'API **déjà en place**. Les comblements d'ES-7.2 (indent/outdent au clic, compact/plein-écran/
super-racine multi-forêt/zoom, décision rich-text OQ-S5) sont des **améliorations INTERNES à l'éditeur**
`zcrud_mindmap`, orthogonales à la **composition d'une section** dans study-tools. Quand ES-7.2 atterrit,
ses affordances arrivent **de façon transparente** via le widget réutilisé — **sans changement d'API pour
ES-7.1**. ⇒ ES-7.1 (`zcrud_study`) et ES-7.2 (`zcrud_mindmap`) sont **parallélisables** (fichiers
disjoints), mais **NON parallélisables avec ES-8.1/ES-9.*** (qui écrivent aussi `zcrud_study` — sérialiser).

> ⚠️ Un SEUL cas retournerait la conclusion : si l'intégration devait exposer, DANS la section, une
> affordance UX que seul ES-7.2 apporte (ex. bouton plein-écran/super-racine intégré au chrome de la
> section). **Ce n'est PAS le périmètre d'ES-7.1** (composition, pas enrichissement de l'éditeur). Si le dev
> découvre un tel besoin, il **NE le comble PAS ici** (SM-S4/R21 : combler dans le package d'origine) : il le
> consigne comme dette et laisse ES-7.2 le porter.

## Acceptance Criteria

Chaque AC est à **POUVOIR DISCRIMINANT** (R12) : il **rougit** quand on neutralise la ligne de prod qu'il
protège (cf. § « Injections R3 prévues »). Ancrage **R20** : ES-7.1 est un **adaptateur mince** au-dessus de
widgets qui portent DÉJÀ des garanties (`ZMindmapView` lecture seule ; `ZMindmapOutlineController` controllers
stables) — les AC ci-dessous ancrent leurs assertions sur les **lignes PROPRES à ES-7.1**
(`ZStudyMindmapSection`), jamais sur une propriété protégée par le widget réutilisé.

**AC1 — Composition lecture par `folderId` (clé NEUTRE), zéro réimplémentation graphite.**
**Given** un dossier portant une carte mentale (`ZMindmap`/`List<ZMindmapNode>`) et son `folderId` (`String`),
**When** `ZStudyMindmapSection` compose la section en mode lecture,
**Then** l'arbre rend **exactement un** `ZMindmapView` (graphite, E10-2) alimenté par la carte fournie,
**And** le sous-arbre de la section est identifié par une **clé NEUTRE dérivée du `folderId`**
(`ValueKey('mindmap:<folderId>')`) — **jamais** par l'entité `ZStudyFolder` du kernel (préserve AD-1 :
`zcrud_study → zcrud_mindmap` ne réintroduit **aucune** arête vers une entité de `zcrud_study_kernel` via
mindmap ; `zcrud_mindmap` reste couplé aux dossiers par `folderId` neutre).

**AC2 — Flowchart legacy IFFD NON porté ; graphite standard, atteint UNIQUEMENT via `zcrud_mindmap`.**
**Given** le mode flowchart legacy IFFD (`flutter_flow_chart`/`graphview`),
**When** on décide de sa portée dans ES-7.1,
**Then** il **n'est pas** porté : un **verrou-source** (scan de `z_study_mindmap_section.dart` **et** de
`packages/zcrud_study/pubspec.yaml`) prouve l'**absence** de tout `import`/dépendance
`flutter_flow_chart`/`graphview`, **And** `graphite` n'apparaît **pas** en dépendance directe de
`zcrud_study` (il est atteint **transitivement** via `zcrud_mindmap` seulement — AD-1, arête justifiée).

**AC3 — Cycle de vie du `ZMindmapOutlineController` DÉTENU par la section (édition, AD-2/AD-15, ancrage R20).**
**Given** une section en mode édition **sans** controller injecté,
**When** la section subit une **tempête de rebuilds** (≥ 5 rebuilds du parent) puis est démontée,
**Then** le `ZMindmapOutlineController` **possédé** est créé **UNE seule fois** (`identical` avant/après la
tempête) **et disposé exactement une fois** au démontage ; **And** un controller **injecté** par l'appelant
est **UTILISÉ tel quel** et **JAMAIS disposé** par la section (propriété de l'appelant).
*(Ancrage R20 : l'assertion porte sur l'identité de l'objet DÉTENU par `ZStudyMindmapSection`, capturée par
la section — pas sur une garantie interne de `ZMindmapOutlineController`. Miroir du patron owned/injected de
`ZStudyToolsPage`/`ZFormController`, ES-5.2.)*

**AC4 — Bascule lecture ⇄ édition LOCALE (Flutter-native), frontière rebuild SM-1 préservée.**
**Given** une `ZStudyToolsPage` contenant la section mindmap **et** une autre section instrumentée d'un
compteur de builds,
**When** on bascule le mode de la section mindmap (lecture ⇄ édition) via son chrome,
**Then** la bascule est pilotée par un `ValueNotifier`/`ValueListenableBuilder` **LOCAL à la section**
(aucun `setState` au niveau page/section, aucun gestionnaire d'état) ⇒ **seul** le sous-arbre de la section
mindmap se reconstruit ; **And** le compteur de builds de l'autre section reste **inchangé** (== sa valeur
initiale), zéro perte de focus (SM-1).
*(Ancrage R20 : la « non-reconstruction des autres sections » est partiellement garantie par la frontière
`ValueKey('section:<id>')` d'ES-5.1 — DONC l'assertion discriminante d'ES-7.1 est que le mode vit dans un
notifier LOCAL à `ZStudyMindmapSection` : l'injection R3-I4 lève le mode au parent via `setState` et prouve
la régression du sibling.)*

**AC5 — Chrome de section : thème/labels/sémantique INJECTÉS (FR-26/AD-13), cibles ≥ 48 dp, directionnel.**
**Given** une section mindmap avec bascule lecture/édition,
**When** on rend son chrome (bouton de bascule, en-tête, état vide),
**Then** couleurs/espacements viennent de `ZcrudTheme.of` (repli `Theme.of`) — **aucune** `Color`/valeur
d'espacement codée en dur ; **And** le libellé sémantique de la bascule et le libellé d'état vide sont
**INJECTÉS** (aucun `'Éditer'`/`'Edit'`/`'Voir'` codé en dur) ; **And** la cible interactive de bascule est
**≥ 48 dp** et le padding est **directionnel** (`EdgeInsetsDirectional`, `TextAlign.start`).

**AC6 — `nodeContentBuilder` transmis tel quel ; `content` de nœud reste texte brut (AD-28).**
**Given** un `nodeContentBuilder` custom injecté à la section,
**When** la section compose `ZMindmapView`/`ZMindmapOutlineEditor`,
**Then** ce builder est **FORWARDÉ** au widget composé (le contenu custom est effectivement rendu) ;
**And** ES-7.1 **n'ajoute AUCUN** champ rich-text au modèle de nœud et **n'importe PAS** `zcrud_markdown` ni
n'introduit de `ZCodec` de `content` — le rich-text éventuel reste un **slot opt-in câblé CÔTÉ APP** via ce
`nodeContentBuilder` (AD-28 : `content` de nœud = **texte brut** dans `zcrud_mindmap`, non porté par ES-7.1).
*(Verrou-source : `z_study_mindmap_section.dart` ne contient aucun `import ...zcrud_markdown...`.)*

**AC7 — Fabrique de `ZStudyToolsSectionSpec` réutilisant le vocabulaire de sections AD-4 déjà livré.**
**Given** l'API sections/actions d'ES-5 (`ZStudyToolsSectionSpec`, `addAction` `null` = action absente AD-4),
**When** l'app veut insérer la mindmap comme **une section** de `ZStudyToolsPage`,
**Then** `ZStudyMindmapSection` expose une fabrique (`sectionSpec(...)`) retournant un
`ZStudyToolsSectionSpec` (`itemCount == 1`, `itemBuilder` rendant la section mindmap, `emptyState` = état vide
INJECTÉ, `addAction` transmis — `null` ⇒ action ABSENTE, jamais un no-op) — **réutilisé**, jamais une
réimplémentation inline du layout (AD-4/AD-25).

## Tasks / Subtasks

- [x] **T1 — Arête AD-1 `zcrud_study → zcrud_mindmap` (AC1, AC2)**
  - [x] Ajouter `zcrud_mindmap: ^0.1.0` à `dependencies:` de `packages/zcrud_study/pubspec.yaml`, avec
        commentaire justifiant l'arête (composition study-tools, FR-S26, AD-28/AD-4) et rappelant **⛔ pas de
        `graphite`/`flutter_flow_chart`/`graphview` en dépendance directe** (graphite atteint transitivement).
  - [x] `dart pub get` / `melos bootstrap` ; vérifier `scripts/dev/graph_proof.py` : **ACYCLIQUE**, **CORE
        OUT=0**, arête ajoutée (+1 → 42), `melos list` inchangé (20 packages).
- [x] **T2 — `ZStudyMindmapSection` (widget de composition) (AC1, AC3, AC4, AC5, AC6)**
  - [x] Créer `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart`.
  - [x] Signature : `folderId` (`String` requis, clé neutre) ; `mindmap`/`roots` (source de forêt) ;
        `initialMode` (`enum ZStudyMindmapMode` lecture/édition **local au package**) ; `viewMode`
        (`ZMindmapViewMode`) ; `nodeContentBuilder?` (forwardé) ; `outlineController?` (injecté, NON disposé) ;
        `viewConfig`/`outlineLabels` mindmap ; `emptyLabel`/`enterEditSemanticLabel`/`enterReadSemanticLabel`
        INJECTÉS ; `onSave?`/`onChanged?` remontés à l'éditeur.
  - [x] `StatefulWidget` **uniquement** pour : (a) cycle de vie du `ZMindmapOutlineController` **possédé**
        (créé `initState` ssi non injecté, disposé `dispose` ssi possédé) ; (b) `ValueNotifier<ZStudyMindmapMode>`
        **local**. `didUpdateWidget` : transitions possédé↔injecté défensives (jamais recréé en rebuild ordinaire).
  - [x] `build` : `ValueListenableBuilder<mode>` → lecture ⇒ `ZMindmapView(...)` ; édition ⇒
        `ZMindmapOutlineEditor(controller: <possédé|injecté>, ...)`. **Aucun** `ListenableBuilder(listenable:
        controller)` enveloppant global.
  - [x] Clé neutre du sous-arbre : `KeyedSubtree(key: ValueKey('mindmap:$folderId'))`. Chrome de bascule :
        `IconButton` dans `ConstrainedBox(minWidth/minHeight ≥ 48)`, `Semantics` label **injecté**, `tooltip` =
        même label, `EdgeInsetsDirectional`, couleur `ZcrudTheme.of` (repli `Theme.of`).
  - [x] **Aucun** `import` `zcrud_markdown`/`flutter_flow_chart`/`graphview`/`graphite` (AC2/AC6).
- [x] **T3 — Fabrique `sectionSpec(...)` → `ZStudyToolsSectionSpec` (AC7)**
  - [x] Méthode statique retournant `ZStudyToolsSectionSpec(id, title, itemCount: 1, itemBuilder → ZStudyMindmapSection,
        emptyState injecté, addAction transmis (null = absent), addActionIcon/addActionSemanticLabel transmis)`.
        Aucun tri, aucune réordonnabilité (section singleton, `axis` vertical par défaut).
- [x] **T4 — Barrel (AC1, AC7)**
  - [x] Exporter `src/presentation/z_study_mindmap_section.dart` dans `packages/zcrud_study/lib/zcrud_study.dart`.
- [x] **T5 — Tests `flutter test` (R14) — `packages/zcrud_study/test/z_study_mindmap_section_test.dart`**
  - [x] AC1 : `ZMindmapView` unique rendu ; `find.byKey(ValueKey('mindmap:$folderId'))` présent ; deux
        `folderId` distincts ⇒ deux clés distinctes.
  - [x] AC2 : verrou-source (lecture `z_study_mindmap_section.dart` + `pubspec.yaml` : absence des imports
        `package:flutter_flow_chart`/`package:graphview`/`package:graphite` ; `graphite`/`flutter_flow_chart`/
        `graphview` absents des `dependencies:` via regex `^\s+pkg:` ignorant les commentaires ; arête
        `zcrud_mindmap` présente).
  - [x] AC3 : `controller` capturé via l'éditeur composé avant tempête (6 rebuilds), `identical` après ;
        `controller.isDisposed` == true au démontage (possédé) ; controller injecté ⇒ `isDisposed` == false.
  - [x] AC4 : `ZStudyToolsPage` avec section mindmap + section-sonde (compteur de builds, on-screen en premier) ;
        bascule via `find.byTooltip` du label injecté ; sonde `buildCount` inchangé ; view→editor confirmé.
  - [x] AC5 : label sémantique == label injecté (`find.bySemanticsLabel`) ; `ConstrainedBox` de la section
        minWidth/minHeight ≥ 48 ; couleur d'icône == `ZcrudTheme.labelColor` injecté (FR-26).
  - [x] AC6 : `nodeContentBuilder` custom (marqueur `Key('custom-<id>')`) rendu par le `ZMindmapView` composé ;
        verrou-source absence `package:zcrud_markdown`.
  - [x] AC7 : `sectionSpec(...)` → `itemCount == 1` ; `addAction` transmis (identique) ; `addAction: null` ⇒
        `spec.addAction == null` ; rendu dans `ZSectionedStudyLayout` OK.
- [x] **T6 — Vérif verte rejouée** (cf. § dédiée) + mise à jour File List.

## Injections R3 prévues (mutation → AC rouge → restauration)

Pour chaque AC load-bearing, l'injection **fidèle** de la panne + preuve de rougissement, puis restauration
(→ vert). À exécuter réellement (RC hors pipe, R15).

| Ref | AC | Mutation (ligne de prod neutralisée) | Attendu |
|-----|----|--------------------------------------|---------|
| R3-I1 | AC1 | Remplacer `ValueKey('mindmap:$folderId')` par une clé constante (ou la retirer) | `find.byKey` échoue / deux folderId ⇒ même clé → **RC=1** |
| R3-I2 | AC1 | Remplacer `ZMindmapView(...)` par un `Placeholder`/réimplémentation inline | `find(ZMindmapView)` absent → **RC=1** |
| R3-I3 | AC2 | Ajouter `import 'package:graphview/graphview.dart';` (ou `graphview:` au pubspec) | verrou-source → **RC=1** |
| R3-I4 | AC3 | Créer le `ZMindmapOutlineController` **dans `build()`** (au lieu d'`initState`) | `identical(before, after)` faux après tempête → **RC=1** (« controller recréé sous rebuild ⇒ AD-2 violé ») |
| R3-I5 | AC3 | Disposer le controller **injecté** dans `dispose()` | sonde de dispose sur controller injecté déclenchée → **RC=1** |
| R3-I6 | AC4 | Lever le `mode` au parent via `setState` (au lieu du `ValueNotifier` local) | `buildCount` de la section-sonde incrémenté → **RC=1** |
| R3-I7 | AC5 | Coder en dur `semanticLabel: 'Éditer'` (au lieu du label injecté) | label observé != label injecté → **RC=1** |
| R3-I8 | AC5 | Ramener la cible de bascule à `< 48 dp` | assert taille ≥ 48 → **RC=1** |
| R3-I9 | AC6 | Ne PAS forwarder `nodeContentBuilder` (laisser le défaut) | marqueur custom absent de l'arbre → **RC=1** |
| R3-I10 | AC7 | `sectionSpec` renvoie `itemCount: 0` (ou ignore `addAction`) | `itemCount == 1` / `addAction` transmis → **RC=1** |

> **Piège R20 explicitement traité** : NE PAS ancrer AC3 sur le fait que `ZMindmapOutlineController` détient
> des `TextEditingController` stables (c'est SA garantie, elle **masquerait** un churn de la section) —
> ancrer sur l'**identité du controller détenu par `ZStudyMindmapSection`** capturée par le test (R3-I4).
> De même AC4 : NE PAS se contenter du fait que `ZSectionedStudyLayout` keye ses sections (garantie ES-5.1) —
> l'injection R3-I6 doit prouver que la régression vient bien du mode lifté hors de la section.

## Dev Notes

### Architecture & invariants (NON-NÉGOCIABLES)
- **AD-1 (graphe acyclique, CORE OUT=0)** : arête **nouvelle** `zcrud_study → zcrud_mindmap`.
  `zcrud_mindmap` dépend de `zcrud_core` **seul** (vérifié : `packages/zcrud_mindmap/pubspec.yaml`) — **aucun
  cycle**, **aucun** nouveau CORE OUT. `graphite`/`flutter_flow_chart`/`graphview` restent **confinés** hors
  de `zcrud_study` (graphite transitif via `zcrud_mindmap` uniquement). [Source: architecture.md#AD-1 ; #Graph]
- **AD-2/AD-15 (réactivité Flutter-native)** : aucun `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/
  `Get.`/`Provider.of`. État de vue = `ValueNotifier`/`ValueListenableBuilder` locaux ; controller possédé
  créé/disposé hors `build`. Miroir du patron owned/injected de `ZStudyToolsPage` (ES-5.2). [Source:
  architecture.md#AD-2 ; z_study_tools_page.dart]
- **AD-4 (extensibilité, String opaque, callback null = absent)** : `folderId` = `String` opaque ;
  `addAction` `null` = action ABSENTE (jamais no-op) ; réutilise `ZStudyToolsSectionSpec`. `abstract
  interface` (pas `sealed`) si une interface est introduite. [Source: architecture.md#AD-4 ; #AD-25]
- **AD-28 (contenus rich-text typés)** : `content` de nœud **reste texte brut** dans `zcrud_mindmap` ; le
  rich-text est un **slot opt-in câblé côté app** via `nodeContentBuilder`. ES-7.1 **ne** modifie **pas** le
  modèle de nœud et **n'importe pas** `zcrud_markdown`. La **décision** OQ-S5 est portée par **ES-7.2** (note
  d'archi + memlog) — ES-7.1 s'y **conforme** sans la trancher. [Source: architecture.md#AD-28 ; epics.md#ES-7.2]
- **AD-13/FR-26** : directionnel (`EdgeInsetsDirectional`, `TextAlign.start`), `Semantics` explicites, cibles
  ≥ 48 dp, thème injecté `ZcrudTheme.of` (repli `Theme.of`), aucune couleur/label codé en dur. [Source:
  architecture.md#AD-13 ; z_sectioned_study_layout.dart]
- **AD-25 (layout study-tools sectionné, SM-1)** : la section mindmap s'insère comme un
  `ZStudyToolsSectionSpec` composé par `ZSectionedStudyLayout` (frontière `ValueKey('section:<id>')`) — une
  bascule dans la section ne reconstruit **aucune** autre section. [Source: architecture.md#AD-25 ;
  z_study_tools_page.dart]

### Source tree à toucher
- **NEW** `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart` (widget + fabrique `sectionSpec`).
- **UPDATE** `packages/zcrud_study/lib/zcrud_study.dart` (export barrel).
- **UPDATE** `packages/zcrud_study/pubspec.yaml` (arête `zcrud_mindmap`, commentaire AD-1).
- **NEW** `packages/zcrud_study/test/z_study_mindmap_section_test.dart`.

### API réutilisée (déjà livrée — NE PAS réimplémenter)
- `ZMindmapView({mindmap, roots, mode, nodeContentBuilder, config, onNodeTap, onNodeSelected, emptyLabel})` —
  lecture seule, `ExcludeSemantics` sur le graphe, vue liste = surface a11y. [Source: z_mindmap_view.dart]
- `ZMindmapOutlineEditor({roots, controller, onSave, onChanged, labels, config, editContentField, padding})`
  ; `ZMindmapOutlineController({initialForest})` (`forest` getter, `dispose` libère les
  `TextEditingController`). [Source: z_mindmap_outline_{editor,controller}.dart]
- `ZStudyToolsSectionSpec({id, title, itemCount, itemBuilder, emptyState, addAction?, addActionIcon?,
  addActionSemanticLabel?, axis, ...})` ; `ZSectionedStudyLayout({sections})` ; `ZStudyToolsPage({sections,
  globalEmptyState?, formController?})`. [Source: z_study_tools_section_spec.dart ; z_sectioned_study_layout.dart]

### Dettes/pièges anticipés
- **DW-ES22-5 (ouverte)** : `ZMindmap`/`ZMindmapNode` **n'ont AUCUNE égalité de valeur** (`==` d'identité).
  ⇒ Les tests d'ES-7.1 **NE doivent PAS** s'appuyer sur `ZMindmap == ZMindmap` (déduplication/`expect(relu,
  original)` cassés). Comparer par `id`/structure explicite. [Source: architecture.md#DW-ES22-5]
- **R20 (motif dominant ES-6.1)** : AC3/AC4 ancrés sur les objets/lignes PROPRES à `ZStudyMindmapSection`
  (identité du controller détenu ; notifier de mode local), jamais sur une garantie des widgets réutilisés.
- **SM-S4/R21** : si le dev rencontre un manque de l'éditeur (indent/outdent au clic, plein-écran…), **NE le
  comble PAS** dans `zcrud_study` — c'est le périmètre d'ES-7.2 (package d'origine). Consigner en dette.
- **Flowchart legacy** : `flutter_flow_chart`/`graphview` **interdits** (AD-1, epics.md). Verrou-source AC2.

### Vérif verte à rejouer (avant tout `review`/`done`)
- `dart run melos bootstrap` (nouvelle arête résolue) — RC=0.
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, `total arêtes` = +1 vs baseline.
- `dart run melos run analyze` (repo-wide **et** ciblé `zcrud_study`) — RC=0 (une suppression de symbole
  public casserait un consommateur : vérif **repo-wide** obligatoire, cf. gate d'epic).
- `flutter test` sur `packages/zcrud_study` (**R14** — package Flutter, jamais `dart test`) — RC=0, tous les
  AC verts + non-régression des suites ES-5 existantes.
- **RC capturé HORS pipe** (R15) : `flutter test ...; echo "RC=$?"` (jamais `| tee`).
- `dart run melos list` inchangé (aucun nouveau package).
- Injections R3-I1..I10 rejouées (rouge attendu) puis restaurées (vert).

### Project Structure Notes
- Conforme à la structure `zcrud_study` (présentation sous `lib/src/presentation/`, API = barrel
  `lib/zcrud_study.dart`). Aucun `@ZcrudModel` (pas de codegen, gate `codegen-distribution` sans objet).
- Variance : première arête `zcrud_study → zcrud_mindmap` (attendue par AD-17/AD-28 ; documentée au pubspec).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Epic-ES-7 (l.841-880)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-1, #AD-2, #AD-4, #AD-13, #AD-25, #AD-28, #DW-ES22-5]
- [Source: _bmad-output/implementation-artifacts/stories/epic-es-6-retrospective.md#R20, #R21, #R22, §7 (décisions verrouillées ES-7+)]
- [Source: packages/zcrud_mindmap/lib/zcrud_mindmap.dart ; z_mindmap_view.dart ; z_mindmap_outline_controller.dart ; z_mindmap_outline_editor.dart]
- [Source: packages/zcrud_study/lib/src/presentation/z_study_tools_page.dart ; z_sectioned_study_layout.dart ; z_study_tools_section_spec.dart ; z_feature_availability.dart]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story` invoqué réellement — pas de fallback disque).

### Debug Log References

Vérif verte rejouée RÉELLEMENT sur disque (RC capturés HORS pipe, R15) :
- `dart pub get` (workspace) → RC=0.
- `flutter test` sur `packages/zcrud_study` (R14, jamais `dart test`) → RC=0, **65 tests** (14 nouveaux ES-7.1
  + 51 ES-5 existants, non-régression).
- `python3 scripts/dev/graph_proof.py` → RC=0 : **ACYCLIQUE OK**, **CORE OUT=0 OK**, arête
  `zcrud_study -> zcrud_mindmap` présente, `total arêtes = 42` (+1 vs baseline 41), `noeuds = 20`.
- `dart run melos list` → **20** (aucun nouveau package).
- `dart run melos exec --scope=zcrud_study -- dart analyze` → RC=0, **No issues found!**

Injections R3 rejouées (mutation → AC rouge RC=1 → restauration ciblée → vert). Toutes RC=1 sur l'AC visé,
SRC restauré byte-identique, suite finale RC=0 :
| Ref | AC | Mutation | RC obtenu |
|-----|----|----------|-----------|
| R3-I1 | AC1 | clé constante `mindmap:CONST` | RC=1 (deux folderId ⇒ clés distinctes) |
| R3-I2 | AC1 | `Placeholder()` au lieu de `ZMindmapView` | RC=1 |
| R3-I3 | AC2 | `import package:graphview` / dép pubspec | RC=1 (src) + RC=1 (pubspec) |
| R3-I4 | AC3 | controller créé dans `build()` | RC=1 (non `identical` après tempête) |
| R3-I5 | AC3 | dispose du controller injecté | RC=1 |
| R3-I6 | AC4 | rebuild lifté au parent (`markNeedsBuild` ancêtres) | RC=1 (sonde reconstruite) |
| R3-I7 | AC5 | `semanticLabel: 'Éditer'/'Voir'` codé en dur | RC=1 |
| R3-I8 | AC5 | cible `ConstrainedBox` à 20 dp | RC=1 |
| R3-I9 | AC6 | `nodeContentBuilder: null` (non forwardé) | RC=1 |
| R3-I10 | AC7 | `sectionSpec` `itemCount: 0` | RC=1 |

### Completion Notes List

- `ZStudyMindmapSection` = ADAPTATEUR MINCE de composition : assemble `ZMindmapView` (E10-2) en lecture et
  `ZMindmapOutlineEditor`/`ZMindmapOutlineController` (E10-3) en édition, keyé par `ValueKey('mindmap:$folderId')`
  neutre. AUCUNE réimplémentation graphite ; flowchart legacy IFFD NON porté.
- AD-1 : seule arête nouvelle `zcrud_study → zcrud_mindmap` (acyclique, CORE OUT=0). `graphite` reste TRANSITIF
  via `zcrud_mindmap` ; `flutter_flow_chart`/`graphview` interdits (verrou-source AC2).
- AD-2/AD-15 : patron owned/injected du `ZMindmapOutlineController` (créé `initState` ssi non injecté, disposé
  ssi possédé) ; bascule lecture⇄édition via `ValueNotifier` LOCAL (frontière rebuild SM-1 préservée — sonde
  non reconstruite).
- AD-28 : `content` de nœud reste texte brut ; `nodeContentBuilder` forwardé tel quel à `ZMindmapView` ; AUCUN
  import `zcrud_markdown`. Décision OQ-S5 laissée à ES-7.2 (non tranchée ici).
- AD-4/AD-13/FR-26 : `folderId` String opaque ; `addAction` null = absent ; labels/couleurs/sémantique injectés
  (`ZcrudTheme.of`) ; cible bascule ≥ 48 dp ; padding directionnel.
- Ancrage R20 : AC3 ancré sur l'identité du controller DÉTENU par la section (capturé via l'éditeur composé),
  AC4 sur la localité du notifier de mode (R3-I6 prouve la régression si lifté) — jamais sur une garantie des
  widgets réutilisés. DW-ES22-5 respectée : les fixtures comparent par `id`/structure, jamais `ZMindmap==`.
- Aucun besoin d'affordance ES-7.2 (plein-écran/super-racine/indent-clic) rencontré : SM-S4/R21 respecté, rien
  comblé hors `zcrud_mindmap`.

### File List

- **NEW** `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart`
- **UPDATE** `packages/zcrud_study/lib/zcrud_study.dart` (export du nouveau widget)
- **UPDATE** `packages/zcrud_study/pubspec.yaml` (arête `zcrud_mindmap`, commentaire AD-1)
- **NEW** `packages/zcrud_study/test/z_study_mindmap_section_test.dart`
