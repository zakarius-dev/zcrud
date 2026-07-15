/// Famille de tâches quotidiennes `ZDailyStudyTask` + port neutre
/// `ZApproachingExam` (ES-2.7, **FR-S10**).
///
/// origine: lex_core (module « Étude ») —
/// `entities/education/daily_study_task.dart` (famille ÉPHÉMÈRE, jamais
/// persistée, aucun `fromJson`/`toJson`, deux variantes `DueCardsTask(count)` /
/// `ExamTask(exam, daysUntil)`). Sert à peindre la vue « Aujourd'hui » (cartes
/// dues + examens approchants).
///
/// ## 🔴 D2 — famille OUVERTE (interface + discriminant `String kind`), JAMAIS `sealed`
///
/// La source lex est une **`sealed class`**. **AD-4 REJETTE explicitement
/// `sealed` pour l'extension inter-package** (« Rejetés : … `sealed` pour
/// l'extension inter-package »), et l'épic exige « sans switch exhaustif figé ».
/// ⇒ [ZDailyStudyTask] est une **`abstract interface class`** portant un
/// discriminant **opaque** `String kind` (précédent `ZSessionCandidate.typeKey`
/// / `ZFlashcardSource.kind`).
///
/// Un consommateur dispatche via `switch (task.kind) { case 'dueCards': … case
/// 'exam': … default: … }` avec un **`default` OBLIGATOIRE** (aucune exhaustivité
/// figée) : un satellite futur (ES-2.8 podcast, ES-9) peut **AJOUTER** une
/// variante `implements ZDailyStudyTask` **sans modifier le kernel** (AD-4).
///
/// **Non persisté** ⇒ AUCUN `ZTypeRegistry`, AUCUN codegen, AUCUN câblage de
/// gate (YAGNI — la machinerie `register(kind, fromJson, toJson)` est réservée
/// aux types SÉRIALISÉS).
///
/// ## 🔴 D3 — le port neutre `ZApproachingExam` (acyclicité AD-1/AD-17)
///
/// Le kernel **ne dépend d'AUCUN satellite** : `aggregateDailyStudyTasks` ne peut
/// PAS importer `zcrud_exam`/`ZExam`. [ZApproachingExam] est donc un **port
/// pur-Dart** défini ICI (précédent EXACT `ZSessionCandidate` : port au kernel,
/// implémenté côté satellite). `ZExam` (ES-2.6) a **déjà** la forme structurelle
/// du port (`isApproaching(now)` / `daysUntil(now)` / `date`) mais ne l'`implements`
/// pas encore — le câblage `ZExam implements ZApproachingExam` (ou un adaptateur)
/// est **additif, trivial et DÉFÉRÉ au consommateur** (ES-9.2 / ES-5, D10). Le
/// kernel reste **ignorant de `ZExam`** ; l'agrégation est testée avec un
/// **double** local implémentant le port.
library;

/// Tâche quotidienne d'étude — famille **OUVERTE** (AD-4, D2).
///
/// Discriminée par [kind] (`String` opaque). **JAMAIS `sealed`** : un satellite
/// peut ajouter une variante sans toucher au kernel (dispatch `kind` + `default`).
abstract interface class ZDailyStudyTask {
  /// Discriminant **opaque** de variante (ex. `'dueCards'`, `'exam'`), comparé
  /// tel quel par les consommateurs (`switch (task.kind) { … default: … }`).
  String get kind;
}

/// Ligne « cartes dues » — présente **ssi `count > 0`**, toujours **en tête** de
/// l'agrégation (D3). Immuable, `==`/`hashCode` de valeur (clé de rebuild stable).
class ZDueCardsTask implements ZDailyStudyTask {
  /// Construit une tâche « cartes dues » (primitif `const`).
  ///
  /// L'entité elle-même **ne garde pas** `count > 0` (AD-10, aucun `assert` en
  /// `const`) : c'est [aggregateDailyStudyTasks] qui n'en **émet pas** quand
  /// `dueCount <= 0`.
  const ZDueCardsTask(this.count);

  /// Nombre de cartes dues (fourni par l'appelant, jamais recalculé — parité lex).
  final int count;

  @override
  String get kind => 'dueCards';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDueCardsTask && count == other.count;

  @override
  int get hashCode => Object.hash('dueCards', count);

  @override
  String toString() => 'ZDueCardsTask($count)';
}

/// Ligne « examen approchant » — un par examen dont `isApproaching(now)` est
/// vrai, triés par date d'échéance croissante, **après** la ligne dues (D3).
/// Immuable, `==`/`hashCode` de valeur (sur [exam] + [daysUntil]).
class ZExamTask implements ZDailyStudyTask {
  /// Construit une tâche « examen approchant » (primitif `const`).
  const ZExamTask(this.exam, this.daysUntil);

  /// L'examen approchant (consommé via le port neutre [ZApproachingExam], D3).
  final ZApproachingExam exam;

  /// Jours calendaires (UTC) jusqu'à l'échéance, au regard du `now` injecté
  /// (`0` = jour J, positif = futur). Dérivé de `exam.daysUntil(now)`.
  final int daysUntil;

  @override
  String get kind => 'exam';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZExamTask &&
          exam == other.exam &&
          daysUntil == other.daysUntil;

  @override
  int get hashCode => Object.hash('exam', exam, daysUntil);

  @override
  String toString() => 'ZExamTask($exam, daysUntil: $daysUntil)';
}

/// Port **NEUTRE** pur-Dart d'un examen consommé par l'agrégation quotidienne
/// (D3, AD-1/AD-17).
///
/// Contrat MINIMAL que [aggregateDailyStudyTasks] applique sans dépendre d'un
/// satellite concret : c'est la clé de voûte du découplage acyclique (précédent
/// `ZSessionCandidate`). Structurellement satisfait par `ZExam` (ES-2.6) —
/// câblage `implements` DÉFÉRÉ au consommateur (D10).
///
/// Toutes les méthodes sont **PURES, TOTALES, DÉTERMINISTES** et prennent
/// l'horloge `now` en **PARAMÈTRE** (jamais de `DateTime.now()` interne, R5) —
/// comparaison UTC-normalisée héritée de `ZExam` (aucune dérive DST/fuseau, D4).
abstract interface class ZApproachingExam {
  /// `true` si un rappel est **dû** au regard de [now] (rappels activés, date
  /// présente, non passé, sous un seuil de rappel). `false` sinon — jamais throw.
  bool isApproaching(DateTime now);

  /// Jours calendaires (UTC) de [now] jusqu'à l'échéance, ou **`null`** si aucune
  /// [date] (méthode TOTALE). Positif = futur, `0` = jour J, négatif = passé.
  int? daysUntil(DateTime now);

  /// Date d'échéance (clé de tri), ou `null` si non planifiée.
  DateTime? get date;
}
