---
title: "Product Brief — zcrud_study (extension éducative)"
status: draft
created: 2026-07-12
updated: 2026-07-12
owner: Zakarius
project: zcrud
phase: "Extension — famille de packages éducatifs"
grounding: docs/study-integration-inventory.md
predecessors:
  - _bmad-output/planning-artifacts/briefs/brief-zcrud-2026-07-09/brief.md
  - _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md
language: fr
---

# Product Brief : zcrud_study (famille de packages éducatifs)

> **Nature de ce document.** Ce brief ouvre une **nouvelle phase** du produit `zcrud`, pas un nouveau produit. Il **étend** — sans le refaire — le socle planifié dans le [brief initial](../brief-zcrud-2026-07-09/brief.md), le [PRD (26 FR)](../../prds/prd-zcrud-2026-07-09/prd.md) et l'[architecture (16 AD non-négociables)](../../architecture/architecture-zcrud-2026-07-09/architecture.md). Sa source de vérité factuelle est [`docs/study-integration-inventory.md`](../../../../docs/study-integration-inventory.md), dont la **Section 0 (décisions verrouillées)** prime et structure ce qui suit.

## Résumé exécutif

Le monorepo `zcrud` a résolu la duplication du **moteur CRUD** partagé entre DODLP, IFFD et DLCFTI. Une deuxième duplication, tout aussi coûteuse, reste ouverte : les **fonctionnalités éducatives**. Le même domaine — dossiers d'étude, flashcards à répétition espacée, cartes mentales, notes riches, documents annotés, sessions de révision, examens, tags, partage communautaire — existe en **deux implémentations divergentes** : IFFD (l'origine historique, et l'apparence UI de référence) et lex_douane (le domaine « education » le plus complet et le plus propre, ~25 entités pures Dart). Chaque évolution doit être re-portée à la main d'une app à l'autre ; les modèles divergent, les bugs se dédoublent, et aucune future app éducative (collège, université, institut, centre de formation) ne peut démarrer sans re-cloner ce socle.

`zcrud_study` extrait ce domaine éducatif en une **famille de packages finement décomposés**, tous bâtis sur `zcrud_core` et sur les packages déjà livrés (`zcrud_flashcard` E9, `zcrud_mindmap` E10, `zcrud_markdown` E6) qu'ils **réutilisent au lieu de reconstruire**. Un nouveau socle bas `zcrud_study_kernel` porte le squelette organisationnel (`ZStudyFolder` et sa hiérarchie), remonté depuis `zcrud_flashcard` ; au-dessus, des packages spécialisés (`zcrud_note`, `zcrud_document`, `zcrud_session`, `zcrud_exam`) portent chacun un pan du domaine ; un package d'orchestration `zcrud_study` compose le tout et reproduit le **layout « study tools » d'IFFD** comme apparence par défaut. La décomposition fine permet à une app d'importer exactement ce qu'elle veut — les flashcards sans les examens, les notes sans le partage communautaire — sans tirer tout le domaine.

Le pari : **à la migration d'IFFD et de lex_douane sur `zcrud_study`, rien ne devient structurellement différent.** L'apparence de référence est préservée, les modèles convergent vers le canonique lex sans casser la planification SRS existante, et les deux apps continuent de fonctionner — l'une sous GetX, l'autre sous Riverpod — via des bindings minces, le cœur n'imposant aucun gestionnaire d'état (AD-2/AD-15). Ce qui change, c'est qu'une correction se fait désormais une fois et profite à tout l'écosystème éducatif.

## Le problème

- **Duplication éducative structurelle.** Le domaine d'étude vit en double : IFFD (`lib/src/domain/models/` + `lib/data_crud/`) et lex_douane (`packages/lex_core/lib/domain/entities/education/`). Les deux couvrent le même terrain — flashcards, dossiers, mindmaps, notes, documents, examens — mais divergent en granularité, en nommage et en topologie de persistance. Toute nouvelle fonctionnalité éducative est écrite deux fois.
- **Deux niveaux de maturité inconciliables sans travail.** lex_douane est le modèle canonique cible : entités pures Dart, `@JsonSerializable(fieldRename: snake)`, enums camelCase, désérialisation défensive systématique, séparation stricte état-personnel / contenu-partageable, domaine déjà backend-agnostique. IFFD est l'origine et l'**apparence de référence**, mais son domaine **fuit le backend** (`cloud_firestore.Timestamp`, `Color`/`IconData`, `flutter_flow_chart.Dashboard` dans les modèles), sa sérialisation est quasi-réflexive, et son état mêle GetX legacy, Riverpod partiel, `ChangeNotifier` maison et `setState` global.
- **Le bug produit n°1, encore vivant.** `multi_flashcard_editor_page.dart` (IFFD) déclenche `setState()` à l'échelle de la page (×18) sur un moteur de formulaire legacy — l'incarnation exacte du rafraîchissement global que `zcrud` existe pour corriger. Il reste à ce jour non réglé dans l'app éducative.
- **Aucun point de départ pour les futures apps.** Un collège, une université ou un centre de formation qui voudrait une app éducative devrait re-cloner ce socle dupliqué — reproduisant précisément la dette que le monorepo a été conçu pour éliminer.
- **Fonctionnalités entières manquantes du socle zcrud actuel.** `ZStudyDocument` (PDF + annotations + état de lecture), `ZSmartNote`, examens et rappels, tags first-class (`ZFlashcardTag` — aujourd'hui de simples `List<String>` nues), ordre de contenu, podcasts, et **toute la logique de communauté/partage active** (le bloc de partage de `ZStudyFolder` est déclaré mais inerte) n'existent nulle part sous forme réutilisable.

## La solution

Une **famille de packages** dérivée de la décomposition fine verrouillée (Section 0 de l'inventaire), acyclique par construction (AD-1) :

```
zcrud_core
   ▲
zcrud_study_kernel   (NOUVEAU) — squelette d'étude : ZStudyFolder + hiérarchie/validatePlacement
   ▲                              + ZFolderContentsOrder + ZStudySessionConfig
   ├── zcrud_flashcard  (REFACTOR — dépend du kernel, ne porte plus ZStudyFolder)
   ├── zcrud_mindmap    (dépend du kernel via folderId)
   ├── zcrud_markdown   (inchangé)
   ├── zcrud_note       (NOUVEAU) — ZSmartNote + annotations (kernel + markdown)
   ├── zcrud_document   (NOUVEAU) — ZStudyDocument + état lecture + annotations (kernel)
   ├── zcrud_session    (NOUVEAU) — moteurs de session purs SRS/cramming/liste (kernel + flashcard)
   └── zcrud_exam       (NOUVEAU) — ZExam + rappels + examen blanc (kernel)
        ▲
   zcrud_study          (NOUVEAU, orchestration) — ZStudyToolsPage (apparence IFFD),
                         agrégation quotidienne, seams communauté/partage/podcasts/IA
        ▲
   zcrud_riverpod (lex) · zcrud_get (IFFD/DODLP)   — bindings
```

Chaque package suit les invariants du monorepo : domaine pur généré par codegen zcrud (`@ZcrudModel`, jamais `reflectable`/`freezed`/`Timestamp`), ports retournant `Either<ZFailure, T>` et flux `Stream<List<T>>` nus, métadonnées de sync hors-entité (`ZSyncMeta`), offline-first Last-Write-Wins, réactivité `ChangeNotifier`/`ValueListenable`, thème et l10n injectés.

Ce que la solution **réutilise sans reconstruire** (déjà livré et conforme AD) : `ZFlashcard` + SRS pluggable (`ZSrsScheduler`/`ZSm2Scheduler`), `ZMindmap` + `ZMindmapTreeOps` + `ZMindmapView`, `ZMarkdownField`/`ZCodec`. Ce qu'elle **ajoute** : les entités manquantes (`ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZFlashcardTag`, `ZDocumentAnnotation`, `ZDocumentReadingState`, `ZFolderContentsOrder`, `ZStudyPodcast`, `ZStudyMembership`/`ZShareLink`/`ZPublicStudyFolder`), les **runtimes de session** purs (cycle SRS, cramming, liste, examen blanc — extraits en state machines sans gestionnaire d'état), et le **layout « study tools »** unifié à l'apparence IFFD.

## Ce qui le distingue

- **Décomposition fine réutilisable indépendamment.** Contrairement à un `zcrud_study` monolithique, chaque capacité est un package importable seul. Une app veut les flashcards et les notes mais ni les examens ni la communauté : elle importe `zcrud_flashcard` + `zcrud_note` et rien d'autre. La modularité melos du socle initial est portée jusqu'au domaine éducatif.
- **Apparence IFFD par défaut, thème injecté.** `ZStudyToolsPage` reproduit le layout de référence (`folder_study_tools_page.dart` — rail flashcards, sections réordonnables docs/notes/mindmaps, états vides par section) pour que la migration ne dépayse pas les utilisateurs IFFD — mais couleurs, labels et l10n sont **injectés** (`ZcrudScope`/`ThemeExtension`, l10n `zcrud_core`), jamais codés en dur. Une nouvelle app éducative repart de cette apparence et la re-thème sans forker.
- **Réactivité Flutter-native, agnostique du gestionnaire d'état.** Les moteurs de session sont des classes pures (`ChangeNotifier`/reducer) ; le code spécifique à Riverpod (familles, égalité de `ZStudySessionConfig`) ou à GetX vit **uniquement** dans son binding. IFFD (GetX) et lex_douane (Riverpod) consomment le même cœur — et le bug de rebuild global disparaît par construction (SM-1).
- **Canonique lex, sans casser l'existant.** Les modèles convergent vers les entités lex_douane (les plus propres), mais la convergence SRS (trois implémentations SM-2 : `Sm2` lex, `Sm` IFFD, `ZSm2Scheduler` existant) est traitée comme un risque explicite — comparaison précise avant merge, pas de régression de planification silencieuse.
- **Seams neutres pour tout ce qui est app-specific.** Génération IA (flashcards, résumés, explications, podcasts), backend de partage/modération, upload de documents, quota IA, disponibilité progressive des éditeurs — chacun derrière un port neutre (`Either<ZFailure, T>`), jamais dans le cœur. IFFD et lex_douane branchent leurs routeurs et prompts propres sans modifier `zcrud_study`.

## Qui cela sert

- **IFFD — origine et apparence de référence.** Sa page « study tools » définit le layout par défaut. La migration remplace son `data_crud` legacy et son god-controller GetX, corrige les fuites backend de son domaine, et règle le bug de rebuild de son éditeur de flashcards. Nécessite une **migration de données lourde** (structure de collections plate → canonique), traitée comme un chantier explicite, pas un renommage.
- **lex_douane — domaine canonique et second consommateur.** Fournit les ~25 entités de référence. La migration est additive et progressive : les providers Riverpod de `zcrud_riverpod` remplacent peu à peu les repos lex, sans big-bang. Succès = aucune régression fonctionnelle, le module « education » continuant de tourner sur le socle partagé.
- **Futures apps éducatives (collèges, universités, instituts, centres de formation).** Les vrais bénéficiaires de long terme : elles démarrent en important les packages voulus, héritent de l'apparence IFFD, du SRS éprouvé, des mindmaps et du markdown riche — et étendent modèles et types via les mécanismes d'extensibilité (`ZExtension`, `extra`, registres `ZTypeRegistry`/`ZSourceRegistry`) sans forker le socle.

## Critères de succès

- **Invariant de migration (n°1).** À la bascule d'IFFD et de lex_douane, **rien ne devient structurellement différent** : apparence préservée, planification SRS inchangée, deux gestionnaires d'état distincts servis par le même cœur, les deux apps fonctionnelles après migration.
- **Acyclicité prouvée repo-wide.** Après la remontée de `ZStudyFolder` vers `zcrud_study_kernel` (option A), `melos run analyze` **et** `melos run verify` sont verts **repo-wide**, et la suite de tests E9 (`zcrud_flashcard`) passe sans régression.
- **Réutilisation, pas reconstruction.** `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_markdown` sont consommés tels quels ; les écarts (ex. édition outline interactive de mindmap, migration des tables markdown) sont comblés **dans le package d'origine**, pas dupliqués dans `zcrud_study`.
- **Le bug de rebuild reste corrigé.** Sur l'éditeur de flashcards (cas de non-régression tiré de `multi_flashcard_editor_page.dart`), taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus (SM-1).
- **Domaine backend-agnostique.** Aucun `Timestamp`/`Filter`/`Box`/`Color`/`IconData` dans un package `zcrud_study*` ; toute persistance passe par les ports neutres et les adapters `zcrud_firestore`.
- **Compat de sérialisation.** Les gates CI de rétro-compatibilité passent : les documents IFFD legacy (camelCase, sans `ZSyncMeta`) se désérialisent défensivement (champ absent/corrompu → défaut sûr, jamais throw) via le codec de `zcrud_firestore`.
- **Modularité prouvée.** Une app importe `zcrud_note` (ou `zcrud_flashcard`) seul sans tirer les examens ni la communauté ni Firebase.

## Périmètre

**Dans la v1 — TOUT (décision verrouillée) :**

- **Squelette d'étude** — `zcrud_study_kernel` : `ZStudyFolder` remonté depuis `zcrud_flashcard` (option A), hiérarchie 2 niveaux (`validatePlacement`), `ZFolderContentsOrder`, `ZStudySessionConfig` ; refactor de `zcrud_flashcard` pour en dépendre.
- **Domaine canonique** — `ZStudyDocument` + `ZDocumentReadingState`/`ZDocumentLearningInfo`, `ZSmartNote` (contenu typé via `ZCodec`), `ZFlashcardTag` + `ZSuggestedTag`, `ZDocumentAnnotation`/`ZAnnotationBounds`, `ZExam` + `ZReminderTime`, `ZStudySessionResult`, `ZDailyStudyTask` + agrégation.
- **Ports & data offline-first** — `ZStudyRepository<T>` générique, `ZOfflineFirstBoxRepository<T>` + `ZFirestorePathResolver` (adapters plat IFFD **et** imbriqué lex), cascade déclarative batchée (≤ 450 writes), `ZSyncOrchestrator` paramétré par liste injectée.
- **SRS & runtimes de session** — convergence SM-2 vers une source unique, `ZStudySessionEngine` (cycle SRS), `ZLinearSessionState` (cramming/liste, zéro-SM2 par construction), `ZWhiteExamSessionEngine` (examen blanc), widgets qualité/progression (thème injecté).
- **Dossiers & organisation** — `ZStudyToolsPage` (apparence IFFD, scoping `ValueListenable` isolé par section), sections réordonnables, hub d'ajout, menu d'actions, `ZFeatureAvailability` injectable.
- **Notes, mindmap, tags, annotations** — via `zcrud_markdown`/`zcrud_mindmap` réutilisés ; tags et annotations avec palette injectable et a11y (WCAG, couleur jamais seul canal d'info).
- **Examens & rappels** — `ZExam` + rappels datés (`ZReminderTime`), examen blanc.
- **Communauté / partage** — `ZStudyMembership`/`ZShareLink`/`ZPublicStudyFolder` + modération, comme **extension optionnelle activable** (`ZExtension` sur `ZStudyFolder` + `ZStudySharingPort`/`ZStudyModerationPort`), pas un invariant du domaine.
- **Podcasts** — `ZStudyPodcast` (content-addressed) + `ZPodcastGenerationPort`.
- **Seams IA** — `ZFlashcardGenerationPort`, `ZAiExplanationPort`, `ZNoteSummaryPort`, `ZEducationQuotaInfo` (fail-open) — ports neutres, routeurs/prompts app-specific hors cœur.
- **Bindings** — `zcrud_riverpod` (lex_douane) puis `zcrud_get` (IFFD), et migration des données IFFD.

**Explicitement hors périmètre :**

- Les **routeurs IA, prompts, backends de partage et pipelines d'upload concrets** — restent dans les apps, derrière les seams.
- Le mode **flowchart legacy** des mindmaps (`flutter_flow_chart`, obsolète) et `graphview` — `graphite` reste le standard de `zcrud_mindmap`.
- Les entités **spécifiques métier douane** (ex. `ComparativeStudy`) — non portées, hors périmètre éducatif générique.
- Le **format wire chat** (`toChatJson`/`fromChatJson`) et les **seeds de flashcards par référentiel** (SH/tarif IFFD) — app-specific, jamais dans le domaine.

## Risques

- **Refactor `ZStudyFolder` (E9).** Remonter `ZStudyFolder` de `zcrud_flashcard` vers `zcrud_study_kernel` touche un package déjà livré et testé. Mitigation : **story de tête d'epic** dédiée, preuve d'acyclicité repo-wide (`melos analyze` + `verify`), non-régression complète des tests E9 avant tout `done`.
- **Réconciliation de l'open question #3.** `ZMindmap` porte ses métadonnées de sync **hors-entité** (AD-16), alors que `ZStudyFolder` les porte **dans** l'entité — divergence à trancher avant de figer `ZStudyDocument`/`ZSmartNote`/`ZExam`, sous peine d'incohérence structurelle du canonique.
- **Convergence SM-2.** Trois implémentations (`Sm2` lex, `Sm` IFFD, `ZSm2Scheduler` existant) aux paramètres subtils (plafond EF 2.5, bonus overdue, paliers 1j/6j, échelle qualité 0-5 vs 1-5). Un merge naïf **casse la compatibilité de planification** des utilisateurs existants. Mitigation : comparaison précise documentée, source unique choisie explicitement, tests de planification.
- **Divergences GetX ↔ Riverpod.** IFFD mêle GetX legacy, Riverpod partiel et `setState` global (parfois dans le même widget) ; lex est Riverpod exclusif. Toute UI portée doit être **ré-écrite en `ChangeNotifier`/`ValueListenable` pur** avant tout binding — le code manager-spécifique ne doit jamais fuiter dans `zcrud_study*`.
- **Fuites backend IFFD.** `Timestamp`/`Color`/`IconData`/`Dashboard` dans le domaine IFFD, CRUD quasi-réflexif (collection = nom de classe, proche de ce qu'AD-3 bannit). Chaque portage exige un adapter de désérialisation dédié et une résolution de collection **statique explicite**, pas un renommage.
- **Migration des données IFFD (flat → canonique).** IFFD stocke en collections top-level plates nommées d'après la classe Dart ; lex en sous-collections imbriquées sous le dossier. La bascule IFFD est une **restructuration de données lourde**, avec ajout rétro-compatible obligatoire de `ZSyncMeta` (absent des deux sources).
- **Gonflement du périmètre partagé.** Examens, communauté et podcasts sont plus matures côté lex que côté IFFD. Risque d'embarquer dans le package partagé du app-specific déguisé en générique. Mitigation : tout ce qui diverge fortement passe par un **seam optionnel activable**, pas par un invariant.
- **Dette de sécurité héritée du partage lex.** La logique de partage lex porte une limite LWW documentée et une faille connue (un contributeur peut modifier des champs de contrôle). À **corriger ou documenter explicitement** au portage, jamais hériter silencieusement.
- **Régression cross-package invisible.** Comme la remontée de `ZStudyFolder` et la suppression de symboles publics traversent plusieurs packages, une vérif par-package ne suffit pas (cf. régression `ZExportApi` E11a-3). Mitigation : à chaque gate de commit d'epic, `melos run analyze` **ET** `melos run verify` **repo-wide**.

## Séquencement (rappel)

Le découpage BMAD détaillé (11 epics ES-1..ES-11, du kernel jusqu'aux bindings) est porté par [l'inventaire d'intégration, §9](../../../../docs/study-integration-inventory.md). Tête de file **non-négociable** : la story de remontée de `ZStudyFolder` (option A) avec preuve d'acyclicité et non-régression E9. Séquentiel par défaut sur le domaine (`zcrud_study` est le seul point de contact) ; parallélisation seulement à fichiers disjoints (3 max).

## Vision

À terme, `zcrud_study` est **la fondation éducative commune** de l'écosystème : n'importe quelle app d'apprentissage — douane, mais aussi collège, université, institut, centre de formation — démarre en important les packages voulus et obtient dossiers, flashcards à répétition espacée, cartes mentales, notes riches, documents annotés, examens, tags et partage, sur n'importe quel backend, avec l'apparence de référence prête à re-thémer. Une correction se fait une fois et profite à toutes les apps. La duplication éducative entre IFFD et lex_douane — comme celle du moteur CRUD avant elle — cesse d'exister.

---

## Décisions verrouillées (Zakarius, 2026-07-12)

_Reprises de la Section 0 de [`docs/study-integration-inventory.md`](../../../../docs/study-integration-inventory.md) ; elles priment sur les recommandations « option B / v1.x » de la synthèse d'inventaire et gouvernent ce brief._

1. **Décomposition FINE multi-packages** (kernel bas-niveau + note/document/session/exam + orchestration) plutôt qu'un `zcrud_study` monolithique.
2. **`ZStudyFolder` — OPTION A** : remonté de `zcrud_flashcard` vers `zcrud_study_kernel` ; `zcrud_flashcard` (E9) refactoré pour en dépendre ; story de tête avec preuve d'acyclicité repo-wide et non-régression E9.
3. **Périmètre v1 = TOUT** : examens + rappels, communauté / partage + modération, podcasts et seams IA inclus dès la v1 (rien différé en v1.x) ; logique app-specific derrière des seams neutres.
4. **Apparence par défaut = IFFD** (`folder_study_tools_page.dart`), thème injecté (`ZcrudScope`/`ThemeExtension`), l10n de `zcrud_core`, réactivité Flutter-native (AD-2/AD-15), aucun gestionnaire d'état imposé.

## Contraintes gouvernantes

Les **16 décisions d'architecture (AD-1..AD-16)** de l'[architecture zcrud](../../architecture/architecture-zcrud-2026-07-09/architecture.md) sont **non-négociables** et s'appliquent intégralement à chaque package et chaque story : direction de dépendance acyclique (AD-1), réactivité Flutter-native sans gestionnaire d'état dans le cœur (AD-2/AD-15), codegen sans `reflectable` ni `freezed` imposé (AD-3), extensibilité par `ZExtension`/`extra`/registres (AD-4), erreurs `Either<ZFailure, T>` et domaine backend-agnostique (AD-5/AD-11/AD-16), rich-text `ZCodec` et liste `ZListRenderer` (AD-7/AD-8), offline-first LWW + `ZSyncMeta` hors-entité (AD-9), désérialisation défensive additive (AD-10), a11y et RTL directionnels (AD-13).
