/// `ZExamRemindersSection` — section « rappels approchants » (Story ES-9.2, AC4/
/// AC5/AC7, **FR-S10**). ADAPTATEUR MINCE de PRÉSENTATION : elle DÉRIVE les
/// examens approchants via [approachingReminders] (filtre `isApproaching` + tri par
/// date DÉLÉGUÉS au kernel `aggregateDailyStudyTasks`, R21/R26) et les rend en
/// `ListView.builder` accessible (AD-13). L'horloge `now` est **INJECTÉE** (jamais
/// `DateTime.now()`, AC5).
///
/// ## 🔴 AC5 — la planification OS est un SEAM APP ; ici, exposition SEULE
///
/// La section **ne planifie JAMAIS** de notification : elle ne calcule que
/// `isApproaching(now)` (déterministe) et EXPOSE les approchants à l'app via
/// [ZExamRemindersSection.onRemindersComputed], à charge pour l'app de programmer le
/// canal OS (plugin, horaire système). **AUCUN** plugin de notification, **AUCUN**
/// `Timer`/`Future.delayed` de planification ici (AD-26).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_exam/zcrud_exam.dart';

import 'z_exam_reminders.dart';

export 'z_exam_reminders.dart'
    show
        ZApproachingReminder,
        approachingReminders,
        examDailyTasks,
        zExamAsApproaching;

/// Construit la ligne d'un rappel approchant (INJECTÉ). Reçoit l'examen complet +
/// son décompte de jours (AD-13/FR-26 — couleurs/labels fournis par l'appelant).
typedef ZApproachingReminderTileBuilder = Widget Function(
  BuildContext context,
  ZApproachingReminder reminder,
);

/// Exposition des approchants à l'app pour la planification OS (AC5). Invoquée
/// après le calcul (post-frame) — la section ne planifie JAMAIS elle-même.
typedef ZRemindersComputed = void Function(List<ZApproachingReminder> reminders);

/// Section listant les examens approchants dérivés d'un `now` INJECTÉ.
///
/// `StatefulWidget` **uniquement** pour recalculer les approchants quand les entrées
/// ([exams]/[now]) changent et NOTIFIER l'app (post-frame) — jamais pour un état
/// d'entité. La liste est un `ListView.builder` (AD-13, jamais `ListView(children:)`).
class ZExamRemindersSection extends StatefulWidget {
  const ZExamRemindersSection({
    required this.exams,
    required this.now,
    this.onRemindersComputed,
    this.tileBuilder,
    this.emptyState = const SizedBox.shrink(),
    this.shrinkWrap = true,
    this.reminderSemanticLabel = _defaultReminderSemanticLabel,
    this.dueInLabel = _defaultDueInLabel,
    super.key,
  });

  /// Les examens candidats (mix approchants/passés/off/`date==null`). La section
  /// n'en garde que les approchants (via le port, AC4).
  final List<ZExam> exams;

  /// Horloge INJECTÉE (jamais `DateTime.now()`, AC5). Seul référentiel temporel.
  final DateTime now;

  /// Exposition des approchants à l'app (AC5). `null` = aucune exposition (la
  /// section reste un affichage passif ; jamais un no-op de planification).
  final ZRemindersComputed? onRemindersComputed;

  /// Construit la ligne d'un rappel (INJECTÉ). `null` ⇒ repli neutre (intitulé +
  /// décompte via [dueInLabel]) — jamais une `Color`/icône codée en dur (FR-26).
  final ZApproachingReminderTileBuilder? tileBuilder;

  /// Widget affiché quand AUCUN examen n'approche. Fourni par l'appelant.
  final Widget emptyState;

  /// `ListView.builder` en `shrinkWrap` (défaut, s'intègre dans une colonne).
  final bool shrinkWrap;

  /// Libellé sémantique INJECTÉ d'une ligne de rappel (i18n — défaut documenté).
  final String Function(ZApproachingReminder reminder) reminderSemanticLabel;

  /// Libellé INJECTÉ du décompte de jours (i18n — défaut documenté).
  final String Function(int daysUntil) dueInLabel;

  static String _defaultReminderSemanticLabel(ZApproachingReminder reminder) =>
      'Rappel d\'examen ${reminder.exam.title}, dans ${reminder.daysUntil} jour(s)';

  static String _defaultDueInLabel(int daysUntil) => 'dans $daysUntil j';

  @override
  State<ZExamRemindersSection> createState() => _ZExamRemindersSectionState();
}

class _ZExamRemindersSectionState extends State<ZExamRemindersSection> {
  /// Approchants DÉRIVÉS (filtre + tri délégués au kernel — R21/R26).
  late List<ZApproachingReminder> _reminders;

  @override
  void initState() {
    super.initState();
    _recompute();
    _scheduleNotify();
  }

  @override
  void didUpdateWidget(covariant ZExamRemindersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.exams, widget.exams) ||
        oldWidget.now != widget.now) {
      _recompute();
      _scheduleNotify();
    }
  }

  /// Recalcule les approchants (horloge INJECTÉE `widget.now`, jamais interne, AC5).
  void _recompute() {
    _reminders = approachingReminders(exams: widget.exams, now: widget.now);
  }

  /// Notifie l'app APRÈS la frame (jamais de setState d'ancêtre en plein build).
  /// Ce n'est PAS une planification de notification OS (aucun `Timer`, aucun plugin,
  /// aucun horaire système) : juste l'exposition des approchants calculés (AC5).
  void _scheduleNotify() {
    final callback = widget.onRemindersComputed;
    if (callback == null) return;
    final snapshot = List<ZApproachingReminder>.of(_reminders);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(snapshot);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    if (_reminders.isEmpty) return widget.emptyState;
    return ListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : null,
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        final tile = widget.tileBuilder?.call(context, reminder) ??
            _defaultTile(theme, reminder);
        return Semantics(
          key: ValueKey<String>('z-exam-reminder:${reminder.exam.id ?? index}'),
          label: widget.reminderSemanticLabel(reminder),
          child: tile,
        );
      },
    );
  }

  Widget _defaultTile(ZcrudTheme theme, ZApproachingReminder reminder) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: theme.gapS,
        bottom: theme.gapS,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(reminder.exam.title, textAlign: TextAlign.start),
          ),
          SizedBox(width: theme.gapM),
          Text(widget.dueInLabel(reminder.daysUntil), textAlign: TextAlign.end),
        ],
      ),
    );
  }
}
