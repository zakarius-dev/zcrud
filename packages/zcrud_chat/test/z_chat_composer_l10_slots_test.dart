// Lot L10 — le porteur de créneaux des écrans assemblés.
//
// Ce que ce fichier prouve :
//
// * INERTIE — sans porteur, l'écran passe `null` à CHACUN des seize créneaux
//   de `ZDefaultChatComposer`, et conserve le câblage qu'il faisait déjà.
//   L'assemblé n'a pas été touché par ce lot : seize `null` + un câblage
//   intact ⇒ l'arbre rendu est celui d'avant, à l'octet près. La liste
//   littérale des types de l'arbre est la ceinture de cette déduction ;
// * RELAIS — un créneau fourni ARRIVE au composer, à son rang, et le reste du
//   câblage de l'écran (réglages, badge d'outils, sélecteur de routeur) est
//   CONSERVÉ : c'est le bénéfice que le remplacement total fait perdre ;
// * EXCLUSION — déclarer le remplacement total ET le porteur mord en debug ;
// * PRÉCÉDENCE — le remplacement total prime ;
// * GRANULARITÉ — un créneau qui se reconstruit ne reconstruit pas les autres
//   pièces de l'écran.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

ZChatMessage _msg(String id, ZChatRole role, String text) => ZChatMessage(
      id: id,
      role: role,
      conversationId: 'c1',
      contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
    );

/// L'écran de CONVERSATION assemblé — le plus léger des deux à monter, et
/// celui qui porte le même `_composer` que le notebook.
Widget _conv({
  ZChatComposerSlots? slots,
  ZChatConversationComposerBuilder? builder,
  ZChatToolCatalog? tools,
  ZChatNotebookSheetPresenter? presentTools,
  List<ZChatModelOption> models = const <ZChatModelOption>[],
  ZChatRouteSession? session,
}) {
  final FakeStreamPort stream = FakeStreamPort();
  addTearDown(stream.closeAll);
  return harness(ZChatConversationScreen(
    streamPort: stream,
    cursorColor: const Color(0xFF000000),
    conversationId: 'c1',
    initialMessages: <ZChatMessage>[_msg('q1', ZChatRole.user, 'bonjour')],
    composerSlots: slots,
    composerBuilder: builder,
    toolCatalog: tools,
    presentTools: presentTools,
    modelOptions: models,
    onSelectModel: (String _) {},
    routeSession: session,
    routerOptions: session == null ? const <ZChatModelOption>[] : _kRouters,
  ));
}

ZDefaultChatComposer _assembled(WidgetTester tester) =>
    tester.widget<ZDefaultChatComposer>(find.byType(ZDefaultChatComposer));


/// L'écran NOTEBOOK assemblé — l'autre porteur du même `_composer`.
Widget _notebook({
  ZChatComposerSlots? slots,
  ZChatNotebookComposerBuilder? builder,
  ZChatToolCatalog? tools,
  ZChatNotebookSheetPresenter? presentTools,
  List<ZChatModelOption> models = const <ZChatModelOption>[],
}) {
  final FakeStreamPort stream = FakeStreamPort();
  addTearDown(stream.closeAll);
  final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
  addTearDown(transcript.dispose);
  return harness(ZChatNotebookScreen(
    streamPort: stream,
    transcript: transcript,
    conversationId: 'c1',
    cursorColor: const Color(0xFF000000),
    composerSlots: slots,
    composerBuilder: builder,
    toolCatalog: tools,
    presentTools: presentTools,
    modelOptions: models,
    onSelectModel: (String _) {},
  ));
}

ZChatToolCatalog _tools() => ZChatToolCatalog(
      sections: <ZChatToolSection>[
        const ZChatToolSection(key: 'gen', label: 'Génération'),
      ],
      entries: <ZChatToolEntry>[
        ZChatToolEntry(
          key: 'web',
          sectionKey: 'gen',
          label: 'Recherche web',
          state: const ZChatToggleState(value: true),
        ),
      ],
    );

const List<ZChatModelOption> _kModels = <ZChatModelOption>[
  ZChatModelOption(id: 'm1', label: 'Modèle un'),
];

const List<ZChatModelOption> _kRouters = <ZChatModelOption>[
  ZChatModelOption(id: 'ra', label: 'Routeur A'),
];

Widget _mark(String id) =>
    SizedBox(key: ValueKey<String>('slot-$id'), width: 8, height: 8);

ZChatComposerSlotBuilder _markSlot(String id) =>
    (BuildContext context, ZChatComposerSlot slot) => _mark(id);

void main() {
  group('🔴 L10-1 — INERTIE : sans porteur, l\'écran rend ce qu\'il rendait', () {
    testWidgets('les seize créneaux de l\'assemblé valent `null`, et le '
        'câblage préexistant de l\'écran est intact', (WidgetTester tester) async {
      await tester.pumpWidget(_conv());
      await tester.pump();
      final ZDefaultChatComposer c = _assembled(tester);

      // Les SEIZE créneaux du porteur, un par un, en ABSOLU.
      expect(c.draftNoticeBuilder, isNull, reason: 'rang 0');
      expect(c.editingBannerBuilder, isNull, reason: 'rang 1');
      expect(c.progressBuilder, isNull, reason: 'rang 2');
      expect(c.suggestionsBuilder, isNull, reason: 'rang 3');
      expect(c.attachmentsBuilder, isNull, reason: 'rang 4');
      expect(c.dictation, isNull, reason: 'rang 5 (capture)');
      expect(c.hintBuilder, isNull, reason: 'hint');
      expect(c.plusBuilder, isNull, reason: 'plus');
      expect(c.thinkingBuilder, isNull, reason: 'thinking');
      expect(c.webSearchBuilder, isNull, reason: 'webSearch');
      expect(c.toolsBuilder, isNull, reason: 'tools');
      expect(c.effortBuilder, isNull, reason: 'effort');
      expect(c.modelBuilder, isNull, reason: 'model (aucune session déclarée)');
      expect(c.dictationBuilder, isNull, reason: 'dictationTrigger');
      expect(c.stopBuilder, isNull, reason: 'stop');
      expect(c.sendBuilder, isNull, reason: 'send');

      // Le câblage que l'écran faisait DÉJÀ, inchangé.
      expect(c.settings, isNotNull);
      expect(c.cursorColor, const Color(0xFF000000));
      expect(c.showToolsBadge, isTrue);
      expect(c.onOpenTools, isNull);
      expect(c.toolsBadge, isNull);
    });

    testWidgets('ceinture : l\'arbre monté sous l\'assemblé est la liste '
        'littérale d\'avant le porteur', (WidgetTester tester) async {
      await tester.pumpWidget(_conv());
      await tester.pump();
      expect(_typesUnderAssembled(tester), _kInertTree);
    });
  });

  group('🔴 L10-2 — RELAIS : le créneau ARRIVE, à son rang, sans rien perdre', () {
    testWidgets('conversation — le créneau `plus` remplace la pièce par '
        'défaut, le rang 1 reste AU-DESSUS de la bande, et le déclencheur '
        'd\'outils, son badge et le sélecteur de modèle sont CONSERVÉS',
        (WidgetTester tester) async {
      bool opened = false;
      await tester.pumpWidget(_conv(
        slots: ZChatComposerSlots(
          plus: _markSlot('plus'),
          editingBanner: _markSlot('rang1'),
        ),
        tools: _tools(),
        presentTools: (BuildContext c, WidgetBuilder b) async {
          opened = true;
        },
        models: _kModels,
      ));
      await tester.pump();

      // ARRIVÉ : les deux créneaux sont dans l'arbre.
      expect(find.byKey(const ValueKey<String>('slot-plus')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('slot-rang1')), findsOneWidget);
      // Il REMPLACE : la pièce par défaut du `+` n'est plus montée.
      expect(find.byType(ZChatComposerPickerTrigger), findsNothing);

      // À SON RANG : le rang 1 est au-dessus de la bande.
      final double rang1 = tester
          .getTopLeft(find.byKey(const ValueKey<String>('slot-rang1')))
          .dy;
      final double band =
          tester.getTopLeft(find.byKey(const ValueKey<String>('slot-plus'))).dy;
      expect(rang1, lessThan(band));

      // CONSERVÉ — c'est le bénéfice que le remplacement total fait perdre :
      // le déclencheur d'outils que l'écran câble, son badge de compte, et
      // le sélecteur de modèle de l'hôte.
      expect(find.byType(ZChatComposerToolsTrigger), findsOneWidget);
      expect(find.byType(ZChatComposerCountBadge), findsOneWidget);
      expect(find.byType(ZChatComposerModelSelector), findsOneWidget);
      final ZDefaultChatComposer c = _assembled(tester);
      expect(c.settings, isNotNull);
      expect(c.onOpenTools, isNotNull);
      expect(c.modelOptions, _kModels);
      expect(opened, isFalse);
    });

    testWidgets('notebook — même relais, même conservation du câblage',
        (WidgetTester tester) async {
      await tester.pumpWidget(_notebook(
        slots: ZChatComposerSlots(plus: _markSlot('plus')),
        tools: _tools(),
        presentTools: (BuildContext c, WidgetBuilder b) async {},
        models: _kModels,
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('slot-plus')), findsOneWidget);
      expect(find.byType(ZChatComposerPickerTrigger), findsNothing);
      expect(find.byType(ZChatComposerToolsTrigger), findsOneWidget);
      expect(find.byType(ZChatComposerCountBadge), findsOneWidget);
      expect(find.byType(ZChatComposerModelSelector), findsOneWidget);
      expect(_assembled(tester).modelOptions, _kModels);
    });
  });

  group('🔴 L10-3 — EXCLUSION : les deux intentions ensemble MORDENT', () {
    test('conversation — `composerBuilder` ET `composerSlots` déclarés : '
        'l\'assertion de debug refuse la construction', () {
      Object? caught;
      try {
        ZChatConversationScreen(
          streamPort: FakeStreamPort(),
          cursorColor: const Color(0xFF000000),
          composerBuilder: (BuildContext c, ZChatController a, dynamic b) =>
              const SizedBox.shrink(),
          composerSlots: ZChatComposerSlots(plus: _markSlot('plus')),
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<AssertionError>());
      expect(
        '$caught'.contains(kZChatComposerSlotsExclusiveAssertMessage),
        isTrue,
        reason: 'le message du contrat, pas un autre assert',
      );
    });

    test('notebook — même refus', () {
      Object? caught;
      final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
      addTearDown(transcript.dispose);
      try {
        ZChatNotebookScreen(
          streamPort: FakeStreamPort(),
          transcript: transcript,
          conversationId: 'c1',
          cursorColor: const Color(0xFF000000),
          composerBuilder: (BuildContext c, dynamic a, dynamic b) =>
              const SizedBox.shrink(),
          composerSlots: ZChatComposerSlots(plus: _markSlot('plus')),
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<AssertionError>());
      expect(
        '$caught'.contains(kZChatComposerSlotsExclusiveAssertMessage),
        isTrue,
      );
    });

    test('chacune SEULE est acceptée — la garde ne refuse pas l\'usage normal',
        () {
      final ZChatInMemoryTranscript t = ZChatInMemoryTranscript();
      addTearDown(t.dispose);
      expect(
        () => ZChatConversationScreen(
          streamPort: FakeStreamPort(),
          cursorColor: const Color(0xFF000000),
          composerSlots: ZChatComposerSlots(plus: _markSlot('plus')),
        ),
        returnsNormally,
      );
      expect(
        () => ZChatConversationScreen(
          streamPort: FakeStreamPort(),
          cursorColor: const Color(0xFF000000),
          composerBuilder: (BuildContext c, ZChatController a, dynamic b) =>
              const SizedBox.shrink(),
        ),
        returnsNormally,
      );
    });
  });

  group('🔴 L10-5 — GRANULARITÉ : un créneau qui réagit n\'entraîne pas les '
      'autres', () {
    testWidgets('la frappe reconstruit le créneau ABONNÉ (`send` sur '
        '`canSend`) et laisse le créneau INERTE (`plus`) à UN seul build',
        (WidgetTester tester) async {
      int plusBuilds = 0;
      int sendBuilds = 0;
      await tester.pumpWidget(_conv(
        slots: ZChatComposerSlots(
          plus: (BuildContext context, ZChatComposerSlot slot) {
            plusBuilds++;
            return _mark('plus');
          },
          send: (BuildContext context, ZChatComposerSlot slot) =>
              ValueListenableBuilder<bool>(
            valueListenable: slot.controller.canSend,
            builder: (BuildContext context, bool can, Widget? _) {
              sendBuilds++;
              return _mark('send');
            },
          ),
        ),
      ));
      await tester.pump();
      expect(plusBuilds, 1, reason: 'point de départ');
      final int sendAtRest = sendBuilds;

      await tester.enterText(find.byType(EditableText).first, 'a');
      await tester.pump();

      // Non-vacuité : la frappe a bien atteint le composer.
      expect(find.text('a'), findsWidgets);
      expect(sendBuilds, greaterThan(sendAtRest),
          reason: 'le créneau ABONNÉ a réagi');
      // EN ABSOLU : le créneau inerte n'a pas été reconstruit une seconde
      // fois — ni lui, ni donc l'écran au-dessus de lui.
      expect(plusBuilds, 1, reason: 'le créneau INERTE ne bouge pas');
    });
  });

  group('🔴 L10-6 — le créneau `model` d\'hôte prime sur le sélecteur de '
      'ROUTEUR que l\'écran monte à cette place', () {
    testWidgets('sans créneau, l\'écran monte SON sélecteur de routeur ; avec '
        'créneau, c\'est CELUI DE L\'HÔTE qui arrive — le même objet',
        (WidgetTester tester) async {
      final ZChatRouteSession session = ZChatRouteSession(
        catalog: ZChatInMemoryRouteCatalog(const <ZChatRouter>[]),
      );
      addTearDown(session.dispose);

      await tester.pumpWidget(_conv(session: session));
      await tester.pump();
      expect(_assembled(tester).modelBuilder, isNotNull,
          reason: 'le sélecteur de routeur de l\'écran');

      final ZChatComposerSlotBuilder mine = _markSlot('model');
      await tester.pumpWidget(_conv(
        session: session,
        slots: ZChatComposerSlots(model: mine),
      ));
      await tester.pump();
      expect(identical(_assembled(tester).modelBuilder, mine), isTrue,
          reason: 'le créneau d\'hôte, pas le slot de routeur');
    });
  });
}

/// Les types de l'arbre SOUS l'assemblé, dans l'ordre de parcours.
List<String> _typesUnderAssembled(WidgetTester tester) => <String>[
      for (final Element e in find
          .descendant(
            of: find.byType(ZDefaultChatComposer),
            matching: find.byWidgetPredicate((Widget _) => true),
          )
          .evaluate())
        e.widget.runtimeType.toString(),
    ];

/// L'arbre de l'écran assemblé SANS porteur — relevé littéral.
const List<String> _kInertTree = <String>[
  'ZChatComposerSurface',
  'ZChatComposer',
  'Semantics',
  'Padding',
  'Column',
  'ZChatComposerEditingBanner',
  'ValueListenableBuilder<ZChatEditingSession?>',
  'SizedBox',
  'Row',
  'Expanded',
  '_ZChatComposerField',
  'Semantics',
  'Stack',
  '_ZChatComposerHint',
  'ExcludeSemantics',
  'IgnorePointer',
  'ValueListenableBuilder<TextEditingValue>',
  'Text',
  'RichText',
  'EditableText',
  '_CompositionCallback',
  'Actions',
  '_ActionsScope',
  'Builder',
  'TextFieldTapRegion',
  'MouseRegion',
  'UndoHistory<TextEditingValue>',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'NotificationListener<ScrollNotification>',
  'Scrollable',
  '_ScrollableScope',
  'Listener',
  'RawGestureDetector',
  'Listener',
  'Semantics',
  'IgnorePointer',
  'CompositedTransformTarget',
  'Semantics',
  '_ScribbleFocusable',
  'SizeChangedLayoutNotifier',
  '_Editable',
  '_ZChatComposerTarget',
  'ConstrainedBox',
  'Align',
  'Row',
  'ZChatComposerStopTarget',
  'ValueListenableBuilder<List<String>>',
  'SizedBox',
  'ZChatComposerSendTarget',
  'ValueListenableBuilder<bool>',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  '_GestureSemantics',
  'Listener',
  'ConstrainedBox',
  'Align',
  'Padding',
  'AnimatedScale',
  'ScaleTransition',
  'Transform',
  'Text',
  'RichText',
  'LayoutBuilder',
  'SingleChildScrollView',
  'Scrollable',
  'StretchingOverscrollIndicator',
  'NotificationListener<ScrollNotification>',
  'AnimatedBuilder',
  'ClipRect',
  'StretchEffect',
  'Transform',
  'NotificationListener<ScrollMetricsNotification>',
  '_ScrollSemantics',
  '_ScrollableScope',
  'Listener',
  'RawGestureDetector',
  '_GestureSemantics',
  'Listener',
  'Semantics',
  'IgnorePointer',
  '_SingleChildViewport',
  'ConstrainedBox',
  'Row',
  'Row',
  'ZChatComposerThinkingToggle',
  'ValueListenableBuilder<ZChatGenerationSettings>',
  '_ZChatComposerBandTarget',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  '_GestureSemantics',
  'Listener',
  'ConstrainedBox',
  'Align',
  'Row',
  'Text',
  'RichText',
  'ZChatComposerWebSearchToggle',
  'ValueListenableBuilder<ZChatGenerationSettings>',
  '_ZChatComposerBandTarget',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  '_GestureSemantics',
  'Listener',
  'ConstrainedBox',
  'Align',
  'Row',
  'Text',
  'RichText',
  'Row',
  'ZChatComposerEffortSelector',
  'OverlayPortal',
  '_OverlayPortal',
  'Semantics',
  'CompositedTransformTarget',
  'ValueListenableBuilder<ZChatGenerationSettings>',
  'ValueListenableBuilder<bool>',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  '_GestureSemantics',
  'Listener',
  'ConstrainedBox',
  'Align',
  'Row',
  'Text',
  'RichText',
];
