/// Les MOTIFS DE REJET d'une sélection de pièce jointe.
///
/// Le défaut fermé : un seul code fondait trois causes que sa propre
/// documentation énumérait — permission refusée, source indisponible, fichier
/// illisible. Trois causes, trois remèdes, trois messages ; un seul code les
/// rendait indistinguables pour l'hôte qui écrit le message.
///
/// Ce que ces gardes mesurent :
///
/// * **REJ-1** — les trois motifs neufs existent, en QUEUE d'énumération : un
///   ajout en tête décalerait l'index de tous les autres (une valeur nommée
///   n'est pas un index, mais un `enum` sérialisé par position le devient).
/// * **REJ-2** — chaque motif nommé par le sélecteur est RELAYÉ, jamais écrasé
///   par le repli. Une garde par motif : une garde unique paramétrée passerait
///   si un seul des trois marchait et que les autres tombaient au repli.
/// * **REJ-3** — REPLI : un échec que le socle ne sait pas lire retombe sur
///   `pickFailed` **sans lever** (invariant AD-10). Trois formes d'inconnu :
///   une `ZFailure` quelconque, un motif hors famille de sélection, un
///   sélecteur qui LÈVE.
/// * **REJ-4** — le message et la `cause` d'origine survivent au relais : le
///   socle discrimine, il ne paraphrase pas.
/// * **REJ-5** — INERTIE : les motifs préexistants ne bougent pas.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_core/domain.dart';

ZPendingAttachment _png() => ZPendingAttachment(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  fileName: 'a.png',
  mimeType: 'image/png',
);

/// Sélecteur qui rend exactement l'échec qu'on lui donne — ou qui lève.
class _NamingPicker extends ZChatAttachmentPicker {
  const _NamingPicker(this.failure, {this.throws = false});

  final ZFailure? failure;
  final bool throws;

  @override
  Future<ZResult<ZPendingAttachment?>> pick(ZChatAttachmentSource source) async {
    if (throws) throw StateError('boom');
    return Left<ZFailure, ZPendingAttachment?>(failure!);
  }
}

Future<ZChatAttachmentRejection> _reasonOf(ZChatAttachmentPicker picker) async {
  final ZChatAttachmentController c = ZChatAttachmentController(
    picker: picker,
  );
  addTearDown(c.dispose);
  final ZResult<ZPendingAttachment?> result = await c.pick(
    ZChatAttachmentSource.camera,
  );
  final ZFailure failure = result.fold(
    (ZFailure f) => f,
    (ZPendingAttachment? _) =>
        throw StateError('un Right est un échec de la garde'),
  );
  return (failure as ZChatAttachmentFailure).reason;
}

void main() {
  group('🔴 REJ — les trois causes, distinctes', () {
    test('REJ-1 les motifs neufs sont AJOUTÉS EN QUEUE', () {
      expect(
        ZChatAttachmentRejection.values.map((ZChatAttachmentRejection r) => r.name),
        <String>[
          // Les six d'avant, dans leur ordre d'avant — aucun décalage.
          'maxFilesReached',
          'unsupportedType',
          'fileTooLarge',
          'pickFailed',
          'uploadFailed',
          'rejectedByServer',
          // Les trois neufs, en queue.
          'permissionDenied',
          'sourceUnavailable',
          'fileUnreadable',
        ],
      );
    });

    test('REJ-2a une permission refusée est relayée', () async {
      expect(
        await _reasonOf(
          const _NamingPicker(
            ZChatAttachmentFailure(
              'denied',
              reason: ZChatAttachmentRejection.permissionDenied,
            ),
          ),
        ),
        ZChatAttachmentRejection.permissionDenied,
      );
    });

    test('REJ-2b une source indisponible est relayée', () async {
      expect(
        await _reasonOf(
          const _NamingPicker(
            ZChatAttachmentFailure(
              'no camera',
              reason: ZChatAttachmentRejection.sourceUnavailable,
            ),
          ),
        ),
        ZChatAttachmentRejection.sourceUnavailable,
      );
    });

    test('REJ-2c un fichier illisible est relayé', () async {
      expect(
        await _reasonOf(
          const _NamingPicker(
            ZChatAttachmentFailure(
              'gone',
              reason: ZChatAttachmentRejection.fileUnreadable,
            ),
          ),
        ),
        ZChatAttachmentRejection.fileUnreadable,
      );
    });

    test('REJ-3a une ZFailure quelconque retombe au repli', () async {
      expect(
        await _reasonOf(const _NamingPicker(ZServerFailure('opaque'))),
        ZChatAttachmentRejection.pickFailed,
      );
    });

    test('REJ-3b un motif HORS famille de sélection retombe au repli',
        () async {
      // Le serveur n'a rien à voir avec un sélecteur : relayer ce motif
      // laisserait un hôte croire que son backend a refusé une image qui
      // n'est jamais partie.
      expect(
        await _reasonOf(
          const _NamingPicker(
            ZChatAttachmentFailure(
              'server',
              reason: ZChatAttachmentRejection.rejectedByServer,
            ),
          ),
        ),
        ZChatAttachmentRejection.pickFailed,
      );
    });

    test('REJ-3c un sélecteur qui LÈVE retombe au repli, sans exception',
        () async {
      expect(
        await _reasonOf(const _NamingPicker(null, throws: true)),
        ZChatAttachmentRejection.pickFailed,
      );
    });

    test('REJ-4 le message et la cause d\'origine survivent au relais',
        () async {
      const ZChatAttachmentFailure origin = ZChatAttachmentFailure(
        'camera permission denied by user',
        reason: ZChatAttachmentRejection.permissionDenied,
      );
      final ZChatAttachmentController c = ZChatAttachmentController(
        picker: const _NamingPicker(origin),
      );
      addTearDown(c.dispose);
      await c.pick(ZChatAttachmentSource.camera);
      final ZChatAttachmentFailure? recorded = c.lastFailure.value;
      expect(recorded, isNotNull);
      expect(recorded!.reason, ZChatAttachmentRejection.permissionDenied);
      expect(recorded.message, 'camera permission denied by user');
      expect(recorded.cause, same(origin));
    });

    test('REJ-5 INERTIE — les motifs locaux préexistants ne bougent pas',
        () async {
      final ZChatAttachmentController c = ZChatAttachmentController(
        maxFiles: 1,
      );
      addTearDown(c.dispose);
      expect(c.add(_png()).isRight(), isTrue);
      final ZFailure over = c.add(_png()).fold(
        (ZFailure f) => f,
        (ZPendingAttachment _) => throw StateError('devait refuser'),
      );
      expect(
        (over as ZChatAttachmentFailure).reason,
        ZChatAttachmentRejection.maxFilesReached,
      );

      final ZChatAttachmentController typed = ZChatAttachmentController();
      addTearDown(typed.dispose);
      final ZFailure bad = typed
          .add(
            ZPendingAttachment(
              bytes: Uint8List.fromList(<int>[1]),
              fileName: 'x.exe',
              mimeType: 'application/x-msdownload',
            ),
          )
          .fold(
            (ZFailure f) => f,
            (ZPendingAttachment _) => throw StateError('devait refuser'),
          );
      expect(
        (bad as ZChatAttachmentFailure).reason,
        ZChatAttachmentRejection.unsupportedType,
      );
    });

    test('REJ-5b sans sélecteur câblé, le refus reste `pickFailed`', () async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      final ZResult<ZPendingAttachment?> r = await c.pick(
        ZChatAttachmentSource.files,
      );
      final ZFailure f = r.fold(
        (ZFailure e) => e,
        (ZPendingAttachment? _) => throw StateError('devait refuser'),
      );
      expect(
        (f as ZChatAttachmentFailure).reason,
        ZChatAttachmentRejection.pickFailed,
      );
    });
  });
}
