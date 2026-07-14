/// Cycle de vie d'un document d'étude (ES-2.1, FR-S4).
///
/// origine: lex_core (module « Étude ») — `enums/document_status.dart`
/// (canonique retenu, D1). IFFD (`FolderDocumentStatus`) en porte **6**
/// (`uploading, uploaded, converting, converted, embedding, embedded`) : ce
/// cycle de vie **conversion / embedding IA** est un concern **app-spécifique**,
/// pas un schéma partagé (AD-4 : il passe par `extra`/`ZExtension`). Le repli
/// 6 → 4 est du **mapping legacy** et appartient à l'**adapter**
/// (`zcrud_firestore`, ES-3.5/ES-11.2 — AD-27), jamais au domaine. Dette
/// **DW-ES21-1**, épinglée par un test (cf. `z_document_status_test.dart`).
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive (NFR-S3/SM-S5).
library;

/// État du cycle de vie d'un [ZStudyDocument] (upload → validation → prêt).
///
/// 🔴 **L'ORDRE DE DÉCLARATION EST NORMATIF** (D5, piège écrit nulle part
/// ailleurs) : le générateur `zcrud` décode un enum **par NOM**
/// (`_$enumFromName`) et, pour un champ **non-nullable sans `defaultValue`**,
/// son repli défensif (AD-10) est **`T.values.first`**. **La première constante
/// déclarée EST donc le défaut d'une valeur absente / `null` / non-`String` /
/// inconnue.** Réordonner cet enum changerait **silencieusement** le
/// comportement défensif de `ZStudyDocument.status`.
///
/// **Pourquoi [uploading] en premier** (les 3 replis possibles ne sont **pas**
/// équivalents) :
/// - [ready] **mentirait** sur la disponibilité d'un document non prêt (ouverture
///   cassée côté viewer) ;
/// - [rejected] est documenté par lex comme un état *transitoire jamais persisté*
///   (la carte optimiste est **purgée**) ⇒ repli **destructeur d'affichage** ;
/// - [uploading] affiche « Traitement… » : **ne détruit rien, ne ment sur rien**.
///   C'est aussi le défaut de lex (`DocumentStatus.fromJson`).
enum ZDocumentStatus {
  /// Envoi des octets en cours (**défaut défensif** — 1ʳᵉ constante, D5).
  uploading,

  /// Validation / OCR côté backend en cours.
  validating,

  /// Document prêt et consultable.
  ready,

  /// Rejeté (échec de validation) — état **transitoire**, en principe jamais
  /// persisté (la carte optimiste est purgée côté app).
  rejected;

  /// `true` tant que le document est en cours de traitement
  /// ([uploading]/[validating]) — pilote l'affichage « Traitement… ».
  bool get isProcessing =>
      this == ZDocumentStatus.uploading || this == ZDocumentStatus.validating;
}
