---
baseline_commit: f751d82fecf2f7b80104a32146a3c14dfa8ef38e
---

# Story ES-6.1 : Édition/lecture de notes markdown (`ZSmartNoteEditor` / `ZSmartNoteReader`, `zcrud_note`)

Status: review

- **Clé sprint-status** : `es-6-1-edition-lecture-notes-markdown`
- **Epic** : ES-6 (Notes & markdown — réutilisation `zcrud_markdown`) — **TÊTE d'ES-6** (précède SÉQ ES-6.2, même package `zcrud_note`).
- **Taille** : **M**
- **Parallélisation** : ✅ **PARALLÉLISABLE** avec `ES-7.2` (`zcrud_mindmap`) et `ES-8.2` (`zcrud_document/presentation`) — trois packages disjoints (garde-fou n°1/n°2 de CLAUDE.md).
  **Packages écrits** : `packages/zcrud_note/` **UNIQUEMENT** (nouveau dossier `lib/src/presentation/`, `pubspec.yaml`, barrel, `test/`).
  ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_markdown` NI `zcrud_study_kernel`.** Si le dev découvre un **écart de `zcrud_markdown`** (ex. rendu markdown → Delta riche manquant), il le **COMBLE DANS `zcrud_markdown`** (package d'origine, SM-S4) — mais **c'est le périmètre d'ES-6.2**, pas d'ES-6.1 : ici on **réutilise `zcrud_markdown` TEL QUEL**. Si un symbole doit remonter au cœur, il **ARRÊTE** et le signale (cf. **D5/DW-ES-6.1-1**).
- **Couvre** : **FR-S25** · **AD-28** (contenu rich-text typé), **AD-7** (rich-text Delta interne, `ZCodec` pluggable, controller isolé), **AD-2** (réactivité Flutter-native, SM-1), **AD-1** (graphe acyclique, CORE OUT=0), **AD-10** (décodage défensif), **AD-13/FR-26** (directionnel, `Semantics`, ≥48 dp, thème injecté) · **SM-S4** (aucun nouveau pipeline rich-text) · NFR-S10.
- **Dépend de** : **ES-2** (`done` — `ZSmartNote`/`content`/`normalizeNoteContentOps` livrés) + **ES-5** (`done`). Réutilise l'**existant livré** de `zcrud_markdown` (E6-1..E6-4/DP-3/DP-22/MIN-1) : `ZMarkdownField`, `ZMarkdownReader`, `ZCodec`/`ZDeltaCodec`.

> ✅ **Périmètre VÉRIFIÉ** : PRD `FR-S25` = « Édition/lecture de notes via `zcrud_markdown` + migration des tables » ; table de traçabilité epics l. 129 → **ES-6.1** = édition/lecture (la migration tables/sticky-notes est **ES-6.2**). Aucune ligne de migration/adaptateur ne doit être écrite ici.

---

## Story

**As a** utilisateur d'une app d'étude (lex_douane, IFFD),
**I want** éditer et lire le corps riche d'une `ZSmartNote` via `ZMarkdownField`/`ZMarkdownReader` réutilisés **tels quels**,
**so that** je bénéficie du pipeline rich-text éprouvé (controller Quill **isolé**, focus/sélection préservés — objectif produit n°1) **sans qu'un développeur réimplémente un codec ou un éditeur** (SM-S4), et **sans jamais perdre** un corps de note markdown legacy dans l'aller-retour domaine → éditeur → domaine (dette **DW-ES22-1**).

---

## ⚠️ LE FAIT STRUCTURANT : `note.content` EST DÉJÀ la « valeur neutre » de `ZCodec`

Mesuré sur disque (`packages/zcrud_note/lib/src/domain/z_note_content.dart`, `z_smart_note.dart`) :

- `ZSmartNote.content` est **typé `List<Map<String, dynamic>>`** (ops Delta neutres), **jamais** une `String` ambiguë (AD-28, D3).
- Toute construction (`fromMap`, `copyWith`) passe le contenu par **`normalizeNoteContentOps`** : une `String` markdown legacy (`'# Titre'`) **survit VERBATIM** en `[{'insert': '# Titre\n'}]` — **jamais `[]`** (D5).
- La « valeur neutre » que consomment `ZMarkdownField`/`ZMarkdownReader`/`ZCodec` (`z_codec.dart` l. 5-9, `z_markdown_field.dart` l. 102-104) **EST EXACTEMENT** ce type `List<Map<String, dynamic>>`.

⇒ **Le pont domaine ↔ éditeur est une IDENTITÉ, zéro conversion** (dartdoc de `z_smart_note.dart` l. 30-35 : *« ES-6.1 branchera `note.content` sur l'éditeur sans transformer quoi que ce soit »*). Le **codec applicable est `ZDeltaCodec` (identité)** — c'est pourquoi **aucun nouveau codec n'est créé** (contrainte épic / AD-28 / SM-S4).

---

## 🔴 DETTE BLOQUANTE À RÉCONCILIER **DANS CETTE STORY** — DW-ES22-1

`packages/zcrud_note/test/source_policy_test.dart` (groupe `DW-ES22-1`, l. 117-188) épingle en machine, et exige explicitement **« RÉCONCILIER AVANT de brancher `note.content` sur `ZMarkdownField` (ES-6.1) »** :

| Entrée `String` markdown | `zcrud_note.normalizeNoteContentOps` | `zcrud_markdown` `DeltaNeutralOps.asDeltaOps` → `decodeDefensiveOps` |
|---|---|---|
| `'# T'` | `[{'insert':'# T\n'}]` ✅ **PRÉSERVE** | `null` ⇒ `[]` ⛔ **DÉTRUIT** |

**Nature réelle de la dette** (mesurée) : ce n'est PAS une simple duplication de ~20 lignes, c'est une **divergence sémantique SUR LA PRÉSERVATION DES DONNÉES**. Un aller-retour domaine → éditeur → domaine **effacerait** un corps markdown legacy **SI** une `String` brute atteignait `asDeltaOps`.

**Résolution retenue (D4) — par CONSTRUCTION, pas par patch de `zcrud_markdown`** : le contenu qui entre dans `ZMarkdownField` est **TOUJOURS `note.content`**, c.-à-d. **déjà des ops `List<Map>` canoniques** (le domaine a déjà exécuté `normalizeNoteContentOps`). La branche destructrice `asDeltaOps(String)→null→[]` **n'est jamais atteinte** : `asDeltaOps(List d'ops portant insert)` **conserve les ops** (`delta_neutral_ops.dart` l. 29-49). Le widget **NE DOIT JAMAIS** passer une `String` brute au champ.

⇒ La réconciliation d'ES-6.1 = (1) **garantir en code** que seul `note.content` (ops) est injecté ; (2) **PROUVER par test discriminant** que le round-trip complet **préserve** un corps né d'un markdown legacy (AC5) ; (3) **conserver le verrou-source** DW-ES22-1 tant que `DeltaNeutralOps` reste privé (il l'est — `zcrud_markdown.dart` ne l'exporte pas).

---

## Contexte fichiers EXISTANTS lus (état AVANT — à préserver)

### `zcrud_markdown` (RÉUTILISÉ tel quel — NE PAS MODIFIER)
- `lib/src/presentation/z_markdown_field.dart` — `ZMarkdownField` : voie **`controller`** (`ZFormController` + `ZFieldSpec`, E6-1) **et** voie **`fromContext`** (`ZFieldWidgetContext`, DP-3). Controller Quill **créé UNE FOIS** en `initState`, jamais recréé (l. 349-358) ; abonnement `document.changes` annulé au `dispose` (l. 415-424) ; **sync guardée hors focus** (l. 527-544) ; **valeur NEUTRE** en signature (l. 102-104) ; `field.readOnly` honoré (rendu lecteur). `persistedValueOf(...)` = couture de persistance publique.
- `lib/src/presentation/z_markdown_reader.dart` — `ZMarkdownReader({required value, codec, label, placeholder})` : `QuillController` **readOnly**, aucun abonnement/aucune voie d'écriture (l. 68-116) ; décodage défensif (AD-10) ; `Semantics(readOnly:true)`.
- `lib/src/domain/z_codec.dart` — `ZCodec` (`encode`/`decode` 100% neutres) ; `ZDeltaCodec` = round-trip **IDENTITÉ**.
- `lib/zcrud_markdown.dart` (barrel) — exporte `ZMarkdownField`, `ZMarkdownReader`, `ZCodec`, `ZDeltaCodec`, `ZMarkdownFieldMode`. **N'exporte AUCUN symbole Quill** ni `DeltaNeutralOps` (privé) — l'isolation AD-1/AD-7 est garantie.

### `zcrud_core` (RÉUTILISÉ — NE PAS MODIFIER)
- `lib/src/presentation/z_form_controller.dart` — `ZFormController({initialValues, visibleFields})` : `ChangeNotifier` pur-Flutter, tranche mémoïsée par `name`, `setValue`/`valueOf`, **aucun rebuild global** sur `setValue` (AD-2). À créer UNE FOIS (initState) / `dispose()`.
- `lib/src/domain/edition/z_field_spec.dart` — `ZFieldSpec({required name, required type, label, readOnly, ...})` (const, pur-données). `EditionFieldType.markdown` pour le corps rich-text.
- `lib/src/presentation/edition/z_widget_registry.dart` — `ZFieldWidgetContext` (voie `ctx`).

### `zcrud_note` (ÉTAT AVANT — package PUR-DART à FAIRE BASCULER en Flutter)
- `lib/src/domain/z_smart_note.dart`, `z_note_content.dart`, `z_note_audio.dart`, `z_opaque_note_extension.dart` — **domaine pur, INCHANGÉ** (aucune ligne modifiée).
- `lib/zcrud_note.dart` (barrel) — exporte le domaine ; **à ÉTENDRE** avec les 2 widgets de présentation.
- `pubspec.yaml` — déclare **UNIQUEMENT** `zcrud_core` + `zcrud_annotations`, **pas de `sdk: flutter`** ; commentaire l. 44-53 : *« L'arête [vers `zcrud_markdown`] naîtra en ES-6.1, avec le PREMIER WIDGET »*. **À MODIFIER** (cf. D2).
- `test/source_policy_test.dart` — asserte `⛔ AUCUN import de zcrud_markdown / Flutter / Quill` **sur tout `lib/`** (l. 77-102) et pubspec sans `zcrud_markdown`/`sdk: flutter`. **CES GARDES VONT MORDRE** dès l'ajout du widget → à **RETARGETER** (R13), pas à supprimer (cf. D6).

---

## 🔴 DÉCISIONS DE CONCEPTION (D1..D6)

- **D1 — Réutilisation TOTALE, zéro nouveau codec/éditeur (AD-28/SM-S4).** Les deux widgets `zcrud_note` sont de **minces adaptateurs** : ils composent `ZMarkdownField`/`ZMarkdownReader` + `ZDeltaCodec`. **Interdit** : toute classe `implements ZCodec`, toute heuristique `startsWith('[')`/`contains('"insert"')`, tout `QuillController`/`Delta` manipulé à la main (isolé dans `zcrud_markdown`), toute conversion markdown↔Delta (c'est ES-6.2). Le codec = **`ZDeltaCodec` (identité)** puisque `note.content` est déjà la valeur neutre.

- **D2 — Nouvelle arête `zcrud_note → zcrud_markdown` + bascule Flutter (AD-1).** `pubspec.yaml` de `zcrud_note` ajoute `flutter: {sdk: flutter}` et `zcrud_markdown: ^0.1.0`. Conséquences ASSUMÉES (annoncées par le barrel/pubspec) :
  - le package devient **FLUTTER** → ses tests de **présentation** tournent sous **`flutter test`** (R14) ; les tests de **domaine** existants (`z_smart_note_test.dart`, `z_note_content_test.dart`, …) **restent verts** sous `flutter test` (ils n'importent pas Flutter — un package Flutter exécute aussi les tests pur-Dart).
  - `graph_proof.py` verra la nouvelle arête `zcrud_note → zcrud_markdown` (runtime `dependencies:`) : **ACYCLIQUE conservé** (`zcrud_markdown → zcrud_core` seul, jamais l'inverse), **CORE OUT=0 conservé**. À **rejouer** et noter.
  - `zcrud_markdown` reste **arête sortante `zcrud_core` uniquement** — non modifié.

- **D3 — Controller ISOLÉ + place stable (AD-2/AD-7, SM-1).** L'adaptateur d'édition :
  - crée le `ZFormController` **UNE FOIS** en `initState` (seed `{contentField.name: widget.note.content}`), le **`dispose()`** en `dispose` ; **jamais** recréé au rebuild.
  - rend `ZMarkdownField(controller: _form, field: _contentSpec, codec: const ZDeltaCodec(), key: ValueKey(_contentSpec.name))` — la **`ValueKey` est OBLIGATOIRE** (place stable : sans elle un rebuild parent volerait l'état ou recréerait le `QuillController` — `z_markdown_field.dart` l. 40-42).
  - **saisie à sens unique** : écoute la tranche `content` du `ZFormController` (ou expose `onChanged`) et **remonte** `widget.note.copyWith(content: ops)` à l'hôte — **jamais** de ré-injection dans le champ pendant l'édition (la sync guardée de `ZMarkdownField` s'en charge hors focus).

- **D4 — DW-ES22-1 réconciliée par construction + preuve (cf. section dédiée).** Seul `note.content` (ops déjà canoniques) entre dans le champ. Preuve discriminante AC5.

- **D5 — Perte de couverture `gate:web` sur `zcrud_note` (à ESCALADER, DW-ES-6.1-1).** `scripts/ci/gate_web_determinism.dart` (l. 103-133) **EXCLUT** tout package portant `sdk: flutter`. En faisant basculer `zcrud_note` en Flutter (D2), la **matrice de coercition D5** (`z_note_content_test.dart`, qui repose sur `jsonDecode` — déterminisme JS **réel**) **cesse d'être rejouée sous `dart test -p node`**. Ce n'est **pas** dans le périmètre d'ES-6.1 de re-splitter le package (cela réécrirait l'architecture des packages). ⇒ **Déferrer** : consigner **DW-ES-6.1-1** (`architecture.md § Deferred` + memlog) — option future : extraire le domaine pur dans un sous-package pour restaurer la couverture JS. **Aucune régression de test** n'en découle (les tests tournent toujours, sous VM) ; c'est une **perte de couverture de PLATEFORME**, à tracer explicitement.

- **D6 — Retarget des gardes de pureté (R13), jamais suppression.** `source_policy_test.dart` doit **RESTER MORDANT sur la pureté du DOMAINE** : retargeter les assertions *« aucun import Flutter/Quill/zcrud_markdown »* pour qu'elles couvrent **`lib/src/domain/` + `lib/src/data/`** (pureté conservée) et **AUTORISENT** `lib/src/presentation/`. L'assertion pubspec *« que core+annotations »* devient *« le domaine ne dépend que de core+annotations, l'arête `zcrud_markdown` est RÉSERVÉE à la présentation »*. **Interdit** : supprimer la garde (ce serait perdre la preuve que le domaine reste pur-Dart, réutilisable sans Flutter — NFR-S10). Le verrou-source `DW-ES22-1` (l. 143-188) est **CONSERVÉ** tant que `DeltaNeutralOps` est privé.

---

## Acceptance Criteria (à pouvoir discriminant — R12)

**AC1 — Lecture via `ZMarkdownReader` réutilisé.**
**Given** une `ZSmartNote` dont `content = [{'insert':'Bonjour **gras**\n'}]`
**When** on rend `ZSmartNoteReader(note: note)`
**Then** l'arbre contient exactement **un** `ZMarkdownReader` recevant `value == note.content` et `codec` = `ZDeltaCodec`, en lecture seule (aucune voie d'écriture).
> **Discrimine** : rougit si le reader n'est pas réutilisé (widget maison), si le contenu est transformé avant d'être passé, ou si un codec non-identité est employé.

**AC2 — Édition via `ZMarkdownField` réutilisé, controller `ZFormController` isolé.**
**Given** une `ZSmartNote`
**When** on rend `ZSmartNoteEditor(note: note, onChanged: ...)`
**Then** l'arbre contient exactement **un** `ZMarkdownField` (voie `controller`), portant `key == ValueKey(<contentField>)`, `codec` = `ZDeltaCodec`, seedé avec `note.content` ; le `ZFormController` est créé en `initState` et disposé en `dispose`.
> **Discrimine** : rougit sans `ValueKey`, si le field n'est pas réutilisé, ou si le controller est recréé au build.

**AC3 — SM-1 : édition sans rebuild du voisinage ni recréation de controller (AD-2).**
**Given** l'éditeur monté et le corps focalisé
**When** on tape **100 caractères** successifs
**Then** le `QuillController` **n'est jamais recréé** (même identité de `State`/controller du début à la fin) et le focus/sélection n'est **jamais perdu** ; le compteur de rebuild d'un widget témoin **frère** (hors tranche `content`) **reste à sa valeur initiale**.
> **Discrimine (LOAD-BEARING)** : rougit si l'adaptateur recrée le `ZFormController`/`ZMarkdownField` au rebuild (perte de focus) ou déclenche un rebuild global. Réutilise l'instrumentation `ZMarkdownFieldDebug` (`debugDocChangeCount`, `debugDocSubscriptionActive`) exposée par `zcrud_markdown`.

**AC4 — Saisie à sens unique : `onChanged` remonte une `ZSmartNote` mise à jour, contenu neutre.**
**Given** l'éditeur monté avec `onChanged`
**When** l'utilisateur modifie le corps
**Then** `onChanged` reçoit `note.copyWith(content: <ops neutres>)` où `content` est une `List<Map<String,dynamic>>` (jamais une `String`, jamais un type Quill), **titre/dossier/extension/extra préservés** ; **aucune** ré-injection n'écrase la sélection pendant la frappe.
> **Discrimine** : rougit si `onChanged` fuit un type Quill, écrase un autre champ de la note, ou si une valeur externe est ré-injectée en cours de frappe.

**AC5 — 🔴 DW-ES22-1 : round-trip d'un corps markdown LEGACY sans perte (réconciliation).**
**Given** `note = ZSmartNote.fromMap({'content': '# Titre markdown legacy'})` (⇒ `content == [{'insert':'# Titre markdown legacy\n'}]`, préservé par `normalizeNoteContentOps`)
**When** on monte `ZSmartNoteEditor(note: note, onChanged: capture)`, on focalise/défocalise **sans rien taper** (ou on tape puis efface), et on relit la note remontée
**Then** le corps **survit VERBATIM** — le texte `# Titre markdown legacy` est toujours présent dans les ops remontées ; **jamais `[]`**, jamais un corps vidé.
> **Discrimine (LOAD-BEARING)** : rougit **exactement** si l'implémentation passe une `String` brute à `ZMarkdownField` (⇒ `asDeltaOps(String)→null→[]` détruit le corps) au lieu des ops `note.content`. C'est la preuve EXÉCUTABLE de la réconciliation exigée par le verrou DW-ES22-1.

**AC6 — Décodage défensif (AD-10) : contenu vide/corrompu → rendu propre, jamais de throw.**
**Given** une `ZSmartNote` avec `content == []` (ou une note construite d'une map vide)
**When** on rend l'éditeur ET le reader
**Then** aucun `throw` ; l'éditeur rend un document **vide éditable**, le reader rend le **placeholder** — parité stricte avec le comportement défensif de `zcrud_markdown`.

**AC7 — AD-13/FR-26 : accessibilité & thème injecté.**
**Given** l'éditeur et le reader montés
**Then** les cibles interactives introduites par l'adaptateur (le cas échéant) sont **≥ 48 dp**, les libellés portent des `Semantics` explicites, le rendu est **directionnel** (aucun `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`), **aucune couleur codée en dur** (thème via `ZcrudTheme`/`Theme.of`). *(Les widgets `zcrud_markdown` réutilisés portent déjà ces garanties — l'adaptateur ne doit pas les régresser.)*

**AC8 — Isolation de type conservée (AD-1/AD-7) : aucun symbole Quill dans la surface publique de `zcrud_note`.**
**Given** le barrel `lib/zcrud_note.dart` étendu des 2 widgets
**Then** aucun type `flutter_quill` (`QuillController`/`Document`/`Delta`) n'apparaît dans la signature publique de `ZSmartNoteEditor`/`ZSmartNoteReader` ; les entrées/sorties publiques sont `ZSmartNote`, callbacks `void Function(ZSmartNote)`, valeurs neutres. Le domaine (`lib/src/domain/`, `lib/src/data/`) **reste libre de tout import Flutter/Quill/zcrud_markdown** (garde retargetée D6).

**AC9 — Aucun nouveau codec / aucune duplication de `zcrud_markdown` (SM-S4, scan machine).**
**Given** `lib/` de `zcrud_note`
**Then** un scan confirme : **zéro** `implements ZCodec`, **zéro** ré-implémentation d'éditeur/lecteur rich-text, **zéro** heuristique textuelle markdown-vs-Delta ; les widgets de présentation **importent** `package:zcrud_markdown/zcrud_markdown.dart`.

**AC10 — Graphe & runner (AD-1, R14).**
**Given** le workspace
**Then** `graph_proof.py` prouve l'acyclicité et `out-degree(zcrud_core)==0` **avec** la nouvelle arête `zcrud_note → zcrud_markdown` ; `melos list` inchangé (20 packages) ; `zcrud_note` est routé vers **`flutter test`** (bascule Flutter D2).

---

## Deliverables (D1..Dn)

- **D1** `packages/zcrud_note/lib/src/presentation/z_smart_note_reader.dart` — `ZSmartNoteReader({required ZSmartNote note, String? placeholder, Key? key})` : `StatelessWidget` composant `ZMarkdownReader(value: note.content, codec: const ZDeltaCodec(), label: note.title, placeholder: ...)`.
- **D2** `packages/zcrud_note/lib/src/presentation/z_smart_note_editor.dart` — `ZSmartNoteEditor({required ZSmartNote note, required ValueChanged<ZSmartNote> onChanged, Key? key})` : `StatefulWidget` détenant un `ZFormController` isolé (initState/dispose), un `ZFieldSpec` const `content` (`EditionFieldType.markdown`), rendant `ZMarkdownField` (voie `controller`, `ValueKey`, `ZDeltaCodec`), écoutant la tranche `content` → `onChanged(note.copyWith(content: ops))`. **Sens unique**, aucune ré-injection.
- **D3** `packages/zcrud_note/lib/zcrud_note.dart` — barrel ÉTENDU : `export 'src/presentation/z_smart_note_editor.dart' show ZSmartNoteEditor;` + `export 'src/presentation/z_smart_note_reader.dart' show ZSmartNoteReader;` (n'expose **aucun** type Quill).
- **D4** `packages/zcrud_note/pubspec.yaml` — ajoute `flutter: {sdk: flutter}` + `zcrud_markdown: ^0.1.0` ; commentaire d'arête mis à jour (l'arête ES-6.1 est **née**) ; note la bascule runner (R14) et la perte `gate:web` (DW-ES-6.1-1).
- **D5** `packages/zcrud_note/test/z_smart_note_reader_test.dart` — AC1, AC6 (reader), AC7 (a11y basique).
- **D6** `packages/zcrud_note/test/z_smart_note_editor_test.dart` — AC2, AC3 (SM-1 : 100 frappes, controller stable, témoin frère), AC4 (sens unique), AC5 (**DW-ES22-1 round-trip legacy**), AC6 (défensif), AC8 (isolation type).
- **D7** `packages/zcrud_note/test/source_policy_test.dart` — **RETARGET** (D6) : pureté domaine `lib/src/domain/`+`lib/src/data/` ; présentation autorisée à importer Flutter/Quill/zcrud_markdown ; AC9 (scan no-codec/no-dup) ; verrou DW-ES22-1 conservé.
- **D8** `architecture.md § Deferred` + memlog — **DW-ES-6.1-1** (perte couverture `gate:web` sur `zcrud_note` après bascule Flutter). *(Édition documentaire hors code ; si l'orchestrateur préfère, consigner dans le code-review de la story.)*

---

## Tâches (T1..Tn)

- **T1** — `pubspec.yaml` : ajouter `flutter`/`zcrud_markdown`, mettre à jour les commentaires d'arête ; `dart pub get` (workspace) VERT.
- **T2** — `ZSmartNoteReader` (D1) : composition `ZMarkdownReader` + `ZDeltaCodec`, aucun type Quill en surface.
- **T3** — `ZSmartNoteEditor` (D2) : `ZFormController` isolé (initState/dispose), `ZFieldSpec` const `content`, `ZMarkdownField` (voie controller, `ValueKey`, `ZDeltaCodec`), écoute tranche → `onChanged(copyWith)`. Sens unique.
- **T4** — Barrel (D3) : exports `show ZSmartNoteEditor`/`show ZSmartNoteReader`.
- **T5** — Tests reader (D5) + éditeur (D6) : **AC3 SM-1** et **AC5 DW-ES22-1** en priorité (pouvoir discriminant).
- **T6** — Retarget `source_policy_test.dart` (D7) : garde de pureté domaine, autorisation présentation, scan AC9, verrou DW-ES22-1 conservé.
- **T7** — DW-ES-6.1-1 (D8) : consigner la perte de couverture `gate:web`.
- **T8** — Vérif verte (cf. section) : `flutter test` (zcrud_note) + `graph_proof.py` + `melos analyze` ciblé.

---

## Injections R3 prévues (preuve NON-POWERLESS — chaque garde rougit quand on la neutralise)

1. **AC3 (SM-1)** : dans le test, remplacer temporairement la création `initState` du `ZFormController` par une création **dans `build`** ⇒ le controller se recrée à chaque frappe ⇒ AC3 doit **ROUGIR** (perte de focus / identité de controller changée). Rétablir.
2. **AC5 (DW-ES22-1)** : injecter dans l'éditeur une variante qui passe **`jsonEncode(note.content)` (String)** — ou la valeur brute non normalisée — à `ZMarkdownField` au lieu des ops ⇒ `asDeltaOps(String)→null→[]` ⇒ AC5 doit **ROUGIR** (corps `# Titre markdown legacy` effacé). Rétablir. C'est la preuve EXÉCUTABLE de la réconciliation.
3. **AC8/D6 (pureté)** : ajouter temporairement un `import 'package:flutter/material.dart';` dans un fichier de `lib/src/domain/` ⇒ la garde retargetée doit **ROUGIR** ; l'ajouter dans `lib/src/presentation/` ⇒ **VERTE** (autorisée). Prouve que le retarget mord encore là où il faut.
4. **AC9 (no-codec)** : injecter une classe `class _X implements ZCodec {}` dans `lib/` ⇒ le scan AC9 doit **ROUGIR**. Rétablir.

> **R13 — restauration par édition CIBLÉE** : chaque injection est retirée après observation du rouge ; aucune garde n'est laissée neutralisée.

---

## Vérif verte à rejouer RÉELLEMENT (RC capturé HORS pipe — R15)

```bash
# 1) Résolution workspace après bascule Flutter de zcrud_note
dart pub get   # RC=0

# 2) Runner FLUTTER (R14 — zcrud_note est désormais un package Flutter)
cd packages/zcrud_note && flutter test ; echo "RC=$?"   # RC=0, N tests

# 3) Graphe : acyclicité + CORE OUT=0 AVEC la nouvelle arête zcrud_note→zcrud_markdown
cd ../../ && python3 scripts/dev/graph_proof.py ; echo "RC=$?"   # RC=0

# 4) Analyse ciblée (repo-wide au gate de commit d'epic, cf. CLAUDE.md)
dart run melos exec --scope="zcrud_note" -- dart analyze ; echo "RC=$?"   # RC=0
```

> ⚠️ **RC capturé hors pipe** (R15) : `cmd ; echo "RC=$?"`, jamais `cmd | tee` (le RC d'un pipe est celui de `tee`).
> ⚠️ **Bascule Flutter** : ne PAS lancer `dart test` dans `zcrud_note` après D2 (un package Flutter le refuse) — utiliser `flutter test`. Le tag `@TestOn('vm')` de `source_policy_test.dart` reste valide sous `flutter test`.
> ⚠️ **`gate:web`** : `zcrud_note` sort de sa cible (Flutter) — c'est **attendu** (D5/DW-ES-6.1-1), pas une régression.

---

## Dépendances & séquencement

- **Dépend de** : ES-2 (`done`), ES-5 (`done`), + l'existant livré de `zcrud_markdown`/`zcrud_core`.
- **∥ PARALLÉLISABLE** avec **ES-7.2** (`zcrud_mindmap`) et **ES-8.2** (`zcrud_document/presentation`) — fichiers disjoints, seul point de contact possible = `zcrud_core` (qu'**aucune** des trois n'écrit ici).
- **SÉQ AVANT ES-6.2** : même package `zcrud_note` ; ES-6.2 (migration tables/sticky-notes + comblement éventuel de `zcrud_markdown`) s'appuie sur les widgets d'ES-6.1.
- ⛔ **Ne jamais** mettre ES-6.1 en vol avec une story écrivant aussi `zcrud_note`.

---

## Invariants AD applicables (rappel — s'appliquent à CHAQUE tâche)

AD-1 (acyclique, CORE OUT=0, arête sortante = core ; l'arête `zcrud_note→zcrud_markdown` est la SEULE nouvelle) · AD-2 (Flutter-native, controller isolé, `ValueKey`, sens unique, zéro rebuild global — SM-1) · AD-7 (Delta interne, `ZCodec` pluggable = `ZDeltaCodec` identité, valeur neutre) · AD-10 (décodage défensif, jamais de throw) · AD-13/FR-26 (directionnel, `Semantics`, ≥48 dp, thème injecté) · AD-28 (contenu typé, aucune heuristique, aucun nouveau codec) · SM-S4 (aucun nouveau pipeline rich-text) · NFR-S10 (le domaine `zcrud_note` reste importable/pur — garde retargetée).

---

## Questions / clarifications (non bloquantes)

1. **DW-ES-6.1-1 (perte `gate:web`)** : accepter la perte documentée pour ES-6.1, ou planifier dès maintenant une extraction `zcrud_note_domain` pur-Dart ? *Recommandation story : accepter+déferrer (l'extraction réécrirait l'architecture des packages, hors périmètre M).*
2. **Ergonomie éditeur** : `ZSmartNoteEditor` expose-t-il aussi le **titre** (champ texte) en plus du corps, ou uniquement le corps rich-text ? *Recommandation : ES-6.1 = corps uniquement (le titre est un champ de schéma `DynamicEdition` standard) ; à confirmer par l'hôte.* — **Décision d'implémentation : corps uniquement** (le titre alimente la sémantique du reader via `note.title`).

---

## Tâches (état)

- [x] **T1** — `pubspec.yaml` : bascule Flutter + arêtes `flutter`/`zcrud_markdown` ; `dart pub get` VERT.
- [x] **T2** — `ZSmartNoteReader` (D1) : composition `ZMarkdownReader` + `ZDeltaCodec`, aucun type Quill en surface.
- [x] **T3** — `ZSmartNoteEditor` (D2) : `ZFormController` isolé (initState/dispose), `ZFieldSpec` const `content`, `ZMarkdownField` (voie controller, `ValueKey`, `ZDeltaCodec`), écoute tranche → `onChanged(copyWith)`. Sens unique.
- [x] **T4** — Barrel (D3) : exports `show ZSmartNoteEditor`/`show ZSmartNoteReader`.
- [x] **T5** — Tests reader (D5) + éditeur (D6) : AC3 SM-1 et AC5 DW-ES22-1 en priorité (pouvoir discriminant prouvé par injections R3).
- [x] **T6** — Retarget `source_policy_test.dart` (D7) : garde de pureté domaine, autorisation présentation, scan AC9, verrou DW-ES22-1 conservé.
- [x] **T7** — DW-ES-6.1-1 (D8) : perte de couverture `gate:web` consignée (pubspec + `source_policy_test`) ; escalade `architecture.md § Deferred` **à faire par l'orchestrateur/code-review** (édition documentaire hors périmètre code de cette story — cf. D8).
- [x] **T8** — Vérif verte rejouée (voir Dev Agent Record).

---

## Dev Agent Record

### Completion Notes

- **Approche** : deux MINCES ADAPTATEURS de présentation, zéro nouveau codec, zéro duplication de `zcrud_markdown` (SM-S4/AD-28). `ZDeltaCodec` (identité) réutilisé car `note.content` EST déjà la valeur neutre de `ZCodec`.
- **DW-ES22-1 réconciliée PAR CONSTRUCTION (D4)** : `ZSmartNoteEditor` seed la tranche avec `note.content` (ops `List<Map>` canoniques) — jamais une `String` brute ⇒ la branche destructrice `asDeltaOps(String)→null→[]` n'est jamais atteinte. Preuve exécutable = AC5 (round-trip d'un corps `'# Titre markdown legacy'` sans perte).
- **Controller isolé (AD-2/AD-7, SM-1)** : `ZFormController` créé en `initState`, disposé en `dispose`, jamais recréé ; `ZMarkdownField` porte `ValueKey('content')` ; saisie à sens unique (écoute de tranche → `onChanged(note.copyWith(content: ops))`, aucune ré-injection).
- **Bascule Flutter (D2)** : `zcrud_note` devient package Flutter ; le DOMAINE reste PUR-DART (garde `source_policy_test` retargetée sur `lib/src/domain/` + `lib/src/data/`, présentation autorisée). Perte de couverture `gate:web` → **DW-ES-6.1-1** consignée (pubspec + test), à escalader dans `architecture.md § Deferred`.
- **Isolation de type (AC8)** : barrel `zcrud_note.dart` n'exporte AUCUN symbole Quill ; `onChanged` remonte une `ZSmartNote` à `content` neutre. `flutter_quill` n'est qu'une arête de TEST (dev_dependency) pour piloter la frappe réelle.
- **Preuves R3 (garde non-powerless)** — chaque injection observée ROUGE puis restaurée par édition ciblée :
  1. AC3/SM-1 : création du `ZFormController` dans `build` ⇒ `LateInitializationError` ⇒ ROUGE.
  2. AC5/DW-ES22-1 : seed d'une `String` brute dans `ZMarkdownField` ⇒ document VIDE (`asDeltaOps(String)→null→[]`) ⇒ ROUGE.
  3. D6 pureté : `import 'package:flutter/…'` dans `lib/src/domain/` ⇒ garde retargetée ROUGE.
  4. AC9 no-codec : classe `implements ZCodec` dans `lib/` ⇒ scan ROUGE.

### Vérif verte rejouée (RC hors pipe — R15)

- `dart pub get` (workspace) → **RC=0**.
- `flutter test` (zcrud_note, package Flutter — R14) → **RC=0, 147 tests** (88 domaine existants inchangés + 59 nouveaux présentation/politique).
- `python3 scripts/dev/graph_proof.py` → **RC=0** : ACYCLIQUE OK, CORE OUT=0 OK, arête `zcrud_note → zcrud_markdown` présente (41 arêtes, 20 nœuds).
- `dart run melos exec --scope="zcrud_note" -- dart analyze` → **RC=0**, *No issues found!*.

### File List

- **Modifié** `packages/zcrud_note/pubspec.yaml` (bascule Flutter, arête `zcrud_markdown`, dev-deps `flutter_test`/`flutter_quill`/`test`).
- **Modifié** `packages/zcrud_note/lib/zcrud_note.dart` (barrel étendu des 2 widgets).
- **Créé** `packages/zcrud_note/lib/src/presentation/z_smart_note_reader.dart`.
- **Créé** `packages/zcrud_note/lib/src/presentation/z_smart_note_editor.dart`.
- **Créé** `packages/zcrud_note/test/z_smart_note_reader_test.dart`.
- **Créé** `packages/zcrud_note/test/z_smart_note_editor_test.dart`.
- **Modifié** `packages/zcrud_note/test/source_policy_test.dart` (retarget pureté domaine + AC9 réutilisation + pubspec Flutter + verrou DW-ES22-1 conservé).

### Change Log

- ES-6.1 : édition/lecture de notes markdown via `ZSmartNoteEditor`/`ZSmartNoteReader` (réutilisation `zcrud_markdown`), bascule Flutter de `zcrud_note`, réconciliation DW-ES22-1 par construction, retarget des gardes de pureté.
