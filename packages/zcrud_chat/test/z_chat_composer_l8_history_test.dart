/// Le **rappel d'historique** sur flèche haut — et ce qu'il ne prend pas.
///
/// Ce que ces gardes prouvent : sans port, la flèche haut ne fait RIEN de
/// nouveau (inertie mesurée en absolu, sur le comportement) ; avec un port,
/// elle ne rappelle que sur un champ **vide** ; et dès que le champ contient
/// du texte, elle retrouve son sens de NAVIGATION — le curseur remonte d'une
/// ligne et le texte ne bouge pas.
@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

ZChatMessage _user(String texte, {String id = 'u1'}) => ZChatMessage(
  id: id,
  conversationId: 'c1',
  role: ZChatRole.user,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: texte)],
);

ZChatMessage _bot(String texte, {String id = 'a1'}) => ZChatMessage(
  id: id,
  conversationId: 'c1',
  role: ZChatRole.assistant,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: texte)],
);

Future<FocusNode> _monter(
  WidgetTester tester,
  ZChatController c, {
  ZChatComposerHistoryPort? history,
}) async {
  final FocusNode noeud = FocusNode();
  addTearDown(noeud.dispose);
  await tester.pumpWidget(
    harness(
      ZChatComposer(
        controller: c,
        cursorColor: _cursor,
        focusNode: noeud,
        history: history,
      ),
    ),
  );
  noeud.requestFocus();
  await tester.pump();
  return noeud;
}

void main() {
  group('L8 — le rappel d\'historique', () {
    testWidgets(
      'INERTE sans port : la flèche haut ne rappelle RIEN, le champ reste vide',
      (WidgetTester tester) async {
        final rig = buildController(
          initialMessages: <ZChatMessage>[_user('question précédente')],
        );
        addTearDown(rig.controller.dispose);
        await _monter(tester, rig.controller);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(
          rig.controller.composer.text,
          isEmpty,
          reason: 'un hôte qui n\'a rien déclaré ne voit AUCUN geste changer',
        );
      },
    );

    testWidgets(
      'champ VIDE : la flèche haut rappelle le dernier message d\'UTILISATEUR '
      '— jamais la réponse de l\'assistant',
      (WidgetTester tester) async {
        final rig = buildController(
          initialMessages: <ZChatMessage>[
            _user('première', id: 'u1'),
            _user('question précédente', id: 'u2'),
            _bot('réponse de l\'assistant', id: 'a1'),
          ],
        );
        addTearDown(rig.controller.dispose);
        await _monter(
          tester,
          rig.controller,
          history: ZChatThreadHistory(rig.controller),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(rig.controller.composer.text, 'question précédente');
        // ⚠️ La position du curseur n'est PAS assertée ici : montée sous
        // `EditableText`, elle est normalisée par le framework, et une
        // assertion à ce niveau passerait quoi qu'on écrive dans l'action.
        // Elle est mesurée plus bas, sur l'action seule.
      },
    );

    testWidgets(
      '🔴 champ NON VIDE : la flèche haut garde son sens de NAVIGATION — le '
      'curseur remonte d\'une ligne et le texte ne bouge pas',
      (WidgetTester tester) async {
        final rig = buildController(
          initialMessages: <ZChatMessage>[_user('question précédente')],
        );
        addTearDown(rig.controller.dispose);
        rig.controller.composer.value = const TextEditingValue(
          text: 'aaa\nbbb',
          selection: TextSelection.collapsed(offset: 7),
        );
        await _monter(
          tester,
          rig.controller,
          history: ZChatThreadHistory(rig.controller),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(
          rig.controller.composer.text,
          'aaa\nbbb',
          reason: '🔴 le rappel ne doit PAS écraser une saisie en cours',
        );
        expect(
          rig.controller.composer.selection.baseOffset,
          lessThan(4),
          reason: '🔴 la frappe a bien atteint la navigation multiligne de '
              'Flutter : le curseur est remonté sur la PREMIÈRE ligne',
        );
      },
    );

    testWidgets(
      'champ vide mais RIEN à rappeler : la frappe n\'est pas avalée pour rien',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        await _monter(
          tester,
          rig.controller,
          history: ZChatThreadHistory(rig.controller),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(rig.controller.composer.text, isEmpty);
      },
    );

    testWidgets(
      'un message d\'utilisateur fait de BLANCS n\'est pas une entrée',
      (WidgetTester tester) async {
        final rig = buildController(
          initialMessages: <ZChatMessage>[_user('   ')],
        );
        addTearDown(rig.controller.dispose);
        await _monter(
          tester,
          rig.controller,
          history: ZChatThreadHistory(rig.controller),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(rig.controller.composer.text, isEmpty);
      },
    );
  });

  group('L8 — l\'action de rappel, mesurée SANS framework', () {
    test(
      'elle pose le texte rappelé ET le curseur en FIN — là où le framework ne '
      'peut pas normaliser à notre place',
      () {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        final ZChatComposerHistoryAction action = ZChatComposerHistoryAction(
          composer: champ,
          history: _Fixe('abcd'),
        );

        expect(action.isEnabled(const ZChatComposerHistoryIntent()), isTrue);
        action.invoke(const ZChatComposerHistoryIntent());

        expect(champ.text, 'abcd');
        expect(champ.selection.baseOffset, 4);
        expect(champ.selection.isCollapsed, isTrue);
      },
    );

    test('elle est DÉSACTIVÉE dès que le champ contient quelque chose', () {
      final TextEditingController champ = TextEditingController(text: 'x');
      addTearDown(champ.dispose);
      final ZChatComposerHistoryAction action = ZChatComposerHistoryAction(
        composer: champ,
        history: _Fixe('abcd'),
      );

      expect(
        action.isEnabled(const ZChatComposerHistoryIntent()),
        isFalse,
        reason: '🔴 désactivée = la frappe poursuit sa route (KeyEventResult'
            '.ignored), donc la navigation multiligne est préservée',
      );
    });

    test('elle est DÉSACTIVÉE quand le port n\'a rien à rappeler', () {
      final TextEditingController champ = TextEditingController();
      addTearDown(champ.dispose);
      final ZChatComposerHistoryAction action = ZChatComposerHistoryAction(
        composer: champ,
        history: const ZChatComposerNoHistory(),
      );

      expect(action.isEnabled(const ZChatComposerHistoryIntent()), isFalse);
    });
  });
}

/// Port à valeur fixe — il rend toujours la même entrée.
class _Fixe implements ZChatComposerHistoryPort {
  const _Fixe(this.entree);
  final String entree;
  @override
  String? previous() => entree;
}
