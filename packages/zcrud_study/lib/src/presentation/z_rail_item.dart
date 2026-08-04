/// `ZRailItem` — item de **rail horizontal** borné en largeur (CR-IFFD-49 ①).
///
/// PUBLIC (demande owner) : la carte par défaut (`ZDefaultFlashcardCard` & co.)
/// est réutilisée à plusieurs endroits chez les hôtes (page « study tools »,
/// liste de flashcards en grille…) — un hôte qui assemble SON propre défileur
/// horizontal doit pouvoir borner ses items avec la MÊME résolution de largeur
/// que les voies typées du socle, au lieu de recopier un `SizedBox(width:)`
/// avec sa propre constante.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// Largeur de REPLI d'un item de rail horizontal (CR-IFFD-49 ①), quand ni
/// [ZRailItem.width] ni le token `ZcrudTheme.railItemWidth` ne sont fournis.
///
/// **280 dp — et PAS les 300 dp mesurés chez IFFD** : 300 est la valeur d'UN
/// hôte, elle n'entre pas dans le socle sans arbitrage (réserve explicite de la
/// CR). Arbitrage retenu : sur les largeurs d'écran courantes (360–412 dp),
/// 280 dp laisse au moins ~60 dp de la carte suivante visibles — l'affordance
/// de défilement du rail, qu'un item pleine-largeur ferait disparaître. Un hôte
/// qui veut 300 le pose dans son thème (token) ou par paramètre.
const double zRailItemFallbackWidth = 280;

/// Item de rail borné en largeur — enveloppe appliquée par les voies typées de
/// `ZStudyToolsSectionSpec` en `axis: Axis.horizontal` UNIQUEMENT (jamais
/// autour d'un `itemBuilder` d'hôte : neutralité stricte du constructeur
/// principal), et réutilisable TELLE QUELLE par un hôte dans ses propres
/// surfaces (liste de flashcards en grille/rail, carrousels…).
///
/// Résolution de la largeur, documentée et testée : paramètre explicite
/// [width] > `ZcrudTheme.railItemWidth` (token de thème, décision d'apparence
/// de l'app consommatrice) > [zRailItemFallbackWidth]. La résolution du token
/// se fait au `build` (thème courant, réactif au changement de thème), jamais
/// figée à la construction.
class ZRailItem extends StatelessWidget {
  /// Construit un item de rail borné. [width] `null` ⇒ token de thème, puis
  /// repli du socle.
  const ZRailItem({required this.child, this.width, super.key});

  /// Largeur EXPLICITE demandée par l'appelant. `null` ⇒ token
  /// `ZcrudTheme.railItemWidth`, puis [zRailItemFallbackWidth].
  final double? width;

  /// Le contenu borné (typiquement une carte par défaut du socle).
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width ??
            ZcrudTheme.of(context).railItemWidth ??
            zRailItemFallbackWidth,
        child: child,
      );
}
