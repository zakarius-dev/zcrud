// CHAT-0 — AC6. Gardes **G1** (round-trip), **G8** (`ZSourceRegistry` RÉUTILISÉ,
// jamais doublé) et **G9** (fail-safe `isVerified`/`usageStatus`).
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('G1 — round-trip complet de la forme commune', () {
    test('les 10 champs + payload survivent à fromJson(toJson())', () {
      const ZChatSource source = ZChatSource(
        sourceType: 'web',
        displayText: 'Exemple',
        relevanceScore: 0.42,
        verified: true,
        verificationStatus: 'verified',
        snippet: 'un extrait',
        breadcrumb: 'a > b > c',
        ranker: 'bm25',
        corpus: 'corpus-1',
        usageStatusRaw: 'consulted',
        payload: <String, dynamic>{
          'code_id': 'x',
          'nested': <String, dynamic>{'k': 1},
        },
      );
      final ZChatSource? relu = ZChatSource.fromJson(source.toJson());
      expect(relu, equals(source));
      expect(<Object>{relu!, source}, hasLength(1));
    });

    test('chaque champ discret compte (sonde de mordant)', () {
      // Si `snippet` disparaissait de `toJson`, ces deux sources deviendraient
      // indiscernables au round-trip : la garde ci-dessus rougirait.
      expect(
        const ZChatSource(sourceType: 't', snippet: 'a'),
        isNot(const ZChatSource(sourceType: 't')),
      );
      expect(
        const ZChatSource(sourceType: 't', breadcrumb: 'a'),
        isNot(const ZChatSource(sourceType: 't')),
      );
      expect(
        const ZChatSource(sourceType: 't', ranker: 'a'),
        isNot(const ZChatSource(sourceType: 't')),
      );
      expect(
        const ZChatSource(sourceType: 't', corpus: 'a'),
        isNot(const ZChatSource(sourceType: 't')),
      );
      expect(
        const ZChatSource(sourceType: 't', relevanceScore: 0.1),
        isNot(const ZChatSource(sourceType: 't')),
      );
    });

    test('égalité PROFONDE du payload (JSON imbriqué)', () {
      final ZChatSource? a = ZChatSource.fromJson(<String, dynamic>{
        'source_type': 't',
        'meta': <String, dynamic>{
          'l': <dynamic>[
            1,
            <String, dynamic>{'b': 2},
          ],
        },
      });
      final ZChatSource? b = ZChatSource.fromJson(<String, dynamic>{
        'source_type': 't',
        'meta': <String, dynamic>{
          'l': <dynamic>[
            1,
            <String, dynamic>{'b': 2},
          ],
        },
      });
      expect(a, equals(b));
      expect(<Object>{a!, b!}, hasLength(1));
    });
  });

  group('AC6 — lecture défensive (AD-10)', () {
    test('raw non-map ⇒ null ; map vide ⇒ défauts sûrs', () {
      expect(ZChatSource.fromJson(null), isNull);
      expect(ZChatSource.fromJson(42), isNull);
      final ZChatSource? vide = ZChatSource.fromJson(<String, dynamic>{});
      expect(vide, isNotNull);
      expect(vide!.sourceType, '');
      expect(vide.relevanceScore, 0.0);
      expect(vide.verified, isNull);
    });

    test('`verified` tolère bool / num / chaîne (porté de lex)', () {
      ZChatSource read(Object? v) => ZChatSource.fromJson(
            <String, dynamic>{'source_type': 't', 'verified': v},
          )!;
      expect(read(true).verified, isTrue);
      expect(read(1).verified, isTrue);
      expect(read(0).verified, isFalse);
      expect(read('true').verified, isTrue);
      expect(read('false').verified, isFalse);
      expect(read('zzz').verified, isNull);
    });
  });

  group('G9 — fail-safe : ne JAMAIS présumer « vérifié »', () {
    test('`verified: true` SANS `verification_status` ⇒ isVerified == false',
        () {
      final ZChatSource s = ZChatSource.fromJson(<String, dynamic>{
        'source_type': 't',
        'verified': true,
      })!;
      expect(s.verified, isTrue, reason: 'le drapeau brut est bien porté');
      expect(s.isVerified, isFalse,
          reason: 'seul `verification_status == "verified"` fait autorité');
    });

    test('`not_applicable` / `pass-through` / null ⇒ isVerified == false', () {
      for (final String? statut in <String?>[
        null,
        'not_applicable',
        'pass-through',
        '',
      ]) {
        final Map<String, dynamic> doc = <String, dynamic>{'source_type': 't'};
        if (statut != null) doc['verification_status'] = statut;
        final ZChatSource s = ZChatSource.fromJson(doc)!;
        expect(s.isVerified, isFalse, reason: 'statut=$statut');
      }
    });

    test('`verified` (le statut) ⇒ isVerified == true', () {
      final ZChatSource s = ZChatSource.fromJson(<String, dynamic>{
        'source_type': 't',
        'verification_status': 'verified',
      })!;
      expect(s.isVerified, isTrue);
    });

    test('usageStatus : défaut `cited`, alias lex reconnu, brut préservé', () {
      expect(
        ZChatSource.fromJson(<String, dynamic>{'source_type': 't'})!.usageStatus,
        ZChatSourceUsageStatus.cited,
      );
      expect(
        ZChatSource.fromJson(<String, dynamic>{
          'source_type': 't',
          'usage_status': 'zzz',
        })!
            .usageStatus,
        ZChatSourceUsageStatus.cited,
      );
      final ZChatSource s = ZChatSource.fromJson(<String, dynamic>{
        'source_type': 't',
        'usage_status': 'general_knowledge',
      })!;
      expect(s.usageStatus, ZChatSourceUsageStatus.generalKnowledge);
      expect(s.usageStatusRaw, 'general_knowledge',
          reason: 'la valeur BRUTE fait un round-trip sans perte');
    });
  });

  group('G8 — `ZSourceRegistry` RÉUTILISÉ (aucun second registre)', () {
    ZSourceRegistry buildRegistry() => ZSourceRegistry()
      ..register(
        'tec',
        fromJson: (Map<String, dynamic> json) => <String, dynamic>{
          'tec_id': json['tec_id'],
          'reconstruit_par_app': true,
        },
        toJson: (Object value) => <String, dynamic>{
          ...(value as Map<String, dynamic>),
          'reencode_par_app': true,
        },
      );

    test('un `source_type` enregistré est reconstruit par SON codec', () {
      final ZSourceRegistry registry = buildRegistry();
      final ZChatSource s = ZChatSource.fromJson(
        <String, dynamic>{
          'source_type': 'tec',
          'display_text': 'TEC',
          'tec_id': '0102',
        },
        registry: registry,
      )!;
      expect(s.payload['reconstruit_par_app'], isTrue,
          reason: 'le registre INJECTÉ n\'a pas été consulté');
      expect(s.payload['tec_id'], '0102');
      expect(s.toJson(registry: registry)['reencode_par_app'], isTrue);
    });

    test('SANS registre injecté, le payload reste VERBATIM', () {
      final ZChatSource s = ZChatSource.fromJson(<String, dynamic>{
        'source_type': 'tec',
        'tec_id': '0102',
      })!;
      expect(s.payload, <String, dynamic>{'tec_id': '0102'});
      expect(s.payload.containsKey('reconstruit_par_app'), isFalse);
    });

    test('un `source_type` INCONNU du registre conserve son payload', () {
      final ZSourceRegistry registry = buildRegistry();
      final ZChatSource s = ZChatSource.fromJson(
        <String, dynamic>{'source_type': 'inconnu', 'foo': 'bar'},
        registry: registry,
      )!;
      expect(s.payload, <String, dynamic>{'foo': 'bar'});
    });

    test('un codec d\'app qui LÈVE est absorbé (repli verbatim)', () {
      final ZSourceRegistry registry = ZSourceRegistry()
        ..register(
          'boom',
          fromJson: (Map<String, dynamic> json) => throw StateError('x'),
          toJson: (Object value) => throw StateError('x'),
        );
      late final ZChatSource? s;
      expect(
        () => s = ZChatSource.fromJson(
          <String, dynamic>{'source_type': 'boom', 'foo': 'bar'},
          registry: registry,
        ),
        returnsNormally,
      );
      expect(s!.payload, <String, dynamic>{'foo': 'bar'});
      expect(() => s!.toJson(registry: registry), returnsNormally);
    });

    test('`payload` est NON MODIFIABLE', () {
      final ZChatSource s =
          ZChatSource.fromJson(<String, dynamic>{'source_type': 't', 'a': 1})!;
      expect(() => s.payload['b'] = 2, throwsUnsupportedError);
    });
  });
}
