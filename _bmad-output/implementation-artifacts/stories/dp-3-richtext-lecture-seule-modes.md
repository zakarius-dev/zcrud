---
baseline_commit: 1bcae2ad4ea1a66198f02020a6f29f77e1e2e2f6
---

# Story DP.3 : Rich-text — lecture seule + modes (parité DODLP, gaps B4+B6) (`zcrud_markdown`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **intégrateur DODLP (migration du moteur d'édition déclaratif vers zcrud) puis lex_douane**,
I want **que le champ rich-text (`ZMarkdownField`) honore `field.readOnly` (rendu lecteur non-éditable, sans éditeur ni toolbar), et qu'il distingue un mode `inline` (compact, édition en place) d'un mode `block` (aperçu + édition en dialog plein-écran) avec un toggle vers le plein-écran (`ZRichTextFullscreenDialog`)**,
so that **tout écran de consultation DODLP (action `read`) affiche le contenu rich-text sans le rendre éditable, et que les deux usages réels — `inlineMarkdown` (compact, le type rich-text le plus utilisé) vs `markdown` (bloc/plein-écran) — soient tous deux couverts fidèlement, sans casser l'éditeur granulaire existant (SM-1/AD-2) ni toucher `zcrud_core`.**

## Contexte & cadrage (à lire avant de coder)

**Épic E-DP — Parité migration DODLP (post-v1.x).** Objectif de l'épic : rendre la migration DODLP → zcrud **structurellement fidèle**. **Source de vérité détaillée des comportements DODLP réels + gaps :** `docs/dodlp-edition-parity-gap.md` (§2.1 Éditeur Markdown / Rich-text). Cette story couvre **B4** (lecture seule rich-text absente — bloquant) **+ B6** (distinction `markdown` bloc/plein-écran vs `inlineMarkdown` compact + dialog plein-écran — bloquant) **+ le major « dialog/bottom-sheet plein-écran »** (`ZRichTextFullscreenDialog`).

**Périmètre STRICT : `zcrud_markdown` (+ ses tests).** **NE PAS modifier `zcrud_core`.** Tous les leviers nécessaires existent déjà côté cœur (voir « État de l'existant » ci-dessous) : `field.readOnly` est porté par `ZFieldSpec`, et le dispatcher `ZFieldWidget` route déjà les kinds `markdown`/`inlineMarkdown`/`richText` vers le `ZWidgetRegistry` injecté. Si un besoin cœur **réel** émerge (ex. le contrat `ZFieldWidgetContext` s'avère insuffisant), **STOP** et signaler à l'orchestrateur — mais l'analyse ci-dessous montre qu'il est suffisant.

### État de l'existant (lu sur disque — à préserver)

- **`ZMarkdownField`** (`packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart`) : champ rich-text Quill au controller **isolé** (AD-2/AD-7/SM-1). Contrat actuel (E6-1..E6-4, **done**, à NE PAS régresser) :
  - Constructeur : `ZMarkdownField({required ZFormController controller, required ZFieldSpec field, bool showToolbar = true, ZCodec? codec, VoidCallback? onInit, VoidCallback? onBuild, Key? key})`.
  - `QuillController`/`FocusNode`/`ScrollController` créés **1×** en `initState`, disposés en `dispose` ; abonnement `document.changes` annulé au dispose (anti-fuite). Saisie **à sens unique** (`document change → controller.setValue`). **Sync guardée hors focus** (`_syncFromExternal`, ne ré-injecte jamais pendant l'édition).
  - Valeur de tranche **NEUTRE** (Delta JSON `List<Map<String,dynamic>>`) ; **aucun** type Quill dans la signature publique (gate `quill_signature_isolation_test.dart`). Codec `ZCodec` pluggable **uniquement** à la couture de persistance (`persistedValueOf`), jamais dans le chemin chaud.
  - Toolbar `QuillSimpleToolbar` + `_kEmbedBuilders` (`const [ZLatexEmbedBuilder(), ZTableEmbedBuilder()]`) partagés édition **et** rendu ; `Localizations.override(FlutterQuillLocalizations.delegate)`.
  - `showToolbar: false` **existe déjà** pour un rendu compact — MAIS l'éditeur **reste pleinement éditable** (ce n'est PAS un mode lecture seule ; `field.readOnly` n'est **jamais lu**).
  - **Fenêtre de test** `ZMarkdownFieldDebug` (`debugDocChangeCount`, `debugDocSubscriptionActive`, `debugPersistedValue`) + hooks `onInit`/`onBuild` (`@visibleForTesting`) : **réutiliser** pour les preuves SM-1 / anti-fuite.
- **`ZFieldSpec.readOnly`** (`packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart:79`) : `final bool readOnly` (défaut `false`), présent dans `copyWith` (`readOnly:` — utilisé par le **mode lecture global** d'E3-4, `spec.copyWith(readOnly:true)`). **Aucune modification cœur requise** : la spec transporte déjà le flag ; il suffit de le **lire** côté `zcrud_markdown`.
- **`ZWidgetRegistry` / dispatcher `ZFieldWidget`** (`packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:432-450` + `z_widget_registry.dart`) :
  - Les kinds `markdown`, `inlineMarkdown`, `richText` (+ html/inlineHtml/géo/tél/…) sont routés vers `EditionFamily.registryOrFallback` → `_dispatchRegistry` (`edition_field_family.dart:183-195`).
  - Convention de `kind` = **`field.type.name`** (`'markdown'`, `'inlineMarkdown'`, `'richText'`). Chaque kind est un builder distinct dans le registre.
  - **CONTRAT CLÉ (à intégrer) :** le builder reçoit **UNIQUEMENT** un `ZFieldWidgetContext { ZFieldSpec field; Object? value; ValueChanged<Object?> onChanged; }` — **PAS** le `ZFormController`. `onChanged` est branché sur `controller.setValue(field.name, …)`. Le dispatcher rend le builder **dans** sa propre frontière de rebuild (value-in-slice) : `value` est ré-émise à chaque changement de la tranche `field.name`. Repli `ZUnsupportedFieldWidget` si le kind n'est pas enregistré.
- **`ZMarkdownCodecScope`** (`z_markdown_codec_scope.dart`) : InheritedWidget optionnel fournissant le `ZCodec` de persistance hérité (précédence `param > scope > ZDeltaCodec()`).

### Le point d'intégration structurant (⚠️ lire attentivement — décision de conception)

`ZMarkdownField` exige **aujourd'hui** un `ZFormController` complet (il ouvre lui-même sa tranche via `ZFieldListenableBuilder(controller, name)`). Or le builder du `ZWidgetRegistry` ne reçoit **que** `ZFieldWidgetContext` (`field`/`value`/`onChanged`) — **jamais** le controller. **C'est le nœud de la story** et il se résout **entièrement dans `zcrud_markdown`, sans toucher le cœur** :

- Fournir une **voie d'intégration `ctx`-native** du champ rich-text (nouvel adaptateur/constructeur nommé, ex. `ZMarkdownField.fromContext(...)` **ou** un widget interne `ZMarkdownFieldRegistryAdapter`) qui pilote un `QuillController` **isolé et stable** (créé 1× en `initState`, disposé) en s'alimentant de `ctx.value` (**seed + sync guardée hors focus**) et en écrivant via `ctx.onChanged` (**sens unique**) — **strictement le même contrat AD-2/AD-7/SM-1** que la version `controller`, mais sans dépendre du `ZFormController`.
  - Le dispatcher ré-émet `ctx.value` à chaque frappe (car `onChanged → setValue → slice change → rebuild du builder`). Le `State` de l'adaptateur **persiste** (place stable via `ValueKey(field.name)` posée par l'assembleur) ⇒ le `QuillController` **n'est jamais recréé**, focus/sélection préservés ; la sync guardée `!hasFocus` reste **no-op** pendant la frappe. **SM-1 intact** (rebuild O(1) borné à la tranche).
- **Ne PAS régresser** la voie `controller` publique existante (E6-1) : `ZMarkdownField({controller, field, …})` reste exportée et testée telle quelle. La logique neutre/défensive (`DeltaNeutralOps`, résolution du codec, embeds, toolbar stable) est **factorisée/partagée** entre les deux voies (pas de duplication du chemin chaud).

### Invariants d'architecture applicables (NON-NÉGOCIABLES)

- **AD-2 / AD-15 (réactivité Flutter-native — OBJECTIF PRODUIT N°1 / SM-1)** [Source: architecture.md#AD-2,#AD-15 ; z_markdown_field.dart:14-44] : controller Quill **isolé** créé 1× / disposé, **jamais** recréé au rebuild ; abonnement `document.changes` annulé au dispose ; saisie **à sens unique** ; **aucune** ré-injection écrasant la sélection pendant l'édition (sync guardée hors focus). **AUCUN** `import` de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`) dans `zcrud_markdown`. En mode **lecture seule**, la voie de frappe et l'abonnement `document.changes` **n'existent pas** (aucun listener, aucun `setValue`).
- **AD-7 / AD-1 (isolation Quill)** [Source: architecture.md#AD-7,#AD-1 ; zcrud_markdown.dart:7-11] : la valeur portée reste le **Delta JSON neutre** ; **aucun** type `flutter_quill` (`QuillController`/`Document`/`Delta`) ni `flutter_math_fork` ne fuit dans la signature publique **ni** dans le contrat du dialog/reader. Gates existants à préserver : `quill_signature_isolation_test.dart`, `flutter_quill_isolation_graph_test.dart`, `math_lib_isolation_graph_test.dart`, `conversion_libs_isolation_graph_test.dart`. **Le nouveau `ZRichTextFullscreenDialog` et le reader lecture seule n'exposent AUCUN type Quill** (entrée/sortie = valeur neutre Delta JSON + `ZCodec`).
- **AD-10 (décodage défensif)** [Source: architecture.md#AD-10 ; z_markdown_field.dart:35-36,254-255] : valeur absente/vide/Delta corrompu → **document VIDE utilisable**, **jamais** de throw — vaut aussi pour le **reader lecture seule** (contenu vide/corrompu → rendu vide propre, pas d'exception) et pour la valeur retournée par le dialog (annulation → `null`, aucune mutation).
- **AD-13 (a11y / RTL / directionnel)** [Source: architecture.md#AD-13 ; z_markdown_field.dart:37-39,415-471] : `Directionality`, `Semantics` explicites, cibles interactives **≥ 48 dp** (bouton toggle plein-écran, bouton « Modifier/Rédiger », actions du dialog) ; layout **directionnel** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start/end`, jamais `left`/`right`) ; listes en `ListView.builder` ; `const` partout où immuable. Le **reader lecture seule** reste **sémantiquement lisible** (contenu exposé au lecteur d'écran) mais **non éditable** (aucune action d'édition annoncée).
- **FR-26 / AD-6 (thème injecté)** [Source: prd.md#FR-26 ; z_markdown_field.dart:410-412] : **aucun** style/couleur codé en dur ; tout via `ZcrudTheme.of(context)` / `ZcrudScope`, repli `Theme.of(context)`. (Le DODLP code des dégradés `Colors.blue/purple` en dur — **NE PAS** les porter ; c'est une divergence AD-6 **voulue**.)
- **AD-4 (extensibilité — widgets via registre)** [Source: architecture.md#AD-4 ; z_widget_registry.dart] : le widget est fourni par le **satellite** (`zcrud_markdown`) et **enregistré** dans un `ZWidgetRegistry` **instanciable** injecté via `ZcrudScope.widgetRegistry` — **jamais** un singleton statique mutable. Le mode (`inline`/`block`) et le flag `readOnly` sont dérivés **par le builder** de `ctx.field` (`field.type` + `field.readOnly`).

### Comportements DODLP retenus (référence — lus sur disque, à répliquer fidèlement, hors chrome cosmétique)

Réf. `dodlp-otr/lib/modules/data_crud/presentation/widgets/rich_text_editor/editors/markdown_edition_field.dart` (`MarkdownEditionField`, `isInline`/`readOnly`) + `.../views/rich_text_editor_screen.dart` (`RichTextEditorScreen` dialog / `RichTextReaderScreen`) + `.../editor_config.dart` (`RichTextToolbarConfig`) + `edition_screen.dart:1330` (`isInline: field.type == EditionFieldTypes.inlineMarkdown`).

1. **Sélection du mode par le TYPE de champ** (`edition_screen.dart:1330`) : `inlineMarkdown` ⇒ **mode inline** (`isInline: true`) ; `markdown` (et `richText`) ⇒ **mode block** (`isInline: false`). → côté zcrud : le **builder enregistré par kind** fixe le mode (`inlineMarkdown` → `inline`, `markdown`/`richText` → `block`).
2. **`readOnly` (prioritaire sur le mode)** (`markdown_edition_field.dart:65,366`) : dès `readOnly`, **aucun** `QuillController` d'édition n'est créé (`_initController` court-circuité : `if (isInline && !readOnly)`), **aucune** toolbar, **aucun** bouton d'édition (`if (!readOnly)` gardant le bouton) ; seul le **rendu lecteur** est affiché (`if (readOnly || !isInline)` → `RichTextReaderScreen`). → côté zcrud : `field.readOnly == true` ⇒ **reader léger** exclusif (voir AC1).
3. **Mode `block` (non-inline, éditable)** (`markdown_edition_field.dart:229-247,366-385`) : affiche un **aperçu lecteur** du contenu (`RichTextReaderScreen`) + un bouton **« Rédiger »/« Modifier »** (selon contenu vide/non-vide) qui ouvre l'**éditeur plein-écran en dialog** et **remonte** la valeur éditée via `onSubmit`. Pas d'édition en place.
4. **Mode `inline` (éditable)** (`markdown_edition_field.dart:311-361,416-448`) : affiche un **éditeur compact en place** (toolbar **minimale**, hauteur bornée `minLines`/`maxLines`) **+** un bouton **toggle plein-écran** (`Icons.fullscreen`, `markdown_edition_field.dart:311-361`) qui ouvre le **même** éditeur en dialog plein-écran ; au retour, le document compact est ré-hydraté avec la valeur éditée. Soumission de l'inline **hors focus** (`_quillFocusNode` listener → `_submitChanges`, ligne 97-101) — **déjà** le contrat « sync/submit hors focus » de zcrud.
5. **Dialog plein-écran** (`rich_text_editor_screen.dart:38,323-451`) : deux présentations — **dialog** `AlertDialog` dimensionné **80 % × 70 %** de l'écran (`width: size.width*0.8, height: size.height*0.7`, lignes 425-426) **OU** **`Scaffold` plein-écran** (`fullscreenDialog`, ligne 436) ; titre = libellé du champ ; **actions** valider/annuler (`buildDialogFormActions`, ligne 429) ; l'annulation ne remonte **aucune** valeur (pas de mutation). → côté zcrud : `ZRichTextFullscreenDialog` — dialog 80 %×70 % (repli `Scaffold` plein-écran sur petit écran, seuil de largeur raisonnable), toolbar **complète**, **retourne** la valeur neutre éditée (`Object?` Delta JSON) ou `null` si annulé.
6. **Rendu lecteur** (`rich_text_editor_screen.dart:527-606`, `RichTextReaderScreen`) : contenu Delta JSON ⇒ `QuillEditor` en **lecture seule** (pas de toolbar) réutilisant les **mêmes embed builders** (LaTeX/tableau) ; contenu vide ⇒ **placeholder** discret « Aucun contenu ». → côté zcrud : reader = `QuillEditor` **non éditable** (readOnly), **sans** toolbar, **mêmes `_kEmbedBuilders`**, hauteur intrinsèque (l'hôte défile), placeholder vide propre.

> **Divergences AD volontaires (NE PAS porter depuis DODLP)** : dégradés/couleurs codés en dur (`mdGradient`, `Colors.*`, `withAlpha`), `EdgeInsets.only(left:)` (utiliser `EdgeInsetsDirectional`), conversion Markdown via `flutter_markdown_plus`/`DefaultStyles` (zcrud reste **Delta neutre** + `ZCodec` ; le reader est un `QuillEditor` readOnly, **pas** un moteur Markdown tiers). L'objectif est la **parité fonctionnelle** (lecture seule + inline/block + dialog), pas la copie du chrome.

## Acceptance Criteria

1. **Lecture seule rich-text (B4) — `field.readOnly` honoré, rendu lecteur non-éditable.** Quand `field.readOnly == true`, `ZMarkdownField` (voie `controller` **et** voie `ctx`/registre) rend un **lecteur léger** : `QuillEditor` **non éditable** (readOnly, `enableInteractiveSelection` autorisant la copie/lecture mais **aucune** saisie), **SANS** `QuillSimpleToolbar`, **SANS** aucun bouton d'édition, réutilisant les **mêmes** `_kEmbedBuilders` (LaTeX/tableau rendus en lecture). **Aucun** `QuillController` d'édition mutant, **aucun** abonnement `document.changes`, **aucun** `setValue`/`onChanged` n'est jamais émis en lecture seule. Contenu vide/absent/corrompu ⇒ rendu vide propre (AD-10), **jamais** de throw. *Test widget : `field.readOnly=true` ⇒ `find` **0** `QuillSimpleToolbar` et **0** bouton d'édition ; le contenu (texte + embed LaTeX) est **visible** ; une tentative de saisie ne modifie pas la valeur ; `debugDocSubscriptionActive == false` (aucun abonnement) et `onChanged` jamais appelé.*

2. **Distinction mode `inline` (compact) vs `block` (bloc/plein-écran) (B6).** `ZMarkdownField` expose un **mode** explicite (`enum ZMarkdownFieldMode { inline, block }` public, dérivé par le builder registre : `inlineMarkdown` → `inline`, `markdown`/`richText` → `block`) :
   - **`inline`** : éditeur **compact en place** (toolbar minimale, hauteur bornée par `minLines`/`maxLines` si présents dans la config, repli défauts sinon) **+** bouton toggle plein-écran (AC3). Édition granulaire SM-1 en place (contrat E6-1 inchangé).
   - **`block`** : **aperçu lecteur** (le reader d'AC1) **+** bouton **« Rédiger »** (contenu vide) / **« Modifier »** (contenu non vide) ouvrant le dialog plein-écran (AC3) ; **pas** d'édition en place.
   *Test widget : un champ `inlineMarkdown` monte un éditeur compact **éditable** en place (frappe → `onChanged`/`setValue`) ; un champ `markdown` monte un **aperçu non éditable** + bouton « Rédiger/Modifier » (frappe directe impossible, seul le dialog édite).*

3. **Toggle vers le plein-écran + `ZRichTextFullscreenDialog`.** Un bouton (cible **≥ 48 dp**, `Semantics` explicite) ouvre `ZRichTextFullscreenDialog` :
   - **inline** : bouton `Icons.fullscreen` « Agrandir » ; **block** : bouton « Rédiger/Modifier ».
   - Le dialog présente l'éditeur rich-text **complet** (toolbar complète, embeds LaTeX/tableau), pré-rempli avec la valeur **neutre** courante, titre = `field.label ?? field.name`, **actions Valider/Annuler**.
   - Présentation : **dialog 80 %×70 %** de l'écran ; **repli `Scaffold` plein-écran** en dessous d'un seuil de largeur (petit écran) — `MediaQuery`, directionnel.
   - **Valider** ⇒ retourne la valeur **neutre éditée** (`Object?` Delta JSON) qui est **écrite via `onChanged`/`setValue`** puis ré-hydrate le champ hôte (via sync guardée hors focus) ; **Annuler**/dismiss ⇒ retourne `null`, **aucune** mutation de la tranche.
   - **AUCUN** type Quill dans la signature publique du dialog (entrée/sortie = valeur neutre + `ZCodec` optionnel). *Test widget : ouvrir le dialog (inline ET block), éditer, Valider ⇒ la tranche reçoit la nouvelle valeur ; ré-ouvrir puis Annuler ⇒ valeur **inchangée** ; le dialog rend son contenu à 80 %×70 % en large et en `Scaffold` plein-écran en étroit.*

4. **Rétro-compatibilité de l'éditeur existant (E6-1..E6-4) — zéro régression.** La voie publique `ZMarkdownField({controller, field, showToolbar, codec, onInit, onBuild})` reste **inchangée** en signature et comportement par **défaut** (`readOnly=false` implicite via `field.readOnly` défaut `false`, mode par défaut = l'éditeur pleine-toolbar actuel). Tous les invariants E6 restent tenus : controller isolé créé 1×/disposé, saisie sens unique, sync guardée hors focus, valeur neutre Delta JSON, codec **hors** chemin chaud, embeds LaTeX/tableau en édition **et** lecture, isolation de signature (aucun type Quill exporté). **Tous les tests markdown existants restent verts** (baseline actuelle du package, cf. AC7). *Gate : les tests E6 existants (`z_markdown_field_test.dart`, `z_markdown_field_lifecycle_test.dart`, `z_markdown_field_codec_test.dart`, `quill_signature_isolation_test.dart`, embeds…) passent **sans modification de leurs attentes** ; SM-1 (100 frappes ⇒ rebuild borné à la tranche, focus préservé) reste prouvé sur la voie éditable.*

5. **Réactivité AD-2/AD-15 sur la voie `ctx`/registre (SM-1).** L'adaptateur `ctx`-natif (`ZMarkdownField.fromContext`/`ZMarkdownFieldRegistryAdapter`, cf. « point d'intégration ») tient **exactement** le même contrat : `QuillController`/`FocusNode`/`ScrollController` créés **1×** en `initState`, disposés, **jamais** recréés ; abonnement `document.changes` annulé au dispose ; écriture **exclusivement** via `ctx.onChanged` ; **sync guardée hors focus** depuis `ctx.value` (jamais de ré-injection pendant l'édition). *Test SM-1 : monté via un `ZWidgetRegistry` peuplé par la factory du package et rendu par `ZFieldWidget`/`DynamicEdition`, taper 100 caractères ne reconstruit **que** ce champ (compteur `onBuild` ciblé), **zéro** perte de focus, identité du `QuillController` stable ; `debugDocChangeCount` inchangé sur simple déplacement de curseur.*

6. **Factory d'enregistrement + a11y/thème/isolation (AD-4, AD-13, FR-26, AD-1).**
   - **Factory publique** `registerZMarkdownFields(ZWidgetRegistry registry, {ZCodec? codec, …})` enregistrant les kinds `markdown` (block), `inlineMarkdown` (inline) et `richText` (block, alias) sur le **même** adaptateur `ctx`-natif paramétré par le mode ; **aucun** singleton statique mutable ; exportée au barrel `zcrud_markdown.dart`. Collision de kind ⇒ `throw` (contrat `ZWidgetRegistry.register`).
   - **a11y (AD-13)** : boutons toggle/édition et actions du dialog exposent `SemanticsAction.tap` **opérable** ET mesurent **≥ 48 dp** ; `Semantics` explicites ; directionnel ; le reader lecture seule reste **lisible** au lecteur d'écran mais **sans** action d'édition.
   - **thème (FR-26)** : **aucun** `Colors.`/`Color(0x…)`/style codé en dur ; tout via `ZcrudTheme.of` (repli `Theme.of`).
   - **isolation (AD-1/AD-7)** : `pubspec.yaml` **n'ajoute aucune** dépendance (réutiliser `flutter_quill`/`flutter_math_fork` déjà présents ; **PAS** de `flutter_markdown_plus`/`html_editor_enhanced`) ; **aucun** type Quill/math dans la surface publique (gates d'isolation verts) ; **aucune** modification de `zcrud_core` (`git diff --name-only` confiné à `packages/zcrud_markdown/**`).
   *Test : garde grep exhaustif (denylist `Colors.`, `Color(0x`, `EdgeInsets.only(left`, `EdgeInsets.only(right`, `Alignment.centerLeft`, `Alignment.centerRight`, `Positioned(left`, `Positioned(right`, `TextAlign.left`, `TextAlign.right`, imports `flutter_riverpod`/`package:get/`/`package:provider/`), **cwd-robuste** + **strip-comment**, = 0 sur `lib/` ; `assertSemanticActionTap` + `assertMinTapTarget(…, 48)` sur chaque cible interactive ; gates d'isolation de signature verts.*

7. **Vérif verte + non-régression du package.** `dart run melos run generate` OK (le package n'a pas d'annotations codegen — no-op attendu, ne DOIT pas casser) ; `flutter analyze packages/zcrud_markdown` RC=0 ; `flutter test packages/zcrud_markdown` RC=0, **total ≥ baseline existante + nouveaux tests** (readonly, inline/block, dialog Valider/Annuler, SM-1 ctx, a11y, garde thème). *Gate : RC=0 aux trois étapes ; aucun test E6 existant affaibli ; `git diff --name-only` ne touche pas `packages/zcrud_core/`.*

## Tasks / Subtasks

- [x] **T1. Factorisation du cœur neutre/défensif partagé** (AC4, AC5) — *pré-requis, zéro régression*
  - [x] Isolé dans `z_rich_text_core.dart` : `buildZToolbarConfig`, `insertZLatex`/`insertZTable` (+ détection embed sous caret), `kZEmbedBuilders`, `kZMinTapTarget` — partagés par la voie `controller`, la voie `ctx` inline et le dialog, **sans dupliquer le chemin chaud**. `DeltaNeutralOps`/résolution codec réutilisés tels quels.
  - [x] Voie publique `ZMarkdownField({controller,…})` **inchangée** (signature + comportement) : les 155 tests E6 passent sans modification.
- [x] **T2. Reader lecture seule** (AC1) — `z_markdown_reader.dart`
  - [x] `ZMarkdownReader` : `QuillController(readOnly: true)` + `QuillEditor` (showCursor:false), **sans** toolbar, mêmes `kZEmbedBuilders`, hauteur intrinsèque, placeholder « Aucun contenu » (AD-10), thémé `ZcrudTheme`, `Semantics(readOnly:true)`.
  - [x] **Aucun** abonnement `document.changes`, **aucun** `setValue`/`onChanged` en lecture seule.
- [x] **T3. Adaptateur `ctx`-natif + mode inline/block** (AC2, AC3, AC5)
  - [x] `enum ZMarkdownFieldMode { inline, block }` public (barrel).
  - [x] `ZMarkdownField.fromContext({ctx, mode, codec, onInit, onBuild, key})` : `QuillController` isolé stable alimenté par `ctx.value` (seed + sync guardée hors focus), écriture via `ctx.onChanged` (sens unique). `field.readOnly` ⇒ délègue au reader (court-circuite l'édition). Voie `controller` et voie `ctx` partagent le même `State`.
  - [x] **Mode `inline`** : éditeur compact (toolbar minimale via `buildZToolbarConfig(minimal:true)`) + bouton toggle plein-écran.
  - [x] **Mode `block`** : aperçu reader + bouton « Rédiger »/« Modifier » (selon contenu vide/non-vide) ouvrant le dialog. Pas d'édition en place, pas de `QuillController` d'édition.
- [x] **T4. `ZRichTextFullscreenDialog`** (AC3) — `z_rich_text_fullscreen_dialog.dart`
  - [x] Dialog **80 %×70 %** (`MediaQuery`, directionnel) + repli `Dialog.fullscreen`/`Scaffold` sous 600 dp ; toolbar **complète** + embeds ; titre = `field.label ?? field.name` ; actions **Valider/Annuler** (≥ 48 dp, `Semantics`).
  - [x] `Future<Object?> showZRichTextFullscreenDialog(BuildContext, {required Object? initialValue, String? title, ZCodec? codec})` → valeur **neutre** (Valider) / `null` (Annuler) — **aucun** type Quill dans la signature.
  - [x] Câblage : `_openFullscreen` → `_write(result)` + `_forceApplyNeutral` ré-hydrate l'éditeur en place (inline).
- [x] **T5. Factory d'enregistrement** (AC6) — `z_markdown_registration.dart`
  - [x] `registerZMarkdownFields(ZWidgetRegistry, {ZCodec? codec})` : `markdown`→block, `inlineMarkdown`→inline, `richText`→block ; `ValueKey(field.name)` (place stable) ; export barrel.
- [x] **T6. Tests widget + gardes** (AC1-AC7)
  - [x] Helpers a11y copiés verbatim depuis `zcrud_flashcard` → `test/support/a11y_asserts.dart`.
  - [x] `z_markdown_richtext_modes_test.dart` (19 tests) : lecture seule (0 toolbar/0 bouton, contenu lisible, `onChanged` jamais appelé, corrompu→vide) ; inline vs block ; dialog Valider/Annuler + présentation large/étroit ; SM-1 via `ctx` (init==1, voisin non reconstruit, focus, identité controller, MED-1) ; a11y ≥48dp + action sémantique ; factory kinds + collision ; RTL. Garde grep thème/directionnel vérifiée sur disque.
- [x] **T7. Vérif verte** (AC7) — `flutter analyze packages/zcrud_markdown` RC=0 ; `flutter test packages/zcrud_markdown` RC=0 (174 tests) ; `graph_proof.py` CORE OUT=0 ; diff confiné à `packages/zcrud_markdown/**`.

## Dev Notes

### Ce qui NE nécessite PAS de changement cœur (confirmé sur disque)

- **`field.readOnly`** est déjà transporté par `ZFieldSpec` (défaut `false`) et propagé par le **mode lecture global** d'E3-4 (`copyWith(readOnly:true)`). Le builder lit `ctx.field.readOnly` — rien à ajouter au cœur.
- **Le routage des kinds** `markdown`/`inlineMarkdown`/`richText` vers le registre existe déjà (`edition_field_family.dart:183-195`, `z_field_widget.dart:432-450`). La factory du package n'a qu'à **enregistrer** ses builders sous ces `kind`.
- **Le contrat `ZFieldWidgetContext` (field/value/onChanged, sans controller) est SUFFISANT** pour un champ rich-text isolé AD-2 : le `State` persiste (place stable), le `QuillController` reste stable, `value` sert de source de sync guardée hors focus, `onChanged` de voie d'écriture sens unique. **C'est la raison pour laquelle aucun changement cœur n'est requis.**

### Besoin cœur détecté ? → NON (avec garde)

Analyse : aucun besoin `zcrud_core` réel. Le seul point sensible (le builder ne reçoit pas le `ZFormController`) est **résolu dans `zcrud_markdown`** par l'adaptateur `ctx`-natif. **Garde-fou dev-story** : si, en implémentant, l'adaptateur `ctx` s'avère **incapable** de tenir SM-1/AD-2 sans accéder au controller (ex. besoin d'un canal `reseedRevision`/`reveal` non dérivable de `ctx.value`), **STOP** et signaler à l'orchestrateur (re-séquencer un mini-ajout cœur **isolé**) — **ne pas** modifier `zcrud_core` de façon opportuniste.

### Points d'attention flutter_quill 11.x (lecture seule)

- Vérifier l'API readOnly effective de la version résolue (`flutter_quill ^11.5.0`) : selon la mineure, le readOnly se pose via `QuillController(readOnly: …)` **ou** `QuillEditorConfig`/`QuillController.readOnly` (setter). **Lire le code du package sur disque** (`.dart_tool`/pub cache) avant de coder — ne pas deviner. Le reader ne doit **jamais** monter de `QuillSimpleToolbar`.
- Le reader réutilise `_kEmbedBuilders` (LaTeX/tableau) pour rendre les embeds **en lecture** — même liste `const` que l'éditeur (zéro alloc, isolation AC de signature préservée : liste définie hors surface publique).

### Testing standards

- **flutter_test** (widget tests), pattern maison du package : hooks `onInit`/`onBuild` + `ZMarkdownFieldDebug` (`@visibleForTesting`) pour prouver non-recréation du controller (SM-1) et retrait d'abonnement (anti-fuite). Réutiliser les fixtures existantes (`test/fixtures/`).
- **Helpers a11y** : `assertSemanticActionTap` / `assertMinTapTarget(…, 48)` (copie locale par package, AI-E10-1).
- **Garde thème/directionnel** : grep denylist cwd-robuste + strip-comment (AI-E10-2) sur `packages/zcrud_markdown/lib/`.
- **Gates d'isolation** existants (`quill_signature_isolation_test.dart`, `*_isolation_graph_test.dart`) : doivent rester verts (le dialog/reader/adaptateur n'exposent aucun type Quill/math/conversion).

### Project Structure Notes

- Tout le neuf sous `packages/zcrud_markdown/lib/src/presentation/` (+ `data/` si factorisation neutre partagée) : ex. `z_rich_text_fullscreen_dialog.dart`, `z_markdown_reader.dart` (ou reader interne à `z_markdown_field.dart`), enrichissement de `z_markdown_field.dart` (adaptateur `ctx` + mode + readOnly), `z_markdown_registration.dart` (factory). Exports ajoutés au barrel `zcrud_markdown.dart`.
- **Aucun** fichier hors `packages/zcrud_markdown/**`. **Aucune** dépendance ajoutée au `pubspec.yaml`.

### References

- [Source: docs/dodlp-edition-parity-gap.md#2.1 Éditeur Markdown / Rich-text] — B4 (lecture seule), B6 (markdown vs inlineMarkdown + dialog), major « dialog/bottom-sheet plein-écran ».
- [Source: docs/dodlp-edition-parity-gap.md#3 BLOCKING] — B4, B6 (actions proposées : lire `field.readOnly`, reader léger, `mode {inline,block}`, `ZRichTextFullscreenDialog`, `registerMarkdownFields`).
- [Source: epics.md#E-DP] — DP-3 « `ZMarkdownField` honore `readOnly` (reader léger) + distinction `markdown` (bloc, dialog plein-écran) vs `inlineMarkdown` (compact) + toggle. [B4+B6, zcrud_markdown] ».
- [Source: architecture.md#AD-2,#AD-7,#AD-1,#AD-10,#AD-13,#AD-4] ; [Source: prd.md#FR-26].
- [Ref DODLP: dodlp-otr/.../editors/markdown_edition_field.dart:31-47,65,229-247,311-385,416-448] (isInline/readOnly, block edit button, inline compact + fullscreen toggle, reader preview).
- [Ref DODLP: dodlp-otr/.../views/rich_text_editor_screen.dart:38,323-451,527-606] (dialog 80%×70% / Scaffold fullscreen, RichTextReaderScreen).
- [Ref DODLP: dodlp-otr/.../editor_config.dart:18-72] (RichTextToolbarConfig full/minimal/markdown — inspire toolbar complète (dialog) vs minimale (inline)).
- [Existant zcrud: packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart] (contrat E6-1..E6-4 à préserver).
- [Existant zcrud: packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart ; z_field_widget.dart:432-450 ; edition_field_family.dart:183-195] (contrat registre ctx-only).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, effort high).

### Debug Log References

- `flutter_quill 11.5.1` : readOnly posé via `QuillController(readOnly: true)` (constructeur) — vérifié dans le pub cache (`quill_controller.dart:38`).
- Quill rend via un `RenderEditor` maison (ni `Text` ni `EditableText`) : les tests pilotent le contenu par le `QuillController` public (`replaceText`/`document.toPlainText`), comme les tests E6 existants.
- AD-10 défensif : la valeur corrompue (`not-a-delta`) journalise un `debugPrint` non-fatal (dans un `assert`) et rend un document vide — comportement attendu, aucun throw.

### Completion Notes List

- **Aucun besoin cœur détecté.** `ZFieldWidgetContext` (field/value/onChanged) suffit : le `State` de `ZMarkdownField.fromContext` persiste (place stable `ValueKey(field.name)`), le `QuillController` reste stable, `ctx.value` alimente la sync guardée hors focus, `ctx.onChanged` la voie d'écriture. **Aucune** modification de `zcrud_core`. Le canal `reseedRevision`/`reveal` évoqué par le garde-fou n'a **pas** été nécessaire.
- **Rétro-compat E6 STRICTE** : la voie `controller` conserve exactement le même chemin (toolbar full via `buildZToolbarConfig(minimal:false)` == config d'origine ; `showToolbar` honoré ; sync guardée ; normalisation MED-1). 155 tests E6 verts sans modification de leurs attentes.
- **Isolation AD-1/AD-7** : le barrel n'exporte que des symboles neutres (`ZMarkdownField`, `ZMarkdownFieldMode`, `ZMarkdownFieldDebug`, `ZMarkdownReader`, `registerZMarkdownFields`, `showZRichTextFullscreenDialog`, `ZRichTextFullscreenDialog`) ; aucun type Quill dans les signatures publiques (entrées/sorties = `Object?` Delta JSON + `ZCodec`). Gates d'isolation existants verts.
- **AC statut** : AC1 ✅, AC2 ✅, AC3 ✅, AC4 ✅ (E6 intact), AC5 ✅ (SM-1 ctx : init==1, voisin non reconstruit, focus, identité controller, MED-1), AC6 ✅ (factory + collision + a11y ≥48dp + thème + isolation), AC7 ✅ (analyze RC=0, 174 tests, graph CORE OUT=0, diff confiné).
- **Vérif verte rejouée** : `dart analyze packages/zcrud_markdown` → No issues. `flutter test packages/zcrud_markdown` → All tests passed (174, dont 19 neufs). `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK. `dart analyze` sur dépendants `zcrud_mindmap`/`zcrud_flashcard` → No issues (barrel `show` n'a rien retiré).

### File List

**Nouveaux (`packages/zcrud_markdown/`)**
- `lib/src/presentation/z_rich_text_core.dart` — noyau interne partagé (toolbar config, insertion embeds LaTeX/tableau, `kZEmbedBuilders`, `kZMinTapTarget`).
- `lib/src/presentation/z_markdown_reader.dart` — `ZMarkdownReader` (lecteur readOnly).
- `lib/src/presentation/z_rich_text_fullscreen_dialog.dart` — `ZRichTextFullscreenDialog` + `showZRichTextFullscreenDialog`.
- `lib/src/presentation/z_markdown_registration.dart` — `registerZMarkdownFields`.
- `test/z_markdown_richtext_modes_test.dart` — 19 tests DP-3.
- `test/support/a11y_asserts.dart` — helpers a11y (copie verbatim).

**Modifiés (`packages/zcrud_markdown/`)**
- `lib/src/presentation/z_markdown_field.dart` — `ZMarkdownFieldMode`, `ZMarkdownField.fromContext`, honneur `readOnly` (reader), modes inline/block, factorisation embeds vers le core.
- `lib/zcrud_markdown.dart` — exports DP-3 (barrel, `show` neutres).
