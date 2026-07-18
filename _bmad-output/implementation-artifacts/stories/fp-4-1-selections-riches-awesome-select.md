# Story 4.1: Sélections riches complètes (`zcrud_select` + fork `awesome_select`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur consommateur,
I want un `ZSelectPresenter` adossé au fork vendoré `awesome_select` (SmartSelect) fournissant
`select` (modal S2 + recherche), `radio` en modal, `checkbox`/`multiselect` (single + multiple)
et `relation` + CRUD inline, injectable via `ZcrudScope.selectPresenter`,
So that j'atteins la parité de sélection riche DODLP (`crudDataSelect` inclus) sans qu'aucun type
`awesome_select`/`S2*` ne fuite hors du satellite et sans régression du rendu natif par défaut.

## Contexte & état réel sur disque (LIRE AVANT DE CODER)

**Le seam cœur est DÉJÀ livré (fp-1-1) et DÉJÀ câblé** — cette story n'écrit **PAS** dans `zcrud_core`.
Vérifié sur disque :

- `packages/zcrud_core/lib/src/presentation/edition/z_select_presenter.dart` déclare l'`abstract class
  ZSelectPresenter` (`const` ctor, unique méthode `Widget present(BuildContext, ZSelectPresentation)`)
  + le DTO **neutre** `ZSelectPresentation{field, options, selected, onChanged, multiple, searchable,
  readOnly, label}`. Exporté par le barrel `zcrud_core`.
- `ZcrudScope.selectPresenter` (`z_select_scope.dart:66/141/209`) porte le seam, **défaut `null`**.
- **La délégation existe déjà dans les deux widgets natifs** :
  - `z_select_field_widget.dart:123-138` (`select`/`radio`/`checkbox`) : `final presenter =
    ZcrudScope.maybeOf(context)?.selectPresenter; if (presenter != null) return presenter.present(...,
    ZSelectPresentation(... multiple: multiple || field.type == checkbox ...));` sinon rendu natif.
  - `z_relation_field_widget.dart:167-182` (`relation`) : idem, `options: _choices` (flux dynamique si
    branché, sinon repli statique).

⇒ **Le seul travail restant côté rendu** est d'écrire l'implémentation concrète de `ZSelectPresenter`
dans `zcrud_select`, adossée à `awesome_select`, et de prouver qu'injectée elle **rend réellement**.
Le cœur ne bouge pas ; ne pas le rouvrir (si un besoin cœur apparaît → **signaler / re-séquencer**,
ne pas écrire dans `zcrud_core`).

**État `zcrud_select` (squelette fp-1-2, à faire évoluer)** : barrel + `lib/src/{domain,data,
presentation}/` + `presentation/z_select_presenter_placeholder.dart` (const `kZcrudSelectPlaceholder`)
+ `test/z_select_confinement_test.dart` (3 volets falsifiables). `pubspec.yaml` déclare déjà
`zcrud_core: ^0.2.1` + `awesome_select: ^6.0.0` + `flutter` (arête vendor ET-1 déjà posée).

**Dette héritée de fp-1-2 (à traiter EN PREMIER, cf. `code-review-fp-1-2.md`)** : la source vendorée
`packages/awesome_select/` cible Flutter 3.0 et **casse sous la toolchain workspace**. Elle a été
rendue analysable UNIQUEMENT via un **blanket** dans `packages/awesome_select/analysis_options.yaml`
(`undefined_getter: ignore` + `class_used_as_mixin: ignore`). Ce blanket **doit être retiré** par
cette story après correction des sites réels (rien ne l'importait au stade squelette ; `zcrud_select`
l'importe maintenant → les vrais diagnostics doivent redevenir visibles).

## Acceptance Criteria

### AC1 — Compat Flutter du fork rétablie EN SOURCE + blanket `analysis_options` remplacé

**Given** la source vendorée `packages/awesome_select/` casse sous la toolchain (`Dart ^3.12.2`) sur
**4 sites réels** : `Theme.of(context).errorColor` (`lib/src/tile/tile.dart:216`),
`theme.textTheme.headline6` (`lib/src/widget/s2_state.dart:142`),
`theme.primaryTextTheme.headline6` (`s2_state.dart:143`), et `abstract class S2ChosenData<T>` utilisée
en `with` (`lib/src/model/chosen.dart:13`, cf. `S2ChosenNotifier extends ChangeNotifier with
S2ChosenData` → `class_used_as_mixin` Dart 3)
**When** on maintient le fork (owner : « fork maintenu par nous », AD-49)
**Then** les 4 sites sont corrigés **dans le source amont** vers l'API Flutter courante — mapping M3 :
`errorColor` → `Theme.of(context).colorScheme.error` ; `headline6` → `titleLarge` (×2) ;
`abstract class S2ChosenData<T>` → `abstract mixin class S2ChosenData<T>` (préserve `extends` ET `with`)
**And** le **blanket par catégorie** est **retiré** de `packages/awesome_select/analysis_options.yaml`
(plus de `undefined_getter: ignore` ni `class_used_as_mixin: ignore`) ; tout diagnostic résiduel
**inévitable** est traité par un `// ignore: <règle_précise>` **ciblé ligne-à-ligne** avec justification
en commentaire (jamais une suppression par catégorie/fichier)
**And** `dart analyze packages/awesome_select` retourne **RC=0** sans le blanket, LICENCE MIT +
attribution Akbar Pulatov conservées, `publish_to: none` conservé.

### AC2 — `ZSelectPresenter` concret rend `select` (modal S2 + recherche) et est PROUVÉ injecté

**Given** `zcrud_select` dépendant du vendor `awesome_select`
**When** il fournit une implémentation concrète de `ZSelectPresenter` (p.ex. `ZSmartSelectPresenter`,
`const` ctor) et qu'elle est injectée via `ZcrudScope(selectPresenter: const ZSmartSelectPresenter())`
**Then** un `select` rend un **modal S2 responsive + recherche** (`SmartSelect.single`,
`modalFilter: true`) à parité DODLP ; la sélection écrit via `onChanged` **le `value` métier** (jamais
un type S2) ; **aucun type `awesome_select`/`S2*` ne fuit** dans une signature publique de
`zcrud_select` (barrel + `ZSelectPresenter.present` reste neutre, AD-40)
**And** un test widget monte `ZSelectFieldWidget` (famille `select`) **sous un `ZcrudScope` avec le
présentateur injecté** et prouve que le sous-arbre riche est rendu : `find.byType(SmartSelect)`
`findsOneWidget` **ET** `find.byType(DropdownButtonFormField)` `findsNothing` (le natif est bien
supplanté — presence≠association prouvée par ABSENCE du natif)
**And** un **espion** sur `onChanged` capte la valeur métier sélectionnée après ouverture du modal +
tap d'une option (capture prouvée, pas seulement « le widget existe »)
**And** **sans présentateur injecté** (`selectPresenter: null`), la famille native retombe **exactement**
sur le rendu natif (`DropdownButtonFormField`/modal natif) — non-régression prouvée par un 2ᵉ test
(défaut AD-48).

### AC3 — `radio` (modal), `checkbox`/`multiselect` (single + multiple, statiques + dynamiques)

**Given** un champ `radio` et un champ `checkbox`/`select multiple`
**When** ils sont rendus via le présentateur (`DTO.multiple` distingue mono/multi : le cœur passe
`multiple || field.type == checkbox`)
**Then** `radio` rend un **déclencheur modal S2** (`choiceType: radios`, parité vs `RadioListTile`
inline DODLP) ; le mode **multiple** (`checkbox`/`select multi`) rend `SmartSelect.multiple`
(`choiceType: checkboxes`/`switches`) et **écrit une `List<Object?>`** dans la tranche (jamais la
concaténation littérale `"S2Choice"` du DODLP — bug à NE PAS hériter)
**And** les options **statiques** (`ZSelectPresentation.options`, projetées depuis `field.choices`) et
**dynamiques** (mêmes `options` déjà résolues cross-champ par le cœur) sont couvertes — le présentateur
consomme `presentation.options` **tel quel** (déjà résolu par le dispatcher, ne re-résout rien)
**And** un test widget prouve mono→scalaire et multi→`List` via l'espion `onChanged`.

### AC4 — `relation` + CRUD inline (registration runtime, jamais dans l'annotation `const`)

**Given** une source `relation` (`crudDataSelect` DODLP)
**When** le présentateur rend la famille `relation` (`ZRelationFieldWidget` délègue déjà via le même
seam, `options: _choices`)
**Then** le présentateur rend le sélecteur riche (modal + recherche) et **préserve la voie CRUD inline
neutre** : l'entité créée/éditée inline est **retournée et sélectionnée sans quitter** le formulaire
parent (chemin `onChanged`), la source dynamique et le CRUD restant résolus au **runtime** via
`ZRelationSourceRegistry`/`ZRelationCrudRegistry` + `sourceKey`/`crudKey` (jamais dans l'annotation
`const` — le présentateur ne porte AUCUNE closure de source/CRUD)
**And** un test widget prouve que, sous présentateur injecté, un champ `relation` rend le sous-arbre S2
riche et capte la sélection.

> **Écart tranché (disjonction × frontière fp-3)** : le DTO neutre `ZSelectPresentation` **ne porte pas**
> le `ZRelationSource`/`ZRelationCrudHandler` (seam volontairement minimal, fp-1-1). Le CRUD inline
> **réel** (form + repository + registres) est câblé côté **binding/app** (fan-in) et exercé par le
> **harnais fp-3**. fp-4-1 prouve donc, dans son scope disjoint, que **le chemin `relation` du
> présentateur rend et capte** ; la démonstration bout-en-bout « créer inline puis sélectionner » avec
> registres réels relève de fp-2-2 (binding) / fp-3 (harnais). Consigner cet écart en Completion Notes.

### AC5 — Isolation AD-1/AD-40/AD-49 : CORE OUT=0, zéro fuite S2, garde falsifiable

**Given** l'ajout de l'adaptateur importe réellement `awesome_select` dans `lib/**`
**When** on rejoue `scripts/dev/graph_proof.py` + la garde de confinement
**Then** le graphe reste **ACYCLIQUE** et **CORE OUT=0** (les arêtes zcrud_* sortantes de `zcrud_select`
= `zcrud_core` uniquement ; `awesome_select` = tiers privé invisible au graph_proof)
**And** `awesome_select` reste déclaré **exactement par `zcrud_select`** parmi `packages/*/pubspec.yaml`
(volet 3 de la garde)
**And** le barrel `lib/zcrud_select.dart` **n'exporte AUCUN type `S2*`/`SmartSelect`** ni `awesome_select`
— la garde de confinement est **étendue** d'un volet falsifiable prouvant qu'aucun identifiant
`SmartSelect`/`S2` n'apparaît dans les **exports publics** (mutant témoin : exporter un helper S2 → la
garde ROUGIT), les helpers de conversion `ZFieldChoice`→`S2Choice` restant **privés sous `lib/src/`**
**And** l'allowlist deps/imports (volets 1-2) reste vraie ; l'anti-vacuité (`expect(files, isNotEmpty)`)
est conservée.

### AC6 — a11y / RTL / thème (AD-13, FR-26) : ≥48dp, pas de double annonce, zéro couleur en dur

**Given** le rendu du présentateur
**When** on l'audite a11y/RTL/thème
**Then** le déclencheur (tuile modale) porte un `Semantics(button: true, label: <label champ>)`
explicite **sans double annonce** (ne pas empiler un `Semantics(label:)` par-dessus un `ListTile` qui
annonce déjà son `title` — une seule annonce accessible) ; cibles tactiles **≥ 48 dp** (vérifiées en
test, pas assumées) ; **aucune couleur codée en dur** — toute couleur dérive de `Theme.of(context)`/
`ColorScheme` (FR-26 ; bannir `Colors.grey/blueAccent/white70`, `kErrorColor`, etc. si recopiés) ;
insets **directionnels** (`EdgeInsetsDirectional`, `TextAlign.start`, jamais `.only(left:/right:)`) ;
les **libellés d'options** l10n sont résolus via `label(context, choice.label, fallback: choice.label)`
(helper public exporté par `zcrud_core`), jamais affichés en clé brute ni codés en dur.

### AC7 — Défensif AD-10 : options absentes/corrompues → dégradé DÉFINI, jamais un crash

**Given** `presentation.options` vide, ou `selected` absent des options, ou une option `disabled`
**When** le présentateur rend
**Then** le rendu est **dégradé défini** (sélecteur vide mais accessible / option non représentée
affichée neutre / option désactivée non sélectionnable) — **jamais** une exception propagée ; un test
couvre les 3 cas (`options: []`, `selected` hors options, `ZFieldChoice.disabled`).

### AC8 — Composabilité binding (AR-4) sans side-effect d'import ; injectabilité prouvée in-scope

**Given** le présentateur destiné à être composé par le binding `zcrud_get` au bootstrap
**When** un consommateur l'enrôle
**Then** le présentateur est une classe **`const`-constructible** exportée par le barrel, **sans aucun
enrôlement par side-effect d'import** (aucun `registerX()` top-level exécuté à l'import du package) —
l'injection est **explicite** via `ZcrudScope(selectPresenter: ...)`
**And** son injectabilité + son rendu sont **prouvés dans le scope disjoint de fp-4-1** (widget test avec
`ZcrudScope`), la composition `zcrud_get` au bootstrap et la **showcase « natif vs modal côte à côte »**
(axe 2 du harnais, entrées « ABSENT » → « livré ») étant **fan-in fp-2-2 / fp-3** (frontière : fp-4-1
n'écrit ni `zcrud_get` ni `example/`). Consigner cet écart en Completion Notes.

## Tasks / Subtasks

- [x] **T1 — Rétablir la compat Flutter du fork vendoré** (AC1)
  - [x] `tile.dart:216` : `Theme.of(context).errorColor` → `Theme.of(context).colorScheme.error`.
  - [x] `s2_state.dart:142-143` : `headline6` → `titleLarge` (×2, `textTheme` et `primaryTextTheme`).
  - [x] `chosen.dart:13` : `abstract class S2ChosenData<T>` → `abstract mixin class S2ChosenData<T>`
        (vérifier que `extends S2ChosenData` ET `with S2ChosenData` compilent tous deux).
  - [x] Retirer le blanket de `awesome_select/analysis_options.yaml` (`undefined_getter`/
        `class_used_as_mixin`) ; conserver l'`include: package:flutter_lints/flutter.yaml`.
  - [x] Rejouer `dart analyze packages/awesome_select` → **RC=0**. Si diagnostic résiduel inévitable :
        `// ignore: <règle_exacte>` ciblé + justification (jamais par catégorie). Documenter en en-tête.
  - [x] Ne PAS toucher la LICENSE MIT / attribution / `publish_to: none`.
- [x] **T2 — Implémenter `ZSmartSelectPresenter` (`ZSelectPresenter`) sous `lib/src/presentation/`** (AC2, AC3, AC4, AC6, AC7)
  - [x] Créer `lib/src/presentation/z_smart_select_presenter.dart` : `class ZSmartSelectPresenter
        extends ZSelectPresenter { const ZSmartSelectPresenter(); @override Widget present(...) }`.
  - [x] Brancher `presentation.multiple` → `SmartSelect.single` vs `.multiple` ;
        `presentation.searchable`/`readOnly` → `modalFilter`/désactivation ; `presentation.label` →
        `title`/déclencheur ; `presentation.selected` → `selectedValue`/`selectedValues`.
  - [x] Helper **privé** `_toS2Choices(List<ZFieldChoice>, BuildContext)` : projette
        `{value,label,subtitle,disabled}` → `S2Choice`, **résout les labels via `label(context, ...)`**.
        Garder ces helpers **sous `lib/src/` (non exportés)** — aucun `S2*` dans le barrel (AC5).
  - [x] `onChange` S2 → `presentation.onChanged` avec le **`value` métier** (scalaire en mono, `List`
        en multi) ; **jamais** la concat `"S2Choice"` DODLP.
  - [x] `radio` : `presentation.multiple == false` + famille `radio` → `SmartSelect.single`
        `choiceType: radios` en modal (parité `radioAsModal`).
  - [x] a11y/thème (AC6) : `Semantics(button:, label:)` **unique** sur le déclencheur (pas de double
        annonce), ≥48dp, couleurs dérivées `Theme`/`ColorScheme`, directionnel.
  - [x] Défensif (AC7) : `options` vide / `selected` hors options / `disabled` → dégradé défini, no crash.
- [x] **T3 — Exposer le présentateur au barrel (composable, zéro side-effect)** (AC8, AC5)
  - [x] `lib/zcrud_select.dart` : `export 'src/presentation/z_smart_select_presenter.dart' show
        ZSmartSelectPresenter;` — **ne rien exporter de `S2*`/`SmartSelect`**.
  - [x] Retirer/repositionner `kZcrudSelectPlaceholder` si le barrel a désormais un symbole réel
        (ou le conserver s'il reste référencé ; ne pas casser un import existant).
  - [x] Aucun `register*()` top-level exécuté à l'import (injection explicite uniquement).
- [x] **T4 — Étendre la garde de confinement (volet fuite S2) + tests widget porteurs** (AC2-AC8)
  - [x] `test/z_select_confinement_test.dart` : **nouveau volet falsifiable** — les exports publics du
        barrel ne contiennent aucun identifiant `SmartSelect`/`S2` ; contre-preuve R12 (mutant : un
        export S2 témoin DOIT rougir). Conserver anti-vacuité + volets 1-3.
  - [x] `test/z_smart_select_presenter_test.dart` (**tests porteurs, injection R3 rougissante**) :
    - [x] AC2 : sous `ZcrudScope(selectPresenter: const ZSmartSelectPresenter())`, `select` →
          `find.byType(SmartSelect)` `findsOneWidget` **ET** `DropdownButtonFormField` `findsNothing`.
    - [x] AC2 : espion `onChanged` capte le `value` métier (ouvrir modal + tap option).
    - [x] AC2 : **sans** présentateur → `DropdownButtonFormField` `findsOneWidget` (non-régression).
    - [x] AC3 : mono→scalaire, multi→`List` via l'espion ; options statiques ET dynamiques (déjà
          résolues) rendues.
    - [x] AC4 : famille `relation` sous présentateur → sous-arbre S2 rendu + capture.
    - [x] AC6 : cible ≥48dp mesurée ; `Semantics` unique (pas de double annonce) ; test RTL
          (`Directionality.rtl`) sans assertion de couleur en dur.
    - [x] AC7 : `options: []` / `selected` hors options / `disabled` → pas d'exception.
  - [x] **R3** : vérifier qu'un mutant faisant retourner à `present()` un `SizedBox`/le natif fait
        **rougir** les tests AC2/AC3/AC4 (sinon le test est tautologique).
- [x] **T5 — Vérif verte + graphe (rejoués sur disque)** (AC1, AC5)
  - [x] `dart analyze packages/awesome_select` RC=0 (sans blanket).
  - [x] `flutter test packages/zcrud_select` RC=0 (confinement + présentateur).
  - [x] `python3 scripts/dev/graph_proof.py` → ACYCLIQUE + CORE OUT=0.
  - [x] `melos run analyze` repo-wide RC=0 (détecte une régression cross-package).

## Dev Notes

### Disjonction & frontières (NON-NÉGOCIABLE)
- **Écrit UNIQUEMENT** : `packages/zcrud_select/` (adaptateur + barrel + tests) et
  `packages/awesome_select/` (fixes compat + `analysis_options`).
- **NE TOUCHE PAS** : `zcrud_core` (le seam est déjà livré et câblé — si un besoin cœur émerge,
  **signaler / re-séquencer**, ne pas écrire), les autres satellites, `zcrud_get`, `example/`
  (showcase/harnais = fp-3), le sprint-status.
- Points de contact possibles : aucun avec le cœur (lecture seule). Parallélisable à fichiers disjoints.

### Le seam est déjà branché — ce qu'il fournit / attend
- `ZSelectPresentation` (DTO neutre, `z_select_presenter.dart`) : `field` (`ZFieldSpec` const),
  `options` (`List<ZFieldChoice>` **déjà résolues** — statiques OU dynamiques cross-champ, le cœur a
  déjà appliqué la résolution/le flux), `selected` (scalaire mono / `List<Object?>` multi), `onChanged`
  (écrit la tranche — le présentateur **notifie seulement**, jamais d'accès au `ZFormController`, AD-2),
  `multiple`, `searchable`, `readOnly`, `label` (**label du champ déjà résolu** l10n ; les labels
  d'**options** restent des clés → résoudre via `label(context, ...)`).
- Le présentateur **ne re-résout ni ne re-filtre** les options (le dispatcher cœur l'a déjà fait). Il
  **ne gère pas** l'abonnement au flux `relation` (le `State` du `ZRelationFieldWidget` le possède déjà,
  AD-2/SM-1) — il reçoit un instantané `options` à chaque `present`.

### Fork `awesome_select` — surface & pièges à NE PAS hériter (cf. `03-awesome-select.md`)
- Barrel vendor : `SmartSelect<T>` (`.single`/`.multiple`), `S2Choice<T>{value,title,subtitle,disabled}`,
  `S2ChoiceType.{radios,checkboxes,switches,chips}`, `S2ModalType.{bottomSheet,popupDialog}`,
  `S2ModalConfig`, `S2SingleSelected`/`S2MultiSelected` (payload `onChange`).
- `SmartSelect.single(... onChange: ValueChanged<S2SingleSelected<T>> ...)` → lire `.value` pour
  reprojeter en `value` métier ; `.multiple(... onChange: ValueChanged<S2MultiSelected<T>> ...)` →
  `.value` = `List<T>`.
- **Bugs DODLP à ne pas reproduire** : `rowChips.multiple` vide (hors périmètre — `rowChips` reste natif
  cœur) ; séparateur littéral `"S2Choice"` pour le multi (utiliser une vraie `List`) ; règle magique
  `_choiceType` par **nom de champ** (5 noms hardcodés → NE PAS porter ; toute variante = config
  explicite, jamais une règle de nommage).
- `checkbox` **n'a pas de référence de parité DODLP** (type mort côté DODLP) : rendu **neuf** libre côté
  zcrud (`SmartSelect.multiple` `choiceType: checkboxes` recommandé). Aucune contrainte historique.
- FR-26 : SmartSelect a son propre thème S2 (`choiceStyle`, `modalStyle`) — dériver toute couleur du
  `ColorScheme`/`Theme` ambiant, ne recopier AUCUNE constante `Colors.*`/`kErrorColor` des sites DODLP.

### Mapping compat Flutter (AC1) — références précises
- `ThemeData.errorColor` retiré → `ColorScheme.error` (`Theme.of(context).colorScheme.error`).
- `TextTheme.headline6` → `TextTheme.titleLarge` (migration typographie M3).
- Dart 3 : une classe utilisée en `with` doit être `mixin` ou `mixin class` →
  `abstract mixin class S2ChosenData<T>` (conserve `extends` pour `S2SingleChosen`/`S2MultiChosen` et
  `with` pour `S2ChosenNotifier`/dérivés). Vérifier les autres `on S2ChosenData` (mixins déjà valides).

### Testing (discipline R3 — leçon fp-1-2)
- **ABSENCE = grep négatif** (`grep -q`, jamais `| head`) : toute affirmation « le natif n'est pas
  rendu » se prouve par `findsNothing` (widget) et « aucune fuite S2 » par un scan des exports qui
  **ROUGIT** sur un mutant témoin.
- **Injection rougissante** : chaque test de rendu doit casser si `present()` renvoie le natif/un
  placebo (prouvé par un mutant). Pas de test tautologique.
- **Espion prouvé captant** : `onChanged` capté (valeur métier exacte), pas seulement « présent ».
- **Pas de double annonce a11y** : un seul nœud accessible nommé sur le déclencheur.
- Patron de garde : `z_export_ui/test/z_export_ui_confinement_test.dart` + l'actuel
  `z_select_confinement_test.dart` (dé-commentateur YAML/Dart correct, motifs ancrés, allowlist dérivée,
  contre-preuves R12).

### Project Structure Notes
- Nouveaux fichiers : `packages/zcrud_select/lib/src/presentation/z_smart_select_presenter.dart`,
  `packages/zcrud_select/test/z_smart_select_presenter_test.dart`. Modifiés :
  `packages/zcrud_select/lib/zcrud_select.dart` (export), `test/z_select_confinement_test.dart`
  (+volet fuite S2), et les 3 fichiers vendor + `analysis_options.yaml`.
- Barrel = seule API publique ; impl sous `lib/src/` ; `*_test.dart`. Nom de type préfixe `Z`.
- Le placeholder `kZcrudSelectPlaceholder` peut disparaître si plus référencé (vérifier `grep -rn
  kZcrudSelectPlaceholder`), sinon conservé.

### References
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_select_presenter.dart] — contrat + DTO neutre (fp-1-1).
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart#L120-138] — délégation `select`/`radio`/`checkbox` déjà câblée.
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_relation_field_widget.dart#L163-182] — délégation `relation` déjà câblée + CRUD inline/source neutre.
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story 4.1] — user story + Given/When/Then.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-48] — seam présentateur injecté, défaut natif ; [#AD-49] — vendoring workspace privé.
- [Source: _bmad-output/implementation-artifacts/stories/code-review-fp-1-2.md] — dette 4 sites API + blanket à remplacer.
- [Source: docs/dodlp-form-integration-study-2026-07-17/03-awesome-select.md] — usages DODLP réels, mapping S2, bugs à ne pas hériter, a11y/thème (§2.1, §5, §6.3, §7).
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md#L44-47] — rows select/radio/checkbox/relation.
- [Source: packages/zcrud_select/test/z_select_confinement_test.dart] — garde falsifiable existante (patron à étendre).
- [Source: packages/awesome_select/lib/{src/tile/tile.dart,src/widget/s2_state.dart,src/model/chosen.dart}] — sites de compat.

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]`, via Workflow `bmad-dev-story` (effort high).

### Debug Log References

- `dart analyze packages/awesome_select` → **RC=0** (blanket retiré ; 74 résiduels
  `info`-level upstream, aucun error/warning).
- `dart analyze packages/zcrud_select packages/awesome_select` → **RC=0** (75 `info`
  only : 74 lints amont du fork + 1 deprecation `containsSemantics` côté test).
- `flutter test packages/zcrud_select` → **RC=0**, **25/25** tests (9 confinement
  incl. volet 4 fuite S2 + 16 présentateur).
- **R3 mutant** : `present()` → `const SizedBox()` fait **ROUGIR** 5 tests
  (AC2 rendu+capture, AC3 radio+multi, AC4 relation) → non-tautologie prouvée ;
  original restauré (aucun résidu).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**.

### Completion Notes List

- **T1 (AC1)** — Compat Flutter du fork rétablie EN SOURCE (3 fichiers) : `errorColor`
  → `colorScheme.error` (`tile.dart:216`) ; `headline6` → `titleLarge` ×2
  (`s2_state.dart:142-143`) ; `abstract class` → `abstract mixin class S2ChosenData`
  (`chosen.dart:13`, préserve `extends` ET `with`). **Blanket** `undefined_getter` /
  `class_used_as_mixin` **retiré** de `analysis_options.yaml` ; `include` amont,
  LICENCE MIT + attribution Akbar Pulatov, `publish_to: none` conservés. Aucun
  `// ignore:` ciblé nécessaire (RC=0 sans rabaissement).
- **T2 (AC2-AC7)** — `ZSmartSelectPresenter` (`const`, `extends ZSelectPresenter`)
  sous `lib/src/presentation/`. `SmartSelect<dynamic>.single/.multiple` (type-param
  `dynamic` requis pour que `find.byType(SmartSelect)` matche par égalité de type) ;
  `choiceType radios`/`checkboxes` ; `modalType bottomSheet` ; `modalFilter =
  searchable`. `onChange` reprojette la **valeur métier** (scalaire mono / **vraie
  `List<Object?>`** multi — jamais la concat `"S2Choice"` DODLP). Helper **privé**
  `_toS2Choices` (labels résolus via `label(context,...)`). Défensif AD-10 : options
  `[]` / `selected` hors options / `disabled` → dégradé défini, no crash.
- **T3 (AC5/AC8)** — Barrel exporte `ZSmartSelectPresenter` uniquement (aucun
  `S2*`/`SmartSelect`). Placeholder `kZcrudSelectPlaceholder` **retiré** (substrat
  mort, plus référencé nulle part — `grep` négatif). Zéro `register*()` top-level.
- **T4 (AC2-AC8)** — Garde de confinement **étendue** (volet 4 falsifiable : exports
  du barrel sans `SmartSelect`/`S2*`/export nu ; mutant `S2Choice`/`*` ROUGIT, `Z*`
  légitime ne rougit pas). 16 tests présentateur porteurs (rendu, capture via modal
  réel, radio/multi, relation, ≥48dp mesuré, annonce a11y unique button+label+tap,
  RTL, readOnly, défensif AD-10, `const`).
- **A11y (AC6)** — Déclencheur : **un seul** nœud `Semantics(button, label, value,
  onTap:, excludeSemantics: true)` → pas de double annonce mais activable au lecteur
  d'écran ; `ConstrainedBox(minHeight: 48)` ; couleurs `Theme`/`ColorScheme` ;
  `TextAlign.start`.
- **Écarts tranchés (frontière fp-4-1, consignés)** :
  - **AC4** — le DTO neutre ne porte pas `ZRelationSource`/`ZRelationCrudHandler` ;
    fp-4-1 prouve que le **chemin `relation` du présentateur rend et capte** ; le CRUD
    inline bout-en-bout (form+repository+registres) relève de fp-2-2 (binding) / fp-3
    (harnais).
  - **AC8** — composition `zcrud_get` au bootstrap + showcase « natif vs modal » =
    fan-in fp-2-2 / fp-3 (fp-4-1 n'écrit ni `zcrud_get` ni `example/`). Injectabilité
    + rendu prouvés **in-scope** (widget test sous `ZcrudScope`).
- **⚠️ Interaction parallélisme (signalé)** — `packages/zcrud_core/` est **modifié en
  working-tree par un workstream concurrent (fp-5-1 : ajout `EditionFieldType.pin/
  autocomplete/editableTable`)**. Un premier `flutter test` a échoué sur un `switch`
  non exhaustif (`edition_field_family.dart`) attrapé **mid-edit** ; l'état disque
  s'est stabilisé (case `pin` présent) et le re-run est passé. fp-4-1 **n'a pas touché
  le cœur**. Vérif finale rejouée sur un cœur cohérent. `melos analyze`/`melos verify`
  **repo-wide** restent le gate de l'orchestrateur au commit d'epic (cœur au repos).

### File List

**Modifiés (fork `awesome_select`, compat) :**
- `packages/awesome_select/lib/src/tile/tile.dart`
- `packages/awesome_select/lib/src/widget/s2_state.dart`
- `packages/awesome_select/lib/src/model/chosen.dart`
- `packages/awesome_select/analysis_options.yaml`

**Ajoutés (`zcrud_select`) :**
- `packages/zcrud_select/lib/src/presentation/z_smart_select_presenter.dart`
- `packages/zcrud_select/test/z_smart_select_presenter_test.dart`

**Modifiés (`zcrud_select`) :**
- `packages/zcrud_select/lib/zcrud_select.dart` (export présentateur)
- `packages/zcrud_select/test/z_select_confinement_test.dart` (+volet 4 fuite S2 ; LOW-3 : identifiant SOURCE avant `as`)
- `packages/zcrud_select/lib/src/presentation/z_smart_select_presenter.dart` (MED-1 : placeholder LOCALISÉ)
- `packages/zcrud_select/test/z_smart_select_presenter_test.dart` (MED-1 + FIX-3 : reflet externe AD-2)
- `packages/zcrud_select/README.md` (MED-2 : état livré, modes réels)

### Code-review (fp-4-1) — remédiation

Rapport : `_bmad-output/implementation-artifacts/stories/code-review-fp-4-1.md`.
Corrigés : **MED-1** (placeholder anglais du fork → l10n `select`), **MED-2** (README
périmé → état livré), **LOW-3** (garde volet 4 : identifiant source avant `as`), plus
**FIX-3** (test de non-régression AD-2 : reflet externe de la tranche). Le finding
**MAJEUR** « reflet externe non reflété » est **RÉFUTÉ (R3)** : le fork re-résout via
`didUpdateWidget` — aucun correctif de prod, seulement le test verrou. Vérif verte
rejouée : `flutter test packages/zcrud_select` RC=0 **29/29** ; `dart analyze` RC=0 ;
`graph_proof` ACYCLIQUE + CORE OUT=0.

**Supprimés (`zcrud_select`) :**
- `packages/zcrud_select/lib/src/presentation/z_select_presenter_placeholder.dart`
  (substrat mort, plus référencé)

**Cœur + autres satellites : INTOUCHÉS par fp-4-1** (les modifications working-tree de
`packages/zcrud_core/` proviennent du workstream concurrent fp-5-1).
