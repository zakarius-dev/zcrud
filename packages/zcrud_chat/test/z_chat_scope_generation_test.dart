@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

class _HungPort implements ZChatArtifactGenerationPort {
  final Completer<ZResult<ZChatArtifactContent>> gate =
      Completer<ZResult<ZChatArtifactContent>>();
  int calls = 0;

  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    calls++;
    return gate.future;
  }
}

void main() {
  test('une seconde génération sur la même portée est refusée', () async {
    final _HungPort port = _HungPort();
    final ZChatScopeGeneration generation = ZChatScopeGeneration(port: port);
    addTearDown(generation.dispose);

    final Future<ZResult<ZChatArtifactContent>> first = generation.generate(
      scopeId: 'folder-1',
      artifactKey: 'cards',
      notes: 'matière',
    );
    await Future<void>.delayed(Duration.zero);
    expect(generation.busy.value, <String>{'folder-1'});

    final ZResult<ZChatArtifactContent> second = await generation.generate(
      scopeId: 'folder-1',
      artifactKey: 'cards',
      notes: 'autre',
    );
    expect(second.isLeft(), isTrue);
    expect(port.calls, 1);

    port.gate.complete(
      Right<ZFailure, ZChatArtifactContent>(
        ZChatArtifactContent('', structured: const <String, dynamic>{'n': 1}),
      ),
    );
    expect((await first).isRight(), isTrue);
    expect(generation.busy.value, isEmpty);
  });

  test('onGenerated remplace l\'écriture du magasin', () async {
    final ZChatScopeGeneration generation = ZChatScopeGeneration(
      port: _Immediate(
        ZChatArtifactContent('texte', structured: const <String, dynamic>{}),
      ),
    );
    addTearDown(generation.dispose);
    ZChatArtifactContent? recorded;
    final ZResult<ZChatArtifactContent> done = await generation.generate(
      scopeId: 'folder-1',
      artifactKey: 'cards',
      notes: 'matière',
      onGenerated: (ZChatArtifactContent content) async {
        recorded = content;
        return const Right<ZFailure, Unit>(unit);
      },
    );
    expect(done.isRight(), isTrue);
    expect(recorded?.data, 'texte');
  });
}

class _Immediate implements ZChatArtifactGenerationPort {
  _Immediate(this.content);
  final ZChatArtifactContent content;

  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) async => Right<ZFailure, ZChatArtifactContent>(content);
}
