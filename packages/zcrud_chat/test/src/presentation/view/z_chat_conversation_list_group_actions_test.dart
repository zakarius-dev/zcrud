/// Gardes CR-IFFD-81 — actions déclaratives à l'échelle d'un groupe.
library;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../../../support/z_chat_render_harness.dart';

final DateTime _now = DateTime.utc(2026, 8, 20, 12);

ZChatConversation _conversation(String id, String title) => ZChatConversation(
  id: id,
  title: title,
  createdAt: _now.subtract(const Duration(days: 1)),
  lastMessageAt: _now.subtract(const Duration(minutes: 5)),
);

class _ReferenceLeaf extends StatelessWidget {
  const _ReferenceLeaf(this.name);

  final String name;

  @override
  Widget build(BuildContext context) =>
      SizedBox(key: ValueKey<String>(name), height: 24, child: Text(name));
}

Widget _groupedList({ZChatGroupActionsBuilder? groupActionsBuilder}) =>
    ZChatConversationList(
      items: <ZChatConversation>[
        _conversation('a', 'Alpha'),
        _conversation('b', 'Bravo'),
      ],
      groupKeyOf: (ZChatConversation conversation) => conversation.id,
      groupHeaderBuilder: (BuildContext context, Object? groupKey, int count) =>
          _ReferenceLeaf('groupe-$groupKey'),
      groupActionsBuilder: groupActionsBuilder,
      tileBuilder: (BuildContext context, ZChatConversation conversation) =>
          _ReferenceLeaf('conversation-${conversation.id}'),
    );

void main() {
  testWidgets(
    'CR81-G1 — l’action est rendue dans son groupe et invoquée avec ce groupe',
    (WidgetTester tester) async {
      ZChatConversationGroup? builtGroup;
      ZChatConversationGroup? invokedGroup;
      await tester.pumpWidget(
        harness(
          _groupedList(
            groupActionsBuilder:
                (BuildContext context, ZChatConversationGroup group) {
                  if (group.key != 'a') return const <ZChatGroupAction>[];
                  builtGroup = group;
                  return <ZChatGroupAction>[
                    ZChatGroupAction(
                      icon: const SizedBox(key: ValueKey<String>('action-a')),
                      label: 'Créer dans Alpha',
                      onInvoke: (ZChatConversationGroup invoked) {
                        invokedGroup = invoked;
                      },
                    ),
                  ];
                },
          ),
        ),
      );

      final Finder action = find.byKey(const ValueKey<String>('action-a'));
      final Finder actionRow = find.ancestor(
        of: action,
        matching: find.byType(Row),
      );
      expect(action, findsOneWidget);
      expect(actionRow, findsOneWidget);
      expect(
        find.descendant(
          of: actionRow,
          matching: find.byKey(const ValueKey<String>('groupe-a')),
        ),
        findsOneWidget,
        reason: 'L’action doit partager la ligne de l’en-tête du groupe a.',
      );

      await tester.tap(
        find.ancestor(of: action, matching: find.byType(GestureDetector)).first,
      );
      await tester.pump();

      expect(invokedGroup, isNotNull);
      expect(invokedGroup!.key, 'a');
      expect(invokedGroup!.count, 1);
      expect(identical(invokedGroup, builtGroup), isTrue);
    },
  );

  testWidgets(
    'CR81-G2 — une action conditionnelle reste isolée de l’autre groupe',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          _groupedList(
            groupActionsBuilder:
                (BuildContext context, ZChatConversationGroup group) =>
                    group.key == 'a'
                    ? <ZChatGroupAction>[
                        ZChatGroupAction(
                          icon: SizedBox(
                            key: ValueKey<String>('action-${group.key}'),
                          ),
                          label: 'Créer dans Alpha',
                          onInvoke: (ZChatConversationGroup group) {},
                        ),
                      ]
                    : const <ZChatGroupAction>[],
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('action-a')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('action-b')),
        findsNothing,
        reason:
            'Le groupe b ne déclare aucune action et ne doit recevoir '
            'aucune surface d’action.',
      );
      final Finder groupBRow = find.ancestor(
        of: find.byKey(const ValueKey<String>('groupe-b')),
        matching: find.byType(Row),
      );
      expect(groupBRow, findsNothing);
    },
  );

  testWidgets(
    'CR81-G3 — sans groupActionsBuilder, le rendu historique conserve '
    'exactement 4 feuilles de référence',
    (WidgetTester tester) async {
      await tester.pumpWidget(harness(_groupedList()));

      expect(
        find.byType(_ReferenceLeaf),
        findsNWidgets(4),
        reason:
            'Le chemin sans action doit conserver exactement les deux '
            'en-têtes et les deux conversations du rendu antérieur.',
      );
      expect(
        find.byType(Row),
        findsNothing,
        reason:
            'Sans action déclarée, aucun conteneur de groupe '
            'supplémentaire ne doit être introduit.',
      );
    },
  );

  testWidgets(
    'CR81-G4 — une exception du builder n’emporte ni ce groupe ni la liste',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          _groupedList(
            groupActionsBuilder:
                (BuildContext context, ZChatConversationGroup group) {
                  if (group.key == 'a') {
                    throw StateError('builder défaillant pour a');
                  }
                  return <ZChatGroupAction>[
                    ZChatGroupAction(
                      icon: const SizedBox(
                        key: ValueKey<String>('action-b-saine'),
                      ),
                      label: 'Créer dans Bravo',
                      onInvoke: (ZChatConversationGroup group) {},
                    ),
                  ];
                },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(_ReferenceLeaf), findsNWidgets(4));
      expect(find.byKey(const ValueKey<String>('groupe-a')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('groupe-a')),
          matching: find.byType(Row),
        ),
        findsNothing,
        reason:
            'Le groupe dont le builder échoue se replie sur son en-tête '
            'seul, sans action de secours.',
      );
      expect(
        find.byKey(const ValueKey<String>('conversation-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('action-b-saine')),
        findsOneWidget,
        reason:
            'L’échec du groupe a ne doit pas supprimer l’action saine du '
            'groupe b.',
      );
    },
  );

  testWidgets(
    'CR81-G5 — libellé exact, contrainte 48 dp et activation clavier',
    (WidgetTester tester) async {
      int calls = 0;
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          harness(
            _groupedList(
              groupActionsBuilder:
                  (BuildContext context, ZChatConversationGroup group) =>
                      group.key == 'a'
                      ? <ZChatGroupAction>[
                          ZChatGroupAction(
                            icon: const SizedBox(
                              key: ValueKey<String>('action-a11y'),
                            ),
                            label: 'Créer dans le dossier Alpha',
                            tooltip: 'Nouvelle conversation dans Alpha',
                            onInvoke: (ZChatConversationGroup group) => calls++,
                          ),
                        ]
                      : const <ZChatGroupAction>[],
            ),
          ),
        );

        final Finder action = find.byKey(const ValueKey<String>('action-a11y'));
        final Finder explicitTarget = find.ancestor(
          of: action,
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is ConstrainedBox &&
                widget.constraints ==
                    const BoxConstraints(minWidth: 48, minHeight: 48),
            description: 'ConstrainedBox explicite 48 × 48',
          ),
        );
        expect(
          explicitTarget,
          findsOneWidget,
          reason:
              'La garde vise la contrainte déclarée par zcrud_chat, pas le '
              'plancher implicite d’un bouton Material.',
        );
        final SemanticsNode node = tester.getSemantics(action);
        expect(node.label, 'Créer dans le dossier Alpha');
        expect(node.tooltip, 'Nouvelle conversation dans Alpha');
        expect(node.flagsCollection.isButton, isTrue);
        expect(
          tester.widget<RawTooltip>(find.byType(RawTooltip)).semanticsTooltip,
          'Nouvelle conversation dans Alpha',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 1, reason: 'L’action focalisée doit répondre à Entrée.');
      } finally {
        semantics.dispose();
      }
    },
  );
}
