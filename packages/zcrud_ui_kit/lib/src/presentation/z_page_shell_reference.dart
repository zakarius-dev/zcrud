/// **Unique** fichier de référence du chrome de page de ce paquet : app-bar
/// d'identité, bouton d'action flottant, puces.
///
/// ## Ce que ce fichier est
///
/// Les **métriques** auditées du chrome de référence — rien d'autre. Alphas de
/// composition, rayons, élévations, décalages d'ombre, tailles de glyphe,
/// interlettrage. Ce sont des **scalaires** : ils décrivent une géométrie, pas
/// une teinte.
///
/// ## Ce que ce fichier n'est PAS
///
/// **Il ne contient aucune couleur, et ne doit jamais en contenir.** Les
/// couleurs du chrome viennent toutes de la palette signature de `zcrud_core`
/// (`zResolveGradient` / `ZcrudTheme.signaturePalette` /
/// `ZSignaturePaletteReference`) ou des rôles du `ColorScheme` de l'hôte. Une
/// garde de source vérifie l'absence de littéral de couleur ici.
///
/// ## Comment ces valeurs sont appliquées
///
/// Jamais inconditionnellement : elles sont le **dernier maillon** d'une chaîne
/// **paramètre > jeton `ZcrudTheme` > référence**. Pour les membres COULEUR qui
/// les accompagnent, le profil `ZReferenceProfile.neutral` neutralise
/// entièrement la référence ; les scalaires d'ici, eux, ne peignent rien par
/// eux-mêmes et restent donc sans effet visible quand la couleur est absente.
library;

import 'package:flutter/widgets.dart';

/// Métriques auditées du chrome de page.
///
/// Chaque groupe documente la **surface** qu'il décrit et le rôle exact de
/// chaque valeur. Aucune de ces valeurs n'est peinte seule.
abstract final class ZPageShellReference {
  // ── App-bar d'identité ────────────────────────────────────────────────────

  /// Rampe d'opacité du **lavis** d'app-bar, du haut vers le bas.
  ///
  /// Le dégradé d'identité n'est pas peint à saturation pleine dans une
  /// app-bar : il y est posé en **lavis**, c'est-à-dire une même teinte de base
  /// déclinée sur ces quatre opacités décroissantes. La teinte reste
  /// reconnaissable, le contenu de la barre reste lisible sur la surface de
  /// l'hôte, et la barre ne devient pas un bloc de couleur.
  ///
  /// Quatre arrêts, dans cet ordre exact — ni trois, ni cinq : la décroissance
  /// rapide en tête puis lente en pied est ce qui donne au lavis son aspect de
  /// halo plutôt que de bande.
  static const List<double> appBarWashAlphas = <double>[0.15, 0.10, 0.05, 0.02];

  /// Élévation de l'app-bar **quand elle porte un lavis d'identité**.
  ///
  /// Zéro : sous un lavis, l'ombre portée de l'app-bar ajoute une seconde
  /// séparation visuelle qui concurrence la teinte. Sans lavis, l'élévation
  /// n'est pas touchée — elle reste celle du thème de l'hôte.
  static const double appBarWashElevation = 0;

  /// Début du lavis (haut de la barre). Vertical : aucune notion de gauche ni
  /// de droite n'est introduite, la valeur est donc identique en RTL.
  static const Alignment appBarWashBegin = Alignment.topCenter;

  /// Fin du lavis (bas de la barre). Voir [appBarWashBegin].
  static const Alignment appBarWashEnd = Alignment.bottomCenter;

  // ── Bouton d'action flottant ──────────────────────────────────────────────

  /// Rayon des coins du fond dégradé du bouton d'action flottant **étendu**.
  ///
  /// Le bouton étendu de référence est un rectangle à coins très arrondis, pas
  /// une capsule : 20 dp pour une hauteur de 56 dp.
  static const double fabCornerRadius = 20;

  /// Opacité de l'ombre colorée portée par le bouton d'action flottant.
  ///
  /// L'ombre reprend la **teinte de base** du dégradé du bouton (jamais du
  /// noir) : c'est ce qui donne l'impression que le bouton diffuse sa couleur.
  static const double fabShadowAlpha = 0.4;

  /// Rayon de flou de l'ombre colorée du bouton d'action flottant.
  static const double fabShadowBlurRadius = 20;

  /// Décalage de l'ombre colorée : vers le bas uniquement (aucune composante
  /// horizontale, donc identique en RTL).
  static const Offset fabShadowOffset = Offset(0, 8);

  /// Élévation du bouton d'action flottant **posé sur son fond dégradé**.
  ///
  /// Zéro au repos comme au tap : l'ombre est déjà rendue par le fond, et
  /// l'élévation Material en ajouterait une seconde, grise, décalée.
  static const double fabElevation = 0;

  /// Taille du glyphe du bouton d'action flottant étendu.
  static const double fabIconSize = 22;

  /// Interlettrage du libellé du bouton d'action flottant étendu.
  static const double fabLabelLetterSpacing = 0.3;

  /// Graisse du libellé du bouton d'action flottant étendu.
  static const FontWeight fabLabelWeight = FontWeight.w600;

  // ── Puces ─────────────────────────────────────────────────────────────────

  /// Rayon des coins d'une puce de choix.
  ///
  /// 12 dp : une puce à coins arrondis, franchement distincte de la capsule
  /// (`StadiumBorder`) qu'est la puce Material 3 par défaut.
  static const double chipCornerRadius = 12;

  /// Une puce de choix affiche-t-elle la coche Material de sélection ?
  ///
  /// Non : la sélection est portée par le fond teinté et par l'avatar de la
  /// puce. La coche ajouterait un troisième signal et décalerait le libellé au
  /// moment de la sélection.
  static const bool chipShowCheckmark = false;
}
