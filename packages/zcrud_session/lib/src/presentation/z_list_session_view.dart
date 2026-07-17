/// SU-7 (FR-SU13) — UI d'**examen blanc** en liste : `ZListSessionView`.
///
/// # Ce que ce widget est, et ce qu'il n'est PAS
///
/// C'est un widget de **présentation PUR** (D3) : il **ne connaît PAS**
/// `ZWhiteExamSessionEngine`. Il reçoit sa `phase` et ses `cards` **en données**
/// et rend ses décisions à l'hôte par callbacks. Trois raisons, toutes
/// structurelles :
///
/// 1. **La garde l'impose** : `test/presentation/z_widgets_purity_test.dart`
///    bannit l'import de `z_white_exam_session_engine.dart` dans
///    `lib/src/presentation/**`. Un widget qui *détiendrait* le moteur violerait
///    la garde ; un widget qui le *recevrait* devrait l'importer pour le typer —
///    ce qui la violerait aussi. **La vue ne le voit donc jamais.**
/// 2. **ZÉRO écriture SRS, par CONSTRUCTION** (AC3/AD-23) : ce constructeur
///    n'accepte **AUCUN** `reviewer`/`scheduler`/`store`. Il n'y a pas de seam à
///    atteindre — l'absence d'écriture n'est pas un comportement qu'on observe,
///    c'est une propriété du **type**. (Le moteur d'examen n'en a pas davantage :
///    son ctor ne prend que `queue`/`config`/`scorer`, et `ZExamScoringPort`
///    n'expose ni store ni scheduler ⇒ même un scorer tiers ne peut pas écrire.)
/// 3. **Aucun `StateError` possible** (G3/AC6) : le moteur **lève** sur toute
///    transition illégale (`answer` hors `running`, **double `submit`**…). Ce
///    widget ne les **rattrape pas** — 🚫 **aucun `try-catch` autour du moteur** :
///    il rend ces transitions **structurellement inatteignables** en gatant
///    **toute** affordance sur la [phase], jamais sur un booléen local dérivé (un
///    booléen se désynchronise, la phase est la vérité).
///
/// # Rien n'est persisté, jamais (D5, AD-43)
///
/// `ZListSessionView` n'est **pas une surface d'édition** : AD-43 (« brouillon »
/// vs « direct ») **ne la gouverne pas**, car elle **ne persiste RIEN, jamais,
/// par aucun chemin**. Son état vit en mémoire pour la durée du montage. **Il n'y
/// a pas de brouillon** (aucune reprise après abandon) — et c'est un **choix
/// explicite**, pas un oubli : un examen repris est un examen faussé (conditions
/// d'examen). *Aucune écriture SRS à l'abandon : il n'existe aucun chemin
/// d'écriture.*
///
/// # Deux canaux, jamais deux calculs (D4/AD-4)
///
/// - **Agrégat** `{total, correct, byQuality}` ⇐ [result] (= `engine.result`,
///   produit par `scoreWhiteExam`, **producteur unique**). Cette vue **ne
///   recompte JAMAIS** `correct` et ne connaît aucun `passThreshold` de jugement.
/// - **Détail par question** (`isCorrect`/`feedback`) ⇐ les [submissions]
///   mémorisées par l'hôte. Canal **distinct**, jamais un recalcul de l'agrégat.
///
/// # 🔴 Correspondance carte ↔ réponse (AC9) — le risque n°1 de cette story
///
/// `ZSessionItem` (la file du moteur) ne porte **que des identifiants**
/// (`flashcardId`/`folderId`/`typeKey`) — **aucun `ZFlashcard`**. La file du
/// moteur n'est donc **pas rendable** : l'hôte tient **deux listes parallèles**
/// (`items` pour le moteur, `cards` pour la vue). Si elles se désynchronisent, la
/// qualité de la carte **A** est attribuée à la carte **B** : un examen **faux**,
/// par la voie **légitime**, **sans aucune exception**.
///
/// **Mitigation portée par cette API** : [onAnswered] émet **l'INDEX de la carte
/// répondue** en même temps que sa soumission — jamais une qualité anonyme. Et
/// [submissions] est une **`Map` indexée par POSITION dans [cards]**, jamais une
/// liste parallèle de plus : une soumission ne peut pas « glisser » d'un cran au
/// **rang d'arrivée**, puisqu'elle est rangée sous **la position de sa carte**.
///
/// ⚠️ **Portée EXACTE de cette mitigation — ne pas la surestimer.** La clé est
/// une **position**, pas une **identité de carte** (`card.id`). Elle ferme le
/// canal « décalage d'un cran au rang d'arrivée » — elle **ne ferme PAS** le
/// canal « [cards] change sous les clés ». Si la file **rétrécit** ou est
/// **réordonnée**, les clés de l'hôte **périment** : c'est à l'hôte de purger sa
/// `Map` (cf. `didUpdateWidget` de l'`ExamHost` de référence). Cette vue s'en
/// **défend** (elle ignore toute clé hors `[0, cards.length)`, cf. [_unanswered])
/// mais ne peut pas deviner *quelle* carte une clé périmée désignait.
///
/// ⚠️ **L'alignement `answers`/`queue` du MOTEUR n'est PAS gardé par cette API**
/// (hors périmètre — cf. `ZWhiteExamSessionEngine.answer`, dont le contrat est
/// **positionnel** : l'hôte doit soit répondre dans l'ordre, soit n'exploiter que
/// l'**agrégat commutatif**).
///
/// # Une réponse par carte, DÉFINITIVE (D10 — imposé par le moteur)
///
/// `recordAnswer` **ajoute** une réponse et avance le curseur : le moteur **ne
/// sait pas réviser**. ⇒ aucune révision n'est offerte ; une carte répondue est
/// **verrouillée** (le verrou de su-3 le fait déjà, et su-7 le **préserve
/// exactement** : cf. `ZCorrectionVisibility`). L'apprenant peut **sauter** une
/// question (elle reste sans réponse) mais **jamais changer** une réponse donnée.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import '../domain/z_flashcard_submission.dart';
import 'z_correction_visibility.dart';
import 'z_flashcard_answer_input.dart';
import 'z_session_progress_indicator.dart';
import 'z_session_summary_view.dart';

/// Phase d'examen **telle que la vue la consomme** — miroir 1:1 de
/// `ZWhiteExamPhase` (domaine).
///
/// ⚠️ **Pourquoi un type distinct plutôt que `ZWhiteExamPhase` directement** :
/// `ZWhiteExamPhase` est déclaré dans `z_white_exam_session_engine.dart`, dont
/// l'import est **banni** dans `lib/src/presentation/**` par
/// `z_widgets_purity_test.dart` (le fichier porte le moteur ET l'enum). Importer
/// l'enum importerait le moteur. Ce miroir est le **prix de la pureté** (D3) :
/// l'hôte fait la conversion, qui est **totale** et sans perte.
enum ZExamViewPhase {
  /// L'examen n'a pas démarré : aucune saisie, aucune soumission.
  setup,

  /// Examen en cours : les cartes non répondues sont saisissables ; la
  /// soumission est offerte.
  running,

  /// Examen soumis et **figé** : la correction est révélée, plus aucune saisie,
  /// **aucune affordance de soumission** (⇒ le double `submit()` — qui lèverait
  /// `StateError` — est **inatteignable**).
  submitted,
}

/// Callback de réponse : la carte d'index [index] a émis [submission].
///
/// 🔒 **L'index est LÀ EXPRÈS** (AC9) : l'hôte doit pouvoir ranger la soumission
/// **sous sa carte** et vérifier son alignement avec la file du moteur. Une
/// signature qui n'émettrait que la qualité rendrait la désynchronisation
/// **indétectable**.
typedef ZExamAnswerCallback =
    void Function(int index, ZFlashcardSubmission submission);

/// UI d'**examen blanc** en liste (FR-SU13).
class ZListSessionView extends StatelessWidget {
  /// Construit la vue d'examen.
  ///
  /// 🚫 **AUCUN paramètre `reviewer`/`scheduler`/`store`** — c'est l'AC3(a), et
  /// c'est **structurel** : il n'existe aucun endroit où brancher une écriture
  /// SRS. Cette absence est gardée par `z_list_session_view_no_srs_test.dart`
  /// (scan du ctor RÉEL sur disque) **et** par `z_widgets_purity_test.dart`.
  const ZListSessionView({
    required this.cards,
    required this.phase,
    required this.onAnswered,
    required this.onSubmit,
    this.submissions = const <int, ZFlashcardSubmission>{},
    this.result,
    this.config = const ZSrsConfig(),
    this.duration = Duration.zero,
    this.onFinish,
    this.contentBuilder,
    this.evaluationPort,
    super.key,
  });

  /// File **DÉJÀ sélectionnée** (AD-33 : **aucun re-filtrage ici**).
  ///
  /// La sélection (filtres de su-6, mélange des choix) est un fait **AMONT**,
  /// produit par `ZStudySessionConfig`/`ZStudySessionSelector`. Câbler
  /// `zApplyTestFilters`/`zShuffleChoices` ici ferait de cette vue un **second
  /// sélecteur** — exactement ce qu'AD-33 interdit (D6).
  final List<ZFlashcard> cards;

  /// Phase courante — 🔒 l'**UNIQUE** gate des affordances (G3/AC6).
  final ZExamViewPhase phase;

  /// Émis quand une carte est répondue — porte **l'index de SA carte** (AC9).
  final ZExamAnswerCallback onAnswered;

  /// Demande de soumission finale (l'hôte fait `engine.submit()`).
  final VoidCallback onSubmit;

  /// Soumissions mémorisées, **indexées par POSITION dans [cards]** (jamais par
  /// rang d'arrivée).
  ///
  /// Alimente la révélation de fin (canal `isCorrect`/`feedback`, D4) et le
  /// compte des questions **sans réponse**.
  ///
  /// 🔒 **AD-10 — cette vue ne fait PAS confiance à l'hôte** : elle est publique
  /// (exportée au barrel), donc toute clé **hors `[0, cards.length)`** (une clé
  /// **périmée** laissée par un hôte qui n'a pas purgé après un rétrécissement de
  /// file) est **ignorée**, jamais comptée. Cf. [_unanswered].
  final Map<int, ZFlashcardSubmission> submissions;

  /// Agrégat **INJECTÉ** (= `engine.result`) — 🔒 **jamais recalculé** (AC4/D4).
  /// `null` hors phase [ZExamViewPhase.submitted].
  final ZStudySessionResult? result;

  /// Config SRS — source **UNIQUE** de l'échelle et du seuil (AD-46).
  /// 🔒 **Jamais** une échelle redéclarée, **jamais** un clamp réécrit.
  final ZSrsConfig config;

  /// Durée de l'examen — **INJECTÉE** (le VO du kernel ne la porte pas, su-5/D4).
  final Duration duration;

  /// Callback « Terminer » de l'écran de fin.
  final VoidCallback? onFinish;

  /// Slot AD-40 de rendu du contenu, relayé **verbatim** à chaque carte.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Port d'évaluation ADVISORY, relayé **verbatim** à chaque carte.
  ///
  /// 🔒 **Jamais appelé** pour un QCM/Vrai-Faux (AD-35) : l'évaluation locale est
  /// déterministe et vit dans su-3 — su-7 n'en réimplémente **aucune**.
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Clé du bouton de soumission finale.
  static const ValueKey<String> submitKey = ValueKey<String>('zExamSubmit');

  /// Clé du bouton de confirmation du dialog (D7).
  static const ValueKey<String> confirmKey = ValueKey<String>(
    'zExamSubmitConfirm',
  );

  /// Clé du bouton d'annulation du dialog (D7).
  static const ValueKey<String> cancelKey = ValueKey<String>(
    'zExamSubmitCancel',
  );

  /// Clé de l'état vide.
  static const ValueKey<String> emptyKey = ValueKey<String>('zExamEmpty');

  /// Clé du nœud **région live** portant le résultat de fin d'examen (AD-13).
  static const ValueKey<String> resultKey = ValueKey<String>('zExamResult');

  /// Clé du **nœud sémantique** du compte de questions sans réponse.
  static const ValueKey<String> unansweredKey = ValueKey<String>(
    'zExamUnanswered',
  );

  /// Clé du **texte visible** du compte de questions sans réponse.
  ///
  /// 🔴 Deux clés parce qu'il y a **deux canaux** à garder séparément (AD-13) :
  /// un test qui n'en observerait qu'un laisserait passer le défaut su-6 (un
  /// nombre annoncé au lecteur d'écran mais affiché **nulle part**).
  static const ValueKey<String> unansweredTextKey = ValueKey<String>(
    'zExamUnansweredText',
  );

  /// Préfixe de clé d'une question (testabilité + identité stable).
  static const String questionKeyPrefix = 'zExamQuestion_';

  /// Nombre de questions **sans réponse** — dérivé, jamais tenu en double.
  ///
  /// 🔴 **Le filtre de bornes N'EST PAS décoratif** (défaut MESURÉ, AD-10) :
  /// [submissions] est indexée par **position**. Si l'hôte ne purge pas sa `Map`
  /// quand la file **rétrécit** (le chemin qu'AC6 exige explicitement), les clés
  /// **périmées** survivent : 3 clés `{0,1,2}` contre 1 carte neuve **vierge**
  /// donnaient `1 - 3 = -2` ⇒ **« -2 questions sans réponse »** affiché à
  /// l'apprenant, annoncé au lecteur d'écran (`Semantics(value:'-2')`), et
  /// **répété dans le dialog de confirmation** — au moment le plus irréversible
  /// du parcours, sans **aucune** exception pour le signaler.
  int get _unanswered => cards.length - _answeredInRange;

  /// Réponses dont la clé désigne **réellement** une carte de [cards] — les
  /// clés périmées d'un hôte qui n'a pas purgé sont **ignorées** (AD-10).
  int get _answeredInRange =>
      submissions.keys.where((k) => k >= 0 && k < cards.length).length;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    // 🔒 AD-10 — examen VIDE : état l10n, et **AUCUNE** affordance de soumission
    // (absente, jamais grisée — patron AD-45/`ZItemActionsMenu`). `submit()` sur
    // une file vide serait pourtant LÉGAL côté moteur et produirait `total: 0` :
    // on ne le propose donc pas, plutôt que de le griser.
    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.gapL),
          child: Text(
            label(
              context,
              'zcrud.study.exam.empty',
              fallback: 'Aucune question dans cet examen',
            ),
            key: emptyKey,
            textAlign: TextAlign.start,
          ),
        ),
      );
    }

    final submitted = phase == ZExamViewPhase.submitted;

    // 🔒 D8 (patron su-4 `_queueGeneration`) : l'identité de la LISTE dérive de
    // celle de la FILE. Quand la file change (elle rétrécit, notamment), la
    // sous-arborescence est reconstruite au lieu d'être réconciliée sur des
    // index périmés — c'est ce qui a évité le `RangeError` en su-4.
    //
    // ⚠️ **Coût HONNÊTE** : ce parcours est **O(N) à chaque `build` de la vue**
    // (soit à chaque réponse) — la virtualisation vantée plus bas est réelle
    // pour le `ListView`, mais **elle ne couvre pas cette clé**, qui touche les
    // N cartes systématiquement. Non-régression SM-1 (AC8) : `build` ne tourne
    // **pas à la frappe** (l'état de saisie vit dans `ZFlashcardAnswerInput`),
    // donc l'objectif produit n°1 n'est pas menacé. Consigné, non optimisé.
    final queueKey = ValueKey<String>(
      'zExamQueue_${cards.length}_${cards.map((c) => c.id ?? c.question).join('|')}',
    );

    return Column(
      key: queueKey,
      children: <Widget>[
        _ProgressHeader(
          cards: cards,
          answered: _answeredInRange,
          submissions: submissions,
          config: config,
        ),
        Expanded(
          // 🔒 `ListView.builder` — **JAMAIS** `ListView(children: [...])`
          // (AD-13/garde) : un examen peut porter des centaines de questions ;
          // seules les visibles sont construites.
          child: ListView.builder(
            // +1 : en phase soumise, l'écran de fin (su-5) est la PREMIÈRE
            // entrée de la liste — il n'est donc construit que s'il est visible.
            itemCount: cards.length + (submitted ? 1 : 0),
            itemBuilder: (context, i) {
              if (submitted && i == 0) return _summary(context);
              final index = submitted ? i - 1 : i;
              return _question(context, index);
            },
          ),
        ),
        if (phase == ZExamViewPhase.running) _submitBar(context),
      ],
    );
  }

  /// Écran de fin — 🔒 **`ZSessionSummaryView` (su-5)**, jamais un écran réécrit,
  /// alimenté par l'agrégat **INJECTÉ** ([result]) — **zéro recomptage** (AC4).
  Widget _summary(BuildContext context) {
    final aggregate = result;
    // 🔒 AD-10 — phase soumise sans résultat (état incohérent) : on n'invente
    // aucun agrégat et on ne lève rien ; la correction par question reste, elle,
    // pleinement lisible.
    if (aggregate == null) return const SizedBox.shrink();
    // 🔴 `liveRegion` — défaut MESURÉ : au passage en `submitted`, l'écran de
    // fin est inséré **à l'index 0 de la `ListView`**, c'est-à-dire AU-DESSUS de
    // la position de lecture courante. Sans région live, **rien n'était
    // annoncé** : le focus restait près du bas de la liste et l'apprenant
    // non-voyant devait **deviner** que son examen avait été noté, puis remonter
    // toute la liste à l'aveugle pour trouver son score. Or le résultat est
    // précisément l'information qu'il attend à cet instant.
    return Semantics(
      key: resultKey,
      liveRegion: true,
      child: ZSessionSummaryView(
        result: aggregate,
        duration: duration,
        config: config,
        onFinish: onFinish ?? () {},
      ),
    );
  }

  /// Une question de l'examen.
  Widget _question(BuildContext context, int index) {
    final theme = ZcrudTheme.of(context);
    final card = cards[index];
    final submission = submissions[index];
    final submitted = phase == ZExamViewPhase.submitted;

    return Padding(
      key: ValueKey<String>('$questionKeyPrefix$index'),
      padding: EdgeInsetsDirectional.all(theme.gapM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 🔒 La saisie est celle de su-3 — **JAMAIS une saisie réécrite** :
          // l'évaluation locale QCM/VF (AD-35), les indices (AD-36), le minuteur
          // et les DEUX verrous (`onTap`/`_submitLocked`) sont hérités tels quels.
          //
          // 🔒 Gatée par la PHASE (G3) : hors `running`, `IgnorePointer` rend la
          // saisie inerte — aucune réponse ne peut donc partir vers le moteur
          // avant `start()` ou après `submit()`, où `answer()` LÈVERAIT.
          IgnorePointer(
            ignoring: phase != ZExamViewPhase.running,
            child: ZFlashcardAnswerInput(
              // 🔒 Identité STABLE par carte (SM-1/AC8) : sans elle, un
              // changement de file réconcilierait l'état d'une carte sur une
              // autre — la classe de défaut que le jeton `_generation` de su-3 a
              // dû fermer.
              //
              // 🔴 Les deux replis sont dans des **espaces de noms DISJOINTS**
              // (`id:` / `ix:`) — défaut AD-10 réel : `ZFlashcard.id` est
              // **nullable** (« opaque, nullable pour l'éphémère »), donc un
              // examen mêlant cartes persistées et éphémères où une carte porte
              // `id == '3'` et où la carte d'**index 3** a `id == null`
              // produisait **deux `ValueKey('zExamQuestion_3')` FRÈRES** dans le
              // même `ListView.builder` ⇒ Flutter **lève** « Duplicate keys
              // found ». Le préfixe rend la collision impossible **par
              // construction**, sans sacrifier la stabilité par `id`.
              key: ValueKey<String>(
                '$questionKeyPrefix${card.id != null ? 'id:${card.id}' : 'ix:$index'}',
              ),
              card: card,
              mode: ZReviewMode.whiteExam,
              srsConfig: config,
              contentBuilder: contentBuilder,
              evaluationPort: evaluationPort,
              // 🔴 LE gate de su-7 (D2) : la carte **ne rend JAMAIS** sa
              // correction. Elle la **pose** quand même ⇒ la saisie se
              // **verrouille** (une réponse par carte, D10) et `_submitLocked`
              // reste armé. C'est la révélation de fin, ci-dessous, qui peint —
              // depuis les `submissions` mémorisées (D4).
              correctionVisibility: ZCorrectionVisibility.deferred,
              // 🔒 AC9 — on émet l'INDEX de CETTE carte, capturé ici, jamais un
              // curseur partagé ni un rang d'arrivée.
              onSubmitted: (submission) => onAnswered(index, submission),
            ),
          ),
          if (submitted) ...<Widget>[
            SizedBox(height: theme.gapM),
            _CorrectionReveal(index: index, submission: submission),
          ],
        ],
      ),
    );
  }

  /// Barre de soumission finale — présente **uniquement** en `running` (le gate
  /// est la PHASE : en `submitted`, l'affordance n'existe pas ⇒ le double
  /// `submit()` est **inatteignable**, et le `StateError` du moteur n'est jamais
  /// provoqué. 🚫 Aucun `try-catch` n'est requis, ni permis.
  Widget _submitBar(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final unanswered = _unanswered;
    return Padding(
      padding: EdgeInsetsDirectional.all(theme.gapM),
      child: Row(
        children: <Widget>[
          // 🔴 Leçon su-6 (« un seul canal observé ») : le nombre de questions
          // sans réponse est porté **À LA FOIS** par le TEXTE VISIBLE et par
          // `Semantics(value:)`. Le streak de su-6 n'existait que dans
          // `Semantics(value:)` — invisible à l'œil, et son test était VERT.
          Expanded(
            child: Semantics(
              key: unansweredKey,
              label: label(
                context,
                'zcrud.study.exam.unanswered',
                fallback: 'Questions sans réponse',
              ),
              value: '$unanswered',
              // 🔴 `ExcludeSemantics` — défaut MESURÉ (rejeu exact du D1 de
              // su-5) : sans lui, le `Text` enfant FUSIONNE avec le `Semantics`
              // parent et le nœud annonce « Questions sans réponse\n2 — valeur :
              // 2 » : le lecteur d'écran **bégaie**. Le sens est porté par le
              // `Semantics` (canal unique) ; le `Text` n'est que le canal
              // VISUEL du même contenu.
              child: ExcludeSemantics(
                child: Text(
                  '$unanswered',
                  key: unansweredTextKey,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ),
          _ExamButton(
            buttonKey: submitKey,
            text: label(
              context,
              'zcrud.study.exam.submit',
              fallback: 'Soumettre',
            ),
            onPressed: () => _confirmSubmit(context, unanswered),
          ),
        ],
      ),
    );
  }

  /// Dialog de confirmation (D7) — un examen soumis est **irréversible**
  /// (`submitted` n'a **aucune** transition sortante) ⇒ confirmation explicite,
  /// **mentionnant le nombre de questions sans réponse**.
  ///
  /// 🔴 **Les libellés sont résolus ICI, dans le contexte de la VUE — jamais
  /// dans celui du dialog** (défaut RÉEL, mesuré par l'énumération a11y AC14 de
  /// su-7, qui rendait `'Confirmer'` au lieu du libellé injecté).
  ///
  /// **Pourquoi** : `showDialog` monte son contenu sur une **nouvelle route**,
  /// dont le contexte est enraciné au `Navigator` — c'est-à-dire **AU-DESSUS**
  /// du `ZcrudScope` de l'app. Un `label(dialogContext, …)` ne voit donc
  /// **aucun** `ZcrudLabels` et retombe **toujours** sur son `fallback`
  /// français : une app anglophone aurait affiché « Confirmer »/« Annuler », en
  /// silence, sans qu'aucune garde de libellés en dur ne bronche (le fallback
  /// **est** du français légitime côté source).
  ///
  /// Le patron retenu est celui, **déjà sanctionné**, de `_StatTile`
  /// (`z_session_summary_view.dart`) : *« `labelText` est DÉJÀ résolu par
  /// `label(context, …)` chez l'appelant — aucun littéral ne transite »*.
  Future<void> _confirmSubmit(BuildContext context, int unanswered) async {
    final unansweredLabel = label(
      context,
      'zcrud.study.exam.unanswered',
      fallback: 'Questions sans réponse',
    );
    final cancelText = label(
      context,
      'zcrud.study.exam.submit.cancel',
      fallback: 'Annuler',
    );
    final confirmText = label(
      context,
      'zcrud.study.exam.submit.confirm',
      fallback: 'Confirmer',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Semantics(
          label: unansweredLabel,
          value: '$unanswered',
          child: ExcludeSemantics(
            child: Text('$unanswered', textAlign: TextAlign.start),
          ),
        ),
        actions: <Widget>[
          _ExamButton(
            buttonKey: cancelKey,
            text: cancelText,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          _ExamButton(
            buttonKey: confirmKey,
            text: confirmText,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed ?? false) onSubmit();
  }
}

/// En-tête de progression — 🔒 **`ZSessionProgressIndicator` (su-4)**, jamais un
/// compteur parallèle réécrit.
///
/// 🔴 **Cet en-tête RELAIE, il ne PUBLIE PAS** (AC1 : « la progression vient de
/// `ZSessionProgressIndicator`, **aucun compteur parallèle** »). Il enveloppait
/// le composant dans un **second `Semantics(label:, value:)`** — défaut MESURÉ :
/// `ZSessionProgressIndicator` **porte DÉJÀ** son nœud (`progressKey`), si bien
/// que deux nœuds annonçaient **deux nombres qui n'étaient jamais d'accord**
/// (su-7 comptait `submissions.length` = réponses données ; su-4 compte
/// `(currentIndex+1).clamp(1,total)` = position courante) :
///
/// | Phase | Nœud enveloppant (su-7) | Nœud du composant (su-4) |
/// |---|---|---|
/// | `running`, 0 répondue | `0/2` | `1/2` |
/// | `submitted`, 1 répondue | `1/2` | `2/2` |
///
/// Un apprenant non-voyant entendait « Progression de l'examen, 0 sur 2 » puis,
/// au nœud suivant, « Progression, 1 sur 2 » — sans moyen de savoir lequel est
/// vrai. ⇒ **UN seul nœud de progression, portant UN seul nombre**, celui du
/// composant. (La clé `zcrud.study.exam.progress` disparaît avec lui : un nœud
/// unique porte un libellé unique, `zcrud.session.progress`.)
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.cards,
    required this.answered,
    required this.submissions,
    required this.config,
  });

  final List<ZFlashcard> cards;

  /// Nombre de réponses **dans les bornes** de [cards] (AD-10 — cf.
  /// `ZListSessionView._answeredInRange` : une clé périmée ne doit pas faire
  /// avancer la progression).
  final int answered;

  final Map<int, ZFlashcardSubmission> submissions;
  final ZSrsConfig config;

  @override
  Widget build(BuildContext context) {
    return ZSessionProgressIndicator(
      total: cards.length,
      currentIndex: answered,
      // 🔒 Seuil **CONSOMMÉ** de la config (AD-46) — jamais un `3` littéral.
      passThreshold: config.passThreshold,
      // 🔒 Seam « qualité de la carte i » : lu **sous SA carte** (AC9).
      qualityOf: (index) => submissions[index]?.quality,
    );
  }
}

/// Révélation de la correction d'**UNE** question, en phase soumise (D4).
///
/// 🔒 Le canal est **NON-COLORÉ** (AD-13) : une **FORME** (✓/✗) porte la vérité,
/// jamais la seule couleur — aligné sur `_ChoiceRow`/`_tfButton` de su-3.
class _CorrectionReveal extends StatelessWidget {
  const _CorrectionReveal({required this.index, required this.submission});

  final int index;
  final ZFlashcardSubmission? submission;

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    // 🔒 AD-10 — une question **sautée** n'a pas de soumission : elle n'est
    // **PAS** comptée comme fausse (elle n'est pas dans `answers` du moteur ⇒
    // elle ne pèse pas sur `total`). On le **dit**, on n'invente aucune qualité.
    if (sub == null) {
      return Text(
        label(
          context,
          'zcrud.study.exam.noAnswer',
          fallback: 'Sans réponse',
        ),
        textAlign: TextAlign.start,
      );
    }
    // 🔒 `isCorrect` est **nullable** (une réponse rédigée sans port
    // d'évaluation n'a pas de vérité locale) : on n'affirme alors NI correct NI
    // incorrect — jamais un `!`, jamais un faux verdict.
    final isCorrect = sub.isCorrect;
    final statusText = isCorrect == null
        ? null
        : (isCorrect
              ? label(context, 'zcrud.flashcard.correct', fallback: 'correct')
              : label(
                  context,
                  'zcrud.flashcard.incorrect',
                  fallback: 'incorrect',
                ));

    return MergeSemantics(
      // 🔒 Le verdict est **ASSOCIÉ à SA question** (leçon D2 de su-2 : un
      // marqueur détaché s'attache à la mauvaise question et **enseigne une
      // erreur** à un utilisateur non-voyant).
      child: Semantics(
        value: statusText,
        // 🔴 `ExcludeSemantics` sur le `Text` du verdict — défaut MESURÉ
        // (`label="correct\nBIEN" value="correct"` ⇒ « correct, BIEN — valeur :
        // correct » : le verdict est prononcé **DEUX FOIS**). `MergeSemantics`
        // fusionne le sous-arbre : le `Text(statusText)` alimentait le `label`
        // pendant que `Semantics(value:)` alimentait la `value`, **avec la même
        // chaîne**. C'est le D1 de su-5 rejoué sur le nœud le plus important de
        // la story — celui qui porte le **verdict** (raison d'être de FR-SU13).
        //
        // 🔒 Le `feedback`, lui, N'EST PAS exclu : c'est un contenu **distinct**
        // du verdict, jamais un doublon — il doit rester annoncé.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isCorrect != null)
              Icon(isCorrect ? Icons.check_circle : Icons.cancel),
            if (statusText != null)
              ExcludeSemantics(
                child: Text(statusText, textAlign: TextAlign.start),
              ),
            if (sub.feedback != null)
              Expanded(child: Text(sub.feedback!, textAlign: TextAlign.start)),
          ],
        ),
      ),
    );
  }
}

/// Bouton d'examen — 🔒 cible ≥ 48 dp (AD-13) et `Semantics(label:)` issu de
/// `ZcrudLabels`.
///
/// 🔒 [text] est **DÉJÀ résolu** par `label(context, …)` chez l'appelant —
/// **aucun littéral ne transite** (patron `_StatTile` de su-5). C'est ce qui
/// permet au **dialog** (dont le contexte est au-dessus du `ZcrudScope`, cf.
/// `_confirmSubmit`) de porter les libellés **injectés par l'app**.
class _ExamButton extends StatelessWidget {
  const _ExamButton({
    required this.buttonKey,
    required this.text,
    required this.onPressed,
  });

  final ValueKey<String> buttonKey;

  /// Libellé **déjà localisé** par l'appelant.
  final String text;
  final VoidCallback? onPressed;

  /// Cible tap minimale (AD-13).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) => Semantics(
    key: buttonKey,
    button: true,
    label: text,
    // 🔴 `onTap` — défaut MESURÉ (`hasTapAction=false` sur les TROIS boutons).
    // L'`ExcludeSemantics` ci-dessous engloutit **tout** le sous-arbre,
    // `TextButton` **inclus** : il supprime donc aussi sa `SemanticsAction.tap`.
    // Le nœud s'annonçait « bouton » **sans aucune action** ⇒ TalkBack/VoiceOver
    // n'exposaient pas `ACTION_CLICK` : un apprenant non-voyant ne pouvait ni
    // soumettre son examen, ni sortir du dialog de confirmation (`confirmKey` ET
    // `cancelKey` inactivables ⇒ modale sans issue).
    //
    // ⚠️ La transplantation du patron `_StatTile` (su-5/D1) sans sa précondition
    // est la cause racine : `_StatTile` est une tuile **NON INTERACTIVE** —
    // y exclure la sémantique de l'enfant ne coûte rien. Ici, elle coûtait la
    // seule chose qui rend le bouton utilisable. L'action est donc **portée par
    // le nœud qui porte le rôle**.
    onTap: onPressed,
    // 🔴 `ExcludeSemantics` — même défaut que `_StatTile` (su-5/D1) : sans lui
    // le `Text` de l'enfant fusionne et le nœud annonce le libellé DEUX FOIS.
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minTarget,
          minHeight: minTarget,
        ),
        child: TextButton(
          onPressed: onPressed,
          child: Text(text, textAlign: TextAlign.start),
        ),
      ),
    ),
  );
}
