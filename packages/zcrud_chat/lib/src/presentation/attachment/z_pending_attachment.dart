/// Pièce jointe **sélectionnée mais pas encore téléversée** —
/// `ZPendingAttachment` (CHAT-5).
///
/// origine: lex_ui — `chat_attachment_controller.dart` (`PendingAttachment`,
/// Story 104.1/FR64/A17). **Porté, pas réinventé** : la forme bytes-only de lex
/// est reprise telle quelle, y compris sa raison d'être.
///
/// ## 🔴 Ce n'est PAS un doublon de `ZChatAttachment`
///
/// `ZChatAttachment` (kernel, `z_chat_attachment.dart`, livré par CHAT-0) est la
/// pièce jointe **PERSISTÉE** : `id` + `url` + `mime_type` + `file_name`, telle
/// qu'elle vit dans un `ZChatMessage` déjà envoyé. Elle n'a **pas d'octets** —
/// et ne doit pas en avoir : on ne sérialise pas 10 Mo dans une entité.
///
/// Ce type-ci est l'état **AMONT**, strictement local et éphémère : l'octet
/// choisi par l'utilisateur, avant qu'un téléversement ne lui donne une identité
/// et une URL. Les deux sont reliés par [ZChatAttachmentUploader], qui consomme
/// l'un et produit l'autre — c'est le CÂBLAGE, et il est gardé (aucune
/// redéclaration de `ZChatAttachment` dans ce package).
///
/// | | `ZPendingAttachment` (ici) | `ZChatAttachment` (kernel) |
/// |---|---|---|
/// | porte | des **octets** | une **URL** |
/// | a une identité | non | oui (`id`) |
/// | sérialisable | **non** (jamais persisté) | oui (`toJson`) |
/// | durée de vie | le temps de la saisie | celle du message |
///
/// ## 🔴 Bytes, jamais `dart:io`
///
/// Aucun `File`, aucun `localPath` : `dart:io` n'existe pas sur le web et ce
/// socle est multi-plateformes. C'est la migration que lex a dû faire *après
/// coup* (Story 104.1) ; elle est acquise dès l'origine ici.
library;

import 'dart:typed_data';

/// Un fichier choisi localement, **pas encore téléversé**.
///
/// Immuable. Les octets sont la source de vérité ; [thumbnailBytes] n'est qu'un
/// raccourci d'affichage (identique à [bytes] pour une image, `null` sinon).
class ZPendingAttachment {
  /// Construit une pièce jointe en attente.
  const ZPendingAttachment({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.thumbnailBytes,
  });

  /// Contenu binaire du fichier — source de vérité, multi-plateformes.
  final Uint8List bytes;

  /// Nom de fichier lisible, tel que la plateforme l'a rendu.
  final String fileName;

  /// Type MIME déclaré par la plateforme.
  final String mimeType;

  /// Vignette d'aperçu, ou `null` quand il n'y en a pas (un PDF, par exemple).
  final Uint8List? thumbnailBytes;

  /// Taille en octets — **dérivée**, jamais stockée.
  ///
  /// 🔴 lex portait un champ `sizeBytes` *à côté* de `bytes`. Deux sources pour
  /// un même fait : rien n'empêchait `sizeBytes` de mentir sur `bytes.length`,
  /// et c'est précisément la valeur que la validation de taille compare. Ici la
  /// taille est calculée, donc toujours vraie.
  int get sizeBytes => bytes.length;

  /// `true` si le type MIME déclaré est une image.
  bool get isImage => mimeType.startsWith('image/');

  /// `true` si le type MIME déclaré est un PDF.
  bool get isPdf => mimeType == 'application/pdf';

  @override
  String toString() =>
      'ZPendingAttachment(fileName: $fileName, mimeType: $mimeType, '
      'sizeBytes: $sizeBytes)';
}
