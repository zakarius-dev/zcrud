---
baseline_commit: fe203b90bb95a659063452af4cf584f66e7bab0f
---

# Story 6.3: Embed LaTeX

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrateur zcrud (lex_douane module « Étude », DODLP)**,
I want **insérer, éditer et rendre des formules LaTeX comme embeds dans l'éditeur rich-text `ZMarkdownField`, via une lib de rendu isolée**,
so that **mes contenus riches (articles, cartes) affichent des formules mathématiques correctement rendues, sans jamais casser l'éditeur sur une formule malformée, et sans que la lib de rendu ne fuite hors de `zcrud_markdown`**.

## Contexte & valeur (AD-7 / AD-1 / AD-10)

**E6-1** (done) a livré `ZMarkdownField` : éditeur Quill à controller **isolé**, scellé sur **sa seule tranche** du `ZFormController`, portant une **valeur neutre Delta JSON** (`List<Map<String, dynamic>>`). **E6-2** (done) a livré le **`ZCodec` pluggable** (Delta / Markdown), qui (dé)sérialise le **format persisté** à la couture de persistance — **hors** du chemin chaud de frappe.

**Point clé absorbé d'E6-2** : les embeds y sont déjà traités comme des **ops Delta OPAQUES** qui traversent le round-trip. `ZDeltaCodec` les préserve **à l'identique** (fidélité totale) ; `ZMarkdownCodec` les remplace par un **placeholder textuel** `[embed:<type>]` (`DeltaNeutralOps.toDeltaForMarkdown` → `_embedPlaceholder`, perte **bornée** — le texte environnant survit). **E6-2 traite donc déjà la (dé)sérialisation de l'embed LaTeX** — E6-3 n'y touche PAS.

**E6-3 ajoute exclusivement le RENDU et l'ÉDITION** de l'embed LaTeX : un **embed Quill custom** (type `latex`, op `{insert: {latex: "..."}}`) rendu via une lib LaTeX **isolée** (`flutter_math_fork`, AD-1), inséré/édité dans l'éditeur (bouton toolbar + dialogue de saisie de formule), et affiché en édition comme en lecture. Le rendu est **défensif** (AD-10) : formule invalide / vide / absente → **placeholder d'erreur inline**, **jamais** de throw ni de crash de l'éditeur. La lib de rendu vit au **seul** pubspec de `zcrud_markdown` (AD-1) ; **aucun** de ses types ne fuit en signature publique ; la **valeur de tranche reste Delta JSON neutre** (inchangée).

> **Frontière E6-3 (stricte)** : E6-3 = **embed LaTeX UNIQUEMENT**. L'embed **tableau** = **E6-4** (aucune anticipation ; aucune dépendance table `flutter_tex`/`html_editor_enhanced` ajoutée). La **(dé)sérialisation** des embeds (opaque) = déjà **E6-2** (aucune modif de `ZCodec`/`DeltaNeutralOps` requise, hors extension éventuelle du placeholder — voir Dev Notes).

## Acceptance Criteria

1. **AC1 — Embed LaTeX Quill custom défini dans `zcrud_markdown` (op opaque JSON-safe).** Un embed Quill custom (`Embeddable`/`BlockEmbed`) de **type `latex`** est défini sous `lib/src/` (jamais dans le barrel public en tant que type Quill). Sa représentation Delta est **exactement** `{"insert": {"latex": "<chaîne LaTeX>"}}` — **JSON-safe** et **opaque** (une `Map` sous `insert`), donc déjà couverte par le traitement embed d'E6-2. La donnée portée est une **`String`** (le source LaTeX). Aucune modification de la valeur de tranche : elle reste **Delta JSON neutre** (`List<Map<String, dynamic>>`).

2. **AC2 — Rendu de l'embed via `flutter_math_fork` (formule affichée, édition + lecture).** Un `EmbedBuilder` Quill (`key == 'latex'`) rend l'op `{insert:{latex:...}}` en **formule mathématique** via `flutter_math_fork` (`Math.tex(...)`), branché sur `QuillEditorConfig.embedBuilders`. La formule s'affiche correctement **en édition** (éditeur actif) **et en lecture** (`QuillController.readOnly == true` / champ en mode lecture). Test widget : un `ZMarkdownField` seedé avec une tranche contenant l'op LaTeX affiche un widget de rendu de formule (`Math`/`SelectableMath`), pas le texte brut `latex`.

3. **AC3 — Insertion / édition de la formule via l'éditeur.** L'utilisateur insère une formule via un **bouton de toolbar** (`QuillSimpleToolbarConfig.customButtons`) qui ouvre un **dialogue de saisie** capturant la chaîne LaTeX ; la validation insère l'op embed au point d'insertion courant (`controller.replaceText(index, len, embed, selection)`). Éditer un embed existant (re-saisie) est possible (tap/bouton → dialogue pré-rempli → remplacement de l'op). Test widget : insérer `E=mc^2` via le flux d'insertion produit une tranche contenant l'op `{insert:{latex:'E=mc^2'}}` et un rendu de formule.

4. **AC4 — Défensif (AD-10) : LaTeX invalide / vide / absent → placeholder d'erreur inline, jamais de throw.** L'`EmbedBuilder` ne throw **JAMAIS** : (a) LaTeX **malformé** (parse error `flutter_math_fork`) → **placeholder d'erreur inline** (via `Math.tex(onErrorFallback: ...)`), l'éditeur reste fonctionnel ; (b) donnée **vide** (`''`) ou **absente** / **non-`String`** (type inattendu sous `insert.latex`) → placeholder d'erreur inline, pas de crash. Test widget sur matrice réelle (`'\\frac{'` tronqué, `''`, donnée `null`/nombre) : `takeException()` null, éditeur toujours montable/utilisable.

5. **AC5 — Round-trip préservé (cohérence E6-2, op opaque).** L'op embed LaTeX **traverse** le round-trip **inchangée** : `ZDeltaCodec.decode(encode(ops)) == ops` (identité, l'op `{insert:{latex:...}}` incluse) ; `ZMarkdownCodec` la remplace par le **placeholder** `[embed:latex]` (perte bornée, texte environnant préservé) — le **type `latex`** est bien celui capté par `DeltaNeutralOps._embedPlaceholder` (1re clé de la `Map` `insert`). **Aucune** modification du chemin hot de codec. Test : round-trip d'un corpus `texte + embed latex + texte` → `ZDeltaCodec` identité ; `ZMarkdownCodec` → Markdown non vide contenant les 2 segments de texte + un marqueur `[embed:latex]`, sans ressusciter l'embed.

6. **AC6 — Isolation de la lib de rendu (gate AD-1).** `flutter_math_fork` est déclarée au **SEUL** pubspec de `zcrud_markdown`. Un test de **graphe par fermeture transitive** (miroir de `conversion_libs_isolation_graph_test.dart` / `flutter_quill_isolation_graph_test.dart`) prouve : (a) la closure de `zcrud_core` **ne contient AUCUN** `flutter_math_fork` (ni ses transitives) ; (b) **contrôle positif** anti-faux-vert : la closure de `zcrud_markdown` **contient** `flutter_math_fork` ; (c) acyclicité `zcrud_markdown → zcrud_core` maintenue, out-degree zcrud_* du cœur = 0. `dart pub get --dry-run` (gate compat E1-4) **VERT** après ajout de la dép ; version exacte figée dans les Completion Notes.

7. **AC7 — Aucun type de rendu ne fuit (signature + barrel + runtime).** Le barrel n'exporte **aucun** symbole `flutter_math_fork` (ni `Math`/`SelectableMath`/`TeXParser`) ni `flutter_quill`. La surface **publique** de `ZMarkdownField` (et de tout nouveau symbole public exporté par E6-3) ne cite **aucun** type `flutter_math_fork`/Quill (scan statique, miroir de `quill_signature_isolation_test.dart`). Runtime : la valeur de tranche après insertion d'un embed reste `List<Map<String, dynamic>>` **JSON-safe** (`jsonDecode(jsonEncode(v)) == v`), l'op embed = `Map` opaque — jamais un type Quill/math.

8. **AC8 — SM-1 / AD-2 non régressés par l'ajout d'embed.** Réutilise le harnais 100-frappes d'E6-1 (`group('AC2 / SM-1 …')`) : taper **100 caractères** un par un dans un champ **doté** de l'`EmbedBuilder` LaTeX ne reconstruit **que** le champ courant (compteur build tranche == frappes ; voisin figé), le `QuillController` **jamais recréé** (`init == 1`, `identical`), **zéro perte de focus/sélection** (caret au point d'insertion). Les `embedBuilders` et le/les bouton(s) custom sont construits de manière **STABLE** (référence figée, pas d'allocation par (re)build de tranche) — l'`EmbedBuilder` n'entre **jamais** dans le flux `document.changes` (chemin chaud intact, MED-1 préservé).

9. **AC9 — Thème / RTL / a11y (AD-13).** Bouton toolbar d'insertion et boutons du dialogue : cibles **≥ 48 dp**, `Semantics` explicites, insets **directionnels** (`EdgeInsetsDirectional`), `TextAlign.start`/`AlignmentDirectional`. Le placeholder d'erreur porte une `Semantics`/label lisible (ex. « formule invalide ») et ses couleurs viennent du **thème injecté** (`ZcrudTheme.of(context)` / `Theme.of(context)`) — **zéro** couleur codée en dur. Rendu vérifié sans exception sous `TextDirection.rtl` et sous thème clair/sombre.

10. **AC10 — Frontière E6-3 respectée (LaTeX uniquement).** **Aucun** embed tableau (E6-4) n'est introduit ; **aucune** dépendance table (`flutter_tex`, `html_editor_enhanced`, lib de tableau) ajoutée. **Aucune** modification de `zcrud_core`. Aucune modification du contrat `ZCodec` (E6-2) au-delà, éventuellement, de l'étiquetage du placeholder (voir Dev Notes — optionnel, non requis car le placeholder générique gère déjà `latex`).

## Tasks / Subtasks

- [x] **Task 1 — Embed LaTeX custom + dép isolée (AC1, AC6).**
  - [x] Ajouter `flutter_math_fork` (voir version § Libs) au **seul** `packages/zcrud_markdown/pubspec.yaml` ; `dart pub get --dry-run` (racine) VERT (gate E1-4) ; **figer la version exacte** dans les Completion Notes. → `flutter_math_fork ^0.7.4`, résolu **0.7.4**.
  - [x] `lib/src/presentation/z_latex_embed.dart` : embed Quill custom `ZLatexEmbed extends Embeddable` de type `latex` (op `{insert:{latex:String}}`, `const`). **Rien dans le barrel**.
- [x] **Task 2 — `EmbedBuilder` de rendu défensif (AC2, AC4, AC9).**
  - [x] `ZLatexEmbedBuilder extends EmbedBuilder` (`key == 'latex'`, `expanded == false` → inline) : `build(...)` → `Math.tex(<latex>, mathStyle: text, textStyle: ctx.textStyle, onErrorFallback: (e) => <placeholder>)`.
  - [x] **Défensif (AD-10)** : donnée vide / non-`String` / absente → placeholder d'erreur inline (`Icon(error_outline)`) ; **jamais** de throw. Placeholder = widget thémé (`ZcrudTheme.errorColor` → repli `Theme.error`) + `Semantics(label: 'formule invalide')`, insets directionnels.
- [x] **Task 3 — Câblage dans `ZMarkdownField` (AC2, AC8).**
  - [x] `QuillEditorConfig.embedBuilders: _kLatexEmbedBuilders` (const top-level → instance CANONICALISÉE stable). Config éditeur reste `const`. Chemin chaud `_onQuillChanged` INCHANGÉ.
- [x] **Task 4 — Insertion / édition via toolbar + dialogue (AC3, AC9).**
  - [x] `QuillSimpleToolbarConfig.customButtons` (hissée en `late final _toolbarConfig` STABLE) : bouton « Formule » (`Icons.functions`, tooltip) → dialogue de saisie/édition ; validation → `_quill.replaceText(index, len, ZLatexEmbed(source), selection)`.
  - [x] Édition d'un embed existant : `_latexEmbedAtSelection()` détecte l'embed sous/juste-après le caret → dialogue pré-rempli → remplacement de l'op (longueur 1).
- [x] **Task 5 — Tests rendu / insertion / défensif (AC2, AC3, AC4).**
  - [x] `test/z_latex_embed_test.dart` : rendu (op → widget `Math`) ; insertion via flux (bouton `onPressed` réel → dialogue → tranche contient `{insert:{latex:'E=mc^2'}}`) ; édition d'embed existant ; annulation ; matrice défensive (malformé, vide, non-`String`, null) → `takeException()` null, éditeur montable.
- [x] **Task 6 — Round-trip / cohérence E6-2 (AC5).**
  - [x] `test/fixtures/rich_corpus.dart` étendu (`latexTypeEmbedOps`, `mixedTextAndLatexEmbedOps` de type CANONIQUE `latex`) ; `ZDeltaCodec` identité (corpus) + `z_markdown_codec_test.dart` : `ZMarkdownCodec` → `[embed:latex]`, texte préservé, embed non ressuscité. Codec INCHANGÉ.
- [x] **Task 7 — Gates isolation & signature (AC6, AC7).**
  - [x] `test/math_lib_isolation_graph_test.dart` (miroir) : `flutter_math_fork` **absent** closure `zcrud_core`, **présent** `zcrud_markdown` (contrôle positif). `graph_proof.py` CORE OUT=0, acyclique.
  - [x] `test/quill_signature_isolation_test.dart` étendu : barrel + surface publique sans `flutter_math`/`Math`/`SelectableMath`/`MathStyle` ni embed non exporté ; runtime tranche neutre JSON-safe après insertion (dans `z_latex_embed_test.dart`).
- [x] **Task 8 — SM-1 + a11y/RTL + vérif verte (AC8, AC9).**
  - [x] Harnais SM-1 (100 frappes) **avec** `EmbedBuilder` actif : build tranche == frappes, `init==1`, `identical` (controller + `embedBuilders`), focus/caret conservés.
  - [x] Test a11y/RTL : bouton toolbar présent + toolbar ≥ 48 dp, dialogue OK/Annuler ≥ 48 dp, `Semantics`, placeholder thémé sous `rtl`, couleur du thème injecté, sans exception.
  - [x] Vérif verte **ciblée** `zcrud_markdown` : `flutter analyze` RC=0 (0 issue) → `flutter test` RC=0 (125 tests) → `dart pub get --dry-run` RC=0 → `graph_proof.py` RC=0. **Aucune** modif hors `packages/zcrud_markdown/`.

## Dev Notes

### Décision de conception (résout l'ambiguïté centrale)

> **Question ouverte** : réutiliser le type d'embed **`formula`** intégré de flutter_quill (`BlockEmbed.formulaType`, servi par `flutter_quill_extensions`) OU définir un embed **custom `latex`** ?
>
> **Résolution retenue (à implémenter telle quelle)** : **embed custom de type `latex`**, op `{"insert": {"latex": "<source>"}}`, avec un `EmbedBuilder` **maison** branché sur `flutter_math_fork` **directement** — **PAS** `flutter_quill_extensions` (dép additionnelle non voulue, AD-1). Rationale : (a) le task/epic nomment `latex` ; (b) le placeholder d'E6-2 (`_embedPlaceholder` = 1re clé de la `Map` `insert`) est **générique** → il produit `[embed:latex]` **sans aucune modif** de `ZMarkdownCodec` ; (c) isolation totale de la lib de rendu (aucun couplage à l'écosystème d'extensions Quill).
>
> **Inline vs block** : par défaut embed **inline** (formule dans le flux du paragraphe) via `Embeddable('latex', source)`. Un `BlockEmbed` (ligne dédiée) est acceptable si l'API Quill 11.5 l'impose pour le rendu ; documenter le choix. Dans les deux cas la représentation Delta reste `{insert:{latex:...}}`.

### État réel du point d'intégration (à lire AVANT de coder)

`packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart` (E6-1/E6-2, **done**) :
- **Ce qu'il fait** : `initState` → seed via `codec.decode` → `decodeDefensiveDocument` → `QuillController` unique. Frappe → `document.changes` → `_onQuillChanged` → `encodeNeutral` → `setValue` (sens unique, dédup `_lastValueJson`, garde `_applyingExternal`). Sync guardée `_syncFromExternal` **hors focus** uniquement. `_buildEditor` construit un `QuillEditor` avec `config: const QuillEditorConfig(scrollable:false, padding: EdgeInsetsDirectional.zero)` et un `QuillSimpleToolbar` (const config).
- **Ce que E6-3 change** : (a) `QuillEditorConfig.embedBuilders: <EmbedBuilder>[ZLatexEmbedBuilder()]` (instance **stable**) ; (b) `QuillSimpleToolbarConfig.customButtons` : bouton « Formule ». **Rien d'autre** dans le chemin chaud.
- **DOIT être préservé (non-négociable)** : `QuillController`/`FocusNode`/`ScrollController` créés une fois / disposés ; abonnement `document.changes` annulé au dispose + ré-abonné après swap de document ; sens unique ; dédup ; sync guardée hors focus ; RTL/thème/a11y (AD-13). ⚠️ **Le `const QuillEditorConfig(...)` actuel devient non-const** si `embedBuilders` référence des instances non-const → **hisser la liste `embedBuilders` en champ `static`/`late final` STABLE** pour ne pas ré-allouer à chaque build de tranche (SM-1). **Ne JAMAIS** faire entrer l'`EmbedBuilder` ni le codec dans `_onQuillChanged` (chemin chaud).
- **Réutiliser, ne pas réimplémenter** : `DeltaNeutralOps` (E6-2) pour toute manip d'ops neutres ; les fixtures/harnais SM-1/défensif d'E6-1/E6-2.

### API Quill 11.5 — embeds (rappel technique)

- **Op Delta d'un embed** : `{"insert": {<type>: <data>}}` (data JSON-safe). Type `latex`, data = `String` source.
- **`EmbedBuilder`** : `String get key` (== `'latex'`) + `Widget build(BuildContext, EmbedContext)` (récupère `embedContext.node.value.data`). Enregistré via `QuillEditorConfig(embedBuilders: [...])`.
- **Insertion** : `controller.replaceText(index, length, Embeddable('latex', source), TextSelection.collapsed(offset: index + 1))`.
- **Toolbar custom** : `QuillSimpleToolbarConfig(customButtons: [QuillToolbarCustomButtonOptions(icon: ..., onPressed: () => showDialog(...))])`.

### Rendu défensif `flutter_math_fork` (AD-10)

- `Math.tex(source, onErrorFallback: (FlutterMathException e) => <placeholder>)` — capture les erreurs de **parse/rendu** sans throw. NE PAS laisser l'exception remonter.
- Envelopper l'accès à la donnée : si `data` n'est pas une `String` non vide → retourner directement le placeholder (ne pas appeler `Math.tex` sur une entrée invalide).
- Placeholder = widget thémé (`Theme.of`/`ZcrudTheme`) + `Semantics(label: '<formule invalide>')`, insets directionnels — jamais une couleur en dur (AD-13/FR-26).

### Learnings absorbés (E6-1 / E6-2)

- **Round-trip prouvé sur cas RÉELS** (pas de proxy) : reproduire la matrice défensive réelle (E6-1 : 9 cas → doc vide/`takeException` null). Pour E6-3 : matrice LaTeX malformé/vide/non-String.
- **Isolation lib = gate de graphe par fermeture transitive** (`dart pub deps --json`, fallback local honnête) **avec contrôle positif** anti-faux-vert : réutiliser exactement le patron `conversion_libs_isolation_graph_test.dart`, cible = `flutter_math_fork`.
- **Anti-fuite de type** : scan statique (barrel + région publique) **et** runtime (tranche `List<Map>` JSON-safe). Étendre au type `flutter_math_fork`.
- **MED-1 (efficacité)** : ne rien introduire dans le flux `document.changes` ; `embedBuilders` stables (pas d'alloc par build).
- **HIGH-1 d'E6-2 (perte bornée)** : l'op embed LaTeX est déjà gérée en placeholder par `ZMarkdownCodec` — **ne pas** la faire ressusciter ni casser cette borne.
- **Instance-par-montage / anti-fuite dispose** (E6-1) : rien de nouveau à disposer si l'`EmbedBuilder` est sans état ; s'il détient une ressource, la libérer.

### Invariants d'architecture applicables (AD)

- **AD-7** — Delta interne ; embeds LaTeX rendus ; (dé)sérialisation persistée via `ZCodec` (déjà E6-2, non modifié).
- **AD-1** — `flutter_math_fork` au **seul** pubspec `zcrud_markdown` ; aucun type ne fuit ; closure `zcrud_core` sans la lib ; acyclicité ; out-degree zcrud_* du cœur = 0.
- **AD-10** — rendu **défensif** : formule invalide/vide/absente → placeholder d'erreur inline, jamais de throw ; évolution additive.
- **AD-2** — chemin chaud de frappe intact (embed builder hors flux) ; controller stable ; `embedBuilders` stables ; sens unique ; SM-1 non régressé.
- **AD-13** — RTL/thème/a11y : bouton toolbar/dialogue ≥ 48 dp, `Semantics`, directionnel, couleurs du thème.

### Impact `zcrud_core` — **NON**

**E6-3 vit ENTIÈREMENT dans `zcrud_markdown`** : l'embed custom, l'`EmbedBuilder`, le bouton toolbar, le dialogue et la dép `flutter_math_fork` sont tous **spécifiques au rich-text** et consomment `flutter_quill` (déjà la SEULE arête Quill du graphe, cantonnée à ce package). La valeur de tranche reste **Delta JSON neutre** (l'op `{insert:{latex:...}}` est JSON-safe et déjà round-trippée opaquement par E6-2) → **aucun** nouveau concept dans `zcrud_core`, **aucun** port neutre requis pour le MVP. *Note orchestrateur* : E6-3 est **disjointe** d'E11a-2 (`zcrud_intl`, package et fichiers différents) → parallélisation sûre ; **aucune** écriture concurrente de fichiers partagés.

### Libs de rendu — choix & version

- **`flutter_math_fork`** (stack architecture, « rendu formules ») — rendu LaTeX Flutter pur, API `Math.tex(...)` + `onErrorFallback`. Version cible **`^0.7.4`** (dernière stable de la lignée 0.7.x, compatible Flutter/Dart `^3.12.2`). **Contrainte de compat à VÉRIFIER au dev** : `dart pub get --dry-run` (racine workspace) doit rester **VERT** (gate E1-4) après ajout ; **figer la version exacte résolue** dans les Completion Notes (comme E6-2 l'a fait pour `markdown_quill 4.3.0`). En cas d'incompat de résolution, choisir la version 0.7.x compatible la plus proche et **justifier**.
- **PAS** `flutter_quill_extensions` (éviterait de réimplémenter le builder, mais tire un ensemble de deps additionnel non voulu — AD-1). On câble `flutter_math_fork` **directement**.

> ⚠️ **Ne PAS** committer les `pubspec.lock` de package ni les `*.g.dart` (gitignorés). Nouvelle dépendance : **uniquement** `zcrud_markdown/pubspec.yaml` (AD-1). Le `pubspec.lock` **racine** du workspace bougera (conséquence inévitable, commit en fin d'epic par l'orchestrateur).

### Stratégie de tests

- **Rendu (AC2)** : op `{insert:{latex:'E=mc^2'}}` → widget `Math`/`SelectableMath` trouvé (édition + `readOnly`).
- **Insertion (AC3)** : flux toolbar+dialogue → tranche contient l'op ; édition d'un embed existant.
- **Défensif (AC4, AD-10)** : matrice réelle (`'\\frac{'`, `''`, data `null`/nombre) → placeholder, `takeException()` null.
- **Round-trip (AC5)** : `ZDeltaCodec` identité incl. op latex ; `ZMarkdownCodec` → `[embed:latex]`, texte préservé.
- **Isolation graphe (AC6)** : fermeture transitive `flutter_math_fork` absent core / présent markdown (contrôle positif) ; `graph_proof.py` CORE OUT=0.
- **Signature (AC7)** : scan statique barrel + surface publique ; runtime tranche neutre JSON-safe après insertion.
- **SM-1/AD-2 (AC8)** : harnais 100-frappes d'E6-1 avec `EmbedBuilder` actif → build==frappes, `init==1`, `identical`, focus/caret conservés.
- **a11y/RTL (AC9)** : bouton ≥ 48 dp, `Semantics`, placeholder thémé sous rtl + clair/sombre.

### Project Structure Notes

- **Fichiers NEW** (tous sous `packages/zcrud_markdown/`) : `lib/src/presentation/z_latex_embed.dart` (embed custom + `ZLatexEmbedBuilder` + bouton/dialogue, ou scinder builder/dialogue si volumineux) ; tests `test/z_latex_embed_test.dart`, `test/math_lib_isolation_graph_test.dart`.
- **Fichiers UPDATE** : `lib/src/presentation/z_markdown_field.dart` (branchement `embedBuilders` + `customButtons`, config non-const hissée en champ stable ; **chemin chaud inchangé**) ; `pubspec.yaml` (+ `flutter_math_fork`) ; `test/quill_signature_isolation_test.dart` (extension AC7) ; `test/fixtures/rich_corpus.dart` (fixture `texte + embed latex + texte`, si non déjà présente) ; `test/z_markdown_codec_test.dart` (assertion `[embed:latex]`, si à renforcer). **Aucun** fichier hors `packages/zcrud_markdown/`. **Zéro** modif `zcrud_core`.
- **Naming** (conventions zcrud) : types `Z*` (`ZLatexEmbed`, `ZLatexEmbedBuilder`) ; fichiers snake_case ; API publique = barrel, impl sous `lib/src/{domain,data,presentation}`. **Aucun** symbole Quill/`flutter_math_fork` re-exporté.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E6] — Story E6-3 (insertion/édition/rendu ; `flutter_math_fork` ; formule malformée → repli sûr placeholder, AD-10) ; frontière E6-4 (tableau).
- [Source: architecture.md#AD-7] — Delta interne (Quill) + embeds ; round-trip testé (formules) ; controller isolé (AD-2). Stack : `flutter_math_fork (LaTeX)`.
- [Source: architecture.md#AD-1] — lib de rendu au seul pubspec `zcrud_markdown` ; ne fuit jamais dans `zcrud_core` ; satellite → core uniquement ; acyclicité.
- [Source: architecture.md#AD-10] — désérialisation/rendu défensif ; embed corrompu → parent jamais cassé ; additif.
- [Source: architecture.md#AD-2, #AD-13] — chemin chaud granulaire, controller stable ; RTL/a11y (≥48 dp, `Semantics`, directionnel), thème injecté.
- [Source: packages/zcrud_markdown/lib/src/data/delta_neutral_ops.dart] — traitement embed OPAQUE d'E6-2 (`toDeltaForMarkdown`/`_embedPlaceholder` → `[embed:<type>]`, perte bornée) ; le type `latex` y est capté génériquement.
- [Source: packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart] — point d'intégration (config `QuillEditor`/toolbar, chemin chaud `_onQuillChanged`, sync guardée).
- [Source: _bmad-output/implementation-artifacts/stories/e6-2-zcodec-pluggable.md] — embeds = ops opaques ; HIGH-1 (perte bornée) ; gates isolation/signature ; SM-1 avec codec.
- [Source: packages/zcrud_markdown/test/flutter_quill_isolation_graph_test.dart, conversion_libs_isolation_graph_test.dart, quill_signature_isolation_test.dart] — patrons de gate à réutiliser (cible `flutter_math_fork`).
- [Source: packages/zcrud_markdown/test/z_markdown_field_test.dart] — harnais SM-1 (`group('AC2 / SM-1 …')`, 100 frappes, `onInit`/`onBuild`) à réutiliser.
- [Source: CLAUDE.md] — `zcrud_markdown` = Quill + `ZCodec` + embeds LaTeX/tables ; Key Don'ts (pas de lib lourde dans le cœur, pas de fuite de type, barrel, directionnel).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- Vérif verte rejouée réellement sur disque (ciblée `zcrud_markdown`) :
  - `flutter analyze` → **No issues found!**, RC=0.
  - `flutter test` (package entier) → **125 tests, All tests passed!**, RC=0 (dont 14 nouveaux tests E6-3 dans `z_latex_embed_test.dart`).
  - `dart pub get --dry-run` (racine workspace) → RC=0 (résolution VERTE, `flutter_math_fork 0.7.4`).
  - `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0**, 14 nœuds, RC=0.
  - `dart run melos list` → **14** packages.
- Ajustements de tests durant le dev (sans changer la conception) :
  - AC3/AC9 (dialogue) : le bouton custom de toolbar est déclenché via son `options.onPressed` RÉEL (`QuillToolbarCustomButton`) plutôt que par un tap hit-testé (toolbar défilante) — voie de production exacte, robuste.
  - AC4 (malformé) : `Math.tex` retourne un widget `Math` qui REND lui-même le fallback ⇒ l'assertion « pas de widget Math » n'est valide que pour le cas `''` (court-circuit avant `Math.tex`). Le placeholder (`Icon(error_outline)`) reste l'invariant asserté pour malformé + vide.
- **Remédiation code-review E6-3 (2026-07-10)** — traitement des findings F1 (MEDIUM) + F2/F3/F4/F5 (LOW). Vérif verte rejouée réellement (ciblée `zcrud_markdown`) :
  - `flutter analyze` → **No issues found!**, RC=0.
  - `flutter test` (package entier) → **128 tests, All tests passed!**, RC=0 (**+3** vs 125 : rendu readOnly RÉEL, OK-sur-vide/blanc, label a11y `kLatexInvalidLabel`).
  - `dart pub get --dry-run` (racine workspace) → RC=0 (résolution VERTE inchangée).
  - `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0**, RC=0.

### Completion Notes List

- **Dépendance figée** : `flutter_math_fork: ^0.7.4` (résolu **0.7.4**, sha `6d5f2f1aa57ae539ffb0a04bb39d2da67af74601d685a161aff7ce5bda5fa407`) au **SEUL** `packages/zcrud_markdown/pubspec.yaml` (AD-1). Compat E1-4 : SDK `>=3.0.0 <4.0.0` (satisfait par `^3.12.2`), résolution workspace VERTE.
- **Inline vs block (ambiguïté tranchée)** : embed **inline** via `ZLatexEmbed extends Embeddable('latex', source)` + `ZLatexEmbedBuilder.expanded == false` (force le chemin `buildWidgetSpan` inline, y compris pour une formule seule sur sa ligne). Représentation Delta = `{"insert": {"latex": "<source>"}}`. **PAS** `BlockEmbed.formula`, **PAS** `flutter_quill_extensions`.
- **Cohérence E6-2 (AC5)** : AUCUNE modification de `ZDeltaCodec`/`ZMarkdownCodec`/`DeltaNeutralOps`. Le type `latex` est capté GÉNÉRIQUEMENT par `_embedPlaceholder` (1re clé de la `Map` `insert`) → `ZMarkdownCodec` produit `[embed:latex]` sans changement. `ZDeltaCodec` préserve l'op à l'identité (identité prouvée sur `latexTypeEmbedOps` + `mixedTextAndLatexEmbedOps`).
- **Isolation (AC6/AC7)** : `flutter_math_fork` absent de la fermeture de `zcrud_core` (gate `math_lib_isolation_graph_test.dart`, contrôle positif inclus). Aucun type `flutter_math_fork`/Quill dans le barrel ni la surface publique de `ZMarkdownField` (scan statique) ; tranche runtime = `List<Map<String,dynamic>>` JSON-safe après insertion (op embed = `Map` opaque).
- **Défensif (AC4/AD-10)** : LaTeX malformé (`\frac{`) → `onErrorFallback` placeholder ; `''`/`null`/nombre → court-circuit avant `Math.tex` ou dégradation défensive du document ; `takeException()` null, éditeur montable.
- **SM-1/AD-2 (AC8) NON régressé** : `embedBuilders` = `const` canonicalisée (MÊME instance à chaque build, assertion `identical`) ; `_toolbarConfig` hissée `late final` ; chemin chaud `_onQuillChanged` INCHANGÉ. 100 frappes → seul le champ courant rebâtit, voisin/global figés, controller jamais recréé, focus/caret préservés.
- **A11y/RTL/thème (AC9)** : bouton « Formule » (tooltip) + toolbar ≥ 48 dp ; dialogue OK/Annuler ≥ 48 dp ; placeholder `Semantics(label: 'formule invalide')`, couleur du thème injecté (`ZcrudTheme.errorColor`), insets directionnels ; rendu sans exception sous `rtl`.
- **Impact `zcrud_core` = NON** (confirmé) : aucun fichier hors `packages/zcrud_markdown/` modifié ; aucun nouveau concept/port dans le cœur.
- **Frontière E6-3** respectée : embed LaTeX UNIQUEMENT ; aucun embed tableau (E6-4), aucune dép table (`flutter_tex`/`html_editor_enhanced`).
- **Remédiation code-review (2026-07-10)** — findings du rapport `code-review-e6-3.md` :
  - **F1 (MEDIUM) — CORRIGÉ** : AC2 « rendu en LECTURE (readOnly) » désormais prouvé par un test RÉEL (`z_latex_embed_test.dart`, groupe AC2) montant un `QuillEditor` avec `QuillController(readOnly: true)` câblé sur l'`EmbedBuilder` réel (`ZLatexEmbedBuilder`) + document `latex` → `find.byType(Math) findsWidgets` ET `controller.readOnly == true`. Le proxy « builder câblé » ne prouvait pas le rendu ; c'est désormais un rendu effectif en lecture.
  - **F2 (LOW) — CORRIGÉ** : `_ZLatexDialogState._submit` traite une saisie **vide ou blanche** (`trim().isEmpty`) comme une ANNULATION (`pop(null)`) — plus aucun embed `latex` vide inséré (fini le placeholder d'erreur persistant). Test : OK sur champ vide PUIS sur saisie `'   '` → aucune mutation de tranche, `Math findsNothing`.
  - **F3 (LOW) — CORRIGÉ** : nouveau test AC9 vérifiant que le placeholder d'erreur porte bien le `Semantics.label == kLatexInvalidLabel` (« formule invalide ») — inspection directe du widget `Semantics` (robuste, sans dépendre de l'arbre sémantique activé).
  - **F4 (LOW/nit) — CORRIGÉ** : lecture morte `final sel = _quill.selection;` déplacée dans la seule branche INSERTION (après le `return` d'édition) où elle est effectivement utilisée.
  - **F5 (LOW/nit) — DOCUMENTÉ** : l'édition par **tap direct** sur la formule rendue est explicitement HORS PÉRIMÈTRE (garde l'`EmbedBuilder` `const` sans état → SM-1) ; la ré-édition passe par la **voie bouton toolbar** (caret sur/après l'embed + bouton « Formule »). Documenté dans le doc-comment de `ZLatexEmbedBuilder` (`z_latex_embed.dart`). AC3 reste satisfait par la voie bouton.
  - Invariants E6-1/E6-2/E6-3 préservés : `embedBuilders` const stable, op opaque, codec inchangé, SM-1 (AC8) non régressé (test 100 frappes toujours vert).

### File List

**NEW (tous sous `packages/zcrud_markdown/`)**
- `lib/src/presentation/z_latex_embed.dart` — `ZLatexEmbed` (embed custom `latex`), `ZLatexEmbedBuilder` (rendu défensif `flutter_math_fork`), dialogue `showZLatexDialog`/`_ZLatexDialog`. _(Remédiation 2026-07-10 : F2 `_submit` annule sur saisie vide/blanche ; F5 doc-comment « édition via bouton toolbar »)._
- `test/z_latex_embed_test.dart` — rendu (édition + **lecture readOnly RÉELLE**) / insertion / édition / défensif / SM-1 / a11y-RTL-thème (**17 tests** ; +3 en remédiation : readOnly F1, OK-sur-vide/blanc F2, label a11y F3). Importe l'impl `src/presentation/z_latex_embed.dart` (test interne au package).
- `test/math_lib_isolation_graph_test.dart` — gate de graphe (isolation `flutter_math_fork`, contrôle positif).

**UPDATED (tous sous `packages/zcrud_markdown/`)**
- `pubspec.yaml` — ajout `flutter_math_fork: ^0.7.4` (isolé, AD-1).
- `lib/src/presentation/z_markdown_field.dart` — `embedBuilders` (const stable) + `customButtons` (`_toolbarConfig` late final) + méthodes `_promptAndInsertLatex`/`_latexEmbedAtSelection` + `_LatexEmbedHit`. Chemin chaud inchangé. _(Remédiation 2026-07-10 : F4 lecture morte `sel` déplacée dans la branche insertion.)_
- `test/fixtures/rich_corpus.dart` — fixtures `latexTypeEmbedOps` + `mixedTextAndLatexEmbedOps` (type CANONIQUE `latex`) ajoutées au corpus d'identité.
- `test/z_markdown_codec_test.dart` — assertion `[embed:latex]` (perte bornée, texte préservé, non ressuscité).
- `test/quill_signature_isolation_test.dart` — extension AC7 (barrel + surface publique sans type `flutter_math_fork`/`Math`, embed non exporté).
