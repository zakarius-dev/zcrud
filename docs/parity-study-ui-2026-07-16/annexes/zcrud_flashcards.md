# Reconnaissance zcrud — Affichage & Édition des Flashcards (audit parité IFFD)

Périmètre exploré : `zcrud_flashcard`, `zcrud_session`, `zcrud_study`,
`zcrud_study_kernel`, `zcrud_exam`, `zcrud_export`. Lecture seule, aucune
modification.

---

## 1. Types & champs (domaine)

### `ZFlashcardType` (`packages/zcrud_flashcard/lib/src/domain/z_flashcard_type.dart`)
Enum à 6 valeurs, persistées en camelCase, repli défensif `openQuestion` :
- `multipleChoice` (QCM, via `ZChoice`)
- `trueOrFalse` (via `ZFlashcard.isTrue`)
- `openQuestion` (réponse libre — valeur de repli)
- `exercise` (réponse libre évaluée)
- `fillBlank` (texte à trous)
- `shortAnswer` (réponse courte)

### `ZFlashcard` (`z_flashcard.dart`) — entité canonique `@ZcrudModel`, `ZEntity + ZExtensible`, implémente `ZSessionCandidate`
Champs : `id` (nullable/éphémère), `folderId`, `subFolderId`, `type`
(`ZFlashcardType`), `question` (requis, seul champ validé au niveau cœur),
`answer`, `isTrue`, `choices` (`List<ZChoice>?`), `explanation`, `hint`,
`tagIds` (`List<String>`), `isReadOnly`, `createdAt`, `updatedAt`, `source`
(`ZFlashcardSource?`, hors-codegen), `extension` (`ZExtension?`, slot additif
versionné), `extra` (`Map<String,dynamic>`, échappatoire non typée).
**État SRS explicitement HORS carte** (AD-9) : aucun champ SRS sur l'entité —
vit dans `ZRepetitionInfo` (canal séparé).

### `ZChoice` (`z_choice.dart`) — sous-modèle `@ZcrudModel`
`content` (String, défaut `''`), `isCorrect` (bool, défaut `false`). Aucune
validation métier portée par l'entité (déférée à l'éditeur).

### `ZFlashcardSource` (`z_flashcard_source.dart`) — union scellée en interne, ouverte par registre
Variants génériques : `ZNoteSource` (`noteId`), `ZConversationSource`
(`conversationId`, `messageId`), `ZDocumentSource` (`documentId`, `page?`).
Variant de repli **ouvert** `ZCustomSource(kind, payload)` : un `kind`
inconnu (ex. futur variant « article » IFFD) est routé ici via
`ZSourceRegistry.register(kind, …)` injecté — jamais codé en dur, jamais de
throw.

### `ZFlashcardTag` (`zcrud_study_kernel/z_flashcard_tag.dart`) — entité first-class
`id`, `title`, `colorKey` (String libre, borné à l'affichage via
`remapColorKey`+palette injectée), `extension`, `extra`. Remplace une liste
`tagIds` nue.

### `ZRepetitionInfo` (`z_repetition_info.dart`) — état SRS séparé, `@ZcrudModel`
`flashcardId` (clé de jointure), `folderId` (dénormalisé), `interval` (jours),
`repetitions`, `easeFactor` (borné `[1.3;2.5]` par défaut), `nextReviewDate`,
`learnedAt` (première réussite, jamais remise à null), `lastQuality` (0..5),
`extension`, `extra`. **Aucun `copyWith` public** — voie d'avancement unique
via `ZSrsScheduler`.

---

## 2. Capacités (C1..Cn)

### Domaine / SRS

**C1 — `ZSrsScheduler` (interface) + `ZSm2Scheduler` (impl SuperMemo-2)**
`packages/zcrud_flashcard/lib/src/domain/z_srs_scheduler.dart` +
`z_sm2_scheduler.dart`. Planificateur de répétition espacée remplaçable
(FSRS/Leitner branchable sans toucher les modèles). `apply()` = unique voie
d'avancement, `simulate()` = projection pure sans effet de bord (alimente
l'aperçu d'intervalle des boutons qualité), `initial()` = état neuf.

**C2 — `ZSrsConfig`** (`z_srs_config.dart`). Constantes SM-2 injectables
(`minEaseFactor`, `maxEaseFactor`, `defaultEaseFactor`, `overdueBonusFactor`,
`passThreshold=3`) — aucune constante en dur dans l'algorithme.

**C3 — `ZFlashcardRepository`** (`data/z_flashcard_repository.dart`).
Coordinateur offline-first CRUD carte + SRS : `watchAll/watch/getAll/getById`,
`save` (avec garde `folderId` requis pour une carte éphémère), `softDelete`,
`restore`, `moveCard` (déplacement + re-sync SRS folder-only), `sync`.
**`reviewCard()`** = unique voie d'écriture SRS avançant l'état (délègue à
`scheduler.apply`) ; `initRepetition` (idempotent) et `resetRepetition`
(reset délibéré) sont les deux seuls autres writes SRS. `getDue()` sélectionne
les états dus (filtre en mémoire, dette assumée A2).

**C4 — `ZRepetitionStore`** (port, `data/z_repetition_store.dart`). Persistance
offline-first neutre de l'état SRS, top-level (`study_repetitions/{cardId}`),
séparée de la carte — le partage d'une carte n'emporte jamais l'historique
SRS d'autrui. **PORT SEULEMENT** : E9-4 ne livre que le contrat + fakes en
mémoire ; l'adaptateur Hive/Firestore concret est déféré à l'app/composition
root (non trouvé dans `zcrud_firestore` lors de cette reconnaissance — à
vérifier séparément si besoin).

**C5 — `ZSessionCandidate` (port) + `ZStudySessionSelector`**
(`zcrud_study_kernel`). Sélection déterministe pure de candidats de session
filtrés par dossier ∧ tags ∧ types (ET logique) puis plafond `count`. Le
noyau reste ignorant de `ZFlashcardType` (clé `typeKey` opaque).

### Édition (presentation, `zcrud_flashcard`)

**C6 — `registerZFlashcardEditors` + `ZFlashcardEditionFields`**
(`presentation/z_flashcard_editors.dart`). Enregistre un unique builder dans
le `ZWidgetRegistry` du cœur sous le `kind` `custom`, discriminé par
`ZFlashcardFieldConfig.editorKind`. Fabriques prêtes à l'emploi pour un
formulaire flashcard standard : `type()`, `choices()`, `trueFalse()`,
`question()` (multiline, requis), `answer()`, `explanation()`, `hint()`,
`tags()` — plus `all()` qui assemble les 8 champs. C'est le **formulaire
d'édition mono-carte** du package (pas de multi-carte).

**C7 — `ZFlashcardTypeFieldWidget`** — sélecteur du type (6 tuiles mono-choix
accessibles), libellés FR par défaut, résolveur surchargeable.

**C8 — `ZChoicesFieldWidget`** — éditeur QCM complet : ajouter/supprimer/
réordonner un choix, éditer son libellé, basculer son caractère correct.
`TextEditingController`/`FocusNode` stables par ligne (SM-1 : pas de perte de
focus). Émission neutre via `ctx.onChanged`.

**C9 — `ZTrueFalseFieldWidget`** — sélecteur vrai/faux à deux tuiles
(`ZFlashcardOptionTile`).

**C10 — `ZFlashcardOptionTile`** — tuile d'option mono-choix accessible
partagée par C7/C9 (≥ 48 dp, `Semantics` `tap`, thème injecté).

**C11 — `ZFlashcardEditionValidator`** (`z_flashcard_edition_validator.dart`).
Validation éditeur pure : `question` requise ; si `type == multipleChoice`,
`choices` doit avoir ≥ 2 choix ET ≥ 1 correct. `validate()` renvoie une table
d'erreurs par champ ; `validateAndReveal(controller)` intègre la soumission
(révèle sans `Form` global).

**C12 — `ZFlashcardEditingScope`** (`InheritedWidget`). Expose le
`ZFormController` aux widgets d'édition flashcard pour le canal `reveal`
(révélation d'erreurs à la soumission agrégée, sans `Form` global).

**C13 — Coercitions défensives** (`z_flashcard_editor_values.dart`) —
`coerceFlashcardType`/`coerceChoices`/`coerceTrueFalse` : jamais de throw sur
valeur de tranche corrompue.

**C14 — Déplacement de carte** — `ZFlashcardRepository.moveCard` (déjà cité
en C3) réalise le changement de dossier avec re-synchronisation SRS.

### Session / Révision (`zcrud_session`)

**C15 — `ZStudySessionEngine`** (`domain/z_study_session_engine.dart`).
Moteur `ChangeNotifier` pur-Flutter (zéro gestionnaire d'état) pilotant une
session en cycle : reducer pur `reduceGrade`, réinsertion des lapses à offset
+2/+4 selon sévérité, écriture SRS via seam injecté `ZSessionReviewer` (jamais
de scheduler/store en champ).

**C16 — `ZWhiteExamSessionEngine`** (`domain/z_white_exam_session_engine.dart`)
— moteur de session « examen blanc » séparé (sans progression SRS,
confirmé par les tests `z_white_exam_no_srs_test.dart`) ; agrège des
qualités + un seuil vers un résultat.

**C17 — `ZSessionState`/`ZSessionItem`/`ZLinearSessionState`/`ZSessionReviewer`**
— value-objects immuables de file de session + seam d'écriture SRS injecté
(signature = `ZFlashcardRepository.reviewCard`, garantissant par construction
une voie unique).

**C18 — `ZSrsQualityButtons`** (`presentation/z_srs_quality_buttons.dart`).
Rangée de boutons de notation qualité SM-2 (`ZQualityScale` 0..5 ou 1..5),
widget `StatelessWidget` pur : mapping cran→qualité interne, aperçu
d'intervalle via seam `previewLabelFor` (= `scheduler.simulate`), couleurs/
labels injectés (thème + l10n), cibles ≥ 48 dp.

**C19 — `ZSessionQualityBreakdown`** (`presentation/z_session_quality_breakdown.dart`).
Répartition fidèle des qualités d'une session : un segment par clé présente,
ordonné croissant, clés hors échelle signalées à part (jamais fusionnées
silencieusement).

**C20 — `ZStudyProgressRings`** (`presentation/z_study_progress_rings.dart`).
Anneau(x) de progression `correct/total` en `CustomPaint` pur, DTO
`ZProgressRingsData` pré-calculé (ratio clampé, pas de division par zéro),
couleurs injectées.

### Study / IA / tags / examens (`zcrud_study`, `zcrud_exam`)

**C21 — `ZFlashcardGenerationPort`** (`domain/z_flashcard_generation_port.dart`).
**PORT SEUL, aucune implémentation fournie.** `abstract interface class` avec
une seule méthode `generateFlashcards(request) -> ZResult<List<ZFlashcard>>`.
`ZFlashcardGenerationRequest` porte `content`, `count?`, `languageTag?`,
`provenance?` (`ZFlashcardSource?`) — zéro prompt, zéro endpoint, zéro clé
API (AD-12). L'app hôte doit fournir l'implémentation (routeur IA).

**C22 — `ZNoteSummaryPort`, `ZPodcastGenerationPort`, `ZAiExplanationPort`,
`ZStudyModerationPort`** (`zcrud_study/lib/src/domain/`) — autres seams IA
neutres du module étude (résumé de note, génération podcast, explication IA,
modération). **PORTS SEULS** également, même patron que C21. Non spécifiques
flashcard mais utilisables en périphérie (ex. génération de carte depuis un
résumé de note).

**C23 — `ZTagChips`** (`presentation/z_tag_chips.dart`). Rangée de puces de
tags de flashcard : couleur via palette injectée + `remapColorKey`, titre
textuel toujours affiché (couleur jamais seul canal), compteur d'usages
dérivé au rendu (jamais un champ stocké), suppression/tap optionnels.

**C24 — `ZTagEditor`** (`presentation/z_tag_editor.dart`, non lu en détail
mais présent) — éditeur de tags associé au module study.

**C25 — `ZExam` / `ZReminderTime`** (`zcrud_exam`) — entité examen + rappels,
liée au module étude (planification), pas directement aux flashcards
individuelles ; `ZExamEditor`/`ZExamReminders*` en presentation `zcrud_study`.

**C26 — `ZItemActionsMenu`, `ZContentHubSheet`, `ZStudyToolsPage`,
`ZSectionedStudyLayout`** (`zcrud_study/lib/src/presentation/`) — briques de
navigation/organisation du hub d'étude (menus d'action sur un item, feuille
de sélection de contenu, page d'outils d'étude, layout en sections). Ce sont
des briques génériques d'orchestration UI du module étude, PAS un rendu de
liste de flashcards ni une carte de révision.

### Export

**C27 — `ZExporter` / `ZExportTable` / `ZExportApi`** (`zcrud_export`).
Export tabulaire **générique** neutre (Excel `.xlsx` via Syncfusion, PDF) à
partir d'un `ZListRenderRequest`/colonnes du cœur `zcrud_core` — **aucune
spécificité flashcard** : si une app veut exporter des flashcards en PDF/Excel,
elle doit les projeter elle-même dans un `ZExportTable`/`ZListRenderRequest`
générique. Pas de gabarit d'export "fiche de révision" ou "paquet de cartes"
dédié.

**C28 — `ZPdfCreationService` / `ZPdfExportOptions` / `ZFileSaver`**
(`zcrud_export`). Assemblage images→PDF générique + sauvegarde cross-platform
+ options anti-rognage. Utilisable pour exporter des captures de cartes mais
aucun lien direct au domaine flashcard (pas d'API `exportFlashcards(...)`).

---

## 3. Ce qui semble ABSENT ou PORT-seulement

| Capacité recherchée | État |
|---|---|
| **Carte de révision interactive (flip recto/verso)** | **ABSENT.** Aucun widget de type `ZFlashcardReviewCard`/flip trouvé dans tout le monorepo (grep `flip`/`recto`/`verso`/`showAnswer` ne retourne que des occurrences non liées, ex. guards de formulaire). `zcrud_session` ne fournit que le moteur d'état + les boutons de qualité + les indicateurs de progression, **pas** le widget de carte lui-même — l'app doit le construire. |
| **Rendu de liste de flashcards** | **ABSENT en tant que widget dédié.** Aucun `ZFlashcardList`/`ZFlashcardListTile` trouvé. `zcrud_list` (Syncfusion `SfDataGrid`) est générique et ne référence pas `ZFlashcard`. `zcrud_study` fournit des briques d'orchestration (`ZContentHubSheet`, `ZItemActionsMenu`, `ZSectionedStudyLayout`) mais pas un rendu de carte/liste flashcard prêt à l'emploi. |
| **Page de fin de session / célébration** | **ABSENT.** Grep `celebrat`/`confetti`/`congrat`/`completion.*page` = zéro résultat dans `packages/*/lib`. Le moteur expose `ZSessionState.isComplete` (booléen) et des DTO de résultat (`ZStudySessionResult` dans le kernel, masqué du barrel flashcard) mais aucune page/widget de célébration n'est fourni — à construire côté app. |
| **Édition batch/multi-carte** | **ABSENT.** Grep `batch` dans les libs flashcard/study/session ne retourne que du vocabulaire `WriteBatch` Firestore (persistance), aucun éditeur multi-sélection/batch de flashcards. `ZFlashcardEditionFields`/`ZFlashcardEditors` ne couvrent que l'édition d'**une** carte à la fois. |
| **Génération IA de flashcards** | **PORT SEULEMENT** (`ZFlashcardGenerationPort`, C21). Contrat pur, zéro implémentation de référence — l'app doit brancher son propre routeur IA. Idem pour résumé de note, podcast, explication IA, modération (C22) : tous des ports. |
| **Export PDF/Excel de flashcards** | **PARTIEL / générique seulement.** `zcrud_export` (C27/C28) fournit l'infrastructure Excel/PDF générique (via `ZListRenderRequest`/`ZExportTable` du cœur, plus assemblage image→PDF), mais **aucune API/gabarit spécifique flashcard** (pas de "export du paquet de cartes en PDF" prêt à l'emploi) — à composer côté app. |
| **Adaptateur concret `ZRepetitionStore`** | Port confirmé dans `zcrud_flashcard` (C4) ; recherche rapide dans `zcrud_firestore` n'a pas fait remonter d'implémentation nommée explicitement lors de cette passe — **à vérifier séparément** si l'audit de parité en a besoin (hors périmètre strict de cette reconnaissance, qui s'est concentrée sur affichage/édition). |
| **Filtres/tri de liste de flashcards (UI)** | `ZStudySessionSelector` (kernel, C5) fournit un **filtrage pur en domaine** (dossier/tags/types/count) pour composer une session, mais aucun widget de filtre/tri UI dédié aux flashcards (pas de `ZFlashcardFilterBar`). |
| **Tags** | **PRÉSENT** côté domaine (`ZFlashcardTag`, entité first-class) et présentation (`ZTagChips` C23, `ZTagEditor` C24) — capacité couverte, bien que `ZTagEditor` n'ait pas été lu en détail. |

---

## Résumé des fichiers clés lus

- `packages/zcrud_flashcard/lib/src/domain/{z_flashcard,z_choice,z_flashcard_type,z_flashcard_source,z_flashcard_api,z_repetition_info,z_srs_scheduler,z_srs_config}.dart`
- `packages/zcrud_flashcard/lib/src/data/{z_flashcard_repository,z_repetition_store}.dart`
- `packages/zcrud_flashcard/lib/src/presentation/*.dart` (9 fichiers)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (barrel)
- `packages/zcrud_session/lib/src/domain/{z_session_item,z_session_reviewer,z_session_state,z_study_session_engine}.dart`
- `packages/zcrud_session/lib/src/presentation/{z_srs_quality_buttons,z_study_progress_rings,z_session_quality_breakdown}.dart`
- `packages/zcrud_session/lib/zcrud_session.dart` (barrel)
- `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart`
- `packages/zcrud_study/lib/src/presentation/z_tag_chips.dart`
- `packages/zcrud_study_kernel/lib/src/domain/{z_study_session_selector,z_flashcard_tag}.dart`
- `packages/zcrud_export/lib/zcrud_export.dart` (barrel)
