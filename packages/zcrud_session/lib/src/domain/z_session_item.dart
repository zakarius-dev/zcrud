/// Élément NEUTRE d'une file de session (`ZSessionItem`) — ES-4.2, D7.
///
/// Le moteur de session (`ZStudySessionEngine`) est **générique sur l'identité
/// de carte** (anti-inertie AD-1) : il ne tire **aucun** widget flashcard et ne
/// connaît le « type » d'une carte qu'au travers d'un [typeKey] **opaque**. Un
/// item ne porte que ce qu'il faut pour (1) invoquer le seam d'écriture SRS
/// (`reviewCard(flashcardId, folderId, …)`) et (2) ordonner la file.
///
/// Pur-Dart, immuable, value-object (`==`/`hashCode`). Aucune I/O, aucune
/// horloge, aucune (dé)sérialisation (état de session runtime NON persisté —
/// pas de `@ZcrudModel`, AC10).
library;

/// Un candidat de la file de session : couple d'identité neutre
/// `{flashcardId, folderId}` + [typeKey] opaque optionnel.
class ZSessionItem {
  /// Construit un item de session immuable.
  const ZSessionItem({
    required this.flashcardId,
    required this.folderId,
    this.typeKey,
  });

  /// Identité opaque de la carte (relayée telle quelle au seam `reviewCard`).
  final String flashcardId;

  /// Dossier logique de la carte (relayé au seam `reviewCard`, canal SRS).
  final String folderId;

  /// Clé de type **opaque** (ex. `"openQuestion"`) — le moteur ne l'interprète
  /// jamais ; simple donnée de présentation pour un consommateur.
  final String? typeKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSessionItem &&
          runtimeType == other.runtimeType &&
          flashcardId == other.flashcardId &&
          folderId == other.folderId &&
          typeKey == other.typeKey;

  @override
  int get hashCode => Object.hash(runtimeType, flashcardId, folderId, typeKey);

  @override
  String toString() =>
      'ZSessionItem(flashcardId: $flashcardId, folderId: $folderId, '
      'typeKey: $typeKey)';
}
