/// `zAdvanceStreak` — avancement pur de la flamme d'assiduité.
///
/// Pur (invariant AD-14) : aucune I/O, aucun état, aucun `DateTime.now()` —
/// l'instant est un paramètre. Une source non déterministe capturée rend un
/// test soit flaky, soit tautologique ; c'est la même discipline que tout
/// aléa injecté en paramètre.
///
/// Cette fonction est appelée par l'hôte après une répétition notée. Aucun
/// moteur de session n'est modifié par ce fichier.
library;

import 'z_review_mode.dart';
import 'z_study_streak.dart';

/// Issue d'un [zAdvanceStreak] — un enum, jamais un `bool` : un simple
/// booléen ne saurait pas dire *pourquoi* rien n'a bougé.
///
/// Non persisté (valeur de retour runtime) ⇒ aucun `@JsonKey
/// (unknownEnumValue:)` à déclarer.
enum ZStreakOutcome {
  /// Toute première répétition notée : la série démarre à `1`.
  started,

  /// Jour civil suivant le dernier jour noté : la série s'allonge.
  incremented,

  /// Déjà noté ce jour civil : série inchangée (idempotent).
  alreadyCountedToday,

  /// Trou d'au moins un jour civil complet : la série repart à `1`, jamais
  /// à `0` — la répétition du jour compte.
  resetToOne,

  /// Mode non noté (consultation, test, examen blanc, bachotage) : streak
  /// strictement inchangé.
  skippedNotGraded,
}

/// Résultat d'un avancement : le [streak] résultant + l'[outcome] qui
/// explique ce qui s'est passé (l'hôte s'en sert pour décider d'une
/// notification).
class ZStreakAdvance {
  /// Construit un résultat d'avancement.
  const ZStreakAdvance({required this.streak, required this.outcome});

  /// Streak résultant (l'entrée elle-même si rien n'a bougé).
  final ZStudyStreak streak;

  /// Ce qui s'est passé (jamais un `bool`).
  final ZStreakOutcome outcome;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStreakAdvance &&
          streak == other.streak &&
          outcome == other.outcome;

  @override
  int get hashCode => Object.hash(streak, outcome);

  @override
  String toString() => 'ZStreakAdvance(streak: $streak, outcome: $outcome)';
}

/// Modes qui écrivent réellement de la répétition espacée ⇒ les seuls qui
/// font avancer la flamme.
///
/// La règle réelle est « répétition notée », pas « hors consultation » :
/// seuls [ZReviewMode.spaced] et [ZReviewMode.learn] écrivent l'état de
/// répétition espacée. [ZReviewMode.list] (la consultation),
/// [ZReviewMode.cramming], [ZReviewMode.test] et [ZReviewMode.whiteExam]
/// sont donc exclus par la même règle, jamais par un cas particulier.
///
/// Le test énumère `ZReviewMode.values` : un mode ajouté demain casse la
/// suite tant qu'il n'est pas classé ici — garde délibérée contre l'oubli.
const Set<ZReviewMode> _gradedModes = <ZReviewMode>{
  ZReviewMode.spaced,
  ZReviewMode.learn,
};

/// Le mode [mode] correspond-il à une répétition notée (⇒ fait avancer la
/// flamme) ? Voir [_gradedModes] pour la règle et son périmètre.
bool zIsGradedMode(ZReviewMode mode) => _gradedModes.contains(mode);

/// Fait avancer la flamme d'assiduité — fonction pure.
///
/// - [current] : streak actuel ;
/// - [at] : instant de la répétition — paramètre (invariant AD-14 :
///   `DateTime.now()` est interdit dans ce corps) ;
/// - [mode] : mode de session — seuls `spaced`/`learn` avancent ;
/// - [civilDayOf] : dérivation instant → jour civil, défaut [zLocalCivilDay]
///   (jour civil local). Injectable : c'est ce qui rend un jour d'heure
///   d'été/hiver (23 h ou 25 h) réellement testable sans dépendre du fuseau
///   horaire de l'environnement d'exécution.
///
/// ## Comportement — le tableau, exactement
///
/// | `lastGradedDay` vs jour civil de [at] | Résultat |
/// |---|---|
/// | `null` (ou illisible) | `current = 1`, [ZStreakOutcome.started] |
/// | `== jour(at)` | inchangé (idempotent), [ZStreakOutcome.alreadyCountedToday] |
/// | `== jour(at) - 1` | `current + 1`, [ZStreakOutcome.incremented] |
/// | `< jour(at) - 1` (trou) | `current = 1`, [ZStreakOutcome.resetToOne] — jamais 0 |
/// | `> jour(at)` (date future) | inchangé, [ZStreakOutcome.alreadyCountedToday] (repli défensif) |
///
/// `best = max(best, current)` après application.
///
/// ## Jour civil : jamais une durée
///
/// L'écart est `zParseCivilDayNumber(jour(at)) - zParseCivilDayNumber(last)`
/// — une soustraction d'entiers de calendrier (voir [zCivilDayNumber]).
/// `at.difference(other).inDays` est interdit : il mesure du temps écoulé et
/// rend `0` pour un jour d'heure d'été/hiver de 23 h (« hier → aujourd'hui »
/// deviendrait `alreadyCountedToday` : la flamme se figerait), et `0` aussi
/// pour `23:59:59 → 00:00:01` (2 s d'écart réel, mais deux jours civils).
///
/// ## Robustesse (invariant AD-10) — jamais de `throw`
///
/// - `lastGradedDay` illisible (corruption) ⇒ traité comme `null` ⇒
///   `started` (repli sûr, cohérent avec le décodeur de streak qui applique
///   le même critère — aucune date ne tombe entre les deux) ;
/// - `civilDayOf` rendant une valeur illisible ⇒ streak inchangé
///   ([ZStreakOutcome.alreadyCountedToday]) : on ne corrompt jamais la série
///   sur une horloge folle ;
/// - date future persistée (horloge reculée) ⇒ jamais de `current` négatif,
///   jamais de `throw` ;
/// - idempotence : rejouer N fois le même [at] rend strictement le même
///   résultat (le 2ᵉ appel voit `last == jour(at)`).
ZStreakAdvance zAdvanceStreak(
  ZStudyStreak current, {
  required DateTime at,
  required ZReviewMode mode,
  ZCivilDayOf civilDayOf = zLocalCivilDay,
}) {
  // Hors répétition notée (dont la consultation `list`) : strictement
  // inchangé. L'objet d'entrée est rendu tel quel.
  if (!zIsGradedMode(mode)) {
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.skippedNotGraded,
    );
  }

  final today = civilDayOf(at);
  final todayNumber = zParseCivilDayNumber(today);
  if (todayNumber == null) {
    // Une dérivation de jour folle ne corrompt jamais la série.
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.alreadyCountedToday,
    );
  }

  final lastNumber = zParseCivilDayNumber(current.lastGradedDay);
  if (lastNumber == null) {
    // Jamais noté (ou jour persisté illisible) ⇒ la série démarre à 1.
    return ZStreakAdvance(
      streak: _applied(current, next: 1, day: today),
      outcome: ZStreakOutcome.started,
    );
  }

  // Écart en jours civils — entiers de calendrier, jamais une Duration.
  final gap = todayNumber - lastNumber;

  if (gap == 0) {
    // Déjà noté aujourd'hui ⇒ idempotent, rien ne bouge.
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.alreadyCountedToday,
    );
  }
  if (gap < 0) {
    // Date future persistée (horloge reculée) — repli inchangé, jamais de
    // `current` négatif, jamais de `throw`.
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.alreadyCountedToday,
    );
  }
  if (gap == 1) {
    // Plancher à 1 : `current.current + 1` nu propagerait un négatif. La
    // dartdoc de `ZStudyStreak.current` promet une valeur jamais négative,
    // garantie par le décodeur ET par cette fonction. Le constructeur est
    // `const` sans assert (délibéré, invariant AD-10 : le décodeur généré
    // l'appelle avec des valeurs brutes) et le `copyWith` généré est
    // public, donc un appelant qui forcerait un `current` négatif à J
    // rendrait un résultat négatif à J+1, que le badge afficherait et
    // annoncerait tel quel. Cette branche — la seule voie d'avancement —
    // planche donc aussi : une série qui avance vaut au moins 1.
    final next = current.current < 0 ? 1 : current.current + 1;
    return ZStreakAdvance(
      streak: _applied(current, next: next, day: today),
      outcome: ZStreakOutcome.incremented,
    );
  }
  // Trou >= 1 jour civil complet ⇒ reset à 1, jamais à 0 (la répétition du
  // jour compte).
  return ZStreakAdvance(
    streak: _applied(current, next: 1, day: today),
    outcome: ZStreakOutcome.resetToOne,
  );
}

/// Applique la série [next] et le jour [day], en maintenant l'invariant
/// `best = max(best, current)`.
ZStudyStreak _applied(ZStudyStreak streak, {required int next, required String day}) =>
    streak.copyWith(
      current: next,
      best: next > streak.best ? next : streak.best,
      lastGradedDay: day,
    );
