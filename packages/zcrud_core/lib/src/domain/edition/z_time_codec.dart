/// `ZTimeCodec` — conversion **pur-Dart** entre la représentation d'heure zcrud
/// (chaîne `'HH:mm'`, convention canonique §Dates) et la représentation DODLP
/// (`Map{hour, minute}`, image d'un `TimeOfDay`), pour la **migration** des
/// champs `time` (MIN-2, parité DODLP `time` Map↔ISO).
///
/// **Pur-Dart, Flutter-free (AD-1/AD-14)** : aucun `TimeOfDay`, aucune dépendance
/// Material — le domaine reste utilisable hors Flutter. **Défensif (AD-10)** :
/// toute entrée absente/corrompue/hors bornes retourne `null` (jamais de throw),
/// laissant l'appelant décider du repli.
///
/// Rappels de format :
/// - zcrud (`ZDateFieldWidget` mode `time`) stocke `'HH:mm'` (heures/minutes
///   zéro-paddées, 24 h) ;
/// - DODLP (`FormBuilderDateTimePicker`/`TimeOfDay`) sérialise
///   `{'hour': int, 'minute': int}`.
library;

/// Codec pur-données `time` ↔ `Map{hour, minute}` (helpers `static`).
abstract final class ZTimeCodec {
  /// Clé de l'heure dans la map DODLP.
  static const String hourKey = 'hour';

  /// Clé des minutes dans la map DODLP.
  static const String minuteKey = 'minute';

  /// Convertit une map DODLP `{hour, minute}` en chaîne zcrud `'HH:mm'`.
  ///
  /// Accepte des valeurs `int` ou `String` numériques (désérialisation
  /// défensive). Retourne `null` si la map est absente, mal formée, ou si
  /// l'heure/les minutes sont hors bornes (`0..23` / `0..59`).
  static String? mapToHhmm(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final h = _asInt(map[hourKey]);
    final m = _asInt(map[minuteKey]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return '${_pad2(h)}:${_pad2(m)}';
  }

  /// Convertit une chaîne zcrud `'HH:mm'` (ou `'HH:mm:ss'`) en map DODLP
  /// `{hour, minute}`. Retourne `null` si l'entrée est absente ou non parsable
  /// (borne AD-10). Les secondes éventuelles sont **ignorées** (troncature à la
  /// minute, parité `TimeOfDay`).
  static Map<String, int>? hhmmToMap(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = _asInt(parts[0]);
    final m = _asInt(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return <String, int>{hourKey: h, minuteKey: m};
  }

  /// Nombre total de **minutes depuis minuit** d'une heure `'HH:mm'`, ou `null`
  /// si non parsable (utilitaire de tri/comparaison sans dépendance Flutter).
  static int? hhmmToMinutesOfDay(String? hhmm) {
    final map = hhmmToMap(hhmm);
    if (map == null) return null;
    return map[hourKey]! * 60 + map[minuteKey]!;
  }

  /// Parse un `int` tolérant : `int` tel quel, `num` tronqué, `String`
  /// numérique ; `null` sinon.
  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String _pad2(int v) => v.toString().padLeft(2, '0');
}
