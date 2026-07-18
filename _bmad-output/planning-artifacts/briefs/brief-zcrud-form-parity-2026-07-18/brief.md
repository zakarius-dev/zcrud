---
title: "Product Brief — zcrud « Formulaire : parité DODLP totale »"
status: draft
created: 2026-07-18
updated: 2026-07-18
---

# Product Brief: zcrud — Formulaire « Parité DODLP totale »

> **Mode de production** : brief rédigé en **non-interactif** (fast path headless), ancré sur
> l'étude d'intégration `docs/dodlp-form-integration-study-2026-07-17/` (STUDY.md,
> FIELD-PACKAGE-MATRIX.md, NEXT-ITERATION-SCOPE.md) et sur `CLAUDE.md` (16 AD, objectif
> produit n°1). Chaque arbitrage non tranché par le owner a retenu **l'option conservatrice**
> (natif zcrud, isolation AD-1, pas de dépendance lourde), consignée dans `.memlog.md`. Les
> décisions **verrouillées** par le owner (fork `awesome_select`, parité DODLP totale) sont
> encodées comme **contraintes non re-litigables** de ce brief. `[ASSUMPTION]` marque toute
> inférence à confirmer.

## Executive Summary

zcrud a déjà réimplémenté nativement — theme-driven et conforme à la réactivité Flutter-native
(AD-2) — la quasi-totalité des familles de champ que **DODLP** rendait via une pile de packages
tiers (`flutter_form_builder`, `flutter_switch`, `country_picker`, `intl_phone_number_input`,
`awesome_select`, aération interne). L'étude d'intégration l'a prouvé sur disque : le gros du
travail est fait, et le bug historique de jank/perte de focus ne venait **pas** des packages de
rendu mais d'un `setState()` d'écran que `ZFormController`/`ZFieldListenableBuilder` corrige par
conception. Ce qui reste n'est plus une réécriture mais un **achèvement discipliné** : câbler les
adaptateurs, combler une poignée de vrais gaps, et **prouver** que la migration ne régresse rien.

Cette itération pose un objectif dur : **parité DODLP totale**. Il n'y a plus de gap « optionnel ».
Tout ce que le module CRUD de DODLP savait rendre — chaque type de champ et chaque variante —
devient périmètre-cible. La livraison est **phasée** (MVP : champs de base polis + `dateRange` +
showcase + harnais → média/capture/rich-text/WYSIWYG → finitions), mais la parité totale est
l'état-cible non négociable, pas un sous-ensemble choisi.

La preuve de succès est concrète et vérifiable, pas déclarative : (1) un **harnais de parité** qui
réplique **≥ 6 formulaires réels de DODLP** dans l'app Exemple (`example/`) avec données fictives,
pour démontrer bout-en-bout la **non-régression visuelle** à la migration ; (2) une **page showcase
exhaustive** couvrant **tous** les `EditionFieldType` et toutes leurs variantes, servant à la fois
de référence de complétude et de banc SM-1 ; (3) l'ajout du champ **`dateRange`** aujourd'hui absent.
Le consommateur prioritaire est **DODLP** (GetX, binding `zcrud_get`), puis **lex_douane** (Riverpod).

## The Problem

DODLP porte un moteur CRUD déclaratif mûr : 54 entités `DynamicModel`, un `edition_screen.dart` de
4455 lignes, des dizaines de types de champ, un habillage visuel calibré (aération, grille 12
colonnes, steppers, sélecteurs modaux). Tout cela repose sur une pile de packages tiers dont
plusieurs sont **fragiles** — au premier rang, `awesome_select` distribué en **fork git non
pub.dev, `ref: master` flottant, mainteneur unique**, sans garantie semver. Le moteur souffre aussi
d'un défaut de conception structurel : chaque frappe déclenche un `setState()` à l'échelle de
l'écran (contournement `Future.delayed(300ms)` constaté dans le code DODLP), d'où jank et pertes de
focus — l'objectif produit n°1 de zcrud.

zcrud existe pour extraire ce moteur en packages réutilisables, corriger le bug par conception, et
le distribuer proprement (en dépendance git) à DODLP, IFFD, DLCFTI puis lex_douane. Mais tant que la
**parité n'est pas prouvée**, aucune de ces apps ne peut migrer sans risque : une divergence
visuelle invisible en revue de code devient une régression perçue en production, et un type de champ
manquant bloque une entité entière. Le coût du statu quo est double — DODLP reste prisonnier de
dépendances fragiles, et la valeur de zcrud reste théorique tant qu'une app réelle ne l'a pas
adopté sans perte.

Le problème central de cette itération n'est donc **pas** « réécrire les widgets » (l'étude montre
qu'ils existent, souvent supérieurs en a11y/RTL/thème), mais **fermer l'écart de parité de bout en
bout et le démontrer** : combler les derniers gaps réels, trancher les décisions natif-vs-package
laissées ouvertes, et livrer une preuve visuelle et fonctionnelle qu'une app DODLP migre sans
régression.

## The Solution

Trois livrables produit structurent l'itération, chacun exécuté via le cycle BMAD strict
(create-story → dev-story → code-review → done), story par story, les touches à `zcrud_core`
sérialisées (une seule story y écrit à la fois).

1. **Harnais de parité bout-en-bout** — répliquer **≥ 6 formulaires fonctionnels de DODLP** dans
   `example/`, avec **données fictives** et **aucun secret**, en reproduisant le rendu visuel DODLP
   (aération incluse, cf. spacing spec de l'étude) via les adaptateurs de champ et les tokens de
   thème. Chaque formulaire couvre un **axe de risque distinct** (texte/nombre/date dense ;
   sélections `select`/`radio`/`relation` ; média ; rich-text ; intl/géo ; spécialisés/imbriqués).
   Critère d'acceptation : **aucune régression visuelle** démontrée à la migration.

2. **Page showcase exhaustive** — une page de l'app Exemple montrant **chaque `EditionFieldType` ×
   chaque variante** (source de vérité de l'enum :
   `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`, 40 valeurs), avec les états
   transverses par champ (read-only, désactivé, erreur de validation, valeur initiale, conditionnel,
   RTL, thème clair/sombre). Elle sert de **preuve de complétude**, de **tableau de bord du
   reste-à-faire** (les gaps y figurent, étiquetés « ABSENT / à combler ») et de **banc SM-1** (taper
   100 caractères ne reconstruit que le champ courant, zéro perte de focus).

3. **Champ `dateRange`** — ajouter le type aujourd'hui absent (grep négatif RC=1). Patron aligné sur
   `dateTime` : enum `dateRange` (camelCase), valeur `ZDateRange{start, end}` sérialisable ISO-8601 en
   désérialisation défensive (AD-10, `end >= start`, `null` toléré si optionnel), widget
   `ZDateRangeFieldWidget` monté sous `ZFieldListenableBuilder` (SM-1), picker **natif
   `showDateRangePicker`** (recommandation étude ferme : **pas** `table_calendar`), directionnel
   (AD-13), et génération du `ZFieldSpec` par `zcrud_generator` + test de rétro-compat de sérialisation.

Autour de ces trois livrables, le travail de parité se répartit entre **câblage** (enregistrer les
adaptateurs existants via `registry.register(kind, builder)` dans le binding), **finitions de thème**
(reproduire les mesures DODLP par tokens `ZcrudTheme`/`ThemeExtension`, jamais les couleurs
hardcodées), et **quelques gaps neufs** à combler proprement (énumérés en Scope). L'architecture
détaillée (emplacement des satellites, mécanique du fork) relève de la **phase suivante** — ce brief
ne la tranche pas.

## What Makes This Different

- **La preuve avant la promesse.** L'originalité de cette itération n'est pas un widget, c'est un
  **dispositif de preuve** : le harnais 6-formulaires et la showcase exhaustive transforment « on
  pense que ça migre » en « voici les formulaires DODLP rejoués sans régression ». C'est ce qui rend
  une migration réelle (DODLP) défendable.
- **On corrige un vrai défaut, pas un défaut supposé.** L'étude a localisé le bug historique (le
  `setState()` d'écran) et montré que la correction (`ZFormController`/tranche) est déjà en place. La
  parité zcrud arrive donc avec un **avantage net** : rebuild granulaire, RTL/a11y directionnels,
  thème dérivé au lieu de couleurs codées, format téléphone canonique. La migration **améliore**
  plusieurs invariants — le risque à gérer n'est pas une régression technique mais une **divergence
  visuelle assumée** à faire valider.
- **Isolation par conception.** Chaque adaptateur de package tiers vit **hors `zcrud_core`** (AD-1,
  CORE OUT=0) : le cœur ne tire ni Firebase, ni Syncfusion, ni WebView, ni le fork `awesome_select`.
  Un consommateur qui n'a pas besoin d'un champ lourd ne le paie pas. C'est ce qui distingue zcrud de
  la pile monolithique de DODLP.

## Who This Serves

- **Consommateur prioritaire — DODLP** (GetX, binding `zcrud_get`). C'est l'app dont la parité est
  mesurée, le référentiel visuel du harnais, et le premier bénéficiaire de la sortie des dépendances
  fragiles. Succès pour elle = migrer ses formulaires sans que ses utilisateurs perçoivent une
  régression, et se débarrasser du `ref: master` flottant d'`awesome_select`.
- **Consommateur suivant — lex_douane** (Riverpod, binding `zcrud_riverpod`). Réutilise le même
  moteur et la même showcase comme référence de complétude ; valide que la parité n'est pas
  DODLP-spécifique mais bien portée par le cœur neutre.
- **[ASSUMPTION] IFFD / DLCFTI** — les deux autres apps historiques du moteur dupliqué. Bénéficiaires
  indirects (mêmes packages) ; certaines variantes basse-priorité (ex. `subItems.itemsAreTags`, 0
  call-site actif dans le DODLP cloné) pourraient être motivées par leur usage — à confirmer.
- **Développeurs zcrud / mainteneurs** — la showcase et le harnais deviennent leur **filet de
  régression** et leur documentation vivante des champs supportés.

## Success Criteria

- **Non-régression visuelle prouvée.** Les **≥ 6 formulaires DODLP** rejoués dans `example/` rendent
  sans écart visuel bloquant vs la référence DODLP (les 3 écarts d'aération connus — gouttière
  asymétrique, spacer inter-champ, padding d'écran — tranchés explicitement, pas subis).
- **Showcase exhaustive verte.** Chaque `EditionFieldType` (40) et ses variantes sont démontrés ;
  les gaps résiduels y sont **explicitement étiquetés**, pas masqués. La page couvre les états
  transverses (read-only, désactivé, erreur, RTL, thème clair/sombre).
- **SM-1 tenu (objectif produit n°1).** Sur le formulaire de frappe intensive de la showcase, taper
  100 caractères ne reconstruit que le champ courant, **zéro perte de focus** — vérifié par test
  widget + profiling.
- **`dateRange` livré** — enum + `ZDateRange` + widget + `ZFieldSpec` généré + test de rétro-compat
  de sérialisation, apparaissant dans la showcase et dans le formulaire du harnais qui l'appelle.
- **Parité totale traçable.** Chaque type/variante de la matrice `FIELD-PACKAGE-MATRIX.md` a un
  statut connu : livré, câblé, ou gap consciemment reporté avec justification écrite. Aucun « on ne
  sait pas ».
- **Gates AD tenues à chaque story** — les 16 AD ; **CORE OUT=0** (grep : aucune dépendance lourde ni
  `zcrud_*` dans `zcrud_core/pubspec.yaml`) ; tests widget RTL/a11y ; vérif verte
  `generate`+`analyze`+`test` rejouée avant tout `done`.

## Scope

### Décisions owner VERROUILLÉES (contraintes, non re-litigables ici)

- **`awesome_select` = FORK maintenu par nous.** On adopte `awesome_select` (`SmartSelect` :
  `select`/`radio`/`relation`/`multiselect`, modal S2 responsive + recherche + CRUD inline) via un
  **fork que nous maintenons** — ce qui **élimine le risque du `ref: master` flottant**. Il est
  enveloppé derrière un `ZFieldWidgetBuilder` dans un **satellite** (jamais `zcrud_core`, AD-1). La
  **mécanique exacte** (fork GitHub épinglé sur un commit vs vendoring du package dans le monorepo)
  est une décision de la **phase architecture**, pas de ce brief.
- **PARITÉ DODLP TOTALE.** L'état-cible est de supporter **tout** ce que le module CRUD de DODLP
  savait rendre. Plus de gap « optionnel ». La livraison peut être phasée, la parité totale ne l'est
  pas.

### In — périmètre de parité (issu de la matrice)

**Familles déjà couvertes nativement — à confirmer/polir + câbler** : `text`, `multiline`, `number`
(+ `%`), `integer`, `float` (+ devise), `boolean`, `dateTime`, `time`, `select`, `radio`, `checkbox`,
`relation`, `rowChips`, `tags`, `subItems` (+ réordo monter/descendre, supérieur à DODLP),
`dynamicItem`, `rating`, `slider`, `signature`, `color` (simple), `stepper`, `password`, `hidden`,
`widget`, `custom`.

**Satellites existants — à câbler/vérifier** : `phoneNumber`, `country`, `address` (`zcrud_intl`) ;
`markdown` / `inlineMarkdown` / `richText` (`zcrud_markdown`, + LaTeX) ; `location` / `geoArea`
(`zcrud_geo`) ; `file` / `image` / `document` (contrat présent, `ZFilePicker` concret à câbler côté
binding, E7).

**Travail neuf pour la parité totale** :
- **`dateRange`** — natif `showDateRangePicker` (jamais `table_calendar`). Touche `zcrud_core` →
  story sérialisée.
- **`color` multiple + roue/opacité** — variante `ZColorConfig.multiple` (`List<int>` ARGB) ; roue
  HSV/opacité pixel-exacte via seam `flex_color_picker` **côté binding** si jugée bloquante.
- **Média capture/recadrage** — `image_picker` / `image_cropper` / `camera` / `video_thumbnail` via
  adaptateur `ZFilePicker` dans le binding/satellite média (jamais le cœur).
- **Fichier avancé** — `file_picker` / `open_file` / `dotted_border` (bottom-sheet multi-sources).
- **Rich-text HTML WYSIWYG** — `html_editor_enhanced` (⚠️ WebView = **2ᵉ voie d'état**, en tension
  avec AD-2) + rendu HTML `flutter_html`, dans un **nouveau satellite dédié** (isolé, jamais
  `zcrud_markdown`) — la tension AD-2 est **assumée et isolée**, pas ignorée.
- **PIN** (`pinput`) · **autocomplétion** · **table éditable** (`editable`) · **tags riches**
  (`flutter_tags`) · **réordonnancement subItems** (`drag_and_drop_lists`) · **icon picker**.
- **`awesome_select`** (via fork, satellite) — `select`/`radio`/`relation`/`multiselect` avec parité
  modal riche.
- **`geoArea` — UI stylisation fill/stroke** (réutiliser le seam `ZColorPicker` existant, pas de 2ᵉ
  picker).
- **Aération / espacement DODLP** — répliquer les **mesures** (dp) via tokens `ThemeExtension`
  (FR-26), jamais les **couleurs** (dérivées du `ColorScheme`). Trancher les 3 écarts d'aération.

**Livrables de preuve** : harnais 6-formulaires DODLP dans `example/` ; page showcase exhaustive.

### Out (hors périmètre de ce brief / de cette itération)

- **Décisions d'architecture** : emplacement/nom des satellites (`zcrud_select`, `zcrud_html`,
  `zcrud_media`…), fork épinglé vs vendoring, ré-organisation des packages → **phase architecture**.
- **`flutter_form_builder` (widgets)** — écarté définitivement (familles natives plus conformes AD-2 ;
  seuls les validateurs `form_builder_validators`, déjà dep pure de `zcrud_core`, sont réutilisés).
- **LaTeX fallback SVG `flutter_tex`** — gap **assumé par architecture** (banni par le test
  d'isolation ; formule hors sous-ensemble `flutter_math_fork` → placeholder thémé, pas de crash).
- **Migrations de données (ETL app-side)** — le **backfill** `signature` (PNG→strokes, **non
  réversible**) et `phoneNumber` (String legacy → `ZPhoneNumber` E.164) sont des **travaux ETL de
  l'app**, pas des gaps de widget zcrud. Nommés ici comme **risques/dépendances**, exécutés hors
  packages zcrud.
- **CI/CD, distribution, tags de version** — hors périmètre produit.

### Phasage proposé (jalons, ordre indicatif)

- **Phase MVP** — champs de base confirmés/polis + **`dateRange`** + **page showcase exhaustive** +
  **harnais 6-formulaires** + câblage des satellites existants (`phoneNumber`, `country`, `address`,
  markdown) + spacing spec (3 écarts d'aération tranchés). Objectif : la **preuve de non-régression**
  et le socle SM-1.
- **Phase média & rich** — `ZFilePicker` concret (image/file/document/scan + recadrage/capture),
  `color` multiple + roue/opacité, satellite rich-text HTML **WYSIWYG** (`html_editor_enhanced` +
  `flutter_html`, tension AD-2 isolée), adaptateur `awesome_select` (fork) pour la parité modal riche.
- **Phase finitions** — PIN, autocomplétion, table éditable, tags riches, réordonnancement subItems,
  `geoArea` UI stylisation, icon picker, `subItems.itemsAreTags`, parité pixel optionnelle (tokens
  `runGutter`, `formPadding`, look « boîte grise » des sections).

> Le phasage est **indicatif** : le séquencement fin (et le respect du graphe de dépendances des
> epics) est fixé au sprint-planning. La parité **totale** reste l'invariant, quel que soit le
> découpage.

## Invariants de conception (contraintes rappelées)

- **AD-1** — tout adaptateur de champ tiers vit **hors `zcrud_core`** (satellite ou binding),
  **CORE OUT=0**. Le fork `awesome_select`, la WebView WYSIWYG, `flex_color_picker`, les pickers
  média : jamais dans le cœur.
- **AD-2 / AD-15** (objectif produit n°1) — **aucun état de formulaire global** ; rebuild granulaire.
  Le seam **`ZWidgetRegistry.register(kind, builder)` existe déjà** et ne livre que
  `ctx.value` / `ctx.onChanged`, jamais le `ZFormController`. Un widget tiers à état propre
  (WebView WYSIWYG) doit être **isolé** et piloté sans casser la granularité.
- **AD-13** — RTL + a11y (directionnel : `EdgeInsetsDirectional`/`AlignmentDirectional`/
  `TextAlign.start-end` ; `Semantics` explicites ; cibles ≥ 48 dp).
- **FR-26** — aucun style/libellé codé en dur ; thème injecté via `ZcrudScope`/`ThemeExtension`,
  repli `Theme.of(context)`.
- **AD-10** — désérialisation défensive pour **tout nouveau type de valeur** (`ZDateRange`, couleur
  multiple ARGB, PIN…) : champ absent/corrompu ne fait jamais échouer le parent ; évolution de
  schéma additive seulement.

## Risks

- **Fork `awesome_select` maintenu par nous.** Décision verrouillée qui **supprime** le risque du
  `ref: master` flottant, mais **transfère** une charge de maintenance (suivi upstream, sécurité,
  compat Flutter) sur l'équipe zcrud, propagée à **tous** les consommateurs du satellite. Mécanique
  (épinglage vs vendoring) à trancher en architecture pour borner ce coût. **Sévérité : moyenne.**
- **WYSIWYG HTML vs AD-2.** `html_editor_enhanced` embarque une **WebView Summernote** = une **2ᵉ
  voie d'état** hors `ZFormController`, en tension directe avec l'objectif produit n°1. À **isoler**
  dans un satellite dédié et piloter sans casser la granularité des autres champs ; round-trip HTML
  riche→Delta à **pertes bornées documentées**. **Sévérité : élevée** (le champ le plus coûteux et le
  plus à risque d'invariant).
- **Migrations de données non-widget.** `signature` (PNG bitmap DODLP → strokes vectoriels, **non
  réversible**) et `phoneNumber` (String legacy → `ZPhoneNumber` E.164) exigent un **backfill ETL
  app-side** ; sans lui, perte silencieuse à la migration. Le widget est prêt des deux côtés — le
  risque est **hors zcrud** mais bloquant pour la migration DODLP. **Sévérité : moyenne.**
- **Divergence visuelle perçue.** `radio`/`select`/`relation` DODLP sont des **modaux S2** (pas
  inline) ; le sélecteur pays téléphone est un **dialog** (pas inline). Un utilisateur DODLP
  percevra un changement même si zcrud est fonctionnellement équivalent/supérieur. Mitigé par
  `radioAsModal: true` et le fork `awesome_select`, mais **validation produit explicite** requise via
  le harnais. **Sévérité : moyenne.**
- **Poids des dépendances.** Média (`image_cropper`/`camera`/`video_thumbnail`), WebView, roue
  couleur : chacun alourdit l'app. L'isolation AD-1 (satellites) contient le risque, mais le nombre
  de satellites neufs augmente la surface à maintenir. **Sévérité : faible-moyenne.**
- **Parité pixel « aveugle ».** Chercher une égalité au pixel avec DODLP risquerait de **régresser**
  des points où zcrud est déjà supérieur (grille directionnelle, en-têtes `Semantics`, ≥48dp). La
  parité visée est **fonctionnelle + aération tranchée**, pas une copie pixel des couleurs codées de
  DODLP. **Sévérité : faible** (traitée par la spacing spec).

## Vraies décisions produit laissées OUVERTES pour le owner

Ces points ne sont **pas** tranchés par le brief (au-delà des décisions verrouillées) et appellent un
arbitrage owner au PRD/architecture — retenus ici en **option conservatrice par défaut** :

1. **Niveau de parité pixel exigé** : parité *fonctionnelle* (défaut retenu) vs parité *visuelle
   stricte* (déclenche les stories `zcrud_core` de la Phase finitions : `runGutter`, `formPadding`,
   look « boîte grise » des sections `MyStickyHeader`).
2. **`color` multiple** : variante native `ZColorConfig.multiple` dans `zcrud_core` (défaut recommandé
   par l'étude) **vs** satellite `kind:"colorMulti"`. Ne pas forker `color_picker_field` (peu maintenu).
3. **Sélecteur pays téléphone** : panneau **inline** de `ZCountryPickerField` (défaut) acceptable, ou
   variante `showDialog`/`showModalBottomSheet` pour coller au dialog DODLP.
4. **Validateur national Togo** : « chiffres nus » (`length:8`, plus propre — défaut) vs « formaté
   avec espaces » (`length:11`, parité stricte). Seuils d'erreur observables différents.
5. **WYSIWYG HTML** : le owner **exige-t-il** la WYSIWYG (`html_editor_enhanced`, satellite `zcrud_html`
   + tension AD-2) — la parité totale l'implique — **ou** accepte-t-il le round-trip
   `ZHtmlCodec`→Delta pour l'HTML simple/structuré comme évolution assumée ? *La parité totale
   verrouillée penche vers « oui WYSIWYG » ; à confirmer explicitement vu le coût AD-2.*
6. **`subItems.itemsAreTags` & `icon`** : combler (aucun call-site actif observé dans le DODLP cloné —
   peut-être motivé par IFFD/DLCFTI ?) ou reporter. La parité totale pousse à combler ; le besoin réel
   reste à confirmer.
7. **Sélection finale des 6 formulaires du harnais** : la shortlist (Cargaison, DemandeDepotage,
   Consignee/BoatService, AuthProfileData, ArticleBep/Cotation, ConvocationBmd/Event) est
   **provisoire** — à figer sur le critère « couverture maximale de types de champ × axes de risque ».

## Références (source of truth)

- Étude d'intégration : `docs/dodlp-form-integration-study-2026-07-17/` (STUDY.md,
  FIELD-PACKAGE-MATRIX.md, NEXT-ITERATION-SCOPE.md, 13 rapports de lentille).
- Architecture (16 AD) :
  `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`.
- Enum des champs :
  `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` (40 valeurs).
- Référence DODLP (lecture seule) : `dodlp-otr/lib/modules/data_crud/`.
