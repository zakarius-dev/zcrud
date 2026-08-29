// Lot P0-E — assemblage de génération de carte mentale par IA.
//
// Ce que ces gardes défendent, et pourquoi elles ont été écrites ainsi :
//
// * INERTIE ABSOLUE (G1) — le recensement de l'arbre de `ZStudyMindmapSection`
//   a été capturé par une sonde AVANT toute modification de la section, puis
//   figé ci-dessous. Une garde en `<=` ou en `contains` aurait laissé passer
//   l'ajout d'un widget ; l'égalité ORDONNÉE et STRICTE ne le peut pas. La
//   descente s'arrête à `ZMindmapView` : les entrailles du graphe appartiennent
//   à un autre paquet, les inclure ferait rougir cette garde pour un changement
//   qui n'est pas le sien (garde MAL ANCRÉE).
// * ZÉRO ÉCRITURE (G3/G4) — le compteur d'un dépôt EN MÉMOIRE branché sur le
//   handoff est la seule mesure honnête : compter les appels d'une méthode
//   qu'on n'appelle pas prouverait seulement qu'on ne l'appelle pas.
// * NŒUDS ÉDITÉS (G5) — la validation est déclenchée APRÈS une mutation réelle
//   dans la revue. Valider sans éditer laisserait passer une implémentation qui
//   persiste la forêt d'origine.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Recensement ORDONNÉ de l'arbre de `ZStudyMindmapSection` **avant** le lot
/// (sonde du 2026-08-28, descente arrêtée à `ZMindmapView`). Toute action
/// ajoutée sans port le ferait diverger.
const List<String> _sectionCensusBeforeLot = <String>[
  'ZStudyMindmapSection',
  'KeyedSubtree',
  'ValueListenableBuilder<ZStudyMindmapMode>',
  'Column',
  'Padding',
  'Row',
  'Spacer',
  'Expanded',
  'SizedBox',
  'ConstrainedBox',
  'IconButton',
  '_SelectableIconButton',
  '_IconButtonM3',
  'Semantics',
  '_InputPadding',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'Tooltip',
  'RawTooltip',
  'OverlayPortal',
  '_OverlayPortal',
  'Semantics',
  '_ExclusiveMouseRegion',
  'Listener',
  'Semantics',
  'MouseRegion',
  'AnimatedTheme',
  'Theme',
  '_InheritedTheme',
  'CupertinoTheme',
  'InheritedCupertinoTheme',
  'IconTheme',
  'IconTheme',
  'DefaultSelectionStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Align',
  'Semantics',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'SizedBox',
  'ZMindmapView',
];

/// Recense l'arbre sous [root], dans l'ordre de visite, sans descendre dans
/// `ZMindmapView` (frontière d'un autre paquet).
List<String> _census(WidgetTester tester, Finder root) {
  final types = <String>[];
  void visit(Element e) {
    final name = e.widget.runtimeType.toString();
    types.add(name);
    if (name == 'ZMindmapView') return;
    e.visitChildren(visit);
  }

  visit(tester.element(root));
  return types;
}

/// Port de génération contrôlé par le test : capture la requête reçue et rend
/// exactement ce que le scénario demande (y compris une LEVÉE).
class _FakePort implements ZMindmapGenerationPort {
  _FakePort({this.nodes = const <ZMindmapNode>[], this.failure, this.throws = false});

  final List<ZMindmapNode> nodes;
  final ZFailure? failure;
  final bool throws;

  final List<ZMindmapGenerationRequest> received = <ZMindmapGenerationRequest>[];

  @override
  Future<ZResult<List<ZMindmapNode>>> generateMindmap(
    ZMindmapGenerationRequest request,
  ) async {
    received.add(request);
    if (throws) throw StateError('port en panne');
    final f = failure;
    if (f != null) return Left<ZFailure, List<ZMindmapNode>>(f);
    return Right<ZFailure, List<ZMindmapNode>>(nodes);
  }
}

/// Dépôt EN MÉMOIRE branché sur le handoff : c'est lui qui compte les
/// écritures. Aucune écriture ne peut se produire sans passer par ce compteur.
class _InMemorySink {
  final List<ZMindmap> written = <ZMindmap>[];

  void call(ZMindmap mindmap) => written.add(mindmap);
}

const ZMindmapGenerationMessages _messages = ZMindmapGenerationMessages(
  unexpectedError: 'MSG-UNEXPECTED',
  emptyResult: 'MSG-EMPTY',
);

const ZMindmapGenerationLabels _labels = ZMindmapGenerationLabels(
  contentLabel: 'L-CONTENT',
  contentHint: 'L-CONTENT-HINT',
  instructionsLabel: 'L-INSTR',
  instructionsHint: 'L-INSTR-HINT',
  sourceLabel: 'L-SOURCE',
  summarizeLabel: 'L-SUMMARIZE',
  generateLabel: 'L-GENERATE',
  generatingLabel: 'L-GENERATING',
  reviewTitle: 'L-REVIEW',
);

Widget _sectionApp({
  ZMindmapGenerationPort? port,
  void Function(ZMindmapGenerationPort port)? onGenerate,
  String? generateSemanticLabel,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZStudyMindmapSection(
        folderId: 'f1',
        roots: <ZMindmapNode>[
          ZMindmapNode(id: 'n1', label: 'A'),
          ZMindmapNode(id: 'n2', label: 'B'),
        ],
        generationPort: port,
        onGenerate: onGenerate,
        generateSemanticLabel: generateSemanticLabel,
      ),
    ),
  );
}

Widget _sheetApp({
  required ZMindmapGenerationPort port,
  required _InMemorySink sink,
  String? routeId,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZMindmapGenerationSheet(
        port: port,
        folderId: 'f-cible',
        messages: _messages,
        labels: _labels,
        onGenerated: sink.call,
        routeId: routeId,
        sources: const <ZMindmapGenerationSourceOption>[
          ZMindmapGenerationSourceOption(label: 'L-SRC-LIBRE'),
          ZMindmapGenerationSourceOption(
            label: 'L-SRC-DOC',
            source: ZMindmapSourceRef(id: 'doc-1', selector: 'p.1-3'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('G1 — INERTIE ABSOLUE de la section sans port', () {
    testWidgets('arbre STRICTEMENT identique au recensement d\'avant le lot',
        (tester) async {
      await tester.pumpWidget(_sectionApp());
      await tester.pumpAndSettle();

      expect(
        _census(tester, find.byType(ZStudyMindmapSection)),
        equals(_sectionCensusBeforeLot),
        reason: '🔴 la section rend un arbre DIFFÉRENT de celui d\'avant le '
            'lot alors qu\'aucun port n\'est fourni : le défaut passif exige '
            'une inertie ABSOLUE, pas « à peu près la même chose ».',
      );
    });

    testWidgets('même nombre d\'actions : une seule (la bascule)',
        (tester) async {
      await tester.pumpWidget(_sectionApp());
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('z-mindmap-section-generate')),
        findsNothing,
      );
    });

    testWidgets('port SEUL (sans rappel ni libellé) ⇒ action toujours ABSENTE',
        (tester) async {
      // Les trois maillons sont indissociables : une action sans rappel serait
      // un no-op, sans libellé elle serait muette.
      await tester.pumpWidget(_sectionApp(port: _FakePort()));
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsOneWidget);
      expect(
        _census(tester, find.byType(ZStudyMindmapSection)),
        equals(_sectionCensusBeforeLot),
      );
    });
  });

  group('G2 — port CÂBLÉ ⇒ action PRÉSENTE', () {
    testWidgets('paramètre : action montée, libellé annoncé, port remis au tap',
        (tester) async {
      final port = _FakePort();
      final handed = <ZMindmapGenerationPort>[];
      await tester.pumpWidget(_sectionApp(
        port: port,
        onGenerate: handed.add,
        generateSemanticLabel: 'L-GENERATE-ACTION',
      ));
      await tester.pumpAndSettle();

      final action =
          find.byKey(const ValueKey<String>('z-mindmap-section-generate'));
      expect(action, findsOneWidget);
      // Deux actions au lieu d'une : c'est la différence EXACTE avec l'inertie.
      expect(find.byType(IconButton), findsNWidgets(2));
      expect(
        _census(tester, find.byType(ZStudyMindmapSection)),
        isNot(equals(_sectionCensusBeforeLot)),
        reason: 'sonde : sans divergence d\'arbre ici, G1 serait infalsifiable',
      );
      expect(find.byTooltip('L-GENERATE-ACTION'), findsOneWidget);
      // Cible ≥ 48 dp (AD-13).
      final size = tester.getSize(action);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(action);
      await tester.pump();
      expect(handed, hasLength(1));
      expect(identical(handed.single, port), isTrue,
          reason: 'le port RÉSOLU doit être remis tel quel à l\'appelant');
    });

    testWidgets('scope ancêtre : le port injecté monte aussi l\'action',
        (tester) async {
      final port = _FakePort();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZMindmapGenerationScope(
              port: port,
              child: ZStudyMindmapSection(
                folderId: 'f1',
                roots: <ZMindmapNode>[ZMindmapNode(id: 'n1', label: 'A')],
                onGenerate: (_) {},
                generateSemanticLabel: 'L-GENERATE-ACTION',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('z-mindmap-section-generate')),
        findsOneWidget,
      );
    });
  });

  group('G3 — Left ⇒ failed, AUCUNE levée, AUCUNE écriture', () {
    testWidgets('le message du ZFailure est annoncé, le dépôt reste à 0',
        (tester) async {
      final port = _FakePort(failure: const ZDomainFailure('QUOTA-ÉPUISÉ'));
      final sink = _InMemorySink();
      await tester.pumpWidget(_sheetApp(port: port, sink: sink));

      await tester.enterText(
          find.byKey(const ValueKey<String>('z-mindmap-generation-content')),
          'source');
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-error')),
        findsOneWidget,
      );
      expect(find.text('QUOTA-ÉPUISÉ'), findsOneWidget);
      expect(sink.written, isEmpty,
          reason: '🔴 un échec a déclenché une écriture');
      expect(tester.takeException(), isNull,
          reason: '🔴 une exception a fui hors du contrôleur (AD-10)');
    });

    testWidgets('un port qui LÈVE ⇒ failed, message injecté, lastFailure null',
        (tester) async {
      final port = _FakePort(throws: true);
      final sink = _InMemorySink();
      await tester.pumpWidget(_sheetApp(port: port, sink: sink));
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      expect(find.text('MSG-UNEXPECTED'), findsOneWidget);
      expect(sink.written, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('G4 — Right([]) ⇒ empty, AUCUNE écriture', () {
    testWidgets('résultat vide : statut empty, message injecté, dépôt à 0',
        (tester) async {
      final port = _FakePort(nodes: const <ZMindmapNode>[]);
      final sink = _InMemorySink();
      await tester.pumpWidget(_sheetApp(port: port, sink: sink));
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-empty')),
        findsOneWidget,
      );
      expect(find.text('MSG-EMPTY'), findsOneWidget);
      expect(sink.written, isEmpty);
      expect(find.byType(ZMindmapOutlineEditor), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-review')),
        findsNothing,
      );
    });
  });

  group('G5 — Right(nodes) ⇒ revue, puis les nœuds ÉDITÉS sont matérialisés',
      () {
    testWidgets('revue montrée avec les nœuds générés', (tester) async {
      await tester.pumpWidget(_sheetApp(
        port: _FakePort(nodes: <ZMindmapNode>[
          ZMindmapNode(id: 'g1', label: 'RACINE-GÉNÉRÉE'),
        ]),
        sink: _InMemorySink(),
      ));
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-review')),
        findsOneWidget,
      );
      // La revue est celle de l'éditeur d'outline existant, pas un rendu
      // parallèle : sa présence est ce qui prouve la composition.
      expect(find.byType(ZMindmapOutlineEditor), findsOneWidget);
      expect(find.widgetWithText(TextField, 'RACINE-GÉNÉRÉE'), findsWidgets);
    });

    testWidgets(
        '🔴 validation APRÈS édition : 1 écriture portant le nœud ÉDITÉ',
        (tester) async {
      final sink = _InMemorySink();
      await tester.pumpWidget(_sheetApp(
        port: _FakePort(nodes: <ZMindmapNode>[
          ZMindmapNode(id: 'g1', label: 'AVANT-ÉDITION'),
        ]),
        sink: sink,
      ));
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      // Mutation RÉELLE dans la revue : valider sans éditer laisserait passer
      // une implémentation qui matérialise la forêt d'ORIGINE.
      await tester.enterText(
          find.widgetWithText(TextField, 'AVANT-ÉDITION'), 'APRÈS-ÉDITION');
      await tester.pump();

      expect(sink.written, isEmpty,
          reason: 'rien ne doit être écrit AVANT la validation');

      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      expect(sink.written, hasLength(1), reason: 'exactement UNE écriture');
      final written = sink.written.single;
      expect(written.folderId, 'f-cible');
      expect(written.id, isEmpty,
          reason: 'aucune identité fabriquée : la persistance la pose');
      expect(written.nodes.map((n) => n.label).toList(),
          equals(<String>['APRÈS-ÉDITION']),
          reason: '🔴 ce sont les nœuds ÉDITÉS qui partent à l\'écriture, '
              'jamais ceux d\'origine');
      // Le flux revient au repos : la revue disparaît, la saisie réapparaît.
      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-review')),
        findsNothing,
      );
    });
  });

  group('G3b/G4b/G5b — machine à états du contrôleur, mesurée directement', () {
    test('Left ⇒ status failed, lastFailure PORTÉ, 0 handoff, aucune levée',
        () async {
      final sink = _InMemorySink();
      final controller = ZMindmapGenerationController(
        port: _FakePort(failure: const ZDomainFailure('QUOTA')),
        folderId: 'f',
        messages: _messages,
        onGenerated: sink.call,
      );
      addTearDown(controller.dispose);
      expect(controller.status, ZMindmapGenerationStatus.idle);

      await controller.generate(const ZMindmapGenerationRequest(content: 'x'));

      expect(controller.status, ZMindmapGenerationStatus.failed);
      expect(controller.lastFailure, isA<ZDomainFailure>());
      expect(controller.lastFailure!.message, 'QUOTA');
      expect(controller.errorMessage, 'QUOTA');
      expect(controller.nodes, isEmpty);
      expect(sink.written, isEmpty);
    });

    test('port qui LÈVE ⇒ failed SANS lastFailure fabriqué, 0 handoff',
        () async {
      final sink = _InMemorySink();
      final controller = ZMindmapGenerationController(
        port: _FakePort(throws: true),
        folderId: 'f',
        messages: _messages,
        onGenerated: sink.call,
      );
      addTearDown(controller.dispose);
      await controller.generate(const ZMindmapGenerationRequest(content: 'x'));
      expect(controller.status, ZMindmapGenerationStatus.failed);
      expect(controller.lastFailure, isNull);
      expect(controller.errorMessage, 'MSG-UNEXPECTED');
      expect(sink.written, isEmpty);
    });

    test('Right([]) ⇒ status empty (JAMAIS failed), 0 handoff', () async {
      final sink = _InMemorySink();
      final controller = ZMindmapGenerationController(
        port: _FakePort(),
        folderId: 'f',
        messages: _messages,
        onGenerated: sink.call,
      );
      addTearDown(controller.dispose);
      await controller.generate(const ZMindmapGenerationRequest(content: 'x'));
      expect(controller.status, ZMindmapGenerationStatus.empty);
      expect(controller.lastFailure, isNull);
      expect(controller.errorMessage, 'MSG-EMPTY');
      expect(sink.written, isEmpty);
    });

    test('Right(nodes) ⇒ reviewing avec les nœuds, puis confirm ⇒ 1 handoff',
        () async {
      final sink = _InMemorySink();
      final controller = ZMindmapGenerationController(
        port: _FakePort(
            nodes: <ZMindmapNode>[ZMindmapNode(id: 'g1', label: 'GÉNÉRÉ')]),
        folderId: 'f-cible',
        messages: _messages,
        onGenerated: sink.call,
        title: 'T',
      );
      addTearDown(controller.dispose);
      await controller.generate(const ZMindmapGenerationRequest(content: 'x'));
      expect(controller.status, ZMindmapGenerationStatus.reviewing);
      expect(controller.nodes.single.label, 'GÉNÉRÉ');
      expect(sink.written, isEmpty, reason: 'la revue n\'écrit rien');

      controller.confirm(
          <ZMindmapNode>[ZMindmapNode(id: 'g1', label: 'ÉDITÉ')]);
      expect(sink.written, hasLength(1));
      expect(sink.written.single.nodes.single.label, 'ÉDITÉ');
      expect(sink.written.single.title, 'T');
      expect(controller.status, ZMindmapGenerationStatus.idle);

      // `confirm` hors `reviewing` est un no-op : aucune seconde écriture.
      controller.confirm(<ZMindmapNode>[ZMindmapNode(id: 'z')]);
      expect(sink.written, hasLength(1));
    });

    test('abandon en vol ⇒ la réponse tardive est ÉCARTÉE, 0 handoff',
        () async {
      final sink = _InMemorySink();
      final controller = ZMindmapGenerationController(
        port: _FakePort(
            nodes: <ZMindmapNode>[ZMindmapNode(id: 'g1', label: 'GÉNÉRÉ')]),
        folderId: 'f',
        messages: _messages,
        onGenerated: sink.call,
      );
      addTearDown(controller.dispose);
      final inFlight =
          controller.generate(const ZMindmapGenerationRequest(content: 'x'));
      controller.abandon();
      await inFlight;
      expect(controller.status, ZMindmapGenerationStatus.idle);
      expect(controller.nodes, isEmpty);
      expect(sink.written, isEmpty);
    });
  });

  group('G6 — routeId transporté VERBATIM', () {
    testWidgets('la route du contrôleur arrive intacte dans la requête',
        (tester) async {
      final port = _FakePort(nodes: <ZMindmapNode>[ZMindmapNode(id: 'g1')]);
      await tester.pumpWidget(
          _sheetApp(port: port, sink: _InMemorySink(), routeId: 'ROUTE-42'));
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      expect(port.received, hasLength(1));
      expect(port.received.single.routeId, 'ROUTE-42',
          reason: '🔴 la route est transportée telle quelle — ni dérivée, '
              'ni préfixée, ni transformée en transport');
    });

    test('une route déjà portée par la requête n\'est JAMAIS réécrite',
        () async {
      final port = _FakePort(nodes: <ZMindmapNode>[ZMindmapNode(id: 'g1')]);
      final controller = ZMindmapGenerationController(
        port: port,
        folderId: 'f',
        messages: _messages,
        routeId: 'ROUTE-DU-CONTRÔLEUR',
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const ZMindmapGenerationRequest(
            content: 'x', routeId: 'ROUTE-DE-L-APPELANT'),
      );
      expect(port.received.single.routeId, 'ROUTE-DE-L-APPELANT');
    });
  });

  group('G7 — granularité : un changement d\'état ne reconstruit pas l\'hôte',
      () {
    testWidgets('l\'hôte construit UNE fois pendant tout le cycle',
        (tester) async {
      final port = _FakePort(nodes: <ZMindmapNode>[ZMindmapNode(id: 'g1')]);
      var hostBuilds = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            hostBuilds++;
            return ZMindmapGenerationSheet(
              port: port,
              folderId: 'f-cible',
              messages: _messages,
              labels: _labels,
            );
          }),
        ),
      ));
      expect(hostBuilds, 1);

      await tester.enterText(
          find.byKey(const ValueKey<String>('z-mindmap-generation-content')),
          'saisie conservée');
      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-review')),
        findsOneWidget,
      );
      expect(hostBuilds, 1,
          reason: '🔴 le cycle de génération a reconstruit la surface HÔTE : '
              'l\'état doit rester dans la tranche du contrôleur (AD-2/SM-1)');
    });

    testWidgets(
        '🔴 la saisie SURVIT au changement d\'état (controller STABLE, SM-1)',
        (tester) async {
      // Un `TextEditingController` recréé au rebuild perdrait le texte ET le
      // focus à chaque notification du contrôleur : c'est le défaut historique
      // que ce socle élimine. La survie du texte est ce qui le mesure.
      await tester.pumpWidget(_sheetApp(
        port: _FakePort(failure: const ZDomainFailure('QUOTA')),
        sink: _InMemorySink(),
      ));
      const key = ValueKey<String>('z-mindmap-generation-content');
      await tester.enterText(find.byKey(key), 'SAISIE-À-CONSERVER');
      await tester.pump();

      await tester.tap(
          find.byKey(const ValueKey<String>('z-mindmap-generation-submit')));
      await tester.pumpAndSettle();

      // Le statut a changé deux fois (generating puis failed) : si le
      // controller de texte était recréé dans `build`, le texte aurait disparu.
      expect(
        find.byKey(const ValueKey<String>('z-mindmap-generation-error')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byKey(key)).controller!.text,
          'SAISIE-À-CONSERVER',
          reason: '🔴 la saisie a été perdue au changement d\'état — '
              'controller recréé dans build() (AD-2/SM-1)');
    });
  });
}
