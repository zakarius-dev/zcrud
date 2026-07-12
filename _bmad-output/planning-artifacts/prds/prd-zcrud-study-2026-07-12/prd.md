---
title: "zcrud_study (extension éducative)"
status: draft
created: 2026-07-12
updated: 2026-07-12
owner: Zakarius
project: zcrud
phase: "Extension — famille de packages éducatifs"
language: fr
grounding:
  - docs/study-integration-inventory.md
  - _bmad-output/planning-artifacts/briefs/brief-zcrud-study-2026-07-12/brief.md
predecessors:
  - _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md
numbering: "FR-S## / UJ-S## / SM-S## / OQ-S## — préfixe -S- pour ne PAS entrer en collision avec les 26 FR du PRD produit (FR-1..FR-26)"
---

# PRD : zcrud_study (famille de packages éducatifs)
*Titre de travail — à confirmer.*

## 0. Objet du document

Ce PRD **étend** le produit `zcrud` pour une nouvelle phase — la famille de packages éducatifs `zcrud_study` — sans le refaire. Il est destiné au product owner (Zakarius), aux applications consommatrices (**IFFD**, **lex_douane**, puis futures apps éducatives) et aux workflows BMAD en aval (architecture, épics, stories). Comme le PRD produit, le vocabulaire est ancré par un Glossaire (§3), les capacités sont groupées par **fonctionnalité** avec des exigences fonctionnelles numérotées, les hypothèses sont taguées `[HYPOTHÈSE]` et indexées (§10).

**Continuité de numérotation (non-négociable).** Le PRD produit occupe déjà `FR-1..FR-26`, `SM-1..SM-6/SM-C1-C2`, `UJ-1..UJ-4`, `OQ-1..OQ-12`. Pour éviter toute collision et rendre la provenance immédiatement lisible en aval, **cette extension utilise un préfixe distinct `-S-`** : exigences `FR-S1..FR-S34`, parcours `UJ-S1..UJ-S4`, métriques `SM-S1..SM-S7`, questions ouvertes `OQ-S1..OQ-S6`. Une référence `FR-S12` est donc sans ambiguïté une exigence de l'extension éducative.

Ce PRD **s'appuie sur** et ne duplique pas : le **Product Brief `zcrud_study`** (`_bmad-output/planning-artifacts/briefs/brief-zcrud-study-2026-07-12/brief.md`), l'**inventaire d'intégration** (`docs/study-integration-inventory.md` — **source of truth factuelle**, Section 0 = décisions verrouillées, §2 modèle canonique, §3 ports, §4 data, §5 UI, §6 seams, §7 graphe, §9 découpage ES-1..ES-11), le **PRD produit** (26 FR) et l'**architecture** (**16 décisions AD-1..AD-16 NON-NÉGOCIABLES**). Les détails exhaustifs vivent dans ces documents ; les FR y renvoient.

## 1. Vision

Le monorepo `zcrud` a résolu la duplication du **moteur CRUD** partagé entre DODLP, IFFD et DLCFTI. Une deuxième duplication, tout aussi coûteuse, reste ouverte : les **fonctionnalités éducatives** — dossiers d'étude, flashcards à répétition espacée, cartes mentales, notes riches, documents annotés, sessions de révision, examens, tags, partage communautaire — vivent en **deux implémentations divergentes**, IFFD (origine et **apparence de référence**) et lex_douane (domaine « education » le plus complet et le plus propre, ~25 entités pures Dart). Chaque évolution est re-portée à la main d'une app à l'autre ; les modèles divergent, les bugs se dédoublent, et aucune future app éducative ne peut démarrer sans re-cloner ce socle.

`zcrud_study` extrait ce domaine en une **famille de packages finement décomposés**, tous bâtis sur `zcrud_core` et **réutilisant** les packages déjà livrés (`zcrud_flashcard` E9, `zcrud_mindmap` E10, `zcrud_markdown` E6) au lieu de les reconstruire. Un nouveau socle bas `zcrud_study_kernel` porte le squelette organisationnel (`ZStudyFolder` et sa hiérarchie), remonté depuis `zcrud_flashcard` ; au-dessus, des packages spécialisés (`zcrud_note`, `zcrud_document`, `zcrud_session`, `zcrud_exam`) portent chacun un pan du domaine ; un package d'orchestration `zcrud_study` compose le tout et reproduit le **layout « study tools » d'IFFD** comme apparence par défaut, thème et l10n injectés.

Le pari, **invariant de succès n°1** : à la migration d'IFFD et de lex_douane sur `zcrud_study`, **rien ne devient structurellement différent**. L'apparence de référence est préservée, les modèles convergent vers le canonique lex sans casser la planification SRS existante, et les deux apps continuent de fonctionner — l'une sous GetX, l'autre sous Riverpod — via des bindings minces, le cœur n'imposant aucun gestionnaire d'état (AD-2/AD-15). Ce qui change : une correction se fait désormais **une fois** et profite à tout l'écosystème éducatif — comme pour le moteur CRUD avant lui.

## 2. Cible

### 2.1 Jobs To Be Done

- **En tant que développeur-mainteneur (Zakarius)**, cesser d'écrire deux fois toute évolution éducative (IFFD ↔ lex_douane) ; corriger un bug d'étude une fois pour toutes les apps.
- **En tant qu'intégrateur d'IFFD**, remplacer le `data_crud` legacy et le god-controller GetX par des packages, corriger les fuites backend du domaine (`Timestamp`/`Color`/`IconData`/`Dashboard`) et régler le bug de rebuild de l'éditeur de flashcards — **sans réécrire l'apparence** que mes utilisateurs connaissent.
- **En tant qu'intégrateur de lex_douane**, remplacer progressivement mes ~25 entités et ~15 repos d'« education » par le socle partagé, sous Riverpod, **sans big-bang** ni régression fonctionnelle du module.
- **En tant qu'auteur d'une future app éducative** (collège, université, institut, centre de formation), démarrer en important exactement les packages voulus (flashcards sans examens, notes sans communauté), hériter de l'apparence IFFD re-thémable, du SRS éprouvé, des mindmaps et du markdown riche, et étendre modèles/types sans forker le socle.
- **En tant qu'utilisateur final**, organiser mes dossiers, réviser en répétition espacée sans perte de focus à l'édition, annoter des documents, prendre des notes riches, préparer des examens et partager mes dossiers.

### 2.2 Non-utilisateurs (v1)

- Les entités **spécifiques métier douane** (ex. `ComparativeStudy`) — non portées, hors périmètre éducatif générique.
- Les apps voulant le mode **flowchart legacy** des mindmaps (`flutter_flow_chart`) ou `graphview` — `graphite` reste le standard de `zcrud_mindmap`.
- Les apps voulant un **routeur IA / backend de partage clé-en-main** dans le package — ces implémentations restent app-specific derrière les seams.

### 2.3 Parcours utilisateurs clés

*Les « utilisateurs » d'une famille de packages sont d'abord des développeurs intégrateurs ; les parcours end-user comptent car ils fixent les critères de qualité observables (notamment l'invariant de migration et le bug de rebuild).*

- **UJ-S1. Zakarius migre IFFD sur `zcrud_study` sans dépayser les utilisateurs.**
  - **Persona + contexte :** mainteneur, IFFD en prod, `data_crud` réflexif + god-controller GetX, domaine qui fuit le backend, données en collections top-level plates nommées d'après la classe Dart.
  - **Parcours :** ajoute les packages `zcrud_study*` au pubspec ; branche le binding `zcrud_get` ; fournit un `ZFirestorePathResolver` « flat top-level by type » et un codec de désérialisation acceptant les clés camelCase legacy ; lance la migration de données (ajout rétro-compatible de `ZSyncMeta`, restructuration plat→canonique) ; remplace les écrans par `ZStudyToolsPage`.
  - **Climax :** l'app tourne à parité, **l'apparence « study tools » est préservée**, l'éditeur de flashcards ne perd plus le focus, aucune donnée utilisateur n'est perdue à la bascule.
  - **Résolution :** le `data_crud` legacy et le god-controller sont supprimés ; les corrections profitent désormais aussi à lex_douane.
  - **Edge case :** un document IFFD legacy sans `ZSyncMeta` et à enum inconnu se désérialise sur un défaut sûr, jamais un throw (AD-10).

- **UJ-S2. lex_douane_admin remplace un repo « education » sous Riverpod, sans big-bang.**
  - **Persona + contexte :** app lex_douane, Riverpod exclusif, module « education » canonique et actif.
  - **Parcours :** remplace un provider de repo lex (ex. `smart_notes_repository`) par un provider `zcrud_riverpod` adossé à `ZStudyRepository<ZSmartNote>` + adapter `zcrud_firestore` « nested under folder » ; la famille Riverpod de config de session utilise l'égalité profonde de `ZStudySessionConfig` **fournie côté binding**.
  - **Climax :** l'écran fonctionne à l'identique, la planification SRS des utilisateurs reste inchangée (source SM-2 unique), aucune régression fonctionnelle.
  - **Résolution :** les repos lex sont remplacés un par un ; le domaine devient partagé.

- **UJ-S3. Une utilisatrice révise un dossier via l'apparence study-tools.**
  - **Persona + contexte :** Aïcha, étudiante, ouvre un dossier d'étude sur mobile.
  - **Parcours :** voit le rail horizontal de flashcards, les sections réordonnables (documents, notes, mindmaps), lance une session de révision espacée, note la qualité de chaque carte, consulte l'anneau de progression, puis annote un PDF du dossier.
  - **Climax :** la session planifie les prochaines révisions (SM-2), la progression s'affiche, l'annotation est persistée offline-first ; taper dans l'éditeur d'une carte ne reconstruit que le champ courant.
  - **Résolution :** l'état SRS (personnel) est mis à jour sans jamais être emporté par un futur partage.

- **UJ-S4. Un enseignant partage un dossier public modéré.**
  - **Persona + contexte :** enseignant activant l'extension communauté (optionnelle) de son app.
  - **Parcours :** publie un dossier via `ZShareLink`, l'expose en galerie (`ZPublicStudyFolder`) ; un autre utilisateur le rejoint (`ZStudyMembership`) ; un contenu est signalé (`ZStudyFolderReport`) et masqué par modération.
  - **Climax :** le partage fonctionne via le seam `ZStudySharingPort`/`ZStudyModerationPort` ; l'état personnel (SRS, ordre de contenu, état de lecture) **n'est jamais** partagé.
  - **Edge case :** la limite LWW connue (révocation à la prochaine sync) et la dette de sécurité héritée de lex sont **documentées ou corrigées explicitement**, jamais héritées silencieusement.

## 3. Glossaire

*Termes à employer verbatim en aval (FR, UJ, SM). Pas de synonyme ailleurs. Les termes déjà définis dans le PRD produit (ZFieldSpec, ZcrudModel, ZExtension, extra, ZcrudScope, ZSrsScheduler, ZRepository, offline-first…) restent valides et ne sont pas redéfinis ici.*

- **`zcrud_study_kernel`** — nouveau package bas-niveau portant le **squelette d'étude** : `ZStudyFolder` + hiérarchie/`validatePlacement` + `ZFolderContentsOrder` + `ZStudySessionConfig`. Dépend de `zcrud_core` uniquement.
- **`zcrud_study`** — nouveau package d'**orchestration** : `ZStudyToolsPage` (apparence IFFD), agrégation quotidienne, composition des seams. Dépend de `zcrud_core`, `zcrud_study_kernel`, `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_markdown`, `zcrud_note`, `zcrud_document`, `zcrud_session`, `zcrud_exam`.
- **`zcrud_note` / `zcrud_document` / `zcrud_session` / `zcrud_exam`** — nouveaux packages spécialisés (notes riches ; documents+annotations+lecture ; runtimes de session purs ; examens+rappels).
- **ZStudyFolder** — container d'étude générique multi-type (rattachement inverse par `folderId`), hiérarchie 2 niveaux via `validatePlacement`, soft-archive. **Remonté** de `zcrud_flashcard` vers `zcrud_study_kernel` (option A). Les champs de partage vivent en `ZExtension?`.
- **ZStudyDocument** — document (PDF) rattaché à un dossier : `documentId`, `folderId`, `fileName`, `status`, `storagePath`, `pageCount?`, `sizeBytes`.
- **ZDocumentReadingState / ZDocumentLearningInfo** — état **personnel** de lecture d'un document (page courante, préférences, apprentissage par page). Hors sous-arbre partageable.
- **ZDocumentAnnotation / ZAnnotationBounds** — annotation **partageable** d'un document (surlignage / note collante), bornes normalisées [0,1]. `is_deleted` porté hors-entité (`ZSyncMeta`).
- **ZSmartNote** — note riche rattachée à un dossier ; `content` **typé via `ZCodec`** (Delta JSON), jamais `String?` ambiguë. Champs audio en `ZExtension`/`extra`.
- **ZFlashcardTag / ZSuggestedTag** — tag de flashcard first-class (aujourd'hui `tagIds` = `List<String>` nu) avec `colorKey` bornée + remap déterministe ; suggestion de tag avant matérialisation.
- **ZExam / ZReminderTime** — examen daté rattaché à un dossier + rappels (jours avant, heure `HH:mm`). Méthodes pures `daysUntil`/`isPast`/`isApproaching(now injecté)`.
- **ZFolderContentsOrder** — ordre **personnel** du contenu d'un dossier par section (`Map<sectionKey, List<id>>`), appliqué par `applyOrder<T>` (tri stable pur).
- **ZStudySessionConfig / ZStudySessionResult** — configuration d'une session (mode, dossier, tags, types, count) et son résultat agrégé (total/correct/byQuality).
- **ZDailyStudyTask** — tâche quotidienne agrégée (cartes dues, examen approchant), produite par `aggregateDailyStudyTasks` (fonction pure).
- **ZStudySessionEngine / ZLinearSessionState / ZWhiteExamSessionEngine** — **runtimes de session purs** (`ChangeNotifier`/reducer, aucun gestionnaire d'état) : cycle SRS (queue/réinsertion) ; cramming/liste (zéro écriture SM-2 **par construction**) ; examen blanc (setup/running/submitted).
- **ZStudyPodcast** — podcast audio content-addressed (`{sourceId}_{mode}`, `sourceHash`, `resultRef`, `status`).
- **ZStudyMembership / ZShareLink / ZPublicStudyFolder / ZStudyFolderReport** — entités de **communauté/partage** (adhésion, lien de partage révocable, galerie publique, signalement) ; **extension optionnelle activable**, pas un invariant du domaine.
- **ZStudyRepository&lt;T&gt;** — contrat de dépôt d'étude générique (`Either<ZFailure,T>`, `Stream<List<T>>` nu, `save`/`delete`/`sync`), avec hook de validation métier par override.
- **ZOfflineFirstBoxRepository&lt;T&gt;** — helper d'adapter `zcrud_firestore` factorisant le stockage local (`_StoredEntry`/`is_deleted`), la boucle de merge LWW et le filtrage `hasPendingWrites`.
- **ZFirestorePathResolver** — résolveur de chemins configurable réconciliant les deux topologies : « flat top-level by type » (IFFD) et « nested under folder » (lex).
- **ZSyncMeta** — métadonnées de sync **hors-entité** (`updated_at`, `is_deleted`), AD-9/AD-16 ; ajout **rétro-compatible additif obligatoire**, absent des deux sources.
- **ZFeatureAvailability** — interface **injectable** (pas classe const) exprimant la disponibilité progressive des éditeurs par app.
- **Seam d'étude** — port neutre (`Either<ZFailure,T>`) déféré à l'app/binding : `ZFlashcardGenerationPort`, `ZAiExplanationPort`, `ZNoteSummaryPort`, `ZPodcastGenerationPort`, `ZStudySharingPort`, `ZStudyModerationPort`, `ZDocumentUploadPipeline`, `ZEducationQuotaInfo` (fail-open).

## 4. Fonctionnalités

*Chaque sous-section est une fonctionnalité cohérente : description comportementale, puis FR (`FR-S1..FR-S34`). Les détails exhaustifs sont dans l'inventaire d'intégration. Toutes les entités sont `@ZcrudModel` (codegen zcrud, AD-3 — jamais `Timestamp`/`freezed`/`reflectable`), persistance snake_case + enums camelCase, désérialisation défensive (AD-10), sync hors-entité `ZSyncMeta` (AD-9/AD-16). Les 16 AD s'appliquent à chaque FR.*

### 4.1 Squelette d'étude — `zcrud_study_kernel` (fondations)

**Description :** crée le socle bas-niveau et **remonte `ZStudyFolder`** de `zcrud_flashcard` vers `zcrud_study_kernel` (option A verrouillée), refactorant `zcrud_flashcard` (E9) pour en dépendre. Tranche l'open question canonique #3 (métadonnées de sync dans-entité vs hors-entité). Extrait les utilitaires purs dupliqués. Réalise UJ-S1, UJ-S2. Correspond à **ES-1**.

**Functional Requirements :**

#### FR-S1 : Remontée de `ZStudyFolder` vers `zcrud_study_kernel` (option A), acyclicité prouvée
Un développeur peut dépendre de `ZStudyFolder` + `validatePlacement` + `ZStudySessionConfig`/`Selector` + `ZFolderContentsOrder` depuis `zcrud_study_kernel` sans tirer tout `zcrud_flashcard`.
**Conséquences (testables) :**
- `zcrud_study_kernel` porte `ZStudyFolder`, la hiérarchie 2 niveaux (`validatePlacement`) et `ZStudySessionConfig` ; `zcrud_flashcard` est refactoré pour en dépendre et **ne définit plus** `ZStudyFolder`.
- Le graphe de dépendances reste **acyclique** : `melos run analyze` **ET** `melos run verify` sont verts **repo-wide** (pas seulement par package), après refactor.
- La suite de tests E9 (`zcrud_flashcard`) passe **sans régression** (RC=0, nombre de tests ≥ avant refactor).
- `zcrud_mindmap` référence les dossiers par `folderId` (clé neutre) et **ne dépend pas** de `ZStudyFolder` (aucun cycle).
- Aucun symbole public supprimé de `zcrud_flashcard` n'est référencé sans réexport/migration (contrôle cross-package explicite).

#### FR-S2 : Utilitaires domaine purs partagés
Un développeur peut réutiliser palette de couleurs, tri d'ordre et normalisation de titre sans les redupliquer.
**Conséquences (testables) :**
- `ZColorPalette` (registre `colorKey→Color` figé + fallback + remap déterministe SHA-256) est fourni **couleurs injectées** (jamais codées en dur, AD-13) ; il remplace les 3+ palettes dupliquées lex/IFFD.
- `applyOrder<T>` réalise un tri stable générique sans dépendance métier (candidat `zcrud_core`) ; un id absent de l'ordre garde une position déterministe.
- `normalizeTagTitle()` (trim + collapse d'espaces + lowercase) et le dédoublonnage par titre normalisé sont purs et testés.

#### FR-S3 : Réconciliation des métadonnées de sync (open question canonique #3)
Un développeur obtient une convention **unique** de métadonnées de sync pour toutes les entités d'étude.
**Conséquences (testables) :**
- Toutes les **nouvelles** entités d'étude (`ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZDocumentAnnotation`, …) portent `updated_at`/`is_deleted` **hors-entité** via `ZSyncMeta` (AD-9/AD-16), alignées sur `ZMindmap`.
- `ZStudyFolder` (qui portait historiquement ces champs dans l'entité) est aligné ou sa divergence est **documentée explicitement** dans l'architecture, jamais laissée implicite.
- La décision est consignée (memlog + doc architecture) avant de figer une seule entité canonique.

### 4.2 Domaine canonique éducatif + codegen — `zcrud_note`/`zcrud_document`/`zcrud_exam`

**Description :** porte les entités manquantes vers le canonique lex, chacune `@ZcrudModel`, désérialisation défensive, round-trip testé. Réutilise `ZFlashcard`/`ZRepetitionInfo`/`ZStudyFolder`/`ZMindmap` existants. Réalise UJ-S2, UJ-S3. Correspond à **ES-2**.

**Functional Requirements :**

#### FR-S4 : Document d'étude + état de lecture
Un développeur peut modéliser un document (PDF) rattaché à un dossier et son état de lecture personnel.
**Conséquences (testables) :**
- `ZStudyDocument` porte `documentId`/`folderId`/`fileName`/`status`/`storagePath`/`pageCount?`/`sizeBytes` ; round-trip `toMap/fromMap` stable.
- `ZDocumentReadingState`/`ZDocumentLearningInfo` (page courante, préférences, `qualityByPage`) sont **état personnel** (hors sous-arbre partageable) ; désérialisation défensive imbriquée (champ absent → défaut sûr, jamais throw).

#### FR-S5 : Note intelligente à contenu typé
Un développeur peut modéliser une note riche dont le contenu est non ambigu.
**Conséquences (testables) :**
- `ZSmartNote` porte `content` **typé via `ZCodec`** (Delta JSON) ; l'ambiguïté markdown/Delta n'est **jamais** résolue par heuristique regex dans l'UI.
- Les champs audio (`audioUrl`/`audioPath`/`audioTextHash`) vivent en `ZExtension`/`extra` ; une note sans audio se désérialise sur le défaut.

#### FR-S6 : Tags de flashcard first-class
Un développeur peut créer/matérialiser des tags de flashcard typés, palette injectable.
**Conséquences (testables) :**
- `ZFlashcardTag` (id/title/colorKey) et `ZSuggestedTag` (title/colorKey) sont des entités ; `remapColorKey` est une fonction domaine pure déterministe.
- La palette n'est **pas verrouillée** à N clés lex : elle est **injectée** (AD-13) ; une `colorKey` inconnue est remappée déterministe, jamais un crash.
- La référence orpheline (tag supprimé encore référencé par `tagIds`) est détectable (intégrité référentielle, cf. FR-S27).

#### FR-S7 : Ordre de contenu de dossier
Un développeur peut persister et appliquer un ordre personnel du contenu par section.
**Conséquences (testables) :**
- `ZFolderContentsOrder` porte `folderId` + `Map<sectionKey, List<id>>` ; `applyOrder<T>` (FR-S2) l'applique de façon stable ; état **personnel**.

#### FR-S8 : Annotation de document
Un développeur peut modéliser des annotations partageables de document.
**Conséquences (testables) :**
- `ZDocumentAnnotation` (id/docId/page/kind/colorKey/bounds/rects?/text?) + `ZAnnotationBounds` bornées [0,1] ; contenu **partageable**.
- `is_deleted` est extrait **hors-entité** vers `ZSyncMeta` (AD-9) — jamais inline comme dans la source lex.

#### FR-S9 : Examen daté + rappels
Un développeur peut modéliser un examen rattaché à un dossier avec rappels.
**Conséquences (testables) :**
- `ZExam` (id/folderId/title/date/reminderEnabled/reminderDaysBefore[]/reminderTime) + `ZReminderTime` (value-object + JsonConverter `HH:mm`).
- Méthodes pures `daysUntil`/`isPast`/`isApproaching` prennent l'horloge **injectée** (`now`), jamais `DateTime.now()` en dur → testables déterministes.

#### FR-S10 : Résultat de session + agrégation quotidienne
Un développeur peut agréger les tâches d'étude du jour.
**Conséquences (testables) :**
- `ZStudySessionResult` (mode/total/correct/byQuality) est un value-object.
- `ZDailyStudyTask` + `aggregateDailyStudyTasks` (fonction pure) produisent les cartes dues et examens approchants ; le variant sealed est généralisé via registre si extensible (AD-4).

#### FR-S11 : Podcast content-addressed
Un développeur peut modéliser un podcast dérivé d'une source, invalidé par hash.
**Conséquences (testables) :**
- `ZStudyPodcast` (id `{sourceId}_{mode}`, sourceKind/sourceId/folderId/mode/sourceHash/resultRef/status) ; un changement de `sourceHash` invalide le cache (le port de génération vit en seam, FR-S31).

**Feature-specific NFR :** toutes les entités de §4.2 passent la gate de rétro-compatibilité de sérialisation (§5, NFR-S4) ; `FlashcardSource.fromJson` **diverge volontairement** de la source lex (qui lève `FormatException`) vers un variant « unknown »/défaut sûr (AD-10).

### 4.3 Ports & couche data offline-first — `zcrud_firestore` (adapters)

**Description :** factorise le contrat de dépôt répété ~15× dans lex, réconcilie les deux topologies de collections (flat IFFD / nested lex) par adapters, sans qu'aucun nom/chemin de collection ni type backend ne fuie dans le domaine (AD-5/AD-11/AD-16). Réalise UJ-S1, UJ-S2. Correspond à **ES-3**.

**Functional Requirements :**

#### FR-S12 : Dépôt d'étude générique
Un développeur peut consommer/fournir un `ZStudyRepository<T>` sans dupliquer le CRUD offline-first.
**Conséquences (testables) :**
- `ZStudyRepository<T>` expose `dataChanges: Stream<List<T>>` **nu**, `get`/`save`/`delete`/`sync` en `Either<ZFailure,T>`/`Unit`, avec **hook de validation métier par override** (invariant 2 niveaux dossiers, matérialisation éphémère flashcards).
- Le domaine ne contient **aucun** `Timestamp`/`Filter`/`Box`/`WriteBatch`/`Color`/`IconData`.

#### FR-S13 : Helper offline-first + résolveur de chemins bi-topologie
Un développeur peut brancher le même domaine sur la topologie plate (IFFD) **ou** imbriquée (lex).
**Conséquences (testables) :**
- `ZOfflineFirstBoxRepository<T>` factorise `_StoredEntry`/`_readEntry` (+ `is_deleted`), `_softDeleteInBox`, la boucle `_mergeSnapshotWithLocal` (paramétrée par comparateur LWW + fromJson/toJson), le filtrage `hasPendingWrites` (ignorer les échos locaux) et l'upload de rattrapage local-only.
- `ZFirestorePathResolver` configurable résout « flat top-level by type » (IFFD) **et** « nested under folder » (lex) + collections globales (`study_share_links` hors `users/{uid}`) ; **aucun chemin en dur dans le domaine**.
- La résolution de collection IFFD est **explicite et statique** (le CRUD quasi-réflexif `collection = nom de classe` est banni, esprit AD-3).
- Le merge supporte un **merge-key hors-entité** (`ZMindmap` n'a pas de `updatedAt` propre), pas seulement `T.updatedAt`.

#### FR-S14 : Cascade de suppression déclarative bornée
Un développeur peut supprimer un dossier et voir sa descendance nettoyée en lots sûrs.
**Conséquences (testables) :**
- La cascade (dossier→sous-dossiers→cartes→répétitions→notes→mindmaps→documents→annotations) est exprimée par un **registre déclaratif de relations parent/enfant** (pas codée en dur), la topologie IFFD pouvant différer.
- Le batcher (`ZFirestoreCascadeBatcher`) borne à **≤ 450 écritures/lot** avec flush automatique (AD-9).

#### FR-S15 : Orchestrateur de sync paramétré
Un développeur peut déclencher la sync d'un ensemble de dépôts injecté, générique entre IFFD et lex.
**Conséquences (testables) :**
- `ZSyncOrchestrator` (existant E5) est **paramétré par une liste injectée** de dépôts synchronisables (login + reconnexion débouncée ~400 ms), **jamais** des imports en dur (sinon non générique).
- Un échec de dépôt n'arrête pas les autres (best-effort) ; aucun blocage du thread UI.

#### FR-S16 : Compatibilité de sérialisation camelCase↔snake_case + `ZSyncMeta` additif
Un développeur peut migrer des documents legacy sans perte ni throw.
**Conséquences (testables) :**
- Le codec `zcrud_firestore` fait le **mapping bidirectionnel** snake_case (canonique) ↔ camelCase (clés historiques IFFD) en lecture — **jamais dans le domaine**.
- L'ajout de `ZSyncMeta` (`updated_at` + `is_deleted`) est **rétro-compatible additif** : un document IFFD legacy qui ne les porte pas se lit sur des défauts sûrs.
- L'asymétrie d'horloge (soft-delete `DateTime.now()` local vs `serverTimestamp()` distant) est normalisée dans l'adapter.
- La gate CI de rétro-compatibilité (§5, NFR-S4) passe sur un corpus de documents IFFD legacy (camelCase, sans `ZSyncMeta`).

### 4.4 SRS & runtimes de session — `zcrud_session`

**Description :** converge les trois implémentations SM-2 vers une source unique, extrait les state machines de session en **classes pures** (aucun gestionnaire d'état), fournit les widgets qualité/progression thème injecté. Réalise UJ-S3. Correspond à **ES-4**.

**Functional Requirements :**

#### FR-S17 : Convergence SM-2 vers une source unique
Un utilisateur existant ne subit **aucune** régression de planification après convergence.
**Conséquences (testables) :**
- Les trois implémentations (`Sm2` lex, `Sm` IFFD, `ZSm2Scheduler` existant) sont comparées **précisément et par écrit** (plafond EF 2.5, bonus overdue 0.5, paliers 1j/6j, échelle qualité) ; une **source unique** est choisie explicitement.
- `ZSm2Scheduler` reste derrière `ZSrsScheduler.apply/simulate/initial`, horloge injectée, jamais sealed ; voie d'écriture unique `reviewCard() → apply`.
- Des tests de planification figent le contrat (mêmes entrées → mêmes intervalles) ; l'échelle qualité (lex 0-5 vs IFFD 1-5) est **figée** et documentée.

#### FR-S18 : Runtime de session SRS en cycle (pur)
Un utilisateur peut réviser en cycle (réinsertion sur lapse) ; le runtime est agnostique du gestionnaire d'état.
**Conséquences (testables) :**
- `ZStudySessionEngine` est une classe pure (`ChangeNotifier`/reducer) portant la queue et la réinsertion (offset +2/+4 sur lapse) ; aucun import Riverpod/GetX.
- L'écriture SRS passe uniquement par `reviewCard()` → `ZSrsScheduler.apply`.

#### FR-S19 : Runtimes cramming/liste (zéro écriture SM-2 par construction)
Un utilisateur peut réviser en mode cramming/liste sans altérer sa planification SRS.
**Conséquences (testables) :**
- `ZLinearSessionState` générique **ne référence pas** le dépôt de répétition ; l'invariant « zéro écriture SM-2 » est **garanti par construction** (ports séparés) et testé (aucun appel `apply` durant une session linéaire).

#### FR-S20 : Examen blanc
Un utilisateur peut passer un examen blanc (setup/running/submitted).
**Conséquences (testables) :**
- `ZWhiteExamSessionEngine` couvre les états setup→running→submitted ; le scoring est composable (seam `ZExamScoringPort` si besoin) ; aucune écriture SM-2.

#### FR-S21 : Widgets qualité & progression (thème injecté)
Un développeur peut afficher boutons qualité + intervalle prévisionnel et anneaux de progression sans couleurs codées en dur.
**Conséquences (testables) :**
- `ZSrsQualityButtons` (via `simulate`/`previewLabel`), `ZSessionQualityBreakdown`, `ZStudyProgressRings` (CustomPaint pur consommant un DTO pré-calculé).
- Couleurs/labels via **seam thème** (`ZcrudScope`/`ThemeExtension`), jamais `AppColors.srs*`/`Colors.blue` ; l10n de `zcrud_core`.

### 4.5 Dossiers & organisation — layout « study tools » IFFD (`zcrud_study`)

**Description :** reproduit l'apparence de référence IFFD (`folder_study_tools_page.dart`) comme défaut, chaque section à **scoping `ValueListenable` isolé** (AD-2, zéro rebuild global). Réalise UJ-S3 ; porte l'invariant SM-1. Correspond à **ES-5**.

**Functional Requirements :**

#### FR-S22 : Page « study tools » à apparence IFFD, rebuilds granulaires
Un utilisateur retrouve l'apparence IFFD ; taper dans un champ ne reconstruit que le champ courant.
**Conséquences (testables) :**
- `ZStudyToolsPage` est paramétré par une **liste de sections** (title/itemBuilder/emptyState/addAction) : rail horizontal flashcards + grilles réordonnables docs/notes/mindmaps + `ZEmptyContent` par section et global.
- **Chaque section = un scoping `ValueListenable` isolé** : une frappe/édition dans une section ne reconstruit pas les autres sections (SM-S1 / SM-1 produit — cas de non-régression tiré de `multi_flashcard_editor_page.dart`, `setState` ×18).
- Couleurs/labels/l10n **injectés** ; RTL directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), cibles ≥ 48 dp, `Semantics` explicites, `ListView.builder`.

#### FR-S23 : Sections réordonnables, hub d'ajout, menu d'actions
Un utilisateur peut réordonner le contenu, ajouter du contenu et agir sur un item.
**Conséquences (testables) :**
- `ZStudyToolsSection<T>` générique (id+child) réordonnable ; l'ordre persiste via `ZFolderContentsOrder` (FR-S7).
- `ZContentHubSheet` paramétré par entrées (icon/label/enabled/hint/onTap) ; `ZItemActionsMenu` paramétré par enum kind + callbacks (**callback null = action absente**, AD-4).

#### FR-S24 : Disponibilité progressive des éditeurs injectable
Un développeur peut activer/désactiver des éditeurs selon la roadmap de son app.
**Conséquences (testables) :**
- `ZFeatureAvailability` est une **interface injectable** (jamais une classe const compilée) : deux apps aux roadmaps différentes fournissent leurs disponibilités sans modifier `zcrud_study`.

### 4.6 Notes & markdown (réutilisation `zcrud_markdown`) — `zcrud_note`

**Description :** monte l'édition/lecture de `ZSmartNote` sur `zcrud_markdown` **réutilisé tel quel** (pas de nouveau codec), plus la migration des tables. Correspond à **ES-6**.

**Functional Requirements :**

#### FR-S25 : Édition/lecture de notes via `zcrud_markdown`
Un utilisateur peut éditer et lire une note riche ; un développeur ne réimplémente pas de codec.
**Conséquences (testables) :**
- L'édition passe par `ZMarkdownField` (controller isolé, conforme FR-1/AD-2), la lecture par `ZMarkdownReader` ; aucun nouveau pipeline rich-text.
- Un adaptateur migre les **tables markdown** IFFD (string) vers la table structurée `{rows,columns,cells}` de `zcrud_markdown` ; les sticky-notes IFFD (TextField texte plat) sont upgradées vers `ZCodec`.

### 4.7 Mindmap (intégration, réutilisation `zcrud_mindmap`) — `zcrud_study`

**Description :** compose `ZMindmapView`/`ZMindmapOutlineController` dans la page study-tools ; **les écarts sont comblés dans `zcrud_mindmap`**, pas dupliqués. Pas de `graphview`/`flowchart`. Correspond à **ES-7**.

**Functional Requirements :**

#### FR-S26 : Intégration mindmap dans study-tools
Un utilisateur peut visualiser/éditer une carte mentale de dossier ; les écarts vivent dans le package d'origine.
**Conséquences (testables) :**
- `ZMindmapView`/`ZMindmapOutlineController` (existants, `graphite`) sont composés dans `ZStudyToolsPage` par `folderId`.
- Les écarts éventuels (édition outline interactive indent/outdent au clic, compact/plein-écran/super-racine multi-forêt/zoom) sont comblés **dans `zcrud_mindmap`**, pas dans `zcrud_study` ; le mode `flowchart` legacy n'est **pas** porté.
- La décision rich-text du `content` de nœud (slot `ZExtension`/`ZCodec` côté app) est tranchée et documentée (cf. OQ-S).

### 4.8 Tags & annotations (UI) — `zcrud_document` / `zcrud_study`

**Description :** éditeur/chips/confirmation IA de tags (palette injectable) et outils d'annotation (a11y WCAG stricte). Correspond à **ES-8**.

**Functional Requirements :**

#### FR-S27 : UI de tags + intégrité référentielle
Un utilisateur peut créer/appliquer des tags ; les références orphelines sont purgées.
**Conséquences (testables) :**
- Éditeur/chips/confirmation-IA de tags avec **palette injectable** (FR-S6) ; `normalizeTagTitle` empêche les doublons.
- La suppression d'un tag purge ses références orphelines dans `tagIds` (intégrité référentielle) ; `usageCount` reste cohérent.

#### FR-S28 : UI d'annotations accessible
Un utilisateur peut annoter un document ; l'accessibilité est garantie.
**Conséquences (testables) :**
- Toolbar/panel/palette d'annotations ; **la couleur n'est jamais le seul canal d'information** (WCAG) — label/forme/texte a11y obligatoires ; cibles ≥ 48 dp, `Semantics` explicites.

### 4.9 Seams IA / communauté / examens (UI) — `zcrud_study`

**Description :** expose tout l'app-specific derrière des **ports neutres** (`Either<ZFailure,T>`), jamais dans le cœur. Inclut examens (UI+rappels), podcasts, et communauté/partage en **extension optionnelle activable**. Réalise UJ-S4. Correspond à **ES-9**.

**Functional Requirements :**

#### FR-S29 : Seams IA neutres (génération, explication, résumé, quota)
Un développeur peut brancher son routeur IA sans que prompts/transport ne fuient dans le domaine.
**Conséquences (testables) :**
- `ZFlashcardGenerationPort` (`Either<ZFailure, List<ZFlashcard>>`), `ZAiExplanationPort`, `ZNoteSummaryPort` sont des ports neutres ; `ZFlashcardGenerationRequest` est un value-object, `toWireJson`/prompts/streaming SSE restent **côté app**.
- `ZEducationQuotaInfo` (limit?/remaining?/resetSeconds?) est construit côté datasource depuis les headers HTTP (pas JSON entité), **fail-open** (quota indisponible ⇒ ne bloque pas).
- La provenance de flashcard (`article/note/conversation/document/subject`) est un **registre pluggable** (`ZSourceRegistry`/`ZTypeRegistry`, AD-4), pas un switch exhaustif — IFFD/lex enregistrent leurs variants (hsSection/chatConversationId) sans modifier `zcrud_study`.

#### FR-S30 : Examens & rappels (UI)
Un utilisateur peut créer/consulter des examens et recevoir des rappels.
**Conséquences (testables) :**
- UI de création/liste d'examens adossée à `ZExam`/`ZReminderTime` (FR-S9) ; les rappels approchants alimentent `aggregateDailyStudyTasks` (FR-S10).
- La planification de notification concrète (canal OS) est un **seam app** ; le domaine ne calcule que `isApproaching(now)` déterministe.

#### FR-S31 : Podcasts (seam de génération)
Un développeur peut générer des podcasts content-addressed via un port neutre.
**Conséquences (testables) :**
- `ZPodcastGenerationPort` + `ZStudyPodcast` (FR-S11) ; l'implémentation TTS/pipeline audio reste app-specific ; le cache est invalidé par `sourceHash`.

#### FR-S32 : Communauté / partage optionnelle + modération
Un développeur peut activer le partage sans qu'il devienne un invariant du domaine ; l'état personnel n'est jamais partagé.
**Conséquences (testables) :**
- Le partage est une **extension optionnelle activable** : `ZExtension?` sur `ZStudyFolder` + `ZStudyMembership`/`ZShareLink`/`ZPublicStudyFolder`/`ZStudyFolderReport` + ports `ZStudySharingPort`/`ZStudyModerationPort`. Une app qui n'active pas le partage n'en tire ni entités ni backend.
- L'état **personnel** (`ZRepetitionInfo`, `ZFolderContentsOrder`, `ZDocumentReadingState`) n'est **jamais** emporté par le partage (séparé du sous-arbre partageable).
- La **dette de sécurité héritée de lex** (contributeur pouvant modifier des champs de contrôle ; limite LWW / révocation à la prochaine sync) est **corrigée ou documentée explicitement** au portage — jamais héritée silencieusement.

**Feature-specific NFR :** `ZShareLink` révocable ; `study_share_links` résolu en collection globale (FR-S13) ; l'`ownerUid` et les champs de contrôle sont protégés côté règles/adaptateur.

### 4.10 Bindings & migration des données

**Description :** relie `zcrud_study` aux gestionnaires d'état des apps par bindings minces (AD-15), puis migre les apps. Le code manager-spécifique vit **uniquement** dans son binding. Réalise UJ-S1, UJ-S2. Correspond à **ES-10 / ES-11**.

**Functional Requirements :**

#### FR-S33 : Binding Riverpod (lex_douane)
Un développeur lex peut consommer `zcrud_study` sous Riverpod et migrer progressivement.
**Conséquences (testables) :**
- `zcrud_riverpod` fournit les providers pour repos/streams `zcrud_study` ; l'**égalité profonde** de `ZStudySessionConfig` pour la famille Riverpod vit **dans le binding**, pas dans le cœur.
- L'intégration lex_douane remplace les repos « education » **un par un** (pas de big-bang) ; aucune régression fonctionnelle du module.
- Aucun `WidgetRef`/`ConsumerWidget` dans `zcrud_study*`.

#### FR-S34 : Binding GetX + migration IFFD (données flat→canonique)
Un développeur IFFD peut consommer `zcrud_study` sous GetX et migrer ses données sans perte.
**Conséquences (testables) :**
- `zcrud_get` fournit injection/lifecycle pour `zcrud_study` ; aucun `Get.find`/`Get.put` dans `zcrud_study*`.
- La migration IFFD remplace le `data_crud` legacy + le god-controller, et **restructure les données** top-level plates → canonique (nested ou flat via `ZFirestorePathResolver`), avec ajout rétro-compatible de `ZSyncMeta`.
- Aucune donnée utilisateur perdue à la bascule (vérifié sur corpus de migration) ; l'apparence study-tools est préservée (UJ-S1).

## 5. NFR transverses (cross-cutting)

*S'appliquent à **toute** FR. Adossés aux 16 AD ; chaque `done` de story les rejoue réellement (gates CI E1-3/E2-10).*

- **NFR-S1 — Rebuilds granulaires (SM-1, objectif produit n°1).** Sur l'éditeur de flashcards de référence (cas `multi_flashcard_editor_page.dart`), taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus (test widget + profiling). Aucun `setState` à l'échelle d'un formulaire/section. AD-2/AD-15.
- **NFR-S2 — Acyclicité repo-wide (AD-1).** Le graphe de packages reste acyclique ; à **chaque** gate de commit d'epic, `melos run analyze` **ET** `melos run verify` verts **repo-wide** (une vérif par package ne détecte pas une régression cross-package — cf. `ZExportApi` E11a-3).
- **NFR-S3 — Domaine backend-agnostique (AD-5/AD-11/AD-16).** Aucun `Timestamp`/`Filter`/`Box`/`WriteBatch`/`FirebaseException`/`Color`/`IconData`/`Dashboard` dans un package `zcrud_study*` ; toute persistance passe par ports neutres + adapters `zcrud_firestore`. Contrats `Either<ZFailure,T>` (jamais `try-catch` nu), flux `Stream<List<T>>` nus.
- **NFR-S4 — Désérialisation défensive & compat de sérialisation (AD-10).** Un champ absent/corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`/`defaultValue`/`fromJsonSafe → null`). Évolution de schéma **additive seulement**. Gate CI : un corpus de documents IFFD legacy (camelCase, sans `ZSyncMeta`) se désérialise sur défauts sûrs.
- **NFR-S5 — Réactivité Flutter-native, agnostique du manager (AD-2/AD-15).** Aucun `flutter_riverpod`/`get`/`provider` dans `zcrud_study*` ; runtimes de session en `ChangeNotifier`/reducer purs ; code manager-spécifique confiné aux bindings.
- **NFR-S6 — a11y & RTL (AD-13).** Variantes directionnelles obligatoires, cibles ≥ 48 dp, `Semantics` explicites, `ListView.builder`, couleur jamais seul canal d'info (WCAG), sur toutes les surfaces UI.
- **NFR-S7 — Thème & l10n injectés (FR-26 produit, AD-13).** Aucune couleur/label/l10n en dur ; tout via `ZcrudScope`/`ThemeExtension` et l10n de `zcrud_core` (jamais `AppColors.*`/`lex_localizations`/`AppLocalizations`).
- **NFR-S8 — Codegen sans réflexion (AD-3).** Entités `@ZcrudModel` ; `reflectable` banni ; `freezed` non imposé ; la résolution de collection IFFD est statique et explicite (pas `collection = nom de classe`).
- **NFR-S9 — Offline-first (AD-9).** Store local source de vérité, distant fire-and-forget, LWW sur `updated_at`, soft-delete `is_deleted` hors-entité, cascade ≤ 450 écritures/lot, orchestrateur débouncé ~400 ms.
- **NFR-S10 — Modularité prouvée.** Une app importe `zcrud_note` (ou `zcrud_flashcard`) **seul** sans tirer examens, communauté ni Firebase (test de résolution de dépendances).
- **NFR-S11 — Sécurité.** Aucun secret dans un package ; jamais `badCertificateCallback => true` ; la dette de sécurité du partage lex corrigée ou documentée (FR-S32).

## 6. Non-Goals (explicites)

- `zcrud_study` ne remplace **pas** le module « education » de lex_douane en big-bang : remplacement progressif, repo par repo.
- Il n'embarque **pas** de routeur IA, prompts, backend de partage ni pipeline d'upload concrets — ils restent dans les apps derrière les seams.
- Il ne porte **pas** le mode flowchart legacy (`flutter_flow_chart`) ni `graphview` — `graphite` reste le standard mindmap.
- Il ne porte **pas** les entités métier douane (`ComparativeStudy`) ni le format wire chat (`toChatJson`/`fromChatJson`) ni les seeds de flashcards par référentiel (SH/tarif IFFD) — app-specific.
- Il n'impose **aucun** gestionnaire d'état ; le partage n'est **pas** un invariant du domaine (extension optionnelle).

## 7. Périmètre v1

### 7.1 Dans le périmètre (v1 = TOUT — décision verrouillée)

Squelette (`zcrud_study_kernel` + refactor `zcrud_flashcard`), domaine canonique complet (document/note/tag/ordre/annotation/examen/résultat/tâche quotidienne/podcast), ports & data offline-first bi-topologie, SRS convergé + runtimes de session, layout study-tools apparence IFFD, notes/mindmap/tags/annotations, examens & rappels, communauté/partage + modération (optionnelle), podcasts, seams IA, bindings Riverpod (lex) **et** GetX (IFFD) + migration des données IFFD. Couvre `FR-S1..FR-S34`.

### 7.2 Hors périmètre v1

- Implémentations concrètes derrière les seams (routeurs IA, TTS podcast, backend de partage, upload storage) — fournies par les apps.
- Migration de DLCFTI/DODLP sur `zcrud_study` — après stabilisation IFFD + lex_douane.
- Backends non-Firestore réels — contrat exprimable seulement.

## 8. Métriques de succès

*Chaque SM-S croise les FR qu'elle valide. Reprend les critères de succès du brief.*

**Primaires**
- **SM-S1 — Invariant de migration (n°1).** À la bascule d'IFFD et de lex_douane, rien ne devient structurellement différent : apparence préservée, planification SRS inchangée, deux managers distincts servis par le même cœur, les deux apps fonctionnelles. Valide FR-S17, FR-S22, FR-S33, FR-S34.
- **SM-S2 — Acyclicité prouvée repo-wide.** Après remontée de `ZStudyFolder` (option A), `melos run analyze` **et** `melos run verify` verts repo-wide + suite E9 sans régression. Valide FR-S1, NFR-S2.
- **SM-S3 — Bug de rebuild reste corrigé (SM-1).** Sur l'éditeur de flashcards, taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus. Valide FR-S22, NFR-S1.

**Secondaires**
- **SM-S4 — Réutilisation, pas reconstruction.** `zcrud_flashcard`/`zcrud_mindmap`/`zcrud_markdown` consommés tels quels ; les écarts comblés dans le package d'origine, pas dupliqués. Valide FR-S25, FR-S26.
- **SM-S5 — Domaine backend-agnostique.** Zéro `Timestamp`/`Box`/`Color`/`IconData` dans un package `zcrud_study*` (scan CI). Valide NFR-S3.
- **SM-S6 — Compat de sérialisation.** 100 % d'un corpus de documents IFFD legacy (camelCase, sans `ZSyncMeta`) se désérialise défensivement (jamais throw). Valide FR-S16, NFR-S4.
- **SM-S7 — Modularité prouvée.** Importer `zcrud_note` (ou `zcrud_flashcard`) seul n'ajoute ni examens, ni communauté, ni Firebase au graphe. Valide NFR-S10.

**Contre-métriques (à ne pas optimiser)**
- **SM-SC1 — Ne pas maximiser le nombre de packages.** Une décomposition trop fine nuit à l'ergonomie d'import ; contrebalance SM-S7. Cible : granularité justifiée par l'isolation (réutilisation indépendante réelle), pas par principe.
- **SM-SC2 — Ne pas embarquer d'app-specific dans le package partagé.** Examens/communauté/podcasts plus matures côté lex ne doivent pas faire entrer du douane déguisé en générique ; contrebalance SM-S1. Cible : tout ce qui diverge fortement passe par un seam optionnel, pas un invariant.

## 9. Questions ouvertes

*Les décisions se prennent en phase Architecture / tête d'epic. Détail dans l'inventaire §8.*

- **OQ-S1** ✅ *Tranché (verrouillé)* : `ZStudyFolder` **option A** (remonté vers `zcrud_study_kernel`), story de tête avec preuve d'acyclicité + non-régression E9 (FR-S1).
- **OQ-S2** ✅ *Tranché (ce PRD)* : open question canonique #3 → **`ZSyncMeta` hors-entité** pour toutes les nouvelles entités study (AD-9/AD-16) ; `ZStudyFolder` aligné/documenté (FR-S3). À confirmer en Architecture.
- **OQ-S3** : **Source SM-2 unique** — laquelle des trois (`Sm2` lex / `Sm` IFFD / `ZSm2Scheduler`) devient canonique ? À trancher par comparaison chiffrée avant merge (FR-S17) ; risque de casser la compat de planification.
- **OQ-S4** : **Forme unique de `ZStudySessionConfig`** — lex en a deux (persistée simple vs value-object riche pour clé Riverpod). Choisir une forme domaine-pur ; l'égalité profonde va au binding (FR-S33).
- **OQ-S5** : **Rich-text du `content` de nœud mindmap** — slot `ZExtension`/`ZCodec` côté app vs texte brut ; divergence produit visible si IFFD migre sans slot (FR-S26).
- **OQ-S6** : **Portée du registre de cascade** — le registre déclaratif de relations parent/enfant (FR-S14) doit couvrir les deux topologies (IFFD flat / lex nested) sans hard-code ; confirmer l'emplacement (`zcrud_study_kernel` vs adapter).

## 10. Index des hypothèses

- §2 / §4.9 (FR-S9, FR-S30) — `[HYPOTHÈSE]` Le besoin IFFD des **examens** est confirmé implicitement par la décision verrouillée « v1 = TOUT » ; l'inventaire (§2/§8) le marquait « à confirmer avant v1 ». Si IFFD n'en a pas l'usage, `zcrud_exam` reste importable indépendamment (NFR-S10) — pas de coût imposé.
- §4.2 (FR-S4..FR-S11) — `[HYPOTHÈSE]` Les entités lex_douane « education » restent la référence canonique malgré leur évolution ; un `formatVersion` (`ZExtension`) absorbe leur évolution sans casser les consommateurs.
- §4.5 (FR-S22) — `[HYPOTHÈSE]` Le layout `folder_study_tools_page.dart` (~1750 lignes) est décomposable en une liste de sections paramétriques sans perdre l'apparence ; à valider par golden/design review à l'implémentation (ES-5).
- §4.10 (FR-S34) — `[HYPOTHÈSE]` La migration de données IFFD (flat→canonique + `ZSyncMeta`) est faisable sans perte sur le corpus réel ; chantier explicite (pas un renommage), à prouver sur données réelles.

---

## Annexe A — Matrice de traçabilité FR → epic (ES-1..ES-11)

*Épics de l'inventaire §9. Une FR peut toucher plusieurs epics quand entité (domaine) et UI/binding sont séparés.*

| FR | Intitulé court | Epic(s) | Réalise UJ | Valide SM |
|---|---|---|---|---|
| FR-S1 | Remontée `ZStudyFolder` (option A) + acyclicité | ES-1 | UJ-S1,UJ-S2 | SM-S2 |
| FR-S2 | Utilitaires purs (`ZColorPalette`/`applyOrder`/`normalizeTagTitle`) | ES-1 | — | SM-S4 |
| FR-S3 | Réconciliation `ZSyncMeta` hors-entité (OQ #3) | ES-1 | — | SM-S6 |
| FR-S4 | `ZStudyDocument` + état de lecture | ES-2 | UJ-S3 | SM-S5,SM-S6 |
| FR-S5 | `ZSmartNote` (content via `ZCodec`) | ES-2 | UJ-S2 | SM-S6 |
| FR-S6 | `ZFlashcardTag`/`ZSuggestedTag` | ES-2 | UJ-S3 | SM-S6 |
| FR-S7 | `ZFolderContentsOrder` | ES-2 | UJ-S3 | SM-S6 |
| FR-S8 | `ZDocumentAnnotation`/`ZAnnotationBounds` | ES-2 | UJ-S3 | SM-S6 |
| FR-S9 | `ZExam`/`ZReminderTime` | ES-2 | UJ-S3 | SM-S6 |
| FR-S10 | `ZStudySessionResult`/`ZDailyStudyTask`+agrégation | ES-2 | UJ-S3 | SM-S6 |
| FR-S11 | `ZStudyPodcast` (content-addressed) | ES-2 | — | SM-S6 |
| FR-S12 | `ZStudyRepository<T>` générique | ES-3 | UJ-S1,UJ-S2 | SM-S5 |
| FR-S13 | `ZOfflineFirstBoxRepository`+`ZFirestorePathResolver` (flat+nested) | ES-3 | UJ-S1,UJ-S2 | SM-S5 |
| FR-S14 | Cascade déclarative bornée ≤450 | ES-3 | UJ-S1 | SM-S5 |
| FR-S15 | `ZSyncOrchestrator` paramétré | ES-3 | UJ-S2 | SM-S5 |
| FR-S16 | Compat sérialisation camelCase↔snake + `ZSyncMeta` additif | ES-3 | UJ-S1 | SM-S6 |
| FR-S17 | Convergence SM-2 source unique | ES-4 | UJ-S2,UJ-S3 | SM-S1 |
| FR-S18 | `ZStudySessionEngine` (cycle SRS pur) | ES-4 | UJ-S3 | SM-S1 |
| FR-S19 | `ZLinearSessionState` (zéro-SM2) | ES-4 | UJ-S3 | SM-S1 |
| FR-S20 | `ZWhiteExamSessionEngine` (examen blanc) | ES-4 | UJ-S3 | SM-S1 |
| FR-S21 | Widgets qualité/progression (thème injecté) | ES-4 | UJ-S3 | SM-S1 |
| FR-S22 | `ZStudyToolsPage` apparence IFFD + rebuilds granulaires | ES-5 | UJ-S3 | SM-S1,SM-S3 |
| FR-S23 | Sections réordonnables + hub + menu d'actions | ES-5 | UJ-S3 | SM-S3 |
| FR-S24 | `ZFeatureAvailability` injectable | ES-5 | UJ-S1 | SM-SC2 |
| FR-S25 | Notes UI via `zcrud_markdown` + migration tables | ES-6 | UJ-S3 | SM-S4 |
| FR-S26 | Intégration mindmap (`zcrud_mindmap`) | ES-7 | UJ-S3 | SM-S4 |
| FR-S27 | UI tags + intégrité référentielle | ES-8 | UJ-S3 | SM-S6 |
| FR-S28 | UI annotations accessible (WCAG) | ES-8 | UJ-S3 | — |
| FR-S29 | Seams IA neutres (génération/explication/résumé/quota) | ES-9 | UJ-S4 | SM-SC2 |
| FR-S30 | Examens & rappels (UI) | ES-9 | UJ-S3 | — |
| FR-S31 | Podcasts (seam de génération) | ES-9 | — | SM-SC2 |
| FR-S32 | Communauté/partage optionnelle + modération | ES-9 | UJ-S4 | SM-SC2 |
| FR-S33 | Binding Riverpod (lex_douane) | ES-10 | UJ-S2 | SM-S1 |
| FR-S34 | Binding GetX + migration IFFD (flat→canonique) | ES-11 | UJ-S1 | SM-S1 |

## Annexe B — Renvois vers la source of truth

- **Modèle canonique** : inventaire §2 (tableau entité→source→décision d'abstraction) + fichiers de référence lex/IFFD/zcrud listés en fin d'inventaire.
- **Ports & data** : inventaire §3 (contrat générique, asymétries listener/merge-key/cascade) + §4 (topologies, compat sérialisation).
- **UI & apparence** : inventaire §5 (surfaces inventoriées, apparence IFFD + thème injecté).
- **Seams & extensibilité** : inventaire §6.
- **Graphe & risques de cycle** : inventaire §7 ; **risques & divergences** : §8.
- **Découpage BMAD ES-1..ES-11** : inventaire §9 (dépend-de, stories candidates, notes).
- **Décisions verrouillées** : inventaire §0 + brief §« Décisions verrouillées ».
