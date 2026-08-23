// Lot G2 — `ZChatNotebookScreen` : l'écran assemblé, couche mince au-dessus
// des briques. Ce que ce fichier prouve :
//
// * le contrôleur de fil de travail est créé UNE fois (deux `build`, un seul
//   abonnement au transcript) et libéré au `dispose` ;
// * un jeton reçu ne reconstruit ni l'écran ni le composer (AD-2) ;
// * ÉCHAPPATOIRE : l'arbre rendu par l'écran avec ses défauts est celui
//   qu'un hôte obtient en assemblant les briques à la main ;
// * sans seam de confirmation, « supprimer » est REFUSÉ et le contenu reste ;
// * `ZUnsupportedOperationFailure` et `ZChatActionNotConfirmedFailure` ne
//   sont JAMAIS présentés au créneau d'échec ; un autre échec l'est ;
// * la région live des artefacts est montée EN PLUS de celle des tours ;
// * lecture seule : composer absent, bascule sans recréer le contrôleur ;
// * hauteur repliée dérivée de l'écran, remplaçable ;
// * outils : catalogue ⇒ badge et feuille projetée ; sans présentateur, le
//   bouton « outils » est absent ;
// * gardes de source : le contrôleur n'est construit que dans `initState`.
//
// Gardes DÉJÀ existantes, citées et non doublonnées : l'étalon de la surface
// de `ZChatNotebookView` (`z_chat_lot_f_notebook_test.dart`, F4), la
// partition des fichiers de rendu (`z_chat_purity_test.dart`), l'absence de
// littéral porteur de mot et de `setState` (`z_chat_render_guard_test.dart`,
// `z_chat_structure_guard_test.dart`), et les propriétaires de la référence
// (`z_chat_notebook_reference_test.dart`, REF-G7 — cardinal porté à 7).
library;

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const String _kMindmap = 'mindmap';
const String _screenFile = 'lib/src/presentation/view/z_chat_notebook_screen.dart';

/// Transcript qui COMPTE les ouvertures du fil et observe l'annulation.
class _CountingTranscript implements ZChatTranscriptPort {
  _CountingTranscript(this.inner);
  final ZChatInMemoryTranscript inner;
  int opens = 0;
  int cancels = 0;

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) {
    opens++;
    late final StreamController<List<ZChatMessage>> out;
    StreamSubscription<List<ZChatMessage>>? sub;
    out = StreamController<List<ZChatMessage>>(
      onListen: () {
        sub = inner.messages(conversationId).listen(out.add, onError: out.addError);
      },
      onCancel: () async {
        cancels++;
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) => inner.append(message);

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) => inner.update(message);
}

/// Port de génération dont chaque appel reste EN VOL.
class _PendingGen implements ZChatArtifactGenerationPort {
  int calls = 0;
  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    calls++;
    return Completer<ZResult<ZChatArtifactContent>>().future;
  }
}

ZChatArtifactRegistry _registry() => ZChatArtifactRegistry(<ZChatArtifactDeclaration>[
      ZChatArtifactDeclaration(
        key: _kMindmap,
        iconKey: 'icon.mindmap',
        labelToken: 'label.mindmap',
        hasCount: true,
        verbs: <ZChatArtifactVerb>[
          ZChatArtifactVerb.create(labelToken: 'verb.create'),
          ZChatArtifactVerb.open(labelToken: 'verb.open'),
          ZChatArtifactVerb.delete(
            labelToken: 'verb.delete',
            confirmToken: 'confirm.delete',
          ),
        ],
      ),
    ]);

const ZChatArtifactResolvers _resolvers = ZChatArtifactResolvers(
  icon: _icon,
  label: _label,
);
IconData? _icon(String k) => const IconData(0xe901);
String? _label(String k) => k;

ZChatMessage _msg(String id, ZChatRole role, String text) => ZChatMessage(
      id: id,
      role: role,
      conversationId: 'c1',
      contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
    );

typedef _Rig = ({
  _CountingTranscript transcript,
  FakeStreamPort stream,
  ZChatInMemoryArtifactStore store,
});

Future<_Rig> _rig() async {
  final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
  addTearDown(inner.dispose);
  await inner.append(_msg('q1', ZChatRole.user, 'question une'));
  await inner.append(_msg('r1', ZChatRole.assistant, 'réponse une'));
  final FakeStreamPort stream = FakeStreamPort();
  addTearDown(stream.closeAll);
  return (
    transcript: _CountingTranscript(inner),
    stream: stream,
    store: ZChatInMemoryArtifactStore(),
  );
}

Widget _screen(
  _Rig r, {
  Key? key,
  bool readOnly = false,
  ZChatArtifactGenerationPort? gen,
  ZChatArtifactRequestDecorator? decorate,
  ZChatArtifactVerbConfirm? confirmArtifact,
  ZChatNotebookSlotBuilder? header,
  ZChatNotebookFailureBuilder? onFailure,
  ZChatNotebookArtifactFailureBuilder? onArtifactFailure,
  ZChatToolCatalog? tools,
  ZChatNotebookSheetPresenter? presentTools,
  double? collapsed,
  ZChatLiveLabels labels = ZChatLiveLabels.none,
  List<String> hints = const <String>[],
}) =>
    harness(ZChatNotebookScreen(
      key: key,
      streamPort: r.stream,
      transcript: r.transcript,
      conversationId: 'c1',
      cursorColor: const Color(0xFF000000),
      registry: _registry(),
      store: r.store,
      generationPort: gen,
      decorateRequest: decorate,
      confirmArtifactVerb: confirmArtifact ?? zChatConfirmArtifactWithoutDialog,
      resolvers: _resolvers,
      readOnly: readOnly,
      headerBuilder: header,
      failureBuilder: onFailure,
      artifactFailureBuilder: onArtifactFailure,
      toolCatalog: tools,
      presentTools: presentTools,
      collapsedMaxHeight: collapsed,
      liveLabels: labels,
      hints: hints,
    ));

/// Les types de l'arbre SOUS la région live, dans l'ordre de parcours.
List<String> _treeUnderLiveRegion(WidgetTester tester) => <String>[
      for (final Element e in find
          .descendant(
            of: find.byType(ZChatNotebookLiveRegion),
            matching: find.byWidgetPredicate((Widget _) => true),
          )
          .evaluate())
        e.widget.runtimeType.toString(),
    ];

ZChatToolCatalog _tools() => ZChatToolCatalog(
      sections: <ZChatToolSection>[
        const ZChatToolSection(key: 'gen', label: 'Génération'),
      ],
      entries: <ZChatToolEntry>[
        ZChatToolEntry(
          key: 'web',
          sectionKey: 'gen',
          label: 'Recherche web',
          state: const ZChatToggleState(),
        ),
      ],
    );

void main() {
  group('🔴 G2-1 — cycle de vie : UNE création, UNE libération', () {
    testWidgets('le contrôleur est créé une fois sur deux `build`, et libéré '
        'au `dispose` (abonnement annulé, tranches fermées)', (WidgetTester tester) async {
      final _Rig r = await _rig();
      ZChatNotebookController? seen;
      int headerBuilds = 0;
      Widget? header(BuildContext _, ZChatNotebookController nb) {
        headerBuilds++;
        seen = nb;
        return null;
      }

      await tester.pumpWidget(_screen(r, header: header));
      await tester.pump();
      final ZChatNotebookController first = seen!;
      // Second `build` de l'écran : une configuration qui change
      // (`hints`), donc `didUpdateWidget`, donc un nouveau passage dans
      // `build` — et PAS un nouveau contrôleur.
      await tester.pumpWidget(_screen(r, header: header, hints: const <String>['x']));
      await tester.pump();
      expect(headerBuilds, greaterThanOrEqualTo(2), reason: 'l\'écran a bien été reconstruit');
      expect(identical(seen, first), isTrue,
          reason: '🔴 un contrôleur NEUF à chaque build : requêtes en vol, '
              'abonnement et tranches perdus');
      expect(r.transcript.opens, 1,
          reason: '🔴 le fil a été rouvert : le contrôleur a été recréé');
      expect(r.transcript.cancels, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(r.transcript.cancels, 1,
          reason: '🔴 `dispose` n\'a pas libéré le contrôleur : l\'abonnement '
              'au transcript survit à l\'écran');
      expect(() => first.readOnly.addListener(() {}), throwsFlutterError,
          reason: 'les tranches du contrôleur sont fermées');
    });

    testWidgets('AD-2 — un jeton reçu ne reconstruit NI l\'écran NI le '
        'composer', (WidgetTester tester) async {
      final _Rig r = await _rig();
      ZChatNotebookController? seen;
      int headerBuilds = 0;
      Widget? header(BuildContext _, ZChatNotebookController nb) {
        headerBuilds++;
        seen = nb;
        return null;
      }

      await tester.pumpWidget(_screen(r, header: header));
      await tester.pump();
      final int builtBefore = headerBuilds;
      final ZDefaultChatComposer composerBefore =
          tester.widget<ZDefaultChatComposer>(find.byType(ZDefaultChatComposer));

      seen!.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = seen!.chat.send();
      await tester.pump();
      r.stream.last.add(tok('bon'));
      r.stream.last.add(tok('jour'));
      await tester.pump();
      final String requestId = seen!.chat.activeRequests.value.single;
      expect(seen!.chat.streamText(requestId).value, 'bonjour',
          reason: 'le jeton a bien été reçu et publié sur sa tranche');
      expect(headerBuilds, builtBefore,
          reason: '🔴 un jeton a reconstruit l\'écran : il écoute une tranche '
              'qu\'il ne devrait pas');
      expect(
        identical(
          tester.widget<ZDefaultChatComposer>(find.byType(ZDefaultChatComposer)),
          composerBefore,
        ),
        isTrue,
        reason: '🔴 le composer a été reconstruit par un jeton du fil',
      );

      r.stream.last.add(done(id: 'a2'));
      await r.stream.closeAll();
      await sending;
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 G2-2 — ÉCHAPPATOIRE : l\'écran rend l\'arbre des briques', () {
    testWidgets('avec ses défauts, l\'arbre sous la région live est IDENTIQUE '
        'à l\'assemblage manuel des briques', (WidgetTester tester) async {
      final _Rig r = await _rig();
      await tester.pumpWidget(_screen(r));
      await tester.pump();
      await tester.pump();
      final List<String> byScreen = _treeUnderLiveRegion(tester);
      await tester.pumpWidget(const SizedBox());

      // L'assemblage à la main — exactement les briques publiques.
      final ZChatNotebookController nb = ZChatNotebookController(
        streamPort: r.stream,
        transcript: r.transcript,
        conversationId: 'c1',
        registry: _registry(),
        store: r.store,
      );
      addTearDown(nb.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final double height = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      await tester.pumpWidget(harness(ZChatNotebookLiveRegion(
        announcement: nb.liveAnnouncement,
        child: ZChatNotebookView(
          controller: nb.chat,
          actionsBuilder: zChatNotebookArtifactsSlot(
            controller: nb,
            resolvers: _resolvers,
          ),
          collapsedMaxHeight: zChatNotebookCollapsedMaxHeightOf(height),
          composer: ZDefaultChatComposer(
            controller: nb.chat,
            settings: settings,
            cursorColor: const Color(0xFF000000),
          ),
        ),
      )));
      await tester.pump();
      await tester.pump();
      final List<String> byHand = _treeUnderLiveRegion(tester);

      expect(byScreen, isNotEmpty);
      expect(byScreen, contains('ZChatArtifactBar'),
          reason: 'l\'arbre comparé porte bien les artefacts');
      expect(byScreen, contains('ZDefaultChatComposer'));
      final List<String> diff = <String>[
        for (int i = 0; i < byScreen.length || i < byHand.length; i++)
          if ((i < byScreen.length ? byScreen[i] : null) !=
              (i < byHand.length ? byHand[i] : null))
            '$i: écran=${i < byScreen.length ? byScreen[i] : '-'} '
                'briques=${i < byHand.length ? byHand[i] : '-'}',
      ];
      expect(diff, isEmpty,
          reason: '🔴 l\'écran ajoute ou retire quelque chose que les briques '
              'ne rendent pas : un hôte qui descend d\'un cran perdrait — ou '
              'gagnerait — un widget');
      await tester.pumpWidget(const SizedBox());
    });

    test('le composant de dérivation de hauteur est une fonction PURE de la '
        'hauteur d\'écran', () {
      expect(zChatNotebookCollapsedMaxHeightOf(600), 180);
      expect(zChatNotebookCollapsedMaxHeightOf(2000), 250);
      expect(kZChatNotebookCollapsedMaxHeight, 250);
      expect(kZChatNotebookCollapsedHeightFactor, 0.3);
    });

    testWidgets('la hauteur repliée est DÉRIVÉE de l\'écran par défaut, et '
        'REMPLACÉE par le paramètre', (WidgetTester tester) async {
      final _Rig r = await _rig();
      await tester.pumpWidget(_screen(r));
      await tester.pump();
      final double height = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      expect(
        tester.widget<ZChatNotebookView>(find.byType(ZChatNotebookView)).collapsedMaxHeight,
        zChatNotebookCollapsedMaxHeightOf(height),
      );
      await tester.pumpWidget(_screen(r, collapsed: 99));
      await tester.pump();
      expect(
        tester.widget<ZChatNotebookView>(find.byType(ZChatNotebookView)).collapsedMaxHeight,
        99,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 G2-3 — confirmation et échecs', () {
    testWidgets('sans seam de confirmation, « supprimer » est REFUSÉ, le '
        'contenu reste, et RIEN n\'est présenté au créneau d\'échec', (WidgetTester tester) async {
      final _Rig r = await _rig();
      await r.store.write(messageId: 'r1', artifactKey: _kMindmap, content: 'm');
      ZChatNotebookController? seen;
      int reported = 0;
      await tester.pumpWidget(_screen(
        r,
        header: (BuildContext _, ZChatNotebookController nb) {
          seen = nb;
          return null;
        },
        onArtifactFailure: (BuildContext _, ZChatMessage m, String k, ZFailure f) {
          reported++;
          return const SizedBox(key: ValueKey<String>('failure'));
        },
      ));
      await tester.pump();
      await tester.pump();
      expect(
        seen!.verbsFor('r1', _kMindmap).map((ZChatArtifactVerb v) => v.key),
        contains(kZChatArtifactVerbDelete),
        reason: 'l\'artefact est présent : « supprimer » est offert',
      );
      final ZResult<ZChatActionOutcome> out = await seen!.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbDelete,
      );
      await tester.pump();
      expect(out.fold((ZFailure f) => f, (_) => null),
          isA<ZChatActionNotConfirmedFailure>(),
          reason: '🔴 supprimé SANS question : le défaut permissif est revenu');
      final ZResult<String?> kept =
          await r.store.read(messageId: 'r1', artifactKey: _kMindmap);
      expect(kept.fold((_) => null, (String? c) => c), 'm');
      expect(reported, 0,
          reason: '🔴 un refus de l\'utilisateur a été présenté comme un échec');
      expect(find.byKey(const ValueKey<String>('failure')), findsNothing);

      // Avec le seam branché, le même geste aboutit.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_screen(
        r,
        confirmArtifact: (ZChatArtifactVerbAction v) async => true,
        header: (BuildContext _, ZChatNotebookController nb) {
          seen = nb;
          return null;
        },
      ));
      await tester.pump();
      await tester.pump();
      final ZResult<ZChatActionOutcome> ok = await seen!.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbDelete,
      );
      await tester.pump();
      expect(ok.isRight(), isTrue);
      final ZResult<String?> gone =
          await r.store.read(messageId: 'r1', artifactKey: _kMindmap);
      expect(gone.fold((_) => null, (String? c) => c), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    test('la règle de présentation : `Unsupported` et `NotConfirmed` sont '
        'TUS, tout autre échec est présenté', () {
      expect(
        zChatNotebookFailureIsReportable(
          const ZUnsupportedOperationFailure('x', operation: 'op'),
        ),
        isFalse,
      );
      expect(
        zChatNotebookFailureIsReportable(
          const ZChatActionNotConfirmedFailure(verb: 'v'),
        ),
        isFalse,
      );
      expect(zChatNotebookFailureIsReportable(const ZCacheFailure('disk')), isTrue);
      expect(zChatNotebookFailureIsReportable(const ZDomainFailure('d')), isTrue);
    });

    testWidgets('`Unsupported` MASQUE (rien au créneau) ; un autre échec est '
        'SIGNALÉ par le créneau de l\'hôte, sur SA tranche', (WidgetTester tester) async {
      final _Rig r = await _rig();
      ZChatNotebookController? seen;
      final List<(String, String, ZFailure)> reported = <(String, String, ZFailure)>[];
      Widget? onArtifactFailure(BuildContext _, ZChatMessage m, String k, ZFailure f) {
        reported.add((m.id!, k, f));
        return const SizedBox(key: ValueKey<String>('failure'));
      }

      Widget? header(BuildContext _, ZChatNotebookController nb) {
        seen = nb;
        return null;
      }

      // Sans port de génération : « créer » ⇒ `Unsupported` ⇒ masqué.
      await tester.pumpWidget(_screen(r, header: header, onArtifactFailure: onArtifactFailure));
      await tester.pump();
      await tester.pump();
      final ZResult<ZChatActionOutcome> unsupported = await seen!.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      );
      await tester.pump();
      expect(unsupported.fold((ZFailure f) => f, (_) => null),
          isA<ZUnsupportedOperationFailure>());
      expect(seen!.failureOf('r1', _kMindmap).value, isA<ZUnsupportedOperationFailure>(),
          reason: 'la tranche PORTE l\'échec — c\'est la présentation qui le tait');
      expect(reported, isEmpty,
          reason: '🔴 `Unsupported` a été présenté : le socle doit masquer');
      expect(find.byKey(const ValueKey<String>('failure')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      // Avec un port, mais un ajusteur qui lève : échec de génération ⇒
      // signalé, avec le message, la clé et l'échec — jamais un texte du socle.
      await tester.pumpWidget(_screen(
        r,
        gen: _PendingGen(),
        decorate: (ZChatArtifactGenerationRequest _, ZChatMessage _) =>
            throw StateError('boom'),
        header: header,
        onArtifactFailure: onArtifactFailure,
      ));
      await tester.pump();
      await tester.pump();
      await seen!.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      );
      await tester.pump();
      expect(reported, hasLength(1));
      expect(reported.single.$1, 'r1');
      expect(reported.single.$2, _kMindmap);
      expect(reported.single.$3, isA<ZChatArtifactGenerationFailure>());
      expect(find.byKey(const ValueKey<String>('failure')), findsOneWidget,
          reason: '🔴 l\'échec est sur la tranche mais le créneau n\'est pas monté');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('le créneau d\'échec GLOBAL suit `lastFailure` du fil de '
        'travail ET de la conversation', (WidgetTester tester) async {
      final _Rig r = await _rig();
      final List<ZFailure> reported = <ZFailure>[];
      await tester.pumpWidget(_screen(
        r,
        onFailure: (BuildContext _, ZFailure f) {
          reported.add(f);
          return SizedBox(key: ValueKey<String>('global-${reported.length}'));
        },
      ));
      await tester.pump();
      expect(reported, isEmpty, reason: 'rien à signaler au repos');
      // Deux tranches ⇒ deux écouteurs, chacun sur la sienne.
      expect(find.byType(ValueListenableBuilder<ZFailure?>), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 G2-4 — région live, lecture seule, action globale', () {
    testWidgets('la région live des ARTEFACTS est montée EN PLUS de celle des '
        'tours : les deux annonces sont audibles', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final _Rig r = await _rig();
      final _PendingGen gen = _PendingGen();
      ZChatNotebookController? seen;
      await tester.pumpWidget(_screen(
        r,
        gen: gen,
        labels: ZChatLiveLabels(
          generationStarted: 'tour lancé',
          artifactGenerationStarted: (String k) => 'artefact $k lancé',
        ),
        header: (BuildContext _, ZChatNotebookController nb) {
          seen = nb;
          return null;
        },
      ));
      await tester.pump();
      await tester.pump();
      final int regionsAtRest = collectSemantics(
        tester,
        (SemanticsNode n) => n.getSemanticsData().flagsCollection.isLiveRegion,
      ).length;
      expect(regionsAtRest, greaterThanOrEqualTo(2),
          reason: '🔴 une seule région live : les jalons d\'artefact sont muets');

      // Le port reste EN VOL : ne jamais attendre ce verbe sous `testWidgets`
      // (le `Future` ne se résout pas), pomper.
      unawaited(seen!.runArtifactVerb(
        messageId: 'r1',
        artifactKey: _kMindmap,
        verbKey: kZChatArtifactVerbCreate,
      ));
      await tester.pump();
      expect(gen.calls, 1);
      expect(
        findSemantics(tester, (SemanticsNode n) => n.label == 'artefact mindmap lancé'),
        isNotNull,
        reason: '🔴 l\'annonce d\'artefact n\'atteint aucun nœud live',
      );

      seen!.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = seen!.chat.send();
      await tester.pump();
      expect(
        findSemantics(tester, (SemanticsNode n) => n.label == 'tour lancé'),
        isNotNull,
        reason: 'l\'annonce des tours reste celle de la vue',
      );
      expect(
        findSemantics(tester, (SemanticsNode n) => n.label == 'artefact mindmap lancé'),
        isNotNull,
        reason: '🔴 l\'annonce de tour a ÉCRASÉ celle de l\'artefact : une '
            'seule région pour deux canaux',
      );
      r.stream.last.add(done(id: 'a2'));
      await r.stream.closeAll();
      await sending;
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    });

    testWidgets('lecture seule : composer ABSENT ; la bascule est suivie sans '
        'recréer le contrôleur', (WidgetTester tester) async {
      final _Rig r = await _rig();
      ZChatNotebookController? seen;
      Widget? header(BuildContext _, ZChatNotebookController nb) {
        seen = nb;
        return null;
      }

      await tester.pumpWidget(_screen(r, readOnly: true, header: header));
      await tester.pump();
      expect(find.byType(ZDefaultChatComposer), findsNothing,
          reason: '🔴 une zone de saisie en consultation');
      expect(seen!.readOnly.value, isTrue);
      await tester.pumpWidget(_screen(r, header: header));
      await tester.pump();
      expect(find.byType(ZDefaultChatComposer), findsOneWidget);
      expect(seen!.readOnly.value, isFalse, reason: 'la bascule atteint le contrôleur');
      expect(r.transcript.opens, 1, reason: '🔴 la bascule a recréé le contrôleur');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('le créneau d\'action GLOBALE reçoit le contrôleur et se rend '
        'au-dessus du fil ; `null` ⇒ absent', (WidgetTester tester) async {
      final _Rig r = await _rig();
      await tester.pumpWidget(_screen(
        r,
        header: (BuildContext _, ZChatNotebookController nb) => SizedBox(
          key: ValueKey<String>('export:${nb.conversationId}'),
          height: 48,
        ),
      ));
      await tester.pump();
      final Finder slot = find.byKey(const ValueKey<String>('export:c1'));
      expect(slot, findsOneWidget);
      expect(
        tester.getTopLeft(slot).dy,
        lessThan(tester.getTopLeft(find.byType(ZChatNotebookView)).dy),
        reason: 'l\'action globale est AU-DESSUS du fil',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 G2-5 — outils et feuille', () {
    testWidgets('sans présentateur, le bouton « outils » est ABSENT (AD-4) ; '
        'avec, la feuille est projetée depuis le catalogue et le badge suit '
        'le compte des outils', (WidgetTester tester) async {
      final _Rig r = await _rig();
      await tester.pumpWidget(_screen(r, tools: _tools()));
      await tester.pump();
      ZDefaultChatComposer composer =
          tester.widget<ZDefaultChatComposer>(find.byType(ZDefaultChatComposer));
      expect(composer.onOpenTools, isNull,
          reason: '🔴 un bouton qui ouvre une feuille que le socle ne sait '
              'pas présenter');
      expect(composer.toolsBadge, isA<ValueListenableBuilder<int>>(),
          reason: 'le badge suit `ZChatToolController.activeCount`');
      expect(composer.showToolsBadge, isFalse,
          reason: 'un seul compte sur le déclencheur : celui des outils');
      await tester.pumpWidget(const SizedBox());

      WidgetBuilder? presented;
      await tester.pumpWidget(_screen(
        r,
        tools: _tools(),
        presentTools: (BuildContext context, WidgetBuilder sheet) async {
          presented = sheet;
        },
      ));
      await tester.pump();
      composer = tester.widget<ZDefaultChatComposer>(find.byType(ZDefaultChatComposer));
      expect(composer.onOpenTools, isNotNull);
      composer.onOpenTools!();
      expect(presented, isNotNull, reason: 'le présentateur de l\'hôte est appelé');
      // La feuille, montée dans l'arbre de l'hôte (ici : par-dessus l'écran).
      final BuildContext context = tester.element(find.byType(ZChatNotebookScreen));
      final Widget sheet = presented!(context);
      expect(sheet, isA<ListenableBuilder>(),
          reason: 'la feuille suit le contrôleur d\'outils');
      await tester.pumpWidget(harness(sheet));
      await tester.pump();
      final ZChatSettingsSheet built =
          tester.widget<ZChatSettingsSheet>(find.byType(ZChatSettingsSheet));
      expect(built.sections.map((ZChatSettingsSection s) => s.id), <String>['gen']);
      expect(built.entries, hasLength(1),
          reason: '🔴 le catalogue n\'est pas projeté dans la feuille');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 G2-6 — gardes de source', () {
    test('le contrôleur de fil de travail n\'est construit QUE dans '
        '`initState` — jamais dans `build`', () {
      final List<String> src = stripped(libFile(_screenFile));
      final RegExp ctor = RegExp(r'\bZChatNotebookController\(');
      final List<int> sites = <int>[
        for (int i = 0; i < src.length; i++)
          if (ctor.hasMatch(src[i])) i,
      ];
      expect(sites, hasLength(1),
          reason: '🔴 ${sites.length} constructions du contrôleur : $sites');
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
      expect(sites.single, inExclusiveRange(initState, nextMember),
          reason: '🔴 le contrôleur est construit hors de `initState` '
              '(ligne ${sites.single + 1}) — dans `build`, il serait recréé '
              'à chaque frame');
      expect(src.any((String l) => l.contains('_nb.dispose()')), isTrue,
          reason: '🔴 le contrôleur n\'est pas libéré');
    });

    test('🔬 contre-preuve — la garde de site VOIT une construction dans '
        '`build`', () {
      final List<String> witness = <String>[
        '  void initState() {',
        '    super.initState();',
        '  }',
        '  @override',
        '  Widget build(BuildContext context) {',
        '    final ZChatNotebookController nb = ZChatNotebookController(',
      ];
      final RegExp ctor = RegExp(r'\bZChatNotebookController\(');
      final int site = witness.indexWhere(ctor.hasMatch);
      final int initState = witness.indexWhere(
        (String l) => RegExp(r'void initState\(\)').hasMatch(l),
      );
      final int nextMember = witness.indexWhere(
        (String l) => l.trim() == '@override',
        initState,
      );
      expect(site, isNot(inExclusiveRange(initState, nextMember)),
          reason: 'le témoin construit dans `build` : la garde doit le voir');
    });

    test('l\'écran ne cite AUCUN libellé, aucune couleur, et ne dépend pas '
        'd\'un paquet hors des trois admis', () {
      final List<String> src = stripped(libFile(_screenFile));
      final List<String> imports = <String>[
        for (final String l in src)
          if (l.trimLeft().startsWith('import ')) l.trim(),
      ];
      expect(
        imports.where((String i) => i.contains('zcrud_screen') ||
            i.contains('zcrud_chat_material') ||
            i.contains('material.dart')),
        isEmpty,
        reason: '🔴 `zcrud_chat` ne dépend ni de `zcrud_screen`, ni du '
            'satellite Material, ni de `material.dart`',
      );
      expect(src.any((String l) => RegExp(r'Color\(0x').hasMatch(l)), isFalse);
      expect(
        src.any((String l) => RegExp(r'\bsetState\s*\(').hasMatch(l)),
        isFalse,
      );
    });
  });
}
