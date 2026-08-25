/// Canal **interne** au satellite entre une cellule réordonnable et la poignée
/// de glissement que l'appelant rend à l'intérieur de cette cellule.
///
/// Ce fichier n'est **pas** exporté par le barrel `zcrud_responsive.dart` :
/// c'est un détail d'implémentation partagé entre la grille réordonnable et le
/// renderer de repli, deux fichiers distincts d'une même bibliothèque logique.
/// Aucun de ses types n'apparaît dans la signature du port `ZReorderRenderer` —
/// c'est précisément ce que le port autorise en promettant que le `BuildContext`
/// d'une poignée appartient au sous-arbre du renderer.
library;

import 'package:flutter/widgets.dart';

/// Ce qu'une cellule réordonnable met à disposition de la poignée construite
/// dans son sous-arbre : la **position affichée** dont elle est la case, la
/// taille et le contenu de l'aperçu flottant, et les crochets de suivi et de
/// fin de glissement.
///
/// Une poignée qui ne trouve pas ce canal n'est pas dans une cellule de ce
/// chassis : elle doit alors rester rendue telle quelle.
class ZReorderHandleScope extends InheritedWidget {
  /// Construit le canal d'une cellule vers les poignées de son sous-arbre.
  const ZReorderHandleScope({
    required this.position,
    required this.width,
    required this.height,
    required this.onDragUpdate,
    required this.onDragStopped,
    required this.buildFeedback,
    required super.child,
  });

  /// Position **affichée** de la cellule (`0..n-1` dans l'ordre courant).
  ///
  /// C'est la grandeur en laquelle raisonne tout le chassis : cible de dépôt,
  /// rappel d'ordre, actions sémantiques. Elle ne coïncide avec l'index
  /// **source** d'un item que tant que l'ordre optimiste local n'a pas permuté
  /// l'affichage.
  final int position;

  /// Largeur mesurée de la cellule (`null` si la contrainte est infinie).
  final double? width;

  /// Hauteur mesurée de la cellule (`null` si la contrainte est infinie).
  final double? height;

  /// Suivi du pointeur pendant le glissement (alimente l'autoscroll de bord).
  final void Function(DragUpdateDetails details) onDragUpdate;

  /// Fin de glissement, quelle qu'en soit l'issue (dépôt, annulation, sortie).
  final VoidCallback onDragStopped;

  /// Construit l'aperçu flottant de la cellule — celui-là même que sert le
  /// geste propre à la cellule, à la taille réellement mesurée.
  final Widget Function() buildFeedback;

  /// Canal de la cellule qui contient [context], ou `null` hors de ce chassis.
  static ZReorderHandleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZReorderHandleScope>();

  @override
  bool updateShouldNotify(ZReorderHandleScope oldWidget) =>
      position != oldWidget.position ||
      width != oldWidget.width ||
      height != oldWidget.height;
}
