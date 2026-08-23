// Tests comportementaux du vocabulaire et des ports du fil de travail
// (« notebook ») : registre d'artefacts, état dérivé, séquence de génération,
// stockage anti-résurrection, fil lu/écrit, exécuteur par défaut, défauts des
// seams triviaux.
//
// Chaque groupe porte au moins une garde qui rougit PAR ASSERTION si la règle
// qu'il surveille est retirée (campagne R3 rejouée dans le rapport du lot).
import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

ZChatMessage _msg({String? id, ZChatRole role = ZChatRole.assistant}) =>
    ZChatMessage(
      id: id,
      conversationId: 'c1',
      role: role,
      contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'hello')],
    );

class _ImpactOnly extends ZChatUnsupportedActionExecutor {
  const _ImpactOnly();
  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(
    ZChatAction action,
  ) async =>
      const Right<ZFailure, ZChatActionImpact>(ZChatActionImpact());
}

class _ScriptedGeneration implements ZChatArtifactGenerationPort {
  _ScriptedGeneration(this.script);
  final Future<ZResult<ZChatArtifactContent>> Function() script;
  int calls = 0;
  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    calls++;
    return script();
  }
}

class _Marks {
  final List<String> log = <String>[];
  void call(String messageId, String artifactKey, {required bool busy}) =>
      log.add('$messageId/$artifactKey:${busy ? 'on' : 'off'}');
}

void main() {
  group('NB-1 — registre : jetons, verbes dérivés, confirmation', () {
    final ZChatArtifactDeclaration mindmap = ZChatArtifactDeclaration(
      key: 'mindmap',
      iconKey: 'icon.mindmap',
      labelToken: 'artifact.mindmap',
      accentToken: 'accent.mindmap',
      hasCount: true,
      verbs: <ZChatArtifactVerb>[
        ZChatArtifactVerb.create(),
        ZChatArtifactVerb.open(),
        ZChatArtifactVerb.regenerate(),
        ZChatArtifactVerb.edit(),
        ZChatArtifactVerb.delete(confirmToken: 'confirm.mindmap'),
        ZChatArtifactVerb(
          key: kZChatArtifactVerbPrint,
          availability: ZChatArtifactVerbAvailability.whenPresent,
        ),
      ],
    );

    test('absent ⇒ « créer » seul ; lecture seule ⇒ rien', () {
      expect(
        mindmap.verbsFor(ZChatArtifactStatus.absent).map((v) => v.key),
        <String>[kZChatArtifactVerbCreate],
      );
      expect(
        mindmap.verbsFor(ZChatArtifactStatus.absent, readOnly: true),
        isEmpty,
      );
    });

    test('présent ⇒ tous sauf « créer » ; lecture seule garde la LECTURE', () {
      const ZChatArtifactStatus present = ZChatArtifactStatus.present(count: 4);
      expect(
        mindmap.verbsFor(present).map((v) => v.key),
        <String>['open', 'regenerate', 'edit', 'delete', 'print'],
      );
      // Règle : un dossier partagé en lecture ne perd pas son contenu produit.
      expect(
        mindmap.verbsFor(present, readOnly: true).map((v) => v.key),
        <String>['open', 'print'],
      );
    });

    test('en cours ⇒ aucun verbe', () {
      expect(mindmap.verbsFor(ZChatArtifactStatus.inProgress), isEmpty);
      expect(
        mindmap.verbsFor(ZChatArtifactStatus.inProgress, readOnly: true),
        isEmpty,
      );
    });

    test('la confirmation est DÉRIVÉE du verbe destructeur, inconnu ⇒ oui', () {
      expect(mindmap.requiresConfirmation('delete'), isTrue);
      expect(mindmap.requiresConfirmation('open'), isFalse);
      expect(mindmap.requiresConfirmation('nope'), isTrue);
      expect(mindmap.isDestructive, isTrue);
      final ZChatArtifactRegistry reg = ZChatArtifactRegistry([mindmap]);
      expect(reg.requiresConfirmation('mindmap', 'delete'), isTrue);
      expect(reg.requiresConfirmation('unknown', 'open'), isTrue);
      expect(reg.verbsFor('unknown', ZChatArtifactStatus.absent), isEmpty);
      expect(reg.hasCount('mindmap'), isTrue);
      expect(reg.hasCount('unknown'), isFalse);
    });

    test('le registre ordonne par `order` puis déclaration ; dernière clé gagne',
        () {
      final ZChatArtifactRegistry reg = ZChatArtifactRegistry([
        ZChatArtifactDeclaration(key: 'b', order: 2),
        ZChatArtifactDeclaration(key: 'a', order: 1),
        ZChatArtifactDeclaration(key: 'c', order: 1),
        ZChatArtifactDeclaration(key: 'a', order: 3, hasCount: true),
      ]);
      expect(reg.keys, <String>['c', 'b', 'a']);
      expect(reg.declarationOf('a')!.hasCount, isTrue);
      expect(reg.withDeclaration(ZChatArtifactDeclaration(key: 'b', order: 0))
          .keys, <String>['b', 'c', 'a']);
      expect(reg.without('c').keys, <String>['b', 'a']);
    });

    test('aller-retour JSON snake_case, décodage défensif', () {
      final List<Map<String, dynamic>> json =
          ZChatArtifactRegistry([mindmap]).toJson();
      expect(json.single['icon_key'], 'icon.mindmap');
      expect(json.single['has_count'], isTrue);
      expect((json.single['verbs'] as List).length, 6);
      final ZChatArtifactRegistry back = ZChatArtifactRegistry.fromJson(json);
      final ZChatArtifactDeclaration d = back.declarationOf('mindmap')!;
      expect(d.verbs, mindmap.verbs);
      expect(d.verb('delete')!.confirmToken, 'confirm.mindmap');
      expect(d.verb('delete')!.availability,
          ZChatArtifactVerbAvailability.whenPresentEditable);
      // Corrompu : entrées sans clé écartées, disponibilité inconnue ⇒ la plus
      // restrictive, jamais une exception.
      final ZChatArtifactRegistry corrupt = ZChatArtifactRegistry.fromJson(
        <Object?>[
          42,
          <String, dynamic>{'icon_key': 'x'},
          <String, dynamic>{
            'key': 'k',
            'verbs': <Object?>[
              <String, dynamic>{'key': 'v', 'availability': '???'},
              'junk',
            ],
          },
        ],
      );
      expect(corrupt.keys, <String>['k']);
      expect(corrupt.declarationOf('k')!.verbs.single.availability,
          ZChatArtifactVerbAvailability.whenPresentEditable);
      expect(ZChatArtifactPhase.fromJson('bogus'), ZChatArtifactPhase.absent);
    });
  });

  group('NB-2 — état dérivé : l\'OCCUPATION l\'emporte sur l\'EXISTENCE', () {
    test('busy ⇒ inProgress même quand le stockage dit présent avec compte', () {
      final ZChatArtifactStatus s = ZChatArtifactStatus.resolve(
        busy: true,
        existence: const ZChatArtifactExistence.found(count: 12),
      );
      expect(s, ZChatArtifactStatus.inProgress);
      expect(s.count, 0);
      expect(s.badgeCount, isNull);
    });

    test('non busy ⇒ l\'existence décide, compte conservé', () {
      expect(
        ZChatArtifactStatus.resolve(
          busy: false,
          existence: const ZChatArtifactExistence.found(count: 3),
        ),
        const ZChatArtifactStatus.present(count: 3),
      );
      expect(
        ZChatArtifactStatus.resolve(
          busy: false,
          existence: ZChatArtifactExistence.absent,
        ),
        ZChatArtifactStatus.absent,
      );
      expect(ZChatArtifactExistence.counted(0).present, isFalse);
      expect(ZChatArtifactExistence.counted(5).present, isTrue);
      expect(const ZChatArtifactStatus.present(count: -3).count, 0);
      expect(const ZChatArtifactStatus.present().badgeCount, isNull);
      expect(const ZChatArtifactStatus.present(count: 2).badgeCount, 2);
    });

    test('lecture impossible (null / Left) ⇒ absent, sauf occupation', () {
      expect(
        ZChatArtifactStatus.resolve(busy: false, existence: null),
        ZChatArtifactStatus.absent,
      );
      expect(
        ZChatArtifactStatus.fromResult(
          busy: false,
          result: const Left<ZFailure, ZChatArtifactExistence>(
            ZDomainFailure('boom'),
          ),
        ),
        ZChatArtifactStatus.absent,
      );
      expect(
        ZChatArtifactStatus.fromResult(
          busy: true,
          result: const Left<ZFailure, ZChatArtifactExistence>(
            ZDomainFailure('boom'),
          ),
        ),
        ZChatArtifactStatus.inProgress,
      );
    });
  });

  group('NB-3 — séquence de génération', () {
    late ZChatInMemoryArtifactStore store;
    late _Marks marks;
    final ZChatRequestToken token = ZChatRequestToken('r1');
    ZChatArtifactGenerationRequest req({String notes = 'matière'}) =>
        ZChatArtifactGenerationRequest(
          messageId: 'm1',
          artifactKey: 'mindmap',
          notes: notes,
        );

    setUp(() {
      store = ZChatInMemoryArtifactStore();
      marks = _Marks();
    });

    test('refus sur vide : ni appel, ni marquage, échec TYPÉ', () async {
      final _ScriptedGeneration port = _ScriptedGeneration(
        () async => Right<ZFailure, ZChatArtifactContent>(
          ZChatArtifactContent('x'),
        ),
      );
      final ZResult<ZChatArtifactContent> r =
          await ZChatArtifactGenerationRunner(port: port, store: store)
              .run(req(notes: '   '), token: token, mark: marks.call);
      expect(r.isLeft(), isTrue);
      expect(r.fold((f) => f, (_) => null),
          isA<ZChatArtifactEmptyInputFailure>());
      expect(port.calls, 0);
      expect(marks.log, isEmpty);
      // Sujet exigé et vide ⇒ même refus.
      final ZResult<ZChatArtifactContent> r2 =
          await ZChatArtifactGenerationRunner(port: port, store: store).run(
        ZChatArtifactGenerationRequest(
          messageId: 'm1',
          artifactKey: 'k',
          notes: 'ok',
          subjectRequired: true,
        ),
        token: token,
        mark: marks.call,
      );
      expect(r2.fold((f) => f, (_) => null),
          isA<ZChatArtifactEmptyInputFailure>());
      expect(port.calls, 0);
    });

    test('succès : marque, écrit, démarque — dans cet ordre', () async {
      final _ScriptedGeneration port = _ScriptedGeneration(
        () async => Right<ZFailure, ZChatArtifactContent>(
          ZChatArtifactContent('{"nodes":3}'),
        ),
      );
      final ZResult<ZChatArtifactContent> r =
          await ZChatArtifactGenerationRunner(port: port, store: store)
              .run(req(), token: token, mark: marks.call);
      expect(r.isRight(), isTrue);
      expect(marks.log, <String>['m1/mindmap:on', 'm1/mindmap:off']);
      expect(
        (await store.read(messageId: 'm1', artifactKey: 'mindmap'))
            .fold((_) => null, (c) => c),
        '{"nodes":3}',
      );
    });

    test('le port LÈVE ⇒ démarqué quand même, échec remonté typé', () async {
      final _ScriptedGeneration port =
          _ScriptedGeneration(() async => throw StateError('réseau'));
      final ZResult<ZChatArtifactContent> r =
          await ZChatArtifactGenerationRunner(port: port, store: store)
              .run(req(), token: token, mark: marks.call);
      expect(marks.log, <String>['m1/mindmap:on', 'm1/mindmap:off'],
          reason: 'sans démarquage, l\'indicateur reste allumé pour toujours');
      final ZFailure? f = r.fold((f) => f, (_) => null);
      expect(f, isA<ZChatArtifactGenerationFailure>());
      expect((f! as ZChatArtifactGenerationFailure).cause, isA<StateError>());
      expect(
        (await store.read(messageId: 'm1', artifactKey: 'mindmap'))
            .fold((_) => 'left', (c) => c),
        isNull,
      );
    });

    test('le port rend Left ⇒ REMONTÉ tel quel, jamais avalé', () async {
      final _ScriptedGeneration port = _ScriptedGeneration(
        () async => const Left<ZFailure, ZChatArtifactContent>(
          ZQuotaExceededFailure('quota'),
        ),
      );
      final ZResult<ZChatArtifactContent> r =
          await ZChatArtifactGenerationRunner(port: port, store: store)
              .run(req(), token: token, mark: marks.call);
      expect(r.isLeft(), isTrue,
          reason: 'un échec avalé laisse l\'utilisateur attendre en vain');
      expect(r.fold((f) => f, (_) => null), isA<ZQuotaExceededFailure>());
      expect(marks.log.last, 'm1/mindmap:off');
    });

    test('résultat vide ⇒ rien n\'est écrit, l\'ancien contenu survit', () async {
      await store.write(messageId: 'm1', artifactKey: 'mindmap', content: 'old');
      final _ScriptedGeneration port = _ScriptedGeneration(
        () async => Right<ZFailure, ZChatArtifactContent>(
          ZChatArtifactContent('  \n'),
        ),
      );
      final ZResult<ZChatArtifactContent> r =
          await ZChatArtifactGenerationRunner(port: port, store: store)
              .run(req(), token: token, mark: marks.call);
      expect(r.fold((f) => f, (_) => null),
          isA<ZChatArtifactEmptyResultFailure>());
      expect(
        (await store.read(messageId: 'm1', artifactKey: 'mindmap'))
            .fold((_) => null, (c) => c),
        'old',
      );
      expect(marks.log.last, 'm1/mindmap:off');
    });

    test('l\'écriture échoue ou lève ⇒ Left, démarqué', () async {
      int writes = 0;
      final ZResult<int> r = await zChatRunArtifactGeneration<int>(
        messageId: 'm',
        artifactKey: 'k',
        notes: 'n',
        mark: marks.call,
        generate: () async => const Right<ZFailure, int>(7),
        isEmpty: (int v) => v == 0,
        write: (int v) async {
          writes++;
          throw StateError('disque plein');
        },
      );
      expect(writes, 1);
      expect(r.fold((f) => f, (_) => null),
          isA<ZChatArtifactGenerationFailure>());
      expect(marks.log, <String>['m/k:on', 'm/k:off']);
      final ZResult<int> r2 = await zChatRunArtifactGeneration<int>(
        messageId: 'm',
        artifactKey: 'k',
        notes: 'n',
        mark: marks.call,
        generate: () async => const Right<ZFailure, int>(7),
        isEmpty: (int v) => v == 0,
        write: (int v) async =>
            const Left<ZFailure, Unit>(ZCacheFailure('ro')),
      );
      expect(r2.fold((f) => f, (_) => null), isA<ZCacheFailure>());
    });

    test('générique : un artefact structuré (liste) suit la même séquence',
        () async {
      final List<List<String>> written = <List<String>>[];
      final ZResult<List<String>> r =
          await zChatRunArtifactGeneration<List<String>>(
        messageId: 'm',
        artifactKey: 'flashcards',
        notes: 'n',
        mark: marks.call,
        generate: () async =>
            const Right<ZFailure, List<String>>(<String>['q1', 'q2']),
        isEmpty: (List<String> cards) => cards.isEmpty,
        write: (List<String> cards) async {
          written.add(cards);
          return const Right<ZFailure, Unit>(unit);
        },
      );
      expect(r.fold((_) => null, (c) => c), <String>['q1', 'q2']);
      expect(written.single, <String>['q1', 'q2']);
      expect(marks.log, <String>['m/flashcards:on', 'm/flashcards:off']);
    });
  });

  group('NB-4 — stockage : `delete` emporte TOUTES les représentations', () {
    test('après delete, read rend null même avec une paire annexe', () async {
      final ZChatInMemoryArtifactStore store = ZChatInMemoryArtifactStore();
      await store.write(messageId: 'm', artifactKey: 'v', content: 'champ');
      await store.writeRepresentation(
        messageId: 'm',
        artifactKey: 'v',
        content: 'réponse annexe',
        representation: 'legacy_pair',
      );
      expect(store.representationsOf(messageId: 'm', artifactKey: 'v'),
          <String>['primary', 'legacy_pair']);
      final ZResult<Unit> d = await store.delete(messageId: 'm', artifactKey: 'v');
      expect(d.isRight(), isTrue);
      final String? after = (await store.read(messageId: 'm', artifactKey: 'v'))
          .fold((_) => 'left', (c) => c);
      expect(after, isNull,
          reason: 'anti-résurrection : la paire annexe doit partir aussi');
      expect(store.representationsOf(messageId: 'm', artifactKey: 'v'), isEmpty);
      // Idempotent.
      expect((await store.delete(messageId: 'm', artifactKey: 'v')).isRight(),
          isTrue);
    });

    test('le repli de lecture retrouve l\'annexe quand le principal manque',
        () async {
      final ZChatInMemoryArtifactStore store = ZChatInMemoryArtifactStore();
      await store.writeRepresentation(
        messageId: 'm',
        artifactKey: 'v',
        content: 'annexe',
        representation: 'legacy_pair',
      );
      expect(
        (await store.read(messageId: 'm', artifactKey: 'v'))
            .fold((_) => null, (c) => c),
        'annexe',
      );
      expect(
        (await store.writeRepresentation(
          messageId: 'm',
          artifactKey: 'v',
          content: 'x',
          representation: '  ',
        ))
            .isLeft(),
        isTrue,
      );
      expect(
        (await store.read(messageId: 'other', artifactKey: 'v'))
            .fold((_) => 'left', (c) => c),
        isNull,
      );
    });
  });

  group('NB-5 — fil : lecture résiliente, écriture', () {
    test('une erreur AVANT tout instantané ⇒ fil vierge, pas d\'erreur',
        () async {
      final Stream<List<ZChatMessage>> dead =
          Stream<List<ZChatMessage>>.error(StateError('firestore'));
      final List<List<ZChatMessage>> got =
          await zChatTranscriptOrEmpty(dead).toList();
      expect(got, <List<ZChatMessage>>[<ZChatMessage>[]]);
    });

    test('une erreur APRÈS un instantané ⇒ le dernier instantané reste',
        () async {
      final StreamController<List<ZChatMessage>> c =
          StreamController<List<ZChatMessage>>();
      final Future<List<List<ZChatMessage>>> collected =
          zChatTranscriptOrEmpty(c.stream).toList();
      c.add(<ZChatMessage>[_msg(id: 'a')]);
      c.addError(StateError('coupure'));
      await c.close();
      final List<List<ZChatMessage>> got = await collected;
      expect(got.length, 1);
      expect(got.single.single.id, 'a');
    });

    test('en mémoire : instantané à l\'abonnement, append/update publient',
        () async {
      final ZChatInMemoryTranscript t = ZChatInMemoryTranscript();
      final List<List<ZChatMessage>> seen = <List<ZChatMessage>>[];
      final StreamSubscription<List<ZChatMessage>> sub =
          t.messages('c1').listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      final ZChatMessage stored =
          (await t.append(_msg())).fold((_) => throw 'left', (m) => m);
      expect(stored.id, isNotNull);
      final ZChatMessage own = (await t.append(_msg(id: 'mine')))
          .fold((_) => throw 'left', (m) => m);
      expect(own.id, 'mine');
      final ZResult<ZChatMessage> up = await t.update(
        own.copyWith(
          contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'edited')],
        ),
      );
      expect(up.isRight(), isTrue);
      expect((await t.update(_msg())).fold((f) => f, (_) => null),
          isA<ZDomainFailure>());
      expect((await t.update(_msg(id: 'ghost'))).fold((f) => f, (_) => null),
          isA<ZNotFoundFailure>());
      await Future<void>.delayed(Duration.zero);
      expect(seen.first, isEmpty);
      expect(seen.last.length, 2);
      expect((seen.last[1].contentBlocks.single as ZTextBlock).text, 'edited');
      await sub.cancel();
      await t.dispose();
    });
  });

  group('NB-6 — exécuteur par défaut : refus NOMMÉS, sous-classable', () {
    test('huit membres, huit refus distincts nommés', () async {
      const ZChatUnsupportedActionExecutor x = ZChatUnsupportedActionExecutor();
      final List<ZResult<Object>> results = <ZResult<Object>>[
        await x.estimateImpact(const ZChatDeleteAction(messageId: 'm')),
        await x.editAndResend(messageId: 'm', newText: 't'),
        await x.regenerate(messageId: 'm'),
        await x.regenerateWithSettings(
          const ZChatRegenerateAction(messageId: 'm'),
        ),
        await x.softDeleteMessages(messageId: 'm', cascadeToPair: true),
        await x.cancelRequest('r'),
        await x.renderForCopy(messageId: 'm', format: ZChatCopyFormat.markdown),
        await x.executeCustom(const ZChatCustomAction(
          verb: 'v',
          isDestructive: false,
          cascades: false,
        )),
      ];
      final Set<String> operations = <String>{};
      for (final ZResult<Object> r in results) {
        final ZFailure? f = r.fold((f) => f, (_) => null);
        expect(f, isA<ZUnsupportedOperationFailure>());
        operations.add((f! as ZUnsupportedOperationFailure).operation);
      }
      expect(operations, <String>{
        'estimateImpact',
        'editAndResend',
        'regenerate',
        'regenerateWithSettings',
        'softDeleteMessages',
        'cancelRequest',
        'renderForCopy',
        'executeCustom',
      });
    });

    test('une sous-classe ne redéfinit QUE ce qu\'elle sait faire', () async {
      const _ImpactOnly x = _ImpactOnly();
      expect(
        (await x.estimateImpact(const ZChatDeleteAction(messageId: 'm')))
            .isRight(),
        isTrue,
      );
      expect((await x.cancelRequest('r')).isLeft(), isTrue);
      expect(x.refuse<int>('mine', 'why').fold((f) => f, (_) => null),
          const ZUnsupportedOperationFailure('why', operation: 'mine'));
    });
  });

  group('NB-8 — requête d\'artefact : `providerId` TYPÉ, même statut que '
      '`modelId`', () {
    ZChatArtifactGenerationRequest req({String? providerId = 'prov'}) =>
        ZChatArtifactGenerationRequest(
          messageId: 'm1',
          artifactKey: 'mindmap',
          notes: 'n',
          modelId: 'model',
          providerId: providerId,
          extra: const <String, dynamic>{'k': 1},
        );

    test('transporté verbatim, nul par défaut, jamais dans `extra`', () {
      expect(req().providerId, 'prov');
      expect(req(providerId: null).providerId, isNull);
      expect(
        ZChatArtifactGenerationRequest(
          messageId: 'm',
          artifactKey: 'k',
          notes: 'n',
        ).providerId,
        isNull,
      );
      expect(req().extra.containsKey('provider_id'), isFalse);
    });

    test('participe à `==`, `hashCode` et `toString`', () {
      expect(req(), req());
      expect(req().hashCode, req().hashCode);
      expect(req(providerId: 'autre'), isNot(req()));
      expect(req(providerId: null), isNot(req()));
      expect(req().toString(), contains('providerId: prov'));
      expect(req().toString(), contains('modelId: model'));
    });

    test('copyWith : omis conservé, `null` explicite retiré, seul lui bouge',
        () {
      expect(req().copyWith(subject: 'x').providerId, 'prov');
      expect(req().copyWith(providerId: null).providerId, isNull);
      expect(req().copyWith(providerId: 'p2').providerId, 'p2');
      expect(req().copyWith(providerId: 'p2').copyWith(providerId: 'prov'),
          req());
      expect(req().copyWith(), req());
    });
  });

  group('NB-7 — défauts des seams triviaux', () {
    test('le builder copie le brouillon ENTIER — pièces jointes comprises', () {
      final ZChatDraftRequestBuilder build = ZChatDraftRequestBuilder(
        style: ZChatGenerationStyle('ask'),
        conversationId: 'c1',
        subject: 'Douane',
      );
      final ZChatGenerationRequest r = build(const ZChatDraft(
        text: 'question',
        attachmentIds: <String>['doc-1', 'doc-2'],
      ));
      expect(r.notes, 'question');
      expect(r.attachmentIds, <String>['doc-1', 'doc-2'],
          reason: 'un brouillon traduit à la main perd ses pièces jointes');
      expect(r.conversationId, 'c1');
      expect(r.subject, 'Douane');
      expect(r.style.kind, 'ask');
      // Assignable au seam.
      final ZChatGenerationRequest Function(ZChatDraft) seam = build.call;
      expect(seam(const ZChatDraft()).attachmentIds, isEmpty);
    });

    test('identités déterministes `conversationId:n`, une par conversation', () {
      final ZChatSequentialRequestIds ids = ZChatSequentialRequestIds('c1');
      expect(ids(), 'c1:0');
      expect(ids(), 'c1:1');
      expect(ids.next, 2);
      final ZChatSequentialRequestIds other =
          ZChatSequentialRequestIds('c2', start: 10);
      expect(other(), 'c2:10');
      final String Function() seam = ids.call;
      expect(seam(), 'c1:2');
    });

    test('confirm sans dialogue : oui sans question, NON dès qu\'il en faut une',
        () async {
      const ZChatActionDispatcher d = ZChatActionDispatcher(_ImpactOnly());
      final ZChatActionPlan copy =
          (await d.prepare(const ZChatCopyAction(messageId: 'm')))
              .fold((_) => throw 'left', (p) => p);
      expect(copy.requiresConfirmation, isFalse);
      expect(await zChatConfirmWithoutDialog(copy), isTrue);
      final ZChatActionPlan delete =
          (await d.prepare(const ZChatDeleteAction(messageId: 'm')))
              .fold((_) => throw 'left', (p) => p);
      expect(delete.requiresConfirmation, isTrue);
      expect(await zChatConfirmWithoutDialog(delete), isFalse,
          reason: 'le jour où un verbe destructeur apparaît, on ne dit pas oui');
    });
  });
}
