// CHAT-1 — comportement des ports IA de la conversation.
//
// ⚠️ AUCUN `dart:io` ici : ce fichier DOIT tourner sous `dart test -p node`
// (gate `web-determinism`). Les gardes qui lisent les sources vivent dans
// `z_chat_ai_ports_guard_test.dart`, annoté `@TestOn('vm')`.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Doubles d'hôte — implémentent les ports SANS que le socle fournisse d'impl.
// ─────────────────────────────────────────────────────────────────────────────

/// Port de streaming d'hôte qui HONORE le jeton reçu — annulation ET reprise.
class _FakeStreamPort implements ZChatStreamPort {
  _FakeStreamPort({this.cutAt});

  /// Index auquel le transport coupe (simule une déconnexion), ou `null`.
  final int? cutAt;

  /// Événements du tour, indexés par leur position de séquence `e0..e4`.
  static const int total = 5;

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async* {
    // 🔴 REPRISE : on repart APRÈS la position reçue, jamais du début.
    final int start = token.lastSequenceId == null
        ? 0
        : int.parse(token.lastSequenceId!.substring(1)) + 1;
    for (int i = start; i < total; i++) {
      if (token.isCancelled) {
        yield Left<ZFailure, ZChatStreamEvent>(
          ZChatStreamInterruptedFailure(
            'cancelled',
            requestId: token.requestId,
            eventsReceived: i - start,
            cancelledByUser: true,
          ),
        );
        return;
      }
      if (cutAt != null && i == cutAt) {
        yield Left<ZFailure, ZChatStreamEvent>(
          ZChatStreamInterruptedFailure(
            'transport lost',
            requestId: token.requestId,
            eventsReceived: i - start,
          ),
        );
        return;
      }
      yield Right<ZFailure, ZChatStreamEvent>(
        ZChatTokenEvent(
          content: '${token.requestId}#$i',
          sequenceId: 'e$i',
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    yield Right<ZFailure, ZChatStreamEvent>(
      ZChatDoneEvent(messageId: token.requestId, sequenceId: 'e$total'),
    );
  }
}

/// Port de contexte d'hôte : rend des fragments d'étude.
class _FakeContextPort implements ZChatContextPort {
  _FakeContextPort(this._fragments);

  final List<ZChatContextFragment> _fragments;

  @override
  Future<ZResult<List<ZChatContextFragment>>> contextFor(
    ZChatContextRequest request,
  ) async =>
      Right<ZFailure, List<ZChatContextFragment>>(_fragments);
}

/// Hôte qui n'implémente PAS la capacité — réutilise le type EXISTANT.
class _UnsupportedContextPort implements ZChatContextPort {
  @override
  Future<ZResult<List<ZChatContextFragment>>> contextFor(
    ZChatContextRequest request,
  ) async =>
      Left<ZFailure, List<ZChatContextFragment>>(
        const ZUnsupportedOperationFailure(
          'no study context on this host',
          operation: 'contextFor',
        ),
      );
}

/// Port de génération d'hôte : rend des blocs de contenu.
class _FakeGenerationPort implements ZChatGenerationPort {
  @override
  Future<ZResult<List<ZContentBlock>>> generate(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async {
    if (token.isCancelled) {
      return Left<ZFailure, List<ZContentBlock>>(
        ZChatStreamInterruptedFailure(
          'cancelled',
          requestId: token.requestId,
          cancelledByUser: true,
        ),
      );
    }
    return Right<ZFailure, List<ZContentBlock>>(<ZContentBlock>[
      ZTextBlock(text: '${request.style.kind}:${request.notes}'),
    ]);
  }
}

void main() {
  group('ZChatGenerationStyle — extensible SANS modifier le socle (AD-4)', () {
    test('un style d\'hôte absent du catalogue est exprimable tel quel', () {
      // Les quatre styles de gamification d'IFFD — AUCUN n'est déclaré par le
      // socle, et pourtant l'hôte les exprime sans le forker.
      for (final String kind in <String>[
        'poem',
        'story',
        'humor',
        'classroom',
      ]) {
        final ZChatGenerationStyle style = ZChatGenerationStyle(kind);
        expect(style.kind, kind);
        expect(style.toJson()['style'], kind);
        expect(ZChatGenerationStyle.fromJson(style.toJson()), style);
      }
    });

    test('les params d\'un style d\'hôte round-trippent par ZTypeRegistry '
        '— aucun second registre n\'est créé', () {
      final ZTypeRegistry registry = ZTypeRegistry()
        ..register(
          'classroom',
          fromJson: (Map<String, dynamic> json) => <String, dynamic>{
            ...json,
            'decoded': true,
          },
          toJson: (Object value) => <String, dynamic>{
            ...(value as Map<String, dynamic>),
            'encoded': true,
          },
        );
      final ZChatGenerationStyle style = ZChatGenerationStyle(
        'classroom',
        <String, dynamic>{'level': 'debutant'},
      );
      final Map<String, dynamic> wire = style.toJson(typeRegistry: registry);
      expect(
        (wire['style_params'] as Map<String, dynamic>)['encoded'],
        isTrue,
      );
      final ZChatGenerationStyle? back =
          ZChatGenerationStyle.fromJson(wire, typeRegistry: registry);
      expect(back!.params['decoded'], isTrue);
      expect(back.params['level'], 'debutant');
    });

    test('un codec d\'hôte qui LÈVE est absorbé — repli verbatim (AD-10)', () {
      final ZTypeRegistry registry = ZTypeRegistry()
        ..register(
          'boom',
          fromJson: (Map<String, dynamic> json) =>
              throw StateError('codec hôte cassé'),
          toJson: (Object value) => throw StateError('codec hôte cassé'),
        );
      final ZChatGenerationStyle style =
          ZChatGenerationStyle('boom', <String, dynamic>{'a': 1});
      final Map<String, dynamic> wire = style.toJson(typeRegistry: registry);
      expect((wire['style_params'] as Map<String, dynamic>)['a'], 1);
      expect(
        ZChatGenerationStyle.fromJson(wire, typeRegistry: registry)!.params['a'],
        1,
      );
    });

    test('décodage défensif — entrée illisible ⇒ null, jamais de throw', () {
      expect(ZChatGenerationStyle.fromJson(null), isNull);
      expect(ZChatGenerationStyle.fromJson('pas une map'), isNull);
      expect(ZChatGenerationStyle.fromJson(<String, dynamic>{}), isNull);
      expect(
        ZChatGenerationStyle.fromJson(<String, dynamic>{'style': 42}),
        isNull,
      );
      expect(
        ZChatGenerationStyle.fromJson(
          <String, dynamic>{'style': 'x', 'style_params': 'illisible'},
        )!
            .params,
        isEmpty,
      );
    });

    test('le catalogue du socle reste MINIMAL et neutre', () {
      final Set<String> catalogue = <String>{
        ZChatGenerationStyle.converse.kind,
        ZChatGenerationStyle.summarize.kind,
        ZChatGenerationStyle.elaborate.kind,
        ZChatGenerationStyle.examples.kind,
      };
      expect(catalogue, hasLength(4));
      // La gamification d'IFFD n'entre PAS au socle.
      expect(
        catalogue.intersection(<String>{
          'poem',
          'story',
          'humor',
          'classroom',
        }),
        isEmpty,
      );
    });
  });

  group('ZChatRequestToken — annulation PAR REQUÊTE (D4)', () {
    test('deux jetons s\'annulent INDÉPENDAMMENT', () {
      final ZChatRequestToken a = ZChatRequestToken('req-a');
      final ZChatRequestToken b = ZChatRequestToken('req-b');
      a.cancel();
      expect(a.isCancelled, isTrue);
      expect(
        b.isCancelled,
        isFalse,
        reason: '🔴 jeton PARTAGÉ : annuler une requête a annulé l\'autre — '
            'défaut IFFD `iffd_ai_repository_impl.dart:29`',
      );
    });

    test('deux jetons de MÊME requestId restent distincts (pas un value '
        'object)', () {
      final ZChatRequestToken a = ZChatRequestToken('same');
      final ZChatRequestToken b = ZChatRequestToken('same');
      expect(a == b, isFalse);
      a.cancel();
      expect(b.isCancelled, isFalse);
    });

    test('cancel() est idempotent (AD-10)', () {
      final ZChatRequestToken t = ZChatRequestToken('r');
      t.cancel();
      expect(t.cancel, returnsNormally);
      expect(t.isCancelled, isTrue);
    });

    test('whenCancelled se complète sans erreur, et seulement pour SON jeton',
        () async {
      final ZChatRequestToken a = ZChatRequestToken('a');
      final ZChatRequestToken b = ZChatRequestToken('b');
      bool bFired = false;
      unawaited(b.whenCancelled.then((_) => bFired = true));
      a.cancel();
      await expectLater(a.whenCancelled, completes);
      await Future<void>.delayed(Duration.zero);
      expect(bFired, isFalse);
    });

    test('DEUX FLUX CONCURRENTS : annuler l\'un n\'interrompt pas l\'autre',
        () async {
      final ZChatStreamPort port = _FakeStreamPort();
      final ZChatGenerationRequest req =
          ZChatGenerationRequest(style: ZChatGenerationStyle.converse);
      final ZChatRequestToken t1 = ZChatRequestToken('flux-1');
      final ZChatRequestToken t2 = ZChatRequestToken('flux-2');

      final Future<List<ZResult<ZChatStreamEvent>>> f1 =
          port.stream(req, token: t1).toList();
      final Future<List<ZResult<ZChatStreamEvent>>> f2 =
          port.stream(req, token: t2).toList();

      await Future<void>.delayed(Duration.zero);
      t1.cancel();

      final List<ZResult<ZChatStreamEvent>> r1 = await f1;
      final List<ZResult<ZChatStreamEvent>> r2 = await f2;

      final ZFailure? f = r1.last.fold((ZFailure l) => l, (_) => null);
      expect(f, isA<ZChatStreamInterruptedFailure>());
      expect((f! as ZChatStreamInterruptedFailure).requestId, 'flux-1');
      expect((f as ZChatStreamInterruptedFailure).cancelledByUser, isTrue);

      // 🔴 Le second flux va au BOUT : aucune annulation croisée.
      expect(
        r2.every((ZResult<ZChatStreamEvent> e) => e.isRight()),
        isTrue,
        reason: '🔴 annulation croisée : le flux 2 a été coupé par le stop du '
            'flux 1',
      );
      expect(
        r2.last.fold((_) => null, (ZChatStreamEvent e) => e),
        isA<ZChatDoneEvent>(),
      );
    });

    test('REPRISE : le flux repart APRÈS la position reçue, sous la MÊME '
        'identité — le tour n\'est pas rejoué', () async {
      final ZChatGenerationRequest req = ZChatGenerationRequest(
        style: ZChatGenerationStyle.converse,
      );
      // 1er essai : le transport coupe après 2 événements.
      final ZChatRequestToken t = ZChatRequestToken('tour-7');
      expect(t.isResumption, isFalse);
      expect(t.lastSequenceId, isNull,
          reason: 'un premier essai ne reprend rien — jamais « position 0 »');

      final List<ZResult<ZChatStreamEvent>> essai1 =
          await _FakeStreamPort(cutAt: 2).stream(req, token: t).toList();
      final List<ZChatStreamEvent> recus1 = <ZChatStreamEvent>[
        for (final ZResult<ZChatStreamEvent> r in essai1)
          ?r.fold((_) => null, (ZChatStreamEvent e) => e),
      ];
      expect(recus1.map((ZChatStreamEvent e) => e.sequenceId).toList(),
          <String>['e0', 'e1']);
      final ZFailure coupure =
          essai1.last.fold((ZFailure f) => f, (_) => throw StateError('x'));
      expect(coupure, isA<ZChatStreamInterruptedFailure>());
      expect((coupure as ZChatStreamInterruptedFailure).cancelledByUser, isFalse,
          reason: 'une coupure SUBIE n\'est pas une annulation VOULUE');

      // Reprise : nouveau jeton, MÊME identité, position portée.
      final ZChatRequestToken reprise = t.resumeFrom(recus1.last.sequenceId!);
      expect(reprise.requestId, t.requestId,
          reason: '🔴 identité de tour CHANGÉE ⇒ le serveur rejouerait le tour');
      expect(reprise.isResumption, isTrue);
      expect(identical(reprise, t), isFalse,
          reason: 'la reprise est une NOUVELLE tentative, annulable seule');

      final List<ZResult<ZChatStreamEvent>> essai2 =
          await _FakeStreamPort().stream(req, token: reprise).toList();
      final List<String?> seq2 = <String?>[
        for (final ZResult<ZChatStreamEvent> r in essai2)
          r.fold((_) => null, (ZChatStreamEvent e) => e.sequenceId),
      ];
      expect(seq2, <String>['e2', 'e3', 'e4', 'e5'],
          reason: '🔴 le flux a REJOUÉ des événements déjà reçus');
    });

    test('la reprise s\'annule INDÉPENDAMMENT de la tentative coupée', () {
      final ZChatRequestToken t = ZChatRequestToken('tour-8');
      final ZChatRequestToken reprise = t.resumeFrom('e3');
      t.cancel();
      expect(reprise.isCancelled, isFalse);
      reprise.cancel();
      expect(reprise.isCancelled, isTrue);
    });

    test('le requestId est bien l\'identité attendue par cancelRequest '
        '(câblage CHAT-0b)', () {
      final ZChatRequestToken t = ZChatRequestToken('m-42');
      // `ZChatActionExecutor.cancelRequest(String requestId)` — même identité,
      // aucun second mécanisme d'annulation.
      expect(t.requestId, 'm-42');
    });
  });

  group('ZChatStreamEvent — modèle SCELLÉ, zéro sentinelle textuelle', () {
    test('la réflexion est un VARIANT, portant le ZChatThinkingStep EXISTANT',
        () {
      final ZChatStreamEvent? e = ZChatStreamEvent.fromJson(<String, dynamic>{
        'type': 'thinking',
        'agent': 'retriever',
        'content': 'je cherche',
      });
      expect(e, isA<ZChatThinkingEvent>());
      final ZChatThinkingStep step = (e! as ZChatThinkingEvent).step;
      expect(step.agent, 'retriever');
      expect(step.content, 'je cherche');
    });

    test('un contenu utilisateur qui RESSEMBLE à une sentinelle IFFD reste un '
        'contenu — il ne bascule aucun mode', () {
      const String piege = '<RAG_THINKING>coucou</RAG_THINKING>';
      final ZChatStreamEvent? e = ZChatStreamEvent.fromJson(
        <String, dynamic>{'type': 'token', 'content': piege},
      );
      expect(e, isA<ZChatTokenEvent>());
      expect((e! as ZChatTokenEvent).content, piege);
      // Le contenu traverse INTACT : aucun nettoyage par regex n'est requis
      // (IFFD en recopie un dans cinq fichiers de présentation).
      expect(e.toJson()['content'], piege);
    });

    test('les alias snake_case du fil de lex sont LUS, jamais réémis', () {
      final ZChatStreamEvent? e = ZChatStreamEvent.fromJson(<String, dynamic>{
        'type': 'retrieval_progress',
        'agent': 'a',
        'sources_found': 3,
      });
      expect(e, isA<ZChatRetrievalProgressEvent>());
      expect((e! as ZChatRetrievalProgressEvent).sourcesFound, 3);
      expect(e.toJson()['type'], 'retrievalProgress');
    });

    test('un type INCONNU devient un variant OUVERT, jamais une erreur '
        '(divergence assumée d\'avec lex)', () {
      final ZChatStreamEvent? e = ZChatStreamEvent.fromJson(<String, dynamic>{
        'type': 'clarification',
        'question': 'Pour quel pays ?',
      });
      expect(e, isA<ZChatCustomStreamEvent>());
      final ZChatCustomStreamEvent c = e! as ZChatCustomStreamEvent;
      expect(c.kind, 'clarification');
      expect(c.payload['question'], 'Pour quel pays ?');
      expect(c.toJson()['type'], 'clarification');
    });

    test('round-trip des variants portant un type EXISTANT du package', () {
      final List<ZChatStreamEvent> events = <ZChatStreamEvent>[
        const ZChatThinkingEvent(
          step: ZChatThinkingStep(agent: 'a', content: 'c'),
        ),
        const ZChatRetrievalProgressEvent(agent: 'a', sourcesFound: 2),
        const ZChatSourcesPreviewEvent(
          sources: <ZChatSource>[
            ZChatSource(sourceType: 'article', displayText: 'Art. 1'),
          ],
        ),
        const ZChatTokenEvent(content: 'salut'),
        const ZChatContentBlockEvent(block: ZTextBlock(text: 'bloc')),
        const ZChatSuggestionsEvent(
          suggestions: <ZChatSuggestion>[
            ZChatSuggestion(id: 's1', type: 'followUp', content: 'et sinon ?'),
          ],
        ),
        const ZChatQuotaEvent(
          snapshot: ZChatQuotaSnapshot(limit: 10, remaining: 4),
        ),
        const ZChatDoneEvent(messageId: 'm1', conversationId: 'c1'),
      ];
      for (final ZChatStreamEvent e in events) {
        expect(
          ZChatStreamEvent.fromJson(e.toJson()),
          e,
          reason: 'round-trip cassé pour ${e.kind}',
        );
      }
    });

    test('la POSITION de reprise round-trippe, et `id:` brut est accepté', () {
      final ZChatStreamEvent? e = ZChatStreamEvent.fromJson(<String, dynamic>{
        'type': 'token',
        'content': 'x',
        'id': 'seq-42',
      });
      expect(e!.sequenceId, 'seq-42',
          reason: 'sans la position, aucune reprise n\'est possible');
      expect(e.toJson()['sequence_id'], 'seq-42',
          reason: 'la forme canonique est réémise, pas `id`');
      expect(ZChatStreamEvent.fromJson(e.toJson())!.sequenceId, 'seq-42');
    });

    test('la position N\'EST PAS recopiée dans le payload d\'un variant '
        'ouvert (elle est structurelle)', () {
      final ZChatCustomStreamEvent c = ZChatStreamEvent.fromJson(
        <String, dynamic>{
          'type': 'clarification',
          'question': 'q',
          'sequence_id': 's1',
        },
      )! as ZChatCustomStreamEvent;
      expect(c.sequenceId, 's1');
      expect(c.payload.containsKey('sequence_id'), isFalse);
      expect(c.payload.containsKey('id'), isFalse);
    });

    test('deux événements identiques à des POSITIONS différentes ne sont pas '
        'égaux (dédoublonnage de reprise)', () {
      expect(
        const ZChatTokenEvent(content: 'a', sequenceId: 'e1'),
        isNot(const ZChatTokenEvent(content: 'a', sequenceId: 'e2')),
      );
      expect(
        const ZChatTokenEvent(content: 'a', sequenceId: 'e1'),
        const ZChatTokenEvent(content: 'a', sequenceId: 'e1'),
      );
    });

    test('position ABSENTE ⇒ null (transport non reprenable), jamais « 0 »',
        () {
      final ZChatStreamEvent? e = ZChatStreamEvent.fromJson(
        <String, dynamic>{'type': 'token', 'content': 'x'},
      );
      expect(e!.sequenceId, isNull);
      expect(e.toJson().containsKey('sequence_id'), isFalse);
    });

    test('décodage TOTAL : aucune entrée illisible ne lève (AD-10)', () {
      for (final Object? raw in <Object?>[
        null,
        'texte',
        42,
        <String, dynamic>{},
        <String, dynamic>{'type': ''},
        <String, dynamic>{'type': 123},
        <String, dynamic>{'type': 'sourcesPreview', 'sources': 'pas une liste'},
        <String, dynamic>{'type': 'quota', 'snapshot': 'illisible'},
        <String, dynamic>{'type': 'contentBlock', 'block_type': null},
      ]) {
        expect(() => ZChatStreamEvent.fromJson(raw), returnsNormally);
      }
      expect(
        ZChatStreamEvent.fromJson(<String, dynamic>{
          'type': 'sourcesPreview',
          'sources': 'pas une liste',
        }),
        const ZChatSourcesPreviewEvent(),
      );
    });
  });

  group('ZChatContextPort — le contexte d\'étude, assemblé à UN SEUL site', () {
    test('ordered() : priorité décroissante, tri STABLE, vides écartés, '
        'doublons retirés', () {
      final List<ZChatContextFragment> out = ZChatContextFragment.ordered(
        <ZChatContextFragment?>[
          const ZChatContextFragment(kind: 'folder', text: 'Dossier X'),
          const ZChatContextFragment(kind: 'vide', text: ''),
          null,
          const ZChatContextFragment(
            kind: 'userPresentation',
            text: 'Étudiant L3',
            priority: 10,
          ),
          const ZChatContextFragment(kind: 'folder', text: 'Dossier X'),
          const ZChatContextFragment(kind: 'level', text: 'Superieur'),
        ],
      );
      expect(
        out.map((ZChatContextFragment f) => f.kind).toList(),
        <String>['userPresentation', 'folder', 'level'],
      );
      expect(out, hasLength(3));
    });

    test('ordered() est DÉTERMINISTE : deux ordres d\'entrée équivalents '
        'produisent le même contexte soumis', () {
      const ZChatContextFragment a =
          ZChatContextFragment(kind: 'a', text: 'A', priority: 5);
      const ZChatContextFragment b =
          ZChatContextFragment(kind: 'b', text: 'B', priority: 9);
      expect(
        ZChatContextFragment.ordered(<ZChatContextFragment>[a, b]),
        ZChatContextFragment.ordered(<ZChatContextFragment>[b, a]),
      );
    });

    test('le résultat est NON MODIFIABLE (aucun site ne peut le réécrire)',
        () {
      final List<ZChatContextFragment> out = ZChatContextFragment.ordered(
        <ZChatContextFragment>[
          const ZChatContextFragment(kind: 'k', text: 't'),
        ],
      );
      expect(
        () => out.add(const ZChatContextFragment(kind: 'x', text: 'y')),
        throwsUnsupportedError,
      );
    });

    test('un hôte fournit son contexte ; il alimente la requête, ordonné',
        () async {
      final ZChatContextPort port = _FakeContextPort(<ZChatContextFragment>[
        const ZChatContextFragment(kind: 'folder', text: 'Douane'),
        const ZChatContextFragment(
          kind: 'userPresentation',
          text: 'Étudiant',
          priority: 10,
        ),
      ]);
      final ZResult<List<ZChatContextFragment>> r =
          await port.contextFor(ZChatContextRequest(subject: 'TEC'));
      final List<ZChatContextFragment> fragments =
          r.fold((_) => <ZChatContextFragment>[], (List<ZChatContextFragment> f) => f);
      final ZChatGenerationRequest req = ZChatGenerationRequest(
        style: ZChatGenerationStyle.summarize,
        context: fragments,
      );
      expect(
        req.context.map((ZChatContextFragment f) => f.kind).toList(),
        <String>['userPresentation', 'folder'],
      );
    });

    test('capacité absente ⇒ type EXISTANT ZUnsupportedOperationFailure, '
        'jamais une panne ni un parsing de texte', () async {
      final ZResult<List<ZChatContextFragment>> r =
          await _UnsupportedContextPort().contextFor(ZChatContextRequest());
      final ZFailure? f = r.fold((ZFailure l) => l, (_) => null);
      expect(f, isA<ZUnsupportedOperationFailure>());
      expect((f! as ZUnsupportedOperationFailure).operation, 'contextFor');
    });

    test('la portée écarte les clés de sync réservées (AD-19.1)', () {
      final ZChatContextRequest req = ZChatContextRequest(
        scope: <String, dynamic>{
          'folder_id': 'f1',
          'updated_at': 'triche',
          'is_deleted': true,
        },
      );
      expect(req.scope.containsKey('folder_id'), isTrue);
      expect(req.scope.containsKey('updated_at'), isFalse);
      expect(req.scope.containsKey('is_deleted'), isFalse);
    });

    test('round-trip défensif d\'un fragment', () {
      const ZChatContextFragment f =
          ZChatContextFragment(kind: 'folder', text: 'X', priority: 3);
      expect(ZChatContextFragment.fromJson(f.toJson()), f);
      expect(ZChatContextFragment.fromJson(null), isNull);
      expect(ZChatContextFragment.fromJson(<String, dynamic>{'text': 'x'}),
          isNull);
    });
  });

  group('ZChatGenerationRequest / ports — un contrat, deux transports', () {
    test('la MÊME requête sert le port one-shot et le port de streaming', () {
      final ZChatGenerationRequest req = ZChatGenerationRequest(
        style: ZChatGenerationStyle('poem'),
        subject: 'Valeur en douane',
        notes: 'mes notes',
      );
      expect(
        () => _FakeGenerationPort()
            .generate(req, token: ZChatRequestToken('a')),
        returnsNormally,
      );
      expect(
        () => _FakeStreamPort().stream(req, token: ZChatRequestToken('b')),
        returnsNormally,
      );
    });

    test('un style d\'hôte traverse la génération sans toucher au socle',
        () async {
      final ZResult<List<ZContentBlock>> r = await _FakeGenerationPort().generate(
        ZChatGenerationRequest(
          style: ZChatGenerationStyle('classroom'),
          notes: 'la TEC',
        ),
        token: ZChatRequestToken('r1'),
      );
      final List<ZContentBlock> blocks =
          r.fold((_) => <ZContentBlock>[], (List<ZContentBlock> b) => b);
      expect(blocks.single, isA<ZTextBlock>());
      expect((blocks.single as ZTextBlock).text, 'classroom:la TEC');
    });

    test('égalité PAR VALEUR, contexte normalisé à la construction', () {
      final ZChatGenerationRequest a = ZChatGenerationRequest(
        style: ZChatGenerationStyle.summarize,
        context: <ZChatContextFragment>[
          const ZChatContextFragment(kind: 'b', text: 'B'),
          const ZChatContextFragment(kind: 'a', text: 'A', priority: 3),
        ],
      );
      final ZChatGenerationRequest b = ZChatGenerationRequest(
        style: ZChatGenerationStyle.summarize,
        context: <ZChatContextFragment>[
          const ZChatContextFragment(kind: 'a', text: 'A', priority: 3),
          const ZChatContextFragment(kind: 'b', text: 'B'),
        ],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('les enums EXISTANTS de CHAT-0 sont RÉUTILISÉS, jamais redéclarés',
        () {
      final ZChatGenerationRequest req = ZChatGenerationRequest(
        style: ZChatGenerationStyle.converse,
        responseLength: ZChatResponseLength.concise,
        lengthBias: ZChatLengthBias.longer,
      );
      expect(req.responseLength, ZChatResponseLength.concise);
      expect(req.lengthBias, ZChatLengthBias.longer);
    });

    test('extra normalisé EAGER : clés de sync réservées écartées (AD-19.1)',
        () {
      final ZChatGenerationRequest req = ZChatGenerationRequest(
        style: ZChatGenerationStyle.converse,
        extra: <String, dynamic>{'x': 1, 'updated_at': 'triche'},
      );
      expect(req.extra['x'], 1);
      expect(req.extra.containsKey('updated_at'), isFalse);
    });
  });

  group('ZChatGenerationRequest.copyWith — sentinelle, 19 champs', () {
    ZChatGenerationRequest full() => ZChatGenerationRequest(
          style: ZChatGenerationStyle('s'),
          subject: 'subj',
          notes: 'notes',
          conversationId: 'c',
          sourceMessageId: 'sm',
          context: const <ZChatContextFragment>[
            ZChatContextFragment(kind: 'k', text: 't'),
          ],
          attachmentIds: const <String>['a'],
          responseLength: ZChatResponseLength.concise,
          lengthBias: ZChatLengthBias.longer,
          computeEffort: ZChatComputeEffort(2),
          revealThinkingSteps: true,
          webSearch: true,
          capabilities: const <String, bool>{'cap': true},
          corpusScope: ZChatCorpusScope.ofKeys(const <String>['corpus']),
          languageTag: 'fr',
          instructions: 'i',
          modelId: 'm',
          providerId: 'p',
          extra: const <String, dynamic>{'x': 1},
        );

    test('sans argument ⇒ copie ÉGALE (et même hash)', () {
      final ZChatGenerationRequest base = full();
      expect(base.copyWith(), base);
      expect(base.copyWith().hashCode, base.hashCode);
    });

    test('chaque champ, seul, change la copie et ne change QUE lui (tableau)',
        () {
      final ZChatGenerationRequest base = full();
      final Map<String, ZChatGenerationRequest> variants =
          <String, ZChatGenerationRequest>{
        'style': base.copyWith(style: ZChatGenerationStyle('autre')),
        'subject': base.copyWith(subject: 'autre'),
        'notes': base.copyWith(notes: 'autre'),
        'conversationId': base.copyWith(conversationId: 'autre'),
        'sourceMessageId': base.copyWith(sourceMessageId: 'autre'),
        'context': base.copyWith(context: const <ZChatContextFragment>[]),
        'attachmentIds': base.copyWith(attachmentIds: const <String>[]),
        'responseLength':
            base.copyWith(responseLength: ZChatResponseLength.detailed),
        'lengthBias': base.copyWith(lengthBias: ZChatLengthBias.shorter),
        'computeEffort': base.copyWith(computeEffort: ZChatComputeEffort(5)),
        'revealThinkingSteps': base.copyWith(revealThinkingSteps: false),
        'webSearch': base.copyWith(webSearch: false),
        'capabilities':
            base.copyWith(capabilities: const <String, bool>{'cap': false}),
        'corpusScope': base.copyWith(
          corpusScope: ZChatCorpusScope.ofKeys(const <String>['z']),
        ),
        'languageTag': base.copyWith(languageTag: 'en'),
        'instructions': base.copyWith(instructions: 'autre'),
        'modelId': base.copyWith(modelId: 'autre'),
        'providerId': base.copyWith(providerId: 'autre'),
        'extra': base.copyWith(extra: const <String, dynamic>{'x': 2}),
      };
      expect(variants.length, 19, reason: 'un champ de la requête manque');
      for (final MapEntry<String, ZChatGenerationRequest> e
          in variants.entries) {
        expect(e.value, isNot(base), reason: '`${e.key}` ignoré par copyWith');
        // Revenir sur CE champ seul rend l'égalité : rien d'autre n'a bougé.
        final ZChatGenerationRequest back = switch (e.key) {
          'style' => e.value.copyWith(style: base.style),
          'subject' => e.value.copyWith(subject: base.subject),
          'notes' => e.value.copyWith(notes: base.notes),
          'conversationId' =>
            e.value.copyWith(conversationId: base.conversationId),
          'sourceMessageId' =>
            e.value.copyWith(sourceMessageId: base.sourceMessageId),
          'context' => e.value.copyWith(context: base.context),
          'attachmentIds' => e.value.copyWith(attachmentIds: base.attachmentIds),
          'responseLength' =>
            e.value.copyWith(responseLength: base.responseLength),
          'lengthBias' => e.value.copyWith(lengthBias: base.lengthBias),
          'computeEffort' => e.value.copyWith(computeEffort: base.computeEffort),
          'revealThinkingSteps' =>
            e.value.copyWith(revealThinkingSteps: base.revealThinkingSteps),
          'webSearch' => e.value.copyWith(webSearch: base.webSearch),
          'capabilities' => e.value.copyWith(capabilities: base.capabilities),
          'corpusScope' => e.value.copyWith(corpusScope: base.corpusScope),
          'languageTag' => e.value.copyWith(languageTag: base.languageTag),
          'instructions' => e.value.copyWith(instructions: base.instructions),
          'modelId' => e.value.copyWith(modelId: base.modelId),
          'providerId' => e.value.copyWith(providerId: base.providerId),
          'extra' => e.value.copyWith(extra: base.extra),
          _ => throw StateError(e.key),
        };
        expect(back, base, reason: '`${e.key}` a entraîné un autre champ');
      }
    });

    test('`null` EXPLICITE retire un champ nullable ; omis le conserve', () {
      final ZChatGenerationRequest base = full();
      expect(base.copyWith(providerId: null).providerId, isNull);
      expect(base.copyWith(modelId: null).modelId, isNull);
      expect(base.copyWith(corpusScope: null).corpusScope, isNull);
      expect(base.copyWith(computeEffort: null).computeEffort, isNull);
      expect(base.copyWith(subject: 'z').providerId, 'p');
      expect(base.copyWith(subject: 'z').modelId, 'm');
    });

    test('les invariants du constructeur s\'appliquent à la copie', () {
      final ZChatGenerationRequest base = full();
      final ZChatGenerationRequest c = base.copyWith(
        webSearch: null,
        capabilities: const <String, bool>{'web_search': false, 'b': true},
        extra: const <String, dynamic>{'ok': 1, 'updated_at': 'triche'},
        context: const <ZChatContextFragment>[
          ZChatContextFragment(kind: 'b', text: 'B'),
          ZChatContextFragment(kind: 'a', text: 'A', priority: 3),
        ],
      );
      expect(c.webSearch, isFalse, reason: 'clé réservée hissée');
      expect(c.capabilities.containsKey('web_search'), isFalse);
      expect(c.extra.containsKey('updated_at'), isFalse);
      expect(c.context.first.kind, 'a', reason: 'contexte réordonné');
    });

    test('`withSettings` / `withCorpusScope` sont des appelants de copyWith',
        () {
      final ZChatGenerationRequest base = full();
      expect(base.withSettings(base.settings), base);
      expect(base.withSettings(null), same(base));
      expect(
        base.withSettings(const ZChatGenerationSettings()),
        base.copyWith(
          responseLength: null,
          lengthBias: null,
          computeEffort: null,
          revealThinkingSteps: null,
          webSearch: null,
          capabilities: const <String, bool>{},
        ),
      );
      expect(base.withCorpusScope(null), base.copyWith(corpusScope: null));
      expect(base.withCorpusScope(null).providerId, 'p');
    });
  });

  group('ZChatComputeEffort — DEUX AXES, jamais fusionnés', () {
    test('l\'axe CALCUL est l\'entier 1..5 commun aux DEUX backends', () {
      expect(ZChatComputeEffort.min, 1);
      expect(ZChatComputeEffort.max, 5);
      for (int i = 1; i <= 5; i++) {
        expect(ZChatComputeEffort(i).level, i);
        expect(ZChatComputeEffort(i).toJson(), i);
      }
    });

    test('l\'enum low/medium/high d\'IFFD se PROJETTE sur l\'entier — sans '
        'perdre les paliers intermédiaires', () {
      expect(ZChatComputeEffort.low.level, 1);
      expect(ZChatComputeEffort.medium.level, 3);
      expect(ZChatComputeEffort.high.level, 5);
      // 🔴 Un enum à trois valeurs perdrait 2 et 4 : c'est pour cela que le
      // socle porte l'entier et non l'enum.
      expect(<int>{2, 4}.every((int i) => ZChatComputeEffort(i).level == i),
          isTrue);
    });

    test('hors bornes ⇒ ÉCRÊTÉ, jamais une exception (AD-10)', () {
      expect(ZChatComputeEffort(0).level, 1);
      expect(ZChatComputeEffort(-9).level, 1);
      expect(ZChatComputeEffort(42).level, 5);
    });

    test('lecture défensive : absent/illisible ⇒ null, jamais un palier '
        'inventé', () {
      expect(ZChatComputeEffort.fromJson(null), isNull);
      expect(ZChatComputeEffort.fromJson('abc'), isNull);
      expect(ZChatComputeEffort.fromJson(<String, dynamic>{}), isNull);
      expect(ZChatComputeEffort.fromJson('4')!.level, 4);
      expect(ZChatComputeEffort.fromJson(3.7)!.level, 3);
    });

    test('CALCUL et VERBOSITÉ coexistent sur la requête, orthogonaux', () {
      final ZChatGenerationRequest a = ZChatGenerationRequest(
        style: ZChatGenerationStyle.converse,
        responseLength: ZChatResponseLength.concise,
        computeEffort: ZChatComputeEffort.high,
      );
      final ZChatGenerationRequest b = ZChatGenerationRequest(
        style: ZChatGenerationStyle.converse,
        responseLength: ZChatResponseLength.detailed,
        computeEffort: ZChatComputeEffort.high,
      );
      // Même budget de calcul, verbosité opposée : deux demandes DISTINCTES.
      expect(a, isNot(b));
      expect(a.computeEffort, b.computeEffort);

      final ZChatGenerationRequest c = ZChatGenerationRequest(
        style: ZChatGenerationStyle.converse,
        responseLength: ZChatResponseLength.concise,
        computeEffort: ZChatComputeEffort.low,
      );
      expect(a, isNot(c));
    });

    test('égalité par VALEUR', () {
      expect(ZChatComputeEffort(3), ZChatComputeEffort(3));
      expect(ZChatComputeEffort(3).hashCode, ZChatComputeEffort(3).hashCode);
      expect(ZChatComputeEffort(3), isNot(ZChatComputeEffort(4)));
    });
  });

  group('Quota — lu depuis une carte NEUTRE au transport, absent possible', () {
    test('alimenté depuis des métadonnées, pas depuis un corps JSON supposé',
        () {
      final ZChatQuotaSnapshot? q = zChatQuotaFromMetadata(<String, Object?>{
        // Valeurs TEXTUELLES : c'est ce que rend un en-tête.
        'limit': '50',
        'remaining': '12',
        'reset_epoch': '1750000000',
        'prepaid_balance': '3',
      });
      expect(q, isNotNull);
      expect(q!.limit, 50);
      expect(q.remaining, 12);
      expect(q.resetEpoch, 1750000000);
      expect(q.prepaidBalance, 3);
      expect(q.isExhausted, isFalse);
    });

    test('insensible à la casse (les en-têtes le sont)', () {
      final ZChatQuotaSnapshot? q = zChatQuotaFromMetadata(<String, Object?>{
        'Limit': 20,
        'REMAINING': 5,
      });
      expect(q!.limit, 20);
      expect(q.remaining, 5);
    });

    test('🔴 KILL-SWITCH : aucune clé de quota ⇒ null, JAMAIS un instantané à '
        'zéro qui se lirait « quota épuisé »', () {
      for (final Map<String, Object?>? meta in <Map<String, Object?>?>[
        null,
        <String, Object?>{},
        <String, Object?>{'content-length': '42', 'x-trace': 'abc'},
      ]) {
        expect(zChatQuotaFromMetadata(meta), isNull, reason: '$meta');
      }
      // La preuve du danger : un instantané à zéro SE LIRAIT épuisé.
      expect(const ZChatQuotaSnapshot().isExhausted, isTrue);
    });

    test('clés INJECTABLES : un hôte qui nomme autrement n\'a rien à forker',
        () {
      const ZChatQuotaKeys keys = ZChatQuotaKeys(
        limit: 'quota_max',
        remaining: 'quota_left',
      );
      final ZChatQuotaSnapshot? q = zChatQuotaFromMetadata(
        <String, Object?>{'quota_max': 9, 'quota_left': 4},
        keys: keys,
      );
      expect(q!.limit, 9);
      expect(q.remaining, 4);
      // Les clés par défaut ne voient rien dans cette carte.
      expect(
        zChatQuotaFromMetadata(<String, Object?>{'quota_max': 9}),
        isNull,
      );
    });

    test('valeur illisible ⇒ défaut neutre, jamais de throw (AD-10)', () {
      final ZChatQuotaSnapshot? q = zChatQuotaFromMetadata(<String, Object?>{
        'limit': 'pas un nombre',
        'remaining': 7,
      });
      expect(q!.limit, 0);
      expect(q.remaining, 7);
      expect(q.prepaidBalance, isNull);
    });

    test('le délai de réessai alimente le type EXISTANT '
        'ZQuotaExceededFailure', () {
      final Duration? d =
          zChatRetryAfterFromMetadata(<String, Object?>{'retry_after_seconds': '120'});
      expect(d, const Duration(seconds: 120));
      final ZFailure f = ZQuotaExceededFailure('quota', retryAfter: d);
      expect((f as ZQuotaExceededFailure).retryAfter, const Duration(seconds: 120));
      // Absent ⇒ null, ce qui ne veut JAMAIS dire « réessayable tout de suite ».
      expect(zChatRetryAfterFromMetadata(<String, Object?>{}), isNull);
      expect(zChatRetryAfterFromMetadata(null), isNull);
      expect(
        zChatRetryAfterFromMetadata(<String, Object?>{'retry_after_seconds': 'x'}),
        isNull,
      );
    });

    test('un `retry_after_seconds` SEUL ne fabrique pas un instantané de '
        'quota', () {
      expect(
        zChatQuotaFromMetadata(<String, Object?>{'retry_after_seconds': '30'}),
        isNull,
      );
    });
  });

  group('Familles d\'échec IA — typées, jamais du texte brut', () {
    test('quota ⇒ ZQuotaExceededFailure, le type EXISTANT du cœur, avec son '
        'retryAfter', () {
      final ZFailure f = zChatFailureFromWire(<String, dynamic>{
        'code': ZChatFailureCodes.quotaExceeded,
        'message': 'quota epuise',
        'retry_after_seconds': 90,
      });
      expect(f, isA<ZQuotaExceededFailure>());
      expect((f as ZQuotaExceededFailure).retryAfter, const Duration(seconds: 90));
      expect(f.message, 'quota epuise');
    });

    test('modération / contexte / interruption ⇒ les trois familles créées',
        () {
      final ZFailure moderation = zChatFailureFromWire(<String, dynamic>{
        'code': ZChatFailureCodes.moderationBlocked,
        'category': 'violence',
        'on_input': false,
      });
      expect(moderation, isA<ZChatModerationFailure>());
      expect((moderation as ZChatModerationFailure).category, 'violence');
      expect(moderation.onInput, isFalse);

      final ZFailure ctx = zChatFailureFromWire(<String, dynamic>{
        'code': ZChatFailureCodes.contextLimitExceeded,
        'token_count': 40000,
        'token_limit': 32000,
      });
      expect(ctx, isA<ZChatContextLimitFailure>());
      expect((ctx as ZChatContextLimitFailure).tokenCount, 40000);
      expect(ctx.tokenLimit, 32000);

      final ZFailure cut = zChatFailureFromWire(<String, dynamic>{
        'code': ZChatFailureCodes.streamInterrupted,
        'request_id': 'r7',
        'events_received': 12,
        'cancelled_by_user': true,
      });
      expect(cut, isA<ZChatStreamInterruptedFailure>());
      expect((cut as ZChatStreamInterruptedFailure).requestId, 'r7');
      expect(cut.eventsReceived, 12);
      expect(cut.cancelledByUser, isTrue);
    });

    test('capacité absente ⇒ ZUnsupportedOperationFailure (EXISTANT)', () {
      final ZFailure f = zChatFailureFromWire(<String, dynamic>{
        'code': ZChatFailureCodes.unsupported,
        'operation': 'stream',
      });
      expect(f, isA<ZUnsupportedOperationFailure>());
      expect((f as ZUnsupportedOperationFailure).operation, 'stream');
    });

    test('code INCONNU ⇒ le code est CONSERVÉ (amélioration réelle sur lex, '
        'dont le client Dart le jette)', () {
      // Les 4 codes propres au streaming chez lex. Aucun n'a de famille typée
      // dédiée — et aucun ne doit pour autant être perdu.
      for (final String code in <String>[
        'AGENT_TIMEOUT',
        'LLM_ERROR',
        'GRAPH_ERROR',
        'quelque_chose_de_futur',
      ]) {
        final ZFailure f = zChatFailureFromWire(<String, dynamic>{
          'code': code,
          'message': 'boom',
        });
        expect(f, isA<ZChatProviderFailure>(), reason: code);
        expect((f as ZChatProviderFailure).code, code,
            reason: '🔴 code JETÉ — c\'est exactement ce que fait '
                '`ChatErrorEvent` de lex, qui ne porte qu\'un `message`');
        expect(f.message, 'boom');
      }
    });

    test('AUCUN code ⇒ ZServerFailure (le repli n\'est atteint que sans code)',
        () {
      final ZFailure f =
          zChatFailureFromWire(<String, dynamic>{'message': 'boom'});
      expect(f, isA<ZServerFailure>());
      expect(f, isNot(isA<ZChatProviderFailure>()));
    });

    test('les familles TYPÉES conservent AUSSI le code du fournisseur', () {
      final ZFailure m = zChatFailureFromWire(<String, dynamic>{
        'code': 'CONTENT_FILTERED',
        'message': 'refuse',
      });
      expect(m, isA<ZChatModerationFailure>());
      expect((m as ZChatModerationFailure).code, 'CONTENT_FILTERED',
          reason: 'le code BRUT est conservé, pas la forme canonique');

      final ZFailure cut = zChatFailureFromWire(<String, dynamic>{
        'code': 'STREAM_INTERRUPTED',
        'request_id': 'r1',
      });
      expect(cut, isA<ZChatStreamInterruptedFailure>());
      expect((cut as ZChatStreamInterruptedFailure).code, 'STREAM_INTERRUPTED');
    });

    test('alias SCREAMING_SNAKE du fil de lex : lus, jamais réémis', () {
      expect(
        zChatFailureFromWire(<String, dynamic>{'code': 'QUOTA_EXCEEDED'}),
        isA<ZQuotaExceededFailure>(),
      );
      expect(
        zChatFailureFromWire(<String, dynamic>{
          'code': 'CONTEXT_LENGTH_EXCEEDED',
        }),
        isA<ZChatContextLimitFailure>(),
      );
    });

    test('entrée illisible ⇒ repli typé, ne lève jamais (AD-10)', () {
      for (final Object? raw in <Object?>[null, 'texte', 42, <String, dynamic>{}]) {
        final ZFailure f = zChatFailureFromWire(raw);
        expect(f, isA<ZServerFailure>());
        expect(f.message, 'chat request failed');
      }
    });

    test('les quatre familles sont des FRÈRES de ZFailure (hiérarchie plate)',
        () {
      const ZFailure moderation = ZChatModerationFailure('m');
      const ZFailure ctx = ZChatContextLimitFailure('c');
      const ZFailure cut = ZChatStreamInterruptedFailure('s', requestId: 'r');
      const ZFailure quota = ZQuotaExceededFailure('q');
      for (final ZFailure f in <ZFailure>[moderation, ctx, cut, quota]) {
        expect(f, isA<ZFailure>());
        expect(f, isNot(isA<ZDomainFailure>()));
        expect(f, isNot(isA<ZServerFailure>()));
      }
      expect(moderation, isNot(isA<ZChatContextLimitFailure>()));
      expect(ctx, isNot(isA<ZChatStreamInterruptedFailure>()));
    });

    test('égalité PAR VALEUR des trois nouvelles familles', () {
      expect(
        const ZChatModerationFailure('m', category: 'c'),
        const ZChatModerationFailure('m', category: 'c'),
      );
      expect(
        const ZChatModerationFailure('m', category: 'c'),
        isNot(const ZChatModerationFailure('m', category: 'd')),
      );
      expect(
        const ZChatContextLimitFailure('c', tokenLimit: 1),
        const ZChatContextLimitFailure('c', tokenLimit: 1),
      );
      expect(
        const ZChatStreamInterruptedFailure('s', requestId: 'a'),
        isNot(const ZChatStreamInterruptedFailure('s', requestId: 'b')),
      );
    });
  });
}
