# Story ES-5.2 : `ZStudyToolsPage` — scoping réactif isolé, non-régression SM-1

Status: review

<!-- Epic ES-5 · Taille L · SÉQUENTIELLE vs ES-5.1 (done) · Package `zcrud_study` (présentation), sérialisé avec ES-5.3. Dépend d'ES-5.1 done ; BLOQUE ES-5.3. Workstream B — ISOLATION vs workstream A (ES-4 / scripts/ci / zcrud_flashcard). -->

## Story

As a **utilisateur (et développeur intégrateur IFFD, Zakarius)**,
I want **la page réelle `ZStudyToolsPage` qui ASSEMBLE les sections paramétriques d'ES-5.1 (`ZStudyToolsSectionSpec` + `ZSectionedStudyLayout`) en reproduisant l'apparence IFFD, où taper dans un champ ne reconstruit QUE le champ courant (zéro perte de focus), avec l'action d'ajout (`+`) réellement branchée et son icône/label INJECTÉS**,
so that **le bug historique de rafraîchissement global du formulaire (jank, perte de focus — objectif produit n°1 / SM-1 / NFR-S1) ne réapparaisse jamais dans la surface study-tools, et que la dette DW-ES51-1 (icône codée en dur + sémantique ambiguë du bouton + tokens de badge) soit soldée dans le même commit d'epic ES-5**.

---

## Contexte & problème (pourquoi cette story existe)

ES-5.1 a livré (done, golden 6/6) le **socle décomposable** : le descripteur `ZStudyToolsSectionSpec` (`id`/`title`/`itemCount`/`itemBuilder`/`emptyState`/`addAction?`) et l'échafaudage `ZSectionedStudyLayout` (une frontière de widget keyée `ValueKey('section:$id')` par section, `ListView.builder`, ordre d'entrée préservé). Le harnais golden PROUVE la décomposabilité (byte-diff m1/m2/m3 + comptage structurel N→N-1). **ES-5.1 a garanti la FRONTIÈRE de section ; ES-5.2 branche la réactivité par champ SUR cette frontière et livre la page réelle.**

Trois résidus explicitement DÉFÉRÉS d'ES-5.1 à ES-5.2 (à SOLDER ici) :

1. **SM-1 non prouvé** — ES-5.1 pose la frontière mais ne branche AUCUN champ éditable ; le rebuild ciblé (taper 100 caractères ⇒ seul le champ courant se reconstruit) reste à démontrer sur la page. C'est l'**objectif produit n°1**.
2. **DW-ES51-1** (code-review-es-5-1.md, MEDIUM-1 + LOW-1/2/3, REPORTÉS et JUSTIFIÉS) :
   - **MEDIUM-1** : `z_sectioned_study_layout.dart:121` `icon: const Icon(Icons.add)` — icône du bouton d'ajout **codée en dur** (viole FR-26 : aucun `IconData` codé en dur dans un package) ; `z_sectioned_study_layout.dart:110-113` `Semantics(button: true, label: spec.title)` — le lecteur d'écran annonce « Flashcards, bouton » sur le `+`, **ambigu** avec l'en-tête homonyme (n'indique pas l'action « ajouter »).
   - **LOW-1** : `z_sectioned_study_layout.dart:164` `BorderRadius.circular(10)` + paddings `8`/`2` en dur dans `_CountBadge` — incohérent avec les tokens de thème (`theme.radiusM`, `theme.gapS`) déjà utilisés ailleurs dans le même fichier.
   - **LOW-2** : `Semantics` redondants — `_CountBadge` (`:155`) enveloppe `Text('$count')` dans `Semantics(label:'$count')` (double annonce) ; le bouton d'ajout imbrique `Semantics(button:true)` autour d'un `IconButton` qui porte déjà sa sémantique.
   - **LOW-3** : documentaire — `fusedSections()` (`study_tools_page_golden_test.dart:80`) retire la section notes au lieu de fusionner (libellé imprécis). Correction purement documentaire, sans impact.
3. **Écarts d'apparence résiduels** (Dev Agent Record ES-5.1 §« Écarts résiduels ») : **rail horizontal** (flashcards) vs **grilles verticales** non différenciés en ES-5.1 (toutes sections empilées uniformément). ES-5.2 introduit l'orientation de section injectable (`axis`) — rail horizontal pour flashcards. La **réordonnabilité / drag** (`ReorderableGridView`, `ZFolderContentsOrder`) reste **HORS PÉRIMÈTRE → ES-5.3**.

**Cause racine historique** (reconnaissance READ-ONLY `~/DEV/iffd`, AUCUN fichier IFFD modifié) : le monolithe `folder_study_tools_page.dart` (**1753 l.**, `build` unique 350→~1739) inline les 4 sections dans un seul arbre ; l'édition inline (ex. `multi_flashcard_editor_page.dart`, **`setState` ×18**) reconstruit tout à chaque frappe → perte de focus/jank. `ZStudyToolsPage` corrige **par conception** : contrôleur stable + `ValueListenable` par champ, **jamais** de `setState` à l'échelle page/section.

---

## Périmètre & NON-périmètre (garde-fous)

**DANS le périmètre ES-5.2** :
1. `packages/zcrud_study/lib/src/presentation/z_study_tools_page.dart` — la page réelle `ZStudyToolsPage` : détient un **`ZFormController` STABLE** (create/dispose, jamais recréé au rebuild), COMPOSE `ZSectionedStudyLayout` (ne le duplique PAS), rend un **état vide GLOBAL injecté** quand toutes les sections sont vides, **jamais** de `setState` pour une valeur de champ, **jamais** de `ListenableBuilder` global enveloppant les sections.
2. **Solder DW-ES51-1** dans `z_study_tools_section_spec.dart` + `z_sectioned_study_layout.dart` :
   - Ajouter au spec les slots **INJECTABLES** `addActionIcon` (`IconData?`) et `addActionSemanticLabel` (`String?`) — nullable, l'appelant fournit l'icône ET le label localisé (jamais de FR/EN codé en dur — i18n).
   - Ajouter au spec l'orientation injectable `axis` (`Axis`, défaut `Axis.vertical`) — `Axis.horizontal` = rail (flashcards).
   - Le layout consomme `addActionIcon`/`addActionSemanticLabel`/`axis` ; corrige la sémantique du bouton (`label = addActionSemanticLabel`, jamais `spec.title`) ; badge via `theme.radiusM`/`theme.gapS`/`theme.gapM` (LOW-1) ; supprime les `Semantics` redondants (LOW-2).
3. **Non-régression SM-1** : `packages/zcrud_study/test/z_study_tools_rebuild_test.dart` — test widget discriminant (compteurs de build par champ/section/page) + focus/sélection préservés.
4. **Branchement réel de `addAction`** : le bouton `+` invoque le callback injecté (tap → callback) ; test discriminant.
5. Export barrel de `ZStudyToolsPage` (et de tout type public nouveau) via `lib/zcrud_study.dart`.
6. **Régénération du golden ES-5.1** (`study_tools_sectioned.png`) si l'apparence change (badge `radiusM` au lieu de `circular(10)` ; nouvelle orientation de section) — `flutter test --update-goldens` + re-commit du PNG.

**HORS périmètre (NE PAS implémenter ici)** :
- Sections réordonnables persistantes (drag, `ReorderableGridView`), `ZContentHubSheet`, `ZItemActionsMenu`, `applyOrder<T>`/`ZFolderContentsOrder` → **ES-5.3**.
- `ZFeatureAvailability` (disponibilité progressive des éditeurs) → **ES-5.4**.
- Toute dépendance vers les satellites lourds (`zcrud_flashcard`/`zcrud_mindmap`/`zcrud_note`/`zcrud_document`/`zcrud_session`) : NON tirée (la page + le harnais SM-1 n'ont besoin QUE de `zcrud_core` + `zcrud_study_kernel`). Les données réelles/cartes d'item viennent des `itemBuilder` fournis par l'appelant.
- Toucher `zcrud_core`, `zcrud_flashcard`, `scripts/ci`, `sprint-status.yaml` (workstream A actif — ISOLATION).

---

## Acceptance Criteria

Chaque AC est formulé à **pouvoir discriminant** (R12) : un test DOIT pouvoir le faire échouer si l'implémentation dévie. **AC2 (SM-1) est l'AC CENTRAL.**

**AC1 — `ZStudyToolsPage` COMPOSE `ZSectionedStudyLayout`, paramétrée par une liste de sections (aucune duplication du layout)**
**Given** une `List<ZStudyToolsSectionSpec>` de N sections (mix peuplées/vides, orientations mixtes rail/grille)
**When** on rend `ZStudyToolsPage(sections: …)`
**Then** la page rend **exactement un** `ZSectionedStudyLayout` (composition, `find.byType(ZSectionedStudyLayout)` = 1 — le layout d'ES-5.1 est RÉUTILISÉ, jamais réimplémenté inline) alimenté par les mêmes N sections dans l'**ordre d'entrée**
**And** chaque section conserve sa frontière keyée `ValueKey('section:$id')` (N sous-arbres distincts — comptage identique à ES-5.1)
**And** `ZStudyToolsPage` est exportée par le barrel `lib/zcrud_study.dart` uniquement (impl sous `lib/src/`).

**AC2 — [CENTRAL / SM-1 / objectif n°1] Taper 100 caractères ne reconstruit QUE le champ courant, zéro rebuild des autres sections ni de la page**
**Given** une `ZStudyToolsPage` détenant un `ZFormController` STABLE, dont deux sections contiennent chacune un champ éditable scopé par `ZFieldListenableBuilder` (tranche `ValueListenable` par champ), et un compteur de build (a) du champ courant, (b) du champ voisin, (c) d'un observateur au niveau page
**When** on tape **100 caractères** dans le champ courant (`enterText`/`setValue` × 100, `pump` à chaque frappe)
**Then** le compteur du **champ courant** croît de 100 (un rebuild ciblé par frappe), le compteur du **champ voisin reste à 1** (montage initial, JAMAIS reconstruit), et le compteur **au niveau page reste à 1** (aucun rebuild global — aucun `notifyListeners` propagé à la page)
**And** **aucun `setState`** à l'échelle page/section (scan de `z_study_tools_page.dart` : zéro occurrence de `setState(` pour une valeur de champ)
**And** (pouvoir discriminant — R3-I1) si l'on enveloppe les sections dans un `ListenableBuilder(listenable: controller)` au niveau page (ré-introduction du rebuild global), le compteur du champ voisin ET celui de la page deviennent > 1 ⇒ **le test ROUGIT**.

**AC3 — Focus et sélection préservés pendant la saisie (controller stable, pas de ré-injection)**
**Given** le champ courant équipé d'un `TextEditingController` et d'un `FocusNode` **STABLES** (créés une fois, non recréés au rebuild), saisie à **sens unique** (`onChanged → setValue`, JAMAIS de ré-injection `.text =`)
**When** on tape 100 caractères l'un après l'autre
**Then** `focusNode.hasFocus == true` à **chaque** frappe (zéro perte de focus) et `controller.selection.baseOffset == longueur` après saisie (curseur en fin, jamais réinitialisé à 0)
**And** (pouvoir discriminant — R3-I2) si le `TextEditingController` est **recréé à chaque `build`** (ou si la valeur est ré-injectée via `.text =`), le focus est perdu et/ou la sélection réinitialisée ⇒ **le test ROUGIT**.

**AC4 — Action d'ajout (`+`) RÉELLEMENT branchée + icône/label INJECTÉS (solde DW-ES51-1 MEDIUM-1)**
**Given** une section dont `addAction` est un callback non-null, `addActionIcon` = une `IconData` DISTINCTIVE injectée, `addActionSemanticLabel` = un label DISTINCTIF injecté
**When** on rend la section et on **tape** sur le bouton `+`
**Then** le callback `addAction` est **invoqué exactement une fois** (compteur = 1)
**And** la **Semantics** du bouton porte le **label injecté** (`addActionSemanticLabel`), PAS `spec.title` — un `find` par la sémantique du label injecté le trouve, et un `find` du bouton annonçant le titre de section échoue
**And** l'icône rendue est celle **injectée** (`addActionIcon`), pas `Icons.add` codée en dur (`find.byIcon(injectedIcon)` = 1)
**And** (AD-4) `addAction == null` ⇒ **aucun bouton d'ajout** rendu (ni icône ni sémantique de bouton)
**And** (pouvoir discriminant — R3-I3) si le bouton n'appelle pas le callback injecté (ou hardcode `Icons.add`/`label: spec.title`), l'un des trois asserts ci-dessus ROUGIT.

**AC5 — État vide GLOBAL injecté quand toutes les sections sont vides (AD-25 : `ZEmptyContent` par section ET global)**
**Given** une `ZStudyToolsPage(sections: …, globalEmptyState: <widget injecté>)`
**When** **toutes** les sections ont `itemCount == 0`
**Then** la page rend le `globalEmptyState` **injecté** (jamais un label codé en dur), et NON la liste de sections vides empilées
**And** dès qu'**au moins une** section est peuplée, `globalEmptyState` n'est PAS rendu (les sections, chacune avec son `emptyState` par section pour les vides, le sont)
**And** si `globalEmptyState == null`, la page rend les sections telles quelles (comportement d'ES-5.1 préservé — non-régression).

**AC6 — Orientation de section injectable : rail horizontal vs grille verticale (résidu d'apparence ES-5.1)**
**Given** une section `axis: Axis.horizontal` (rail flashcards) et une section `axis: Axis.vertical` (grille docs, défaut)
**When** on rend `ZSectionedStudyLayout`/`ZStudyToolsPage`
**Then** la section horizontale rend ses items dans un défilement **horizontal** (`ListView`/`SingleChildScrollView` `scrollDirection: Axis.horizontal`), la verticale les empile verticalement — l'apparence golden reflète les deux dispositions
**And** `axis` par défaut = `Axis.vertical` (sections existantes ES-5.1 inchangées, non-régression du contrat)
**And** la réordonnabilité/drag (`ReorderableGridView`) reste HORS PÉRIMÈTRE (ES-5.3) — documenté, jamais implicite.

**AC7 — Invariants transverses AD-2/AD-13/AD-15 respectés + tokens de thème (solde DW-ES51-1 LOW-1/2)**
**Given** toutes les surfaces de `zcrud_study` (page + layout + spec)
**When** on les analyse
**Then** **AUCUN** import ni symbole de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`/`ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`) — réactivité Flutter-native pure ; injection thème via `ZcrudTheme.of` (`ZcrudScope` → `Theme.of` repli, AUCUNE couleur/`IconData`/label codé en dur)
**And** le `_CountBadge` utilise `theme.radiusM`/`theme.gapS`/`theme.gapM` (plus de `BorderRadius.circular(10)`/paddings `8`/`2` en dur — LOW-1) ; les `Semantics` redondants supprimés (LOW-2)
**And** RTL directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, jamais `.left/.right`), `Semantics` explicites, cibles interactives ≥ 48 dp, `ListView.builder` (jamais `ListView(children:)`), `const` où possible (AD-13/NFR-S6/NFR-S7).

**AC8 — Acyclicité AD-1 / CORE OUT=0 préservées, vérif verte (RC hors pipe)**
**Given** le package `zcrud_study` après ajout de `ZStudyToolsPage`
**When** on rejoue les gates ciblés
**Then** `python3 scripts/dev/graph_proof.py` reste **ACYCLIQUE** avec **out-degree(zcrud_core) == 0** (arêtes de `zcrud_study` inchangées : `→ zcrud_core`, `→ zcrud_study_kernel`, `→ zcrud_annotations` ; aucun satellite lourd tiré)
**And** `flutter test` (RUNNER Flutter, R14) est **VERT RC=0** (golden ES-5.1 régénéré + rebuild-test SM-1 + discriminants) ; `dart analyze` (zcrud_study) RC=0.

---

## Tasks / Subtasks

- [x] **T1 — Solder DW-ES51-1 dans le spec (AC4, AC6, AC7)**
  - [x] `z_study_tools_section_spec.dart` : ajouté `final IconData? addActionIcon;`, `final String? addActionSemanticLabel;`, `final Axis axis` (défaut `Axis.vertical`), tous const-compatibles, additifs (non-cassant). Docstrings i18n/injection ; aucun `Color`/label/modèle d'app.
  - [x] `package:flutter/widgets.dart` déjà présent (fournit `IconData`/`Axis`/`VoidCallback`).

- [x] **T2 — Solder DW-ES51-1 dans le layout (AC4, AC6, AC7)**
  - [x] Bouton `+` → `Icon(spec.addActionIcon ?? _kAddActionFallbackIcon, semanticLabel: spec.addActionSemanticLabel ?? spec.title)` (repli documenté, jamais hardcode inconditionnel) ; label INJECTÉ porté par `Icon.semanticLabel` fusionné dans le nœud bouton de l'`IconButton` (prime sur `spec.title` → MEDIUM-1) ; `tooltip` = même label (survol).
  - [x] `_CountBadge` : `BorderRadius.all(theme.radiusM)`, paddings `theme.gapM`/`theme.gapS` (LOW-1) ; `Semantics(label:'$count')` redondant supprimé (LOW-2) ; plus de `Semantics(button:true)` enveloppant l'`IconButton` (une seule source de sémantique de bouton).
  - [x] Rendu selon `spec.axis` : `Axis.horizontal` → `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))` (rail) ; `Axis.vertical` → `Column` empilé. Directionnel (`EdgeInsetsDirectional.only(end/bottom:)`), ≥48 dp.

- [x] **T3 — `ZStudyToolsPage` (AC1, AC2, AC3, AC5)**
  - [x] `z_study_tools_page.dart` : `StatefulWidget` pour le SEUL cycle de vie du controller. `initState` crée un `ZFormController` STABLE si `formController == null` ; `dispose` ne dispose QUE le controller possédé ; `didUpdateWidget` gère la bascule possédé↔injecté. Paramètres `sections`/`globalEmptyState`/`formController`.
  - [x] `build` : `globalEmptyState != null && allEmpty` → `globalEmptyState` ; sinon `ZSectionedStudyLayout(sections)` (COMPOSITION). AUCUN `setState` de champ ; AUCUN `ListenableBuilder(listenable: controller)` enveloppant.
  - [x] Controller exposé aux `itemBuilder` via `_ZStudyFormScope` (`InheritedWidget` interne, identité stable ⇒ zéro rebuild propagé) + accès public `ZStudyToolsPage.of/maybeOf(context)` (owned OU injecté).

- [x] **T4 — Export barrel (AC1)**
  - [x] `lib/zcrud_study.dart` exporte `z_study_tools_page.dart` (`ZStudyToolsPage`). Impl sous `lib/src/`.

- [x] **T5 — Test SM-1 discriminant (AC2, AC3) — le cœur**
  - [x] `test/z_study_tools_rebuild_test.dart` reproduit le pattern `sm1_granular_rebuild_test.dart` : page à 2 sections, champ 'a' scopé + observateur structurel de page (section A) + champ voisin 'b' (section B), `TextEditingController`/`FocusNode` stables, `onChanged → setValue`. Compteurs `buildsA`/`buildsB`/`buildsPage`.
  - [x] `AC2 SM-1` : 100 frappes ⇒ `buildsA == 101`, `buildsB == 1`, `buildsPage == 1`, focus vrai à chaque frappe.
  - [x] `AC3` : focus vrai à chaque frappe ; `selection.baseOffset == 100` en fin.

- [x] **T6 — Tests addAction + icône/label injectés + état vide global (AC4, AC5, AC6)**
  - [x] callback tap ⇒ compteur == 1.
  - [x] label sémantique injecté trouvé (`find.bySemanticsLabel`).
  - [x] `find.byIcon(kInjectedAddIcon) == 1` ET `find.byIcon(Icons.add) == 0`.
  - [x] `addAction null ⇒ aucun IconButton`.
  - [x] toutes vides ⇒ `globalEmptyState` ; une peuplée ⇒ pas de global ; `globalEmptyState null` ⇒ sections rendues.
  - [x] section horizontale ⇒ scroller horizontal ; section verticale ⇒ aucun scroller horizontal ; controller injecté non disposé.

- [x] **T7 — Régénérer le golden ES-5.1 (AC7, AC8)**
  - [x] `flutter test --update-goldens` → `study_tools_sectioned.png` régénéré (badge `radiusM` + rail flashcards `Axis.horizontal`) ; golden reste DISCRIMINANT (byte-diff m1/m2/m3 + comptage N→N-1 verts, rail horizontal constant entre canonique et mutants). LOW-3 : docstring + commentaires `fusedSections()` corrigés (« retrait de la section notes », pas « fusion »).

- [x] **T8 — Injections R3 (pouvoir discriminant) + vérif verte (AC2, AC3, AC4, AC8)**
  - [x] R3-I1..I4 joués RÉELLEMENT (RC=1 RED capturé, cf. Debug Log), restaurés par édition ciblée (aucun `git checkout/restore/stash`), re-vérif verte.
  - [x] Vérif verte CIBLÉE rejouée (RC hors pipe) : `dart analyze` RC=0, `flutter test` RC=0 (19 tests), `graph_proof` RC=0, `melos list`=19, scans interdits = commentaires seulement.

---

## Dev Notes

### Architecture — invariants NON-NÉGOCIABLES applicables (AD)
- **AD-25** [archi:243-246] — `ZStudyToolsPage` = **liste de sections paramétriques** (`title`/`itemBuilder`/`emptyState`/`addAction`) ; **chaque section = un scoping `ValueListenable`/`ListenableBuilder` ISOLÉ** — une frappe dans une section ne reconstruit AUCUNE autre (SM-1) ; **aucun `setState` page/section** ; `ZItemActionsMenu`/`ZContentHubSheet` paramétrés (`null` = action absente) → ES-5.3 ; `ZFeatureAvailability` injectable → ES-5.4 ; couleurs/labels/l10n injectés, directionnel / ≥48 dp / `Semantics` / `ListView.builder`.
- **AD-2** [archi:44, sm1_granular_rebuild_test.dart] — `ZFormController` **pur-Flutter** (`ChangeNotifier`/`ValueListenable`) ; un champ = un `ZFieldListenableBuilder`/`ValueListenableBuilder` n'écoutant que SA tranche ; controller **STABLE** (create/dispose, jamais recréé au rebuild) ; `TextEditingController`/`FocusNode` stables ; saisie sens unique (`onChanged → setValue`, pas de ré-injection `.text=`) ; `setValue` ne provoque JAMAIS de rebuild global (`z_form_controller.dart:19`). Interdits : `setState` de formulaire ; construction de champs dans une closure de `build()` recréant les controllers.
- **AD-15** [archi:44] — AUCUN gestionnaire d'état dans `zcrud_study` ; injection via `ZcrudScope` (jamais `ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`).
- **AD-13** [archi:51] — RTL directionnel, `Semantics`, ≥48 dp, couleur jamais seul canal, thème/l10n injectés (`ZcrudScope`/`ThemeExtension`, repli `Theme.of`).
- **AD-4** [archi:Inherited] — composition, pas héritage de vues ; `addAction`/`addActionIcon`/`addActionSemanticLabel`/`ZItemActionsMenu` : callback/valeur `null` = capacité absente (jamais un no-op silencieux).
- **AD-1 / AD-17** [archi:54,89] — graphe **acyclique**, `zcrud_study → zcrud_core`/`zcrud_study_kernel`/`zcrud_annotations` (jamais l'inverse), **out-degree(zcrud_core)=0**. NE PAS tirer les satellites lourds.

### Réactivité de référence (AD-25 dérivé d'AD-2, [archi:335-343])
```
Frappe dans une section → ZFormController (ChangeNotifier) → fieldListenable(name) (tranche)
  → ZFieldListenableBuilder isolé → rebuild CIBLÉ du seul champ courant ; autres sections/page intactes.
```
ES-5.1 a garanti la **frontière** (`ValueKey('section:$id')` + sous-arbre isolé). ES-5.2 branche la tranche par champ SANS surface de rebuild global. **Pattern de référence à reproduire** : `packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart` (compteurs `buildsA`/`buildsB`/`buildsGlobal` sur `ZFieldListenableBuilder`, `EditableText` à controller/focus stables, `onChanged → setValue`, `selection.baseOffset == length`). NE PAS régresser SM-1.

### API `zcrud_core` réutilisée (déjà livrée, NE PAS réimplémenter)
- `ZFormController extends ChangeNotifier` [`z_form_controller.dart:32`] : `fieldListenable(name) → ValueListenable<Object?>` (même instance stable par `name`, `:96-103`), `valueOf(name)` (`:109`), `setValue(name, value)` (`:127`, jamais de rebuild global `:19`), `isDirty`/`reveal`/`visibleFields` (non requis ici). Ctor `ZFormController(initialValues: {...})`.
- `ZFieldListenableBuilder({controller, name, builder, child})` [`z_field_listenable_builder.dart:21`] — `StatelessWidget` = `ValueListenableBuilder` sur `controller.fieldListenable(name)`. Réutiliser tel quel pour scoper chaque champ.
- `ZcrudTheme.of(context)` [`theme/z_theme.dart:296`] : `ZcrudScope.maybeOf(context)?.theme` → `Theme.of(context).extension<ZcrudTheme>()` → `ZcrudTheme.fallback(...)`. Tokens dispo : `gapS=4`, `gapM=8`, `gapL`, `radiusS=Radius.circular(4)`, `radiusM=Radius.circular(8)`, `labelTextStyle`, etc. **Utiliser `radiusM`/`gapS`/`gapM` pour le badge (LOW-1).**
- `ZcrudScope` [`zcrud_scope.dart:48`] : `InheritedWidget` zéro-config, `of`/`maybeOf` ; `ZScopeError` si backend non injecté sur `resolve<T>`.

### Solde DW-ES51-1 (détail, code-review-es-5-1.md §Décision orchestrateur)
| Finding | Fichier:ligne (ES-5.1) | Correctif ES-5.2 |
|---|---|---|
| MEDIUM-1 (icône codée en dur) | `z_sectioned_study_layout.dart:121` | Icône **injectée** `spec.addActionIcon` |
| MEDIUM-1 (sémantique ambiguë) | `z_sectioned_study_layout.dart:110-113` | `label = spec.addActionSemanticLabel` (injecté, prime sur `spec.title`) |
| LOW-1 (badge en dur) | `z_sectioned_study_layout.dart:158-165` | `theme.radiusM` + `theme.gapS/gapM` |
| LOW-2 (Semantics redondants) | `:155`, `:111-119` | Une seule source de sémantique (badge Text nu ; bouton = IconButton + Semantics label injecté) |
| LOW-3 (fusedSections documentaire) | `study_tools_page_golden_test.dart:80` | Corriger le commentaire |
> i18n NON-NÉGOCIABLE : le label du bouton d'ajout est **fourni par l'appelant** (localisé) — hardcoder « Ajouter »/« Add » violerait FR-23/AD-13.

### GOTCHA RUNNER (R14) — `flutter test`, PAS `dart test`
`zcrud_study` déclare `flutter: sdk: flutter` → package **Flutter**. Les tests importent `flutter_test`/`dart:ui` → tournent **UNIQUEMENT** sous `flutter test`. Le gate `gate:web-determinism` (`dart test -p node`) **auto-exclut** les packages Flutter (`scripts/ci/gate_web_determinism.dart:_isFlutterPackage`) — `zcrud_study` hors couverture, aucune édition d'allowlist. `codegen-distribution` : aucun `*.g.dart` (pas de `@ZcrudModel`), sans objet.

### GOTCHA RC (R15) — mesurer le vrai code de sortie hors pipe
```bash
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"
```
Un `flutter test | tee` renvoie le RC de `tee`, pas du test.

### Golden ES-5.1 — régénération attendue
Le badge passe de `BorderRadius.circular(10)` à `theme.radiusM` (`Radius.circular(8)`) ⇒ pixels différents ⇒ `matchesGoldenFile` ROUGIT tant que le PNG n'est pas régénéré. De même si une section de la fixture golden adopte `axis: Axis.horizontal`. Prévoir `flutter test --update-goldens` + re-commit `test/golden/goldens/study_tools_sectioned.png` (au commit d'epic ES-5). Le changement de `addActionSemanticLabel` (sémantique, non-pixel) n'affecte PAS le golden. Vérifier que le diff visuel reste raisonnable (pas d'effondrement du rendu).

### Injections R3 prévues (défaut réel → test RED → restauration par ÉDITION CIBLÉE, R13)
> JAMAIS `git checkout/restore/stash` (working-tree partagé workstream A). Restauration par édition ciblée du fichier, RC RED puis GREEN consignés au Debug Log.

| # | Injection (édition ciblée dans la PROD) | Test attendu RED | Restauration |
|---|---|---|---|
| **R3-I1** (anti-rebuild-global — CENTRAL) | Envelopper les sections de `ZStudyToolsPage.build` dans `ListenableBuilder(listenable: formController, builder: …)` (ré-introduit le rebuild global à chaque frappe) | `test SM-1` (AC2) : `buildsB` et `buildsPage` deviennent > 1 → `expect(buildsB, 1)` / `expect(buildsPage, 1)` ROUGIT | supprimer le `ListenableBuilder` global (repasser au scoping par champ) |
| **R3-I2** (focus/controller) | Recréer le `TextEditingController` (ou ré-injecter `.text = value`) à chaque `build` du champ courant | `test focus` (AC3) : focus perdu / `selection.baseOffset` réinitialisé à 0 → ROUGIT | remettre le controller STABLE + saisie sens unique |
| **R3-I3** (addAction) | Bouton `+` : ignorer `spec.addAction` (onPressed no-op) OU hardcoder `Icon(Icons.add)`/`label: spec.title` | `test addAction` (AC4) : compteur callback == 0 / `find.byIcon(injectedIcon)` == 0 / label injecté absent de la Semantics → ROUGIT | rebrancher `onPressed: spec.addAction`, icône/label injectés |
| **R3-I4** (état vide global) | Rendre `ZSectionedStudyLayout` même quand toutes les sections sont vides ET `globalEmptyState != null` (ignorer la branche globale) | `test 'toutes vides ⇒ globalEmptyState'` (AC5) : `globalEmptyState` absent → ROUGIT | remettre la branche `if (allEmpty && globalEmptyState != null)` |

### Structure du package (à modifier/créer)
```text
packages/zcrud_study/
  lib/
    zcrud_study.dart                              # + export ZStudyToolsPage (MODIFIED)
    src/presentation/
      z_study_tools_section_spec.dart             # + addActionIcon/addActionSemanticLabel/axis (MODIFIED)
      z_sectioned_study_layout.dart               # DW-ES51-1 : icône/label injectés, badge radiusM, axis, Semantics nettoyés (MODIFIED)
      z_study_tools_page.dart                     # ZStudyToolsPage (NEW)
  test/
    z_study_tools_rebuild_test.dart               # SM-1 + addAction + état vide + axis (NEW)
    golden/
      study_tools_page_golden_test.dart           # commentaire fusedSections LOW-3 (MODIFIED, documentaire)
      goldens/study_tools_sectioned.png           # régénéré si apparence change (MODIFIED)
```

### Project Structure Notes
- **Isolation workstream B** : NE PAS toucher `zcrud_core`, `zcrud_flashcard`, `scripts/ci`, `sprint-status.yaml` (workstream A actif sur ES-4). Aucun fichier hors `packages/zcrud_study/**`.
- `graph_proof.py` inchangé (même package, aucune nouvelle arête — la page ne tire QUE `zcrud_core`/`flutter`). `melos list` reste à 19 packages.
- Le spec gagne 3 champs optionnels additifs (const-compatible) — non-cassant pour les fixtures golden ES-5.1 (valeurs par défaut).

### Vérif verte à rejouer (commandes exactes, RC hors pipe R15 — CIBLÉES, PAS de `melos verify`/`analyze` repo-wide tant que workstream A actif)
```bash
# 1. Tests du package (RUNNER = flutter test, R14) — golden régénéré + SM-1 + discriminants
OUT=$(cd packages/zcrud_study && flutter test 2>&1); RC=$?; echo "$OUT" | tail -40; echo "RC=$RC"
#   (si apparence changée : cd packages/zcrud_study && flutter test --update-goldens  PUIS re-run vert)

# 2. Analyse ciblée du package (RC=0)
OUT=$(cd packages/zcrud_study && dart analyze 2>&1); RC=$?; echo "$OUT" | tail -20; echo "RC=$RC"

# 3. Acyclicité AD-1 + CORE OUT=0 (inchangé)
OUT=$(python3 scripts/dev/graph_proof.py 2>&1); RC=$?; echo "$OUT"; echo "RC=$RC"

# 4. Scans interdits (doivent être VIDES)
grep -rnE "flutter_riverpod|package:get/|package:provider/|ConsumerWidget|WidgetRef|Get\.|Provider\.of|setState\(" packages/zcrud_study/lib
grep -rnE "EdgeInsets\.only\(|centerLeft|centerRight|Positioned\(|TextAlign\.(left|right)|ListView\(children:" packages/zcrud_study/lib
```
**Attendu** : (1) `flutter test` RC=0 (golden + SM-1 + addAction + état vide + axis) ; (2) `dart analyze` RC=0 ; (3) `ACYCLIQUE` + `out-degree(zcrud_core)=0` RC=0 ; (4) scans VIDES (seule occurrence tolérée = commentaire).
> La vérif repo-wide (`melos run analyze` ET `melos run verify`) reste à la charge de l'orchestrateur AU GATE DE COMMIT D'EPIC (workstreams au repos) — non rejouée ici (isolation).

### Dépendances de la story
- **Dépend de** : **ES-5.1 (done)** — consomme `ZStudyToolsSectionSpec` + `ZSectionedStudyLayout` ; réutilise le golden ES-5.1 (régénéré). ES-3 (data) au niveau epic, mais la page + le harnais SM-1 n'ont besoin QUE de `zcrud_core` + `zcrud_study_kernel` (déjà livrés).
- **BLOQUE** : **ES-5.3** (sections réordonnables, `ZContentHubSheet`, `ZItemActionsMenu` — réutilisent `ZStudyToolsPage` + `ZStudyToolsSectionSpec` étendu + `ZFolderContentsOrder`). Le scoping isolé prouvé ici est le socle SM-1 des sections réordonnables.

### References
- [Source: epics-zcrud-study-2026-07-12/epics.md#Story-ES-5.2] (l.735-756) — ACs canoniques (liste de sections, SM-1 100 caractères, injection couleurs/labels, RTL/48dp/Semantics/ListView.builder).
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-25] (l.243-246) — sections paramétriques à scoping isolé, `null` = action absente, couleurs/labels injectés.
- [Source: architecture.md] (l.335-343) — diagramme de réactivité study-tools (frappe → tranche → ListenableBuilder isolé → rebuild ciblé).
- [Source: architecture.md] (l.44,51) — AD-2/AD-15 (aucun gestionnaire d'état), AD-13 (RTL/a11y/thème injecté).
- [Source: es-5-1-decomposabilite-layout-golden.md] — socle ES-5.1 (spec + layout + golden), §« Écarts résiduels » (rail vs grille, scoping ES-5.2).
- [Source: code-review-es-5-1.md] — DW-ES51-1 (MEDIUM-1 + LOW-1/2/3), justification du report à ES-5.2.
- [Source: packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart] — pattern SM-1 de référence (compteurs, focus, sélection).
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart] — `ZFormController` (fieldListenable/valueOf/setValue).
- [Source: packages/zcrud_core/lib/src/presentation/z_field_listenable_builder.dart] — `ZFieldListenableBuilder`.
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart] — `ZcrudTheme` (tokens radiusM/gapS/gapM).
- [Source: packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart] / [z_study_tools_section_spec.dart] — cibles de modification (DW-ES51-1).
- [Source: ~/DEV/iffd/lib/src/presentation/features/folders/pages/folder_study_tools_page.dart] — monolithe mesuré 1753 l. (build 350→~1739, 4 sections inlinées) ; `multi_flashcard_editor_page.dart` (`setState` ×18) = bug de rebuild global de référence. READ-ONLY, aucun fichier IFFD modifié.

---

## Dev Agent Record

### Agent Model Used
claude-opus-4-8 (bmad-dev-story, effort high, workstream B isolé).

### Debug Log References

**Injections R3 (pouvoir discriminant R12) — RC hors pipe (R15), restauration par ÉDITION CIBLÉE (R13, aucun `git checkout/restore/stash`).**

| # | Injection (édition ciblée) | Test | RC | Message EXACT capturé | Restauration |
|---|---|---|---|---|---|
| **R3-I1** (anti-rebuild-global, CENTRAL) | `ZStudyToolsPage.build` : sections enveloppées dans `ListenableBuilder(listenable: _controller.fieldListenable('a'), …)` — reconstruit toute la surface à chaque frappe | `AC2 SM-1` | **1** | `Expected: <1>` / `Actual: <101>` (`reason: le champ voisin (autre section) JAMAIS reconstruit`) → `buildsB` passe 1→101 | supprimé le `ListenableBuilder`, retour au `ZSectionedStudyLayout(sections)` nu |
| **R3-I2** (focus/controller) | champ 'a' : `TextEditingController` RECRÉÉ à chaque `build` (controller instable, AD-2) | `AC3` | **1** | `Expected: <100>` / `Actual: <-1>` (`reason: curseur en fin de texte, jamais réinitialisé à 0`) → `selection.baseOffset` -1 | retour au `teA` STABLE, saisie sens unique |
| **R3-I3** (addAction) | layout : `Icon(Icons.add, semanticLabel: 'R3I3')` + `tooltip: spec.title` (icône/label hardcodés) | `AC4` (×3) | **1** | icône : `Expected: exactly one matching candidate` / `Actual: _IconWidgetFinder:<Found 0 widgets with icon "IconData(U+0E5F9)": []>` ; label : `Found 0 widgets with a semantics label named "AJOUTER-UN-ELEMENT-XYZ"` ; callback : `Found 0 widgets with icon` (star) → tap échoue | rebranché `spec.addActionIcon ?? _kAddActionFallbackIcon` + `semanticLabel/tooltip` injectés |
| **R3-I4** (état vide global) | `ZStudyToolsPage.build` : `false &&` sur la garde état-vide global (toujours le layout) | `AC5` (toutes vides) | **1** | `Expected: exactly one matching candidate` / `Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'global-empty'>]: []>` | rétabli la garde `globalEmptyState != null && allEmpty` |

> Note R3-I1 : la variante littérale `ListenableBuilder(listenable: formController)` est INERTE ici — `ZFormController.setValue` ne déclenche JAMAIS `notifyListeners()` (garantie SM-1 au niveau controller, déjà prouvée dans zcrud_core). L'injection biting équivalente écoute la tranche du champ édité (`fieldListenable('a')`), reproduisant fidèlement un rebuild GLOBAL par frappe — discriminant plus fort prouvant l'absence de surface de rebuild global au niveau page.

**Vérif verte CIBLÉE finale (RC hors pipe) :**
- `dart analyze` (zcrud_study) → `No issues found!` RC=0
- `flutter test` (zcrud_study, RUNNER Flutter R14) → `All tests passed!` **19 tests** (6 golden + 13 rebuild/AC), golden régénéré, RC=0
- `python3 scripts/dev/graph_proof.py` → `ACYCLIQUE OK`, `out-degree(zcrud_core) = 0`, arêtes `zcrud_study → {zcrud_core, zcrud_study_kernel, zcrud_annotations}` inchangées, RC=0
- `dart run melos list` → **19 packages**, RC=0
- scans interdits (`flutter_riverpod`/`get`/`provider`/`ConsumerWidget`/`WidgetRef`/`Get.`/`Provider.of`/`setState(` ; `EdgeInsets.only(`/`centerLeft`/`centerRight`/`Positioned(`/`TextAlign.left|right`/`ListView(children:`) sur `lib/` → **seules occurrences = commentaires documentaires** (tolérées).

### Completion Notes List

- **Conception scoping SM-1 (AC2, objectif produit n°1)** : `ZStudyToolsPage` = `StatefulWidget` détenant un `ZFormController` STABLE (create `initState` si non injecté / dispose seulement si possédé). `build` compose `ZSectionedStudyLayout(sections)` SANS aucune surface de rebuild global (pas de `ListenableBuilder`/`setState` enveloppant). Le controller est exposé aux `itemBuilder` via `_ZStudyFormScope` (`InheritedWidget` interne, `updateShouldNotify` sur l'identité seule → jamais notifié par `setValue`) et `ZStudyToolsPage.of/maybeOf`. Chaque champ éditable = `ZFieldListenableBuilder` sur sa tranche → rebuild ciblé prouvé : 100 frappes ⇒ `buildsA=101`, `buildsB=1`, `buildsPage=1` (observateur structurel non field-scoped), focus/`selection.baseOffset==100` préservés.
- **Résolution DW-ES51-1** : MEDIUM-1 (icône hardcodée → `addActionIcon` injecté avec repli neutre documenté `_kAddActionFallbackIcon` ; sémantique ambiguë → label INJECTÉ `addActionSemanticLabel` porté par `Icon.semanticLabel`, prime sur `spec.title`) ; LOW-1 (badge → `theme.radiusM`/`theme.gapM`/`theme.gapS`) ; LOW-2 (`Semantics(label:'$count')` + `Semantics(button:true)` redondants supprimés) ; LOW-3 (docstring/commentaires `fusedSections()` corrigés — « retrait de la section notes »).
- **AC6 orientation** : `axis` injectable ; `Axis.horizontal` → rail `SingleChildScrollView` horizontal (flashcards), défaut `Axis.vertical` (non-régression du contrat ES-5.1). Golden canonique reflète les deux dispositions.
- **Golden régénéré** DISCRIMINANT : rail horizontal maintenu CONSTANT entre canonique et mutants m1/m2/m3 (la mutation reste l'unique différence ; byte-diff + comptage N→N-1 rougissent toujours sous injection).
- **Invariants** : AD-2 (tranches, controller stable, sens unique) ✅ ; AD-15 (aucun gestionnaire d'état — scans clean hors commentaires) ✅ ; AD-13/FR-26 (directionnel, `Semantics`, ≥48 dp, thème/icône/label injectés) ✅ ; AD-1/AD-17 (graphe acyclique, CORE OUT=0, aucun satellite lourd tiré) ✅.
- **Isolation workstream B** : uniquement `packages/zcrud_study/**` modifié ; sprint-status.yaml NON touché (sérialisé par l'orchestrateur) ; aucune vérif repo-wide `melos verify/analyze` (workstream A actif).

### File List

- `packages/zcrud_study/lib/src/presentation/z_study_tools_page.dart` — **NEW** — `ZStudyToolsPage` + `_ZStudyFormScope`.
- `packages/zcrud_study/lib/src/presentation/z_study_tools_section_spec.dart` — **MODIFIED** — slots `addActionIcon`/`addActionSemanticLabel`/`axis`.
- `packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart` — **MODIFIED** — icône/label injectés, badge tokens, axis rail/grille, Semantics nettoyés.
- `packages/zcrud_study/lib/zcrud_study.dart` — **MODIFIED** — export `ZStudyToolsPage`.
- `packages/zcrud_study/test/z_study_tools_rebuild_test.dart` — **NEW** — SM-1 + AC1/AC3/AC4/AC5/AC6 + cycle de vie controller (13 tests).
- `packages/zcrud_study/test/golden/_fixtures.dart` — **MODIFIED** — `axis` sur `populatedSection`, rail flashcards horizontal en canonique.
- `packages/zcrud_study/test/golden/study_tools_page_golden_test.dart` — **MODIFIED** — import `Axis`, mutants flashcards horizontaux, commentaires LOW-3.
- `packages/zcrud_study/test/golden/goldens/study_tools_sectioned.png` — **MODIFIED (régénéré)** — badge `radiusM` + rail horizontal.
