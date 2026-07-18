/// Type-valeur **plage de dates** `ZDateRange{start, end}` (AD-47).
///
/// origine: parité DODLP « champ plage de dates » (`dateRange`) — un couple
/// `start`/`end` sérialisé `{start, end}` en **ISO-8601**, avec l'invariant
/// **`end >= start`** (une plage inversée n'est jamais construite/retournée
/// valide).
///
/// **Domaine PUR-DART** (Flutter-free — garde `domain_purity_test.dart`) : ce
/// type vit sous `lib/src/domain/edition/` et n'importe **aucun** SDK Flutter.
/// La (dé)sérialisation défensive (AD-10) réutilise la brique [ZExtension.guard]
/// (`fromJsonSafe` → `null` sur TOUTE anomalie, jamais de throw ; le parent
/// survit toujours).
library;

import '../extension/z_extension.dart';

/// Plage de dates immuable `{start, end}` (ISO-8601), invariant **`end >= start`**.
///
/// - [toJson] émet `{'start': iso, 'end': iso}` (persistance snake-neutre : les
///   deux clés `start`/`end` sont stables).
/// - [fromJson] est **STRICT** : il **lève** (`FormatException`/`TypeError`) sur
///   toute entrée non conforme (non-map, clé absente, valeur non-`String`, date
///   non-ISO, `start > end`). C'est le décodeur « brut » — à ne JAMAIS câbler
///   directement dans un chemin défensif.
/// - [fromJsonSafe] enveloppe [fromJson] dans [ZExtension.guard] : il **ne throw
///   JAMAIS** et retombe sur `null` (AD-10). C'est le décodeur à utiliser sur la
///   voie de persistance (helper généré `_$asDateRange`).
class ZDateRange {
  /// Construit une plage. En debug, l'invariant **`end >= start`** est vérifié
  /// par assertion (une plage inversée est un bug d'appel). En release, la seule
  /// voie de désérialisation ([fromJsonSafe]) ne construit jamais de plage
  /// inversée (elle retombe sur `null`).
  ///
  /// Non `const` : l'assertion d'invariant repose sur `DateTime.isBefore`
  /// (invocation de méthode — non « potentiellement constante », donc incompatible
  /// avec un constructeur `const`). Aucun site d'appel n'exige de contexte `const`
  /// (widget/générateur/désérialisation construisent au runtime).
  ZDateRange({required this.start, required this.end})
      // `!end.isBefore(start)` autorise l'égalité (`end == start`).
      : assert(
          !end.isBefore(start),
          'ZDateRange: end doit être >= start',
        );

  /// Borne basse (incluse) de la plage.
  final DateTime start;

  /// Borne haute (incluse) de la plage — **>= [start]**.
  final DateTime end;

  /// Sérialise la plage en `{'start': iso, 'end': iso}` (ISO-8601).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  /// Décodeur **STRICT** (peut throw) — n'utiliser QUE derrière [fromJsonSafe].
  ///
  /// Lève sur : entrée non-map, `start`/`end` absent ou non-`String`, date
  /// non-ISO (`DateTime.parse`), ou invariant `end < start` violé. Cette
  /// falsifiabilité est **volontaire** : brancher un chemin de persistance sur ce
  /// décodeur (au lieu de [fromJsonSafe]) fait **rougir** le corpus corrompu
  /// (injection R3, AD-10).
  static ZDateRange fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('ZDateRange.fromJson: entrée non-map');
    }
    final rawStart = json['start'];
    final rawEnd = json['end'];
    if (rawStart is! String || rawEnd is! String) {
      throw const FormatException(
          'ZDateRange.fromJson: `start`/`end` absent ou non-String');
    }
    final start = DateTime.parse(rawStart);
    final end = DateTime.parse(rawEnd);
    if (end.isBefore(start)) {
      throw const FormatException('ZDateRange.fromJson: end < start');
    }
    return ZDateRange(start: start, end: end);
  }

  /// Décodeur **DÉFENSIF** (AD-10) : `null` sur TOUTE anomalie, **jamais** de
  /// throw. Le parent d'un champ `ZDateRange?` survit à une entrée corrompue (le
  /// champ retombe sur `null`, les autres champs conservent leurs valeurs).
  static ZDateRange? fromJsonSafe(Object? json) =>
      ZExtension.guard<ZDateRange>(() => fromJson(json));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(runtimeType, start, end);

  @override
  String toString() =>
      'ZDateRange(start: ${start.toIso8601String()}, '
      'end: ${end.toIso8601String()})';
}
