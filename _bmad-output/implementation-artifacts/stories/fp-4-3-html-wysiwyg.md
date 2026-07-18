<!-- Story enrichie fp-4-3 — générée par bmad-create-story (mode non-interactif). -->
<!-- Épic 4 (Média-rich) · satellite zcrud_html · AD-50/AD-7. Validation optionnelle avant dev-story. -->

# Story fp-4.3: HTML WYSIWYG complet (`zcrud_html`) — WebView isolée + rendu `flutter_html`

Status: review

## Story

As a **utilisateur DODLP**,
I want **éditer du HTML en WYSIWYG (WebView isolée), le lire en rendu natif, avec exclusivité md/html au bootstrap, câblé et démontré**,
so that **j'atteins la parité rich-text HTML de DODLP sans casser SM-1 ni créer deux propriétaires du `kind` `html`.**

Marquage : `[Média-rich]` · **parallélisable** (satellite `zcrud_html`, fichiers disjoints) · Binds **FR-22, FR-23** ; **AD-50, AD-7**, NFR-1/2 ; contribue FR-39 (axe 4), FR-40 ; **AR-5**.

---

## Contexte & périmètre (LIRE AVANT DE CODER)

`zcrud_html` a été livré en **squelette** par fp-1-2 (barrel + hexagone `lib/src/{domain,data,presentation}` + garde de confinement `test/z_html_confinement_test.dart` + placeholder `kZcrudHtmlPlaceholder`). **Cette story remplit l'adaptateur réel.** C'est **LE point le plus risqué de l'épic** : la WebView `html_editor_enhanced` est une **2ᵉ voie d'état** qui, mal isolée, casse SM-1/AD-2.

**DISJONCTION STRICTE (parallélisation ≤ 3 stories) :** fp-4-3 écrit **UNIQUEMENT** dans `packages/zcrud_html/`.
- 🚫 **NE TOUCHE PAS** `zcrud_core`, `zcrud_markdown`, ni aucun autre satellite/binding, ni `example/` (showcase/harnais).
- ✅ Tous les contrats du cœur nécessaires **existent déjà** (aucune écriture cœur requise) : `ZWidgetRegistry` (`register`/`kinds` + `throw` sur collision), `ZFieldWidgetContext` (`field`/`value`/`onChanged`), `ZDuplicateRegistrationError`, `ZcrudScope.widgetRegistry`. **Si un manque du cœur apparaît → SIGNALER, ne pas l'écrire ici.**

**⚠️ Fait CAPITAL vérifié sur disque :** `zcrud_markdown` **enregistre DÉJÀ** `html`/`inlineHtml` via `registerZHtmlFields` (HTML↔Delta au-dessus de l'éditeur Quill, `packages/zcrud_markdown/lib/src/presentation/z_html_registration.dart`). fp-4-3 fournit la **2ᵉ voie concurrente** (WYSIWYG WebView, format HTML natif). Les deux sont **mutuellement exclusives** (AR-5/AD-50) : l'app choisit **une seule** voie au bootstrap ; la collision est **détectée par le contrat cœur** `ZWidgetRegistry.register` (`throw ZDuplicateRegistrationError`), **jamais** par une dépendance de `zcrud_html` vers `zcrud_markdown` (interdite AD-1).

---

## Acceptance Criteria

### AC1 — Deps lourdes confinées + allowlist de confinement mise à jour **falsifiablement** (AD-1, NFR-2)
**Given** `zcrud_html` recevant ses dépendances d'impl
**When** on ajoute `html_editor_enhanced: ^2.7.1` (édition WYSIWYG) et `flutter_html: ^3.0.0` (lecture) au `pubspec.yaml`
**Then** ce sont les **seules** deps tierces (au-delà de `flutter` + `zcrud_core`) ; **CORE OUT=0** reste vrai (`graph_proof.py` : les tierces non-`zcrud_*` n'ajoutent aucune arête inter-package) ; et la garde `test/z_html_confinement_test.dart` est **mise à jour de façon falsifiable** :
- `_allowedDeps` = `{flutter, zcrud_core, html_editor_enhanced, flutter_html}` ;
- `_allowedImportPkgs` = `{flutter, zcrud_core, zcrud_html, html_editor_enhanced, flutter_html}` ;
- le témoin `_probeIntruder` (aujourd'hui `'html_editor_enhanced'`, qui **devient autorisé**) est **remplacé** par un intrus **encore interdit** (ex. `'get'`) pour que le test **R12** (« la règle SAIT détecter une dép/import interdit ») **morde toujours** (contre-preuve mutante RC verte).

### AC2 — Enrôlement `registerZHtmlFields` : exactement `{html, inlineHtml}`, aucune fuite de type tiers (AD-55, AD-40)
**Given** `zcrud_html` exposant `registerZHtmlFields(ZWidgetRegistry registry, {…})` dans son barrel
**When** l'app l'appelle
**Then** il enregistre **exactement** les `kind` `html` **et** `inlineHtml` (`registry.kinds` = `{html, inlineHtml}`) ; **aucun type `html_editor_enhanced`/`flutter_html` n'apparaît en signature publique** (barrel + typedef) ; le widget réel est fourni par CE satellite (cœur agnostique). *Test porteur : `registry.kinds` après enrôlement + grep négatif d'un type tiers dans le barrel.*

### AC3 — Controller isolé créé **une seule fois** (AD-7/AD-50)
**Given** l'adaptateur d'édition monté sur `kind` `html`/`inlineHtml`
**When** son `State` s'initialise
**Then** il possède le `HtmlEditorController`/WebView **créé une seule fois** en `initState` (`late final`, **jamais recréé** au rebuild de tranche), avec `key: ValueKey('z-html-<field.name>')` (place stable AD-2, patron `z_html_registration.dart` de `zcrud_markdown`) ; il lit `ctx.value` (HTML `String`) comme **contenu initial** injecté au controller. *Le `State` WebView n'est pas montable en VM `flutter_test` (cf. ET-5) : la stabilité est prouvée par conception (`late final` + `ValueKey`) et par le test unitaire de la mécanique de commit extraite (AC4).*

### AC4 — SM-1 : commit **débouncé hors-frappe**, re-synchro **hors focus** seulement (NFR-1, AD-2)
**Given** l'utilisateur qui tape 100 caractères dans le WYSIWYG
**When** les champs voisins se reconstruisent
**Then** le `State` de la WebView **survit** aux rebuilds voisins (le champ n'écoute que sa tranche) ; `ctx.onChanged` n'est poussé **qu'au `onChange`/blur DÉBOUNCÉ** (jamais synchrone à chaque frappe) ; la re-synchro **depuis `ctx.value` ne se fait que hors focus** (garde de reconciliation) ; **SM-1 tenu**. *Test porteur FALSIFIABLE : la mécanique de commit est extraite en une classe pure injectable (horloge/callback injectés) — N entrées rapides ⇒ **≤ 1** commit poussé dans la fenêtre ; la 1ʳᵉ frappe **n'est pas** poussée de façon synchrone ; une valeur entrante `ctx.value` **en focus** n'écrase pas la saisie. Un mutant (push synchrone / re-sync en focus) fait **rougir** le test.*

### AC5 — Lecture `flutter_html`, format persisté = HTML `String`, défensif AD-10 (FR-23, AD-10)
**Given** du HTML arbitraire en lecture (ou un champ `readOnly`)
**When** il est rendu via `flutter_html` dans `zcrud_html`
**Then** le **format persisté est HTML `String`** (le WYSIWYG **ne force pas** de Delta — c'est sa raison d'être vs la voie markdown) ; un **HTML corrompu/vide en entrée rend un rendu vide, jamais un `throw`** (AD-10) — côté édition, un contenu initial corrompu ⇒ **éditeur vide** ; les **pertes de round-trip** (code inline, CSS/`<div>` exotiques, structures Summernote) sont **documentées et bornées** (table dans le code). *Test porteur : montage widget de `ZHtmlView` (pur Flutter, testable en VM) avec HTML corrompu/vide ⇒ aucun `throw`, rendu présent.*

### AC6 — Exclusivité `md`/`html` prouvée **sans dépendre de `zcrud_markdown`** (AR-5, AD-50, AD-1)
**Given** `zcrud_html` et `zcrud_markdown` visant les mêmes `kind` `html`/`inlineHtml`
**When** les deux voies sont enrôlées sur le **même** `ZWidgetRegistry`
**Then** la **seconde** registration **`throw ZDuplicateRegistrationError`** (mutuellement exclusif) ; l'app choisit **une seule** voie au bootstrap. *Preuve FALSIFIABLE sans arête interdite vers `zcrud_markdown` (AD-1) : (a) pré-enregistrer un builder factice sur `'html'` PUIS `registerZHtmlFields` ⇒ `throw` ; (b) `registerZHtmlFields` appelé **deux fois** sur le même registre ⇒ `throw` à la 2ᵉ. La collision réelle avec `zcrud_markdown` est le **même contrat cœur** — vérifié ici contre n'importe quel propriétaire concurrent du `kind`.* La couverture de l'**axe 4 du harnais** et l'entrée **showcase** relèvent de la composition binding (AR-4/AR-5) et de la consolidation **fp-3-2** — **hors périmètre fp-4-3** (cf. ET-3).

---

## Tasks / Subtasks

- [x] **T1 — pubspec + confinement falsifiable** (AC1)
  - [x] Ajouter `html_editor_enhanced: ^2.7.1` et `flutter_html: ^3.0.0` à `dependencies:` (mettre à jour l'en-tête de commentaire du pubspec : les deps lourdes arrivent **ici**, confinées à `lib/src/`).
  - [x] Mettre à jour `test/z_html_confinement_test.dart` : `_allowedDeps` + `_allowedImportPkgs` (ajout des 2 paquets), **remplacer `_probeIntruder`** par un intrus encore interdit (`'get'`) et ajuster le témoin R12 en conséquence (contre-preuve mutante toujours verte).
  - [x] Rejouer `graph_proof.py` (CORE OUT=0 inchangé) + `flutter test` du fichier de confinement.
- [x] **T2 — enrôlement `registerZHtmlFields`** (AC2, AC6)
  - [x] `lib/src/presentation/z_html_wysiwyg_registration.dart` : `void registerZHtmlFields(ZWidgetRegistry registry)` enregistrant `'inlineHtml'` (inline) et `'html'` (block) ; builder ⇒ `ValueKey('z-html-<field.name>')`.
  - [x] Exporter depuis le barrel `lib/zcrud_html.dart` ; placeholder retiré (fichier + export supprimés), barrel propre (aucun type tiers exposé).
- [x] **T3 — adaptateur d'édition WYSIWYG isolé** (AC3, AC4)
  - [x] `lib/src/presentation/z_html_editor_field.dart` : `StatefulWidget` ; `late final HtmlEditorController _controller` créé **une seule fois** en `initState` ; `initialText` défensif AD-10 (vide si non-`String`/corrompu) ; callbacks `onChangeContent`/`onFocus`/`onBlur`.
  - [x] `lib/src/domain/z_html_commit_debouncer.dart` (**pur Dart, injectable** — `ZDebounceScheduler`) : « débounce + garde focus », commit **hors-frappe** jamais synchrone ; re-sync entrante ignorée en focus. Unité falsifiable de SM-1.
  - [x] Câbler `onChangeContent`→debouncer→`ctx.onChanged` ; `onBlur`→flush ; `didUpdateWidget` ⇒ `setText` **seulement hors focus** (garde du débouncer).
- [x] **T4 — lecture `flutter_html` + pertes documentées** (AC5)
  - [x] `lib/src/presentation/z_html_view.dart` : `ZHtmlView` (widget pur) enveloppant `Html(data:)` ; défensif (HTML corrompu/`null`/vide ⇒ rendu vide, aucun `throw`) ; couleur `Theme.of(context)` (FR-26), `Semantics` de conteneur (AD-13).
  - [x] Le builder d'enrôlement route sur `ZHtmlView` quand `ctx.field.readOnly`, sinon `ZHtmlEditorField` (lecteur prioritaire).
  - [x] Table des **pertes de round-trip bornées** documentée en tête de `z_html_view.dart` (code inline, `<div>`/CSS exotiques, embeds Summernote, MathJax CDN hors périmètre).
- [x] **T5 — tests porteurs + doc** (AC2..AC6, R3)
  - [x] `test/z_html_registration_test.dart` : `registry.kinds == {html, inlineHtml}` (égalité d'ensemble, R3) ; exclusivité (pré-registration factice ⇒ `throw` ; double appel ⇒ `throw`).
  - [x] `test/z_html_commit_debouncer_test.dart` : N frappes ⇒ ≤ 1 commit ; pas de push synchrone ; garde focus ; **mutants** (push synchrone / re-sync en focus) ⇒ rouges.
  - [x] `test/z_html_view_test.dart` : montage `ZHtmlView` (HTML valide / vide / `null` / corrompu) ⇒ aucun `throw`, rendu présent ; grep négatif des directives tierces dans le barrel (AD-40).
  - [x] Mettre à jour `README.md`/`CHANGELOG.md` du satellite (voie WYSIWYG livrée, exclusivité, limites a11y WebView).

---

## Dev Notes

### Patron de référence (à IMITER sur disque, ne pas réinventer)
- **Enrôlement + `ValueKey` + lecteur-prioritaire** : `packages/zcrud_markdown/lib/src/presentation/z_html_registration.dart` (structure `registerZHtmlFields`, `register('inlineHtml'|'html', …)`, `ValueKey('z-html-<name>')`, `field.readOnly` honoré). **Copier la FORME, PAS la dépendance** — `zcrud_html` ne dépend **jamais** de `zcrud_markdown`.
- **Controller isolé créé une fois** : `packages/zcrud_markdown/lib/src/presentation/z_rich_text_fullscreen_dialog.dart` (`late final QuillController _quill;` en `initState`, jamais recréé — la WebView est à HTML ce que Quill est au Delta, AD-50).
- **Garde de confinement falsifiable + R12 mutant** : le fichier `test/z_html_confinement_test.dart` existant (fp-1-2) est déjà au patron `zcrud_export_ui` — se contenter de **muter l'allowlist + le probe**, ne pas réécrire la mécanique.
- **Contrat registre** : `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart` (`register` **throw** `ZDuplicateRegistrationError` sur collision ; `kinds` ; `ZFieldWidgetContext.{field,value,onChanged}`).

### AD-50 — comment l'isolation WYSIWYG est rendue FALSIFIABLE (le point dur)
1. **Controller unique** — `late final HtmlEditorController` en `initState` + `key: ValueKey('z-html-<field.name>')` (place stable AD-2). Recréation impossible par construction ; `late final` réassigné ⇒ erreur runtime (garde du langage).
2. **Commit débouncé hors-frappe** — toute la logique temporelle vit dans `ZHtmlCommitDebouncer` (**pur Dart, sans WebView**), testable au caractère près : la fenêtre de débounce + la garde de focus sont des assertions, pas de la prose. Mutant « push synchrone » ⇒ test rouge.
3. **Re-sync hors focus** — `ctx.value` entrant n'est réinjecté (`setText`) **que** si le champ n'a pas le focus (drapeau piloté par `onFocus`/`onBlur`) ⇒ jamais d'écrasement de sélection (AD-2). Testé dans le debouncer.
4. **SM-1** — le champ n'écoute que sa tranche (dispatcher cœur, inchangé) ; le `State` WebView survit aux rebuilds voisins (place stable). Pas de `setState` d'écran, pas de controller recréé.

### Format persisté & round-trip (AD-50, FR-23)
- **Format = HTML `String`** (pas de Delta forcé) : c'est la raison d'être de la voie WYSIWYG vs la voie Delta de `zcrud_markdown`. `ctx.value` **est** la `String` HTML ; `ctx.onChanged(htmlString)`.
- **Pertes bornées documentées** (table en tête de fichier) : code inline, `<div>`/classes/CSS inline exotiques, embeds Summernote/MathJax (le LaTeX WebView DODLP s'appuie sur un **CDN MathJax** — hors périmètre offline zcrud, à documenter comme limite, ne PAS réintroduire de CDN runtime).
- **AD-10 défensif** : lecture (`flutter_html`) et édition (`initialText`) sur HTML corrompu/`null`/non-`String` ⇒ rendu/éditeur **vide**, **jamais** `throw`.

### Exclusivité `md`/`html` (AR-5) — pourquoi le test ne dépend PAS de markdown
`ZWidgetRegistry.register` throw sur collision de `kind` : c'est **le** garde-fou. `zcrud_html` ne peut pas importer `zcrud_markdown` (AD-1 acyclique, allowlist de confinement). La preuve d'exclusivité se fait donc **contre le contrat cœur** : un builder factice pré-enregistré sur `'html'` (proxy de la voie markdown) ⇒ `registerZHtmlFields` **throw**. La collision réelle markdown↔html est le **même** contrat — l'app choisit une voie au bootstrap (AR-4, binding).

### Écarts tranchés (mode non-interactif → option CONSERVATRICE, consignée)
- **ET-1 — Paquet concret = `html_editor_enhanced: ^2.7.1`** (pas le fork `html_editor_plus`). Rationale : version du tableau des versions du spine (`^2.7.1`), parité DODLP directe (`html_editor_wrapper.dart` amont), ligne #32 de la FIELD-PACKAGE-MATRIX. Le paquet est **abstrait par l'adaptateur** (aucun type en signature publique) ⇒ substituable plus tard sans casser le barrel. Le task-brief autorise « `html_editor_enhanced`/`_plus` » → **tranché : enhanced**.
- **ET-2 — Nom de la fonction d'enrôlement = `registerZHtmlFields`** (convention AD-55 `registerZ<Pkg>Fields`, pkg=html). **Identique** au nom de la fonction homonyme de `zcrud_markdown` : c'est **voulu** — ce sont les **deux voies mutuellement exclusives** ; une app **importe exactement UN** des deux paquets (jamais les deux barrels ⇒ pas d'ambiguïté d'import Dart). Le garde-fou runtime reste le `throw` du registre.
- **ET-3 — Harnais axe 4 / entrée showcase = HORS PÉRIMÈTRE fp-4-3.** Frontière : `example/` (showcase/harnais) n'est **pas** touché ici. La couverture axe 4 et le passage showcase « ABSENT → livré » relèvent de la **composition binding** (`zcrud_get`, AR-4/AR-5) et de la **consolidation fp-3-2** (fan-in final). fp-4-3 livre **satellite + enrôlement + tests** uniquement.
- **ET-4 — Preuve d'exclusivité contre le contrat cœur** (dummy pré-registration), pas contre `zcrud_markdown` (arête interdite AD-1). Cf. Dev Notes ci-dessus.
- **ET-5 — Le `State` WebView n'est pas montable en `flutter_test` (VM, pas de moteur WebView).** La mécanique SM-1 est donc **extraite** dans `ZHtmlCommitDebouncer` (pur Dart) — **falsifiable au caractère**. La lecture `ZHtmlView` (`flutter_html` = pur Flutter) **est** montable ⇒ testée. La stabilité du controller est prouvée par conception (`late final` + `ValueKey`) + documentée. **Ne pas** écrire un test tautologique qui « monte » la WebView sans moteur (il ne rougirait jamais).
- **ET-6 — Builder lecteur-prioritaire** : `ctx.field.readOnly` ⇒ `ZHtmlView` ; sinon `ZHtmlEditorField`. Miroir de l'adaptateur markdown.
- **ET-7 — a11y WebView (AD-13) = au mieux + limite documentée.** `html_editor_enhanced` embarque son propre DOM/Summernote : les `Semantics` fines sont hors de notre contrôle ⇒ **documenter la limite** (README) ; côté lecture, `ZHtmlView` reçoit `Semantics` + thème (`Theme.of`) — parité a11y raisonnable là où c'est possible.

### Invariants applicables (rappel, NON-NÉGOCIABLES)
- **AD-1** : graphe acyclique, **CORE OUT=0** ; `zcrud_html` ne dépend que de `zcrud_core` + `html_editor_enhanced` + `flutter_html`. **PAS** `zcrud_markdown`. `zcrud_core` **inchangé** (aucune écriture cœur).
- **AD-2 / SM-1 / NFR-1** : WebView isolée, controller créé une fois, commit débouncé hors-frappe, re-sync hors focus ; jamais de `setState` d'écran ni de `TextEditingController`/controller recréé.
- **AD-7** : rich-text à controller isolé (la WebView est le controller isolé, à HTML ce que Quill est au Delta).
- **AD-40 / NFR-2** : aucun type `html_editor_enhanced`/`flutter_html` en signature publique ; deps confinées à `lib/src/`, gardées par le confinement test.
- **AD-10 / NFR-5** : HTML corrompu ⇒ dégradé (vide), jamais `throw`.
- **FR-26 / NFR-4** : thème/couleurs dérivés de `Theme.of(context)` ; aucune couleur/libellé codé en dur.
- **AD-12** : zéro secret (aucune clé/CDN/endpoint committé — ne PAS réintroduire le CDN MathJax DODLP).
- **Distribution en dép. git** : squelette→impl, aucun codegen (pas de `*.g.dart` ⇒ `gate:codegen-distribution` no-op propre).

### Pièges de vérification (discipline de réalité)
- Toute **« absence »** (ex. « aucun type tiers dans le barrel », « `zcrud_markdown` non importé ») = **`grep -q` + RC=1** ou assertion de test, jamais une affirmation nue.
- `melos run test` **peut se bloquer** (Flutter) → lancer `flutter test` **par package** (`packages/zcrud_html`).
- `git checkout`/`git restore` **interdits** (destructif).
- **Ne pas** tester la WebView en VM (tautologie R3) ; cibler debouncer + registration + reader.
- Après ajout des deps : `dart pub get` (workspace) puis `graph_proof.py` (CORE OUT=0) + `flutter analyze` + `flutter test` du package = **verts** avant `review`.

### Project Structure Notes
- Arbre attendu : `lib/src/presentation/{z_html_wysiwyg_registration.dart, z_html_editor_field.dart, z_html_view.dart}` + `lib/src/domain/z_html_commit_debouncer.dart` ; barrel `lib/zcrud_html.dart` exporte `registerZHtmlFields` (+ `ZHtmlView` si utile en lecture directe).
- Le placeholder `kZcrudHtmlPlaceholder` peut être retiré une fois l'API réelle exportée (garder les fichiers `data.dart`/`domain.dart` documentés s'ils restent des marqueurs de couche, sinon peupler).
- Variance assumée : `html_editor_enhanced` porte ses transitives (WebView/JS) — non importées directement dans notre `lib/**` (le confinement volet 2 ne voit que les imports directs, licite).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story-4.3] (ACs source, Binds FR-22/23, AD-50, AR-5)
- [Source: …/epics.md#Epic-4] (satellites disjoints parallélisables, 4.4 seule écrit le cœur) · [#NFR-1] (SM-1/WebView isolée) · [#AR-5] (exclusivité md/html)
- [Source: …/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-50] (WYSIWYG isolé, controller unique, commit débouncé, format HTML, exclusivité throw, `html_editor_enhanced ^2.7.1`)
- [Source: …/ARCHITECTURE-SPINE.md#AD-7] (rich-text controller isolé, `ZCodec`) · [#AD-55] (binding = point de composition unique, `registerZ<Pkg>Fields`, throw sur double registration) · [#AD-1] (acyclique, CORE OUT=0) · [#AD-40] (pas de type tiers en signature) · [#Versions] (`html_editor_enhanced ^2.7.1`, `flutter_html ^3.0.0`)
- [Source: docs/dodlp-form-integration-study-2026-07-17/10-field-richtext-html-markdown.md#3] (usages DODLP réels `html_editor_wrapper.dart`/`Html(data:)` — LECTURE SEULE ; MathJax CDN à ne pas reproduire ; pertes round-trip bornées)
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md#lignes-32/32b/34] (html WYSIWYG + rendu → satellite `zcrud_html`, jamais `zcrud_markdown`)
- [Pattern: packages/zcrud_markdown/lib/src/presentation/z_html_registration.dart] (forme d'enrôlement + `ValueKey` + lecteur-prioritaire — copier la forme, pas la dep)
- [Pattern: packages/zcrud_markdown/lib/src/presentation/z_rich_text_fullscreen_dialog.dart] (`late final` controller en `initState`, jamais recréé)
- [Contrat: packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart] (`register` throw `ZDuplicateRegistrationError`, `kinds`, `ZFieldWidgetContext`)
- [Garde à muter: packages/zcrud_html/test/z_html_confinement_test.dart] (allowlist + `_probeIntruder` + R12 mutant)
- [Gates: scripts/dev/graph_proof.py (CORE OUT=0) ; pubspec.yaml bloc `melos:` (gate:secrets, gate:codegen-distribution, verify)]

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (dev-story, effort high)

### Debug Log References

- `dart pub get` (workspace) — OK (html_editor_enhanced 2.7.1 + flutter_html 3.0.0 résolus).
- `dart analyze packages/zcrud_html` — RC=0 (3 `info` `prefer_initializing_formals` non-fatals : impossibles à corriger proprement pour des params nommés privés — un formal init `this._x` en param nommé est interdit par le langage).
- `flutter test` (packages/zcrud_html) — **21/21 verts**.
- `python3 scripts/dev/graph_proof.py` — ACYCLIQUE OK, CORE OUT=0 OK ; seule arête `zcrud_html -> zcrud_core` (aucune vers `zcrud_markdown`).
- **Code-review fp-4-3 (findings appliqués)** : `dart analyze packages/zcrud_html` RC=0 ; `flutter test packages/zcrud_html` **26/26 verts** (21 initiaux + 3 debouncer MED-1/idempotence + 2 confinement volet 3 LOW-3) ; graph_proof inchangé (ACYCLIQUE, CORE OUT=0). Le test porteur MED-1 rougissait avant correctif (`Actual: []`), vert après. Cf. `code-review-fp-4-3.md`.

### Completion Notes List

- **AC1** : deps lourdes confinées à `lib/src/` ; garde `z_html_confinement_test.dart` mise à jour (allowlists élargies aux 2 paquets ; `_probeIntruder` déplacé sur `get`, encore interdit ⇒ R12 mord toujours). CORE OUT=0 inchangé.
- **AC2** : `registerZHtmlFields` enregistre EXACTEMENT `{html, inlineHtml}` (assertion d'égalité d'ensemble = sentinelle R3) ; aucun type tiers en signature (grep négatif des directives `import/export 'package:<tiers>'` dans le barrel).
- **AC3** : `late final HtmlEditorController` en `initState`, `key: ValueKey('z-html-<name>')` posée par l'enrôlement ; contenu initial = `ctx.value` coercé en `String` (AD-10).
- **AC4** : SM-1 falsifiable via `ZHtmlCommitDebouncer` (pur Dart, ordonnanceur injecté) : 100 frappes ⇒ 1 commit (le dernier) ; 1ʳᵉ frappe non poussée synchroniquement ; re-sync refusée en focus. Mutants « push synchrone » / « re-sync en focus » ⇒ rouges.
- **AC5** : `ZHtmlView` (`flutter_html`) monté en VM sur HTML valide/vide/`null`/corrompu ⇒ aucun `throw`. Format persisté = HTML `String`. Pertes de round-trip bornées documentées en tête de fichier.
- **AC6** : exclusivité prouvée contre le contrat cœur (`ZWidgetRegistry.register` throw) — dummy pré-registration sur `html`/`inlineHtml` ⇒ throw ; double appel ⇒ throw à la 2ᵉ. AUCUN import de `zcrud_markdown` (AD-1, gardé par graph_proof + confinement).
- **ET-5 respecté** : aucun test ne monte la WebView (tautologie interdite) ; cibles = debouncer + registration + reader (tous falsifiables). Placeholder `kZcrudHtmlPlaceholder` retiré.

### File List

- `packages/zcrud_html/pubspec.yaml` (M — deps html_editor_enhanced/flutter_html + en-tête)
- `packages/zcrud_html/lib/zcrud_html.dart` (M — barrel : exporte `registerZHtmlFields` + `ZHtmlView`)
- `packages/zcrud_html/lib/src/domain/z_html_commit_debouncer.dart` (A)
- `packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart` (A)
- `packages/zcrud_html/lib/src/presentation/z_html_editor_field.dart` (A)
- `packages/zcrud_html/lib/src/presentation/z_html_view.dart` (A)
- `packages/zcrud_html/lib/src/presentation/z_html_view_placeholder.dart` (D — placeholder retiré)
- `packages/zcrud_html/test/z_html_confinement_test.dart` (M — allowlists + probe `get`)
- `packages/zcrud_html/test/z_html_commit_debouncer_test.dart` (A)
- `packages/zcrud_html/test/z_html_registration_test.dart` (A)
- `packages/zcrud_html/test/z_html_view_test.dart` (A)
- `packages/zcrud_html/README.md` (M)
- `packages/zcrud_html/CHANGELOG.md` (M)

#### Code-review fp-4-3 — fichiers modifiés (MED-1 / MED-2 / LOW-3)

- `packages/zcrud_html/lib/src/domain/z_html_commit_debouncer.dart` (M — MED-1 : `dispose()` FLUSHE le `_pending` avant nettoyage ; prose dartdoc dispose alignée)
- `packages/zcrud_html/lib/src/presentation/z_html_editor_field.dart` (M — MED-1 commentaire `dispose` ; MED-2 prose « corrompu ⇒ vide » → « non-String/null ⇒ vide ; HTML malformé String ⇒ best-effort, jamais throw »)
- `packages/zcrud_html/lib/src/presentation/z_html_view.dart` (M — MED-2 prose invariant AD-10 + dartdoc `html`)
- `packages/zcrud_html/lib/src/presentation/z_html_wysiwyg_registration.dart` (M — MED-2 prose lecteur-prioritaire)
- `packages/zcrud_html/test/z_html_commit_debouncer_test.dart` (M — MED-1 : test porteur non-perte au dispose + test idempotence)
- `packages/zcrud_html/test/z_html_confinement_test.dart` (M — LOW-3 : volet 3 « barrel sans type tiers » AD-40 + R12)
