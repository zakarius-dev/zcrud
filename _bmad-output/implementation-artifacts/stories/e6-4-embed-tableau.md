---
baseline_commit: 3dfcb4fe48f8fa7ffb113c120783a6124cb0dba2
---

# Story 6.4: Embed tableau

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrateur zcrud (lex_douane module « Étude », DODLP)**,
I want **insérer, éditer et rendre des tableaux comme embeds dans l'éditeur rich-text `ZMarkdownField`, via un rendu isolé**,
so that **mes contenus riches (articles, cartes) affichent des tableaux correctement rendus, sans jamais casser l'éditeur sur une structure de tableau corrompue, et sans tirer de dépendance lourde ni la faire fuir hors de `zcrud_markdown`**.

## Contexte & valeur (AD-7 / AD-1 / AD-10)

**E6-1** (done) a livré `ZMarkdownField` : éditeur Quill à controller **isolé**, scellé sur **sa seule tranche** du `ZFormController`, portant une **valeur neutre Delta JSON** (`List<Map<String, dynamic>>`). **E6-2** (done) a livré le **`ZCodec` pluggable** (Delta / Markdown), qui (dé)sérialise le **format persisté** à la couture de persistance — **hors** du chemin chaud de frappe. **E6-3** (review) a livré l'**embed LaTeX** : c'est le **PATRON à imiter EXACTEMENT** (embed Quill custom, `EmbedBuilder` défensif, dialogue d'insertion/édition, bouton toolbar, `embedBuilders` **stables** anti-régression SM-1, isolation au seul pubspec, op **opaque** captée génériquement par le placeholder d'E6-2).

**Point clé absorbé d'E6-2 / E6-3** : les embeds sont déjà traités comme des **ops Delta OPAQUES** qui traversent le round-trip. `ZDeltaCodec` les préserve **à l'identique** (fidélité totale) ; `ZMarkdownCodec` les remplace par un **placeholder textuel** `[embed:<type>]` (`DeltaNeutralOps.toDeltaForMarkdown` → `_embedPlaceholder` = **1re clé** de la `Map` `insert`, perte **bornée** — le texte environnant survit). **E6-2 traite donc déjà la (dé)sérialisation de l'embed tableau** (le placeholder `_embedPlaceholder` cite explicitement `z-table` en commentaire) — E6-4 n'y touche PAS.

**E6-4 ajoute exclusivement le RENDU et l'ÉDITION** de l'embed tableau : un **embed Quill custom** (type `table`, op `{insert: {table: <structure JSON-safe>}}`) rendu via un **widget Flutter `Table` natif** (AD-1 : **zéro dépendance ajoutée** — idéal), inséré/édité dans l'éditeur (bouton toolbar + dialogue de saisie lignes/colonnes/cellules), et affiché en édition comme en lecture. Le rendu est **défensif** (AD-10) : structure invalide / vide / absente / non-`Map` → **placeholder d'erreur inline**, **jamais** de throw ni de crash de l'éditeur. La **valeur de tranche reste Delta JSON neutre** (inchangée).

> **Frontière E6-4 (stricte, CLÔT E6)** : E6-4 = **embed tableau UNIQUEMENT**. C'est la **DERNIÈRE story d'E6** (Markdown & rich text). L'embed **LaTeX** = déjà **E6-3**. La **(dé)sérialisation** des embeds (opaque) = déjà **E6-2** (aucune modif de `ZCodec`/`DeltaNeutralOps`). Le **contenu riche de cellule** (rich-text imbriqué par cellule, fusion de cellules, redimensionnement) et **tout autre embed** relèvent de **v1.x** — non anticipés ici. **Aucune** dépendance table lourde (`flutter_tex`, `html_editor_enhanced`, lib de grille) n'est ajoutée (voir Dev Notes — décision de conception).

## Acceptance Criteria

1. **AC1 — Embed tableau Quill custom défini dans `zcrud_markdown` (op opaque JSON-safe).** Un embed Quill custom (`Embeddable`) de **type `table`** est défini sous `lib/src/` (jamais dans le barrel public en tant que type Quill). Sa représentation Delta est **exactement** `{"insert": {"table": <structure>}}` — **JSON-safe** et **opaque** (une `Map` sous `insert`), donc déjà couverte par le traitement embed d'E6-2. La **structure** est une `Map`/`List` JSON-safe décrivant lignes et cellules (recommandé : `{"rows": <int>, "columns": <int>, "cells": <List<List<String>>>}` ; cellules = **texte simple** pour le MVP). Aucune modification de la valeur de tranche : elle reste **Delta JSON neutre** (`List<Map<String, dynamic>>`), JSON-safe (`jsonDecode(jsonEncode(v)) == v`).

2. **AC2 — Rendu de l'embed via un widget `Table` Flutter natif (tableau affiché, édition + lecture).** Un `EmbedBuilder` Quill (`key == 'table'`) rend l'op `{insert:{table:...}}` en **tableau** via le widget **`Table` de Flutter** (aucune lib externe), branché sur `QuillEditorConfig.embedBuilders`. Le tableau s'affiche correctement **en édition** (éditeur actif) **et en lecture** (`readOnly == true` / champ en mode lecture). Test widget : un `ZMarkdownField` seedé avec une tranche contenant l'op table affiche un widget `Table` (avec le nombre de lignes/colonnes attendu et le texte des cellules), pas le texte brut `table`.

3. **AC3 — Insertion / édition du tableau via l'éditeur.** L'utilisateur insère un tableau via un **bouton de toolbar** (`QuillSimpleToolbarConfig.customButtons`, second bouton après « Formule » d'E6-3) qui ouvre un **dialogue** capturant le **nombre de lignes/colonnes** et la **saisie des cellules** ; la validation insère l'op embed au point d'insertion courant (`controller.replaceText(index, len, embed, selection)`). Éditer un embed existant est possible (caret sur/juste-après l'embed → dialogue **pré-rempli** avec la structure courante → **remplacement** de l'op, longueur 1). Test widget : insérer un tableau 2×2 via le flux produit une tranche contenant l'op `{insert:{table:{...cells:[["…","…"],["…","…"]]}}}` et un rendu `Table`.

4. **AC4 — Défensif (AD-10) : structure invalide / vide / absente / corrompue → placeholder d'erreur inline, jamais de throw.** L'`EmbedBuilder` ne throw **JAMAIS** : (a) structure **absente** / **non-`Map`** (type inattendu sous `insert.table`) → **placeholder d'erreur inline** ; (b) `cells` **absent** / non-`List` / lignes non-`List` / cellules non-`String` / **vide** / dimensions incohérentes → placeholder d'erreur inline, jamais de crash ; (c) valeurs de cellules **coercées défensivement** en `String` (jamais d'accès typé non gardé). Test widget sur matrice réelle (`table` absent, `cells` `null`/nombre, lignes irrégulières, `{}` vide) : `takeException()` null, éditeur toujours montable/utilisable.

5. **AC5 — Round-trip préservé (cohérence E6-2/E6-3, op opaque).** L'op embed table **traverse** le round-trip **inchangée** : `ZDeltaCodec.decode(encode(ops)) == ops` (identité, l'op `{insert:{table:...}}` incluse) ; `ZMarkdownCodec` la remplace par le **placeholder** `[embed:table]` (perte bornée, texte environnant préservé) — le **type `table`** est bien celui capté par `DeltaNeutralOps._embedPlaceholder` (1re clé de la `Map` `insert`). **Aucune** modification du chemin hot de codec ni de `DeltaNeutralOps`. Test : round-trip d'un corpus `texte + embed table + texte` → `ZDeltaCodec` identité (structure imbriquée préservée bit-à-bit via JSON) ; `ZMarkdownCodec` → Markdown non vide contenant les 2 segments de texte + un marqueur `[embed:table]`, sans ressusciter l'embed.

6. **AC6 — Isolation & zéro dépendance ajoutée (gate AD-1).** Le rendu utilise le widget **`Table` de Flutter** ⇒ **AUCUNE** nouvelle dépendance au `pubspec.yaml` de `zcrud_markdown` (idéal AD-1). **Aucune** dépendance table lourde (`flutter_tex`, `html_editor_enhanced`, lib de grille tierce). Le gate de graphe existant reste **VERT** (closure `zcrud_core` inchangée, out-degree zcrud_* du cœur = 0, acyclicité `zcrud_markdown → zcrud_core`) et `dart pub get --dry-run` (gate compat E1-4) **VERT** (résolution inchangée). Assertion explicite : le `pubspec.yaml` de `zcrud_markdown` n'acquiert **aucune** arête nouvelle.

7. **AC7 — Aucun type de rendu ne fuit (signature + barrel + runtime).** Le barrel n'exporte **aucun** symbole `flutter_quill` ni le nouvel embed table (`ZTableEmbed`/`ZTableEmbedBuilder` NON publics). La surface **publique** de `ZMarkdownField` (et de tout symbole public éventuel) ne cite **aucun** type Quill (scan statique, miroir de `quill_signature_isolation_test.dart`). Le widget `Table` étant du framework Flutter (`package:flutter`), il n'introduit **aucune** fuite de package tiers. Runtime : la valeur de tranche après insertion d'un embed table reste `List<Map<String, dynamic>>` **JSON-safe** (`jsonDecode(jsonEncode(v)) == v`), l'op embed = `Map` opaque — jamais un type Quill.

8. **AC8 — SM-1 / AD-2 non régressés par l'ajout de l'embed table.** Réutilise le harnais 100-frappes d'E6-1/E6-3 : taper **100 caractères** un par un dans un champ **doté** des `EmbedBuilder` LaTeX **+ table** ne reconstruit **que** le champ courant (compteur build tranche == frappes ; voisin figé), le `QuillController` **jamais recréé** (`init == 1`, `identical`), **zéro perte de focus/sélection** (caret au point d'insertion). L'`EmbedBuilder` table est ajouté à la **MÊME** liste `const` **STABLE** (canonicalisée) que LaTeX (référence figée, pas d'allocation par (re)build de tranche — assertion `identical`), et le bouton table est ajouté au **MÊME** `_toolbarConfig` **STABLE** (hissé `late final`, construit UNE fois en `initState`). L'`EmbedBuilder` n'entre **jamais** dans le flux `document.changes` (chemin chaud `_onQuillChanged` INCHANGÉ, MED-1 préservé).

9. **AC9 — Thème / RTL / a11y (AD-13).** Bouton toolbar d'insertion table et boutons du dialogue : cibles **≥ 48 dp**, `Semantics` explicites, insets **directionnels** (`EdgeInsetsDirectional`), `TextAlign.start`/`AlignmentDirectional`. Le rendu du `Table` : bordures/couleurs issues du **thème injecté** (`ZcrudTheme.of(context)` / `Theme.of(context)`) — **zéro** couleur codée en dur ; padding de cellule directionnel ; lisible sous `TextDirection.rtl` (ordre logique des colonnes). Le placeholder d'erreur porte une `Semantics`/label lisible (ex. « tableau invalide ») et ses couleurs viennent du thème. Rendu vérifié sans exception sous `TextDirection.rtl` et sous thème clair/sombre.

10. **AC10 — Frontière E6-4 respectée (tableau uniquement ; clôt E6).** **Aucun** embed autre que LaTeX (E6-3) et table (E6-4) n'est introduit ; **aucune** dépendance table/rich lourde ajoutée. **Aucune** modification de `zcrud_core`. **Aucune** modification du contrat `ZCodec` (E6-2) ni de `DeltaNeutralOps`. Le **contenu riche de cellule** (rich-text par cellule, fusion, redimensionnement) est explicitement **hors périmètre** (v1.x — cellules = texte simple pour le MVP).

## Tasks / Subtasks

- [x] **Task 1 — Embed table custom (op opaque JSON-safe) (AC1, AC6).**
  - [x] Confirmer **zéro** ajout au `packages/zcrud_markdown/pubspec.yaml` (widget `Table` natif) ; `dart pub get --dry-run` (racine) VERT (gate E1-4 inchangé) ; gate de graphe inchangé.
  - [x] `lib/src/presentation/z_table_embed.dart` : embed Quill custom `ZTableEmbed extends Embeddable` de type `table` (op `{insert:{table:<structure JSON-safe>}}`, `const`). Structure recommandée : `{"rows": int, "columns": int, "cells": List<List<String>>}`. **Rien dans le barrel**. Constante `kTableEmbedType = 'table'` + label a11y `@visibleForTesting kTableInvalidLabel = 'tableau invalide'`.
- [x] **Task 2 — `EmbedBuilder` de rendu défensif via `Table` natif (AC2, AC4, AC9).**
  - [x] `ZTableEmbedBuilder extends EmbedBuilder` (`key == 'table'`, `const`) : `build(...)` lit `embedContext.node.value.data`, **parse défensivement** la structure, et rend un widget `Table` Flutter (lignes/cellules), bordures/couleurs du thème injecté, padding directionnel.
  - [x] **Défensif (AD-10)** : structure absente / non-`Map` / `cells` non-`List` / lignes non-`List` / cellules coercées en `String` / vide / dimensions incohérentes → placeholder d'erreur inline (`Icon(error_outline)`) ; **jamais** de throw. Placeholder = widget thémé (`ZcrudTheme.errorColor` → repli `Theme.error`) + `Semantics(label: 'tableau invalide')`, insets directionnels. Décider `expanded` (block vs inline — recommandé **block** `expanded == true` : un tableau occupe sa propre ligne) et documenter.
- [x] **Task 3 — Câblage dans `ZMarkdownField` (AC2, AC8).**
  - [x] Ajouter `ZTableEmbedBuilder()` à la **MÊME** liste `const` STABLE que LaTeX : renommer/étendre `_kLatexEmbedBuilders` → `_kEmbedBuilders = const [ZLatexEmbedBuilder(), ZTableEmbedBuilder()]` (canonicalisée, instance UNIQUE, assertion `identical`). Config éditeur reste `const`. Chemin chaud `_onQuillChanged` INCHANGÉ.
- [x] **Task 4 — Insertion / édition via toolbar + dialogue (AC3, AC9).**
  - [x] Ajouter au `_toolbarConfig` STABLE (hissé `late final` en `initState`) un **second** `QuillToolbarCustomButtonOptions` : bouton « Tableau » (`Icons.table_chart`/`Icons.grid_on`, tooltip) → `_promptAndInsertTable`.
  - [x] `showZTableDialog(context, {initial})` : dialogue de saisie lignes/colonnes + grille de `TextField` de cellules (cibles ≥ 48 dp, `Semantics`, directionnel) → structure JSON-safe validée ; annulation → `null`.
  - [x] `_promptAndInsertTable` : insertion via `_quill.replaceText(index, len, ZTableEmbed(structure), selection)` ; édition d'un embed existant : `_tableEmbedAtSelection()` détecte l'embed sous/juste-après le caret → dialogue pré-rempli → remplacement de l'op (longueur 1). Mirror EXACT de `_promptAndInsertLatex`/`_latexEmbedAtSelection`.
- [x] **Task 5 — Tests rendu / insertion / défensif (AC2, AC3, AC4).**
  - [x] `test/z_table_embed_test.dart` : rendu (op → widget `Table` avec dims + textes) en édition ET `readOnly` ; insertion via flux (bouton `onPressed` RÉEL → dialogue → tranche contient l'op table) ; édition d'embed existant ; annulation ; matrice défensive (`table` absent, `cells` null/nombre, lignes irrégulières, `{}` vide) → `takeException()` null, éditeur montable + placeholder rendu.
- [x] **Task 6 — Round-trip / cohérence E6-2 (AC5).**
  - [x] `test/fixtures/rich_corpus.dart` étendu (`tableTypeEmbedOps`, `mixedTextAndTableEmbedOps` de type CANONIQUE `table`, structure imbriquée) ; `ZDeltaCodec` identité (corpus, structure préservée) + `z_markdown_codec_test.dart` : `ZMarkdownCodec` → `[embed:table]`, texte préservé, embed non ressuscité. Codec/`DeltaNeutralOps` INCHANGÉS.
- [x] **Task 7 — Gates isolation & signature (AC6, AC7).**
  - [x] Vérifier que le gate de graphe existant reste VERT **sans** modification (zéro dép ajoutée) ; assertion : `pubspec.yaml` `zcrud_markdown` inchangé côté dépendances.
  - [x] `test/quill_signature_isolation_test.dart` étendu : barrel + surface publique sans type Quill ni embed table exporté ; runtime tranche neutre JSON-safe après insertion table (dans `z_table_embed_test.dart`).
- [x] **Task 8 — SM-1 + a11y/RTL + vérif verte (AC8, AC9, AC10).**
  - [x] Harnais SM-1 (100 frappes) **avec** les `EmbedBuilder` LaTeX **+ table** actifs : build tranche == frappes, `init==1`, `identical` (controller + `_kEmbedBuilders`), focus/caret conservés.
  - [x] Test a11y/RTL : bouton toolbar « Tableau » présent + toolbar ≥ 48 dp, dialogue OK/Annuler ≥ 48 dp, `Semantics`, `Table` rendu sous `rtl` + thème clair/sombre, couleurs du thème injecté, sans exception ; placeholder thémé sous `rtl`.
  - [x] Vérif verte **ciblée** `zcrud_markdown` : `flutter analyze` RC=0 (0 issue) → `flutter test` RC=0 → `dart pub get --dry-run` RC=0 → gate de graphe RC=0. **Aucune** modif hors `packages/zcrud_markdown/`. **Zéro** modif `zcrud_core`.

## Dev Notes

### Décision de conception (résout l'ambiguïté centrale)

> **Question ouverte** (epic E6-4 : « `flutter_tex`/`html_editor_enhanced` optionnels derrière drapeau ») : rendre le tableau via une **lib externe** (flag) OU via un **widget `Table` Flutter natif** ?
>
> **Résolution retenue (à implémenter telle quelle)** : **widget `Table` Flutter natif** — **AUCUNE** dépendance ajoutée (idéal AD-1). Rationale : (a) un tableau à cellules de texte simple (périmètre MVP) est rendu parfaitement par le `Table` du framework ; (b) `flutter_tex`/`html_editor_enhanced` tirent un **WebView / moteur lourd** (contamination du graphe, coût de build, surface RTL/a11y incontrôlée) — inutiles ici et contraires à l'esprit AD-1 (« pas de lib lourde ») ; (c) le mot « optionnels derrière drapeau » de l'epic **autorise** de ne PAS les inclure — on choisit l'option **zéro-dépendance**, la plus propre pour l'isolation. Toute lib de tableau reste **déférée v1.x** (contenu riche de cellule).
>
> **Structure de l'op** : `{"insert": {"table": {"rows": <int>, "columns": <int>, "cells": <List<List<String>>>}}}`. `cells` = matrice de **texte simple** (MVP) ; JSON-safe et **opaque** (traverse E6-2 à l'identique). Le `rows`/`columns` peut être **dérivé** de `cells` (redondance tolérée pour lisibilité) — le rendu DOIT rester défensif si dims et matrice divergent (prendre la matrice comme source de vérité).
>
> **Inline vs block** : recommandé **block** (`expanded == true` : le tableau occupe sa propre ligne, cohérent avec la nature d'un tableau). Documenter le choix effectif dans les Completion Notes (comme E6-3 l'a fait pour inline).

### État réel du point d'intégration (à lire AVANT de coder)

`packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` (E6-1/E6-2/E6-3, **done/review**) :
- **Ce qu'il fait** : `initState` → seed via `codec.decode` → `decodeDefensiveDocument` → `QuillController` unique. Frappe → `document.changes` → `_onQuillChanged` → `encodeNeutral` → `setValue` (sens unique, dédup `_lastValueJson`, garde `_applyingExternal`). Sync guardée `_syncFromExternal` **hors focus** uniquement. `_buildEditor` construit un `QuillEditor` avec `config: const QuillEditorConfig(scrollable:false, padding: EdgeInsetsDirectional.zero, embedBuilders: _kLatexEmbedBuilders)` et un `QuillSimpleToolbar` (`config: _toolbarConfig` — `late final`, construit en `initState`, avec **1** customButton « Formule » branché sur `_promptAndInsertLatex`).
- **Ce que E6-4 change** : (a) **étendre** `_kLatexEmbedBuilders` → `_kEmbedBuilders = const [ZLatexEmbedBuilder(), ZTableEmbedBuilder()]` (MÊME const stable, +table) et mettre à jour la référence dans `QuillEditorConfig.embedBuilders` ; (b) **ajouter** un **second** `QuillToolbarCustomButtonOptions` (« Tableau ») à `_toolbarConfig` dans `initState`, branché sur `_promptAndInsertTable` ; (c) ajouter `_promptAndInsertTable`/`_tableEmbedAtSelection`/`_TableEmbedHit`. **Rien d'autre** dans le chemin chaud.
- **DOIT être préservé (non-négociable)** : `QuillController`/`FocusNode`/`ScrollController` créés une fois / disposés ; abonnement `document.changes` annulé au dispose + ré-abonné après swap de document ; sens unique ; dédup ; sync guardée hors focus ; RTL/thème/a11y (AD-13) ; embed **LaTeX** d'E6-3 (ne rien casser). ⚠️ La liste `embedBuilders` DOIT rester `const` STABLE (renommée `_kEmbedBuilders`) — sinon régression SM-1. **Ne JAMAIS** faire entrer un `EmbedBuilder` ni le codec dans `_onQuillChanged` (chemin chaud).
- **Réutiliser, ne pas réimplémenter** : `DeltaNeutralOps` (E6-2) pour toute manip d'ops neutres ; `z_latex_embed.dart` comme **gabarit exact** (embed + builder défensif + dialogue + hit-testing du caret) ; les fixtures/harnais SM-1/défensif d'E6-1/E6-3.

### API Quill 11.5 — embeds (rappel technique, cf. E6-3)

- **Op Delta d'un embed** : `{"insert": {<type>: <data>}}` (data JSON-safe). Type `table`, data = **`Map`/`List`** JSON-safe (structure du tableau).
- **`Embeddable(type, data)`** : `ZTableEmbed extends Embeddable('table', structure)` → `toJson()` = `{"table": <structure>}` → op `{"insert": {"table": <structure>}}`. La `data` peut être une `Map`/`List` (pas seulement une `String`) ; veiller à ce qu'elle reste **JSON-safe** (primitifs uniquement en feuilles) pour le round-trip `encodeNeutral`/`Document.fromJson`.
- **`EmbedBuilder`** : `String get key` (== `'table'`) + `bool get expanded` + `Widget build(BuildContext, EmbedContext)` (récupère `embedContext.node.value.data`). Enregistré via `QuillEditorConfig(embedBuilders: [...])`.
- **Insertion** : `controller.replaceText(index, length, ZTableEmbed(structure), TextSelection.collapsed(offset: index + 1))`.
- **Toolbar custom** : `QuillSimpleToolbarConfig(customButtons: [ <bouton Formule E6-3>, <bouton Tableau E6-4> ])`.

### Rendu défensif du `Table` natif (AD-10)

- Parser la structure AVANT tout accès typé : si `data` n'est pas une `Map`, ou `cells` n'est pas une `List` de `List`, retourner directement le placeholder (ne jamais appeler `Table(...)` sur une entrée invalide).
- **Coercition** des feuilles en `String` (`'${cell}'` / `cell?.toString() ?? ''`) — une cellule non-`String` ne throw jamais.
- Lignes de longueurs **irrégulières** : normaliser (padder/tronquer à la largeur max) OU placeholder — choisir la voie qui ne throw jamais (`Table` de Flutter **exige** des lignes de même longueur → normalisation OBLIGATOire avant construction, sinon assertion Flutter).
- `cells` **vide** / dims nulles → placeholder d'erreur inline.
- Placeholder = widget thémé (`Theme.of`/`ZcrudTheme`) + `Semantics(label: 'tableau invalide')`, insets directionnels — jamais une couleur en dur (AD-13/FR-26).

### Learnings absorbés (E6-1 / E6-2 / E6-3)

- **SM-1 non régressé** : `embedBuilders` = **une seule** liste `const` canonicalisée (MÊME instance à chaque build, assertion `identical`) ; ajouter le builder table à cette MÊME liste, ne PAS créer une seconde liste ni une liste par build. `_toolbarConfig` reste `late final` (bouton table ajouté à la config construite UNE fois).
- **Op embed OPAQUE** : le codec E6-2 est INCHANGÉ ; le placeholder générique `_embedPlaceholder` produit `[embed:table]` **sans** modif (le commentaire d'E6-2 cite déjà `z-table` — mais le type CANONIQUE retenu ici est **`table`**, aligné sur l'epic ; l'op reste captée génériquement quelle que soit la 1re clé).
- **Défensif = matrice réelle** (pas de proxy) : reproduire une matrice défensive réelle (structure corrompue variée) → placeholder / doc utilisable / `takeException()` null.
- **Isolation** : ici **zéro dépendance** ajoutée (Table natif) → le gate de graphe reste vert **sans** nouveau contrôle ; assertion que le `pubspec.yaml` ne gagne aucune arête. Anti-fuite de type : scan statique (barrel + région publique) **et** runtime (tranche `List<Map>` JSON-safe après insertion).
- **MED-1 (efficacité)** : ne rien introduire dans le flux `document.changes` ; `embedBuilders` stables (pas d'alloc par build).
- **HIGH-1 d'E6-2 (perte bornée)** : l'op embed table est déjà gérée en placeholder par `ZMarkdownCodec` — **ne pas** la faire ressusciter ni casser cette borne.
- **Instance-par-montage / anti-fuite dispose** (E6-1/E6-3) : l'`EmbedBuilder` table est sans état ⇒ rien de nouveau à disposer. Le dialogue dispose ses `TextEditingController` (une grille de cellules → **N contrôleurs** créés/disposés dans le `State` du dialogue).

### Invariants d'architecture applicables (AD)

- **AD-7** — Delta interne ; embeds **tables** rendus ; (dé)sérialisation persistée via `ZCodec` (déjà E6-2, non modifié) ; round-trip testé (tables).
- **AD-1** — rendu via widget natif → **zéro** dépendance ajoutée ; aucun type ne fuit ; closure `zcrud_core` inchangée ; acyclicité ; out-degree zcrud_* du cœur = 0.
- **AD-10** — rendu **défensif** : structure invalide/vide/absente/corrompue → placeholder d'erreur inline, jamais de throw ; évolution additive.
- **AD-2** — chemin chaud de frappe intact (embed builder hors flux) ; controller stable ; `embedBuilders`/`_toolbarConfig` stables ; sens unique ; SM-1 non régressé.
- **AD-13** — RTL/thème/a11y : bouton toolbar/dialogue ≥ 48 dp, `Semantics`, directionnel, couleurs du thème (bordures de table incluses).

### Impact `zcrud_core` — **NON**

**E6-4 vit ENTIÈREMENT dans `zcrud_markdown`** : l'embed custom, l'`EmbedBuilder` (`Table` natif Flutter), le bouton toolbar et le dialogue sont tous **spécifiques au rich-text** et consomment `flutter_quill` (déjà la SEULE arête Quill du graphe, cantonnée à ce package) + le widget `Table` du framework (`package:flutter`, aucune fuite tierce). La valeur de tranche reste **Delta JSON neutre** (l'op `{insert:{table:...}}` est JSON-safe et déjà round-trippée opaquement par E6-2) → **aucun** nouveau concept dans `zcrud_core`, **aucun** port neutre requis pour le MVP. *Note orchestrateur* : E6-4 = **dernière** story d'E6 ; après elle → `bmad-retrospective` epic 6 puis commit d'epic.

### Libs de rendu — choix & version

- **Widget `Table` de Flutter** (`package:flutter/widgets.dart`) — rendu tableau natif, **zéro dépendance ajoutée** (AD-1 idéal). C'est la voie retenue (voir Décision de conception).
- **PAS** `flutter_tex` (WebView/MathJax lourd), **PAS** `html_editor_enhanced` (éditeur HTML WebView), **PAS** de lib de grille tierce — déférés v1.x (contenu riche de cellule). L'epic les autorise « derrière drapeau » ; on choisit de **ne pas** les inclure.

> ⚠️ **Ne PAS** committer les `pubspec.lock` de package ni les `*.g.dart` (gitignorés). E6-4 n'ajoute **aucune** dépendance : le `pubspec.yaml` de `zcrud_markdown` ne change PAS côté `dependencies`.

### Stratégie de tests

- **Rendu (AC2)** : op `{insert:{table:{rows:2,columns:2,cells:[["a","b"],["c","d"]]}}}` → widget `Table` trouvé (dims + textes) en édition + `readOnly`.
- **Insertion (AC3)** : flux toolbar+dialogue → tranche contient l'op ; édition d'un embed existant (dialogue pré-rempli → remplacement).
- **Défensif (AC4, AD-10)** : matrice réelle (`table` absent, `cells` `null`/nombre, lignes irrégulières, `{}`) → placeholder, `takeException()` null, éditeur montable.
- **Round-trip (AC5)** : `ZDeltaCodec` identité incl. op table (structure imbriquée préservée) ; `ZMarkdownCodec` → `[embed:table]`, texte préservé.
- **Isolation graphe (AC6)** : gate existant VERT **sans** modif ; `pubspec.yaml` dépendances inchangées.
- **Signature (AC7)** : scan statique barrel + surface publique (aucun type Quill ni embed table exporté) ; runtime tranche neutre JSON-safe après insertion.
- **SM-1/AD-2 (AC8)** : harnais 100-frappes d'E6-1/E6-3 avec les 2 `EmbedBuilder` actifs → build==frappes, `init==1`, `identical` (controller + `_kEmbedBuilders`), focus/caret conservés.
- **a11y/RTL (AC9)** : bouton « Tableau » ≥ 48 dp, `Semantics`, `Table` rendu sous rtl + clair/sombre, placeholder thémé.

### Project Structure Notes

- **Fichiers NEW** (tous sous `packages/zcrud_markdown/`) : `lib/src/presentation/z_table_embed.dart` (`ZTableEmbed` + `ZTableEmbedBuilder` défensif `Table` natif + dialogue `showZTableDialog`/`_ZTableDialog`, scinder si volumineux) ; tests `test/z_table_embed_test.dart`.
- **Fichiers UPDATE** (tous sous `packages/zcrud_markdown/`) : `lib/src/presentation/z_markdown_field.dart` (renommer `_kLatexEmbedBuilders` → `_kEmbedBuilders` + ajout `ZTableEmbedBuilder()`, 2ᵉ customButton, `_promptAndInsertTable`/`_tableEmbedAtSelection`/`_TableEmbedHit` ; **chemin chaud inchangé**) ; `test/quill_signature_isolation_test.dart` (extension AC7 : embed table non exporté) ; `test/fixtures/rich_corpus.dart` (fixtures `texte + embed table + texte`) ; `test/z_markdown_codec_test.dart` (assertion `[embed:table]`). **PAS** de modif `pubspec.yaml` (dépendances). **Aucun** fichier hors `packages/zcrud_markdown/`. **Zéro** modif `zcrud_core`.
- **Naming** (conventions zcrud) : types `Z*` (`ZTableEmbed`, `ZTableEmbedBuilder`) ; fichiers snake_case ; API publique = barrel, impl sous `lib/src/{domain,data,presentation}`. **Aucun** symbole Quill re-exporté.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E6] — Story E6-4 (insertion/édition/rendu de tableaux ; `flutter_tex`/`html_editor_enhanced` optionnels derrière drapeau ; embed table corrompu → repli sûr, AD-10) ; **dernière story d'E6**.
- [Source: architecture.md#AD-7] — Delta interne (Quill) + embeds ; round-trip testé (**tables**) ; controller isolé (AD-2).
- [Source: architecture.md#AD-1] — rendu au seul pubspec `zcrud_markdown` ; ne fuit jamais dans `zcrud_core` ; satellite → core uniquement ; acyclicité ; pas de lib lourde dans le graphe.
- [Source: architecture.md#AD-10] — désérialisation/rendu défensif ; embed corrompu → parent jamais cassé ; additif.
- [Source: architecture.md#AD-2, #AD-13] — chemin chaud granulaire, controller stable ; RTL/a11y (≥48 dp, `Semantics`, directionnel), thème injecté.
- [Source: packages/zcrud_markdown/lib/src/presentation/z_latex_embed.dart] — **PATRON EXACT à imiter** (E6-3) : embed custom `Embeddable`, `EmbedBuilder` défensif, dialogue, label a11y, placeholder thémé.
- [Source: packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart] — point d'intégration (`_kLatexEmbedBuilders` const stable, `_toolbarConfig` late final, `_promptAndInsertLatex`/`_latexEmbedAtSelection`/`_LatexEmbedHit`, chemin chaud `_onQuillChanged`).
- [Source: packages/zcrud_markdown/lib/src/data/delta_neutral_ops.dart] — traitement embed OPAQUE d'E6-2 (`toDeltaForMarkdown`/`_embedPlaceholder` → `[embed:<type>]`, perte bornée ; cite déjà `z-table`) ; le type `table` y est capté génériquement.
- [Source: _bmad-output/implementation-artifacts/stories/e6-3-embed-latex.md] — story sœur (embed LaTeX) : structure, ACs, gates isolation/signature, SM-1, décision inline/block, dialogue.
- [Source: packages/zcrud_markdown/test/z_latex_embed_test.dart] — harnais de test à cloner (rendu/insertion/édition/défensif/SM-1/a11y-RTL, `QuillController` réel, `onInit`/`onBuild`).
- [Source: packages/zcrud_markdown/test/quill_signature_isolation_test.dart, flutter_quill_isolation_graph_test.dart] — patrons de gate signature/isolation à réutiliser.
- [Source: CLAUDE.md] — `zcrud_markdown` = Quill + `ZCodec` + embeds LaTeX/**tables** ; Key Don'ts (pas de lib lourde dans le cœur, pas de fuite de type, barrel, directionnel, `ListView.builder`, `const` widgets).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story)

### Debug Log References

- `flutter analyze` (zcrud_markdown) → RC=0, « No issues found! ».
- `flutter test` (zcrud_markdown) → RC=0, **155 tests passés** (dont les nouveaux
  `z_table_embed_test.dart`, les fixtures/codec étendus, et E6-1/E6-2/E6-3 non
  régressés).
- `dart pub get --dry-run` (racine workspace) → RC=0 (résolution inchangée).
- `python3 scripts/dev/graph_proof.py` → RC=0 : ACYCLIQUE, **CORE OUT=0**,
  14 nœuds / 17 arêtes, `zcrud_markdown → zcrud_core` (seule arête sortante,
  inchangée).

### Completion Notes List

- **Choix INLINE vs BLOCK : BLOCK (`expanded == true`)** — conforme à la
  recommandation de conception E6-4. Un tableau occupe sa propre ligne. Le rendu
  emploie `Table(defaultColumnWidth: IntrinsicColumnWidth())` : le tableau se
  dimensionne à son contenu et reste donc ROBUSTE même s'il se retrouvait sur une
  ligne mixte (Quill le rend alors inline via `WidgetSpan`) — jamais d'assertion
  de largeur non bornée. Décision documentée dans `z_table_embed.dart`.
- **Défensif jagged (AD-10) : lignes irrégulières → placeholder.** La matrice
  `cells` est la SOURCE DE VÉRITÉ (les champs `rows`/`columns` sont ignorés au
  rendu) ; toute ligne non-`List`, longueur irrégulière, `cells` vide/non-`List`,
  ou `data` non-`Map` → placeholder d'erreur inline thémé (`Semantics(label:
  'tableau invalide')`), jamais de throw. Les cellules non-`String` sont coercées
  (`cell?.toString() ?? ''`). Pour l'ÉDITION, le dialogue NORMALISE (padde) une
  matrice jagged afin de charger un contenu utilisable.
- **SM-1 NON régressé** : `ZTableEmbedBuilder()` ajouté à la MÊME liste `const`
  canonicalisée que LaTeX (`_kLatexEmbedBuilders` → `_kEmbedBuilders =
  const [ZLatexEmbedBuilder(), ZTableEmbedBuilder()]`) ; assertion `identical`
  vérifiée après 100 frappes (controller `init==1`, voisin figé, focus/caret
  conservés). Bouton « Tableau » ajouté au MÊME `_toolbarConfig` `late final`
  (2ᵉ `customButton`). Chemin chaud `_onQuillChanged` INCHANGÉ.
- **Op OPAQUE / codec inchangé** : op `{insert:{table:<struct>}}` JSON-safe ;
  `ZDeltaCodec` = identité (round-trip corpus) ; `ZMarkdownCodec` → placeholder
  `[embed:table]` capté GÉNÉRIQUEMENT par `_embedPlaceholder` (1re clé) — AUCUNE
  modif de `ZCodec`/`DeltaNeutralOps`.
- **Isolation (AD-1)** : ZÉRO dépendance ajoutée (widget `Table` natif du
  framework). `pubspec.yaml` de `zcrud_markdown` inchangé côté `dependencies` ;
  gate de graphe/signature verts sans modification ; aucun symbole public
  (`ZTableEmbed`/`ZTableEmbedBuilder` non exportés) ; tranche neutre `List<Map>`
  JSON-safe après insertion.
- **IMPACT `zcrud_core` = NON confirmé** : rien hors `packages/zcrud_markdown/`.
- **Note test E6-3** : la toolbar portant désormais 2 boutons custom, le helper
  `_pressLatexButton` de `z_latex_embed_test.dart` a été désambiguïsé par
  `tooltip` (mise à jour de test minimale, aucune régression E6-3).
- **10/10 ACs satisfaits.** Frontière respectée : embed tableau UNIQUEMENT
  (contenu riche de cellule / fusion / redimensionnement = v1.x). **Clôt E6.**

### File List

**NEW (packages/zcrud_markdown/) :**
- `lib/src/presentation/z_table_embed.dart` (`ZTableEmbed` + `ZTableEmbedBuilder`
  défensif `Table` natif + `showZTableDialog`/`_ZTableDialog`)
- `test/z_table_embed_test.dart`

**UPDATE (packages/zcrud_markdown/) :**
- `lib/src/presentation/z_markdown_field.dart` (`_kLatexEmbedBuilders` →
  `_kEmbedBuilders` + `ZTableEmbedBuilder()` ; 2ᵉ customButton « Tableau » ;
  `_promptAndInsertTable`/`_tableEmbedAtSelection`/`_TableEmbedHit` ; chemin chaud
  inchangé)
- `test/fixtures/rich_corpus.dart` (`tableTypeEmbedOps`,
  `mixedTextAndTableEmbedOps` + ajout au `deltaIdentityCorpus`)
- `test/z_markdown_codec_test.dart` (assertion `[embed:table]`)
- `test/quill_signature_isolation_test.dart` (embed table non exporté + pubspec
  sans dépendance table lourde)
- `test/z_latex_embed_test.dart` (helper `_pressLatexButton` désambiguïsé par
  tooltip — 2 boutons custom)

**PAS de modif `pubspec.yaml` (dépendances) — zéro dépendance ajoutée.**
