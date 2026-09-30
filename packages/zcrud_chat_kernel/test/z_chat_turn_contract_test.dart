/// Champs de fin de tour, ancre d'artefact, sources et palette.
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  test(
    'grounded, unverified et level font l\'aller-retour et sortent d\'extra',
    () {
      final ZChatMessage message = ZChatMessage.fromMap(<String, dynamic>{
        'role': 'assistant',
        'grounded': true,
        'unverified': false,
        'level': 'plus',
        'note': 'hôte',
      });
      expect(message.grounded, isTrue);
      expect(message.unverified, isFalse);
      expect(message.level, 'plus');
      expect(message.extra.containsKey('grounded'), isFalse);
      expect(message.extra['note'], 'hôte');
      final ZChatMessage back = ZChatMessage.fromMap(message.toMap());
      expect(back.grounded, isTrue);
      expect(back.level, 'plus');
      expect(back, message);
    },
  );

  test('status et reasoning sont des événements typés', () {
    final ZChatStreamEvent? status = ZChatStreamEvent.fromJson(
      <String, dynamic>{'type': 'status', 'phase': 'read', 'detail': 'art. 12'},
    );
    expect(status, isA<ZChatStatusEvent>());
    expect((status! as ZChatStatusEvent).notice.detail, 'art. 12');
    final ZChatStreamEvent? reasoning = ZChatStreamEvent.fromJson(
      <String, dynamic>{'type': 'reasoning', 'content': 'donc'},
    );
    expect((reasoning! as ZChatReasoningEvent).content, 'donc');
  });

  test('une requête sans message s\'ancre sur le conteneur', () {
    final ZChatArtifactGenerationRequest scoped =
        ZChatArtifactGenerationRequest(
          scopeId: 'folder-1',
          artifactKey: 'summary',
          notes: 'le fil',
        );
    expect(scoped.messageId, isEmpty);
    expect(scoped.anchorId, 'folder-1');
    final ZChatArtifactGenerationRequest copied = scoped.copyWith(
      artifactKey: 'faq',
    );
    expect(copied.scopeId, 'folder-1');
    expect(copied.artifactKey, 'faq');
    expect(copied, isNot(scoped));
  });

  test('une source inconnue reste listable et la palette filtre le niveau', () {
    final ZNotebookSource source = ZNotebookSource.fromJson(<String, dynamic>{
      'id': 's1',
      'title': 'Code',
      'state': 'nope',
    });
    expect(source.state, ZNotebookIngestionState.ready);
    final ZTransformPalette palette =
        ZTransformPalette(<ZTransformPaletteEntry>[
          const ZTransformPaletteEntry(artifactKey: 'summary', label: 'Résumé'),
          ZTransformPaletteEntry(
            artifactKey: 'quiz',
            label: 'Quiz',
            allows: (String? level) => level == 'plus',
          ),
        ]);
    expect(
      palette.visibleFor(null).map((ZTransformPaletteEntry e) => e.artifactKey),
      <String>['summary'],
    );
    expect(
      palette
          .visibleFor('plus')
          .map((ZTransformPaletteEntry e) => e.artifactKey),
      <String>['summary', 'quiz'],
    );
    expect(ZNotebookArtifactKind.reference, contains('study_guide'));
  });
}
