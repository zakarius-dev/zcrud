/// Famille de tâches quotidiennes `ZDailyStudyTask` + port neutre
/// `ZApproachingExam`.
///
/// Famille éphémère, jamais persistée, sans `fromJson`/`toJson`, à deux
/// variantes (« cartes dues » / « examen approchant »). Sert à peindre une
/// vue « Aujourd'hui » (cartes dues + examens approchants).
///
/// ## Famille ouverte (interface + discriminant `String kind`), jamais `sealed`
///
/// L'invariant AD-4 rejette explicitement `sealed` pour l'extension
/// inter-paquet. [ZDailyStudyTask] est donc une `abstract interface class`
/// portant un discriminant opaque `String kind` (même patron que
/// `ZSessionCandidate.typeKey`).
///
/// Un consommateur dispatche via `switch (task.kind) { case 'dueCards': …
/// case 'exam': … default: … }` avec un `default` obligatoire (aucune
/// exhaustivité figée) : un satellite futur peut ajouter une variante
/// `implements ZDailyStudyTask` sans modifier le kernel (invariant AD-4).
///
/// Non persisté ⇒ aucun registre de type, aucun codegen — la machinerie
/// d'enregistrement par nature/décodeur est réservée aux types sérialisés.
///
/// ## Le port neutre `ZApproachingExam` (acyclicité, invariant AD-1)
///
/// Le kernel ne dépend d'aucun satellite : `aggregateDailyStudyTasks` ne
/// peut pas importer un type d'examen concret. [ZApproachingExam] est donc
/// un port pur-Dart défini ici (même patron que [ZSessionCandidate] : port
/// au kernel, implémenté côté satellite). Une entité d'examen réelle peut
/// déjà avoir la forme structurelle du port (`isApproaching(now)` /
/// `daysUntil(now)` / `date`) sans encore l'`implements` — ce câblage est
/// additif, trivial et différé au consommateur. Le kernel reste ignorant du
/// type d'examen concret ; l'agrégation est testée avec un double local
/// implémentant le port.
library;

/// Tâche quotidienne d'étude — famille ouverte (invariant AD-4).
///
/// Discriminée par [kind] (`String` opaque). Jamais `sealed` : un satellite
/// peut ajouter une variante sans toucher au kernel (dispatch `kind` +
/// `default`).
abstract interface class ZDailyStudyTask {
  /// Discriminant opaque de variante (ex. `'dueCards'`, `'exam'`), comparé
  /// tel quel par les consommateurs (`switch (task.kind) { … default: … }`).
  String get kind;
}

/// Ligne « cartes dues » — présente ssi `count > 0`, toujours en tête de
/// l'agrégation. Immuable, `==`/`hashCode` de valeur (clé de rebuild
/// stable).
class ZDueCardsTask implements ZDailyStudyTask {
  /// Construit une tâche « cartes dues » (constructeur `const`).
  ///
  /// L'entité elle-même ne garde pas `count > 0` (invariant AD-10, aucun
  /// `assert` en `const`) : c'est [aggregateDailyStudyTasks] qui n'en émet
  /// pas quand `dueCount <= 0`.
  const ZDueCardsTask(this.count);

  /// Nombre de cartes dues (fourni par l'appelant, jamais recalculé).
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
/// vrai, triés par date d'échéance croissante, après la ligne dues.
/// Immuable, `==`/`hashCode` de valeur (sur [exam] + [daysUntil]).
class ZExamTask implements ZDailyStudyTask {
  /// Construit une tâche « examen approchant » (constructeur `const`).
  const ZExamTask(this.exam, this.daysUntil);

  /// L'examen approchant (consommé via le port neutre [ZApproachingExam]).
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

/// Port neutre pur-Dart d'un examen consommé par l'agrégation quotidienne
/// (invariant AD-1).
///
/// Contrat minimal que [aggregateDailyStudyTasks] applique sans dépendre
/// d'un satellite concret : c'est la clé de voûte du découplage acyclique
/// (même patron que [ZSessionCandidate]). Structurellement satisfaisable par
/// une entité d'examen réelle — le câblage `implements` est différé au
/// consommateur.
///
/// Toutes les méthodes sont pures, totales, déterministes et prennent
/// l'horloge `now` en paramètre (jamais de `DateTime.now()` interne) —
/// comparaison UTC-normalisée (aucune dérive DST/fuseau).
abstract interface class ZApproachingExam {
  /// `true` si un rappel est dû au regard de [now] (rappels activés, date
  /// présente, non passé, sous un seuil de rappel). `false` sinon — jamais
  /// de `throw`.
  bool isApproaching(DateTime now);

  /// Jours calendaires (UTC) de [now] jusqu'à l'échéance, ou `null` si
  /// aucune [date] (méthode totale). Positif = futur, `0` = jour J, négatif
  /// = passé.
  int? daysUntil(DateTime now);

  /// Date d'échéance (clé de tri), ou `null` si non planifiée.
  DateTime? get date;
}
