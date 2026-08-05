// CR-IFFD-70 — la feuille de génération PREND sa source sur place :
// * CHOISIR parmi les sources du contexte (multi-sélection, résolution À LA
//   DEMANDE — jamais à l'ouverture, SM-1) ;
// * ACQUÉRIR pendant la génération (gestes injectés par l'hôte, le paramétrage
//   saisi SURVIT — garde dédiée) ;
// * CHAÎNE DE REPLI TOTALE : l'hôte passif rend EXACTEMENT la feuille
//   d'aujourd'hui (garde dédiée, géométrie mesurée) ;
// * tout échec (résolution, acquisition) ⇒ `Left(ZFailure)` affiché, feuille
//   utilisable (AD-5/AD-10).
// Runner : `flutter test` DEPUIS packages/zcrud_study.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _messages = ZFlashcardGenerationMessages(
  unexpectedError: 'ERREUR',
  emptyResult: 'VIDE',
);

const _labels = ZFlashcardGenerationLabels(
  contentLabel: 'Contenu',
  contentHint: 'Coller le texte',
  countLabel: 'Nombre',
  instructionsLabel: 'Instructions',
  instructionsHint: 'Facultatif',
  modelIdLabel: 'Modèle',
  modelIdHint: 'Optionnel',
  sourceLabel: 'Source',
  generateLabel: 'Générer',
  generatingLabel: 'Génération…',
  proceedToTagsLabel: 'Confirmer les tags',
  previewTitle: 'Aperçu',
  typeLabels: <ZFlashcardType, String>{},
  tagConfirmTitle: 'Tags proposés',
  tagConfirmApply: 'Confirmer',
  tagConfirmCancel: 'Annuler',
  tagInputLabel: 'Nom du tag',
  tagInputHint: 'Ajouter un tag',
  tagAddSemanticLabel: 'Ajouter le tag',
  contextSourcesLabel: 'Sources du dossier',
);

class _FakePort implements ZFlashcardGenerationPort {
  ZFlashcardGenerationRequest? lastRequest;
  int calls = 0;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
      ZFlashcardGenerationRequest r) {
    calls++;
    lastRequest = r;
    return Future<ZResult<List<ZFlashcard>>>.value(
      Right<ZFailure, List<ZFlashcard>>(
        <ZFlashcard>[const ZFlashcard(question: 'Q', answer: 'A')],
      ),
    );
  }
}

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 900, height: 1400, child: child)),
    );

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _submit(WidgetTester tester) async {
  final submit = _key('z-generation-submit');
  await tester.ensureVisible(submit);
  await tester.pump();
  await tester.tap(submit);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('CR-70 §3 — CHAÎNE DE REPLI TOTALE : l\'hôte passif ne bouge pas', () {
    testWidgets(
        '🔴 sans sources ni gestes : aucune section, aucun bouton, requête sans '
        'resolvedSources — GÉOMÉTRIE identique à la feuille d\'aujourd\'hui',
        (tester) async {
      // Feuille « d'aujourd'hui » (aucun paramètre CR-70).
      final portToday = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: portToday,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
      )));
      final todayContentOffset =
          tester.getTopLeft(_key('z-generation-content'));
      expect(_key('z-generation-context-sources'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing,
          reason: 'aucun geste d\'acquisition ⇒ aucun bouton (jamais grisé)');
      await _submit(tester);
      expect(portToday.lastRequest!.resolvedSources, isNull,
          reason: 'le flux passif ne fabrique JAMAIS de resolvedSources');

      // Feuille avec les paramètres CR-70 EXPLICITEMENT vides (+ libellé posé) :
      // même arbre, même géométrie.
      final portEmpty = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: portEmpty,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: const <ZGenerationSourceOption>[],
        acquisitionGestures: const <ZSourceAcquisitionGesture>[],
      )));
      expect(_key('z-generation-context-sources'), findsNothing);
      expect(find.text('Sources du dossier'), findsNothing,
          reason: 'le libellé de section n\'apparaît pas sans section');
      expect(tester.getTopLeft(_key('z-generation-content')),
          todayContentOffset,
          reason: 'GÉOMÉTRIE mesurée : le champ de contenu n\'a pas bougé '
              'd\'un pixel pour l\'hôte passif');
    });
  });

  group('CR-70 §1 — CHOISIR sur place, résolution À LA DEMANDE', () {
    testWidgets(
        '🔴 SM-1 : 50 sources présentées ⇒ OUVRIR ne résout RIEN, sélectionner '
        'ne résout RIEN, soumettre ne résout QUE les sélectionnées', (tester) async {
      var resolutions = 0;
      final sources = <ZGenerationSourceOption>[
        for (var i = 0; i < 50; i++)
          ZGenerationSourceOption(
            label: 'Doc $i',
            resolveContent: () async {
              resolutions++;
              return Right<ZFailure, ZResolvedGenerationSource>(
                ZResolvedGenerationSource(text: 'contenu $i'),
              );
            },
          ),
      ];
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: sources,
      )));
      expect(resolutions, 0,
          reason: 'SM-1 : un dossier de 50 documents s\'OUVRE sans rien charger');

      await tester.tap(_key('z-generation-context-source-2'));
      await tester.pump();
      await tester.tap(_key('z-generation-context-source-7'));
      await tester.pump();
      expect(resolutions, 0,
          reason: 'sélectionner n\'est pas résoudre — résolution À LA DEMANDE');

      await _submit(tester);
      expect(resolutions, 2,
          reason: 'seules les 2 sources SÉLECTIONNÉES sont résolues');
      expect(port.lastRequest!.resolvedSources, hasLength(2));
    });

    testWidgets(
        'multi-sélection COMPOSITE : ordre de présentation + provenance de '
        'l\'option estampillée quand le résolveur ne la pose pas', (tester) async {
      final p0 = ZCustomSource('document', const <String, dynamic>{'id': 'd0'});
      final p2self =
          ZCustomSource('note', const <String, dynamic>{'id': 'n2'});
      final sources = <ZGenerationSourceOption>[
        ZGenerationSourceOption(
          label: 'DocZero',
          provenance: p0,
          resolveContent: () async =>
              Right<ZFailure, ZResolvedGenerationSource>(
            const ZResolvedGenerationSource(text: 'T0'),
          ),
        ),
        const ZGenerationSourceOption(label: 'NonChoisi'),
        ZGenerationSourceOption(
          label: 'NoteDeux',
          resolveContent: () async =>
              Right<ZFailure, ZResolvedGenerationSource>(
            ZResolvedGenerationSource(text: 'T2', provenance: p2self),
          ),
        ),
      ];
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: sources,
      )));
      await tester.tap(_key('z-generation-context-source-2'));
      await tester.pump();
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      await _submit(tester);

      final resolved = port.lastRequest!.resolvedSources!;
      expect(resolved, hasLength(2));
      expect(resolved[0].text, 'T0',
          reason: 'ordre de PRÉSENTATION, pas ordre de sélection');
      expect(resolved[0].provenance, p0,
          reason: 'provenance de l\'option estampillée sur la source résolue');
      expect(resolved[1].text, 'T2');
      expect(resolved[1].provenance, p2self,
          reason: 'la provenance posée par le résolveur PRIME (jamais écrasée)');
    });

    testWidgets(
        'source PAR RÉFÉRENCE (aucun résolveur) : la provenance porte la '
        'référence — couvre le legacy …FromWholeDocument', (tester) async {
      final docRef =
          ZCustomSource('document', const <String, dynamic>{'id': 'doc-300p'});
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: <ZGenerationSourceOption>[
          ZGenerationSourceOption(label: 'Tout le document', provenance: docRef),
        ],
      )));
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      await _submit(tester);

      final resolved = port.lastRequest!.resolvedSources!;
      expect(resolved, hasLength(1));
      expect(resolved.single.text, isNull);
      expect(resolved.single.pagesContents, isNull);
      expect(resolved.single.provenance, docRef,
          reason: 'forme PAR RÉFÉRENCE : l\'impl du port extrait côté serveur');
    });

    testWidgets(
        'source VOLUMINEUSE : résolution PARTIELLE paginée (pages choisies '
        'seulement — la forme du legacy)', (tester) async {
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: <ZGenerationSourceOption>[
          ZGenerationSourceOption(
            label: 'PDF 300 pages',
            resolveContent: () async =>
                Right<ZFailure, ZResolvedGenerationSource>(
              const ZResolvedGenerationSource(
                pagesContents: <int, String>{3: 'page 3', 7: 'page 7'},
              ),
            ),
          ),
        ],
      )));
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      await _submit(tester);

      final pages = port.lastRequest!.resolvedSources!.single.pagesContents!;
      expect(pages.keys, unorderedEquals(<int>[3, 7]),
          reason: 'EXACTEMENT les pages choisies — jamais tout le document');
    });

    testWidgets(
        '🔴 échec de résolution (fichier illisible) ⇒ Left affiché, saisie '
        'préservée, la feuille RESTE utilisable', (tester) async {
      var broken = true;
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: <ZGenerationSourceOption>[
          ZGenerationSourceOption(
            label: 'DocFragile',
            resolveContent: () async => broken
                ? Left<ZFailure, ZResolvedGenerationSource>(
                    const ZServerFailure('illisible'))
                : Right<ZFailure, ZResolvedGenerationSource>(
                    const ZResolvedGenerationSource(text: 'réparé')),
          ),
        ],
      )));
      await tester.enterText(_key('z-generation-content'), 'gardé');
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      await _submit(tester);

      expect(find.text('illisible'), findsOneWidget,
          reason: 'le message du ZFailure (AD-5) — jamais un throw');
      expect(tester.takeException(), isNull);
      expect(find.text('gardé'), findsOneWidget, reason: 'saisie préservée');
      expect(port.calls, 0,
          reason: 'le port n\'est JAMAIS appelé sur une résolution échouée');

      // La feuille reste utilisable : la même session re-soumet et aboutit.
      broken = false;
      await _submit(tester);
      expect(find.byType(ZFlashcardPreview), findsOneWidget,
          reason: 'après réparation, la MÊME feuille génère (aucun état bloqué)');
    });

    testWidgets('résolveur qui LÈVE ⇒ capté (AD-10), message injecté, pas de '
        'crash', (tester) async {
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: <ZGenerationSourceOption>[
          ZGenerationSourceOption(
            label: 'DocToxique',
            resolveContent: () async => throw StateError('boom'),
          ),
        ],
      )));
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      await _submit(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('ERREUR'), findsOneWidget);
      expect(port.calls, 0);
    });
  });

  group('CR-70 §2 — ACQUÉRIR sur place, sans rompre le flux', () {
    ZSourceAcquisitionGesture gesture(
      Future<ZResult<ZGenerationSourceOption?>> Function() acquire, {
      String label = 'Uploader',
    }) =>
        ZSourceAcquisitionGesture(label: label, acquire: acquire);

    testWidgets(
        '🔴 garde dédiée : le PARAMÉTRAGE SAISI SURVIT à l\'acquisition '
        '(saisit → acquiert → vérifie), la source acquise est pré-sélectionnée '
        'et part dans la requête', (tester) async {
      final acquired = ZGenerationSourceOption(
        label: 'ScanAcquis',
        resolveContent: () async => Right<ZFailure, ZResolvedGenerationSource>(
          const ZResolvedGenerationSource(text: 'CONTENU-ACQUIS'),
        ),
      );
      final port = _FakePort();
      final firstType = ZFlashcardType.values.first;
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: const <ZGenerationSourceOption>[],
        acquisitionGestures: <ZSourceAcquisitionGesture>[
          gesture(() async =>
              Right<ZFailure, ZGenerationSourceOption?>(acquired)),
        ],
      )));

      // SAISIT : contenu + instructions + modelId + un type DÉSÉLECTIONNÉ.
      await tester.enterText(_key('z-generation-content'), 'garde-contenu');
      await tester.enterText(
          _key('z-generation-instructions'), 'garde-instructions');
      await tester.enterText(_key('z-generation-model-id'), 'garde-modele');
      await tester.tap(find.text(firstType.name));
      await tester.pump();

      // ACQUIERT.
      await tester.tap(_key('z-generation-acquire-0'));
      await tester.pump();
      await tester.pump();

      // VÉRIFIE : rien de la saisie n'a bougé.
      expect(find.text('garde-contenu'), findsOneWidget);
      expect(find.text('garde-instructions'), findsOneWidget);
      expect(find.text('garde-modele'), findsOneWidget);
      final typeChip = tester.widget<FilterChip>(find.ancestor(
        of: find.text(firstType.name),
        matching: find.byType(FilterChip),
      ));
      expect(typeChip.selected, isFalse,
          reason: 'le type désélectionné RESTE désélectionné après acquisition');
      final acquiredChip = tester
          .widget<FilterChip>(_key('z-generation-context-source-0'));
      expect(acquiredChip.selected, isTrue,
          reason: 'la source acquise est utilisable dans la MÊME session, '
              'pré-sélectionnée');

      // Et la requête porte TOUT : saisie + source acquise résolue.
      await _submit(tester);
      final req = port.lastRequest!;
      expect(req.content, 'garde-contenu');
      expect(req.instructions, 'garde-instructions');
      expect(req.modelId, 'garde-modele');
      expect(req.typesDistribution!.containsKey(firstType), isFalse);
      expect(req.resolvedSources!.single.text, 'CONTENU-ACQUIS');
    });

    testWidgets('annulation utilisateur (Right(null)) : rien n\'apparaît, '
        'aucune erreur', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: _FakePort(),
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        acquisitionGestures: <ZSourceAcquisitionGesture>[
          gesture(() async => Right<ZFailure, ZGenerationSourceOption?>(null)),
        ],
      )));
      await tester.tap(_key('z-generation-acquire-0'));
      await tester.pump();
      await tester.pump();
      expect(_key('z-generation-context-source-0'), findsNothing);
      expect(_key('z-generation-acquisition-error'), findsNothing,
          reason: 'annuler n\'est pas échouer');
    });

    testWidgets('🔴 échec d\'acquisition ⇒ Left affiché (liveRegion), la '
        'feuille reste utilisable', (tester) async {
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        acquisitionGestures: <ZSourceAcquisitionGesture>[
          gesture(() async => Left<ZFailure, ZGenerationSourceOption?>(
              const ZServerFailure('scanner en panne'))),
        ],
      )));
      await tester.enterText(_key('z-generation-content'), 'toujours là');
      await tester.tap(_key('z-generation-acquire-0'));
      await tester.pump();
      await tester.pump();
      expect(find.text('scanner en panne'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('toujours là'), findsOneWidget);
      await _submit(tester);
      expect(port.calls, 1,
          reason: 'un échec d\'acquisition ne bloque JAMAIS la génération');
    });

    testWidgets('geste qui LÈVE ⇒ capté (AD-10), message injecté', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: _FakePort(),
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        acquisitionGestures: <ZSourceAcquisitionGesture>[
          gesture(() async => throw StateError('boom')),
        ],
      )));
      await tester.tap(_key('z-generation-acquire-0'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ERREUR'), findsOneWidget);
    });

    testWidgets('AD-13 : le geste d\'acquisition est une cible ≥ 48 dp au '
        'libellé injecté', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: _FakePort(),
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        acquisitionGestures: <ZSourceAcquisitionGesture>[
          gesture(() async => Right<ZFailure, ZGenerationSourceOption?>(null),
              label: 'Scanner un document'),
        ],
      )));
      expect(find.text('Scanner un document'), findsOneWidget,
          reason: 'libellé INJECTÉ (jamais en dur — FR-26/NFR-S7)');
      final size = tester.getSize(_key('z-generation-acquire-0'));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });
  });

  group('CR-70 — SM-1/AD-2 : la saisie survit aux sources', () {
    testWidgets(
        '🔴 une frappe PENDANT une résolution asynchrone : focus et contenu '
        'intacts, puis l\'aperçu arrive sans rien perdre', (tester) async {
      final gate = Completer<ZResult<ZResolvedGenerationSource>>();
      final port = _FakePort();
      await tester.pumpWidget(_harness(ZFlashcardGenerationSheet(
        port: port,
        messages: _messages,
        labels: _labels,
        sources: const <ZGenerationSourceOption>[],
        contextSources: <ZGenerationSourceOption>[
          ZGenerationSourceOption(
            label: 'DocLent',
            resolveContent: () => gate.future,
          ),
        ],
      )));
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      await _submit(tester); // la résolution est EN VOL (gate non complété).

      final field = _key('z-generation-instructions');
      await tester.enterText(field, 'pendant la résolution');
      await tester.pump();
      final editable =
          find.descendant(of: field, matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue,
          reason: 'frappe pendant la résolution : AUCUNE perte de focus (SM-1)');

      gate.complete(Right<ZFailure, ZResolvedGenerationSource>(
          const ZResolvedGenerationSource(text: 'lent')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ZFlashcardPreview), findsOneWidget);
      expect(find.text('pendant la résolution'), findsOneWidget,
          reason: 'le rebuild de statut ne détruit pas la saisie (AD-2)');
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      expect(port.lastRequest!.instructions, isNot('pendant la résolution'),
          reason: 'la requête soumise reste celle du moment du tap — la frappe '
              'tardive n\'y fuit pas');
    });

    testWidgets(
        'l\'hôte repasse une AUTRE liste de sources : focus et saisie intacts, '
        'sélection orpheline purgée', (tester) async {
      final port = _FakePort();
      Widget sheet(List<ZGenerationSourceOption> context) =>
          _harness(ZFlashcardGenerationSheet(
            port: port,
            messages: _messages,
            labels: _labels,
            sources: const <ZGenerationSourceOption>[],
            contextSources: context,
          ));
      final listA = <ZGenerationSourceOption>[
        ZGenerationSourceOption(
          label: 'DocA',
          resolveContent: () async =>
              Right<ZFailure, ZResolvedGenerationSource>(
            const ZResolvedGenerationSource(text: 'A'),
          ),
        ),
      ];
      await tester.pumpWidget(sheet(listA));
      await tester.tap(_key('z-generation-context-source-0'));
      await tester.pump();
      final field = _key('z-generation-instructions');
      await tester.enterText(field, 'stable');
      await tester.pump();

      // L'hôte change la liste (autres instances) SOUS la feuille.
      await tester.pumpWidget(sheet(<ZGenerationSourceOption>[
        const ZGenerationSourceOption(label: 'DocB'),
      ]));
      final editable =
          find.descendant(of: field, matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue,
          reason: 'le changement de liste ne touche pas aux controllers (SM-1)');
      expect(find.text('stable'), findsOneWidget);
      expect(find.text('DocB'), findsOneWidget);

      await _submit(tester);
      expect(port.lastRequest!.resolvedSources, isNull,
          reason: 'la sélection ORPHELINE (DocA disparu) est purgée — jamais '
              'une source fantôme résolue');
    });
  });

  group('CR-70 — contrôleur : fraîcheur et repli sur le chemin de résolution', () {
    test('hôte passif : generate(request) transmet la requête TELLE QUELLE '
        '(resolvedSources null)', () async {
      final port = _FakePort();
      final controller = ZFlashcardGenerationController(
        port: port,
        messages: _messages,
      );
      const request = ZFlashcardGenerationRequest(content: 'x');
      await controller.generate(request);
      expect(port.lastRequest, equals(request));
      expect(port.lastRequest!.resolvedSources, isNull);
      controller.dispose();
    });

    test('🔴 abandon PENDANT la résolution ⇒ réponse écartée, port JAMAIS '
        'appelé, statut idle', () async {
      final gate = Completer<ZResult<ZResolvedGenerationSource>>();
      final port = _FakePort();
      final controller = ZFlashcardGenerationController(
        port: port,
        messages: _messages,
      );
      final pending = controller.generate(
        const ZFlashcardGenerationRequest(content: 'x'),
        sourceResolvers: <ZGenerationSourceResolver>[() => gate.future],
      );
      expect(controller.status, ZFlashcardGenerationStatus.generating);
      controller.abandon();
      gate.complete(Right<ZFailure, ZResolvedGenerationSource>(
          const ZResolvedGenerationSource(text: 'tard')));
      await pending;
      expect(port.calls, 0,
          reason: 'jeton de fraîcheur : la résolution tardive est écartée');
      expect(controller.status, ZFlashcardGenerationStatus.idle);
      controller.dispose();
    });

    test('anti-double-tap : une soumission pendant la résolution est ignorée',
        () async {
      final gate = Completer<ZResult<ZResolvedGenerationSource>>();
      final port = _FakePort();
      final controller = ZFlashcardGenerationController(
        port: port,
        messages: _messages,
      );
      final first = controller.generate(
        const ZFlashcardGenerationRequest(content: 'x'),
        sourceResolvers: <ZGenerationSourceResolver>[() => gate.future],
      );
      await controller.generate(
        const ZFlashcardGenerationRequest(content: 'DOUBLON'),
      );
      gate.complete(Right<ZFailure, ZResolvedGenerationSource>(
          const ZResolvedGenerationSource(text: 'ok')));
      await first;
      expect(port.calls, 1);
      expect(port.lastRequest!.content, 'x',
          reason: 'le doublon soumis pendant la résolution a été ignoré');
      controller.dispose();
    });
  });
}
