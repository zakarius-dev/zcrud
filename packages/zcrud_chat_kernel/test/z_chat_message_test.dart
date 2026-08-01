// CHAT-0 — AC9/AC11. Gardes **G1** (round-trip), **G10** (élément de liste
// illisible IGNORÉ, liste préservée), **G11** (`created_at` absent/corrompu : le
// parent SURVIT), **G12** (aucune clé de sync émise), **G13** (`extra` :
// round-trip exact, étanche sur les TROIS voies, non modifiable, égalité
// PROFONDE) et **G14** (slot `extension` défensif).
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Extension typée d'hôte — sert à prouver que le slot revient TYPÉ quand un
/// parseur est injecté (et opaque sinon).
class _FauxExt extends ZExtension {
  const _FauxExt(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': 1, 'note': note};

  static ZExtension? parse(Map<String, dynamic> json) {
    if (json['format_version'] != 1) return null;
    return _FauxExt(json['note'] as String? ?? '');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FauxExt && note == other.note;

  @override
  int get hashCode => note.hashCode;
}

void main() {
  group('G1 — round-trip complet du message', () {
    test('tous les champs survivent à fromMap(toMap())', () {
      final ZChatMessage message = ZChatMessage(
        id: 'm1',
        conversationId: 'c1',
        role: ZChatRole.assistant,
        contentBlocks: const <ZContentBlock>[
          ZTextBlock(text: 'bonjour'),
          ZAlertBlock(level: 'info', message: 'note'),
        ],
        sources: const <ZChatSource>[
          ZChatSource(sourceType: 'web', displayText: 'x'),
        ],
        attachments: const <ZChatAttachment>[
          ZChatAttachment(id: 'a', url: 'u', mimeType: 'm', fileName: 'f'),
        ],
        createdAt: DateTime.utc(2026, 7, 9, 10, 30),
        thinking: <ZChatThinkingStep>[
          ZChatThinkingStep(
            agent: 'planner',
            content: 'plan',
            timestamp: DateTime.utc(2026, 7, 9),
          ),
        ],
        suggestions: const <ZChatSuggestion>[
          ZChatSuggestion(id: 's', type: 'followUp', content: 'et après ?'),
        ],
        feedbackRating: ZChatFeedbackRating.down,
        feedbackCategory: ZChatFeedbackCategory.offTopic,
        feedbackComment: 'hors sujet',
        agentsCalled: const <String>['planner', 'writer'],
        confidence: const ZChatResponseConfidence(
          faithfulnessScore: 0.9,
          citationGuardStatus: 'ok',
          verifiedSourceCount: 2,
          totalSourceCount: 2,
        ),
        sourceFreshness: const <ZChatSourceFreshness>[
          ZChatSourceFreshness(datasetId: 'd1'),
        ],
        versionKey: 'prompt:x:3',
        extension: const _FauxExt('n'),
        extra: const <String, dynamic>{
          'cle_hote': <String, dynamic>{'imbrique': true},
        },
      );

      final ZChatMessage relu = ZChatMessage.fromMap(
        message.toMap(),
        extensionParser: _FauxExt.parse,
      );
      expect(relu, equals(message));
      expect(<Object>{relu, message}, hasLength(1));
    });

    test('message VIDE : `fromMap({})` ne lève pas et donne des défauts sûrs',
        () {
      final ZChatMessage m = ZChatMessage.fromMap(const <String, dynamic>{});
      expect(m.id, isNull);
      expect(m.isEphemeral, isTrue, reason: 'ZEntity : id null = éphémère');
      expect(m.conversationId, '');
      expect(m.role, ZChatRole.unknown);
      expect(m.contentBlocks, isEmpty);
      expect(m.sources, isNull);
      expect(m.createdAt, isNull);
      expect(m.extra, isEmpty);
    });

    test('`content` concatène les seuls ZTextBlock', () {
      const ZChatMessage m = ZChatMessage(
        contentBlocks: <ZContentBlock>[
          ZTextBlock(text: 'a'),
          ZAlertBlock(level: 'info', message: 'IGNORÉ'),
          ZTextBlock(text: 'b'),
        ],
      );
      expect(m.content, 'ab');
    });

    test('`copyWith` à SENTINELLE : omis conserve, `null` explicite efface', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'id': 'm',
        'version_key': 'v1',
        'feedback_comment': 'c',
        'created_at': '2026-07-09T00:00:00.000Z',
      });
      expect(m.copyWith(role: ZChatRole.user).versionKey, 'v1',
          reason: 'un champ OMIS doit être conservé');
      expect(m.copyWith(versionKey: null).versionKey, isNull,
          reason: 'un `null` EXPLICITE doit effacer');
      expect(m.copyWith(feedbackComment: null).feedbackComment, isNull);
      expect(m.copyWith(createdAt: null).createdAt, isNull);
      expect(m.copyWith(id: null).id, isNull);
    });
  });

  group('G10 — élément de liste illisible IGNORÉ, la liste survit', () {
    test('content_blocks / sources / thinking / suggestions / attachments', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'content_blocks': <dynamic>[
          <String, dynamic>{
            'type': 'text',
            'data': <String, dynamic>{'text': 'a'},
          },
          42,
          null,
          'chaine',
          <String, dynamic>{
            'type': 'text',
            'data': <String, dynamic>{'text': 'b'},
          },
        ],
        'sources': <dynamic>[
          <String, dynamic>{'source_type': 't'},
          42,
          null,
        ],
        'thinking': <dynamic>[
          <String, dynamic>{'agent': 'a'},
          null,
        ],
        'suggestions': <dynamic>[
          <String, dynamic>{'id': 's'},
          <dynamic>[],
        ],
        'attachments': <dynamic>[
          <String, dynamic>{'id': 'a'},
          42,
        ],
        'source_freshness': <dynamic>[
          <String, dynamic>{'dataset_id': 'd'},
          'zzz',
        ],
        'agents_called': <dynamic>['a', 42, null, 'b'],
      });
      expect(m.contentBlocks, hasLength(2));
      expect(m.content, 'ab');
      expect(m.sources, hasLength(1));
      expect(m.thinking, hasLength(1));
      expect(m.suggestions, hasLength(1));
      expect(m.attachments, hasLength(1));
      expect(m.sourceFreshness, hasLength(1));
      expect(m.agentsCalled, <String>['a', 'b']);
    });

    test('une liste absente reste `null` (≠ liste vide)', () {
      final ZChatMessage m = ZChatMessage.fromMap(const <String, dynamic>{});
      expect(m.sources, isNull);
      expect(m.toMap().containsKey('sources'), isFalse);

      final ZChatMessage vide =
          ZChatMessage.fromMap(<String, dynamic>{'sources': <dynamic>[]});
      expect(vide.sources, isEmpty);
      expect(vide.toMap()['sources'], isEmpty);
    });

    test('une liste au mauvais TYPE ⇒ `null`, aucun throw', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'content_blocks': 42,
        'sources': 'zzz',
      });
      expect(m.contentBlocks, isEmpty);
      expect(m.sources, isNull);
    });
  });

  group('G11 — `created_at` absent/corrompu : le parent SURVIT (D6)', () {
    test('absent ⇒ createdAt null, clé NON réémise', () {
      final ZChatMessage m =
          ZChatMessage.fromMap(<String, dynamic>{'id': 'm'});
      expect(m.createdAt, isNull);
      expect(m.id, 'm', reason: 'le message est décodé, pas détruit');
      expect(m.toMap().containsKey('created_at'), isFalse);
    });

    test('valeurs corrompues ⇒ aucun throw, message décodé', () {
      for (final Object? v in <Object?>[
        'pas-une-date',
        42,
        true,
        '',
        <String, dynamic>{},
      ]) {
        late final ZChatMessage m;
        expect(
          () => m = ZChatMessage.fromMap(
            <String, dynamic>{'id': 'm', 'created_at': v},
          ),
          returnsNormally,
          reason: 'valeur=$v',
        );
        expect(m.createdAt, isNull);
        expect(m.id, 'm');
      }
    });

    test('date valide ⇒ lue et réémise en ISO-8601', () {
      final ZChatMessage m = ZChatMessage.fromMap(
        <String, dynamic>{'created_at': '2026-07-09T10:30:00.000Z'},
      );
      expect(m.createdAt, DateTime.utc(2026, 7, 9, 10, 30));
      expect(m.toMap()['created_at'], '2026-07-09T10:30:00.000Z');
    });
  });

  group('G12 — AUCUNE clé de sync émise, sur AUCUNE voie', () {
    test('`toMap()` n\'émet ni `updated_at` ni `is_deleted`', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'id': 'm',
        'conversation_id': 'c',
        ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00.000Z',
        ZSyncMeta.kIsDeleted: true,
      });
      final Map<String, dynamic> encoded = m.toMap();
      expect(encoded.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(encoded.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(ZSyncMeta.collidingReservedKeys(encoded), isEmpty);
    });

    test('les clés du store n\'entrent PAS dans `extra` (fromMap)', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'id': 'm',
        ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00.000Z',
        ZSyncMeta.kIsDeleted: true,
        'zz_inconnue': 'gardee',
      });
      expect(m.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(m.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(m.extra['zz_inconnue'], 'gardee',
          reason: 'on ne passe pas la garde en VIDANT `extra` (AD-4)');
    });
  });

  group('G13 — `extra` : les TROIS voies d\'écriture sont étanches', () {
    test('(a) voie CTOR `const` — l\'ACCESSEUR filtre', () {
      const ZChatMessage m = ZChatMessage(
        id: 'm',
        extra: <String, dynamic>{
          ZSyncMeta.kIsDeleted: true,
          ZSyncMeta.kUpdatedAt: '1999-01-01T00:00:00.000Z',
          'zz_temoin': 'ok',
        },
      );
      expect(m.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse,
          reason: 'le ctor `const` ne peut RIEN filtrer : c\'est l\'accesseur '
              'qui porte la garde (zNormalizeExtra)');
      expect(m.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(m.extra['zz_temoin'], 'ok');
      expect(m.toMap().containsKey(ZSyncMeta.kIsDeleted), isFalse);
    });

    test('(b) voie `copyWith` — sanitisation EAGER', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{'id': 'm'});
      final ZChatMessage ecrit = m.copyWith(extra: <String, dynamic>{
        ZSyncMeta.kIsDeleted: true,
        ZSyncMeta.kUpdatedAt: '1999-01-01T00:00:00.000Z',
        'zz_temoin': 'ok',
      });
      expect(ecrit.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(ecrit.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(ecrit.extra['zz_temoin'], 'ok');
      expect(ecrit.toMap().containsKey(ZSyncMeta.kIsDeleted), isFalse);
      // Normalisation EAGER ⇒ le slot STOCKÉ est déjà propre ⇒ lecture SANS
      // COPIE. La retirer ferait copier à chaque lecture (assertion (i.3)).
      expect(identical(ecrit.extra, ecrit.extra), isTrue);
    });

    test('(b bis) la voie CTOR, elle, COPIE à la lecture (i.3 inverse)', () {
      const ZChatMessage m = ZChatMessage(
        extra: <String, dynamic>{ZSyncMeta.kIsDeleted: true, 'k': 1},
      );
      expect(identical(m.extra, m.extra), isFalse,
          reason: 'la copie PROUVE que l\'accesseur a réellement travaillé');
    });

    test('(c) égalité/hash PROFONDS d\'un `extra` IMBRIQUÉ', () {
      Map<String, dynamic> payload() => <String, dynamic>{
            'id': 'm',
            'zz_imbrique': <String, dynamic>{
              'a': 1,
              'l': <dynamic>[
                1,
                <String, dynamic>{'b': 2},
              ],
            },
          };
      // Deux décodages INDÉPENDANTS (aucune sous-`Map` partagée : `identical`
      // ne peut pas court-circuiter une égalité SUPERFICIELLE).
      final ZChatMessage a = ZChatMessage.fromMap(payload());
      final ZChatMessage b = ZChatMessage.fromMap(payload());
      expect(a.extra['zz_imbrique'], isA<Map<String, dynamic>>());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(<Object>{a, b}, hasLength(1),
          reason: 'un `Set` qui en garde DEUX = déduplication cassée');
    });

    test('`extra` est NON MODIFIABLE', () {
      final ZChatMessage m =
          ZChatMessage.fromMap(<String, dynamic>{'zz': 'x'});
      expect(() => m.extra['autre'] = 1, throwsUnsupportedError);
    });

    test('round-trip EXACT des clés inconnues, y compris imbriquées', () {
      final Map<String, dynamic> source = <String, dynamic>{
        'id': 'm',
        'conversation_id': 'c',
        'inconnu_plat': 'v',
        'inconnu_imbrique': <String, dynamic>{
          'x': <dynamic>[1, 2],
        },
      };
      final ZChatMessage m = ZChatMessage.fromMap(source);
      final Map<String, dynamic> encoded = m.toMap();
      expect(encoded['inconnu_plat'], 'v');
      expect(encoded['inconnu_imbrique'], <String, dynamic>{
        'x': <dynamic>[1, 2],
      });
      expect(ZChatMessage.fromMap(encoded), equals(m));
    });
  });

  group('G14 — slot `extension` défensif (AD-4/AD-10)', () {
    test('parseur injecté ⇒ extension TYPÉE, réémise', () {
      final ZChatMessage m = ZChatMessage.fromMap(
        <String, dynamic>{
          'extension': <String, dynamic>{'format_version': 1, 'note': 'n'},
        },
        extensionParser: _FauxExt.parse,
      );
      expect(m.extension, isA<_FauxExt>());
      expect(m.toMap()['extension'],
          <String, dynamic>{'format_version': 1, 'note': 'n'});
    });

    test('parseur ABSENT ⇒ payload PRÉSERVÉ (opaque), jamais détruit', () {
      final ZChatMessage m = ZChatMessage.fromMap(<String, dynamic>{
        'extension': <String, dynamic>{'format_version': 9, 'x': 1},
      });
      expect(m.extension, isNotNull);
      expect(m.toMap()['extension'],
          <String, dynamic>{'format_version': 9, 'x': 1});
    });

    test('parseur qui LÈVE ⇒ absorbé, message décodé (aucun throw)', () {
      late final ZChatMessage m;
      expect(
        () => m = ZChatMessage.fromMap(
          <String, dynamic>{
            'id': 'm',
            'extension': <String, dynamic>{'format_version': 1},
          },
          extensionParser: (Map<String, dynamic> json) =>
              throw StateError('parseur cassé'),
        ),
        returnsNormally,
      );
      expect(m.id, 'm');
      expect(m.extension, isNotNull,
          reason: 'le payload survit malgré le parseur défaillant');
    });

    test('payload non-`Map` ⇒ extension `null` (rien à préserver)', () {
      for (final Object? v in <Object?>[42, 'x', <dynamic>[], null]) {
        final ZChatMessage m =
            ZChatMessage.fromMap(<String, dynamic>{'extension': v});
        expect(m.extension, isNull, reason: 'valeur=$v');
        expect(m.toMap().containsKey('extension'), isFalse);
      }
    });
  });

  group('AC9 — clés persistées snake_case', () {
    test('le schéma émis est exactement celui attendu', () {
      final ZChatMessage m = ZChatMessage(
        id: 'm',
        conversationId: 'c',
        role: ZChatRole.user,
        createdAt: DateTime.utc(2026),
        feedbackRating: ZChatFeedbackRating.up,
        feedbackCategory: ZChatFeedbackCategory.offTopic,
        feedbackComment: 'x',
        agentsCalled: const <String>['a'],
        versionKey: 'v',
      );
      expect(
        m.toMap().keys.toSet(),
        <String>{
          'id',
          'conversation_id',
          'role',
          'content_blocks',
          'created_at',
          'feedback_rating',
          'feedback_category',
          'feedback_comment',
          'agents_called',
          'version_key',
        },
      );
      expect(m.toMap()['feedback_category'], 'offTopic',
          reason: 'AD-3 : valeurs d\'enum en camelCase en persistance');
    });
  });
}
