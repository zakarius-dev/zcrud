/// Récurrence de rappel — objet valeur pur combinant deux modèles temporels.
///
/// ## Le problème que ce type résout
///
/// Une entité d'examen peut n'exprimer qu'un seul modèle de rappel via
/// `reminderDaysBefore` — « rappeler **N jours avant** l'échéance ». C'est un
/// modèle **relatif**, ancré sur la date de l'examen.
///
/// Il en existe un second, tout aussi courant : **absolu-hebdomadaire** —
/// « rappeler **ces jours de la semaine** ». Les deux modèles ne sont **pas
/// inter-convertibles** : un *lundi* n'est pas « k jours avant » quelque
/// chose, et « 7 jours avant » ne désigne aucun jour de semaine particulier.
///
/// Sans ce type, une application portant le modèle hebdomadaire ne pouvait
/// que le loger dans `extra` : la donnée survivait au round-trip, mais
/// devenait invisible à toute logique de proximité générique.
///
/// ## Ce que ce type n'est pas
///
/// Ce n'est pas le remplacement de `reminderDaysBefore`, qui reste correct et
/// inchangé — une application n'utilisant que les seuils relatifs n'a rien à
/// modifier. Ce n'est pas non plus l'énumération de jours propre à une
/// application particulière : [weekdays] utilise la convention ISO-8601 de
/// `DateTime.weekday` (1 = lundi … 7 = dimanche).
///
/// ## Horloge injectée
///
/// [matches] prend `now` en **paramètre**. Aucun `DateTime.now()` implicite
/// dans ce paquet.
library;

// Pur-Dart : ce package n'a aucune dépendance Flutter (ses tests tournent
// sous `dart test`). Les comparaisons de listes et d'ensembles sont donc
// écrites à la main plus bas plutôt que d'importer `package:flutter/foundation.dart`
// pour `listEquals`/`setEquals`.

/// Récurrence de rappel couvrant les deux familles temporelles.
///
/// Les deux peuvent coexister : leur combinaison est un **ou** — le rappel se
/// déclenche si l'une ou l'autre correspond. C'est le comportement attendu
/// d'un utilisateur qui demande « tous les lundis, **et** la veille ».
class ZReminderRecurrence {
  /// Construit une récurrence. Les deux familles sont optionnelles ; les deux
  /// vides ⇒ [isEmpty], donc aucun rappel.
  const ZReminderRecurrence({
    this.daysBefore = const <int>[],
    this.weekdays = const <int>{},
  });

  /// Récurrence relative seule — forme équivalente au modèle historique
  /// `reminderDaysBefore`. Sert de pont : un hôte qui n'a jamais quitté ce
  /// modèle obtient le même comportement qu'avant.
  const ZReminderRecurrence.relative(this.daysBefore)
      : weekdays = const <int>{};

  /// Récurrence hebdomadaire seule (convention ISO : 1 = lundi … 7 =
  /// dimanche).
  const ZReminderRecurrence.weekly(this.weekdays)
      : daysBefore = const <int>[];

  /// Reconstruit défensivement une récurrence depuis une valeur persistée
  /// (invariant AD-10) — ne lève jamais, quelle que soit la corruption.
  ///
  /// Rend `null` si rien d'exploitable n'est présent : c'est un emplacement
  /// *absent*, pas une récurrence vide — la distinction compte pour le
  /// round-trip ([toJson] omet un emplacement `null`).
  static ZReminderRecurrence? fromJsonSafe(Object? json) {
    if (json is! Map) return null;
    final days = <int>[];
    final raw = json['days_before'];
    if (raw is List) {
      for (final e in raw) {
        // Un `num` non-int (le JSON rend parfois `7.0`) est accepté, une
        // chaîne numérique aussi. Tout le reste est écarté sans faire
        // échouer l'ensemble — un seuil corrompu ne doit pas effacer les
        // autres.
        final v = e is int
            ? e
            : e is num
                ? e.toInt()
                : e is String
                    ? int.tryParse(e)
                    : null;
        if (v != null && v >= 0) days.add(v);
      }
    }
    final wd = <int>{};
    final rawW = json['weekdays'];
    if (rawW is List) {
      for (final e in rawW) {
        final v = e is int
            ? e
            : e is num
                ? e.toInt()
                : e is String
                    ? int.tryParse(e)
                    : null;
        // Hors [1,7] ⇒ écarté : `DateTime.weekday` ne rend jamais autre
        // chose, donc une telle valeur ne pourrait jamais correspondre.
        if (v != null && v >= 1 && v <= 7) wd.add(v);
      }
    }
    if (days.isEmpty && wd.isEmpty) return null;
    return ZReminderRecurrence(daysBefore: days, weekdays: wd);
  }

  /// Seuils relatifs à l'échéance, en jours (`[1, 7]` = la veille et une
  /// semaine avant). Les valeurs négatives sont écartées à la
  /// désérialisation.
  final List<int> daysBefore;

  /// Jours de la semaine absolus, convention ISO-8601 de `DateTime.weekday` :
  /// 1 = lundi … 7 = dimanche.
  final Set<int> weekdays;

  /// `true` si aucune des deux familles n'est renseignée ⇒ aucun rappel.
  bool get isEmpty => daysBefore.isEmpty && weekdays.isEmpty;

  /// `true` si un rappel doit se déclencher à [now].
  ///
  /// - [dueDate] `null` ⇒ la famille **relative** ne peut pas s'évaluer (il
  ///   n'y a rien à devancer) ; seule la famille hebdomadaire est consultée.
  /// - Échéance strictement passée ⇒ `false` dans les deux familles. C'est
  ///   une décision explicite : rappeler chaque lundi un examen déjà passé
  ///   n'a pas de sens, et cela préserve le comportement historique
  ///   (`delta < 0 ⇒ false`).
  ///
  /// Pure, totale, déterministe : la sortie ne dépend que de [now], [dueDate]
  /// et de l'état de cet objet.
  bool matches({required DateTime now, DateTime? dueDate}) {
    if (isEmpty) return false;
    final delta = dueDate == null ? null : _daysUntil(now, dueDate);
    if (delta != null && delta < 0) return false;

    if (delta != null && daysBefore.any((t) => delta <= t)) return true;
    return weekdays.contains(now.weekday);
  }

  /// Sérialise vers une map persistable (snake_case). Les ensembles sont
  /// triés pour rendre la sortie déterministe — sans quoi deux exécutions
  /// produiraient des documents différents à contenu identique.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (daysBefore.isNotEmpty) 'days_before': List<int>.of(daysBefore),
        if (weekdays.isNotEmpty) 'weekdays': (weekdays.toList()..sort()),
      };

  /// Copie ciblée.
  ZReminderRecurrence copyWith({
    List<int>? daysBefore,
    Set<int>? weekdays,
  }) =>
      ZReminderRecurrence(
        daysBefore: daysBefore ?? this.daysBefore,
        weekdays: weekdays ?? this.weekdays,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZReminderRecurrence &&
          _intListEquals(daysBefore, other.daysBefore) &&
          _intSetEquals(weekdays, other.weekdays);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(daysBefore),
        Object.hashAllUnordered(weekdays),
      );

  @override
  String toString() =>
      'ZReminderRecurrence(daysBefore: $daysBefore, weekdays: $weekdays)';
}

/// Nombre de jours calendaires séparant `now` de `due`, à minuit local.
///
/// Normalisé sur la date seule : sans cela, « demain 8h » vu depuis
/// « aujourd'hui 20h » rendrait 0 jour au lieu de 1, et un seuil « la
/// veille » ne déclencherait pas au bon moment.
int _daysUntil(DateTime now, DateTime due) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(due.year, due.month, due.day);
  return b.difference(a).inDays;
}

/// Égalité ordonnée de deux `List<int>` (les seuils sont réémis dans l'ordre).
bool _intListEquals(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Égalité non ordonnée de deux `Set<int>` (un jour de semaine n'a pas de
/// rang : `{1,3}` et `{3,1}` désignent la même récurrence).
bool _intSetEquals(Set<int> a, Set<int> b) =>
    identical(a, b) || (a.length == b.length && a.containsAll(b));
