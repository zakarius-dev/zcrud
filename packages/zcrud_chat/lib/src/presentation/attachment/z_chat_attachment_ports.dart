/// Coutures de pièce jointe — sélection et téléversement (CHAT-5, AD-57).
///
/// ## 🔴 Pourquoi des ports, et pas `image_picker` / `file_picker`
///
/// lex branche `ImagePicker()` et `FilePicker.pickFiles()` **directement** dans
/// son contrôleur (`chat_attachment_controller.dart`). Le contrôleur est par
/// ailleurs parfaitement portable — zéro `ref.*`, aucune dépendance à Riverpod —
/// mais ces deux paquets-là ne peuvent pas entrer ici : AD-57 interdit toute
/// dépendance tierce dans `zcrud_chat`, et un hôte qui n'attache jamais rien
/// tirerait quand même deux plugins natifs (caméra, stockage) **et leurs
/// permissions de manifeste**.
///
/// La forme retenue est celle que ce package emploie déjà pour Quill et
/// Syncfusion : une **couture**. Le contrôleur porte la logique (bornes, table
/// des pièces en attente, câblage vers `ZChatAttachment`) ; la plateforme entre
/// par [ZChatAttachmentPicker], que l'hôte implémente avec le paquet de son
/// choix — `image_picker`, `file_picker`, un sélecteur maison, ou un faux en
/// test.
///
/// C'est le patron exact de `ZChatRenderer` (`render/z_chat_renderer.dart`) et
/// de `ZListRenderer` : **défaut fonctionnel à zéro dépendance** — ici, pas de
/// picker ⇒ le chat marche, on ne peut simplement pas joindre de fichier.
///
/// ## 🔴 Ce qu'IFFD offre et qu'on ne porte PAS
///
/// Le composer `+` d'IFFD ouvre **quatre** options
/// (`chatbot_conversation_screen.dart:2652-2751`) : « Joindre des photos »,
/// « Prendre une photo », « Joindre un fichier » et « Joindre un document ».
/// Les **trois premières** sont MORTES — leur `case` est un `break;` nu
/// (`:2707-2713`) : le menu promet trois gestes qui ne font rien. Elles ne sont
/// pas portées.
///
/// [ZChatAttachmentSource] reprend en revanche les trois sélecteurs **vivants**
/// de lex (caméra, galerie, fichiers), tous trois implémentés et éprouvés là-bas.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_pending_attachment.dart';

/// D'où provient le fichier choisi.
///
/// Les trois sélecteurs **vivants** de lex. Une valeur de plus ne se justifie
/// que si un sélecteur de plus existe réellement — un libellé de menu sans
/// implémentation est le défaut d'IFFD, pas une fonctionnalité.
enum ZChatAttachmentSource {
  /// Capture par l'appareil photo.
  camera,

  /// Choix dans la galerie d'images.
  gallery,

  /// Choix dans le système de fichiers.
  files,
}

/// Couture de **sélection** : la plateforme, vue depuis le socle.
///
/// 🔴 **AD-10 — une implémentation ne lève JAMAIS.** L'annulation par
/// l'utilisateur est le cas NOMINAL d'un sélecteur : elle se signale par
/// `Right(null)`, pas par une exception ni par un `Left`. Un échec réel
/// (permission refusée, caméra absente) se signale par `Left`. Le contrôleur
/// enveloppe malgré tout l'appel (une implémentation d'hôte qui lèverait ne doit
/// pas faire tomber la conversation) — mais l'enveloppe est un filet, pas le
/// contrat.
abstract class ZChatAttachmentPicker {
  /// Constructeur `const`, pour des implémentations immuables.
  const ZChatAttachmentPicker();

  /// Ouvre le sélecteur [source].
  ///
  /// * `Right(ZPendingAttachment)` — un fichier a été choisi ;
  /// * `Right(null)` — l'utilisateur a **annulé** (issue nominale) ;
  /// * `Left(ZFailure)` — le sélecteur a échoué.
  Future<ZResult<ZPendingAttachment?>> pick(ZChatAttachmentSource source);
}

/// Couture de **téléversement** — le pont entre l'octet local et l'entité
/// persistée.
///
/// 🔴 C'est ICI que `ZChatAttachment` (kernel, CHAT-0) est **câblé** : ce
/// package ne redéclare aucun modèle de pièce jointe persistée, il consomme
/// celui du kernel comme type de sortie. Le transport (HTTP, Firebase Storage,
/// signature d'URL) reste **côté app** — AD-11/AD-12, exactement comme
/// `ZChatStreamPort`.
///
/// C'est aussi ici que remontent l'**antivirus**, la **gate vision par tier** et
/// le **quota multimodal** : ce sont des verdicts SERVEUR, et ils arrivent au
/// socle sous la forme d'un `Left` que le contrôleur relaie sans le réinterpréter.
abstract class ZChatAttachmentUploader {
  /// Constructeur `const`, pour des implémentations immuables.
  const ZChatAttachmentUploader();

  /// Téléverse [pending] et renvoie la pièce jointe **persistée** correspondante.
  Future<ZResult<ZChatAttachment>> upload(ZPendingAttachment pending);
}
