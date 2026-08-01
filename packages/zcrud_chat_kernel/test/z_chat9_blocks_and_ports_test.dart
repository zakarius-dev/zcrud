// CHAT-9 — gardes de COMPORTEMENT (aucune lecture de source : ce fichier doit
// tourner AUSSI sous `dart test -p node`, gate `web-determinism`).
//
// Trois familles :
//   G9-B* — parité du catalogue de blocs avec lex, et ce qu'on en refuse ;
//   G9-P* — ports de conversation (recherche / épinglage / partage / retrait) ;
//   G9-S* — chaîne de diffusion vocale.
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// 🔴 Le catalogue **LU** dans lex, transcrit une seule fois.
///
/// Source : `lex_douane/backend/app/services/agents/stream_handler.py:19-32`
/// (`VALID_BLOCK_TYPES`, 11 types) **plus** `Text`, que le client déclare et
/// que le serveur émet hors balise (`content_block.dart:18`). Total **12**.
///
/// La même liste est reproduite à l'identique dans le prompt d'écriture
/// (`backend/app/services/agents/prompts/writer.py:28-118`) — vérifié : aucun
/// type n'y apparaît qui ne soit dans `VALID_BLOCK_TYPES`.
const Set<String> kLexBlockCatalogue = <String>{
  'Text',
  'Sources',
  'Suggestions',
  'Flashcards',
  'MermaidDiagram',
  'Mindmap',
  'Table',
  'KeyDefinition',
  'LegalReference',
  'ComparisonTable',
  'Timeline',
  'Alert',
};

/// Les **trois refusés**, avec leur motif — cf. l'en-tête de
/// `z_content_block.dart`.
const Set<String> kRefusedBlockTypes = <String>{
  // douanier : `articles[]`/`source_type` sont du vocabulaire juridique.
  'LegalReference',
  // porterait `ZFlashcard` ⇒ arête `kernel → zcrud_flashcard` (AD-1 ROUGE).
  'Flashcards',
  // porterait `ZMindmap` ⇒ arête `kernel → zcrud_mindmap` (AD-1 ROUGE).
  'Mindmap',
};

Map<String, dynamic> _envelope(String type, [Map<String, dynamic>? data]) =>
    <String, dynamic>{'type': type, 'data': data ?? const <String, dynamic>{}};

void main() {
  group('G9-B1 — parité MESURÉE avec le catalogue de blocs de lex', () {
    test('les alias de lecture ∪ les refusés couvrent EXACTEMENT le catalogue',
        () {
      final Set<String> covered = <String>{
        ...kZContentBlockReadAliases.keys,
        ...kRefusedBlockTypes,
      };
      expect(covered, kLexBlockCatalogue,
          reason: '🔴 DIVERGENCE avec lex. Un type NOUVEAU chez lex doit être '
              'soit typé ici (alias de lecture), soit REFUSÉ explicitement '
              'avec son motif — jamais oublié en silence.\n'
              'manquants : ${kLexBlockCatalogue.difference(covered)}\n'
              'en trop   : ${covered.difference(kLexBlockCatalogue)}');
      // Non-vacuité : le catalogue n'est pas vide, et les deux ensembles sont
      // DISJOINTS (un type ne peut pas être à la fois typé et refusé).
      expect(kLexBlockCatalogue, hasLength(12));
      expect(
        kZContentBlockReadAliases.keys.toSet().intersection(kRefusedBlockTypes),
        isEmpty,
        reason: '🔴 un type à la fois typé ET refusé : la justification ment.',
      );
    });

    test('chaque type ACCEPTÉ décode vers un variant TYPÉ, jamais vers custom',
        () {
      for (final String lexType in kZContentBlockReadAliases.keys) {
        final ZContentBlock? block =
            ZContentBlock.fromJson(_envelope(lexType));
        expect(block, isNotNull, reason: '🔴 `$lexType` ne décode pas.');
        expect(block, isNot(isA<ZCustomContentBlock>()),
            reason: '🔴 `$lexType` retombe en bloc OUVERT : il est réputé '
                'typé mais la branche du `switch` a disparu. Le document se '
                'relit encore — il ne se rend plus.');
        expect(block!.kind, kZContentBlockReadAliases[lexType],
            reason: '🔴 discriminant canonique faux pour `$lexType`.');
      }
    });

    test('chaque type REFUSÉ traverse en `ZCustomContentBlock`, payload '
        'VERBATIM et round-trip exact', () {
      for (final String refused in kRefusedBlockTypes) {
        final Map<String, dynamic> payload = <String, dynamic>{
          'articles': <String>['12', '13'],
          'nested': <String, dynamic>{'k': 1},
        };
        final ZContentBlock? block =
            ZContentBlock.fromJson(_envelope(refused, payload));
        expect(block, isA<ZCustomContentBlock>(),
            reason: '🔴 `$refused` est entré au socle : c\'est une arête '
                'AD-1 ou du vocabulaire d\'hôte dans le noyau.');
        expect((block! as ZCustomContentBlock).payload, payload,
            reason: '🔴 payload MUTILÉ — un bloc inconnu doit être préservé, '
                'jamais réduit (le `TextBlock(text: json.toString())` de lex).');
        // Round-trip : ce qui est sorti se relit à l'identique.
        expect(ZContentBlock.fromJson(block.toJson()), block);
      }
    });

    test('un type INCONNU des deux côtés est préservé, jamais jeté ni '
        'transformé en texte', () {
      const Map<String, dynamic> payload = <String, dynamic>{'x': 1};
      final ZContentBlock? block =
          ZContentBlock.fromJson(_envelope('QuizCarousel', payload));
      expect(block, isA<ZCustomContentBlock>());
      expect((block! as ZCustomContentBlock).payload, payload);
      expect(block, isNot(isA<ZTextBlock>()),
          reason: '🔴 régression du défaut D5 : le bloc inconnu redevient une '
              'bulle de texte contenant le dump de la map.');
    });
  });

  group('G9-B2 — tout variant a un `accessibleText` non vide et localisable',
      () {
    test('chaque type du catalogue, MÊME vide, s\'annonce', () {
      for (final String lexType in kLexBlockCatalogue) {
        final ZContentBlock block =
            ZContentBlock.fromJson(_envelope(lexType))!;
        expect(block.accessibleText().trim(), isNotEmpty,
            reason: '🔴 `$lexType` est MUET : un bloc sans texte annonçable '
                'est invisible au lecteur d\'écran, sans que rien ne le dise.');
      }
    });

    // 🔴 **GARDE RETENDUE EN COURS DE LOT.** Le test ci-dessus, SEUL, ne mord
    // pas : le repli final d'`accessibleText` est le `kind` du bloc, donc un
    // variant dont `_accessibleParts` rendrait `<String>[]` resterait VERT en
    // annonçant « table ». On mesurait « ce n'est pas vide », pas « la donnée
    // est annoncée » — la bonne rigueur sur la mauvaise propriété.
    test('🔴 un bloc PORTEUR annonce sa DONNÉE, pas seulement son `kind`', () {
      const String needle = 'ZZSENTINELLEZZ';
      // Une charge utile qui remplit TOUS les champs textuels de la famille :
      // quel que soit le type, au moins un champ est peuplé.
      final Map<String, dynamic> payload = <String, dynamic>{
        'text': needle,
        'title': needle,
        'term': needle,
        'definition': needle,
        'message': needle,
        'code': needle,
        'level': needle,
        'headers': <String>[needle],
        'rows': <List<String>>[
          <String>[needle],
        ],
        'columns': <Map<String, dynamic>>[
          <String, dynamic>{'header': needle, 'values': <String>[needle]},
        ],
        'events': <Map<String, dynamic>>[
          <String, dynamic>{'date': needle, 'title': needle},
        ],
        'sources': <Map<String, dynamic>>[
          <String, dynamic>{'display_text': needle, 'source_type': needle},
        ],
        'suggestions': <Map<String, dynamic>>[
          <String, dynamic>{'content': needle},
        ],
      };
      for (final String lexType in kZContentBlockReadAliases.keys) {
        final ZContentBlock block =
            ZContentBlock.fromJson(_envelope(lexType, payload))!;
        expect(block.accessibleText(), contains(needle),
            reason: '🔴 `$lexType` n\'annonce PAS son contenu : il retombe sur '
                'son discriminant. Le lecteur d\'écran entend « ${block.kind} » '
                'à la place de la donnée — muet en pratique, vert en test.');
      }
    });

    test('le resolver d\'hôte prime pour TOUTE variante — la localisation '
        'reste possible sans forker le kernel', () {
      for (final String lexType in kLexBlockCatalogue) {
        final ZContentBlock block =
            ZContentBlock.fromJson(_envelope(lexType, <String, dynamic>{
          'text': 'brut',
          'message': 'brut',
          'code': 'brut',
        }))!;
        expect(
          block.accessibleText(resolver: (ZContentBlock b) => 'LOCALISÉ'),
          'LOCALISÉ',
          reason: '🔴 `$lexType` ignore le seam : sa prose est figée dans le '
              'socle, donc non traduisible.',
        );
      }
    });

    test('un resolver qui LÈVE ou rend du blanc ne rend pas le bloc muet', () {
      const ZContentBlock block = ZTextBlock(text: 'contenu');
      expect(
        block.accessibleText(resolver: (ZContentBlock b) => throw StateError('x')),
        'contenu',
      );
      expect(block.accessibleText(resolver: (ZContentBlock b) => '   '),
          'contenu');
    });
  });

  group('G9-P1 — recherche : « absent » et « zéro » ne sont PAS confondus', () {
    test('`matching_messages` ABSENT ⇒ null ; liste VIDE ⇒ [] ; la distinction '
        'survit au décodage', () {
      final ZChatConversationHit titleOnly = ZChatConversationHit.fromJson(
        <String, dynamic>{'id': 'c1', 'title': 't'},
      )!;
      expect(titleOnly.matchingMessages, isNull,
          reason: '🔴 « on n\'a pas cherché dans les messages » est devenu '
              '« on a cherché et n\'a rien trouvé » : deux affichages '
              'différents, un seul modèle.');
      expect(titleOnly.searchedMessages, isFalse);

      final ZChatConversationHit nullField = ZChatConversationHit.fromJson(
        <String, dynamic>{'id': 'c1', 'matching_messages': null},
      )!;
      expect(nullField.matchingMessages, isNull);

      final ZChatConversationHit searchedEmpty =
          ZChatConversationHit.fromJson(<String, dynamic>{
        'id': 'c1',
        'matching_messages': <Object?>[],
      })!;
      expect(searchedEmpty.matchingMessages, isEmpty);
      expect(searchedEmpty.searchedMessages, isTrue);

      // Et les deux ne sont PAS égaux — sinon la distinction serait cosmétique.
      expect(titleOnly, isNot(searchedEmpty));
    });

    test('un extrait sans identité de message est ÉCARTÉ (non navigable), '
        'les autres survivent', () {
      final ZChatConversationHit hit =
          ZChatConversationHit.fromJson(<String, dynamic>{
        'id': 'c1',
        'matching_messages': <Object?>[
          <String, dynamic>{'message_id': '', 'snippet': 'perdu'},
          'pas une map',
          <String, dynamic>{
            'message_id': 'm2',
            'role': 'assistant',
            'snippet': '…extrait…',
            'created_at': '2026-01-02T03:04:05.000Z',
          },
        ],
      })!;
      expect(hit.matchingMessages, hasLength(1));
      expect(hit.matchingMessages!.single.messageId, 'm2');
      expect(hit.matchingMessages!.single.role, ZChatRole.assistant);
      expect(hit.matchingMessages!.single.createdAt, isNotNull);
    });

    test('🔴 AD-19.1 — les clés RÉSERVÉES et les extraits ne polluent PAS '
        '`extra` de la conversation trouvée', () {
      final ZChatConversationHit hit =
          ZChatConversationHit.fromJson(<String, dynamic>{
        'id': 'c1',
        'title': 't',
        // clés de sync réservées (le gate `reserved-keys` a rougi sur cet
        // oubli exact dans ce paquet)
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
        // donnée de RÉSULTAT, pas de conversation
        kZChatMatchingMessagesKey: <Object?>[
          <String, dynamic>{'message_id': 'm1'},
        ],
        // vraie clé d'hôte : elle, doit survivre
        'folder_id': 'f9',
      })!;
      for (final String reserved in ZSyncMeta.reservedKeys) {
        expect(hit.conversation.extra.containsKey(reserved), isFalse,
            reason: '🔴 `$reserved` est entré dans `extra` : le corps métier '
                'porterait l\'autorité de synchronisation, et le merge '
                'Last-Write-Wins serait faussé SANS aucun test rouge.');
      }
      expect(hit.conversation.extra.containsKey(kZChatMatchingMessagesKey),
          isFalse,
          reason: '🔴 les extraits de recherche sont collés sur la '
              'conversation : elle repartirait en persistance avec eux.');
      expect(hit.conversation.extra['folder_id'], 'f9',
          reason: '🔴 le nettoyage est trop large : une clé d\'hôte a été '
              'perdue.');
      expect(hit.conversation.toMap().containsKey(kZChatMatchingMessagesKey),
          isFalse);
      expect(hit.matchingMessages, hasLength(1));
    });

    test('décodage TOTAL — aucune forme ne lève (AD-10)', () {
      expect(ZChatConversationHit.fromJson(null), isNull);
      expect(ZChatConversationHit.fromJson('texte'), isNull);
      expect(ZChatMessageSnippet.fromJson(const <String, dynamic>{}), isNull);
      expect(ZChatShareLink.fromJson(const <String, dynamic>{}), isNull);
    });

    test('la longueur minimale est CONSULTABLE, jamais imposée', () {
      const ZChatConversationQuery short = ZChatConversationQuery(text: 'a');
      expect(short.meetsMinimumLength, isFalse);
      expect(const ZChatConversationQuery(text: 'ab').meetsMinimumLength, isTrue);
      // Le défaut mesuré chez lex : messages NON inclus, limite 20.
      expect(short.includeMessages, isFalse);
      expect(short.limit, kZChatSearchDefaultLimit);
    });
  });

  group('G9-P2 — partage : une expiration INCONNUE n\'est pas une expiration',
      () {
    final DateTime now = DateTime.utc(2026, 8, 1);

    test('`expiresAt` null ⇒ jamais réputé expiré', () {
      const ZChatShareLink link = ZChatShareLink(shareId: 's1');
      expect(link.isExpiredAt(now), isFalse,
          reason: '🔴 « je ne sais pas » est devenu « c\'est expiré » : un '
              'lien fonctionnel disparaîtrait de l\'interface.');
    });

    test('expiration connue : passée ⇒ expiré, future ⇒ valide', () {
      expect(
        ZChatShareLink(
          shareId: 's',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ).isExpiredAt(now),
        isTrue,
      );
      expect(
        ZChatShareLink(
          shareId: 's',
          expiresAt: now.add(const Duration(days: 7)),
        ).isExpiredAt(now),
        isFalse,
      );
    });

    test('round-trip du lien, `share_url` optionnel compris', () {
      final ZChatShareLink link = ZChatShareLink(
        shareId: 'abc',
        url: '/shared/abc',
        expiresAt: now,
      );
      expect(ZChatShareLink.fromJson(link.toJson()), link);
      const ZChatShareLink bare = ZChatShareLink(shareId: 'abc');
      expect(bare.toJson().containsKey('share_url'), isFalse,
          reason: '🔴 une URL absente ne doit pas être persistée en chaîne '
              'vide — c\'est un lien mort qui se lit comme un lien.');
      expect(ZChatShareLink.fromJson(bare.toJson()), bare);
    });
  });

  group('G9-S1 — chaîne de diffusion vocale : le repli est une DONNÉE', () {
    test('le premier maillon DISPONIBLE qui réussit sert, et les suivants ne '
        'sont pas touchés', () async {
      final _FakeSpeech a = _FakeSpeech('localCache', available: false);
      final _FakeSpeech b = _FakeSpeech('backendStream');
      final _FakeSpeech c = _FakeSpeech('onDeviceTts');
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[a, b, c]);

      final ZResult<ZChatSpeechDelivery> result =
          await chain.speak(const ZChatSpeechRequest(text: 'bonjour'));

      expect(result.isRight(), isTrue);
      final ZChatSpeechDelivery delivery =
          result.getOrElse(() => throw StateError('unreachable'));
      expect(delivery.sourceKind, 'backendStream');
      expect(a.spokeCount, 0, reason: '🔴 un maillon INDISPONIBLE a été '
          'sollicité : c\'est l\'appel plateforme qu\'`isAvailable` existe '
          'pour éviter.');
      expect(c.spokeCount, 0);
      expect(delivery.attempts, isEmpty);
    });

    test('🔴 les échecs des maillons intermédiaires sont CONSERVÉS — c\'est ce '
        'que lex jette dans un `debugPrint`', () async {
      final _FakeSpeech a = _FakeSpeech('localCache', failure: 'cache miss');
      final _FakeSpeech b = _FakeSpeech('backendStream', failure: 'HTTP 503');
      final _FakeSpeech c = _FakeSpeech('onDeviceTts');
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[a, b, c]);

      final ZChatSpeechDelivery delivery = (await chain.speak(
        const ZChatSpeechRequest(text: 'bonjour'),
      )).getOrElse(() => throw StateError('unreachable'));

      expect(delivery.sourceKind, 'onDeviceTts');
      expect(delivery.attempts.map((ZFailure f) => f.message),
          <String>['cache miss', 'HTTP 503']);
    });

    test('un maillon qui LÈVE devient un échec ordinaire, la chaîne continue '
        '(AD-10)', () async {
      final _FakeSpeech a = _FakeSpeech('localCache', throws: true);
      final _FakeSpeech b = _FakeSpeech('onDeviceTts');
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[a, b]);
      final ZChatSpeechDelivery delivery = (await chain.speak(
        const ZChatSpeechRequest(text: 'bonjour'),
      )).getOrElse(() => throw StateError('unreachable'));
      expect(delivery.sourceKind, 'onDeviceTts');
      expect(delivery.attempts, hasLength(1));
    });

    test('un `isAvailable` qui LÈVE vaut « indisponible », jamais une panne',
        () async {
      final _FakeSpeech a = _FakeSpeech('localCache', throwsAvailability: true);
      final _FakeSpeech b = _FakeSpeech('onDeviceTts');
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[a, b]);
      expect(await chain.isAvailable(), isTrue);
      final ZChatSpeechDelivery delivery = (await chain.speak(
        const ZChatSpeechRequest(text: 'x'),
      )).getOrElse(() => throw StateError('unreachable'));
      expect(delivery.sourceKind, 'onDeviceTts');
      expect(delivery.attempts, isEmpty,
          reason: '🔴 un maillon INDISPONIBLE a produit un échec : le journal '
              'de diagnostic se remplirait de faux positifs.');
    });

    test('AUCUN maillon disponible ⇒ `ZUnsupportedOperationFailure` (type '
        'EXISTANT), pas une nouvelle famille', () async {
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[
        _FakeSpeech('a', available: false),
      ]);
      expect(await chain.isAvailable(), isFalse);
      final ZResult<ZChatSpeechDelivery> result =
          await chain.speak(const ZChatSpeechRequest(text: 'x'));
      expect(result.fold((ZFailure f) => f, (_) => null),
          isA<ZUnsupportedOperationFailure>());
    });

    test('tous les maillons échouent ⇒ le DERNIER échec remonte', () async {
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[
        _FakeSpeech('a', failure: 'premier'),
        _FakeSpeech('b', failure: 'dernier'),
      ]);
      final ZFailure? failure = (await chain.speak(
        const ZChatSpeechRequest(text: 'x'),
      )).fold((ZFailure f) => f, (_) => null);
      expect(failure!.message, 'dernier');
    });

    test('un texte VIDE ne touche AUCUN maillon', () async {
      final _FakeSpeech a = _FakeSpeech('a');
      final ZChatSpeechChain chain = ZChatSpeechChain(<ZChatSpeechPort>[a]);
      final ZResult<ZChatSpeechDelivery> result =
          await chain.speak(const ZChatSpeechRequest(text: '   '));
      expect(result.isLeft(), isTrue);
      expect(a.availabilityCount, 0);
      expect(a.spokeCount, 0);
    });

    test('`stop` arrête TOUS les maillons, même si l\'un d\'eux lève',
        () async {
      final _FakeSpeech a = _FakeSpeech('a', throwsOnStop: true);
      final _FakeSpeech b = _FakeSpeech('b');
      await ZChatSpeechChain(<ZChatSpeechPort>[a, b]).stop();
      expect(b.stopCount, 1,
          reason: '🔴 un maillon qui lève à l\'arrêt laisse les suivants en '
              'train de parler par-dessus.');
    });

    test('`ofMessage` RÉUTILISE le résumé annonçable du kernel — un tableau '
        'est lu, pas sauté', () {
      const ZChatMessage message = ZChatMessage(
        conversationId: 'c',
        contentBlocks: <ZContentBlock>[
          ZTextBlock(text: 'intro'),
          ZTableBlock(
            headers: <String>['a', 'b'],
            rows: <List<String>>[
              <String>['1', '2'],
            ],
          ),
        ],
      );
      final ZChatSpeechRequest request = ZChatSpeechRequest.ofMessage(message);
      expect(request.text, zChatAccessibleTextOf(message.contentBlocks),
          reason: '🔴 un SECOND aplatissement a été écrit : c\'est le défaut '
              'exact que CHAT-3b avait fermé côté a11y.');
      expect(request.text, contains('1, 2'));
      expect(request.languageTag, isNull,
          reason: '🔴 une langue par défaut a été INVENTÉE — le socle choisit '
              'la voix de l\'utilisateur à la place de l\'hôte.');
    });
  });
}

class _FakeSpeech implements ZChatSpeechPort {
  _FakeSpeech(
    this.sourceKind, {
    this.available = true,
    this.failure,
    this.throws = false,
    this.throwsAvailability = false,
    this.throwsOnStop = false,
  });

  @override
  final String sourceKind;
  final bool available;
  final String? failure;
  final bool throws;
  final bool throwsAvailability;
  final bool throwsOnStop;

  int availabilityCount = 0;
  int spokeCount = 0;
  int stopCount = 0;
  ZChatSpeechRequest? lastRequest;

  @override
  Future<bool> isAvailable() async {
    availabilityCount++;
    if (throwsAvailability) throw StateError('plugin absent');
    return available;
  }

  @override
  Future<ZResult<ZChatSpeechDelivery>> speak(ZChatSpeechRequest request) async {
    spokeCount++;
    lastRequest = request;
    if (throws) throw StateError('moteur cassé');
    if (failure != null) {
      return Left<ZFailure, ZChatSpeechDelivery>(ZServerFailure(failure!));
    }
    return Right<ZFailure, ZChatSpeechDelivery>(
      ZChatSpeechDelivery(sourceKind: sourceKind),
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (throwsOnStop) throw StateError('arrêt impossible');
  }
}
