/// **Le collage d'une image** — un port, jamais une lecture du presse-papier.
///
/// ## Pourquoi un port
///
/// `flutter/services` ne sait lire du presse-papier que du **texte**
/// (`Clipboard.getData(Clipboard.kTextPlain)`). Récupérer une image collée
/// demande un greffon natif. Ce paquet n'en prend aucun : un hôte qui ne colle
/// jamais d'image ne doit pas hériter d'un greffon, de ses permissions de
/// manifeste ni de sa surface native.
///
/// La forme retenue est celle déjà employée pour la sélection de fichier :
/// une couture. La plateforme entre par [ZChatComposerPastePort], que l'hôte
/// implémente avec le paquet de son choix — ou pas du tout.
///
/// ## Ce que le socle fait, et ce qu'il ne fait pas
///
/// Il **reçoit** ce que le port lui rend et le **transmet** — au contrôleur de
/// pièces jointes, à un rappel d'hôte, ou aux deux ([zChatAcceptPastedImage]).
/// Il ne lit aucun presse-papier, n'ouvre aucun fichier, ne devine aucun type
/// MIME et ne décode aucun octet.
///
/// Il n'intercepte pas non plus le raccourci de collage. Un socle qui
/// capterait `Ctrl`/`Cmd`+`V` pour interroger un port **asynchrone** devrait
/// décider d'avaler la frappe avant de savoir si le presse-papier contient une
/// image : un collage de texte ordinaire serait alors perdu. Le déclenchement
/// reste donc à l'hôte, qui sait, lui, ce que son greffon a détecté.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_attachment_controller.dart';
import 'z_chat_attachment_failure.dart';
import 'z_pending_attachment.dart';

/// Couture de collage : le presse-papier, vu depuis le socle.
///
/// Invariant AD-10 : une implémentation ne lève jamais. Un presse-papier qui
/// ne contient pas d'image est le cas **nominal** — il se signale par
/// `Right(null)`, pas par une exception ni par un `Left`. Un échec réel
/// (accès refusé, décodage impossible) se signale par `Left`.
abstract interface class ZChatComposerPastePort {
  /// Rend l'image présente dans le presse-papier, ou `Right(null)` s'il n'y
  /// en a pas.
  Future<ZResult<ZPendingAttachment?>> readImage();
}

/// Port **inerte** : le presse-papier ne rend jamais d'image.
///
/// C'est le défaut d'un hôte qui n'a branché aucun greffon : le geste de
/// collage garde son sens natif, rien ne lève, rien n'est ajouté.
class ZChatUnavailablePaste implements ZChatComposerPastePort {
  /// Construit le port inerte.
  const ZChatUnavailablePaste();

  @override
  Future<ZResult<ZPendingAttachment?>> readImage() async =>
      const Right<ZFailure, ZPendingAttachment?>(null);
}

/// Reçoit ce que [port] rend et le **transmet**.
///
/// * `Right(pièce)` — une image a été collée, et elle a été remise à
///   [attachments] (qui applique seul ses bornes) puis à [onPasted] ;
/// * `Right(null)` — le presse-papier ne contenait pas d'image : issue
///   nominale, rien n'a changé ;
/// * `Left` — le port a échoué, ou le contrôleur a refusé la pièce (type,
///   taille, plafond). Le motif du contrôleur est relayé tel quel.
///
/// Ne lève jamais (invariant AD-10) : un port d'hôte qui lèverait ne doit pas
/// faire tomber la saisie.
Future<ZResult<ZPendingAttachment?>> zChatAcceptPastedImage({
  required ZChatComposerPastePort port,
  ZChatAttachmentController? attachments,
  void Function(ZPendingAttachment pasted)? onPasted,
}) async {
  final ZResult<ZPendingAttachment?> read;
  try {
    read = await port.readImage();
  } catch (error) {
    return Left<ZFailure, ZPendingAttachment?>(
      ZChatAttachmentFailure(
        '$error',
        reason: ZChatAttachmentRejection.pickFailed,
      ),
    );
  }
  return read.fold(
    (ZFailure failure) => Left<ZFailure, ZPendingAttachment?>(failure),
    (ZPendingAttachment? pasted) {
      if (pasted == null) {
        return const Right<ZFailure, ZPendingAttachment?>(null);
      }
      // Les bornes (plafond, type, taille) appartiennent au contrôleur : ce
      // relais n'en refait aucune, et n'en invente aucune quand il n'y a pas
      // de contrôleur.
      if (attachments != null) {
        final ZResult<ZPendingAttachment> added = attachments.add(pasted);
        if (added.isLeft()) {
          return added.map<ZPendingAttachment?>((ZPendingAttachment a) => a);
        }
      }
      onPasted?.call(pasted);
      return Right<ZFailure, ZPendingAttachment?>(pasted);
    },
  );
}
