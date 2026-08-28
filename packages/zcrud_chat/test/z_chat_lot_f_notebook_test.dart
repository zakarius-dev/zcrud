// Lot F — `ZChatNotebookController` : occupation par tranche, verbes dérivés
// du registre, génération par la séquence du kernel, fil persisté, dérivation
// déclaration → rendu.
//
// Gardes DÉJÀ existantes, citées et non doublonnées :
// * `z_chat_structure_guard_test.dart` G-CH2 — un SEUL site `prepare`/
//   `execute` : les verbes d'artefact passent par `runAction`, ce fichier
//   n'en ouvre pas un second ;
// * `z_chat_structure_guard_test.dart` G-CH3 — aucun jeton d'INSTANCE : les
//   jetons de génération d'artefact sont indexés par couple ;
// * `z_chat_cr71_notebook_test.dart` — la vue notebook sans artefact rend le
//   même arbre que la conversation (l'hôte passif) ;
// * kernel `z_chat_notebook_*_test.dart` — la séquence de génération démarque
//   sur chaque chemin, `delete` emporte toutes les représentations.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const String _kMindmap = 'mindmap';
const String _kSummary = 'summary';

/// Port d'état PILOTÉ : existence par couple, journal des lectures, échec ou
/// exception à la demande.
class _StatePort implements ZChatArtifactStatePort {
  final Map<(String, String), ZChatArtifactExistence> existence =
      <(String, String), ZChatArtifactExistence>{};
  final List<(String, String)> reads = <(String, String)>[];
  ZFailure? failWith;
  Object? throwWith;

  @override
  Future<ZResult<ZChatArtifactExistence>> existenceOf({
    required String messageId,
    required String artifactKey,
  }) async {
    reads.add((messageId, artifactKey));
    final Object? boom = throwWith;
    if (boom != null) throw boom;
    final ZFailure? f = failWith;
    if (f != null) return Left<ZFailure, ZChatArtifactExistence>(f);
    return Right<ZFailure, ZChatArtifactExistence>(
      existence[(messageId, artifactKey)] ?? ZChatArtifactExistence.absent,
    );
  }
}

/// Port de génération PILOTÉ : chaque appel rend un `Completer` que le test
/// résout ; peut lever.
class _GenPort implements ZChatArtifactGenerationPort {
  final List<({ZChatArtifactGenerationRequest request, ZChatRequestToken token})>
      calls = <({ZChatArtifactGenerationRequest request, ZChatRequestToken token})>[];
  final List<Completer<ZResult<ZChatArtifactContent>>> pending =
      <Completer<ZResult<ZChatArtifactContent>>>[];
  Object? throwWith;

  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    calls.add((request: request, token: token));
    final Object? boom = throwWith;
    if (boom != null) throw boom;
    final Completer<ZResult<ZChatArtifactContent>> c =
        Completer<ZResult<ZChatArtifactContent>>();
    pending.add(c);
    return c.future;
  }

  void complete(String data) => pending.last.complete(
        Right<ZFailure, ZChatArtifactContent>(ZChatArtifactContent(data)),
      );

  void fail(ZFailure f) =>
      pending.last.complete(Left<ZFailure, ZChatArtifactContent>(f));
}

/// Transcript dont les ÉCRITURES échouent — la lecture reste celle de la
/// référence en mémoire.
class _FailingTranscript implements ZChatTranscriptPort {
  _FailingTranscript(this.inner);
  final ZChatInMemoryTranscript inner;
  int appends = 0;

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) =>
      inner.messages(conversationId);

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) async {
    appends++;
    return const Left<ZFailure, ZChatMessage>(ZCacheFailure('disk full'));
  }

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) async =>
      const Left<ZFailure, ZChatMessage>(ZCacheFailure('disk full'));
}

ZChatArtifactRegistry _registry() => ZChatArtifactRegistry(<ZChatArtifactDeclaration>[
      ZChatArtifactDeclaration(
        key: _kMindmap,
        iconKey: 'icon.mindmap',
        labelToken: 'label.mindmap',
        accentToken: 'accent.mindmap',
        hasCount: true,
        verbs: <ZChatArtifactVerb>[
          ZChatArtifactVerb.create(labelToken: 'verb.create'),
          ZChatArtifactVerb.open(labelToken: 'verb.open'),
          ZChatArtifactVerb.regenerate(labelToken: 'verb.regenerate'),
          ZChatArtifactVerb.edit(labelToken: 'verb.edit'),
          ZChatArtifactVerb.delete(
            labelToken: 'verb.delete',
            confirmToken: 'confirm.delete',
          ),
        ],
      ),
      ZChatArtifactDeclaration(
        key: _kSummary,
        verbs: <ZChatArtifactVerb>[
          ZChatArtifactVerb.create(),
          ZChatArtifactVerb.open(),
          ZChatArtifactVerb.delete(),
        ],
      ),
    ]);

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

typedef _Rig = ({
  ZChatNotebookController nb,
  ZChatInMemoryTranscript transcript,
  ZChatInMemoryArtifactStore store,
  _StatePort state,
  _GenPort gen,
  FakeStreamPort stream,
  List<ZChatArtifactVerbAction> asked,
});

/// Contrôleur câblé sur un fil « q1 → r1 », déjà amorcé.
Future<_Rig> _rig({
  bool withStatePort = true,
  bool withGenPort = true,
  bool? confirmAnswer,
  ZChatActionExecutor? executor,
  ZChatTranscriptPort? transcript,
  bool readOnly = false,
  ZChatLiveLabels labels = ZChatLiveLabels.none,
  bool pump = true,
}) async {
  final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
  // Le fil en mémoire tient des flux ouverts : ils sont fermés à la fin de
  // chaque test, sinon le harnais s'effondre à l'arrêt.
  addTearDown(inner.dispose);
  await inner.append(_user('q1', 'question une'));
  await inner.append(_assistant('r1', 'réponse une'));
  final ZChatInMemoryArtifactStore store = ZChatInMemoryArtifactStore();
  final _StatePort state = _StatePort();
  final _GenPort gen = _GenPort();
  final FakeStreamPort stream = FakeStreamPort();
  final List<ZChatArtifactVerbAction> asked = <ZChatArtifactVerbAction>[];
  final ZChatNotebookController nb = ZChatNotebookController(
    streamPort: stream,
    transcript: transcript ?? inner,
    conversationId: 'c1',
    registry: _registry(),
    generationPort: withGenPort ? gen : null,
    store: store,
    statePort: withStatePort ? state : null,
    actionExecutor: executor ?? const ZChatUnsupportedActionExecutor(),
    confirmArtifactVerb: confirmAnswer == null
        ? zChatConfirmArtifactWithoutDialog
        : (ZChatArtifactVerbAction verb) async {
            asked.add(verb);
            return confirmAnswer;
          },
    readOnly: readOnly,
    liveLabels: labels,
  );
  // Sous `testWidgets` (zone FakeAsync), `pumpEventQueue` n'avance jamais :
  // c'est `tester.pump()` qui draine. Les tests unitaires drainent ici.
  if (pump) await pumpEventQueue();
  return (
    nb: nb,
    transcript: inner,
    store: store,
    state: state,
    gen: gen,
    stream: stream,
    asked: asked,
  );
}

/// Compteur de notifications, lisible après coup.
class _Tally {
  _Tally(Listenable l) {
    l.addListener(() => count++);
  }
  int count = 0;
}

void main() {
  group('🔴 F1 — occupation par TRANCHE, jamais le fil', () {
    test('marquer un couple ne notifie QUE sa tranche — ni le fil, ni le '
        'contrôleur, ni la tranche voisine', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      final ValueListenable<ZChatArtifactStatus> mindmap =
          r.nb.statusOf('r1', _kMindmap);
      final ValueListenable<ZChatArtifactStatus> summary =
          r.nb.statusOf('r1', _kSummary);
      await pumpEventQueue();
      final _Tally onMindmap = _Tally(mindmap);
      final _Tally onSummary = _Tally(summary);
      final _Tally onThread = _Tally(r.nb.chat.messages);
      final _Tally onController = _Tally(r.nb);
      final _Tally onChat = _Tally(r.nb.chat);

      r.nb.markArtifact('r1', _kMindmap, busy: true);
      expect(mindmap.value, ZChatArtifactStatus.inProgress);
      expect(onMindmap.count, 1);
      expect(onSummary.count, 0, reason: '🔴 la tranche voisine a été notifiée');
      expect(onThread.count, 0, reason: '🔴 le fil a été notifié (AD-2)');
      expect(onController.count, 0);
      expect(onChat.count, 0, reason: '🔴 `attach` ou un notifyListeners global');

      r.nb.markArtifact('r1', _kMindmap, busy: false);
      expect(mindmap.value, ZChatArtifactStatus.absent);
      expect(onMindmap.count, 2);
      // Démarquer un couple déjà démarqué ne notifie RIEN (un flux appelle
      // la fin plusieurs fois).
      r.nb.markArtifact('r1', _kMindmap, busy: false);
      expect(onMindmap.count, 2);
      expect(onSummary.count, 0);
    });

    test('la tranche est une instance STABLE par couple', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      expect(
        identical(r.nb.statusOf('r1', _kMindmap), r.nb.statusOf('r1', _kMindmap)),
        isTrue,
      );
      expect(
        identical(r.nb.statusOf('r1', _kMindmap), r.nb.statusOf('r1', _kSummary)),
        isFalse,
      );
    });

    test('occupation > existence : un artefact PRÉSENT marqué occupé est '
        '« en cours », et retrouve son compte au démarquage', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kMindmap)] =
          const ZChatArtifactExistence.found(count: 7);
      final ValueListenable<ZChatArtifactStatus> s = r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      expect(s.value, const ZChatArtifactStatus.present(count: 7));
      expect(s.value.badgeCount, 7);
      r.nb.markArtifact('r1', _kMindmap, busy: true);
      expect(s.value, ZChatArtifactStatus.inProgress);
      expect(s.value.badgeCount, isNull);
      r.nb.markArtifact('r1', _kMindmap, busy: false);
      expect(s.value, const ZChatArtifactStatus.present(count: 7));
    });

    test('sans port d\'état, l\'existence est lue dans le STOCKAGE (défaut '
        'inerte) ; un port qui LÈVE rend absent, sans remonter', () async {
      final _Rig r = await _rig(withStatePort: false);
      addTearDown(r.nb.dispose);
      await r.store.write(messageId: 'r1', artifactKey: _kSummary, content: 'x');
      final ValueListenable<ZChatArtifactStatus> s = r.nb.statusOf('r1', _kSummary);
      await pumpEventQueue();
      expect(s.value.isPresent, isTrue);
      expect(r.nb.statusOf('r1', _kMindmap).value, ZChatArtifactStatus.absent);

      final _Rig t = await _rig();
      addTearDown(t.nb.dispose);
      t.state.throwWith = StateError('boom');
      t.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      final ValueListenable<ZChatArtifactStatus> u = t.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      expect(u.value, ZChatArtifactStatus.absent);
    });
  });

  group('🔴 F1 — génération par la SÉQUENCE du kernel, échec PUBLIÉ', () {
    test('un `Left` du port est publié sur la tranche d\'échec et '
        'l\'occupation RETOMBE', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      final ValueListenable<ZChatArtifactStatus> s = r.nb.statusOf('r1', _kMindmap);
      final ValueListenable<ZFailure?> f = r.nb.failureOf('r1', _kMindmap);
      await pumpEventQueue();
      final List<ZChatArtifactStatus> seen = <ZChatArtifactStatus>[];
      s.addListener(() => seen.add(s.value));

      final Future<ZResult<ZChatActionOutcome>> run = r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      );
      await pumpEventQueue();
      expect(r.gen.calls, hasLength(1));
      expect(r.gen.calls.single.request.notes, 'réponse une');
      expect(r.gen.calls.single.request.subject, 'question une',
          reason: 'le sujet est la question appariée');
      expect(s.value, ZChatArtifactStatus.inProgress);

      r.gen.fail(const ZDomainFailure('model down'));
      final ZResult<ZChatActionOutcome> out = await run;
      expect(out.isLeft(), isTrue);
      expect(f.value, const ZDomainFailure('model down'),
          reason: '🔴 l\'échec a été avalé : l\'utilisateur n\'apprend rien');
      expect(s.value, ZChatArtifactStatus.absent,
          reason: '🔴 l\'indicateur reste allumé');
      expect(seen, <ZChatArtifactStatus>[
        ZChatArtifactStatus.inProgress,
        ZChatArtifactStatus.absent,
      ]);
      expect(
        await r.store.read(messageId: 'r1', artifactKey: _kMindmap),
        const Right<ZFailure, String?>(null),
        reason: 'rien n\'est écrit sur un échec',
      );
    });

    test('un port qui LÈVE démarque quand même, et l\'exception devient un '
        'échec typé publié', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.gen.throwWith = StateError('kaboom');
      final ValueListenable<ZChatArtifactStatus> s = r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      final List<ZChatArtifactStatus> seen = <ZChatArtifactStatus>[];
      s.addListener(() => seen.add(s.value));
      await r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      );
      expect(seen.first, ZChatArtifactStatus.inProgress,
          reason: 'l\'occupation a bien été posée avant l\'appel');
      expect(s.value, ZChatArtifactStatus.absent);
      expect(r.nb.failureOf('r1', _kMindmap).value,
          isA<ZChatArtifactGenerationFailure>());
    });

    test('un `Right` est ÉCRIT, la tranche relue (présent + compte), '
        'l\'annonce faite avec le libellé de l\'hôte', () async {
      final _Rig r = await _rig(
        labels: ZChatLiveLabels(
          artifactGenerationStarted: (String k) => 'start:$k',
          artifactGenerationCompleted: (String k) => 'done:$k',
        ),
      );
      addTearDown(r.nb.dispose);
      final ValueListenable<ZChatArtifactStatus> s = r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      final List<String> said = <String>[];
      r.nb.liveAnnouncement.addListener(() {
        if (r.nb.liveAnnouncement.value.isNotEmpty) {
          said.add(r.nb.liveAnnouncement.value);
        }
      });
      final Future<ZResult<ZChatActionOutcome>> run = r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      );
      await pumpEventQueue();
      // Le port d'état reflète l'écriture : c'est l'hôte qui compte.
      r.state.existence[('r1', _kMindmap)] =
          const ZChatArtifactExistence.found(count: 3);
      r.gen.complete('{"nodes":3}');
      final ZResult<ZChatActionOutcome> out = await run;
      await pumpEventQueue();
      expect(out.isRight(), isTrue);
      expect(
        await r.store.read(messageId: 'r1', artifactKey: _kMindmap),
        const Right<ZFailure, String?>('{"nodes":3}'),
      );
      expect(s.value, const ZChatArtifactStatus.present(count: 3));
      expect(said, <String>['start:mindmap', 'done:mindmap']);
    });

    test('sans port de génération, « créer » est refusé par '
        '`ZUnsupportedOperationFailure`, jamais levé', () async {
      final _Rig r = await _rig(withGenPort: false);
      addTearDown(r.nb.dispose);
      await r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      );
      expect(r.nb.failureOf('r1', _kMindmap).value,
          isA<ZUnsupportedOperationFailure>());
    });

    test('`cancelArtifact` annule le jeton de CE couple, et lui seul', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kSummary)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('r1', _kSummary);
      await pumpEventQueue();
      unawaited(r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      ));
      await pumpEventQueue();
      final ZChatRequestToken token = r.gen.calls.single.token;
      r.nb.cancelArtifact(messageId: 'r1', artifactKey: _kSummary);
      expect(token.isCancelled, isFalse);
      r.nb.cancelArtifact(messageId: 'r1', artifactKey: _kMindmap);
      expect(token.isCancelled, isTrue);
      r.gen.fail(const ZDomainFailure('cancelled'));
      await pumpEventQueue();
    });
  });

  group('🔴 F1 — verbes : registre, rôle, lecture seule', () {
    test('`role == user` ⇒ AUCUN verbe, même si l\'artefact est présent', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.state.existence[('q1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('q1', _kMindmap);
      r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      expect(r.nb.statusOf('q1', _kMindmap).value.isPresent, isTrue,
          reason: 'l\'état existe bien — c\'est le RÔLE qui retire les verbes');
      expect(r.nb.verbsFor('q1', _kMindmap), isEmpty);
      expect(
        r.nb.verbsFor('r1', _kMindmap).map((ZChatArtifactVerb v) => v.key),
        <String>['open', 'regenerate', 'edit', 'delete'],
      );
      expect(r.nb.verbsFor('absent', _kMindmap), isEmpty);
      // Et un verbe non offert est REFUSÉ à l'exécution, refus publié.
      await r.nb.runArtifactVerb(
        messageId: 'q1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbOpen,
      );
      expect(r.nb.failureOf('q1', _kMindmap).value, isA<ZDomainFailure>());
      expect(r.nb.chat.lastFailure.value, isNull,
          reason: 'le refus n\'a pas atteint `runAction`');
    });

    test('`readOnly` retire les verbes d\'ÉDITION et garde « ouvrir » ; '
        'absent + lecture seule ⇒ rien ; la tranche signale', () async {
      final _Rig r = await _rig(readOnly: true);
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('r1', _kMindmap);
      r.nb.statusOf('r1', _kSummary);
      await pumpEventQueue();
      expect(
        r.nb.verbsFor('r1', _kMindmap).map((ZChatArtifactVerb v) => v.key),
        <String>['open'],
      );
      expect(r.nb.verbsFor('r1', _kSummary), isEmpty);
      final _Tally t = _Tally(r.nb.readOnly);
      r.nb.setReadOnly(false);
      expect(t.count, 1);
      expect(
        r.nb.verbsFor('r1', _kSummary).map((ZChatArtifactVerb v) => v.key),
        <String>['create'],
      );
      expect(r.nb.verbsFor('r1', _kMindmap), hasLength(4));
    });

    test('en cours ⇒ aucun verbe', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      r.nb.markArtifact('r1', _kMindmap, busy: true);
      expect(r.nb.verbsFor('r1', _kMindmap), isEmpty);
      r.nb.markArtifact('r1', _kMindmap, busy: false);
    });
  });

  group('🔴 F1 — confirmation, suppression, verbes de l\'hôte', () {
    test('« supprimer » avec le défaut `zChatConfirmArtifactWithoutDialog` '
        'est REFUSÉ : rien n\'est détruit, le refus est publié', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      await r.store.write(messageId: 'r1', artifactKey: _kMindmap, content: 'm');
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      final ZResult<ZChatActionOutcome> out = await r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbDelete,
      );
      expect(out.fold((ZFailure f) => f, (_) => null),
          isA<ZChatActionNotConfirmedFailure>());
      expect(r.nb.failureOf('r1', _kMindmap).value,
          isA<ZChatActionNotConfirmedFailure>());
      expect(
        await r.store.read(messageId: 'r1', artifactKey: _kMindmap),
        const Right<ZFailure, String?>('m'),
      );
    });

    test('le seam de l\'hôte reçoit le verbe d\'artefact avec son jeton de '
        'confirmation ; `true` ⇒ `delete` du stockage, tranche relue',
        () async {
      final _Rig r = await _rig(confirmAnswer: true);
      addTearDown(r.nb.dispose);
      await r.store.write(messageId: 'r1', artifactKey: _kMindmap, content: 'm');
      await r.store.writeRepresentation(
        messageId: 'r1',
        artifactKey: _kMindmap,
        content: 'pair',
        representation: 'legacy_pair',
      );
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      final ValueListenable<ZChatArtifactStatus> s = r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      expect(s.value.isPresent, isTrue);

      final ZResult<ZChatActionOutcome> out = await r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbDelete,
      );
      expect(out.isRight(), isTrue);
      expect(r.asked, hasLength(1));
      expect(r.asked.single.confirmToken, 'confirm.delete');
      expect(r.asked.single.verbKey, 'delete');
      expect(r.asked.single.messageId, 'r1');
      expect(
        await r.store.read(messageId: 'r1', artifactKey: _kMindmap),
        const Right<ZFailure, String?>(null),
        reason: '🔴 une représentation a survécu : l\'artefact réapparaîtra',
      );
      // Le port d'état est relu : il dit désormais absent.
      r.state.existence.remove(('r1', _kMindmap));
      await r.nb.refreshArtifact(messageId: 'r1', artifactKey: _kMindmap);
      expect(s.value, ZChatArtifactStatus.absent);
    });

    test('« ouvrir » n\'est pas un verbe du socle : l\'exécuteur par défaut '
        'le refuse NOMMÉMENT, et le refus est publié sur la tranche', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      await r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbOpen,
      );
      final ZFailure? f = r.nb.failureOf('r1', _kMindmap).value;
      expect(f, isA<ZUnsupportedOperationFailure>());
      // Le refus vient du RÉPARTITEUR (planification par l'exécuteur de
      // l'hôte) : aucun second site d'appel ici.
      expect((f! as ZUnsupportedOperationFailure).operation, 'estimateImpact');
      expect(r.nb.chat.lastFailure.value, same(f));
    });

    test('un exécuteur d\'hôte reçoit « ouvrir » tel quel (verbe + charge), '
        'et son succès n\'est pas un échec', () async {
      final SpyExecutor spy = SpyExecutor();
      final _Rig r = await _rig(executor: spy);
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      final ZResult<ZChatActionOutcome> out = await r.nb.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbOpen,
      );
      expect(out.isRight(), isTrue);
      expect(spy.calls['executeCustom'], 1);
      expect(spy.calls['estimateImpact'], 1,
          reason: 'planifié par le répartiteur, comme tout verbe');
      expect(r.nb.failureOf('r1', _kMindmap).value, isNull);
    });
  });

  group('🔴 F1 — le FIL : une seule amorce, un seul abonnement', () {
    test('`attach` est appelé UNE fois sur deux instantanés ; le second ne '
        'relit que les tranches du message qui a CHANGÉ', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      // `attach` est le SEUL déclencheur de `notifyListeners` du contrôleur
      // de conversation : compter ses notifications compte les `attach`.
      final _Tally attaches = _Tally(r.nb.chat);
      expect(r.nb.chat.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1']);
      await r.transcript.append(_assistant('r2', 'réponse deux'));
      await pumpEventQueue();
      expect(attaches.count, 0, reason: '🔴 `attach` rebranché sur un instantané');

      r.nb.statusOf('r1', _kMindmap);
      r.nb.statusOf('r2', _kMindmap);
      r.nb.statusOf('r2', _kSummary);
      await pumpEventQueue();
      r.state.reads.clear();
      await r.transcript.update(_assistant('r2', 'réponse deux, éditée'));
      await pumpEventQueue();
      expect(r.state.reads.toSet(), <(String, String)>{('r2', _kMindmap), ('r2', _kSummary)},
          reason: '🔴 une émission qui ne change que r2 a relu d\'autres tranches');
      expect(attaches.count, 0);
      // Un instantané identique ne relit rien.
      r.state.reads.clear();
      await r.transcript.update(_assistant('r2', 'réponse deux, éditée'));
      await pumpEventQueue();
      expect(r.state.reads, isEmpty);
    });

    test('`dispose` ANNULE l\'abonnement (la source voit le `cancel`), et une '
        'émission ultérieure ne lit plus rien', () async {
      bool cancelled = false;
      final StreamController<List<ZChatMessage>> source =
          StreamController<List<ZChatMessage>>(onCancel: () => cancelled = true);
      addTearDown(source.close);
      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      final _StatePort state = _StatePort();
      final ZChatNotebookController nb = ZChatNotebookController(
        streamPort: FakeStreamPort(),
        transcript: _BrokenRead(inner, source.stream),
        conversationId: 'c1',
        registry: _registry(),
        statePort: state,
      );
      source.add(<ZChatMessage>[_assistant('r1', 'réponse une')]);
      await pumpEventQueue();
      nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      expect(cancelled, isFalse);
      state.reads.clear();
      nb.dispose();
      await pumpEventQueue();
      expect(cancelled, isTrue, reason: '🔴 l\'abonnement survit au dispose');
      source.add(<ZChatMessage>[_assistant('r1', 'changée après dispose')]);
      await pumpEventQueue();
      expect(state.reads, isEmpty);
    });

    test('un fil illisible ouvre un fil VIERGE (amorce sur la liste vide)', () async {
      final StreamController<List<ZChatMessage>> broken =
          StreamController<List<ZChatMessage>>();
      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      final ZChatNotebookController nb = ZChatNotebookController(
        streamPort: FakeStreamPort(),
        transcript: _BrokenRead(inner, broken.stream),
        conversationId: 'c1',
      );
      addTearDown(nb.dispose);
      final _Tally attaches = _Tally(nb.chat);
      broken.addError(StateError('firestore down'));
      await broken.close();
      await pumpEventQueue();
      expect(attaches.count, 1);
      expect(nb.chat.messages.value, isEmpty);
    });
  });

  group('🔴 F1 — le FIL : chaque tour est ÉCRIT, chaque `Left` publié', () {
    test('un tour écrit la question puis la réponse finale, dans cet ordre, '
        'sans ré-écrire l\'historique amorcé', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.nb.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = r.nb.chat.send();
      await pumpEventQueue();
      r.stream.last.add(tok('réponse '));
      r.stream.last.add(tok('deux'));
      r.stream.last.add(const Right<ZFailure, ZChatStreamEvent>(
        ZChatDoneEvent(messageId: 'a2', conversationId: 'c1'),
      ));
      await r.stream.closeAll();
      await sending;
      await pumpEventQueue();

      final List<ZChatMessage> stored = await r.transcript.messages('c1').first;
      expect(stored.map((ZChatMessage m) => m.id), <String>['q1', 'r1', 'c1:0', 'a2']);
      expect(stored[2].role, ZChatRole.user);
      expect(stored[2].content, 'question deux');
      expect(stored[3].role, ZChatRole.assistant);
      expect(stored[3].content, 'réponse deux');
      expect(r.nb.lastFailure.value, isNull);
    });

    test('un `Left` d\'écriture est PUBLIÉ dans `lastFailure`, le fil local '
        'reste intact', () async {
      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      await inner.append(_user('q1', 'question une'));
      final _FailingTranscript failing = _FailingTranscript(inner);
      final _Rig r = await _rig(transcript: failing);
      addTearDown(r.nb.dispose);
      r.nb.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = r.nb.chat.send();
      await pumpEventQueue();
      expect(failing.appends, 1, reason: 'la question est écrite à l\'envoi');
      expect(r.nb.lastFailure.value, const ZCacheFailure('disk full'));
      r.stream.last.add(tok('ok'));
      r.stream.last.add(const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent()));
      await r.stream.closeAll();
      await sending;
      await pumpEventQueue();
      expect(failing.appends, 2);
      expect(r.nb.chat.messages.value, hasLength(3),
          reason: 'l\'échec d\'écriture ne coûte rien au fil affiché');
    });
  });

  group('🔴 F2 — dérivation déclaration → rendu : RIEN n\'est inventé', () {
    test('un jeton non résolu ⇒ aucun glyphe, aucune couleur, libellé vide', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      final ZChatArtifactSpec bare = zChatArtifactSpecOf(
        r.nb.registry.declarationOf(_kMindmap)!,
        controller: r.nb,
      );
      expect(bare.icon, isNull);
      expect(bare.accent, isNull);
      expect(bare.label, '');
      expect(bare.actions.map((ZChatArtifactAction a) => a.label), everyElement(''));
      expect(bare.actions.map((ZChatArtifactAction a) => a.icon), everyElement(isNull));

      // Un résolveur PARTIEL ne comble pas ses trous.
      final ZChatArtifactSpec partial = zChatArtifactSpecOf(
        r.nb.registry.declarationOf(_kMindmap)!,
        controller: r.nb,
        resolvers: ZChatArtifactResolvers(
          icon: (String k) => k == 'icon.mindmap' ? const IconData(0xe900) : null,
          label: (String k) => k == 'verb.open' ? 'Ouvrir' : null,
          accent: (String k) => throw StateError('no palette'),
        ),
      );
      expect(partial.icon, const IconData(0xe900));
      expect(partial.label, '', reason: 'label.mindmap n\'est pas résolu');
      expect(partial.accent, isNull, reason: 'un résolveur qui lève vaut null');
      expect(partial.actions[1].label, 'Ouvrir');
      expect(partial.actions[0].label, '');
      // Le verbe dérivé N'EST PAS destructeur pour la barre : la question est
      // posée UNE fois, par le contrôleur.
      expect(partial.actions.map((ZChatArtifactAction a) => a.destructive),
          everyElement(isFalse));
      expect(partial.count, isNotNull, reason: 'hasCount ⇒ lecture de compte');
      expect(
        zChatArtifactSpecOf(r.nb.registry.declarationOf(_kSummary)!, controller: r.nb)
            .count,
        isNull,
      );
    });

    test('les lectures d\'état et la visibilité des verbes sont celles du '
        'contrôleur (rôle, état, lecture seule)', () async {
      final _Rig r = await _rig();
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found(count: 2);
      final ZChatArtifactSpec spec = zChatArtifactSpecOf(
        r.nb.registry.declarationOf(_kMindmap)!,
        controller: r.nb,
      );
      final ZChatMessage r1 = r.nb.messageById('r1')!;
      final ZChatMessage q1 = r.nb.messageById('q1')!;
      // Première lecture : la tranche vient d'être créée, relue ensuite.
      spec.isPresent(r1);
      await pumpEventQueue();
      expect(spec.isPresent(r1), isTrue);
      expect(spec.countOf(r1), 2);
      expect(spec.isBusy(r1), isFalse);
      expect(spec.visibleActions(r1, present: true), hasLength(4));
      expect(spec.visibleActions(q1, present: true), isEmpty,
          reason: '🔴 un verbe offert sur un message utilisateur');
      r.nb.setReadOnly(true);
      expect(spec.visibleActions(r1, present: true), hasLength(1));
      r.nb.markArtifact('r1', _kMindmap, busy: true);
      expect(spec.isBusy(r1), isTrue);
      expect(spec.visibleActions(r1, present: true), isEmpty);
      r.nb.markArtifact('r1', _kMindmap, busy: false);
    });

    test('la sélection d\'un verbe dérivé passe par `runArtifactVerb`', () async {
      final SpyExecutor spy = SpyExecutor();
      final _Rig r = await _rig(executor: spy);
      addTearDown(r.nb.dispose);
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found();
      r.nb.statusOf('r1', _kMindmap);
      await pumpEventQueue();
      final ZChatArtifactSpec spec = zChatArtifactSpecOf(
        r.nb.registry.declarationOf(_kMindmap)!,
        controller: r.nb,
      );
      spec.actions[1].onSelected(r.nb.messageById('r1')!); // open
      await pumpEventQueue();
      expect(spy.calls['executeCustom'], 1);
    });
  });

  group('🔴 F4 — le créneau par tranche, et la vue INCHANGÉE', () {
    testWidgets('la barre d\'un message se reconstruit sur SA tranche, sans '
        '`setState`, et un message sans artefact ne change pas', (WidgetTester tester) async {
      final _Rig r = await _rig(pump: false);
      addTearDown(r.nb.dispose);
      await tester.pump();
      const IconData glyph = IconData(0xe901);
      await tester.pumpWidget(harness(
        ZChatNotebookView(
          controller: r.nb.chat,
          actionsBuilder: zChatNotebookArtifactsSlot(
            controller: r.nb,
            resolvers: ZChatArtifactResolvers(
              icon: (String k) => k == 'icon.mindmap' ? glyph : null,
              label: (String k) => k,
            ),
          ),
        ),
      ));
      await tester.pump();
      // La rangée est montée par message ; c'est SON contenu qui suit les
      // tranches : la question (rôle utilisateur) n'offre aucun verbe et
      // aucun état ⇒ aucun glyphe ; la réponse, absente, offre « créer » ⇒
      // un seul glyphe dans tout l'arbre.
      expect(find.byType(ZChatArtifactBar), findsNWidgets(2));
      final Finder icons = find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == glyph,
      );
      expect(icons, findsOneWidget,
          reason: '🔴 un glyphe sur la question, ou aucun sur la réponse');
      expect(find.text('4'), findsNothing);
      // L'existence change sur r1 : sa tranche est relue, sa rangée suit —
      // sans `setState` (garde G-CH5), sans rebrancher le fil.
      r.state.existence[('r1', _kMindmap)] = const ZChatArtifactExistence.found(count: 4);
      await r.nb.refreshArtifact(messageId: 'r1', artifactKey: _kMindmap);
      await tester.pump();
      await tester.pump();
      expect(icons, findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: 'la pastille suit la tranche');
    });

    test('ÉTALON — la surface publique de `ZChatNotebookView` est INCHANGÉE : '
        'aucun contrôleur de notebook, aucun paramètre neuf', () {
      final String src = stripped(libFile(
        'lib/src/presentation/view/z_chat_notebook_view.dart',
      )).join('\n');
      expect(src.contains('ZChatNotebookController'), isFalse,
          reason: '🔴 la vue s\'est mise à dépendre du contrôleur de notebook : '
              'un hôte passif changerait de contrat');
      expect(src.contains('z_chat_artifact_binding'), isFalse);
      final RegExp param = RegExp(r'^\s+(?:required\s+)?this\.(\w+)', multiLine: true);
      final Set<String> params = <String>{
        for (final RegExpMatch m in param.allMatches(src)) m.group(1)!,
      };
      expect(params, <String>{
        'controller',
        'actionsBuilder',
        'artifacts',
        'skin',
        'confirmArtifactAction',
        'artifactMenuBuilder',
        'artifactMenuCrossAxisCount',
        // Position du créneau hôte relative à la rangée d'artefacts — un
        // relais vers `ZChatArtifactBar.slot`, pas une dépendance neuve.
        'artifactHostPosition',
        'collapsedMaxHeight',
        'padding',
        'reverse',
        'composer',
      });
    });

    test('ÉTALON — `ZChatArtifactVerbAction` fait l\'aller-retour', () {
      const ZChatArtifactVerbAction v = ZChatArtifactVerbAction(
        messageId: 'm',
        artifactKey: 'k',
        verbKey: 'open',
        confirmToken: 'c',
      );
      expect(v.verb, 'artifact:k:open');
      expect(ZChatArtifactVerbAction.of(v.toAction(destructive: true)), v);
      expect(v.toAction(destructive: true).isDestructive, isTrue);
      expect(v.toAction(destructive: false).isDestructive, isFalse);
      expect(
        ZChatArtifactVerbAction.of(const ZChatCustomAction(
          verb: 'host:export',
          isDestructive: false,
          cascades: false,
        )),
        isNull,
      );
    });
  });
}

/// Transcript dont la LECTURE est un flux fourni par le test (pour simuler
/// une source qui lève avant tout instantané).
class _BrokenRead implements ZChatTranscriptPort {
  _BrokenRead(this.inner, this.source);
  final ZChatInMemoryTranscript inner;
  final Stream<List<ZChatMessage>> source;

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) => source;

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) =>
      inner.append(message);

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) =>
      inner.update(message);
}
