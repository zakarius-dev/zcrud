// CHAT-9 — diffusion : voix, non-duplication de l'export, barre neutre.
//
// ⚠️ `@TestOn('vm')` — ce fichier lit les SOURCES du package (volet G9-D2).
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const List<ZChatMessage> _conversation = <ZChatMessage>[
  ZChatMessage(
    id: 'm1',
    conversationId: 'c1',
    role: ZChatRole.user,
    contentBlocks: <ZContentBlock>[ZTextBlock(text: 'Quelle est la règle ?')],
  ),
  ZChatMessage(
    id: 'm2',
    conversationId: 'c1',
    role: ZChatRole.assistant,
    contentBlocks: <ZContentBlock>[
      ZTextBlock(text: 'La voici.'),
      ZTableBlock(
        headers: <String>['code', 'taux'],
        rows: <List<String>>[
          <String>['01', '5%'],
        ],
      ),
    ],
  ),
];

void main() {
  group('G9-D2 — l\'export n\'est PAS dupliqué (grep NÉGATIF + preuve d\'usage)',
      () {
    test('le service de diffusion n\'écrit AUCUN rendu de son côté', () {
      final List<String> lines = stripped(
        libFile('diffusion/z_chat_diffusion_service.dart'),
      );
      expect(lines.length, greaterThan(50),
          reason: '🔴 GARDE VACUELLE : ${lines.length} ligne(s) lues.');
      final String code = lines.join('\n');
      for (final String term in <String>[
        'StringBuffer',
        '_escapeHtml',
        'replaceAllMapped',
        '<!DOCTYPE',
        'writeln',
        'toIso8601String',
      ]) {
        expect(code.contains(term), isFalse,
            reason: '🔴 `$term` : un SECOND rendu de conversation est en train '
                'de naître à côté de `ZChatExportService` (CHAT-5, 4 formats '
                'textuels déjà livrés). Deux rendus divergeront.');
      }
      // Volet POSITIF : la délégation existe vraiment.
      //
      // 🔴 Le code est REPLIÉ (espaces écrasés) avant la recherche : le
      // formateur de Dart coupe `exportService\n    .exportConversation(`, et
      // une garde qui cherche la chaîne littérale rougirait au premier
      // `dart format` — un rouge de MISE EN PAGE, pas de comportement, qu'on
      // finirait par désarmer.
      final String flat = code.replaceAll(RegExp(r'\s+'), '');
      expect(flat, contains('exportService.exportConversation('),
          reason: '🔴 la délégation a disparu : le grep négatif ci-dessus '
              'passerait sur un service qui ne fait plus RIEN.');
    });

    test('aucun SECOND format d\'export, aucune seconde couture de partage', () {
      final String code =
          stripped(libFile('diffusion/z_chat_diffusion_service.dart')).join('\n');
      for (final String term in <String>[
        'enum ZChat',
        'abstract class ZChatExport',
        'ZChatExportSink',
        'Uint8List',
      ]) {
        expect(code.contains(term), isFalse,
            reason: '🔴 `$term` : le partage/PDF est REDÉFINI ici alors que '
                '`ZChatExportService.shareConversation` + `ZChatExportSink` '
                'existent depuis CHAT-5.');
      }
    });

    test('🔬 CONTRE-PREUVE — les motifs VOIENT une duplication', () {
      const String sample = '    final StringBuffer buffer = StringBuffer();';
      expect(sample.contains('StringBuffer'), isTrue);
    });
  });

  group('G9-D3 — la narration RÉUTILISE le document exporté, à la lettre', () {
    test('le texte lu est EXACTEMENT l\'export `plainText`', () async {
      const ZChatExportService export = ZChatExportService();
      final _FakeSpeech speech = _FakeSpeech();
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: export,
        speech: speech,
      );
      addTearDown(service.dispose);
      final DateTime date = DateTime.utc(2026, 8, 1);

      final ZResult<ZChatSpeechDelivery> result =
          await service.narrateConversation(
        title: 'Ma conversation',
        messages: _conversation,
        exportDate: date,
      );
      expect(result.isRight(), isTrue);

      final ZChatTextExport expected = (await export.exportConversation(
        title: 'Ma conversation',
        messages: _conversation,
        format: ZChatExportFormat.plainText,
        exportDate: date,
      )).getOrElse(() => throw StateError('unreachable')) as ZChatTextExport;

      expect(speech.lastRequest!.text, expected.text,
          reason: '🔴 le texte lu DIVERGE du document exporté : deux vérités '
              'pour une même conversation.');
      // Et il contient bien le TABLEAU — un rendu maison l\'aurait sauté.
      expect(speech.lastRequest!.text, contains('01'));
    });

    test('la lecture d\'un message passe par le résumé annonçable du kernel',
        () async {
      final _FakeSpeech speech = _FakeSpeech();
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: const ZChatExportService(),
        speech: speech,
      );
      addTearDown(service.dispose);
      await service.narrateMessage(_conversation.last);
      expect(speech.lastRequest!.text,
          zChatAccessibleTextOf(_conversation.last.contentBlocks));
    });

    test('sans port vocal : `Left(ZUnsupportedOperationFailure)`, jamais une '
        'exception, et `speaking` reste FAUX', () async {
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: const ZChatExportService(),
      );
      addTearDown(service.dispose);
      final ZResult<ZChatSpeechDelivery> result =
          await service.narrateMessage(_conversation.last);
      expect(result.fold((ZFailure f) => f, (_) => null),
          isA<ZUnsupportedOperationFailure>());
      expect(service.speaking.value, isFalse);
    });

    test('🔴 un port qui LÈVE ne laisse PAS le bouton figé sur « arrêter »',
        () async {
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: const ZChatExportService(),
        speech: _FakeSpeech(throws: true),
      );
      addTearDown(service.dispose);
      final ZResult<ZChatSpeechDelivery> result =
          await service.narrateMessage(_conversation.last);
      expect(result.isLeft(), isTrue);
      expect(service.speaking.value, isFalse,
          reason: '🔴 la tranche réactive est restée à `true` : l\'action '
              'unique de la barre devient inopérante pour de bon.');
    });

    test('`speaking` passe à VRAI pendant la lecture — la tranche n\'est pas '
        'décorative', () async {
      final _FakeSpeech speech = _FakeSpeech();
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: const ZChatExportService(),
        speech: speech,
      );
      addTearDown(service.dispose);
      bool sawTrue = false;
      speech.onSpeak = () => sawTrue = service.speaking.value;
      await service.narrateMessage(_conversation.last);
      expect(sawTrue, isTrue);
      expect(service.speaking.value, isFalse);
    });

    test('`stopNarration` appelle le port ET retombe à faux', () async {
      final _FakeSpeech speech = _FakeSpeech();
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: const ZChatExportService(),
        speech: speech,
      );
      addTearDown(service.dispose);
      await service.stopNarration();
      expect(speech.stopCount, 1);
      expect(service.speaking.value, isFalse);
    });
  });

  group('G9-A1 — AD-13 sur la barre de diffusion : 48 dp RENDUS, RTL, a11y',
      () {
    Future<ZChatDiffusionService> pump(
      WidgetTester tester, {
      TextDirection direction = TextDirection.ltr,
      VoidCallback? onShare,
      Map<String, String>? labels,
      _FakeSpeech? speech,
    }) async {
      final ZChatDiffusionService service = ZChatDiffusionService(
        exportService: const ZChatExportService(),
        speech: speech ?? _FakeSpeech(),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatDiffusionBar(
              service: service,
              onSpeak: () {},
              onShare: onShare,
            ),
          ),
          direction: direction,
          labels: labels,
        ),
      );
      return service;
    }

    testWidgets('chaque action MESURE au moins 48 dp (taille rendue, pas '
        'contrainte déclarée)', (WidgetTester tester) async {
      await pump(tester, onShare: () {});
      for (final String text in <String>[
        kZChatLabelFallbacks[kZChatLabelSpeak]!,
        kZChatLabelFallbacks[kZChatLabelShare]!,
      ]) {
        final Size size = tester.getSize(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(ConstrainedBox),
          ).first,
        );
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: '🔴 cible « $text » à ${size.height} dp : un `padding` de '
                'parent a écrasé la contrainte — le défaut exact mesuré sur '
                '`ZChatAttachmentStrip`.');
        expect(size.width, greaterThanOrEqualTo(48.0));
        // 🔴 **BORNE HAUTE — la garde ne mordait PAS sans elle.** Mesuré par
        // l'injection R3-10 (`minHeight: 24`) : la garde restait VERTE parce
        // que l'`Align` interne occupait TOUTE la contrainte, et la cible
        // mesurait 600 dp — la hauteur de l'écran, pas notre plancher. On
        // mesurait le SDK. La borne haute rend le plancher de 48 dp la SEULE
        // raison possible du succès.
        expect(size.height, lessThanOrEqualTo(96.0),
            reason: '🔴 la cible mesure ${size.height} dp : elle s\'étire sur '
                'toute la place disponible. La garde ≥ 48 dp passerait alors '
                'quel que soit le `minHeight` — c\'est-à-dire pour rien.');
      }
    });

    testWidgets('chaque action est un `Semantics(button: true)` avec un '
        'libellé RÉSOLU', (WidgetTester tester) async {
      await pump(tester, onShare: () {});
      final SemanticsHandle handle = tester.ensureSemantics();
      for (final String label in <String>[
        kZChatLabelFallbacks[kZChatLabelSpeak]!,
        kZChatLabelFallbacks[kZChatLabelShare]!,
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsWidgets,
          reason: '🔴 « $label » n\'est pas annoncé : l\'action est '
              'inatteignable au lecteur d\'écran.',
        );
      }
      handle.dispose();
    });

    testWidgets('le libellé de l\'hôte PRIME sur le repli (FR-26)',
        (WidgetTester tester) async {
      await pump(tester, labels: <String, String>{kZChatLabelSpeak: 'Écouter'});
      expect(find.text('Écouter'), findsOneWidget);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelSpeak]!), findsNothing);
    });

    // 🔴 **GARDE RETENDUE EN COURS DE LOT.** La première version de ce test
    // comparait le `dx` du bouton « lire » en LTR puis en RTL et attendait
    // qu'il se déplace. Elle passait — mais elle ne mesurait PAS notre code :
    // le déplacement venait de l'`Align(AlignmentDirectional.topStart)` du
    // harnais et du `Row`, tous deux fournis par le SDK. Elle serait restée
    // VERTE avec un `EdgeInsets.only(left:)` en dur dans la barre. C'est
    // exactement « mesurer le plancher du SDK au lieu du nôtre ».
    //
    // Deux volets la remplacent, tous deux ancrés sur NOTRE fichier :
    //   1. les formes non directionnelles y sont absentes et les
    //      directionnelles présentes (le grep repo-wide de
    //      `z_chat_purity_test.dart` le couvre déjà — l'ancrage local survit à
    //      un changement de partition de cette garde) ;
    //   2. la barre reste utilisable en RTL : mêmes cibles, toujours ≥ 48 dp,
    //      aucun débordement.
    test('AD-13 volet SOURCE — la barre n\'emploie que des formes '
        'directionnelles', () {
      final String src =
          stripped(libFile('view/z_chat_diffusion_bar.dart')).join('\n');
      expect(src.length, greaterThan(500),
          reason: '🔴 GARDE VACUELLE : fichier quasi vide.');
      for (final String forbidden in <String>[
        r'\bEdgeInsets\.only\(\s*(left|right):',
        r'\bAlignment\.center(Left|Right)\b',
        r'\bTextAlign\.(left|right)\b',
        r'\bPositioned\(\s*(left|right):',
      ]) {
        expect(RegExp(forbidden).hasMatch(src), isFalse,
            reason: '🔴 `$forbidden` — la barre serait à l\'envers en RTL.');
      }
      expect(src, contains('EdgeInsetsDirectional'));
      expect(src, contains('AlignmentDirectional'));
      expect(src, contains('TextAlign.start'));
      // La cible est ADOSSÉE à la constante partagée, jamais recopiée.
      expect(src, contains('kZChatMinTapTarget'));
      expect(RegExp(r'minHeight:\s*\d').hasMatch(src), isFalse,
          reason: '🔴 contrainte tactile en LITTÉRAL : elle divergera.');
    });

    testWidgets('AD-13 volet RENDU — en RTL les cibles restent présentes, '
        '≥ 48 dp, et rien ne déborde', (WidgetTester tester) async {
      await pump(tester, direction: TextDirection.rtl, onShare: () {});
      for (final String text in <String>[
        kZChatLabelFallbacks[kZChatLabelSpeak]!,
        kZChatLabelFallbacks[kZChatLabelShare]!,
      ]) {
        expect(find.text(text), findsOneWidget);
        final Size size = tester.getSize(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: '🔴 « $text » tombe à ${size.height} dp en RTL.');
        expect(size.width, greaterThanOrEqualTo(48.0));
      }
      expect(tester.takeException(), isNull,
          reason: '🔴 débordement/exception de layout en RTL.');
    });

    testWidgets('l\'action unique BASCULE : « lire » ⇄ « arrêter », jamais '
        'deux cibles dont une inerte', (WidgetTester tester) async {
      // 🔴 Le faux port est GELÉ sur un `Completer` : sans cela, `speak` rend
      // la main dans la même micro-tâche et la tranche est déjà retombée à
      // `false` au premier `pump` — le test serait VERT sans avoir jamais vu
      // l'état « en cours », c'est-à-dire tautologique.
      final Completer<void> gate = Completer<void>();
      final _FakeSpeech speech = _FakeSpeech(gate: gate);
      final ZChatDiffusionService service = await pump(tester, speech: speech);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelSpeak]!), findsOneWidget);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelStopSpeaking]!),
          findsNothing);

      final Future<void> narration = startNarration(service);
      await tester.pump();
      expect(find.text(kZChatLabelFallbacks[kZChatLabelStopSpeaking]!),
          findsOneWidget);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelSpeak]!), findsNothing);

      gate.complete();
      await narration;
      await tester.pump();
      expect(find.text(kZChatLabelFallbacks[kZChatLabelSpeak]!), findsOneWidget,
          reason: '🔴 le basculeur reste sur « arrêter » après la fin de la '
              'lecture : la cible devient inopérante.');
    });

    testWidgets('`onShare` nul ⇒ l\'action n\'est PAS rendue (pas une cible '
        'inerte annoncée comme disponible)', (WidgetTester tester) async {
      await pump(tester);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelShare]!), findsNothing);
    });
  });
}

/// Démarre une narration sans l'attendre — la tranche passe à `true` et y reste
/// tant que le faux port n'a pas rendu la main.
Future<void> startNarration(ZChatDiffusionService service) =>
    service.narrateMessage(_conversation.last);

class _FakeSpeech implements ZChatSpeechPort {
  _FakeSpeech({this.throws = false, this.gate});

  final bool throws;

  /// Verrou optionnel : tant qu'il n'est pas complété, `speak` ne rend pas la
  /// main — c'est ce qui rend l'état « lecture en cours » OBSERVABLE.
  final Completer<void>? gate;
  VoidCallback? onSpeak;
  ZChatSpeechRequest? lastRequest;
  int stopCount = 0;

  @override
  String get sourceKind => 'fake';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ZResult<ZChatSpeechDelivery>> speak(ZChatSpeechRequest request) async {
    lastRequest = request;
    onSpeak?.call();
    if (gate != null) await gate!.future;
    if (throws) throw StateError('moteur cassé');
    return Right<ZFailure, ZChatSpeechDelivery>(
      ZChatSpeechDelivery(sourceKind: sourceKind),
    );
  }

  @override
  Future<void> stop() async => stopCount++;
}
