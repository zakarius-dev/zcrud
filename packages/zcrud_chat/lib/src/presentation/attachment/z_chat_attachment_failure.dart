/// Échec typé d'une opération sur une pièce jointe.
///
/// Le contrat de retour est `ZResult<T>` (invariant AD-11) : l'annulation par
/// l'utilisateur est une valeur (`null` en `Right`), jamais confondue avec une
/// absence d'erreur ou avec un échec.
///
/// ## Ce que le client décide, et ce qu'il ne décide pas
///
/// Un backend applique typiquement antivirus, contrôle d'accès par palier et
/// quota d'usage multimodal côté serveur. Ce paquet ne les reproduit pas : il
/// n'a ni le fichier de signatures, ni le palier de l'utilisateur, ni le
/// compteur de quota, et une seconde implémentation divergerait de la
/// première au premier changement de règle serveur.
///
/// La partition est donc explicite :
/// * [ZChatAttachmentRejection.maxFilesReached], [unsupportedType],
///   [fileTooLarge] — bornes locales et purement ergonomiques (éviter un
///   aller-retour réseau certain d'échouer). Elles ne sont pas des contrôles
///   de sécurité et ne prétendent pas l'être.
/// * [ZChatAttachmentRejection.rejectedByServer] — le serveur a refusé. Le
///   client transporte son verdict ([ZChatAttachmentFailure.cause]) sans
///   l'interpréter : exposer ce qui échoue, sans décider à la place de
///   l'autorité qui a émis le refus.
library;

import 'package:zcrud_core/domain.dart';

/// Motif du rejet d'une pièce jointe — famille fermée : elle ne traverse
/// aucune frontière de sérialisation, l'invariant AD-4 ne s'y applique pas.
enum ZChatAttachmentRejection {
  /// Plafond local du nombre de fichiers atteint.
  maxFilesReached,

  /// Type MIME hors de la liste locale d'ergonomie.
  unsupportedType,

  /// Fichier au-delà de la borne locale de taille.
  fileTooLarge,

  /// Le sélecteur de la plateforme a échoué (permission refusée, caméra
  /// indisponible, fichier illisible…).
  pickFailed,

  /// Le téléversement a échoué pour une raison de transport.
  uploadFailed,

  /// Le serveur a refusé (antivirus, contrôle d'accès, quota multimodal…).
  /// Le client n'a rien décidé : il relaie.
  rejectedByServer,
}

/// Échec typé d'une opération de pièce jointe.
///
/// Porte [reason] (ce qui a échoué), le [fileName] concerné quand il est connu,
/// et [cause] — la `ZFailure` d'origine lorsque le refus vient d'ailleurs
/// (serveur, transport). [cause] n'est jamais interprétée : elle est
/// **transportée**, pour que l'hôte affiche le verdict de l'autorité et non une
/// paraphrase.
class ZChatAttachmentFailure extends ZFailure {
  /// Construit un échec de pièce jointe.
  const ZChatAttachmentFailure(
    super.message, {
    required this.reason,
    this.fileName,
    this.cause,
  });

  /// Motif du rejet.
  final ZChatAttachmentRejection reason;

  /// Nom du fichier concerné, si connu.
  final String? fileName;

  /// Échec d'origine relayé verbatim (serveur/transport), ou `null`.
  final ZFailure? cause;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatAttachmentFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          reason == other.reason &&
          fileName == other.fileName &&
          cause == other.cause;

  @override
  int get hashCode => Object.hash(runtimeType, message, reason, fileName, cause);

  @override
  String toString() =>
      'ZChatAttachmentFailure($reason, fileName: $fileName, message: $message)';
}
