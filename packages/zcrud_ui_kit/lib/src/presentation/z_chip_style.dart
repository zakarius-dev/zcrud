/// Style transversal des puces de choix.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_page_shell_reference.dart';

/// Style résolu d'une puce de choix : forme, teinte de sélection, premier plan
/// du libellé sélectionné, présence de la coche.
///
/// ## Ce que ce style fixe, et ce qu'il laisse au thème
///
/// Il fixe **quatre** propriétés — celles qui séparent une puce de choix de la
/// capsule Material 3 par défaut. Tout le reste (typographie, fond non
/// sélectionné, bordure, densité, états de survol et de focus) reste au thème
/// de l'hôte : ce style **complète** un `ChipThemeData`, il ne le remplace pas.
///
/// ## D'où vient la teinte de sélection
///
/// Par ordre de priorité **paramètre > jeton `ZcrudTheme.signaturePalette` >
/// référence auditée**, ce dernier maillon n'étant lu que sous le profil
/// `ZReferenceProfile.legacy`. Sous `ZReferenceProfile.neutral`, la teinte de
/// sélection est le rôle `ColorScheme.primary` — donc entièrement gouvernée
/// par le thème de l'hôte.
///
/// La couleur du libellé sélectionné est **mesurée** contre cette teinte
/// (WCAG 2.2), jamais décrétée : elle change avec la teinte.
///
/// ## Comment s'en servir
///
/// ```dart
/// ChipTheme(
///   data: zChipThemeFor(context),
///   child: ChoiceChip(label: Text('Actif'), selected: actif, onSelected: …),
/// )
/// ```
///
/// Pour un rendu par entité (une couleur par dossier, par matière…), passer
/// `signatureKey` : l'identité indexe la palette exactement comme le fait le
/// chrome de page pour la même entité.
@immutable
class ZChoiceChipStyle {
  /// Construit un style **entièrement déclaré** (aucune résolution).
  const ZChoiceChipStyle({
    required this.shape,
    required this.selectedColor,
    required this.selectedLabelColor,
    required this.showCheckmark,
  });

  /// Résout le style pour [context].
  ///
  /// Chaque paramètre non nul **prime** sur la chaîne de résolution ; nul, il
  /// laisse jouer jeton puis référence.
  ///
  /// [signatureKey] désigne l'entité qui donne sa couleur à la puce ; nul ou
  /// vide, la puce prend la teinte de **tête** de la palette.
  factory ZChoiceChipStyle.resolve(
    BuildContext context, {
    String? signatureKey,
    OutlinedBorder? shape,
    Color? selectedColor,
    Color? selectedLabelColor,
    bool? showCheckmark,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ZGradientSpec> palette =
        ZcrudTheme.of(context).signaturePalette ??
        ZSignaturePaletteReference.gradients;
    final ZGradientSpec? spec = (signatureKey == null || signatureKey.isEmpty)
        ? (palette.isEmpty ? null : palette.first)
        : zSignatureGradientFor(signatureKey, palette: palette);
    final List<Color> stops = spec?.gradient.colors ?? const <Color>[];
    // Dernier maillon: la référence ne joue que sous `legacy`; sous `neutral`
    // la sélection retombe sur un rôle du ColorScheme de l'hôte.
    final Color selected =
        selectedColor ??
        (stops.isEmpty
            ? scheme.primary
            : zLegacyOr<Color>(context, stops.first, scheme.primary)!);
    return ZChoiceChipStyle(
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ZPageShellReference.chipCornerRadius,
            ),
          ),
      selectedColor: selected,
      selectedLabelColor:
          selectedLabelColor ?? _zForegroundOn(selected, scheme),
      showCheckmark: showCheckmark ?? ZPageShellReference.chipShowCheckmark,
    );
  }

  /// Forme de la puce.
  final OutlinedBorder shape;

  /// Fond de la puce **sélectionnée**.
  final Color selectedColor;

  /// Couleur du libellé de la puce sélectionnée, mesurée contre
  /// [selectedColor].
  final Color selectedLabelColor;

  /// La coche Material de sélection est-elle affichée ?
  final bool showCheckmark;

  /// Projette ce style en `ChipThemeData`, à poser dans un `ChipTheme`.
  ///
  /// Seuls les quatre créneaux décrits par ce style sont renseignés : un
  /// `ChipThemeData` ainsi construit **fusionne** sur celui du thème de
  /// l'hôte, il ne l'écrase pas.
  ChipThemeData toChipThemeData() => ChipThemeData(
    shape: shape,
    selectedColor: selectedColor,
    secondarySelectedColor: selectedColor,
    showCheckmark: showCheckmark,
    secondaryLabelStyle: TextStyle(color: selectedLabelColor),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChoiceChipStyle &&
          shape == other.shape &&
          selectedColor == other.selectedColor &&
          selectedLabelColor == other.selectedLabelColor &&
          showCheckmark == other.showCheckmark;

  @override
  int get hashCode =>
      Object.hash(shape, selectedColor, selectedLabelColor, showCheckmark);
}

/// Premier plan lisible sur [background] : le candidat achromatique qui
/// contraste le plus, ou le rôle `onPrimary` du thème s'il tient déjà le
/// plancher §1.4.3 AA (4.5:1).
Color _zForegroundOn(Color background, ColorScheme scheme) =>
    zContrastRatio(scheme.onPrimary, background) >= kZTextMinContrast
    ? scheme.onPrimary
    : zSignatureForegroundFor(<Color>[background, background]);

/// `ChipThemeData` prêt à poser, résolu par [ZChoiceChipStyle.resolve].
///
/// Raccourci de `ZChoiceChipStyle.resolve(context, …).toChipThemeData()` —
/// même chaîne de priorité, mêmes garanties.
ChipThemeData zChipThemeFor(BuildContext context, {String? signatureKey}) =>
    ZChoiceChipStyle.resolve(
      context,
      signatureKey: signatureKey,
    ).toChipThemeData();
