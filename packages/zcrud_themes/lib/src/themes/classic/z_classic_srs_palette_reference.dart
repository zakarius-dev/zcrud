/// **Unique** fichier de référence COULEUR de la famille « paliers SRS » du
/// thème Classic.
///
/// ## Ce que ce fichier est
///
/// Les cinq paliers de notation SM-2 du thème Classic — couleur de fond,
/// premier plan lisible, glyphe — sous forme de littéraux hexadécimaux. C'est
/// le seul endroit de la famille où ces littéraux ont le droit d'exister
/// (invariant FR-26) : partout ailleurs on passe par une CLÉ
/// ([ZClassicSrsPaletteReference.colorKeyFor]) résolue par le seam
/// `ZcrudScope.colorKeyResolver`.
///
/// ## Ce que ce fichier n'est pas
///
/// Ce n'est pas un défaut du socle. Rien ici n'est peint tant qu'un hôte n'a
/// pas explicitement adopté le thème Classic : sans lui, le socle continue de
/// dériver ses crans de `passThreshold` et du `ColorScheme` courant.
///
/// ## Le premier plan et la lisibilité sont MESURÉS, jamais décrétés
///
/// Chaque palier porte :
/// * un [ZClassicSrsStep.onColor] dont le contraste sur [ZClassicSrsStep.color]
///   atteint `kZTextMinContrast` (4.5:1, WCAG §1.4.3) — c'est du texte ;
/// * une [ZClassicSrsStep.color] dont le contraste atteint
///   `kZNonTextMinContrast` (3.0:1, §1.4.11) sur les **deux** fonds du thème
///   ([ZClassicSurfaceReference.lightBackground] et `darkBackground`) — un cran
///   de notation est un élément d'interface, il doit se voir.
///
/// Une garde recalcule ces deux mesures et rougit si une valeur d'ici cesse de
/// les satisfaire ; elle ne lit pas ce fichier pour se donner raison, elle
/// porte sa propre table figée.
library;

import 'package:flutter/material.dart';

// Les couleurs de palier ne sont pas dérivables d'un `ColorScheme` : Material 3
// n'a ni rôle « réussite » ni rôle « échec partiel », et les inventer par
// dérivation donnerait cinq teintes indiscernables. Elles entrent donc comme
// valeurs de référence auditées — exception FR-26 encadrée, cf. dartdoc de tête.

/// Un palier de notation du thème Classic : sa qualité SM-2, son nom stable,
/// ses deux couleurs et son glyphe.
///
/// Ne porte **aucun libellé** : le texte affiché reste à la charge de l'hôte,
/// qui le résout depuis la clé rendue par
/// [ZClassicSrsPaletteReference.labelKeyFor].
@immutable
class ZClassicSrsStep {
  /// Crée un palier. Tous les champs font partie du contrat public.
  const ZClassicSrsStep({
    required this.quality,
    required this.name,
    required this.color,
    required this.onColor,
    required this.icon,
  });

  /// Qualité SM-2 du palier (1 à 5, croissante).
  final int quality;

  /// Nom stable et non traduit du palier (`fail`, `hard`, `good`, `easy`,
  /// `perfect`). C'est le suffixe des clés de couleur et de libellé : il ne
  /// change jamais, contrairement au texte affiché.
  final String name;

  /// Fond du cran.
  final Color color;

  /// Premier plan lisible sur [color] (contraste mesuré ≥ 4.5:1).
  final Color onColor;

  /// Glyphe du cran.
  final IconData icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZClassicSrsStep &&
          quality == other.quality &&
          name == other.name &&
          color == other.color &&
          onColor == other.onColor &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(quality, name, color, onColor, icon);

  @override
  String toString() => 'ZClassicSrsStep($quality, $name)';
}

/// Noir opaque — premier plan RETENU PAR MESURE sur les cinq paliers (le blanc
/// perd sur chacun d'eux).
const Color _kOn = Color(0xFF000000);

/// Les cinq paliers de notation du thème Classic, point d'audit unique.
abstract final class ZClassicSrsPaletteReference {
  /// Préfixe des clés de couleur des paliers (`zcrud.classic.srs.<name>`).
  static const String colorKeyPrefix = 'zcrud.classic.srs.';

  /// Préfixe des clés de libellé l10n des paliers.
  static const String labelKeyPrefix = 'zcrud.srs.quality.classic.';

  /// Préfixe des clés d'aperçu d'intervalle des paliers.
  static const String previewKeyPrefix = 'zcrud.srs.preview.classic.';

  // Relevé sur le code de référence : les cinq crans y sont déclarés en un seul
  // point, avec leur glyphe et leur teinte Material.
  //   `lib/src/domain/models/flashcard_repetition_info.dart:116` → fail
  //   `…:117-118` → hard, `…:119` → good, `…:120-121` → easy, `…:122` → perfect
  // Les teintes d'origine sont les constantes Material `Colors.red`
  // (#F44336), `Colors.orange` (#FF9800), `Colors.blue` (#2196F3),
  // `Colors.teal` (#009688) et `Colors.green` (#4CAF50).
  //
  // ⚠️ TROIS d'entre elles ne tiennent PAS le plancher 3.0:1 sur le fond CLAIR
  // du thème (#F8FAFC) — un cran de notation invisible sur sa page est un
  // défaut d'accessibilité, pas une identité visuelle. Corrigées ici au
  // minimum nécessaire (nuance Material voisine, même famille chromatique) :
  //   orange #FF9800 → #E65100 (Orange 900) : 2.06:1 → 3.62:1
  //   blue   #2196F3 → #1E88E5 (Blue 600)   : 2.99:1 → 3.52:1
  //   green  #4CAF50 → #388E3C (Green 700)  : 2.66:1 → 3.93:1
  // `red` (3.52:1) et `teal` (3.51:1) passent tels quels et sont repris à
  // l'octet. Aucun échec n'est masqué : la garde recalcule les cinq ratios.

  /// Palier 1 — échec.
  static const ZClassicSrsStep fail = ZClassicSrsStep(
    quality: 1,
    name: 'fail',
    color: Color(0xFFF44336),
    onColor: _kOn,
    icon: Icons.close,
  );

  /// Palier 2 — difficile.
  static const ZClassicSrsStep hard = ZClassicSrsStep(
    quality: 2,
    name: 'hard',
    color: Color(0xFFE65100),
    onColor: _kOn,
    icon: Icons.sentiment_very_dissatisfied,
  );

  /// Palier 3 — correct.
  static const ZClassicSrsStep good = ZClassicSrsStep(
    quality: 3,
    name: 'good',
    color: Color(0xFF1E88E5),
    onColor: _kOn,
    icon: Icons.sentiment_satisfied,
  );

  /// Palier 4 — facile.
  static const ZClassicSrsStep easy = ZClassicSrsStep(
    quality: 4,
    name: 'easy',
    color: Color(0xFF009688),
    onColor: _kOn,
    icon: Icons.sentiment_very_satisfied,
  );

  /// Palier 5 — très facile.
  static const ZClassicSrsStep perfect = ZClassicSrsStep(
    quality: 5,
    name: 'perfect',
    color: Color(0xFF388E3C),
    onColor: _kOn,
    icon: Icons.check,
  );

  /// Les cinq paliers, dans l'ordre croissant de qualité (1 → 5).
  static const List<ZClassicSrsStep> steps = <ZClassicSrsStep>[
    fail,
    hard,
    good,
    easy,
    perfect,
  ];

  /// Palier de qualité [quality], ou `null` hors de l'échelle 1..5.
  ///
  /// Total et défensif (invariant AD-10) : ne lève jamais, quelle que soit la
  /// valeur reçue.
  static ZClassicSrsStep? byQuality(int quality) {
    for (final step in steps) {
      if (step.quality == quality) return step;
    }
    return null;
  }

  /// Clé de couleur du palier [quality] (`zcrud.classic.srs.<name>`).
  ///
  /// Hors échelle, rend la clé du palier le plus proche par bornage — la
  /// chaîne reste totale et aucun cran ne se retrouve sans couleur.
  static String colorKeyFor(int quality) =>
      '$colorKeyPrefix${_clamped(quality).name}';

  /// Clé de libellé l10n du palier [quality]. Rend une CLÉ, jamais un texte.
  static String labelKeyFor(int quality) =>
      '$labelKeyPrefix${_clamped(quality).name}';

  /// Clé d'aperçu d'intervalle du palier [quality]. Rend une CLÉ, jamais un
  /// texte : l'échéance annoncée sous un cran est une phrase, donc de la
  /// traduction, donc du ressort de l'hôte.
  static String previewKeyFor(int quality) =>
      '$previewKeyPrefix${_clamped(quality).name}';

  /// Palier de [ZClassicSrsStep.name] égal à [name], ou `null`.
  static ZClassicSrsStep? byName(String name) {
    for (final step in steps) {
      if (step.name == name) return step;
    }
    return null;
  }

  static ZClassicSrsStep _clamped(int quality) =>
      byQuality(quality.clamp(steps.first.quality, steps.last.quality)) ??
      steps.first;
}
