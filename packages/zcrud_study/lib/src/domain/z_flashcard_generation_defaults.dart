/// Défauts PURS de génération de flashcards (SU-9/AC3/AC4 — AD-37/AD-10).
///
/// **SOURCE UNIQUE** des règles de bornage du `count` et de répartition par type.
/// Module de DOMAINE pur (aucun `import 'package:flutter/...'`, aucun widget) :
/// testable en `dart test`, réutilisé par la feuille de génération ET le
/// contrôleur — **jamais** dupliqué dans un widget (une seconde implémentation
/// divergerait en silence, garde `z_generation_source_unique_test.dart`).
///
/// **AD-10 — JAMAIS de throw** : `count` incohérent (`0`/négatif/énorme/`null`),
/// répartition incohérente (somme ≠ count, type inconnu, valeur négative) sont
/// **dégradés gracieusement**, jamais une exception. Le domaine ne fait pas
/// confiance à ses entrées.
library;

import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcardType;

/// Bornes inclusives du nombre de cartes générables (parité lex : slider 1..50).
///
/// Exposées comme un record `(min, max)` pour que la feuille (slider) et le
/// bornage partagent la MÊME source (pas deux littéraux `1`/`50` à re-synchroniser).
const ({int min, int max}) zGenerationCountBounds = (min: 1, max: 50);

/// Défaut CONSIGNÉ quand `count == null` (l'app n'a rien demandé) : `10` cartes.
///
/// Choix conservateur (dans `[1, 50]`), documenté pour que la garde de bornage
/// soit falsifiable — `null` ne lève jamais (AD-10), il retombe ici.
const int zDefaultGenerationCount = 10;

/// Borne [raw] dans `[zGenerationCountBounds.min, .max]`, **sans jamais lever**
/// (AC3, AD-10).
///
/// - `null` → [zDefaultGenerationCount] (`10`) ;
/// - `0` / négatif → `min` (`1`) ;
/// - `> max` (ex. `10000`) → `max` (`50`) ;
/// - dans les bornes → inchangé.
int zClampGenerationCount(int? raw) {
  if (raw == null) return zDefaultGenerationCount;
  if (raw < zGenerationCountBounds.min) return zGenerationCountBounds.min;
  if (raw > zGenerationCountBounds.max) return zGenerationCountBounds.max;
  return raw;
}

/// Répartition **équitable** de [count] cartes sur [types] (AC3).
///
/// Chaque type reçoit `count ~/ n`, et le **reste** (`count % n`) est distribué
/// **déterministement** sur les PREMIERS types de la liste (ordre d'entrée) ⇒ la
/// somme des valeurs **égale exactement** le `count` borné (invariant testé).
///
/// [count] est d'abord borné par [zClampGenerationCount] (une valeur folle ne
/// produit jamais une map folle). [types] vide ⇒ map vide (AD-10, jamais de
/// division par zéro).
Map<ZFlashcardType, int> zEvenTypesDistribution(
  int count,
  List<ZFlashcardType> types,
) {
  final bounded = zClampGenerationCount(count);
  // Déduplique en préservant l'ordre (un type répété ne fausse pas le partage).
  final ordered = <ZFlashcardType>[];
  for (final t in types) {
    if (!ordered.contains(t)) ordered.add(t);
  }
  final n = ordered.length;
  if (n == 0) return <ZFlashcardType, int>{};

  final base = bounded ~/ n;
  var remainder = bounded % n;
  final result = <ZFlashcardType, int>{};
  for (final type in ordered) {
    // Le reste est donné 1-à-1 aux premiers types ⇒ somme == bounded (déterministe).
    final extra = remainder > 0 ? 1 : 0;
    if (remainder > 0) remainder--;
    result[type] = base + extra;
  }
  return result;
}

/// Normalise une répartition [raw] éventuellement incohérente (AC4, AD-10).
///
/// **La distribution fournie fait FOI** (décision tranchée) : le `count` effectif
/// devient la somme (bornée) des valeurs retenues — aucune divergence silencieuse,
/// aucun throw. Règles :
/// - valeur **négative** → ramenée à `0` ;
/// - type **hors** des [types] admis (ex. non présent dans la liste des 6) →
///   **écarté** (entrée retirée) ;
/// - une entrée à `0` est **conservée** (un type explicitement à zéro reste une
///   information — il n'est pas ré-inventé) ;
/// - [raw] `null` ⇒ repli sur [zEvenTypesDistribution] du [countIfNull] borné.
///
/// La somme finale est **bornée** par [zGenerationCountBounds] (une somme > 50
/// est ramenée proportionnellement n'est PAS faite ici — on borne le TOTAL en
/// tronquant les valeurs de tête au besoin, déterministe), garantissant que le
/// `count` effectif reste dans `[1, 50]` **si** au moins une carte est demandée ;
/// une somme nulle est laissée telle quelle (l'app décide — pas de carte).
Map<ZFlashcardType, int> zNormalizeTypesDistribution(
  Map<ZFlashcardType, int>? raw, {
  required List<ZFlashcardType> types,
  int? countIfNull,
}) {
  if (raw == null) {
    return zEvenTypesDistribution(
      zClampGenerationCount(countIfNull),
      types,
    );
  }
  final allowed = types.toSet();
  final cleaned = <ZFlashcardType, int>{};
  for (final entry in raw.entries) {
    if (!allowed.contains(entry.key)) continue; // type inconnu → écarté.
    cleaned[entry.key] = entry.value < 0 ? 0 : entry.value; // négatif → 0.
  }

  // Borne le TOTAL à `max` sans jamais lever : tronque déterministement les
  // valeurs (ordre d'entrée) jusqu'à ce que la somme retombe sous le plafond.
  var total = cleaned.values.fold<int>(0, (a, b) => a + b);
  if (total > zGenerationCountBounds.max) {
    var overflow = total - zGenerationCountBounds.max;
    final keys = cleaned.keys.toList();
    for (final key in keys) {
      if (overflow <= 0) break;
      final v = cleaned[key]!;
      final cut = v < overflow ? v : overflow;
      cleaned[key] = v - cut;
      overflow -= cut;
    }
    total = zGenerationCountBounds.max;
  }
  return cleaned;
}
