/// Cycle de vie d'un document d'étude.
///
/// Une application consommatrice peut porter un cycle de vie plus riche
/// (par exemple des états de conversion ou d'indexation IA intermédiaires) :
/// c'est un concern app-spécifique, pas un schéma partagé (invariant AD-4 —
/// il passe par `extra`/`ZExtension`). Tout mapping d'un cycle de vie étendu
/// vers ce statut canonique appartient à l'adaptateur, jamais au domaine.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive.
library;

/// État du cycle de vie d'un [ZStudyDocument] (upload → validation → prêt).
///
/// **L'ordre de déclaration est normatif** : le générateur zcrud décode un
/// enum par nom et, pour un champ non-nullable sans valeur par défaut, son
/// repli défensif (invariant AD-10) est la première constante déclarée.
/// Réordonner cet enum changerait silencieusement le comportement défensif
/// de `ZStudyDocument.status`.
///
/// Pourquoi [uploading] en premier (les replis possibles ne sont pas
/// équivalents) :
/// - [ready] mentirait sur la disponibilité d'un document non prêt
///   (ouverture cassée côté viewer) ;
/// - [rejected] est un état transitoire en principe jamais persisté (la
///   carte optimiste est purgée) ⇒ repli destructeur d'affichage ;
/// - [uploading] affiche « Traitement… » : ne détruit rien, ne ment sur
///   rien.
enum ZDocumentStatus {
  /// Envoi des octets en cours — valeur de repli défensive (première
  /// constante déclarée).
  uploading,

  /// Validation / OCR côté backend en cours.
  validating,

  /// Document prêt et consultable.
  ready,

  /// Rejeté (échec de validation) — état transitoire, en principe jamais
  /// persisté (la carte optimiste est purgée côté application).
  rejected;

  /// `true` tant que le document est en cours de traitement
  /// ([uploading]/[validating]) — pilote l'affichage « Traitement… ».
  bool get isProcessing =>
      this == ZDocumentStatus.uploading || this == ZDocumentStatus.validating;
}
