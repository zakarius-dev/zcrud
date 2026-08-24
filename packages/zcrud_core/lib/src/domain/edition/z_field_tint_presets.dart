/// Présets de **teinte par type de champ** — pur-DONNÉES, jamais un défaut.
///
/// ## Ce que ce fichier est, et n'est pas
///
/// La décoration d'un champ peut être teintée **par type de champ** (bordure de
/// focus, icônes d'ornement) via la couture de dégradé du scope
/// (`ZcrudScope.gradientResolver`, clé `zFieldTypeTintKey`). Cette teinte est
/// **strictement opt-in** : une application qui n'injecte aucun résolveur rend
/// la décoration à l'identique, au pixel près.
///
/// Ces présets sont des **constantes copiables** offertes aux applications qui
/// veulent partir d'une palette : l'application les recopie (ou les référence)
/// dans SON résolveur, les surcharge à sa guise — le socle, lui, ne les lit
/// **jamais** (aucun site de `lib/` ne les consomme ; une garde le vérifie).
/// C'est ce qui les distingue d'un défaut actif, interdit (invariant FR-26).
///
/// ## Forme
///
/// Couleurs en `int` ARGB 32 bits (**données**, jamais un type Flutter — le
/// domaine reste pur-Dart, invariant AD-1). Clés = noms des valeurs
/// d'`EditionFieldType` (`'text'`, `'number'`, `'dateTime'`, …).
///
/// ```dart
/// ZcrudScope(
///   gradientResolver: (scheme, key) {
///     final preset = ZFieldTintPresets.classic[
///         key.startsWith(zFieldTypeTintKeyPrefix)
///             ? key.substring(zFieldTypeTintKeyPrefix.length)
///             : key];
///     if (preset == null) return null;
///     return ZGradientSpec(
///       gradient: LinearGradient(colors: [Color(preset.start), Color(preset.end)]),
///       onGradient: scheme.onPrimary,
///     );
///   },
///   child: …,
/// )
/// ```
library;

/// Couple de couleurs ARGB d'un préset de teinte (début/fin de dégradé — un
/// accent uni utilise [start] seul).
class ZFieldTintPreset {
  /// Construit un préset `const` (pur-données).
  const ZFieldTintPreset({required this.start, required this.end});

  /// Couleur ARGB de départ du dégradé (aussi l'accent uni).
  final int start;

  /// Couleur ARGB de fin du dégradé.
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFieldTintPreset &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(runtimeType, start, end);
}

/// Présets **copiables** de teinte par type de champ. Jamais lus par le socle.
abstract final class ZFieldTintPresets {
  /// Palette de départ « classique » : une teinte par grande famille de champ.
  ///
  /// Donnée de référence à copier/surcharger dans le résolveur de l'hôte —
  /// **aucun** site du socle ne l'applique. Toute couleur passée au socle est
  /// de toute façon normalisée pour le contraste avant d'être peinte
  /// (`zReadableTintOn`), thème clair comme sombre.
  static const Map<String, ZFieldTintPreset> classic =
      <String, ZFieldTintPreset>{
    'text': ZFieldTintPreset(start: 0xFF667EEA, end: 0xFF764BA2),
    'multiline': ZFieldTintPreset(start: 0xFF667EEA, end: 0xFF764BA2),
    'password': ZFieldTintPreset(start: 0xFF5C6BC0, end: 0xFF3949AB),
    'number': ZFieldTintPreset(start: 0xFF00897B, end: 0xFF00695C),
    'integer': ZFieldTintPreset(start: 0xFF00897B, end: 0xFF00695C),
    'float': ZFieldTintPreset(start: 0xFF00897B, end: 0xFF00695C),
    'dateTime': ZFieldTintPreset(start: 0xFFEF6C00, end: 0xFFD84315),
    'time': ZFieldTintPreset(start: 0xFFEF6C00, end: 0xFFD84315),
    'dateRange': ZFieldTintPreset(start: 0xFFEF6C00, end: 0xFFD84315),
    'boolean': ZFieldTintPreset(start: 0xFF2E7D32, end: 0xFF1B5E20),
    'select': ZFieldTintPreset(start: 0xFF7B1FA2, end: 0xFF4A148C),
    'radio': ZFieldTintPreset(start: 0xFF7B1FA2, end: 0xFF4A148C),
    'checkbox': ZFieldTintPreset(start: 0xFF7B1FA2, end: 0xFF4A148C),
    'relation': ZFieldTintPreset(start: 0xFF1565C0, end: 0xFF0D47A1),
    'file': ZFieldTintPreset(start: 0xFF6D4C41, end: 0xFF4E342E),
  };
}
