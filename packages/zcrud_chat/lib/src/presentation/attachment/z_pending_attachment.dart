/// Pièce jointe sélectionnée mais pas encore téléversée.
///
/// ## Ce n'est pas un doublon de `ZChatAttachment`
///
/// `ZChatAttachment` (kernel) est la pièce jointe persistée : `id` + `url` +
/// `mime_type` + `file_name`, telle qu'elle vit dans un `ZChatMessage` déjà
/// envoyé. Elle n'a pas d'octets, et ne doit pas en avoir : on ne sérialise
/// pas 10 Mo dans une entité.
///
/// `ZPendingAttachment` est l'état amont, strictement local et éphémère :
/// l'octet choisi par l'utilisateur, avant qu'un téléversement ne lui donne
/// une identité et une URL. Les deux sont reliés par
/// [ZChatAttachmentUploader], qui consomme l'un et produit l'autre.
///
/// | | `ZPendingAttachment` (ici) | `ZChatAttachment` (kernel) |
/// |---|---|---|
/// | porte | des octets | une URL |
/// | a une identité | non | oui (`id`) |
/// | sérialisable | non (jamais persisté) | oui (`toJson`) |
/// | durée de vie | le temps de la saisie | celle du message |
///
/// ## Octets, jamais `dart:io`
///
/// Aucun `File`, aucun `localPath` : `dart:io` n'existe pas sur le web, et ce
/// socle est multi-plateformes par construction.
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

  /// Taille en octets — dérivée de [bytes], jamais stockée séparément.
  ///
  /// Un champ dupliqué à côté de `bytes` ouvrirait deux sources pour un même
  /// fait, et rien n'empêcherait l'une de mentir sur l'autre — précisément la
  /// valeur que la validation de taille compare. Calculée, elle est toujours
  /// vraie.
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
