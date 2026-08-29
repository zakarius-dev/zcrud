// Lot P1-D — `ZExplanationView` : rendu progressif GRANULAIRE, absence
// structurelle des commandes non offertes, sélecteur de versions, handoff de
// matérialisation.
//
// Runner R14 : `flutter test`. Aucun accès disque.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyExplanation;

const _messages = ZExplanationMessages(
  unexpectedError: 'MSG_INATTENDU',
  emptyResult: 'MSG_VIDE',
);

const _labels = ZExplanationLabels(
  generatingLabel: 'LBL_EN_COURS',
  summarizeLabel: 'LBL_CONDENSER',
  regenerateLabel: 'LBL_REFAIRE',
  elaborateLabel: 'LBL_DEVELOPPER',
  restyleLabel: 'LBL_STYLE',
  previousVersionLabel: 'LBL_PRECEDENTE',
  nextVersionLabel: 'LBL_SUIVANTE',
  versionPosition: _position,
  persistLabel: 'LBL_ENREGISTRER',
);

String _position(int index, int total) => 'POS_$index/$total';

const _operations = ZExplanationOperationKeys(
  summarize: 'OP_CONDENSER',
  regenerate: 'OP_REFAIRE',
  elaborate: 'OP_DEVELOPPER',
  restyle: 'OP_STYLE',
);

class _StubPort implements ZAiExplanationPort {
  final List<ZAiExplanationRequest> seen = <ZAiExplanationRequest>[];

  @override
  Future<ZResult<String>> explain(ZAiExplanationRequest request) async {
    seen.add(request);
    return Right<ZFailure, String>('one-shot:${request.content}');
  }
}

class _ControllablePort implements ZAiExplanationStreamPort {
  late StreamController<ZResult<ZGenerationProgress>> controller;

  @override
  bool get isAvailable => true;

  @override
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  ) {
    controller = StreamController<ZResult<ZGenerationProgress>>();
    return controller.stream;
  }

  void emit(String text, {bool isDone = false}) => controller.add(
        Right<ZFailure, ZGenerationProgress>(
          ZGenerationProgress(text: text, isDone: isDone),
        ),
      );
}

/// Libellés dont le formateur de position COMPTE ses appels.
///
/// Le sélecteur de versions n'est construit que par la reconstruction
/// GÉNÉRALE de la vue (celle branchée sur le contrôleur) : compter ses appels
/// mesure donc exactement ce qu'on veut interdire — qu'un fragment de flux
/// reconstruise autre chose que la tranche de texte.
ZExplanationLabels _countingLabels(List<int> calls) => ZExplanationLabels(
      generatingLabel: 'LBL_EN_COURS',
      summarizeLabel: 'LBL_CONDENSER',
      regenerateLabel: 'LBL_REFAIRE',
      elaborateLabel: 'LBL_DEVELOPPER',
      restyleLabel: 'LBL_STYLE',
      previousVersionLabel: 'LBL_PRECEDENTE',
      nextVersionLabel: 'LBL_SUIVANTE',
      versionPosition: (index, total) {
        calls[0]++;
        return 'POS_$index/$total';
      },
      persistLabel: 'LBL_ENREGISTRER',
    );

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(child: Scaffold(body: child)),
      ),
    );

void main() {
  testWidgets(
    'flux : 3 fragments ⇒ texte cumulé EXACT rendu, et RIEN d\'autre '
    'reconstruit',
    (tester) async {
      final stream = _ControllablePort();
      final c = ZExplanationController(
        port: _StubPort(),
        messages: _messages,
        streamPort: stream,
        initialVersions: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
          ZExplanationVersion(text: 'V2'),
        ],
      );
      addTearDown(c.dispose);
      final calls = <int>[0];
      await tester.pumpWidget(
        _wrap(ZExplanationView(controller: c, labels: _countingLabels(calls))),
      );

      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await tester.pump();
      await tester.pump();
      // Le passage en `generating` est UNE reconstruction générale légitime :
      // c'est le point de référence, tout ce qui suit doit être immobile.
      final callsAtStart = calls[0];

      stream.emit('Le ');
      await tester.pump();
      await tester.pump();
      stream.emit('Le chat ');
      await tester.pump();
      await tester.pump();
      stream.emit('Le chat dort.');
      await tester.pump();
      await tester.pump();

      expect(find.text('Le chat dort.'), findsOneWidget);
      expect(calls[0], callsAtStart,
          reason: 'aucun fragment ne reconstruit la vue GÉNÉRALE : seule la '
              'tranche cumulative est écoutée');
      // Fermeture NON attendue : sous `testWidgets`, l'horloge est simulée et
      // attendre un futur de flux gèlerait le test.
      stream.controller.close().ignore();
      await tester.pump();
      await tester.pump();
      expect(find.text('Le chat dort.'), findsOneWidget);
      expect(c.versions, hasLength(3));
    },
  );

  testWidgets('slot de rendu riche INJECTÉ : le texte brut par défaut cède',
      (tester) async {
    final c = ZExplanationController(
      port: _StubPort(),
      messages: _messages,
      initialVersions: const <ZExplanationVersion>[
        ZExplanationVersion(text: 'CONTENU'),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _wrap(
        ZExplanationView(
          controller: c,
          labels: _labels,
          contentBuilder: (context, text) => Text('RICHE[$text]'),
        ),
      ),
    );
    expect(find.text('RICHE[CONTENU]'), findsOneWidget);
    expect(find.text('CONTENU'), findsNothing);
  });

  testWidgets(
    'commandes ABSENTES sans clé d\'opération, PRÉSENTES avec',
    (tester) async {
      final nude = ZExplanationController(
        port: _StubPort(),
        messages: _messages,
        initialVersions: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
        ],
      );
      addTearDown(nude.dispose);
      await tester.pumpWidget(
        _wrap(ZExplanationView(controller: nude, labels: _labels)),
      );
      expect(find.text('LBL_CONDENSER'), findsNothing);
      expect(find.text('LBL_REFAIRE'), findsNothing);
      expect(find.text('LBL_DEVELOPPER'), findsNothing);
      expect(find.text('LBL_STYLE'), findsNothing);
      expect(find.text('LBL_ENREGISTRER'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('z-explanation-operations')),
        findsNothing,
        reason: 'la barre entière disparaît quand rien n\'est offert',
      );

      final full = ZExplanationController(
        port: _StubPort(),
        messages: _messages,
        operations: _operations,
        initialVersions: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
        ],
      );
      addTearDown(full.dispose);
      await tester.pumpWidget(
        _wrap(
          ZExplanationView(
            controller: full,
            labels: _labels,
            styleOptions: const <ZExplanationStyleOption>[
              ZExplanationStyleOption(key: 'K1', label: 'STYLE_UN'),
            ],
            onPersist: (_) {},
          ),
        ),
      );
      expect(find.text('LBL_CONDENSER'), findsOneWidget);
      expect(find.text('LBL_REFAIRE'), findsOneWidget);
      expect(find.text('LBL_DEVELOPPER'), findsOneWidget);
      expect(find.text('LBL_STYLE'), findsOneWidget);
      expect(find.text('LBL_ENREGISTRER'), findsOneWidget);
    },
  );

  testWidgets(
    'restyle depuis le menu ⇒ requête portant operation ET style VERBATIM',
    (tester) async {
      final port = _StubPort();
      final c = ZExplanationController(
        port: port,
        messages: _messages,
        operations: _operations,
        initialVersions: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
        ],
      );
      addTearDown(c.dispose);
      // Une requête d'origine est nécessaire : sans elle, aucun traitement ne
      // part (rien à re-demander).
      c.explain(const ZAiExplanationRequest(content: 'sujet'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(
          ZExplanationView(
            controller: c,
            labels: _labels,
            styleOptions: const <ZExplanationStyleOption>[
              ZExplanationStyleOption(key: 'STYLE_HOTE_42', label: 'STYLE_UN'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('LBL_STYLE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('STYLE_UN').last);
      await tester.pumpAndSettle();

      expect(port.seen, hasLength(2));
      expect(port.seen.last.operation, 'OP_STYLE');
      expect(port.seen.last.style, 'STYLE_HOTE_42');
    },
  );

  testWidgets('sélecteur de versions : absent à une version, actif à deux',
      (tester) async {
    final one = ZExplanationController(
      port: _StubPort(),
      messages: _messages,
      initialVersions: const <ZExplanationVersion>[
        ZExplanationVersion(text: 'V1'),
      ],
    );
    addTearDown(one.dispose);
    await tester.pumpWidget(
      _wrap(ZExplanationView(controller: one, labels: _labels)),
    );
    expect(
      find.byKey(const ValueKey<String>('z-explanation-versions')),
      findsNothing,
    );

    final two = ZExplanationController(
      port: _StubPort(),
      messages: _messages,
      initialVersions: const <ZExplanationVersion>[
        ZExplanationVersion(text: 'V1'),
        ZExplanationVersion(text: 'V2'),
      ],
    );
    addTearDown(two.dispose);
    await tester.pumpWidget(
      _wrap(ZExplanationView(controller: two, labels: _labels)),
    );
    expect(find.text('POS_2/2'), findsOneWidget);
    expect(find.text('V2'), findsOneWidget);

    await tester.tap(find.text('LBL_PRECEDENTE'));
    await tester.pump();
    expect(find.text('POS_1/2'), findsOneWidget);
    expect(find.text('V1'), findsOneWidget,
        reason: '`select` restaure la version EXACTE');
    expect(find.text('V2'), findsNothing);
  });

  testWidgets('handoff onPersist : entité CONSTRUITE, jamais enregistrée ici',
      (tester) async {
    ZStudyExplanation? handed;
    final c = ZExplanationController(
      port: _StubPort(),
      messages: _messages,
      initialVersions: const <ZExplanationVersion>[
        ZExplanationVersion(text: 'V1', style: 'S1', operation: 'O1'),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _wrap(
        ZExplanationView(
          controller: c,
          labels: _labels,
          folderId: 'DOSSIER_7',
          relatedTopics: const <String>['T1', 'T2'],
          onPersist: (explanation) => handed = explanation,
        ),
      ),
    );
    await tester.tap(find.text('LBL_ENREGISTRER'));
    await tester.pump();

    expect(handed, isNotNull);
    expect(handed!.folderId, 'DOSSIER_7');
    expect(handed!.content, 'V1');
    expect(handed!.style, 'S1');
    expect(handed!.operation, 'O1');
    expect(handed!.relatedTopics, <String>['T1', 'T2']);
    expect(handed!.id, isNull, reason: 'rien n\'est écrit : aucune identité');
  });

  testWidgets('A11y : toute commande rendue tient la cible de 48 dp, en RTL '
      'comme en LTR', (tester) async {
    for (final dir in <TextDirection>[
      TextDirection.ltr,
      TextDirection.rtl,
    ]) {
      final c = ZExplanationController(
        port: _StubPort(),
        messages: _messages,
        operations: _operations,
        initialVersions: const <ZExplanationVersion>[
          ZExplanationVersion(text: 'V1'),
          ZExplanationVersion(text: 'V2'),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _wrap(
          ZExplanationView(
            controller: c,
            labels: _labels,
            onPersist: (_) {},
          ),
          dir: dir,
        ),
      );
      for (final key in <String>[
        'z-explanation-previous',
        'z-explanation-next',
        'z-explanation-summarize',
        'z-explanation-elaborate',
        'z-explanation-regenerate',
        'z-explanation-persist',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey<String>(key)));
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: '$key sous la cible de 48 dp en $dir');
      }
    }
  });

  testWidgets('échec annoncé en liveRegion, sans quitter la surface',
      (tester) async {
    final stream = _ControllablePort();
    final c = ZExplanationController(
      port: _StubPort(),
      messages: _messages,
      streamPort: stream,
      initialVersions: const <ZExplanationVersion>[
        ZExplanationVersion(text: 'V1'),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _wrap(ZExplanationView(controller: c, labels: _labels)),
    );
    c.explain(const ZAiExplanationRequest(content: 'sujet'));
    await tester.pump();
    expect(find.text('LBL_EN_COURS'), findsOneWidget);

    stream.controller.add(
      Left<ZFailure, ZGenerationProgress>(const ZDomainFailure('refus')),
    );
    // Deux frames : la livraison de l'événement de flux tombe dans l'espace
    // asynchrone de la première, la reconstruction est donc rendue par la
    // seconde.
    await tester.pump();
    await tester.pump();
    expect(find.text('refus'), findsOneWidget);
    expect(find.text('V1'), findsOneWidget,
        reason: 'la version courante reste affichée après un échec');
    stream.controller.close().ignore();
  });
}
