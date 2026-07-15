/// Barrel d'API publique de `zcrud_session` (ES-4.2).
///
/// Runtime de **session d'étude en cycle** :
/// - `ZStudySessionEngine` — moteur `ChangeNotifier` **pur-Flutter** (état
///   immuable + reducer PUR), sans aucun gestionnaire d'état (AD-2). Fait
///   progresser la file par `grade`, en réinsérant une carte ratée à un offset
///   déterministe (+2/+4 selon la sévérité du lapse, D2) et en écrivant l'état
///   SRS **uniquement** via le seam injecté (voie unique, AD-9/AD-23). Les
///   constantes d'offset (`kLapseOffsetSoft`/`kLapseOffsetHard`) et le reducer
///   PUR `reduceGrade` sont exposés (testabilité golden, AC3/AC5).
/// - `ZSessionState` — instantané **immuable** de la file + compteurs
///   (`reviewed`/`lapses`/`remaining`/`isComplete`), value-object.
/// - `ZSessionItem` — identité **neutre** de carte (`{flashcardId, folderId,
///   typeKey?}`) — le moteur ne tire aucun widget flashcard.
/// - `ZSessionReviewer` — seam d'écriture SRS injecté (= `reviewCard` en prod).
///
/// API publique = ce barrel ; implémentation sous `lib/src/domain/`. Aucun
/// codegen (état de session runtime **non persisté** — pas de `*.g.dart`).
library;

export 'src/domain/z_linear_session_state.dart';
export 'src/domain/z_session_item.dart';
export 'src/domain/z_session_reviewer.dart';
export 'src/domain/z_session_state.dart';
export 'src/domain/z_study_session_engine.dart';
export 'src/domain/z_white_exam_session_engine.dart';
// Widgets de PRÉSENTATION PURS (ES-4.5, AD-2/AD-13/FR-26) — 1re surface
// présentation de `zcrud_session` (import `flutter/material` + surface
// présentation de `zcrud_core`, nœuds de graphe DÉJÀ présents ⇒ zéro nouvelle
// arête inter-packages). Widgets `StatelessWidget` PURS : aucun gestionnaire
// d'état, callbacks injectés, thème/labels/couleurs INJECTÉS.
// - `ZSrsQualityButtons` (+ `ZQualityScale`) : boutons de notation qualité SM-2,
//   mapping cran→qualité DANS le widget (ES-4.1 D6), intervalle via seam
//   `previewLabelFor` (= `simulate`, projection PURE — jamais recalculé).
// - `ZSessionQualityBreakdown` : répartition fidèle de `byQuality` (un segment
//   par clé, aucune omise/inversée, clé hors échelle signalée à part — R6).
// - `ZStudyProgressRings` (+ `ZProgressRingsData`) : `CustomPaint` PUR sur DTO
//   pré-calculé (`ratio` clampé, `total == 0` → 0, pas de division par zéro).
export 'src/presentation/z_session_quality_breakdown.dart';
export 'src/presentation/z_srs_quality_buttons.dart';
export 'src/presentation/z_study_progress_rings.dart';
