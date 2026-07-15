/// `aggregateDailyStudyTasks` — vue « rythme du jour » PURE / TOTALE /
/// DÉTERMINISTE (ES-2.7, **FR-S10**).
///
/// origine: lex_core (module « Étude ») —
/// `entities/education/daily_study_task.dart` (`aggregateDailyStudyTasks`,
/// fonction PURE `{dueCount, exams, now}` → `List<DailyStudyTask>`, « aucune
/// I/O, aucune horloge interne : purement dérivée de ses arguments »).
///
/// ⚠️ **Correction du brief d'orchestration (R4, lecture RÉELLE de la source)** :
/// cette fonction **NE bucketise PAS** des résultats de session par jour
/// calendaire. C'est une vue combinant (a) le **compte de cartes dues**
/// ([dueCount], fourni par l'appelant, **jamais recalculé**) et (b) les
/// **examens approchants** au regard d'un `now` injecté. [ZStudySessionResult]
/// n'est PAS consommé ici.
///
/// ## Contrat (parité lex portée)
///
/// - un [ZDueCardsTask] est présent **ssi `dueCount > 0`**, **TOUJOURS en tête** ;
/// - un [ZExamTask] pour **chaque** examen tel que `isApproaching(now) == true`
///   (les passés / hors-fenêtre / rappels désactivés sont **exclus** par le port) ;
/// - les [ZExamTask] sont triés par **date d'échéance croissante** (le plus
///   proche d'abord), placés **après** la ligne dues.
///
/// ## 🔴 D4 — frontière de jour UTC, HÉRITÉE du port, `now` INJECTÉ
///
/// L'agrégation **ne fait aucune arithmétique de date elle-même** : elle DÉLÈGUE
/// à `exam.isApproaching(now)` (filtre) et `exam.daysUntil(now)` (décompte), tous
/// deux **UTC-normalisés et déterministes** dans `ZExam` (ES-2.6). **AUCUN
/// `DateTime.now()` / `DateTime()` argless / `.toLocal()`** — `now` est le SEUL
/// référentiel temporel (prouvé par machine, `test/no_datetime_now_test.dart`).
///
/// ## 🔴 D5 — tri STABLE et DÉTERMINISTE sur date ÉGALE
///
/// `List.sort` de Dart **n'est PAS garanti stable** (insertion-sort ≤ 33
/// éléments, dual-pivot quicksort au-delà ⇒ deux dates égales peuvent être
/// **permutées**). On décore chaque examen approchant de son **index d'entrée**
/// et on trie par `(date, index)` : le comparateur porte un **ordre total
/// strict**, donc l'ordre de sortie est **totalement déterministe** —
/// l'ordre d'entrée est préservé sur date égale, **indépendamment** de la
/// stabilité interne de `List.sort`. C'est un **pouvoir discriminant OBSERVÉ**
/// (test à 40 examens de même date : sans le tie-breaker d'index, le quicksort
/// les permuterait).
library;

import 'z_daily_study_task.dart';

/// Combine cartes dues + examens approchants en une liste ordonnée de tâches du
/// jour (D3/D4/D5). **PURE, TOTALE, DÉTERMINISTE** — jamais de throw (AD-10).
///
/// [dueCount] est la **source unique** (jamais recalculée ni re-bornée) du compte
/// de cartes dues : `<= 0` ⇒ aucun [ZDueCardsTask]. [exams] sont consommés via le
/// port neutre [ZApproachingExam] (aucune dépendance à `zcrud_exam`, AD-1). [now]
/// est l'horloge **injectée** (aucun `DateTime.now()` interne).
List<ZDailyStudyTask> aggregateDailyStudyTasks({
  required int dueCount,
  required Iterable<ZApproachingExam> exams,
  required DateTime now,
}) {
  // 1. Filtre : ne garder que les approchants (le port exclut passés /
  //    hors-fenêtre / rappels désactivés). On garde-`isApproaching`-PUIS-`daysUntil`
  //    ⇒ `date != null` sur les approchants (ZExam le garantit), mais on reste
  //    TOTAL si un `date == null` fuit (fallback déterministe, jamais de `null!`).
  final approaching = <_IndexedExam>[];
  for (final exam in exams) {
    if (exam.isApproaching(now)) {
      approaching.add(_IndexedExam(approaching.length, exam));
    }
  }

  // 2. Tri STABLE/DÉTERMINISTE par (date croissante, index d'entrée) — D5.
  //    Le tie-breaker d'index donne un ordre TOTAL strict : la sortie ne dépend
  //    PAS de la stabilité interne de `List.sort`.
  approaching.sort((a, b) {
    final cmp = _compareDates(a.exam.date, b.exam.date);
    if (cmp != 0) return cmp;
    // 🔴 Tie-breaker DÉTERMINISTE (D5) : ordre d'entrée sur date égale.
    return a.index.compareTo(b.index);
  });

  // 3. Assemble : ligne dues (ssi dueCount > 0) en tête, puis les ExamTask.
  final tasks = <ZDailyStudyTask>[
    if (dueCount > 0) ZDueCardsTask(dueCount),
    for (final indexed in approaching)
      // `daysUntil(now) ?? 0` : défensif (jamais de `!`) — sur un approchant,
      // ZExam garantit une valeur, le `?? 0` couvre un port hostile (AD-10).
      ZExamTask(indexed.exam, indexed.exam.daysUntil(now) ?? 0),
  ];

  // `const []` exact pour le cas vide (AC9/AC11).
  return tasks.isEmpty
      ? const <ZDailyStudyTask>[]
      : List<ZDailyStudyTask>.unmodifiable(tasks);
}

/// Compare deux dates d'échéance, **nulls en dernier** (déterministe, AD-10) —
/// jamais de throw. Croissant : la plus proche (petite) d'abord.
int _compareDates(DateTime? a, DateTime? b) {
  if (identical(a, b)) return 0;
  if (a == null) return 1; // null trié APRÈS (position déterministe)
  if (b == null) return -1;
  return a.compareTo(b);
}

/// Examen approchant décoré de son **index d'entrée** (support du tri stable D5).
class _IndexedExam {
  const _IndexedExam(this.index, this.exam);

  final int index;
  final ZApproachingExam exam;
}
