/// Réglages **par instance** d'une section repliable.
///
/// Le niveau 1 de la chaîne `paramètre > jeton > référence` : ce que porte
/// cette spec l'emporte sur le jeton `ZcrudTheme.collapsibleSection*`
/// correspondant, qui l'emporte lui-même sur la valeur de référence.
///
/// Tout est nullable, et `null` signifie **« je ne décide pas »** — jamais
/// « remets à zéro ». Une spec entièrement nulle ne change donc rien.
library;

import 'package:flutter/widgets.dart';

/// Métriques d'une section repliable, réglables pour **une** section.
///
/// À poser sur `ZCollapsibleSection.spec` quand une section doit s'écarter du
/// thème. Pour régler *toutes* les sections d'une application, poser les
/// jetons `ZcrudTheme.collapsibleSection*` : ils portent exactement les mêmes
/// dix valeurs.
///
/// ```dart
/// ZCollapsibleSection(
///   title: weekLabel,
///   count: folders.length,
///   spec: const ZCollapsibleSectionSpec(cornerRadius: 4, expandedElevation: 0),
///   child: grid,
/// )
/// ```
@immutable
class ZCollapsibleSectionSpec {
  /// Crée une spec. Chaque champ omis laisse la décision au jeton de thème,
  /// puis à la référence.
  const ZCollapsibleSectionSpec({
    this.expandedElevation,
    this.collapsedElevation,
    this.cornerRadius,
    this.borderAlpha,
    this.bodyBorderAlpha,
    this.bodyCornerRadius,
    this.chevronDuration,
    this.leadingIconSize,
    this.leadingBackgroundAlpha,
    this.countCornerRadius,
  });

  /// Élévation portée quand la section est **dépliée** (par son en-tête).
  final double? expandedElevation;

  /// Élévation portée quand la section est **repliée** (par son conteneur).
  final double? collapsedElevation;

  /// Rayon des coins de la section (conteneur et en-tête).
  final double? cornerRadius;

  /// Opacité du filet de contour, appliquée à `ThemeData.dividerColor`.
  final double? borderAlpha;

  /// Opacité du filet supérieur du corps, appliquée à
  /// `ThemeData.dividerColor`.
  final double? bodyBorderAlpha;

  /// Rayon des coins bas du corps.
  final double? bodyCornerRadius;

  /// Durée de la rotation du chevron. Ignorée quand l'usager a demandé la
  /// réduction des animations : la rotation est alors instantanée.
  final Duration? chevronDuration;

  /// Taille du glyphe du disque de tête.
  final double? leadingIconSize;

  /// Opacité du fond du disque de tête, appliquée à sa teinte.
  final double? leadingBackgroundAlpha;

  /// Rayon des coins de la pastille de compte.
  final double? countCornerRadius;

  /// Une copie où les champs fournis remplacent les miens.
  ///
  /// Comme partout dans cette classe, un argument `null` **ne remet rien à
  /// zéro** : il laisse la valeur en place.
  ZCollapsibleSectionSpec copyWith({
    double? expandedElevation,
    double? collapsedElevation,
    double? cornerRadius,
    double? borderAlpha,
    double? bodyBorderAlpha,
    double? bodyCornerRadius,
    Duration? chevronDuration,
    double? leadingIconSize,
    double? leadingBackgroundAlpha,
    double? countCornerRadius,
  }) {
    return ZCollapsibleSectionSpec(
      expandedElevation: expandedElevation ?? this.expandedElevation,
      collapsedElevation: collapsedElevation ?? this.collapsedElevation,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      borderAlpha: borderAlpha ?? this.borderAlpha,
      bodyBorderAlpha: bodyBorderAlpha ?? this.bodyBorderAlpha,
      bodyCornerRadius: bodyCornerRadius ?? this.bodyCornerRadius,
      chevronDuration: chevronDuration ?? this.chevronDuration,
      leadingIconSize: leadingIconSize ?? this.leadingIconSize,
      leadingBackgroundAlpha:
          leadingBackgroundAlpha ?? this.leadingBackgroundAlpha,
      countCornerRadius: countCornerRadius ?? this.countCornerRadius,
    );
  }

  /// Une spec où [other] a **priorité** sur moi, champ par champ.
  ///
  /// `null` des deux côtés reste `null` : la fusion ne matérialise jamais une
  /// valeur de référence, elle laisse la chaîne se poursuivre.
  ZCollapsibleSectionSpec merge(ZCollapsibleSectionSpec? other) {
    if (other == null) return this;
    return ZCollapsibleSectionSpec(
      expandedElevation: other.expandedElevation ?? expandedElevation,
      collapsedElevation: other.collapsedElevation ?? collapsedElevation,
      cornerRadius: other.cornerRadius ?? cornerRadius,
      borderAlpha: other.borderAlpha ?? borderAlpha,
      bodyBorderAlpha: other.bodyBorderAlpha ?? bodyBorderAlpha,
      bodyCornerRadius: other.bodyCornerRadius ?? bodyCornerRadius,
      chevronDuration: other.chevronDuration ?? chevronDuration,
      leadingIconSize: other.leadingIconSize ?? leadingIconSize,
      leadingBackgroundAlpha:
          other.leadingBackgroundAlpha ?? leadingBackgroundAlpha,
      countCornerRadius: other.countCornerRadius ?? countCornerRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZCollapsibleSectionSpec &&
        other.expandedElevation == expandedElevation &&
        other.collapsedElevation == collapsedElevation &&
        other.cornerRadius == cornerRadius &&
        other.borderAlpha == borderAlpha &&
        other.bodyBorderAlpha == bodyBorderAlpha &&
        other.bodyCornerRadius == bodyCornerRadius &&
        other.chevronDuration == chevronDuration &&
        other.leadingIconSize == leadingIconSize &&
        other.leadingBackgroundAlpha == leadingBackgroundAlpha &&
        other.countCornerRadius == countCornerRadius;
  }

  @override
  int get hashCode => Object.hash(
        expandedElevation,
        collapsedElevation,
        cornerRadius,
        borderAlpha,
        bodyBorderAlpha,
        bodyCornerRadius,
        chevronDuration,
        leadingIconSize,
        leadingBackgroundAlpha,
        countCornerRadius,
      );
}
