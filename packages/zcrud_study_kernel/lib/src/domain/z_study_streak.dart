/// Entité canonique `ZStudyStreak` — la « flamme » d'assiduité.
///
/// Vit dans `zcrud_study_kernel` : le streak n'a besoin que de dates —
/// aucune dépendance à la configuration de répétition espacée ni à son
/// état ⇒ il ne réclame aucune arête sortante supplémentaire (le kernel ne
/// dépend que de `zcrud_core` et `zcrud_annotations`, invariant AD-1).
///
/// Pur-Dart, zéro import Flutter (le kernel tourne sous `dart test`).
///
/// Généré par `@ZcrudModel` (invariant AD-3) : `melos run generate` émet le
/// fichier compagnon (suivi par git sous `packages/*/lib/`) portant le
/// décodeur défensif, l'extension `toMap`/`copyWith`, les spécifications de
/// champ et l'enregistrement au registre.
///
/// Non `ZExtensible` (comme les value objects du kernel) : le streak est un
/// compteur d'assiduité fermé — ni `extra`, ni `extension`. La délégation au
/// décodeur généré est donc autorisée (le générateur ne rejette la
/// délégation nue que pour les types `ZExtensible`). [ZStudyStreak.fromMap]
/// ne délègue toutefois pas nuement : elle sanitise en plus les compteurs
/// négatifs et le jour civil illisible.
///
/// ## Le jour civil : arithmétique calendaire, jamais une durée
///
/// [lastGradedDay] est une date civile `yyyy-MM-dd`, jamais un instant.
/// C'est un choix structurel, pas cosmétique : `at.difference(other).inDays`
/// est interdit ici parce qu'il mesure du temps écoulé, pas des jours de
/// calendrier — un jour d'heure d'été/hiver dure 23 h (⇒ `inDays` rend `0`
/// pour « hier → aujourd'hui » : le streak casserait) ou 25 h. En ne
/// stockant que des champs civils et en ne comparant que des numéros de
/// jour civil ([zCivilDayNumber], arithmétique entière pure — algorithme de
/// Hinnant), la classe de bug liée au changement d'heure est
/// structurellement hors d'atteinte : aucune `Duration` n'intervient
/// jamais.
///
/// **Horloge paramétrée (invariant AD-14)** : cette bibliothèque n'appelle
/// jamais `DateTime.now()`. Le seul point de dérivation « instant → jour
/// civil » est [ZCivilDayOf] (défaut [zLocalCivilDay], qui lit les champs
/// locaux `at.year/month/day`), injectable — c'est ce qui rend le
/// changement d'heure réellement testable sans dépendre du fuseau de la
/// machine d'exécution.
///
/// Aucune clé de synchronisation (mise à jour, suppression) inline — la
/// fraîcheur Last-Write-Wins et le soft-delete vivent hors-entité
/// (`ZSyncMeta`, côté repository — invariant AD-9).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_study_streak.g.dart';

/// Dérive le jour civil (`yyyy-MM-dd`) d'un instant — le seul point de
/// dérivation instant → jour.
///
/// Injectable (invariant AD-14) : `zAdvanceStreak` le reçoit en paramètre,
/// défaut [zLocalCivilDay]. Un test substitue un calendrier simulé pour
/// éprouver un jour de 23 h / 25 h (changement d'heure) sans dépendre du
/// fuseau de l'environnement d'exécution — impossible autrement.
typedef ZCivilDayOf = String Function(DateTime at);

/// Jour civil local de [at], au format ISO-8601 `yyyy-MM-dd` (défaut de
/// [ZCivilDayOf]).
///
/// Lit les champs locaux `at.year`/`at.month`/`at.day` — le calendrier de
/// l'apprenant, jamais UTC (un même instant peut tomber sur deux jours
/// civils différents selon le fuseau : c'est le local qui fait foi).
///
/// N'effectue aucune arithmétique de durée (pas de `DateTime.add`, pas de
/// `difference`) ⇒ insensible au changement d'heure par construction.
String zLocalCivilDay(DateTime at) => zFormatCivilDay(at.year, at.month, at.day);

/// Formate un triplet civil en `yyyy-MM-dd` (zéro-padding strict).
String zFormatCivilDay(int year, int month, int day) {
  final y = year.toString().padLeft(4, '0');
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Motif strict d'un jour civil `yyyy-MM-dd` (4-2-2, zéro-padé).
final RegExp _civilDayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Nombre de jours du mois [month] de l'année [year] (bissextiles incluses).
int _daysInMonth(int year, int month) {
  const lengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2) {
    final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    return leap ? 29 : 28;
  }
  return lengths[month - 1];
}

/// [day] est-il un jour civil lisible (`yyyy-MM-dd`, date réellement
/// existante) ?
///
/// Défensif (invariant AD-10) : rend `false` — jamais de `throw` — pour
/// `null`, une chaîne vide, un format libre (`'28/03/2026'`), ou une date
/// impossible (`'2026-02-31'`, `'2026-13-01'`). C'est le critère unique de
/// lisibilité consommé par [ZStudyStreak.fromMap] et par `zAdvanceStreak` :
/// aucune date ne peut tomber entre les deux.
bool zIsCivilDay(String? day) => zParseCivilDayNumber(day) != null;

/// Parse un jour civil `yyyy-MM-dd` en numéro de jour civil, ou `null` si
/// illisible (jamais de `throw` — invariant AD-10).
///
/// C'est la voie unique de conversion `String → numéro de jour` : elle
/// n'utilise aucun `DateTime` (donc aucun fuseau, aucun changement d'heure).
/// Voir [zCivilDayNumber].
int? zParseCivilDayNumber(String? day) {
  if (day == null) return null;
  final match = _civilDayPattern.firstMatch(day);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final dayOfMonth = int.tryParse(match.group(3)!);
  if (year == null || month == null || dayOfMonth == null) return null;
  if (month < 1 || month > 12) return null;
  if (dayOfMonth < 1 || dayOfMonth > _daysInMonth(year, month)) return null;
  return zCivilDayNumber(year, month, dayOfMonth);
}

/// Numéro de jour civil (jours depuis l'époque civile 1970-01-01) — pure
/// arithmétique entière, algorithme *days_from_civil* de Howard Hinnant.
///
/// C'est le cœur de l'immunité au changement d'heure : la distance entre
/// deux jours civils est `zCivilDayNumber(a) - zCivilDayNumber(b)` — une
/// soustraction d'entiers de calendrier. Elle vaut `1` pour « hier →
/// aujourd'hui » quelle que soit la durée réelle écoulée (23 h en heure
/// d'été, 25 h en heure d'hiver, 2 s pour `23:59:59 → 00:00:01`).
/// `at.difference(o).inDays`, lui, rendrait respectivement `0`, `1` et `0`
/// — trois réponses fausses.
///
/// Aucune `DateTime`, aucune `Duration`, aucun fuseau n'intervient.
int zCivilDayNumber(int year, int month, int day) {
  final y = year - (month <= 2 ? 1 : 0);
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yearOfEra = y - era * 400; // [0, 399]
  final dayOfYear =
      (153 * (month + (month > 2 ? -3 : 9)) + 2) ~/ 5 + day - 1; // [0, 365]
  final dayOfEra =
      yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
  return era * 146097 + dayOfEra - 719468;
}

/// Série d'assiduité (« flamme ») — compteur de jours civils consécutifs
/// portant au moins une répétition notée.
@ZcrudModel(kind: 'study_streak', fieldRename: ZFieldRename.snake)
class ZStudyStreak extends ZEntity {
  /// Construit un streak (constructeur nominal `const` — source du
  /// `copyWith`).
  ///
  /// Aucun `assert` (invariant AD-10 : le décodeur généré l'appelle avec
  /// des valeurs brutes — un `assert` ferait lever la désérialisation d'une
  /// donnée corrompue). Les invariants de valeur sont portés par [fromMap]
  /// (frontière d'entrée) et par `zAdvanceStreak` (voie d'avancement
  /// unique).
  const ZStudyStreak({
    this.id,
    this.current = 0,
    this.best = 0,
    this.lastGradedDay,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Recopie le décodeur généré (défauts sûrs : `current`/`best` absents ou
  /// non-`int` → `0` ; `id`/`last_graded_day` absents → `null`) puis
  /// applique les deux sanitisations que le codegen ne peut pas connaître :
  /// - compteurs négatifs → `0` (un compteur d'assiduité n'est jamais
  ///   négatif) ;
  /// - [lastGradedDay] illisible → `null` (format libre ou date impossible,
  ///   critère unique [zIsCivilDay]) ⇒ le streak repart proprement
  ///   (`started`) au lieu de comparer une date fantôme.
  ///
  /// Aucun cas ne fait échouer le parent : `fromMap(const {})`,
  /// `{'current': 'x', 'best': -4}`, `{'last_graded_day': '28/03/2026'}`
  /// rendent tous un streak valide — jamais de `throw`.
  factory ZStudyStreak.fromMap(Map<String, dynamic> map) {
    final base = _$ZStudyStreakFromMap(map);
    final rawDay = base.lastGradedDay;
    return ZStudyStreak(
      id: base.id,
      current: base.current < 0 ? 0 : base.current,
      best: base.best < 0 ? 0 : base.best,
      lastGradedDay: zIsCivilDay(rawDay) ? rawDay : null,
    );
  }

  /// Identité opaque (nullable pour l'éphémère — invariant AD-14 ; jamais
  /// attribuée par l'entité, matérialisée au repository).
  @override
  @ZcrudId()
  final String? id;

  /// Série en cours — nombre de jours civils consécutifs notés. `0` =
  /// aucune série.
  ///
  /// Jamais négatif — la garantie porte sur toutes les voies :
  /// - [fromMap] (la frontière de persistance) planche les négatifs à `0` ;
  /// - `zAdvanceStreak` (la seule voie d'avancement) ne rend jamais moins
  ///   de `1` : `started`/`resetToOne` posent `1`, `incremented` planche
  ///   une entrée négative à `1` ;
  /// - `alreadyCountedToday`/`skippedNotGraded` rendent l'entrée inchangée
  ///   (ils ne créent donc aucun négatif).
  ///
  /// Portée honnête : le constructeur est `const` sans `assert` (délibéré
  /// — invariant AD-10 : le décodeur généré l'appelle avec des valeurs
  /// brutes) et le `copyWith` généré est public. Un appelant peut donc
  /// construire un `ZStudyStreak(current: -5)` en mémoire : rien ne l'en
  /// empêche, et rien ne lève. Ce que garantissent les voies ci-dessus,
  /// c'est qu'un tel objet ne peut ni naître d'une désérialisation, ni
  /// survivre à un `zAdvanceStreak`.
  @ZcrudField()
  final int current;

  /// Record historique de [current].
  ///
  /// Maintenu à `max(best, current)` par `zAdvanceStreak` — la seule voie
  /// d'avancement. Portée honnête : [fromMap] ne renforce pas `best >=
  /// current` (elle ne fait que plancher les négatifs à `0`) — une map
  /// corrompue est reconstruite telle quelle, pour préserver le round-trip
  /// zéro-perte (le constructeur est `const`, il ne peut rien normaliser ;
  /// le forcer ici casserait `fromMap(toMap(x)) == x`). Un `best < current`
  /// persisté est inoffensif (le badge affiche un record minoré, aucune
  /// exception) et se répare seul au premier `zAdvanceStreak`.
  @ZcrudField()
  final int best;

  /// Jour civil (`yyyy-MM-dd`, persisté `last_graded_day`) de la dernière
  /// répétition notée, ou `null` si aucune (jamais noté).
  ///
  /// Une date civile, jamais un instant : voir la dartdoc de bibliothèque —
  /// c'est ce qui rend la classe de bug liée au changement d'heure
  /// inatteignable. Toujours lisible sur une instance issue de [fromMap]
  /// (critère [zIsCivilDay]).
  @ZcrudField()
  final String? lastGradedDay;

  // Ni `toMap()` ni `copyWith()` écrits à la main, délibérément :
  // `ZStudyStreak` n'étant pas `ZExtensible` (aucun `extra`/`extension` que
  // le généré remettrait aux défauts), son `copyWith` généré est complet et
  // sûr — il est directement consommé.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyStreak &&
          id == other.id &&
          current == other.current &&
          best == other.best &&
          lastGradedDay == other.lastGradedDay;

  @override
  int get hashCode => Object.hash(id, current, best, lastGradedDay);

  @override
  String toString() => 'ZStudyStreak(id: $id, current: $current, best: $best, '
      'lastGradedDay: $lastGradedDay)';
}
