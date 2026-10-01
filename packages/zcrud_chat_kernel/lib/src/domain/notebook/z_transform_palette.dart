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
    this.lockedWhen,
  });

  /// Clé d'artefact demandée au port de génération.
  final String artifactKey;

  /// Libellé affiché, fourni par l'hôte.
  final String label;

  /// `true` si l'entrée est offerte au [level] courant.
  final bool Function(String? level) allows;

  /// `true` si l'entrée reste visible mais ne lance pas de génération.
  ///
  /// Un niveau refusé n'est pas retiré de la barre : l'hôte affiche le
  /// verrou et répond au geste par [ZTransformPaletteBar] `onLocked`.
  /// `null` : jamais verrouillée.
  final bool Function(String? level)? lockedWhen;

  /// Prédicat par défaut : tout niveau, y compris l'absence de niveau.
  static bool allowAnyLevel(String? level) => true;

  /// Verrouillée pour [level]. Un prédicat absent ne verrouille rien.
  bool lockedFor(String? level) => lockedWhen?.call(level) ?? false;
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

  /// Entrées affichées : autorisées, plus celles seulement verrouillées.
  ///
  /// Une entrée verrouillée reste dans la liste. [visibleFor] continue de
  /// ne rendre que les entrées actionnables.
  List<ZTransformPaletteEntry> offeredFor(String? level) =>
      <ZTransformPaletteEntry>[
        for (final ZTransformPaletteEntry entry in entries)
          if (entry.allows(level) || entry.lockedFor(level)) entry,
      ];
}
