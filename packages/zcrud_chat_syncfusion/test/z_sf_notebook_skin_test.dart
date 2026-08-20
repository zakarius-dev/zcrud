// Le **skin de référence du Notebook**, appliqué par la coquille Syncfusion —
// lot γ, CR-IFFD-72.
//
// 🔴 Deux propriétés, et la première commande tout : **sans skin, l'arbre est
// celui d'avant**. Le lot précédent de ce volet a été laissé ROUGE par un
// paramètre rendu obligatoire (incident du 2026-08-01) ; ici la mesure est
// faite sur le widget MONTÉ, champ par champ, contre le défaut de Syncfusion —
// pas sur la seule signature du constructeur.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_chat/assist_view.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_syncfusion/zcrud_chat_syncfusion.dart';
import 'package:zcrud_core/zcrud_core.dart';

const Map<String, String> _labels = <String, String>{
  kZSfAssistLabelUserAuthor: 'Moi',
  kZSfAssistLabelAssistantAuthor: 'Assistant',
  kZChatLabelLiveRegion: 'Conversation',
  kZChatLabelStreaming: 'Rédaction en cours',
};

/// Port de streaming inerte — aucune requête n'est lancée par ces gardes.
class _NoPort implements ZChatStreamPort {
  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) => const Stream<ZResult<ZChatStreamEvent>>.empty();
}

/// Exécuteur inerte — aucune action n'est déclenchée par ces gardes.
class _NoExecutor implements ZChatActionExecutor {
  static ZResult<T> _no<T>() => Left<ZFailure, T>(
    const ZDomainFailure('executor not wired in this test'),
  );

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      _no<ZChatActionImpact>();

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async => _no<List<String>>();

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async =>
      _no<List<String>>();

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async => _no<List<String>>();

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async => _no<Unit>();

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async => _no<String>();

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      _no<List<String>>();
}

ZChatController _controller() => ZChatController(
  streamPort: _NoPort(),
  actionExecutor: _NoExecutor(),
  confirm: (ZChatActionPlan _) async => true,
  newRequestId: () => 'r0',
  buildRequest: (ZChatDraft d) => ZChatGenerationRequest(
    style: ZChatGenerationStyle.converse,
    subject: d.text,
  ),
  conversationId: 'c1',
  initialMessages: <ZChatMessage>[
    ZChatMessage(
      id: 'm1',
      conversationId: 'c1',
      role: ZChatRole.assistant,
      contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'bonjour')],
    ),
  ],
);

/// Monte la vue du SOCLE sous la coquille Syncfusion — là où un hôte la monte.
Future<SfAIAssistView> _mount(
  WidgetTester tester, {
  ZChatNotebookSkin? skin,
  ZcrudTheme? theme,
}) async {
  Widget tree = ZChatNotebookView(controller: _controller());
  tree = ZChatShellRendererScope(
    renderer: ZSfAssistShellRenderer(notebookSkin: skin),
    child: tree,
  );
  tree = ZcrudScope(theme: theme, labels: ZcrudLabels(_labels), child: tree);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: tree)));
  await tester.pump();
  return tester.widget<SfAIAssistView>(find.byType(SfAIAssistView));
}

/// Compare deux `AssistMessageSettings` sur les champs que le skin touche —
/// `AssistMessageSettings` n'implémente pas `==`.
void _expectSame(
  AssistMessageSettings a,
  AssistMessageSettings b, {
  required String quoi,
}) {
  expect(a.widthFactor, b.widthFactor, reason: '$quoi : widthFactor');
  expect(
    a.showAuthorAvatar,
    b.showAuthorAvatar,
    reason: '$quoi : showAuthorAvatar',
  );
  expect(a.showAuthorName, b.showAuthorName, reason: '$quoi : showAuthorName');
  expect(a.showTimestamp, b.showTimestamp, reason: '$quoi : showTimestamp');
  expect(a.shape, b.shape, reason: '$quoi : shape');
  expect(
    a.timestampFormat,
    b.timestampFormat,
    reason: '$quoi : timestampFormat',
  );
  expect(
    a.backgroundColor,
    b.backgroundColor,
    reason: '$quoi : backgroundColor',
  );
  expect(a.textStyle, b.textStyle, reason: '$quoi : textStyle');
  expect(a.padding, b.padding, reason: '$quoi : padding');
  expect(a.margin, b.margin, reason: '$quoi : margin');
  expect(a.avatarSize, b.avatarSize, reason: '$quoi : avatarSize');
}

void main() {
  group('🔴 SF-SKIN-G1 — HÔTE PASSIF : sans skin, l\'arbre est celui d\'avant', () {
    testWidgets('les deux réglages de bulle valent le DÉFAUT Syncfusion, champ '
        'par champ', (WidgetTester tester) async {
      final SfAIAssistView view = await _mount(tester);
      const AssistMessageSettings defaut = AssistMessageSettings();
      _expectSame(view.requestMessageSettings, defaut, quoi: 'requête');
      _expectSame(view.responseMessageSettings, defaut, quoi: 'réponse');
      // Repère explicite : le défaut Syncfusion est 0.8, la référence IFFD 0.95.
      // Si le skin s'appliquait « par défaut », cette valeur serait 0.95.
      expect(view.requestMessageSettings.widthFactor, 0.8);
      expect(view.requestMessageSettings.shape, isNull);
    });

    testWidgets('…y compris quand un JETON de thème est posé — un jeton ne '
        'suffit PAS à activer le skin', (WidgetTester tester) async {
      // 🔴 La propriété inverse serait un piège : un hôte qui pose des jetons
      // pour une autre surface verrait son chat changer d'apparence.
      final SfAIAssistView view = await _mount(
        tester,
        theme: const ZcrudTheme(chatBubbleWidthFactor: 0.42),
      );
      expect(
        view.requestMessageSettings.widthFactor,
        0.8,
        reason: '🔴 le skin s\'est appliqué sans que l\'hôte l\'ait demandé',
      );
    });
  });

  group('🔴 SF-SKIN-G2 — avec skin : EXACTEMENT ce que le legacy fige', () {
    testWidgets(
      'largeur 0.95, rayon 12 sur la REQUÊTE, avatar et nom masqués',
      (WidgetTester tester) async {
        final SfAIAssistView view = await _mount(
          tester,
          skin: const ZChatNotebookSkin(),
        );

        expect(
          view.requestMessageSettings.widthFactor,
          0.95,
          reason: '`chatbot_conversation_screen.dart:3570`',
        );
        expect(
          view.responseMessageSettings.widthFactor,
          0.95,
          reason: '`chatbot_conversation_screen.dart:3587`',
        );
        expect(view.requestMessageSettings.showAuthorAvatar, isFalse);
        expect(view.responseMessageSettings.showAuthorAvatar, isFalse);
        expect(
          view.requestMessageSettings.showAuthorName,
          isFalse,
          reason: '`:3576` — `showAuthorName: isChatSession`',
        );
        expect(view.responseMessageSettings.showAuthorName, isFalse);
        expect(view.requestMessageSettings.showTimestamp, isTrue);

        final ShapeBorder? shape = view.requestMessageSettings.shape;
        expect(
          shape,
          isA<RoundedRectangleBorder>(),
          reason: '`:3577-3579` — le rayon 12 de la bulle de requête',
        );
        final RoundedRectangleBorder rounded = shape! as RoundedRectangleBorder;
        expect(
          rounded.borderRadius,
          const BorderRadius.all(Radius.circular(12)),
        );
        // CR-IFFD-80 : Syncfusion 34.1.31 omet `TextDirection` lorsqu'il peint
        // son `ShapeBorder`. Le rayon est donc résolu à la couture ; lui rendre
        // une géométrie encore directionnelle ferait échouer la peinture avant
        // celle du contenu de la requête.
        expect(rounded.borderRadius, isA<BorderRadius>());
      },
    );

    testWidgets('🔴 la bulle de RÉPONSE n\'a AUCUN `shape` — le legacy n\'en '
        'pose pas', (WidgetTester tester) async {
      final SfAIAssistView view = await _mount(
        tester,
        skin: const ZChatNotebookSkin(),
      );
      expect(
        view.responseMessageSettings.shape,
        isNull,
        reason:
            '🔴 un rayon a été INVENTÉ pour la réponse : le legacy ne '
            'pose `shape:` que sur `requestMessageSettings` '
            '(`:3586-3594` ne porte rien).',
      );
    });

    testWidgets('🔴 le FORMAT d\'horodatage legacy n\'est PAS imposé', (
      WidgetTester tester,
    ) async {
      final SfAIAssistView view = await _mount(
        tester,
        skin: const ZChatNotebookSkin(),
      );
      expect(
        view.requestMessageSettings.timestampFormat,
        isNull,
        reason:
            '🔴 `dd/MM/yyyy HH:mm:ss` est un format EU figé : l\'imposer '
            'reproduirait le défaut « libellé en dur » une couche plus bas. '
            'La valeur reste publiée dans la référence pour l\'hôte qui veut '
            'la parité stricte.',
      );
      // …et elle EST bien publiée (sans quoi l'argument ci-dessus serait faux).
      expect(
        ZChatNotebookReference.timestampFormatPattern,
        'dd/MM/yyyy HH:mm:ss',
      );
    });
  });

  group('🔴 SF-SKIN-G3 — la chaîne des trois niveaux traverse la coquille', () {
    testWidgets('le JETON atteint le widget Syncfusion', (
      WidgetTester tester,
    ) async {
      final SfAIAssistView view = await _mount(
        tester,
        skin: const ZChatNotebookSkin(),
        theme: const ZcrudTheme(chatBubbleWidthFactor: 0.42),
      );
      expect(
        view.requestMessageSettings.widthFactor,
        0.42,
        reason: '🔴 la coquille résout le skin AVANT le thème, ou l\'ignore',
      );
    });

    testWidgets('le PARAMÈTRE bat le jeton, jusque dans le widget', (
      WidgetTester tester,
    ) async {
      final SfAIAssistView view = await _mount(
        tester,
        skin: const ZChatNotebookSkin(
          bubbleWidthFactor: 0.33,
          responseBubbleRadius: Radius.circular(7),
        ),
        theme: const ZcrudTheme(chatBubbleWidthFactor: 0.42),
      );
      expect(view.requestMessageSettings.widthFactor, 0.33);
      final RoundedRectangleBorder response =
          view.responseMessageSettings.shape! as RoundedRectangleBorder;
      expect(
        response.borderRadius,
        const BorderRadius.all(Radius.circular(7)),
        reason: 'une réponse configurée doit recevoir une forme déjà résolue',
      );
    });
  });

  group(
    '🔴 SF-SKIN-G4 — la coquille ne perd RIEN de ce que le socle garantit',
    () {
      testWidgets('avec skin, la fabrique de tuiles du socle rend toujours le '
          'contenu', (WidgetTester tester) async {
        await _mount(tester, skin: const ZChatNotebookSkin());
        // Le corps visible vient de `messageContentBuilder` → fabrique du socle.
        // Un skin qui aurait pris la main sur le contenu ferait disparaître ceci.
        expect(find.text('bonjour'), findsOneWidget);
      });
    },
  );
}
