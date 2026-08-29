/// Présets **copiables** de teinte par type de champ — pur-DONNÉES.
///
/// ## Contrat
///
/// Ces présets sont des constantes offertes aux applications ; le socle ne les
/// lit à AUCUN endroit. Une application qui n'injecte pas de résolveur rend la
/// décoration de ses champs à l'identique — les présets n'y changent rien.
///
/// Pour les appliquer, l'application les recopie (ou les référence) dans SON
/// résolveur de dégradé, branché par `ZcrudScope.gradientResolver`, et
/// répondant aux clés `zFieldTypeTintKey` ; elle est libre d'en surcharger
/// tout ou partie.
///
/// ## Forme
///
/// Couleurs en `int` ARGB 32 bits — des **données**, jamais un type Flutter :
/// le domaine reste pur-Dart (invariant AD-1). Les clés sont les noms des
/// valeurs d'`EditionFieldType` (`'text'`, `'number'`, `'dateTime'`, …) ; une
/// clé absente signifie « pas de préset pour ce type », et l'appelant décide
/// alors de son repli.
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
///
/// Toute couleur remise au socle est normalisée pour le contraste avant
/// d'être peinte (`zReadableTintOn`), en thème clair comme sombre.
///
/// ## À ne pas confondre
///
/// La **palette signature** (`ZSignaturePaletteReference`) est une famille
/// distincte : elle indexe une identité libre (titre de section, dossier), et
/// elle, le socle la lit par défaut. Ces présets-ci restent strictement
/// opt-in.
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

/// Présets **copiables** de teinte par type de champ. Le socle ne les lit pas.
abstract final class ZFieldTintPresets {
  /// Palette de départ « classique » : une teinte par grande famille de champ.
  ///
  /// À copier ou surcharger dans le résolveur de l'hôte ; aucun site du socle
  /// ne l'applique.
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
