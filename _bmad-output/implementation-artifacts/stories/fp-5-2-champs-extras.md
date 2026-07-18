# Story 5.2: Champs extras complets (`zcrud_field_extras`) — PIN / autocomplétion / table éditable (+ tags riches SIGNALÉ)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur consommateur de zcrud**,
I want **des widgets d'édition RICHES pour les types de Finitions déjà nommés+routés au cœur par fp-5-1 — `pin` (`pinput`), `autocomplete` (autocomplétion) et `editableTable` (table éditable virtualisée) — servis par `ZWidgetRegistry` depuis le satellite `zcrud_field_extras`, enrôlés par une fonction d'auto-enregistrement (patron `zcrud_intl`/`zcrud_media`), avec les dépendances lourdes CONFINÉES au satellite et la garde de confinement mise à jour**,
so that **je couvre les gaps net-new « hors-enum » de DODLP (PIN/OTP, autocomplétion, table inline) sans qu'aucun type nouveau ne fasse crasher un formulaire, tout en préservant CORE OUT=0 (le cœur ne tire AUCUNE dépendance lourde) et SM-1 (seul le champ courant se reconstruit).**

**Marquage :** `[Finitions]` · **parallélisable** (satellite `zcrud_field_extras`, fichiers DISJOINTS du cœur et des autres satellites) · Binds **FR-34** (PIN), **FR-35** (autocomplete), **FR-36** (table éditable) ; **AD-53** (satellite champs spécialisés) ; hérités **AD-1** (CORE OUT=0, graphe acyclique), **AD-2/AD-15** (SM-1, réactivité Flutter-native), **AD-10** (désérialisation/parse défensif), **AD-13** (a11y ≥ 48 dp, RTL directionnel, `ListView.builder`), **FR-26** (thème/l10n injectés, zéro couleur/libellé codé en dur) ; NFR-1/2/3/4/9 ; OQ-6. **Contribue** FR-40 (types couverts) — mais **le showcase/harnais `example/` est HORS périmètre de cette story** (cf. §Frontières).

## Contexte & nature de l'itération

fp-5-1 (`done` côté cœur, statut `review`) a livré au cœur, **purement additivement**, les valeurs d'enum `EditionFieldType.pin` / `autocomplete` / `editableTable`, **routées vers `EditionFamily.registryOrFallback`** (aucune nouvelle famille, aucun widget natif). Conséquence prouvée sur disque : sans registre injecté, un champ de ces 3 types **dégrade proprement** en `ZUnsupportedFieldWidget` (jamais un crash). Le dispatcher cœur `ZFieldWidget._dispatchRegistry` appelle `registry.tryBuilderFor(field.type.name)` — donc le `kind` d'enrôlement est **exactement `field.type.name`** (`'pin'` / `'autocomplete'` / `'editableTable'`).

**fp-5-2 est l'IMPL riche satellite** : elle écrit UNIQUEMENT dans `packages/zcrud_field_extras/` (squelette livré par fp-1-2 : barrel + `lib/src/{domain,data,presentation}` + garde de confinement + placeholder). Elle **N'écrit ni le cœur, ni un autre satellite, ni le showcase**. Le patron exact est celui de `zcrud_media` (fp-4-2) et `zcrud_intl` : un ou plusieurs `ZFieldWidgetBuilder` + une fonction top-level `registerZFieldExtrasFields(registry, …)` qui `registry.register(kind, builder)` sous `kind == EditionFieldType.<type>.name`.

[Source: stories/fp-5-1-additions-coeur-finitions.md#AC-A2 · #AC-A3 ; edition_field_family.dart:200-220 ; z_field_widget.dart:608-712 ; z_widget_registry.dart:71-108 ; docs/dodlp-form-integration-study-2026-07-17/11-field-specialized-inputs.md ; docs/…/FIELD-PACKAGE-MATRIX.md]

### ⚠️ DEUX SIGNAUX STRUCTURANTS (à relire AVANT dev)

**SIGNAL 1 — `editableTable` : PERSISTANCE non supportée (limite préexistante du générateur, D1).**
La valeur d'`editableTable` est `List<Map<String,dynamic>>`. fp-5-1 a **découvert sur disque** (build_runner rejoué) que le générateur EXISTANT lève `InvalidGenerationSourceError` sur un élément `Map` (`_classify` récurse sur `Map`, aucune branche) — la prémisse initiale « `List<Map>` round-trippe via `listScalar` » est **FAUSSE**. Le champ `tableValue` a donc été **retiré** du corpus de fp-5-1. **Conséquence pour fp-5-2** : le widget de table éditable **fonctionne en RUNTIME** (valeur `List<Map>` détenue en mémoire dans la tranche, éditée en place, écrite via `onChanged → setValue`), mais **un `@ZcrudModel` portant un champ `List<Map<String,dynamic>>` typé `editableTable` NE round-trippe PAS** via le générateur. La persistance passe par un **type de valeur dédié + codec** = **SUIVI hors fp-5-2** (à trancher : nouvelle story cœur/générateur). fp-5-2 livre donc `editableTable` **runtime-only** et **documente** cette limite dans le doc-comment du widget + les notes de complétion. **Ne PAS** tenter de contourner en touchant le générateur (hors périmètre, cœur disjoint).

**SIGNAL 2 — « tags riches » : NON dispatcher-atteignable sans changement cœur → REDONDANT avec fp-5-1, ESCALADÉ.**
Le brief d'orchestration liste un 4ᵉ widget « tags riches (`flutter_tags` : toggle/icône/reorder au-delà de l'`InputChip` natif) ». Vérifié sur disque, ce livrable **se heurte à trois faits** :
1. **Non-atteignable par le VRAI dispatcher.** `EditionFieldType.tags` est routé par `familyOf` vers `EditionFamily.tags` → `ZTagsFieldWidget` **natif du cœur** — **PAS** `registryOrFallback`. Un builder enregistré sous `kind == 'tags'` ne serait **JAMAIS** appelé par `ZFieldWidget` (seuls les types en `registryOrFallback` passent par `_dispatchRegistry`). C'est du **code mort** au regard du dispatcher — exactement le défaut que la leçon fp-4-2 interdit (tester via `builderFor` direct masquerait le fait que le dispatcher ne l'atteint pas). [Preuve : edition_field_family.dart:153-154 (`case tags → EditionFamily.tags`) ; z_field_widget.dart:549-554 (`case EditionFamily.tags → ZTagsFieldWidget`).]
2. **Déjà couvert nativement, zéro dépendance, par fp-5-1.** Le besoin « tag + icône + toggle » (variante `subItems.itemsAreTags` de DODLP) est livré par `ZSubListDisplayMode.tags` (`InputChip`, zéro dép) dans fp-5-1. [Source: fp-5-1#Bloc-B ; FIELD-PACKAGE-MATRIX.md row 15b / P4.]
3. **L'étude REJETTE explicitement `flutter_tags`.** La matrice recommande de reproduire le rendu avec `ChoiceChip`/`InputChip` Material (zéro dép) **plutôt qu'adopter `flutter_tags`** ; `drag_and_drop_lists` est **mort** (0 call-site dans `data_crud`). [Source: FIELD-PACKAGE-MATRIX.md:49-50, 82-84, 131-134 ; 12-field-tags-chips-calendar-reorder.md:61-68, 86-124.]

**Décision de cadrage (fp-5-2)** : la story ne câble PAS de builder sous `kind == 'tags'` (dead code) et **n'ajoute PAS `flutter_tags`/`drag_and_drop_lists`** (l'étude les rejette). Une « tags riches » dispatcher-atteignable exigerait **un NOUVEAU type d'enum cœur** (ex. `richTags`) routé vers `registryOrFallback` — c'est un **changement `zcrud_core`, HORS périmètre satellite de fp-5-2** (disjonction cœur). **BESOIN CŒUR → SIGNALÉ** : l'orchestrateur doit trancher (a) laisser fp-5-1 `itemsAreTags` couvrir le besoin (recommandé, zéro dép), ou (b) ouvrir une story cœur `richTags` + widget satellite suivant. AC-D formalise ce signal sans écrire de dead code.

## Acceptance Criteria

### Bloc A — Widget PIN (`pin`, `pinput`) — FR-34

**AC-A1 — Builder `pin` servi par le registre, kind aligné.** `zcrud_field_extras` expose un `ZFieldWidgetBuilder` de PIN et l'enregistre via `registerZFieldExtrasFields(registry, …)` sous `kind == EditionFieldType.pin.name` (`'pin'`). Un test **d'alignement** prouve `<kindConst> == EditionFieldType.pin.name` (jamais un littéral `'pin'` codé en dur non ancré à l'enum — cf. patron `mediaImageFieldKind == EditionFieldType.mediaImage.name`).

**AC-A2 — Atteignable par le VRAI dispatcher (PAS `builderFor` direct — leçon fp-4-2).** Monté via `ZcrudScope(widgetRegistry: reg)` autour d'un `ZFieldWidget`/`DynamicEdition` avec un `ZFieldSpec(type: EditionFieldType.pin)`, après `registerZFieldExtrasFields(reg)`, le champ rend le widget PIN riche (cellules de saisie segmentées). Le test emprunte le **chemin d'intégration réel** (`ZFieldWidget` → `familyOf(pin)==registryOrFallback` → `_dispatchRegistry` → `tryBuilderFor('pin')`), **jamais** `reg.builderFor('pin')` en appel direct. **FALSIFIABLE (R3)** : SANS `registerZFieldExtrasFields` (registre vide) OU sans `ZcrudScope`, le même montage retombe sur `ZUnsupportedFieldWidget` (`findsOneWidget`) — un misrouting rougirait.

**AC-A3 — a11y : cellules ≥ 48 dp + `Semantics` de progression.** Chaque cellule de saisie du PIN a une cible tactile ≥ 48 dp (AD-13). Le champ porte une `Semantics` de **progression** (ex. « n sur N chiffres saisis ») **sans double annonce** (le label n'est pas répété par une `Semantics` redondante enveloppante). Test : `tester.getSize` ≥ 48×48 sur une cellule ; `Semantics` de progression présente et **unique** (pas deux nœuds annonçant la même chose). Reduce Motion respecté si `pinput` anime le curseur/complétion.

**AC-A4 — SM-1 / value-in-slice (AD-2).** Le builder LIT `ctx.value` (String) et ÉCRIT via `ctx.onChanged` — l'appel reste **dans** la frontière de rebuild du dispatcher (`ZFieldListenableBuilder`, value-in-slice). Aucun `setState` d'écran, aucun `ZFormController` capturé, aucun `TextEditingController` recréé au rebuild (s'il en faut un, alloué 1× dans un `State` et disposé). Test SM-1 : sur un formulaire de 2 champs (PIN + texte voisin), saisir dans le voisin ne reconstruit pas le PIN (compteur de build de tranche stable).

**AC-A5 — Valeur neutre `String`, parse défensif (AD-10).** La valeur de tranche est un `String` neutre (AD-53) ; une valeur externe non-`String`/`null`/corrompue **ne crashe jamais** le widget (repli propre : champ vide). FR-26 : couleurs/thème du `pinput` dérivés du `Theme.of(context)`/`ZcrudTheme` injecté, **aucune couleur codée en dur**.

### Bloc B — Widget autocomplétion (`autocomplete`) — FR-35

**AC-B1 — Builder `autocomplete` servi par le registre, kind aligné, atteignable via le VRAI dispatcher.** Comme AC-A1/AC-A2 mais pour `kind == EditionFieldType.autocomplete.name` (`'autocomplete'`). Montage réel `ZFieldWidget`(type `autocomplete`) + `ZcrudScope` + `registerZFieldExtrasFields` → rend le champ autocomplété ; registre vide → `ZUnsupportedFieldWidget` (R3).

**AC-B2 — Suggestions filtrées, SM-1 tenu.** Le widget affiche des suggestions filtrées selon la saisie. **SEUL le champ courant se reconstruit** à la frappe (AD-2/SM-1) : la liste d'options est fournie de façon stable (via `field.choices`/`field.config`, mémoïsée), le champ voisin n'est jamais reconstruit. Test : taper dans le champ autocomplete filtre les suggestions ; un champ voisin conserve son compteur de build (SM-1).

**AC-B3 — Implémentation Flutter-native `Autocomplete` privilégiée (zéro dép lourde), l'étude le confirme.** L'étude établit que DODLP utilise le **widget natif Flutter `Autocomplete<String>`** (pas `autocomplete_textfield`, jugé non-portable) et que `autocomplete` **n'est pas** un type moteur `data_crud`. **Décision fp-5-2** : implémenter via `Autocomplete`/`RawAutocomplete` du SDK Flutter (**aucune dépendance lourde ajoutée**) sauf justification contraire écrite en dev-story. Valeur de tranche neutre `String` (AD-53), parse défensif (AD-10). a11y : champ texte ≥ 48 dp, options directionnelles (RTL), `Semantics` sans double annonce. [Source: 11-field-specialized-inputs.md:74-127.]

### Bloc C — Widget table éditable (`editableTable`) — FR-36

**AC-C1 — Builder `editableTable` servi par le registre, kind aligné, atteignable via le VRAI dispatcher.** Comme AC-A1/AC-A2 mais pour `kind == EditionFieldType.editableTable.name` (`'editableTable'`). Montage réel + registre vide → repli `ZUnsupportedFieldWidget` (R3).

**AC-C2 — Table VIRTUALISÉE (`ListView.builder`), cellules éditables en place.** Les lignes sont rendues par `ListView.builder` (**jamais** `ListView(children:[...])` — AD-13/Key Don't). Les cellules sont éditables en place ; ajouter/supprimer une ligne écrit la nouvelle `List<Map<String,dynamic>>` via `ctx.onChanged → setValue`. Test : présence d'un `ListView.builder` (grep négatif sur `ListView(children:` dans le fichier widget) ; édition d'une cellule met à jour la valeur de tranche.

**AC-C3 — Valeur `List<Map>` à parse DÉFENSIF (AD-10) + limite de persistance DOCUMENTÉE (SIGNAL 1).** Le widget lit `ctx.value` en `List<Map<String,dynamic>>` de façon **défensive** : `null`, non-`List`, éléments non-`Map` ⇒ repli sur table vide, **jamais** un crash. Le doc-comment du widget **DOIT** énoncer explicitement : « valeur runtime uniquement ; la persistance via `@ZcrudModel` d'un champ `List<Map<String,dynamic>>` n'est PAS supportée par le générateur (limite préexistante fp-5-1) — suivi : type de valeur dédié + codec ». Test : corpus corrompu (`null`/`'x'`/`[{...}, 42]`) → widget survit, table dérivée cohérente.

**AC-C4 — SM-1 / value-in-slice, FR-26.** Value-in-slice (lit `ctx.value`, écrit `ctx.onChanged`), aucune souscription élargie, aucun `ZFormController`. Styles/bordures/entêtes dérivés du thème injecté (FR-26), aucune couleur codée en dur. Cibles d'action (ajouter/supprimer ligne) ≥ 48 dp (AD-13), icônes avec `Semantics`/tooltip localisable.

### Bloc D — « Tags riches » : SIGNAL cœur (aucun dead code, aucune dép rejetée)

**AC-D1 — Aucun câblage `kind == 'tags'`, aucune dép `flutter_tags`/`drag_and_drop_lists`.** fp-5-2 **N'enregistre PAS** de builder sous `kind == 'tags'` (non-atteignable par le dispatcher, cf. SIGNAL 2) et **N'ajoute PAS** `flutter_tags` ni `drag_and_drop_lists` au pubspec (rejetés par l'étude ; morts dans DODLP). Preuve : la garde de confinement (AC-E) tient avec une allowlist qui **n'inclut ni `flutter_tags` ni `drag_and_drop_lists`** ; grep négatif `flutter_tags`/`drag_and_drop_lists` sur `packages/zcrud_field_extras/` (RC=1).

**AC-D2 — Signal documenté + escalade.** Une note (doc-comment du barrel + §Completion Notes) énonce : « tags riches (toggle/icône/reorder au-delà de l'`InputChip` natif) NON livrable en satellite pur : `EditionFieldType.tags` route vers la famille native `tags` (pas `registryOrFallback`) ⇒ un `kind == 'tags'` serait du code mort ; le besoin est déjà couvert zéro-dép par `ZSubListDisplayMode.tags` (fp-5-1). Un chemin dispatcher-atteignable exigerait un NOUVEAU type d'enum cœur (`richTags`) routé `registryOrFallback` = story cœur ultérieure. Décision owner requise. » Aucun code produit pour ce point (signal only).

### Bloc E — Confinement, isolation, gates

**AC-E1 — Dépendances CONFINÉES + garde de confinement MISE À JOUR (falsifiable).** Les seules dépendances lourdes ajoutées à `packages/zcrud_field_extras/pubspec.yaml` sont celles réellement utilisées par les widgets livrés — a minima **`pinput`** (PIN) ; `autocomplete` et `editableTable` restent **SDK-only** (aucune dép) sauf justification écrite en dev-story. Le test de confinement `test/z_field_extras_confinement_test.dart` est **mis à jour** : `_allowedDeps`/`_allowedImportPkgs` deviennent une allowlist **DÉRIVÉE EXACTE** (`{flutter, zcrud_core} ∪ {deps réellement ajoutées}`) — patron `z_media_confinement_test.dart` (allowlist dérivée `{flutter, zcrud_core} ∪ _mediaDeps`). Les deux volets (pubspec ⊆ allowlist ; imports `lib/**` ⊆ allowlist ∪ self) + les contre-preuves **R12 mutantes** restent verts. Une dép hors allowlist (ex. `flutter_tags`) **DOIT** faire rougir la garde.

**AC-E2 — CORE OUT=0 préservé, graphe acyclique.** `python3 scripts/dev/graph_proof.py` RC=0 : `zcrud_field_extras` a pour **seule** arête `zcrud_*` sortante `zcrud_core` (les deps lourdes ne sont pas des `zcrud_*` → n'ajoutent aucune arête au graph_proof). `zcrud_core/pubspec.yaml` **inchangé** (grep négatif `pinput`/`flutter_tags`/… RC=1) — aucune fuite dans le cœur (AD-1/AD-53).

**AC-E3 — Barrel + enrôlement unique + vérif verte repo-wide.** Le barrel `lib/zcrud_field_extras.dart` exporte les widgets publics + `registerZFieldExtrasFields` (et retire/complète le placeholder `kZcrudFieldExtrasPlaceholder` selon besoin, sans casser un import existant). `registerZFieldExtrasFields` enrôle chaque `kind` **une seule fois** (collision → `ZDuplicateRegistrationError`, jamais un last-wins silencieux) : un test prouve qu'un double appel sur le même registre throw (patron `ZWidgetRegistry.register`). Vérif verte : `dart run melos run generate` OK (aucun `*.g.dart` de `packages/*/lib/` ne change ; s'il en change, régénéré ET commité — gate `codegen-distribution`) ; `melos run analyze` **repo-wide** RC=0 ; `flutter test packages/zcrud_field_extras` RC=0 ; gates `secrets`/`codegen-distribution`/`graph_proof` verts.

## Tasks / Subtasks

- [x] **T1 — Dépendances & garde de confinement** (AC: E1, E2, D1)
  - [x] T1.1 `pinput: ^6.0.0` ajouté (SEULE dép lourde) ; `flutter_tags`/`drag_and_drop_lists`/`autocomplete_textfield`/`editable` NON ajoutés. `dart pub get` OK (pinput 6.0.2 résolu).
  - [x] T1.2 `test/z_field_extras_confinement_test.dart` : allowlist **dérivée exacte** `{flutter, zcrud_core} ∪ _extrasDeps` (`_extrasDeps = {pinput}`) ; R12 mutantes conservées ; intrus témoin devenu `flutter_tags` (rougit).
  - [x] T1.3 `graph_proof.py` RC=0 (CORE OUT=0, arête `zcrud_field_extras → zcrud_core` unique) ; grep négatif deps lourdes dans `zcrud_core/pubspec.yaml` RC=1.
- [x] **T2 — Widget PIN (`pinput`)** (AC: A1..A5)
  - [x] T2.1 `lib/src/presentation/z_pin_field_widget.dart` : PIN `pinput` (cellules ≥ 48 dp `kZPinCellMinSize`, `Semantics` progression unique, value-in-slice `String`, controller alloué 1×/disposé, parse défensif, PinTheme dérivé du `ColorScheme`, Reduce Motion honoré).
  - [x] T2.2 `pinFieldKind` (final) ancré à `EditionFieldType.pin.name`.
- [x] **T3 — Widget autocomplétion (SDK `Autocomplete`)** (AC: B1..B3)
  - [x] T3.1 `lib/src/presentation/z_autocomplete_field_widget.dart` : `Autocomplete<String>` natif (zéro dép), options stables depuis `field.choices`, value-in-slice `String`, options `ListView.builder` directionnelles ≥ 48 dp.
- [x] **T4 — Widget table éditable virtualisée** (AC: C1..C4)
  - [x] T4.1 `lib/src/presentation/z_editable_table_field_widget.dart` : `ListView.builder`, cellules `TextFormField` à clé stable, `List<Map>` défensif (`zParseTableRows`), doc-comment **limite de persistance (SIGNAL 1)**, actions ajouter/supprimer ≥ 48 dp.
- [x] **T5 — Enrôlement + barrel** (AC: A1, B1, C1, E3)
  - [x] T5.1 `lib/src/presentation/z_field_extras_registrar.dart` : `registerZFieldExtrasFields(registry, {onBuild})` → `register('pin'/'autocomplete'/'editableTable')`.
  - [x] T5.2 `lib/zcrud_field_extras.dart` : exports widgets + `registerZFieldExtrasFields` + constantes `kind` + helpers ; SIGNAL 1 & 2 documentés ; placeholder retiré proprement (0 référence).
- [x] **T6 — Tests porteurs (via le VRAI dispatcher, injection R3)** (AC: A2, A3, A4, B1, B2, C1, C2, C3, E3)
  - [x] T6.1 Helper `_mount(controller, fields, registry)` : `ZcrudScope(widgetRegistry)` → `DynamicEdition` → `ZFieldWidget` (vrai dispatcher, PAS `builderFor` direct).
  - [x] T6.2 Alignement des 3 `kind` sur `EditionFieldType.<type>.name`.
  - [x] T6.3 Chaque type : enrôlé+monté → widget riche ; registre vide / pas de scope → `ZUnsupportedFieldWidget` (R3).
  - [x] T6.4 a11y PIN (≥ 48 dp + progression unique) ; SM-1 (voisin ne reconstruit pas) ; table `ListView.builder` (grep négatif code-only) ; parse défensif (corpus corrompu) ; double-enrôlement → `ZDuplicateRegistrationError`.
- [x] **T7 — Vérif verte & signaux** (AC: E3, D2, C3)
  - [x] T7.1 `dart analyze packages/zcrud_field_extras` RC=0 ; `flutter test packages/zcrud_field_extras` RC=0 (23) ; graph_proof RC=0. (Aucun `@ZcrudModel` réel → aucun `*.g.dart` ; `melos generate` repo-wide = gate orchestrateur.)
  - [x] T7.2 SIGNAL 1 (persistance `editableTable` runtime-only) + SIGNAL 2 (tags escaladé, décision owner) consignés en §Completion Notes.

## Dev Notes

### Patrons EXISTANTS à imiter (vérifiés sur disque)

- **Registre & dispatch cœur** — `ZWidgetRegistry.register(kind, builder)` throw `ZDuplicateRegistrationError` sur collision (`z_widget_registry.dart:82-87`) ; `tryBuilderFor(kind)` défensif (`:107`). Le dispatcher route `pin`/`autocomplete`/`editableTable` via `familyOf → registryOrFallback` (`edition_field_family.dart:206-208, 220`) puis `_dispatchRegistry` appelle `registry.tryBuilderFor(field.type.name)` (`z_field_widget.dart:694-712`). **Le `kind` d'enrôlement = `field.type.name` EXACT**, sinon le repli s'active. [Source: z_widget_registry.dart ; z_field_widget.dart ; edition_field_family.dart]
- **Fonction d'enrôlement satellite** — `registerZMediaFieldWidgets(registry, picker:…)` enregistre 3 kinds `mediaImage`/`mediaFile`/`mediaVideo` (`z_media_field_widget.dart:81-113`), exportée par le barrel (`zcrud_media.dart:53`). Autres patrons : `registerZHtmlFields`, `registerZMarkdownFields`, `registerZAddressFieldWidgets`. Nommer `registerZFieldExtrasFields` (cf. epics Story 5.2 second Given). [Source: zcrud_media, zcrud_html, zcrud_intl]
- **Test via le VRAI dispatcher (leçon fp-4-2, NON-NÉGOCIABLE)** — `z_media_field_widget_test.dart` monte `ZcrudScope(widgetRegistry: reg)` → `ZFieldWidget(type: EditionFieldType.mediaImage)` et vérifie le rendu APRÈS `registerZMediaFieldWidgets(reg)`, et le **repli** `ZUnsupportedFieldWidget` sans scope/registre. **NE PAS** tester `reg.builderFor(kind)` en direct : un builder atteignable en direct mais NON routé par le dispatcher passerait vert à tort (défaut « présence ≠ association »). [Source: z_media_field_widget_test.dart:107-135, 186-207]
- **Garde de confinement dérivée** — `z_media_confinement_test.dart` : `_allowedDeps = {flutter, zcrud_core} ∪ _mediaDeps` (EXACT), volet imports = `_allowedDeps ∪ {self}`, contre-preuves R12 mutantes. Le squelette actuel `z_field_extras_confinement_test.dart` a une allowlist **codée en dur** `{flutter, zcrud_core}` + intrus témoin `pinput` : la faire évoluer vers `{flutter, zcrud_core, pinput, …}` (dérivée), et **conserver** un mutant prouvant qu'une dép hors allowlist rougit. [Source: z_media_confinement_test.dart ; z_field_extras_confinement_test.dart]

### Fichiers visés (récap — TOUS sous `packages/zcrud_field_extras/`)

- `pubspec.yaml` (deps confinées : `pinput` a minima) — UPDATE.
- `lib/zcrud_field_extras.dart` (barrel : exports + `registerZFieldExtrasFields` + note SIGNAL 2) — UPDATE.
- `lib/src/presentation/z_pin_field_widget.dart` — NEW.
- `lib/src/presentation/z_autocomplete_field_widget.dart` — NEW.
- `lib/src/presentation/z_editable_table_field_widget.dart` — NEW.
- `lib/src/presentation/z_field_extras_registrar.dart` (enrôlement) — NEW (ou intégré à un widget).
- `lib/src/presentation/z_field_extras_placeholder.dart` — conserver/retirer proprement (ne pas casser un import).
- `test/z_field_extras_confinement_test.dart` — UPDATE (allowlist dérivée).
- `test/z_field_extras_field_widget_test.dart` — NEW (dispatcher réel + a11y + SM-1 + défensif).

### Invariants applicables (rappel)

- **AD-1 / CORE OUT=0** : deps lourdes UNIQUEMENT dans `zcrud_field_extras` ; jamais dans `zcrud_core` ; graphe acyclique (arête `zcrud_*` sortante = `zcrud_core` seule). Prouvé par `graph_proof.py` + garde de confinement + grep négatif sur le cœur.
- **AD-2 / AD-15 / SM-1** : value-in-slice (`ctx.value`/`ctx.onChanged`), aucune souscription élargie, aucun `TextEditingController` recréé au rebuild, aucun `setState` d'écran, aucun `ZFormController` capturé par un widget satellite.
- **AD-10** : parse défensif de toute valeur de tranche (String / List<Map>) — jamais un crash sur valeur corrompue ; schéma additif seulement.
- **AD-13** : cibles ≥ 48 dp, `Semantics` explicites **sans double annonce**, variantes directionnelles (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), `ListView.builder`, Reduce Motion.
- **FR-26** : thème/l10n injectés (`ZcrudScope`/`ThemeExtension`, repli `Theme.of(context)`) ; **aucune** couleur/libellé codé en dur.

### Anti-pièges (défauts à ne pas commettre)

- **Présence ≠ association** : un widget exporté/enregistrable ne prouve rien tant que le **dispatcher réel** ne le rend pas pour le `type` correspondant. Test obligatoire via `ZFieldWidget`+`ZcrudScope`, pas `builderFor` direct.
- **La prose ment** : toute affirmation d'« absence » (ex. « aucune dép `flutter_tags` ») doit être un **grep négatif** joué, pas une assertion.
- **Double annonce a11y** : ne pas envelopper le PIN d'une `Semantics` de label + une `Semantics` de progression qui répètent la même info.
- **`kind` codé en dur** : ancrer les constantes de `kind` à `EditionFieldType.<type>.name` (test d'alignement), sinon un renommage d'enum casserait le routage silencieusement.
- **Toucher le cœur/générateur** : INTERDIT (disjonction). La limite `editableTable`/persistance se **documente et s'escalade**, ne se contourne pas ici.

### Project Structure Notes

- Story STRICTEMENT confinée à `packages/zcrud_field_extras/`. Aucune écriture cœur, aucun autre satellite, aucun `example/`/showcase (le showcase FR-40 est explicitement HORS périmètre de cette story — cf. Frontières). Repos d'app (DODLP) = LECTURE SEULE.
- Deux besoins cœur SIGNALÉS (non écrits ici) : (1) codec/type de valeur pour `editableTable` persistant ; (2) type d'enum `richTags` (`registryOrFallback`) si « tags riches » dispatcher-atteignable est retenu.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story-5.2 (lignes 603-627) ; #FR-34/35/36/37 (84-87)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-53]
- [Source: _bmad-output/implementation-artifacts/stories/fp-5-1-additions-coeur-finitions.md#AC-A2 · #AC-A3 (limite List<Map>) · #Bloc-B (itemsAreTags)]
- [Source: packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart:130-154 (pin/autocomplete/editableTable) ; :85-89 (tags/subItems)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart:153-154, 200-220 (routage) ; z_field_widget.dart:549-554 (tags natif) · :608-712 (registryOrFallback/_dispatchRegistry)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart:71-108]
- [Source: packages/zcrud_media/lib/src/presentation/z_media_field_widget.dart:81-113 ; packages/zcrud_media/test/z_media_field_widget_test.dart:107-207 (patron dispatcher réel + R3) ; packages/zcrud_media/test/z_media_confinement_test.dart (allowlist dérivée)]
- [Source: packages/zcrud_intl/lib/zcrud_intl.dart (patron barrel + widgets registre)]
- [Source: docs/dodlp-form-integration-study-2026-07-17/11-field-specialized-inputs.md (pinput mort ; Autocomplete natif privilégié ; editable mort) ; 12-field-tags-chips-calendar-reorder.md:61-124 (flutter_tags/drag_and_drop rejetés) ; FIELD-PACKAGE-MATRIX.md:49-50, 82-85, 105, 131-134]
- [Source: packages/zcrud_field_extras/pubspec.yaml ; lib/zcrud_field_extras.dart ; test/z_field_extras_confinement_test.dart (squelette fp-1-2)]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `claude-opus-4-8[1m]` (skill `bmad-dev-story`).

### Debug Log References

- `dart pub get` OK — `pinput 6.0.2` résolu (contrainte `^6.0.0`, cache local).
- `dart analyze packages/zcrud_field_extras` → RC=0, « No issues found! ».
- `flutter test packages/zcrud_field_extras` → RC=0, **23 tests** verts (widget + confinement).
- `python3 scripts/dev/graph_proof.py` → RC=0, ACYCLIQUE + CORE OUT=0, arête `zcrud_field_extras → zcrud_core` **unique**.
- Correctif test unique : le grep-négatif `ListView(children:` matchait le doc-comment → filtré aux lignes de **code** (strip `//`/`*`).
- **Remédiation code-review fp-5-2 (2026-07-18)** : `flutter test packages/zcrud_field_extras` → RC=0, **26 tests** (23 + 3 red-before : MED-1 table resync, LOW autocomplete resync, MED-3 double-annonce ; MED-2 renforcé in place). `dart analyze` RC=0. `graph_proof.py` RC=0 (ACYCLIQUE, CORE OUT=0). Falsifiabilité MED-2 prouvée par mutation `: ''` → `: v.toString()` ⇒ le test renforcé rougit (« 0 / 4 » attendu, « 2 / 4 » obtenu), revert appliqué. Rapport : `code-review-fp-5-2.md`.

### Completion Notes List

**Périmètre livré (décision orchestrateur)** : PIN + autocomplétion + table éditable UNIQUEMENT. « tags riches » et « icon » NON livrés (consignés OQ-6 / SIGNAL 2 ci-dessous).

**Widgets (tous sous `packages/zcrud_field_extras/`, cœur/binding/autres satellites INTOUCHÉS)** :
- `ZPinFieldWidget` (`pinput`, kind `pin`) — cellules ≥ 48 dp, `Semantics` de progression unique, value-in-slice `String`, controller alloué 1×/disposé (AD-2), PinTheme dérivé du `ColorScheme` (FR-26), Reduce Motion (`PinAnimationType.none` si `disableAnimations`), parse défensif (non-`String` ⇒ vide, AD-10).
- `ZAutocompleteFieldWidget` (`RawAutocomplete<String>` **natif Flutter, zéro dép**, kind `autocomplete`) — options stables depuis `field.choices`, filtrage à la saisie, TextField ≥ 48 dp, options `ListView.builder` directionnelles. **Post-review** : StatefulWidget détenant `TextEditingController`/`FocusNode` (alloués 1×/disposés) fournis à `RawAutocomplete`, re-sync `didUpdateWidget` sur ré-injection externe (LOW) ; `excludeSemantics:true` sur l'option (MED-3, plus de double annonce).
- `ZEditableTableFieldWidget` (kind `editableTable`) — `ListView.builder` (jamais `ListView(children:)`), `TextFormField` à clé stable, ajout/suppression de ligne ≥ 48 dp, `List<Map>` défensif (`zParseTableRows`). **Post-review** : contrôleurs de cellule gérés (map `cell-<rowKey>-<col>`, alloués 1×, élagués+disposés à la suppression de ligne/colonne, disposés au démontage) + re-sync `didUpdateWidget` sur ré-injection externe d'une cellule existante (MED-1) ; SM-1 préservé (jamais recréés au rebuild).
- `registerZFieldExtrasFields(registry, {onBuild})` enrôle les 3 `kind` (= noms d'enum) ; double appel → `ZDuplicateRegistrationError`.

**Enrôlement atteignable prouvé via le VRAI dispatcher** (`ZcrudScope(widgetRegistry)` → `DynamicEdition`/`ZFieldWidget` → `registryOrFallback` → `tryBuilderFor(type.name)`), jamais `builderFor` direct (leçon fp-4-2). Falsifiable : registre vide / pas de scope → `ZUnsupportedFieldWidget`.

**SIGNAL 1 — persistance `editableTable` (SUIVI hors fp-5-2)** : la valeur est `List<Map<String,dynamic>>`. Le widget est **runtime-only** ; la persistance via `@ZcrudModel` d'un tel champ N'EST PAS supportée par le générateur (limite préexistante fp-5-1 : `InvalidGenerationSourceError` sur élément `Map`). Suivi = type de valeur dédié + codec (story cœur/générateur). Documenté dans le doc-comment du widget + barrel. Non contourné (cœur disjoint).

**SIGNAL 2 — « tags riches » escaladé (décision owner requise, AC-D)** : `EditionFieldType.tags` route vers la famille NATIVE `tags` (pas `registryOrFallback`) ⇒ un `kind == 'tags'` serait du **code mort** ; aucun câblé. `flutter_tags`/`drag_and_drop_lists` NON ajoutés (rejetés par l'étude, morts dans DODLP). Besoin déjà couvert zéro-dép par `ZSubListDisplayMode.tags` (fp-5-1). Un chemin dispatcher-atteignable exigerait un NOUVEAU type d'enum cœur (`richTags`) = story cœur ultérieure. « icon » : idem, 0 call-site actif DODLP → différé OQ-6.

**Dép & confinement** : `pinput` = seule dép lourde ; `autocomplete`/`editableTable` SDK-only. Garde de confinement mise à jour (allowlist dérivée `{flutter, zcrud_core, pinput}`, R12 mutantes + intrus témoin `flutter_tags` qui rougit). `flutter_tags`/`drag_and_drop_lists` : aucune dépendance, aucun import `lib/**` (hits résiduels = prose de doc + probe R12 du test).

**Vérif verte rejouée (RC réels)** : `dart pub get` OK · `dart analyze packages/zcrud_field_extras` RC=0 · `flutter test packages/zcrud_field_extras` RC=0 (23) · `graph_proof.py` RC=0 (CORE OUT=0). Aucun `*.g.dart` (pas d'annotation réelle). `melos analyze`/`melos generate` repo-wide = gate orchestrateur (workstreams au repos).

### File List

- `packages/zcrud_field_extras/pubspec.yaml` — UPDATE (dép `pinput: ^6.0.0`).
- `packages/zcrud_field_extras/lib/zcrud_field_extras.dart` — UPDATE (barrel : exports + registrar + SIGNAL 1/2 ; placeholder retiré).
- `packages/zcrud_field_extras/lib/src/presentation/z_pin_field_widget.dart` — NEW.
- `packages/zcrud_field_extras/lib/src/presentation/z_autocomplete_field_widget.dart` — NEW · UPDATE code-review (StatefulWidget + `RawAutocomplete` controller/focus gérés + `didUpdateWidget` re-sync LOW + `excludeSemantics` MED-3).
- `packages/zcrud_field_extras/lib/src/presentation/z_editable_table_field_widget.dart` — NEW · UPDATE code-review (contrôleurs de cellule gérés + `didUpdateWidget` re-sync + élagage/dispose MED-1).
- `packages/zcrud_field_extras/lib/src/presentation/z_field_extras_registrar.dart` — NEW.
- `packages/zcrud_field_extras/lib/src/presentation/z_field_extras_placeholder.dart` — DELETED (superseded, 0 référence).
- `packages/zcrud_field_extras/test/z_field_extras_confinement_test.dart` — UPDATE (allowlist dérivée + intrus `flutter_tags`).
- `packages/zcrud_field_extras/test/z_field_extras_field_widget_test.dart` — NEW · UPDATE code-review (+3 tests red-before MED-1/LOW/MED-3, MED-2 renforcé avec assertion « champ VIDE » / progression « 0 / 4 »).
- `_bmad-output/implementation-artifacts/stories/code-review-fp-5-2.md` — NEW (rapport finding×statut×preuve).
