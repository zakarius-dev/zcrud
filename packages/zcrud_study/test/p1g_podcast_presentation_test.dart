/// P1-G — la présentation podcast qui manquait, et le `routeId` des trois
/// requêtes qui ne l'avaient pas.
///
/// Ce que ces gardes établissent :
///
/// 1. **Inertie absolue** — une requête construite sans `routeId` est
///    STRICTEMENT égale à ce qu'elle était (égalité, `hashCode`, `extra`), et
///    une entrée de hub non câblée est ABSENTE de l'arbre ;
/// 2. **round-trip `withRouteId` verbatim** sur les trois requêtes ;
/// 3. la carte affiche le statut **par sa clé projetée** et jamais la clé nue ;
/// 4. « régénérer » ⇒ **exactement 1** appel contrôleur ⇒ **exactement 1**
///    appel port ;
/// 5. le mini-lecteur est monté **ssi** port fourni ∧ disponible ∧ audio (4 cas) ;
/// 6. un `Left` du moteur audio ⇒ échec **visible**, sans levée ;
/// 7. **granularité** : un événement de position ne reconstruit PAS le bouton.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

// ── Doublures ─────────────────────────────────────────────────────────────

/// Port de génération faillible et COMPTANT ses appels.
class _CountingPodcastPort implements ZPodcastGenerationPort {
  _CountingPodcastPort({this.failure, this.throws = false});

  final ZFailure? failure;
  final bool throws;

  int calls = 0;
  final List<ZPodcastGenerationRequest> received = <ZPodcastGenerationRequest>[];

  @override
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  ) async {
    calls++;
    received.add(request);
    if (throws) throw StateError('boom');
    final ZFailure? f = failure;
    if (f != null) return Left<ZFailure, ZStudyPodcast>(f);
    return Right<ZFailure, ZStudyPodcast>(
      ZStudyPodcast(
        id: ZStudyPodcast.buildId(request.sourceId, request.mode),
        sourceId: request.sourceId,
        folderId: request.folderId,
        mode: request.mode,
        sourceHash: request.sourceHash,
        resultRef: 'https://cdn.example/podcast.mp3',
      ),
    );
  }
}

/// Moteur audio doublé : disponibilité réglable, `load` faillible réglable,
/// flux de position et d'état pilotables depuis le test.
class _FakeAudioPort extends ZAudioPlaybackPort {
  _FakeAudioPort({
    this.available = true,
    this.loadFails = false,
    this.totalDuration = const Duration(seconds: 100),
  });

  final bool available;
  final bool loadFails;
  final Duration? totalDuration;

  final StreamController<Duration> positions =
      StreamController<Duration>.broadcast();
  final StreamController<ZAudioPlaybackState> states =
      StreamController<ZAudioPlaybackState>.broadcast();

  int loadCalls = 0;
  int playCalls = 0;
  bool disposed = false;

  @override
  bool get isAvailable => available;

  @override
  Duration? get duration => totalDuration;

  @override
  Stream<Duration> get position => positions.stream;

  @override
  Stream<ZAudioPlaybackState> get state => states.stream;

  @override
  Future<ZResult<Unit>> load(ZAudioSource source) async {
    loadCalls++;
    if (loadFails) {
      return Left<ZFailure, Unit>(const ZDomainFailure('source illisible'));
    }
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> play() async {
    playCalls++;
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> pause() async => Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> seek(Duration position) async =>
      Right<ZFailure, Unit>(unit);

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  Future<void> close() async {
    await positions.close();
    await states.close();
  }
}

/// Compte ses reconstructions — sonde de granularité.
class _BuildProbe extends StatefulWidget {
  const _BuildProbe({required this.child, required this.onBuild});

  final Widget child;
  final VoidCallback onBuild;

  @override
  State<_BuildProbe> createState() => _BuildProbeState();
}

class _BuildProbeState extends State<_BuildProbe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return widget.child;
  }
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

const ZStudyPodcast _podcastWithAudio = ZStudyPodcast(
  id: 'n1_simple',
  sourceId: 'n1',
  folderId: 'f1',
  sourceHash: 'h1',
  resultRef: 'https://cdn.example/podcast.mp3',
);

const ZStudyPodcast _podcastWithoutAudio = ZStudyPodcast(
  id: 'n2_simple',
  sourceId: 'n2',
  folderId: 'f1',
  sourceHash: 'h1',
  status: ZPodcastStatus.processing,
);

void main() {
  // ── 1. Inertie absolue ──────────────────────────────────────────────────

  group('INERTIE — une requête sans `routeId` est STRICTEMENT ce qu\'elle était',
      () {
    test('les trois requêtes : `routeId` null, égalité et hash INCHANGÉS', () {
      const ZNoteSummaryRequest summary =
          ZNoteSummaryRequest(content: 'c', maxLength: 40, languageTag: 'fr');
      const ZNoteSummaryRequest summaryTwin =
          ZNoteSummaryRequest(content: 'c', maxLength: 40, languageTag: 'fr');
      expect(summary.routeId, isNull);
      expect(summary, equals(summaryTwin));
      expect(summary.hashCode, equals(summaryTwin.hashCode));
      expect(summary.extra, equals(<String, dynamic>{}));

      const ZPodcastGenerationRequest podcast = ZPodcastGenerationRequest(
        content: 'c',
        sourceId: 'n1',
        folderId: 'f1',
        sourceHash: 'h1',
      );
      const ZPodcastGenerationRequest podcastTwin = ZPodcastGenerationRequest(
        content: 'c',
        sourceId: 'n1',
        folderId: 'f1',
        sourceHash: 'h1',
      );
      expect(podcast.routeId, isNull);
      expect(podcast, equals(podcastTwin));
      expect(podcast.hashCode, equals(podcastTwin.hashCode));
      expect(podcast.extra, equals(<String, dynamic>{}));

      const ZFlashcardGenerationRequest cards =
          ZFlashcardGenerationRequest(content: 'c', count: 7, modelId: 'm');
      const ZFlashcardGenerationRequest cardsTwin =
          ZFlashcardGenerationRequest(content: 'c', count: 7, modelId: 'm');
      expect(cards.routeId, isNull);
      expect(cards, equals(cardsTwin));
      expect(cards.hashCode, equals(cardsTwin.hashCode));
      expect(cards.extra, equals(<String, dynamic>{}));
    });

    test(
        'CONTRE-PREUVE : `routeId` posé rend la requête NON égale (égalité '
        'STRICTE, pas un `contains`)', () {
      const ZNoteSummaryRequest summary = ZNoteSummaryRequest(content: 'c');
      expect(summary == summary.withRouteId('r'), isFalse);

      const ZPodcastGenerationRequest podcast =
          ZPodcastGenerationRequest(content: 'c');
      expect(podcast == podcast.withRouteId('r'), isFalse);

      const ZFlashcardGenerationRequest cards =
          ZFlashcardGenerationRequest(content: 'c');
      expect(cards == cards.withRouteId('r'), isFalse);
    });

    testWidgets('hub SANS câblage : entrée `null` ⇒ arbre STRICTEMENT identique',
        (WidgetTester tester) async {
      // Trois façons de n'être pas câblé : glyphe absent, libellé absent,
      // geste absent. Aucune ne rend d'entrée.
      expect(zPodcastHubEntry(label: 'Podcast', onTap: () {}), isNull);
      expect(
        zPodcastHubEntry(icon: Icons.podcasts_outlined, onTap: () {}),
        isNull,
      );
      expect(
        zPodcastHubEntry(icon: Icons.podcasts_outlined, label: 'Podcast'),
        isNull,
      );
      expect(zPodcastHubEntry(), isNull);

      const ZContentHubEntry other =
          ZContentHubEntry(icon: Icons.note_outlined, label: 'Note');
      final ZContentHubEntry? absent = zPodcastHubEntry();

      await tester.pumpWidget(
        _host(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[other, ?absent],
          ),
        ),
      );
      final int withAbsent =
          tester.widgetList(find.byKey(ZContentHubSheet.avatarKey)).length;

      await tester.pumpWidget(
        _host(const ZContentHubSheet(entries: <ZContentHubEntry>[other])),
      );
      final int reference =
          tester.widgetList(find.byKey(ZContentHubSheet.avatarKey)).length;

      expect(withAbsent, equals(reference));
      expect(find.text('Podcast'), findsNothing);
    });

    testWidgets('CONTRE-PREUVE : câblée, l\'entrée EST montée et actionnable',
        (WidgetTester tester) async {
      int taps = 0;
      final ZContentHubEntry? entry = zPodcastHubEntry(
        icon: Icons.podcasts_outlined,
        label: 'Podcast',
        onTap: () => taps++,
      );
      expect(entry, isNotNull);
      expect(entry!.colorKey, equals(ZContentHubReference.colorKeyPodcast));

      await tester.pumpWidget(
        _host(ZContentHubSheet(entries: <ZContentHubEntry>[entry])),
      );
      expect(find.text('Podcast'), findsOneWidget);
      await tester.tap(find.text('Podcast'));
      await tester.pump();
      expect(taps, equals(1));
    });
  });

  // ── 2. Round-trip `withRouteId` verbatim ────────────────────────────────

  group('`withRouteId` — round-trip VERBATIM sur les trois requêtes', () {
    test('résumé de note : route posée, tout le reste inchangé', () {
      const ZNoteSummaryRequest base = ZNoteSummaryRequest(
        content: 'contenu',
        maxLength: 120,
        languageTag: 'fr',
        extra: <String, dynamic>{'app': 1},
      );
      final ZNoteSummaryRequest routed = base.withRouteId('summarize');
      expect(routed.routeId, equals('summarize'));
      expect(routed.content, equals(base.content));
      expect(routed.maxLength, equals(base.maxLength));
      expect(routed.languageTag, equals(base.languageTag));
      expect(routed.extra, equals(base.extra));
      // Retirer la route rend EXACTEMENT la requête d'origine.
      expect(routed.withRouteId(null), equals(base));
    });

    test('podcast : route posée, tout le reste inchangé', () {
      const ZPodcastGenerationRequest base = ZPodcastGenerationRequest(
        content: 'contenu',
        sourceKind: ZPodcastSourceKind.document,
        sourceId: 'd1',
        folderId: 'f9',
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h9',
        languageTag: 'fr',
        extra: <String, dynamic>{'app': 1},
      );
      final ZPodcastGenerationRequest routed = base.withRouteId('podcast');
      expect(routed.routeId, equals('podcast'));
      expect(routed.content, equals(base.content));
      expect(routed.sourceKind, equals(base.sourceKind));
      expect(routed.sourceId, equals(base.sourceId));
      expect(routed.folderId, equals(base.folderId));
      expect(routed.mode, equals(base.mode));
      expect(routed.sourceHash, equals(base.sourceHash));
      expect(routed.languageTag, equals(base.languageTag));
      expect(routed.extra, equals(base.extra));
      expect(routed.withRouteId(null), equals(base));
    });

    test('flashcards : route posée, tout le reste inchangé (sources incluses)',
        () {
      const ZFlashcardGenerationRequest base = ZFlashcardGenerationRequest(
        content: 'contenu',
        count: 12,
        languageTag: 'fr',
        instructions: 'ins',
        modelId: 'm1',
        extra: <String, dynamic>{'app': 1},
      );
      final ZFlashcardGenerationRequest routed = base.withRouteId('cards');
      expect(routed.routeId, equals('cards'));
      expect(routed.content, equals(base.content));
      expect(routed.count, equals(base.count));
      expect(routed.languageTag, equals(base.languageTag));
      expect(routed.instructions, equals(base.instructions));
      expect(routed.modelId, equals(base.modelId));
      expect(routed.extra, equals(base.extra));
      expect(routed.withRouteId(null), equals(base));

      // `withResolvedSources` ne PERD pas la route déjà posée.
      expect(
        routed.withResolvedSources(const <ZResolvedGenerationSource>[]).routeId,
        equals('cards'),
      );
    });

    test('contrôleur : la route est apposée, mais jamais RÉÉCRITE', () async {
      final _CountingPodcastPort port = _CountingPodcastPort();
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'err'),
        routeId: 'du-controleur',
      );
      addTearDown(controller.dispose);

      await controller.generate(
        const ZPodcastGenerationRequest(content: 'a', sourceId: 'n1'),
      );
      expect(port.received.first.routeId, equals('du-controleur'));

      await controller.generate(
        const ZPodcastGenerationRequest(
          content: 'b',
          sourceId: 'n2',
          routeId: 'de-l-appelant',
        ),
      );
      expect(port.received.last.routeId, equals('de-l-appelant'));
    });
  });

  // ── 3. Contrôleur : cycle, anti-double-soumission, handoff ──────────────

  group('ZPodcastGenerationController', () {
    test('idle → generating → ready, handoff appelé EXACTEMENT une fois',
        () async {
      final _CountingPodcastPort port = _CountingPodcastPort();
      final List<ZStudyPodcast> handed = <ZStudyPodcast>[];
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'err'),
        onGenerated: handed.add,
      );
      addTearDown(controller.dispose);

      expect(controller.status, equals(ZPodcastGenerationStatus.idle));
      await controller.generate(
        const ZPodcastGenerationRequest(content: 'a', sourceId: 'n1'),
      );
      expect(controller.status, equals(ZPodcastGenerationStatus.ready));
      expect(controller.podcast, isNotNull);
      expect(handed.length, equals(1));
      expect(port.calls, equals(1));
    });

    test('`Left` ⇒ failed, message du `ZFailure`, AUCUN handoff', () async {
      final _CountingPodcastPort port =
          _CountingPodcastPort(failure: const ZDomainFailure('quota'));
      int handoffs = 0;
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'err'),
        onGenerated: (_) => handoffs++,
      );
      addTearDown(controller.dispose);

      await controller.generate(const ZPodcastGenerationRequest(content: 'a'));
      expect(controller.status, equals(ZPodcastGenerationStatus.failed));
      expect(controller.errorMessage, equals('quota'));
      expect(controller.lastFailure, isA<ZDomainFailure>());
      expect(controller.podcast, isNull);
      expect(handoffs, equals(0));
    });

    test('port qui LÈVE ⇒ failed sans `ZFailure`, message injecté, sans levée',
        () async {
      final _CountingPodcastPort port = _CountingPodcastPort(throws: true);
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'imprévu'),
      );
      addTearDown(controller.dispose);

      await controller.generate(const ZPodcastGenerationRequest(content: 'a'));
      expect(controller.status, equals(ZPodcastGenerationStatus.failed));
      expect(controller.lastFailure, isNull);
      expect(controller.errorMessage, equals('imprévu'));
    });

    test('anti-double-soumission : une seule requête en vol', () async {
      final _CountingPodcastPort port = _CountingPodcastPort();
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'err'),
      );
      addTearDown(controller.dispose);

      final Future<void> first = controller.generate(
        const ZPodcastGenerationRequest(content: 'a'),
      );
      await controller.generate(const ZPodcastGenerationRequest(content: 'b'));
      await first;
      expect(port.calls, equals(1));
    });

    test('fraîcheur dérivée du podcast détenu (aucun hash calculé)', () async {
      final _CountingPodcastPort port = _CountingPodcastPort();
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'err'),
      );
      addTearDown(controller.dispose);

      expect(controller.freshnessFor('h1'), equals(ZPodcastFreshness.absent));
      await controller.generate(
        const ZPodcastGenerationRequest(content: 'a', sourceHash: 'h1'),
      );
      expect(controller.freshnessFor('h1'), equals(ZPodcastFreshness.fresh));
      expect(controller.freshnessFor('h2'), equals(ZPodcastFreshness.stale));
    });
  });

  // ── 4. Carte : statut par clé, action régénérer ─────────────────────────

  group('ZPodcastCard — statut et fraîcheur par LIBELLÉS injectés', () {
    testWidgets('sans fabrique de libellé : AUCUNE puce, AUCUNE clé nue',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZPodcastCard(podcast: _podcastWithoutAudio, title: 'Titre')),
      );
      expect(find.byKey(ZPodcastCard.statusChipKey), findsNothing);
      expect(find.byKey(ZPodcastCard.freshnessChipKey), findsNothing);
      // La clé d'enum n'est jamais rendue nue.
      expect(find.text('processing'), findsNothing);
      expect(find.text('Titre'), findsOneWidget);
    });

    testWidgets('avec fabriques : la CLÉ est projetée vers le libellé rendu',
        (WidgetTester tester) async {
      final List<ZPodcastStatus> seenStatus = <ZPodcastStatus>[];
      final List<ZPodcastFreshness> seenFreshness = <ZPodcastFreshness>[];
      await tester.pumpWidget(
        _host(
          ZPodcastCard(
            podcast: _podcastWithoutAudio,
            title: 'Titre',
            currentSourceHash: 'h2',
            statusLabel: (ZPodcastStatus s) {
              seenStatus.add(s);
              return 'statut:${s.name}';
            },
            freshnessLabel: (ZPodcastFreshness f) {
              seenFreshness.add(f);
              return 'fraicheur:${f.name}';
            },
          ),
        ),
      );
      expect(seenStatus, contains(ZPodcastStatus.processing));
      expect(seenFreshness, contains(ZPodcastFreshness.stale));
      expect(find.byKey(ZPodcastCard.statusChipKey), findsOneWidget);
      expect(find.text('statut:processing'), findsOneWidget);
      expect(find.text('fraicheur:stale'), findsOneWidget);
    });

    testWidgets('« régénérer » : sans callback ⇒ action ABSENTE',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZPodcastCard(podcast: _podcastWithoutAudio, title: 'T')),
      );
      expect(find.byKey(ZPodcastCard.regenerateKey), findsNothing);
    });

    testWidgets(
        '« régénérer » ⇒ 1 appel contrôleur ⇒ 1 appel port (cible ≥ 48 dp)',
        (WidgetTester tester) async {
      final _CountingPodcastPort port = _CountingPodcastPort();
      final ZPodcastGenerationController controller =
          ZPodcastGenerationController(
        port: port,
        messages: const ZPodcastGenerationMessages(unexpectedError: 'err'),
      );
      addTearDown(controller.dispose);

      int controllerCalls = 0;
      await tester.pumpWidget(
        _host(
          ZPodcastCard(
            podcast: _podcastWithoutAudio,
            title: 'T',
            regenerateLabel: 'Régénérer',
            onRegenerate: () {
              controllerCalls++;
              controller.generate(
                const ZPodcastGenerationRequest(content: 'a', sourceId: 'n2'),
              );
            },
          ),
        ),
      );

      final Finder button = find.byKey(ZPodcastCard.regenerateKey);
      expect(button, findsOneWidget);
      // AD-13 : cible tactile ≥ 48 dp dans les deux axes.
      final Size size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(controllerCalls, equals(1));
      expect(port.calls, equals(1));
    });

    testWidgets('`regenerating` : l\'action reste PRÉSENTE mais INERTE',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          ZPodcastCard(
            podcast: _podcastWithoutAudio,
            title: 'T',
            regenerating: true,
            onRegenerate: () => taps++,
          ),
        ),
      );
      final Finder button = find.byKey(ZPodcastCard.regenerateKey);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(taps, equals(0));
    });
  });

  // ── 5. Mini-lecteur : les quatre cas de montage ─────────────────────────

  group('ZPodcastAudioPlayer — monté SSI port ∧ disponible ∧ audio', () {
    testWidgets('1/4 port disponible + audio ⇒ lecteur MONTÉ',
        (WidgetTester tester) async {
      final _FakeAudioPort port = _FakeAudioPort();
      addTearDown(port.close);
      await tester.pumpWidget(
        _host(
          ZPodcastCard(
            podcast: _podcastWithAudio,
            title: 'T',
            audioPort: port,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZPodcastCard.playerKey), findsOneWidget);
      expect(port.loadCalls, equals(1));
    });

    testWidgets('2/4 port disponible SANS audio ⇒ lecteur ABSENT',
        (WidgetTester tester) async {
      final _FakeAudioPort port = _FakeAudioPort();
      addTearDown(port.close);
      await tester.pumpWidget(
        _host(
          ZPodcastCard(
            podcast: _podcastWithoutAudio,
            title: 'T',
            audioPort: port,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZPodcastCard.playerKey), findsNothing);
      expect(port.loadCalls, equals(0));
    });

    testWidgets('3/4 port INDISPONIBLE + audio ⇒ lecteur ABSENT',
        (WidgetTester tester) async {
      final _FakeAudioPort port = _FakeAudioPort(available: false);
      addTearDown(port.close);
      await tester.pumpWidget(
        _host(
          ZPodcastCard(
            podcast: _podcastWithAudio,
            title: 'T',
            audioPort: port,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZPodcastCard.playerKey), findsNothing);
      expect(port.loadCalls, equals(0));
    });

    testWidgets('4/4 AUCUN port + audio ⇒ lecteur ABSENT (chemin par défaut)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZPodcastCard(podcast: _podcastWithAudio, title: 'T')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZPodcastCard.playerKey), findsNothing);
      // Le repli inerte du socle est lui aussi « indisponible » : il ne monte
      // rien, et ne fait donc jamais croire qu'un son est joué.
      expect(
        ZPodcastAudioPlayer.canPlay(
          _podcastWithAudio,
          const ZInertAudioPlaybackPort(),
        ),
        isFalse,
      );
    });

    test('résolution de la source : règle unique et totale', () {
      expect(
        ZPodcastAudioPlayer.sourceOf(_podcastWithAudio),
        equals(const ZAudioSource.url('https://cdn.example/podcast.mp3')),
      );
      expect(ZPodcastAudioPlayer.sourceOf(_podcastWithoutAudio), isNull);
      expect(
        ZPodcastAudioPlayer.sourceOf(
          const ZStudyPodcast(resultRef: '/data/podcast.m4a'),
        ),
        equals(const ZAudioSource.file('/data/podcast.m4a')),
      );
    });
  });

  // ── 6. `Left` du moteur audio ⇒ échec VISIBLE, sans levée ──────────────

  testWidgets('`Left` au chargement ⇒ échec VISIBLE, aucune exception levée',
      (WidgetTester tester) async {
    final _FakeAudioPort port = _FakeAudioPort(loadFails: true);
    addTearDown(port.close);
    await tester.pumpWidget(
      _host(
        ZPodcastCard(
          podcast: _podcastWithAudio,
          title: 'T',
          audioPort: port,
          playbackFailedLabel: 'Lecture impossible',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(ZPodcastAudioPlayer.failureKey), findsOneWidget);
    expect(find.text('Lecture impossible'), findsOneWidget);
    // Aucun contrôle actionnable ne subsiste en échec.
    expect(find.byKey(ZPodcastAudioPlayer.toggleKey), findsNothing);
    expect(find.byKey(ZPodcastAudioPlayer.sliderKey), findsNothing);
  });

  testWidgets('échec SANS libellé injecté : il reste VISIBLE (glyphe)',
      (WidgetTester tester) async {
    final _FakeAudioPort port = _FakeAudioPort(loadFails: true);
    addTearDown(port.close);
    await tester.pumpWidget(
      _host(
        ZPodcastCard(podcast: _podcastWithAudio, title: 'T', audioPort: port),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(ZPodcastAudioPlayer.failureKey), findsOneWidget);
  });

  testWidgets('le port appartient à l\'hôte : JAMAIS disposé par le lecteur',
      (WidgetTester tester) async {
    final _FakeAudioPort port = _FakeAudioPort();
    addTearDown(port.close);
    await tester.pumpWidget(
      _host(
        ZPodcastCard(podcast: _podcastWithAudio, title: 'T', audioPort: port),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(port.disposed, isFalse);
  });

  // ── 7. Granularité ─────────────────────────────────────────────────────

  testWidgets(
      'GRANULARITÉ : un événement de position ne reconstruit NI l\'arbre '
      'autour NI le bouton de lecture', (WidgetTester tester) async {
    final _FakeAudioPort port =
        _FakeAudioPort(totalDuration: const Duration(seconds: 100));
    addTearDown(port.close);
    int outerBuilds = 0;

    await tester.pumpWidget(
      _host(
        _BuildProbe(
          onBuild: () => outerBuilds++,
          child: ZPodcastAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/p.mp3'),
            port: port,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final int buildsBefore = outerBuilds;

    // Instance du bouton AVANT : si le builder externe rejouait, une NOUVELLE
    // instance de widget serait construite (l'élément, lui, est réutilisé).
    final Widget toggleBefore =
        tester.widget(find.byKey(ZPodcastAudioPlayer.toggleKey));
    final Widget stampBefore =
        tester.widget(find.byKey(ZPodcastAudioPlayer.stampKey));

    for (int i = 1; i <= 5; i++) {
      port.positions.add(Duration(seconds: i));
      await tester.pump();
    }
    // Une passe de plus : le dernier événement du flux est livré au
    // microtask suivant, il ne serait pas encore peint sinon.
    await tester.pump();

    final Widget toggleAfter =
        tester.widget(find.byKey(ZPodcastAudioPlayer.toggleKey));
    final Widget stampAfter =
        tester.widget(find.byKey(ZPodcastAudioPlayer.stampKey));

    // L'événement a bien atterri : l'horodatage a changé d'instance ET de texte.
    expect(identical(stampBefore, stampAfter), isFalse);
    expect(find.text('00:05 / 01:40'), findsOneWidget);
    // …sans reconstruire le bouton ni l'arbre autour.
    expect(identical(toggleBefore, toggleAfter), isTrue);
    expect(outerBuilds, equals(buildsBefore));
  });
}
