/// Valeurs de RÉFÉRENCE des formes de la surface de saisie notée.
///
/// Ce fichier est la **seule** source des géométries de forme de
/// `ZFlashcardAnswerInput` : rayons, marges et épaisseurs y sont centralisés
/// et audités, jamais éparpillés dans les widgets.
///
/// **Aucune couleur ici.** Une couleur de référence serait une couleur en dur
/// (FR-26) ; les formes, elles, ne sont dérivables d'aucun rôle du
/// `ColorScheme` — c'est ce qui justifie leur présence. Les teintes des
/// dispositions non-référence se résolvent par **clé** (seam du cœur) ou par
/// rôle Material 3.
///
/// Priorité, partout : paramètre de la surface > jeton `ZcrudTheme` > ces
/// valeurs.
library;

import 'package:flutter/widgets.dart';

/// Géométries de référence des formes de la surface de saisie notée.
abstract final class ZAnswerInputReference {
  /// Rayon des coins d'une tuile de choix (`ZAnswerChoiceLayout.tile`).
  static const Radius choiceTileRadius = Radius.circular(12);

  /// Gouttière verticale entre deux tuiles de choix, en dp.
  ///
  /// Appliquée en marge SYMÉTRIQUE (haut et bas) : deux tuiles voisines sont
  /// donc séparées du double, et la première comme la dernière gardent la
  /// même respiration vis-à-vis de ce qui les encadre.
  static const double choiceTileGap = 6;

  /// Épaisseur du liseré d'une tuile de choix NON sélectionnée, en dp.
  static const double choiceTileBorderWidth = 1;

  /// Épaisseur du liseré d'une tuile de choix SÉLECTIONNÉE, en dp.
  ///
  /// Strictement supérieure à [choiceTileBorderWidth] : la sélection reste
  /// portée par une FORME (un trait plus épais), jamais par la seule couleur
  /// (invariant AD-13).
  static const double choiceTileSelectedBorderWidth = 2;

  /// Épaisseur du pourtour d'un contrôle d'aide en disposition côte à côte
  /// (`ZAnswerActionsLayout.sideBySide`), en dp.
  static const double actionOutlineWidth = 1;
}
