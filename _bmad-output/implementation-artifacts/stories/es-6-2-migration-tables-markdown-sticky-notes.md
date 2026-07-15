---
baseline_commit: f751d82fecf2f7b80104a32146a3c14dfa8ef38e
---

# Story ES-6.2 : Migration des tables markdown legacy + upgrade des sticky-notes (`zcrud_note` + comblement `zcrud_markdown`)

Status: review

- **Clé sprint-status** : `es-6-2-migration-tables-markdown-sticky-notes`
- **Epic** : ES-6 (Notes & markdown — réutilisation `zcrud_markdown`) — **SÉQ APRÈS ES-6.1** (`done`), même package `zcrud_note` + **comblement dans `zcrud_markdown`** (package d'origine, SM-S4).
- **Taille** : **M**
- **Parallélisation** : 🟡 **PARTIELLEMENT PARALLÉLISABLE** avec `ES-7.2` (`zcrud_mindmap`) — packages disjoints. ⛔ **NON parallélisable avec toute story écrivant `zcrud_markdown`** (cette story y ajoute une couture publique neutre). ⛔ **Ne jamais** mettre en vol avec une autre story écrivant `zcrud_note`.
  **Packages écrits** :
  - `packages/zcrud_note/` — **NOUVEAU** dossier `lib/src/data/` (migration), barrel étendu, `test/`.
  - `packages/zcrud_markdown/` — **COMBLEMENT** (SM-S4) : couture publique **neutre pur-Dart** de construction d'op embed tableau (le contrat `{table:{rows,columns,cells}}` devient réutilisable **sans** dupliquer, sans exposer de type Quill).
  - ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_study_kernel` NI `zcrud_firestore`.**
- **Couvre** : **FR-S25** (volet « migration des tables ») · **AD-28** (contenu typé, aucune heuristique, **aucun nouveau codec**), **AD-7** (rich-text Delta interne, `ZCodec` pluggable, valeur neutre), **AD-1** (graphe acyclique, CORE OUT=0), **AD-4** (extensibilité, `String` opaque, JSON-safe), **AD-10** (migration/décodage **DÉFENSIF** — jamais de throw, jamais de destruction), **AD-13/FR-26** (directionnel, `Semantics`, ≥ 48 dp, thème injecté — porté par les widgets réutilisés) · **SM-S4** (aucune duplication ; l'écart est comblé dans le package d'origine) · **NFR-S10** (le domaine `zcrud_note` reste pur-Dart).
- **Dépend de** : **ES-6.1** (`done` — `ZSmartNoteEditor`/`ZSmartNoteReader`, bascule Flutter de `zcrud_note`, arête `zcrud_note → zcrud_markdown` **née**, `note.content` = valeur neutre de `ZCodec`, `normalizeNoteContentOps` préservante), **ES-2** (`done` — `ZSmartNote`/`content`), l'existant **livré** de `zcrud_markdown` (E6-4 embed tableau `{table:{rows,columns,cells}}`, `ZTableEmbedBuilder` défensif).

> ✅ **Périmètre VÉRIFIÉ sur disque** : PRD `FR-S25` = « Édition/lecture de notes via `zcrud_markdown` **+ migration des tables** » ; table de traçabilité epics l. 129 → **ES-6.1** = édition/lecture (fait), **ES-6.2** = **migration tables + upgrade sticky-notes**. Les 3 blocs BDD de l'epic ES-6.2 (epics.md l. 822-840) sont : (1) table markdown IFFD `String` → structure `{rows,columns,cells}` **sans perte** ; (2) sticky-note IFFD (`TextField` texte plat) → **upgradée vers `ZCodec` (Delta JSON)** ; (3) tout écart de `zcrud_markdown` → comblé **dans `zcrud_markdown`**, jamais dupliqué (SM-S4).

---

## ⚠️ LE FAIT STRUCTURANT n°1 : la structure de table de `zcrud_markdown` existe DÉJÀ mais n'a AUCUNE couture de construction NEUTRE

Mesuré sur disque (`packages/zcrud_markdown/lib/src/presentation/z_table_embed.dart`) :

- L'embed tableau est l'op Delta **`{"insert": {"table": {"rows": R, "columns": C, "cells": [[...]]}}}`** — `Map` opaque **JSON-safe**, valeur neutre (jamais un type Quill). `kTableEmbedType == 'table'` ; clés `rows`/`columns`/`cells`. La **matrice `cells` est la source de vérité** (`_parseTable`, l. 108-126).
- `ZTableEmbedBuilder` rend cette structure **défensivement** (AD-10) : jagged / vide / non-`Map` → placeholder, **jamais de throw** (l. 89-99).
- **MAIS** : `kTableEmbedType`, les clés de structure, et **la seule façon de CONSTRUIRE l'op** vivent dans `z_table_embed.dart`, un fichier de **présentation** qui `import 'package:flutter/material.dart'` + `flutter_quill`. La construction d'op ne passe **QUE** par le dialogue Flutter `showZTableDialog` (interaction utilisateur). **Il n'existe AUCUNE couture pur-Dart, programmatique et neutre** pour fabriquer une op tableau à partir de données structurées.
- Le barrel **n'exporte NI `z_table_embed`, NI `ZTableEmbed`, NI `ZTableEmbedBuilder`, NI `kTableEmbedType`** (isolation AD-1/AD-7 — épinglée par `quill_signature_isolation_test.dart` l. 156-164).

⇒ **C'EST « l'écart de `zcrud_markdown` révélé par la migration »** (3e bloc BDD de l'epic). Un migrateur programmatique a besoin d'une **fabrique d'op embed tableau NEUTRE et pur-Dart**. La combler **dans `zcrud_markdown`** (jamais la dupliquer dans `zcrud_note` — SM-S4) fait de `kTableEmbedType`/la structure la **source unique de vérité** partagée par le builder de rendu **et** le migrateur.

## ⚠️ LE FAIT STRUCTURANT n°2 : le « sticky-note upgrade » EST DÉJÀ résolu par `normalizeNoteContentOps` — RÉUTILISER, ne rien réinventer

Mesuré (`packages/zcrud_note/lib/src/domain/z_note_content.dart` l. 106, 118-162) : une `String` texte plat non-Delta (sticky-note IFFD, `TextField` texte plat) traverse `normalizeNoteContentOps` et **survit VERBATIM** en `[{'insert': '<raw>\n'}]` — **jamais `[]`** (D5/HIGH-1). C'est **exactement** « upgrader un texte plat vers `ZCodec` (Delta JSON) ». ⇒ Le volet sticky-note de la migration **DÉLÈGUE à `normalizeNoteContentOps`** : **aucune** nouvelle coercition, **aucune** heuristique (AD-28/SM-S4).

## ⚠️ LE FAIT STRUCTURANT n°3 : `note.content` est DÉJÀ des ops neutres — le markdown table brut y vit comme TEXTE dans une op `insert`

Une note legacy IFFD/lex (`content: String` markdown) chargée via `ZSmartNote.fromMap` devient, par `normalizeNoteContentOps`, **une op texte unique** : `[{'insert': 'Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nOutro\n'}]`. Le corps **est préservé** (ES-6.1/D5) mais le tableau y reste du **markdown BRUT dans le texte** — non structuré, non rendu comme grille. **Le travail d'ES-6.2 = l'UPGRADE structurel** : détecter le bloc de table GFM (pipe-table) DANS le texte et le remplacer par l'op embed structurée, en **préservant intégralement la prose environnante et son ordre**. Ce travail était **explicitement déféré à ES-6.2** par `z_note_content.dart` l. 152-156 (*« Le rendu RICHE du markdown reste le travail EXPLICITE d'ES-6.2 — jamais une devinette faite ici »*).

---

## 🔴 TENSION DÉCOUVERTE SUR DISQUE (à trancher dans cette story) — FINDING-ANTICIPÉ-1

Le chemin nommé par l'epic pour le migrateur est **`packages/zcrud_note/lib/src/data/z_note_table_migration.dart`**. Or la garde de pureté **retargetée en ES-6.1 (D6)** — `source_policy_test.dart` › groupe `D6 / NFR-S10` — couvre **`lib/src/domain/` + `lib/src/data/`** et **interdit tout import `package:zcrud_markdown/`** sur ces deux dossiers. Le migrateur **DOIT** importer la fabrique neutre de `zcrud_markdown` (fait structurant n°1). ⇒ **conflit direct** entre le chemin epic et la garde ES-6.1.

**Résolution retenue (D3, ci-dessous) — RE-TARGET, jamais suppression** (même principe que D6 d'ES-6.1) : la garde de **pureté stricte** est re-scopée à **`lib/src/domain/` UNIQUEMENT** (où vivent `z_smart_note.dart`, `z_note_content.dart`, `z_note_audio.dart` — le **cœur réutilisable pur-Dart**, NFR-S10 intact). **`lib/src/data/` devient une couche d'ADAPTATION legacy** autorisée à importer la couture **neutre** de `zcrud_markdown` (le migrateur est, par nature, couplé au format cible) — **MAIS** une **NOUVELLE** garde interdit à `data/` tout import **DIRECT** de `package:flutter/` ou `package:flutter_quill/` : la couche data ne connaît que la **couture neutre**, jamais Quill.

---

## Contexte fichiers EXISTANTS lus (état AVANT — à préserver)

### `zcrud_markdown` (COMBLEMENT ciblé — le RESTE inchangé)
- `lib/src/presentation/z_table_embed.dart` — **E6-4**. `kTableEmbedType = 'table'` (l. 36), clés `rows`/`columns`/`cells` (l. 39-41, **actuellement `private`**), `ZTableEmbed`/`ZTableEmbedBuilder` (Quill, **non publics**), rendu défensif `_parseTable` (jagged/vide → placeholder). **À TOUCHER a minima** (D1) : n'y **déplacer** `kTableEmbedType` (+ clés de structure) que si nécessaire pour la source unique ; **préserver le comportement E6-4** (rendu défensif, dialogue, isolation).
- `lib/src/presentation/z_rich_text_core.dart` l. 268-272 — consomme `kTableEmbedType` pour re-typer l'op → **ne PAS régresser** (préserver la ré-édition de table sous le caret).
- `lib/zcrud_markdown.dart` (barrel) — **N'exporte PAS** `z_table_embed`/`ZTableEmbed`/`ZTableEmbedBuilder`/`kTableEmbedType` (isolation épinglée). **À ÉTENDRE** : `show` de la **couture neutre** uniquement (aucun type Quill, aucun symbole interdit par `quill_signature_isolation_test.dart` l. 156-164).
- `lib/src/data/delta_neutral_ops.dart` — `DeltaNeutralOps` **privé** (non exporté), coercition neutre + `_embedPlaceholder` (perte bornée à l'embed). **NE PAS exposer** (préserve le verrou DW-ES22-1, `source_policy_test.dart` l. 263-273).

### `zcrud_note` (état APRÈS ES-6.1 — présentation livrée, domaine pur ; on AJOUTE une couche `data/`)
- `lib/src/domain/z_note_content.dart` — `normalizeNoteContentOps` (préservante, D5), `noteContentEquals`/`noteContentHash` (égalité profonde). **RÉUTILISER pour le sticky-note upgrade** ; **NE PAS modifier**.
- `lib/src/domain/z_smart_note.dart` — `ZSmartNote` + `copyWith(content:)` (sentinelle). Le migrateur produit des ops → l'hôte fait `note.copyWith(content: migratedOps)`. **NE PAS modifier.**
- `lib/src/presentation/z_smart_note_editor.dart`/`z_smart_note_reader.dart` — **inchangés** (le corps migré s'affiche déjà via l'embed tableau natif de `zcrud_markdown`).
- `lib/zcrud_note.dart` (barrel) — exporte domaine + 2 widgets. **À ÉTENDRE** de l'API de migration (`show`).
- `test/source_policy_test.dart` — garde de pureté **domain+data** (l. 134-162), scan **no-codec / no-heuristique** (l. 45-125), verrou DW-ES22-1 (l. 229-274). **À RETARGET (D3)** : pureté stricte → `domain/` seul ; nouvelle garde « `data/` sans Flutter/Quill direct, couture neutre autorisée » ; **conserver** le scan no-codec (sur TOUT `lib/`) et le verrou DW-ES22-1.

---

## 🔴 DÉCISIONS DE CONCEPTION (D1..D6)

- **D1 — COMBLEMENT dans `zcrud_markdown` : fabrique d'op embed tableau NEUTRE, pur-Dart, JSON-safe (SM-S4/AD-1/AD-7).** Nouveau fichier **`packages/zcrud_markdown/lib/src/data/z_table_embed_ops.dart`** (nom **≠** `z_table_embed` pour ne pas déclencher `quill_signature_isolation_test.dart`), **PUR-DART** (aucun `import 'package:flutter*'`) :
  - `const String kTableEmbedType` (**source unique** — `z_table_embed.dart` l'importe désormais d'ici) + clés de structure publiques/partagées ;
  - `Map<String, dynamic> zTableEmbedOp({required List<List<String>> cells})` → `{'insert': {kTableEmbedType: {'rows': cells.length, 'columns': cells.isEmpty ? 0 : cells.first.length, 'cells': <copie JSON-safe>}}}`. **Coerce chaque cellule en `String`**, **normalise** (padde) les lignes jagged à la largeur max **AVANT** de produire (jamais d'op qui ferait planter le rendu natif). Renvoie une **valeur neutre non modifiable**.
  - Barrel `zcrud_markdown.dart` : `export 'src/data/z_table_embed_ops.dart' show zTableEmbedOp, kTableEmbedType;` — **aucun** type Quill. **Interdit** : exporter `ZTableEmbed`/`ZTableEmbedBuilder` (garde d'isolation).
  - `z_table_embed.dart`/`z_rich_text_core.dart` : re-câblés sur le `kTableEmbedType` **importé** de la nouvelle couture (zéro changement de comportement E6-4).

- **D2 — MIGRATEUR dans `zcrud_note/lib/src/data/z_note_table_migration.dart` (couche d'adaptation legacy).** API publique **pur-données** (aucun widget, aucun type Quill en surface) :
  - `List<Map<String, dynamic>> zMigrateStickyNote(Object? raw)` → **DÉLÈGUE à `normalizeNoteContentOps`** (texte plat → ops neutres, verbatim, jamais `[]`). Aucune nouvelle coercition (AD-28).
  - `List<Map<String, dynamic>> zMigrateNoteTables(List<Map<String, dynamic>> ops)` → parcourt les ops ; dans chaque op **texte** (`insert` = `String`), détecte les **blocs de table GFM** (`| … |` + ligne séparatrice `|---|`/`:--:` …), les **remplace** par `zTableEmbedOp(cells: …)` (couture D1), et **ré-émet le texte environnant** (avant/après) en ops texte **dans l'ordre**. Les ops **embed déjà présentes** (`insert` = `Map`) sont **conservées VERBATIM** (idempotence). **DÉFENSIF (AD-10)** : un bloc qui *ressemble* à une table mais est **malformé** (jagged non réconciliable, séparateur absent/incohérent, une seule ligne) **N'est PAS** structuré → le texte **survit VERBATIM** ; **jamais** de throw, **jamais** d'op supprimée.
  - `List<Map<String, dynamic>> zUpgradeLegacyNoteContent(Object? raw)` → composition : `zMigrateNoteTables(normalizeNoteContentOps(raw))` — le point d'entrée « corpus legacy → contenu canonique upgradé ».
  - La **détection de table est STRUCTURELLE** (forme pipe-table ligne à ligne), **JAMAIS** la devinette markdown-vs-Delta d'IFFD (`startsWith('[') && contains('"insert"')`) — bannie R5 (scan AC7).

- **D3 — RE-TARGET de la garde de pureté (jamais suppression — cf. FINDING-ANTICIPÉ-1).** `source_policy_test.dart` :
  - Pureté **stricte** (aucun `package:zcrud_markdown/`, `package:flutter/`, `package:flutter_quill/`, firestore, kernel) **re-scopée à `lib/src/domain/` SEUL** (NFR-S10 : le cœur reste importable pur-Dart).
  - **NOUVELLE garde** sur `lib/src/data/` : autorise `package:zcrud_markdown/zcrud_markdown.dart` (couture neutre) **MAIS interdit** tout import **DIRECT** `package:flutter/` et `package:flutter_quill/` (la couche data ne connaît que la couture neutre).
  - **Conservés** : scan **no-codec / no-heuristique textuelle** sur **TOUT `lib/`** (AC7) ; verrou **DW-ES22-1** (l. 229-274) ; garde pubspec (arête `zcrud_markdown` déjà née).

- **D4 — PRÉSERVATION INTÉGRALE = invariant central (AD-10, cohérent DW-ES22-1).** Comme le principe D5 d'ES-2.2 : **aucune** entrée portant du contenu ne doit produire une perte. La migration est **additive et réversible sur la donnée** : tout caractère de prose survit ; une table valide devient structure `{rows,columns,cells}` **sans perte de cellule** ; une table **invalide** reste du **texte** (dégradation gracieuse, jamais destruction). Prouvé par round-trips discriminants (AC2/AC3/AC5).

- **D5 — Graphe INCHANGÉ (AD-1).** Aucune **nouvelle arête** : `zcrud_note → zcrud_markdown` existe déjà (ES-6.1) ; la couture D1 vit dans `zcrud_markdown` (arête sortante `zcrud_core` seule, **inchangée**). `graph_proof.py` : acyclique + CORE OUT=0 **conservés** ; `melos list` = 20 packages **inchangé**. À **rejouer** et noter.

- **D6 — `gate:web` INCHANGÉ (pas de nouvelle dette de plateforme).** `zcrud_note` **et** `zcrud_markdown` sont **déjà** des packages Flutter → tous deux **déjà hors `gate:web`** (DW-ES-6.1-1 pré-existante, non aggravée). La couture D1 (pur-Dart mais logée dans un package Flutter) n'ajoute **aucune** perte. **Aucune nouvelle escalade `gate:web`.**

---

## Acceptance Criteria (à pouvoir discriminant — R12)

**AC1 — COMBLEMENT : fabrique d'op embed tableau NEUTRE exportée par `zcrud_markdown`.**
**Given** une matrice `cells = [['a','b'],['1','2']]`
**When** on appelle `zTableEmbedOp(cells: cells)`
**Then** le résultat est **exactement** `{'insert': {kTableEmbedType: {'rows': 2, 'columns': 2, 'cells': [['a','b'],['1','2']]}}}`, **JSON-safe** (`jsonDecode(jsonEncode(op))` égal en profondeur), **sans aucun type Quill** ; `kTableEmbedType == 'table'` est exporté ; le barrel n'expose **NI** `ZTableEmbed` **NI** `ZTableEmbedBuilder` **NI** `z_table_embed`.
> **Discrimine** : rougit si la fabrique est absente, si la structure n'est pas JSON-safe, si le type diverge de `kTableEmbedType`, ou si un symbole Quill/interne fuit dans le barrel.

**AC2 — Migration d'une table GFM `String` → structure `{rows,columns,cells}` SANS PERTE (bloc BDD n°1).**
**Given** une table markdown legacy `'| a | b |\n|---|---|\n| 1 | 2 |'` (via `zUpgradeLegacyNoteContent`)
**When** on la migre
**Then** le résultat contient **exactement une** op embed `table` dont `cells == [['a','b'],['1','2']]` : la ligne d'**en-tête est conservée** comme 1re ligne, la ligne **séparatrice `|---|` n'est PAS** une ligne de données, **aucune cellule n'est perdue ni ajoutée**.
> **Discrimine (PRÉSERVATION)** : rougit si le séparateur est émis comme ligne de données, si l'en-tête est perdu, si une cellule est droppée/dupliquée.

**AC3 — Préservation de la PROSE environnante et de l'ORDRE (bloc BDD n°1, mixte).**
**Given** `zUpgradeLegacyNoteContent('Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nOutro')`
**When** on migre
**Then** les ops sortent **dans l'ordre** : op(s) texte portant `Intro` **avant** l'op embed `table`, op(s) texte portant `Outro` **après** ; la concaténation de tout le texte sortant **contient VERBATIM** `Intro` et `Outro` ; **rien** n'est réordonné ni perdu (seul le bloc table markdown brut est remplacé par sa structure).
> **Discrimine (PRÉSERVATION)** : rougit si la prose avant/après est perdue, tronquée, ou réordonnée par rapport à la table.

**AC4 — Upgrade sticky-note (texte plat) → `ZCodec`/Delta neutre, verbatim (bloc BDD n°2).**
**Given** un sticky-note IFFD texte plat `'Rappel: réviser le chapitre'`
**When** on appelle `zMigrateStickyNote('Rappel: réviser le chapitre')`
**Then** le résultat est `[{'insert': 'Rappel: réviser le chapitre\n'}]` — le texte **survit VERBATIM**, **jamais `[]`** ; l'implémentation **délègue à `normalizeNoteContentOps`** (aucune nouvelle coercition).
> **Discrimine (PRÉSERVATION)** : rougit si `[]` (texte détruit), si le texte est altéré, ou si une coercition maison remplace `normalizeNoteContentOps`.

**AC5 — 🔴 DÉFENSIF (AD-10) : une table MALFORMÉE est PRÉSERVÉE comme texte, jamais de throw, jamais d'embed jagged.**
**Given** un bloc pseudo-table **jagged/irrégulier** `'| a | b | c |\n|---|---|\n| 1 | 2 |'` (largeurs incohérentes) **ou** `'| seul |'` (pas de séparateur)
**When** on migre via `zUpgradeLegacyNoteContent`
**Then** **aucun** `throw` ; **aucune** op embed `table` produite pour ce bloc ; le texte brut **survit VERBATIM** dans une op texte (aucun caractère perdu). *(Si une table valide co-existe ailleurs dans le même contenu, elle, est bien structurée — la dégradation est BORNÉE au bloc invalide.)*
> **Discrimine (LOAD-BEARING)** : rougit si la migration throw sur un bloc malformé, si elle produit une op `table` **jagged** (qui ferait rendre le placeholder d'erreur / masquerait la donnée), ou si elle efface le texte du bloc invalide.

**AC6 — Idempotence : re-migrer un contenu DÉJÀ upgradé est un NO-OP profond.**
**Given** `final once = zUpgradeLegacyNoteContent(legacy);`
**When** on ré-applique `final twice = zMigrateNoteTables(once);`
**Then** `noteContentEquals(once, twice) == true` : une op embed `table` déjà présente est **conservée VERBATIM** (jamais ré-encapsulée, jamais son `cells` altéré), aucune double-migration.
> **Discrimine** : rougit si la ré-migration détruit/duplique/altère une op embed existante.

**AC7 — Aucun nouveau codec, aucune duplication du contrat table (SM-S4/AD-28, scan machine).**
**Given** `lib/` de `zcrud_note`
**Then** un scan confirme : **zéro** `implements ZCodec` ; **zéro** heuristique textuelle markdown-vs-Delta (`startsWith('[')` / `contains('"insert"')`) ; le migrateur **N'a PAS** de littéral `'table'`/`'rows'`/`'columns'`/`'cells'` **codé en dur** — il **importe** `zTableEmbedOp`/`kTableEmbedType` de `package:zcrud_markdown/zcrud_markdown.dart`.
> **Discrimine** : rougit si `implements ZCodec` apparaît, si l'heuristique textuelle IFFD réapparaît, ou si le contrat table est **dupliqué** (littéral en dur) au lieu d'être importé de l'origine (SM-S4).

**AC8 — Pureté RE-TARGET (D3) : domaine strict, data adapter neutre (NFR-S10).**
**Given** les sources de `zcrud_note`
**Then** `lib/src/domain/` **n'importe NI** `package:zcrud_markdown/` **NI** `package:flutter/` **NI** `package:flutter_quill/` (cœur pur-Dart) ; `lib/src/data/` **peut** importer `package:zcrud_markdown/zcrud_markdown.dart` (couture neutre) **mais N'importe NI** `package:flutter/` **NI** `package:flutter_quill/` **en DIRECT**.
> **Discrimine** : rougit si un import Quill/Flutter direct apparaît dans `domain/` ou `data/`, ou si `domain/` importe `zcrud_markdown`.

**AC9 — Comblement dans `zcrud_markdown` NON RÉGRESSIF (E6-4 préservé, isolation conservée).**
**Given** le comblement D1 appliqué
**Then** la suite existante `z_table_embed_test.dart` (E6-4) **reste verte** ; `ZTableEmbedBuilder` **rend** l'op produite par `zTableEmbedOp` (parité de structure) ; `quill_signature_isolation_test.dart` **reste vert** (barrel toujours exempt de `z_table_embed`/`ZTableEmbed`/`ZTableEmbedBuilder`) ; `z_rich_text_core.dart` (ré-édition sous caret) **inchangé** fonctionnellement.
> **Discrimine** : rougit si le refactor du constant casse E6-4, si l'op produite n'est pas rendable par le builder, ou si l'isolation du barrel régresse.

**AC10 — Graphe & runner (AD-1, R14) — INVARIANTS CONSERVÉS.**
**Given** le workspace
**Then** `graph_proof.py` prouve l'**acyclicité** et `out-degree(zcrud_core) == 0` ; **aucune nouvelle arête** (`zcrud_note → zcrud_markdown` déjà présente, couture D1 interne à `zcrud_markdown → zcrud_core`) ; `melos list` = **20 packages** inchangé ; `zcrud_note` **et** `zcrud_markdown` sont routés vers **`flutter test`**.

---

## Deliverables (D1..Dn)

- **D1** `packages/zcrud_markdown/lib/src/data/z_table_embed_ops.dart` — **NOUVEAU**, PUR-DART : `kTableEmbedType` (source unique) + clés de structure + `zTableEmbedOp({required List<List<String>> cells})` (JSON-safe, cellules coercées, lignes normalisées, valeur non modifiable). Dartdoc : rôle de couture neutre du comblement (SM-S4), interdiction d'y importer Flutter/Quill.
- **D2** `packages/zcrud_markdown/lib/src/presentation/z_table_embed.dart` — **MODIFIÉ a minima** : `kTableEmbedType` (+ clés) **importés** de D1 (plus de re-déclaration) ; comportement E6-4 **inchangé**.
- **D3** `packages/zcrud_markdown/lib/src/presentation/z_rich_text_core.dart` — **MODIFIÉ si nécessaire** : re-câblage sur `kTableEmbedType` importé de D1 (zéro changement fonctionnel).
- **D4** `packages/zcrud_markdown/lib/zcrud_markdown.dart` — barrel **ÉTENDU** : `export 'src/data/z_table_embed_ops.dart' show zTableEmbedOp, kTableEmbedType;` (aucun type Quill, aucun symbole interdit).
- **D5** `packages/zcrud_note/lib/src/data/z_note_table_migration.dart` — **NOUVEAU** : `zMigrateStickyNote`, `zMigrateNoteTables`, `zUpgradeLegacyNoteContent` (cf. D2 des décisions). Détection GFM structurelle, défensif AD-10, préservant.
- **D6** `packages/zcrud_note/lib/zcrud_note.dart` — barrel **ÉTENDU** : `export 'src/data/z_note_table_migration.dart' show zMigrateStickyNote, zMigrateNoteTables, zUpgradeLegacyNoteContent;`.
- **D7** `packages/zcrud_markdown/test/z_table_embed_ops_test.dart` — **NOUVEAU** : AC1 (structure/JSON-safe), AC9 (parité builder : `ZTableEmbedBuilder._parseTable`/rendu de l'op produite).
- **D8** `packages/zcrud_note/test/z_note_table_migration_test.dart` — **NOUVEAU** : AC2 (table→structure sans perte), AC3 (prose/ordre), AC4 (sticky verbatim), AC5 (**défensif malformé**), AC6 (idempotence), AC7 (scan no-codec/no-dup depuis les sources).
- **D9** `packages/zcrud_note/test/source_policy_test.dart` — **RETARGET (D3 des décisions)** : pureté stricte `domain/` seul ; nouvelle garde `data/` (zcrud_markdown neutre OK, Flutter/Quill direct interdits) ; scan no-codec conservé ; verrou DW-ES22-1 conservé ; AC8.
- **D10** `architecture.md § Deferred` + memlog — **note de clôture** : ES-6.2 **solde le volet « migration des tables » de FR-S25** ; **rappel** que **DW-ES22-2** (mapping legacy IFFD camelCase/`Timestamp`/`audioText`…) reste **HORS périmètre** (adapter `zcrud_firestore`, ES-3.5/ES-11.2 — AD-27), **jamais** dans le domaine ni dans ce migrateur. *(Édition documentaire hors code ; si l'orchestrateur préfère, consigner dans le code-review de la story.)*

---

## Tâches (T1..Tn)

- **T1** — **Comblement `zcrud_markdown`** (D1/D2/D3/D4) : créer `z_table_embed_ops.dart` (pur-Dart), y **déplacer** `kTableEmbedType` (+ clés), re-câbler `z_table_embed.dart`/`z_rich_text_core.dart` sur l'import, étendre le barrel (`show zTableEmbedOp, kTableEmbedType`).
- **T2** — Tests comblement (D7) : AC1 + AC9 (parité builder) ; **rejouer** `z_table_embed_test.dart` + `quill_signature_isolation_test.dart` VERTS (non-régression E6-4/isolation).
- **T3** — **Migrateur `zcrud_note`** (D5) : `zMigrateStickyNote` (délègue `normalizeNoteContentOps`), `zMigrateNoteTables` (détection GFM structurelle, défensif, préservant), `zUpgradeLegacyNoteContent` (composition). **Importe** la couture D1.
- **T4** — Barrel `zcrud_note` (D6) : exports `show`.
- **T5** — Tests migrateur (D8) : **AC2/AC3/AC5 (préservation + défensif) en PRIORITÉ** (pouvoir discriminant), puis AC4/AC6/AC7.
- **T6** — **RETARGET** `source_policy_test.dart` (D9) : pureté `domain/` stricte, garde `data/` neutre, scan no-codec conservé, verrou DW-ES22-1 conservé, AC8.
- **T7** — Escalade DW / clôture FR-S25 (D10) : consigner la note (ou déférer au code-review), **rappeler l'exclusion DW-ES22-2** (adapter, jamais ici).
- **T8** — Vérif verte (cf. section) : `flutter test` (`zcrud_markdown` **ET** `zcrud_note`) + `graph_proof.py` + `melos analyze` ciblé.

---

## Injections R3 prévues (preuve NON-POWERLESS — chaque garde rougit quand on neutralise la ligne de prod qui la porte)

1. **AC2/AC3 (préservation table)** : neutraliser la **détection de la ligne séparatrice** (`|---|`) dans `zMigrateNoteTables` (la traiter comme une ligne de données) ⇒ AC2 doit **ROUGIR** (`cells` gagne une ligne `['---','---']`). Rétablir.
2. **AC5 (défensif malformé — LOAD-BEARING)** : neutraliser la **garde de régularité** (produire une op `table` **même** sur des lignes jagged) ⇒ AC5 doit **ROUGIR** (op embed jagged produite / texte non préservé). Rétablir. C'est la preuve exécutable de la dégradation gracieuse AD-10.
3. **AC4 (sticky verbatim)** : remplacer la délégation `normalizeNoteContentOps` par un repli `[]` sur non-Delta ⇒ AC4 doit **ROUGIR** (texte `'Rappel…'` détruit). Rétablir.
4. **AC7 (no-dup SM-S4)** : coder en dur `const _t = 'table'` (au lieu d'importer `kTableEmbedType`) dans le migrateur ⇒ le scan AC7 doit **ROUGIR** (littéral de contrat dupliqué). Rétablir.
5. **AC8 (pureté RE-TARGET)** : (a) ajouter `import 'package:flutter/material.dart';` dans `lib/src/domain/` ⇒ garde domaine **ROUGE** ; (b) l'ajouter dans `lib/src/data/` ⇒ **ROUGE** (Flutter direct interdit même en data) ; (c) importer `package:zcrud_markdown/zcrud_markdown.dart` dans `lib/src/data/` ⇒ **VERT** (couture neutre autorisée), le **même** import dans `lib/src/domain/` ⇒ **ROUGE**. Prouve que le retarget mord au bon endroit.
6. **AC1/AC9 (comblement)** : changer le type émis par `zTableEmbedOp` en `'tbl'` (diverger de `kTableEmbedType`) ⇒ AC1 **ET** la parité builder AC9 doivent **ROUGIR**. Rétablir.

> **R13 — restauration par édition CIBLÉE** : chaque injection est retirée après observation du rouge ; aucune garde n'est laissée neutralisée.

---

## Vérif verte à rejouer RÉELLEMENT (RC capturé HORS pipe — R15 ; `flutter test` — R14)

```bash
# 1) Résolution workspace (aucune nouvelle arête ; couture interne à zcrud_markdown)
dart pub get   # RC=0

# 2) Runner FLUTTER (R14) — zcrud_markdown COMBLÉ puis zcrud_note MIGRATEUR
cd packages/zcrud_markdown && flutter test ; echo "RC=$?"   # RC=0 (E6-4 + isolation NON régressés + AC1/AC9)
cd ../zcrud_note        && flutter test ; echo "RC=$?"      # RC=0 (migrateur AC2..AC8 + suites ES-6.1/ES-2 intactes)

# 3) Graphe : acyclicité + CORE OUT=0 ; AUCUNE nouvelle arête ; melos list = 20 packages
cd ../../ && python3 scripts/dev/graph_proof.py ; echo "RC=$?"   # RC=0
dart run melos list | wc -l ; echo "RC=$?"                       # 20 packages

# 4) Analyse ciblée (repo-wide au gate de commit d'epic, cf. CLAUDE.md)
dart run melos exec --scope="zcrud_markdown" --scope="zcrud_note" -- dart analyze ; echo "RC=$?"   # RC=0
```

> ⚠️ **RC hors pipe** (R15) : `cmd ; echo "RC=$?"`, jamais `cmd | tee` (le RC d'un pipe est celui de `tee`).
> ⚠️ **Bascule Flutter** (déjà acquise ES-6.1) : `zcrud_note` **et** `zcrud_markdown` tournent sous **`flutter test`**, jamais `dart test`.
> ⚠️ **`gate:web`** : **inchangé** (les deux packages sont déjà Flutter, déjà exclus — D6). **Aucune** nouvelle dette de plateforme.
> ⚠️ **Gate commit d'epic (fin ES-6, orchestrateur)** : rejouer `melos run analyze` **ET** `melos run verify` **REPO-WIDE** (le comblement modifie une surface publique de `zcrud_markdown` — une régression cross-package n'est visible que repo-wide, cf. leçon `ZExportApi`).

---

## Dépendances & séquencement

- **Dépend de** : ES-6.1 (`done`), ES-2 (`done`), + l'existant livré `zcrud_markdown` (E6-4).
- **SÉQ APRÈS ES-6.1** : même package `zcrud_note` ; s'appuie sur la bascule Flutter et l'arête déjà nées.
- **∥** avec **ES-7.2** (`zcrud_mindmap`) — packages disjoints. ⛔ **NON ∥** avec toute story écrivant `zcrud_markdown` (comblement) ou `zcrud_note`.
- **Dernière story d'ES-6** → après son `done`, `bmad-retrospective` d'ES-6 (l'entrée `epic-es-6-retrospective` est `optional` au sprint-status — statuer en rétro/orchestrateur).

---

## Invariants AD applicables (rappel — s'appliquent à CHAQUE tâche)

AD-1 (acyclique, CORE OUT=0 ; **aucune nouvelle arête** ; comblement dans le package d'origine, jamais dupliqué) · AD-4 (valeur neutre JSON-safe, `String` opaque ; op embed = `Map` opaque) · AD-7 (Delta interne, `ZCodec` pluggable, valeur neutre ; aucun type Quill en surface) · AD-10 (**migration DÉFENSIVE** : malformé → préservé comme texte, jamais de throw, jamais de destruction) · AD-13/FR-26 (directionnel, `Semantics`, ≥ 48 dp, thème injecté — portés par les widgets `zcrud_markdown` réutilisés, l'op migrée s'affiche via le builder natif défensif) · AD-28 (contenu typé, **aucune heuristique textuelle**, **aucun nouveau codec**) · SM-S4 (écart comblé dans `zcrud_markdown`, jamais dupliqué) · NFR-S10 (domaine `zcrud_note` reste pur-Dart — garde retargetée D3).

---

## Findings / dettes ANTICIPÉS (à confirmer en dev/code-review)

- **FINDING-ANTICIPÉ-1 (tension chemin epic ↔ garde ES-6.1)** : `lib/src/data/` est couvert par la garde de pureté retargetée en ES-6.1 (D6) qui interdit `zcrud_markdown`. Le migrateur DOIT l'importer. **Résolu par D3** (re-target pureté → `domain/` seul + nouvelle garde `data/` neutre). **Rien à inventer côté build** : `zcrud_note` est déjà Flutter (ES-6.1).
- **FINDING-ANTICIPÉ-2 (isolation barrel)** : `quill_signature_isolation_test.dart` interdit au barrel les chaînes `z_table_embed`/`ZTableEmbed`/`ZTableEmbedBuilder`. La couture D1 est donc **nommée `z_table_embed_ops.dart`** (≠ `z_table_embed`) et **n'exporte que** `zTableEmbedOp`/`kTableEmbedType` (aucun symbole interdit). À vérifier explicitement (AC9).
- **DETTE HORS PÉRIMÈTRE (ne PAS traiter ici) — DW-ES22-2** : le mapping legacy IFFD (camelCase, `Timestamp`, `audioText`, `subjectId`/`creatorId`, `audioTextHash: int`) est dû dans l'**adapter `zcrud_firestore`** (ES-3.5/ES-11.2), **jamais** dans le domaine ni ce migrateur (AD-27). Ce migrateur opère sur des **ops neutres déjà normalisées** (contenu), pas sur la forme de persistance IFFD.
- **ESCALADE DOC (D10)** : consigner en `architecture.md § Deferred`/memlog la **clôture du volet « migration des tables » de FR-S25** et le rappel d'exclusion DW-ES22-2. Aucune **nouvelle** dette `gate:web` (D6).
- **PORTÉE VOLONTAIREMENT BORNÉE** : la migration cible **tables GFM (pipe-tables)** et **texte plat (sticky-notes)** — les seuls formats legacy nommés par l'epic. Les autres embeds (LaTeX/media) restent hors périmètre (déjà couverts E6-3/DP-22). Question ouverte : faut-il généraliser la couture neutre en `ZMarkdownEmbeds` (latex/media) ? *Recommandation : NON dans cette story M — ajouter au besoin, sans sur-concevoir.*

---

## Questions / clarifications (non bloquantes)

1. **Syntaxe de table legacy IFFD** : l'epic dit « table markdown IFFD (string) ». La cible retenue est le **pipe-table GFM standard** (`| … |` + séparateur `|---|`). Si IFFD portait une variante non-GFM, elle tomberait en **fallback préservant** (AC5 : texte verbatim, jamais de perte). *À confirmer sur un échantillon réel IFFD en ES-11.2 ; le contrat de préservation garantit l'absence de perte quoi qu'il arrive.*
2. **Point d'application de la migration** : one-shot à l'import (ES-11.2 migration flat→canonique) vs à la volée. *Recommandation : la migration est une **fonction pure** réutilisable ; le CÂBLAGE (quand l'appeler) appartient à l'adapter/binding IFFD (ES-11.2), hors périmètre ES-6.2.*

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

Vérif verte RÉELLE (RC hors pipe — R15 ; `flutter test` — R14) :
- `dart pub get` (workspace) → RC=0.
- `flutter test` `zcrud_markdown` (FULL) → RC=0 (**+277**, dont `z_table_ops_test` AC1/AC9, `z_table_embed_test` E6-4, `quill_signature_isolation_test` isolation).
- `flutter test` `zcrud_note` (FULL) → RC=0 (**+162**, dont `z_note_table_migration_test` AC2..AC7, `source_policy_test` retarget D3/AC8).
- `python3 scripts/dev/graph_proof.py` → RC=0 : ACYCLIQUE OK, CORE OUT=0 OK, 20 nœuds ; arête `zcrud_note → zcrud_markdown` DÉJÀ présente (ES-6.1) — **aucune nouvelle arête**.
- `dart run melos list | wc -l` → **20** (inchangé).
- `dart run melos exec --scope=zcrud_markdown --scope=zcrud_note -- dart analyze` → RC=0 (`No issues found!`).

Preuves R3 (injection → AC ROUGE RC=1 → restauration par édition ciblée, aucune garde laissée neutralisée) :
- **R3#1** (AC2) — séparateur traité comme donnée (`j = i+1`) ⇒ AC2 ROUGE. Restauré.
- **R3#2** (AC5, LOAD-BEARING) — garde de régularité `sepCount != header.length` neutralisée ⇒ AC5 ROUGE (embed jagged produit). Restauré.
- **R3#3** (AC4) — délégation `normalizeNoteContentOps` remplacée par repli `[]` sur `String` ⇒ AC4 ROUGE (texte détruit). Restauré.
- **R3#4** (AC7) — `const _rInjectDup = 'table'` (contrat dupliqué en dur) ⇒ scan `source_policy_test` › data ROUGE. Restauré.
- **R3#5** (AC8) — `import 'package:flutter/material.dart'` dans `data/` ⇒ garde data ROUGE ; dans `domain/` ⇒ garde domaine ROUGE ; import `zcrud_markdown` dans `data/` = VERT (couture neutre autorisée). Restauré.
- **R3#6** (AC1/AC9) — type émis `'tbl'` ≠ `kTableEmbedType` ⇒ AC1 (structure) **ET** AC9 (parité builder → placeholder) ROUGES. Restauré.

### Completion Notes List

- **COMBLEMENT `zcrud_markdown` (SM-S4)** : nouvelle couture NEUTRE pur-Dart `lib/src/data/z_table_ops.dart` — `kTableEmbedType` (SOURCE UNIQUE) + clés + `zTableEmbedOp({cells})` (JSON-safe, gel PROFOND, lignes paddées ⇒ jamais jagged). `z_table_embed.dart` et `z_rich_text_core.dart` re-câblés sur l'import (comportement E6-4 inchangé). Barrel `show zTableEmbedOp, kTableEmbedType` uniquement.
- **DÉVIATION ASSUMÉE vs chemin littéral de la story (FINDING-2 / orchestrateur)** : fichier nommé **`z_table_ops.dart`** (test `z_table_ops_test.dart`), PAS `z_table_embed_ops.dart` : ce dernier **contient la sous-chaîne interdite `z_table_embed`** que `quill_signature_isolation_test.dart` scanne dans le TEXTE du barrel — l'exporter aurait fait ROUGIR l'isolation. Confirmé en machine (l'isolation reste verte). Intention de la story respectée (« nom ≠ chaînes interdites »).
- **MIGRATEUR `zcrud_note` (couche `data/`)** : `lib/src/data/z_note_table_migration.dart` — `zMigrateStickyNote` (DÉLÈGUE `normalizeNoteContentOps`), `zMigrateNoteTables` (détection GFM STRUCTURELLE ligne-à-ligne, défensive AD-10, préservante au caractère près via offsets), `zUpgradeLegacyNoteContent` (composition). Contrat table **importé** (`zTableEmbedOp`/`kTableEmbedType`), jamais dupliqué.
- **RE-TARGET pureté (D3, miroir de D6 ES-6.1)** : `source_policy_test.dart` — pureté STRICTE re-scopée à `domain/` seul ; NOUVELLE garde `data/` (zcrud_markdown neutre OK, Flutter/Quill DIRECT interdits) ; scan no-codec/no-heuristique conservé sur tout `lib/` ; verrou DW-ES22-1 conservé.
- **Invariants** : AD-1 (graphe inchangé, 0 nouvelle arête, CORE OUT=0), AD-4/AD-7 (valeur neutre opaque JSON-safe, aucun type Quill en surface), AD-10 (défensif : malformé → texte verbatim, jamais de throw, jamais d'embed jagged), AD-28/SM-S4 (aucun codec, aucun contrat dupliqué), NFR-S10 (domaine pur-Dart). `zcrud_core` NON modifié ; E6-4 NON régressé (AC9).
- **D10 (documentaire) — DÉFÉRÉ au code-review** : la story autorise explicitement à consigner la clôture du volet « migration des tables » de FR-S25 + le rappel d'exclusion **DW-ES22-2** (mapping persistance legacy IFFD, dû à l'adapter `zcrud_firestore` ES-3.5/ES-11.2 — AD-27, jamais dans ce migrateur) dans le code-review plutôt que d'éditer `architecture.md` en dev. Aucune nouvelle dette `gate:web` (D6 — les deux packages sont déjà Flutter).

### File List

- `packages/zcrud_markdown/lib/src/data/z_table_ops.dart` — **NOUVEAU** (couture neutre D1).
- `packages/zcrud_markdown/lib/src/presentation/z_table_embed.dart` — **MODIFIÉ** (D2 : `kTableEmbedType`/clés importés).
- `packages/zcrud_markdown/lib/src/presentation/z_rich_text_core.dart` — **MODIFIÉ** (D3 : import couture neutre).
- `packages/zcrud_markdown/lib/zcrud_markdown.dart` — **MODIFIÉ** (D4 : export couture neutre).
- `packages/zcrud_markdown/test/z_table_ops_test.dart` — **NOUVEAU** (D7 : AC1 + AC9).
- `packages/zcrud_note/lib/src/data/z_note_table_migration.dart` — **NOUVEAU** (D5 : migrateur).
- `packages/zcrud_note/lib/zcrud_note.dart` — **MODIFIÉ** (D6 : export migration).
- `packages/zcrud_note/test/z_note_table_migration_test.dart` — **NOUVEAU** (D8 : AC2..AC7).
- `packages/zcrud_note/test/source_policy_test.dart` — **MODIFIÉ** (D9 : retarget pureté domain/data + AC8).

### Change Log

- ES-6.2 : comblement couture neutre d'op embed tableau dans `zcrud_markdown` (SM-S4) + migrateur legacy `zcrud_note` (tables GFM → structure, sticky-note → Delta, défensif AD-10, idempotent) + retarget de la garde de pureté (domain strict / data neutre). Aucune nouvelle arête (AD-1). `zcrud_core` intact ; E6-4 non régressé.
