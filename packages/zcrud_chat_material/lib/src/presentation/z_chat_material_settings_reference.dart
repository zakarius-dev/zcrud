/// La **géométrie de référence** de la feuille de réglages Material.
///
/// Ce paquet n'écrit aucune valeur : chaque dimension qu'il rend est une
/// constante du socle, reprise ici sous le nom que la feuille de réglages
/// emploie. Un fichier unique pour toute la famille, pour qu'une dimension
/// change à un seul endroit — et pour que la garde de source du satellite
/// (aucun littéral numérique hors des bornes neutres) reste vraie.
library;

import 'package:zcrud_chat/zcrud_chat.dart';

/// Dimensions de la feuille de réglages Material, toutes empruntées au socle.
abstract final class ZChatMaterialSettingsReference {
  /// Retrait de début du séparateur posé **entre** deux sections.
  static const double dividerIndent = ZChatToolSheetReference.dividerIndent;

  /// Écart entre deux puces d'une rangée, et entre deux lignes de puces.
  static const double chipGap = ZChatToolSheetReference.chipGap;

  /// Écart vertical entre le titre d'une famille et son contrôle.
  static const double blockGap = ZChatToolSheetReference.blockGap;

  /// Plancher tactile d'une cible (titre d'en-tête, bouton, puce).
  static const double minTapTarget = kZChatMinTapTarget;

  /// Indentation du second niveau d'un catalogue de corpus (les enfants d'une
  /// entrée sélectionnée) : deux fois l'écart de puce.
  static const double childIndent = chipGap * 2;
}
