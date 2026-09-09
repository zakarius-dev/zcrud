/// Teinte d'ombre d'une carte de révision, dérivée du dégradé de son type.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, zResolveFlashcardTypeGradient;

/// La teinte d'ombre qu'un type de carte porte : la **première couleur** du
/// dégradé qui identifie ce type.
///
/// C'est la forme qu'un thème ne peut pas décrire : il n'a qu'un jeton de
/// teinte d'ombre, donc une seule valeur, alors qu'un écran affiche des cartes
/// de plusieurs types côte à côte. La teinte se résout donc **par carte**, au
/// site de montage, où le `BuildContext` donne accès à la même chaîne que la
/// carte elle-même.
///
/// Le dégradé consulté est celui que rend
/// [zResolveFlashcardTypeGradient] — la fonction que la carte de révision
/// appelle elle-même. La chaîne (clé explicite, seam préfixé, seam nu, jeton)
/// est documentée là-bas, et n'a pas de seconde écriture ici : le liseré, la
/// pastille de type et cette ombre lisent **la même** résolution.
///
/// `null` est une valeur FONCTIONNELLE : « ce type ne porte pas de teinte ».
/// La carte reprend alors sa propre chaîne — jeton de teinte d'ombre, puis
/// aucune ombre. Une teinte fabriquée ici rendrait ce jeton inexprimable.
///
/// Cette fonction a la signature d'un `ZCardShadowColorResolver` : elle se
/// passe telle quelle à `ZCardChromeSpec.shadowColorResolver`, et se compose
/// (par exemple pour n'en garder l'effet que sur certains types).
///
/// **L'opacité n'est pas décidée ici.** La teinte rendue est opaque : c'est la
/// carte qui applique l'opacité de son ombre, par luminosité. Une teinte déjà
/// atténuée n'aurait donc aucun effet.
Color? zFlashcardTypeShadowColor(BuildContext context, ZFlashcard card) {
  // Aucun maillon n'est recomposé ici : ce relais APPELLE le foyer unique du
  // paquet amont. Recopier la chaîne — même à l'identique, même sous une
  // garde d'ordre — laisse deux ordres à maintenir, et l'ombre finirait par
  // peindre une teinte que le liseré de la même carte ne peindrait plus.
  final ZGradientSpec? spec = zResolveFlashcardTypeGradient(context, card);
  if (spec == null) return null;
  // La PREMIÈRE couleur, jamais une moyenne ni la dernière : c'est celle que
  // la référence visuelle porte sous la carte, et celle que le liseré montre
  // en tête. Une liste vide est un dégradé sans couleur : rien à teinter.
  final List<Color> colors = spec.gradient.colors;
  if (colors.isEmpty) return null;
  // Valeurs de la référence visuelle mesurée, POUR MÉMOIRE : la teinte y est
  // portée à 50/255 en clair et 30/255 en sombre. Elles ne sont PAS appliquées
  // ici, et le seraient en pure perte : `ZFlashcardReviewCard` réapplique sa
  // propre opacité sur la teinte reçue (`tint.withValues(alpha: …)`), qui
  // remplace celle du canal alpha transmis. L'opacité de l'ombre appartient
  // donc à la carte, ce relais ne porte que la TEINTE.
  return colors.first;
}
