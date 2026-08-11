/// Règles pures de génération de flashcards : bornage du nombre de cartes et
/// répartition par type.
///
/// Source unique de ces règles : module de domaine pur (aucune dépendance
/// Flutter), réutilisé aussi bien par la feuille de génération que par son
/// contrôleur — jamais dupliqué dans un widget, ce qui éviterait qu'une
/// seconde implémentation diverge en silence.
///
/// Ne jette jamais (invariant AD-10) : un `count` incohérent (`0`, négatif,
/// énorme ou `null`) et une répartition incohérente (somme différente du
/// compte, type inconnu, valeur négative) sont dégradés gracieusement plutôt
/// que de lever une exception. Le domaine ne fait pas confiance à ses
/// entrées.
library;

import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcardType;

/// Bornes inclusives du nombre de cartes générables (`1..50`).
///
/// Exposées comme un record `(min, max)` pour que l'interface de génération
/// (curseur) et le bornage partagent la même source — pas deux littéraux
/// `1`/`50` à resynchroniser séparément.
const ({int min, int max}) zGenerationCountBounds = (min: 1, max: 50);

/// Défaut appliqué quand `count == null` (l'application n'a rien demandé) :
/// `10` cartes.
///
/// Choix conservateur, dans `[1, 50]`. `null` ne lève jamais (invariant
/// AD-10) : il retombe sur cette valeur.
const int zDefaultGenerationCount = 10;

/// Borne [raw] dans `[zGenerationCountBounds.min, .max]`, sans jamais lever
/// (invariant AD-10).
///
/// - `null` : repli sur [zDefaultGenerationCount] (`10`) ;
/// - `0` ou négatif : ramené à `min` (`1`) ;
/// - supérieur à `max` (ex. `10000`) : ramené à `max` (`50`) ;
/// - dans les bornes : inchangé.
int zClampGenerationCount(int? raw) {
  if (raw == null) return zDefaultGenerationCount;
  if (raw < zGenerationCountBounds.min) return zGenerationCountBounds.min;
  if (raw > zGenerationCountBounds.max) return zGenerationCountBounds.max;
  return raw;
}

/// Répartition équitable de [count] cartes sur [types].
///
/// Chaque type reçoit `count ~/ n`, et le reste (`count % n`) est distribué
/// de façon déterministe sur les premiers types de la liste (ordre
/// d'entrée) : la somme des valeurs égale exactement le `count` borné.
///
/// [count] est d'abord borné par [zClampGenerationCount] (une valeur
/// aberrante ne produit jamais une répartition aberrante). [types] vide
/// retourne une map vide (invariant AD-10 : jamais de division par zéro).
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

/// Normalise une répartition [raw] éventuellement incohérente (invariant
/// AD-10 : jamais de throw).
///
/// La distribution fournie fait foi : le `count` effectif devient la somme
/// (bornée) des valeurs retenues — aucune divergence silencieuse. Règles :
/// - une valeur négative est ramenée à `0` ;
/// - un type hors des [types] admis est écarté (entrée retirée) ;
/// - une entrée à `0` est conservée (un type explicitement à zéro reste une
///   information, elle n'est pas réinventée) ;
/// - [raw] `null` retombe sur [zEvenTypesDistribution] du [countIfNull]
///   borné.
///
/// La somme finale est bornée par [zGenerationCountBounds] : un dépassement
/// est résorbé en tronquant déterministement les valeurs de tête, ce qui
/// garantit que le `count` effectif reste dans `[1, 50]` si au moins une
/// carte est demandée. Une somme nulle est laissée telle quelle — c'est à
/// l'application de décider qu'aucune carte n'est demandée.
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
