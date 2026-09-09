/// Résolution du dégradé qui identifie le **type** d'une flashcard.
///
/// Foyer unique de la chaîne : la carte de révision la consomme, et toute
/// surface qui veut peindre la même identité de type (liseré, pastille,
/// ombre, puce de liste…) l'appelle plutôt que de la réécrire.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientSpec, ZcrudTheme, zResolveGradient;

import '../domain/z_flashcard.dart';

/// Préfixe de la clé de dégradé par type soumise au seam
/// `ZcrudScope.gradientResolver` : la clé complète est
/// `'$kZFlashcardReviewTypeGradientKeyPrefix<type.name>'`.
///
/// C'est le format à implémenter dans un résolveur d'hôte. La résolution
/// interroge ensuite le seam avec le nom de type **nu** : un résolveur qui ne
/// connaît que ce format-là reste servi, mais un résolveur qui répond aux
/// **deux** voit le format préfixé l'emporter. Les deux clés sont soumises
/// **avant** que le jeton `ZcrudTheme.flashcardTypeGradients` ne soit lu.
///
/// La valeur est identique à celle qu'emploie la carte de flashcard de liste,
/// et une garde de source en tient l'égalité : les deux surfaces se pilotent
/// avec un seul résolveur.
const String kZFlashcardReviewTypeGradientKeyPrefix = 'flashcard.type.';

/// La spécification de dégradé qui identifie le type de [card].
///
/// Chaîne de résolution — **seam > jeton**, l'ordre de priorité du socle :
/// 1. [typeGradientKey], s'il est posé : cette clé est soumise **telle
///    quelle** au seam, et rien d'autre n'est consulté ;
/// 2. le seam `ZcrudScope.gradientResolver`, interrogé avec
///    `'$kZFlashcardReviewTypeGradientKeyPrefix<type.name>'` ;
/// 3. le **même seam**, interrogé avec le nom de type **nu** — le format
///    historique, pour les résolveurs qui ne connaissent que lui ;
/// 4. le jeton `ZcrudTheme.flashcardTypeGradients`, indexé par le nom de
///    type : le repli quand le seam se tait sur les **deux** clés.
///
/// Autrement dit : **un résolveur d'hôte qui répond l'emporte toujours sur le
/// jeton du thème**, quel que soit celui des deux formats de clé auquel il
/// répond. Un hôte qui veut au contraire que son jeton gagne ne pose pas de
/// résolveur pour ces clés — ou pose [typeGradientKey], qui court-circuite
/// tout.
///
/// Entre les deux clés du seam, la clé préfixée l'emporte : un résolveur qui
/// répond aux deux voit le maillon 2 gagner.
///
/// L'identité est le nom stable du type, jamais une position de liste.
/// Chaque maillon est nullable, et `null` est une valeur **fonctionnelle** :
/// « ce type ne porte pas de dégradé ». Un appelant qui fabriquerait une
/// valeur à la place rendrait ce silence inexprimable.
ZGradientSpec? zResolveFlashcardTypeGradient(
  BuildContext context,
  ZFlashcard card, {
  String? typeGradientKey,
}) {
  if (typeGradientKey != null) return zResolveGradient(context, typeGradientKey);
  final String typeName = card.type.name;
  // Le seam est interrogé sur ses DEUX formats de clé avant que le jeton ne
  // soit lu, et non « préfixe, jeton, nu » : couper le seam en deux ferait
  // dépendre la règle de priorité du FORMAT de clé auquel l'hôte répond.
  // Un hôte au format nu verrait alors son résolveur battu par une table que
  // le thème du socle pose à sa place — exactement le défaut corrigé ici.
  return zResolveGradient(
        context,
        '$kZFlashcardReviewTypeGradientKeyPrefix$typeName',
      ) ??
      zResolveGradient(context, typeName) ??
      ZcrudTheme.of(context).flashcardTypeGradients?[typeName];
}
