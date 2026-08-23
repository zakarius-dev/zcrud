/// Les valeurs de **référence** de la feuille d'outils.
///
/// Priorité **paramètre > jeton > référence** : chaque valeur publiée ici est
/// la dernière du triplet — un satellite de rendu la lit quand ni l'hôte ni le
/// thème n'ont tranché. Aucune couleur n'y figure : ce sont des géométries et
/// des fractions, invariantes par thème et par luminosité.
library;

/// Géométries de référence de la feuille d'outils et de ses tuiles.
///
/// Les trois fractions de hauteur décrivent une feuille **négociable** : elle
/// s'ouvre à [sheetInitialSize] de la hauteur disponible, se replie jusqu'à
/// [sheetMinSize] et se déplie jusqu'à [sheetMaxSize].
abstract final class ZChatToolSheetReference {
  /// Fraction de hauteur à l'ouverture.
  static const double sheetInitialSize = 0.6;

  /// Fraction de hauteur minimale atteignable en repliant.
  static const double sheetMinSize = 0.35;

  /// Fraction de hauteur maximale atteignable en dépliant.
  static const double sheetMaxSize = 0.9;

  /// Marge interne de la feuille.
  static const double sheetPadding = 16;

  /// Écart vertical entre deux blocs de la feuille.
  static const double blockGap = 8;

  /// Écart entre deux puces d'une rangée.
  static const double chipGap = 8;

  /// Retrait de début d'un séparateur de section.
  static const double dividerIndent = 16;
}
