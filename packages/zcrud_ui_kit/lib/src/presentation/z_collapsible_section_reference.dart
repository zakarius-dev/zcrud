/// **Unique** fichier de référence de la **section repliable à en-tête**
/// (`ZCollapsibleSection`).
///
/// ## Ce que ce fichier est
///
/// Les **métriques** auditées d'une section repliable — rien d'autre :
/// élévations, rayons, opacités de filet, tailles de glyphe, insets, graisses,
/// nombre de tours du chevron, durée de sa rotation. Ce sont des **scalaires**
/// (et des insets **directionnels**) : ils décrivent une géométrie et un
/// rythme, pas une teinte.
///
/// ## Ce que ce fichier n'est PAS
///
/// **Il ne contient aucune couleur, et ne doit jamais en contenir.** Les
/// couleurs de la section viennent toutes des rôles du `ColorScheme` de
/// l'hôte (`primary`, `secondaryContainer`, `onSecondaryContainer`,
/// `onSurfaceVariant`), de `ThemeData.dividerColor` /
/// `ThemeData.scaffoldBackgroundColor` / `ThemeData.cardColor`, ou d'une clé
/// de couleur déclarée par l'hôte et résolue par `zResolveColorKeyOrSlot`.
/// Une garde de source vérifie l'absence de littéral de couleur ici.
///
/// Les **opacités** qui vivent ici ne sont pas des couleurs : elles disent de
/// combien un filet s'efface, jamais quelle teinte il porte.
///
/// ## Comment ces valeurs sont appliquées
///
/// Jamais inconditionnellement : elles sont le **dernier maillon** d'une
/// chaîne **paramètre > jeton `ZcrudTheme` > référence**. Les dix valeurs qui
/// ont un jeton sont marquées ci-dessous ; les autres décrivent la structure
/// même de la section et ne sont pas des réglages.
library;

import 'package:flutter/widgets.dart';

/// Métriques auditées de la section repliable.
///
/// Chaque groupe documente la **surface** qu'il décrit et le rôle exact de
/// chaque valeur. Aucune de ces valeurs n'est peinte seule.
abstract final class ZCollapsibleSectionReference {
  // Origine des valeurs de ce fichier — deux implémentations indépendantes,
  // à l'identique, relevées le 2026-09-09 :
  //   * iffd  lib/src/presentation/features/tasks/pages/daily_tasks_page.dart
  //           :638-780 (`DailyTasksListWidget`) ;
  //   * lex   packages/lex_ui/lib/presentation/screens/study_screen.dart
  //           :657-790 (`_WeekGroup`).
  // Les `fichier:ligne` de chaque scalaire sont cités en regard.

  // ── Enveloppe ─────────────────────────────────────────────────────────────

  /// Marge extérieure de la section, **directionnelle** : la même en RTL.
  ///
  /// Une section est un bloc dans une pile de blocs ; sans cette respiration,
  /// deux sections voisines se touchent et l'ombre de l'une mange le contour
  /// de l'autre.
  // iffd:672 / lex:679-682 — `symmetric(horizontal: 12, vertical: 6)`.
  static const EdgeInsetsDirectional margin =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6);

  /// Rayon des coins de la section (conteneur et en-tête).
  ///
  /// **Réglable par jeton** (`ZcrudTheme.collapsibleSectionCornerRadius`) et
  /// par paramètre (`ZCollapsibleSectionSpec.cornerRadius`).
  // iffd:669 / lex:685 — `BorderRadius.circular(12)`.
  static const double cornerRadius = 12;

  /// Opacité du **filet de contour**, appliquée à `ThemeData.dividerColor`.
  ///
  /// Un contour à pleine opacité lit comme une bordure de tableau ; à cette
  /// valeur il lit comme une arête de carte.
  ///
  /// **Réglable par jeton** (`ZcrudTheme.collapsibleSectionBorderAlpha`).
  // iffd:670 / lex:686 — `dividerColor.withValues(alpha: 0.6)`.
  static const double borderAlpha = 0.6;

  /// Élévation portée **quand la section est dépliée**.
  ///
  /// Dépliée, c'est l'**en-tête** qui la porte : l'ombre marque la césure
  /// entre l'en-tête et le corps. Repliée, la même valeur passe au
  /// **conteneur** : les deux élévations s'échangent, la section entière
  /// devenant alors une carte posée.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionExpandedElevation`).
  // iffd:676,688 / lex:695,710 — `elevation: expanded ? 8 : 0` (en-tête),
  // `elevation: expanded ? 0 : 8` (conteneur).
  static const double expandedElevation = 8;

  /// Élévation portée **quand la section est repliée** par la surface qui ne
  /// porte pas l'ombre — voir [expandedElevation] pour l'échange.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionCollapsedElevation`).
  // iffd:676,688 / lex:695,710 — l'autre moitié de l'échange.
  static const double collapsedElevation = 0;

  // ── Ligne d'en-tête ───────────────────────────────────────────────────────

  /// Insets du contenu de la ligne d'en-tête, **directionnels**.
  // iffd:694-695 / lex:716-719 — `contentPadding` du `ListTile`,
  // `symmetric(horizontal: 12, vertical: 4)`.
  static const EdgeInsetsDirectional headerContentPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 4);

  /// Écart entre le disque de tête et le titre.
  ///
  /// Reprend l'écart qu'un `ListTile` pose de lui-même entre son `leading` et
  /// son `title` : la ligne est ici construite à la main (pour que le geste
  /// couvre exactement l'en-tête et pas l'action de l'hôte), la valeur est
  /// donc citée explicitement.
  // `ListTile.horizontalTitleGap` — défaut Material 16.
  static const double leadingGap = 16;

  /// Inset du disque de tête autour de son glyphe, **directionnel**.
  // iffd:696-697 / lex:721 — `EdgeInsets.all(8)`.
  static const EdgeInsetsDirectional leadingPadding =
      EdgeInsetsDirectional.all(8);

  /// Opacité du **fond** du disque de tête, appliquée à sa teinte.
  ///
  /// Le disque est un halo, pas une pastille pleine : à cette opacité le
  /// glyphe reste lisible sur le fond de l'en-tête.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionLeadingBackgroundAlpha`).
  // iffd:698 / lex:722 — `primary.withValues(alpha: 0.1)`.
  static const double leadingBackgroundAlpha = 0.1;

  /// Taille du glyphe du disque de tête.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionLeadingIconSize`).
  // iffd:704 / lex:728 — `size: 20`.
  static const double leadingIconSize = 20;

  /// Graisse du titre, appliquée par-dessus les métriques de
  /// `TextTheme.titleMedium`.
  // iffd:713 / lex:740 — `fontWeight: FontWeight.w600`.
  static const FontWeight titleWeight = FontWeight.w600;

  /// Nombre de lignes du titre avant écrêtage par ellipse.
  ///
  /// Une seule : un en-tête qui grandit avec son libellé décale toute la pile
  /// de sections et rend leur alignement illisible.
  // iffd:715 / lex:737 — `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
  static const int titleMaxLines = 1;

  // ── Pastille de compte ────────────────────────────────────────────────────

  /// Écart entre le titre et la pastille de compte, **directionnel**.
  // iffd:721 / lex:747 — `margin: EdgeInsets.only(left: 8)`.
  static const EdgeInsetsDirectional countMargin =
      EdgeInsetsDirectional.only(start: 8);

  /// Insets de la pastille de compte, **directionnels**.
  // iffd:722-723 / lex:748-751 — `symmetric(horizontal: 10, vertical: 4)`.
  static const EdgeInsetsDirectional countPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4);

  /// Rayon des coins de la pastille de compte.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionCountCornerRadius`).
  // iffd:726 / lex:753 — `BorderRadius.circular(12)`.
  static const double countCornerRadius = 12;

  /// Graisse du nombre, appliquée par-dessus `TextTheme.labelSmall`.
  // iffd:729 / lex:757 — `fontWeight: FontWeight.bold`.
  static const FontWeight countWeight = FontWeight.bold;

  // ── Chevron ───────────────────────────────────────────────────────────────

  /// Rotation du chevron **déplié** : un demi-tour, donc pointe en haut.
  // iffd:751 / lex:766 — `turns: expanded ? 0.5 : 0`.
  static const double chevronExpandedTurns = 0.5;

  /// Rotation du chevron **replié** : aucune, donc pointe en bas.
  // iffd:751 / lex:766 — l'autre moitié.
  static const double chevronCollapsedTurns = 0;

  /// Durée de la rotation du chevron.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionChevronDuration`). Nulle quand l'usager a
  /// demandé la réduction des animations — la valeur n'est alors pas lue.
  // iffd:752 / lex:767 — `Duration(milliseconds: 200)`.
  static const Duration chevronDuration = Duration(milliseconds: 200);

  // ── Corps ─────────────────────────────────────────────────────────────────

  /// Opacité du **filet supérieur du corps**, appliquée à
  /// `ThemeData.dividerColor`.
  ///
  /// Nettement plus effacé que [borderAlpha] : ce filet sépare l'en-tête du
  /// corps à l'intérieur d'une même carte, il n'encadre rien.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionBodyBorderAlpha`).
  // iffd:769 / lex:783 — `dividerColor.withValues(alpha: 0.2)`.
  static const double bodyBorderAlpha = 0.2;

  /// Rayon des **coins bas** du corps.
  ///
  /// Volontairement plus serré que [cornerRadius] : le corps est posé *dans*
  /// le conteneur, et deux arrondis égaux laisseraient voir un liseré de fond
  /// dans chaque coin.
  ///
  /// **Réglable par jeton**
  /// (`ZcrudTheme.collapsibleSectionBodyCornerRadius`).
  // iffd:772-775 / lex:786-788 — `bottomLeft`/`bottomRight` `Radius.circular(10)`.
  static const double bodyCornerRadius = 10;

  // ── Accessibilité ─────────────────────────────────────────────────────────

  /// Hauteur minimale de la zone de geste de l'en-tête (invariant AD-13).
  ///
  /// Ne vient d'aucune des deux implémentations relevées : c'est le plancher
  /// de cible tactile du dépôt, imposé ici parce que la ligne d'en-tête est
  /// construite à la main.
  static const double minTouchTarget = 48;
}
