/// **CR-IFFD-64** — le RENDU DE RÉFÉRENCE de la carte de dossier d'étude par
/// défaut, centralisé en UN SEUL endroit (patron `ZStudyCardReference`
/// CR-IFFD-56, `ZFlashcardCardReference` CR-IFFD-57).
///
/// La carte de dossier était **la seule des six** de la famille à n'avoir
/// aucun rendu par défaut : `ZFolderCard` est une primitive à slots, et chaque
/// hôte refabriquait par-dessus ses dix-sept constantes. Ce fichier est le
/// **point d'audit unique** de ces valeurs ; `ZDefaultFolderCard` les rend.
///
/// ## Priorité de résolution, partout
///
/// **paramètre de carte > jeton `ZcrudTheme.folderCard*` > défaut-référence**
/// (les défauts-référence sont les constantes de [ZFolderCardReference]).
///
/// ## 🔴 FR-26 — ce fichier n'a PAS besoin de l'exception encadrée
///
/// Contrairement à `ZFlashcardCardReference` (quatre dégradés par type, non
/// dérivables d'un `ColorScheme`), **la carte de dossier n'a AUCUNE couleur
/// de référence** : sa matière est la couleur du **dossier**, choisie par
/// l'utilisateur et fournie au rendu, et ses couleurs de chrome sont des
/// **rôles** (`shadowColor` pour l'ombre — le legacy y écrivait `Colors.black`
/// en dur —, `surfaceContainerLow` pour la surface). Les valeurs figées ici
/// sont donc **exclusivement** des dimensions et des scalaires.
///
/// ⇒ Ce fichier n'est **PAS** inscrit dans l'exemption nominative de la garde
/// de source anti-couleurs (`z_widgets_hardcode_scan_test.dart`), et l'y
/// inscrire ferait **ROUGIR** sa contre-preuve « exemption INUTILE ». C'est la
/// forme forte de la condition ① de l'exception encadrée : on ne l'invoque que
/// lorsqu'elle est nécessaire.
///
/// ## Le contraste — plancher MESURÉ, jamais une fenêtre de clarté
///
/// La couleur d'un dossier est **arbitraire**. La bande d'accent et le liseré
/// sont donc dérivés par `zReadableTintOn` avec le plancher
/// [ZFolderCardReference.minContrast] (**3.0:1**, WCAG 2.2 §1.4.11 —
/// composants et objets graphiques), mesuré contre la surface **réellement
/// peinte** de la carte (fond du `CardTheme`, teinté par
/// [ZFolderCardReference.tintAlpha] le cas
/// échéant). Les premiers plans TEXTE (libellé de badge, sous-titre) visent
/// [ZFolderCardReference.textMinContrast] (**4.5:1**, §1.4.3 AA).
library;

import 'package:flutter/material.dart';

/// Les valeurs de RÉFÉRENCE de la carte de dossier d'étude (mesurées chez
/// IFFD, `folder_card_zcrud.dart:84-140` — portage annoté de
/// `folders_page.dart`), le point d'audit unique. Modifier une valeur ici
/// change le défaut de `ZDefaultFolderCard` partout.
abstract final class ZFolderCardReference {
  // ── Chrome de carte ───────────────────────────────────────────────────────

  /// Rayon de la carte (**12** — `kFolderCardRadius`).
  static const Radius cardRadius = Radius.circular(12);

  /// Padding interne de la carte (**12**, directionnel — AD-13,
  /// `kFolderCardPadding`).
  ///
  /// 🔴 **Distinct de `gapM`** : la primitive `ZFolderCard` pose
  /// `EdgeInsetsDirectional.all(theme.gapM)`, et `gapM` vaut **8** en thème nu.
  /// Sans ce défaut-référence, la carte par défaut rendrait 8 là où la
  /// référence pose 12 (leçon CR-IFFD-61 ①, rejouée ici).
  static const EdgeInsetsGeometry contentPadding =
      EdgeInsetsDirectional.all(12);

  /// Opacité de la teinte de FOND de la carte de référence (**0** — carte
  /// NEUTRE : le legacy repose sur la surface du `CardTheme`, la couleur du
  /// dossier vivant dans la bande, le liseré et la tuile).
  ///
  /// ⚠️ Diffère du défaut de la primitive `ZFolderCard` (`0.12`, parité lex) :
  /// c'est un **défaut de carte par défaut**, pas un changement de la
  /// primitive — un hôte passif de `ZFolderCard` rend le même pixel qu'avant.
  static const double tintAlpha = 0;

  /// Épaisseur du liseré teinté (**1**).
  static const double borderWidth = 1;

  /// Hauteur de la bande d'accent de tête (**4** — `kFolderCardAccentHeight`).
  static const double accentBandHeight = 4;

  // ── Ombre douce (couleur = rôle `shadowColor`, JAMAIS un littéral) ─────────

  /// Flou de l'ombre (**8** — `kFolderCardShadowBlur`).
  static const double shadowBlurRadius = 8;

  /// Décalage de l'ombre (**0, 2** — `kFolderCardShadowOffset`).
  static const Offset shadowOffset = Offset(0, 2);

  /// Opacité de l'ombre en thème CLAIR (**0.06** —
  /// `kFolderCardShadowAlphaLight`).
  static const double shadowAlphaLight = 0.06;

  /// Opacité de l'ombre en thème SOMBRE (**0.2** —
  /// `kFolderCardShadowAlphaDark`).
  static const double shadowAlphaDark = 0.2;

  // ── Tuile d'icône de tête ─────────────────────────────────────────────────

  /// Côté de la tuile d'icône (**36** — `kFolderCardIconBoxSize` ; PAS le 48
  /// des cartes d'étude ni le 32 de la carte de flashcard).
  static const double iconTileSize = 36;

  /// Rayon de la tuile d'icône (**8** — `kFolderCardIconBoxRadius`).
  static const Radius iconTileRadius = Radius.circular(8);

  /// Opacité de la teinte de fond de la tuile (**0.15** —
  /// `kFolderCardIconBoxAlpha`).
  static const double iconTileTintAlpha = 0.15;

  /// Taille du glyphe dans la tuile (**20** — `kFolderCardIconSize`).
  static const double glyphSize = 20;

  /// Glyphe de référence de la carte (`folder_rounded` — legacy).
  static const IconData glyph = Icons.folder_rounded;

  /// Taille du glyphe du slot menu (**18** — `kFolderCardMenuIconSize`).
  /// Exposée pour que l'hôte compose SON menu à la mesure de la référence :
  /// le slot `menu` reste rendu **verbatim** (le socle n'en fabrique aucun).
  static const double menuGlyphSize = 18;

  // ── Badges de compteur ────────────────────────────────────────────────────

  /// Opacité du fond d'un badge de compteur (**0.1** —
  /// `kFolderCardBadgeAlpha`).
  static const double badgeBackgroundAlpha = 0.1;

  /// Rayon d'un badge de compteur (**6** — `kFolderCardBadgeRadius`).
  static const Radius badgeRadius = Radius.circular(6);

  /// Taille du glyphe d'un badge (**11** — `kFolderCardBadgeIconSize`).
  static const double badgeGlyphSize = 11;

  /// Écart ENTRE deux badges (**8** — `kFolderCardBadgeSpacing`).
  static const double badgeSpacing = 8;

  /// Écart glyphe → libellé DANS un badge (**3** — legacy
  /// `folder_card_zcrud.dart:511-532`).
  static const double badgeGlyphGap = 3;

  /// Padding d'un badge (**6 / 3**, directionnel — legacy).
  static const EdgeInsetsGeometry badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 3);

  /// Taille de fonte du libellé de badge (**10** — legacy). Appliquée sur
  /// `labelSmall` pour hériter de la famille de l'hôte.
  static const double badgeFontSize = 10;

  /// Graisse du libellé de badge (`w600` — legacy).
  static const FontWeight badgeFontWeight = FontWeight.w600;

  // ── Sous-titre (matière / classement) ─────────────────────────────────────

  /// Taille de fonte du sous-titre (**11** — legacy `_subjectLabel`).
  static const double subtitleFontSize = 11;

  /// Opacité du sous-titre teinté (**0.8** — `kFolderCardSubjectAlpha`).
  static const double subtitleAlpha = 0.8;

  /// Écart titre → sous-titre (**2** — `kFolderCardSubtitleGap`,
  /// `Padding(top: 2)` du legacy).
  static const double subtitleGap = 2;

  // ── Contraste (les seuls scalaires qui ne viennent PAS du legacy) ──────────

  /// Plancher de contraste des SURFACES et COMPOSANTS graphiques de la carte —
  /// bande d'accent, liseré, glyphe de tuile (**3.0:1**, WCAG 2.2 §1.4.11).
  ///
  /// 🔴 **Ce n'est PAS une valeur du legacy** : le legacy peignait la couleur
  /// de dossier BRUTE (bande, tuile, glyphe, texte de badge), sans aucune
  /// mesure. C'est une valeur de socle, et c'est le cœur de CR-IFFD-64 : une
  /// couleur de dossier est choisie par l'utilisateur, donc arbitraire, et
  /// aucune fenêtre de clarté HSL ne borne son contraste (mesuré : `#FFFF00`
  /// rendait 2.13:1, `#FFFFFE` 1.28:1).
  static const double minContrast = 3.0;

  /// Plancher de contraste des premiers plans TEXTE de la carte — libellé de
  /// badge, sous-titre (**4.5:1**, WCAG 2.2 §1.4.3 AA, texte normal).
  static const double textMinContrast = 4.5;
}
