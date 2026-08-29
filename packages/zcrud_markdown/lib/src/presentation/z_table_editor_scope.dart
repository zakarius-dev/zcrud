/// Personnalisation de l'ÉDITEUR de tableau — opt-in (AD-57).
///
/// Le dialogue de saisie d'un tableau est ouvert par la barre d'outils, pas par
/// l'hôte : ses réglages ne peuvent donc pas voyager par un paramètre de
/// constructeur. Ils voyagent par le CONTEXTE, comme les autres réglages du
/// rich-text.
///
/// **Absent ⇒ dialogue historique, rendu strictement inchangé.**
library;

import 'package:flutter/widgets.dart';

/// Construit l'éditeur d'UNE cellule du dialogue tableau.
///
/// Reçoit la position de la cellule ([row], [column], indices 0-based), sa
/// [value] courante et le rappel [onChanged] par lequel la nouvelle valeur est
/// remontée au dialogue. Le socle ne présume rien du widget rendu : c'est à
/// l'appelant de décider si une cellule est un champ de texte, un document
/// rich-text, ou autre chose.
///
/// Contrat : le widget rendu DOIT appeler [onChanged] à chaque modification —
/// c'est la seule voie par laquelle la valeur est reprise à la validation.
typedef ZTableCellEditorBuilder = Widget Function(
  BuildContext context,
  int row,
  int column,
  String value,
  ValueChanged<String> onChanged,
);

/// Diffuse les réglages de l'éditeur de tableau au sous-arbre.
///
/// ```dart
/// ZTableEditorScope(
///   maxDim: 30,
///   cellBuilder: (context, row, column, value, onChanged) =>
///       MonEditeurDeCellule(value: value, onChanged: onChanged),
///   child: monEditeur,
/// )
/// ```
class ZTableEditorScope extends InheritedWidget {
  /// Diffuse les réglages au sous-arbre [child].
  const ZTableEditorScope({
    required super.child,
    this.maxDim,
    this.cellWidth,
    this.cellBuilder,
    super.key,
  });

  /// Borne SUPÉRIEURE du nombre de lignes et de colonnes du dialogue.
  ///
  /// `null` ⇒ [kZTableDefaultMaxDim]. La grille du dialogue défile déjà dans
  /// les deux axes : la borne ne protège pas le rendu, elle borne seulement ce
  /// qu'une manipulation accidentelle des compteurs peut produire. Un hôte qui
  /// édite des tableaux larges la relève sans autre conséquence.
  final int? maxDim;

  /// Largeur d'une colonne de saisie du dialogue, en pixels logiques.
  ///
  /// `null` ⇒ [kZTableDefaultCellWidth]. Une cellule qui porte autre chose
  /// qu'une ligne de texte a besoin de plus de place ; c'est le réglage qui
  /// accompagne [cellBuilder].
  final double? cellWidth;

  /// Éditeur de cellule fourni par l'appelant.
  ///
  /// `null` (défaut) ⇒ le champ de texte du dialogue, inchangé.
  final ZTableCellEditorBuilder? cellBuilder;

  /// Réglages hérités les plus proches, ou `null`.
  static ZTableEditorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZTableEditorScope>();

  @override
  bool updateShouldNotify(ZTableEditorScope oldWidget) =>
      maxDim != oldWidget.maxDim ||
      cellWidth != oldWidget.cellWidth ||
      cellBuilder != oldWidget.cellBuilder;
}

/// Borne par défaut des dimensions du dialogue tableau (lignes et colonnes).
const int kZTableDefaultMaxDim = 12;

/// Largeur par défaut d'une colonne de saisie du dialogue tableau.
const double kZTableDefaultCellWidth = 96;
