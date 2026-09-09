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
/// Deux de ces quatre propriétés — la **forme** et la présence de la **coche**
/// — sont réglables à l'échelle de l'application, par ordre **paramètre >
/// jeton (`ZcrudTheme.choiceChipShape`, `ZcrudTheme.choiceChipShowCheckmark`)
/// > référence**. Elles ne passent pas par `ChipThemeData` : ce style pose sa
/// forme et sa coche explicitement, ce qui prime sur le thème de puces de
/// l'hôte — les jetons sont donc le seul canal app-scale de ces deux-là, et ne
/// gouvernent aucune autre puce de l'application.
///
/// ## D'où vient la teinte de sélection
///
/// Par ordre de priorité **paramètre > résolveur `ZcrudScope.gradientResolver`
/// > jeton `ZcrudTheme.signaturePalette` > référence auditée** — la chaîne de
/// `zResolveGradient`, celle de tous les autres dégradés du socle. Seul le
/// dernier maillon est arbitré par le profil : il n'est lu que sous
/// `ZReferenceProfile.legacy`, opt-in de l'hôte. Sous
/// `ZReferenceProfile.neutral` — **le défaut** —, la teinte de sélection est le
/// rôle `ColorScheme.primary`, donc entièrement gouvernée par le thème de
/// l'hôte.
///
/// Le résolveur est interrogé sous la clé `zcrud.signature.<identité>` ; il n'y
/// a d'identité que si [ZChoiceChipStyle.resolve] en reçoit une. Sans identité,
/// la puce prend la teinte de tête de la palette — jeton d'abord, référence
/// ensuite.
///
/// Un jeton `signaturePalette` **posé** est une décision de l'hôte, pas une
/// référence : il s'applique dans les deux profils.
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
  /// laisse jouer jeton puis référence — [shape] et [showCheckmark] compris,
  /// dont les jetons sont `ZcrudTheme.choiceChipShape` et
  /// `ZcrudTheme.choiceChipShowCheckmark`.
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
    final ZGradientSpec? spec = _zChipSignature(context, signatureKey);
    final List<Color> stops = spec?.gradient.colors ?? const <Color>[];
    // Rien de résolu ⇒ le rôle `primary` du thème de l'hôte : aucune couleur
    // n'est écrite ici, et la puce reste celle du SDK habillé par ce thème.
    final Color selected =
        selectedColor ?? (stops.isEmpty ? scheme.primary : stops.first);
    return ZChoiceChipStyle(
      shape:
          shape ??
          ZcrudTheme.of(context).choiceChipShape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ZPageShellReference.chipCornerRadius,
            ),
          ),
      selectedColor: selected,
      selectedLabelColor:
          selectedLabelColor ?? _zForegroundOn(selected, scheme),
      showCheckmark:
          showCheckmark ??
          ZcrudTheme.of(context).choiceChipShowCheckmark ??
          ZPageShellReference.chipShowCheckmark,
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

/// Dégradé de signature d'une puce, par ordre **identité déclarée > tête de
/// palette**.
///
/// Une identité passe par la couture `zResolveGradient` du socle, comme tout
/// autre dégradé : elle consulte le résolveur `ZcrudScope.gradientResolver`,
/// puis le jeton `ZcrudTheme.signaturePalette`, puis — sous le profil
/// `legacy` seulement — la palette de référence auditée, en respectant la
/// stratégie d'index déclarée par le thème. Indexer la palette à la main
/// (`zSignatureGradientFor`) court-circuiterait le résolveur : l'application
/// ne pourrait plus teinter la puce, seulement l'éteindre en basculant le
/// profil.
///
/// Sans identité, il n'existe **aucune clé** à soumettre au résolveur — la
/// couture rend `null` pour une identité vide. La puce prend alors la teinte
/// de TÊTE de la palette, dont le levier de l'hôte est le jeton lui-même,
/// consulté ici avant la référence. Le profil n'arbitre que ce dernier
/// maillon : le rejouer par-dessus la couture effacerait sous `neutral` une
/// palette délibérément posée.
ZGradientSpec? _zChipSignature(BuildContext context, String? signatureKey) {
  if (signatureKey != null && signatureKey.isNotEmpty) {
    return zResolveGradient(context, zSignatureKey(signatureKey));
  }
  final List<ZGradientSpec>? palette =
      ZcrudTheme.of(context).signaturePalette ??
      zLegacyOr<List<ZGradientSpec>>(
        context,
        ZSignaturePaletteReference.gradients,
      );
  if (palette == null || palette.isEmpty) return null;
  return palette.first;
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
