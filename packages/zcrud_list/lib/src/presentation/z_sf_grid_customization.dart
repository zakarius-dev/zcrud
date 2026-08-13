/// Modèles de **personnalisation de grille** consommés par
/// [ZSfDataGridRenderer] : en-têtes multi-lignes (groupes empilés) et
/// dimensionnement **par colonne**.
///
/// Ces types vivent dans `zcrud_list` (jamais dans `zcrud_core`) : ils
/// décrivent des réglages de **rendu tabulaire**, pas le schéma déclaratif. Un
/// hôte qui ne les utilise pas ne change rien à son rendu (tous les paramètres
/// qui les portent sont vides par défaut).
///
/// Ils sont **neutres côté données** : ils désignent les colonnes par leur
/// `name` (`ZListColumn.name` = `field.name`) et portent des **clés l10n**
/// résolues au rendu (`label(context, ...)`) — aucun libellé ni aucune
/// couleur codés en dur (FR-26).
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// Style **CONDITIONNEL** d'une cellule, résolu par ligne × colonne (cf.
/// `ZSfDataGridRenderer.cellStyleBuilder`).
///
/// Chaque champ est **nullable** : un style partiel
/// (`ZSfCellStyle(textStyle: ...)`) ne touche QUE ce qu'il déclare, le reste
/// gardant le rendu par défaut de la cellule (fond transparent, alignement
/// `centerStart`, marge horizontale de 12, ellipse). Un builder qui rend
/// `null` pour une cellule la laisse **entièrement** au rendu par défaut.
///
/// FR-26 : ce type ne porte **aucune** couleur par défaut — c'est l'appelant
/// qui dérive ses valeurs de son thème (`Theme.of(context).colorScheme`,
/// `ZcrudTheme`), jamais un hex codé dans ce paquet.
@immutable
class ZSfCellStyle {
  /// Construit un style de cellule (tous les champs optionnels).
  const ZSfCellStyle({
    this.backgroundColor,
    this.textStyle,
    this.alignment,
    this.padding,
    this.textAlign,
    this.maxLines,
  });

  /// Couleur de FOND de la cellule.
  final Color? backgroundColor;

  /// Style du TEXTE (couleur, graisse, italique, taille…). Il est **fusionné**
  /// par-dessus le style courant du thème (`DefaultTextStyle.merge`) : ne
  /// déclarer que `fontWeight` conserve donc la police et la couleur du thème.
  final TextStyle? textStyle;

  /// Alignement du contenu dans la cellule (utiliser les variantes
  /// **directionnelles** — `AlignmentDirectional` — pour rester RTL-correct,
  /// AD-13).
  final AlignmentGeometry? alignment;

  /// Marge interne de la cellule (utiliser `EdgeInsetsDirectional`, AD-13).
  final EdgeInsetsGeometry? padding;

  /// Alignement du texte (`TextAlign.start`/`end` — jamais `left`/`right`,
  /// AD-13).
  final TextAlign? textAlign;

  /// Nombre maximal de lignes du texte (utile avec la hauteur de ligne
  /// adaptative).
  final int? maxLines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSfCellStyle &&
          runtimeType == other.runtimeType &&
          backgroundColor == other.backgroundColor &&
          textStyle == other.textStyle &&
          alignment == other.alignment &&
          padding == other.padding &&
          textAlign == other.textAlign &&
          maxLines == other.maxLines;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        backgroundColor,
        textStyle,
        alignment,
        padding,
        textAlign,
        maxLines,
      );

  @override
  String toString() => 'ZSfCellStyle(backgroundColor: $backgroundColor, '
      'textStyle: $textStyle, alignment: $alignment, padding: $padding, '
      'textAlign: $textAlign, maxLines: $maxLines)';
}

/// Groupe d'en-tête **empilé** : un libellé unique couvrant plusieurs colonnes
/// sur une ligne d'en-tête supplémentaire (patron « Valeurs (F/Kg) » couvrant
/// `valeurTransacParKg`/`valeurAppliqueeParKg`/`ecart`).
///
/// Plusieurs groupes forment une **ligne** d'en-tête ; plusieurs lignes
/// s'empilent (cf. `ZSfDataGridRenderer.stackedHeaders`, liste de lignes,
/// de haut en bas). Les colonnes non couvertes par un groupe restent
/// simplement vides sur cette ligne.
@immutable
class ZSfStackedHeader {
  /// Construit un groupe d'en-tête empilé.
  const ZSfStackedHeader({required this.labelKey, required this.columnNames});

  /// Clé l10n **non résolue** du libellé du groupe (résolue au rendu via
  /// `label(context, labelKey)` : une clé inconnue rend le texte tel quel,
  /// jamais un throw — AD-10).
  final String labelKey;

  /// `name` des colonnes couvertes (mêmes clés que `ZListColumn.name`). Une
  /// colonne inconnue est simplement ignorée par Syncfusion.
  final List<String> columnNames;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSfStackedHeader &&
          runtimeType == other.runtimeType &&
          labelKey == other.labelKey &&
          listEquals(columnNames, other.columnNames);

  @override
  int get hashCode =>
      Object.hash(runtimeType, labelKey, Object.hashAll(columnNames));

  @override
  String toString() =>
      'ZSfStackedHeader(labelKey: $labelKey, columnNames: $columnNames)';
}

/// Dimensionnement **d'UNE colonne**, appliqué par `name` (cf.
/// `ZSfDataGridRenderer.columnSizing`).
///
/// Chaque champ est **nullable** et n'est posé sur la `GridColumn` que s'il
/// est fourni : une entrée partielle (`ZSfColumnSizing(minimumWidth: 180)`)
/// laisse les autres réglages à leur valeur d'origine (largeur dérivée du
/// schéma, `columnWidthMode` de la grille). Aucune valeur par défaut de
/// Syncfusion n'est réécrite « au passage ».
@immutable
class ZSfColumnSizing {
  /// Construit un dimensionnement de colonne (tous les champs optionnels).
  const ZSfColumnSizing({
    this.width,
    this.minimumWidth,
    this.maximumWidth,
    this.widthMode,
    this.autoFitPadding,
  });

  /// Largeur FIXE (px logiques). Écrase la largeur indicative dérivée du
  /// schéma (`ZListColumn.width`).
  final double? width;

  /// Largeur minimale (px logiques) — la colonne ne rétrécit pas en deçà.
  final double? minimumWidth;

  /// Largeur maximale (px logiques) — la colonne ne s'étend pas au-delà.
  final double? maximumWidth;

  /// Mode de largeur **spécifique à cette colonne** ; il est **prioritaire**
  /// sur le mode de la grille (règle Syncfusion).
  final ColumnWidthMode? widthMode;

  /// Marge prise en compte par l'auto-dimensionnement (`auto`/`fitByCellValue`).
  final double? autoFitPadding;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSfColumnSizing &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          minimumWidth == other.minimumWidth &&
          maximumWidth == other.maximumWidth &&
          widthMode == other.widthMode &&
          autoFitPadding == other.autoFitPadding;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        width,
        minimumWidth,
        maximumWidth,
        widthMode,
        autoFitPadding,
      );

  @override
  String toString() => 'ZSfColumnSizing(width: $width, min: $minimumWidth, '
      'max: $maximumWidth, widthMode: $widthMode, '
      'autoFitPadding: $autoFitPadding)';
}
