---
title: zcrud
created: 2026-07-09
updated: 2026-07-09
owner: Zakarius
status: draft
language: fr
grounding:
  - _bmad-output/planning-artifacts/briefs/brief-zcrud-2026-07-09/brief.md
  - docs/technical-inventory.md
  - docs/canonical-schema.md
---

# PRD : zcrud
*Titre de travail — à confirmer.*

## 0. Objet du document

Ce PRD est destiné au product owner (Zakarius), aux futurs consommateurs du package (les applications DODLP, lex_douane, IFFD, DLCFTI) et aux workflows BMAD en aval (architecture, épics, stories). zcrud étant un **produit-développeur** (monorepo de packages Flutter/Dart réutilisables), le vocabulaire est ancré par un Glossaire (§3), les capacités sont groupées par **fonctionnalité** avec des exigences fonctionnelles (FR) numérotées globalement, et les hypothèses sont taguées `[HYPOTHÈSE]` puis indexées (§9). Ce PRD **s'appuie sur** et ne duplique pas : le **Product Brief** (vision, cibles, périmètre), l'**inventaire technique** (`docs/technical-inventory.md` : catalogue des champs, cause racine du bug de rebuild, découpage des packages, risques d'extraction) et le **schéma canonique** (`docs/canonical-schema.md` : modèles portés de lex_douane, mécanisme d'extension, conventions). Les détails exhaustifs vivent dans ces documents ; les FR y renvoient.

## 1. Vision

zcrud est un **monorepo Flutter (melos) de packages CRUD riches réutilisables**, extrait d'un moteur déclaratif (~11 000 lignes) aujourd'hui cloné par copier-coller dans trois applications (DODLP, IFFD, DLCFTI) à trois stades divergents. Un même moteur, piloté par un schéma de champs, y génère formulaires d'édition **et** tableaux de liste — mais chaque correction doit être re-portée à la main dans chaque copie. zcrud remplace ce code dupliqué par des packages importables sélectivement, avec un socle de **modèles canoniques** portés des entités les plus abouties de lex_douane, **ouverts à l'extension** par chaque application.

Deux propositions de valeur portent le produit. D'abord, il **corrige par conception** le défaut le plus visible et jamais résolu des trois apps : le formulaire entier est une seule `State` et chaque frappe déclenche un `setState` global qui reconstruit tout l'arbre → jank, perte de focus, curseur qui saute. zcrud le remplace par des **rebuilds réactifs granulaires** (un champ = un widget qui n'observe que sa propre tranche d'état). Ensuite, il fait d'un **modèle annoté la source unique de vérité** dont dérivent la (dé)sérialisation, le schéma de formulaire et le rendu en liste — supprimant toute une classe de bugs de correspondance `name` ↔ propriété.

À terme, zcrud est la fondation CRUD commune de l'écosystème douane/ERP : un modèle annoté suffit à obtenir liste, formulaire riche, sérialisation, flashcards, cartes mentales et export, sur n'importe quel backend ; une nouvelle application démarre en important quelques packages ; une correction se fait une fois et profite à toutes.

## 2. Cible

### 2.1 Jobs To Be Done

- **En tant que développeur-mainteneur (Zakarius)**, cesser de re-porter à la main la même évolution CRUD dans 3+ apps ; corriger un bug une fois pour toutes les apps.
- **En tant qu'intégrateur de DODLP**, remplacer ~11 000 lignes dupliquées par un import de package, sans casser reflectable, GetX, ni l'init 2 apps Firebase existante.
- **En tant qu'intégrateur de lex_douane**, obtenir enfin un moteur de **formulaires riches** réutilisable (aujourd'hui ~87 écrans « hand-rolled ») et des widgets flashcards/mindmaps **paramétrés par mes entités**, sans imposer un second modèle concurrent au module « Étude ».
- **En tant qu'utilisateur final** d'une app consommatrice, saisir un formulaire long **sans latence ni perte de focus**, éditer du Markdown riche (tables, formules), réviser des flashcards et consulter/éditer des cartes mentales.
- **En tant qu'auteur d'une nouvelle app**, n'importer que les packages nécessaires (ex. `zcrud_markdown`) sans tirer Firebase, Syncfusion ou Google Maps.

### 2.2 Non-utilisateurs (v1)

- Les projets non-Flutter/Dart de l'écosystème (Angular, backends Node/Python).
- Les apps sans besoin CRUD dynamique (calculatrices, outils statiques).
- Les mainteneurs cherchant un framework CRUD généraliste multi-domaines : zcrud est d'abord optimisé pour l'écosystème douane/ERP de l'auteur, ouvert à l'extension mais pas positionné comme produit tiers en v1.

### 2.3 Parcours utilisateurs clés

*Les « utilisateurs » d'un package sont d'abord des développeurs intégrateurs ; les parcours end-user comptent car ils définissent les critères de qualité observables (notamment le bug de rebuild).*

- **UJ-1. Zakarius migre DODLP vers zcrud sans rien casser.**
  - **Persona + contexte :** mainteneur unique, DODLP en prod (reflectable + GetX + get_it + 2 apps Firebase), `data_crud` importé par 180 fichiers.
  - **Parcours :** ajoute les packages `zcrud_*` au pubspec ; branche le binding **`zcrud_get`** (+ `ZcrudScope`) fournissant un `CrudResolver` délégant à `getIt<DodlpController>()` et un `ReflectableCodec` ; re-pointe les imports par lots ; supprime le code dupliqué de `src/`.
  - **Climax :** l'app compile et tourne à parité fonctionnelle (catalogue figé), **sans jamais ajouter Riverpod**, et l'édition d'un long formulaire ne perd plus le focus.
  - **Résolution :** une PR où ne changent que les imports + une fine couche adaptateur ; le bootstrap, reflectable et Firebase restent inchangés.
  - **Edge case :** un type de champ propre à DODLP absent du catalogue → enregistré via `ZTypeRegistry` sans forker le package.

- **UJ-2. Un utilisateur de DODLP saisit une fiche longue sans jank.**
  - **Persona + contexte :** agent saisissant un dossier de dédouanement (formulaire multi-sections, dizaines de champs, stepper).
  - **Parcours :** ouvre l'écran d'édition, tape dans un champ texte au milieu du formulaire, coche un switch qui révèle des champs conditionnels.
  - **Climax :** chaque frappe ne reconstruit que le champ courant ; le focus et la position du curseur sont préservés ; l'apparition/disparition de champs conditionnels ne déplace pas le focus.
  - **Résolution :** la fiche est soumise (create/update) après validation ciblée par champ.
  - **Edge case :** perte de connexion pendant la saisie → l'état du formulaire n'est pas reconstruit/perdu.

- **UJ-3. lex_douane_admin édite un article via un formulaire riche zcrud.**
  - **Persona + contexte :** admin éditant un article de code douanier ; monorepo Melos moderne (Riverpod 3, freezed, json_serializable, `Either<Failure,T>`, RTL).
  - **Parcours :** remplace un écran `TextEditingController`+`setState` par un `DynamicEditionScreen` zcrud piloté par le `ZFieldSpec` de l'entité ; édite un champ Markdown avec table et formule LaTeX.
  - **Climax :** le formulaire riche fonctionne en `ConsumerWidget`, RTL et a11y respectés, `*.g.dart` générés, sans régression de résolution de dépendances.
  - **Résolution :** l'écran migré est plus court, réactif, et partagé avec d'autres écrans admin.

- **UJ-4. lex_douane affiche/édite flashcards et mindmaps via widgets zcrud additifs.**
  - **Persona + contexte :** app lex_douane, module « Étude » **en développement actif**, schéma canonique (source du canonique zcrud).
  - **Parcours :** utilise `ZMindmapView` et les widgets flashcards de zcrud, **paramétrés par ses propres entités** (`Flashcard`, `Mindmap`) via adaptateurs, sans remplacer son module ni son offline-first Hive+Firestore.
  - **Climax :** les widgets partagés rendent le contenu de l'app ; le SRS reste piloté par l'app (SM-2), branchable sur un `ZSrsScheduler`.
  - **Résolution :** lex_douane bénéficie du socle partagé tout en gardant la maîtrise de ses données et de sa logique métier.

## 3. Glossaire

*Termes à employer verbatim en aval (FR, UJ, SM). Pas de synonyme ailleurs.*

- **zcrud** — le monorepo melos de packages CRUD réutilisables, objet de ce PRD.
- **Package** — unité publiable du monorepo (`zcrud_core`, `zcrud_markdown`, etc.). Un consommateur en importe un sous-ensemble.
- **DynamicEdition** — moteur de formulaire généré à partir d'un schéma de champs (`ZFieldSpec[]`).
- **DynamicList** — moteur d'affichage liste/tableau généré à partir du même schéma.
- **ZFieldSpec** — descripteur déclaratif d'un champ (nom, type, label, validators, config, condition d'affichage). Remplace le `DynamicFormField` historique. Pilote DynamicEdition **et** DynamicList.
- **EditionFieldType** — type canonique d'un champ (catalogue de référence issu de DODLP, ~37 valeurs : texte, nombre, date, select, relation, sous-liste, fichier, géo, téléphone, markdown, table, signature, rating, stepper…).
- **ZcrudModel** — entité annotée (`@ZcrudModel`/`@ZcrudField`) traitée par le générateur zcrud. Source unique de vérité : produit (dé)sérialisation + `ZFieldSpec[]` + enregistrement au registre.
- **ZcrudRegistry / ZTypeRegistry / ZSourceRegistry** — registre injectable où une app enregistre les codecs `fromJson/toJson` (et variants de provenance) de ses types, permettant l'extension **inter-package** sans fork ni réflexion runtime.
- **ZExtension** — sous-schéma typé additif versionné (`formatVersion`, parsing défensif) attaché par champ nullable à une entité canonique ; canal d'extension riche et rétro-compatible (patron `NodeContext`/`ragContext` de lex_douane).
- **extra** — `Map<String,dynamic>` ouverte (défaut `{}`) portée par les entités canoniques pour l'extension non typée.
- **ZEntity / ZSyncable / ZNode** — contrats abstraits de base (identité, synchronisabilité, nœud d'arbre) sans mécanique de sérialisation imposée.
- **ZRepository&lt;T&gt;** — contrat de dépôt neutre (`Either<ZFailure,T>`, `Stream<List<T>>`), indépendant du backend.
- **ZFlashcard / ZFlashcardType / ZRepetitionInfo / ZSrsScheduler** — carte de révision canonique, son enum de types, l'état SRS **séparé** de la carte, et l'ordonnanceur SRS pluggable (SM-2 par défaut).
- **ZMindmap / ZMindmapNode / ZMindmapTreeOps / ZMindmapView** — carte mentale (forêt), nœud d'arbre récursif (nesting + `level`), opérations d'arbre pures, et vue auto-layout.
- **ZStudyFolder / ZStudySession** — container générique multi-type (rattachement inverse par `folderId`) et configuration/état d'une session de révision.
- **ZcrudScope** — point d'injection framework-neutre (InheritedWidget + seams Riverpod) fournissant resolver, permissions, toast, config, l10n et codecs au moteur.
- **seam** — provider/point d'injection qui `throw` par défaut et doit être surchargé par l'app hôte (Riverpod `ProviderScope` ou `ZcrudScope`).
- **Canonique** — schéma verrouillé partagé de zcrud, porté des modèles avancés de lex_douane, ouvert à l'extension.
- **Consommateur** — application important zcrud (DODLP prioritaire, puis lex_douane, puis IFFD/DLCFTI).
- **offline-first** — patron de persistance : store local source de vérité + backend distant fire-and-forget, merge Last-Write-Wins sur `updatedAt`, soft-delete `is_deleted`.

## 4. Fonctionnalités

*Chaque sous-section est une fonctionnalité cohérente : description comportementale, puis FR numérotées globalement (FR-1…FR-N). Les détails exhaustifs sont dans les documents de grounding.*

### 4.1 Moteur DynamicEdition à rebuilds granulaires

**Description :** génère un formulaire à partir d'un `ZFieldSpec[]`. Objectif produit n°1 : **supprimer le rebuild global**. Un champ = un widget top-level qui n'observe que sa tranche d'état ; `TextEditingController` et `key` stables ; validation ciblée. Supporte le catalogue de champs de référence (§Glossaire EditionFieldType), les sections repliables, les champs conditionnels, le mode lecture, la grille responsive 12 colonnes, le stepper multi-étapes, la détection dirty et la soumission create/update. Réalise UJ-2, UJ-3.

**Functional Requirements :**

#### FR-1 : Édition d'un champ sans rebuild global
Un utilisateur peut éditer n'importe quel champ d'un formulaire long sans que les autres champs se reconstruisent. Réalise UJ-2.
**Conséquences (testables) :**
- Taper dans un champ ne déclenche aucun `setState` à l'échelle du formulaire ; seul le widget du champ courant (et un éventuel indicateur dérivé) se reconstruit — vérifiable par compteur de builds en test widget.
- Le focus et la position du curseur sont préservés à chaque frappe, y compris quand un champ conditionnel apparaît/disparaît ailleurs.
- Le `TextEditingController` d'un champ est créé une seule fois (cycle de vie initState/dispose) et n'est jamais recréé au rebuild ; sa valeur n'est jamais ré-injectée en écrasant la sélection.
- Chaque champ visible porte une `key` stable (`ValueKey(field.name)`, jamais `hashCode`).

#### FR-2 : Catalogue de types de champs de référence
Un développeur peut déclarer tout champ du **catalogue de référence figé** (`EditionFieldType`, énuméré dans `docs/technical-inventory.md` §3) et obtenir son rendu d'édition et de liste.
**Conséquences (testables) :**
- Les types du catalogue DODLP (texte/multiligne, nombre/entier/flottant/devise, booléen, date/heure/timestamp, select/radio/checkbox/multi-select, relation `crudDataSelect`, sous-liste `subItems`, `dynamicItem`, fichier/image/document, géo/carte, téléphone international, pays/adresse, rating, slider, signature, couleur, markdown/html, stepper, tags, rowChips, widget libre, hidden, password) sont chacun rendus par un widget dédié — aucun type déclaré ne tombe dans un `default` silencieux.
- Un type inconnu enregistré via `ZTypeRegistry` est rendu par le widget fourni par l'app, sans modification du package.
- La validation transverse (`required`, min/max via clés, email, url, match, etc.) est appliquée par champ en `AutovalidateMode.onUserInteraction`.

#### FR-3 : Sections, champs conditionnels, mode lecture, responsive
Un développeur peut structurer un formulaire en sections repliables, champs conditionnels et grille responsive, et l'afficher en lecture seule.
**Conséquences (testables) :**
- `displayCondition(item, state)` masque/affiche un champ sans déplacer le focus des autres (place réservée stable plutôt que retrait d'`Element`).
- La visibilité est dérivée dans un sélecteur dédié : seul un changement de visibilité reconstruit la liste des champs, pas une frappe.
- Le mode lecture (`readOnly`) rend chaque champ en présentation, avec option `showIfNull`.

#### FR-4 : Stepper multi-étapes fonctionnel
Un développeur peut regrouper des champs en étapes (stepper) avec validation par étape.
**Conséquences (testables) :**
- Le stepper sectionne le **même** `ZFormController` (pas de `FormBuilder` global comme source d'état) ; `form_builder_validators` sert la composition de validateurs par étape (OQ-4 résolu — AD-2, sans réintroduire le rebuild global).
- La navigation entre étapes préserve l'état des champs déjà saisis.

#### FR-5 : Soumission et détection dirty
Un utilisateur peut soumettre le formulaire (create/update) après validation, et l'app est prévenue des modifications non enregistrées.
**Conséquences (testables) :**
- La soumission valide l'ensemble puis appelle un hook `onSubmit` fourni par l'app (les callbacks/Widgets non sérialisables ne transitent pas par la (dé)sérialisation du modèle).
- Une empreinte dirty détecte les changements pour confirmer l'abandon.

### 4.2 Moteur DynamicList (liste & tableau)

**Description :** rend une collection à partir du même `ZFieldSpec[]` : liste, DataGrid, ou vue libre. Recherche, filtres, tri, pagination (dont pagination par curseur), sélection multiple, actions par ligne avec ACL, export, sous-listes/relations, onglets, corbeille (soft-delete). Réalise UJ-1.

**Functional Requirements :**

#### FR-6 : Rendu liste/tableau dérivé du schéma
Un développeur peut afficher une collection en liste, tableau (DataGrid) ou vue personnalisée sans redéclarer les colonnes.
**Conséquences (testables) :**
- Les colonnes/cellules dérivent du `ZFieldSpec[]` (une seule définition pour édition et liste — cf. OQ-8).
- Le moteur de liste par défaut est **Syncfusion `SfDataGrid`** (décision produit), derrière un `ZListRenderer` pluggable autorisant un backend Material `DataTable` alternatif. Le rendu Syncfusion vit dans `zcrud_list` (et non dans `zcrud_core`), afin qu'un consommateur n'important pas de liste (ex. `zcrud_markdown` seul) ne tire pas Syncfusion.

#### FR-7 : Recherche, filtres, tri, pagination curseur
Un utilisateur peut rechercher, filtrer, trier et paginer une collection.
**Conséquences (testables) :**
- Recherche insensible aux accents sur les champs marqués `searchable` dans le `ZFieldSpec` (défaut : tous les champs texte).
- Filtres/tri exprimés dans un `DataRequest` neutre traduisible côté backend.
- La pagination par curseur (`startAfter`/curseur opaque) est exprimée dans le contrat neutre `DataRequest` (OQ-9 résolu — AD-16 ; capacité absente des 3 sources), avec repli in-memory documenté.

#### FR-8 : Actions par ligne avec ACL, sélection, corbeille, export
Un utilisateur peut agir sur les lignes (CRUD) selon ses droits, sélectionner en masse, consulter la corbeille, et exporter.
**Conséquences (testables) :**
- Les actions par ligne sont filtrées par un contrat `ZAcl` fourni par l'app.
- La sélection multiple fonctionne (correction du bug DODLP/IFFD où le contrôleur de sélection était désactivé).
- L'export (Excel/PDF) est fourni par `zcrud_export` (optionnel) ; son absence ne casse pas la liste.

### 4.3 Modèle canonique, codegen & extensibilité

**Description :** un modèle annoté est la source unique de vérité. `zcrud_annotations` (`@ZcrudModel`/`@ZcrudField`/`@ZcrudId`) + `zcrud_generator` (build_runner) produisent (dé)sérialisation, `ZFieldSpec[]` et enregistrement au registre. **reflectable est banni** ; **freezed n'est pas imposé**. L'extensibilité est de premier ordre (§Glossaire ZExtension/extra/registry). Réalise UJ-1, UJ-3.

**Functional Requirements :**

#### FR-9 : Génération à partir d'annotations
Un développeur peut annoter une entité et obtenir sa (dé)sérialisation, son `ZFieldSpec[]` et son enregistrement générés.
**Conséquences (testables) :**
- `build_runner` génère `fromMap/toMap/copyWith` + le `ZFieldSpec[]` dérivé des annotations + l'appel d'enregistrement au registre.
- Aucun usage de `reflectable` n'est requis à l'exécution ni au bootstrap.
- Un type non enregistré échoue explicitement (throw), jamais par cast null silencieux.

#### FR-10 : Extension d'un modèle canonique par une app
Un développeur d'app peut étendre un modèle canonique (champs/comportements) tout en conservant codegen et compatibilité.
**Conséquences (testables) :**
- Extension riche via un `ZExtension?` typé additif versionné (`formatVersion`, `fromJsonSafe → null`, `@JsonKey(defaultValue)`) : un document sans le champ se désérialise sur le défaut, jamais d'échec du parent.
- Extension non typée via `extra: Map<String,dynamic>` (défaut `{}`).
- Extension de provenance/type ouvert via `ZTypeRegistry`/`ZSourceRegistry.register(kind, fromJson, toJson)` — variant inter-package sans fork ni `sealed` fermée.
- Tous les enums zcrud portent `@JsonKey(unknownEnumValue:)` (+ valeur `custom`/`customLabel` là où pertinent).

#### FR-11 : Adaptation d'un schéma existant (sans imposer de modèle)
Un développeur peut brancher zcrud sur des entités existantes (`@JsonSerializable` de lex_douane, reflectable de DODLP) sans les remplacer.
**Conséquences (testables) :**
- Un `ZCodec`/adaptateur permet d'exposer une entité `@JsonSerializable` existante comme `ZcrudModel` sans réécriture.
- Un `ReflectableCodec` permet à DODLP de conserver sa réflexion sans lister ses modèles.
- zcrud partage structure + invariants sans imposer la mécanique de (dé)sérialisation (ni freezed, ni reflectable). *(Conventions de sérialisation par défaut : voir §9, hypothèse indexée.)*

### 4.4 Couche données & backends

**Description :** contrats de dépôt neutres (`ZRepository<T>`, `DataRequest`, `DataState`, `Either<ZFailure,T>`, `Stream<List<T>>`) dans `zcrud_core` ; adaptateurs backend isolés (`zcrud_firestore`). Patron offline-first (store local source de vérité + distant fire-and-forget, LWW, soft-delete) et orchestrateur de sync. Réalise UJ-1, UJ-4.

**Functional Requirements :**

#### FR-12 : Contrats de dépôt neutres et backend-agnostiques
Un développeur peut consommer/fournir un `ZRepository<T>` sans dépendre d'un backend concret.
**Conséquences (testables) :**
- `zcrud_core` ne dépend d'aucun SDK backend : `cloud_firestore` (`Timestamp`/`Filter`/`FirebaseException`) ne fuit pas dans le domaine.
- Les contrats exposent `getAll/getById/save/softDelete/sync` en `Either<ZFailure,T>` et des flux `Stream<List<T>>` nus.
- `zcrud_firestore` fournit l'implémentation (bugs historiques corrigés : réassignation de `limit`, batch/transaction cohérents, pas de `catch(_){}` silencieux, `null ≠ erreur`).

#### FR-13 : Patron offline-first & orchestrateur de sync
Un développeur peut activer un patron offline-first standard pour les données utilisateur.
**Conséquences (testables) :**
- Store local source de vérité, distant fire-and-forget, merge Last-Write-Wins sur `updatedAt`, soft-delete `is_deleted`, cascade bornée.
- Un `ZSyncOrchestrator` déclenche `sync()` d'un ensemble de dépôts enregistrés (login/reconnexion débouncée), best-effort, séparant le *quand* du *comment*.
- Le store local est abstrait (`ZLocalStore`) pour permettre Hive/Isar/Drift sans toucher le domaine (cf. OQ-8).

### 4.5 Markdown & rich text (`zcrud_markdown`)

**Description :** éditeur/lecteur riches basés Quill ; conversion Delta ↔ Markdown ; embeds **LaTeX** et **tableaux** ; presets de toolbar ; rendu. Dépendances lourdes isolées et optionnelles (`flutter_tex`, `html_editor_enhanced`). Réalise UJ-3.

**Functional Requirements :**

#### FR-14 : Édition et lecture Markdown riche
Un utilisateur peut éditer et lire du contenu riche (gras, listes, titres, liens, tables, formules).
**Conséquences (testables) :**
- Round-trip fiable Delta ↔ Markdown testé sur : listes imbriquées, formules multi-lignes, tableaux, entités HTML.
- Un format de persistance **par défaut** est documenté (ex. Delta JSON), **surchargeable via `ZCodec`** (Markdown/HTML) ; le round-trip est spécifié pour chaque format supporté (OQ-1 résolu).
- Le champ rich-text possède son propre contrôleur isolé et ne remonte que par callback (patron `MarkdownEditionField`), conforme à FR-1.

#### FR-15 : Embeds LaTeX et tableaux
Un utilisateur peut insérer et rendre des formules LaTeX et des tableaux dans le contenu riche.
**Conséquences (testables) :**
- Les embeds formule (rendu `flutter_math_fork`, repli optionnel) et tableau sont éditables et sérialisés dans le format canonique.
- `flutter_tex`/`html_editor_enhanced` sont des dépendances optionnelles derrière un drapeau (cf. OQ-6) ; leur absence n'empêche pas l'édition Markdown de base.

### 4.6 Flashcards (`zcrud_flashcard`)

**Description :** modèles canoniques portés de lex_douane — `ZFlashcard` (6 types), `ZFlashcardType`, `ZRepetitionInfo` **séparé** de la carte, `ZSrsScheduler` (SuperMemo-2 par défaut, pluggable), `ZStudyFolder`/`ZStudySession`, patron offline-first, pipeline de génération LLM optionnel. Réalise UJ-4.

**Functional Requirements :**

#### FR-16 : Modèle et édition de flashcards canoniques
Un développeur peut créer/éditer des flashcards canoniques et une app peut étendre le modèle.
**Conséquences (testables) :**
- `ZFlashcard` porte question/answer/isTrue/choices/explanation/hint/tagIds/type/source/timestamps ; l'état SRS n'est **pas** dans la carte.
- L'état éphémère (id/folderId nuls) est matérialisé par le dépôt avant écriture (invariant de frontière).
- La provenance est extensible via `ZSourceRegistry` (le variant « article » douane est enregistré par l'app, pas codé dans le package).

#### FR-17 : Répétition espacée pluggable
Un utilisateur peut réviser en répétition espacée ; un développeur peut remplacer l'algorithme.
**Conséquences (testables) :**
- **SuperMemo-2** par défaut (facteur de facilité borné, intervalles) exposé derrière `ZSrsScheduler.apply/simulate` + `ZSrsConfig`.
- La seule voie d'écriture de l'état SRS passe par `reviewCard()` → `scheduler.apply` (aucun setter brut).
- L'ordonnanceur est remplaçable (FSRS/Leitner) sans toucher les modèles.

#### FR-18 : Organisation & sessions d'étude
Un utilisateur peut organiser flashcards/mindmaps/notes en dossiers et lancer des sessions de révision filtrées.
**Conséquences (testables) :**
- `ZStudyFolder` est un container multi-type à rattachement inverse (les items portent `folderId`) ; hiérarchie 2 niveaux validée par le dépôt.
- `ZStudySession` filtre par mode/tags/types/count ; les modes (`spaced/learn/list/test/whiteExam/cramming`) sont défensifs.

### 4.7 Cartes mentales (`zcrud_mindmap`)

**Description :** `ZMindmapNode` (arbre par nesting + `level`), `ZMindmap` (forêt), `ZMindmapTreeOps` (opérations pures) **complété** par le reparentage manquant, `ZMindmapView` (auto-layout, vue liste a11y), éditeur. Réalise UJ-4.

**Functional Requirements :**

#### FR-19 : Affichage et édition de cartes mentales
Un utilisateur peut visualiser et éditer une carte mentale ; un développeur peut brancher un rendu de contenu de nœud.
**Conséquences (testables) :**
- `ZMindmapView` auto-layout (zoom/pan), plus une vue liste sémantique indentée par `level` comme surface a11y de référence.
- `ZMindmapTreeOps` fournit add/update/delete/find **et** move/indent/outdent (absents de lex, ajoutés au canonique) avec recalcul du `level` du sous-arbre (cf. OQ-5, OQ-10).
- Un `nodeContentBuilder` injectable permet à l'app de rendre un contenu riche/domaine par nœud.

### 4.8 Champs spécialisés (`zcrud_geo`, `zcrud_intl`)

**Description :** champs à dépendances natives/lourdes isolés — géo/carte (adaptateurs Google/OSM), téléphone international, pays/état/devise. Les constantes volumineuses deviennent des assets.

**Functional Requirements :**

#### FR-20 : Champ géo/carte isolé
Un développeur peut utiliser un champ géo (point/polygone/cercle) sans imposer les dépendances carte au reste.
**Conséquences (testables) :**
- Modèle `ZGeoShape` agnostique du SDK ; adaptateurs Google/OSM optionnels.
- **Aucune clé API n'est embarquée dans le package** ; la clé est fournie par la config plateforme de l'app (cf. Contraintes §Sécurité).

#### FR-21 : Champs téléphone/pays/devise
Un développeur peut utiliser des champs téléphone international, pays/état et devise.
**Conséquences (testables) :**
- Constantes (pays 1,1 Mo, mccmnc 843 Ko, devises) chargées en **assets JSON paresseux**, pas en `const` embarquées (cf. OQ ; taille binaire).
- Aucune valeur par défaut nationale codée en dur non surchargeable.

### 4.9 Intégration & injection framework-neutre

**Description :** `ZcrudScope` (InheritedWidget) + seams fournissent resolver, permissions, toast, config, l10n et codecs. Des bindings optionnels (`zcrud_riverpod`, `zcrud_get`, `zcrud_provider`) relient injection et cycle de vie au gestionnaire d'état de l'app ; `ZcrudScope` seul suffit sans aucun manager. l10n injectable sans dépendance au routing/l10n de l'app. Réalise UJ-1, UJ-3, UJ-4.

**Functional Requirements :**

#### FR-22 : Injection & état multi-gestionnaire
Un développeur peut brancher zcrud sur le gestionnaire d'état de son app (Riverpod, GetX, provider) ou sans aucun, sans que le cœur n'en dépende.
**Conséquences (testables) :**
- La réactivité du moteur est **Flutter-native** (`ChangeNotifier`/`ValueListenable`) ; **aucun** gestionnaire d'état dans `zcrud_core`.
- Injection/lifecycle fournis par un **binding au choix** : `ZcrudScope` (défaut, zéro-dépendance), `zcrud_riverpod`, `zcrud_get` (DODLP) ou `zcrud_provider` — un même `ZFormController` fonctionne sous les quatre.
- `zcrud_core` ne dépend d'aucun conteneur ni gestionnaire d'état ; les bindings sont optionnels.
- Le cœur ne référence jamais `WidgetRef`, `Get.find`/`Get.put` ni `Provider.of` ; l'accès passe par `ZcrudScope.of(context)` ou l'API du binding.
- Ajouter un nouveau gestionnaire = un nouveau package de binding, sans modifier le cœur.

#### FR-23 : l10n injectable et RTL/a11y
Un développeur peut fournir/surcharger les libellés du chrome CRUD et obtenir un rendu RTL/accessible.
**Conséquences (testables) :**
- Le delegate l10n générique n'énumère pas de ressources métier ; les libellés métier sont fournis par l'app/feature via un registre.
- Pas de singleton statique mutable de localisation ; accès via `of(context)`/provider.
- Widgets `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, `Semantics` explicites, cibles ≥ 48 dp.

### 4.10 Monorepo melos & packaging

**Description :** frontières de packages, versioning, isolation des dépendances lourdes. Un consommateur importe un sous-ensemble sans tirer les autres.

**Functional Requirements :**

#### FR-24 : Importation sélective sans dépendances superflues
Un développeur peut importer un package isolé sans tirer les dépendances des autres.
**Conséquences (testables) :**
- `zcrud_core` ne dépend ni de Firebase, ni de Syncfusion, ni de Quill, ni de Google Maps.
- Importer `zcrud_markdown` seul ne tire pas `zcrud_firestore`/`zcrud_geo`.
- Le graphe de dépendances entre packages est acyclique et documenté (cf. `docs/technical-inventory.md` §6).

#### FR-25 : Gate de compatibilité de résolution de dépendances
Un développeur peut vérifier la compatibilité des versions avant intégration.
**Conséquences (testables) :**
- Un dry-run de résolution (flutter_quill + awesome_select + analyzer) contre le workspace lex_douane réussit avant tout code d'intégration.
- Les cibles SDK/Flutter sont alignées sur lex_douane (Dart `^3.12.2`) et documentées.

## 5. Non-Goals (explicites)

- zcrud n'est **pas** un framework CRUD généraliste tiers en v1 : il est optimisé pour l'écosystème de l'auteur, ouvert à l'extension.
- zcrud ne **remplace pas** le module « Étude » de lex_douane ni son offline-first : il fournit un socle canonique et des widgets additifs.
- zcrud n'impose **ni freezed, ni reflectable, ni GetX** aux consommateurs ; il ne dicte pas leur mécanique de sérialisation ni leur conteneur d'injection.
- zcrud n'**implémente pas** un backend multi (Supabase) en v1 ; il garde seulement le contrat exprimable.
- zcrud ne fournit **pas** de générateur d'UI « no-code » ni d'éditeur visuel de schéma en v1.
- zcrud ne **migre pas** automatiquement les données existantes des apps.

## 6. Périmètre MVP

### 6.1 Dans le périmètre (MVP)

- `zcrud_core` : DynamicEdition à rebuilds granulaires (FR-1…FR-5), DynamicList (FR-6…FR-8), contrats données neutres (FR-12), l10n/RTL/a11y (FR-23), injection framework-neutre (FR-22).
- `zcrud_annotations` + `zcrud_generator` : codegen + extensibilité (FR-9, FR-10, FR-11).
- `zcrud_markdown` : édition/lecture + embeds LaTeX/tables (FR-14, FR-15).
- `zcrud_firestore` : adaptateur backend débogué + offline-first (FR-13).
- `zcrud_list` : rendu liste/tableau Syncfusion par défaut derrière `ZListRenderer` (FR-6).
- **Bindings d'état** : `zcrud_riverpod`, `zcrud_get` (DODLP), `zcrud_provider` (FR-22 ; AD-15). `ZcrudScope` (zéro-dépendance) est fourni par `zcrud_core`.
- **Lot parité DODLP** (sous-ensemble avancé depuis E11 pour SM-2, requis avant l'intégration DODLP) : widgets géo/téléphone/pays/adresse (`zcrud_geo`/`zcrud_intl`) + export DataGrid (`zcrud_export`). *Alternative retenue au cas par cas : parité par enregistrement des widgets DODLP existants via `ZTypeRegistry`.*
- **Intégration DODLP** (banc d'essai, UJ-1, UJ-2) et **formulaires riches `lex_douane_admin`** (UJ-3), avec gate de compatibilité (FR-25).
- Découpage melos avec importation sélective (FR-24).

### 6.2 Hors périmètre MVP (séquencé après)

- `zcrud_flashcard` (FR-16…FR-18) et `zcrud_mindmap` (FR-19) — livrés en v1.x pour l'intégration additive lex_douane (UJ-4). `[NOTE FOR PM]` chargés émotionnellement : ce sont des besoins explicites, à ne pas oublier.
- `zcrud_geo` (FR-20), `zcrud_intl` (FR-21), `zcrud_export` (FR-8 export) — v1.x/v2 (dépendances lourdes).
- Backend Supabase réel — v2+ (contrat exprimable seulement).
- Mode flowchart des mindmaps — à décider (`zcrud_flowchart` séparé) — cf. OQ.
- Pipeline de génération LLM de flashcards comme module zcrud (`ZFlashcardGeneration`) — v2, sinon laissé à l'app (cf. OQ-9 canonique).
- Migration d'IFFD et DLCFTI vers zcrud — après stabilisation DODLP + lex_douane.

## 7. Métriques de succès

**Primaires**
- **SM-1** : Zéro rebuild global à l'édition — sur un formulaire de référence (≥ 30 champs, ≥ 3 sections), taper 100 caractères ne provoque aucun rebuild hors du champ courant et zéro perte de focus (test widget + profiling). Valide FR-1, FR-3.
- **SM-2** : Parité d'intégration DODLP *(métrique — à ne pas confondre avec l'algorithme SuperMemo-2)* — DODLP compile et tourne en important zcrud, code dupliqué de `src/` supprimé, **chaque type du catalogue figé** (inventaire §3) à parité *(checklist type-par-type)*, GetX/reflectable/Firebase/bootstrap inchangés (via binding `zcrud_get`, **sans ajouter Riverpod**). Les types géo/téléphone/pays sont servis à parité soit par le lot MVP de `zcrud_geo`/`zcrud_intl` (cf. §6.1), soit par enregistrement des widgets DODLP existants via `ZTypeRegistry`. Valide FR-2, FR-9, FR-11, FR-22.
- **SM-3** : Rich forms lex_douane — ≥ 3 écrans d'édition `lex_douane_admin` migrés vers zcrud sans régression de résolution de dépendances (FR-25) ni d'a11y/RTL. Valide FR-14, FR-23, FR-25.

**Secondaires**
- **SM-4** : Round-trip Markdown — 100 % des cas de test (listes imbriquées, formules, tables, entités HTML) préservés Delta↔Markdown. Valide FR-14, FR-15.
- **SM-5** : Isolation des dépendances — importer `zcrud_markdown` seul n'ajoute ni Firebase, ni Syncfusion, ni Google Maps au graphe (test de résolution). Valide FR-24.
- **SM-6** : Hygiène — zéro `reflectable` dans le moteur, zéro secret commité, modèles 100 % codegen. Valide FR-9, FR-20.

**Contre-métriques (à ne pas optimiser)**
- **SM-C1** : Ne pas maximiser le nombre de packages — un découpage trop fin nuit à l'ergonomie d'import ; contrebalance SM-5. Cible : granularité justifiée par l'isolation de dépendances lourdes, pas par principe.
- **SM-C2** : Ne pas maximiser la couverture de types de champs au détriment de la stabilité du cœur — contrebalance SM-2. Un type rare peut vivre en extension d'app plutôt que dans `zcrud_core`.

## 8. Questions ouvertes

*Détail et options dans `docs/technical-inventory.md` §9 et `docs/canonical-schema.md` §8. Les décisions se prennent en phase Architecture.*

- **OQ-1** ✅ *Résolu* : format de stockage rich-text **pluggable via `ZCodec`** (Delta en interne dans Quill, Markdown/HTML en surface/export) ; l'app choisit le format persisté.
- **OQ-2** : Mécanisme d'extension — confirmer « composition + ZExtension versionné + extra + registre + enums ouverts » (recommandé) ; portée du/des registre(s) (global vs par axe).
- **OQ-3** ✅ *Résolu* : injection **multi-gestionnaire** par bindings — `ZcrudScope` (défaut) + `zcrud_riverpod`/`zcrud_get`/`zcrud_provider` (AD-15) ; réactivité du cœur Flutter-native.
- **OQ-4** ✅ *Résolu* : le stepper sectionne le **même** `ZFormController` (pas de `FormBuilder` global comme état) — AD-2.
- **OQ-5** : `level` du mindmap — cache maintenu vs dérivé à la volée (surtout pour le reparentage).
- **OQ-6** : `flutter_tex`/`html_editor_enhanced` — optionnels derrière drapeau vs supprimés (impact multi-plateforme/WebView).
- **OQ-7** ✅ *Résolu* : **générateur zcrud** (`@ZcrudModel`/`@ZcrudField`) + conventions `@JsonSerializable` pur ; **reflectable banni, freezed non imposé**. (copyWith généré + sentinelle reset-null : détail d'architecture.)
- **OQ-8** : Rendu liste vs édition — dériver `ZFieldSpec` unique ou définitions disjointes ; abstraction `ZLocalStore` dès le portage ?
- **OQ-9** ✅ *Résolu* : curseur dans le **contrat neutre** `DataRequest` (impl `zcrud_firestore`) — AD-16.
- **OQ-10** : Reparentage mindmap — zcrud l'implémente (en avance sur lex) vs attend le portage.
- **OQ-11** ✅ *Résolu* : **Syncfusion par défaut** pour la liste (licence commerciale actée), isolé dans `zcrud_list` derrière `ZListRenderer` (repli Material possible).
- **OQ-12** : Uniformisation de la casse de sérialisation (mindmap camelCase vs education snake_case).

## 9. Index des hypothèses

- §2.3 / §4.3 (FR-11) — `[HYPOTHÈSE]` La sérialisation propre à zcrud suit les conventions `@JsonSerializable` pur de lex_douane (snake_case persistance, enums camelCase, désérialisation défensive), en l'absence de freezed/reflectable imposés. À confirmer en Architecture (OQ-7).
- §4.6 (FR-16) — `[HYPOTHÈSE]` Les modèles flashcards/mindmaps de lex_douane restent la référence canonique malgré le développement actif du module « Étude » ; un versionnage (`formatVersion`) absorbe leur évolution sans casser les consommateurs.
- §6.1 — `[HYPOTHÈSE]` Le banc d'essai DODLP peut être migré sans Riverpod (mode locator) ; la couche adaptateur reflectable est suffisante pour préserver le bootstrap.

---

## Annexe A — NFR transverses

- **Performance d'édition** : budget de rebuild = O(1) par frappe (champ courant uniquement) ; aucun recalcul de décoration/validateurs de tous les champs à chaque frappe.
- **Rétro-compatibilité de sérialisation** : un champ absent/corrompu ne fait jamais échouer la désérialisation du parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`).
- **Offline-first** : les données utilisateur restent éditables hors ligne ; sync best-effort non bloquante.
- **Pureté des couches** : la *couche modèles canoniques* (`zcrud_core/domain`) est du Dart pur (aucune dépendance Flutter/Firebase/Hive). Le package `zcrud_core` **autorise Flutter** (widgets du moteur) mais **interdit** Firebase/Syncfusion/Maps (cf. B.4). Backends et UI en couches séparées.
- **RTL & a11y** : support RTL complet et cibles tactiles/`Semantics` conformes sur toutes les surfaces UI.
- **Zéro réflexion runtime** dans le moteur ; tout par codegen.

## Annexe B — Cluster produit-développeur

### B.1 Surface d'API publique
- Chaque package expose un `library` d'API stable ; l'implémentation interne est masquée (`src/`).
- Les contrats abstraits (`ZEntity`, `ZRepository`, `ZFieldSpec`, `ZSrsScheduler`, `ZcrudScope`, registres) constituent la surface publique ; les widgets internes ne le sont pas.
- Correction assumée des typos d'API héritées (`searchInpuCtrl`, `childreen`, `crudActionsButtionsBuilder`…) dès la conception (rupture assumée, pas d'alias de compat legacy). *(cf. inventaire §9-14.)*

### B.2 Versionnage & dépréciation
- SemVer par package ; melos gère le versioning/release.
- Le schéma canonique est **additif seulement** entre versions mineures (nouveaux champs nullable / `defaultValue`), jamais de renommage/suppression sans montée de version majeure.
- Chaque sous-schéma d'extension porte son `formatVersion` indépendant.

### B.3 Budgets de performance
- Édition : rebuild borné au champ courant (SM-1).
- Liste : rendu paginé (curseur) ; pas de chargement intégral pour les grandes collections.
- Assets volumineux (pays/mccmnc) chargés paresseusement.

### B.4 Cibles runtime & politique de dépendances
- Cibles : Flutter/Dart alignés sur lex_douane (Dart `^3.12.2`). **Réactivité du cœur = Flutter-native** (`ChangeNotifier`/`ValueListenable`) ; **support multi-gestionnaire** (Riverpod, GetX, provider) via bindings optionnels — aucun manager imposé (AD-15).
- **Interdits dans le cœur `zcrud_core`** : `reflectable`, `cloud_firestore` (isolé en `zcrud_firestore`), Google Maps (isolé en `zcrud_geo`), Syncfusion (isolé en `zcrud_list`/`zcrud_export`). La liste Syncfusion par défaut vit dans `zcrud_list`, pas dans `zcrud_core` (qui n'expose que l'abstraction `ZListRenderer`).
- Dépendances lourdes (Quill, flutter_tex, html_editor_enhanced) isolées et/ou optionnelles derrière des drapeaux.
- **freezed non imposé** ; zcrud fournit ses annotations/générateur et n'exige pas une techno de (dé)sérialisation particulière côté app.

## Annexe C — Contraintes & garde-fous

### Sécurité
- **Aucun secret dans le code.** La clé API Google Maps aujourd'hui **commitée en clair** dans DODLP et DLCFTI (`google_maps.dart`) doit être **révoquée/restreinte** et fournie par la config plateforme lors de l'extraction de `zcrud_geo`. Aucune clé ne doit entrer dans un package zcrud.
- Retirer les contournements dangereux hérités (`badCertificateCallback => true` côté export).

### Contraintes des cibles (non négociables)
- **lex_douane** : `ConsumerWidget`/`ConsumerStatefulWidget`, `Either<Failure,T>`, RTL complet, a11y ≥ 48 dp + `Semantics`, `*.g.dart` générés, **zéro dépendance** de zcrud à `lex_localizations`/`go_router`, **reflectable exclu**.
- **DODLP** : préserver reflectable, GetX et l'init 2 apps Firebase ; injection framework-neutre obligatoire.
