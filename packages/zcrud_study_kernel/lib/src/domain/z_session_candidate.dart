/// Port neutre `ZSessionCandidate` — candidat filtrable par une session
/// d'étude.
///
/// Contrat minimal et pur-Dart que le sélecteur de session
/// [ZStudySessionSelector] applique à n'importe quel élément d'étude
/// (flashcard, note, mindmap…) sans dépendre d'un satellite concret. C'est
/// la clé de voûte du découplage acyclique (invariant AD-1) : le kernel
/// porte la logique de sélection tout en restant ignorant des concepts
/// spécifiques à un satellite (ex. `ZFlashcardType`).
///
/// Chaque satellite fait implémenter ce port par son entité, par exemple
/// `ZFlashcard implements ZSessionCandidate` avec `String get typeKey =>
/// type.name;`. L'ergonomie typée (ex. `ZFlashcardType`) est restituée côté
/// satellite (extension/adaptateur), jamais dans le kernel.
///
/// Les getters sont volontairement neutres (`String`/`List<String>`) pour
/// coller aux clés de rattachement/filtrage persistées (round-trip,
/// invariant AD-10) :
/// - [folderId]/[subFolderId] : rattachement inverse 2 niveaux (`null` =
///   aucun) ;
/// - [tagIds] : étiquettes (jamais `null` — liste vide si aucune) ;
/// - [typeKey] : identité de type opaque (nom camelCase, ex.
///   `"multipleChoice"`), comparée telle quelle au filtre `types` de la
///   config.
library;

/// Candidat neutre à la sélection de session (implémenté par les entités
/// d'étude des satellites).
abstract interface class ZSessionCandidate {
  /// Dossier de rattachement (`null` = non rattaché).
  String? get folderId;

  /// Sous-dossier de rattachement (hiérarchie 2 niveaux ; `null` = aucun).
  String? get subFolderId;

  /// Étiquettes filtrantes (jamais `null` — liste vide si aucune).
  List<String> get tagIds;

  /// Identité de type opaque (nom camelCase, ex. `"multipleChoice"`),
  /// comparée au filtre `types` (`List<String>`) de [ZStudySessionConfig].
  String get typeKey;
}
