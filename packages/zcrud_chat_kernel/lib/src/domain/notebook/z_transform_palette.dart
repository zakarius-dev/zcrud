/// Palette de transformations d'un notebook.
///
/// Chaque entrée est une clé d'artefact, un libellé **déjà résolu par
/// l'hôte** (le socle ne traduit pas ces libellés : ils nomment des
/// produits de l'hôte) et un prédicat d'accès sur le niveau courant.
/// `null` comme niveau signifie « aucun niveau connu ».
library;

/// Une entrée de palette.
class ZTransformPaletteEntry {
  /// Construit une entrée visible pour tout niveau.
  const ZTransformPaletteEntry({
    required this.artifactKey,
    required this.label,
    this.allows = allowAnyLevel,
  });

  /// Clé d'artefact demandée au port de génération.
  final String artifactKey;

  /// Libellé affiché, fourni par l'hôte.
  final String label;

  /// `true` si l'entrée est offerte au [level] courant.
  final bool Function(String? level) allows;

  /// Prédicat par défaut : tout niveau, y compris l'absence de niveau.
  static bool allowAnyLevel(String? level) => true;
}

/// Catalogue ordonné des transformations offertes.
class ZTransformPalette {
  /// Construit une palette.
  const ZTransformPalette(this.entries);

  /// Entrées, dans l'ordre d'affichage.
  final List<ZTransformPaletteEntry> entries;

  /// Entrées dont [ZTransformPaletteEntry.allows] accepte [level].
  List<ZTransformPaletteEntry> visibleFor(String? level) =>
      <ZTransformPaletteEntry>[
        for (final ZTransformPaletteEntry entry in entries)
          if (entry.allows(level)) entry,
      ];
}
