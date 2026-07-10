/// Résultat **neutre** d'une sauvegarde de fichier (`ZFileSaver`).
///
/// origine: E11b-3 (Axe B). Type partagé par la façade et les implémentations
/// conditionnelles (io/web/stub) — extrait dans son propre fichier pour éviter
/// tout cycle d'import facade↔impl. Purement local : AUCUN symbole `dart:io`/
/// `package:web`/Syncfusion, aucun secret, aucune requête réseau (AD-12).
library;

/// Résultat immuable d'un `ZFileSaver.save` : nom du fichier, chemin écrit (io)
/// ou identifiant de téléchargement (web), et indicateur de succès.
class ZFileSaveResult {
  /// Construit un résultat de sauvegarde.
  const ZFileSaveResult({
    required this.fileName,
    required this.success,
    this.path,
  });

  /// Nom de fichier demandé (ex. `export.pdf`).
  final String fileName;

  /// Chemin absolu écrit sur disque (io) ; `null` sur le web (téléchargement
  /// navigateur, pas de chemin filesystem) ou en cas d'échec.
  final String? path;

  /// `true` si l'écriture/le déclenchement du téléchargement a réussi.
  final bool success;
}
