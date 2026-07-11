# Story DP.12: Décoration de champ enrichie — leading/prefix/suffix + label requis + hint/helper (parité DODLP, M1 + M5 + M6)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur consommateur de zcrud (migration DODLP → zcrud),
I want déclarer par champ, de façon **purement déclarative** (`@ZcrudField` → `ZFieldSpec`), une **décoration enrichie** — slots `leading`/`prefix`/`suffix` (icône, texte ou widget neutre), un **label enrichi** (style thémé + astérisque « requis » rouge) et des `hintText`/`helperText` — consommés à l'identique par les familles de champs `text`/`number`/`select`/`relation`,
so that un formulaire authored pour DODLP (`_buildLabelWidget`, `suffix/suffixIcon/preffix/leading`, `hintText/helperText` propagés dans `InputDecoration`) rende **visuellement à l'identique** sous zcrud — sans style codé en dur, sans closure sérialisée (AD-3/AD-14), thème injectable (FR-26), RTL/a11y (AD-13), défensif (AD-10) et **strictement additif** (un champ sans slot reste inchangé, SM-1 non régressé).

## Contexte & source de vérité

- **Gaps couverts** (`docs/dodlp-edition-parity-gap.md`, sévérité **major**) :
  - **M1** (`:92`, `:200`) — « Leading/prefix/suffix par champ » : DODLP `suffix/suffixIcon/preffix/preffixText/preffixIcon/leading/suffixText` (`models.dart:742-752`, ctor `DynamicFormField`). zcrud : **aucun** slot leading/prefix/suffix sur `ZFieldSpec`.
  - **M5** (`:96`, `:204`) — « Style label (`bodyLarge`/`w500` + `*` requis rouge) » : DODLP `_buildLabelWidget` (`edition_screen.dart.bak2:554`, ~20 usages) rend `Text.rich` avec le libellé `.capitalize` + `WidgetSpan(" *", color: kErrorColorDark)` **si** `isFieldRequired && !widget.readOnly && !field.readOnly`. zcrud : `labelText` String nue → perte de l'astérisque requis + du style.
  - **M6** (`:97`, `:205`) — « `hintText`/`helperText` par champ » : DODLP `hintText`/`helperText` (`models.dart:742-743`) propagés dans `InputDecoration`. zcrud : **absents** de `ZFieldSpec` → perte de contenu (pas seulement de style).
- **Comportement DODLP exact** (lecture réelle, `dodlp-otr` en LECTURE SEULE) :
  - `_buildLabelWidget({String? label, TextStyle? style})` → `Text.rich(TextSpan(text: (label ?? field.label)?.capitalize, style: style, children: [ if (isFieldRequired && !widget.readOnly && !field.readOnly) WidgetSpan(Text(" *", style: TextStyle(color: kErrorColorDark))) ]))`.
  - Slots champ : `leading` (tête), `preffix`/`preffixText`/`preffixIcon` (préfixe interne), `suffix`/`suffixText`/`suffixIcon` (suffixe interne). Le `suffix` DODLP est une **closure** `Widget? Function(Map<String,dynamic> editionState)` — **NON portable en pur-données** (AD-3/AD-14) : voir §« Décision M1 » (le cas état-dépendant passe par le seam widget neutre, pas par une closure sérialisée).
- **Épic** `E-DP` (parité DODLP), lot des majeurs. Bloc bloquant **B1/M2 (DP-1) DÉJÀ LIVRÉ** : `ZFieldSize.large`, `ZLargeFieldCard` (slots `leading`/`suffix` **déjà présents**, aujourd'hui alimentés `null`), fabrique `ZcrudTheme.inputDecoration(...)` (params `prefixIcon`/`suffixIcon` **déjà présents**), tokens de décoration. **DP-12 branche les données déclaratives sur cette tuyauterie existante.**

## Périmètre

- **`zcrud_core`** (couche `domain` + `presentation`) — cœur de la story.
- **`zcrud_annotations`** + **`zcrud_generator`** — projection authoring `@ZcrudField(leading:/prefix:/suffix:/hintText:/helperText:)` → `ZFieldSpec` (surface de saisie, cohérence avec DP-11).
- **HORS PÉRIMÈTRE** : DODLP (lecture seule, jamais modifié) ; les autres familles non décor-portantes (date/booléen/etc. — hors des 4 ciblées) ; le rendu **liste** (`DynamicList`).

### ⚠️ Points de contact `zcrud_core` PARTAGÉS (additif STRICT)

DP-12 touche des fichiers **partagés** que les stories DP-13..DP-22 rouvriront (lock `zcrud_core` sérialisé au dev — une seule story écrit `zcrud_core` à la fois). **Toutes les mutations doivent être additives** (aucun champ existant renommé/supprimé/réordonné ; aucun défaut changé) :

- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` — **ajout** de 5 champs `final` nullables + intégration `copyWith`/`==`/`hashCode` (jamais toucher les champs existants).
- `packages/zcrud_core/lib/domain.dart` + `packages/zcrud_core/lib/zcrud_core.dart` — **ajout** d'exports (nouveau fichier `z_field_adornment.dart`, helper label).
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` — **ajout** de paramètres optionnels à `inputDecoration(...)` (aucune signature existante cassée : nouveaux params nommés à défaut préservant le comportement DP-1).
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (dispatcher) — **branche** les slots dans les appels familles + la Card `large` (aucun changement de frontière de rebuild).
- Familles `families/z_text_field_widget.dart`, `z_number_field_widget.dart`, `z_select_field_widget.dart`, `z_relation_field_widget.dart` — **ajout** de consommation de décoration.

## Acceptance Criteria

### Bloc M1 — Slots `leading`/`prefix`/`suffix` déclaratifs (pur-données, AD-3/AD-14)

1. **Type neutre `ZFieldAdornment` (domaine pur-Dart `const`).** Un nouveau fichier `packages/zcrud_core/lib/src/domain/edition/z_field_adornment.dart` définit une classe-valeur `const` **pur-données** (couche `domain`, AUCUNE dépendance Flutter — garde `domain_purity_test.dart` verte ; aucun `IconData`, aucun `Widget`, aucune closure) représentant un ornement de champ, discriminée par un enum public `ZAdornmentKind { text, icon, widget }` :
   - `const ZFieldAdornment.text(String value)` — texte littéral **ou** clé l10n (résolu côté UI) ;
   - `const ZFieldAdornment.icon(String iconKey)` — **clé d'icône neutre** (String), résolue en `Widget` côté présentation (jamais un `IconData` dans le domaine) ;
   - `const ZFieldAdornment.widget(String kind)` — **clé de registre** neutre, résolue via le seam `ZcrudScope.widgetRegistry` (host-fourni), couvrant le cas état-dépendant DODLP (`suffix(editionState)`) SANS closure sérialisée.
   Champs `final` : `ZAdornmentKind kind`, `String value` (payload unique). `==`/`hashCode`/`toString` implémentés (identité de valeur pour tests de projection). Exporté par le barrel du domaine (`domain.dart`, là où `ZFieldSpec` est exporté).
2. **Slots additifs sur `ZFieldSpec`.** `ZFieldSpec` porte 3 nouveaux champs `final ZFieldAdornment? leading`, `final ZFieldAdornment? prefix`, `final ZFieldAdornment? suffix`, **défaut `null`**, intégrés au constructeur `const`, à `copyWith`, à `==` et à `hashCode`. Une `ZFieldSpec` construite sans ces slots conserve **exactement** l'égalité de valeur, la projection (tests E2-5) et le rendu actuels (aucune régression).
3. **Résolveur d'ornement neutre (présentation).** Un helper de présentation (`ZFieldAdornmentView` ou fonction `resolveAdornment(context, adornment)` sous `lib/src/presentation/edition/`) transforme un `ZFieldAdornment?` en `Widget?` **défensivement** (AD-10) :
   - `null` → `null` (aucun slot rendu) ;
   - `.text` → `Text` **thémé** (résolution l10n via `label(context, value, fallback: value)`, style dérivé du thème — aucune couleur en dur) ;
   - `.icon` → icône résolue via un seam neutre injecté (`ZcrudScope` : résolveur d'icône host-fourni **ou** table de correspondance par défaut du cœur) ; clé inconnue ⇒ `null` (jamais de throw) ;
   - `.widget` → `ZcrudScope.widgetRegistry.tryBuilderFor(kind)` ; `kind` non enregistré ⇒ `null` (dégradation propre, jamais de throw).
   Cibles tactiles ≥ 48 dp lorsque l'ornement est interactif (AD-13) ; aucun inset non directionnel.
4. **Câblage des slots dans les 4 familles + la Card `large`.**
   - **Mode `normal`** : `leading` → `InputDecoration.icon` (tête, hors bordure) ; `prefix` → `InputDecoration.prefix`/`prefixIcon` ; `suffix` → `InputDecoration.suffix`/`suffixIcon`. La fabrique `ZcrudTheme.inputDecoration(...)` reçoit ces widgets résolus (AC8).
   - **Mode `large`** : `leading` et `suffix` alimentent les slots **déjà existants** `ZLargeFieldCard.leading`/`.suffix` (aujourd'hui `null`) ; le champ interne reste `bare` (le `prefix` interne reste porté par la décoration `bare`). Le dispatcher (`z_field_widget.dart`) résout les ornements **une fois** et les passe à `ZLargeFieldCard`.
   Familles concernées : `text`, `number`, `select`, `relation`.

### Bloc M5 — Label enrichi partagé (style thémé + astérisque requis rouge)

5. **Détection « requis » pur-Dart.** `ZFieldSpec` expose un getter pur-Dart `bool get isRequired` ⇒ `true` ssi `validators` contient un `ZValidatorSpec` de kind `ZValidatorKind.required` (domaine, aucune dépendance Flutter). (Miroir de `isFieldRequired` DODLP.)
6. **Widget label enrichi partagé.** Un widget de présentation partagé `ZFieldLabel` (sous `lib/src/presentation/edition/`) rend `Text.rich` : le libellé de base (résolu l10n, style **thémé** via `ZcrudTheme` — `labelTextStyle`/repli `bodyMedium` en mode normal, `largeLabelTextStyle`/`bodyLarge` `w500` en mode large) **+** un `WidgetSpan(" *")` coloré **erreur** (`ZcrudTheme.of(context).errorColor ?? ColorScheme.error` — AUCUNE couleur en dur, contrairement au `kErrorColorDark` DODLP) rendu **uniquement** si `field.isRequired && !field.readOnly` (parité `_buildLabelWidget`). Directionnel/RTL (AD-13). Sémantique : le libellé reste porté par le rôle de champ natif ; l'astérisque n'introduit pas de faux label a11y (le `*` est décoratif, l'état requis est aussi porté par le validateur natif).
7. **Consommation dans les familles + la Card.** Les familles `text`/`number`/`select`/`relation` en mode `normal` passent ce label enrichi à l'`InputDecoration` (via le param `label:` Widget de la fabrique — AC8), **au lieu** d'un `labelText` String nu. En mode `large`, `ZLargeFieldCard` rend `ZFieldLabel` au-dessus du champ (remplaçant l'actuel `Text(label)` String). Le comportement d'un champ **non requis** ou **readOnly** est identique à aujourd'hui (aucun astérisque).

### Bloc M6 — `hintText`/`helperText` par champ

8. **Slots `hintText`/`helperText` additifs + projection décoration.** `ZFieldSpec` porte `final String? hintText` et `final String? helperText` (défaut `null` ; intégrés constructeur/`copyWith`/`==`/`hashCode`). Les 4 familles les résolvent (l10n : `label(context, key, fallback: key)`, `null` ⇒ non passé) et les injectent dans l'`InputDecoration` via la fabrique existante (params `hintText`/`helperText` de `ZcrudTheme.inputDecoration` **déjà présents** depuis DP-1) — le token `helperMaxLines` (DP-1) reste appliqué. Champ sans hint/helper ⇒ `InputDecoration` inchangée.

### Bloc — Fabrique de décoration (extension additive)

9. **`ZcrudTheme.inputDecoration` étendue additivement.** La fabrique gagne des paramètres nommés optionnels **à défaut préservant DP-1** : `Widget? label` (label enrichi ; si fourni, prime sur `labelText`/`String? label` existant — mutuellement exclusifs côté Flutter), `Widget? prefix`, `Widget? suffix`, `Widget? leadingIcon` (→ `InputDecoration.icon`). Aucune signature existante cassée ; le chemin `bare` (large) continue de **ne pas** poser de label (porté par la Card) mais peut porter `prefix`/`suffix`/`icon` internes si fournis. Aucune couleur en dur ajoutée (dérivations `ColorScheme` seulement — FR-26).

### Bloc — Projection authoring (zcrud_annotations + zcrud_generator)

10. **`@ZcrudField` : nouveaux paramètres pur-Dart.** `ZcrudField` expose `ZFieldAdornment? leading`, `ZFieldAdornment? prefix`, `ZFieldAdornment? suffix`, `String? hintText`, `String? helperText` (tous optionnels, défaut `null`). `ZcrudField` reste `const` pur-données (tous champs `final`, zéro closure, zéro dépendance Flutter/backend). `ZFieldAdornment` étant dans `zcrud_core/domain` (pur-Dart), `zcrud_annotations` peut le référencer sans introduire de dépendance interdite (vérifier le graphe : `zcrud_annotations` → `zcrud_core` domaine est-il déjà présent ? Voir §« Besoin annotations/generator détecté » — si le sens de dépendance l'interdit, le type d'ornement est **redéclaré** côté annotations OU placé dans un module partagé ; le dev tranche en respectant AD-1 acyclique).
11. **Le générateur projette les slots.** `zcrud_model_generator.dart` (`_emitSpec`, ~L381-409) émet, quand présents, `leading:`/`prefix:`/`suffix:` (via `_emitConst` sur le `ConstantReader` — const AST re-émis à l'identique) et `hintText:`/`helperText:` (String littéraux). Un `@ZcrudField` sans ces paramètres émet une `ZFieldSpec` **identique** à aujourd'hui (aucun `part` supplémentaire). Lecture **statique** uniquement (`ConstantReader`, jamais `reflectable` — gate anti-reflectable verte).

### Transverse — invariants & non-régression

12. **Rétro-compatibilité additive stricte.** Toute `ZFieldSpec`/`@ZcrudField` existante (sans slot/label enrichi/hint) conserve égalité de valeur, projection générée et rendu **inchangés**. Tests de projection (E2-5) et de sérialisation défensive existants restent **verts**.
13. **Défensif (AD-10).** Toute résolution d'ornement/label/hint est tolérante : clé l10n absente ⇒ fallback littéral ; clé d'icône/registre inconnue ⇒ slot omis (jamais de throw, jamais de crash du parent). Un `ZFieldAdornment.widget(kind)` non enregistré dégrade proprement (slot vide).
14. **Zéro style/couleur en dur (FR-26).** Aucun littéral de couleur ni constante interdite dans le code nouveau/modifié (astérisque requis, labels, ornements texte) — la garde `test/purity/style_purity_test.dart` reste **verte**. Toutes les couleurs dérivent de `ZcrudTheme`/`ColorScheme`.
15. **Directionnel only (AD-13) + cibles ≥ 48 dp.** Tous les insets/paddings/positions introduits sont directionnels (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`) ; les ornements interactifs offrent une cible ≥ 48 dp.
16. **SM-1 / AD-2 non régressés (décoration HORS chemin chaud).** La résolution des ornements/label enrichi/hint se fait dans la construction **statique** de la décoration (mémoïsable, aucune allocation de `TextEditingController`/`FocusNode`, aucun nouvel abonnement/`Listenable`, aucun élargissement de la frontière de rebuild). Taper 100 caractères dans un champ décoré (normal **ou** large) ne reconstruit que ce champ, sans perte de focus ni saut de curseur (test widget de rebuild ciblé toujours vert).

## Tasks / Subtasks

- [ ] **T1 — Domaine : `ZFieldAdornment` + slots `ZFieldSpec` (AC1, AC2, AC5, AC8, AC12)**
  - [ ] Créer `z_field_adornment.dart` : `enum ZAdornmentKind { text, icon, widget }` + classe-valeur `const` (3 ctors nommés, `value`, `==`/`hashCode`/`toString`), pur-Dart.
  - [ ] `z_field_spec.dart` : ajouter `leading`/`prefix`/`suffix` (`ZFieldAdornment?`), `hintText`/`helperText` (`String?`), défauts `null`, au ctor `const`, `copyWith`, `==`, `hashCode`. Ajouter le getter `bool get isRequired`.
  - [ ] Exports barrels (`domain.dart`, `zcrud_core.dart`). Garde `domain_purity_test.dart` verte.
- [ ] **T2 — Présentation : résolveur d'ornement + `ZFieldLabel` (AC3, AC6, AC13, AC14, AC15)**
  - [ ] `ZFieldAdornmentView`/`resolveAdornment` : text→Text thémé, icon→seam icône, widget→`widgetRegistry` ; défensif (null si non résolu). Seam d'icône neutre via `ZcrudScope`.
  - [ ] `ZFieldLabel` : `Text.rich` label thémé + `WidgetSpan(" *")` erreur-thémée si `isRequired && !readOnly`. Directionnel.
  - [ ] Exports nécessaires.
- [ ] **T3 — Fabrique : `ZcrudTheme.inputDecoration` étendue (AC9)**
  - [ ] Ajouter params `Widget? label`, `Widget? prefix`, `Widget? suffix`, `Widget? leadingIcon` (→ `icon`). Défauts préservant DP-1 (`bare` inchangé). Aucune couleur en dur.
- [ ] **T4 — Familles : consommation décor (AC4, AC7, AC8)**
  - [ ] `z_text_field_widget.dart`, `z_number_field_widget.dart`, `z_select_field_widget.dart` : passer label enrichi (`ZFieldLabel`) + `hintText`/`helperText` résolus + ornements résolus à `inputDecoration(...)` (mode normal) ; en `bare` (large), label omis, ornements internes conservés.
  - [ ] `z_relation_field_widget.dart` : migrer les `InputDecoration(labelText:…)` bruts (L178, L356) vers label enrichi + hint/helper + ornements (parité au moins pour le déclencheur mono).
- [ ] **T5 — Dispatcher + Card `large` (AC4, AC7, AC16)**
  - [ ] `z_field_widget.dart` : résoudre `field.leading`/`field.suffix` en widgets et les passer à `ZLargeFieldCard(leading:, suffix:)` ; remplacer le `label:` String de la Card par `ZFieldLabel`. Résolution statique (hors frontière de rebuild).
  - [ ] `z_large_field_card.dart` : accepter/afficher `ZFieldLabel` (ou recevoir un `Widget label`), slots leading/suffix déjà présents.
- [ ] **T6 — Projection annotations + generator (AC10, AC11, AC12)**
  - [ ] `zcrud_annotations` `@ZcrudField` : ajouter `leading`/`prefix`/`suffix`/`hintText`/`helperText`. Résoudre la question de dépendance `ZFieldAdornment` (cf. §besoin).
  - [ ] `zcrud_model_generator.dart` `_emitSpec` : émettre les 5 nouveaux slots via `_emitConst`/littéral quand présents.
- [ ] **T7 — Tests (AC exhaustifs)**
  - [ ] Domaine : `ZFieldAdornment` (égalité/kinds), `ZFieldSpec` additif (== / hashCode / copyWith inchangés sans slot), `isRequired`.
  - [ ] Présentation : résolveur défensif (icône/registre inconnu → pas de crash), `ZFieldLabel` (astérisque présent/absent selon `isRequired`/`readOnly`, couleur thémée), familles (leading/prefix/suffix rendus, hint/helper dans la décoration), large (slots Card alimentés).
  - [ ] Générateur : projection des 5 slots ; champ sans slot ⇒ spec identique (golden inchangé).
  - [ ] Non-régression : `style_purity_test`, `domain_purity_test`, rebuild ciblé (SM-1) verts.

## Mapping DODLP retenu

| DODLP (`models.dart` / `_buildLabelWidget`) | zcrud (`ZFieldSpec` / rendu) | Gap |
|---|---|---|
| `leading` (`:744`) | `ZFieldSpec.leading: ZFieldAdornment?` → `InputDecoration.icon` (normal) / `ZLargeFieldCard.leading` (large) | M1 |
| `preffix`/`preffixText`/`preffixIcon` (`:750-752`) | `ZFieldSpec.prefix: ZFieldAdornment?` → `InputDecoration.prefix`/`prefixIcon` | M1 |
| `suffix`(closure)/`suffixText`/`suffixIcon` (`:746-748`) | `ZFieldSpec.suffix: ZFieldAdornment?` → `InputDecoration.suffix`/`suffixIcon` (normal) / `ZLargeFieldCard.suffix` (large). **Closure `suffix(editionState)` → `ZFieldAdornment.widget(kind)`** (seam registre, pas de closure sérialisée) | M1 |
| `_buildLabelWidget` : `Text.rich` + `" *"` `kErrorColorDark` si `isFieldRequired && !readOnly && !field.readOnly` | `ZFieldLabel` : `Text.rich` + `WidgetSpan(" *")` `errorColor` thémé si `field.isRequired && !field.readOnly` | M5 |
| `hintText`/`helperText` (`:742-743`) → `InputDecoration` | `ZFieldSpec.hintText`/`helperText` → `ZcrudTheme.inputDecoration(hintText:/helperText:)` (déjà câblé DP-1) | M6 |

## Points de contact `zcrud_core` partagés signalés

- **`z_field_spec.dart`** (partagé DP-13..DP-22) : +5 champs nullables + `isRequired` — **additif strict**.
- **`z_theme.dart`** : +4 params optionnels à `inputDecoration` — **additif** (DP-1 inchangé).
- **`z_field_widget.dart`** (dispatcher) + **4 familles** + **`z_large_field_card.dart`** : câblage additif, aucune frontière de rebuild déplacée.
- **Barrels** `domain.dart` / `zcrud_core.dart` : +exports (`z_field_adornment.dart`, `ZFieldLabel`, résolveur).
- Note dev : sérialiser le lock `zcrud_core` avec les stories DP suivantes (une seule story écrit `zcrud_core` à la fois).

## Besoin annotations/generator détecté

- **Question de dépendance (AD-1 acyclique)** : `ZFieldAdornment` vit dans `zcrud_core/domain`. `@ZcrudField` (dans `zcrud_annotations`) doit le référencer comme type de paramètre. **Vérifier** si `zcrud_annotations` dépend déjà de `zcrud_core` (DP-11 a ajouté `ZPersistAs` **dans** `zcrud_annotations`, pas dans core → suggère que `zcrud_annotations` n'importe PAS `zcrud_core`). **Décision dev à trancher, deux options AD-1-safe :**
  1. **Déclarer `ZFieldAdornment` dans `zcrud_annotations`** (pur-Dart) et le **ré-exporter/aliaser** depuis `zcrud_core` (ou le core en dépend) — cohérent avec le pattern `ZPersistAs` (DP-11).
  2. Garder `ZFieldAdornment` dans `zcrud_core` **si** `zcrud_annotations → zcrud_core` est déjà un arc autorisé du graphe (vérifier `graph_proof`/`pubspec`).
  Le générateur émet du code **dans le package du modèle** qui dépend de `zcrud_core` → l'émission `_emitConst(ZFieldAdornment(...))` référence le type visible côté runtime (`zcrud_core`). Aligner les deux surfaces (authoring vs runtime) sur **le même type** exporté.
- **Generator** : `_emitSpec` étendu (5 lignes conditionnelles `_emitConst`/littéral) ; `_Field.reader` déjà disponible ; aucun nouvel artefact `part` requis (contrairement au `Set<String>` de DP-11).

## Notes d'implémentation (guardrails dev)

- **AD-3/AD-14** : le slot `suffix` DODLP est une **closure état-dépendante** — NE PAS tenter de la sérialiser. Le cas dynamique passe par `ZFieldAdornment.widget(kind)` + `ZcrudScope.widgetRegistry` (le widget host lit l'état via `context`/registre). Documenter cette limite volontaire.
- **`InputDecoration` mutuellement exclusifs** : `label` (Widget) et `labelText` (String) ne coexistent pas ; quand `ZFieldLabel` est fourni, passer `label:` et NE PAS passer `labelText`. Idem `prefix`/`prefixIcon` et `suffix`/`suffixIcon` (choisir selon `ZAdornmentKind` : `.icon` → `prefixIcon`/`suffixIcon` ; `.text` → `prefix`/`suffix`).
- **Seam icône** : ne PAS importer un package d'icônes ni coder un `IconData` en dur hors table de correspondance bornée ; privilégier un résolveur host-fourni via `ZcrudScope` (défaut : petite table Material neutre, ou `null` si non résolu — AD-10).
- **SM-1** : la décoration est reconstruite dans le slice (comportement DP-1 existant) ; ne PAS y ajouter d'allocation d'objet coûteuse par frappe ni de `Listenable`. Résolution d'ornement = fonctions pures cheap.
- **`ZLargeFieldCard`** : ses slots `leading`/`suffix` existent déjà (DP-1) mais sont alimentés `null` par le dispatcher — DP-12 les **branche** ; son `label` String devient un `Widget`/`ZFieldLabel`.

## Project Context Reference

- CLAUDE.md (invariants AD-1..AD-16, FR-26, SM-1) ; `docs/dodlp-edition-parity-gap.md` §3 (M1/M5/M6).
- Précédents : **DP-1** (`ZFieldSize.large`, `ZLargeFieldCard`, `ZcrudTheme.inputDecoration`, tokens décor — tuyauterie réutilisée), **DP-11** (pattern annotations+generator additif, `ZPersistAs` dans `zcrud_annotations`).
- Vérif verte NON-NÉGOCIABLE avant `review` : `melos run generate` → `melos run analyze` (RC=0) → `flutter test` (RC=0).

## Dev Agent Record

### Completion Notes

Implémenté en lot groupé avec DP-13 (LOCK CORE partagé — single writer `zcrud_core`).

**Décision AD-1 (ZFieldAdornment)** : placé dans `zcrud_core/domain`
(`z_field_adornment.dart`), pur-Dart `const`. L'arc `zcrud_annotations → zcrud_core`
existe déjà (les annotations importent `package:zcrud_core/edition.dart`) → Option 2
retenue : `@ZcrudField` référence directement `ZFieldAdornment` (mêmes surfaces
authoring/runtime, pas de duplication). `graph_proof` : CORE OUT=0 / ACYCLIQUE OK.
Type Flutter-free confirmé (garde `domain_entrypoint_dart_test` verte sous `dart test`).

**Statut ACs** :
- AC1 `ZFieldAdornment` (enum `ZAdornmentKind` + 3 ctors const, ==/hashCode/toString) : OK, testé.
- AC2 slots `leading`/`prefix`/`suffix` additifs sur `ZFieldSpec` (+ ctor/copyWith/==/hashCode) : OK, rétro-compat testée.
- AC3 résolveur `resolveAdornment` défensif (text→Text thémé, icon→seam `ZcrudScope.iconResolver`+table Material, widget→`widgetRegistry`) ; clé inconnue/registre absent → `null` (jamais de throw) : OK.
- AC4 câblage 4 familles + Card `large` (leading→`icon`, prefix→`prefix`/`prefixIcon`, suffix→`suffix`/`suffixIcon`) : OK via helper central `zFieldDecoration`.
- AC5 getter `isRequired` pur-Dart : OK, testé.
- AC6 `ZFieldLabel` (`Text.rich` + astérisque erreur-thémé, décoratif `ExcludeSemantics`, requis && !readOnly) : OK, testé (présent/absent/couleur).
- AC7 consommation familles (label enrichi via `label:` Widget, non `labelText`) + Card `labelWidget` : OK.
- AC8 `hintText`/`helperText` additifs + projection décoration : OK, testé.
- AC9 `ZcrudTheme.inputDecoration` étendue (`labelWidget`/`prefix`/`suffix`/`leadingIcon`, défauts préservant DP-1) : OK. Note : param `Widget? label` de l'AC nommé `labelWidget` (collision Dart avec `String? label` existant).
- AC10 `@ZcrudField` (leading/prefix/suffix/hintText/helperText, const pur-données) : OK.
- AC11 générateur `_emitSpec` émet les 5 slots via `_emitConst` (const AST re-émis 1:1) : OK, testé (`revive()` sur ctors nommés vérifié).
- AC12/AC13/AC14/AC15/AC16 (rétro-compat additive, défensif, zéro couleur en dur, directionnel, SM-1 hors chemin chaud) : OK — gardes `style_purity`/`domain_purity`/`presentation_purity` vertes ; décoration statique, aucun controller/Listenable ajouté.

**Vérif verte réelle** : `dart analyze` (core/annotations/generator) RC=0 ;
`flutter test` zcrud_core = 760 tests OK ; générateur = 87 tests OK (scope `test/`) ;
annotations = 9 OK ; `graph_proof` CORE OUT=0 OK.

### File List

- `packages/zcrud_core/lib/src/domain/edition/z_field_adornment.dart` (nouveau)
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` (5 slots + `isRequired` ; + flip showIfNull DP-13)
- `packages/zcrud_core/lib/domain.dart`, `lib/edition.dart`, `lib/zcrud_core.dart` (exports)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_adornment_view.dart` (nouveau — resolveAdornment + zFieldDecoration + seam icône)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_label.dart` (nouveau)
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` (inputDecoration étendue + tokens read* DP-13)
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (seam `iconResolver`)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (résolution ornements Card large ; + readMode DP-13)
- `packages/zcrud_core/lib/src/presentation/edition/z_large_field_card.dart` (`labelWidget`)
- `packages/zcrud_core/lib/src/presentation/edition/families/{z_text,z_number,z_select,z_relation}_field_widget.dart` (consommation décor)
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart` (5 params ; + flip showIfNull DP-13)
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` (`_emitSpec` 5 slots ; + projection showIfNull DP-13)
- Tests : `test/domain/edition/z_field_adornment_test.dart`, `test/presentation/edition/dp12_decoration_test.dart`, `packages/zcrud_generator/test/dp12_dp13_projection_test.dart` (nouveaux) ; `test/presentation/edition/dp1_layout_decoration_test.dart` (label enrichi).
