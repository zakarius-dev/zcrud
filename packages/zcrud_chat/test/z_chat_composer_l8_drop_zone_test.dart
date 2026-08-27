/// La **zone de dépôt** : une zone et un rappel, jamais un greffon.
///
/// Ce que ces gardes prouvent : sans créneau d'hôte l'arbre est **identique**
/// à celui de l'enfant seul (mesuré en ABSOLU, pas par comparaison de deux
/// arbres que l'injection déplacerait tous les deux) ; les fichiers déposés
/// traversent le contrôleur, donc ses bornes ; le survol ne reconstruit pas la
/// saisie et ne lui fait perdre ni focus ni texte.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

ZPendingAttachment _png(String name) => ZPendingAttachment(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  fileName: name,
  mimeType: 'image/png',
);

/// Compte ses constructions — c'est ce qui rend « le survol ne reconstruit pas
/// la saisie » mesurable, plutôt que promis.
class _CountingChild extends StatefulWidget {
  const _CountingChild({required this.builds});
  final List<int> builds;
  @override
  State<_CountingChild> createState() => _CountingChildState();
}

class _CountingChildState extends State<_CountingChild> {
  @override
  Widget build(BuildContext context) {
    widget.builds.add(1);
    return const SizedBox(width: 10, height: 10);
  }
}

void main() {
  group('L8 — la zone de dépôt', () {
    testWidgets(
      'INERTE sans créneau : l\'arbre ne contient AUCUN widget de zone, mesuré '
      'en absolu',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ZChatComposerDropZone(child: Text('saisie')),
          ),
        );

        // Mesure ABSOLUE : les types que la zone pourrait introduire ne sont
        // pas dans l'arbre. Aucune comparaison à un arbre témoin — un tel
        // témoin serait affecté par la même injection.
        final Finder zone = find.byType(ZChatComposerDropZone);
        for (final Type t in <Type>[
          Stack,
          ValueListenableBuilder<bool>,
          Positioned,
        ]) {
          expect(
            find.descendant(of: zone, matching: find.byType(t)),
            findsNothing,
            reason: '$t ne doit PAS apparaître sous une zone sans créneau',
          );
        }
        expect(find.text('saisie'), findsOneWidget);
      },
    );

    testWidgets(
      'les fichiers déposés traversent le CONTRÔLEUR, et le rappel d\'hôte '
      'reçoit la liste telle qu\'elle a été déposée',
      (WidgetTester tester) async {
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        final List<List<ZPendingAttachment>> vus =
            <List<ZPendingAttachment>>[];
        ZChatComposerDropHandle? poignee;

        await tester.pumpWidget(
          MaterialApp(
            home: ZChatComposerDropZone(
              attachments: attachments,
              onFiles: vus.add,
              wrap: (
                BuildContext context,
                ZChatComposerDropHandle handle,
                Widget child,
              ) {
                poignee = handle;
                return child;
              },
              child: const Text('saisie'),
            ),
          ),
        );

        // `.gif` n'est pas dans les types admis par défaut : le contrôleur le
        // refuse, l'hôte le voit quand même.
        final ZPendingAttachment ok = _png('a.png');
        final ZPendingAttachment refuse = ZPendingAttachment(
          bytes: Uint8List.fromList(<int>[9]),
          fileName: 'b.gif',
          mimeType: 'image/gif',
        );
        poignee!.deliver(<ZPendingAttachment>[ok, refuse]);
        await tester.pump();

        expect(
          attachments.pending.value,
          <ZPendingAttachment>[ok],
          reason: 'les bornes appartiennent au contrôleur, pas à la zone',
        );
        expect(vus, hasLength(1));
        expect(
          vus.single,
          <ZPendingAttachment>[ok, refuse],
          reason: 'l\'hôte reçoit ce qui a été DÉPOSÉ, pas ce qui a été retenu',
        );
      },
    );

    testWidgets(
      'le survol ne reconstruit PAS la saisie — et le dépôt met fin au survol',
      (WidgetTester tester) async {
        final List<int> builds = <int>[];
        ZChatComposerDropHandle? poignee;

        await tester.pumpWidget(
          MaterialApp(
            home: ZChatComposerDropZone(
              overlay: (BuildContext context) => const Text('surbrillance'),
              wrap: (
                BuildContext context,
                ZChatComposerDropHandle handle,
                Widget child,
              ) {
                poignee = handle;
                return child;
              },
              child: _CountingChild(builds: builds),
            ),
          ),
        );
        final int apresMontage = builds.length;
        expect(apresMontage, 1);

        poignee!.setHovering(true);
        await tester.pump();
        expect(
          find.text('surbrillance'),
          findsOneWidget,
          reason: 'la mise en évidence d\'hôte est montée pendant le survol',
        );
        expect(poignee!.isHovering.value, isTrue);
        expect(
          builds.length,
          apresMontage,
          reason: 'la saisie est passée en `child` : elle n\'est PAS reconstruite',
        );

        poignee!.deliver(<ZPendingAttachment>[_png('c.png')]);
        await tester.pump();
        expect(poignee!.isHovering.value, isFalse);
        expect(
          find.text('surbrillance'),
          findsNothing,
          reason: 'le dépôt éteint la mise en évidence',
        );
        expect(builds.length, apresMontage);
      },
    );

    testWidgets(
      'le survol ne fait perdre à la saisie ni son FOCUS ni son texte',
      (WidgetTester tester) async {
        ZChatComposerDropHandle? poignee;
        final TextEditingController champ = TextEditingController(text: 'abc');
        addTearDown(champ.dispose);
        final FocusNode noeud = FocusNode();
        addTearDown(noeud.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: ZChatComposerDropZone(
                overlay: (BuildContext context) => const SizedBox.shrink(),
                wrap: (
                  BuildContext context,
                  ZChatComposerDropHandle handle,
                  Widget child,
                ) {
                  poignee = handle;
                  return child;
                },
                child: TextField(controller: champ, focusNode: noeud),
              ),
            ),
          ),
        );
        noeud.requestFocus();
        await tester.pump();
        champ.selection = const TextSelection.collapsed(offset: 2);
        await tester.pump();

        poignee!.setHovering(true);
        await tester.pump();

        expect(noeud.hasFocus, isTrue);
        expect(champ.text, 'abc');
        expect(champ.selection.baseOffset, 2);
      },
    );
  });
}
