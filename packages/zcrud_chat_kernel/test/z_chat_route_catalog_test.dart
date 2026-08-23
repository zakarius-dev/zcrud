// Comportement du catalogue assemblé (`domain/route/catalog/`) :
//   G-RC2 décodeur (rejet d'un élément, jamais de la liste ; enveloppe ou
//         liste nue ; replis en chaîne seule ; clé inconnue → extra ;
//         `updated_at` retiré ; formes camel/snake et paires à suffixe) ;
//   G-RC3 cache TTL (horloge injectée, compteur d'appels, invalidation
//         ciblée / totale, entrée périmée servie sur panne, cache négatif) ;
//   G-RC4 repli DÉCLARÉ seulement (sinon `Left(ZNotFoundFailure)`) ;
//   G-RC5 `Left` distant ⇒ source suivante, `Left(ZCacheFailure)` ⇒ repropagé ;
//   G-RC6 dépôt mémoire ≡ sémantique documentaire ;
//   invalidation du catalogue après écriture réussie.
//
// R3 : chaque test nomme dans son titre ce qu'il casse si la règle est
// retirée ; les injections rejouées sont consignées dans le rapport du lot.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

ZChatRouter _r(String id, {bool active = true, String? tier, String? name}) =>
    ZChatRouter(id: id, isActive: active, tier: tier, name: name);

/// Source **espionne** : réponses scriptées par identité, appels comptés.
class _Spy implements ZChatRouteCatalogSource {
  _Spy({
    Map<String, ZResult<ZChatRouter?>> byId = const {},
    ZResult<List<ZChatRouter>>? all,
    ZResult<ZChatRouter?>? otherwise,
  }) : _byId = Map<String, ZResult<ZChatRouter?>>.of(byId),
       _all = all ?? const Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[]),
       _otherwise = otherwise ?? const Right<ZFailure, ZChatRouter?>(null);

  final Map<String, ZResult<ZChatRouter?>> _byId;
  ZResult<List<ZChatRouter>> _all;
  final ZResult<ZChatRouter?> _otherwise;
  final List<String> fetched = <String>[];
  int listed = 0;

  void script(String id, ZResult<ZChatRouter?> result) => _byId[id] = result;
  set all(ZResult<List<ZChatRouter>> v) => _all = v;

  int calls(String id) => fetched.where((String x) => x == id).length;

  @override
  Future<ZResult<ZChatRouter?>> fetchRouter(String id) async {
    fetched.add(id);
    return _byId[id] ?? _otherwise;
  }

  @override
  Future<ZResult<List<ZChatRouter>>> fetchAll() async {
    listed++;
    return _all;
  }
}

/// Catalogue espion : enregistre les invalidations.
class _CatalogSpy implements ZChatRouteCatalogPort {
  final List<String?> invalidated = <String?>[];
  @override
  Future<ZResult<ZChatRouter>> resolveRouter(String id) async =>
      const Left<ZFailure, ZChatRouter>(ZDomainFailure('unused'));
  @override
  Future<ZResult<List<ZChatRouter>>> listRouters() async =>
      const Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[]);
  @override
  Future<void> invalidate([String? id]) async => invalidated.add(id);
}

/// Dépôt lecture seule scripté (sans `ZDelegatesSearch`).
class _ReadOnlyRepo implements ZReadOnlyRepository<ZChatRouter> {
  _ReadOnlyRepo({required this.byId, required this.all});
  final ZResult<ZChatRouter> Function(String id) byId;
  final ZResult<List<ZChatRouter>> all;
  final List<ZDataRequest?> requests = <ZDataRequest?>[];
  @override
  Stream<List<ZChatRouter>> watchAll() => const Stream.empty();
  @override
  Stream<List<ZChatRouter>> watch(ZDataRequest request) => const Stream.empty();
  @override
  Future<ZResult<List<ZChatRouter>>> getAll({ZDataRequest? request}) async {
    requests.add(request);
    return all;
  }

  @override
  Future<ZResult<ZChatRouter>> getById(String id) async => byId(id);
  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      const Right<ZFailure, int>(0);
}

/// Dépôt complet NON délégant, par-dessus le dépôt mémoire.
class _ServingRepo implements ZRepository<ZChatRouter> {
  _ServingRepo(this.inner);
  final ZChatInMemoryRouterRepository inner;
  @override
  Stream<List<ZChatRouter>> watchAll() => inner.watchAll();
  @override
  Stream<List<ZChatRouter>> watch(ZDataRequest request) => inner.watch(request);
  @override
  Future<ZResult<List<ZChatRouter>>> getAll({ZDataRequest? request}) =>
      inner.getAll(request: request);
  @override
  Future<ZResult<ZChatRouter>> getById(String id) => inner.getById(id);
  @override
  Future<ZResult<int>> count({ZDataRequest? request}) =>
      inner.count(request: request);
  @override
  Future<ZResult<ZChatRouter>> save(ZChatRouter item, {String? collectionId}) =>
      inner.save(item, collectionId: collectionId);
  @override
  Future<ZResult<Unit>> softDelete(String id) => inner.softDelete(id);
  @override
  Future<ZResult<Unit>> restore(String id) => inner.restore(id);
  @override
  void dispose() => inner.dispose();
}

/// Une map qui LÈVE dès qu'on l'itère — l'élément « qui lève ».
class _ExplodingMap extends MapBase<String, dynamic> {
  @override
  Iterable<String> get keys => throw StateError('boom');
  @override
  dynamic operator [](Object? key) => throw StateError('boom');
  @override
  void operator []=(String key, dynamic value) {}
  @override
  void clear() {}
  @override
  dynamic remove(Object? key) => null;
}

void main() {
  group('G-RC2 — décodeur : un élément corrompu est REJETÉ, jamais la liste', () {
    const ZChatRouteCatalogDecoder canonical = ZChatRouteCatalogDecoder();

    test('[ok, 42, ok] ⇒ 2 routeurs et 1 rejet `notAMap`', () {
      final ZChatRouteCatalogDecodeReport rep = canonical.decodeList(<Object?>[
        <String, dynamic>{'id': 'a'},
        42,
        <String, dynamic>{'id': 'b'},
      ]);
      expect(rep.routers.map((ZChatRouter r) => r.id), <String>['a', 'b']);
      expect(rep.rejected, hasLength(1));
      expect(rep.rejected.single.index, 1);
      expect(rep.rejected.single.reason, 'notAMap');
    });

    test(
      'sans `id` ⇒ rejet `missingId` ; élément qui LÈVE ⇒ rejet `threw`',
      () {
        final ZChatRouteCatalogDecodeReport rep = canonical.decodeList(
          <Object?>[
            <String, dynamic>{'name': 'anonyme'},
            <String, dynamic>{'id': '  '},
            _ExplodingMap(),
            <String, dynamic>{'id': 'ok'},
          ],
        );
        expect(rep.routers.single.id, 'ok');
        expect(
          rep.rejected.map((ZChatRouteCatalogRejection r) => r.reason),
          <String>['missingId', 'missingId', 'threw'],
        );
      },
    );

    test('enveloppe `{routers: [...]}`, liste nue et routeur seul', () {
      final List<Object?> bare = <Object?>[
        <String, dynamic>{'id': 'a'},
        <String, dynamic>{'id': 'b'},
      ];
      expect(canonical.decodeList(bare).routers, hasLength(2));
      expect(
        canonical.decodeList(<String, dynamic>{'routers': bare}).routers,
        hasLength(2),
      );
      expect(
        canonical.decodeList(<String, dynamic>{'id': 'solo'}).routers.single.id,
        'solo',
      );
      expect(canonical.decodeList(null).routers, isEmpty);
      expect(canonical.decodeList('junk').routers, isEmpty);
    });

    test(
      '`fallbacks` en CHAÎNE seule ⇒ liste d\'un repli (racine ET route)',
      () {
        final ZChatRouter r = canonical
            .decodeList(<Object?>[
              <String, dynamic>{
                'id': 'a',
                'fallbacks': 'p:m',
                'routes': <Object?>[
                  <String, dynamic>{'task_key': 't', 'fallbacks': 'q:n'},
                ],
              },
            ])
            .routers
            .single;
        expect(r.fallbacks, <ZChatModelRef>[
          const ZChatModelRef(providerId: 'p', modelId: 'm'),
        ]);
        expect(r.routeOf('t')!.fallbacks, <ZChatModelRef>[
          const ZChatModelRef(providerId: 'q', modelId: 'n'),
        ]);
      },
    );

    test('clé inconnue → `extra` ; `updated_at`/`is_deleted` RETIRÉS', () {
      final ZChatRouter r = canonical
          .decodeList(<Object?>[
            <String, dynamic>{
              'id': 'a',
              'host_key': 7,
              'updated_at': '2026-01-01T00:00:00Z',
              'is_deleted': true,
            },
          ])
          .routers
          .single;
      expect(r.extra, <String, dynamic>{'host_key': 7});
      expect(r.toMap().containsKey('updated_at'), isFalse);
      expect(r.toMap().containsKey('is_deleted'), isFalse);
    });

    test('clé inconnue d\'une ROUTE → `params` de la route', () {
      final ZChatRouter r = canonical
          .decodeList(<Object?>[
            <String, dynamic>{
              'id': 'a',
              'routes': <Object?>[
                <String, dynamic>{'task_key': 't', 'model_id': 'm', 'top_p': 1},
              ],
            },
          ])
          .routers
          .single;
      expect(r.routeOf('t')!.params, <String, dynamic>{'top_p': 1});
      expect(r.routeOf('t')!.model, const ZChatModelRef(modelId: 'm'));
    });

    group('forme `lex` — camelCase sur le fil, snake_case en base', () {
      const ZChatRouteCatalogDecoder lex = ZChatRouteCatalogDecoder(
        shape: ZChatRouteCatalogShape.lex,
      );

      void check(ZChatRouter r) {
        expect(r.id, 'rt');
        expect(r.isActive, isFalse, reason: 'isActive/is_active → is_active');
        expect(r.tier, 'deep', reason: 'effort du backend → tier opaque');
        expect(r.params, <String, dynamic>{'maxAgents': 3});
        final ZChatRouteSpec sup = r.routeOf('agent_a')!;
        expect(sup.model, const ZChatModelRef(providerId: 'p', modelId: 'm'));
        expect(sup.fallbacks, <ZChatModelRef>[
          const ZChatModelRef(providerId: 'q', modelId: 'n'),
        ]);
        expect(sup.params, <String, dynamic>{'temperature': 0.2});
        expect(r.extra.containsKey('updatedAt'), isFalse);
        expect(r.extra.containsKey('updated_at'), isFalse);
        expect(r.extra, <String, dynamic>{'createdAt': 'x'});
      }

      test('camelCase (fil HTTP)', () {
        final ZChatRouteCatalogDecodeReport rep = lex.decodeList(
          jsonDecode(
            '{"routers":[{"id":"rt","name":"n","isActive":false,'
            '"workflowEffort":"deep","agentModels":{"agent_a":{"provider":"p",'
            '"model":"m","fallbackModels":["q:n"],"temperature":0.2}},'
            '"pipelineParams":{"maxAgents":3},"updatedAt":"t","createdAt":"x"}],'
            '"total":1}',
          ),
        );
        expect(rep.rejected, isEmpty);
        check(rep.routers.single);
      });

      test('snake_case (document persisté)', () {
        final ZChatRouter r = lex
            .decodeList(<Object?>[
              <String, dynamic>{
                'id': 'rt',
                'is_active': false,
                'workflow_effort': 'deep',
                'agent_models': <String, dynamic>{
                  'agent_a': <String, dynamic>{
                    'provider': 'p',
                    'model': 'm',
                    'fallback_models': 'q:n',
                    'temperature': 0.2,
                  },
                },
                'pipeline_params': <String, dynamic>{'maxAgents': 3},
                'updated_at': 't',
                'createdAt': 'x',
              },
            ])
            .routers
            .single;
        check(r);
      });
    });

    test('forme `suffixPairs` — l\'hôte passe SES clés, le socle n\'en code '
        'aucune ; le fournisseur racine complète les références nues', () {
      final ZChatRouteCatalogDecoder dec = ZChatRouteCatalogDecoder(
        shape: ZChatRouteCatalogShape.suffixPairs(
          modelSuffix: 'Model',
          fallbackSuffix: 'FallbackModels',
          rootModel: 'aiModel',
          rootFallback: 'aiFallbackModels',
          tierKey: 'plan',
          providerKey: 'aiProvider',
        ),
      );
      final ZChatRouter r = dec
          .decodeList(<Object?>[
            <String, dynamic>{
              'id': 'rt',
              'aiModel': 'm0',
              'aiFallbackModels': 'f0',
              'fooModel': 'm1',
              'fooFallbackModels': <String>['f1', 'q:f2'],
              'barFallbackModels': <String>['f3'],
              'plan': 'gold',
              'aiProvider': 'pp',
              'other': 1,
            },
          ])
          .routers
          .single;
      expect(r.model, const ZChatModelRef(providerId: 'pp', modelId: 'm0'));
      expect(r.fallbacks, <ZChatModelRef>[
        const ZChatModelRef(providerId: 'pp', modelId: 'f0'),
      ]);
      expect(r.tier, 'gold');
      final ZChatRouteSpec foo = r.routeOf('foo')!;
      expect(foo.model, const ZChatModelRef(providerId: 'pp', modelId: 'm1'));
      expect(foo.fallbacks, <ZChatModelRef>[
        const ZChatModelRef(providerId: 'pp', modelId: 'f1'),
        const ZChatModelRef(providerId: 'q', modelId: 'f2'),
      ]);
      expect(r.routeOf('bar')!.model, isNull);
      expect(r.routeOf('bar')!.fallbacks, hasLength(1));
      expect(
        r.extra,
        <String, dynamic>{'other': 1},
        reason: 'les clés de paire et de fournisseur ne fuient pas en extra',
      );
    });

    test('la normalisation est PURE : la map reçue n\'est pas mutée', () {
      final Map<String, dynamic> raw = <String, dynamic>{
        'id': 'a',
        'fallbacks': 'p:m',
        'routes': <String, dynamic>{
          'k': <String, dynamic>{'model_id': 'm'},
        },
      };
      final String before = jsonEncode(raw);
      canonical.decodeList(<Object?>[raw]);
      expect(jsonEncode(raw), before);
    });
  });

  group('sources', () {
    test(
      'statique : inactif ⇒ Right(null) ; fetchAll ne liste que les actifs',
      () async {
        final ZChatStaticRouteCatalogSource s = ZChatStaticRouteCatalogSource(
          <ZChatRouter>[_r('a'), _r('b', active: false), const ZChatRouter()],
        );
        expect(s.ids, <String>['a', 'b']);
        expect((await s.fetchRouter('a')).getOrElse(() => null)!.id, 'a');
        expect((await s.fetchRouter('b')).getOrElse(() => _r('x')), isNull);
        expect((await s.fetchRouter('zz')).getOrElse(() => _r('x')), isNull);
        expect(
          (await s.fetchAll()).getOrElse(() => []).map((ZChatRouter r) => r.id),
          <String>['a'],
        );
      },
    );

    group('dépôt (`ZChatRepositoryRouteCatalogSource`)', () {
      test('getById : actif ⇒ Right(r) ; inactif ⇒ Right(null) ; '
          'NotFound ⇒ Right(null) ; autre Left ⇒ REPROPAGÉ', () async {
        final _ReadOnlyRepo repo = _ReadOnlyRepo(
          byId: (String id) => switch (id) {
            'a' => Right<ZFailure, ZChatRouter>(_r('a')),
            'off' => Right<ZFailure, ZChatRouter>(_r('off', active: false)),
            'down' => const Left<ZFailure, ZChatRouter>(ZServerFailure('down')),
            _ => Left<ZFailure, ZChatRouter>(
              ZNotFoundFailure('nf', id: id, entity: kZChatRouterKind),
            ),
          },
          all: const Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[]),
        );
        final ZChatRepositoryRouteCatalogSource s =
            ZChatRepositoryRouteCatalogSource(repo);
        expect((await s.fetchRouter('a')).getOrElse(() => null)!.id, 'a');
        expect((await s.fetchRouter('off')).getOrElse(() => _r('x')), isNull);
        expect((await s.fetchRouter('nope')).getOrElse(() => _r('x')), isNull);
        final ZResult<ZChatRouter?> down = await s.fetchRouter('down');
        expect(down.isLeft(), isTrue);
        expect(
          down.fold((ZFailure f) => f, (_) => null),
          isA<ZServerFailure>(),
        );
      });

      test(
        'fetchAll : filtre serveur `is_active == true` ET filtre mémoire',
        () async {
          final _ReadOnlyRepo repo = _ReadOnlyRepo(
            byId: (_) => const Left<ZFailure, ZChatRouter>(ZDomainFailure('x')),
            all: Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[
              _r('a'),
              _r('b', active: false),
            ]),
          );
          final List<ZChatRouter> all =
              (await ZChatRepositoryRouteCatalogSource(
                repo,
              ).fetchAll()).getOrElse(() => []);
          expect(
            all.map((ZChatRouter r) => r.id),
            <String>['a'],
            reason:
                'un dépôt qui ignore le filtre ne fait pas passer un inactif',
          );
          expect(repo.requests.single!.filters, <ZFilter>[
            const ZFilter('is_active', ZFilterOp.eq, true),
          ]);
        },
      );

      test(
        'au-dessus du dépôt mémoire : un soft-deleted est Right(null)',
        () async {
          final ZChatInMemoryRouterRepository repo =
              ZChatInMemoryRouterRepository(
                seed: <ZChatRouter>[_r('a'), _r('b')],
              );
          await repo.softDelete('b');
          final ZChatRepositoryRouteCatalogSource s =
              ZChatRepositoryRouteCatalogSource(repo);
          expect((await s.fetchRouter('b')).getOrElse(() => _r('x')), isNull);
          expect(
            (await s.fetchAll())
                .getOrElse(() => [])
                .map((ZChatRouter r) => r.id),
            <String>['a'],
          );
        },
      );
    });

    group('distante (`ZChatRemoteRouteCatalogSource`)', () {
      const ZChatRouteCatalogDecoder dec = ZChatRouteCatalogDecoder();

      test('l\'ouvreur reçoit la requête ; corps JSON ⇒ routeur ; '
          'corps vide ⇒ Right(null) / Right([])', () async {
        final List<ZChatRouteCatalogQuery> seen = <ZChatRouteCatalogQuery>[];
        final ZChatRemoteRouteCatalogSource s = ZChatRemoteRouteCatalogSource(
          open: (ZChatRouteCatalogQuery q) async {
            seen.add(q);
            if (q.isList) return '';
            return q.id == 'a' ? '{"id":"a","tier":"t"}' : '   ';
          },
          decode: dec,
        );
        expect((await s.fetchRouter('a')).getOrElse(() => null)!.tier, 't');
        expect((await s.fetchRouter('zz')).getOrElse(() => _r('x')), isNull);
        expect((await s.fetchAll()).getOrElse(() => [_r('x')]), isEmpty);
        expect(seen, <ZChatRouteCatalogQuery>[
          const ZChatRouteCatalogQuery(id: 'a'),
          const ZChatRouteCatalogQuery(id: 'zz'),
          const ZChatRouteCatalogQuery(),
        ]);
      });

      test('exception de l\'ouvreur ⇒ Left(ZServerFailure) ; JSON illisible '
          '⇒ Left(ZServerFailure) ; les deux journalisés', () async {
        final List<String> log = <String>[];
        final ZChatRemoteRouteCatalogSource s = ZChatRemoteRouteCatalogSource(
          open: (ZChatRouteCatalogQuery q) async {
            if (q.isList) return '{not json';
            throw StateError('offline');
          },
          decode: dec,
          log: (String m, {Object? cause}) => log.add('$m|$cause'),
        );
        final ZResult<ZChatRouter?> one = await s.fetchRouter('a');
        expect(one.fold((ZFailure f) => f, (_) => null), isA<ZServerFailure>());
        final ZResult<List<ZChatRouter>> all = await s.fetchAll();
        expect(all.fold((ZFailure f) => f, (_) => null), isA<ZServerFailure>());
        expect(log, hasLength(2));
        expect(log.first, contains('offline'));
      });

      test('routeur seul SANS identité ⇒ reçoit l\'identité demandée ; '
          'inactif ⇒ Right(null) ; rejets journalisés', () async {
        final List<String> log = <String>[];
        final ZChatRemoteRouteCatalogSource s = ZChatRemoteRouteCatalogSource(
          open: (ZChatRouteCatalogQuery q) async => switch (q.id) {
            'anon' => '{"tier":"t"}',
            'off' => '{"id":"off","is_active":false}',
            _ => '{"routers":[{"id":"a"},7,{"id":"b","is_active":false}]}',
          },
          decode: dec,
          log: (String m, {Object? cause}) => log.add(m),
        );
        expect((await s.fetchRouter('anon')).getOrElse(() => null)!.id, 'anon');
        expect((await s.fetchRouter('off')).getOrElse(() => _r('x')), isNull);
        expect(
          (await s.fetchAll()).getOrElse(() => []).map((ZChatRouter r) => r.id),
          <String>['a'],
        );
        expect(log.single, contains('rejected'));
      });
    });
  });

  group('G-RC3 — cache TTL : horloge INJECTÉE, appels COMPTÉS', () {
    late DateTime now;
    late _Spy inner;
    late ZChatTtlRouteCatalog ttl;

    setUp(() {
      now = DateTime.utc(2026, 1, 1);
      inner = _Spy(
        byId: <String, ZResult<ZChatRouter?>>{
          'a': Right<ZFailure, ZChatRouter?>(_r('a')),
          'b': Right<ZFailure, ZChatRouter?>(_r('b')),
        },
        all: Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[
          _r('a'),
          _r('b'),
        ]),
      );
      ttl = ZChatTtlRouteCatalog(
        inner,
        ttl: const Duration(seconds: 300),
        clock: () => now,
      );
    });

    test('deux appels < TTL ⇒ 1 fetch ; > TTL ⇒ 2', () async {
      await ttl.fetchRouter('a');
      now = now.add(const Duration(seconds: 299));
      await ttl.fetchRouter('a');
      expect(inner.calls('a'), 1);
      now = now.add(const Duration(seconds: 2));
      expect((await ttl.fetchRouter('a')).getOrElse(() => null)!.id, 'a');
      expect(inner.calls('a'), 2);
    });

    test(
      '`ZSystemClock.fixed` : le temps ne passe JAMAIS ⇒ 1 seul fetch',
      () async {
        final ZChatTtlRouteCatalog frozen = ZChatTtlRouteCatalog(
          inner,
          ttl: const Duration(milliseconds: 1),
          clock: ZSystemClock.fixed(DateTime.utc(2026)),
        );
        for (int i = 0; i < 5; i++) {
          await frozen.fetchRouter('a');
        }
        expect(inner.calls('a'), 1);
      },
    );

    test(
      '`invalidate(id)` ⇒ refetch de CET id seul ; `invalidate()` ⇒ tout',
      () async {
        await ttl.fetchRouter('a');
        await ttl.fetchRouter('b');
        await ttl.invalidate('a');
        await ttl.fetchRouter('a');
        await ttl.fetchRouter('b');
        expect(inner.calls('a'), 2);
        expect(inner.calls('b'), 1);
        await ttl.invalidate();
        await ttl.fetchRouter('a');
        await ttl.fetchRouter('b');
        expect(inner.calls('a'), 3);
        expect(inner.calls('b'), 2);
      },
    );

    test('`Left` distant + entrée PÉRIMÉE ⇒ Right(stale) journalisé ; '
        'sans entrée ⇒ le Left passe', () async {
      final List<Object?> causes = <Object?>[];
      ttl = ZChatTtlRouteCatalog(
        inner,
        ttl: const Duration(seconds: 10),
        clock: () => now,
        log: (String m, {Object? cause}) => causes.add(cause),
      );
      final ZChatRouter first = (await ttl.fetchRouter(
        'a',
      )).getOrElse(() => null)!;
      inner.script(
        'a',
        const Left<ZFailure, ZChatRouter?>(ZServerFailure('down')),
      );
      now = now.add(const Duration(seconds: 11));
      final ZResult<ZChatRouter?> stale = await ttl.fetchRouter('a');
      expect(identical(stale.getOrElse(() => null), first), isTrue);
      expect(causes.single, isA<ZServerFailure>());
      inner.script(
        'zz',
        const Left<ZFailure, ZChatRouter?>(ZServerFailure('down')),
      );
      expect((await ttl.fetchRouter('zz')).isLeft(), isTrue);
    });

    test(
      'cache NÉGATIF : une absence est mémorisée comme une présence',
      () async {
        expect(
          (await ttl.fetchRouter('nope')).getOrElse(() => _r('x')),
          isNull,
        );
        await ttl.fetchRouter('nope');
        expect(inner.calls('nope'), 1);
        expect(ttl.cachedIds, contains('nope'));
      },
    );

    test('`ttl == Duration.zero` ⇒ AUCUN cache', () async {
      final ZChatTtlRouteCatalog none = ZChatTtlRouteCatalog(
        inner,
        ttl: Duration.zero,
        clock: () => now,
      );
      await none.fetchRouter('a');
      await none.fetchRouter('a');
      expect(inner.calls('a'), 2);
      expect(none.cachedIds, isEmpty);
    });

    test('`fetchAll` est caché et ALIMENTE les entrées unitaires', () async {
      await ttl.fetchAll();
      await ttl.fetchAll();
      expect(inner.listed, 1);
      await ttl.fetchRouter('a');
      expect(inner.calls('a'), 0, reason: 'servi par le listing');
      inner.all = const Left<ZFailure, List<ZChatRouter>>(ZServerFailure('x'));
      now = now.add(const Duration(seconds: 301));
      expect(
        (await ttl.fetchAll()).getOrElse(() => []),
        hasLength(2),
        reason: 'liste périmée servie sur panne',
      );
    });
  });

  group('G-RC4 — repli DÉCLARÉ seulement', () {
    test(
      'toutes Right(null) + fallback ⇒ `identical(result, fallback(id))`',
      () async {
        final ZChatRouter built = _r('fb');
        final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
          sources: <ZChatRouteCatalogSource>[_Spy(), _Spy()],
          fallback: (String id) => built,
        );
        final ZChatRouter got = (await c.resolveRouter(
          'zz',
        )).getOrElse(() => _r('x'));
        expect(identical(got, built), isTrue);
      },
    );

    test(
      'sans fallback ⇒ Left(ZNotFoundFailure(id, entity)) — rien d\'inventé',
      () async {
        final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
          sources: <ZChatRouteCatalogSource>[_Spy()],
        );
        final ZFailure? f = (await c.resolveRouter(
          'zz',
        )).fold((ZFailure f) => f, (_) => null);
        expect(f, isA<ZNotFoundFailure>());
        expect((f! as ZNotFoundFailure).id, 'zz');
        expect((f as ZNotFoundFailure).entity, kZChatRouterKind);
      },
    );

    test('la première source qui CONNAÎT gagne ; les suivantes ne sont pas '
        'interrogées', () async {
      final _Spy first = _Spy();
      final _Spy second = _Spy(
        byId: <String, ZResult<ZChatRouter?>>{
          'a': Right<ZFailure, ZChatRouter?>(_r('a', tier: 'second')),
        },
      );
      final _Spy third = _Spy(
        byId: <String, ZResult<ZChatRouter?>>{
          'a': Right<ZFailure, ZChatRouter?>(_r('a', tier: 'third')),
        },
      );
      final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
        sources: <ZChatRouteCatalogSource>[first, second, third],
        fallback: (_) => _r('never'),
      );
      expect(
        (await c.resolveRouter(
          'a',
        )).fold((_) => null, (ZChatRouter r) => r)!.tier,
        'second',
      );
      expect(first.fetched, <String>['a']);
      expect(third.fetched, isEmpty);
    });

    test(
      '`listRouters` = première liste NON VIDE ; le repli n\'est JAMAIS listé',
      () async {
        final _Spy empty = _Spy();
        final _Spy full = _Spy(
          all: Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[_r('a')]),
        );
        final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
          sources: <ZChatRouteCatalogSource>[empty, full],
          fallback: (_) => _r('fb'),
        );
        expect(
          (await c.listRouters())
              .getOrElse(() => [])
              .map((ZChatRouter r) => r.id),
          <String>['a'],
        );
        final ZChatCascadeRouteCatalog none = ZChatCascadeRouteCatalog(
          sources: <ZChatRouteCatalogSource>[empty],
          fallback: (_) => _r('fb'),
        );
        expect((await none.listRouters()).getOrElse(() => [_r('x')]), isEmpty);
      },
    );
  });

  group(
    'G-RC5 — `Left` distant ⇒ suivante ; `Left(ZCacheFailure)` ⇒ REPROPAGÉ',
    () {
      test('ZServerFailure : journalisé, la source suivante répond', () async {
        final List<Object?> causes = <Object?>[];
        final _Spy down = _Spy(
          otherwise: const Left<ZFailure, ZChatRouter?>(ZServerFailure('down')),
          all: const Left<ZFailure, List<ZChatRouter>>(ZServerFailure('down')),
        );
        final _Spy ok = _Spy(
          byId: <String, ZResult<ZChatRouter?>>{
            'a': Right<ZFailure, ZChatRouter?>(_r('a')),
          },
          all: Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[_r('a')]),
        );
        final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
          sources: <ZChatRouteCatalogSource>[down, ok],
          log: (String m, {Object? cause}) => causes.add(cause),
        );
        expect(
          (await c.resolveRouter(
            'a',
          )).fold((_) => null, (ZChatRouter r) => r)!.id,
          'a',
        );
        expect((await c.listRouters()).getOrElse(() => []), hasLength(1));
        expect(causes, hasLength(2));
        expect(causes.every((Object? c) => c is ZServerFailure), isTrue);
      });

      test(
        'ZCacheFailure : repropagé tel quel, la suivante n\'est PAS appelée',
        () async {
          const ZCacheFailure broken = ZCacheFailure('store corrompu');
          final _Spy local = _Spy(
            otherwise: const Left<ZFailure, ZChatRouter?>(broken),
            all: const Left<ZFailure, List<ZChatRouter>>(broken),
          );
          final _Spy next = _Spy(
            byId: <String, ZResult<ZChatRouter?>>{
              'a': Right<ZFailure, ZChatRouter?>(_r('a')),
            },
          );
          final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
            sources: <ZChatRouteCatalogSource>[local, next],
            fallback: (_) => _r('fb'),
          );
          final ZResult<ZChatRouter> one = await c.resolveRouter('a');
          expect(
            identical(one.fold((ZFailure f) => f, (_) => null), broken),
            isTrue,
          );
          expect(next.fetched, isEmpty);
          expect(
            identical(
              (await c.listRouters()).fold((ZFailure f) => f, (_) => null),
              broken,
            ),
            isTrue,
          );
          expect(next.listed, 0);
        },
      );

      test('`invalidate` est propagé aux sources TTL seulement', () async {
        final _Spy inner = _Spy(
          byId: <String, ZResult<ZChatRouter?>>{
            'a': Right<ZFailure, ZChatRouter?>(_r('a')),
          },
        );
        final ZChatTtlRouteCatalog cached = ZChatTtlRouteCatalog(
          inner,
          ttl: const Duration(hours: 1),
        );
        final ZChatCascadeRouteCatalog c = ZChatCascadeRouteCatalog(
          sources: <ZChatRouteCatalogSource>[_Spy(), cached],
        );
        await c.resolveRouter('a');
        await c.resolveRouter('a');
        expect(inner.calls('a'), 1);
        await c.invalidate('a');
        await c.resolveRouter('a');
        expect(inner.calls('a'), 2);
      });
    },
  );

  group('G-RC6 — dépôt mémoire ≡ sémantique documentaire', () {
    late ZChatInMemoryRouterRepository repo;
    setUp(() => repo = ZChatInMemoryRouterRepository());
    tearDown(() => repo.dispose());

    test(
      'l\'ÉPHÉMÈRE est matérialisé : `id` attribué, rendu par `save`',
      () async {
        final ZChatRouter saved = (await repo.save(
          const ZChatRouter(tier: 't'),
        )).getOrElse(() => _r('x'));
        expect(saved.id, isNotNull);
        expect(saved.tier, 't');
        expect((await repo.getById(saved.id!)).getOrElse(() => _r('x')), saved);
        expect(
          zRepositoryServesSearch(repo),
          isFalse,
          reason: 'la recherche est DÉLÉGUÉE (mixin)',
        );
      },
    );

    test('après `softDelete` : getById ⇒ Left(ZNotFoundFailure) ; '
        '`restore` le ramène ; absent ⇒ Left(ZNotFoundFailure)', () async {
      await repo.save(_r('a'));
      expect((await repo.softDelete('a')).isRight(), isTrue);
      final ZFailure? f = (await repo.getById(
        'a',
      )).fold((ZFailure f) => f, (_) => null);
      expect(f, isA<ZNotFoundFailure>());
      expect((f! as ZNotFoundFailure).id, 'a');
      expect(repo.isDeleted('a'), isTrue);
      expect((await repo.restore('a')).isRight(), isTrue);
      expect((await repo.getById('a')).isRight(), isTrue);
      expect(
        (await repo.softDelete('zz')).fold((ZFailure f) => f, (_) => null),
        isA<ZNotFoundFailure>(),
      );
      expect(
        (await repo.restore('zz')).fold((ZFailure f) => f, (_) => null),
        isA<ZNotFoundFailure>(),
      );
    });

    test('`deletedScope` ×3 sur getAll ET count', () async {
      await repo.save(_r('a'));
      await repo.save(_r('b'));
      await repo.softDelete('b');
      Future<List<String>> ids(ZDeletedScope s) async => (await repo.getAll(
        request: ZDataRequest(deletedScope: s),
      )).getOrElse(() => []).map((ZChatRouter r) => r.id!).toList();
      expect(await ids(ZDeletedScope.aliveOnly), <String>['a']);
      expect(await ids(ZDeletedScope.deletedOnly), <String>['b']);
      expect(await ids(ZDeletedScope.includeDeleted), <String>['a', 'b']);
      expect(
        (await repo.getAll()).getOrElse(() => []),
        hasLength(1),
        reason: 'sans requête : aliveOnly',
      );
      expect(
        (await repo.count(
          request: const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
        )).getOrElse(() => -1),
        1,
      );
    });

    test(
      'filtres `eq`/`neq`/`isIn`, tris et limite sur les clés persistées',
      () async {
        await repo.save(_r('a', tier: 'x', name: 'n2'));
        await repo.save(_r('b', tier: 'y', name: 'n1'));
        await repo.save(_r('c', tier: 'x', name: 'n3', active: false));
        Future<List<String>> ids(ZDataRequest q) async => (await repo.getAll(
          request: q,
        )).getOrElse(() => []).map((ZChatRouter r) => r.id!).toList();
        expect(
          await ids(
            const ZDataRequest(
              filters: <ZFilter>[ZFilter('tier', ZFilterOp.eq, 'x')],
            ),
          ),
          <String>['a', 'c'],
        );
        expect(
          await ids(
            const ZDataRequest(
              filters: <ZFilter>[ZFilter('is_active', ZFilterOp.neq, true)],
            ),
          ),
          <String>['c'],
        );
        expect(
          await ids(
            const ZDataRequest(
              filters: <ZFilter>[
                ZFilter('id', ZFilterOp.isIn, <String>['b', 'c']),
              ],
            ),
          ),
          <String>['b', 'c'],
        );
        expect(
          await ids(const ZDataRequest(sorts: <ZSort>[ZSort('name')])),
          <String>['b', 'a', 'c'],
        );
        expect(
          await ids(
            const ZDataRequest(
              sorts: <ZSort>[ZSort('name', ZSortDirection.desc)],
              limit: 2,
            ),
          ),
          <String>['c', 'a'],
        );
      },
    );

    test('`watchAll` SEED immédiat puis diffusion des mutations ; '
        '`watch(deletedOnly)` voit la corbeille', () async {
      await repo.save(_r('a'));
      final List<List<String>> seen = <List<String>>[];
      final StreamSubscription<List<ZChatRouter>> sub = repo.watchAll().listen(
        (List<ZChatRouter> l) =>
            seen.add(l.map((ZChatRouter r) => r.id!).toList()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, <List<String>>[
        <String>['a'],
      ], reason: 'seed');
      await repo.save(_r('b'));
      await repo.softDelete('a');
      await Future<void>.delayed(Duration.zero);
      expect(seen.last, <String>['b']);
      await sub.cancel();
      expect(
        await repo
            .watch(const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly))
            .first,
        <ZChatRouter>[_r('a')],
      );
    });

    test(
      '`save` sur une identité en corbeille la RAVIVE ; seed éphémère nommé',
      () async {
        final ZChatInMemoryRouterRepository seeded =
            ZChatInMemoryRouterRepository(
              seed: <ZChatRouter>[const ZChatRouter(tier: 'seed')],
              idGenerator: () => 'fixed',
            );
        expect((await seeded.getById('fixed')).isRight(), isTrue);
        await seeded.softDelete('fixed');
        await seeded.save(_r('fixed'));
        expect((await seeded.getById('fixed')).isRight(), isTrue);
        seeded.dispose();
      },
    );
  });

  group(
    'invalidation après écriture (`ZChatInvalidatingRouterRepository`)',
    () {
      test(
        'save/softDelete/restore RÉUSSIS ⇒ invalidate(id) ; échec ⇒ rien',
        () async {
          final ZChatInMemoryRouterRepository inner =
              ZChatInMemoryRouterRepository(idGenerator: () => 'gen');
          final _CatalogSpy catalog = _CatalogSpy();
          final ZChatInvalidatingRouterRepository repo =
              ZChatInvalidatingRouterRepository(inner, catalog);
          await repo.save(const ZChatRouter());
          expect(catalog.invalidated, <String?>[
            'gen',
          ], reason: 'l\'identité MATÉRIALISÉE, pas `null`');
          await repo.softDelete('gen');
          await repo.restore('gen');
          expect(catalog.invalidated, <String?>['gen', 'gen', 'gen']);
          await repo.softDelete('absent');
          expect(
            catalog.invalidated,
            hasLength(3),
            reason: 'échec ⇒ pas d\'invalidation',
          );
          expect((await repo.getById('gen')).isRight(), isTrue);
          expect((await repo.count()).getOrElse(() => -1), 1);
          repo.dispose();
        },
      );

      test('la capacité de recherche est celle de `inner`', () {
        final ZChatInMemoryRouterRepository delegating =
            ZChatInMemoryRouterRepository();
        final _ServingRepo serving = _ServingRepo(delegating);
        expect(
          zRepositoryServesSearch(
            ZChatInvalidatingRouterRepository(delegating, _CatalogSpy()),
          ),
          isFalse,
        );
        expect(
          zRepositoryServesSearch(
            ZChatInvalidatingRouterRepository(serving, _CatalogSpy()),
          ),
          isTrue,
        );
        delegating.dispose();
      });
    },
  );
}
