/// Transitions de route **RTL-aware** et **découplées de tout routeur** (AD-32,
/// AD-13, NFR-U2/U6/U7).
///
/// Neutralise `transitions.dart` de lex (couplé à `go_router` via
/// `CustomTransitionPage`/`GoRouterState`) en primitives **`package:flutter`
/// natives** :
/// * [zSlideBeginOffset] : **fonction pure** (testable sans `BuildContext`)
///   calculant l'offset de début du slide selon la `TextDirection` — cœur de
///   l'inversion RTL (AD-13/NFR-U6) ;
/// * [zPageRoute] : `PageRouteBuilder<T>` **neutre** (aucun `go_router`), piloté
///   par l'enum [ZRouteTransition] (jamais un `bool` — NFR-U7), durées/courbes
///   **injectées** ;
/// * [ZPageTransitionsBuilder] : `PageTransitionsBuilder` natif enregistrable
///   dans `PageTransitionsTheme`, réutilisant la même logique RTL.
///
/// ⛔ **Aucun** routeur : le câblage dans un `GoRouter`/`Navigator` réel
/// appartient à l'app/binding, pas à `zcrud_ui_kit`.
library;

import 'package:flutter/material.dart';

import '../domain/z_route_transition.dart';

/// Offset de **DÉBUT** du slide entrant, selon la direction de lecture.
///
/// Le contenu entre par le côté **« fin » (end)** de la lecture :
/// * LTR : le « end » est à droite → `Offset(1, 0)` ;
/// * RTL : le « end » est à gauche → `Offset(-1, 0)`.
///
/// L'offset horizontal **change de signe** entre LTR et RTL — c'est l'inversion
/// exigée par AD-13. **Fonction pure** : aucun `BuildContext`, déterministe et
/// totale sur les deux valeurs de [TextDirection] (jamais de throw).
Offset zSlideBeginOffset(TextDirection direction) =>
    Offset(direction == TextDirection.rtl ? -1.0 : 1.0, 0.0);

/// Construit le widget de transition RTL-aware pour un [ZRouteTransition] donné.
///
/// Isolé pour être partagé par [zPageRoute] et [ZPageTransitionsBuilder].
Widget _buildZTransition({
  required BuildContext context,
  required ZRouteTransition transition,
  required Animation<double> animation,
  required Curve curve,
  required Widget child,
}) {
  // Exhaustif sans `default` : un nouveau palier casserait la compilation.
  switch (transition) {
    case ZRouteTransition.slide:
      final begin = zSlideBeginOffset(Directionality.of(context));
      final tween = Tween<Offset>(begin: begin, end: Offset.zero)
          .chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    case ZRouteTransition.fade:
      // Fondu insensible à la direction (aucune composante horizontale).
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: curve),
        child: child,
      );
  }
}

/// Route de page **neutre** (aucun routeur) appliquant une transition RTL-aware.
///
/// Retourne un `PageRouteBuilder<T>` `package:flutter` pur : aucun
/// `CustomTransitionPage`, aucun `GoRouterState`, aucun `go_router`. Le sens du
/// slide est dérivé de `Directionality.of(context)` via [zSlideBeginOffset] ;
/// [duration] et [curve] sont **injectés** (jamais codés en dur non
/// surchargeable).
PageRouteBuilder<T> zPageRoute<T>({
  required WidgetBuilder builder,
  ZRouteTransition transition = ZRouteTransition.slide,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _buildZTransition(
      context: context,
      transition: transition,
      animation: animation,
      curve: curve,
      child: child,
    ),
  );
}

/// `PageTransitionsBuilder` natif RTL-aware, enregistrable dans un
/// `PageTransitionsTheme` (`builders: {TargetPlatform.x: ZPageTransitionsBuilder()}`).
///
/// Réutilise [zSlideBeginOffset] : même inversion RTL que [zPageRoute], sans
/// dépendre d'aucun routeur.
class ZPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Construit un builder de transition. [transition] et [curve] injectés.
  const ZPageTransitionsBuilder({
    this.transition = ZRouteTransition.slide,
    this.curve = Curves.easeInOut,
  });

  /// Type de transition appliqué (enum, jamais un `bool` — NFR-U7).
  final ZRouteTransition transition;

  /// Courbe d'animation injectée.
  final Curve curve;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildZTransition(
      context: context,
      transition: transition,
      animation: animation,
      curve: curve,
      child: child,
    );
  }
}
