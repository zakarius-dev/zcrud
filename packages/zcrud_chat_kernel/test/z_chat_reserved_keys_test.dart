// Clés réservées de synchronisation (AD-19.1) sur les slots `extra` concrets
// du notebook et des outils : `ZChatArtifactVerb`, `ZChatArtifactDeclaration`,
// `ZChatArtifactGenerationRequest`, `ZChatArtifactContent`, `ZChatToolEntry`.
//
// Chaque test décode (ou construit) un `extra` POLLUÉ par `updated_at`,
// `is_deleted` et une clé propre du type, puis vérifie que :
//   (a) l'accesseur `extra` ne rend aucune de ces clés ;
//   (b) `toJson` ne les réémet pas (le merge Last-Write-Wins, AD-9, n'est pas
//       faussé) ;
//   (c) une clé ordinaire survit à l'aller-retour (AD-4 non régressé).
//
// R3 : retirer `...ZSyncMeta.reservedKeys` d'un `_reservedKeys`, ou remplacer
// `zSanitizeExtra` par `Map.unmodifiable`, fait rougir le test du type par
// assertion (b) puis (a).
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

const Map<String, dynamic> _polluted = <String, dynamic>{
  'host': 'kept',
  ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00Z',
  ZSyncMeta.kIsDeleted: true,
  'key': 'smuggled',
};

void _expectClean(Map<String, dynamic> extra) {
  expect(extra, <String, dynamic>{'host': 'kept'});
  expect(extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
  expect(extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
  expect(extra.containsKey('key'), isFalse);
}

void main() {
  group('AD-19.1 — clés réservées retirées des slots extra', () {
    test('ZChatArtifactVerb : fromJson/toJson ne réémettent pas les clés', () {
      final ZChatArtifactVerb verb = ZChatArtifactVerb.fromJson(
        <String, dynamic>{
          'key': 'open',
          'availability': 'whenPresent',
          'extra': _polluted,
        },
      )!;
      _expectClean(verb.extra);
      final Map<String, dynamic> out = verb.toJson();
      expect(out['key'], 'open');
      expect(out['extra'], <String, dynamic>{'host': 'kept'});
      // Voie constructeur : même garde.
      _expectClean(ZChatArtifactVerb(
        key: 'x',
        availability: ZChatArtifactVerbAvailability.whenAbsent,
        extra: _polluted,
      ).extra);
      // Un `extra` propre est rendu sans copie.
      expect(identical(verb.extra, verb.extra), isTrue);
    });

    test('ZChatArtifactDeclaration : fromJson/toJson ne réémettent pas', () {
      final ZChatArtifactDeclaration decl = ZChatArtifactDeclaration.fromJson(
        <String, dynamic>{
          'key': 'mindmap',
          'extra': <String, dynamic>{..._polluted, 'verbs': 'smuggled'},
        },
      )!;
      _expectClean(decl.extra);
      expect(decl.extra.containsKey('verbs'), isFalse);
      final Map<String, dynamic> out = decl.toJson();
      expect(out['key'], 'mindmap');
      expect(out['extra'], <String, dynamic>{'host': 'kept'});
      _expectClean(ZChatArtifactDeclaration(key: 'x', extra: _polluted).extra);
      expect(identical(decl.extra, decl.extra), isTrue);
    });

    test('ZChatArtifactGenerationRequest : constructeur et copyWith', () {
      // Ce type n'a pas de `toJson` : seules les clés de sync sont réservées ;
      // `key` n'est PAS une clé propre de la requête et doit survivre.
      final ZChatArtifactGenerationRequest req = ZChatArtifactGenerationRequest(
        messageId: 'm',
        artifactKey: 'a',
        notes: 'n',
        extra: _polluted,
      );
      expect(req.extra, <String, dynamic>{'host': 'kept', 'key': 'smuggled'});
      expect(req.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(req.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      final ZChatArtifactGenerationRequest copy = req.copyWith(
        extra: <String, dynamic>{'other': 2, ZSyncMeta.kIsDeleted: true},
      );
      expect(copy.extra, <String, dynamic>{'other': 2});
      // L'égalité lit l'`extra` filtré : pollué == propre.
      expect(
        req,
        ZChatArtifactGenerationRequest(
          messageId: 'm',
          artifactKey: 'a',
          notes: 'n',
          extra: const <String, dynamic>{'host': 'kept', 'key': 'smuggled'},
        ),
      );
      expect(identical(req.extra, req.extra), isTrue);
    });

    test('ZChatArtifactContent : constructeur', () {
      final ZChatArtifactContent content =
          ZChatArtifactContent('data', extra: _polluted);
      expect(content.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(content.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(content.extra['host'], 'kept');
      expect(
        content,
        ZChatArtifactContent(
          'data',
          extra: const <String, dynamic>{'host': 'kept', 'key': 'smuggled'},
        ),
      );
    });

    test('ZChatToolEntry : fromJson/toJson ne réémettent pas les clés', () {
      final ZChatToolEntry entry = ZChatToolEntry.fromJson(<String, dynamic>{
        'key': 'tool',
        'state': const ZChatToggleState(value: true).toJson(),
        'extra': <String, dynamic>{..._polluted, 'state': 'smuggled'},
      })!;
      _expectClean(entry.extra);
      expect(entry.extra.containsKey('state'), isFalse);
      final Map<String, dynamic> out = entry.toJson();
      expect(out['key'], 'tool');
      expect(out['extra'], <String, dynamic>{'host': 'kept'});
      // `_copy` (withState/cleared/reset) repasse par la garde.
      _expectClean(entry.cleared().extra);
      _expectClean(ZChatToolEntry(
        key: 'x',
        state: const ZChatToggleState(),
        extra: _polluted,
      ).extra);
      expect(identical(entry.extra, entry.extra), isTrue);
    });

    test('un extra sans clé réservée est rendu tel quel (pas de copie)', () {
      const Map<String, dynamic> clean = <String, dynamic>{'a': 1, 'b': 'c'};
      expect(
        ZChatArtifactVerb.fromJson(<String, dynamic>{
          'key': 'k',
          'extra': clean,
        })!
            .toJson()['extra'],
        clean,
      );
      expect(
        ZChatToolEntry(
          key: 'k',
          state: const ZChatToggleState(),
          extra: clean,
        ).toJson()['extra'],
        clean,
      );
    });
  });
}
