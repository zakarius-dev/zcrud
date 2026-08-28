/// Barrel d'API publique de `zcrud_study_kernel`.
///
/// Noyau d'étude bas-niveau, source unique de :
/// - `ZStudyFolder` : dossier d'organisation multi-type (rattachement
///   inverse) ;
/// - `validatePlacement` : primitive pure de hiérarchie 2 niveaux ;
/// - `ZReviewMode` : enum de mode de session ;
/// - `ZStudySessionConfig` : config de session persistable (filtres `types`
///   neutralisés en `List<String>` pour l'acyclicité) ;
/// - `ZSessionCandidate` : port neutre filtrable (implémenté par les
///   entités des satellites, ex. une flashcard) ;
/// - `ZStudySessionSelector` : sélection pure opérant sur
///   `ZSessionCandidate`.
///
/// Dépend uniquement de `zcrud_core` (surface pur-Dart) et
/// `zcrud_annotations` (invariant AD-1) — aucune dépendance lourde.
///
/// **Extensions générées masquées (`hide`)** : les extensions générées de
/// `ZStudyFolder`/`ZStudySessionConfig` portent un `copyWith`/`toMap`
/// internes ; la (dé)sérialisation et la copie passent par l'API d'instance
/// (`fromMap`/`toMap`/`copyWith` à sentinelle), pas par l'extension générée
/// (qui remettrait `extra`/`extension` à leurs défauts → perte silencieuse).
///
/// **Utilitaires domaine purs partagés** : trois familles d'utilitaires sans
/// dépendance métier, réutilisables par tout satellite d'étude :
/// - `ZColorPalette`/`ZKeyHash`/`zFnv1a32` : registre borné + repli + remap
///   déterministe de `colorKey` (zéro `Color` — la résolution `colorKey →
///   Color` est injectée côté `zcrud_core`, `ZcrudScope.colorKeyResolver`) ;
/// - `ZUnorderedPlacement`/`applyOrder<T>` : tri stable à ordre personnel
///   partiel ;
/// - `normalizeTagTitle`/`dedupeByNormalizedTitle<T>` : normalisation et
///   dédoublonnage de titre de tag.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Agrégation pure « rythme du jour » (cartes dues + examens approchants) via
// le port neutre `ZApproachingExam` : le kernel ne dépend d'aucun satellite.
export 'src/domain/aggregate_daily_study_tasks.dart';
export 'src/domain/apply_order.dart';
export 'src/domain/normalize_tag_title.dart';
export 'src/domain/remap_color_key.dart';
export 'src/domain/tag_referential_integrity.dart';
// Avancement pur de la flamme d'assiduité : `zAdvanceStreak` (horloge
// paramétrée, invariant AD-14, reset à 1 jamais 0, jour civil local) +
// `ZStreakOutcome`/`ZStreakAdvance`. Aucune extension générée (fonction +
// enum + value object) ⇒ exporté sans `hide`.
export 'src/domain/z_advance_streak.dart';
// Registre déclaratif de cascade `ZCascadeEdge` + `ZCascadeRegistry` : pur,
// zéro backend, zéro chemin ; ownership anti « deux propriétaires » (garde
// machine) + traversée bornée (garde de cycle self-edge). La topologie
// concrète est résolue côté `zcrud_firestore`.
export 'src/domain/z_cascade_registry.dart';
export 'src/domain/z_color_palette.dart';
// Famille ouverte de tâches quotidiennes (interface + `String kind`, jamais
// `sealed`, invariant AD-4) + port neutre `ZApproachingExam`.
export 'src/domain/z_daily_study_task.dart';
// `ZFlashcardTag` (`ZExtensible`) : l'extension générée `ZFlashcardTagZcrud`
// est masquée — son `copyWith` généré remettrait `extra`/`extension` aux
// défauts, ce qui serait une perte silencieuse.
export 'src/domain/z_flashcard_tag.dart' hide ZFlashcardTagZcrud;
// `ZFolderContentsOrder` (`ZExtensible`, état personnel clé par `folderId`) :
// l'extension générée `ZFolderContentsOrderZcrud` est masquée — son
// `copyWith`/`toMap` généré remettrait `extra`/`extension`/le canal
// `section_orders` aux défauts, ce qui serait une perte silencieuse.
export 'src/domain/z_folder_contents_order.dart' hide ZFolderContentsOrderZcrud;
// Enums du podcast content-addressed : purs, aucune extension générée ⇒
// exportés sans `hide`.
export 'src/domain/z_podcast_freshness.dart';
export 'src/domain/z_podcast_mode.dart';
export 'src/domain/z_podcast_source_kind.dart';
export 'src/domain/z_podcast_status.dart';
export 'src/domain/z_review_mode.dart';
// `zSectionKey` : constructeur canonique et unique des clés de
// `sectionOrders` (canal persisté). Fonction pure, aucune extension générée.
export 'src/domain/z_section_key.dart';
export 'src/domain/z_session_candidate.dart';
// Ports neutres `ZStudyDocumentRef` / `ZStudyNoteRef` — la voie typée pour
// documents et notes manque au socle de présentation d'étude parce que les
// arêtes vers les paquets de documents/notes n'existent pas (invariant
// AD-1). Le contrat est donc défini ici et implémenté côté satellite — même
// patron que `ZSessionCandidate` et `ZApproachingExam`. Surface pur-Dart,
// zéro import, zéro codegen (aucune extension générée) ⇒ exportés sans
// `hide`.
export 'src/domain/z_study_document_ref.dart';
export 'src/domain/z_study_folder.dart' hide ZStudyFolderZcrud;
export 'src/domain/z_study_folder_hierarchy.dart';
export 'src/domain/z_study_note_ref.dart';
// `ZStudyPodcast` (`ZEntity` + `ZExtensible`) : l'extension générée
// `ZStudyPodcastZcrud` est masquée — son `copyWith`/`toMap` généré
// remettrait `extra`/`extension` aux défauts, ce qui serait une perte
// silencieuse. `sourceHash` est une empreinte opaque comparée, jamais
// calculée ici (aucune dépendance cryptographique dans le kernel).
export 'src/domain/z_study_podcast.dart' hide ZStudyPodcastZcrud;
// Port CRUD offline-first générique `ZStudyRepository<T>` (Template Method :
// `validate` overridable exécuté avant `persist`). Compose avec
// `ZSyncableRepository` de `zcrud_core` (invariant AD-4), n'ajoute que le
// hook métier.
export 'src/domain/z_study_repository.dart';
export 'src/domain/z_study_session_config.dart' hide ZStudySessionConfigZcrud;
// Résultat d'une session : value-object pur (aucun codegen, aucun
// `@ZcrudModel`/registre).
export 'src/domain/z_study_session_result.dart';
export 'src/domain/z_study_session_selector.dart';
// `ZStudyStreak` (`ZEntity`, `@ZcrudModel`) + le jour civil
// (`ZCivilDayOf`/`zLocalCivilDay`/`zCivilDayNumber`/`zParseCivilDayNumber`/
// `zIsCivilDay`/`zFormatCivilDay`).
//
// Exporté sans `hide` : `ZStudyStreak` n'est pas `ZExtensible` (aucun
// `extra`/`extension` que le `copyWith` généré remettrait aux défauts) ⇒ son
// extension générée est complète et sûre, et c'est elle qui porte
// `toMap`/`copyWith` (aucun doublon à la main).
export 'src/domain/z_study_streak.dart';
// Référence légère vers une matière possédée et résolue par l'application.
// Le kernel n'introduit ni entité matière ni port de résolution.
export 'src/domain/z_study_subject_ref.dart';
// `ZSuggestedTag` : value object non-`ZExtensible`. Son extension générée
// `ZSuggestedTagZcrud` est exportée sans `hide` : un value object n'a ni
// `extra` ni `extension`, son `copyWith` généré est donc complet et sûr.
export 'src/domain/z_suggested_tag.dart';
