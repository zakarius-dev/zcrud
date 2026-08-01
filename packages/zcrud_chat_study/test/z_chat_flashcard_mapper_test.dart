/// Gardes du mapper conversation → requête de génération (CHAT-8).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_study/zcrud_chat_study.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  group('projection textuelle', () {
    test('couvre les blocs NON textuels (le défaut que `content` aurait laissé)',
        () {
      const ZChatMessage message = ZChatMessage(
        conversationId: 'c1',
        role: ZChatRole.assistant,
        contentBlocks: <ZContentBlock>[
          ZTextBlock(text: 'Le fait générateur.'),
          ZKeyDefinitionBlock(
            term: 'Valeur en douane',
            definition: 'Assiette des droits ad valorem.',
          ),
        ],
      );

      final String text = zChatMessageStudyText(message);

      // Le bloc de définition est la matière la PLUS directement transformable
      // en carte : s'il manquait, le mapper serait muet là où il compte le plus.
      expect(text, contains('Valeur en douane'));
      expect(text, contains('Assiette des droits ad valorem.'));
      expect(text, contains('Le fait générateur.'));
      // Contrôle DISCRIMINANT : `content` (texte seul) perd la définition —
      // c'est la propriété que ce test protège, pas juste « le texte est là ».
      expect(message.content, isNot(contains('Valeur en douane')));
    });

    test('un message sans bloc rend une chaîne vide, sans lever (AD-10)', () {
      expect(zChatMessageStudyText(const ZChatMessage()), isEmpty);
    });

    test('les messages `system` sont exclus par défaut', () {
      const List<ZChatMessage> messages = <ZChatMessage>[
        ZChatMessage(
          role: ZChatRole.system,
          contentBlocks: <ZContentBlock>[ZTextBlock(text: 'TU ES UN TUTEUR')],
        ),
        ZChatMessage(
          role: ZChatRole.assistant,
          contentBlocks: <ZContentBlock>[ZTextBlock(text: 'La règle est X.')],
        ),
      ];

      final String text = zChatMessagesStudyText(messages);

      expect(text, 'La règle est X.');
      expect(text, isNot(contains('TUTEUR')));
    });
  });

  group('provenance — RÉUTILISE ZConversationSource', () {
    test('un message porte conversationId + messageId', () {
      const ZChatMessage message =
          ZChatMessage(id: 'm7', conversationId: 'c1');

      final ZConversationSource source = zChatMessageProvenance(message);

      expect(source.kind, 'conversation');
      expect(source.conversationId, 'c1');
      expect(source.messageId, 'm7');
    });

    test('un message éphémère (id null) retombe sur `""` et round-trippe', () {
      const ZChatMessage message = ZChatMessage(conversationId: 'c1');

      final ZConversationSource source = zChatMessageProvenance(message);
      final ZFlashcardSource? back =
          ZFlashcardSource.fromJson(source.toJson());

      expect(source.messageId, '');
      expect(back, source);
    });

    test('une conversation entière ne s\'attribue AUCUN messageId', () {
      const ZChatConversation conversation = ZChatConversation(id: 'c9');

      final ZConversationSource source =
          zChatConversationProvenance(conversation);

      expect(source.conversationId, 'c9');
      expect(source.messageId, '');
    });
  });

  group('requête — câblage des normaliseurs EXISTANTS de zcrud_study', () {
    test('un count fou est borné par zClampGenerationCount, pas recopié', () {
      final ZFlashcardGenerationRequest r = zChatMessageGenerationRequest(
        const ZChatMessage(conversationId: 'c1'),
        count: 10000,
      );

      expect(r.count, zGenerationCountBounds.max);
    });

    test('count null retombe sur le défaut CONSIGNÉ du module de défauts', () {
      final ZFlashcardGenerationRequest r = zChatMessageGenerationRequest(
        const ZChatMessage(conversationId: 'c1'),
      );

      expect(r.count, zDefaultGenerationCount);
    });

    test('typesDistribution null RESTE null (le droit de décider de l\'hôte)',
        () {
      final ZFlashcardGenerationRequest r = zChatMessageGenerationRequest(
        const ZChatMessage(conversationId: 'c1'),
      );

      expect(r.typesDistribution, isNull);
    });

    test('une répartition incohérente est normalisée (négatif → 0)', () {
      final ZFlashcardGenerationRequest r = zChatMessageGenerationRequest(
        const ZChatMessage(conversationId: 'c1'),
        count: 4,
        typesDistribution: const <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: -3,
          ZFlashcardType.trueOrFalse: 4,
        },
      );

      expect(r.typesDistribution?[ZFlashcardType.openQuestion], 0);
      expect(r.typesDistribution?[ZFlashcardType.trueOrFalse], 4);
    });

    // ⚠️ CE QUE CE TEST MESURE, EXACTEMENT (mesuré par R3, pas supposé).
    //
    // Il pin la propriété de la COMPOSITION : la requête rendue n'expose jamais
    // de clé réservée. Il n'est **PAS porteur** de l'appel `zSanitizeExtra` de
    // ce module : retirer cet appel laisse le test VERT, parce que l'accesseur
    // `ZFlashcardGenerationRequest.extra` filtre déjà à la LECTURE. Notre appel
    // est donc une ceinture en plus des bretelles (AD-19.1 : ne jamais ÉMETTRE
    // une clé possédée par le store), et c'est
    // `z_no_duplicate_seam_test.dart` — garde de SOURCE — qui empêche qu'on la
    // retire par mégarde. Deux propriétés distinctes, deux gardes distinctes.
    test('AD-19.1 — la requête n\'expose JAMAIS de clé de sync réservée',
        () {
      final ZFlashcardGenerationRequest r = zChatMessageGenerationRequest(
        const ZChatMessage(conversationId: 'c1'),
        extra: <String, dynamic>{
          ZSyncMeta.kUpdatedAt: '2026-01-01',
          ZSyncMeta.kIsDeleted: true,
          'ok': 1,
        },
      );

      for (final String key in ZSyncMeta.reservedKeys) {
        expect(r.extra.containsKey(key), isFalse, reason: key);
      }
      expect(r.extra['ok'], 1);
    });

    test('la provenance de la requête est celle du message', () {
      final ZFlashcardGenerationRequest r = zChatMessageGenerationRequest(
        const ZChatMessage(id: 'm1', conversationId: 'c1'),
      );

      expect(r.provenance, const ZConversationSource(
        conversationId: 'c1',
        messageId: 'm1',
      ));
    });
  });
}
