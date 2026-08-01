// CHAT-0 — AC10/AC11. Gardes **G1** (round-trip), **G12** (🔴 AUCUNE clé de
// sync émise — `last_message_at`, jamais `updated_at`) et **G13** (`extra`
// étanche sur les trois voies).
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('G1 — round-trip complet de la conversation', () {
    test('tous les champs survivent à fromMap(toMap())', () {
      final ZChatConversation c = ZChatConversation(
        id: 'c1',
        title: 'Ma conversation',
        createdAt: DateTime.utc(2026, 7, 1),
        lastMessageAt: DateTime.utc(2026, 7, 9, 10),
        messageCount: 12,
        pinned: true,
        pinnedAt: DateTime.utc(2026, 7, 5),
        extra: const <String, dynamic>{
          'folder_id': 'f',
          'imbrique': <String, dynamic>{'x': 1},
        },
      );
      final ZChatConversation relu = ZChatConversation.fromMap(c.toMap());
      expect(relu, equals(c));
      expect(<Object>{relu, c}, hasLength(1));
    });

    test('`fromMap({})` ne lève pas et donne des défauts sûrs', () {
      final ZChatConversation c =
          ZChatConversation.fromMap(const <String, dynamic>{});
      expect(c.id, isNull);
      expect(c.isEphemeral, isTrue);
      expect(c.title, '');
      expect(c.createdAt, isNull);
      expect(c.lastMessageAt, isNull);
      expect(c.messageCount, 0);
      expect(c.pinned, isFalse);
      expect(c.pinnedAt, isNull);
      expect(c.extra, isEmpty);
    });

    test('dates corrompues ⇒ `null`, la conversation SURVIT (AD-10)', () {
      final ZChatConversation c = ZChatConversation.fromMap(<String, dynamic>{
        'id': 'c',
        'created_at': 'pas-une-date',
        'last_message_at': 42,
        'pinned_at': true,
        'message_count': 'zzz',
        'pinned': 'zzz',
      });
      expect(c.id, 'c');
      expect(c.createdAt, isNull);
      expect(c.lastMessageAt, isNull);
      expect(c.pinnedAt, isNull);
      expect(c.messageCount, 0);
      expect(c.pinned, isFalse);
    });

    test('`copyWith` à SENTINELLE', () {
      final ZChatConversation c = ZChatConversation.fromMap(<String, dynamic>{
        'id': 'c',
        'title': 't',
        'last_message_at': '2026-07-09T00:00:00.000Z',
        'pinned_at': '2026-07-05T00:00:00.000Z',
      });
      expect(c.copyWith(title: 'autre').lastMessageAt, isNotNull,
          reason: 'un champ OMIS est conservé');
      expect(c.copyWith(lastMessageAt: null).lastMessageAt, isNull,
          reason: 'un `null` EXPLICITE efface');
      expect(c.copyWith(pinnedAt: null).pinnedAt, isNull);
      expect(c.copyWith(messageCount: 7).messageCount, 7);
    });
  });

  group('🔴 D3/G12 — `last_message_at`, JAMAIS `updated_at`', () {
    test('le champ métier de récence est persisté `last_message_at`', () {
      final ZChatConversation c = ZChatConversation(
        lastMessageAt: DateTime.utc(2026, 7, 9),
      );
      final Map<String, dynamic> encoded = c.toMap();
      expect(encoded[kZChatLastMessageAtKey], '2026-07-09T00:00:00.000Z');
      expect(encoded.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
    });

    test('`toMap()` n\'émet NI `updated_at` NI `is_deleted`, MÊME si la map '
        'source les portait', () {
      final ZChatConversation c = ZChatConversation.fromMap(<String, dynamic>{
        'id': 'c',
        'title': 't',
        ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00.000Z',
        ZSyncMeta.kIsDeleted: true,
      });
      final Map<String, dynamic> encoded = c.toMap();
      expect(encoded.containsKey(ZSyncMeta.kUpdatedAt), isFalse,
          reason: 'un `updated_at` métier dans le CORPS fausserait le merge '
              'Last-Write-Wins (AD-16/AD-19), silencieusement');
      expect(encoded.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(ZSyncMeta.collidingReservedKeys(encoded), isEmpty);
    });

    test('un `updated_at` du store n\'entre PAS dans `extra`', () {
      final ZChatConversation c = ZChatConversation.fromMap(<String, dynamic>{
        ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00.000Z',
        ZSyncMeta.kIsDeleted: true,
        'zz_inconnue': 'gardee',
      });
      expect(c.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(c.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(c.extra['zz_inconnue'], 'gardee');
    });

    test('AUCUN champ nommé `updatedAt` n\'est exposé', () {
      // Contrôle SÉMANTIQUE : la seule date de récence est `lastMessageAt`.
      // Le contrôle SYNTAXIQUE (grep négatif) est dans le naming guard.
      final ZChatConversation c = ZChatConversation(
        lastMessageAt: DateTime.utc(2026),
      );
      expect(c.toMap().keys.where((String k) => k.contains('updated')), isEmpty);
    });
  });

  group('G13 — `extra` : les TROIS voies d\'écriture sont étanches', () {
    test('(a) voie CTOR `const` — l\'ACCESSEUR filtre', () {
      const ZChatConversation c = ZChatConversation(
        id: 'c',
        extra: <String, dynamic>{
          ZSyncMeta.kIsDeleted: true,
          ZSyncMeta.kUpdatedAt: '1999-01-01T00:00:00.000Z',
          'zz_temoin': 'ok',
        },
      );
      expect(c.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(c.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(c.extra['zz_temoin'], 'ok');
      expect(c.toMap().containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(identical(c.extra, c.extra), isFalse,
          reason: 'la copie PROUVE que l\'accesseur a travaillé');
    });

    test('(b) voie `copyWith` — sanitisation EAGER (lecture zéro-copie)', () {
      final ZChatConversation c =
          ZChatConversation.fromMap(<String, dynamic>{'id': 'c'});
      final ZChatConversation ecrit = c.copyWith(extra: <String, dynamic>{
        ZSyncMeta.kIsDeleted: true,
        'zz_temoin': 'ok',
      });
      expect(ecrit.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(ecrit.extra['zz_temoin'], 'ok');
      expect(identical(ecrit.extra, ecrit.extra), isTrue);
    });

    test('(c) égalité/hash PROFONDS d\'un `extra` IMBRIQUÉ', () {
      Map<String, dynamic> payload() => <String, dynamic>{
            'id': 'c',
            'zz_imbrique': <String, dynamic>{
              'a': 1,
              'l': <dynamic>[
                1,
                <String, dynamic>{'b': 2},
              ],
            },
          };
      final ZChatConversation a = ZChatConversation.fromMap(payload());
      final ZChatConversation b = ZChatConversation.fromMap(payload());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(<Object>{a, b}, hasLength(1));
    });

    test('`extra` est NON MODIFIABLE', () {
      final ZChatConversation c =
          ZChatConversation.fromMap(<String, dynamic>{'zz': 1});
      expect(() => c.extra['x'] = 1, throwsUnsupportedError);
    });
  });

  group('AC10 — le scoping d\'hôte passe par `extra`, pas par le schéma', () {
    test('les champs IFFD survivent sans être connus du cœur', () {
      final ZChatConversation c = ZChatConversation.fromMap(<String, dynamic>{
        'id': 'c',
        'folderId': 'f1',
        'subFolderId': 's1',
        'isChatSession': true,
        'conversationSummary': 'résumé',
      });
      expect(c.extra['folderId'], 'f1');
      expect(c.extra['isChatSession'], isTrue);
      expect(ZChatConversation.fromMap(c.toMap()), equals(c));
    });
  });
}
