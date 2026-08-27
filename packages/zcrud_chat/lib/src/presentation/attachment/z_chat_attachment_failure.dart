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
/// * [ZChatAttachmentRejection.permissionDenied], [sourceUnavailable],
///   [fileUnreadable] — trois causes de sélection que la PLATEFORME nomme.
///   Elles ne sont jamais devinées : elles arrivent au contrôleur parce
///   qu'un `ZChatAttachmentPicker` les a nommées, et le socle les relaie.
///   Ce qu'il ne sait pas lire retombe sur [ZChatAttachmentRejection.pickFailed].
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

  /// Le sélecteur de la plateforme a échoué, sans cause discernable.
  ///
  /// C'est le **repli** de la famille de sélection : une cause que la
  /// plateforme n'a pas nommée, ou qu'elle a nommée d'une façon que ce socle
  /// ne sait pas lire, retombe ici — sans exception (invariant AD-10). Les
  /// causes nommées ont leurs propres valeurs : [permissionDenied],
  /// [sourceUnavailable], [fileUnreadable].
  pickFailed,

  /// Le téléversement a échoué pour une raison de transport.
  uploadFailed,

  /// Le serveur a refusé (antivirus, contrôle d'accès, quota multimodal…).
  /// Le client n'a rien décidé : il relaie.
  rejectedByServer,

  /// L'utilisateur — ou la plateforme — a **refusé l'accès** à la source.
  ///
  /// Le remède est un réglage système : aucun réessai ne peut aboutir tant
  /// que l'autorisation n'a pas changé. C'est ce qui distingue ce motif de
  /// [sourceUnavailable] et de [fileUnreadable], que le même message
  /// couvrirait à tort.
  permissionDenied,

  /// La source elle-même est **indisponible** : pas d'appareil photo, service
  /// de galerie absent, sélecteur non installé sur la plateforme.
  ///
  /// Rien à autoriser et rien à relire : l'affordance n'a simplement pas de
  /// moteur derrière elle.
  sourceUnavailable,

  /// Le fichier choisi n'a **pas pu être lu** : introuvable, effacé entre le
  /// choix et la lecture, corrompu, ou verrouillé par une autre application.
  fileUnreadable,
}

/// Les motifs qu'un `ZChatAttachmentPicker` peut légitimement rendre.
///
/// Ce socle ne **devine** aucune cause : il ne la distingue que là où la
/// plateforme la lui a donnée, c'est-à-dire quand l'implémentation d'hôte
/// rend elle-même un [ZChatAttachmentFailure] portant l'un de ces motifs.
/// Tout autre échec — y compris un motif de cette énumération qui n'a rien à
/// faire dans une sélection ([ZChatAttachmentRejection.rejectedByServer], par
/// exemple) — retombe sur [ZChatAttachmentRejection.pickFailed].
const Set<ZChatAttachmentRejection> kZChatPickRejections =
    <ZChatAttachmentRejection>{
      ZChatAttachmentRejection.pickFailed,
      ZChatAttachmentRejection.permissionDenied,
      ZChatAttachmentRejection.sourceUnavailable,
      ZChatAttachmentRejection.fileUnreadable,
    };

/// Le motif de sélection porté par [failure], ou le repli.
///
/// Un seul site de décision : la règle « le socle relaie, il ne devine pas »
/// vaut d'être écrite une fois, pas à chaque site d'appel.
ZChatAttachmentRejection zChatPickRejectionOf(ZFailure failure) =>
    failure is ZChatAttachmentFailure &&
        kZChatPickRejections.contains(failure.reason)
    ? failure.reason
    : ZChatAttachmentRejection.pickFailed;

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
