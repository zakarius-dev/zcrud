/// Politique de largeur du tableau RENDU — opt-in (AD-57).
///
/// Le tableau écrit en Markdown devient un embed, et son rendu se dimensionne
/// **au contenu**. Quand la somme des colonnes dépasse la place offerte, le
/// widget `Table` rétracte les colonnes jusqu'à leur largeur intrinsèque
/// minimale puis s'arrête : au-delà, la fin du tableau sort du cadre et n'est
/// plus atteignable. Sur une surface étroite — un `title:` de `ListTile`, une
/// tuile plafonnée, un nœud de carte mentale, une bulle de conversation — ce
/// n'est pas un style différent qui s'affiche, c'est une donnée absente.
///
/// Ce scope rouvre ce choix. Il ne change ni la charge de l'embed, ni le format
/// persisté, ni le nombre de colonnes : seule la **géométrie** du rendu bouge,
/// et seulement là où le tableau débordait déjà.
library;

import 'package:flutter/widgets.dart';

/// Comment le tableau rendu occupe la largeur qui lui est offerte.
enum ZTableWidth {
  /// Dimensionnement **au contenu**, sans échappatoire — le comportement
  /// HISTORIQUE, et le défaut.
  ///
  /// Un tableau qui tient est rendu tel quel ; un tableau plus large que son
  /// cadre est rétracté puis **écrêté**.
  intrinsic,

  /// Dimensionnement au contenu, rendu **atteignable par défilement
  /// horizontal**.
  ///
  /// C'est l'échappatoire déjà posée sur l'autre embed bloc du paquet, la
  /// formule LaTeX en display : un viewport horizontal borne la largeur, le
  /// début reste visible et la fin s'atteint au **glisser** sur la zone
  /// visible du tableau. La course offerte vaut exactement ce qui dépassait.
  ///
  /// Les colonnes ne se replient pas : elles défilent. Deux conséquences à
  /// connaître avant de poser ce mode :
  ///
  /// - un tableau **plus étroit** que la place offerte cesse d'être **étiré**
  ///   jusqu'aux bords et se dimensionne à son contenu — le viewport lui rend
  ///   une contrainte non bornée. Le rendu de ces tableaux-là bouge donc, lui
  ///   aussi, dès que le mode est posé ;
  /// - le texte d'une cellule ne se replie plus : une cellule longue étire sa
  ///   colonne au lieu de passer à la ligne.
  scrollable,
}

/// Diffuse la politique de largeur des tableaux au sous-arbre.
///
/// **Absent ⇒ [ZTableWidth.intrinsic]** : un hôte qui ne fait rien garde
/// exactement le rendu d'avant.
///
/// ```dart
/// ZTableWidthScope(
///   width: ZTableWidth.scrollable,
///   child: ZMarkdownReader(value: valeur),
/// )
/// ```
///
/// Le scope se pose autour du lecteur, du champ ou du dialogue : il traverse
/// les trois montages, y compris le tableau **legacy**, qui emprunte le même
/// chemin de rendu.
class ZTableWidthScope extends InheritedWidget {
  /// Diffuse [width] au sous-arbre [child].
  const ZTableWidthScope({
    required this.width,
    required super.child,
    super.key,
  });

  /// Politique appliquée aux tableaux descendants.
  final ZTableWidth width;

  /// Scope hérité le plus proche, ou `null`.
  static ZTableWidthScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZTableWidthScope>();

  /// Politique héritée, [ZTableWidth.intrinsic] par défaut (AD-10 : jamais de
  /// throw sur absence).
  static ZTableWidth widthOf(BuildContext context) =>
      maybeOf(context)?.width ?? ZTableWidth.intrinsic;

  @override
  bool updateShouldNotify(ZTableWidthScope oldWidget) =>
      width != oldWidget.width;
}
