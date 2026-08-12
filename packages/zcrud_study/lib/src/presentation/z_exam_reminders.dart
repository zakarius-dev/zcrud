/// Câblage `ZExam → ZApproachingExam`.
///
/// Le port neutre `ZApproachingExam` vit au `zcrud_study_kernel` ; l'entité `ZExam`
/// vit au `zcrud_exam` (pur-Dart). Le kernel ne dépend d'aucun satellite — il
/// ne peut donc pas importer `ZExam`. Le kernel laisse ce choix au consommateur :
/// soit `ZExam implements ZApproachingExam`, soit un adaptateur. Ce fichier livre
/// le câblage sous forme d'un adaptateur côté `zcrud_study`.
///
/// ## Pourquoi un adaptateur ici, et non un `implements` dans `zcrud_exam`
///
/// Un `class ZExam implements ZApproachingExam` dans `zcrud_exam` ajouterait
/// l'arête `zcrud_exam → zcrud_study_kernel` (le port vit au kernel) — arête que le
/// pubspec `zcrud_exam` évite délibérément (elle ne se déclare que quand un
/// import réel l'exige). L'adaptateur côté `zcrud_study` évite cette
/// arête : `zcrud_exam` reste sur `core`/`annotations` seuls. `zcrud_study` importe
/// déjà le kernel (`ZApproachingExam`) et importe `zcrud_exam` (`ZExam`)
/// ⇒ il est le seul point où les deux types se rencontrent. Coût graphe : une seule
/// arête `zcrud_study → zcrud_exam` (invariant AD-1, acyclique).
///
/// ## Forwarder trivial — aucune réimplémentation de la proximité
///
/// [_ZExamApproaching] délègue `isApproaching(now)` / `daysUntil(now)` / `date` aux
/// vraies méthodes de `ZExam` (pures, totales, déterministes, horloge injectée)
/// — la logique de proximité vit dans `ZExam`, déjà testée. Coder en dur
/// `isApproaching(now) => true` laisserait fuiter un examen passé.
///
/// ## La planification OS reste un seam applicatif ; ici, calcul déterministe seul
///
/// [examDailyTasks] / [approachingReminders] prennent l'horloge `now` en
/// paramètre (jamais `DateTime.now()`) et ne font que déléguer le filtre
/// (`isApproaching`) + le tri (date croissante) à `aggregateDailyStudyTasks`
/// (kernel). Aucun plugin de notification, aucun `Timer`/`Future.delayed`
/// de planification : la programmation concrète (canal OS) reste côté application.
library;

import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZApproachingExam, ZDailyStudyTask, ZExamTask, aggregateDailyStudyTasks;

/// Adaptateur `ZExam → ZApproachingExam` — forwarder trivial.
///
/// Délègue les trois membres du port aux vraies méthodes de [ZExam] : aucune
/// réimplémentation de la proximité (elle vit dans `ZExam`, déjà testée). Immuable
/// (`const`) : ne porte que la référence à l'examen source.
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
/// Surface publique du câblage : un `ZExam` réel, vu à travers cet
/// adaptateur, est consommable par le kernel sans que le kernel connaisse
/// `zcrud_exam` (invariant AD-1).
ZApproachingExam zExamAsApproaching(ZExam exam) => _ZExamApproaching(exam);

/// Vue « rythme du jour » à partir d'examens réels.
///
/// Adapte chaque [ZExam] via [zExamAsApproaching] puis délègue à
/// `aggregateDailyStudyTasks` (kernel) : filtre les approchants (`isApproaching`),
/// trie par date croissante, émet `[ZDueCardsTask?] + ZExamTask[]`. Le `now` reste
/// injecté (jamais `DateTime.now()`). Zéro réimplémentation du tri/filtre :
/// le kernel est la source unique.
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

/// Un rappel approchant matérialisé : l'examen source et son décompte.
///
/// Dérivé de [examDailyTasks] : porte le [ZExam] complet (pour rendre
/// l'intitulé, que le port neutre `ZApproachingExam` n'expose pas) et le
/// [daysUntil] déjà calculé par le kernel via l'adaptateur. Immuable,
/// `==`/`hashCode` par valeur.
class ZApproachingReminder {
  /// Construit un rappel à partir de l'[exam] et de son décompte
  /// [daysUntil].
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

/// Examens approchants (avec décompte) dérivés de la vue quotidienne.
///
/// Réutilise [examDailyTasks] (donc `aggregateDailyStudyTasks`) — filtre et tri
/// délégués au kernel, zéro réimplémentation. Reconstruit la liste de
/// [ZApproachingReminder] depuis les [ZExamTask] émis, en récupérant le [ZExam]
/// source porté par l'adaptateur. La préservation exacte de la sélection et de
/// l'ordre est celle du kernel (approchants seuls, date croissante) : neutraliser
/// la délégation de l'adaptateur (`isApproaching => true`) ferait fuiter un examen
/// passé. `now` injecté (jamais `DateTime.now()`).
List<ZApproachingReminder> approachingReminders({
  required Iterable<ZExam> exams,
  required DateTime now,
}) {
  final tasks = examDailyTasks(dueCount: 0, exams: exams, now: now);
  return <ZApproachingReminder>[
    for (final task in tasks.whereType<ZExamTask>())
      // Cet adaptateur est le seul producteur de ces tâches ⇒ le cast est sûr
      // et récupère le `ZExam` source (le port neutre n'expose pas l'intitulé).
      ZApproachingReminder(
        (task.exam as _ZExamApproaching).exam,
        task.daysUntil,
      ),
  ];
}
