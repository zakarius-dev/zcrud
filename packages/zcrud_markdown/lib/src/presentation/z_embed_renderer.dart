/// Rendu d'un type d'embed DÉCLARÉ PAR L'APPELANT — opt-in (AD-57).
///
/// Les types d'embed du socle sont un **plancher, pas un plafond** : un
/// appelant peut en ajouter un qui lui est propre, ou remplacer le rendu d'un
/// type existant, sans que le socle ait à connaître son contenu.
library;

import 'package:flutter/widgets.dart';

/// Rendu d'un type d'embed, décrit en types NEUTRES.
///
/// C'est une DESCRIPTION, pas un widget : elle dit quel type d'op elle rend
/// ([type]), comment ([build]) et si le rendu occupe sa propre ligne ([block]).
/// Aucun type de l'éditeur sous-jacent n'apparaît — l'appelant décrit son rendu
/// sans dépendre de la mécanique d'édition.
///
/// ## Règle de collision (figée)
///
/// Un rendu déclaré par l'appelant **gagne** sur celui du socle pour le même
/// [type]. C'est ce qui permet de remplacer un rendu existant — par exemple de
/// brancher un second moteur de formules — sans rien retirer au socle. Entre
/// deux rendus déclarés portant le même [type], le **premier de la liste**
/// gagne.
///
/// ## Contrat de [build]
///
/// [build] reçoit la charge BRUTE de l'op (`data`) : ce que l'op portait, tel
/// quel — une `String` pour un embed textuel, une `Map` pour un embed
/// structuré, éventuellement autre chose. Aucune coercition n'est faite : c'est
/// à l'implémentation de vérifier le type avant de le lire. Un rendu qui lève
/// est neutralisé (l'embed disparaît du rendu, l'éditeur reste utilisable) —
/// il ne casse jamais le document.
///
/// ```dart
/// ZEmbedRenderer(
///   type: 'latex',
///   build: (context, data, textStyle) =>
///       MonMoteurDeFormules('$data', style: textStyle),
/// )
/// ```
@immutable
class ZEmbedRenderer {
  /// Déclare le rendu du type d'op [type].
  const ZEmbedRenderer({
    required this.type,
    required this.build,
    this.block = false,
  });

  /// Clé de l'op embed rendue — la clé de la `Map` `insert`
  /// (`{"insert": {"<type>": <data>}}`).
  final String type;

  /// Construit le rendu depuis la charge de l'op et le style de texte du point
  /// d'insertion.
  final Widget Function(BuildContext context, Object? data, TextStyle textStyle)
      build;

  /// Le rendu occupe-t-il sa propre ligne ? `false` (défaut) ⇒ rendu dans le
  /// flux du paragraphe.
  final bool block;
}
