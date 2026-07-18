---
title: "PRD — zcrud « Formulaire : parité DODLP totale »"
status: draft
created: 2026-07-18
updated: 2026-07-18
---

# PRD: zcrud — Formulaire « Parité DODLP totale »
*Working title — confirmer.*

## 0. Document Purpose

Ce PRD est destiné au PM (Zakarius), aux owners de la phase **architecture** (emplacement des
satellites, mécanique du fork `awesome_select`) et à l'auteur des **epics/stories** BMAD. Il fixe
**quoi** livrer pour atteindre la parité fonctionnelle totale du formulaire DODLP dans zcrud, **pas
le comment** (les choix de packages/adaptateurs concrets relèvent de l'architecture et sont capturés
en `addendum.md`). Il est **dérivé 1:1** de la matrice de reconnaissance
`docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md` (LA base des FR de parité) et
du brief `_bmad-output/planning-artifacts/briefs/brief-zcrud-form-parity-2026-07-18/brief.md`. Chaque
FR référence l'item de matrice qu'il couvre et porte un **marquage de phase** (MVP / Média-rich /
Finitions). Les invariants d'architecture (16 AD, `CLAUDE.md`) sont traités en **NFR transverses**
(§ Cross-Cutting NFRs), pas répétés par FR. Produit en mode **non-interactif** : chaque arbitrage non
tranché par le owner retient l'**option conservatrice** (natif zcrud, isolation AD-1), taguée
`[ASSUMPTION]` et indexée en §9 ; les décisions **verrouillées** par le owner sont des **contraintes
non re-litigables** (§ Constraints).

## 1. Vision

DODLP porte un moteur CRUD déclaratif mûr (54 entités `DynamicModel`, `edition_screen.dart` de 4455
lignes, ~40 types de champ) construit sur une pile de packages tiers dont plusieurs sont fragiles
(`awesome_select` en fork git `ref: master` flottant au premier rang) et miné par un défaut
structurel : un `setState()` d'écran à chaque frappe, d'où jank et pertes de focus — l'**objectif
produit n°1** de zcrud. L'étude d'intégration a prouvé sur disque que zcrud a **déjà réimplémenté
nativement** la quasi-totalité de ces familles de champ, en meilleure conformité a11y/RTL/thème, et
que le bug historique est corrigé par conception (`ZFormController` + rebuild granulaire par tranche).

Cette itération ne réécrit donc pas des widgets : elle **achève et prouve** la parité. Elle pose un
objectif dur — **parité DODLP totale** : chaque type de champ et chaque variante que le module CRUD
de DODLP savait rendre devient périmètre-cible, y compris le **rich-text HTML WYSIWYG**. Il n'y a plus
de gap « optionnel ». La livraison est **phasée** (MVP → Média-rich → Finitions), mais l'état-cible de
parité totale n'est pas négociable.

La preuve de succès est concrète, pas déclarative : un **harnais de parité** rejouant ≥ 6 formulaires
réels de DODLP dans l'app Exemple (données fictives), une **page showcase exhaustive** couvrant tous
les types × variantes × états, et le **banc SM-1** démontrant zéro perte de focus sous frappe
intensive. Consommateur prioritaire : **DODLP** (GetX, binding `zcrud_get`) ; suivant : **lex_douane**
(Riverpod, `zcrud_riverpod`).

## 2. Target User

### 2.1 Jobs To Be Done

- **DODLP (app prioritaire)** : migrer ses formulaires vers zcrud **sans que ses utilisateurs
  perçoivent une régression**, et se débarrasser des dépendances fragiles (`ref: master` flottant
  d'`awesome_select`, `setState()` d'écran).
- **lex_douane (app suivante)** : réutiliser le même moteur neutre et la même showcase comme
  référence de complétude ; valider que la parité n'est pas DODLP-spécifique.
- **Développeurs / mainteneurs zcrud** : disposer d'un **filet de régression** (harnais + showcase)
  et d'une documentation vivante des champs supportés.
- **[ASSUMPTION] IFFD / DLCFTI** : bénéficiaires indirects (mêmes packages) ; certaines variantes
  basse-priorité (`subItems.itemsAreTags`, `icon`) pourraient être motivées par leur usage — à
  confirmer.

### 2.2 Non-Users (v1)

- Un consommateur zcrud qui n'a **pas** besoin d'un champ lourd (média, WebView WYSIWYG, roue
  couleur) ne doit **pas** le payer : l'isolation AD-1 (satellites) garantit que le cœur reste léger.
  Ce PRD ne cible donc pas un consommateur « tout-en-un monolithique ».

### 2.3 Key User Journeys

- **UJ-1. Bilal (dev DODLP) migre un écran d'édition sans régression visible.**
  Bilal remplace un formulaire DODLP par son équivalent zcrud dans l'app Exemple (harnais). Il
  compare côte à côte avec la référence DODLP : aération, sélecteurs modaux, champs intl. Il constate
  que le rendu est fonctionnellement identique (les 3 écarts d'aération connus étant tranchés
  explicitement) et que **taper dans un champ ne fait plus perdre le focus**. Il valide la migration.
  *Realizes FR-38, FR-39.*

- **UJ-2. Zakarius (owner) audite la complétude sur une seule page.**
  Zakarius ouvre la page showcase : chaque `EditionFieldType` et chaque variante y est démontré, avec
  les états transverses (read-only, désactivé, erreur, RTL, thème clair/sombre). Les gaps résiduels y
  sont **étiquetés « ABSENT / à combler »**, pas masqués. Il bascule le thème et la direction RTL et
  voit tous les champs se réagencer directionnellement. *Realizes FR-40.*

- **UJ-3. Une utilisatrice DODLP saisit une plage de dates de validité.**
  Sur le formulaire ConvocationBmd du harnais, elle ouvre le nouveau champ `dateRange`, sélectionne un
  début et une fin via le picker natif `showDateRangePicker`. La valeur `ZDateRange{start, end}` est
  persistée en ISO-8601 ; un début postérieur à la fin est refusé. *Realizes FR-5.*

## 3. Glossary

- **EditionFieldType** — enum canonique des types de champ du moteur zcrud (40 valeurs), source de
  vérité : `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`. Pilote à la fois le
  widget d'édition (`DynamicEdition`) et la colonne de liste (`DynamicList`).
- **ZFieldSpec** — spécification runtime d'un champ (type, validateurs, (dé)sérialisation), émise par
  le générateur `zcrud_generator` à partir du modèle annoté.
- **ZFormController** — controller d'état du formulaire, `ChangeNotifier`/`Listenable` pur-Flutter,
  exposant une `ValueListenable` par champ (aucun gestionnaire d'état importé — AD-2/AD-15).
- **ZFieldListenableBuilder** — builder montant un champ qui n'écoute que sa tranche (rebuild ciblé).
- **ZWidgetRegistry** — seam d'enregistrement runtime `register(kind, builder)` ; le builder ne reçoit
  que `ctx.value`/`ctx.onChanged`, **jamais** le `ZFormController`.
- **Satellite** — package zcrud autre que `zcrud_core` (ex. `zcrud_intl`, `zcrud_markdown`,
  `zcrud_geo`, et les satellites à créer en architecture). Tout adaptateur de package tiers y vit.
- **Binding** — package de branchement à un gestionnaire d'état (`zcrud_get`, `zcrud_riverpod`,
  `zcrud_provider`). Câble les adaptateurs concrets (ex. `ZFilePicker`).
- **CORE OUT=0** — invariant AD-1 : `zcrud_core/pubspec.yaml` ne déclare **aucune** dépendance lourde
  ni aucun autre package `zcrud_*`. Vérifié par grep.
- **Harnais de parité** — ensemble de ≥ 6 formulaires réels de DODLP rejoués dans `example/` avec
  données fictives, servant de preuve de non-régression visuelle à la migration.
- **Page showcase** — page unique de `example/` démontrant chaque `EditionFieldType` × chaque variante
  × chaque état transverse ; sert de preuve de complétude, de tableau de bord du reste-à-faire, et de
  banc SM-1.
- **Spacing spec** — jeu de tokens de layout (dp) répliquant les mesures d'aération DODLP, injectés
  via `ThemeExtension`/`ZcrudTheme` (jamais de couleur codée en dur — FR-26).
- **ZDateRange** — nouvelle valeur `{start, end}` sérialisable ISO-8601, désérialisation défensive
  (AD-10), invariant `end >= start`, `null` toléré si le champ est optionnel.
- **Round-trip borné** — conversion HTML/Markdown ⇄ Delta dont les pertes sont **documentées et
  bornées** (ex. styles CSS exotiques, code inline).

## 4. Features

> **Convention de traçabilité** : chaque FR référence l'item de `FIELD-PACKAGE-MATRIX.md` qu'il couvre
> (`[Matrice #N]`) et porte un **marquage de phase** `[MVP]` / `[Média-rich]` / `[Finitions]`. La
> table de synthèse complète est en § 4.14 (Traçabilité & phasage).

### 4.1 Champs de saisie de base (natifs — confirmer, polir, câbler)

**Description:** Familles déjà réimplémentées nativement dans `zcrud_core`, souvent supérieures à
DODLP en a11y/RTL/thème. Le travail est **confirmation + polissage cosmétique par thème** + câblage,
pas réécriture. `flutter_form_builder` (widgets) est écarté ; seuls ses validateurs
`form_builder_validators` (déjà dep pure de `zcrud_core`) sont réutilisés. Realizes UJ-1.

**Functional Requirements:**

#### FR-1: Texte, multiligne, mot de passe `[MVP]` `[Matrice #1, #2, #37]`
Un consommateur peut rendre un champ `text` (mono-ligne), `multiline` (min/maxLines) et `password`
(texte masqué + validateur).
**Consequences (testable):**
- Saisir 100 caractères ne reconstruit que le champ courant (banc SM-1), zéro perte de focus.
- `password` masque la valeur ; le `TextEditingController` n'est pas recréé au rebuild.
- Validateurs `form_builder_validators` appliqués via `AutovalidateMode.onUserInteraction` par champ.

#### FR-2: Numériques (number, integer, float) `[MVP]` `[Matrice #3, #4, #5]`
Un consommateur peut rendre `number` (avec mode pourcentage, suffixe `%`), `integer` (clavier
numérique), `float` (décimal + affichage devise).
**Consequences (testable):**
- Le mode pourcentage affiche le suffixe `%` sans altérer la valeur persistée.
- L'affichage devise est dérivé de la locale/thème injecté, jamais codé en dur.

#### FR-3: Booléen `[MVP]` `[Matrice #6]`
Un consommateur peut rendre `boolean` via un contrôle switch/toggle accessible.
**Consequences (testable):**
- Cible tactile ≥ 48 dp ; `Semantics` explicite (état on/off).
- Le delta cosmétique vs le pill switch DODLP (`flutter_switch`) est absorbé par `SwitchThemeData`,
  pas par une dépendance tierce.

#### FR-4: Date & heure `[MVP]` `[Matrice #7, #8]`
Un consommateur peut rendre `dateTime` (date + heure) et `time` (heure seule) via les pickers Material
natifs, valeurs ISO-8601.
**Consequences (testable):**
- Aucune dépendance à `date_time_picker` (code mort DODLP) ni `table_calendar`.

### 4.2 Plage de dates (net-new)

**Description:** Type **absent** de zcrud (grep négatif confirmé). DODLP ne l'a jamais implémenté →
**zéro contrainte de parité**, c'est un gain net. Touche `zcrud_core` (enum + valeur + widget + spec)
→ **story sérialisée** (une seule story écrit `zcrud_core` à la fois). Realizes UJ-3.

**Functional Requirements:**

#### FR-5: Champ `dateRange` `[MVP]` `[Matrice §2 P1 / hors-enum]`
Un consommateur peut déclarer un champ `dateRange` produisant une valeur `ZDateRange{start, end}`.
**Consequences (testable):**
- Valeur `dateRange` ajoutée à `EditionFieldType` (camelCase), près de `dateTime`/`time`.
- `ZDateRange` sérialise/désérialise en ISO-8601 ; désérialisation défensive AD-10 (champ
  absent/corrompu ne fait pas échouer le parent) ; invariant `end >= start` validé ; `null` toléré si
  optionnel.
- Widget `ZDateRangeFieldWidget` monté sous `ZFieldListenableBuilder`, picker natif
  `showDateRangePicker` (**pas** `table_calendar`), directionnel (AD-13).
- `zcrud_generator` émet le `ZFieldSpec` du type ; test de rétro-compat de sérialisation vert (gate CI).
- Apparaît dans la showcase (variantes : ouvert/borné min-max, optionnel) et dans le formulaire du
  harnais qui l'appelle.

### 4.3 Sélections riches (fork `awesome_select`)

**Description:** Le seul type où la parité DODLP est visuellement **riche** : modal S2 responsive +
recherche + CRUD inline. Familles natives déjà présentes (`ZSelectFieldWidget`, `ZRelationFieldWidget`
+ configs). Décision **verrouillée** : adopter `awesome_select` via un **fork maintenu par nous**,
enveloppé derrière un `ZFieldWidgetBuilder` dans un **satellite** (jamais `zcrud_core`). La mécanique
exacte (fork épinglé vs vendoring) est une décision d'**architecture**. Realizes UJ-1.

**Functional Requirements:**

#### FR-6: `select` (choix unique, modal riche) `[Média-rich]` `[Matrice #9]`
Un consommateur peut rendre `select` avec modal S2 responsive + recherche, à parité DODLP.
**Consequences (testable):** l'adaptateur `awesome_select` vit hors `zcrud_core` (CORE OUT=0) ; le
builder ne reçoit que `ctx.value`/`ctx.onChanged`.

#### FR-7: `radio` (modal) `[Média-rich]` `[Matrice #10]`
Un consommateur peut rendre `radio` en **modal** (`radioAsModal: true`), pas seulement inline.
**Consequences (testable):** parité UX modal vs `RadioListTile` inline DODLP démontrée dans le harnais.

#### FR-8: `checkbox` / multiselect `[Média-rich]` `[Matrice #11]`
Un consommateur peut rendre un choix multiple (`checkbox`) et un `multiselect` via `SmartSelect`.
**Consequences (testable):** multiselect exposé dans la showcase et un formulaire du harnais.

#### FR-9: `relation` + CRUD inline `[Média-rich]` `[Matrice #12]`
Un consommateur peut rendre `relation` (source runtime `crudDataSelect`) avec recherche modale et
**création/édition inline** d'une entité liée.
**Consequences (testable):**
- Source câblée au runtime via `ZRelationSourceRegistry`/`ZRelationCrudRegistry` (à vérifier), jamais
  dans l'annotation `const`.
- Le CRUD inline retourne l'entité créée et la sélectionne sans quitter le formulaire parent.

### 4.4 Puces, tags, listes imbriquées

**Description:** Familles natives (`rowChips`, `tags`, `subItems` avec réordonnancement — supérieur à
DODLP qui n'a aucun réordo, `dynamicItem`). Une variante mineure reste à combler.

**Functional Requirements:**

#### FR-10: `rowChips` `[MVP]` `[Matrice #13]`
Un consommateur peut rendre des puces mono-choix horizontales (`ChoiceChip`).

#### FR-11: `tags` (saisie libre) `[MVP]` `[Matrice #14]`
Un consommateur peut rendre des étiquettes en saisie libre avec bouton `+` explicite (≥ 48 dp).
**Consequences (testable):** parité fonctionnelle avec `flutter_tags` sans en dépendre ; écart de
style pur ajustable via `ZcrudTheme`.

#### FR-12: `subItems` (mini-CRUD + réordonnancement) `[MVP]` `[Matrice #15]`
Un consommateur peut rendre une liste imbriquée (carte + dialog) avec **réordonnancement monter/
descendre**.
**Consequences (testable):** le réordo (`_move()`) est démontré dans la showcase comme écart
**supérieur** à DODLP ; aucune dépendance `drag_and_drop_lists` (morte dans `data_crud`).

#### FR-13: `subItems` variante `itemsAreTags` `[Finitions]` `[Matrice #15b]`
Un consommateur peut afficher les subItems en mode tag + icône + toggle (`ZSubListDisplayMode.tags`,
`InputChip`, zéro dépendance).
**Consequences (testable):** implémenté en `zcrud_core` sans dépendance tierce.
**Notes:** `[NOTE FOR PM]` 0 call-site actif observé dans le DODLP cloné ; besoin réel peut-être motivé
par IFFD/DLCFTI — à confirmer (OQ-6).

#### FR-14: `dynamicItem` (sous-formulaire) `[MVP]` `[Matrice #16]`
Un consommateur peut rendre un sous-formulaire dynamique (`DeepAttribute`).

### 4.5 Média & fichiers

**Description:** Contrat/seam présent dans le cœur (`ZAppFileField`, `ZFilePicker`, `ZFileSource`) ;
les **adaptateurs concrets** vivent dans un binding/satellite média (jamais le cœur). Parité totale =
sélection + recadrage + caméra + scan + vignette vidéo + fichier avancé. Realizes UJ-1.

**Functional Requirements:**

#### FR-15: `file` (multi-sources + fichier avancé) `[Média-rich]` `[Matrice #17]`
Un consommateur peut sélectionner un fichier via un bottom-sheet multi-sources, l'ouvrir (`open_file`)
et le déposer dans une **zone de dépôt** (style `dotted_border`).
**Consequences (testable):** l'adaptateur `ZFilePicker` vit dans `zcrud_get`/satellite média (E7).

#### FR-16: `image` (galerie / caméra + recadrage) `[Média-rich]` `[Matrice #18]`
Un consommateur peut sélectionner une image (galerie multi-sélection, **caméra**) et la **recadrer**.
**Consequences (testable):** sélection/caméra/recadrage via l'adaptateur média, jamais `zcrud_core`.

#### FR-17: `document` (scan → PDF) `[Média-rich]` `[Matrice #19]`
Un consommateur peut scanner un document (`ZFileSource.scan`) et le convertir en PDF.
**Consequences (testable):** service PDF câblé dans le binding/satellite (E7), pas dans le cœur.

#### FR-18: Vignette vidéo `[Média-rich]` `[Matrice §média (video_thumbnail)]`
Un consommateur peut afficher une **vignette** d'un fichier vidéo sélectionné.
**Consequences (testable):** génération de vignette via l'adaptateur média isolé.

### 4.6 Couleur

**Description:** `color` mono natif présent (`ZColorFieldWidget`) + seam `ZcrudScope.colorPicker`.
Parité totale ajoute la **variante multiple** et la **roue HSV/opacité**.

**Functional Requirements:**

#### FR-19: `color` simple (+ roue HSV / opacité) `[MVP]` `[Matrice #28]`
Un consommateur peut choisir une couleur via le picker natif (sliders HSV + hex + récents) ou, via le
seam binding, la **roue HSV/opacité** de référence (`flex_color_picker`) si jugée bloquante.
**Consequences (testable):** `flex_color_picker` reste **côté binding**, jamais `zcrud_core`/`zcrud_geo`.

#### FR-20: `color` multiple `[Média-rich]` `[Matrice #28b]`
Un consommateur peut sélectionner **plusieurs** couleurs (`ZColorConfig.multiple`, `List<int>` ARGB).
**Consequences (testable):**
- `[ASSUMPTION]` variante native `ZColorConfig.multiple` dans `zcrud_core` (reco étude), **pas** de
  fork `color_picker_field` (peu maintenu). Alternative satellite `kind:"colorMulti"` laissée en OQ-2.
- Désérialisation défensive AD-10 de la liste ARGB.

### 4.7 Rich-text (Markdown, HTML WYSIWYG)

**Description:** Markdown/richText couverts par `zcrud_markdown` (Quill + LaTeX) — **câblage**. La
parité totale **verrouillée** exige le **HTML WYSIWYG** (`html_editor_enhanced`) + le rendu HTML
(`flutter_html`), dans un **nouveau satellite dédié** (jamais `zcrud_markdown`). La WebView Summernote
est une **2ᵉ voie d'état** en tension avec AD-2 : **assumée et isolée**, pas ignorée. Realizes UJ-1.

**Functional Requirements:**

#### FR-21: `markdown` / `inlineMarkdown` / `richText` `[MVP]` `[Matrice #30, #31, #35]`
Un consommateur peut rendre un éditeur Markdown bloc (toolbar, LaTeX, table, dialog plein écran), une
variante inline, et le `richText` Delta interne, via `zcrud_markdown`.
**Consequences (testable):** chaque éditeur rich-text a un controller isolé (conforme AD-2) ; LaTeX
hors sous-ensemble `flutter_math_fork` → placeholder thémé (pas de crash, pas de `flutter_tex`).

#### FR-22: `html` / `inlineHtml` WYSIWYG (édition) `[Média-rich]` `[Matrice #32, #34]`
Un consommateur peut éditer du HTML en **WYSIWYG** (`html_editor_enhanced`) dans un satellite dédié.
**Consequences (testable):**
- La WebView est **isolée** dans le satellite ; elle ne casse pas la granularité de rebuild des autres
  champs (NFR-1).
- Round-trip HTML riche ⇄ Delta à **pertes bornées documentées**.

#### FR-23: Rendu HTML natif (lecture) `[Média-rich]` `[Matrice #32b]`
Un consommateur peut afficher du HTML arbitraire en lecture (`flutter_html`).
**Consequences (testable):** rendu dans le même satellite ; pertes de round-trip documentées (code
inline, styles CSS exotiques).

### 4.8 Champs intl & géo (satellites existants — câblage)

**Description:** `zcrud_intl` (phone/country/address) et `zcrud_geo` (location/geoArea) **existent** ;
l'essentiel du travail est le **câblage** `registry.register(kind, …)` côté binding. Un seul vrai gap
neuf : l'UI de stylisation fill/stroke de `geoArea`. Realizes UJ-1.

**Functional Requirements:**

#### FR-24: `phoneNumber` (câblage `zcrud_intl`) `[MVP]` `[Matrice #22]`
Un consommateur peut rendre `phoneNumber` (`ZPhoneFieldWidget`, `phone_numbers_parser`).
**Consequences (testable):**
- Le câblage `registry.register('phoneNumber', …)` manquant est ajouté au binding.
- `[ASSUMPTION]` sélecteur pays = panneau **inline** par défaut (variante dialog en OQ-3).
- `[ASSUMPTION]` validateur national Togo = **chiffres nus** `length:8` par défaut (parité stricte
  `length:11` en OQ-4).
- **Migration données** String legacy → `ZPhoneNumber` E.164 = ETL app-side (NFR-8), hors widget.

#### FR-25: `country` (câblage `zcrud_intl`) `[MVP]` `[Matrice #23]`
Un consommateur peut rendre `country` (`ZCountryFieldWidget`, zéro dépendance tierce).
**Consequences (testable):** couverture l10n JSON des pays vérifiée ; aucune dépendance
`country_picker` (code mort DODLP).

#### FR-26: `address` (câblage `zcrud_intl`) `[MVP]` `[Matrice #24]`
Un consommateur peut rendre `address` (`ZAddressFieldWidget`, auto-enregistré `'address'`/
`'addressSearch'`).
**Consequences (testable):** widget **présent** (pas un gap) ; géocodage de recherche éventuel = adapter
`zcrud_geo` (amélioration hors parité).

#### FR-27: `location` `[MVP]` `[Matrice #20]`
Un consommateur peut rendre un point géographique (`zcrud_geo`).

#### FR-28: `geoArea` + UI style-picker fill/stroke `[Finitions]` `[Matrice #21]`
Un consommateur peut styliser une zone géographique (polygone/cercle) avec toolbar fill/stroke.
**Consequences (testable):** modèle `ZGeoShapeStyle` déjà prêt ; l'UI **réutilise** le seam
`ZColorPicker`/`ZColorPickerDialog` (pas de 2ᵉ picker). Reporté à l'éditeur geofence interactif.

### 4.9 Champs natifs spécialisés & seams

**Description:** Champs natifs « 0 dépendance » (rating, slider, signature), layout stepper, et seams
d'extension (hidden/widget/custom). Écarts purement cosmétiques absorbés par thème.

**Functional Requirements:**

#### FR-29: `rating` `[MVP]` `[Matrice #25]`
Un consommateur peut rendre une note en étoiles (max configurable, toggle-clear, a11y) — supérieur à
l'implémentation ad-hoc DODLP.

#### FR-30: `slider` `[MVP]` `[Matrice #26]`
Un consommateur peut rendre un curseur (`min`/`max`/`divisions`).

#### FR-31: `signature` `[MVP]` `[Matrice #27]`
Un consommateur peut capturer une signature manuscrite (strokes vectoriels, 0 dépendance).
**Consequences (testable):** **Migration données** PNG bitmap DODLP → strokes = ETL app-side **non
réversible** (NFR-8), hors widget.

#### FR-32: `stepper` / sections `[MVP]` `[Matrice #36]`
Un consommateur peut regrouper des champs en étapes/sections (`ZStepperConfig`) — répare le bug DODLP
`indicatorSize`.
**Consequences (testable):** paramètre de `DynamicEdition`, pas un widget de champ.

#### FR-33: Seams `hidden` / `widget` / `custom` `[MVP]` `[Matrice #38, #39, #40]`
Un consommateur peut déclarer un champ non rendu (`hidden`), un builder libre (`widget`) ou un type
projeté par l'app (`custom`), résolus via `ZWidgetRegistry`/`ZTypeRegistry`.

### 4.10 Champs de finition additionnels

**Description:** Capacités DODLP hors `EditionFieldType` que la parité totale verrouillée fait entrer
dans le périmètre (Finitions). Chacune vit hors `zcrud_core` si elle porte une dépendance lourde.

**Functional Requirements:**

#### FR-34: PIN `[Finitions]` `[Matrice §hors-enum (pinput)]`
Un consommateur peut rendre un champ PIN (saisie code segmentée).
**Consequences (testable):** cible ≥ 48 dp par cellule ; `Semantics` sur la progression.

#### FR-35: Autocomplétion `[Finitions]` `[Matrice §hors-enum (autocomplete)]`
Un consommateur peut rendre un champ texte à **autocomplétion** (suggestions filtrées).

#### FR-36: Table éditable `[Finitions]` `[Matrice §hors-enum (editable)]`
Un consommateur peut rendre une **table éditable** (cellules modifiables en place).
**Consequences (testable):** rendu virtualisé (pas de `ListView(children:[...])`).

#### FR-37: `icon` picker `[Finitions]` `[Matrice #29]`
Un consommateur peut rendre un sélecteur d'icône (registre d'icônes, satellite si besoin).
**Notes:** `[NOTE FOR PM]` aucun besoin produit prouvé ; la parité totale pousse à combler (OQ-6).

### 4.11 Aération / spacing spec

**Description:** Répliquer les **mesures** d'aération DODLP (dp) par tokens injectés, jamais les
couleurs codées. Trois écarts d'aération connus à trancher explicitement. Realizes UJ-1.

**Functional Requirements:**

#### FR-38: Tokens de layout & 3 écarts d'aération `[MVP]` `[Matrice §aération]`
Un consommateur peut appliquer les mesures d'aération DODLP via des tokens `ThemeExtension`/
`ZcrudTheme` (ex. `runGutter`, `formPadding`, spacer inter-champ).
**Consequences (testable):**
- Aucune couleur/valeur codée en dur (FR-26) ; les couleurs dérivent du `ColorScheme`.
- Les **3 écarts d'aération** (gouttière asymétrique, spacer inter-champ, padding d'écran) sont
  tranchés **explicitement** dans le PRD/architecture, pas subis.

### 4.12 Harnais de parité (≥ 6 formulaires DODLP)

**Description:** Preuve de non-régression bout-en-bout : rejouer ≥ 6 formulaires réels de DODLP dans
`example/` avec données fictives, chacun couvrant un **axe de risque distinct**. Realizes UJ-1.

**Functional Requirements:**

#### FR-39: Harnais 6 formulaires dans `example/` `[MVP]` `[Matrice §5.2]`
Un mainteneur peut ouvrir ≥ 6 formulaires DODLP répliqués et démontrer l'absence de régression
visuelle bloquante vs la référence DODLP.
**Consequences (testable):**
- Les 6 axes sont couverts : (1) texte/nombre/date dense + SM-1 ; (2) sélections `select`/`radio`/
  `relation`+`crudDataSelect` ; (3) média ; (4) rich-text markdown/LaTeX/html ; (5) intl/géo (phone/
  country/location/geoArea) ; (6) spécialisés/imbriqués (rating/slider/signature/color/subItems+réordo).
- Données **fictives**, aucun secret, aucune dépendance backend DODLP.
- `[ASSUMPTION]` shortlist provisoire (Cargaison, DemandeDepotage, Consignee/BoatService,
  AuthProfileData, ArticleBep/Cotation, ConvocationBmd) à figer sur « couverture max types × axes »
  (OQ-7).

### 4.13 Page showcase exhaustive

**Description:** Page unique de `example/` démontrant chaque `EditionFieldType` × chaque variante ×
chaque état transverse. Sert de preuve de complétude, de tableau de bord du reste-à-faire, et de banc
SM-1. Realizes UJ-2.

**Functional Requirements:**

#### FR-40: Showcase tous types × variantes × états `[MVP]` `[Matrice §5.1]`
Un owner peut vérifier sur une page la complétude et l'état de chaque champ.
**Consequences (testable):**
- Chaque `EditionFieldType` (40) et ses variantes sont démontrés ; les décisions natif-vs-package
  montrées côte à côte quand possible (`color` sliders vs roue ; `select`/`radio` natif vs modal ;
  phone inline vs dialog).
- États transverses par champ : read-only, désactivé, erreur de validation, valeur initiale,
  conditionnel, **RTL**, **thème clair/sombre**.
- Gaps résiduels **étiquetés « ABSENT / à combler »** (pas masqués) : `dateRange` (avant FR-5),
  `color` multiple, `icon`, `subItems.itemsAreTags`, WYSIWYG HTML.
- Un formulaire de frappe intensive prouve **SM-1** (100 caractères → seul le champ courant se
  reconstruit, zéro perte de focus).

### 4.14 Traçabilité & phasage (synthèse)

| FR | Capacité | Item matrice | Phase | Couverture zcrud |
|----|----------|--------------|-------|------------------|
| FR-1 | text/multiline/password | #1,#2,#37 | MVP | NATIF (polir) |
| FR-2 | number/integer/float+% +devise | #3,#4,#5 | MVP | NATIF (polir) |
| FR-3 | boolean | #6 | MVP | NATIF |
| FR-4 | dateTime/time | #7,#8 | MVP | NATIF |
| FR-5 | **dateRange** | §2 P1 | MVP | **NET-NEW `zcrud_core`** |
| FR-6 | select | #9 | Média-rich | NATIF + fork `awesome_select` |
| FR-7 | radio (modal) | #10 | Média-rich | NATIF + fork |
| FR-8 | checkbox/multiselect | #11 | Média-rich | NATIF + fork |
| FR-9 | relation + CRUD inline | #12 | Média-rich | NATIF + fork |
| FR-10 | rowChips | #13 | MVP | NATIF |
| FR-11 | tags | #14 | MVP | NATIF |
| FR-12 | subItems + réordo | #15 | MVP | NATIF (supérieur) |
| FR-13 | subItems.itemsAreTags | #15b | Finitions | ABSENT → `zcrud_core` |
| FR-14 | dynamicItem | #16 | MVP | NATIF |
| FR-15 | file (multi-sources + avancé) | #17 | Média-rich | impl différée (binding) |
| FR-16 | image (caméra + recadrage) | #18 | Média-rich | impl différée (binding) |
| FR-17 | document (scan→PDF) | #19 | Média-rich | impl différée (binding) |
| FR-18 | vignette vidéo | §média | Média-rich | ABSENT → satellite média |
| FR-19 | color simple (+ roue/opacité) | #28 | MVP | NATIF + seam binding |
| FR-20 | color multiple | #28b | Média-rich | ABSENT → `zcrud_core` |
| FR-21 | markdown/inlineMarkdown/richText | #30,#31,#35 | MVP | SATELLITE (câblage) |
| FR-22 | html WYSIWYG édition | #32,#34 | Média-rich | ABSENT → satellite `zcrud_html` |
| FR-23 | rendu HTML | #32b | Média-rich | ABSENT → satellite `zcrud_html` |
| FR-24 | phoneNumber (câblage) | #22 | MVP | SATELLITE (câblage) |
| FR-25 | country (câblage) | #23 | MVP | SATELLITE |
| FR-26 | address (câblage) | #24 | MVP | SATELLITE (présent) |
| FR-27 | location | #20 | MVP | SATELLITE |
| FR-28 | geoArea style-picker | #21 | Finitions | partiel → `zcrud_geo` |
| FR-29 | rating | #25 | MVP | NATIF (supérieur) |
| FR-30 | slider | #26 | MVP | NATIF |
| FR-31 | signature | #27 | MVP | NATIF |
| FR-32 | stepper/sections | #36 | MVP | NATIF |
| FR-33 | hidden/widget/custom | #38,#39,#40 | MVP | NATIF (seams) |
| FR-34 | PIN | §hors-enum | Finitions | ABSENT → satellite |
| FR-35 | autocomplétion | §hors-enum | Finitions | ABSENT → satellite |
| FR-36 | table éditable | §hors-enum | Finitions | ABSENT → satellite |
| FR-37 | icon picker | #29 | Finitions | ABSENT → satellite |
| FR-38 | spacing spec / aération | §aération | MVP | tokens `ThemeExtension` |
| FR-39 | harnais 6 formulaires | §5.2 | MVP | `example/` |
| FR-40 | showcase exhaustive | §5.1 | MVP | `example/` |

**Couverture de parité** : **tous** les items de `FIELD-PACKAGE-MATRIX.md` (rows 1–40 + variantes 15b,
28b, 32b, 34 + `dateRange` + capacités hors-enum PIN/autocomplete/table + aération + harnais + showcase)
sont tracés en FR. **Seule exception assumée** : row #33 (LaTeX fallback SVG `flutter_tex`), **non
couvert par conception** (banni par le test d'isolation → placeholder thémé) → § 5 Non-Goals.

## 5. Non-Goals (Explicit)

- **Décisions d'architecture** — emplacement/nom des satellites (`zcrud_select`, `zcrud_html`,
  `zcrud_media`…), fork épinglé vs vendoring, ré-organisation des packages → **phase architecture**.
  Ce PRD reste au niveau exigence.
- **`flutter_form_builder` (widgets)** — écarté définitivement (familles natives plus conformes AD-2 ;
  seuls les validateurs `form_builder_validators` sont réutilisés).
- **LaTeX fallback SVG `flutter_tex`** (Matrice #33) — `[NON-GOAL for MVP et au-delà]` gap **assumé par
  architecture** (banni par le test d'isolation) ; formule hors sous-ensemble `flutter_math_fork` →
  placeholder thémé, pas de crash.
- **Migrations de données (ETL app-side)** — backfill `signature` (PNG→strokes, non réversible) et
  `phoneNumber` (String→`ZPhoneNumber` E.164) : **travaux ETL de l'app**, pas des gaps de widget zcrud
  (voir NFR-8).
- **Parité pixel-exacte** — la parité visée est **fonctionnelle** + aération tranchée, pas une copie
  pixel des couleurs codées DODLP. La parité visuelle stricte est une OQ owner (OQ-1).
- **CI/CD, distribution, tags de version** — hors périmètre produit.

## 6. MVP Scope

### 6.1 In Scope

- Champs de base natifs confirmés/polis (FR-1..FR-4), + `hidden`/`widget`/`custom` (FR-33),
  rating/slider/signature/stepper (FR-29..FR-32), rowChips/tags/subItems+réordo/dynamicItem
  (FR-10..FR-12, FR-14), color simple (FR-19).
- **`dateRange`** net-new (FR-5) — story `zcrud_core` sérialisée.
- Câblage des satellites existants : phone/country/address/location + markdown (FR-21, FR-24..FR-27).
- **Spacing spec** + 3 écarts d'aération tranchés (FR-38).
- **Harnais 6 formulaires** (FR-39) + **page showcase exhaustive** (FR-40) — la preuve de
  non-régression et le socle SM-1.

### 6.2 Out of Scope for MVP

- **Phase Média-rich** (v1.x) : sélections `awesome_select` (FR-6..FR-9), média
  capture/recadrage/scan/vidéo (FR-15..FR-18), color multiple (FR-20), rich-text HTML WYSIWYG +
  rendu HTML (FR-22, FR-23). *Raison : dépendances lourdes/satellites neufs + tension AD-2 à isoler.*
- **Phase Finitions** (v1.x) : PIN (FR-34), autocomplétion (FR-35), table éditable (FR-36),
  `subItems.itemsAreTags` (FR-13), `geoArea` style-picker (FR-28), icon picker (FR-37), parité pixel
  optionnelle. `[NOTE FOR PM]` FR-13 et FR-37 sont sans call-site actif prouvé — revisiter si
  IFFD/DLCFTI les motivent (OQ-6).

> Le phasage est **indicatif** ; le séquencement fin (respect du graphe de dépendances des epics) est
> fixé au sprint-planning. La **parité totale** reste l'invariant, quel que soit le découpage.

## 7. Success Metrics

**Primary**
- **SM-1 (objectif produit n°1)** : sur le formulaire de frappe intensive de la showcase, taper 100
  caractères ne reconstruit **que le champ courant**, **zéro perte de focus** (test widget +
  profiling). Validates FR-1, FR-40 ; s'applique à tout champ à saisie (incl. FR-22 WYSIWYG isolé).
- **SM-2 : parité totale traçable** — 100 % des items de `FIELD-PACKAGE-MATRIX.md` ont un statut connu
  (livré / câblé / gap consciemment reporté avec justification écrite). Aucun « on ne sait pas ».
  Validates FR-1..FR-40.
- **SM-3 : non-régression visuelle prouvée** — les ≥ 6 formulaires du harnais rendent sans écart
  visuel **bloquant** vs la référence DODLP (les 3 écarts d'aération tranchés explicitement).
  Validates FR-38, FR-39.

**Secondary**
- **SM-4 : complétude showcase** — chaque `EditionFieldType` (40) + variantes + états transverses
  (read-only, désactivé, erreur, RTL, thème) démontrés ; gaps résiduels étiquetés. Validates FR-40.
- **SM-5 : `dateRange` livré** — enum + `ZDateRange` + widget + `ZFieldSpec` généré + test de
  rétro-compat vert, présent en showcase et dans le harnais. Validates FR-5.
- **SM-6 : isolation** — CORE OUT=0 (grep : aucune dépendance lourde ni `zcrud_*` dans
  `zcrud_core/pubspec.yaml`) à chaque story. Validates NFR-2.

**Counter-metrics (do not optimize)**
- **SM-C1 : ne pas courir la parité pixel** — chercher l'égalité au pixel avec les couleurs codées de
  DODLP **régresserait** des points où zcrud est déjà supérieur (grille directionnelle, `Semantics`,
  ≥ 48 dp). Contrebalance SM-3. La parité est fonctionnelle, pas pixel.
- **SM-C2 : ne pas gonfler le cœur** — ne pas atteindre la parité en tirant une dépendance dans
  `zcrud_core`. Contrebalance SM-2/SM-1 : la vitesse de livraison ne justifie jamais une violation
  AD-1 (CORE OUT=0).

## Cross-Cutting NFRs *(invariants d'architecture — s'appliquent à chaque FR)*

- **NFR-1 — SM-1 / AD-2 / AD-15 (rebuild granulaire)** : aucun état de formulaire global ; chaque
  champ n'écoute que sa tranche (`ZFieldListenableBuilder`). Le seam `ZWidgetRegistry.register(kind,
  builder)` ne livre que `ctx.value`/`ctx.onChanged`, jamais le `ZFormController`. Tout widget tiers à
  état propre — **WebView WYSIWYG (FR-22)** au premier chef — est **isolé** et piloté sans casser la
  granularité des autres champs. Interdits : `setState` d'écran, recréation de `TextEditingController`
  au rebuild, ré-injection de valeur écrasant la sélection.
- **NFR-2 — AD-1 (isolation, CORE OUT=0)** : tout adaptateur de package tiers vit **hors `zcrud_core`**
  (satellite ou binding). Le fork `awesome_select`, la WebView WYSIWYG, `flex_color_picker`, les
  pickers média : jamais dans le cœur. Vérifié par grep sur `zcrud_core/pubspec.yaml`.
- **NFR-3 — AD-13 (RTL & a11y)** : variantes **directionnelles** (`EdgeInsetsDirectional`,
  `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`) ; `Semantics` explicites ;
  cibles ≥ 48 dp ; `ListView.builder` (jamais `ListView(children:[...])`). Reduce Motion respecté.
- **NFR-4 — FR-26 (thème & l10n injectés)** : aucun style/libellé/couleur codé en dur ; thème injecté
  via `ZcrudScope`/`ThemeExtension`, repli `Theme.of(context)`. L'aération DODLP est répliquée par
  **tokens** (dp), les couleurs **dérivées** du `ColorScheme`.
- **NFR-5 — AD-10 (désérialisation défensive)** : **tout nouveau type de valeur** (`ZDateRange`, liste
  ARGB de `color` multiple, PIN, valeur HTML…) doit tolérer un champ absent/corrompu sans faire échouer
  le parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`) ; évolution de schéma
  **additive seulement**.
- **NFR-6 — codegen & rétro-compat (AD-3)** : chaque nouveau type émet son `ZFieldSpec` via
  `zcrud_generator` ; les `*.g.dart` de `packages/*/lib/` sont régénérés et commités ; test de
  rétro-compatibilité de sérialisation vert (gate CI `codegen-distribution`).
- **NFR-7 — non-régression visuelle prouvée** : le harnais (FR-39) est le critère d'acceptation de la
  migration ; aucun écart visuel bloquant vs DODLP hors les 3 écarts d'aération tranchés.
- **NFR-8 — migrations de données app-side (risque/dépendance nommé)** : `signature` (PNG bitmap
  DODLP → strokes vectoriels, **non réversible**) et `phoneNumber` (String legacy → `ZPhoneNumber`
  E.164) exigent un **backfill ETL de l'app** ; sans lui, perte silencieuse à la migration. Le widget
  est prêt des deux côtés — le risque est **hors packages zcrud** mais **bloquant** pour la migration
  DODLP. À planifier côté app, pas dans les epics zcrud.
- **NFR-9 — poids des dépendances & surface satellites** : média (`image_cropper`/`camera`/
  `video_thumbnail`), WebView WYSIWYG, roue couleur alourdissent l'app ; l'isolation AD-1 contient le
  risque mais le nombre de satellites neufs augmente la surface à maintenir. Chaque satellite neuf est
  justifié en architecture (perf/poids bornés).

## Constraints and Guardrails *(décisions owner VERROUILLÉES — non re-litigables ici)*

- **`awesome_select` = FORK maintenu par nous.** Adopté (`SmartSelect` :
  select/radio/relation/multiselect, modal S2 + recherche + CRUD inline) via un **fork que nous
  maintenons** (élimine le risque du `ref: master` flottant), enveloppé derrière un
  `ZFieldWidgetBuilder` dans un **satellite** (jamais `zcrud_core`). Mécanique exacte (fork épinglé vs
  vendoring) = **phase architecture**. Transfère une charge de maintenance (suivi upstream/sécurité/
  compat Flutter) sur l'équipe zcrud.
- **PARITÉ DODLP TOTALE.** État-cible = supporter **tout** ce que le module CRUD de DODLP savait
  rendre, **WYSIWYG HTML inclus**. Plus de gap « optionnel ». Livraison phasée, parité totale non.
- **Séquencement `zcrud_core`.** Toute story touchant `zcrud_core` (FR-5 `dateRange`, FR-13/FR-20 si
  natifs cœur) est **sérialisée** — une seule story écrit `zcrud_core` à la fois (règle de
  parallélisation `CLAUDE.md`).

## Why Now

L'étude d'intégration (2026-07-17) vient de **localiser** le vrai défaut (le `setState()` d'écran, déjà
corrigé par conception) et de **prouver sur disque** que le gros du travail natif est fait. La fenêtre
est ouverte : le reste n'est plus une réécriture mais un achèvement discipliné, et tant que la parité
n'est pas **prouvée**, aucune app (DODLP en tête) ne peut migrer sans risque — la valeur de zcrud reste
théorique. Prouver la parité maintenant débloque la première adoption réelle.

## 8. Open Questions

1. **OQ-1 — Niveau de parité pixel exigé** : parité *fonctionnelle* (défaut retenu) vs parité
   *visuelle stricte* (déclenche les stories `zcrud_core` de Finitions : `runGutter`, `formPadding`,
   look « boîte grise » des sections `MyStickyHeader`). *Owner.*
2. **OQ-2 — `color` multiple** : variante native `ZColorConfig.multiple` dans `zcrud_core` (défaut
   recommandé) vs satellite `kind:"colorMulti"`. Ne pas forker `color_picker_field`. *Owner/archi.*
3. **OQ-3 — Sélecteur pays téléphone** : panneau **inline** (défaut) vs variante `showDialog`/
   `showModalBottomSheet` pour coller au dialog DODLP. *Owner.*
4. **OQ-4 — Validateur national Togo** : chiffres nus `length:8` (défaut, plus propre) vs formaté
   `length:11` (parité stricte). Seuils d'erreur observables différents. *Owner.*
5. **OQ-5 — WYSIWYG HTML** : la parité totale verrouillée **implique** la WYSIWYG
   (`html_editor_enhanced`, satellite dédié + tension AD-2). Confirmer explicitement vu le coût AD-2,
   ou accepter le round-trip `ZHtmlCodec`→Delta pour l'HTML simple comme évolution assumée. *Owner —
   défaut retenu : oui WYSIWYG (FR-22/FR-23).*
6. **OQ-6 — `subItems.itemsAreTags` (FR-13) & `icon` (FR-37)** : combler (parité totale) ou reporter
   (aucun call-site actif observé ; peut-être motivé par IFFD/DLCFTI). *Owner.*
7. **OQ-7 — Sélection finale des 6 formulaires du harnais** : figer la shortlist provisoire sur le
   critère « couverture maximale de types × axes de risque ». *PM, à l'ouverture de l'epic harnais.*

## 9. Assumptions Index

- `[ASSUMPTION]` §2.1 — IFFD/DLCFTI bénéficiaires indirects ; motivation de variantes basse-priorité à
  confirmer.
- `[ASSUMPTION]` §4.6 FR-20 — `color` multiple = variante native `ZColorConfig.multiple` par défaut
  (OQ-2).
- `[ASSUMPTION]` §4.8 FR-24 — sélecteur pays téléphone inline par défaut (OQ-3) ; validateur Togo
  `length:8` par défaut (OQ-4).
- `[ASSUMPTION]` §4.12 FR-39 — shortlist des 6 formulaires provisoire (OQ-7).
- `[ASSUMPTION]` §4.7 FR-22/FR-23 — WYSIWYG HTML retenue par défaut (parité totale verrouillée),
  malgré le coût AD-2 (OQ-5).
- `[NOTE FOR PM]` §4.4 FR-13 / §4.10 FR-37 — combler `itemsAreTags` et `icon` sans besoin prouvé
  (OQ-6).

## Références (source of truth)

- Brief : `_bmad-output/planning-artifacts/briefs/brief-zcrud-form-parity-2026-07-18/brief.md`.
- Matrice champ×package (base des FR) :
  `docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md` (+ `STUDY.md`,
  `NEXT-ITERATION-SCOPE.md`, 13 rapports de lentille).
- Architecture (16 AD) :
  `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`.
- Enum des champs :
  `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` (40 valeurs).
- Référence DODLP (lecture seule) : `dodlp-otr/lib/modules/data_crud/`.
