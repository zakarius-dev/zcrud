/// Le **compteur** : il rend une mesure, il n'en fabrique aucune.
///
/// Ce que ces gardes prouvent : sans port, **aucun chiffre** n'apparaît — ni
/// zéro, ni longueur de texte (mesure ABSOLUE : on cherche tout chiffre dans
/// l'arbre du compteur, pas la différence avec un arbre témoin) ; une mesure
/// indisponible est traitée comme une absence, pas comme un `0` ; et le
/// compteur rend ce que le PORT dit, même quand ce n'est pas le nombre de
/// caractères.
@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Port scriptable : il rend ce qu'on lui dit, y compris `null`.
class _Mesure implements ZChatTextMeasurePort {
  _Mesure(this.reponse);
  final ZChatTextMeasurement? Function(String texte) reponse;
  final List<String> vus = <String>[];
  @override
  ZChatTextMeasurement? measure(String text) {
    vus.add(text);
    return reponse(text);
  }
}

/// Tout texte affiché sous le compteur — la mesure ABSOLUE de « rien ».
List<String> _textes(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(ZChatComposerCounter),
        matching: find.byType(Text),
      ),
    )
    .map((Text t) => t.data ?? '')
    .toList();

void main() {
  group('L8 — le compteur', () {
    testWidgets(
      '🔴 SANS PORT : aucun chiffre dans l\'arbre du compteur — pas même un '
      'zéro, pas même la longueur du texte',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        rig.controller.composer.text = 'douze caractères et plus';

        await tester.pumpWidget(
          harness(ZChatComposerCounter(controller: rig.controller)),
        );

        expect(_textes(tester), isEmpty);
        // Mesure absolue : aucun chiffre, où qu'il soit sous le compteur.
        for (final String t in _textes(tester)) {
          expect(RegExp(r'\d').hasMatch(t), isFalse);
        }
        expect(find.byType(ValueListenableBuilder<TextEditingValue>),
            findsNothing,
            reason: 'sans port, le compteur ne s\'abonne même pas à la saisie');
      },
    );

    testWidgets(
      'port présent mais mesure INDISPONIBLE : toujours aucun chiffre — '
      '« je ne sais pas » n\'est pas `0`',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        rig.controller.composer.text = 'abc';

        await tester.pumpWidget(
          harness(
            ZChatComposerCounter(
              controller: rig.controller,
              port: const ZChatUnavailableTextMeasure(),
            ),
          ),
        );

        expect(_textes(tester), isEmpty);
      },
    );

    testWidgets(
      'le compteur rend ce que le PORT dit — pas le nombre de caractères',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        rig.controller.composer.text = 'abc';
        // 7 unités pour 3 caractères : si le socle comptait lui-même, il
        // afficherait 3.
        final _Mesure port = _Mesure(
          (String t) => ZChatTextMeasurement(units: 7, unitKey: 'tokens'),
        );

        await tester.pumpWidget(
          harness(
            ZChatComposerCounter(controller: rig.controller, port: port),
          ),
        );

        expect(_textes(tester), <String>['7']);
        expect(port.vus, contains('abc'));
      },
    );

    testWidgets('le plafond est rendu quand le port en déclare un', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final _Mesure port = _Mesure(
        (String t) => ZChatTextMeasurement(units: 12, limit: 100),
      );

      await tester.pumpWidget(
        harness(ZChatComposerCounter(controller: rig.controller, port: port)),
      );

      expect(_textes(tester), <String>['12 / 100']);
    });

    testWidgets(
      'un DÉPASSEMENT est rendu, jamais borné ni transformé en refus',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final _Mesure port = _Mesure(
          (String t) => ZChatTextMeasurement(units: 150, limit: 100),
        );

        await tester.pumpWidget(
          harness(
            ZChatComposerCounter(controller: rig.controller, port: port),
          ),
        );

        expect(_textes(tester), <String>['150 / 100']);
        expect(
          rig.controller.canSend.value,
          isFalse,
          reason: 'canSend ne dépend QUE de la saisie — le compteur ne le '
              'touche pas ; ici la saisie est vide',
        );
      },
    );

    testWidgets(
      'le compteur suit la frappe SANS reconstruire le champ — il est une '
      'feuille',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final _Mesure port = _Mesure(
          (String t) => ZChatTextMeasurement(units: t.length * 2),
        );

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: const Color(0xFF123456),
              counter: (BuildContext context, ZChatComposerSlot slot) =>
                  ZChatComposerCounter(controller: slot.controller, port: port),
            ),
          ),
        );
        final EditableText avant = tester.widget<EditableText>(
          find.byType(EditableText),
        );

        rig.controller.composer.text = 'abcd';
        await tester.pump();

        expect(_textes(tester), <String>['8']);
        expect(
          identical(
            tester.widget<EditableText>(find.byType(EditableText)).controller,
            avant.controller,
          ),
          isTrue,
          reason: 'la tranche de saisie n\'est jamais recréée (invariant AD-2)',
        );
      },
    );

    testWidgets(
      'le rendu d\'hôte remplace le rendu par défaut ; rendre `null` remet le '
      'compteur au silence (AD-4)',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final _Mesure port = _Mesure(
          (String t) => ZChatTextMeasurement(units: 5),
        );

        await tester.pumpWidget(
          harness(
            ZChatComposerCounter(
              controller: rig.controller,
              port: port,
              builder: (BuildContext c, ZChatTextMeasurement m) =>
                  Text('hôte:${m.units}'),
            ),
          ),
        );
        expect(_textes(tester), <String>['hôte:5']);

        await tester.pumpWidget(
          harness(
            ZChatComposerCounter(
              controller: rig.controller,
              port: port,
              builder: (BuildContext c, ZChatTextMeasurement m) => null,
            ),
          ),
        );
        expect(_textes(tester), isEmpty);
      },
    );
  });
}
