// Doublures et harnais PARTAGÉS des gardes du lot K3.
//
// 🔴 Source UNIQUE (patron `zcrud_chat/test/support/z_chat_fakes.dart`) : les
// recopier dans chaque garde créerait deux définitions divergentes de « ce que
// fait l'hôte ».
//
// ⚠️ Ce fichier n'est PAS un `*_test.dart` : le runner ne l'exécute jamais seul.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Port de streaming espion : enregistre chaque appel, n'émet rien.
class FakeStreamPort implements ZChatStreamPort {
  /// Requêtes reçues, dans l'ordre.
  final List<ZChatGenerationRequest> calls = <ZChatGenerationRequest>[];

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    calls.add(request);
    return const Stream<ZResult<ZChatStreamEvent>>.empty();
  }
}

/// Exécuteur inerte : aucun test K3 ne dispatch d'action.
class NoopExecutor implements ZChatActionExecutor {
  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      const Right<ZFailure, ZChatActionImpact>(
        ZChatActionImpact(affectedMessageCount: 0),
      );

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async => const Right<ZFailure, List<String>>(<String>[]);

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async =>
      const Right<ZFailure, List<String>>(<String>[]);

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async => const Right<ZFailure, List<String>>(<String>[]);

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async => const Right<ZFailure, String>('');

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      const Right<ZFailure, List<String>>(<String>[]);
}

/// Un [ZChatController] minimal + son port espion.
({ZChatController controller, FakeStreamPort port}) buildController() {
  final FakeStreamPort port = FakeStreamPort();
  int seq = 0;
  final ZChatController controller = ZChatController(
    streamPort: port,
    actionExecutor: NoopExecutor(),
    confirm: (ZChatActionPlan plan) async => true,
    newRequestId: () => 'r${seq++}',
    buildRequest: (ZChatDraft draft) => ZChatGenerationRequest(
      style: ZChatGenerationStyle('test'),
      subject: draft.text,
      attachmentIds: draft.attachmentIds,
    ),
  );
  return (controller: controller, port: port);
}

/// Un PNG transparent 1×1 VALIDE — un octet arbitraire ne décode pas, et un
/// `MemoryImage` sur un flux invalide fait échouer le test par exception.
final Uint8List kTransparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// Une pièce jointe en attente valide.
ZPendingAttachment pendingPng(String name, {bool withThumb = false}) =>
    ZPendingAttachment(
      bytes: kTransparentPng,
      fileName: name,
      mimeType: 'image/png',
      thumbnailBytes: withThumb ? kTransparentPng : null,
    );

/// Monte [child] dans un hôte Material minimal (thème d'hôte + directionnalité).
///
/// [material] : le `ThemeData` de l'hôte — les gardes de géométrie DOIVENT
/// mesurer sous `materialTapTargetSize: shrinkWrap`, sinon elles mesurent le
/// plancher AMBIANT du SDK (padded ⇒ 48) au lieu du NÔTRE : la leçon
/// « attendu ≠ ambiant », vécue par l'injection I06 de ce lot.
Widget harness(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  ZcrudTheme? theme,
  ThemeData? material,
}) {
  Widget tree = child;
  if (theme != null) tree = ZcrudScope(theme: theme, child: tree);
  return MaterialApp(
    theme: material,
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: tree)),
    ),
  );
}

/// Le thème d'hôte HOSTILE aux cibles : ce que rend un hôte qui compacte tout.
ThemeData hostileTapTargets() =>
    ThemeData(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
