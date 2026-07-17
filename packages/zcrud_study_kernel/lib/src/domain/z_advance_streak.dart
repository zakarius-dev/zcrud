/// `zAdvanceStreak` — avancement PUR de la flamme d'assiduité (SU-6, FR-SU11,
/// AC2/AC3/AC4 — décisions D5/D6/D7).
///
/// **PUR** (AD-14) : aucune I/O, aucun état, **aucun `DateTime.now()`** —
/// l'instant est un **PARAMÈTRE**. Une source non déterministe *capturée* rend le
/// test soit flaky, soit tautologique ; c'est la même discipline que l'aléa
/// injecté (`Random` en paramètre, D5).
///
/// **D7 — su-6 ne câble AUCUN moteur** : cette fonction est appelée par l'hôte
/// **après** une répétition notée. Aucun runtime (`ZStudySessionEngine`/
/// `ZSessionReviewer`/`ZSessionCardSwiper`) n'est modifié (AD-34).
library;

import 'z_review_mode.dart';
import 'z_study_streak.dart';

/// Issue d'un [zAdvanceStreak] — **enum, jamais un `bool`** (AC15 : la
/// convention du spine préfère les enums aux booléens ; `didIncrement` ne saurait
/// pas dire *pourquoi* rien n'a bougé).
///
/// **NON persisté** (valeur de retour **runtime**) ⇒ pas de
/// `@JsonKey(unknownEnumValue:)` à déclarer — consigné (AC15).
enum ZStreakOutcome {
  /// Toute **première** répétition notée : la série démarre à `1`.
  started,

  /// Jour civil **suivant** le dernier jour noté : la série s'allonge.
  incremented,

  /// Déjà noté **ce jour civil** : série **inchangée** (idempotent — AC3).
  alreadyCountedToday,

  /// 🔴 **Trou** d'au moins un jour civil complet : la série repart à **`1`**,
  /// **JAMAIS à `0`** — la répétition du jour **compte** (spine, § « Écarts
  /// assumés » ; le PRD « remise à zéro » est **déjà amendé**, cf. écart E2).
  resetToOne,

  /// Mode **non noté** (`list` = la consultation, `test`, `whiteExam`,
  /// `cramming`) : streak **strictement inchangé** (AC4/D6).
  skippedNotGraded,
}

/// Résultat d'un avancement : le [streak] résultant + l'[outcome] qui explique
/// ce qui s'est passé (l'hôte s'en sert pour décider du toast — AC6).
class ZStreakAdvance {
  /// Construit un résultat d'avancement.
  const ZStreakAdvance({required this.streak, required this.outcome});

  /// Streak **résultant** (l'entrée elle-même si rien n'a bougé).
  final ZStudyStreak streak;

  /// Ce qui s'est passé (jamais un `bool` — AC15).
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

/// Modes qui écrivent réellement du SRS ⇒ les **seuls** qui font avancer la
/// flamme (AC4 / **D6**).
///
/// **La règle RÉELLE est « répétition NOTÉE »**, pas « hors consultation » :
/// FR-SU11 dit « incrément à la première **répétition notée** du jour », et
/// AD-34 établit que **seuls** [ZReviewMode.spaced] et [ZReviewMode.learn]
/// écrivent le SRS. [ZReviewMode.list] (**la consultation**),
/// [ZReviewMode.cramming], [ZReviewMode.test] et [ZReviewMode.whiteExam] sont
/// donc exclus **par la même règle**, jamais par un cas particulier.
///
/// ⚠️ Consigné : les epics n'exigent **littéralement** que l'exclusion de la
/// consultation ; exclure aussi les 3 autres modes non-SRS est un **sur-ensemble**
/// assumé, cohérent avec « notée ». Le test **énumère `ZReviewMode.values`**
/// (AC4) ⇒ un **7ᵉ mode** ajouté demain **casse** la suite tant qu'il n'est pas
/// classé ici.
const Set<ZReviewMode> _gradedModes = <ZReviewMode>{
  ZReviewMode.spaced,
  ZReviewMode.learn,
};

/// Le mode [mode] correspond-il à une **répétition notée** (⇒ fait avancer la
/// flamme) ? Voir [_gradedModes] pour la règle et son périmètre.
bool zIsGradedMode(ZReviewMode mode) => _gradedModes.contains(mode);

/// Fait avancer la flamme d'assiduité — **fonction PURE** (AC2).
///
/// - [current] : streak actuel ;
/// - [at] : instant de la répétition — **PARAMÈTRE** (AD-14 : `DateTime.now()`
///   est **interdit** dans ce corps) ;
/// - [mode] : mode de session — seuls `spaced`/`learn` avancent (AC4/D6) ;
/// - [civilDayOf] : dérivation **instant → jour civil**, défaut [zLocalCivilDay]
///   (jour civil **LOCAL**). **Injectable** : c'est ce qui rend le DST (jour de
///   23 h / 25 h) réellement testable sans dépendre du `TZ` de la CI (AC3).
///
/// ## Comportement (AC2) — le tableau, exactement
///
/// | `lastGradedDay` vs jour civil de [at] | Résultat |
/// |---|---|
/// | `null` (ou **illisible**) | `current = 1`, [ZStreakOutcome.started] |
/// | `== jour(at)` | **inchangé** (idempotent), [ZStreakOutcome.alreadyCountedToday] |
/// | `== jour(at) - 1` | `current + 1`, [ZStreakOutcome.incremented] |
/// | `< jour(at) - 1` (trou) | 🔴 `current = 1`, [ZStreakOutcome.resetToOne] — **jamais 0** |
/// | `> jour(at)` (date **future**) | **inchangé**, [ZStreakOutcome.alreadyCountedToday] (repli AD-10) |
///
/// `best = max(best, current)` après application.
///
/// ## 🔴 Jour civil : jamais une durée (AC3)
///
/// L'écart est `zParseCivilDayNumber(jour(at)) - zParseCivilDayNumber(last)` —
/// une soustraction d'**entiers de calendrier** (cf. [zCivilDayNumber]).
/// `at.difference(other).inDays` est **INTERDIT** : il mesure du **temps
/// écoulé** et rend `0` pour un jour de DST de 23 h (« hier → aujourd'hui »
/// deviendrait `alreadyCountedToday` : la flamme se figerait), et `0` aussi pour
/// `23:59:59 → 00:00:01` (2 s d'écart réel, mais **deux jours civils**).
///
/// ## Robustesse (AD-10) — **jamais** de throw
///
/// - `lastGradedDay` **illisible** (corruption) ⇒ traité comme `null` ⇒
///   `started` (repli sûr, cohérent avec [ZStudyStreak.fromMap] qui applique le
///   **même** critère [zIsCivilDay] — aucune date ne tombe entre les deux) ;
/// - `civilDayOf` rendant une valeur **illisible** ⇒ streak **inchangé**
///   ([ZStreakOutcome.alreadyCountedToday]) : on ne corrompt jamais la série sur
///   une horloge folle ;
/// - date **future** persistée (horloge reculée) ⇒ **jamais** de `current`
///   négatif, **jamais** de throw ;
/// - **idempotence** : rejouer N fois le même [at] rend **strictement** le même
///   résultat (le 2ᵉ appel voit `last == jour(at)`).
ZStreakAdvance zAdvanceStreak(
  ZStudyStreak current, {
  required DateTime at,
  required ZReviewMode mode,
  ZCivilDayOf civilDayOf = zLocalCivilDay,
}) {
  // AC4/D6 — hors répétition notée (dont la consultation `list`) : STRICTEMENT
  // inchangé. L'objet d'entrée est rendu tel quel (assertion `equals(before)`).
  if (!zIsGradedMode(mode)) {
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.skippedNotGraded,
    );
  }

  final today = civilDayOf(at);
  final todayNumber = zParseCivilDayNumber(today);
  if (todayNumber == null) {
    // AD-10 — une dérivation de jour folle ne corrompt jamais la série.
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

  // 🔴 Écart en JOURS CIVILS — entiers de calendrier, jamais une Duration.
  final gap = todayNumber - lastNumber;

  if (gap == 0) {
    // Déjà noté aujourd'hui ⇒ idempotent, rien ne bouge.
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.alreadyCountedToday,
    );
  }
  if (gap < 0) {
    // Date FUTURE persistée (horloge reculée) — AD-10 : repli inchangé, jamais
    // de `current` négatif, jamais de throw.
    return ZStreakAdvance(
      streak: current,
      outcome: ZStreakOutcome.alreadyCountedToday,
    );
  }
  if (gap == 1) {
    // 🔴 PLANCHER à 1 (code-review su-6, LOW-3). `current.current + 1` NU
    // propageait un négatif : la dartdoc de `ZStudyStreak.current` promet
    // « **Jamais négatif** — garanti par `fromMap` ET par `zAdvanceStreak` »,
    // or cette branche ne le garantissait pas. Le constructeur est `const` SANS
    // assert (délibéré : AD-10 — le décodeur généré l'appelle avec des valeurs
    // brutes) et le `copyWith` généré est public, donc
    // `streak.copyWith(current: -5)` + un jour civil J+1 rendait **-4**, que le
    // badge AFFICHAIT et annonçait (`Semantics(value: '-4')`).
    //
    // `fromMap` (la frontière de persistance) planche déjà ; cette voie — **la
    // seule voie d'avancement** — planche désormais aussi. L'invariant devient
    // VRAI sur tous les chemins, au lieu d'être rétréci dans la prose : une
    // série qui avance vaut au moins 1, comme `started` et `resetToOne`.
    final next = current.current < 0 ? 1 : current.current + 1;
    return ZStreakAdvance(
      streak: _applied(current, next: next, day: today),
      outcome: ZStreakOutcome.incremented,
    );
  }
  // Trou >= 1 jour civil COMPLET ⇒ 🔴 reset à **1**, JAMAIS à 0 (la répétition
  // du jour compte — spine § « Écarts assumés », écart E2).
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
