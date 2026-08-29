/// 🔴 Gardes des adaptateurs PAR ROUTE des ports d'étude (`lib/src/domain/routing/`).
///
/// Ce que chaque garde mesure, et pourquoi elle mord :
///
/// - **route inconnue ⇒ UN SEUL `Left`, 0 appel** : un adaptateur qui, faute
///   de route, appellerait « le premier port venu » ou un port par défaut
///   enverrait la génération sur un modèle non gouverné. Les mocks portent un
///   compteur, et la garde exige `0` — pas « peu ».
/// - **gate refusé ⇒ 0 appel, code `upgradeRequired`** : un refus de
///   gouvernance qui laisserait passer l'appel factureraient l'hôte pour une
///   route qu'il refuse.
/// - **route résolue ⇒ 1 appel, requête portant le routeId VERBATIM** : la
///   requête reçue par le handler est inspectée ; l'égalité est stricte, pas
///   un `contains`.
/// - **repli** : utilisé SEULEMENT quand aucune identité ne résout.
/// - **flux** : les événements traversent sans altération ni ré-ordre, et
///   l'annulation ferme l'abonnement amont (compteur d'annulation).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_study/zcrud_chat_study.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmapNode;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyPodcast;

const String kTask = 'host.task';
const String kRouterId = 'router-1';

ZChatInMemoryRouteCatalog _catalog({
  String? routeName = 'route-A',
  String? handlerId,
  List<String> tokens = const <String>[],
  String? tier,
}) => ZChatInMemoryRouteCatalog(<ZChatRouter>[
  ZChatRouter(
    id: kRouterId,
    tier: tier,
    routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[
      ZChatRouteSpec(
        taskKey: kTask,
        routeName: routeName,
        handlerId: handlerId,
        requiredAccessTokens: tokens,
      ),
    ]),
  ),
]);

/// Catalogue sans le routeur demandé — la « route inconnue ».
final ZChatInMemoryRouteCatalog kEmptyCatalog =
    ZChatInMemoryRouteCatalog(const <ZChatRouter>[]);

// ─────────────────────────── mocks à compteur ───────────────────────────

class _MindmapSpy implements ZMindmapGenerationPort {
  int calls = 0;
  ZMindmapGenerationRequest? seen;

  @override
  Future<ZResult<List<ZMindmapNode>>> generateMindmap(
    ZMindmapGenerationRequest request,
  ) async {
    calls++;
    seen = request;
    return const Right<ZFailure, List<ZMindmapNode>>(<ZMindmapNode>[]);
  }
}

class _ExplanationSpy implements ZAiExplanationPort {
  int calls = 0;
  ZAiExplanationRequest? seen;

  @override
  Future<ZResult<String>> explain(ZAiExplanationRequest request) async {
    calls++;
    seen = request;
    return const Right<ZFailure, String>('ok');
  }
}

class _SummarySpy implements ZNoteSummaryPort {
  int calls = 0;
  ZNoteSummaryRequest? seen;

  @override
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request) async {
    calls++;
    seen = request;
    return const Right<ZFailure, String>('ok');
  }
}

class _PodcastSpy implements ZPodcastGenerationPort {
  int calls = 0;
  ZPodcastGenerationRequest? seen;

  @override
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  ) async {
    calls++;
    seen = request;
    // Le sujet de la garde est l'ATTEINTE du handler, pas la valeur produite :
    // un `Left` marqueur évite de fabriquer une entité de persistance.
    return const Left<ZFailure, ZStudyPodcast>(ZDomainFailure('reached'));
  }
}

class _FlashcardSpy implements ZFlashcardGenerationPort {
  int calls = 0;
  ZFlashcardGenerationRequest? seen;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  ) async {
    calls++;
    seen = request;
    return const Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[]);
  }
}

class _StreamSpy implements ZAiExplanationStreamPort {
  _StreamSpy({this.events = const <String>[], this.available = true});

  final List<String> events;
  final bool available;
  int calls = 0;
  int cancels = 0;
  ZAiExplanationRequest? seen;

  @override
  bool get isAvailable => available;

  @override
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  ) {
    calls++;
    seen = request;
    late StreamController<ZResult<ZGenerationProgress>> controller;
    controller = StreamController<ZResult<ZGenerationProgress>>(
      onListen: () async {
        for (final String e in events) {
          if (controller.isClosed) return;
          controller.add(
            Right<ZFailure, ZGenerationProgress>(ZGenerationProgress(text: e)),
          );
          await Future<void>.delayed(Duration.zero);
        }
        if (!controller.isClosed) await controller.close();
      },
      onCancel: () {
        cancels++;
      },
    );
    return controller.stream;
  }
}

ZFailure _failureOf<T>(ZResult<T> r) {
  // `expect` et non `fail` : une garde qui rougit doit rendre un
  // `Expected:`/`Actual:` lisible, pas un simple message.
  expect(r.isLeft(), isTrue, reason: 'attendu un Left, reçu $r');
  return r.fold((ZFailure f) => f, (T _) => throw StateError('inatteignable'));
}

void main() {
  group('route inconnue — UN SEUL Left, aucun port appelé', () {
    test('mindmap', () async {
      final _MindmapSpy handler = _MindmapSpy();
      final ZResult<List<ZMindmapNode>> r =
          await ZChatRoutedMindmapGenerationPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZMindmapGenerationPort>{'route-A': handler},
        taskKey: kTask,
      ).generateMindmap(const ZMindmapGenerationRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
      expect(handler.calls, 0);
    });

    test('résumé de note', () async {
      final _SummarySpy handler = _SummarySpy();
      final ZResult<String> r = await ZChatRoutedNoteSummaryPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZNoteSummaryPort>{'route-A': handler},
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
      expect(handler.calls, 0);
    });

    test('explication one-shot', () async {
      final _ExplanationSpy handler = _ExplanationSpy();
      final ZResult<String> r = await ZChatRoutedAiExplanationPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZAiExplanationPort>{'route-A': handler},
        taskKey: kTask,
      ).explain(const ZAiExplanationRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
      expect(handler.calls, 0);
    });

    test('podcast', () async {
      final _PodcastSpy handler = _PodcastSpy();
      final ZResult<ZStudyPodcast> r = await ZChatRoutedPodcastGenerationPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZPodcastGenerationPort>{'route-A': handler},
        taskKey: kTask,
      ).generatePodcast(const ZPodcastGenerationRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
      expect(handler.calls, 0);
    });

    test('flashcards', () async {
      final _FlashcardSpy handler = _FlashcardSpy();
      final ZResult<List<ZFlashcard>> r =
          await ZChatRoutedFlashcardGenerationPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZFlashcardGenerationPort>{'route-A': handler},
        taskKey: kTask,
      ).generateFlashcards(const ZFlashcardGenerationRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
      expect(handler.calls, 0);
    });

    test('flux — un SEUL événement Left, aucun abonnement amont', () async {
      final _StreamSpy handler = _StreamSpy(events: <String>['a']);
      final List<ZResult<ZGenerationProgress>> got =
          await ZChatRoutedAiExplanationStreamPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZAiExplanationStreamPort>{'route-A': handler},
        taskKey: kTask,
      ).explainStream(const ZAiExplanationRequest(content: 'c')).toList();
      expect(got, hasLength(1));
      expect(_failureOf(got.single), isA<ZNotFoundFailure>());
      expect(handler.calls, 0);
    });
  });

  group('route résolue mais AUCUN handler et AUCUN repli — Left unique', () {
    test('le port par défaut n\'est jamais inventé', () async {
      final _MindmapSpy unrelated = _MindmapSpy();
      final ZResult<List<ZMindmapNode>> r =
          await ZChatRoutedMindmapGenerationPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        // L'annuaire ne connaît PAS `route-A` : rien ne doit être appelé.
        handlers: <String, ZMindmapGenerationPort>{'autre': unrelated},
        taskKey: kTask,
      ).generateMindmap(const ZMindmapGenerationRequest(content: 'c'));
      // Le compteur d'abord : un port inventé se voit à l'appel avant de se
      // voir au résultat.
      expect(unrelated.calls, 0);
      final ZFailure f = _failureOf(r);
      expect(f, isA<ZNotFoundFailure>());
      expect((f as ZNotFoundFailure).id, 'route-A');
      expect(f.entity, kZRoutedStudyPortKind);
    });
  });

  group('gate refusé — 0 appel, refus du kernel', () {
    test('mindmap : code upgradeRequired, handler jamais appelé', () async {
      final _MindmapSpy handler = _MindmapSpy();
      final ZResult<List<ZMindmapNode>> r =
          await ZChatRoutedMindmapGenerationPort(
        catalog: _catalog(),
        routerId: kRouterId,
        // Défaut du socle : refus. Explicité ici pour que la garde nomme ce
        // qu'elle mesure.
        gate: const ZDenyAllChatRouteGate(),
        handlers: <String, ZMindmapGenerationPort>{'route-A': handler},
        taskKey: kTask,
      ).generateMindmap(const ZMindmapGenerationRequest(content: 'c'));
      expect(handler.calls, 0);
      final ZFailure f = _failureOf(r);
      expect(f, isA<ZChatProviderFailure>());
      expect(
        (f as ZChatProviderFailure).code,
        ZChatFailureCodes.upgradeRequired,
      );
    });

    test('le gate REFUSE par défaut, sans avoir à le nommer', () async {
      final _SummarySpy handler = _SummarySpy();
      final ZResult<String> r = await ZChatRoutedNoteSummaryPort(
        catalog: _catalog(),
        routerId: kRouterId,
        handlers: <String, ZNoteSummaryPort>{'route-A': handler},
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(handler.calls, 0);
      expect(_failureOf(r), isA<ZChatProviderFailure>());
    });

    test('le repli non plus n\'est PAS appelé quand le gate refuse', () async {
      final _ExplanationSpy handler = _ExplanationSpy();
      final _ExplanationSpy repli = _ExplanationSpy();
      final ZResult<String> r = await ZChatRoutedAiExplanationPort(
        catalog: _catalog(),
        routerId: kRouterId,
        handlers: <String, ZAiExplanationPort>{'route-A': handler},
        fallback: repli,
        taskKey: kTask,
      ).explain(const ZAiExplanationRequest(content: 'c'));
      expect(handler.calls, 0);
      expect(repli.calls, 0);
      expect(_failureOf(r), isA<ZChatProviderFailure>());
    });

    test('les jetons d\'accès de la ROUTE sont soumis au gate', () async {
      final List<List<String>> seen = <List<String>>[];
      final ZResult<String> r = await ZChatRoutedNoteSummaryPort(
        catalog: _catalog(tokens: <String>['pro', 'beta'], tier: 'gold'),
        routerId: kRouterId,
        gate: _RecordingGate(seen),
        handlers: <String, ZNoteSummaryPort>{'route-A': _SummarySpy()},
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      // Dédupliqués et TRIÉS par le kernel — égalité stricte, pas `contains`.
      expect(seen, <List<String>>[
        <String>['beta', 'pro'],
      ]);
      expect(_failureOf(r), isA<ZChatProviderFailure>());
    });
  });

  group('route résolue — 1 appel, requête portant le routeId VERBATIM', () {
    test('mindmap : le routeId résolu est estampillé', () async {
      final _MindmapSpy handler = _MindmapSpy();
      await ZChatRoutedMindmapGenerationPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZMindmapGenerationPort>{'route-A': handler},
        taskKey: kTask,
      ).generateMindmap(const ZMindmapGenerationRequest(content: 'c'));
      expect(handler.calls, 1);
      expect(handler.seen!.routeId, 'route-A');
      expect(handler.seen!.content, 'c');
    });

    test('mindmap : le routeId de la REQUÊTE prime sur le catalogue',
        () async {
      final _MindmapSpy viaRequest = _MindmapSpy();
      final _MindmapSpy viaCatalog = _MindmapSpy();
      await ZChatRoutedMindmapGenerationPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZMindmapGenerationPort>{
          'route-A': viaCatalog,
          'route-B': viaRequest,
        },
        taskKey: kTask,
      ).generateMindmap(
        const ZMindmapGenerationRequest(content: 'c', routeId: 'route-B'),
      );
      expect(viaRequest.calls, 1);
      expect(viaCatalog.calls, 0);
      expect(viaRequest.seen!.routeId, 'route-B');
    });

    test('explication : le routeId résolu est estampillé', () async {
      final _ExplanationSpy handler = _ExplanationSpy();
      await ZChatRoutedAiExplanationPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZAiExplanationPort>{'route-A': handler},
        taskKey: kTask,
      ).explain(const ZAiExplanationRequest(content: 'c', style: 's'));
      expect(handler.calls, 1);
      expect(handler.seen!.routeId, 'route-A');
      // Aucun autre champ n'est réécrit au passage.
      expect(handler.seen!.style, 's');
    });

    test('le gestionnaire de la route (handlerId) prime sur le nom de route',
        () async {
      final _ExplanationSpy byHandler = _ExplanationSpy();
      final _ExplanationSpy byRouteName = _ExplanationSpy();
      await ZChatRoutedAiExplanationPort(
        catalog: _catalog(handlerId: 'H'),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZAiExplanationPort>{
          'H': byHandler,
          'route-A': byRouteName,
        },
        taskKey: kTask,
      ).explain(const ZAiExplanationRequest(content: 'c'));
      expect(byHandler.calls, 1);
      expect(byRouteName.calls, 0);
      // La route estampillée reste le NOM DE ROUTE, pas le gestionnaire :
      // le gestionnaire est une identité d'annuaire, pas une route.
      expect(byHandler.seen!.routeId, 'route-A');
    });

    group('les contrats SANS routeId reçoivent la requête VERBATIM', () {
      test('résumé de note', () async {
        final _SummarySpy handler = _SummarySpy();
        const ZNoteSummaryRequest req =
            ZNoteSummaryRequest(content: 'c', maxLength: 42);
        await ZChatRoutedNoteSummaryPort(
          catalog: _catalog(),
          routerId: kRouterId,
          gate: const ZAllowAllChatRouteGate(),
          handlers: <String, ZNoteSummaryPort>{'route-A': handler},
          taskKey: kTask,
        ).summarize(req);
        expect(handler.calls, 1);
        expect(identical(handler.seen, req), isTrue);
      });

      test('podcast', () async {
        final _PodcastSpy handler = _PodcastSpy();
        const ZPodcastGenerationRequest req =
            ZPodcastGenerationRequest(content: 'c', sourceId: 's');
        await ZChatRoutedPodcastGenerationPort(
          catalog: _catalog(),
          routerId: kRouterId,
          gate: const ZAllowAllChatRouteGate(),
          handlers: <String, ZPodcastGenerationPort>{'route-A': handler},
          taskKey: kTask,
        ).generatePodcast(req);
        expect(handler.calls, 1);
        expect(identical(handler.seen, req), isTrue);
      });

      test('flashcards', () async {
        final _FlashcardSpy handler = _FlashcardSpy();
        const ZFlashcardGenerationRequest req =
            ZFlashcardGenerationRequest(content: 'c', count: 7);
        await ZChatRoutedFlashcardGenerationPort(
          catalog: _catalog(),
          routerId: kRouterId,
          gate: const ZAllowAllChatRouteGate(),
          handlers: <String, ZFlashcardGenerationPort>{'route-A': handler},
          taskKey: kTask,
        ).generateFlashcards(req);
        expect(handler.calls, 1);
        expect(identical(handler.seen, req), isTrue);
      });
    });
  });

  group('repli — utilisé SEULEMENT quand la route ne résout pas', () {
    test('un handler qui résout laisse le repli à 0 appel', () async {
      final _SummarySpy handler = _SummarySpy();
      final _SummarySpy repli = _SummarySpy();
      await ZChatRoutedNoteSummaryPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZNoteSummaryPort>{'route-A': handler},
        fallback: repli,
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(handler.calls, 1);
      expect(repli.calls, 0);
    });

    test('aucune identité connue ⇒ le repli, exactement une fois', () async {
      final _SummarySpy repli = _SummarySpy();
      final ZResult<String> r = await ZChatRoutedNoteSummaryPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: const <String, ZNoteSummaryPort>{},
        fallback: repli,
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(repli.calls, 1);
      expect(r.getOrElse(() => 'ABSENT'), 'ok');
    });

    test('un routeur INTROUVABLE n\'est pas rattrapé par le repli', () async {
      // La route inconnue est un refus du CATALOGUE : le repli sert d'issue
      // à une route qui ne désigne aucun port, pas d'issue à l'absence de
      // gouvernance.
      final _SummarySpy repli = _SummarySpy();
      final ZResult<String> r = await ZChatRoutedNoteSummaryPort(
        catalog: kEmptyCatalog,
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: const <String, ZNoteSummaryPort>{},
        fallback: repli,
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
      expect(repli.calls, 0);
    });
  });

  group('flux — transparence et annulation', () {
    test('les événements traversent SANS altération ni ré-ordre', () async {
      final _StreamSpy handler =
          _StreamSpy(events: <String>['a', 'ab', 'abc']);
      final List<ZResult<ZGenerationProgress>> got =
          await ZChatRoutedAiExplanationStreamPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZAiExplanationStreamPort>{'route-A': handler},
        taskKey: kTask,
      ).explainStream(const ZAiExplanationRequest(content: 'c')).toList();
      expect(handler.calls, 1);
      expect(handler.seen!.routeId, 'route-A');
      expect(
        got
            .map(
              (ZResult<ZGenerationProgress> e) =>
                  e.getOrElse(() => const ZGenerationProgress(text: '!')).text,
            )
            .toList(),
        <String>['a', 'ab', 'abc'],
      );
    });

    test('annuler l\'abonnement AVAL ferme l\'abonnement AMONT', () async {
      final _StreamSpy handler =
          _StreamSpy(events: <String>['a', 'ab', 'abc', 'abcd']);
      final Completer<void> first = Completer<void>();
      final StreamSubscription<ZResult<ZGenerationProgress>> sub =
          ZChatRoutedAiExplanationStreamPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZAiExplanationStreamPort>{'route-A': handler},
        taskKey: kTask,
      ).explainStream(const ZAiExplanationRequest(content: 'c')).listen((
        ZResult<ZGenerationProgress> _,
      ) {
        if (!first.isCompleted) first.complete();
      });
      await first.future;
      expect(handler.cancels, 0);
      await sub.cancel();
      expect(handler.cancels, 1);
    });

    test('isAvailable suit les ports branchés', () {
      ZChatRoutedAiExplanationStreamPort build(
        Map<String, ZAiExplanationStreamPort> h, {
        ZAiExplanationStreamPort? repli,
      }) => ZChatRoutedAiExplanationStreamPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: h,
        fallback: repli,
        taskKey: kTask,
      );
      expect(build(const <String, ZAiExplanationStreamPort>{}).isAvailable,
          isFalse);
      expect(
        build(<String, ZAiExplanationStreamPort>{
          'route-A': _StreamSpy(available: false),
        }).isAvailable,
        isFalse,
      );
      expect(
        build(<String, ZAiExplanationStreamPort>{
          'route-A': _StreamSpy(),
        }).isAvailable,
        isTrue,
      );
      expect(
        build(
          const <String, ZAiExplanationStreamPort>{},
          repli: _StreamSpy(),
        ).isAvailable,
        isTrue,
      );
    });
  });

  group('AD-10 — un port d\'hôte qui LÈVE ne traverse jamais', () {
    test('l\'exception devient un Left(ZDomainFailure)', () async {
      final ZResult<String> r = await ZChatRoutedNoteSummaryPort(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        handlers: <String, ZNoteSummaryPort>{'route-A': _ThrowingSummary()},
        taskKey: kTask,
      ).summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(_failureOf(r), isA<ZDomainFailure>());
    });
  });

  group('fabrique d\'ensemble — un câblage en UNE expression', () {
    test('les six ports sont câblés sur le même catalogue et le même gate',
        () async {
      final _MindmapSpy mindmap = _MindmapSpy();
      final _SummarySpy summary = _SummarySpy();
      final ZRoutedStudyPorts ports = buildRoutedStudyPorts(
        catalog: _catalog(),
        routerId: kRouterId,
        gate: const ZAllowAllChatRouteGate(),
        taskKeys: const ZRoutedStudyTaskKeys(
          mindmap: kTask,
          noteSummary: kTask,
          explanation: kTask,
          explanationStream: kTask,
          podcast: kTask,
          flashcards: kTask,
        ),
        mindmapHandlers: <String, ZMindmapGenerationPort>{'route-A': mindmap},
        noteSummaryHandlers: <String, ZNoteSummaryPort>{'route-A': summary},
      );
      await ports.mindmap
          .generateMindmap(const ZMindmapGenerationRequest(content: 'c'));
      await ports.noteSummary
          .summarize(const ZNoteSummaryRequest(content: 'c'));
      expect(mindmap.calls, 1);
      expect(summary.calls, 1);

      // Une famille sans annuaire ni repli reste CÂBLÉE et refuse proprement.
      final ZResult<List<ZFlashcard>> r = await ports.flashcards
          .generateFlashcards(const ZFlashcardGenerationRequest(content: 'c'));
      expect(_failureOf(r), isA<ZNotFoundFailure>());
    });

    test('le gate de la fabrique refuse par défaut', () async {
      final _MindmapSpy mindmap = _MindmapSpy();
      final ZRoutedStudyPorts ports = buildRoutedStudyPorts(
        catalog: _catalog(),
        routerId: kRouterId,
        taskKeys: const ZRoutedStudyTaskKeys(
          mindmap: kTask,
          noteSummary: kTask,
          explanation: kTask,
          explanationStream: kTask,
          podcast: kTask,
          flashcards: kTask,
        ),
        mindmapHandlers: <String, ZMindmapGenerationPort>{'route-A': mindmap},
      );
      final ZResult<List<ZMindmapNode>> r = await ports.mindmap
          .generateMindmap(const ZMindmapGenerationRequest(content: 'c'));
      expect(mindmap.calls, 0);
      expect(_failureOf(r), isA<ZChatProviderFailure>());
    });
  });
}

class _RecordingGate implements ZChatRouteGate {
  _RecordingGate(this.seen);

  final List<List<String>> seen;

  @override
  ZResult<Unit> canRoute(
    String taskKey, {
    String? tier,
    List<String> requiredAccessTokens = const <String>[],
  }) {
    seen.add(requiredAccessTokens);
    return const ZDenyAllChatRouteGate().canRoute(taskKey);
  }
}

class _ThrowingSummary implements ZNoteSummaryPort {
  @override
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request) =>
      throw StateError('boom');
}
