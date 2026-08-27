/// Contrôleur de pièces jointes.
///
/// ## Quatre choix structurants
///
/// 1. État Flutter-native (invariants AD-2/AD-15) — `ChangeNotifier` +
///    tranches `ValueListenable` : aucun gestionnaire d'état n'entre dans ce
///    socle.
/// 2. `ZResult` partout (invariants AD-5/AD-11) — l'annulation par
///    l'utilisateur est `Right(null)`, l'ajout est `Right(pièce)`, l'échec
///    est `Left` : les trois issues restent distinctes, jamais confondues
///    sous une même valeur `null`.
/// 3. Sélecteurs derrière une couture — un sélecteur de fichier ou de caméra
///    ne peut pas entrer directement dans ce paquet, cf.
///    `z_chat_attachment_ports.dart`.
/// 4. `ZChatAttachment` du kernel câblé — [upload] produit directement
///    l'entité du kernel, ce qui referme la boucle jusqu'à
///    `ZChatController.setAttachments`.
///
/// ## Pourquoi un contrôleur séparé de `ZChatController`
///
/// La surface publique de `ZChatController` est gardée en égalité
/// d'ensemble : chaque membre public ajouté est un site d'appel de plus,
/// donc une divergence possible entre deux surfaces d'interface. Faire
/// entrer les gestes de pièce jointe dans ce contrôleur aurait exigé de
/// relâcher cette garantie. Le cycle de vie d'une pièce jointe (sélection →
/// validation → téléversement) est d'ailleurs indépendant du tour de
/// conversation : c'est un autre objet.
///
/// Les deux se rejoignent par un seul point, explicite et sous le contrôle
/// de l'hôte : `ZChatController.setAttachments(controller.attachmentIdsOf(...))`
/// — ou plus simplement les `id` de [uploaded].
///
/// ## Invariant AD-10 — une pièce jointe ne fait jamais tomber la conversation
///
/// Aucune méthode de ce fichier ne lève, ne relance, ni ne laisse échapper
/// une exception : tout chemin d'échec produit un
/// `Left(ZChatAttachmentFailure)` et laisse la liste des pièces inchangée.
/// Y compris quand c'est l'implémentation de l'hôte qui lève — un sélecteur
/// qui échoue est un défaut de l'hôte, pas une raison de perdre la
/// conversation en cours.
///
/// C'est un écart assumé avec `zResolveChatBlock`, qui laisse au contraire
/// remonter l'exception d'un renderer d'hôte : là-bas on est dans un
/// `build()`, où avaler l'erreur rendrait le défaut indébogable et
/// invisible ; ici on est sur un chemin asynchrone dont le résultat est déjà
/// un canal d'erreur typé — la `ZFailure` produite porte la cause
/// ([ZChatAttachmentFailure.message]), donc rien n'est perdu.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_attachment_failure.dart';
import 'z_chat_attachment_ports.dart';
import 'z_pending_attachment.dart';

/// État réactif des pièces jointes du composer.
///
/// Tranches granulaires (invariant AD-2) : la liste des pièces en attente,
/// celle des pièces téléversées, le dernier échec et le transfert en cours
/// changent indépendamment.
/// Le canal global de `ChangeNotifier` reste réservé aux changements
/// structurels — ici [reset], qui change de composer.
class ZChatAttachmentController extends ChangeNotifier {
  /// Construit le contrôleur.
  ///
  /// [picker] et [uploader] sont optionnels : sans eux le contrôleur est
  /// fonctionnel en lecture et en retrait, et [pick]/[upload] renvoient un
  /// `Left` explicite plutôt que de lever — le défaut zéro-dépendance
  /// fonctionnel exigé d'une couture.
  ZChatAttachmentController({
    this.picker,
    this.uploader,
    this.maxFiles = kZChatDefaultMaxAttachments,
    this.maxFileSizeBytes = kZChatDefaultMaxAttachmentBytes,
    Set<String>? allowedMimeTypes,
  }) : allowedMimeTypes =
           allowedMimeTypes ?? kZChatDefaultAllowedAttachmentMimeTypes;

  /// Couture de sélection, ou `null` (aucun sélecteur câblé).
  final ZChatAttachmentPicker? picker;

  /// Couture de téléversement, ou `null` (aucun transport câblé).
  final ZChatAttachmentUploader? uploader;

  /// Plafond local du nombre de pièces (borne d'ERGONOMIE, pas de sécurité).
  final int maxFiles;

  /// Plafond local de taille, en octets (borne d'ERGONOMIE, pas de sécurité).
  final int maxFileSizeBytes;

  /// Types MIME admis localement (borne d'ERGONOMIE, pas de sécurité).
  final Set<String> allowedMimeTypes;

  final ValueNotifier<List<ZPendingAttachment>> _pending =
      ValueNotifier<List<ZPendingAttachment>>(
        List<ZPendingAttachment>.unmodifiable(const <ZPendingAttachment>[]),
      );

  final ValueNotifier<List<ZChatAttachment>> _uploaded =
      ValueNotifier<List<ZChatAttachment>>(
        List<ZChatAttachment>.unmodifiable(const <ZChatAttachment>[]),
      );

  final ValueNotifier<ZChatAttachmentFailure?> _lastFailure =
      ValueNotifier<ZChatAttachmentFailure?>(null);

  final ValueNotifier<bool> _uploading = ValueNotifier<bool>(false);

  /// Le nombre de [upload] EN VOL, et non un booléen.
  ///
  /// Deux téléversements simultanés sont un cas nominal (l'utilisateur joint
  /// deux fichiers d'affilée) : avec un simple booléen, le premier des deux à
  /// finir remettrait la tranche au repos alors que l'autre monte encore.
  int _uploadsInFlight = 0;

  bool _disposed = false;

  /// Pièces choisies, **pas encore téléversées**.
  ValueListenable<List<ZPendingAttachment>> get pending => _pending;

  /// Pièces **téléversées** — l'entité du kernel, telle qu'elle partira dans le
  /// message. Aucun modèle concurrent n'est déclaré ici.
  ValueListenable<List<ZChatAttachment>> get uploaded => _uploaded;

  /// Dernier échec, ou `null`. Purement informatif : la conversation continue.
  ValueListenable<ZChatAttachmentFailure?> get lastFailure => _lastFailure;

  /// `true` tant qu'au moins un [upload] est en vol.
  ///
  /// Tranche granulaire (invariant AD-2) : elle change SEULE, sans toucher
  /// ni [pending], ni [uploaded], ni [lastFailure]. Une vue qui n'écoute
  /// qu'elle — un indicateur de progression, l'état occupé d'un bouton
  /// d'envoi — se reconstruit sans reconstruire le champ de saisie, donc
  /// sans lui faire perdre le focus.
  ///
  /// Elle dit qu'un transfert **tourne**, jamais où il en est : ce socle n'a
  /// pas le compteur d'octets, et [ZChatAttachmentUploader] ne le lui rend
  /// pas. Un hôte qui veut un pourcentage le porte lui-même.
  ///
  /// Elle revient au repos quand le DERNIER transfert en vol se termine —
  /// succès, refus ou exception d'hôte confondus.
  ValueListenable<bool> get uploading => _uploading;

  /// `true` tant que le plafond local n'est pas atteint.
  bool get canAddMore => _pending.value.length < maxFiles;

  /// Les identités des pièces téléversées — l'argument de
  /// `ZChatController.setAttachments`, et le SEUL point de contact entre les
  /// deux contrôleurs.
  List<String> get uploadedIds => List<String>.unmodifiable(<String>[
    for (final ZChatAttachment a in _uploaded.value) a.id,
  ]);

  /// Ouvre le sélecteur [source] et ajoute la pièce choisie.
  ///
  /// * `Right(pièce)` — ajoutée ;
  /// * `Right(null)` — l'utilisateur a annulé (rien n'a changé) ;
  /// * `Left` — refus local ou échec du sélecteur.
  Future<ZResult<ZPendingAttachment?>> pick(
    ZChatAttachmentSource source,
  ) async {
    if (_disposed) {
      return Left<ZFailure, ZPendingAttachment?>(
        _fail(ZChatAttachmentRejection.pickFailed, 'controller disposed'),
      );
    }
    final ZChatAttachmentPicker? p = picker;
    if (p == null) {
      return Left<ZFailure, ZPendingAttachment?>(
        _fail(ZChatAttachmentRejection.pickFailed, 'no picker wired'),
      );
    }
    if (!canAddMore) {
      return Left<ZFailure, ZPendingAttachment?>(
        _fail(ZChatAttachmentRejection.maxFilesReached, 'max files reached'),
      );
    }

    final ZResult<ZPendingAttachment?> picked;
    try {
      picked = await p.pick(source);
    } catch (error) {
      // Invariant AD-10 : un picker d'hôte qui lève ne fait pas tomber la
      // conversation.
      return Left<ZFailure, ZPendingAttachment?>(
        _fail(ZChatAttachmentRejection.pickFailed, '$error'),
      );
    }

    return picked.fold(
      (ZFailure failure) => Left<ZFailure, ZPendingAttachment?>(
        _fail(
          // Le motif vient du SÉLECTEUR quand il l'a nommé, du repli sinon :
          // ce socle n'a ni la permission système, ni l'inventaire des
          // périphériques, ni le descripteur de fichier — il ne devine pas.
          zChatPickRejectionOf(failure),
          failure.message,
          cause: failure,
        ),
      ),
      (ZPendingAttachment? candidate) {
        if (candidate == null) {
          // Annulation : issue NOMINALE, aucun échec enregistré.
          return const Right<ZFailure, ZPendingAttachment?>(null);
        }
        return add(candidate).map<ZPendingAttachment?>(
          (ZPendingAttachment a) => a,
        );
      },
    );
  }

  /// Valide et ajoute [candidate] — ordre de vérification fixe : plafond,
  /// puis type, puis taille.
  ZResult<ZPendingAttachment> add(ZPendingAttachment candidate) {
    if (_disposed) {
      return Left<ZFailure, ZPendingAttachment>(
        _fail(ZChatAttachmentRejection.pickFailed, 'controller disposed'),
      );
    }
    if (!canAddMore) {
      return Left<ZFailure, ZPendingAttachment>(
        _fail(
          ZChatAttachmentRejection.maxFilesReached,
          'max files reached',
          fileName: candidate.fileName,
        ),
      );
    }
    if (!allowedMimeTypes.contains(candidate.mimeType)) {
      return Left<ZFailure, ZPendingAttachment>(
        _fail(
          ZChatAttachmentRejection.unsupportedType,
          candidate.mimeType,
          fileName: candidate.fileName,
        ),
      );
    }
    if (candidate.sizeBytes > maxFileSizeBytes) {
      return Left<ZFailure, ZPendingAttachment>(
        _fail(
          ZChatAttachmentRejection.fileTooLarge,
          '${candidate.sizeBytes}',
          fileName: candidate.fileName,
        ),
      );
    }

    _pending.value = List<ZPendingAttachment>.unmodifiable(
      <ZPendingAttachment>[..._pending.value, candidate],
    );
    _lastFailure.value = null;
    return Right<ZFailure, ZPendingAttachment>(candidate);
  }

  /// Téléverse [pending] et le déplace vers [uploaded].
  ///
  /// Le verdict du serveur (antivirus, contrôle d'accès, quota) est relayé
  /// tel quel dans [ZChatAttachmentFailure.cause] : le socle n'en reproduit
  /// aucun et ne le paraphrase pas.
  Future<ZResult<ZChatAttachment>> upload(ZPendingAttachment attachment) async {
    if (_disposed) {
      return Left<ZFailure, ZChatAttachment>(
        _fail(ZChatAttachmentRejection.uploadFailed, 'controller disposed'),
      );
    }
    final ZChatAttachmentUploader? u = uploader;
    if (u == null) {
      return Left<ZFailure, ZChatAttachment>(
        _fail(
          ZChatAttachmentRejection.uploadFailed,
          'no uploader wired',
          fileName: attachment.fileName,
        ),
      );
    }

    final ZResult<ZChatAttachment> result;
    _uploadsInFlight += 1;
    _uploading.value = true;
    try {
      result = await u.upload(attachment);
    } catch (error) {
      return Left<ZFailure, ZChatAttachment>(
        _fail(
          ZChatAttachmentRejection.uploadFailed,
          '$error',
          fileName: attachment.fileName,
        ),
      );
    } finally {
      // `finally` et non deux sites de remise au repos : le chemin
      // d'exception d'hôte est justement celui qu'on oublie, et une tranche
      // restée à `true` bloquerait l'envoi pour toujours.
      _uploadsInFlight -= 1;
      if (_uploadsInFlight == 0 && !_disposed) _uploading.value = false;
    }

    return result.fold(
      (ZFailure failure) => Left<ZFailure, ZChatAttachment>(
        _fail(
          // Un refus du serveur reste un refus du SERVEUR : il ne devient pas un
          // « échec de téléversement » du client sous prétexte qu'il transite ici.
          ZChatAttachmentRejection.rejectedByServer,
          failure.message,
          fileName: attachment.fileName,
          cause: failure,
        ),
      ),
      (ZChatAttachment stored) {
        _uploaded.value = List<ZChatAttachment>.unmodifiable(
          <ZChatAttachment>[..._uploaded.value, stored],
        );
        _pending.value = List<ZPendingAttachment>.unmodifiable(<
          ZPendingAttachment
        >[
          for (final ZPendingAttachment a in _pending.value)
            if (!identical(a, attachment)) a,
        ]);
        _lastFailure.value = null;
        return Right<ZFailure, ZChatAttachment>(stored);
      },
    );
  }

  /// Retire la pièce en attente à [index]. Un index hors bornes est ignoré :
  /// un retrait ne peut pas casser la saisie.
  void remove(int index) {
    if (_disposed) return;
    final List<ZPendingAttachment> current = _pending.value;
    if (index < 0 || index >= current.length) return;
    _pending.value = List<ZPendingAttachment>.unmodifiable(
      <ZPendingAttachment>[...current]..removeAt(index),
    );
  }

  /// Vide les pièces en attente **et** téléversées, sans toucher au dernier
  /// échec (l'hôte peut vouloir l'afficher encore).
  void clearAll() {
    if (_disposed) return;
    _pending.value = List<ZPendingAttachment>.unmodifiable(
      const <ZPendingAttachment>[],
    );
    _uploaded.value = List<ZChatAttachment>.unmodifiable(
      const <ZChatAttachment>[],
    );
  }

  /// Changement structurel : on repart d'un composer vierge. Seul geste de
  /// ce fichier qui notifie le canal global (même patron que
  /// `ZChatController.attach`).
  void reset() {
    if (_disposed) return;
    clearAll();
    _lastFailure.value = null;
    notifyListeners();
  }

  /// Enregistre et renvoie l'échec — un seul site de fabrication.
  ZChatAttachmentFailure _fail(
    ZChatAttachmentRejection reason,
    String message, {
    String? fileName,
    ZFailure? cause,
  }) {
    final ZChatAttachmentFailure failure = ZChatAttachmentFailure(
      message,
      reason: reason,
      fileName: fileName,
      cause: cause,
    );
    _lastFailure.value = failure;
    return failure;
  }

  @override
  void dispose() {
    _disposed = true;
    _pending.dispose();
    _uploaded.dispose();
    _lastFailure.dispose();
    _uploading.dispose();
    super.dispose();
  }
}

/// Plafond par défaut du nombre de pièces jointes.
const int kZChatDefaultMaxAttachments = 5;

/// Plafond par défaut de taille d'une pièce jointe — 10 Mio.
const int kZChatDefaultMaxAttachmentBytes = 10 * 1024 * 1024;

/// Types MIME admis par défaut.
///
/// Borne d'ergonomie, jamais de sécurité : le contrôle qui compte (antivirus,
/// contrôle d'accès, quota) est appliqué par le serveur, et ce socle ne le
/// refait pas.
const Set<String> kZChatDefaultAllowedAttachmentMimeTypes = <String>{
  'image/png',
  'image/jpeg',
  'application/pdf',
};
