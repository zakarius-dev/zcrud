/// Barrel d'API publique de `zcrud_session`.
///
/// Runtime de session d'étude en cycle :
/// - `ZStudySessionEngine` — moteur `ChangeNotifier` pur-Flutter (état
///   immuable + reducer pur), sans aucun gestionnaire d'état (invariant AD-2).
///   Fait progresser la file par `grade`, en réinsérant une carte ratée à un
///   offset déterministe (+2/+4 selon la sévérité du lapse) et en écrivant
///   l'état SRS uniquement via le seam injecté (voie unique, invariant AD-9).
///   Les constantes d'offset (`kLapseOffsetSoft`/`kLapseOffsetHard`) et le
///   reducer pur `reduceGrade` sont exposés pour la testabilité.
/// - `ZSessionState` — instantané immuable de la file et de ses compteurs
///   (`reviewed`/`lapses`/`remaining`/`isComplete`), value-object.
/// - `ZSessionItem` — identité neutre de carte (`{flashcardId, folderId,
///   typeKey?}`) — le moteur ne tire aucun widget flashcard.
/// - `ZSessionReviewer` — seam d'écriture SRS injecté (= `reviewCard` en
///   production).
///
/// API publique = ce barrel ; implémentation sous `lib/src/domain/`. Aucun
/// codegen : l'état de session runtime n'est pas persisté, il n'y a donc pas
/// de `*.g.dart`.
library;

// Soumission advisory émise à l'hôte : cette surface de saisie n'écrit rien
// elle-même, c'est l'hôte qui branche l'écriture SRS sur le seam
// `ZSessionReviewer` (voie unique). Pur-Dart, aucun import Flutter.
export 'src/domain/z_flashcard_submission.dart';
export 'src/domain/z_linear_session_state.dart';
// Sélection pure du feedback pédagogique : `(quality, timeTaken, hintsUsed)`
// → une clé l10n. Pur-Dart, testable hors widget. La qualité passe par
// `config.clampQuality` (voie unique) : aucune note n'est hors seau.
export 'src/domain/z_session_feedback.dart';
export 'src/domain/z_session_item.dart';
export 'src/domain/z_session_reviewer.dart';
// Table unique mode → runtime. Les six modes sont servis par les trois
// runtimes qui existent déjà, aucun n'est créé ici. `switch` exhaustif sans
// `default` : une septième valeur de `ZReviewMode` casse la compilation.
export 'src/domain/z_session_runtime.dart';
export 'src/domain/z_session_state.dart';
export 'src/domain/z_study_session_engine.dart';
export 'src/domain/z_white_exam_session_controller.dart';
export 'src/domain/z_white_exam_session_engine.dart';
// Verdict de réussite d'un examen blanc : le SEUIL est une donnée de
// l'application (`successRatio`), jamais une valeur du socle. Sans seuil
// déclaré, `zWhiteExamVerdictFor` rend `null` — aucun verdict, aucun effet.
export 'src/domain/z_white_exam_verdict.dart';
// Widgets de présentation purs : `StatelessWidget`, aucun gestionnaire
// d'état, callbacks injectés, thème/labels/couleurs injectés.
// - `ZSrsQualityButtons` (+ `ZQualityScale`) : boutons de notation qualité
//   SM-2, mapping cran → qualité dans le widget, intervalle prévisionnel via
//   le seam `previewLabelFor` (projection pure, jamais recalculé).
// - `ZSessionQualityBreakdown` : répartition fidèle de `byQuality` (un
//   segment par clé, aucune omise ni inversée, clé hors échelle signalée à
//   part).
// - `ZStudyProgressRings` (+ `ZProgressRingsData`) : `CustomPaint` pur sur un
//   DTO pré-calculé (`ratio` clampé, `total == 0` donne 0, pas de division
//   par zéro).
// `ZCardAdvanceBehavior` + table unique des défauts par mode
// (`zDefaultAdvanceBehavior`) : jamais redécidée par un widget.
export 'src/presentation/z_card_advance_behavior.dart';
// Régime d'apparition de la correction. Gate de rendu seul (défaut
// `immediate`, comportement historique inchangé) : en `deferred`, la
// correction est posée (donc la saisie reste verrouillée, une réponse par
// carte) mais jamais peinte. Mêler ce gate au verrou d'interaction
// rouvrirait la double soumission.
export 'src/presentation/z_correction_visibility.dart';
// Surface de saisie notée. Aucun tap-to-reveal : la correction est causée
// par la soumission ; le contenu reste sous `IgnorePointer` jusque-là.
// Composée en frère de `ZFlashcardReviewCard` par l'hôte.
export 'src/presentation/z_flashcard_answer_input.dart';
// UI d'examen blanc en liste. Widget pur : il ne connaît pas
// `ZWhiteExamSessionEngine` (une garde de pureté interdit l'import) — l'hôte
// pilote le moteur et lui passe `phase`/`cards` en données.
//
// Zéro écriture SRS, par construction : son constructeur n'a aucun
// paramètre `reviewer`/`scheduler`/`store`, il n'existe aucun seam à
// atteindre. Toute affordance est gatée par la phase, donc les
// `StateError` du moteur (double soumission, réponse hors `running`) sont
// inatteignables : aucun `try-catch` ne les masque.
export 'src/presentation/z_list_session_view.dart';
// Pile de session swipeable. Le swipe est une navigation :
// `ZSessionCardSwiper` n'a aucun paramètre de qualité/notation/reviewer
// (impossibilité structurelle) — la notation reste aux
// `ZSrsQualityButtons`, composés en frère par l'hôte, hors de la pile.
//
// Confinement : ce barrel exporte le widget zcrud, jamais un type de
// `flutter_card_swiper` (`CardSwiper`/`CardSwiperDirection`/
// `CardSwiperController`/`AllowedSwipeDirection`) — le paquet tiers reste
// privé à `src/presentation/z_session_card_swiper.dart`.
export 'src/presentation/z_session_card_swiper.dart';
// Banques de feedback FR/EN par défaut, embarquées ici : les tables du cœur
// sont fermées et hors périmètre de ce paquet, et `label(context, key,
// fallback:)` ne porte qu'une seule langue de repli. La banque passe en
// `fallback:`, si bien que `ZcrudScope(labels:)` de l'application garde la
// priorité. Une banque injectée remplace intégralement la banque par
// défaut, jamais une fusion.
export 'src/presentation/z_session_feedback_bank.dart';
// Indicateurs de progression (variante par enum, jamais un booléen) et
// retour émotionnel de drag (animation réelle, dégradée sous Reduce
// Motion). Distinct de `ZSessionQualityBreakdown` : par carte (position) vs
// par qualité (agrégat) — voir la dartdoc du fichier pour le détail.
// Sélecteur de session : trois options (apprendre de nouvelles cartes, à
// réviser, test), badge flamme, lot configurable (défaut 30). Produit une
// file de session, ne démarre aucun runtime.
export 'src/presentation/z_session_mode_selector.dart';
export 'src/presentation/z_session_progress_indicator.dart';
export 'src/presentation/z_session_quality_breakdown.dart';
// Écran de fin de session. Il assemble `ZSessionQualityBreakdown` et
// `ZStudyProgressRings`, il ne réimplémente rien. « Maîtrisées » (dérivé de
// `byQuality`) n'est pas `result.correct` — deux nombres différents,
// délibérément. La durée est injectée : le value-object du kernel ne la
// porte pas.
//
// Confinement : ce barrel exporte le widget zcrud, jamais un type de
// `confetti` (`ConfettiWidget`/`ConfettiController`/`BlastDirectionality`) —
// le paquet tiers reste privé à `src/presentation/z_session_summary_view.dart`.
export 'src/presentation/z_session_summary_view.dart';
export 'src/presentation/z_srs_quality_buttons.dart';
// Direction LOGIQUE d'un swipe (`start`/`end`, résolues contre la
// `TextDirection` — jamais `left`/`right`, invariant AD-13). C'est un fait de
// geste, pas une évaluation : le seam `ZSessionCardSwiper.onSwipeDirection`
// dit vers où et sur quelle carte, l'hôte décide seul ce que cela veut dire.
export 'src/presentation/z_swipe_direction.dart';
// Badge flamme (statique : aucune animation factice).
export 'src/presentation/z_streak_badge.dart';
// Confirmation de flamme via le port `ZToaster` (`zcrud_ui_kit`), jamais un
// SnackBar en dur. `alreadyCountedToday`/`skippedNotGraded` n'affichent
// aucun toast (pas de spam).
export 'src/presentation/z_streak_toast.dart';
export 'src/presentation/z_study_progress_rings.dart';
// `ZTimerDisplay` : le temps est toujours mesuré ; l'affichage suit l'enum
// (défaut `hidden`).
// Dialog de filtres : compose un `ZFlashcardTestFilters` et le rend à
// l'hôte ; le filtrage est la fonction pure `zApplyTestFilters`.
export 'src/presentation/z_test_filters_dialog.dart';
export 'src/presentation/z_timer_display.dart';
export 'src/presentation/z_white_exam_session_view.dart';
