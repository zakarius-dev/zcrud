/// `aggregateDailyStudyTasks` — vue « rythme du jour », pure, totale,
/// déterministe.
///
/// Cette fonction ne bucketise pas des résultats de session par jour
/// calendaire. C'est une vue combinant (a) le compte de cartes dues
/// ([dueCount], fourni par l'appelant, jamais recalculé) et (b) les examens
/// approchants au regard d'un `now` injecté. [ZStudySessionResult] n'est pas
/// consommé ici.
///
/// ## Contrat
///
/// - un [ZDueCardsTask] est présent ssi `dueCount > 0`, toujours en tête ;
/// - un [ZExamTask] pour chaque examen tel que `isApproaching(now) == true`
///   (les passés / hors-fenêtre / rappels désactivés sont exclus par le
///   port) ;
/// - les [ZExamTask] sont triés par date d'échéance croissante (le plus
///   proche d'abord), placés après la ligne dues.
///
/// ## Frontière de jour UTC, horloge injectée
///
/// L'agrégation ne fait aucune arithmétique de date elle-même : elle
/// délègue à `exam.isApproaching(now)` (filtre) et `exam.daysUntil(now)`
/// (décompte), tous deux UTC-normalisés et déterministes côté implémentation
/// du port. Aucun `DateTime.now()` ni équivalent implicite — `now` est le
/// seul référentiel temporel.
///
/// ## Tri stable et déterministe sur date égale
///
/// `List.sort` de Dart n'est pas garanti stable (insertion-sort en dessous
/// d'un certain seuil, quicksort au-delà ⇒ deux dates égales peuvent être
/// permutées). Chaque examen approchant est décoré de son index d'entrée et
/// le tri se fait par `(date, index)` : le comparateur porte un ordre total
/// strict, donc l'ordre de sortie est totalement déterministe — l'ordre
/// d'entrée est préservé sur date égale, indépendamment de la stabilité
/// interne de `List.sort`.
library;

import 'z_daily_study_task.dart';

/// Combine cartes dues + examens approchants en une liste ordonnée de
/// tâches du jour. Pure, totale, déterministe — jamais de `throw` (invariant
/// AD-10).
///
/// [dueCount] est la source unique (jamais recalculée ni re-bornée) du
/// compte de cartes dues : `<= 0` ⇒ aucun [ZDueCardsTask]. [exams] sont
/// consommés via le port neutre [ZApproachingExam] (aucune dépendance à un
/// satellite d'examen, invariant AD-1). [now] est l'horloge injectée (aucun
/// `DateTime.now()` interne).
List<ZDailyStudyTask> aggregateDailyStudyTasks({
  required int dueCount,
  required Iterable<ZApproachingExam> exams,
  required DateTime now,
}) {
  // 1. Filtre : ne garder que les approchants (le port exclut passés /
  //    hors-fenêtre / rappels désactivés). On garde-`isApproaching`-PUIS-`daysUntil`
  //    ⇒ `date != null` sur les approchants (garanti par le port), mais on reste
  //    total si un `date == null` fuit (fallback déterministe, jamais de `null!`).
  final approaching = <_IndexedExam>[];
  for (final exam in exams) {
    if (exam.isApproaching(now)) {
      approaching.add(_IndexedExam(approaching.length, exam));
    }
  }

  // 2. Tri stable/déterministe par (date croissante, index d'entrée).
  //    Le tie-breaker d'index donne un ordre total strict : la sortie ne dépend
  //    pas de la stabilité interne de `List.sort`.
  approaching.sort((a, b) {
    final cmp = _compareDates(a.exam.date, b.exam.date);
    if (cmp != 0) return cmp;
    // Tie-breaker déterministe : ordre d'entrée sur date égale.
    return a.index.compareTo(b.index);
  });

  // 3. Assemble : ligne dues (ssi dueCount > 0) en tête, puis les ExamTask.
  final tasks = <ZDailyStudyTask>[
    if (dueCount > 0) ZDueCardsTask(dueCount),
    for (final indexed in approaching)
      // `daysUntil(now) ?? 0` : défensif (jamais de `!`) — sur un approchant,
      // le port garantit une valeur, le `?? 0` couvre un port hostile.
      ZExamTask(indexed.exam, indexed.exam.daysUntil(now) ?? 0),
  ];

  // `const []` exact pour le cas vide.
  return tasks.isEmpty
      ? const <ZDailyStudyTask>[]
      : List<ZDailyStudyTask>.unmodifiable(tasks);
}

/// Compare deux dates d'échéance, nulls en dernier (déterministe, invariant
/// AD-10) — jamais de `throw`. Croissant : la plus proche (petite) d'abord.
int _compareDates(DateTime? a, DateTime? b) {
  if (identical(a, b)) return 0;
  if (a == null) return 1; // null trié APRÈS (position déterministe)
  if (b == null) return -1;
  return a.compareTo(b);
}

/// Examen approchant décoré de son index d'entrée (support du tri stable).
class _IndexedExam {
  const _IndexedExam(this.index, this.exam);

  final int index;
  final ZApproachingExam exam;
}
