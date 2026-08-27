/// Coutures de pièce jointe — sélection et téléversement.
///
/// ## Pourquoi des ports, et pas une dépendance directe à un sélecteur
///
/// Une intégration directe à un plugin de sélection de fichier ou de caméra
/// interdirait à ce paquet de rester sans dépendance tierce : un hôte qui
/// n'attache jamais rien tirerait quand même les plugins natifs correspondants
/// et leurs permissions de manifeste.
///
/// La forme retenue est celle que ce paquet emploie déjà pour le rendu : une
/// couture. Le contrôleur porte la logique (bornes, table des pièces en
/// attente, câblage vers `ZChatAttachment`) ; la plateforme entre par
/// [ZChatAttachmentPicker], que l'hôte implémente avec le paquet de son choix
/// — un sélecteur d'image, un sélecteur de fichier, un sélecteur maison, ou un
/// faux en test.
///
/// C'est le même patron que `ZChatRenderer` et `ZListRenderer` : défaut
/// fonctionnel à zéro dépendance — sans picker fourni, le chat fonctionne, on
/// ne peut simplement pas joindre de fichier.
///
/// [ZChatAttachmentSource] couvre les trois sélecteurs éprouvés : caméra,
/// galerie et système de fichiers. Une valeur de plus ne se justifie que si un
/// sélecteur de plus est réellement implémenté quelque part — un libellé de
/// menu sans implémentation n'est pas une fonctionnalité.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_attachment_failure.dart';
import 'z_pending_attachment.dart';

/// D'où provient le fichier choisi.
enum ZChatAttachmentSource {
  /// Capture par l'appareil photo.
  camera,

  /// Choix dans la galerie d'images.
  gallery,

  /// Choix dans le système de fichiers.
  files,
}

/// Couture de sélection : la plateforme, vue depuis le socle.
///
/// Invariant AD-10 : une implémentation ne lève jamais. L'annulation par
/// l'utilisateur est le cas nominal d'un sélecteur : elle se signale par
/// `Right(null)`, pas par une exception ni par un `Left`. Un échec réel
/// (permission refusée, caméra absente) se signale par `Left`. Le contrôleur
/// enveloppe malgré tout l'appel — une implémentation d'hôte qui lèverait ne
/// doit pas faire tomber la conversation — mais cette enveloppe est un filet,
/// pas le contrat.
abstract class ZChatAttachmentPicker {
  /// Constructeur `const`, pour des implémentations immuables.
  const ZChatAttachmentPicker();

  /// Ouvre le sélecteur [source].
  ///
  /// * `Right(ZPendingAttachment)` — un fichier a été choisi ;
  /// * `Right(null)` — l'utilisateur a **annulé** (issue nominale) ;
  /// * `Left(ZFailure)` — le sélecteur a échoué.
  ///
  /// ## Nommer la cause d'un échec
  ///
  /// Trois causes appellent trois messages différents — « fichier
  /// introuvable » n'est pas « accès caméra refusé ». Seule la plateforme les
  /// connaît : ce socle ne les devine pas et ne les infère d'aucun texte.
  ///
  /// Une implémentation qui sait laquelle s'est produite rend un
  /// `Left(ZChatAttachmentFailure(..., reason: …))` portant
  /// [ZChatAttachmentRejection.permissionDenied],
  /// [ZChatAttachmentRejection.sourceUnavailable] ou
  /// [ZChatAttachmentRejection.fileUnreadable] : le contrôleur relaie ce
  /// motif tel quel. Tout autre `ZFailure` — et toute implémentation qui ne
  /// sait pas discriminer — retombe sur
  /// [ZChatAttachmentRejection.pickFailed], sans exception (invariant AD-10).
  Future<ZResult<ZPendingAttachment?>> pick(ZChatAttachmentSource source);
}

/// Couture de téléversement — le pont entre l'octet local et l'entité
/// persistée.
///
/// C'est ici que `ZChatAttachment` (kernel) est câblé : ce paquet ne
/// redéclare aucun modèle de pièce jointe persistée, il consomme celui du
/// kernel comme type de sortie. Le transport (HTTP, stockage objet, signature
/// d'URL) reste côté application (invariants AD-11/AD-12), exactement comme
/// pour le port de streaming.
///
/// C'est aussi ici que remontent les verdicts serveur (antivirus, contrôle
/// d'accès, quota) : ils arrivent au socle sous la forme d'un `Left` que le
/// contrôleur relaie sans le réinterpréter.
abstract class ZChatAttachmentUploader {
  /// Constructeur `const`, pour des implémentations immuables.
  const ZChatAttachmentUploader();

  /// Téléverse [pending] et renvoie la pièce jointe **persistée** correspondante.
  Future<ZResult<ZChatAttachment>> upload(ZPendingAttachment pending);
}
