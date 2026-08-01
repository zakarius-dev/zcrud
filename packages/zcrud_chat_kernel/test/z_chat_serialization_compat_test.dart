@Tags(<String>['serialization-compat'])
library;

// CHAT-0 — AC13. Garde **G15** : rétro-compatibilité de sérialisation (AD-10).
//
// Trois populations de documents ÉTRANGERS au schéma canonique :
//   1. un document **lex authentique** — blocs `PascalCase`, `feedback_category`
//      snake_case, `WorkflowEffort: 'detaille'`, `updated_at` EN CORPS, aucun
//      `version_key`, aucun `extension` ;
//   2. un document **tronqué** (`{}`) ;
//   3. un document **futur** — clés inconnues du cœur, qui doivent SURVIVRE au
//      round-trip.
//
// L'invariant testé n'est pas « ça ne plante pas » : c'est **« le parent survit
// ET ne perd rien »**.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Message tel que lex le persiste aujourd'hui (LECTURE SEULE du dépôt lex,
/// recopié ici comme fixture).
Map<String, dynamic> _documentLex() => <String, dynamic>{
      'id': 'msg-lex-1',
      'conversation_id': 'conv-lex-1',
      'role': 'assistant',
      'content_blocks': <dynamic>[
        <String, dynamic>{
          'type': 'Text',
          'data': <String, dynamic>{'text': 'Bonjour'},
        },
        <String, dynamic>{
          'type': 'KeyDefinition',
          'data': <String, dynamic>{
            'term': 'valeur en douane',
            'definition': 'base taxable',
            'source': 'CDN',
          },
        },
        <String, dynamic>{
          'type': 'Alert',
          'data': <String, dynamic>{
            'level': 'warning',
            'title': 'Attention',
            'message': 'à vérifier',
          },
        },
        // 🔴 Variante NON portée dans le cœur (D4) : elle doit survivre en
        // payload verbatim, jamais devenir du texte.
        <String, dynamic>{
          'type': 'LegalReference',
          'data': <String, dynamic>{
            'title': 'Art. 20',
            'articles': <String>['20', '21'],
            'summary': 'résumé',
            'source_type': 'code_des_douanes',
            'source_id': 'cdn-20',
          },
        },
      ],
      'sources': <dynamic>[
        <String, dynamic>{
          'source_type': 'code_des_douanes',
          'display_text': 'CDN art. 20',
          'relevance_score': 0.87,
          'verified': true,
          'verification_status': 'verified',
          'snippet': 'extrait',
          'breadcrumb': 'Titre I > Art. 20',
          'usage_status': 'general_knowledge',
          'code_id': 'cdn_benin_2014',
          'node_number': '20',
        },
      ],
      'created_at': '2026-07-09T10:30:00.000Z',
      'thinking': <dynamic>[
        <String, dynamic>{
          'agent': 'planner',
          'content': 'analyse',
          'timestamp': '2026-07-09T10:29:00.000Z',
        },
      ],
      'suggestions': <dynamic>[
        <String, dynamic>{
          'id': 'sg-1',
          'type': 'follow_up',
          'content': 'et la TVA ?',
          'actions': <dynamic>[
            <String, dynamic>{
              'shortcut': 'A',
              'title': 'Demander',
              'description': 'poser la question',
              'action_type': 'send_message',
            },
          ],
        },
      ],
      'feedback_rating': 'down',
      'feedback_category': 'off_topic',
      'feedback_comment': 'hors sujet',
      'agents_called': <dynamic>['planner', 'writer'],
      'confidence': <String, dynamic>{
        'faithfulness_score': 0.91,
        'completeness_score': 0.75,
        'quality_grade': 'pass',
        'citation_guard_status': 'ok',
        'citations_verified': 2,
        'citations_rejected': 0,
        'coverage_status': 'available',
        'verified_source_count': 2,
        'total_source_count': 2,
      },
      'source_freshness': <dynamic>[
        <String, dynamic>{
          'dataset_id': 'cdn_benin_2014',
          'freshness': 'stale',
          'pending_amendments': <dynamic>['a1'],
        },
      ],
      // Le champ que lex écrit et que zcrud REFUSE de porter en corps (D3) :
      // il appartient au store (`ZSyncMeta`, AD-16/AD-19).
      'updated_at': '2026-07-09T11:00:00.000Z',
      'is_deleted': false,
      // Métadonnée d'hôte sans équivalent canonique.
      'workflow_effort': 'detaille',
    };

void main() {
  group('G15 — document lex AUTHENTIQUE relu COMPLET', () {
    test('les blocs PascalCase sont relus TYPÉS', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      expect(m.contentBlocks, hasLength(4));
      expect(m.contentBlocks[0], isA<ZTextBlock>());
      expect(m.contentBlocks[1], isA<ZKeyDefinitionBlock>());
      expect(m.contentBlocks[2], isA<ZAlertBlock>());
      expect(m.content, 'Bonjour');
      expect((m.contentBlocks[1] as ZKeyDefinitionBlock).term,
          'valeur en douane');
    });

    test('la variante NON portée survit en payload VERBATIM (D4/D5)', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      final ZContentBlock bloc = m.contentBlocks[3];
      expect(bloc, isA<ZCustomContentBlock>());
      expect(bloc, isNot(isA<ZTextBlock>()),
          reason: 'lex ferait `TextBlock(json.toString())` — destructeur');
      expect(bloc.kind, 'LegalReference');
      expect((bloc as ZCustomContentBlock).payload['articles'],
          <String>['20', '21']);
    });

    test('les enums snake_case de lex sont relus TYPÉS', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      expect(m.role, ZChatRole.assistant);
      expect(m.feedbackRating, ZChatFeedbackRating.down);
      expect(m.feedbackCategory, ZChatFeedbackCategory.offTopic);
      expect(m.suggestions!.single.typedType, ZChatSuggestionType.followUp);
      expect(
        m.suggestions!.single.actions.single.typedActionType,
        ZChatSuggestionActionType.sendMessage,
      );
      expect(m.sources!.single.usageStatus,
          ZChatSourceUsageStatus.generalKnowledge);
      expect(m.sourceFreshness!.single.freshness, ZChatDatasetFreshness.stale);
      expect(m.sourceFreshness!.single.pendingUpdates, isTrue,
          reason: 'alias legacy `pending_amendments` lu');
    });

    test('les champs propres d\'un sous-type douanier survivent en payload', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      final ZChatSource s = m.sources!.single;
      expect(s.sourceType, 'code_des_douanes');
      expect(s.isVerified, isTrue);
      expect(s.payload['code_id'], 'cdn_benin_2014');
      expect(s.payload['node_number'], '20');
    });

    test('`version_key` absent ⇒ null, aucun throw', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      expect(m.versionKey, isNull);
      expect(m.extension, isNull);
    });

    test('🔴 les clés de SYNC du document lex ne ressortent JAMAIS', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      expect(m.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(m.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      final Map<String, dynamic> encoded = m.toMap();
      expect(ZSyncMeta.collidingReservedKeys(encoded), isEmpty);
    });

    test('la métadonnée d\'hôte inconnue SURVIT au round-trip (AD-4)', () {
      final ZChatMessage m = ZChatMessage.fromMap(_documentLex());
      expect(m.extra['workflow_effort'], 'detaille');
      expect(m.toMap()['workflow_effort'], 'detaille');
      expect(ZChatMessage.fromMap(m.toMap()), equals(m));
    });

    test('conversation lex : `updated_at` du corps N\'EST PAS relu comme '
        'récence métier (D3)', () {
      final ZChatConversation c = ZChatConversation.fromMap(<String, dynamic>{
        'id': 'conv-lex-1',
        'title': 'Valeur en douane',
        'created_at': '2026-07-01T08:00:00.000Z',
        'updated_at': '2026-07-09T11:00:00.000Z',
        'message_count': 12,
        'pinned': true,
        'pinned_at': '2026-07-05T09:00:00.000Z',
      });
      expect(c.createdAt, isNotNull);
      expect(c.messageCount, 12);
      expect(c.pinned, isTrue);
      // La récence métier vit sous `last_message_at` — l'`updated_at` de lex
      // appartient au store et est DÉPOUILLÉ, jamais réémis.
      expect(c.lastMessageAt, isNull);
      expect(c.extra.containsKey('updated_at'), isFalse);
      expect(c.toMap().containsKey('updated_at'), isFalse);
    });
  });

  group('G15 — document TRONQUÉ : entité valide, aucun throw', () {
    test('`{}` produit un message et une conversation valides', () {
      late final ZChatMessage m;
      late final ZChatConversation c;
      expect(() => m = ZChatMessage.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(() => c = ZChatConversation.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(m.isEphemeral, isTrue);
      expect(m.role, ZChatRole.unknown);
      expect(m.contentBlocks, isEmpty);
      expect(c.title, '');
      expect(c.messageCount, 0);
      // Round-trip d'un document vide : idempotent.
      expect(ZChatMessage.fromMap(m.toMap()), equals(m));
      expect(ZChatConversation.fromMap(c.toMap()), equals(c));
    });

    test('champs présents mais du MAUVAIS type ⇒ défauts sûrs', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'id': 42,
        'conversation_id': <dynamic>[],
        'role': <String, dynamic>{},
        'content_blocks': 'zzz',
        'created_at': 1234,
        'confidence': 'zzz',
        'agents_called': 42,
      });
      expect(m.id, isNull);
      expect(m.conversationId, '');
      expect(m.role, ZChatRole.unknown);
      expect(m.contentBlocks, isEmpty);
      expect(m.createdAt, isNull);
      expect(m.confidence, isNull);
      expect(m.agentsCalled, isNull);
    });
  });

  group('G15 — document FUTUR : les clés inconnues SURVIVENT', () {
    test('round-trip exact, y compris pour du JSON imbriqué', () {
      final Map<String, dynamic> futur = <String, dynamic>{
        'id': 'm',
        'conversation_id': 'c',
        'role': 'assistant',
        'content_blocks': <dynamic>[],
        // Champs d'une version ULTÉRIEURE du schéma, inconnus du cœur.
        'token_usage': <String, dynamic>{
          'input': 120,
          'output': 340,
          'detail': <dynamic>[
            1,
            <String, dynamic>{'cached': true},
          ],
        },
        'persona': 'tuteur',
      };
      final ZChatMessage m = ZChatMessage.fromMap(futur);
      expect(m.extra['persona'], 'tuteur');
      expect(m.extra['token_usage'], futur['token_usage']);

      final Map<String, dynamic> encoded = m.toMap();
      expect(encoded['persona'], 'tuteur');
      expect(encoded['token_usage'], futur['token_usage']);
      expect(ZChatMessage.fromMap(encoded), equals(m));
    });

    test('un bloc d\'un type FUTUR ne dégrade pas les blocs voisins', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'content_blocks': <dynamic>[
          <String, dynamic>{
            'type': 'text',
            'data': <String, dynamic>{'text': 'avant'},
          },
          <String, dynamic>{
            'type': 'holoDiagram',
            'data': <String, dynamic>{
              'spec': <String, dynamic>{'v': 3},
            },
          },
          <String, dynamic>{
            'type': 'text',
            'data': <String, dynamic>{'text': 'après'},
          },
        ],
      });
      expect(m.contentBlocks, hasLength(3));
      expect(m.content, 'avantaprès');
      expect(m.contentBlocks[1], isA<ZCustomContentBlock>());
      expect(ZChatMessage.fromMap(m.toMap()), equals(m));
    });
  });
}
