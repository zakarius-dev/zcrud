/// Le **collage** : le socle reçoit et transmet, il ne lit rien.
///
/// Ce que ces gardes prouvent : sans greffon d'hôte le collage est **inerte**
/// (rien n'entre, rien ne lève) ; avec un port, la pièce collée traverse le
/// contrôleur — donc ses bornes — avant d'atteindre le rappel d'hôte ; et un
/// port qui LÈVE ne fait pas tomber la saisie.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_core/domain.dart';

ZPendingAttachment _png({String name = 'collage.png', int size = 8}) =>
    ZPendingAttachment(
      bytes: Uint8List.fromList(List<int>.filled(size, 0x41)),
      fileName: name,
      mimeType: 'image/png',
    );

/// Port scriptable — il joue exactement ce qu'on lui dit, y compris LEVER.
class _ScriptedPaste implements ZChatComposerPastePort {
  _ScriptedPaste({this.result, this.throws = false});

  final ZResult<ZPendingAttachment?>? result;
  final bool throws;
  int calls = 0;

  @override
  Future<ZResult<ZPendingAttachment?>> readImage() async {
    calls++;
    if (throws) throw StateError('greffon en panne');
    return result ?? const Right<ZFailure, ZPendingAttachment?>(null);
  }
}

void main() {
  group('L8 — le port de collage', () {
    test(
      'port INERTE : rien n\'entre, rien ne lève, et le rappel d\'hôte n\'est '
      'jamais appelé',
      () async {
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        int rappels = 0;

        final ZResult<ZPendingAttachment?> r = await zChatAcceptPastedImage(
          port: const ZChatUnavailablePaste(),
          attachments: attachments,
          onPasted: (ZPendingAttachment _) => rappels++,
        );

        expect(r.isRight(), isTrue, reason: 'un presse-papier sans image est nominal');
        expect(
          r.getOrElse(() => _png()),
          isNull,
          reason: 'le port inerte rend null, pas une pièce fabriquée',
        );
        expect(attachments.pending.value, isEmpty);
        expect(rappels, 0);
      },
    );

    test(
      'pièce collée : elle passe par le CONTRÔLEUR (donc ses bornes) avant '
      'd\'atteindre le rappel d\'hôte',
      () async {
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        final ZPendingAttachment collee = _png();
        final List<ZPendingAttachment> vus = <ZPendingAttachment>[];

        final ZResult<ZPendingAttachment?> r = await zChatAcceptPastedImage(
          port: _ScriptedPaste(
            result: Right<ZFailure, ZPendingAttachment?>(collee),
          ),
          attachments: attachments,
          onPasted: vus.add,
        );

        expect(r.isRight(), isTrue);
        expect(
          attachments.pending.value,
          <ZPendingAttachment>[collee],
          reason: 'le contrôleur est le SEUL site d\'ajout',
        );
        expect(vus, <ZPendingAttachment>[collee]);
      },
    );

    test(
      'REFUS du contrôleur : le motif est relayé tel quel, rien n\'est ajouté '
      'et le rappel d\'hôte n\'est PAS appelé',
      () async {
        // `image/gif` est hors de la liste autorisée par défaut : le refus
        // vient du contrôleur, pas du relais.
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        int rappels = 0;
        final ZPendingAttachment gif = ZPendingAttachment(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'a.gif',
          mimeType: 'image/gif',
        );

        final ZResult<ZPendingAttachment?> r = await zChatAcceptPastedImage(
          port: _ScriptedPaste(
            result: Right<ZFailure, ZPendingAttachment?>(gif),
          ),
          attachments: attachments,
          onPasted: (ZPendingAttachment _) => rappels++,
        );

        expect(r.isLeft(), isTrue, reason: 'un refus de borne ne peut pas passer pour un succès');
        final ZFailure f = r.fold(
          (ZFailure e) => e,
          (ZPendingAttachment? _) => fail('un Right est une régression'),
        );
        expect(f, isA<ZChatAttachmentFailure>());
        expect(
          (f as ZChatAttachmentFailure).reason,
          ZChatAttachmentRejection.unsupportedType,
          reason: 'le motif du contrôleur est relayé, jamais réinventé',
        );
        expect(attachments.pending.value, isEmpty);
        expect(rappels, 0);
      },
    );

    test('un port qui LÈVE rend un Left typé — la saisie ne tombe pas (AD-10)',
        () async {
      final _ScriptedPaste port = _ScriptedPaste(throws: true);

      final ZResult<ZPendingAttachment?> r =
          await zChatAcceptPastedImage(port: port);

      expect(port.calls, 1);
      expect(r.isLeft(), isTrue);
      final ZFailure f = r.fold(
        (ZFailure e) => e,
        (ZPendingAttachment? _) => fail('une exception ne peut pas rendre un Right'),
      );
      expect((f as ZChatAttachmentFailure).reason,
          ZChatAttachmentRejection.pickFailed);
    });

    test(
      'sans contrôleur, le relais n\'invente AUCUNE borne : la pièce atteint '
      'le rappel d\'hôte telle quelle',
      () async {
        final ZPendingAttachment enorme = _png(size: 999999999 ~/ 1000);
        final List<ZPendingAttachment> vus = <ZPendingAttachment>[];

        final ZResult<ZPendingAttachment?> r = await zChatAcceptPastedImage(
          port: _ScriptedPaste(
            result: Right<ZFailure, ZPendingAttachment?>(enorme),
          ),
          onPasted: vus.add,
        );

        expect(r.isRight(), isTrue);
        expect(vus, <ZPendingAttachment>[enorme]);
      },
    );
  });
}
