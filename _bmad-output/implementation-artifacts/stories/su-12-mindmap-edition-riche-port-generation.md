---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story SU-12 : Édition riche de nœud mindmap et port de génération

Status: review

<!-- Source : epics-zcrud-study-ui-2026-07-16/epics.md § Story 1.12 (Epic 1 E-STUDY-UI) -->
<!-- Mode non-interactif : options conservatrices consignées (§ Décisions tranchées). -->

## Story

As an **utilisateur de cartes mentales**,
I want **rédiger mes nœuds (label et contenu) en markdown/LaTeX**,
so that **mes cartes portent des formules et de la mise en forme, sans régression pour qui ne veut que du texte brut**.

**Couvre :** FR-SU17, FR-SU18 · **Taille :** L · **Workstream :** C (mindmap, package DISJOINT de A/B) · **Séquence :** ∥ A et B, après su-1 (livrée).

---

## Contexte livré à CONSOMMER (ne pas refaire — vérifié sur disque)

| Acquis | Vérifié | Emplacement / contrat réel |
|---|---|---|
| `ZMindmapOutlineEditor` avec **`TextField` EN DUR** (cible de su-12) | ✅ | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart` — **deux** `TextField` codés en dur : `labelField` (`:266`, `controller.labelControllerFor(node)` → `controller.editLabel`) et `contentField` (`:298`, `controller.contentControllerFor(node)` → `controller.editContent`, `maxLines:4`). C'est ce que le slot d'édition remplace. |
| `ZMindmapOutlineController` (controllers stables SM-1) | ✅ | `.../z_mindmap_outline_controller.dart:34` — `ChangeNotifier` ; `_labelControllers`/`_contentControllers` = `Map<String,TextEditingController>` **stables keyés par `node.id`**, jamais recréés (zéro perte de focus, AD-2/SM-1) ; `dispose` libère tout. |
| **Patron AD-40 de RENDU déjà établi** dans `zcrud_mindmap` | ✅ | `ZMindmapNodeContentBuilder` (typedef, `.../z_mindmap_view_config.dart:25`), slot `nodeContentBuilder` de `ZMindmapView` (`.../z_mindmap_view.dart:82`, défaut `_defaultContent` texte brut `:142`), consommé par `z_mindmap_node_card.dart:94` et `z_mindmap_list_view.dart:43`. **su-12 ajoute le pendant ÉDITION** de ce patron. |
| `ZMindmapMarkdownContent` — **adaptateur riche de rendu chez le consommateur** | ✅ | `.../z_mindmap_markdown_content.dart:38` — adaptateur MINCE composant `ZMarkdownReader` + `const ZDeltaCodec()`, `.builder(slotKey:)` → `ZMindmapNodeContentBuilder`. **Lit le payload rich dans `node.extra[slotKey]`** (ops Delta), **repli plain-text** (AD-10) si absent/mal formé. `ZMindmapNode.content`/`label` **restent texte brut** (OQ-S5/AD-28). **su-12 édite le MÊME slot `extra[slotKey]`** (symétrie lecture/écriture). |
| Arête **existante** `zcrud_mindmap → zcrud_markdown` | ✅ | `packages/zcrud_mindmap/pubspec.yaml:29` (`zcrud_markdown: ^0.2.1`). L'adaptateur d'édition riche vit AU-DESSUS de cette arête. **Aucune arête nouvelle.** |
| `ZMarkdownField` — éditeur rich-text (aucun Quill fuité) | ✅ | `packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart:105`, exporté par le barrel `zcrud_markdown.dart:25` **sans** symbole `flutter_quill`. Deux voies : voie `controller` (`ZFormController`) **et** voie `ctx` (`ZFieldWidgetContext` value-in-slice, `State` persistant par **place stable** ⇒ `QuillController` non recréé). C'est la voie `ctx` qu'un adaptateur d'édition de nœud compose. |
| `ZMindmapNode` (label/content plain) | ✅ | `.../z_mindmap_node.dart:56` `final String label` (défaut `''`), `:59` `final String? content`. `ZExtensible` (`extra`/`extension`, AD-4). |
| `ZMindmap` (entité PERSISTÉE — porte `id`+`folderId`) | ✅ | `.../z_mindmap.dart:21` — **id+folderId = identité de persistance** ⇒ **PAS** le type de résultat du port de génération (AD-37 : résultat éphémère « ni id ni source »). |
| `ZFlashcardGenerationPort` — **modèle d'alignement** (FR-SU18) | ✅ | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:158` — `abstract interface class`, une méthode `Future<ZResult<List<ZFlashcard>>> generateFlashcards(ZFlashcardGenerationRequest)`. Request value-object (`==`/`hashCode` par valeur, `:108`/`:120`) : `{content, count?, languageTag?, provenance?, typesDistribution?, instructions?, modelId(opaque String?), extra(normalisé AD-19.1)}`. **Aucune impl de référence** (l'app *implements*, AD-15/AD-35). |
| Garde de **surface des ports IA** | ✅ | `packages/zcrud_study/test/z_ai_ports_surface_test.dart` — vérifie type de retour EXACT (`ZResult<…>` jamais nu ni `Stream`) + égalité par valeur des requests. **su-12 étend cette garde** au nouveau port. |
| `zcrud_study` dépend déjà de `zcrud_mindmap` | ✅ | barrel `zcrud_study.dart:99` exporte `z_study_mindmap_section.dart` ⇒ `ZMindmapNode` est visible côté `zcrud_study` : le port peut y typer son résultat éphémère sans arête nouvelle. |
| Bornage AD-41 **déjà partiel** dans la cellule graphe | ✅ | `z_mindmap_node_card.dart` — `ZMindmapDefaultNodeContent` (`:41` `maxLines:3`+`overflow:ellipsis`), `_CompactLabel` (`:65` `maxLines:1`+ellipsis), carte en `ConstrainedBox` (`:124`), `cellSize=Size(180,72)` (`z_mindmap_view_config.dart:71`). **Le défaut est borné ; l'enjeu su-12 = borner AUSSI le builder RICHE injecté** (leçon su-2). |
| Graphe = **display-only, pan/zoom borné** | ✅ | `z_mindmap_view.dart:5-36` — `graphite` `DirectGraph` (`:302`), `InteractiveViewer` interne borné (`minScale/maxScale`), nœud en `ExcludeSemantics`, `onTap` seul (aucune mutation d'arbre). **L'édition vit dans `ZMindmapOutlineEditor` (liste), pas dans le graphe.** |

### Preuves de discipline de réalité (greps joués)

- `grep -rn "class ZMindmapOutlineEditor"` → `z_mindmap_outline_editor.dart:37` (RC=0) — **existe**.
- `grep -rn "TextField" packages/zcrud_mindmap/lib/` → `z_mindmap_outline_editor.dart:266,298` (RC=0) — **`TextField` en dur prouvé**.
- **ANTI-CYCLE** `grep -rn "zcrud_mindmap\|z_mindmap" packages/zcrud_markdown/lib/` → **RC=1** (absent) · `grep -n "zcrud_mindmap" packages/zcrud_markdown/pubspec.yaml` → **RC=1** (absent). **`zcrud_markdown → zcrud_mindmap` = ABSENT, aucun cycle.**
- `grep -rn "ZMindmapGenerationPort" packages/` → **RC=1** — **le port N'EXISTE PAS** (à créer, aligné).
- `grep -rln "ZFlashcardGenerationPort" packages/` → présent dans `zcrud_study/lib/src/domain/z_flashcard_generation_port.dart` (contrat d'alignement).

---

## Acceptance Criteria

### AC1 — Slot d'édition de champ injectable dans `ZMindmapOutlineEditor` (FR-SU17, AD-40)
**Given** `ZMindmapOutlineEditor`, dont `labelField` et `contentField` sont des `TextField` en dur
**When** un **slot de champ d'édition** (`ZMindmapEditFieldBuilder`) est fourni
**Then** **label ET contenu** sont rendus par le builder injecté
**And** **sans injection**, le repli est le `TextField` texte brut ACTUEL — **aucune régression** (mêmes contrôleurs stables, mêmes hints/bordures, cible ≥ 48 dp, `TextAlign.start`)
**And** le kind du champ est un **enum** `ZMindmapEditFieldKind { label, content }` (jamais un `bool`)
**And** **SM-1 est préservé** : le `TextEditingController` stable keyé par `node.id` n'est **pas** recréé au rebuild ; taper N caractères ne reconstruit pas l'outline (zéro perte de focus).

### AC2 — Adaptateur d'édition riche **dans `zcrud_mindmap`**, payload dans le slot AD-4 (AD-40/AD-28/AD-7)
**Given** l'adaptateur d'édition riche
**When** il est livré
**Then** il vit **dans `zcrud_mindmap`** (`ZMindmapMarkdownEditField`, au-dessus de l'arête existante vers `zcrud_markdown`), **jamais** dans `zcrud_markdown`
**And** il compose `ZMarkdownField` (voie `ctx`) **tel quel** — **aucun `QuillController`/`Delta`/`flutter_math_fork` dans une signature publique** (AD-7)
**And** il **écrit** le payload rich dans `node.extra[slotKey]` (ops Delta neutres) via une voie d'écriture du contrôleur — **le MÊME `slotKey`** que `ZMindmapMarkdownContent` LIT (symétrie round-trip R22) ; `label`/`content` **restent texte brut** (OQ-S5/AD-28)
**And** il expose une fabrique `ZMindmapMarkdownEditField.builder(slotKey:)` → `ZMindmapEditFieldBuilder`, symétrique de `ZMindmapMarkdownContent.builder(slotKey:)`.

### AC3 — Test de graphe **anti-cycle** (AD-40/AD-1)
**Given** le graphe de dépendances
**When** la garde s'exécute
**Then** un test **échoue** si l'arête inverse `zcrud_markdown → zcrud_mindmap` apparaît (import de lib **ou** dépendance pubspec)
**And** la garde prouve l'**absence** par lecture réelle du disque (pubspec + `lib/`), pas par affirmation.

### AC4 — Label riche **borné à la cellule fixe** du graphe (AD-41)
**Given** un builder de contenu **riche** injecté et un label long/multi-ligne dans le graphe
**When** il s'affiche dans la cellule `cellSize` (défaut `180×72`)
**Then** il est **borné/clippé proprement** (troncature), **sans mesure intrinsèque ni re-layout** — **aucun `RenderFlex overflow`** (leçon su-2)
**And** une **contre-preuve** existe : un harnais SAIT produire un débordement quand le bornage est retiré (sinon `takeException(), isNull` serait aveugle)
**And** le **mode compact** conserve le label brut mono-ligne (`_CompactLabel` inchangé)
**And** le rendu riche **complet** (non borné) reste garanti dans l'outline editor et la **liste a11y** (`ZMindmapListView`).

### AC5 — `ZMindmapGenerationPort` dans `zcrud_study`, aligné sur `ZFlashcardGenerationPort` (FR-SU18/AD-37)
**Given** `ZMindmapGenerationPort`
**When** il est défini dans `zcrud_study` (domaine)
**Then** c'est un `abstract interface class` avec une méthode retournant `Future<ZResult<List<ZMindmapNode>>>` — **jamais** une liste nue, **jamais** un `Stream` (AD-5), résultat **éphémère** = forêt de nœuds **sans `id`/`folderId` backend** (AD-37 ; la matérialisation en `ZMindmap` est app-side, après revue)
**And** `ZMindmapGenerationRequest` est un **value-object** (`==`/`hashCode` par valeur) portant `{content, count?(borné app-side), languageTag?, instructions?, modelId(opaque `String?`), extra(normalisé AD-19.1)}` — `modelId` **transporté VERBATIM, jamais interprété** (aucun enum/switch/catalogue)
**And** **aucune implémentation** n'est fournie (app+backend-side, hors périmètre)
**And** la garde `z_ai_ports_surface_test.dart` est étendue au nouveau port (type de retour exact + égalité par valeur).

### AC6 — Preuve de **branchement effectif** du slot (leçon su-1, R3)
**Given** le slot d'édition (AC1) et l'adaptateur riche (AC2)
**When** le builder injecté est fourni
**Then** un test **actionne** le contrôle : il **rougit** si `ZMindmapOutlineEditor` ignore le builder injecté et retombe sur le `TextField` en dur (contrôle décoratif ⇒ rouge) — la garde observe le **comportement** (le champ riche apparaît / le TextField par défaut disparaît), pas la seule présence d'un paramètre.

### AC7 — Robustesse (AD-10) et arène gestes/scroll de l'outline
**Given** des entrées dégradées
**When** elles surviennent
**Then** — nœud **vide** (`label==''`, `content==null`) → repli plain sûr, aucun throw ; **label très long** → borné (AC4) ; **markdown malformé** dans `extra[slotKey]` → repli plain-text (jamais de throw, réutilise la défense de `ZMindmapMarkdownContent`) ; **RTL/Unicode** dans label/content → `TextAlign.start` respecté, aucun débordement ; **port de génération qui échoue** → `Left(ZFailure)` **advisory** (jamais d'exception propagée)
**And** l'éditeur riche dans l'outline (`ListView.builder`) **ne vole pas** le scroll de l'outline : son défilement interne est **borné** (`maxLines`/hauteur bornée) — pas d'« unbounded height », pas d'arène de gestes qui casse le scroll parent. **Le graphe reste display-only** (aucun éditeur monté dans une cellule graphite).

---

## Tasks / Subtasks

- [x] **T1 — Slot d'édition dans l'outline editor** (AC1, AC6)
  - [x] `enum ZMindmapEditFieldKind { label, content }` + `typedef ZMindmapEditFieldBuilder` + contexte stable `ZMindmapEditFieldContext {node, kind, controller, value, onChanged, writeRichSlot, hint, config, theme}` (pas de `bool`) — dans `z_mindmap_view_config.dart`.
  - [x] Paramètre optionnel `editFieldBuilder` (défaut `null`) sur `ZMindmapOutlineEditor`.
  - [x] `TextField` en dur extrait dans `_defaultEditField` (comportement IDENTIQUE : hints/bordures/`minTapTarget`/`TextAlign.start`, `label` mono-ligne, `content` `minLines:1`/`maxLines:4`).
  - [x] Routage `label`/`content` → `editFieldBuilder ?? _defaultEditField`, controllers stables inchangés (SM-1).
- [x] **T2 — Adaptateur d'édition riche `ZMindmapMarkdownEditField`** (AC2)
  - [x] `z_mindmap_markdown_edit_field.dart` (dans `zcrud_mindmap`) composant `ZMarkdownField.fromContext` (voie `ctx`) + `const ZDeltaCodec()`, exporté par le barrel.
  - [x] Fabrique `ZMindmapMarkdownEditField.builder({required String slotKey})` → `ZMindmapEditFieldBuilder` (+ `slotKeyFor` : content→base, label→`__label`, sans collision).
  - [x] Voie d'écriture : `ZMindmapOutlineController.editRichSlot(nodeId, slotKey, ops)` mutant `extra[slotKey]` via `ZMindmapTreeOps.updateExtra` (ajoutée), `label`/`content` inchangés, SANS notifier (SM-1) ; place stable `ValueKey(node.id + kind)`.
  - [x] Zéro type Quill/Delta/math dans la signature publique (grep de garde vert).
- [x] **T3 — Test de graphe anti-cycle** (AC3) — `z_mindmap_graph_acyclic_test.dart` lit `pubspec.yaml` + `lib/**` de `zcrud_markdown` (scan non vacant prouvé).
- [x] **T4 — Bornage AD-41 du rendu riche dans la cellule** (AC4)
  - [x] `ZMindmapCellClip` (`SizedBox.fromSize`+`OverflowBox`+`ClipRect`, aucun intrinsèque) enveloppe les nœuds du GRAPHE (`z_mindmap_view.dart`) ; liste/outline NON bornés.
  - [x] Tests bornage 180×72 + **contre-preuve** overflow falsifiable ; graphe wrappé / liste non-wrappée ; contenu riche trop haut borné.
- [x] **T5 — `ZMindmapGenerationPort` + request (aligné AD-37)** (AC5)
  - [x] `z_mindmap_generation_port.dart` : `ZMindmapGenerationRequest` (VO `==`/`hashCode`, `extra` normalisé) + `abstract interface class` `Future<ZResult<List<ZMindmapNode>>> generateMindmap(...)`. Aucune impl. Omet `typesDistribution`/`provenance`.
  - [x] Export barrel `zcrud_study.dart`.
  - [x] `z_ai_ports_surface_test.dart` étendu (fake, type EXACT, `Left` advisory, égalité par valeur + discrimination `modelId`).
- [x] **T6 — Preuve de branchement + robustesse** (AC6, AC7)
  - [x] Branchement à deux canaux (adaptateur monté + `ZMarkdownField` réel), rouge si builder ignoré (R3 prouvé).
  - [x] AD-10 : nœud vide, slot malformé (repli), RTL/Unicode, port `Left`, éditeur riche borné (`maxLines`) dans `ListView`.
- [x] **T7 — Vérif verte ciblée** : `flutter analyze` (0) + `flutter test` sur `zcrud_mindmap` (167) et `zcrud_study` (voir Completion Notes). PAS de `melos` global (workstream su-11 ∥ actif). Aucun codegen requis (aucune annotation touchée).

---

## Dev Notes

### Décisions tranchées (mode non-interactif — options conservatrices)
- **Type de résultat du port = `List<ZMindmapNode>` (forêt éphémère), PAS `ZMindmap`.** `ZMindmap` porte `id`+`folderId` = identité de persistance ; AD-37 exige un résultat « ni id ni source du backend », matérialisé client-side après revue. Rejeté : `ZResult<ZMindmap>` (fabriquerait une identité fictive).
- **Request = alignement STRUCTUREL, pas copie littérale.** On omet `typesDistribution` (aucune notion de « type de nœud » à répartir dans une carte) et `provenance:ZFlashcardSource` (provenance flashcard-spécifique ; la coupler au mindmap serait un mésusage). On conserve les invariants d'AD-37 : requête d'union, `modelId` **opaque**, résultat éphémère. `count` = nombre de nœuds souhaité (borné app-side). Toute dimension future passe par des propriétés **typées additives** (jamais `extra`), comme SU-9.
- **Édition riche = écriture du slot `extra[slotKey]`, `label`/`content` restent plain** (symétrie exacte avec le rendu `ZMindmapMarkdownContent`, OQ-S5/AD-28). Rejeté : stocker le Delta dans `content` (casserait le repli plain-text et le round-trip R22).
- **Le graphe reste display-only** : aucun éditeur riche monté dans une cellule graphite (évite l'arène de gestes pan/zoom vs édition). L'édition riche vit dans `ZMindmapOutlineEditor` (liste défilable) ; le graphe n'en montre que le **rendu borné** (AC4). C'est pourquoi l'« arène des gestes » se réduit à l'arène **scroll** de l'outline (AC7).

### Fichiers à toucher
- **UPDATE** `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart` — extraire les 2 `TextField` en un builder par défaut ; router vers le slot injectable.
- **UPDATE** `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_controller.dart` — ajouter `editRichSlot(nodeId, slotKey, ops)` (mutation `extra` via `ZMindmapTreeOps`), sans recréer de contrôleur.
- **NEW** `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_edit_field.dart` — adaptateur d'édition riche + `.builder(slotKey:)`.
- **UPDATE** `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart` (ou node_card) — `typedef ZMindmapEditFieldBuilder`, `enum ZMindmapEditFieldKind` ; bornage AD-41 du rendu riche dans la cellule.
- **UPDATE** `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` — export du nouvel adaptateur + types du slot.
- **NEW** `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart` + export barrel `zcrud_study.dart`.
- **UPDATE** `packages/zcrud_study/test/z_ai_ports_surface_test.dart` — étendre au nouveau port.
- **NEW tests** `zcrud_mindmap/test/` : slot/branchement, anti-cycle, bornage AD-41 + contre-preuve overflow, robustesse AD-10.

### Invariants AD applicables (spine study-ui + hérités AD-1..46)
- **AD-40** — rendu/édition riche par slot injectable, adaptateur CHEZ le consommateur (`zcrud_mindmap`), **jamais** l'inverse ; aucun type Quill/math dans une signature publique.
- **AD-41** — label riche borné à la cellule fixe (troncature, aucune mesure intrinsèque).
- **AD-37** — port de génération : requête d'union, `modelId` opaque, résultat **éphémère**.
- **AD-28/OQ-S5** — `content`/`label` restent texte brut ; le rich vit dans le slot AD-4.
- **AD-7** — pas de fuite `flutter_quill`/`flutter_math_fork`. **AD-5** — `Either<ZFailure,·>`, jamais nu/Stream.
- **AD-2/AD-15/SM-1** — réactivité Flutter-native, contrôleurs stables, rebuild granulaire, zéro perte de focus.
- **AD-10** — défensif : jamais d'exception, replis définis. **AD-13** — RTL (`TextAlign.start`, `EdgeInsetsDirectional`), `Semantics`, ≥ 48 dp. **FR-26** — thème injecté, aucun littéral de couleur.
- **AD-1** — graphe acyclique (test anti-cycle). **AD-19.1** — `extra` normalisé (clés de sync réservées écartées).

### Leçons opposables (code-reviews su-1/su-2 — à NE PAS reproduire)
- **su-1 / D5** : un test de slot **infalsifiable** (builder local jamais branché à un call-site réel) = preuve creuse. Ici le call-site EXISTE (`ZMindmapOutlineEditor`) ⇒ **AC6 doit être falsifiable** (rougir si le builder injecté est ignoré). Observer le **comportement**, pas la présence d'un paramètre.
- **su-2 / D3** : une face **non bornée** débordait (`RenderFlex overflowed`, jusqu'à 3436 px) — et un test avait été **modifié pour cacher** le défaut. **Jamais** modifier un test pour taire un débordement réel. AC4 exige un **bornage prouvé + une contre-preuve** (le harnais SAIT déborder sans le bornage).
- Général : présence ≠ association (contrôle **actionné**) ; un test ne doit pas observer qu'UN canal ; la prose ne prouve rien (dartdoc vraie sur disque) ; toute **absence** prouvée par grep négatif (commande + RC).

### Testing standards
- Runner : **`flutter test` DEPUIS le package** (`packages/zcrud_mindmap`, `packages/zcrud_study`). Jamais `melos run test` (workstreams ∥ actifs).
- Discipline R3 : chaque AC = fichier réel + test porteur rougissant **par le comportement** (injection de défaut réelle, pas tautologique).
- **Baselines à confirmer par le dev avant de coder** : `zcrud_mindmap` ~140 tests (9 fichiers `*_test.dart` sur disque), `zcrud_markdown` 277. Nouveaux tests **additifs** (aucun test existant supprimé/affaibli).

### Project Structure Notes
- Package DISJOINT (`zcrud_mindmap` + ajout domaine dans `zcrud_study`) — aucun contact avec su-10 (`example/`) ni su-11 (`zcrud_export`/`zcrud_export_ui`). `zcrud_core` **non touché**.
- API publique via barrels ; impl sous `lib/src/{domain,presentation}` ; `*_test.dart`.

### References
- [Source: epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.12] — ACs source.
- [Source: prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU17, FR-SU18]
- [Source: architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-40] / #AD-41 / #AD-37 / #AD-28 / #AD-10 / #AD-13
- [Source: packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart:266,298] — `TextField` en dur.
- [Source: packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_content.dart:38,63] — patron rendu à répliquer en édition.
- [Source: packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:46,158] — contrat d'alignement.
- [Source: stories/code-review-su-1.md#D5] / [code-review-su-2.md#D3] — leçons opposables.

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — workflow `bmad-dev-story` (mode non-interactif, options conservatrices consignées).

### Debug Log References

- Piège Quill inline en test : `QuillToolbar…initState` planifie un `Timer` ⇒ « A Timer is still pending ». Résolu par le patron `zcrud_markdown` `_settle` (`pump(50ms)` → `pumpWidget(SizedBox.shrink())` → `pump()`) en fin de test montant l'éditeur.
- Preuve R3 (injection réelle → rouge **par comportement** → restauration `cp`+SHA-256 vérifiée) : (1) routage `_defaultEditField` forcé ⇒ AC6/kind-enum + tests rich rouges ; (2) `ZMindmapCellClip` retiré du graphe ⇒ AC4 clip + overflow rouges ; (3) `editRichSlot` écrivant un slot erroné ⇒ AC2 write + symétrie round-trip rouges. Les 3 fichiers restaurés (SHA-256 identiques).

### Completion Notes List

- **AC1..AC7 satisfaits.** Slot d'édition injectable (défaut = `TextField` texte brut inchangé, adaptateur riche opt-in), adaptateur `ZMindmapMarkdownEditField` chez le consommateur (au-dessus de l'arête existante), test anti-cycle, bornage AD-41 `ZMindmapCellClip` (graphe uniquement + contre-preuve overflow), port `ZMindmapGenerationPort` éphémère aligné SU-9 (`modelId` opaque, omet `typesDistribution`/`provenance`), robustesse AD-10.
- **Décisions tranchées** (mode non-interactif) : slot-par-kind (`content`→`slotKey` symétrique du rendu, `label`→`${slotKey}__label` sans collision) ; `editRichSlot`/`updateExtra` SANS notifier (SM-1) ; graphe display-only borné, édition riche dans l'outline (mode `inline` borné `maxLines` — ne vole pas le scroll).
- **Vérif verte réelle** : `zcrud_mindmap` `flutter analyze` 0 issue, `flutter test` **167** (baseline 140 + 27). `zcrud_study` `flutter analyze` 0 error (seuls infos pré-existantes, dont `prefer_initializing_formals` idiome commun à tous les ports), `flutter test` **voir gate**. Aucun `melos` global (workstream su-11 ∥).
- **Gate REPO-WIDE à rejouer par l'orchestrateur** : anti-cycle `zcrud_markdown ↛ zcrud_mindmap` (aucune arête ajoutée ; `zcrud_study` réutilise `zcrud_mindmap`/`zcrud_core` existants) ; nouveau port exporté par le barrel `zcrud_study` ; `melos run analyze` + `melos run verify` repo-wide.

### File List

**zcrud_mindmap (workstream C)**
- UPDATE `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart` — `enum ZMindmapEditFieldKind`, `ZMindmapEditFieldContext`, `typedef ZMindmapEditFieldBuilder`.
- UPDATE `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_editor.dart` — param `editFieldBuilder`, routage slot, `_defaultEditField`.
- UPDATE `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_outline_controller.dart` — `editRichSlot(...)`.
- UPDATE `packages/zcrud_mindmap/lib/src/domain/z_mindmap_tree_ops.dart` — `updateExtra(...)`.
- NEW `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_markdown_edit_field.dart` — adaptateur d'édition riche + `.builder(slotKey:)`.
- UPDATE `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_node_card.dart` — `ZMindmapCellClip` (bornage AD-41).
- UPDATE `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view.dart` — graphe wrappé `ZMindmapCellClip`.
- UPDATE `packages/zcrud_mindmap/lib/zcrud_mindmap.dart` — export adaptateur.
- NEW tests : `test/z_mindmap_edit_slot_test.dart`, `test/z_mindmap_markdown_edit_field_test.dart`, `test/z_mindmap_graph_acyclic_test.dart`, `test/z_mindmap_cell_clip_test.dart`.

**zcrud_study (domaine ajouté — package que ce workstream peut compiler)**
- NEW `packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart`.
- UPDATE `packages/zcrud_study/lib/zcrud_study.dart` — export du port.
- UPDATE `packages/zcrud_study/test/z_ai_ports_surface_test.dart` — garde étendue au nouveau port.
