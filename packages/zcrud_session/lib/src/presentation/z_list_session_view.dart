/// UI d'examen blanc en liste : `ZListSessionView`.
///
/// # Ce que ce widget est, et ce qu'il n'est pas
///
/// C'est un widget de présentation pur : il ne connaît pas
/// `ZWhiteExamSessionEngine`. Il reçoit sa `phase` et ses `cards` en données
/// et rend ses décisions à l'hôte par callbacks. Trois raisons, toutes
/// structurelles :
///
/// 1. une garde de pureté du paquet bannit l'import du fichier du moteur
///    dans `lib/src/presentation/**`. Un widget qui détiendrait le moteur
///    violerait cette garde ; un widget qui le recevrait devrait l'importer
///    pour le typer — ce qui la violerait aussi. La vue ne le voit donc
///    jamais ;
/// 2. zéro écriture SRS, par construction : ce constructeur n'accepte aucun
///    `reviewer`/`scheduler`/`store`. Il n'y a pas de seam à atteindre —
///    l'absence d'écriture n'est pas un comportement qu'on observe, c'est
///    une propriété du type (le moteur d'examen n'en a pas davantage : son
///    constructeur ne prend que `queue`/`config`/`scorer`, et
///    `ZExamScoringPort` n'expose ni store ni scheduler, donc même un
///    scorer tiers ne peut pas écrire) ;
/// 3. aucun `StateError` possible : le moteur lève sur toute transition
///    illégale (`answer` hors `running`, double `submit`…). Ce widget ne
///    les rattrape pas — aucun `try-catch` autour du moteur : il rend ces
///    transitions structurellement inatteignables en gatant toute
///    affordance sur la [phase], jamais sur un booléen local dérivé (un
///    booléen se désynchronise, la phase est la vérité).
///
/// # Rien n'est persisté, jamais
///
/// `ZListSessionView` n'est pas une surface d'édition avec brouillon : elle
/// ne persiste rien, jamais, par aucun chemin. Son état vit en mémoire pour
/// la durée du montage. Il n'y a pas de brouillon (aucune reprise après
/// abandon) — et c'est un choix explicite, pas un oubli : un examen repris
/// est un examen faussé. Aucune écriture SRS à l'abandon : il n'existe
/// aucun chemin d'écriture.
///
/// # Deux canaux, jamais deux calculs
///
/// - agrégat `{total, correct, byQuality}` issu de [result] (= `engine.result`,
///   produit par `scoreWhiteExam`, producteur unique). Cette vue ne recompte
///   jamais `correct` et ne connaît aucun `passThreshold` de jugement ;
/// - détail par question (`isCorrect`/`feedback`) issu des [submissions]
///   mémorisées par l'hôte. Canal distinct, jamais un recalcul de l'agrégat.
///
/// # Correspondance carte ↔ réponse — le risque principal de cette surface
///
/// `ZSessionItem` (la file du moteur) ne porte que des identifiants
/// (`flashcardId`/`folderId`/`typeKey`), aucun `ZFlashcard`. La file du
/// moteur n'est donc pas directement rendable : l'hôte tient deux listes
/// parallèles (`items` pour le moteur, `cards` pour la vue). Si elles se
/// désynchronisent, la qualité de la carte A est attribuée à la carte B :
/// un examen faux, par la voie légitime, sans aucune exception.
///
/// Mitigation portée par cette API : [onAnswered] émet l'index de la carte
/// répondue en même temps que sa soumission — jamais une qualité anonyme.
/// Et [submissions] est une `Map` indexée par position dans [cards], jamais
/// une liste parallèle de plus : une soumission ne peut pas glisser d'un
/// cran au rang d'arrivée, puisqu'elle est rangée sous la position de sa
/// carte.
///
/// Portée exacte de cette mitigation, à ne pas surestimer : la clé est une
/// position, pas une identité de carte (`card.id`). Elle ferme le canal
/// « décalage d'un cran au rang d'arrivée » — elle ne ferme pas le canal
/// « [cards] change sous les clés ». Si la file rétrécit ou est
/// réordonnée, les clés de l'hôte périment : c'est à l'hôte de purger sa
/// `Map`. Cette vue s'en défend (elle ignore toute clé hors
/// `[0, cards.length)`, voir [_unanswered]) mais ne peut pas deviner quelle
/// carte une clé périmée désignait.
///
/// L'alignement `answers`/`queue` du moteur n'est pas gardé par cette API
/// (hors périmètre — voir `ZWhiteExamSessionEngine.answer`, dont le contrat
/// est positionnel : l'hôte doit soit répondre dans l'ordre, soit
/// n'exploiter que l'agrégat commutatif).
///
/// # Une réponse par carte, définitive
///
/// `recordAnswer` ajoute une réponse et avance le curseur : le moteur ne
/// sait pas réviser. Aucune révision n'est donc offerte ; une carte
/// répondue est verrouillée (voir `ZCorrectionVisibility`). L'apprenant
/// peut sauter une question (elle reste sans réponse) mais jamais changer
/// une réponse donnée.
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

/// Phase d'examen telle que la vue la consomme — miroir 1:1 de
/// `ZWhiteExamPhase` (domaine).
///
/// Pourquoi un type distinct plutôt que `ZWhiteExamPhase` directement :
/// `ZWhiteExamPhase` est déclaré dans le même fichier que le moteur, dont
/// l'import est banni dans `lib/src/presentation/**` par une garde de
/// pureté. Importer l'enum importerait le moteur. Ce miroir est le prix de
/// la pureté : l'hôte fait la conversion, qui est totale et sans perte.
enum ZExamViewPhase {
  /// L'examen n'a pas démarré : aucune saisie, aucune soumission.
  setup,

  /// Examen en cours : les cartes non répondues sont saisissables ; la
  /// soumission est offerte.
  running,

  /// Examen soumis et figé : la correction est révélée, plus aucune saisie,
  /// aucune affordance de soumission (donc le double `submit()`, qui
  /// lèverait `StateError`, est inatteignable).
  submitted,
}

/// Callback de réponse : la carte d'index [index] a émis [submission].
///
/// L'index est là exprès : l'hôte doit pouvoir ranger la soumission sous sa
/// carte et vérifier son alignement avec la file du moteur. Une signature
/// qui n'émettrait que la qualité rendrait la désynchronisation indétectable.
typedef ZExamAnswerCallback =
    void Function(int index, ZFlashcardSubmission submission);

/// UI d'examen blanc en liste.
class ZListSessionView extends StatelessWidget {
  /// Construit la vue d'examen.
  ///
  /// Aucun paramètre `reviewer`/`scheduler`/`store` — c'est structurel : il
  /// n'existe aucun endroit où brancher une écriture SRS. Cette absence est
  /// gardée par un scan du constructeur réel sur disque et par une garde de
  /// pureté générale.
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

  /// File déjà sélectionnée — aucun re-filtrage ici.
  ///
  /// La sélection (filtres, mélange des choix) est un fait amont, produit
  /// par `ZStudySessionConfig`/`ZStudySessionSelector`. Câbler un filtrage
  /// ou un mélange ici ferait de cette vue un second sélecteur — exactement
  /// ce que l'invariant AD-1 interdit.
  final List<ZFlashcard> cards;

  /// Phase courante — l'unique gate des affordances.
  final ZExamViewPhase phase;

  /// Émis quand une carte est répondue — porte l'index de sa carte.
  final ZExamAnswerCallback onAnswered;

  /// Demande de soumission finale (l'hôte fait `engine.submit()`).
  final VoidCallback onSubmit;

  /// Soumissions mémorisées, indexées par position dans [cards] (jamais par
  /// rang d'arrivée).
  ///
  /// Alimente la révélation de fin (canal `isCorrect`/`feedback`) et le
  /// compte des questions sans réponse.
  ///
  /// Défensif (invariant AD-10) : cette vue ne fait pas confiance à l'hôte —
  /// elle est publique, donc toute clé hors `[0, cards.length)` (une clé
  /// périmée laissée par un hôte qui n'a pas purgé après un rétrécissement
  /// de file) est ignorée, jamais comptée. Voir [_unanswered].
  final Map<int, ZFlashcardSubmission> submissions;

  /// Agrégat injecté (= `engine.result`) — jamais recalculé. `null` hors
  /// phase [ZExamViewPhase.submitted].
  final ZStudySessionResult? result;

  /// Config SRS — source unique de l'échelle et du seuil. Jamais une
  /// échelle redéclarée, jamais un clamp réécrit.
  final ZSrsConfig config;

  /// Durée de l'examen — injectée (le value-object du kernel ne la porte pas).
  final Duration duration;

  /// Callback « Terminer » de l'écran de fin.
  final VoidCallback? onFinish;

  /// Slot de rendu du contenu, relayé verbatim à chaque carte.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Port d'évaluation advisory, relayé verbatim à chaque carte.
  ///
  /// Jamais appelé pour un QCM/Vrai-Faux : l'évaluation locale est
  /// déterministe et vit dans la surface de saisie — cette vue n'en
  /// réimplémente aucune.
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Clé du bouton de soumission finale.
  static const ValueKey<String> submitKey = ValueKey<String>('zExamSubmit');

  /// Clé du bouton de confirmation du dialog.
  static const ValueKey<String> confirmKey = ValueKey<String>(
    'zExamSubmitConfirm',
  );

  /// Clé du bouton d'annulation du dialog.
  static const ValueKey<String> cancelKey = ValueKey<String>(
    'zExamSubmitCancel',
  );

  /// Clé de l'état vide.
  static const ValueKey<String> emptyKey = ValueKey<String>('zExamEmpty');

  /// Clé du nœud région live portant le résultat de fin d'examen (invariant
  /// AD-13).
  static const ValueKey<String> resultKey = ValueKey<String>('zExamResult');

  /// Clé du nœud sémantique du compte de questions sans réponse.
  static const ValueKey<String> unansweredKey = ValueKey<String>(
    'zExamUnanswered',
  );

  /// Clé du texte visible du compte de questions sans réponse.
  ///
  /// Deux clés parce qu'il y a deux canaux à garder séparément : un test qui
  /// n'en observerait qu'un laisserait passer un nombre annoncé au lecteur
  /// d'écran mais affiché nulle part à l'œil.
  static const ValueKey<String> unansweredTextKey = ValueKey<String>(
    'zExamUnansweredText',
  );

  /// Préfixe de clé d'une question, pour la testabilité et une identité
  /// stable.
  static const String questionKeyPrefix = 'zExamQuestion_';

  /// Nombre de questions sans réponse — dérivé, jamais tenu en double.
  ///
  /// Le filtre de bornes n'est pas décoratif (invariant AD-10) :
  /// [submissions] est indexée par position. Si l'hôte ne purge pas sa `Map`
  /// quand la file rétrécit, les clés périmées survivent : trois clés
  /// contre une seule carte neuve vierge donneraient un décompte négatif,
  /// affiché à l'apprenant, annoncé au lecteur d'écran, et répété dans le
  /// dialog de confirmation — au moment le plus irréversible du parcours,
  /// sans aucune exception pour le signaler.
  int get _unanswered => cards.length - _answeredInRange;

  /// Réponses dont la clé désigne réellement une carte de [cards] — les
  /// clés périmées d'un hôte qui n'a pas purgé sont ignorées (invariant
  /// AD-10).
  int get _answeredInRange =>
      submissions.keys.where((k) => k >= 0 && k < cards.length).length;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    // Examen vide (invariant AD-10) : état l10n, et aucune affordance de
    // soumission (absente, jamais grisée). `submit()` sur une file vide
    // serait pourtant légal côté moteur et produirait `total: 0` : on ne le
    // propose donc pas, plutôt que de le griser.
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

    // L'identité de la liste dérive de celle de la file, sur le même
    // patron que `ZSessionCardSwiper._queueGeneration`. Quand la file
    // change (elle rétrécit, notamment), la sous-arborescence est
    // reconstruite au lieu d'être réconciliée sur des index périmés — ce
    // qui évite un `RangeError`.
    //
    // Coût honnête : ce parcours est en coût linéaire à chaque `build` de
    // la vue (soit à chaque réponse) — la virtualisation du `ListView` plus
    // bas est réelle, mais elle ne couvre pas cette clé, qui touche les N
    // cartes systématiquement. Non-régression pour le rebuild granulaire :
    // `build` ne tourne pas à la frappe (l'état de saisie vit dans
    // `ZFlashcardAnswerInput`), donc l'objectif produit n°1 n'est pas
    // menacé. Consigné, non optimisé.
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
          // `ListView.builder`, jamais `ListView(children: [...])` : un
          // examen peut porter des centaines de questions ; seules les
          // visibles sont construites.
          child: ListView.builder(
            // +1 : en phase soumise, l'écran de fin est la première entrée
            // de la liste — il n'est donc construit que s'il est visible.
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

  /// Écran de fin — `ZSessionSummaryView`, jamais un écran réécrit, alimenté
  /// par l'agrégat injecté ([result]) — zéro recomptage.
  Widget _summary(BuildContext context) {
    final aggregate = result;
    // Phase soumise sans résultat (état incohérent, invariant AD-10) : on
    // n'invente aucun agrégat et on ne lève rien ; la correction par
    // question reste, elle, pleinement lisible.
    if (aggregate == null) return const SizedBox.shrink();
    // `liveRegion` : au passage en `submitted`, l'écran de fin est inséré à
    // l'index 0 de la `ListView`, c'est-à-dire au-dessus de la position de
    // lecture courante. Sans région live, rien ne serait annoncé : le focus
    // resterait près du bas de la liste et l'apprenant non-voyant devrait
    // deviner que son examen a été noté, puis remonter toute la liste à
    // l'aveugle pour trouver son score. Or le résultat est précisément
    // l'information qu'il attend à cet instant.
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
          // La saisie est celle de la surface de saisie standard — jamais
          // une saisie réécrite : l'évaluation locale QCM/VF, les indices,
          // le minuteur et les deux verrous (`onTap`/`_submitLocked`) sont
          // hérités tels quels.
          //
          // Gatée par la phase : hors `running`, `IgnorePointer` rend la
          // saisie inerte — aucune réponse ne peut donc partir vers le
          // moteur avant `start()` ou après `submit()`, où `answer()`
          // lèverait.
          IgnorePointer(
            ignoring: phase != ZExamViewPhase.running,
            child: ZFlashcardAnswerInput(
              // Identité stable par carte : sans elle, un changement de
              // file réconcilierait l'état d'une carte sur une autre.
              //
              // Les deux replis sont dans des espaces de noms disjoints
              // (`id:` / `ix:`) : `ZFlashcard.id` est nullable (opaque,
              // nullable pour l'éphémère), donc un examen mêlant cartes
              // persistées et éphémères où une carte porte `id == '3'` et
              // où la carte d'index 3 a `id == null` produirait deux
              // `ValueKey('zExamQuestion_3')` frères dans le même
              // `ListView.builder`, et Flutter lèverait une erreur de clés
              // dupliquées. Le préfixe rend la collision impossible par
              // construction, sans sacrifier la stabilité par `id`.
              key: ValueKey<String>(
                '$questionKeyPrefix${card.id != null ? 'id:${card.id}' : 'ix:$index'}',
              ),
              card: card,
              mode: ZReviewMode.whiteExam,
              srsConfig: config,
              contentBuilder: contentBuilder,
              evaluationPort: evaluationPort,
              // La carte ne rend jamais sa correction. Elle la pose quand
              // même, donc la saisie se verrouille (une réponse par carte)
              // et `_submitLocked` reste armé. C'est la révélation de fin,
              // ci-dessous, qui peint — depuis les `submissions` mémorisées.
              correctionVisibility: ZCorrectionVisibility.deferred,
              // On émet l'index de cette carte, capturé ici, jamais un
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

  /// Barre de soumission finale — présente uniquement en `running` (le gate
  /// est la phase : en `submitted`, l'affordance n'existe pas, donc le
  /// double `submit()` est inatteignable, et le `StateError` du moteur
  /// n'est jamais provoqué. Aucun `try-catch` n'est requis, ni permis.
  Widget _submitBar(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final unanswered = _unanswered;
    return Padding(
      padding: EdgeInsetsDirectional.all(theme.gapM),
      child: Row(
        children: <Widget>[
          // Le nombre de questions sans réponse est porté à la fois par le
          // texte visible et par `Semantics(value:)` : un canal a11y seul,
          // invisible à l'œil, ne suffirait pas.
          Expanded(
            child: Semantics(
              key: unansweredKey,
              label: label(
                context,
                'zcrud.study.exam.unanswered',
                fallback: 'Questions sans réponse',
              ),
              value: '$unanswered',
              // Sans cet `ExcludeSemantics`, le `Text` enfant fusionnerait
              // avec le `Semantics` parent et le nœud annoncerait « Questions
              // sans réponse\n2 — valeur : 2 », le lecteur d'écran bégayant.
              // Le sens est porté par le `Semantics` (canal unique) ; le
              // `Text` n'est que le canal visuel du même contenu.
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

  /// Dialog de confirmation — un examen soumis est irréversible (`submitted`
  /// n'a aucune transition sortante), donc confirmation explicite,
  /// mentionnant le nombre de questions sans réponse.
  ///
  /// Les libellés sont résolus ici, dans le contexte de la vue — jamais
  /// dans celui du dialog.
  ///
  /// Pourquoi : `showDialog` monte son contenu sur une nouvelle route, dont
  /// le contexte est enraciné au `Navigator` — c'est-à-dire au-dessus du
  /// `ZcrudScope` de l'application. Un `label(dialogContext, …)` ne voit
  /// donc aucun `ZcrudLabels` et retombe toujours sur son `fallback`
  /// français : une application anglophone afficherait « Confirmer »/
  /// « Annuler », en silence, sans qu'aucune garde de libellés en dur ne
  /// bronche (le fallback est du français légitime côté source).
  ///
  /// Le patron retenu est celui, déjà sanctionné, de `_StatTile`
  /// (`z_session_summary_view.dart`) : le libellé est déjà résolu par
  /// `label(context, …)` chez l'appelant — aucun littéral ne transite.
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

/// En-tête de progression — `ZSessionProgressIndicator`, jamais un compteur
/// parallèle réécrit.
///
/// Cet en-tête relaie, il ne publie pas : la progression vient de
/// `ZSessionProgressIndicator`, aucun compteur parallèle. Un second
/// `Semantics(label:, value:)` autour du composant produirait deux nœuds
/// annonçant deux nombres potentiellement en désaccord (un décompte de
/// réponses données face à une position courante `(currentIndex+1).clamp
/// (1,total)`), qu'un apprenant non-voyant entendrait successivement sans
/// moyen de savoir lequel est vrai. Un seul nœud de progression, portant un
/// seul nombre : celui du composant, sous sa clé l10n propre
/// (`zcrud.session.progress`).
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.cards,
    required this.answered,
    required this.submissions,
    required this.config,
  });

  final List<ZFlashcard> cards;

  /// Nombre de réponses dans les bornes de [cards] (invariant AD-10 — voir
  /// `ZListSessionView._answeredInRange` : une clé périmée ne doit pas
  /// faire avancer la progression).
  final int answered;

  final Map<int, ZFlashcardSubmission> submissions;
  final ZSrsConfig config;

  @override
  Widget build(BuildContext context) {
    return ZSessionProgressIndicator(
      total: cards.length,
      currentIndex: answered,
      // Seuil consommé de la config — jamais un littéral en dur.
      passThreshold: config.passThreshold,
      // Seam « qualité de la carte i » : lu sous sa carte.
      qualityOf: (index) => submissions[index]?.quality,
    );
  }
}

/// Révélation de la correction d'une question, en phase soumise.
///
/// Le canal est non-coloré (invariant AD-13) : une forme (✓/✗) porte la
/// vérité, jamais la seule couleur.
class _CorrectionReveal extends StatelessWidget {
  const _CorrectionReveal({required this.index, required this.submission});

  final int index;
  final ZFlashcardSubmission? submission;

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    // Une question sautée n'a pas de soumission (invariant AD-10) : elle
    // n'est pas comptée comme fausse (elle n'est pas dans `answers` du
    // moteur, donc elle ne pèse pas sur `total`). On le dit, on n'invente
    // aucune qualité.
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
    // `isCorrect` est nullable (une réponse rédigée sans port d'évaluation
    // n'a pas de vérité locale) : on n'affirme alors ni correct ni
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
      // Le verdict est associé à sa question : un marqueur détaché
      // s'attacherait à la mauvaise question et enseignerait une erreur à
      // un utilisateur non-voyant.
      child: Semantics(
        value: statusText,
        // Sans cet `ExcludeSemantics` sur le `Text` du verdict,
        // `MergeSemantics` fusionnerait le sous-arbre : le `Text(statusText)`
        // alimenterait le `label` pendant que `Semantics(value:)`
        // alimenterait la `value`, avec la même chaîne, faisant prononcer le
        // verdict deux fois — le nœud le plus important de cette surface.
        //
        // Le `feedback`, lui, n'est pas exclu : c'est un contenu distinct
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

/// Bouton d'examen — cible ≥ 48 dp (invariant AD-13) et `Semantics(label:)`
/// issu de `ZcrudLabels`.
///
/// [text] est déjà résolu par `label(context, …)` chez l'appelant — aucun
/// littéral ne transite (même patron que `_StatTile`). C'est ce qui permet
/// au dialog (dont le contexte est au-dessus du `ZcrudScope`, voir
/// `_confirmSubmit`) de porter les libellés injectés par l'application.
class _ExamButton extends StatelessWidget {
  const _ExamButton({
    required this.buttonKey,
    required this.text,
    required this.onPressed,
  });

  final ValueKey<String> buttonKey;

  /// Libellé déjà localisé par l'appelant.
  final String text;
  final VoidCallback? onPressed;

  /// Cible tap minimale (invariant AD-13).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) => Semantics(
    key: buttonKey,
    button: true,
    label: text,
    // L'`ExcludeSemantics` ci-dessous engloutit tout le sous-arbre,
    // `TextButton` inclus : il supprime donc aussi sa
    // `SemanticsAction.tap`. Sans re-déclaration ici, le nœud s'annoncerait
    // « bouton » sans aucune action : un lecteur d'écran n'exposerait pas
    // l'action de clic, et un apprenant non-voyant ne pourrait ni soumettre
    // son examen, ni sortir du dialog de confirmation. L'action est donc
    // portée par le nœud qui porte le rôle, jamais laissée à l'enfant exclu.
    onTap: onPressed,
    // Sans cet `ExcludeSemantics`, le `Text` de l'enfant fusionnerait et le
    // nœud annoncerait le libellé deux fois.
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
