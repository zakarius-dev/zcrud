// Lot RT — le routage par tâche côté assemblage : `ZChatRouteSession`, le
// seam `routeResolver` de `ZChatController._launch` (partagé par l'envoi,
// l'édition rejouée et la régénération), le seam d'artefact de
// `ZChatNotebookController._generate`, les ports routés, la projection de
// feuille et l'assemblage commun des deux écrans.
//
// Gardes DÉJÀ existantes, citées et non doublonnées :
// * `z_chat_structure_guard_test.dart` G-CH1 — la surface publique du
//   contrôleur est INCHANGÉE (un paramètre nommé n'est pas un membre) ;
// * `z_chat_settings_guard_test.dart` — aucun second site d'envoi ;
// * `z_chat_purity_test.dart` — le partitionneur scanne TOUT `lib/`, donc
//   `routing/` (RT-G9 en asserte ici la non-vacuité) ;
// * `z_chat_lot_g2_screen_test.dart` G2-2 — l'étalon de l'écran de fil de
//   travail sans session (arbre des briques).
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const String _controllerFile = 'lib/src/presentation/z_chat_controller.dart';
const String _sessionFile =
    'lib/src/presentation/routing/z_chat_route_session.dart';
const String _screenFile =
    'lib/src/presentation/view/z_chat_conversation_screen.dart';

// ── Routeurs de référence ───────────────────────────────────────────────────

const ZChatModelRef _root = ZChatModelRef(providerId: 'p0', modelId: 'm0');
const ZChatModelRef _ma = ZChatModelRef(providerId: 'pa', modelId: 'ma');
const ZChatModelRef _mb = ZChatModelRef(providerId: 'pb', modelId: 'mb');
const ZChatModelRef _mx = ZChatModelRef(providerId: 'px', modelId: 'mx');
const ZChatModelRef _my = ZChatModelRef(providerId: 'py', modelId: 'my');

ZChatRouteSpec _testRoute({ZChatModelRef model = _ma}) => ZChatRouteSpec(
  taskKey: 'test',
  routeName: 'rn',
  handlerId: 'h1',
  model: model,
  fallbacks: const <ZChatModelRef>[_mb],
  computeEffort: ZChatComputeEffort.fromJson(5),
  params: const <String, dynamic>{'temperature': 0.2},
  requiredAccessTokens: const <String>['tok'],
);

ZChatRouteSpec _artRoute() => ZChatRouteSpec(
  taskKey: 'art',
  model: _mx,
  fallbacks: const <ZChatModelRef>[_my],
);

ZChatRouteSpec _soloRoute() => ZChatRouteSpec(
  taskKey: 'solo',
  model: const ZChatModelRef(modelId: 's'),
);

ZChatRouter _ra() => ZChatRouter(
  id: 'ra',
  tier: 'gold',
  model: _root,
  routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[
    _testRoute(),
    _artRoute(),
    _soloRoute(),
  ]),
);

ZChatRouter _rb() => ZChatRouter(
  id: 'rb',
  tier: 'silver',
  routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[
    _testRoute(
      model: const ZChatModelRef(providerId: 'pz', modelId: 'mz'),
    ),
    _artRoute(),
    _soloRoute(),
  ]),
);

ZChatInMemoryRouteCatalog _catalog() =>
    ZChatInMemoryRouteCatalog(<ZChatRouter>[_ra(), _rb()]);

Future<ZChatRouteSession> _session({
  ZChatRouteGate gate = const ZAllowAllChatRouteGate(),
  String? initial = 'ra',
  ZChatRouteCatalogPort? catalog,
}) async {
  final ZChatRouteSession s = ZChatRouteSession(
    catalog: catalog ?? _catalog(),
    gate: gate,
    initialRouterId: initial,
  );
  addTearDown(s.dispose);
  await pumpEventQueue();
  return s;
}

ZChatGenerationRequest _req({
  String kind = 'test',
  String? modelId,
  ZChatComputeEffort? effort,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) => ZChatGenerationRequest(
  style: ZChatGenerationStyle(kind),
  subject: 'q',
  modelId: modelId,
  computeEffort: effort,
  extra: extra,
);

/// Refus de gouvernance, tel qu'un gate le rend.
final ZFailure _denied = const ZDenyAllChatRouteGate()
    .canRoute('test')
    .fold((ZFailure f) => f, (Unit _) => throw StateError('unreachable'));

ZChatMessage _user(String id, String text) => ZChatMessage(
  id: id,
  conversationId: 'c1',
  role: ZChatRole.user,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
);

ZChatMessage _assistant(String id, String text) => ZChatMessage(
  id: id,
  conversationId: 'c1',
  role: ZChatRole.assistant,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
);

List<ZChatMessage> _thread() => <ZChatMessage>[
  _user('q1', 'première question'),
  _assistant('r1', 'première réponse'),
];

/// Port de cycle de vie inerte — rend l'édition et la régénération NATIVES.
class _Lifecycle implements ZChatConversationLifecyclePort {
  @override
  Future<ZResult<int>> trimAfter({
    required String conversationId,
    required String messageId,
  }) async => const Right<ZFailure, int>(1);
  @override
  Future<ZResult<Unit>> retire(String conversationId) async =>
      const Right<ZFailure, Unit>(unit);
  @override
  Future<ZResult<Unit>> restore(String conversationId) async =>
      const Right<ZFailure, Unit>(unit);
  @override
  Future<ZResult<int>> retireAll(List<String> ids) async =>
      const Right<ZFailure, int>(0);
}

/// Contrôleur câblé sur un résolveur de route donné (ou aucun).
({
  ZChatController c,
  FakeStreamPort port,
  ZChatGenerationRequest Function() last,
})
_controller({
  ZChatRouteResolver? resolver,
  List<ZChatMessage> initial = const <ZChatMessage>[],
  ZChatLiveLabels labels = ZChatLiveLabels.none,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  final FakeStreamPort port = FakeStreamPort();
  final SeqIds ids = SeqIds();
  ZChatGenerationRequest? built;
  final ZChatController c = ZChatController(
    streamPort: port,
    actionExecutor: SpyExecutor(),
    confirm: (ZChatActionPlan _) async => true,
    newRequestId: ids.next,
    buildRequest: (ZChatDraft d) => built = ZChatGenerationRequest(
      style: ZChatGenerationStyle('test'),
      subject: d.text,
      attachmentIds: d.attachmentIds,
      extra: extra,
    ),
    lifecycle: _Lifecycle(),
    routeResolver: resolver,
    liveLabels: labels,
    conversationId: 'c1',
    initialMessages: initial,
  );
  addTearDown(c.dispose);
  addTearDown(port.closeAll);
  return (c: c, port: port, last: () => built!);
}

class _Tally {
  _Tally(Listenable l) {
    l.addListener(() => count++);
  }
  int count = 0;
}

/// Corps de [declaration] dans [file], dé-commenté.
List<String> _classBody(String file, String declaration) {
  final List<String> lines = stripped(libFile(file));
  final int start = lines.indexWhere(
    (String l) => RegExp('^$declaration\\b').hasMatch(l),
  );
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: '🔴 `$declaration` introuvable dans $file — garde VACUELLE',
  );
  final List<String> body = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\}').hasMatch(lines[i])) break;
    body.add(lines[i]);
  }
  expect(
    body.length,
    greaterThan(20),
    reason: '🔴 corps quasi vide (${body.length} lignes) : découpeur cassé',
  );
  return body;
}

/// Découpeur repris verbatim de G-CH1 (`z_chat_structure_guard_test.dart`).
Set<String> _publicMembers(List<String> body, String owner) {
  final RegExp getter = RegExp(r'^\s{2}[\w<>?,\s.]*\bget\s+(\w+)\b');
  final RegExp field = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*\s(\w+)\s*[;=]');
  final RegExp method = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*\(');
  final Set<String> names = <String>{};
  for (final String l in body) {
    if (!RegExp(r'^\s{2}\S').hasMatch(l)) continue;
    final RegExpMatch? m =
        getter.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m == null) continue;
    final String name = m.group(1)!;
    if (name.startsWith('_')) continue;
    if (name == owner) continue;
    if (name == 'override') continue;
    names.add(name);
  }
  return names;
}

/// Le corps de `_launch` dans le contrôleur, dé-commenté.
List<String> _launchBody() {
  final List<String> lines = stripped(libFile(_controllerFile));
  final int start = lines.indexWhere(
    (String l) => RegExp(r'\b_launch\(\{').hasMatch(l),
  );
  expect(start, greaterThanOrEqualTo(0), reason: '🔴 `_launch` introuvable');
  final List<String> body = <String>[];
  for (int i = start; i < lines.length; i++) {
    body.add(lines[i]);
    if (RegExp(r'^\s{2}\}\s*$').hasMatch(lines[i]) && i > start) break;
  }
  expect(
    body.length,
    greaterThan(30),
    reason: '🔴 `_launch` quasi vide : découpeur cassé',
  );
  return body;
}

int _firstIndex(List<String> lines, Pattern p) =>
    lines.indexWhere((String l) => l.contains(p));

/// Les types de l'arbre SOUS la vue de conversation, dans l'ordre.
List<String> _treeUnderView(WidgetTester tester) => <String>[
  for (final Element e
      in find
          .descendant(
            of: find.byType(ZChatConversationView),
            matching: find.byWidgetPredicate((Widget _) => true),
          )
          .evaluate())
    e.widget.runtimeType.toString(),
];

void main() {
  group('🔴 RT-G1 — ORDRE TEXTUEL dans `_launch`', () {
    test('le résolveur vient APRÈS les réglages, AVANT l\'état, le message '
        'optimiste et l\'annonce ; `_streamPort.stream(` est appelé UNE fois, '
        'dans `_drain`', () {
      final List<String> body = _launchBody();
      final int settings = _firstIndex(body, '.withSettings(');
      final int resolver = _firstIndex(body, '_routeResolver');
      final int state = _firstIndex(body, '_states[requestId] =');
      final int optimistic = _firstIndex(body, '_messages.value =');
      final int say = _firstIndex(body, '_say(');
      for (final (String, int) p in <(String, int)>[
        ('withSettings', settings),
        ('_routeResolver', resolver),
        ('_states[requestId] =', state),
        ('_messages.value =', optimistic),
        ('_say(', say),
      ]) {
        expect(
          p.$2,
          greaterThanOrEqualTo(0),
          reason: '🔴 `${p.$1}` introuvable dans `_launch` : garde VACUELLE',
        );
      }
      expect(
        resolver,
        greaterThan(settings),
        reason:
            '🔴 le routage doit voir la requête APRÈS les réglages : le '
            'budget de repli de la route s\'applique sous celui de la feuille',
      );
      expect(
        resolver,
        lessThan(state),
        reason: '🔴 un refus de route ne doit laisser AUCUN état de requête',
      );
      expect(
        resolver,
        lessThan(optimistic),
        reason: '🔴 un refus de route ne doit ajouter AUCUN message optimiste',
      );
      expect(
        resolver,
        lessThan(say),
        reason: '🔴 un refus de route ne doit rien ANNONCER',
      );

      final List<String> all = stripped(libFile(_controllerFile));
      final List<int> sites = <int>[
        for (int i = 0; i < all.length; i++)
          if (all[i].contains('_streamPort')) i,
      ];
      // Le champ, son initialisation, et l'unique appel de `_drain`.
      final List<int> calls = <int>[
        for (int i = 0; i < all.length; i++)
          if (RegExp(r'_streamPort\s*$').hasMatch(all[i]) ||
              all[i].contains('_streamPort.stream('))
            i,
      ];
      expect(
        calls,
        hasLength(1),
        reason:
            '🔴 le port est appelé depuis ${calls.length} sites : '
            '$sites — un second chemin d\'envoi contourne le routage',
      );
      expect(
        _launchBody().any((String l) => l.contains('_streamPort')),
        isFalse,
        reason: '🔴 `_launch` ne touche JAMAIS le port : c\'est `_drain`',
      );
    });

    test('🔬 contre-preuve — l\'indexeur VOIT un ordre inversé', () {
      const List<String> witness = <String>[
        '    _states[requestId] = x;',
        '    final r = _routeResolver;',
      ];
      expect(
        _firstIndex(witness, '_routeResolver'),
        greaterThan(_firstIndex(witness, '_states[requestId] =')),
      );
    });
  });

  group('🔴 RT-G2 — un REFUS n\'ouvre pas le tour', () {
    Future<void> expectRefused(
      ZChatController c,
      FakeStreamPort port, {
      required List<ZChatMessage> messagesBefore,
      required String draftBefore,
      required String announcementBefore,
    }) async {
      expect(
        port.calls,
        isEmpty,
        reason: '🔴 le port a été appelé malgré le refus de route',
      );
      final ZFailure? f = c.lastFailure.value;
      expect(f, isA<ZChatProviderFailure>());
      expect(
        (f! as ZChatProviderFailure).code,
        ZChatFailureCodes.upgradeRequired,
      );
      expect(
        c.messages.value,
        messagesBefore,
        reason:
            '🔴 le fil a bougé : message optimiste ou troncature non '
            'restituée',
      );
      expect(c.composer.text, draftBefore, reason: '🔴 la saisie a été perdue');
      expect(
        c.activeRequests.value,
        isEmpty,
        reason: '🔴 une requête reste EN VOL après un refus',
      );
      expect(
        c.liveAnnouncement.value,
        announcementBefore,
        reason: '🔴 un refus a été ANNONCÉ comme un tour lancé',
      );
    }

    test('`send` : port jamais appelé, `lastFailure` typé, fil et saisie '
        'intacts, `Left` rendu', () async {
      final r = _controller(
        resolver: (ZChatGenerationRequest _) =>
            Left<ZFailure, ZChatGenerationRequest>(_denied),
        initial: _thread(),
        labels: const ZChatLiveLabels(generationStarted: 'started'),
      );
      r.c.composer.text = 'question';
      final List<ZChatMessage> before = r.c.messages.value;
      final ZResult<ZChatRequestToken> res = await r.c.send();
      expect(res.isLeft(), isTrue);
      await expectRefused(
        r.c,
        r.port,
        messagesBefore: before,
        draftBefore: 'question',
        announcementBefore: '',
      );
    });

    test('ÉDITION rejouée : refusée au même endroit, les messages retirés '
        'localement sont RESTITUÉS', () async {
      final r = _controller(
        resolver: (ZChatGenerationRequest _) =>
            Left<ZFailure, ZChatGenerationRequest>(_denied),
        initial: _thread(),
      );
      final List<ZChatMessage> before = r.c.messages.value;
      final ZResult<ZChatActionOutcome> res = await r.c.runAction(
        const ZChatEditAction(messageId: 'q1', newText: 'corrigée'),
      );
      expect(res.isLeft(), isTrue);
      await expectRefused(
        r.c,
        r.port,
        messagesBefore: before,
        draftBefore: '',
        announcementBefore: '',
      );
    });

    test('RÉGÉNÉRATION : refusée, l\'ancienne réponse est conservée', () async {
      final r = _controller(
        resolver: (ZChatGenerationRequest _) =>
            Left<ZFailure, ZChatGenerationRequest>(_denied),
        initial: _thread(),
      );
      r.c.composer.text = 'brouillon';
      final List<ZChatMessage> before = r.c.messages.value;
      final ZResult<ZChatActionOutcome> res = await r.c.runAction(
        const ZChatRegenerateAction(messageId: 'r1'),
      );
      expect(res.isLeft(), isTrue);
      await expectRefused(
        r.c,
        r.port,
        messagesBefore: before,
        draftBefore: 'brouillon',
        announcementBefore: '',
      );
    });

    test(
      'un résolveur qui LÈVE vaut un refus (AD-10), jamais une exception',
      () async {
        final r = _controller(
          resolver: (ZChatGenerationRequest _) => throw StateError('boom'),
        );
        r.c.composer.text = 'q';
        final ZResult<ZChatRequestToken> res = await r.c.send();
        expect(res.isLeft(), isTrue);
        expect(r.c.lastFailure.value, isA<ZDomainFailure>());
        expect(r.port.calls, isEmpty);
      },
    );
  });

  group('🔴 RT-G3 — ÉTALONS de l\'hôte passif', () {
    test(
      'sans résolveur, la requête envoyée EST celle du builder (`identical`)',
      () async {
        final r = _controller();
        r.c.composer.text = 'q';
        final Future<ZResult<ZChatRequestToken>> sending = r.c.send();
        await pumpEventQueue();
        expect(
          identical(r.port.calls.single.request, r.last()),
          isTrue,
          reason:
              '🔴 la requête a été RECOPIÉE sans résolveur : l\'hôte '
              'passif ne doit payer aucune projection',
        );
        r.port.last.add(done());
        await sending;
      },
    );

    test('avec un résolveur qui rend `Right(request)`, la requête envoyée est '
        'celle rendue par lui', () async {
      final r = _controller(
        resolver: (ZChatGenerationRequest req) =>
            Right<ZFailure, ZChatGenerationRequest>(req),
      );
      r.c.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = r.c.send();
      await pumpEventQueue();
      expect(identical(r.port.calls.single.request, r.last()), isTrue);
      r.port.last.add(done());
      await sending;
    });

    testWidgets('écran de fil de travail SANS session : `modelBuilder` est '
        '`null`, la feuille n\'a AUCUNE entrée de repli', (
      WidgetTester tester,
    ) async {
      final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
      addTearDown(transcript.dispose);
      final FakeStreamPort port = FakeStreamPort();
      WidgetBuilder? presented;
      await tester.pumpWidget(
        harness(
          ZChatNotebookScreen(
            streamPort: port,
            transcript: transcript,
            conversationId: 'c1',
            cursorColor: const Color(0xFF000000),
            presentTools: (BuildContext _, WidgetBuilder sheet) async =>
                presented = sheet,
          ),
        ),
      );
      await tester.pump();
      final ZDefaultChatComposer composer = tester.widget<ZDefaultChatComposer>(
        find.byType(ZDefaultChatComposer),
      );
      expect(
        composer.modelBuilder,
        isNull,
        reason: '🔴 un sélecteur de routeur monté SANS session',
      );
      composer.onOpenTools!();
      final BuildContext context = tester.element(
        find.byType(ZChatNotebookScreen),
      );
      final Widget sheet = presented!(context);
      expect(
        sheet,
        isA<ZChatSettingsSheet>(),
        reason: 'sans outils ni session, la feuille est rendue NUE',
      );
      expect((sheet as ZChatSettingsSheet).entries, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('écran de CONVERSATION avec ses défauts ≡ briques assemblées à '
        'la main', (WidgetTester tester) async {
      final FakeStreamPort port = FakeStreamPort();
      await tester.pumpWidget(
        harness(
          ZChatConversationScreen(
            streamPort: port,
            conversationId: 'c1',
            initialMessages: _thread(),
            cursorColor: const Color(0xFF000000),
          ),
        ),
      );
      await tester.pump();
      final List<String> byScreen = _treeUnderView(tester);
      await tester.pumpWidget(const SizedBox());

      final ZChatController c = ZChatController(
        streamPort: port,
        actionExecutor: const ZChatUnsupportedActionExecutor(),
        confirm: zChatConfirmWithoutDialog,
        newRequestId: ZChatSequentialRequestIds('c1').call,
        buildRequest: ZChatDraftRequestBuilder(
          style: ZChatGenerationStyle.converse,
          conversationId: 'c1',
        ).call,
        conversationId: 'c1',
        initialMessages: _thread(),
      );
      addTearDown(c.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: c,
            composer: ZDefaultChatComposer(
              controller: c,
              settings: settings,
              cursorColor: const Color(0xFF000000),
            ),
          ),
        ),
      );
      await tester.pump();
      final List<String> byHand = _treeUnderView(tester);
      expect(byScreen, isNotEmpty);
      expect(byScreen, contains('ZDefaultChatComposer'));
      expect(
        byScreen,
        byHand,
        reason:
            '🔴 l\'écran de conversation rend un arbre DIFFÉRENT de '
            'l\'échappatoire : un hôte qui descend d\'un cran perdrait '
            'quelque chose',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 RT-G4 — GRANULARITÉ des tranches de la session', () {
    test(
      '`selectRouter(b)` notifie `routerId`, `router` et SEULES les '
      '`routeOf(k)` qui changent ; `routeOf(k)` est une instance STABLE',
      () async {
        final ZChatRouteSession s = await _session();
        expect(s.router.value?.id, 'ra');
        final ValueListenable<ZChatRouteSpec?> test1 = s.routeOf('test');
        expect(
          identical(test1, s.routeOf('test')),
          isTrue,
          reason:
              '🔴 `routeOf` recrée une tranche : un builder se '
              'ré-abonnerait à chaque rebuild',
        );
        final _Tally id = _Tally(s.routerId);
        final _Tally router = _Tally(s.router);
        final _Tally test = _Tally(test1);
        final _Tally art = _Tally(s.routeOf('art'));
        final _Tally solo = _Tally(s.routeOf('solo'));
        final _Tally failure = _Tally(s.catalogFailure);
        final r = _controller(resolver: s.resolve);
        final ZChatSettingsController settings = ZChatSettingsController();
        addTearDown(settings.dispose);
        final _Tally messages = _Tally(r.c.messages);
        final _Tally sett = _Tally(settings.settings);

        await s.selectRouter('rb');

        expect(id.count, 1);
        expect(router.count, 1);
        expect(test.count, 1, reason: 'la route `test` diffère entre ra et rb');
        expect(
          art.count,
          0,
          reason:
              '🔴 la route `art` est ÉGALE (`==`) sur les deux routeurs : '
              'sa tranche ne doit PAS signaler',
        );
        expect(solo.count, 0);
        expect(failure.count, 0);
        expect(
          messages.count,
          0,
          reason: '🔴 le fil a été notifié par le routage',
        );
        expect(sett.count, 0, reason: '🔴 les réglages ont été notifiés');
        expect(s.routeOf('test').value?.model?.modelId, 'mz');
      },
    );

    test('`setModelOverride` ne signale que la tranche de SA tâche', () async {
      final ZChatRouteSession s = await _session();
      final _Tally test = _Tally(s.overrideOf('test'));
      final _Tally art = _Tally(s.overrideOf('art'));
      final _Tally router = _Tally(s.router);
      s.setModelOverride('test', _mb);
      s.setModelOverride('test', _mb);
      expect(test.count, 1, reason: 'une valeur égale ne notifie pas');
      expect(art.count, 0);
      expect(router.count, 0);
    });

    test('un `Left` du catalogue va dans `catalogFailure` et RETIRE le '
        'routeur chargé', () async {
      final ZChatRouteSession s = await _session();
      await s.selectRouter('absent');
      expect(s.catalogFailure.value, isA<ZNotFoundFailure>());
      expect(
        s.router.value,
        isNull,
        reason:
            '🔴 identité choisie `absent`, routeur chargé `ra` : une '
            'route résolue sur le MAUVAIS routeur',
      );
      expect(s.resolve(_req()).isLeft(), isTrue);
      await s.selectRouter('ra');
      expect(s.catalogFailure.value, isNull);
      expect(s.router.value?.id, 'ra');
    });
  });

  group('🔴 RT-G5 — ce qui ATTEINT le port', () {
    Future<ZChatGenerationRequest> sent(
      ZChatRouteSession s, {
      ZChatGenerationSettings? settings,
      Map<String, dynamic> extra = const <String, dynamic>{},
    }) async {
      final r = _controller(resolver: s.resolve, extra: extra);
      r.c.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = r.c.send(
        settings: settings,
      );
      await pumpEventQueue();
      expect(r.port.calls, hasLength(1));
      r.port.last.add(done());
      await sending;
      return r.port.calls.single.request;
    }

    test(
      '`providerId`/`modelId` = route ; `computeEffort` = route en repli',
      () async {
        final ZChatRouteSession s = await _session();
        final ZChatGenerationRequest got = await sent(s);
        expect(got.providerId, 'pa');
        expect(got.modelId, 'ma');
        expect(got.computeEffort?.toJson(), 5);
        expect(got.extra['temperature'], 0.2, reason: 'les params de la route');
      },
    );

    test('le RÉGLAGE de la feuille prime le budget de la route', () async {
      final ZChatRouteSession s = await _session();
      final ZChatGenerationRequest got = await sent(
        s,
        settings: ZChatGenerationSettings(
          computeEffort: ZChatComputeEffort.fromJson(2),
        ),
      );
      expect(
        got.computeEffort?.toJson(),
        2,
        reason: '🔴 la route a ÉCRASÉ le réglage explicite de la feuille',
      );
      expect(got.modelId, 'ma');
    });

    test('le REPLI choisi pour la tâche prime le modèle de la route', () async {
      final ZChatRouteSession s = await _session();
      s.setModelOverride('test', _mb);
      final ZChatGenerationRequest got = await sent(s);
      expect(got.providerId, 'pb');
      expect(got.modelId, 'mb');
      s.setModelOverride('test', null);
      expect((await sent(s)).modelId, 'ma');
    });

    test('un modèle DÉJÀ nommé par le builder prime tout, repli compris', () {
      final ZChatRouteSession s = ZChatRouteSession(
        catalog: _catalog(),
        gate: const ZAllowAllChatRouteGate(),
      );
      addTearDown(s.dispose);
      return s.selectRouter('ra').then((_) {
        s.setModelOverride('test', _mb);
        final ZChatGenerationRequest got = s
            .resolve(_req(modelId: 'mine'))
            .getOrElse(() => throw StateError('refused'));
        expect(got.modelId, 'mine');
        expect(got.providerId, isNull);
      });
    });

    test('les `extra` de l\'HÔTE priment les params de la route', () async {
      final ZChatRouteSession s = await _session();
      final ZChatGenerationRequest got = await sent(
        s,
        extra: const <String, dynamic>{'temperature': 0.9},
      );
      expect(got.extra['temperature'], 0.9);
    });

    test('`zChatApplyRoute` est PURE : même entrée, même sortie, routeur '
        'non muté', () {
      final ZChatRouter ra = _ra();
      final ZChatGenerationRequest req = _req();
      final ZResult<ZChatGenerationRequest> a = zChatApplyRoute(
        router: ra,
        gate: const ZAllowAllChatRouteGate(),
        request: req,
      );
      final ZResult<ZChatGenerationRequest> b = zChatApplyRoute(
        router: ra,
        gate: const ZAllowAllChatRouteGate(),
        request: req,
      );
      expect(
        a.getOrElse(() => throw StateError('x')),
        b.getOrElse(() => throw StateError('x')),
      );
      expect(ra.routeOf('test'), _testRoute());
    });
  });

  group('🔴 RT-G6 — AUCUN libellé inventé', () {
    test('grep NÉGATIF : `routing/` ne construit ni option ni texte', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        if (!e.key.replaceAll(r'\', '/').contains('/presentation/routing/')) {
          continue;
        }
        scanned++;
        for (int i = 0; i < e.value.length; i++) {
          final String l = e.value[i];
          if (RegExp(r'ZChatModelOption(\.byKey)?\s*\(').hasMatch(l) ||
              RegExp(r'\bText\s*\(').hasMatch(l) ||
              RegExp(
                r'ZChatSettingsLabel\.text\s*\(\s*['
                "'"
                r'"]',
              ).hasMatch(l)) {
            offenders.add('${e.key}:${i + 1}: ${l.trim()}');
          }
        }
      }
      expect(
        scanned,
        greaterThanOrEqualTo(4),
        reason: '🔴 GARDE VACUELLE : $scanned fichier(s) sous `routing/`',
      );
      expect(offenders, isEmpty, reason: '🔴\n${offenders.join('\n')}');
    });

    test('🔬 contre-preuve — le motif VOIT une option construite', () {
      expect(
        RegExp(
          r'ZChatModelOption(\.byKey)?\s*\(',
        ).hasMatch("  ZChatModelOption(id: 'free', label: 'Gratuit')"),
        isTrue,
      );
      expect(
        RegExp(
          r'ZChatSettingsLabel\.text\s*\(\s*['
          "'"
          r'"]',
        ).hasMatch("title: ZChatSettingsLabel.text('Modèle'),"),
        isTrue,
      );
      expect(
        RegExp(
          r'ZChatSettingsLabel\.text\s*\(\s*['
          "'"
          r'"]',
        ).hasMatch('ZChatSettingsLabel.text(label)'),
        isFalse,
      );
    });

    test('sans libellé d\'hôte ⇒ AUCUNE entrée ; avec ⇒ une par route à '
        '≥ 2 candidats, liée à `overrideOf`/`setModelOverride`', () async {
      final ZChatRouteSession s = await _session();
      expect(
        zChatRouteSettingsEntries(
          s,
          modelLabelOf: (ZChatModelRef _) => null,
          taskLabelKeyOf: (String k) => 'host.$k',
        ),
        isEmpty,
      );
      expect(
        zChatRouteSettingsEntries(
          s,
          modelLabelOf: (ZChatModelRef m) => m.token,
          taskLabelKeyOf: (String _) => null,
        ),
        isEmpty,
      );
      List<ZChatSettingsEntry> entries() => zChatRouteSettingsEntries(
        s,
        modelLabelOf: (ZChatModelRef m) => m.token,
        taskLabelKeyOf: (String k) => 'host.$k',
        sectionId: 'sec',
      );
      final List<ZChatSettingsEntry> got = entries();
      expect(
        got.map((ZChatSettingsEntry e) => e.id),
        <String>[
          '${kZChatRouteEntryIdPrefix}test',
          '${kZChatRouteEntryIdPrefix}art',
        ],
        reason: '`solo` n\'a qu\'un candidat : aucun choix à offrir',
      );
      expect(got.first.title.labelKey, 'host.test');
      expect(got.first.sectionId, 'sec');
      final ZChatSelectControl control =
          got.first.control as ZChatSelectControl;
      expect(
        control.choices.map((ZChatSettingsChoice c) => c.label.text),
        <String>['pa:ma', 'pb:mb'],
      );
      expect(
        control.choices.first.selected,
        isTrue,
        reason: 'sans repli choisi, le modèle de la route est coché',
      );
      control.choices[1].onTap();
      expect(s.overrideOf('test').value, _mb);
      expect(
        (entries().first.control as ZChatSelectControl).choices[1].selected,
        isTrue,
      );
      (entries().first.control as ZChatSelectControl).choices[0].onTap();
      expect(
        s.overrideOf('test').value,
        isNull,
        reason: 'choisir le modèle de la route = ne plus rien forcer',
      );
    });
  });

  group('🔴 RT-G7 — le GATE', () {
    test('le gate par défaut REFUSE (code `upgradeRequired`) ; `AllowAll` '
        'rend `Right`', () async {
      final ZChatRouteSession denied = await _session(
        gate: const ZDenyAllChatRouteGate(),
      );
      final ZFailure? f = denied
          .resolve(_req())
          .fold((ZFailure f) => f, (_) => null);
      expect(f, isA<ZChatProviderFailure>());
      expect(
        (f! as ZChatProviderFailure).code,
        ZChatFailureCodes.upgradeRequired,
      );

      final ZChatRouteSession open = await _session();
      expect(open.resolve(_req()).isRight(), isTrue);
    });

    test('le gate par DÉFAUT du constructeur est le refus', () {
      final ZChatRouteSession s = ZChatRouteSession(catalog: _catalog());
      addTearDown(s.dispose);
      return s.selectRouter('ra').then((_) {
        expect(
          s.resolve(_req()).isLeft(),
          isTrue,
          reason: '🔴 un catalogue déclaré SANS gate laisse passer',
        );
      });
    });

    test('le gate reçoit le palier et les jetons de la route', () async {
      final List<(String, String?, List<String>)> seen =
          <(String, String?, List<String>)>[];
      final ZChatRouteSession s = await _session(
        gate: _SpyGate(
          (String k, String? t, List<String> tokens) =>
              seen.add((k, t, tokens)),
        ),
      );
      s.resolve(_req());
      expect(seen.single.$1, 'test');
      expect(seen.single.$2, 'gold');
      expect(seen.single.$3, <String>['tok']);
    });

    test(
      'sans routeur ⇒ `Left(ZDomainFailure)`, jamais un modèle fabriqué',
      () async {
        final ZChatRouteSession s = await _session(initial: null);
        final ZResult<ZChatGenerationRequest> r = s.resolve(_req());
        expect(r.fold((ZFailure f) => f, (_) => null), isA<ZDomainFailure>());
      },
    );

    test('tâche NON déclarée : racine vide ⇒ `Left` ; racine avec modèle ⇒ '
        'le modèle de la racine', () async {
      final ZChatRouteSession s = await _session();
      final ZChatGenerationRequest fromRoot = s
          .resolve(_req(kind: 'unknown'))
          .getOrElse(() => throw StateError('refused'));
      expect(fromRoot.modelId, 'm0');
      expect(fromRoot.providerId, 'p0');
      await s.selectRouter('rb');
      expect(
        s.resolve(_req(kind: 'unknown')).isLeft(),
        isTrue,
        reason:
            '🔴 `rb` n\'a ni route `unknown` ni modèle racine : rien à '
            'router, et le socle n\'invente pas',
      );
    });
  });

  group('🔴 RT-G8 — le port ROUTÉ répartit, ne résout pas', () {
    ZChatRoutedStreamPort routed({
      required Map<String, ZChatStreamPort> ports,
      ZChatRouteSpec? Function(String)? routeOf,
      ZChatStreamPort? fallback,
    }) => ZChatRoutedStreamPort(
      routeOf: routeOf ?? (String _) => null,
      handlers: ZChatMapRouteHandlers(streamPorts: ports),
      fallback: fallback,
    );

    test('gestionnaire → fournisseur → nom de route → repli ; requête '
        'déléguée `identical`', () async {
      final FakeStreamPort h1 = FakeStreamPort();
      final FakeStreamPort px = FakeStreamPort();
      final FakeStreamPort rn = FakeStreamPort();
      final FakeStreamPort fb = FakeStreamPort();
      // Aucun canal n'est écouté ici : `closeAll` attendrait un auditeur qui
      // ne vient jamais — les canaux sont simplement abandonnés.
      final Map<String, ZChatStreamPort> ports = <String, ZChatStreamPort>{
        'h1': h1,
        'px': px,
        'rn': rn,
      };
      final ZChatRequestToken t = ZChatRequestToken('r');
      final ZChatGenerationRequest byHandler = _req();
      routed(
        ports: ports,
        routeOf: (String _) => _testRoute(),
      ).stream(byHandler, token: t);
      expect(identical(h1.calls.single.request, byHandler), isTrue);

      final ZChatGenerationRequest byProvider = ZChatGenerationRequest(
        style: ZChatGenerationStyle('test'),
        providerId: 'px',
      );
      routed(
        ports: ports,
        routeOf: (String _) => ZChatRouteSpec(taskKey: 'test', routeName: 'rn'),
      ).stream(byProvider, token: t);
      expect(
        px.calls,
        hasLength(1),
        reason: 'le fournisseur de la requête prime le nom de route',
      );

      routed(
        ports: ports,
        routeOf: (String _) => ZChatRouteSpec(taskKey: 'test', routeName: 'rn'),
      ).stream(_req(), token: t);
      expect(rn.calls, hasLength(1));

      routed(ports: ports, fallback: fb).stream(_req(), token: t);
      expect(fb.calls, hasLength(1));
    });

    test('identité INCONNUE ⇒ un seul `Left(ZUnsupportedOperationFailure)` '
        'nommant la route', () async {
      final List<ZResult<ZChatStreamEvent>> events = await routed(
        ports: const <String, ZChatStreamPort>{},
        routeOf: (String _) => _testRoute(),
      ).stream(_req(), token: ZChatRequestToken('r')).toList();
      expect(events, hasLength(1));
      final ZFailure? f = events.single.fold((ZFailure f) => f, (_) => null);
      expect(f, isA<ZUnsupportedOperationFailure>());
      expect((f! as ZUnsupportedOperationFailure).operation, 'route:h1');
    });

    test('un port interne qui LÈVE ⇒ un seul `Left` (AD-10)', () async {
      final FakeStreamPort boom = FakeStreamPort()
        ..throwOnCall = StateError('x');
      final List<ZResult<ZChatStreamEvent>> events = await routed(
        ports: <String, ZChatStreamPort>{'h1': boom},
        routeOf: (String _) => _testRoute(),
      ).stream(_req(), token: ZChatRequestToken('r')).toList();
      expect(events, hasLength(1));
      expect(events.single.isLeft(), isTrue);
    });

    test('le port routé ne RÉSOUT pas : il ne cite ni gate ni résolution', () {
      for (final String f in <String>[
        'lib/src/presentation/routing/z_chat_routed_stream_port.dart',
        'lib/src/presentation/routing/z_chat_routed_artifact_port.dart',
      ]) {
        final String src = stripped(libFile(f)).join('\n');
        expect(src.contains('ZChatRouteGate'), isFalse, reason: f);
        expect(src.contains('ZChatRouteResolution'), isFalse, reason: f);
        expect(src.contains('canRoute('), isFalse, reason: f);
      }
    });

    test(
      'le port d\'ARTEFACT routé : même répartition, fournisseur lu dans '
      'le champ TYPÉ `providerId` (jamais `extra`), inconnu ⇒ `Left`',
      () async {
        final List<ZChatArtifactGenerationRequest> seen =
            <ZChatArtifactGenerationRequest>[];
        final List<ZChatArtifactGenerationRequest> byName =
            <ZChatArtifactGenerationRequest>[];
        final ZChatRoutedArtifactGenerationPort port =
            ZChatRoutedArtifactGenerationPort(
              routeOf: (String _) =>
                  ZChatRouteSpec(taskKey: 'art', routeName: 'rn'),
              handlers: const ZChatInertRouteHandlers(),
              artifactPorts: <String, ZChatArtifactGenerationPort>{
                'px': _ArtPort(seen.add),
                'rn': _ArtPort(byName.add),
              },
            );
        final ZChatArtifactGenerationRequest req =
            ZChatArtifactGenerationRequest(
              messageId: 'm',
              artifactKey: 'art',
              notes: 'n',
              providerId: 'px',
            );
        final ZResult<ZChatArtifactContent> ok = await port.generate(
          req,
          token: ZChatRequestToken('r'),
        );
        expect(ok.isRight(), isTrue);
        expect(
          identical(seen.single, req),
          isTrue,
          reason: 'le fournisseur TYPÉ prime le nom de route',
        );
        expect(byName, isEmpty);

        // Un `provider_id` glissé dans `extra` n'est PAS un fournisseur : il
        // n'est pas lu, la répartition tombe sur le nom de route.
        await port.generate(
          ZChatArtifactGenerationRequest(
            messageId: 'm',
            artifactKey: 'art',
            notes: 'n',
            extra: const <String, dynamic>{'provider_id': 'px'},
          ),
          token: ZChatRequestToken('r'),
        );
        expect(seen, hasLength(1), reason: '🔴 `extra[provider_id]` a été LU');
        expect(byName, hasLength(1));

        final ZResult<ZChatArtifactContent> ko =
            await ZChatRoutedArtifactGenerationPort(
              routeOf: (String _) => null,
              handlers: const ZChatInertRouteHandlers(),
            ).generate(
              ZChatArtifactGenerationRequest(
                messageId: 'm',
                artifactKey: 'art',
                notes: 'n',
              ),
              token: ZChatRequestToken('r'),
            );
        expect(
          ko.fold((ZFailure f) => f, (_) => null),
          isA<ZUnsupportedOperationFailure>(),
        );
      },
    );

    test('l\'ADAPTATEUR de port texte reporte `providerId` typé sur la '
        'requête de conversation', () async {
      final List<ZChatGenerationRequest> inner = <ZChatGenerationRequest>[];
      final ZChatRoutedArtifactGenerationPort port =
          ZChatRoutedArtifactGenerationPort(
            routeOf: (String _) => null,
            handlers: ZChatMapRouteHandlers(
              generationPorts: <String, ZChatGenerationPort>{
                'px': _GenPort(inner.add),
              },
            ),
          );
      await port.generate(
        ZChatArtifactGenerationRequest(
          messageId: 'm',
          artifactKey: 'art',
          notes: 'n',
          providerId: 'px',
          modelId: 'mx',
        ),
        token: ZChatRequestToken('r'),
      );
      expect(inner.single.providerId, 'px');
      expect(inner.single.modelId, 'mx');
      expect(inner.single.extra.containsKey('provider_id'), isFalse);
    });
  });

  group('🔴 RT-G9 — `routing/` est COUVERT par la garde de pureté', () {
    test('les fichiers de `routing/` sont scannés et n\'ouvrent pas '
        '`flutter/widgets.dart`', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<String> routing = <String>[
        for (final String k in lib.keys)
          if (k.replaceAll(r'\', '/').contains('/presentation/routing/')) k,
      ];
      expect(
        routing.length,
        greaterThanOrEqualTo(4),
        reason: '🔴 `routing/` n\'est pas scanné par `strippedLib`',
      );
      for (final String k in routing) {
        for (final String l in lib[k]!) {
          if (!l.trimLeft().startsWith('import ')) continue;
          expect(
            l.contains('package:flutter/widgets.dart'),
            isFalse,
            reason:
                '🔴 $k ouvre `widgets.dart` : un fichier de routage ne '
                'rend aucun pixel',
          );
          expect(l.contains('package:flutter/material.dart'), isFalse);
        }
      }
    });
  });

  group('🔴 RT-G10 — la surface de la session, en ÉGALITÉ d\'ENSEMBLE', () {
    test('EXACTEMENT les membres attendus — AUCUN membre qui envoie', () {
      final Set<String> publics = _publicMembers(
        _classBody(_sessionFile, 'class ZChatRouteSession'),
        'ZChatRouteSession',
      );
      expect(
        publics,
        <String>{
          'routerId',
          'router',
          'catalogFailure',
          'routeOf',
          'overrideOf',
          'selectRouter',
          'refresh',
          'setModelOverride',
          'resolve',
          'resolveArtifact',
          'dispose',
        },
        reason:
            '🔴 ÉGALITÉ D\'ENSEMBLE. Un membre ajouté qui ENVERRAIT — '
            '`send()`, `stream()`, `generate()` — ferait de la session un '
            'second site d\'envoi, à côté de `ZChatController.send`.',
      );
    });

    test('la session ne cite AUCUN port d\'envoi', () {
      final String src = stripped(libFile(_sessionFile)).join('\n');
      for (final String banned in <String>[
        'ZChatStreamPort',
        'ZChatGenerationPort',
        'ZChatArtifactGenerationPort',
        '.stream(',
        '.generate(',
      ]) {
        expect(
          src.contains(banned),
          isFalse,
          reason:
              '🔴 la session cite `$banned` : elle résout, elle '
              'n\'envoie pas',
        );
      }
    });
  });

  group('🔴 RT-G11 — ARTEFACT refusé : rien ne part', () {
    test('`generate` jamais appelé, `statusOf` jamais en cours, aucune '
        'annonce, échec sur la tranche du couple', () async {
      final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
      addTearDown(transcript.dispose);
      await transcript.append(_user('q1', 'question'));
      await transcript.append(_assistant('r1', 'réponse'));
      final List<ZChatArtifactGenerationRequest> calls =
          <ZChatArtifactGenerationRequest>[];
      final ZChatNotebookController nb = ZChatNotebookController(
        streamPort: FakeStreamPort(),
        transcript: transcript,
        conversationId: 'c1',
        registry: ZChatArtifactRegistry(<ZChatArtifactDeclaration>[
          ZChatArtifactDeclaration(
            key: 'art',
            verbs: <ZChatArtifactVerb>[ZChatArtifactVerb.create()],
          ),
        ]),
        generationPort: _ArtPort(calls.add),
        artifactRouteResolver: (ZChatArtifactGenerationRequest _) =>
            Left<ZFailure, ZChatArtifactGenerationRequest>(_denied),
        liveLabels: ZChatLiveLabels(
          artifactGenerationStarted: (String k) => 'started $k',
        ),
      );
      addTearDown(nb.dispose);
      await pumpEventQueue();
      final ValueListenable<ZChatArtifactStatus> status = nb.statusOf(
        'r1',
        'art',
      );
      final List<ZChatArtifactStatus> seen = <ZChatArtifactStatus>[];
      status.addListener(() => seen.add(status.value));
      final ZResult<ZChatActionOutcome> res = await nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: 'art',
        verbKey: kZChatArtifactVerbCreate,
      );
      await pumpEventQueue();
      expect(res.isLeft(), isTrue);
      expect(calls, isEmpty, reason: '🔴 le port a été appelé malgré le refus');
      expect(
        seen.contains(ZChatArtifactStatus.inProgress),
        isFalse,
        reason: '🔴 le couple a été marqué EN COURS pour rien',
      );
      expect(
        nb.liveAnnouncement.value,
        '',
        reason: '🔴 une génération refusée a été ANNONCÉE',
      );
      expect(nb.failureOf('r1', 'art').value, same(_denied));
    });

    test('avec la session : le repli choisi et le fournisseur atteignent la '
        'requête d\'artefact', () async {
      final ZChatRouteSession s = await _session();
      s.setModelOverride('art', _my);
      final ZChatArtifactGenerationRequest got = s
          .resolveArtifact(
            ZChatArtifactGenerationRequest(
              messageId: 'm',
              artifactKey: 'art',
              notes: 'n',
            ),
          )
          .getOrElse(() => throw StateError('refused'));
      expect(got.modelId, 'my');
      expect(got.providerId, 'py', reason: 'le fournisseur voyage TYPÉ');
      expect(
        got.extra.containsKey('provider_id'),
        isFalse,
        reason: '🔴 deux canaux pour le fournisseur (`extra[provider_id]`)',
      );
    });

    test('artefact, RT-G5 : `providerId`/`modelId` = route sans repli ; un '
        'modèle DÉJÀ nommé garde son fournisseur (même `null`)', () async {
      final ZChatRouteSession s = await _session();
      ZChatArtifactGenerationRequest art({
        String? modelId,
        String? providerId,
      }) => ZChatArtifactGenerationRequest(
        messageId: 'm',
        artifactKey: 'art',
        notes: 'n',
        modelId: modelId,
        providerId: providerId,
      );
      final ZChatArtifactGenerationRequest fromRoute = s
          .resolveArtifact(art())
          .getOrElse(() => throw StateError('refused'));
      expect(fromRoute.providerId, 'px');
      expect(fromRoute.modelId, 'mx');
      expect(fromRoute.extra.containsKey('provider_id'), isFalse);

      s.setModelOverride('art', _my);
      final ZChatArtifactGenerationRequest mine = s
          .resolveArtifact(art(modelId: 'mine'))
          .getOrElse(() => throw StateError('refused'));
      expect(mine.modelId, 'mine');
      expect(
        mine.providerId,
        isNull,
        reason: '🔴 un fournisseur de route posé sur un modèle de l\'hôte',
      );
      final ZChatArtifactGenerationRequest both = s
          .resolveArtifact(art(modelId: 'mine', providerId: 'mineP'))
          .getOrElse(() => throw StateError('refused'));
      expect(both.providerId, 'mineP');
    });
  });

  group('🔴 RT-G12 — le fournisseur d\'artefact n\'a qu\'UN canal', () {
    test('grep NÉGATIF : `lib/` ne cite ni `provider_id` ni '
        '`kZChatArtifactProviderIdKey`', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      final RegExp motif = RegExp(
        r'''['"]provider_id['"]|kZChatArtifactProviderIdKey''',
      );
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        scanned++;
        for (int i = 0; i < e.value.length; i++) {
          if (motif.hasMatch(e.value[i])) {
            offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(scanned, greaterThan(20), reason: '🔴 GARDE VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason:
            '🔴 le fournisseur d\'un artefact voyage dans `providerId` '
            'typé — un second canal dans `extra` :\n${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve — le motif VOIT la clé', () {
      final RegExp motif = RegExp(
        r'''['"]provider_id['"]|kZChatArtifactProviderIdKey''',
      );
      expect(motif.hasMatch("extra['provider_id']"), isTrue);
      expect(
        motif.hasMatch('const String kZChatArtifactProviderIdKey ='),
        isTrue,
      );
      expect(motif.hasMatch("'model_provider_id'"), isFalse);
    });
  });

  group('🔴 RT-SCREEN — l\'écran de conversation', () {
    testWidgets('le contrôleur est créé UNE fois sur deux `build`, libéré au '
        '`dispose` ; avec session, le sélecteur de routeur est monté et la '
        'sélection passe par `selectRouter`', (WidgetTester tester) async {
      final FakeStreamPort port = FakeStreamPort();
      final ZChatRouteSession s = ZChatRouteSession(
        catalog: _catalog(),
        gate: const ZAllowAllChatRouteGate(),
        initialRouterId: 'ra',
      );
      addTearDown(s.dispose);
      Widget screen() => harness(
        ZChatConversationScreen(
          key: const ValueKey<String>('screen'),
          streamPort: port,
          conversationId: 'c1',
          cursorColor: const Color(0xFF000000),
          routeSession: s,
          routerOptions: const <ZChatModelOption>[
            ZChatModelOption(id: 'ra', label: 'A'),
            ZChatModelOption(id: 'rb', label: 'B'),
          ],
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pump();
      final ZChatController first = tester
          .widget<ZChatConversationView>(find.byType(ZChatConversationView))
          .controller;
      await tester.pumpWidget(screen());
      await tester.pump();
      final ZChatController second = tester
          .widget<ZChatConversationView>(find.byType(ZChatConversationView))
          .controller;
      expect(
        identical(first, second),
        isTrue,
        reason: '🔴 le contrôleur a été RECRÉÉ au second build',
      );

      final ZChatComposerModelSelector selector = tester
          .widget<ZChatComposerModelSelector>(
            find.byType(ZChatComposerModelSelector),
          );
      expect(selector.activeId, 'ra');
      selector.onSelect('rb');
      await tester.pump();
      expect(s.routerId.value, 'rb');
      expect(
        tester
            .widget<ZChatComposerModelSelector>(
              find.byType(ZChatComposerModelSelector),
            )
            .activeId,
        'rb',
        reason: 'l\'actif suit `routerId`',
      );

      await tester.pumpWidget(const SizedBox());
      expect(
        () => first.composer.addListener(() {}),
        throwsFlutterError,
        reason: '🔴 le contrôleur n\'a pas été libéré au `dispose`',
      );
    });

    test('garde de source : le contrôleur de conversation n\'est construit '
        'QUE dans `initState`', () {
      final List<String> src = stripped(libFile(_screenFile));
      // L'écran construit `ZChatConversationController`, qui compose le
      // `ZChatController` : c'est LUI le site unique à surveiller. Un
      // `ZChatController(` nu dans l'écran serait un second site de
      // composition — il est interdit au même titre.
      final RegExp ctor = RegExp(r'\bZChatConversationController\(');
      expect(
        src.any((String l) => RegExp(r'\bZChatController\(').hasMatch(l)),
        isFalse,
        reason: '🔴 l\'écran construit un `ZChatController` nu à côté du '
            'contrôleur de conversation : deux compositions',
      );
      final List<int> sites = <int>[
        for (int i = 0; i < src.length; i++)
          if (ctor.hasMatch(src[i])) i,
      ];
      expect(sites, hasLength(1));
      int initState = -1;
      int nextMember = src.length;
      for (int i = 0; i < src.length; i++) {
        if (RegExp(r'void initState\(\)').hasMatch(src[i])) initState = i;
        if (initState >= 0 && i > initState && src[i].trim() == '@override') {
          nextMember = i;
          break;
        }
      }
      expect(initState, greaterThanOrEqualTo(0));
      expect(
        sites.single,
        inExclusiveRange(initState, nextMember),
        reason: '🔴 le contrôleur est construit hors de `initState`',
      );
    });

    testWidgets('SANS session : `modelBuilder == null` — l\'écran est celui '
        'd\'un hôte passif', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          ZChatConversationScreen(
            streamPort: FakeStreamPort(),
            cursorColor: const Color(0xFF000000),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<ZDefaultChatComposer>(find.byType(ZDefaultChatComposer))
            .modelBuilder,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class _SpyGate implements ZChatRouteGate {
  const _SpyGate(this.onSeen);
  final void Function(String, String?, List<String>) onSeen;
  @override
  ZResult<Unit> canRoute(
    String taskKey, {
    String? tier,
    List<String> requiredAccessTokens = const <String>[],
  }) {
    onSeen(taskKey, tier, requiredAccessTokens);
    return const Right<ZFailure, Unit>(unit);
  }
}

class _GenPort implements ZChatGenerationPort {
  const _GenPort(this.onCall);
  final void Function(ZChatGenerationRequest) onCall;
  @override
  Future<ZResult<List<ZContentBlock>>> generate(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async {
    onCall(request);
    return Right<ZFailure, List<ZContentBlock>>(<ZContentBlock>[]);
  }
}

class _ArtPort implements ZChatArtifactGenerationPort {
  const _ArtPort(this.onCall);
  final void Function(ZChatArtifactGenerationRequest) onCall;
  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) async {
    onCall(request);
    return Right<ZFailure, ZChatArtifactContent>(ZChatArtifactContent('ok'));
  }
}
