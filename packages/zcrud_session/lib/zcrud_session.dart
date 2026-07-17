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

// SU-3 (AC2, AD-33/AD-35) — soumission ADVISORY émise à l'hôte. su-3 n'écrit
// RIEN : su-4 branchera l'écriture SRS sur le seam `ZSessionReviewer` (voie
// UNIQUE). Pur-Dart (aucun import Flutter — `test/z_purity_test.dart` le garde).
export 'src/domain/z_flashcard_submission.dart';
export 'src/domain/z_linear_session_state.dart';
// SU-5 (AC4, FR-SU9) — sélection PURE du feedback pédagogique : `(quality,
// timeTaken, hintsUsed)` → une CLÉ l10n. Pur-Dart, testable HORS widget
// (`test`, jamais `testWidgets`). La qualité passe par `config.clampQuality`
// (voie UNIQUE, AD-46/AD-10) ⇒ AUCUNE note n'est hors seau (le « mauvais » est
// **q0-2**, jamais « 1-2 » — le résidu PRD de l'échelle 1-5 est amendé par AD-46).
export 'src/domain/z_session_feedback.dart';
export 'src/domain/z_session_item.dart';
export 'src/domain/z_session_reviewer.dart';
// SU-4 (AC3, AD-34) — TABLE UNIQUE mode → runtime. Les 6 modes sont servis par
// les 3 runtimes qui EXISTENT DÉJÀ : su-4 n'en crée AUCUN. `switch` exhaustif
// sans `default` (une 7ᵉ valeur de `ZReviewMode` casse la compilation).
export 'src/domain/z_session_runtime.dart';
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
// SU-3 (AC8, FR-SU5) — `ZCardAdvanceBehavior` + TABLE UNIQUE des défauts par
// mode (`zDefaultAdvanceBehavior`) : jamais redécidée par un widget.
export 'src/presentation/z_card_advance_behavior.dart';
// SU-7 (AC2, D2) — régime d'apparition de la correction. Gate de **RENDU SEUL**
// (défaut `immediate` ⇒ su-3 inchangé) : en `deferred`, la correction est POSÉE
// (donc la saisie reste VERROUILLÉE — une réponse par carte) mais jamais peinte.
// Mêler ce gate au verrou d'interaction rouvrirait la double soumission (G4).
export 'src/presentation/z_correction_visibility.dart';
// SU-3 (AC1..AC11) — surface de SAISIE notée. 🔒 AUCUN tap-to-reveal (AC9) : la
// correction est causée par la SOUMISSION ; le contenu (slot AD-40) reste sous
// `IgnorePointer`. Composée en FRÈRE de `ZFlashcardReviewCard` (su-2) par l'hôte.
export 'src/presentation/z_flashcard_answer_input.dart';
// SU-7 (AC1..AC9, FR-SU13) — UI d'EXAMEN BLANC en liste. Widget PUR : il ne
// connaît PAS `ZWhiteExamSessionEngine` (la garde de pureté interdit l'import) —
// l'hôte pilote le moteur et lui passe `phase`/`cards` en DONNÉES.
//
// 🔒 ZÉRO écriture SRS, par CONSTRUCTION : son ctor n'a AUCUN paramètre
// `reviewer`/`scheduler`/`store` — il n'existe aucun seam à atteindre (AC3).
// 🔒 Toute affordance est gatée par la PHASE ⇒ les `StateError` du moteur
// (double `submit`, `answer` hors `running`) sont INATTEIGNABLES : aucun
// `try-catch` ne les masque.
export 'src/presentation/z_list_session_view.dart';
// SU-4 (AC1/AC10, FR-SU6) — pile de session SWIPEABLE. Le swipe est une
// NAVIGATION : `ZSessionCardSwiper` n'a AUCUN paramètre de qualité/notation/
// reviewer (impossibilité STRUCTURELLE, AD-33/AD-34) — la notation reste aux
// `ZSrsQualityButtons`, composés en FRÈRE par l'hôte, HORS de la pile.
//
// 🔒 CONFINEMENT (NFR-SU7) : ce barrel exporte le widget zcrud, JAMAIS un type
// de `flutter_card_swiper` (`CardSwiper`/`CardSwiperDirection`/
// `CardSwiperController`/`AllowedSwipeDirection`) — le paquet tiers reste privé
// à `src/presentation/z_session_card_swiper.dart` (gardé par
// `test/z_card_swiper_confinement_test.dart`).
export 'src/presentation/z_session_card_swiper.dart';
// SU-5 (AC5, FR-SU9/NFR-SU4) — banques de feedback FR/EN par défaut, EMBARQUÉES
// ici : les tables du cœur sont fermées et hors périmètre (D5), et
// `label(context, key, fallback:)` ne porte qu'UNE langue de repli. La banque
// passe en `fallback:` ⇒ `ZcrudScope(labels:)` de l'app garde la PRIORITÉ. Une
// banque injectée REMPLACE INTÉGRALEMENT la banque par défaut (jamais une fusion).
export 'src/presentation/z_session_feedback_bank.dart';
// SU-4 (AC8, FR-SU7) — indicateurs de progression (variante par ENUM, jamais un
// booléen) + retour émotionnel de drag (animation RÉELLE, dégradée sous Reduce
// Motion). DISTINCT de `ZSessionQualityBreakdown` : par CARTE (position) vs par
// QUALITÉ (agrégat) — cf. dartdoc, arbitrage A3.
// SU-6 (FR-SU10, AC7/AC15) — sélecteur de session : 3 options (« Apprendre +N »
// / « À réviser » / « Test »), badge flamme, lot configurable (défaut 30).
// PRODUIT une file (AD-33), ne démarre AUCUN runtime (AD-34/D7).
export 'src/presentation/z_session_mode_selector.dart';
export 'src/presentation/z_session_progress_indicator.dart';
export 'src/presentation/z_session_quality_breakdown.dart';
// SU-5 (AC1..AC11, FR-SU8/FR-SU9) — écran de FIN de session. Il ASSEMBLE
// (`ZSessionQualityBreakdown` + `ZStudyProgressRings`), il ne réimplémente RIEN.
// 🔴 « maîtrisées » (q4-5, DÉRIVÉ de `byQuality`) n'est PAS `result.correct`
// (q3+) — deux nombres différents, volontairement (D3). La durée est INJECTÉE
// (le VO du kernel ne la porte pas — D4).
//
// 🔒 CONFINEMENT (NFR-SU7) : ce barrel exporte le widget zcrud, JAMAIS un type
// de `confetti` (`ConfettiWidget`/`ConfettiController`/`BlastDirectionality`) —
// le paquet tiers reste privé à `src/presentation/z_session_summary_view.dart`
// (gardé par `test/z_third_party_confinement_test.dart`).
export 'src/presentation/z_session_summary_view.dart';
export 'src/presentation/z_srs_quality_buttons.dart';
// SU-6 (FR-SU11, AC7/AC14) — badge FLAMME (statique : aucune animation factice).
export 'src/presentation/z_streak_badge.dart';
// SU-6 (FR-SU11, AC6) — confirmation de flamme via le port `ZToaster`
// (`zcrud_ui_kit`), JAMAIS un SnackBar en dur. `alreadyCountedToday`/
// `skippedNotGraded` ⇒ AUCUN toast (pas de spam).
export 'src/presentation/z_streak_toast.dart';
export 'src/presentation/z_study_progress_rings.dart';
// SU-3 (AC7, FR-SU4) — `ZTimerDisplay` : le temps est TOUJOURS mesuré ;
// l'affichage suit l'enum (défaut `hidden`).
// SU-6 (FR-SU12, AC10) — dialog de filtres : COMPOSE un `ZFlashcardTestFilters`
// et le rend à l'hôte ; le filtrage EST la fonction pure `zApplyTestFilters`.
export 'src/presentation/z_test_filters_dialog.dart';
export 'src/presentation/z_timer_display.dart';
