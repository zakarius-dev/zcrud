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
///
/// **CR-IFFD-62 ①** — la HAUTEUR suit le MÊME patron (paramètre [height] >
/// token `ZcrudTheme.railItemHeight`) à une différence près, assumée et
/// motivée : il n'y a **pas de repli chiffré**. Voir [height].
class ZRailItem extends StatelessWidget {
  /// Construit un item de rail borné. [width] `null` ⇒ token de thème, puis
  /// repli du socle ; [height] `null` ⇒ token de thème, puis AUCUNE contrainte.
  const ZRailItem({required this.child, this.width, this.height, super.key});

  /// Largeur EXPLICITE demandée par l'appelant. `null` ⇒ token
  /// `ZcrudTheme.railItemWidth`, puis [zRailItemFallbackWidth].
  final double? width;

  /// Hauteur EXPLICITE demandée par l'appelant (**CR-IFFD-62 ①**). `null` ⇒
  /// token `ZcrudTheme.railItemHeight`, puis **aucune contrainte de hauteur**
  /// (l'item garde la hauteur de son contenu — rendu strictement inchangé).
  ///
  /// **Pourquoi aucun repli chiffré, contrairement à [width]** : une
  /// largeur non bornée dans un défileur horizontal est une FAUTE de layout
  /// (rien n'est peint, et le debug lève en rafale), donc un repli y est
  /// obligatoire ; une hauteur non bornée est licite et c'est le rendu actuel
  /// de tous les rails. Poser 200 ici l'imposerait à tout item de rail de tout
  /// hôte — y compris ceux qui n'y mettent pas des flashcards. La hauteur de
  /// RÉFÉRENCE (200) reste portée par la carte de flashcard par défaut, là où
  /// elle a un sens (`ZFlashcardCardReference.cardHeight`).
  ///
  /// La hauteur ainsi posée est **TIGHT** : elle est le « cadre » au sens
  /// de CR-IFFD-62 ⑤. Une carte du socle qui la reçoit **la remplit** (son
  /// pied est poussé au bas) au lieu d'additionner ses hauteurs.
  final double? height;

  /// Le contenu borné (typiquement une carte par défaut du socle).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return SizedBox(
      width: width ?? theme.railItemWidth ?? zRailItemFallbackWidth,
      // AD-4 — `null` des DEUX côtés ⇒ capacité ABSENTE : `SizedBox(height:
      // null)` ne contraint rien, l'item garde exactement sa hauteur actuelle.
      height: height ?? theme.railItemHeight,
      child: child,
    );
  }
}
