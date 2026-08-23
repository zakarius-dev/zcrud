// Comportement du catalogue de routes (`domain/route/`) : lecture tolérante
// de `ZChatModelRef`, désérialisation défensive du routeur, round-trip,
// gate de gouvernance, résolution (repli tâche → racine, couple solidaire,
// projection sur la requête), catalogue mémoire et annuaire de gestionnaires.
//
// R3 : chaque test nomme dans son titre ce qu'il casse si la règle est
// retirée ; les injections rejouées sont consignées dans le rapport du lot.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

ZChatRouteSpec _route(
  String key, {
  ZChatModelRef? model,
  List<ZChatModelRef> fallbacks = const <ZChatModelRef>[],
  ZChatComputeEffort? effort,
  Map<String, dynamic> params = const <String, dynamic>{},
  List<String> tokens = const <String>[],
  String? handlerId,
  String? routeName,
}) => ZChatRouteSpec(
  taskKey: key,
  model: model,
  fallbacks: fallbacks,
  computeEffort: effort,
  params: params,
  requiredAccessTokens: tokens,
  handlerId: handlerId,
  routeName: routeName,
);

const ZChatModelRef _rootModel = ZChatModelRef(providerId: 'p0', modelId: 'm0');
const ZChatModelRef _rootFb = ZChatModelRef(providerId: 'p0', modelId: 'f0');
const ZChatModelRef _routeModel = ZChatModelRef(
  providerId: 'p1',
  modelId: 'm1',
);
const ZChatModelRef _routeFb = ZChatModelRef(modelId: 'f1');

ZChatRouter _router() => ZChatRouter(
  id: 'r1',
  name: 'n',
  tier: 't2',
  model: _rootModel,
  fallbacks: const <ZChatModelRef>[_rootFb],
  computeEffort: ZChatComputeEffort(2),
  params: const <String, dynamic>{'a': 1, 'shared': 'root'},
  routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[
    _route(
      'full',
      model: _routeModel,
      fallbacks: const <ZChatModelRef>[_routeFb],
      effort: ZChatComputeEffort(4),
      params: const <String, dynamic>{'b': 2, 'shared': 'route'},
      tokens: const <String>['tok'],
      handlerId: 'h1',
      routeName: 'rn',
    ),
    _route('bare'),
    _route('fallbacksOnly', fallbacks: const <ZChatModelRef>[_routeFb]),
  ]),
);

ZChatGenerationRequest _base({String? modelId, String? providerId}) =>
    ZChatGenerationRequest(
      style: ZChatGenerationStyle('full'),
      subject: 's',
      notes: 'n',
      conversationId: 'c',
      sourceMessageId: 'sm',
      attachmentIds: const <String>['att'],
      responseLength: ZChatResponseLength.values.first,
      computeEffort: ZChatComputeEffort(1),
      revealThinkingSteps: true,
      webSearch: false,
      capabilities: const <String, bool>{'cap': true},
      languageTag: 'fr',
      instructions: 'i',
      modelId: modelId,
      providerId: providerId,
      extra: const <String, dynamic>{'host': 'h', 'shared': 'host'},
    );

void main() {
  group('ZChatModelRef — lecture tolérante', () {
    test('`"deepseek:x"` ⇒ {deepseek, x}', () {
      expect(
        ZChatModelRef.fromJson('deepseek:x'),
        const ZChatModelRef(providerId: 'deepseek', modelId: 'x'),
      );
    });

    test('chaîne nue ⇒ fournisseur `null`', () {
      expect(ZChatModelRef.fromJson('x'), const ZChatModelRef(modelId: 'x'));
    });

    test('`"a:b:c"` ⇒ {a, "b:c"} (coupure sur le PREMIER `:`)', () {
      expect(
        ZChatModelRef.fromJson('a:b:c'),
        const ZChatModelRef(providerId: 'a', modelId: 'b:c'),
      );
    });

    test('map `{provider_id, model_id}` et formes illisibles', () {
      expect(
        ZChatModelRef.fromJson(const <String, dynamic>{
          'provider_id': 'p',
          'model_id': 'm',
        }),
        const ZChatModelRef(providerId: 'p', modelId: 'm'),
      );
      expect(ZChatModelRef.fromJson(null), isNull);
      expect(ZChatModelRef.fromJson(42), isNull);
      expect(ZChatModelRef.fromJson(''), isNull);
      expect(ZChatModelRef.fromJson('p:'), isNull);
      expect(
        ZChatModelRef.fromJson(const <String, dynamic>{'model_id': ''}),
        isNull,
      );
    });

    test('forme compacte : jeton quand réversible, map sinon', () {
      const ZChatModelRef ambiguous = ZChatModelRef(modelId: 'x:y');
      expect(ambiguous.isTokenReversible, isFalse);
      expect(ambiguous.toCompactJson(), <String, dynamic>{'model_id': 'x:y'});
      expect(ZChatModelRef.fromJson(ambiguous.toCompactJson()), ambiguous);
      expect(_routeModel.toCompactJson(), 'p1:m1');
      expect(ZChatModelRef.fromJson(_routeModel.toCompactJson()), _routeModel);
    });
  });

  group('ZChatRouter — désérialisation défensive (AD-10)', () {
    test('`fromMap({})` ne lève pas et rend un routeur actif sans route', () {
      final ZChatRouter r = ZChatRouter.fromMap(const <String, dynamic>{});
      expect(r.isActive, isTrue);
      expect(r.routes, isEmpty);
      expect(r.model, isNull);
    });

    test('routes `[ok, 42, {sans task_key}, "x", ok2]` ⇒ 2 routes', () {
      final ZChatRouter r = ZChatRouter.fromMap(<String, dynamic>{
        'routes': <Object?>[
          <String, dynamic>{'task_key': 'a', 'model_id': 'm'},
          42,
          <String, dynamic>{'model_id': 'orphan'},
          'x',
          <String, dynamic>{'task_key': 'b'},
        ],
      });
      expect(r.routes.keys, <String>['a', 'b']);
      expect(r.routeOf('a')!.model, const ZChatModelRef(modelId: 'm'));
    });

    test('forme OBJET `{clé: {…}}` lue : la clé devient `task_key`', () {
      final ZChatRouter r = ZChatRouter.fromMap(<String, dynamic>{
        'routes': <String, dynamic>{
          'k1': <String, dynamic>{'model': 'p:m', 'compute_effort': 3},
          'k2': 'corrompu',
          'k3': <String, dynamic>{'task_key': 'ignoré', 'model_id': 'z'},
        },
      });
      expect(r.routes.keys, <String>['k1', 'k3']);
      expect(
        r.routeOf('k1')!.model,
        const ZChatModelRef(providerId: 'p', modelId: 'm'),
      );
      expect(r.routeOf('k1')!.computeEffort, ZChatComputeEffort(3));
    });

    test('dernière déclaration gagnante sur une clé dupliquée', () {
      final ZChatRouter r = ZChatRouter.fromMap(<String, dynamic>{
        'routes': <Object?>[
          <String, dynamic>{'task_key': 'a', 'model_id': 'first'},
          <String, dynamic>{'task_key': 'a', 'model_id': 'last'},
        ],
      });
      expect(r.routes.length, 1);
      expect(r.routeOf('a')!.model!.modelId, 'last');
    });

    test('`compute_effort: "abc"` ⇒ null ; replis corrompus sautés', () {
      final ZChatRouter r = ZChatRouter.fromMap(<String, dynamic>{
        'compute_effort': 'abc',
        'fallbacks': <Object?>['p:a', 7, null, <String, dynamic>{}, 'b'],
      });
      expect(r.computeEffort, isNull);
      expect(r.fallbacks, const <ZChatModelRef>[
        ZChatModelRef(providerId: 'p', modelId: 'a'),
        ZChatModelRef(modelId: 'b'),
      ]);
    });

    test('round-trip `fromMap(toMap(x)) == x` sur un routeur complet', () {
      final ZChatRouter x = _router().copyWith(
        description: 'd',
        extra: const <String, dynamic>{'host': 'kept'},
      );
      final Map<String, dynamic> persisted = x.toMap();
      expect(persisted['routes'], isA<List<Object?>>());
      expect(persisted['model_provider_id'], 'p0');
      expect(persisted['model_id'], 'm0');
      expect(persisted['fallbacks'], <Object>['p0:f0']);
      expect(ZChatRouter.fromMap(persisted), x);
      expect(ZChatRouter.fromMap(persisted).hashCode, x.hashCode);
    });

    test('`requiredAccessTokens` dédupliqués, rognés, triés', () {
      final ZChatRouteSpec s = _route(
        'k',
        tokens: <String>['b', ' a ', 'b', ''],
      );
      expect(s.requiredAccessTokens, <String>['a', 'b']);
      expect(() => s.requiredAccessTokens.add('x'), throwsUnsupportedError);
    });

    test('`registerZChatRouter` câble codec et schéma sous `chat_router`', () {
      final ZcrudRegistry registry = ZcrudRegistry();
      registerZChatRouter(registry);
      expect(registry.fieldSpecsFor(kZChatRouterKind), $ZChatRouterFieldSpecs);
      final ZChatRouter x = _router();
      final Object decoded = registry.decode(kZChatRouterKind, x.toMap());
      expect(decoded, x);
      expect(registry.encode(kZChatRouterKind, x), x.toMap());
    });
  });

  group('ZChatRouteGate', () {
    test('le gate de REFUS rend `upgradeRequired` ; AllowAll rend Right', () {
      final ZResult<Unit> denied = const ZDenyAllChatRouteGate().canRoute(
        'k',
        tier: 't',
      );
      expect(denied.isLeft(), isTrue);
      denied.fold((ZFailure f) {
        expect(f, isA<ZChatProviderFailure>());
        expect(
          (f as ZChatProviderFailure).code,
          ZChatFailureCodes.upgradeRequired,
        );
      }, (_) => fail('refus attendu'));
      expect(const ZAllowAllChatRouteGate().canRoute('k').isRight(), isTrue);
    });

    test('`UPGRADE_REQUIRED` sur le fil est absorbé en camelCase', () {
      final ZFailure f = zChatFailureFromWire(const <String, dynamic>{
        'code': 'UPGRADE_REQUIRED',
        'message': 'm',
      });
      expect(f, isA<ZChatProviderFailure>());
      expect((f as ZChatProviderFailure).code, 'upgradeRequired');
    });
  });

  group('ZChatRouteResolution — repli tâche → racine', () {
    test('route déclarée : modèle, replis, effort, params fusionnés', () {
      final ZChatRouteResolution r = ZChatRouteResolution.from(
        _router(),
        'full',
      );
      expect(r.declared, isTrue);
      expect(r.routerId, 'r1');
      expect(r.tier, 't2');
      expect(r.routeName, 'rn');
      expect(r.handlerId, 'h1');
      expect(r.model, _routeModel);
      expect(r.fallbacks, const <ZChatModelRef>[_routeFb]);
      expect(r.computeEffort, ZChatComputeEffort(4));
      expect(r.params, <String, dynamic>{'a': 1, 'shared': 'route', 'b': 2});
      expect(r.requiredAccessTokens, <String>['tok']);
      expect(r.modelCandidates, <ZChatModelRef>[_routeModel, _routeFb]);
    });

    test('tâche NON déclarée : tout vient de la racine', () {
      final ZChatRouteResolution r = ZChatRouteResolution.from(
        _router(),
        'unknown',
      );
      expect(r.declared, isFalse);
      expect(r.model, _rootModel);
      expect(r.fallbacks, const <ZChatModelRef>[_rootFb]);
      expect(r.computeEffort, ZChatComputeEffort(2));
      expect(r.params, <String, dynamic>{'a': 1, 'shared': 'root'});
      expect(r.requiredAccessTokens, isEmpty);
      expect(r.handlerId, isNull);
    });

    test('route déclarée SANS modèle : le couple (modèle, replis) vient '
        'ENTIER de la racine', () {
      final ZChatRouteResolution r = ZChatRouteResolution.from(
        _router(),
        'bare',
      );
      expect(r.declared, isTrue);
      expect(r.model, _rootModel);
      expect(r.fallbacks, const <ZChatModelRef>[_rootFb]);
      expect(r.computeEffort, ZChatComputeEffort(2));
    });

    test('couple SOLIDAIRE : une route qui ne déclare que des replis ne '
        'reçoit PAS le modèle de la racine', () {
      final ZChatRouteResolution r = ZChatRouteResolution.from(
        _router(),
        'fallbacksOnly',
      );
      expect(r.model, isNull);
      expect(r.fallbacks, const <ZChatModelRef>[_routeFb]);
      expect(r.modelCandidates, const <ZChatModelRef>[_routeFb]);
    });

    test('`modelCandidates` dédoublonne', () {
      final ZChatRouteResolution r = ZChatRouteResolution.from(
        ZChatRouter(
          model: _rootModel,
          fallbacks: const <ZChatModelRef>[_rootModel, _rootFb, _rootFb],
        ),
        'k',
      );
      expect(r.modelCandidates, const <ZChatModelRef>[_rootModel, _rootFb]);
    });
  });

  group('ZChatRouteResolution.toRequest', () {
    test('GARDE D\'IDENTITÉ : résolution vide ⇒ requête == base', () {
      final ZChatRouteResolution empty = ZChatRouteResolution.from(
        const ZChatRouter(),
        'k',
      );
      expect(empty.isEmpty, isTrue);
      final ZChatGenerationRequest base = _base();
      final ZChatGenerationRequest out = empty.toRequest(base);
      expect(out, base);
      expect(out.hashCode, base.hashCode);
    });

    test('fournisseur ET modèle de la route quand la base ne choisit pas', () {
      final ZChatGenerationRequest out = ZChatRouteResolution.from(
        _router(),
        'full',
      ).toRequest(_base());
      expect(out.providerId, 'p1');
      expect(out.modelId, 'm1');
      expect(out.computeEffort, ZChatComputeEffort(4));
    });

    test('`base.modelId` PRIME, avec SON fournisseur (même null)', () {
      final ZChatGenerationRequest out = ZChatRouteResolution.from(
        _router(),
        'full',
      ).toRequest(_base(modelId: 'mine'));
      expect(out.modelId, 'mine');
      expect(out.providerId, isNull);
      final ZChatGenerationRequest out2 = ZChatRouteResolution.from(
        _router(),
        'full',
      ).toRequest(_base(modelId: 'mine', providerId: 'pm'));
      expect(out2.providerId, 'pm');
    });

    test('`extra` : params de la route, RECOUVERTS par ceux de l\'hôte', () {
      final ZChatGenerationRequest out = ZChatRouteResolution.from(
        _router(),
        'full',
      ).toRequest(_base());
      expect(out.extra, <String, dynamic>{
        'a': 1,
        'b': 2,
        'shared': 'host',
        'host': 'h',
      });
    });

    test('`updated_at` dans `params` n\'atteint JAMAIS la requête', () {
      final ZChatRouter r = ZChatRouter.fromMap(<String, dynamic>{
        'params': <String, dynamic>{'ok': 1, ZSyncMeta.kUpdatedAt: 'x'},
        'routes': <Object?>[
          <String, dynamic>{
            'task_key': 'k',
            'params': <String, dynamic>{ZSyncMeta.kIsDeleted: true},
          },
        ],
      });
      final ZChatGenerationRequest out = ZChatRouteResolution.from(
        r,
        'k',
      ).toRequest(ZChatGenerationRequest(style: ZChatGenerationStyle('k')));
      expect(out.extra, <String, dynamic>{'ok': 1});
    });

    test('effort : réglage > résolution > base ; autres réglages remplacés', () {
      final ZChatRouteResolution res = ZChatRouteResolution.from(
        _router(),
        'full',
      );
      final ZChatGenerationRequest base = _base();
      final ZChatGenerationRequest reglee = res.toRequest(
        base,
        settings: ZChatGenerationSettings(computeEffort: ZChatComputeEffort(5)),
      );
      expect(reglee.computeEffort, ZChatComputeEffort(5));
      // Un porteur vide REMPLACE les autres réglages (forme de `withSettings`).
      expect(reglee.responseLength, isNull);
      expect(reglee.revealThinkingSteps, isNull);
      final ZChatGenerationRequest sansEffort = res.toRequest(
        base,
        settings: const ZChatGenerationSettings(),
      );
      expect(sansEffort.computeEffort, ZChatComputeEffort(4));
      final ZChatGenerationRequest sansRien = ZChatRouteResolution.from(
        const ZChatRouter(),
        'k',
      ).toRequest(base);
      expect(sansRien.computeEffort, ZChatComputeEffort(1));
    });

    test('`providerId` transporté par withSettings / withCorpusScope / '
        'toRequest', () {
      final ZChatGenerationRequest base = _base(modelId: 'm', providerId: 'p');
      expect(base.withSettings(base.settings).providerId, 'p');
      expect(base.withSettings(base.settings), base);
      expect(base.withCorpusScope(null).providerId, 'p');
      expect(
        ZChatRouteResolution.from(_router(), 'full').toRequest(base).providerId,
        'p',
      );
      // `providerId` participe à l'égalité.
      expect(_base(modelId: 'm', providerId: 'q') == base, isFalse);
    });
  });

  group('ZChatInMemoryRouteCatalog / ZChatInertRouteCatalog', () {
    test('inactif exclu de la liste et introuvable à la résolution', () async {
      final ZChatInMemoryRouteCatalog c = ZChatInMemoryRouteCatalog(
        <ZChatRouter>[_router(), const ZChatRouter(id: 'off', isActive: false)],
      );
      final List<ZChatRouter> listed = (await c.listRouters()).getOrElse(
        () => <ZChatRouter>[],
      );
      expect(listed.map((ZChatRouter r) => r.id), <String>['r1']);
      final ZResult<ZChatRouter> off = await c.resolveRouter('off');
      expect(off.isLeft(), isTrue);
      off.fold(
        (ZFailure f) => expect(f, isA<ZNotFoundFailure>()),
        (_) => fail('inactif ⇒ Left'),
      );
      expect((await c.resolveRouter('r1')).isRight(), isTrue);
      expect((await c.resolveRouter('absent')).isLeft(), isTrue);
    });

    test(
      'éphémère ignoré ; `withRouter` remplace ; `without` retire',
      () async {
        final ZChatInMemoryRouteCatalog c = ZChatInMemoryRouteCatalog(
          <ZChatRouter>[const ZChatRouter(name: 'ephemeral'), _router()],
        );
        expect(c.ids, <String>['r1']);
        final ZChatInMemoryRouteCatalog c2 = c.withRouter(
          _router().copyWith(name: 'renamed'),
        );
        expect(c2.ids, <String>['r1']);
        expect(
          (await c2.resolveRouter('r1')).getOrElse(() => _router()).name,
          'renamed',
        );
        // L'original est INCHANGÉ (valeur, pas état).
        expect(
          (await c.resolveRouter('r1')).getOrElse(() => _router()).name,
          'n',
        );
        expect(c2.without('r1').ids, isEmpty);
        expect(identical(c.withRouter(const ZChatRouter()), c), isTrue);
      },
    );

    test('catalogue inerte : refus typé et liste vide', () async {
      const ZChatInertRouteCatalog c = ZChatInertRouteCatalog();
      final ZResult<ZChatRouter> r = await c.resolveRouter('x');
      r.fold((ZFailure f) {
        expect(f, isA<ZUnsupportedOperationFailure>());
        expect((f as ZUnsupportedOperationFailure).operation, 'resolveRouter');
      }, (_) => fail('inerte ⇒ Left'));
      expect(
        (await c.listRouters()).getOrElse(
          () => <ZChatRouter>[const ZChatRouter()],
        ),
        isEmpty,
      );
      await c.invalidate();
    });
  });

  group('ZChatRouteHandlers', () {
    test('inerte ⇒ null ; annuaire mémoire immuable', () {
      const ZChatInertRouteHandlers inert = ZChatInertRouteHandlers();
      expect(inert.streamPortFor('h'), isNull);
      expect(inert.generationPortFor('h'), isNull);
      const ZChatMapRouteHandlers empty = ZChatMapRouteHandlers();
      final _Port port = _Port();
      final ZChatMapRouteHandlers filled = empty
          .withStreamPort('h', port)
          .withGenerationPort('g', port);
      expect(empty.streamIds, isEmpty);
      expect(identical(filled.streamPortFor('h'), port), isTrue);
      expect(identical(filled.generationPortFor('g'), port), isTrue);
      expect(filled.streamPortFor('g'), isNull);
      expect(filled.generationIds, <String>['g']);
    });
  });
}

class _Port implements ZChatStreamPort, ZChatGenerationPort {
  @override
  Future<ZResult<List<ZContentBlock>>> generate(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async => const Right<ZFailure, List<ZContentBlock>>(<ZContentBlock>[]);

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) => const Stream<ZResult<ZChatStreamEvent>>.empty();
}
