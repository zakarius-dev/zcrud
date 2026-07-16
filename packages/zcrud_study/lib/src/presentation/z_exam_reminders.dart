/// Câblage `ZExam → ZApproachingExam` (Story ES-9.2, AC4/AC5, **FR-S10**).
///
/// Le port neutre `ZApproachingExam` vit au `zcrud_study_kernel` ; l'entité `ZExam`
/// vit au `zcrud_exam` (pur-Dart). Le kernel **ne dépend d'AUCUN satellite** — il
/// ne peut donc pas importer `ZExam`. Le doc kernel (`z_daily_study_task.dart:30`)
/// sanctionne « `ZExam implements ZApproachingExam` **OU un adaptateur** …
/// **DÉFÉRÉ au consommateur** (ES-9.2) ». **ES-9.2 EST ce consommateur** : elle
/// livre le câblage — sous forme d'un **ADAPTATEUR** côté `zcrud_study`.
///
/// ## 🔴 Pourquoi un ADAPTATEUR ICI, et NON un `implements` dans `zcrud_exam`
///
/// Un `class ZExam implements ZApproachingExam` dans `zcrud_exam` ajouterait
/// l'arête `zcrud_exam → zcrud_study_kernel` (le port vit au kernel) — arête que le
/// pubspec `zcrud_exam` **DIFFÈRE explicitement** (« l'arête sera déclarée quand un
/// import réel l'exigera, ES-3.x »). L'adaptateur côté `zcrud_study` évite cette
/// arête : `zcrud_exam` reste sur `core`/`annotations` SEULS. `zcrud_study` importe
/// DÉJÀ le kernel (`ZApproachingExam`) **et** importe `zcrud_exam` (`ZExam`, ES-9.2)
/// ⇒ il est le SEUL point où les deux types se rencontrent. Coût graphe : **1 seule
/// arête** `zcrud_study → zcrud_exam` (AD-1, acyclique).
///
/// ## 🔴 Forwarder TRIVIAL — AUCUNE réimplémentation de la proximité (R20)
///
/// [_ZExamApproaching] DÉLÈGUE `isApproaching(now)` / `daysUntil(now)` / `date` aux
/// vraies méthodes de `ZExam` (pures, totales, déterministes, horloge INJECTÉE, D5)
/// — la logique de proximité vit dans `ZExam` (ES-2.6, déjà testée). C'est **LA
/// ligne de prod PROPRE à ES-9.2** : coder en dur `isApproaching(now) => true`
/// laisserait fuiter un examen PASSÉ (R3-I4).
///
/// ## 🔴 AC5 — la planification OS est un SEAM APP ; ici, calcul déterministe SEUL
///
/// [examDailyTasks] / [approachingReminders] prennent l'horloge `now` en
/// **PARAMÈTRE** (jamais `DateTime.now()`, R5) et ne font QUE DÉLÉGUER le filtre
/// (`isApproaching`) + le tri (date croissante) à `aggregateDailyStudyTasks`
/// (kernel). **AUCUN** plugin de notification, **AUCUN** `Timer`/`Future.delayed`
/// de planification : la programmation concrète (canal OS) est app-side (AD-26).
library;

import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZApproachingExam, ZDailyStudyTask, ZExamTask, aggregateDailyStudyTasks;

/// Adaptateur `ZExam → ZApproachingExam` — **forwarder TRIVIAL** (R20).
///
/// Délègue les trois membres du port aux vraies méthodes de [ZExam] : AUCUNE
/// réimplémentation de la proximité (elle vit dans `ZExam`, déjà testée). Immuable
/// (`const`) : ne porte QUE la référence à l'examen source.
class _ZExamApproaching implements ZApproachingExam {
  const _ZExamApproaching(this.exam);

  /// L'examen source (préservé pour reconstruire la vue riche — [ZApproachingReminder]).
  final ZExam exam;

  @override
  bool isApproaching(DateTime now) => exam.isApproaching(now);

  @override
  int? daysUntil(DateTime now) => exam.daysUntil(now);

  @override
  DateTime? get date => exam.date;
}

/// Adapte un [ZExam] au port neutre [ZApproachingExam] (forwarder trivial).
///
/// Surface publique du câblage ES-9.2 : un `ZExam` réel, vu à travers CET
/// adaptateur, est consommable par le kernel sans que le kernel connaisse
/// `zcrud_exam` (AD-1).
ZApproachingExam zExamAsApproaching(ZExam exam) => _ZExamApproaching(exam);

/// Vue « rythme du jour » à partir d'examens RÉELS (AC4, **FR-S10**).
///
/// Adapte chaque [ZExam] via [zExamAsApproaching] puis DÉLÈGUE à
/// `aggregateDailyStudyTasks` (kernel) : filtre les approchants (`isApproaching`),
/// trie par date croissante, émet `[ZDueCardsTask?] + ZExamTask[]`. Le `now` reste
/// **INJECTÉ** (jamais `DateTime.now()`, AC5). Zéro réimplémentation du tri/filtre
/// (R21/R26) : le kernel est la source unique.
List<ZDailyStudyTask> examDailyTasks({
  required int dueCount,
  required Iterable<ZExam> exams,
  required DateTime now,
}) {
  return aggregateDailyStudyTasks(
    dueCount: dueCount,
    exams: exams.map(zExamAsApproaching),
    now: now,
  );
}

/// Un rappel approchant matérialisé : l'examen source + son décompte (AC4).
///
/// DÉRIVÉ de [examDailyTasks] : porte le [ZExam] complet (pour rendre l'intitulé,
/// que le port neutre [ZApproachingExam] n'expose PAS) et le [daysUntil] déjà
/// calculé par le kernel via l'adaptateur. Immuable, `==`/`hashCode` de valeur.
class ZApproachingReminder {
  const ZApproachingReminder(this.exam, this.daysUntil);

  /// L'examen approchant (entité complète, intitulé/date disponibles).
  final ZExam exam;

  /// Jours calendaires (UTC) jusqu'à l'échéance au regard du `now` injecté —
  /// dérivé de `exam.daysUntil(now)` par le kernel (jamais recalculé ici).
  final int daysUntil;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZApproachingReminder &&
          exam == other.exam &&
          daysUntil == other.daysUntil;

  @override
  int get hashCode => Object.hash(exam, daysUntil);

  @override
  String toString() => 'ZApproachingReminder($exam, daysUntil: $daysUntil)';
}

/// Examens approchants (avec décompte) DÉRIVÉS de la vue quotidienne (AC4/AC5).
///
/// Réutilise [examDailyTasks] (donc `aggregateDailyStudyTasks`) — **filtre + tri
/// DÉLÉGUÉS au kernel** (R21/R26, zéro réimplémentation). Reconstruit la liste de
/// [ZApproachingReminder] depuis les [ZExamTask] émis, en récupérant le [ZExam]
/// source porté par l'adaptateur. La **préservation exacte** de la sélection ET de
/// l'ordre est celle du kernel (approchants seuls, date croissante) : neutraliser
/// la délégation de l'adaptateur (`isApproaching => true`) ferait fuiter un passé
/// (R3-I4). `now` INJECTÉ (jamais `DateTime.now()`, AC5).
List<ZApproachingReminder> approachingReminders({
  required Iterable<ZExam> exams,
  required DateTime now,
}) {
  final tasks = examDailyTasks(dueCount: 0, exams: exams, now: now);
  return <ZApproachingReminder>[
    for (final task in tasks.whereType<ZExamTask>())
      // L'adaptateur ES-9.2 est le SEUL producteur de ces tâches ⇒ le cast est sûr
      // et récupère le `ZExam` source (le port neutre n'expose pas l'intitulé).
      ZApproachingReminder(
        (task.exam as _ZExamApproaching).exam,
        task.daysUntil,
      ),
  ];
}
