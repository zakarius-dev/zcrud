// Lot P0-F — assemblage de résumé de note par IA (consommateur de
// `ZNoteSummaryPort`, qui n'en avait aucun).
//
// Ce que ces gardes défendent, et pourquoi elles ont été écrites ainsi :
//
// * INERTIE ABSOLUE (G1) — le recensement de l'arbre de `ZDefaultNoteCard` a
//   été capturé par une sonde AVANT toute modification de la carte, puis figé
//   ci-dessous. Une garde en `<=` ou en `contains` aurait laissé passer l'ajout
//   d'un widget ; l'égalité ORDONNÉE et STRICTE ne le peut pas. La descente est
//   COMPLÈTE : tout l'arbre de la carte appartient à ce paquet ou à Material,
//   il n'y a donc aucune frontière de paquet à respecter ici.
// * ZÉRO ÉCRITURE (G3/G4) — le compteur d'un dépôt EN MÉMOIRE branché sur les
//   deux handoffs est la seule mesure honnête : compter les appels d'une
//   méthode qu'on n'appelle pas prouverait seulement qu'on ne l'appelle pas.
// * TEXTE EXACT (G5) — le texte remis est comparé à l'octet près à celui rendu
//   par le port, blancs de bord compris. La revue est en LECTURE : aucune
//   édition ne peut le transformer, et c'est précisément ce qui est mesuré.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Recensement ORDONNÉ de l'arbre de `ZDefaultNoteCard` **avant** le lot
/// (sonde du 2026-08-29, descente complète). Toute action ajoutée sans port le
/// ferait diverger.
const List<String> _cardCensusBeforeLot = <String>[
  'ZDefaultNoteCard',
  'ZStudyNoteCard',
  'ZStudyToolsItemCard',
  'Semantics',
  'ConstrainedBox',
  'Card',
  'Semantics',
  'Padding',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'Semantics',
  'Padding',
  'Row',
  'ExcludeSemantics',
  'SizedBox',
  'DecoratedBox',
  'Center',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Expanded',
  'Column',
  'Row',
  'Flexible',
  'ExcludeSemantics',
  'Text',
  'RichText',
  'ExcludeSemantics',
  'Text',
  'RichText',
  'Flexible',
  'Padding',
  'Text',
  'RichText',
];

/// Recense l'arbre sous [root], dans l'ordre de visite (descente complète).
List<String> _census(WidgetTester tester, Finder root) {
  final types = <String>[];
  void visit(Element e) {
    types.add(e.widget.runtimeType.toString());
    e.visitChildren(visit);
  }

  visit(tester.element(root));
  return types;
}

/// Port de résumé contrôlé par le test : capture les requêtes reçues et rend
/// exactement ce que le scénario demande (y compris une LEVÉE, ou une réponse
/// différée pilotée par un `Completer`).
class _FakePort implements ZNoteSummaryPort {
  _FakePort({
    this.summary = 'RÉSUMÉ',
    this.failure,
    this.throws = false,
    this.gate,
  });

  final String summary;
  final ZFailure? failure;
  final bool throws;

  /// Quand il est fourni, la réponse n'arrive qu'une fois ce jeton complété :
  /// c'est ce qui rend la fenêtre « requête en vol » observable.
  final Completer<void>? gate;

  final List<ZNoteSummaryRequest> received = <ZNoteSummaryRequest>[];

  @override
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request) async {
    received.add(request);
    final g = gate;
    if (g != null) await g.future;
    if (throws) throw StateError('port en panne');
    final f = failure;
    if (f != null) return Left<ZFailure, String>(f);
    return Right<ZFailure, String>(summary);
  }
}

/// Dépôt EN MÉMOIRE branché sur les DEUX handoffs : c'est lui qui compte les
/// écritures. Aucune écriture ne peut se produire sans passer par ce compteur.
class _InMemorySink {
  final List<String> inserted = <String>[];
  final List<String> created = <String>[];

  int get total => inserted.length + created.length;

  void insert(String s) => inserted.add(s);

  void create(String s) => created.add(s);
}

const ZNoteSummaryMessages _messages = ZNoteSummaryMessages(
  unexpectedError: 'MSG-UNEXPECTED',
  emptyResult: 'MSG-EMPTY',
);

const ZNoteSummaryLabels _labels = ZNoteSummaryLabels(
  contentLabel: 'L-CONTENT',
  contentHint: 'L-CONTENT-HINT',
  summarizeLabel: 'L-SUMMARIZE',
  summarizingLabel: 'L-SUMMARIZING',
  reviewTitle: 'L-REVIEW',
  insertAtTopLabel: 'L-INSERT',
  createNoteLabel: 'L-CREATE',
);

Widget _cardApp({
  ZNoteSummaryPort? port,
  void Function(ZNoteSummaryPort port)? onSummarize,
  String? summarizeSemanticLabel,
  Widget? trailing,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZDefaultNoteCard(
        title: 'T-NOTE',
        subtitle: 'S-NOTE',
        excerpt: 'E-NOTE',
        trailing: trailing,
        summaryPort: port,
        onSummarize: onSummarize,
        summarizeSemanticLabel: summarizeSemanticLabel,
      ),
    ),
  );
}

Widget _sheetApp({
  required ZNoteSummaryPort port,
  required _InMemorySink sink,
  String initialContent = '',
  int? maxLength,
  String? languageTag,
  Map<String, dynamic> requestExtra = const <String, dynamic>{},
  bool insertable = true,
  bool creatable = true,
  ZNoteSummaryTextBuilder? summaryBuilder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZNoteSummarySheet(
        port: port,
        messages: _messages,
        labels: _labels,
        initialContent: initialContent,
        maxLength: maxLength,
        languageTag: languageTag,
        requestExtra: requestExtra,
        summaryBuilder: summaryBuilder,
        onInsertAtTop: insertable ? sink.insert : null,
        onCreateNote: creatable ? sink.create : null,
      ),
    ),
  );
}

void main() {
  group('G1 — INERTIE ABSOLUE de la carte sans port', () {
    testWidgets('arbre STRICTEMENT identique au recensement d\'avant le lot',
        (tester) async {
      await tester.pumpWidget(_cardApp());
      await tester.pumpAndSettle();

      expect(
        _census(tester, find.byType(ZDefaultNoteCard)),
        equals(_cardCensusBeforeLot),
        reason: '🔴 la carte rend un arbre DIFFÉRENT de celui d\'avant le lot '
            'alors qu\'aucun port n\'est fourni : le défaut passif exige une '
            'inertie ABSOLUE, pas « à peu près la même chose ».',
      );
    });

    testWidgets('même nombre d\'actions : aucune', (tester) async {
      await tester.pumpWidget(_cardApp());
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsNothing);
      expect(find.byKey(ZDefaultNoteCard.summarizeActionKey), findsNothing);
    });

    testWidgets(
        'port SEUL (sans rappel ni libellé) ⇒ action toujours ABSENTE',
        (tester) async {
      // Les trois maillons sont indissociables : une action sans rappel serait
      // un no-op, sans libellé elle serait muette.
      await tester.pumpWidget(_cardApp(port: _FakePort()));
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsNothing);
      expect(
        _census(tester, find.byType(ZDefaultNoteCard)),
        equals(_cardCensusBeforeLot),
      );
    });

    testWidgets(
        'un `trailing` d\'hôte traverse SANS rangée interposée',
        (tester) async {
      // Sans port, `trailing` doit arriver TEL QUEL à la carte de base : une
      // `Row` interposée « au cas où » serait déjà une régression de rendu.
      await tester.pumpWidget(_cardApp(
        trailing: const Icon(Icons.more_horiz, key: ValueKey<String>('HOST')),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('HOST')), findsOneWidget);
      final rows = _census(tester, find.byType(ZDefaultNoteCard))
          .where((t) => t == 'Row')
          .length;
      expect(rows, _cardCensusBeforeLot.where((t) => t == 'Row').length,
          reason: '🔴 une rangée a été interposée alors qu\'aucune action '
              'n\'est montée');
    });
  });

  group('G2 — port CÂBLÉ ⇒ action PRÉSENTE', () {
    testWidgets('paramètre : action montée, libellé annoncé, port remis au tap',
        (tester) async {
      final port = _FakePort();
      final handed = <ZNoteSummaryPort>[];
      await tester.pumpWidget(_cardApp(
        port: port,
        onSummarize: handed.add,
        summarizeSemanticLabel: 'L-SUMMARIZE-ACTION',
      ));
      await tester.pumpAndSettle();

      final action = find.byKey(ZDefaultNoteCard.summarizeActionKey);
      expect(action, findsOneWidget);
      // Une action au lieu de zéro : c'est la différence EXACTE avec l'inertie.
      expect(find.byType(IconButton), findsOneWidget);
      expect(
        _census(tester, find.byType(ZDefaultNoteCard)),
        isNot(equals(_cardCensusBeforeLot)),
        reason: 'sonde : sans divergence d\'arbre ici, G1 serait infalsifiable',
      );
      expect(find.byTooltip('L-SUMMARIZE-ACTION'), findsOneWidget);
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
            body: ZNoteSummaryScope(
              port: port,
              child: ZDefaultNoteCard(
                title: 'T-NOTE',
                onSummarize: (_) {},
                summarizeSemanticLabel: 'L-SUMMARIZE-ACTION',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultNoteCard.summarizeActionKey), findsOneWidget);
    });

    testWidgets('l\'action de l\'hôte SURVIT à l\'ajout de la nôtre',
        (tester) async {
      // L'action du socle s'AJOUTE : elle ne remplace pas le créneau de l'hôte.
      await tester.pumpWidget(_cardApp(
        port: _FakePort(),
        onSummarize: (_) {},
        summarizeSemanticLabel: 'L-SUMMARIZE-ACTION',
        trailing: const Icon(Icons.more_horiz, key: ValueKey<String>('HOST')),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('HOST')), findsOneWidget);
      expect(find.byKey(ZDefaultNoteCard.summarizeActionKey), findsOneWidget);
    });
  });

  group('G3 — Left ⇒ failed, AUCUNE levée, AUCUN handoff', () {
    testWidgets('le message du ZFailure est annoncé, le dépôt reste à 0',
        (tester) async {
      final port = _FakePort(failure: const ZDomainFailure('QUOTA-ÉPUISÉ'));
      final sink = _InMemorySink();
      await tester.pumpWidget(_sheetApp(port: port, sink: sink));

      await tester.enterText(
          find.byKey(const ValueKey<String>('z-note-summary-content')),
          'source');
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('z-note-summary-error')),
          findsOneWidget);
      expect(find.text('QUOTA-ÉPUISÉ'), findsOneWidget);
      expect(sink.total, 0, reason: '🔴 un échec a déclenché une écriture');
      expect(tester.takeException(), isNull,
          reason: '🔴 une exception a fui hors du contrôleur (AD-10)');
      // Aucune issue n'est offerte : il n'y a rien à remettre.
      expect(find.byKey(const ValueKey<String>('z-note-summary-insert')),
          findsNothing);
    });

    testWidgets('un port qui LÈVE ⇒ failed, message injecté, lastFailure null',
        (tester) async {
      final sink = _InMemorySink();
      await tester
          .pumpWidget(_sheetApp(port: _FakePort(throws: true), sink: sink));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(find.text('MSG-UNEXPECTED'), findsOneWidget);
      expect(sink.total, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('G4 — Right(\'\') ⇒ empty, AUCUN handoff', () {
    testWidgets('résultat vide : statut empty, message injecté, dépôt à 0',
        (tester) async {
      final sink = _InMemorySink();
      await tester.pumpWidget(_sheetApp(port: _FakePort(summary: ''), sink: sink));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('z-note-summary-empty')),
          findsOneWidget);
      expect(find.text('MSG-EMPTY'), findsOneWidget);
      expect(sink.total, 0);
      expect(find.byKey(const ValueKey<String>('z-note-summary-review')),
          findsNothing);
      expect(find.byKey(const ValueKey<String>('z-note-summary-insert')),
          findsNothing);
    });

    test('un résumé fait de BLANCS est vide, pas « à revoir »', () async {
      final sink = _InMemorySink();
      final controller = ZNoteSummaryController(
        port: _FakePort(summary: '   \n  '),
        messages: _messages,
        onInsertAtTop: sink.insert,
        onCreateNote: sink.create,
      );
      addTearDown(controller.dispose);
      await controller.generate(const ZNoteSummaryRequest(content: 'x'));
      expect(controller.status, ZNoteSummaryStatus.empty);
      expect(controller.summary, isEmpty);
      expect(sink.total, 0);
    });
  });

  group('G5 — Right(texte) ⇒ revue, puis DEUX issues remises à l\'hôte', () {
    testWidgets('la revue montre le texte produit', (tester) async {
      await tester.pumpWidget(_sheetApp(
        port: _FakePort(summary: 'RÉSUMÉ-PRODUIT'),
        sink: _InMemorySink(),
      ));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('z-note-summary-review')),
          findsOneWidget);
      expect(find.text('RÉSUMÉ-PRODUIT'), findsOneWidget);
      expect(find.text('L-REVIEW'), findsOneWidget);
    });

    testWidgets(
        '🔴 « insérer en tête » ⇒ UN handoff, avec le texte EXACT du port',
        (tester) async {
      // Blancs de bord VOLONTAIRES : la revue est en lecture, le texte remis
      // est celui du port à l'octet près — ni rogné, ni reformaté.
      const produced = '  RÉSUMÉ-À-INSÉRER\nligne 2  ';
      final sink = _InMemorySink();
      await tester.pumpWidget(
          _sheetApp(port: _FakePort(summary: produced), sink: sink));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(sink.total, 0, reason: 'rien n\'est remis AVANT le geste');

      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-insert')));
      await tester.pumpAndSettle();

      expect(sink.inserted, hasLength(1), reason: 'exactement UN handoff');
      expect(sink.inserted.single, produced,
          reason: '🔴 le texte remis n\'est pas celui du port');
      expect(sink.created, isEmpty,
          reason: '🔴 les deux issues sont EXCLUSIVES par geste');
      // Le flux revient au repos : la revue disparaît, la saisie réapparaît.
      expect(find.byKey(const ValueKey<String>('z-note-summary-review')),
          findsNothing);
    });

    testWidgets('« nouvelle note » ⇒ UN handoff sur l\'autre canal',
        (tester) async {
      final sink = _InMemorySink();
      await tester.pumpWidget(
          _sheetApp(port: _FakePort(summary: 'RÉSUMÉ-NOUVELLE'), sink: sink));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-create')));
      await tester.pumpAndSettle();

      expect(sink.created, equals(<String>['RÉSUMÉ-NOUVELLE']));
      expect(sink.inserted, isEmpty);
    });

    testWidgets('une issue SANS handoff est ABSENTE, jamais inerte',
        (tester) async {
      await tester.pumpWidget(_sheetApp(
        port: _FakePort(),
        sink: _InMemorySink(),
        insertable: false,
      ));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('z-note-summary-insert')),
          findsNothing);
      expect(find.byKey(const ValueKey<String>('z-note-summary-create')),
          findsOneWidget);
    });

    testWidgets('le slot de rendu injecté REMPLACE le texte brut',
        (tester) async {
      // `zcrud_study` ne dépend d'aucun moteur de rich-text : la lecture
      // Markdown passe par ce slot, fourni par l'application.
      await tester.pumpWidget(_sheetApp(
        port: _FakePort(summary: 'RÉSUMÉ-RICHE'),
        sink: _InMemorySink(),
        summaryBuilder: (context, summary) => Text(
          'RENDU:$summary',
          key: const ValueKey<String>('HOST-RENDER'),
        ),
      ));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('HOST-RENDER')), findsOneWidget);
      expect(find.text('RENDU:RÉSUMÉ-RICHE'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('z-note-summary-text')),
          findsNothing);
    });
  });

  group('G6 — machine à états du contrôleur, mesurée directement', () {
    test('Left ⇒ status failed, lastFailure PORTÉ, 0 handoff, aucune levée',
        () async {
      final sink = _InMemorySink();
      final controller = ZNoteSummaryController(
        port: _FakePort(failure: const ZDomainFailure('QUOTA')),
        messages: _messages,
        onInsertAtTop: sink.insert,
        onCreateNote: sink.create,
      );
      addTearDown(controller.dispose);
      expect(controller.status, ZNoteSummaryStatus.idle);

      await controller.generate(const ZNoteSummaryRequest(content: 'x'));

      expect(controller.status, ZNoteSummaryStatus.failed);
      expect(controller.lastFailure, isA<ZDomainFailure>());
      expect(controller.lastFailure!.message, 'QUOTA');
      expect(controller.errorMessage, 'QUOTA');
      expect(controller.summary, isEmpty);
      expect(sink.total, 0);
    });

    test('port qui LÈVE ⇒ failed SANS lastFailure fabriqué, 0 handoff',
        () async {
      final sink = _InMemorySink();
      final controller = ZNoteSummaryController(
        port: _FakePort(throws: true),
        messages: _messages,
        onInsertAtTop: sink.insert,
        onCreateNote: sink.create,
      );
      addTearDown(controller.dispose);
      await controller.generate(const ZNoteSummaryRequest(content: 'x'));
      expect(controller.status, ZNoteSummaryStatus.failed);
      expect(controller.lastFailure, isNull);
      expect(controller.errorMessage, 'MSG-UNEXPECTED');
      expect(sink.total, 0);
    });

    test('une issue hors `reviewing` est un NO-OP', () async {
      final sink = _InMemorySink();
      final controller = ZNoteSummaryController(
        port: _FakePort(summary: 'R'),
        messages: _messages,
        onInsertAtTop: sink.insert,
        onCreateNote: sink.create,
      );
      addTearDown(controller.dispose);
      controller.insertAtTop();
      controller.createNote();
      expect(sink.total, 0);

      await controller.generate(const ZNoteSummaryRequest(content: 'x'));
      expect(controller.status, ZNoteSummaryStatus.reviewing);
      controller.insertAtTop();
      expect(sink.inserted, equals(<String>['R']));
      // Second appel APRÈS retour à `idle` : aucun handoff supplémentaire.
      controller.insertAtTop();
      controller.createNote();
      expect(sink.total, 1);
    });

    test('abandon en vol ⇒ la réponse tardive est ÉCARTÉE, 0 handoff',
        () async {
      final sink = _InMemorySink();
      final controller = ZNoteSummaryController(
        port: _FakePort(summary: 'R'),
        messages: _messages,
        onInsertAtTop: sink.insert,
        onCreateNote: sink.create,
      );
      addTearDown(controller.dispose);
      final inFlight =
          controller.generate(const ZNoteSummaryRequest(content: 'x'));
      controller.abandon();
      await inFlight;
      expect(controller.status, ZNoteSummaryStatus.idle);
      expect(controller.summary, isEmpty);
      expect(sink.total, 0);
    });
  });

  group('G7 — `summarize` appelé UNE seule fois par geste', () {
    testWidgets('deux taps pendant la requête en vol ⇒ UNE requête',
        (tester) async {
      final gate = Completer<void>();
      final port = _FakePort(summary: 'R', gate: gate);
      await tester
          .pumpWidget(_sheetApp(port: port, sink: _InMemorySink()));

      const submit = ValueKey<String>('z-note-summary-submit');
      await tester.tap(find.byKey(submit));
      await tester.pump();
      // Le bouton est désarmé pendant la requête ; le contrôleur ignore de
      // toute façon toute seconde soumission (double verrou mesuré ici).
      expect(
        tester.widget<ElevatedButton>(find.byKey(submit)).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(submit), warnIfMissed: false);
      await tester.pump();

      expect(port.received, hasLength(1),
          reason: '🔴 un second appel du port a été émis pour un seul geste');

      gate.complete();
      await tester.pumpAndSettle();
      expect(port.received, hasLength(1));
    });

    test('anti-double-soumission mesurée sur le contrôleur seul', () async {
      final gate = Completer<void>();
      final port = _FakePort(summary: 'R', gate: gate);
      final controller = ZNoteSummaryController(
        port: port,
        messages: _messages,
      );
      addTearDown(controller.dispose);
      final first = controller.generate(const ZNoteSummaryRequest(content: 'a'));
      final second =
          controller.generate(const ZNoteSummaryRequest(content: 'b'));
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(port.received, hasLength(1));
      expect(port.received.single.content, 'a');
    });
  });

  group('G8 — la requête voyage VERBATIM', () {
    testWidgets('contenu, longueur cible, langue et extra arrivent intacts',
        (tester) async {
      // `ZNoteSummaryRequest` ne porte AUCUN identifiant de route : il n'y a
      // donc rien à transporter de ce côté, et rien n'en est fabriqué. Ce qui
      // EST porté doit arriver tel quel — c'est ce que mesure cette garde.
      final port = _FakePort();
      await tester.pumpWidget(_sheetApp(
        port: port,
        sink: _InMemorySink(),
        initialContent: 'CONTENU-INITIAL',
        maxLength: 140,
        languageTag: 'fr-CI',
        requestExtra: const <String, dynamic>{'canal': 'VALEUR-OPAQUE'},
      ));
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(port.received, hasLength(1));
      final sent = port.received.single;
      expect(sent.content, 'CONTENU-INITIAL');
      expect(sent.maxLength, 140);
      expect(sent.languageTag, 'fr-CI');
      expect(sent.extra['canal'], 'VALEUR-OPAQUE',
          reason: '🔴 l\'échappatoire est transportée telle quelle');
    });

    test('les clés de synchronisation réservées sont écartées de `extra`', () {
      const request = ZNoteSummaryRequest(
        content: 'x',
        extra: <String, dynamic>{'updated_at': 'X', 'canal': 'OK'},
      );
      expect(request.extra.containsKey('updated_at'), isFalse);
      expect(request.extra['canal'], 'OK');
    });
  });

  group('G9 — granularité : un changement d\'état ne reconstruit pas l\'hôte',
      () {
    testWidgets('l\'hôte construit UNE fois pendant tout le cycle',
        (tester) async {
      var hostBuilds = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            hostBuilds++;
            return ZNoteSummarySheet(
              port: _FakePort(summary: 'R'),
              messages: _messages,
              labels: _labels,
            );
          }),
        ),
      ));
      expect(hostBuilds, 1);

      await tester.enterText(
          find.byKey(const ValueKey<String>('z-note-summary-content')),
          'saisie conservée');
      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('z-note-summary-review')),
          findsOneWidget);
      expect(hostBuilds, 1,
          reason: '🔴 le cycle de résumé a reconstruit la surface HÔTE : '
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
      const key = ValueKey<String>('z-note-summary-content');
      await tester.enterText(find.byKey(key), 'SAISIE-À-CONSERVER');
      await tester.pump();

      await tester
          .tap(find.byKey(const ValueKey<String>('z-note-summary-submit')));
      await tester.pumpAndSettle();

      // Le statut a changé deux fois (summarizing puis failed) : si le
      // controller de texte était recréé dans `build`, le texte aurait disparu.
      expect(find.byKey(const ValueKey<String>('z-note-summary-error')),
          findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(key)).controller!.text,
          'SAISIE-À-CONSERVER',
          reason: '🔴 la saisie a été perdue au changement d\'état — '
              'controller recréé dans build() (AD-2/SM-1)');
    });
  });
}
