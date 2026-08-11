/// `ZReminderTime` — value-object pur d'une heure de rappel, persisté sous
/// forme de chaîne **`'HH:mm'`**.
///
/// ## Pourquoi un value-object pur, et non un type généré par le codegen
///
/// Un type utilisé comme sous-modèle du codegen serait sérialisé par le
/// générateur en **map imbriquée `{hour, minute}`** — jamais en `'HH:mm'`.
/// Or la forme persistée `'HH:mm'` est requise pour rester compatible avec
/// les corpus existants, où l'heure de rappel est une chaîne. `ZReminderTime`
/// est donc un value-object pur (couple `{hour, minute}`), et le champ qui le
/// porte sur une entité est un canal hors schéma décodé et réémis
/// explicitement en `'HH:mm'`. Le type porte le format, ce qui évite qu'une
/// chaîne `'HH:mm'` ambiguë ne circule dans l'interface.
///
/// ## Défensif et total
///
/// [ZReminderTime.parse] ne lève **jamais** : `null`, une chaîne non
/// analysable ou une heure/minute hors bornes retombent sur `null` (repli
/// déterministe), laissant l'appelant décider (invariant AD-10). Réutilise la
/// mécanique de [ZTimeCodec] (`package:zcrud_core/domain.dart`) plutôt que de
/// la dupliquer.
///
/// Pur-Dart, sans dépendance Flutter : aucun `TimeOfDay`, aucune dépendance
/// Material. Ce type n'est pas un point d'extension au sens de l'invariant
/// AD-4 — il n'a donc aucun câblage de registre à porter.
library;

import 'package:zcrud_core/domain.dart';

/// Heure de rappel `{hour, minute}` — immuable, persistée `'HH:mm'` (24 h).
class ZReminderTime {
  /// Construit une heure de rappel.
  ///
  /// Ce constructeur ne porte volontairement aucun `assert` de bornes
  /// (invariant AD-10) : la garde de bornes vit exclusivement à la frontière
  /// [parse], la seule qui reçoit des valeurs brutes du corpus persisté. Un
  /// appelant qui construit `ZReminderTime(hour: 99, minute: 0)` en mémoire
  /// obtient un value-object `'99:00'` — c'est son propre invariant à tenir,
  /// pas celui de la désérialisation.
  const ZReminderTime({required this.hour, required this.minute});

  /// Décode défensivement une chaîne `'HH:mm'` (ou `'HH:mm:ss'`, secondes
  /// tronquées) en [ZReminderTime].
  ///
  /// Rend **`null`** — jamais une exception (invariant AD-10) — si [hhmm]
  /// est `null`, non analysable, ou hors bornes (`hour` hors `[0,23]` ou
  /// `minute` hors `[0,59]`). Tolérant sur le zéro-padding : `'8:5'` ⇒
  /// `hour == 8, minute == 5`.
  ///
  /// Round-trip : `ZReminderTime.parse(t.toHhmm()) == t` pour tout `t` valide
  /// (`hour` dans `[0,23]`, `minute` dans `[0,59]`).
  static ZReminderTime? parse(String? hhmm) {
    // Réutilise la mécanique défensive canonique (`zcrud_core`) : split `:`,
    // coercition `int` tolérante, bornes `0..23` / `0..59`, secondes
    // ignorées.
    final map = ZTimeCodec.hhmmToMap(hhmm);
    if (map == null) return null;
    return ZReminderTime(
      hour: map[ZTimeCodec.hourKey]!,
      minute: map[ZTimeCodec.minuteKey]!,
    );
  }

  /// Heure (0..23 pour un value-object valide).
  final int hour;

  /// Minute (0..59 pour un value-object valide).
  final int minute;

  /// Rend la chaîne zéro-paddée `'HH:mm'` (24 h) — la forme persistée
  /// canonique.
  String toHhmm() => '${_pad2(hour)}:${_pad2(minute)}';

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZReminderTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ZReminderTime(${toHhmm()})';
}
