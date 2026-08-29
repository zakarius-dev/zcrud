/// Direction **logique** d'un geste de swipe sur la pile de session.
///
/// Logique, jamais physique : `start`/`end` se lisent contre la
/// [TextDirection] ambiante, exactement comme `EdgeInsetsDirectional` ou
/// `TextAlign.start` (invariant AD-13). La correspondance est donc :
///
/// | [TextDirection] | doigt vers la gauche | doigt vers la droite |
/// |---|---|---|
/// | `ltr` | [ZSwipeDirection.start] | [ZSwipeDirection.end] |
/// | `rtl` | [ZSwipeDirection.end] | [ZSwipeDirection.start] |
///
/// Un hôte qui associe une intention à chaque direction obtient donc, sous
/// RTL, la même intention pour le geste que l'utilisateur perçoit comme « en
/// avant » — ce qu'un couple `left`/`right` physique ne peut pas offrir.
library;

import 'package:flutter/widgets.dart' show TextDirection;

/// Direction logique d'un swipe, résolue contre la [TextDirection] ambiante.
///
/// Cette valeur décrit **un geste**, et rien d'autre. Elle ne porte aucune
/// sémantique d'évaluation : « raté / réussi », « à revoir / acquise »,
/// « ignorer / garder » sont des décisions de l'hôte, prises chez lui à
/// partir de cette direction.
enum ZSwipeDirection {
  /// Vers le **début** de la ligne — la gauche en `ltr`, la droite en `rtl`.
  start,

  /// Vers la **fin** de la ligne — la droite en `ltr`, la gauche en `rtl`.
  end,
}
