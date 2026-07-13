# Inventaire d'intégration `zcrud_study`

> Point de départ du brief BMAD — extraction d'un package partagé abstrayant les fonctionnalités éducatives communes à **IFFD** (origine, UI de référence) et **lex_douane** (domaine « education » le plus complet), consommable par de futures apps éducatives (collèges, universités, instituts).
> Contraintes gouvernantes : AD-1..AD-16 (NON-NÉGOCIABLES). Communication en français.

---

## 0. Décisions verrouillées (Zakarius, 2026-07-12)

Ces décisions priment sur les recommandations « option B / v1.x » de la synthèse ci-dessous et gouvernent le brief BMAD.

1. **Décomposition FINE en sous-packages** (au lieu d'un seul `zcrud_study` monolithique) :

   ```
   zcrud_core
      ▲
   zcrud_study_kernel   (NOUVEAU, bas-niveau) — squelette d'étude
      ▲
      ├── zcrud_flashcard  (REFACTOR : dépend du kernel, ne porte plus ZStudyFolder)
      ├── zcrud_mindmap    (dépend du kernel via folderId)
      ├── zcrud_markdown   (inchangé)
      ├── zcrud_note       (NOUVEAU) — ZSmartNote + annotations (dépend kernel + markdown)
      ├── zcrud_document   (NOUVEAU) — ZStudyDocument + état lecture + annotations doc (dépend kernel)
      ├── zcrud_session    (NOUVEAU) — moteurs de session purs SRS/cramming/liste (dépend kernel + flashcard)
      └── zcrud_exam       (NOUVEAU) — ZExam + rappels + examen blanc (dépend kernel)
           ▲
      zcrud_study          (NOUVEAU, orchestration) — ZStudyToolsPage (apparence IFFD),
                            agrégation quotidienne, seams communauté/partage/podcasts/IA
           ▲
      zcrud_riverpod (lex) · zcrud_get (IFFD/DODLP)  — bindings
   ```

2. **`ZStudyFolder` — OPTION A retenue** : le squelette organisationnel (`ZStudyFolder` + hiérarchie/`validatePlacement` + `ZFolderContentsOrder` + `ZStudySessionConfig`) est **remonté de `zcrud_flashcard` vers `zcrud_study_kernel`**. `zcrud_flashcard` (E9) est **refactoré** pour en dépendre. Impose une story de tête d'epic « migration ZStudyFolder » avec preuve d'acyclicité repo-wide et non-régression des tests E9.

3. **Périmètre v1 = TOUT** : examens (`ZExam` + rappels + examen blanc), communauté/partage (`ZStudyMembership`/`ZShareLink`/`ZPublicStudyFolder` + modération), podcasts (`ZStudyPodcast`) et seams IA sont **inclus dès la v1** (pas différés en v1.x). La logique app-specific (routeurs IA, backend de partage) reste derrière des seams neutres.

4. **Apparence par défaut = IFFD** (`folder_study_tools_page.dart`), thème injecté (`ZcrudScope`/`ThemeExtension`), l10n de `zcrud_core`, réactivité Flutter-native (AD-2/AD-15), aucun gestionnaire d'état imposé.

5. **Politique de modèle d'implémentation = TOUT-OPUS pour le cycle BMAD** (Zakarius, 2026-07-12 — **révision après retour d'expérience ES-1.2**) :
   - **`create-story`, `dev-story`, `code-review`, `retrospective` → modèle HÉRITÉ (Opus)**, paramètre `model` **OMIS** sur les `agent()` BMAD. Effort par étape inchangé (CLAUDE.md) : dev-story **high**, code-review **high**, create-story **medium** (**high** si story complexe), retrospective **medium**.
   - **Sonnet réservé au HORS-BMAD read-only** : exploration/reconnaissance (ex. les 12 agents de cartographie IFFD/lex_douane), recherches massives. Aucun code écrit ⇒ aucun risque de dégradation. C'est déjà la règle CLAUDE.md.
   - **Orchestration + vérifs vertes + gates repo-wide → Opus** (l'orchestrateur), toujours.

   **Pourquoi le TIERED (Sonnet pour le « portage mécanique ») a été ABANDONNÉ — preuve empirique ES-1.2 :**
   - Bilan réel : `dev-story` Sonnet → code-review → **une passe de remédiation Opus complète** (4 MEDIUM). Soit **deux passes de dev au lieu d'une** ⇒ le tiered a coûté **plus** cher (tokens **et** temps), pas moins.
   - Cause racine : **Sonnet suit la spec fidèlement, failles comprises.** Les findings M2/M3/M4 venaient du fait que **la story elle-même** prescrivait une signature de seam défectueuse (`typedef ZColorKeyResolver = Color? Function(String)` — qui ne compose pas, zéro appelant). Sonnet l'a implémentée telle quelle ; un dev Opus aurait remis la spec en cause. Idem M1 (vecteurs golden spécifiés sans exécution web ⇒ filet aveugle à la régression qu'il devait attraper).
   - Le « portage mécanique » est **largement illusoire dans ce dépôt** : la *fonctionnalité* existe ailleurs (IFFD/lex_douane), mais la **traduction architecturale est de la conception neuve à chaque story** (retirer les fuites backend, rendre défensif AD-10, préserver l'acyclicité AD-1, zéro couleur en dur FR-26, rebuilds granulaires SM-1…). Presque **chaque story crée de la nouvelle API publique** dans un package partagé sous 28 invariants ⇒ presque aucune ne qualifie pour Sonnet sous une règle honnête.
   - Coût caché : le **tri** lui-même. Se tromper **une seule fois** de classification = une remédiation complète. La règle simple (tout-Opus) supprime ce risque.

---

## 1. Synthèse exécutive

### État des trois sources

| Source | Rôle | Maturité domaine | State manager | Fuites backend dans le domaine |
|---|---|---|---|---|
| **lex_douane** (`packages/lex_core/lib/domain/entities/education/`) | Modèle canonique cible (~25 entités pures Dart) | La plus complète et la plus propre : `@JsonSerializable(fieldRename: snake)`, enums camelCase, désérialisation défensive systématique (`unknownEnumValue`/`defaultValue`/`fromJsonSafe`), séparation stricte état-personnel/contenu-partageable | Riverpod (couche presentation/data, **hors** entités) | **Aucune** dans les entités — domaine backend-agnostique déjà respecté. `Timestamp` confiné à `lex_data` |
| **IFFD** (`lib/src/domain/models/` + `lib/data_crud/`) | Origine historique + **apparence UI de référence** (dossiers, page « study tools ») | Modèles couplés à `cloud_firestore.Timestamp` et `flutter/material` (Color/IconData) dans le domaine ; sérialisation manuelle quasi-réflexive | GetX (legacy) → Riverpod (migration avancée, incomplète) + `ChangeNotifier` maison + `setState` global | **Fortes** : `Timestamp`, `Color`, `IconData`, `flutter_flow_chart.Dashboard` dans les modèles domaine |
| **zcrud** (monorepo courant, E9/E10/E6 livrés) | Socle déjà construit | `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_markdown` livrés et conformes AD | ChangeNotifier/ValueListenable pur (AD-2/AD-15) | Aucune (isolation stricte respectée) |

### Ce que zcrud possède **déjà** (à ne PAS reconstruire)

- **`zcrud_flashcard`** (E9) : `ZFlashcard` (6 types, QCM `ZChoice`, provenance `ZFlashcardSource` via registre), SRS pluggable complet (`ZSrsScheduler`/`ZSm2Scheduler`, `ZRepetitionInfo` état séparé, config `ZSrsConfig`), **`ZStudyFolder` générique multi-type** (hiérarchie 2 niveaux via `validatePlacement`, soft-archive, partage V2c **inerte**), sessions (`ZStudySessionConfig`/`ZStudySessionSelector`), dépôt offline-first `ZFlashcardRepository` + `ZRepetitionStore`.
- **`zcrud_mindmap`** (E10) : `ZMindmap`/`ZMindmapNode` (forêt par nesting, immuable, AD-16 sync hors-entité), `ZMindmapTreeOps` (add/update/delete/find/move/indent/outdent/reorder, structural sharing), `ZMindmapView` (graphite, lecture seule + liste a11y), `ZMindmapOutlineController` (ChangeNotifier, corrige le bug de sauvegarde lex historique).
- **`zcrud_markdown`** (E6) : `ZCodec` pluggable (Delta↔Markdown/HTML), `ZMarkdownField` (Quill isolé, valeur neutre Delta JSON), embeds LaTeX/table/média internes, `ZMarkdownReader`, dialog plein écran. **Couvre déjà la quasi-totalité du pipeline rich-text d'IFFD** (`data_crud/rich_text_editor/**` + `embeds/**`) de façon plus robuste (ops Delta neutres vs placeholders regex fragiles).

### Ce qui manque **entièrement**

`ZStudyDocument` (PDF), `ZSmartNote`, examens (`ZExam` + rappels), `ZFlashcardTag` (entité tag first-class — aujourd'hui `ZFlashcard.tagIds` = `List<String>` nu), annotations de documents (`ZDocumentAnnotation`), état de lecture (`ZDocumentReadingState`), ordre de contenu (`ZFolderContentsOrder`), podcasts, **toute la logique de communauté/partage active** (le bloc V2c de `ZStudyFolder` est déclaré mais inerte), les **runtimes de session** (cramming/liste/examen blanc), et le **layout « study tools »** de référence IFFD.

### Verdict : **nouveau package `zcrud_study` — package d'orchestration transverse**, PAS un simple enrichissement

**Recommandation :** créer `zcrud_study` comme **package d'orchestration** qui :
1. **Dépend de** `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_markdown`, `zcrud_core` (jamais l'inverse — AD-1 acyclique).
2. **Porte les entités manquantes** (`ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZFlashcardTag`, `ZDocumentAnnotation`, `ZDocumentReadingState`, `ZFolderContentsOrder`, podcasts, membership/community).
3. **Compose** les sessions transverses (vue quotidienne agrégée, runtimes SRS/cramming/liste/examen blanc) et le **layout « study tools »** unifié (apparence IFFD par défaut).

**Justification (la décision architecturale centrale) :** `ZStudyFolder` — explicitement générique multi-type (cartes/notes/mindmaps/documents par rattachement inverse) — **vit aujourd'hui dans `zcrud_flashcard`**. C'est le point de tension majeur du graphe. Trois options :

- **(A)** Faire remonter `ZStudyFolder` + `validatePlacement` + `ZStudySessionConfig`/`Selector` de `zcrud_flashcard` vers un socle plus bas (`zcrud_core` ou un nouveau `zcrud_study_kernel`) dont dépendraient `zcrud_flashcard`, `zcrud_mindmap` ET `zcrud_study`.
- **(B)** Laisser `ZStudyFolder` dans `zcrud_flashcard` et faire de `zcrud_study` un pur orchestrateur qui **réutilise** `zcrud_flashcard.ZStudyFolder` sans le dupliquer.
- **(C)** Dupliquer le concept dans `zcrud_study` — **rejeté** : recrée exactement le problème historique (duplication à l'identique dans 3 apps) que le monorepo résout.

**→ Recommandation : option (B) pour la v1** (pragmatique, zéro refactor risqué de `zcrud_flashcard` déjà livré/testé), avec une **story de tête d'epic** qui documente ce choix et vérifie l'acyclicité. Bascule vers (A) réservée à une v1.x **seulement si** un besoin réel apparaît de rendre `ZStudyFolder` accessible sans tirer tout `zcrud_flashcard`. Cette décision doit être **tranchée explicitement dans l'architecture** (open question canonique #3, non résolue à ce jour : `ZMindmap` porte `updatedAt`/`is_deleted` hors-entité AD-16, alors que `ZStudyFolder` les porte **dans** l'entité — divergence à réconcilier avant de figer `ZStudyDocument`/`ZSmartNote`/`ZExam`).

---

## 2. Modèle de domaine canonique cible

Convention : préfixe `Z`, `@ZcrudModel`/`@ZcrudField` (codegen zcrud, AD-3 — jamais `Timestamp`/`freezed`/`reflectable`), persistance snake_case, enums camelCase, désérialisation défensive (AD-10), sync hors-entité `ZSyncMeta` (AD-9/AD-16).

| Entité cible | Source de référence | Champs clés | Type Z proposé | Décision d'abstraction |
|---|---|---|---|---|
| **Dossier d'étude** | lex `study_folder.dart` + iffd `folder_model.dart` | id, title, colorKey, parentId?, ownerId, archivedAt?, createdAt, updatedAt | **`ZStudyFolder`** (existe déjà, `zcrud_flashcard`) | **RÉUTILISER l'existant**. Champs de partage (isPublic/sharedWith/viewers/shareId/countryCode/canBeJoinedWithLink/coWorkersCanInviteOthers) → **slot `ZExtension?`** (AD-4), pas champs de base (IFFD/lex divergent en granularité). Invariant 2 niveaux via `validatePlacement` hors-entité |
| **Document PDF** | lex `study_document.dart` | id(=documentId), folderId, fileName, status(`DocumentStatus`), storagePath, pageCount?, sizeBytes, createdAt, updatedAt | **`ZStudyDocument`** | **NOUVEAU** — nouveau périmètre. Confirmer besoin IFFD (`FolderDocument`) |
| **Flashcard** | lex `flashcard.dart` + iffd `flashcard_model.dart` | id?, folderId?, subFolderId?, type, question, answer?, isTrue?, choices?, explanation?, hint?, tagIds[], source?, isReadOnly | **`ZFlashcard`** (existe, `zcrud_flashcard`) | **RÉUTILISER**. État éphémère (id==null) déjà supporté. Format wire chat (`toChatJson`/`fromChatJson`) = **seam app-specific**, jamais dans le cœur |
| **État SRS** | lex `repetition_info.dart` + iffd `flashcard_repetition_info.dart` | flashcardId, folderId, interval, repetitions, easeFactor, nextReviewDate?, learnedAt?, lastQuality? | **`ZRepetitionInfo`** (existe) | **RÉUTILISER**. Séparé de la carte (jamais emporté par le partage). Vérifier alignement échelle qualité (lex 0-5 vs iffd `FlashcardRepetitionQuality` 1-5) |
| **Tag de flashcard** | lex `flashcard_tag.dart` + iffd `flashcard_tag_model.dart` | id, title, colorKey (borné + remap SHA-256) | **`ZFlashcardTag`** | **NOUVEAU** (aujourd'hui `tagIds` = `List<String>` nu). Logique `remapColorKey` = domaine pur. Palette **injectée** (pas verrouillée à 8 clés lex) |
| **Carte mentale** | lex `mindmap.dart` + iffd `mindmap_model.dart` | id, folderId, title, nodes[] | **`ZMindmap`/`ZMindmapNode`** (existe, `zcrud_mindmap`) | **RÉUTILISER**. Divergence : `content` texte brut (zcrud) vs Markdown/LaTeX inline (IFFD) → rich-text via `ZExtension` ou `ZCodec` côté app hôte |
| **Note intelligente** | lex `smart_note.dart` + iffd `smart_note_model.dart` | id, folderId, subFolderId?, title, content(markdown), audioUrl?, audioPath?, audioTextHash? | **`ZSmartNote`** | **NOUVEAU**. `content` **typé via `ZCodec`** (Delta JSON), jamais `String?` ambiguë. Champs audio → `ZExtension`/`extra` |
| **Config de session** | lex `study_session_config.dart` (v2) + `study_session.dart` (v1) | mode, folderId?, subFolderId?, tagIds:Set, cardTypes:Set, count? | **`ZStudySessionConfig`** (existe) | **RÉUTILISER**. **Trancher** : lex a DEUX versions (persistée simple vs value-object riche pour clé Riverpod). L'égalité profonde pour family Riverpod → **binding `zcrud_riverpod`**, pas le cœur |
| **Résultat de session** | lex `study_session.dart` | mode, total, correct, byQuality{} | **`ZStudySessionResult`** | **NOUVEAU** (value-object) |
| **Tâche quotidienne** | lex `daily_study_task.dart` (sealed) | DueCardsTask.count ; ExamTask.exam,daysUntil | **`ZDailyStudyTask`** + `aggregateDailyStudyTasks` (fonction pure) | **NOUVEAU**. Sealed → généraliser via registre si extensible (AD-4) |
| **Examen** | lex `exam.dart` + iffd `exam_model.dart` | id, folderId, title, date, reminderEnabled, reminderDaysBefore[], reminderTime(`ReminderTime`), updatedAt | **`ZExam`** + `ZReminderTime` (value-object + JsonConverter `HH:mm`) | **NOUVEAU**. Méthodes pures `daysUntil`/`isPast`/`isApproaching(now injecté)`. ⚠️ Confirmer besoin IFFD avant d'inclure en v1 (risque de gonfler le périmètre) |
| **État de lecture doc** | lex `document_reading_state.dart` | docId, currentPage, pageCount?, prefs(`DocumentViewerPrefs`), learning(`DocumentLearningInfo`), updatedAt | **`ZDocumentReadingState`** | **NOUVEAU**. État **personnel** (hors sous-arbre partageable). Désérialisation défensive imbriquée |
| **Apprentissage par page** | lex `document_learning_info.dart` | qualityByPage: Map<int,int> | **`ZDocumentLearningInfo`** | **NOUVEAU**. Colocalisé dans `ZDocumentReadingState` |
| **Annotation de doc** | lex `document_annotation.dart` | id, docId, page, kind(highlight/stickyNote), colorKey, bounds([0,1]), rects?[], text? | **`ZDocumentAnnotation`** + `ZAnnotationBounds` | **NOUVEAU**. Contenu **partageable**. ⚠️ Extraire `isDeleted` inline → `ZSyncMeta` hors-entité (AD-9) |
| **Ordre de contenu** | lex `folder_contents_order.dart` + iffd `FolderContentsOrders` | folderId, orders: Map<sectionKey,List<id>> | **`ZFolderContentsOrder`** + `applyOrder<T>` (pur générique) | **NOUVEAU**. État **personnel**. `applyOrder<T>` candidat extraction `zcrud_core` |
| **Podcast** | lex `study_podcast.dart` | id({sourceId}_{mode}), sourceKind, sourceId, folderId, mode, sourceHash, resultRef, status | **`ZStudyPodcast`** | **NOUVEAU** (v1.x). Pattern content-addressed (cache/invalidation par hash) généralisable |
| **Membership / partage** | lex `study_membership.dart`, `share_link.dart` | ownerUid, folderId, joinedAt ; shareId, ownerUid, folderId, revoked | **`ZStudyMembership`**, **`ZShareLink`** | **NOUVEAU** (v1.x). LWW par document, limite documentée (révocation à la prochaine sync) |
| **Galerie communautaire** | lex `public_study_folder.dart`, `study_folder_report.dart` | folderId, ownerUid, ownerDisplayName, title, counts, hiddenByAdmin ; targetFolderId, reporterUid, reason? | **`ZPublicStudyFolder`**, **`ZStudyFolderReport`** | **NOUVEAU** (v1.x). Extension optionnelle activable, **pas** un invariant du domaine |
| **Quota IA** | lex `education_quota_info.dart` | limit?, remaining?, resetSeconds? | **`ZEducationQuotaInfo`** | **Seam app** — construit depuis headers HTTP côté datasource, pas JSON |
| **Suggestion de tag** | lex `suggested_tag.dart` | title, colorKey | **`ZSuggestedTag`** | **NOUVEAU** (avant matérialisation en `ZFlashcardTag`) |
| **Étude comparative** | lex `comparative_study.dart` | id, title, sides[], countryCodes[], themes[] | — | **NE PAS PORTER** — spécifique métier douane, camelCase, hors périmètre éducatif générique |

### Utilitaires domaine purs à extraire

- **`ZColorPalette`** (registre `colorKey→Color` figé + fallback + remap déterministe SHA-256) — dupliqué 3× dans lex (`AnnotationHighlightPalette` 4 clés, `FlashcardTagPalette` 8 clés, `FolderColorPalette` 6 clés) et IFFD. Mécanisme dans `zcrud_core`/`zcrud_study`, couleurs concrètes **injectées** (AD-13, jamais codées en dur).
- **`applyOrder<T>`** (tri stable générique, aucune dépendance métier) — candidat `zcrud_core`.
- **`normalizeTagTitle()`** (trim + collapse + lowercase) + dédoublonnage par titre normalisé.
- **Algorithme SM-2** : `Sm2.apply/simulate` (lex) et `Sm.calc` (iffd) — **converger vers `ZSm2Scheduler` existant**. Comparer précisément (plafond EF 2.5, bonus overdue 0.5, paliers 1j/6j) avant de choisir une source unique. Risque : merge naïf casse la compatibilité de planification existante.

---

## 3. Ports & repositories

Convention AD-5/AD-11/AD-16 : `Either<ZFailure, T>` (dartz) pour les opérations ponctuelles, `Unit` pour void, **`Stream<List<T>>` nus** pour les flux (jamais `Either` sur un flux). Domaine backend-agnostique — aucun `Timestamp`/`Filter`/`Box`.

### Contrat générique répété 5-15× → à factoriser

lex répète quasi mot pour mot dans ~15 repos (`flashcards_repository.dart`, `mindmaps_repository.dart`, `smart_notes_repository.dart`, `study_folders_repository.dart`, `study_tags_repository.dart`, `study_content_order_repository.dart`, `repetition_repository.dart`, `education/*`) :

```
ZStudyRepository<T> {
  Stream<List<T>> dataChanges;
  Future<Either<ZFailure, T>>    get(String id);
  Future<Either<ZFailure, Unit>> save(T item);   // Hive-first, bump updatedAt
  Future<Either<ZFailure, Unit>> delete(String id); // soft-delete hors-entité
  Future<Either<ZFailure, Unit>> sync();          // pull + merge LWW
}
```

Ports à définir (dans `zcrud_study/domain` ou remontés `zcrud_core`) :

- **`ZStudyRepository<T>`** générique paramétré, avec hook de validation métier par override (invariant 2 niveaux dossiers, matérialisation éphémère flashcards).
- **`ZSyncableRepository<T>`** (existe déjà E5, `zcrud_core`) — `sync()` neutre, impl Hive/Firestore dans `zcrud_firestore`.
- **`ZSrsScheduler`** (existe, `zcrud_flashcard`) — interface pure remplaçable (apply/simulate/initial, horloge injectée, jamais sealed). `ZSm2Scheduler` impl par défaut. Voie d'écriture unique `reviewCard() → apply`.
- **`ZRepetitionStore`** (existe) — canal d'état SRS séparé (adressé par flashcardId, pas un `ZEntity`). Généralisable en **`ZKeyedStateStore<K,V>`** pour tout état 1:1 non-ZEntity (progression examen, état lecture doc).
- **`ZMindmapTreeOps`** (existe, `zcrud_mindmap`) — arbre pur. Vérifier que `ZMindmapOutlineController` couvre l'édition outline interactive (indent/outdent au clic) d'IFFD (`_reconstructTree`, algo « dernier nœud connu par niveau »), pas seulement `normalizeLevels` défensif au chargement.
- **`ZContentOrderRepository`** — flux `Stream<ZFolderContentsOrder>` nu (comme lex `orderStream`).
- **`ZStudyTagsRepository`** — CRUD + purge des références orphelines (intégrité référentielle) + usageCount.
- **`ZSyncOrchestrator`** (existe E5, `zcrud_core`) — reproduire `StudySyncManager` (lex `study_sync_manager.dart`) mais **paramétré par une liste injectée** de `ZSyncableRepository` (login + reconnexion débouncée 400ms), **pas** des imports en dur. Sinon `zcrud_study` non générique entre IFFD/lex.

### Asymétries à exprimer explicitement dans les contrats

1. **Merge-key hors-entité** : `ZMindmap` n'a pas de `updatedAt` propre → LWW sur clé `updated_at` hors-entité maintenue par l'adapter. Le contrat neutre doit supporter un merge-key hors-entité, pas seulement `T.updatedAt`.
2. **Topologie listener** : top-level (`study_folders`, `study_repetitions`) ont un listener `snapshots()` cross-device ; sous-collections (flashcards/notes/mindmaps) n'ont que `dataChanges` local + `sync()` pull ponctuel. L'abstraction doit exprimer cette asymétrie sans la fuiter dans le domaine.
3. **Cascade de suppression** : dossier→sous-dossiers→cartes→répétitions→notes→mindmaps→documents→annotations, batchée ≤ 450 writes (AD-9). Aujourd'hui codée en dur dans `study_folders_repository_impl.dart` → **registre déclaratif des relations parent/enfant** (topologie IFFD peut différer).

---

## 4. Couche data & offline-first

### Domaine (zcrud_study) vs Adapter (zcrud_firestore)

| Dans le domaine `zcrud_study` (pur Dart) | Dans l'adapter `zcrud_firestore` |
|---|---|
| Entités `@ZcrudModel`, ports `ZStudyRepository<T>`, `ZSrsScheduler`, `applyOrder<T>`, validation 2 niveaux | `Timestamp`/`FieldValue`/`WriteBatch`/`Box`, chemins de collection, merge LWW concret |
| `ZSyncMeta` (createdAt/updatedAt/isDeleted — hors-entité, AD-9) | `_StoredEntry`/`_readEntry` (JSON + `is_deleted`), `_timeFromRaw`/`_isoFromRaw` |
| Registre déclaratif de cascade (relations parent/enfant) | `ZFirestoreCascadeBatcher` (WriteBatch + seuil 450 + flush) |

**Helper à extraire** (dupliqué ~15× dans lex) : **`ZOfflineFirstBoxRepository<T>`** encapsulant `_StoredEntry`/`_readEntry` (JSON + `is_deleted`), `_softDeleteInBox`, `_timeFromRaw`, la boucle `_mergeSnapshotWithLocal` (paramétrée par comparateur LWW + fromJson/toJson), le filtrage `hasPendingWrites` (ignorer les échos d'écriture locale), l'upload de rattrapage des entités local-only.

**`ZFirestorePathResolver`** configurable (collection racine + sous-collections) — pour réconcilier les DEUX topologies (cf. ci-dessous) sans dupliquer les repos.

### Divergences IFFD ↔ lex_douane à réconcilier

| Axe | IFFD | lex_douane | Stratégie canonique |
|---|---|---|---|
| **Topologie collection** | TOP-LEVEL plat nommé d'après la classe Dart (`FlashCardModel`, `ExamModel`, `MindmapModel`, `SmartNoteModel`) via `FirebaseCrudRepositoryImpl<T>` **quasi-réflexif** (`objectType`) | SOUS-COLLECTIONS `users/{uid}/study_folders/{folderId}/{flashcards\|notes\|mindmaps\|documents\|exams}` + top-level `study_repetitions`/`study_tags`/`study_content_orders` | **Port neutre + adapters distincts** : « flat top-level by type » (IFFD) et « nested under folder » (lex). **Aucun nom/chemin de collection en dur dans le domaine** (AD-5/AD-16). ⚠️ Le CRUD réflexif IFFD viole l'esprit AD-3 (`reflectable` banni) → résolution de collection **explicite et statique** |
| **Nommage champs** | camelCase strict (`question`, `isTrue`, `tagsIds`, `createdAt`) | snake_case (`updated_at`, `deleted_at`, `country_code`) | Canonique = snake_case + enums camelCase. Désérialisation défensive **accepte les DEUX en lecture** (`unknownEnumValue`/`defaultValue`) pour ne pas casser les docs IFFD lors d'une bascule progressive |
| **Métadonnées sync** | Aucune sur les entités éducatives (seul `FolderModel` a `updatedAt`) | `updated_at` présent ; `deleted_at`/`is_deleted` **seulement sur `conversations`**, pas sur les entités étude | **AD-9 (`ZSyncMeta` : updated_at + is_deleted) = AJOUT rétro-compatible additif OBLIGATOIRE**, absent des deux sources. Pas une simple normalisation de nommage |
| **Collection globale** | — | `study_share_links` **hors** `users/{uid}` (résolution cross-compte) | Seam explicite de résolution de chemin, pas un cas caché |
| **Clock** | — | soft-delete local `DateTime.now()` vs écriture normale `FieldValue.serverTimestamp()` | Normaliser l'asymétrie clock-local/clock-serveur dans l'abstraction partagée |

### Stratégie de compat de sérialisation

- **Mapping bidirectionnel camelCase↔snake_case** au niveau du **codec Firestore de `zcrud_firestore`** (jamais dans le domaine) : `fieldRename: snake` côté canonique, mapping explicite vers les clés camelCase historiques IFFD en lecture.
- **Gate CI (E1-3/E2-10)** : tests de **rétro-compatibilité de sérialisation** (désérialisation défensive — champ absent/corrompu → défaut sûr, jamais throw). ⚠️ `FlashcardSource.fromJson` (lex) lève `FormatException` sur kind inconnu — **diverger volontairement d'AD-10** → basculer vers variant « unknown »/défaut sûr.
- **`content` de note** : IFFD résout l'ambiguïté markdown/Delta-JSON par heuristiques regex (`startsWith('[') && contains('"insert"')`) dispersées dans l'UI → **centraliser dans `ZCodec`** (jamais `String?` ambiguë).

---

## 5. Présentation & UI

### Surfaces inventoriées

| Surface | Source | Réutilise | Statut |
|---|---|---|---|
| **Runtime session SRS en cycle** | lex `study_session_provider.dart` + `session_flashcard_view.dart` | `ZSrsScheduler`, `ZRepetitionInfo` | **NOUVEAU** — extraire la state machine (queue/réinsertion offset +2/+4 sur lapse) en **`ZStudySessionEngine` pur** (ChangeNotifier ou reducer), binding Riverpod/GetX en périphérie |
| **Runtimes cramming/liste/examen blanc** | lex `study_alt_session_provider.dart`, `white_exam_session_provider.dart` | — | **NOUVEAU** — **`ZLinearSessionState`** générique. Invariant « zéro écriture SM-2 » **garanti par construction** (aucune référence au repo de répétition) — reproduire explicitement (ports séparés) |
| **Boutons qualité SRS + intervalle prévisionnel** | lex `srs_quality_buttons.dart`, `session_quality_breakdown.dart` | `Sm2.simulate`/`previewLabel`, `ZRepetitionInfo` | **NOUVEAU** — widget partagé, couleurs/labels via **seam thème** (pas `AppColors.srs*`) |
| **Anneaux de progression** | lex `study_progress_rings.dart` | — | **NOUVEAU** — CustomPaint pur consommant un DTO pré-calculé |
| **Layout « study tools » (page détail dossier)** | **iffd `folder_study_tools_page.dart`** (~1750 lignes, apparence de référence) | — | **NOUVEAU — `ZStudyToolsPage`** paramétré par liste de sections (title/itemBuilder/emptyState/addAction). Rail horizontal flashcards + grilles réordonnables docs/notes/mindmaps. **Chaque section = scoping ValueListenable isolé (AD-2, zéro rebuild global)** |
| **Section réordonnable** | iffd `reorderable_study_section.dart`, lex idem | — | **`ZStudyToolsSection<T>`** générique (déjà quasi-générique côté lex : `ReorderableStudyItem` = id+child) → candidat `zcrud_core`/`zcrud_list` |
| **Hub d'ajout de contenu** | lex `add_content_hub_sheet.dart` | — | **`ZContentHubSheet`** paramétré par liste d'entrées (icon/label/enabled/hint/onTap) |
| **Menu d'actions par item** | lex `study_item_actions_menu.dart`, iffd | — | **`ZItemActionsMenu`** paramétré par enum kind + callbacks (`callback null = action absente`, cohérent AD-4) |
| **Carte / dialog dossier** | lex `folder_card.dart`/`folder_edit_dialog.dart`, iffd | `ZColorPalette` | **NOUVEAU** — palette injectée |
| **Vue mindmap** | iffd `graphite_mindmap_viewer.dart` / `graphite_editor_widget.dart` | **`ZMindmapView`/`ZMindmapOutlineController`** (existe) | **RÉUTILISER `zcrud_mindmap`**. ⚠️ IFFD utilise `graphview`, zcrud utilise `graphite` → PAS un copier-coller. Combler les écarts (compact/plein-écran/super-racine multi-forêt/zoom) **dans `zcrud_mindmap`**, pas `zcrud_study`. Ne PAS porter le mode `flowchart` legacy (`flutter_flow_chart`, obsolète) |
| **Éditeur/lecteur notes markdown** | iffd `data_crud/rich_text_editor/**` + `embeds/**` | **`ZMarkdownField`/`ZMarkdownReader`/`ZCodec`** (existe) | **RÉUTILISER `zcrud_markdown` tel quel**. Table structurée `{rows,columns,cells}` (vs string markdown IFFD) → adaptateur de migration des tables existantes. Sticky-note IFFD = TextField texte plat → **upgrade vers `ZCodec`** |
| **Tags (éditeur/chips/confirm IA)** | lex `flashcard_tag_*.dart` | `ZFlashcardTag`, `normalizeTagTitle` | **NOUVEAU** — palette injectable |
| **Annotations (toolbar/panel/palette)** | lex `annotation_*.dart` | `ZDocumentAnnotation` | **NOUVEAU** (v1.x). Couleur jamais seul canal d'info (WCAG, labels a11y obligatoires) |
| **Génération résumé IA / explication dossier** | lex `note_summary_sheet.dart`, `folder_explanation_view.dart` | — | **Seam app** (`ZAiExplanationPort`), streaming SSE spécifique |

### Apparence par défaut + thème injecté (AD-13)

- **Apparence IFFD par défaut** : `ZStudyToolsPage` reproduit le layout `folder_study_tools_page.dart` (sections par type, rail flashcards, grilles réordonnables, `ZEmptyContent` par section + global).
- **Thème injecté via `ZcrudScope`/`ThemeExtension`** — **jamais** de `AppColors.srs*`/`Colors.blue` codé en dur, jamais de `lex_localizations`/`AppLocalizations` (utiliser le l10n de `zcrud_core`). Labels/couleurs via callbacks ou ThemeExtension.
- **RTL directionnel** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`), cibles ≥ 48dp, `Semantics` explicites, `ListView.builder`.
- **SM-1 (objectif produit n°1)** : `multi_flashcard_editor_page.dart` (iffd, `setState()` ×18 à l'échelle page sur moteur `DynamicFormField` legacy) = **incarnation du bug historique** → cas de test de non-régression pour `ZFormController` granulaire.

---

## 6. Seams neutres & extensibilité

Tout ce qui est app-specific est **déféré aux bindings/app** derrière un port neutre (`Either<ZFailure,T>`), jamais dans le cœur `zcrud_study`.

| Capacité app-specific | Seam neutre proposé | Justification |
|---|---|---|
| **Génération IA de flashcards** | `ZFlashcardGenerationPort` (`Either<ZFailure, List<ZFlashcard>>`) | Routeurs IA/prompts différents IFFD vs lex. `ZFlashcardGenerationRequest` = value-object, `toWireJson` séparé côté app |
| **Génération IA mindmap/résumé/explication dossier** | `ZAiExplanationPort`, `ZNoteSummaryPort` | Streaming SSE, prompts spécifiques |
| **Podcasts audio** | `ZPodcastGenerationPort` + `ZStudyPodcast` (content-addressed) | v1.x |
| **Communauté / partage** | `ZExtension?` sur `ZStudyFolder` + `ZStudySharingPort`, `ZStudyModerationPort` | Extension **optionnelle activable**, pas un invariant. IFFD (`isPublic`/`sharedWith`) et lex (owner/contributeur/viewer + memberships + share links) divergent fortement. ⚠️ Recopier la dette de sécurité lex (AC8 : contributeur peut modifier les champs de contrôle) explicitement ou la corriger, pas l'hériter silencieusement |
| **Examens blancs / scoring** | `ZExamScoringPort` (composable via `ZSrsScheduler`-like) | Si besoin |
| **Provenance de flashcard** | `ZSourceRegistry`/`ZTypeRegistry` (existe, AD-4) | Généraliser le switch exhaustif `FlashcardSource` (article/note/conversation/document/subject) en registre pluggable → IFFD/lex enregistrent leurs variants (hsSection/chatConversationId côté IFFD) sans modifier `zcrud_study` |
| **Backend (persistance)** | `ZStudyRepository<T>` + adapters `zcrud_firestore` | Chemins/collections divergents (flat vs nested) résolus par adapter |
| **Quota IA** | `ZEducationQuotaInfo` construit côté datasource (headers HTTP) | Fail-open |
| **Disponibilité progressive des éditeurs** | Interface **injectable** `ZFeatureAvailability` (pas classe const figée) | lex `StudyEditorAvailability` est const → 2 apps avec roadmaps différentes exigent une interface, pas une constante compilée dans le package partagé |
| **Upload de documents** | `ZDocumentUploadPipeline` (create→upload→update status→convert) | Isole `file_picker`/`crypto`/cloud storage. App fournit l'impl storage |
| **Seed de flashcards par référentiel** (SH/tarif IFFD) | `ZFlashcardSeedSource` | Fortement métier douane, garder app-specific |
| **Format wire chat** (LexIA `toChatJson`) | Adapter côté app | Ne doit pas fuiter dans le domaine générique |

---

## 7. Dépendances de package & graphe

### Position de `zcrud_study` dans le graphe (AD-1 acyclique)

```
zcrud_core (domaine pur, ports, ZFieldSpec, ZcrudScope, l10n — AUCUNE dep lourde)
   ▲          ▲              ▲                    ▲
   │          │              │                    │
zcrud_flashcard  zcrud_mindmap  zcrud_markdown   zcrud_firestore (adapters Hive/Firestore)
   ▲          ▲              ▲                    ▲
   └──────────┴──────┬───────┴────────────────────┘
                     │
               zcrud_study  ◄── (dépend de core + flashcard + mindmap + markdown)
                     ▲
        ┌────────────┴────────────┐
   zcrud_riverpod            zcrud_get   (bindings — lex_douane / IFFD-DODLP)
```

### Deps autorisées pour `zcrud_study`

| Dépendance | Autorisée ? | Raison |
|---|---|---|
| `zcrud_core` | ✅ | Domaine pur, ports, `ZcrudScope`, l10n |
| `zcrud_flashcard` | ✅ | `ZFlashcard`, SRS, **`ZStudyFolder`** (option B) |
| `zcrud_mindmap` | ✅ | `ZMindmap`, `ZMindmapView` |
| `zcrud_markdown` | ✅ | `ZCodec`, `ZMarkdownField` (pour `ZSmartNote`) |
| `zcrud_annotations` | ✅ (dev) | `@ZcrudModel` codegen |
| `zcrud_generator` | ✅ (dev_dependency) | build_runner |
| `zcrud_firestore` | ❌ (dans `zcrud_study`) | Adapter — dépend DE `zcrud_study`, jamais l'inverse |
| `zcrud_export` | ⚠️ | `ZFlashcardApi` référence `zcrud_export` (arête AD-1 « tangible » mais semble placeholder) — **ne pas répliquer** ce couplage artificiel sans besoin réel |
| `cloud_firestore`/`hive`/`get`/`riverpod`/`provider` | ❌ | Interdits (AD-2/AD-5/AD-15) |
| `flutter_flow_chart`/`graphview`/`syncfusion` (table) | ❌ | `graphite` déjà standard mindmap ; table native Flutter dans `zcrud_markdown` |

### Risques de cycle

1. **`ZStudyFolder` dans `zcrud_flashcard`** (risque #1) : si `zcrud_study` doit exposer le dossier ET `zcrud_mindmap` doit en dépendre, option B évite le cycle (mindmap consomme `folderId` comme clé neutre, ne dépend pas de `ZStudyFolder`). Si un besoin de dossier partagé sans tirer flashcard émerge → option A (remonter vers un socle bas). **Trancher en tête d'epic.**
2. **Registres partagés** (`ZTypeRegistry`/`ZSourceRegistry`/`ZColorPalette`) : doivent vivre dans `zcrud_core` pour être accessibles par flashcard/mindmap/study sans cycle.
3. **Gate de commit d'epic (NON-NÉGOCIABLE)** : rejouer `melos run analyze` **ET** `melos run verify` **REPO-WIDE** (pas seulement par-package) — un symbole public supprimé dans un package et référencé par un autre n'est détecté que repo-wide (cf. régression `ZExportApi` E11a-3).

---

## 8. Risques & divergences

### Fuites backend / violations AD directes (à corriger au portage)

- **IFFD `flashcard_model.dart`, `flashcard_repetition_info.dart`, `smart_note_model.dart`, `subject_model.dart`, `folder_model.dart`, `mindmap_model.dart`** importent `cloud_firestore.Timestamp` **dans le domaine** → violation frontale AD-5/AD-16. Nécessite un adapter de désérialisation dédié (jamais un simple renommage).
- **IFFD** : `Color`/`IconData` (`flutter/material`) dans les enums domaine (`QuestionType`, `FlashcardGeneratorSource`), `flutter_flow_chart.Dashboard` dans `MindmapModel` → séparer données (enum) et présentation (mapping thème via `ZcrudScope`).
- **IFFD** : `FirebaseCrudRepositoryImpl<T>` quasi-réflexif (collection = nom de classe) → proche de ce qu'AD-3 bannit → résolution de collection explicite statique.
- **lex `document_annotation.dart`** : `isDeleted` inline → extraire vers `ZSyncMeta` hors-entité (AD-9).

### GetX vs Riverpod

- **IFFD** : mixte GetX (legacy `SmartLearnController` god-controller 25+ repos, `Get.put`/`Get.find` taggés `permanent:true`) + Riverpod (migration avancée) + `ChangeNotifier` maison + `setState` global. Vestige : import `flutter_riverpod` isolé dans `folder_mindmap_editor.dart`, mélange GetX+Riverpod dans le **même widget** (`smartnote_actions_dialog_widget.dart`).
- **lex** : Riverpod exclusif (`@riverpod` codegen, family, AsyncNotifier), `ConsumerWidget` systématique (même sans `ref`).
- **Impact** : toute UI portée doit être **ré-écrite en ChangeNotifier/ValueListenable pur** (AD-2/AD-15) ; le code manager-spécifique vit dans `zcrud_riverpod`/`zcrud_get`. Extraire les state machines de session (`study_session_provider` etc.) en classes pures avant tout binding.

### Divergences de modèle IFFD ↔ lex

- **SM-2** : `Sm2` (lex, EF plafond 2.5, bonus overdue 0.5) vs `Sm.calc` (iffd) vs `ZSm2Scheduler` (existant) — 3 implémentations → comparer précisément avant convergence (merge naïf casse la compat de planification).
- **Échelle qualité** : lex 0-5 vs iffd `FlashcardRepetitionQuality` 1-5 (UI color/icon) → figer le contrat.
- **`StudySessionConfig`** : 2 versions concurrentes non réconciliées dans lex (persistée simple vs value-object riche non-JSON pour clé Riverpod) → choisir UNE forme domaine-pur.
- **`content` de note** : markdown String vs Delta JSON ambigu, résolu par heuristiques regex dispersées.
- **mindmap `content`** : texte brut (zcrud) vs Markdown/LaTeX inline (IFFD) → divergence produit visible si IFFD migre sans slot rich-text.
- **Structure profonde des collections** : flat top-level (IFFD) vs nested (lex) → migration de données IFFD **lourde** (restructuration complète), pas un renommage.

### Dette & bugs connus

- **Bug produit n°1** : `multi_flashcard_editor_page.dart` (iffd, setState global) = instance vivante du rafraîchissement global → test de non-régression.
- **`getDue()`** (`ZFlashcardRepository`) filtre EN MÉMOIRE tout le snapshot SRS (dette A2 assumée) → limite de scalabilité héritée si repris sans port de requête backend.
- **Partage lex** : limite LWW documentée (pas de fusion de champs, révocation à la prochaine sync), dette de sécurité AC8 → choix conscient à documenter, pas régression silencieuse.
- **Pattern verbeux** : `fromMap défensif + toMap manuel + copyWith à sentinelle + reservedKeys dérivées de $XFieldSpecs` copié 4× dans zcrud → factoriser (mixin/`@ZcrudModel`) avant d'ajouter `ZStudyDocument`/`ZSmartNote`/`ZExam`.
- **Périmètre examens** : sous-domaine « Exam + rappels datés » probablement spécifique lex_douane → **confirmer besoin IFFD** avant v1 (risque de gonfler le package partagé).

---

## 9. Découpage BMAD proposé

Séquencement respectant le graphe de dépendances (pas la seule numérotation). Effort par étape selon CLAUDE.md. Parallélisation **seulement** si fichiers disjoints (max 3), `zcrud_study` étant le seul point de contact → séquentiel par défaut sur le domaine.

| Epic | Titre | Dépend de | Stories candidates | Notes |
|---|---|---|---|---|
| **ES-1** | **Fondations `zcrud_study`** | — | (1) Créer package melos + barrel `zcrud_study.dart` + structure `src/{domain,data,presentation}` ; (2) **Trancher option A/B `ZStudyFolder`** + doc architecture + preuve acyclicité (`melos analyze` repo-wide) ; (3) Trancher open question #3 (`updatedAt`/`is_deleted` dans-entité vs hors-entité `ZSyncMeta`) ; (4) `ZColorPalette` + `applyOrder<T>` + `normalizeTagTitle` (utilitaires purs, éventuellement remontés `zcrud_core`) | Story de tête = décisions verrouillées |
| **ES-2** | **Domaine canonique + codegen** | ES-1 | (1) `ZStudyDocument` + `ZDocumentReadingState`/`ZDocumentLearningInfo` ; (2) `ZSmartNote` (content via `ZCodec`) ; (3) `ZFlashcardTag` + `ZSuggestedTag` ; (4) `ZFolderContentsOrder` ; (5) `ZDocumentAnnotation`/`ZAnnotationBounds` ; (6) `ZStudySessionResult`/`ZDailyStudyTask` + `aggregateDailyStudyTasks`. Toutes `@ZcrudModel`, désérialisation défensive, tests round-trip | Réutilise `ZFlashcard`/`ZRepetitionInfo`/`ZStudyFolder`/`ZMindmap` existants |
| **ES-3** | **Ports & couche data offline-first** | ES-2 | (1) `ZStudyRepository<T>` générique + hooks validation ; (2) `ZOfflineFirstBoxRepository<T>` + `ZFirestorePathResolver` (adapters `zcrud_firestore`, flat+nested) ; (3) `ZFirestoreCascadeBatcher` + registre déclaratif de cascade ; (4) `ZSyncOrchestrator` paramétré (liste injectée) ; (5) gate compat sérialisation camelCase↔snake_case (docs IFFD legacy) | Aucun `Timestamp`/`Box` dans le domaine |
| **ES-4** | **SRS + runtimes de session** | ES-3 | (1) Réconcilier SM-2 (`Sm2`/`Sm`/`ZSm2Scheduler`) → source unique ; (2) `ZStudySessionEngine` pur (cycle SRS, queue/réinsertion) ; (3) `ZLinearSessionState` (cramming/liste, zéro-SM2 par construction) ; (4) `ZWhiteExamSessionEngine` (setup/running/submitted) ; (5) widgets `ZSrsQualityButtons`/`ZSessionQualityBreakdown`/`ZStudyProgressRings` (thème injecté) | ChangeNotifier pur, binding déféré |
| **ES-5** | **Dossiers & organisation (layout IFFD)** | ES-3 | (1) `ZStudyToolsPage` (apparence IFFD, sections scoping isolé AD-2) ; (2) `ZStudyToolsSection<T>` réordonnable + `ZContentReorderController` ; (3) `ZContentHubSheet` + `ZItemActionsMenu` ; (4) carte/dialog dossier + `ZFolderSubFolderChips`/`ZStudyFolderPickerSheet` ; (5) `ZFeatureAvailability` (interface injectable) | SM-1 non-régression |
| **ES-6** | **Notes & markdown** | ES-2, ES-5 | (1) `ZSmartNote` UI (édition via `ZMarkdownField`, lecture via `ZMarkdownReader`) ; (2) adaptateur migration tables markdown→`{rows,columns,cells}` ; (3) sélecteur de note + preview | **Réutilise `zcrud_markdown`** — pas de nouveau codec |
| **ES-7** | **Mindmap (intégration)** | ES-5 | (1) Composer `ZMindmapView`/`ZMindmapOutlineController` dans `ZStudyToolsPage` ; (2) combler écarts éditeur outline (indent/outdent au clic) **dans `zcrud_mindmap`** si besoin ; (3) décision rich-text content (slot/extension) | **Réutilise `zcrud_mindmap`** — pas de `graphview`/`flowchart` |
| **ES-8** | **Tags & annotations** | ES-2 | (1) éditeur/chips/confirm IA tags (palette injectable) ; (2) toolbar/panel/palette annotations (a11y, WCAG) ; (3) purge références orphelines | v1.x possible pour annotations |
| **ES-9** | **Seams IA / communauté / examens** | ES-3 | (1) ports `ZFlashcardGenerationPort`/`ZAiExplanationPort`/`ZNoteSummaryPort` ; (2) `ZExam`/`ZReminderTime` + rappels (**si besoin IFFD confirmé**) ; (3) `ZStudyPodcast` + `ZPodcastGenerationPort` ; (4) partage : `ZStudyMembership`/`ZShareLink`/`ZPublicStudyFolder` + `ZStudySharingPort`/`ZStudyModerationPort` (extension optionnelle) | Majorité v1.x |
| **ES-10** | **Binding Riverpod (lex_douane)** | ES-4..ES-9 | (1) providers `zcrud_riverpod` pour repos/streams `zcrud_study` ; (2) family/égalité `ZStudySessionConfig` côté binding ; (3) intégration lex_douane (remplacement progressif) | Binding séparé (AD-15) |
| **ES-11** | **Binding GetX + intégration IFFD** | ES-10 | (1) `zcrud_get` pour `zcrud_study` ; (2) migration IFFD (remplacement `data_crud` legacy + god-controller) ; (3) migration données flat→canonique | Consommateur DODLP/IFFD |

**Rétrospective** après chaque epic (`bmad-retrospective`), commit unique en fin d'epic (code source uniquement, exclure `*.g.dart`/`pubspec.lock`).

---

### Fichiers de référence clés (chemins réels)

**lex_douane (modèle canonique) :** `packages/lex_core/lib/domain/entities/education/{study_folder,study_document,flashcard,flashcard_tag,mindmap,repetition_info,smart_note,exam,document_reading_state,document_annotation,folder_contents_order,study_session_config,daily_study_task,study_podcast,study_membership,share_link,public_study_folder}.dart` ; `packages/lex_core/lib/domain/usecases/education/sm2.dart` ; `packages/lex_core/lib/domain/utils/mindmap_tree_ops.dart` ; `packages/lex_data/lib/data/repositories/{study_folders,flashcards,repetition,...}_repository_impl.dart` + `education/*` ; `packages/lex_data/lib/data/services/study_sync_manager.dart` ; `packages/lex_ui/lib/presentation/widgets/study/*` ; `firestore.rules` (lignes 224-350).

**IFFD (apparence + origine) :** `lib/src/presentation/features/folders/pages/folder_study_tools_page.dart` (layout de référence) ; `lib/src/domain/models/{flashcard_model,flashcard_repetition_info,folder_model,subject_model,mindmap_model,smart_note_model}.dart` ; `lib/data_crud/rich_text_editor/**` + `lib/data_crud/embeds/**` ; `lib/src/data/repositories/firebase_models_repositories_impls.dart` ; `firestore.indexes.json`.

**zcrud (existant à réutiliser) :** `packages/zcrud_flashcard/lib/src/domain/{z_flashcard,z_repetition_info,z_study_folder,z_study_folder_hierarchy,z_srs_scheduler,z_sm2_scheduler,z_study_session_config,z_study_session_selector}.dart` + `lib/src/data/{z_flashcard_repository,z_repetition_store}.dart` ; `packages/zcrud_mindmap/lib/src/domain/{z_mindmap,z_mindmap_node,z_mindmap_tree_ops}.dart` + `lib/src/presentation/{z_mindmap_view,z_mindmap_outline_controller}.dart` ; `packages/zcrud_markdown/lib/src/{domain/z_codec,data/z_markdown_codec,presentation/z_markdown_field,presentation/z_latex_embed,presentation/z_table_embed}.dart`.