/// `ZReminderTime` — value-object PUR d'une heure de rappel (ES-2.6, **FR-S9**),
/// persisté en chaîne **`'HH:mm'`** (convention canonique §Dates, alignée
/// `ZTimeCodec`).
///
/// ## 🔴 D2 — pourquoi un value-object PUR, et NON un `@ZcrudModel`
///
/// Un `@ZcrudModel` utilisé comme champ (`subModel`) serait sérialisé par le
/// générateur en **map imbriquée `{hour, minute}`** — jamais en `'HH:mm'`. Or la
/// FR-S9 exige la forme persistée `'HH:mm'` (compat migration lex/IFFD, où l'heure
/// de rappel est une `String`). ⇒ `ZReminderTime` est un **VO pur** (couple
/// `{hour, minute}`), et `ZExam.reminderTime` est un **CANAL HORS-CODEGEN** décodé
/// et réémis À LA MAIN en `'HH:mm'` (patron `ZSmartNote.content`). Le TYPE dit le
/// format ⇒ **aucune `String` `'HH:mm'` ambiguë ne flotte dans l'UI** (AD-28).
///
/// ## Défensif et TOTAL (AD-10)
///
/// [ZReminderTime.parse] ne **throw JAMAIS** : `null`, chaîne non parsable ou
/// heure/minute hors bornes retombent sur `null` (repli déterministe), laissant
/// l'appelant décider. Même défensivité que `ZTimeCodec.hhmmToMap` — dont ce VO
/// **réutilise la mécanique** (`package:zcrud_core/domain.dart`), sans la dupliquer.
///
/// **Pur-Dart, Flutter-free** : aucun `TimeOfDay`, aucune dépendance Material.
/// **NON `ZExtensible`** : ce n'est pas un point d'extension (AD-4) ⇒ **aucun
/// câblage de gate** (ni registrar, ni kind, ni writer `extra`).
library;

import 'package:zcrud_core/domain.dart';

/// Heure de rappel `{hour, minute}` — immuable, persistée `'HH:mm'` (24 h).
class ZReminderTime {
  /// Construit une heure de rappel (primitif `const`).
  ///
  /// ⛔ **AUCUN `assert` de bornes ici** (AD-10, patron des entités `const` du
  /// repo) : la garde de bornes vit **exclusivement** à la frontière [parse], la
  /// seule qui reçoit des valeurs BRUTES du corpus persisté. Un appelant qui
  /// construit `ZReminderTime(hour: 99, minute: 0)` en mémoire obtient un VO
  /// `'99:00'` — c'est **son** invariant à tenir, pas celui de la désérialisation.
  const ZReminderTime({required this.hour, required this.minute});

  /// Décode **défensivement** une chaîne `'HH:mm'` (ou `'HH:mm:ss'`, secondes
  /// tronquées — parité `ZTimeCodec`/`TimeOfDay`) en [ZReminderTime].
  ///
  /// Rend **`null`** — **jamais un throw** (AD-10) — si [hhmm] est `null`, non
  /// parsable, ou hors bornes (`hour ∉ [0,23]` **ou** `minute ∉ [0,59]`).
  /// Tolérant sur le zéro-padding : `'8:5'` ⇒ `hour == 8, minute == 5`.
  ///
  /// Round-trip : `ZReminderTime.parse(t.toHhmm()) == t` pour tout `t` valide
  /// (`hour ∈ [0,23]`, `minute ∈ [0,59]`).
  static ZReminderTime? parse(String? hhmm) {
    // Réutilise la mécanique défensive canonique (`zcrud_core`) : split `:`,
    // coercition `int` tolérante, bornes `0..23` / `0..59`, secondes ignorées.
    final map = ZTimeCodec.hhmmToMap(hhmm);
    if (map == null) return null;
    return ZReminderTime(
      hour: map[ZTimeCodec.hourKey]!,
      minute: map[ZTimeCodec.minuteKey]!,
    );
  }

  /// Heure (0..23 pour un VO valide).
  final int hour;

  /// Minute (0..59 pour un VO valide).
  final int minute;

  /// Rend la chaîne zéro-paddée `'HH:mm'` (24 h) — la forme PERSISTÉE canonique.
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
