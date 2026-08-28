/// Styles **résolus** du dialogue de confirmation et de l'état vide.
///
/// Deux objets immuables, sans widget ni dépendance de rendu : ils lisent les
/// jetons `confirmDialog*` / `emptyState*` de `ZcrudTheme` et appliquent, pour
/// chacun, exactement le repli que la dartdoc du jeton promet. Un composant qui
/// les consomme n'a donc **aucune** décision de style à reprendre à son compte,
/// et deux composants distincts rendus dans le même thème sont identiques par
/// construction.
///
/// La séparation entre le style et le widget est délibérée : elle permet de
/// vérifier la résolution sans monter d'arbre, et laisse un hôte réutiliser les
/// mêmes valeurs dans son propre composant s'il n'emploie pas celui du socle.
library;

import 'package:flutter/material.dart';

import 'z_theme.dart';

/// Style résolu d'un **dialogue de confirmation**.
///
/// Contrat de nullité, à lire avant de consommer : `shape`, [titleStyle],
/// [contentStyle] et [actionsPadding] sont **transportés tels quels** depuis
/// `ZcrudTheme`, `null` compris. Un `null` n'est pas une absence de style :
/// c'est l'instruction « laisse `AlertDialog` suivre le `DialogTheme` ambiant,
/// puis son défaut Material ». Passer ces membres directement aux paramètres
/// homonymes d'`AlertDialog` produit donc le comportement documenté, sans
/// qu'aucune valeur ne soit inventée par le socle.
///
/// [destructiveColor] fait exception : il est **toujours résolu**, parce
/// qu'aucun composant Material ne porte de repli pour une action destructive.
/// À défaut de jeton, il vaut `ColorScheme.error` du thème ambiant.
///
/// ```dart
/// final style = ZConfirmDialogStyle.resolve(context);
/// AlertDialog(
///   shape: style.shape,
///   titleTextStyle: style.titleStyle,
///   contentTextStyle: style.contentStyle,
///   actionsPadding: style.actionsPadding ?? const EdgeInsets.all(8),
///   // …
/// );
/// ```
@immutable
class ZConfirmDialogStyle {
  /// Construit un style explicite — utile pour un test ou pour un hôte qui
  /// compose ses valeurs sans passer par le thème.
  const ZConfirmDialogStyle({
    required this.destructiveColor,
    this.shape,
    this.titleStyle,
    this.contentStyle,
    this.actionsPadding,
  });

  /// Résout le style depuis le thème ambiant de [context].
  ///
  /// Lit `ZcrudTheme.of(context)` — qui couvre à la fois le thème posé par
  /// `ZcrudScope`, l'extension de `ThemeData` et le repli dérivé — puis le
  /// `ColorScheme` ambiant pour l'unique membre à repli.
  factory ZConfirmDialogStyle.resolve(BuildContext context) {
    final ZcrudTheme tokens = ZcrudTheme.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ZConfirmDialogStyle(
      shape: tokens.confirmDialogShape,
      titleStyle: tokens.confirmDialogTitleStyle,
      contentStyle: tokens.confirmDialogContentStyle,
      actionsPadding: tokens.confirmDialogActionsPadding,
      destructiveColor: tokens.confirmDialogDestructiveColor ?? colors.error,
    );
  }

  /// Forme du dialogue, ou `null` pour suivre le `DialogTheme` ambiant.
  final ShapeBorder? shape;

  /// Style du titre, ou `null` pour suivre le `DialogTheme` ambiant.
  final TextStyle? titleStyle;

  /// Style du message, ou `null` pour suivre le `DialogTheme` ambiant.
  final TextStyle? contentStyle;

  /// Padding de la zone d'actions, ou `null` pour suivre la géométrie Material.
  final EdgeInsetsGeometry? actionsPadding;

  /// Couleur de l'action destructive — **jamais** `null`.
  final Color destructiveColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZConfirmDialogStyle &&
          other.shape == shape &&
          other.titleStyle == titleStyle &&
          other.contentStyle == contentStyle &&
          other.actionsPadding == actionsPadding &&
          other.destructiveColor == destructiveColor;

  @override
  int get hashCode => Object.hash(
    shape,
    titleStyle,
    contentStyle,
    actionsPadding,
    destructiveColor,
  );

  @override
  String toString() =>
      'ZConfirmDialogStyle(shape: $shape, titleStyle: $titleStyle, '
      'contentStyle: $contentStyle, actionsPadding: $actionsPadding, '
      'destructiveColor: $destructiveColor)';
}

/// Style résolu d'un **état vide** (illustration, titre, message, rythme).
///
/// Contrairement à [ZConfirmDialogStyle], **aucun membre n'est transporté
/// `null` quand le socle sait quoi mettre** : un état vide n'est pas un
/// composant Material, il n'existe donc pas de chaîne de repli derrière lui. Le
/// résolveur applique les replis que documentent les jetons `emptyState*` :
/// 48 dp pour le glyphe, `ColorScheme.onSurfaceVariant` pour sa couleur,
/// `TextTheme.titleMedium` / `TextTheme.bodyMedium` pour les deux textes, et le
/// `gapL` de `ZcrudTheme` pour le rythme.
///
/// [titleStyle] et [messageStyle] restent typés nullables : ils héritent de la
/// nullité du `TextTheme` ambiant, qu'un `ThemeData` très dépouillé peut laisser
/// vide. Un composant les passe alors tels quels à `Text.style`, dont c'est le
/// contrat.
@immutable
class ZEmptyStateStyle {
  /// Construit un style explicite — utile pour un test ou pour un hôte qui
  /// compose ses valeurs sans passer par le thème.
  const ZEmptyStateStyle({
    required this.iconSize,
    required this.iconColor,
    required this.spacing,
    this.titleStyle,
    this.messageStyle,
  });

  /// Résout le style depuis le thème ambiant de [context].
  factory ZEmptyStateStyle.resolve(BuildContext context) {
    final ZcrudTheme tokens = ZcrudTheme.of(context);
    final ThemeData theme = Theme.of(context);
    return ZEmptyStateStyle(
      iconSize: tokens.emptyStateIconSize ?? defaultIconSize,
      iconColor: tokens.emptyStateIconColor ?? theme.colorScheme.onSurfaceVariant,
      titleStyle: tokens.emptyStateTitleStyle ?? theme.textTheme.titleMedium,
      messageStyle: tokens.emptyStateMessageStyle ?? theme.textTheme.bodyMedium,
      spacing: tokens.emptyStateSpacing ?? tokens.gapL,
    );
  }

  /// Mesure de référence du glyphe d'un état vide, en dp.
  ///
  /// Publique parce qu'elle est le repli **documenté** du jeton
  /// `emptyStateIconSize` : un hôte qui veut « le défaut, mais un peu plus
  /// grand » a besoin de la valeur de départ.
  static const double defaultIconSize = 48;

  /// Taille du glyphe, en dp — **jamais** `null`.
  final double iconSize;

  /// Couleur du glyphe — **jamais** `null`.
  final Color iconColor;

  /// Style du titre, ou `null` si le `TextTheme` ambiant n'en porte pas.
  final TextStyle? titleStyle;

  /// Style du message, ou `null` si le `TextTheme` ambiant n'en porte pas.
  final TextStyle? messageStyle;

  /// Rythme principal entre illustration, bloc textuel et action, en dp —
  /// **jamais** `null`.
  final double spacing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZEmptyStateStyle &&
          other.iconSize == iconSize &&
          other.iconColor == iconColor &&
          other.titleStyle == titleStyle &&
          other.messageStyle == messageStyle &&
          other.spacing == spacing;

  @override
  int get hashCode =>
      Object.hash(iconSize, iconColor, titleStyle, messageStyle, spacing);

  @override
  String toString() =>
      'ZEmptyStateStyle(iconSize: $iconSize, iconColor: $iconColor, '
      'titleStyle: $titleStyle, messageStyle: $messageStyle, '
      'spacing: $spacing)';
}
