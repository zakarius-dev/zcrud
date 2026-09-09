/// Surface d'examen blanc en liste : `ZWhiteExamListView`.
///
/// # Ce qu'elle est
///
/// Une épreuve où **toutes** les questions sont posées en même temps : le
/// candidat répond dans l'ordre qu'il veut, revient sur une réponse, marque
/// une question pour y revenir, en déclare une « je ne sais pas », puis rend
/// sa copie. C'est la surface complémentaire de la coquille « une question à
/// la fois » — et elle consomme le **même** contrôleur, donc le même moteur
/// et le même scoring : deux examens répondus à l'identique par les deux
/// surfaces produisent le même résultat.
///
/// # Ce qu'elle n'est pas
///
/// Elle ne rend **aucun contenu de question** : le contenu, la saisie et la
/// correction appartiennent à l'hôte, qui les pose dans le slot de carte. Elle
/// ne calcule ni score, ni verdict, ni progression : elle **lit** l'état
/// relayé par le contrôleur.
///
/// Elle n'écrit aucun état de répétition espacée : son constructeur n'a aucun
/// paramètre de révision, de planificateur ou de stockage — il n'existe pas de
/// point où brancher une écriture.
///
/// # Reconstruction granulaire
///
/// Répondre à la question `i` ne reconstruit **que** la question `i`. Chaque
/// question n'écoute qu'une tranche de l'état — sa réponse, son marquage, la
/// phase — et la liste elle-même n'écoute que le nombre de questions et la
/// phase. Une frappe ou un choix dans une carte ne fait donc jamais
/// retomber la liste entière.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;

import '../domain/z_exam_answer.dart';
import '../domain/z_white_exam_session_controller.dart';
import 'z_session_progress_indicator.dart';
import 'z_white_exam_session_view.dart';
import 'z_white_exam_submit_policy.dart';

/// Contexte réel remis au slot de carte d'une question.
@immutable
class ZWhiteExamListQuestion {
  /// Construit le contexte d'une question de la liste.
  const ZWhiteExamListQuestion({
    required this.index,
    required this.total,
    required this.phase,
    required this.answer,
    required this.marked,
    required this.onAnswer,
    required this.onDontKnow,
    required this.onToggleMark,
  });

  /// Rang de la question dans l'épreuve, à partir de zéro.
  final int index;

  /// Nombre de questions de l'épreuve.
  final int total;

  /// Phase courante — l'unique gate des affordances.
  final ZWhiteExamSessionViewPhase phase;

  /// Réponse enregistrée pour cette question — « sans réponse » tant qu'il
  /// n'y en a aucune, jamais `null`.
  final ZExamAnswer answer;

  /// La question est-elle marquée par le candidat ?
  final bool marked;

  /// Enregistre une note pour **cette** question, jamais pour une autre : le
  /// rang est capturé ici, il n'y a aucun curseur partagé à faire glisser.
  final ValueChanged<int> onAnswer;

  /// Déclare « je ne sais pas » sur cette question : elle compte répondue et
  /// fausse.
  final VoidCallback onDontKnow;

  /// Bascule le marquage de cette question, sans toucher à sa réponse.
  final VoidCallback onToggleMark;
}

/// Slot de contenu d'une question de la liste.
typedef ZWhiteExamListQuestionBuilder =
    Widget Function(BuildContext context, ZWhiteExamListQuestion question);

/// Surface d'examen blanc en liste, branchée sur le contrôleur du moteur.
///
/// [controller] est détenu par l'hôte et garde donc son identité au travers
/// des rebuilds parents.
class ZWhiteExamListView extends StatelessWidget {
  /// Construit la liste d'examen.
  ///
  /// Aucun paramètre de révision, de planificateur ou de stockage : cette
  /// surface ne peut pas écrire d'état de répétition espacée.
  const ZWhiteExamListView({
    required this.controller,
    required this.questionBuilder,
    this.labels = const ZWhiteExamSessionLabels(),
    this.headerBuilder,
    this.resultBuilder,
    this.submitPolicy = const ZWhiteExamSubmitPolicy(),
    this.config = const ZSrsConfig(),
    this.onSubmitted,
    super.key,
  });

  /// Contrôleur stable qui délègue au moteur réel.
  final ZWhiteExamSessionController controller;

  /// Libellés et annonces injectés — les mêmes que ceux de la coquille.
  ///
  /// Tous ses champs sont facultatifs : sans rien déclarer, la surface rend
  /// les libellés de l'application, résolus par la portée applicative.
  final ZWhiteExamSessionLabels labels;

  /// Rendu de la carte d'une question, détenu par l'hôte.
  final ZWhiteExamListQuestionBuilder questionBuilder;

  /// Rendu de l'en-tête d'une question. `null` : l'en-tête de référence est
  /// rendu — rang, « je ne sais pas » et marquage.
  final ZWhiteExamListQuestionBuilder? headerBuilder;

  /// Rendu du résultat après soumission, posé en tête de liste. `null` :
  /// aucun résultat n'est rendu par cette surface.
  final ZWhiteExamResultBuilder? resultBuilder;

  /// Règles de confirmation et de comptage à la soumission.
  final ZWhiteExamSubmitPolicy submitPolicy;

  /// Configuration de l'échelle de notation — source unique du seuil lu par
  /// la progression. Jamais une échelle redéclarée.
  final ZSrsConfig config;

  /// Notifié juste après une soumission acceptée — le moment où un hôte
  /// arrête son chronomètre.
  final VoidCallback? onSubmitted;

  /// Clé de l'état vide.
  static const ValueKey<String> emptyKey = ValueKey<String>(
    'zWhiteExamListEmpty',
  );

  /// Clé de la liste des questions.
  static const ValueKey<String> listKey = ValueKey<String>('zWhiteExamList');

  /// Clé de la région de progression.
  static const ValueKey<String> progressKey = ValueKey<String>(
    'zWhiteExamListProgress',
  );

  /// Clé de la région de résultat.
  static const ValueKey<String> resultKey = ValueKey<String>(
    'zWhiteExamListResult',
  );

  /// Clé de l'action de soumission.
  static const ValueKey<String> submitKey = ValueKey<String>(
    'zWhiteExamListSubmit',
  );

  /// Clé du bouton de confirmation du dialogue.
  static const ValueKey<String> confirmKey = ValueKey<String>(
    'zWhiteExamListConfirm',
  );

  /// Clé du bouton d'annulation du dialogue.
  static const ValueKey<String> cancelKey = ValueKey<String>(
    'zWhiteExamListCancel',
  );

  /// Clé du nœud sémantique du compte de questions sans réponse.
  static const ValueKey<String> unansweredKey = ValueKey<String>(
    'zWhiteExamListUnanswered',
  );

  /// Clé du texte visible du compte de questions sans réponse.
  ///
  /// Deux clés parce qu'il y a deux canaux à garder séparément : un test qui
  /// n'en observerait qu'un laisserait passer un nombre annoncé au lecteur
  /// d'écran mais affiché nulle part à l'œil.
  static const ValueKey<String> unansweredTextKey = ValueKey<String>(
    'zWhiteExamListUnansweredText',
  );

  /// Clé du compte de questions sans réponse **dans le dialogue** — distincte
  /// de celle de la barre, qui reste montée derrière lui.
  static const ValueKey<String> dialogUnansweredTextKey = ValueKey<String>(
    'zWhiteExamListDialogUnanswered',
  );

  /// Préfixe de clé d'une question — identité stable et testabilité.
  static const String questionKeyPrefix = 'zWhiteExamListQuestion_';

  /// Préfixe de clé du badge de rang d'une question.
  static const String badgeKeyPrefix = 'zWhiteExamListBadge_';

  /// Préfixe de clé du contrôle « je ne sais pas » d'une question.
  static const String dontKnowKeyPrefix = 'zWhiteExamListDontKnow_';

  /// Préfixe de clé du contrôle de marquage d'une question.
  static const String markKeyPrefix = 'zWhiteExamListMark_';

  /// Clé de couleur du marquage d'une question — résolue par le seam de clés
  /// du cœur, jamais par une valeur.
  static const String markedColorKey = 'zcrud.study.exam.marked';

  @override
  Widget build(BuildContext context) => _ExamSlice<int>(
    listenable: controller.state,
    select: _selectTotal,
    builder: (context, total) => total == 0
        ? _empty(context)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ExamSlice<(Map<int, ZExamAnswer>, int)>(
                listenable: controller.state,
                select: _selectProgress,
                builder: (context, slice) => _ProgressHeader(
                  total: total,
                  answers: slice.$1,
                  answered: slice.$2,
                  passThreshold: config.passThreshold,
                ),
              ),
              Expanded(
                child: _ExamSlice<ZWhiteExamSessionViewPhase>(
                  listenable: controller.state,
                  select: _selectPhase,
                  builder: (context, phase) => _list(context, total, phase),
                ),
              ),
              _ExamSlice<(int, ZWhiteExamSessionViewPhase)>(
                listenable: controller.state,
                select: _selectSubmit,
                builder: (context, slice) => slice.$2 ==
                        ZWhiteExamSessionViewPhase.running
                    ? _submitBar(context, slice.$1)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
  );

  /// Épreuve sans question : un état lisible, et aucune affordance de
  /// soumission — une copie vide n'est pas une copie.
  Widget _empty(BuildContext context) {
    final theme = ZcrudTheme.of(context);
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

  /// Liste virtualisée des questions — jamais une liste construite d'un bloc :
  /// une épreuve peut porter des centaines de questions, seules les visibles
  /// sont construites.
  Widget _list(
    BuildContext context,
    int total,
    ZWhiteExamSessionViewPhase phase,
  ) {
    final submitted =
        phase == ZWhiteExamSessionViewPhase.submitted &&
        resultBuilder != null;
    return ListView.builder(
      key: listKey,
      itemCount: total + (submitted ? 1 : 0),
      itemBuilder: (context, position) {
        if (submitted && position == 0) return _result(context);
        final index = submitted ? position - 1 : position;
        return _QuestionTile(
          index: index,
          total: total,
          controller: controller,
          labels: labels,
          questionBuilder: questionBuilder,
          headerBuilder: headerBuilder,
        );
      },
    );
  }

  /// Résultat de fin, posé en tête de liste et annoncé : au passage en phase
  /// soumise, il s'insère au-dessus de la position de lecture courante, et
  /// c'est exactement l'information attendue à cet instant.
  Widget _result(BuildContext context) => Semantics(
    key: resultKey,
    liveRegion: true,
    child: ValueListenableBuilder<ZWhiteExamSessionViewState>(
      valueListenable: controller.state,
      builder: (context, state, _) => switch (resultBuilder) {
        final builder? => builder(context, state),
        _ => const SizedBox.shrink(),
      },
    ),
  );

  /// Barre de soumission — présente uniquement pendant l'épreuve. Hors
  /// `running`, l'affordance n'existe pas : la double soumission, qui lèverait
  /// côté moteur, est donc inatteignable et aucun `try-catch` ne la masque.
  Widget _submitBar(BuildContext context, int unanswered) {
    final theme = ZcrudTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.all(theme.gapM),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              key: unansweredKey,
              label: label(
                context,
                'zcrud.study.exam.unanswered',
                fallback: 'Questions sans réponse',
              ),
              value: '$unanswered',
              // Le sens est porté par ce nœud ; le texte n'en est que le
              // canal visuel. Sans exclusion, le lecteur d'écran bégaierait
              // le même nombre deux fois.
              child: ExcludeSemantics(
                child: Text(
                  '$unanswered',
                  key: unansweredTextKey,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ),
          _ExamAction(
            actionKey: submitKey,
            semanticsLabel: label(
              context,
              'zcrud.study.exam.submit',
              fallback: 'Soumettre',
            ),
            onPressed: () => _submit(context, unanswered),
            child:
                labels.submitAction?.call(context) ??
                Text(
                  label(
                    context,
                    'zcrud.study.exam.submit',
                    fallback: 'Soumettre',
                  ),
                  textAlign: TextAlign.start,
                ),
          ),
        ],
      ),
    );
  }

  /// Soumet, en demandant confirmation si la politique l'exige.
  ///
  /// Les libellés sont résolus **ici**, dans le contexte de la surface —
  /// jamais dans celui du dialogue, dont la route est enracinée au-dessus de
  /// la portée applicative : une résolution faite là-bas retomberait
  /// systématiquement sur les valeurs de repli du socle, en silence.
  Future<void> _submit(BuildContext context, int unanswered) async {
    if (!submitPolicy.requiresConfirmation(unanswered: unanswered)) {
      _commit();
      return;
    }
    final message =
        labels.incompleteSubmitLabel?.call(unanswered) ??
        label(
          context,
          'zcrud.study.exam.unanswered',
          fallback: 'Questions sans réponse',
        );
    final cancelChild = labels.cancelAction?.call(context);
    final confirmChild = labels.confirmAction?.call(context);
    final cancelLabel = label(
      context,
      'zcrud.study.exam.submit.cancel',
      fallback: 'Annuler',
    );
    final confirmLabel = label(
      context,
      'zcrud.study.exam.submit.confirm',
      fallback: 'Confirmer',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Semantics(
          label: message,
          value: '$unanswered',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(message, textAlign: TextAlign.start),
                Text(
                  '$unanswered',
                  key: dialogUnansweredTextKey,
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          _ExamAction(
            actionKey: cancelKey,
            semanticsLabel: cancelLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: cancelChild ?? Text(cancelLabel, textAlign: TextAlign.start),
          ),
          _ExamAction(
            actionKey: confirmKey,
            semanticsLabel: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                confirmChild ?? Text(confirmLabel, textAlign: TextAlign.start),
          ),
        ],
      ),
    );
    if (confirmed ?? false) _commit();
  }

  void _commit() {
    controller.submit(
      countUnansweredAsIncorrect: submitPolicy.countUnansweredAsIncorrect,
    );
    onSubmitted?.call();
  }
}

int _selectTotal(ZWhiteExamSessionViewState state) => state.total;

(Map<int, ZExamAnswer>, int) _selectProgress(
  ZWhiteExamSessionViewState state,
) => (state.answers, state.answeredCount);

ZWhiteExamSessionViewPhase _selectPhase(ZWhiteExamSessionViewState state) =>
    state.phase;

(int, ZWhiteExamSessionViewPhase) _selectSubmit(
  ZWhiteExamSessionViewState state,
) => (state.unansweredCount, state.phase);

/// Abonnement à une **tranche** de l'état : le sous-arbre n'est reconstruit
/// que lorsque la valeur sélectionnée change réellement.
///
/// C'est le mécanisme de la reconstruction granulaire : sans lui, une réponse
/// reconstruirait toutes les questions montées.
class _ExamSlice<S> extends StatefulWidget {
  const _ExamSlice({
    required this.listenable,
    required this.select,
    required this.builder,
  });

  final ValueListenable<ZWhiteExamSessionViewState> listenable;
  final S Function(ZWhiteExamSessionViewState state) select;
  final Widget Function(BuildContext context, S slice) builder;

  @override
  State<_ExamSlice<S>> createState() => _ExamSliceState<S>();
}

class _ExamSliceState<S> extends State<_ExamSlice<S>> {
  late S _slice;

  @override
  void initState() {
    super.initState();
    _slice = widget.select(widget.listenable.value);
    widget.listenable.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(_ExamSlice<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onStateChanged);
      widget.listenable.addListener(_onStateChanged);
    }
    // Le sélecteur peut désigner une autre tranche (une autre question, après
    // un réordonnancement) : on relit, sinon la tranche affichée serait celle
    // de la position précédente.
    _slice = widget.select(widget.listenable.value);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final next = widget.select(widget.listenable.value);
    if (next == _slice) return;
    setState(() => _slice = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _slice);
}

/// Une question de la liste : en-tête et carte, sous une identité stable.
class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.index,
    required this.total,
    required this.controller,
    required this.labels,
    required this.questionBuilder,
    required this.headerBuilder,
  });

  final int index;
  final int total;
  final ZWhiteExamSessionController controller;
  final ZWhiteExamSessionLabels labels;
  final ZWhiteExamListQuestionBuilder questionBuilder;
  final ZWhiteExamListQuestionBuilder? headerBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return _ExamSlice<(ZExamAnswer, bool, ZWhiteExamSessionViewPhase)>(
      listenable: controller.state,
      select: (state) => (
        state.answerFor(index),
        state.isMarkedAt(index),
        state.phase,
      ),
      builder: (context, slice) {
        final question = ZWhiteExamListQuestion(
          index: index,
          total: total,
          phase: slice.$3,
          answer: slice.$1,
          marked: slice.$2,
          // Le rang est capturé ici : la note part sous SA question, jamais
          // sous un rang d'arrivée qui pourrait glisser d'un cran.
          onAnswer: (quality) => controller.answerAt(index, quality),
          onDontKnow: () => controller.dontKnowAt(index),
          onToggleMark: () => controller.toggleMarkAt(index),
        );
        return Semantics(
          key: ValueKey<String>(
            '${ZWhiteExamListView.questionKeyPrefix}$index',
          ),
          label:
              labels.questionItemSemanticsLabel?.call(
                index,
                question.answer,
                question.marked,
              ) ??
              label(
                context,
                'zcrud.study.exam.question',
                fallback: 'Question',
              ),
          // Rang, puis état : l'annonce dit où on en est sans qu'aucun autre
          // nœud ne le répète.
          value: <String>[
            '${index + 1}',
            if (question.answer.isAnswered)
              label(
                context,
                'zcrud.study.exam.answered',
                fallback: 'répondue',
              ),
            if (question.marked)
              label(context, 'zcrud.study.exam.marked', fallback: 'marquée'),
          ].join(' '),
          child: Padding(
            padding: EdgeInsetsDirectional.all(theme.gapM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                headerBuilder?.call(context, question) ??
                    _QuestionHeader(question: question, labels: labels),
                SizedBox(height: theme.gapM),
                questionBuilder(context, question),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// En-tête de référence d'une question : rang, « je ne sais pas », marquage.
class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.question, required this.labels});

  final ZWhiteExamListQuestion question;
  final ZWhiteExamSessionLabels labels;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final running = question.phase == ZWhiteExamSessionViewPhase.running;
    final badge =
        labels.questionBadgeLabel?.call(question.index, question.total) ??
        '${label(context, 'zcrud.study.exam.question', fallback: 'Question')} '
            '${question.index + 1}';
    final markLabel =
        labels.markSemanticsLabel?.call(question.index, question.marked) ??
        label(context, 'zcrud.study.exam.mark', fallback: 'Marquer');
    final dontKnowLabel = label(
      context,
      'zcrud.flashcard.dontKnow',
      fallback: 'Je ne sais pas',
    );
    final marked = zResolveColorKeyOrSlot(
      context,
      ZWhiteExamListView.markedColorKey,
      slotIndex: ZColorSlot.tertiary.index,
    );

    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Padding(
            key: ValueKey<String>(
              '${ZWhiteExamListView.badgeKeyPrefix}${question.index}',
            ),
            padding: EdgeInsetsDirectional.only(end: theme.gapM),
            child: Text(badge, textAlign: TextAlign.start),
          ),
        ),
        const Spacer(),
        if (running)
          _ExamAction(
            actionKey: ValueKey<String>(
              '${ZWhiteExamListView.dontKnowKeyPrefix}${question.index}',
            ),
            semanticsLabel: dontKnowLabel,
            onPressed: question.onDontKnow,
            child:
                labels.dontKnowAction?.call(context) ??
                Text(dontKnowLabel, textAlign: TextAlign.start),
          ),
        if (running) SizedBox(width: theme.gapM),
        if (running)
          _ExamAction(
            actionKey: ValueKey<String>(
              '${ZWhiteExamListView.markKeyPrefix}${question.index}',
            ),
            semanticsLabel: markLabel,
            toggled: question.marked,
            onPressed: question.onToggleMark,
            child:
                labels.markAction?.call(context, question.marked) ??
                Icon(
                  question.marked ? Icons.flag : Icons.flag_outlined,
                  color: question.marked ? marked.color : null,
                ),
          ),
      ],
    );
  }
}

/// Contrôle d'examen — cible tactile d'au moins 48 dp et rôle annoncé.
///
/// [semanticsLabel] est déjà résolu par l'appelant : aucun littéral ne
/// transite, ce qui permet au dialogue — dont le contexte est au-dessus de la
/// portée applicative — de porter les libellés injectés par l'application.
class _ExamAction extends StatelessWidget {
  const _ExamAction({
    required this.actionKey,
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
    this.toggled,
  });

  final ValueKey<String> actionKey;

  /// Libellé déjà localisé par l'appelant.
  final String semanticsLabel;

  /// État d'un contrôle basculable, annoncé comme tel. `null` : le contrôle
  /// n'est pas basculable.
  final bool? toggled;
  final VoidCallback onPressed;
  final Widget child;

  /// Cible tactile minimale.
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) => Semantics(
    key: actionKey,
    button: true,
    label: semanticsLabel,
    toggled: toggled,
    // L'exclusion ci-dessous engloutit le sous-arbre, bouton compris : sans
    // re-déclaration ici, le nœud s'annoncerait « bouton » sans action, et
    // un lecteur d'écran n'exposerait aucun geste.
    onTap: onPressed,
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minTarget,
          minHeight: minTarget,
        ),
        child: TextButton(onPressed: onPressed, child: child),
      ),
    ),
  );
}

/// En-tête de progression — relaie le composant de progression, sans jamais
/// tenir un second compteur.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.total,
    required this.answers,
    required this.answered,
    required this.passThreshold,
  });

  final int total;
  final Map<int, ZExamAnswer> answers;

  /// Nombre de réponses relayé par l'état — jamais recompté ici.
  final int answered;

  final int passThreshold;

  @override
  Widget build(BuildContext context) {
    return ZSessionProgressIndicator(
      key: ZWhiteExamListView.progressKey,
      total: total,
      currentIndex: answered,
      passThreshold: passThreshold,
      qualityOf: (index) => answers[index]?.quality,
    );
  }
}
