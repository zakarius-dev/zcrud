/// Le RELAIS du drapeau de teinte permanente, de la voie déclarative jusqu'à
/// la forme de rendu.
///
/// Le drapeau vivait sur la forme de rendu seule. Un hôte qui déclare ses
/// artefacts par le registre — la voie recommandée — devait redescendre d'un
/// cran pour une propriété. Ces gardes mesurent le RELAIS, pas la
/// déclaration : le drapeau de la déclaration se retrouve sur la spec, dans
/// les deux sens, et rien d'autre ne bouge.
///
/// * **RLY-1** — posé sur la déclaration, il arrive sur la spec.
/// * **RLY-2** — INERTIE : non posé, la spec le rend `false` — une
///   déclaration existante ne change pas de rendu.
/// * **RLY-3** — le drapeau est INDÉPENDANT de la teinte : il traverse même
///   quand aucun accent n'est résolu (le socle n'invente aucune couleur).
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';

const String _kMindmap = 'mindmap';

ZChatArtifactSpec _specOf({required bool alwaysAccented}) {
  final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
  addTearDown(transcript.dispose);
  final ZChatNotebookController nb = ZChatNotebookController(
    streamPort: FakeStreamPort(),
    transcript: transcript,
    conversationId: 'c1',
    registry: ZChatArtifactRegistry(<ZChatArtifactDeclaration>[
      ZChatArtifactDeclaration(
        key: _kMindmap,
        accentToken: 'accent.mindmap',
        alwaysAccented: alwaysAccented,
      ),
    ]),
  );
  addTearDown(nb.dispose);
  return zChatArtifactSpecOf(
    nb.registry.declarationOf(_kMindmap)!,
    controller: nb,
  );
}

void main() {
  group('🔴 RLY — le drapeau traverse la voie déclarative', () {
    test('RLY-1 posé sur la déclaration, il arrive sur la spec', () {
      expect(
        _specOf(alwaysAccented: true).alwaysAccented,
        isTrue,
        reason: '🔴 la voie déclarative ne TRANSPORTE pas le drapeau : un '
            'hôte qui déclare par le registre n\'y a pas accès',
      );
    });

    test('RLY-2 INERTIE : non posé, la spec le rend `false`', () {
      expect(
        _specOf(alwaysAccented: false).alwaysAccented,
        isFalse,
        reason: '🔴 une déclaration existante a changé de rendu',
      );
    });

    test('RLY-3 le drapeau traverse même sans accent résolu', () {
      // Contre-preuve : AUCUNE couleur n'est inventée par le socle — et le
      // drapeau passe quand même. Un relais qui dépendrait de la présence
      // d'une teinte se tairait ici.
      final ZChatArtifactSpec spec = _specOf(alwaysAccented: true);
      expect(spec.accent, isNull);
      expect(spec.alwaysAccented, isTrue);
    });
  });
}
