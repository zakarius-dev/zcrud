/// Barrel d'API publique de `zcrud_study_kernel`.
///
/// Noyau d'étude bas-niveau (ES-1.1), **source UNIQUE** — remontée depuis
/// `zcrud_flashcard` (AD-18) — de :
/// - `ZStudyFolder` : dossier d'organisation multi-type (rattachement inverse) ;
/// - `validatePlacement` : primitive PURE de hiérarchie 2 niveaux ;
/// - `ZReviewMode` : enum de mode de session ;
/// - `ZStudySessionConfig` : config de session persistable (filtres `types`
///   **neutralisés** en `List<String>` pour l'acyclicité — AC6) ;
/// - `ZSessionCandidate` : **port neutre** filtrable (implémenté par les entités
///   des satellites, ex. `ZFlashcard`) ;
/// - `ZStudySessionSelector` : sélection PURE opérant sur `ZSessionCandidate`.
///
/// Dépend UNIQUEMENT de `zcrud_core` (surface pur-Dart) + `zcrud_annotations`
/// (AD-1/AD-17) — aucune arête vers `zcrud_flashcard`, aucune dép lourde.
///
/// **Extensions générées masquées (`hide`)** : `ZStudyFolderZcrud` /
/// `ZStudySessionConfigZcrud` portent un `copyWith`/`toMap` internes ; la
/// (dé)sérialisation et la copie passent par l'API d'instance
/// (`fromMap`/`toMap`/`copyWith` à sentinelle), pas par l'extension générée (qui
/// remettrait `extra`/`extension` à leurs défauts → perte silencieuse). Politique
/// reproduite à l'identique de l'ancien barrel `zcrud_flashcard` (surface
/// publique inchangée).
///
/// **ES-1.2 — utilitaires domaine purs partagés** (FR-S2) : trois utilitaires
/// **sans dépendance métier**, réutilisables par tout satellite study — remplacent
/// les 3+ palettes/tris/normalisations dupliqués lex/IFFD :
/// - `ZColorPalette`/`ZKeyHash`/`zFnv1a32` : registre borné + fallback + remap
///   déterministe de `colorKey` (**zéro `Color`** — SM-S5 ; résolution
///   `colorKey → Color` injectée côté `zcrud_core`, `ZcrudScope.colorKeyResolver`) ;
/// - `ZUnorderedPlacement`/`applyOrder<T>` : tri stable à ordre personnel partiel ;
/// - `normalizeTagTitle`/`dedupeByNormalizedTitle<T>` : normalisation + dédoublonnage
///   de titre de tag.
///
/// **Règle de maintenance (D3, solde LOW-1 d'ES-1.1)** : `zcrud_flashcard`
/// réexporte ce barrel via une liste **`hide`** (jamais `show`) pour préserver
/// intégralement la surface historique E9 — **symboles générés inclus**
/// (`registerZStudyFolder`, `registerZStudySessionConfig`, field-specs) — tout
/// en excluant les utilitaires hors périmètre flashcard. **Tout nouveau symbole
/// public ajouté à CE barrel qui n'a rien à voir avec les flashcards DOIT être
/// ajouté à la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`**
/// (ex. futur `ZSyncMeta` d'ES-1.3, entités ES-2, …).
///
/// Règle **outillée** (finding L4 du code-review ES-1.2) :
/// `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` croise les
/// symboles publics RÉELS de ce barrel avec le `hide` de `zcrud_flashcard` et une
/// allowlist explicite — un symbole non classé **fait échouer les tests** (plus
/// de fuite silencieuse possible).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// ES-2.7 (FR-S10) — agrégation PURE « rythme du jour » (cartes dues + examens
// approchants) via le port neutre `ZApproachingExam` : le kernel ne dépend
// d'AUCUN satellite (AD-1/AD-17/D3).
export 'src/domain/aggregate_daily_study_tasks.dart';
export 'src/domain/apply_order.dart';
export 'src/domain/normalize_tag_title.dart';
export 'src/domain/remap_color_key.dart';
export 'src/domain/tag_referential_integrity.dart';
// ES-3.3 (FR-S14, AD-21) — registre DÉCLARATIF de cascade `ZCascadeEdge` +
// `ZCascadeRegistry` : PUR, zéro backend, zéro chemin ; ownership anti two-owners
// (garde machine) + traversée bornée (garde de cycle self-edge). La topologie
// concrète est résolue côté `zcrud_firestore` (`ZFirestorePathResolver`). Hors
// surface flashcard ⇒ classé au `hide` de `zcrud_flashcard` (D10).
export 'src/domain/z_cascade_registry.dart';
export 'src/domain/z_color_palette.dart';
// ES-2.7 (FR-S10) — famille OUVERTE de tâches quotidiennes (interface +
// `String kind`, JAMAIS `sealed` — AD-4/D2) + port neutre `ZApproachingExam`.
export 'src/domain/z_daily_study_task.dart';
// ES-2.3 — `ZFlashcardTag` (`ZExtensible`) : l'extension GÉNÉRÉE
// `ZFlashcardTagZcrud` est masquée (règle (h) — son `copyWith` généré remettrait
// `extra`/`extension` aux défauts → perte silencieuse, finding H3 d'ES-2.1).
export 'src/domain/z_flashcard_tag.dart' hide ZFlashcardTagZcrud;
// ES-2.4 — `ZFolderContentsOrder` (`ZExtensible`, état PERSONNEL clé par
// `folderId`) : l'extension GÉNÉRÉE `ZFolderContentsOrderZcrud` est masquée
// (règle (h) — son `copyWith`/`toMap` généré remettrait `extra`/`extension`/le
// canal `section_orders` aux défauts → perte silencieuse).
export 'src/domain/z_folder_contents_order.dart' hide ZFolderContentsOrderZcrud;
// ES-2.8 (FR-S11) — enums du podcast *content-addressed* : purs, aucune
// extension générée ⇒ exportés SANS `hide` (précédent `ZReviewMode`).
export 'src/domain/z_podcast_freshness.dart';
export 'src/domain/z_podcast_mode.dart';
export 'src/domain/z_podcast_source_kind.dart';
export 'src/domain/z_podcast_status.dart';
export 'src/domain/z_review_mode.dart';
export 'src/domain/z_session_candidate.dart';
export 'src/domain/z_study_folder.dart' hide ZStudyFolderZcrud;
export 'src/domain/z_study_folder_hierarchy.dart';
// ES-2.8 (FR-S11) — `ZStudyPodcast` (`ZEntity` + `ZExtensible`) : l'extension
// GÉNÉRÉE `ZStudyPodcastZcrud` est masquée (règle (h) — son `copyWith`/`toMap`
// généré remettrait `extra`/`extension` aux défauts → perte silencieuse H3).
// `sourceHash` est une empreinte OPAQUE COMPARÉE, JAMAIS calculée ici (D4 :
// aucune dépendance crypto — NFR-S10/SM-S7).
export 'src/domain/z_study_podcast.dart' hide ZStudyPodcastZcrud;
// ES-3.1 (FR-S12) — port CRUD offline-first générique `ZStudyRepository<T>`
// (Template Method : `validate` overridable exécuté AVANT `persist`). COMPOSE
// avec `ZSyncableRepository` de `zcrud_core` (AD-4), n'ajoute que le hook métier.
// Port data générique HORS surface flashcard historique ⇒ classé au `hide` du
// barrel `zcrud_flashcard` (D7/AC10).
export 'src/domain/z_study_repository.dart';
export 'src/domain/z_study_session_config.dart' hide ZStudySessionConfigZcrud;
// ES-2.7 (FR-S10) — résultat d'UNE session : value-object PUR (AUCUN codegen,
// aucun `@ZcrudModel`/`registerZ…` — D1).
export 'src/domain/z_study_session_result.dart';
export 'src/domain/z_study_session_selector.dart';
// ES-2.3 — `ZSuggestedTag` : value object NON-`ZExtensible`. Son extension
// générée `ZSuggestedTagZcrud` est exportée **sans `hide`** — précédent EXACT
// `ZChoice` (`export 'src/domain/z_choice.dart';` du barrel flashcard, sans
// `hide`). La règle (h) du gate `reserved-keys` ne cible QUE les entités
// `ZExtensible` (dont le `copyWith` généré détruirait `extra`/`extension` —
// finding H3) : un value object n'a NI `extra` NI `extension`, son `copyWith`
// généré est complet et sûr. Le `hide` prescrit par la story (D7/AC10) est écarté
// (R-G) : il amputerait inutilement le `toMap`/`copyWith` publics du DTO, en
// contradiction avec le précédent `ZChoice`.
export 'src/domain/z_suggested_tag.dart';
