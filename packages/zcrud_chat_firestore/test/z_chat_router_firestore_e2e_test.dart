// Bout-en-bout de `buildChatRouterFirestoreRepository` sur
// `FakeFirebaseFirestore` : forme canonique, forme legacy passée par un codec
// d'hôte, document corrompu écarté (et journalisé), soft-delete / restore,
// round-trip à travers Firestore, et la raison pour laquelle une collection
// legacy impose `ZDeletionSemantics.absentMeansAlive`.
//
// Le codec legacy ci-dessous est un EXEMPLE minimal, propriété du test : il
// reproduit la forme d'un hôte qui persiste ses routeurs en camelCase, une
// paire `<tâche>Model` / `<tâche>FallbackModels` par tâche, un palier sous
// `workflowEffort`, des paramètres de flashcards sous `questionsCounts`, et
// un fournisseur sous `aiProvider`. Le paquet ne porte PAS ce codec : il
// fournit le point d'accroche, le test prouve le branchement.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_firestore/zcrud_chat_firestore.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

const String _kPath = 'routers_under_test';

// ───────────────────────── Codec legacy d'exemple ───────────────────────────

/// Clé racine d'un hôte legacy ⇒ modèle de référence (pas une route).
const String _kRootModelKey = 'aiModel';

/// camelCase d'hôte → forme canonique de `ZChatRouter`.
Map<String, dynamic> _legacyToCanonical(Map<String, dynamic> raw) {
  final Map<String, dynamic> out = <String, dynamic>{};
  final Map<String, Map<String, dynamic>> routes =
      <String, Map<String, dynamic>>{};
  final RegExp modelKey = RegExp(r'^([a-z][A-Za-z]*)Model$');
  final RegExp fallbackKey = RegExp(r'^([a-z][A-Za-z]*)FallbackModels$');

  Map<String, dynamic> route(String task) =>
      routes.putIfAbsent(task, () => <String, dynamic>{'task_key': task});

  for (final MapEntry<String, dynamic> e in raw.entries) {
    final String k = e.key;
    final Object? v = e.value;
    if (k == 'id' || k == 'name' || k == 'description') {
      out[k] = v;
    } else if (k == 'aiProvider') {
      out['model_provider_id'] = v;
    } else if (k == _kRootModelKey) {
      out['model_id'] = v;
    } else if (k == 'aiFallbackModels') {
      out['fallbacks'] = v;
    } else if (k == 'workflowEffort') {
      out['tier'] = v;
    } else if (k == 'questionsCounts') {
      route('flashcards')['params'] = <String, dynamic>{'questions_counts': v};
    } else if (modelKey.firstMatch(k) case final RegExpMatch m) {
      route(m.group(1)!)['model_id'] = v;
    } else if (fallbackKey.firstMatch(k) case final RegExpMatch m) {
      route(m.group(1)!)['fallbacks'] = v;
    } else {
      out[k] = v; // clés inconnues : verbatim (dont `is_deleted`/`updated_at`)
    }
  }
  if (routes.isNotEmpty) out['routes'] = routes.values.toList();
  return out;
}

/// Forme canonique → camelCase d'hôte (inverse exact sur le sous-ensemble
/// que le test exerce).
Map<String, dynamic> _canonicalToLegacy(Map<String, dynamic> canonical) {
  final Map<String, dynamic> out = <String, dynamic>{};
  for (final MapEntry<String, dynamic> e in canonical.entries) {
    final String k = e.key;
    final Object? v = e.value;
    switch (k) {
      case 'model_provider_id':
        out['aiProvider'] = v;
      case 'model_id':
        out[_kRootModelKey] = v;
      case 'fallbacks':
        out['aiFallbackModels'] = v;
      case 'tier':
        out['workflowEffort'] = v;
      case 'routes':
        for (final Object? r in v as List) {
          final Map<String, dynamic> m = r! as Map<String, dynamic>;
          final String task = m['task_key'] as String;
          if (m['model_id'] != null) out['${task}Model'] = m['model_id'];
          if (m['fallbacks'] != null) {
            out['${task}FallbackModels'] = m['fallbacks'];
          }
          final Object? params = m['params'];
          if (task == 'flashcards' && params is Map) {
            out['questionsCounts'] = params['questions_counts'];
          }
        }
      default:
        out[k] = v;
    }
  }
  return out;
}

// ───────────────────────── Jeux de données ──────────────────────────────────

Map<String, dynamic> _canonicalDoc(String name, {bool deleted = false}) =>
    <String, dynamic>{
      'name': name,
      'is_active': true,
      'tier': 'gold',
      'model_provider_id': 'prov-a',
      'model_id': 'model-a',
      'routes': <Map<String, dynamic>>[
        <String, dynamic>{'task_key': 'chat', 'model_id': 'model-chat'},
      ],
      'is_deleted': deleted,
      'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    };

/// Document tel qu'un hôte legacy l'a écrit : camelCase, SANS `is_deleted`
/// ni `updated_at`.
Map<String, dynamic> _legacyDoc(String name) => <String, dynamic>{
      'name': name,
      'aiProvider': 'prov-legacy',
      'aiModel': 'legacy-root',
      'aiFallbackModels': <String>['legacy-root-fb'],
      'chatModel': 'legacy-chat',
      'chatFallbackModels': <String>['legacy-chat-fb1', 'legacy-chat-fb2'],
      'flashcardsModel': 'legacy-cards',
      'workflowEffort': 'high',
      'questionsCounts': <String, dynamic>{'mcq': 5.0, 'open': 2.0},
    };

/// Document qui n'est PAS un routeur : `routes` est une chaîne, `is_active`
/// un texte libre. `ZChatRouter.fromMap` l'avalerait en routeur vide actif.
Map<String, dynamic> _corruptDoc() => <String, dynamic>{
      'name': 'corrupt',
      'routes': 'oops',
      'is_active': 'maybe',
      'is_deleted': false,
    };

Future<void> _seed(FakeFirebaseFirestore fs, String id, Map<String, dynamic> body) =>
    fs.collection(_kPath).doc(id).set(<String, dynamic>{...body, 'id': id});

Future<FakeFirebaseFirestore> _seededMixedCollection() async {
  final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
  await _seed(fs, 'c1', _canonicalDoc('canon-1'));
  await _seed(fs, 'c2', _canonicalDoc('canon-2'));
  await _seed(fs, 'l1', _legacyDoc('legacy-1'));
  await _seed(fs, 'l2', _legacyDoc('legacy-2'));
  await _seed(fs, 'bad', _corruptDoc());
  await _seed(fs, 'gone', _canonicalDoc('deleted', deleted: true));
  return fs;
}

class _Log {
  final List<String> messages = <String>[];
  void call(String message, {Object? error, StackTrace? stackTrace}) =>
      messages.add(message);
}

ZRepository<ZChatRouter> _legacyAwareRepo(
  FirebaseFirestore fs, {
  ZDeletionSemantics semantics = ZDeletionSemantics.absentMeansAlive,
  ZFirestoreLog? logger,
}) =>
    buildChatRouterFirestoreRepository(
      firestore: fs,
      collectionPath: _kPath,
      toCanonical: _legacyToCanonical,
      toLegacy: _canonicalToLegacy,
      deletionSemantics: semantics,
      logger: logger,
    );

ZRepository<ZChatRouter> _legacyAwareRepoLogged(
  FirebaseFirestore fs,
  _Log log,
) =>
    _legacyAwareRepo(fs, logger: log.call);

List<ZChatRouter> _ok(ZResult<List<ZChatRouter>> r) =>
    r.getOrElse(() => fail('lecture échouée : $r'));

void main() {
  group('lecture d\'une collection mixte (absentMeansAlive)', () {
    test('les 4 vivants sont lus, le corrompu écarté et journalisé, le '
        'supprimé invisible', () async {
      final FakeFirebaseFirestore fs = await _seededMixedCollection();
      final _Log log = _Log();
      final ZRepository<ZChatRouter> repo = _legacyAwareRepoLogged(fs, log);

      final List<ZChatRouter> all = _ok(await repo.getAll());
      final Set<String?> ids = all.map((ZChatRouter r) => r.id).toSet();
      expect(ids, <String>{'c1', 'c2', 'l1', 'l2'});
      expect(ids, isNot(contains('bad')));
      expect(ids, isNot(contains('gone')));
      expect(
        log.messages.where((String m) => m.contains('id=bad')),
        hasLength(1),
        reason: 'le document corrompu doit être journalisé une fois : $log',
      );
    });

    test('le codec legacy est APPLIQUÉ : routes[], tier, fournisseur, params',
        () async {
      final FakeFirebaseFirestore fs = await _seededMixedCollection();
      final ZRepository<ZChatRouter> repo = _legacyAwareRepo(fs);

      final ZChatRouter l1 =
          (await repo.getById('l1')).getOrElse(() => fail('l1 illisible'));
      expect(l1.name, 'legacy-1');
      expect(l1.tier, 'high');
      expect(
        l1.model,
        const ZChatModelRef(providerId: 'prov-legacy', modelId: 'legacy-root'),
      );
      expect(l1.fallbacks, <ZChatModelRef>[
        const ZChatModelRef(modelId: 'legacy-root-fb'),
      ]);
      expect(l1.routes.keys, unorderedEquals(<String>['chat', 'flashcards']));
      expect(l1.routeOf('chat')!.model!.modelId, 'legacy-chat');
      expect(
        l1.routeOf('chat')!.fallbacks.map((ZChatModelRef f) => f.modelId),
        <String>['legacy-chat-fb1', 'legacy-chat-fb2'],
      );
      expect(l1.routeOf('flashcards')!.model!.modelId, 'legacy-cards');
      expect(
        l1.routeOf('flashcards')!.params['questions_counts'],
        <String, dynamic>{'mcq': 5.0, 'open': 2.0},
      );
      // Rien de la forme legacy ne fuit dans `extra`.
      expect(l1.extra.keys.where((String k) => k.endsWith('Model')), isEmpty);
    });

    test('un document canonique est lu tel quel à travers le codec', () async {
      final FakeFirebaseFirestore fs = await _seededMixedCollection();
      final ZRepository<ZChatRouter> repo = _legacyAwareRepo(fs);
      final ZChatRouter c1 =
          (await repo.getById('c1')).getOrElse(() => fail('c1 illisible'));
      expect(c1.name, 'canon-1');
      expect(c1.tier, 'gold');
      expect(c1.model, const ZChatModelRef(providerId: 'prov-a', modelId: 'model-a'));
      expect(c1.routeOf('chat')!.model!.modelId, 'model-chat');
    });

    test('getById du corrompu ⇒ Left(ZNotFoundFailure)', () async {
      final FakeFirebaseFirestore fs = await _seededMixedCollection();
      final ZRepository<ZChatRouter> repo = _legacyAwareRepo(fs);
      final ZResult<ZChatRouter> r = await repo.getById('bad');
      expect(r.isLeft(), isTrue);
      r.fold(
        (ZFailure f) => expect(f, isA<ZNotFoundFailure>()),
        (_) => fail('un document corrompu ne doit pas être décodé'),
      );
    });

    test('sans codec, un document legacy tombe dans le tri défensif ou dans '
        '`extra`, jamais en routeur routé', () async {
      // Sans `toCanonical`, la forme camelCase n'est pas lisible : aucune
      // clé du schéma hors `name`, donc le document EST lu (il a `name`)
      // mais ne porte ni route ni modèle — le codec est bien ce qui donne
      // son sens au document.
      final FakeFirebaseFirestore fs = await _seededMixedCollection();
      final ZRepository<ZChatRouter> repo = buildChatRouterFirestoreRepository(
        firestore: fs,
        collectionPath: _kPath,
        deletionSemantics: ZDeletionSemantics.absentMeansAlive,
      );
      final ZChatRouter l1 =
          (await repo.getById('l1')).getOrElse(() => fail('l1 illisible'));
      expect(l1.routes, isEmpty);
      expect(l1.model, isNull);
      expect(l1.tier, isNull);
      expect(l1.extra['chatModel'], 'legacy-chat');
    });
  });

  group('écritures', () {
    test('save d\'un routeur éphémère ⇒ is_deleted:false, updated_at ISO, '
        'routes en LISTE (sans codec)', () async {
      final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
      final ZRepository<ZChatRouter> repo = buildChatRouterFirestoreRepository(
        firestore: fs,
        collectionPath: _kPath,
      );
      final ZChatRouter ephemeral = ZChatRouter(
        name: 'fresh',
        tier: 'silver',
        model: const ZChatModelRef(providerId: 'p', modelId: 'm'),
        routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[
          ZChatRouteSpec(
            taskKey: 'chat',
            model: const ZChatModelRef(modelId: 'm-chat'),
            fallbacks: const <ZChatModelRef>[ZChatModelRef(modelId: 'fb')],
            computeEffort: ZChatComputeEffort.fromJson(3),
            params: const <String, dynamic>{'temperature': 0.2},
          ),
          ZChatRouteSpec(taskKey: 'summary', handlerId: 'h1'),
        ]),
      );
      expect(ephemeral.isEphemeral, isTrue);

      final ZChatRouter saved =
          (await repo.save(ephemeral)).getOrElse(() => fail('save'));
      expect(saved.id, isNotNull);
      expect(saved.isEphemeral, isFalse);

      final Map<String, dynamic> doc =
          (await fs.collection(_kPath).doc(saved.id).get()).data()!;
      expect(doc['is_deleted'], false);
      expect(doc['id'], saved.id);
      expect(doc['updated_at'], isA<String>());
      expect(DateTime.tryParse(doc['updated_at'] as String), isNotNull);
      expect(doc['routes'], isA<List<dynamic>>());
      final List<dynamic> routes = doc['routes'] as List<dynamic>;
      expect(routes, hasLength(2));
      expect(
        routes.map((dynamic r) => (r as Map<String, dynamic>)['task_key']),
        unorderedEquals(<String>['chat', 'summary']),
      );
      expect(doc['tier'], 'silver');
      expect(doc['model_provider_id'], 'p');
      expect(doc['model_id'], 'm');

      // Round-trip à travers Firestore : l'entité relue est ÉGALE (hors id).
      expect(saved, ephemeral.copyWith(id: saved.id));
      final ZChatRouter again =
          (await repo.getById(saved.id!)).getOrElse(() => fail('getById'));
      expect(again, saved);
    });

    test('save AVEC codec ⇒ document écrit en forme legacy, relu égal',
        () async {
      final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
      final ZRepository<ZChatRouter> repo = _legacyAwareRepo(fs);
      final ZChatRouter r = ZChatRouter(
        name: 'legacy-write',
        tier: 'high',
        model: const ZChatModelRef(providerId: 'prov', modelId: 'root'),
        fallbacks: const <ZChatModelRef>[ZChatModelRef(modelId: 'root-fb')],
        routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[
          ZChatRouteSpec(
            taskKey: 'chat',
            model: const ZChatModelRef(modelId: 'chat-m'),
            fallbacks: const <ZChatModelRef>[ZChatModelRef(modelId: 'chat-fb')],
          ),
          ZChatRouteSpec(
            taskKey: 'flashcards',
            model: const ZChatModelRef(modelId: 'cards-m'),
            params: const <String, dynamic>{
              'questions_counts': <String, dynamic>{'mcq': 3.0},
            },
          ),
        ]),
      );
      final ZChatRouter saved = (await repo.save(r)).getOrElse(() => fail('save'));

      final Map<String, dynamic> doc =
          (await fs.collection(_kPath).doc(saved.id).get()).data()!;
      // Forme legacy sur le fil…
      expect(doc['aiModel'], 'root');
      expect(doc['aiProvider'], 'prov');
      expect(doc['aiFallbackModels'], <String>['root-fb']);
      expect(doc['chatModel'], 'chat-m');
      expect(doc['chatFallbackModels'], <String>['chat-fb']);
      expect(doc['flashcardsModel'], 'cards-m');
      expect(doc['workflowEffort'], 'high');
      expect(doc['questionsCounts'], <String, dynamic>{'mcq': 3.0});
      expect(doc.containsKey('routes'), isFalse);
      expect(doc.containsKey('model_id'), isFalse);
      // …métadonnées de sync posées par le dépôt, hors codec.
      expect(doc['is_deleted'], false);
      expect(doc['updated_at'], isA<String>());

      // Round-trip : fromMap(toMap(r)) == r à travers Firestore.
      expect(saved, r.copyWith(id: saved.id));
      final ZChatRouter again =
          (await repo.getById(saved.id!)).getOrElse(() => fail('getById'));
      expect(again, saved);
    });

    test('softDelete ⇒ getById Left(ZNotFoundFailure) ; restore ⇒ revisible',
        () async {
      final FakeFirebaseFirestore fs = await _seededMixedCollection();
      final ZRepository<ZChatRouter> repo = _legacyAwareRepo(fs);

      expect((await repo.softDelete('l1')).isRight(), isTrue);
      final ZResult<ZChatRouter> afterDelete = await repo.getById('l1');
      afterDelete.fold(
        (ZFailure f) => expect(f, isA<ZNotFoundFailure>()),
        (_) => fail('l1 doit être invisible après softDelete'),
      );
      expect(
        _ok(await repo.getAll()).map((ZChatRouter r) => r.id),
        unorderedEquals(<String>['c1', 'c2', 'l2']),
      );

      expect((await repo.restore('l1')).isRight(), isTrue);
      final ZChatRouter back =
          (await repo.getById('l1')).getOrElse(() => fail('l1 après restore'));
      expect(back.name, 'legacy-1');
      expect(
        _ok(await repo.getAll()).map((ZChatRouter r) => r.id),
        unorderedEquals(<String>['c1', 'c2', 'l1', 'l2']),
      );
    });
  });

  group('sémantique de suppression', () {
    test('strict sur une collection legacy ⇒ 0 routeur lu (pourquoi '
        'absentMeansAlive est obligatoire)', () async {
      final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
      await _seed(fs, 'l1', _legacyDoc('legacy-1'));
      await _seed(fs, 'l2', _legacyDoc('legacy-2'));

      final ZRepository<ZChatRouter> strict =
          _legacyAwareRepo(fs, semantics: ZDeletionSemantics.strict);
      expect(_ok(await strict.getAll()), isEmpty);
      expect((await strict.getById('l1')).isLeft(), isTrue);

      final ZRepository<ZChatRouter> lenient = _legacyAwareRepo(fs);
      expect(_ok(await lenient.getAll()), hasLength(2));
    });

    test('un save en absentMeansAlive pose le drapeau : le document devient '
        'lisible en strict', () async {
      final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
      await _seed(fs, 'l1', _legacyDoc('legacy-1'));
      final ZRepository<ZChatRouter> lenient = _legacyAwareRepo(fs);
      final ZChatRouter l1 =
          (await lenient.getById('l1')).getOrElse(() => fail('l1'));
      expect((await lenient.save(l1)).isRight(), isTrue);

      final ZRepository<ZChatRouter> strict =
          _legacyAwareRepo(fs, semantics: ZDeletionSemantics.strict);
      expect(
        _ok(await strict.getAll()).map((ZChatRouter r) => r.id),
        <String>['l1'],
      );
    });
  });

  group('zChatRouterShapeIssue', () {
    test('une map canonique lisible rend null', () {
      expect(zChatRouterShapeIssue(_canonicalDoc('x')), isNull);
      expect(zChatRouterShapeIssue(<String, dynamic>{'is_active': true}), isNull);
      expect(
        zChatRouterShapeIssue(<String, dynamic>{
          'routes': <String, dynamic>{'chat': <String, dynamic>{}},
        }),
        isNull,
        reason: 'la forme objet des routes est tolérée par le noyau',
      );
    });

    test('un document sans aucune clé du schéma n\'est pas un routeur', () {
      expect(zChatRouterShapeIssue(<String, dynamic>{'id': 'x'}), isNotNull);
      expect(
        zChatRouterShapeIssue(<String, dynamic>{'id': 'x', 'foo': 1}),
        isNotNull,
      );
    });

    test('un champ du schéma au type illisible est signalé', () {
      expect(zChatRouterShapeIssue(<String, dynamic>{'routes': 'oops'}),
          contains('routes'));
      expect(zChatRouterShapeIssue(<String, dynamic>{'is_active': 'maybe'}),
          contains('is_active'));
      expect(zChatRouterShapeIssue(<String, dynamic>{'fallbacks': 'a'}),
          contains('fallbacks'));
      expect(
        zChatRouterShapeIssue(<String, dynamic>{'name': 'n', 'params': 3}),
        contains('params'),
      );
      expect(zChatRouterShapeIssue(<String, dynamic>{'tier': 42}),
          contains('tier'));
      expect(zChatRouterShapeIssue(<String, dynamic>{'model': 7}),
          contains('model'));
      expect(
        zChatRouterShapeIssue(<String, dynamic>{'compute_effort': <int>[]}),
        contains('compute_effort'),
      );
    });
  });

  group('robustesse du codec d\'hôte', () {
    test('un toCanonical qui lève écarte le document sans casser la lecture',
        () async {
      final FakeFirebaseFirestore fs = FakeFirebaseFirestore();
      await _seed(fs, 'ok', _canonicalDoc('ok'));
      await _seed(fs, 'boom', <String, dynamic>{...(_canonicalDoc('boom')), 'explode': true});
      final _Log log = _Log();
      final ZRepository<ZChatRouter> repo = buildChatRouterFirestoreRepository(
        firestore: fs,
        collectionPath: _kPath,
        toCanonical: (Map<String, dynamic> raw) {
          if (raw['explode'] == true) throw StateError('codec cassé');
          return raw;
        },
        logger: log.call,
      );
      expect(
        _ok(await repo.getAll()).map((ZChatRouter r) => r.id),
        <String>['ok'],
      );
      expect(log.messages.where((String m) => m.contains('id=boom')), hasLength(1));
    });
  });
}
