// Une action de lot ABSENTE et une action INERTE sont deux choses distinctes.
//
// `onSelected == null` retire l'action de la barre (masquage). `enabled: false`
// la garde en place, grisée, non actionnable, motif annoncé — la forme qu'un
// mode d'ACL « désactiver » attend, et celle que les actions de LIGNE offraient
// déjà (`ZResolvedRowAction.enabled`/`disabledReasonKey`).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _bar(List<ZBatchAction> actions, ZListSelectionController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        child: ZBatchActionBar(controller: controller, actions: actions),
      ),
    ),
  );
}

Finder _buttonOf(IconData icon) => find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(IconButton),
    );

void main() {
  testWidgets('action INERTE : présente, sans callback, annoncée désactivée',
      (tester) async {
    final controller = ZListSelectionController()..toggle('a');
    addTearDown(controller.dispose);
    final handle = tester.ensureSemantics();
    var invoked = 0;

    await tester.pumpWidget(
      _bar(
        <ZBatchAction>[
          ZBatchAction(
            kind: ZBatchActionKind.delete,
            label: 'Supprimer',
            icon: Icons.delete_outline,
            enabled: false,
            disabledReason: 'Droit refusé',
            onSelected: () => invoked++,
          ),
        ],
        controller,
      ),
    );

    expect(_buttonOf(Icons.delete_outline), findsOneWidget);
    expect(tester.widget<IconButton>(_buttonOf(Icons.delete_outline)).onPressed,
        isNull);

    final semantics = tester.getSemantics(_buttonOf(Icons.delete_outline));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    expect(semantics.hint, contains('Droit refusé'));

    await tester.tap(_buttonOf(Icons.delete_outline), warnIfMissed: false);
    await tester.pump();
    expect(invoked, 0, reason: 'inerte porte sur l\'effet AUTANT que sur '
        'l\'apparence');
    handle.dispose();
  });

  testWidgets('CONTRE-TÉMOIN — sans déclaration, l\'action reste actionnable',
      (tester) async {
    final controller = ZListSelectionController()..toggle('a');
    addTearDown(controller.dispose);
    var invoked = 0;

    await tester.pumpWidget(
      _bar(
        <ZBatchAction>[
          ZBatchAction(
            kind: ZBatchActionKind.delete,
            label: 'Supprimer',
            icon: Icons.delete_outline,
            onSelected: () => invoked++,
          ),
        ],
        controller,
      ),
    );

    expect(tester.widget<IconButton>(_buttonOf(Icons.delete_outline)).onPressed,
        isNotNull);
    await tester.tap(_buttonOf(Icons.delete_outline));
    await tester.pump();
    expect(invoked, 1);
  });

  testWidgets('MASQUAGE — sans callback, l\'action n\'existe pas', (tester) async {
    final controller = ZListSelectionController()..toggle('a');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _bar(
        const <ZBatchAction>[
          ZBatchAction(
            kind: ZBatchActionKind.delete,
            label: 'Supprimer',
            icon: Icons.delete_outline,
          ),
        ],
        controller,
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('repliée en dépassement, une action inerte reste LISTÉE, '
      'non sélectionnable', (tester) async {
    final controller = ZListSelectionController()..toggle('a');
    addTearDown(controller.dispose);
    var invoked = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            // Trop étroit pour deux boutons : les deux basculent en menu.
            width: 60,
            child: ZBatchActionBar(
              controller: controller,
              actions: <ZBatchAction>[
                ZBatchAction(
                  kind: ZBatchActionKind.move,
                  label: 'Déplacer',
                  icon: Icons.drive_file_move_outline,
                  onSelected: () {},
                ),
                ZBatchAction(
                  kind: ZBatchActionKind.restore,
                  label: 'Restaurer',
                  icon: Icons.restore_from_trash,
                  enabled: false,
                  disabledReason: 'Droit refusé',
                  onSelected: () => invoked++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Le type générique de l'entrée est privé à la barre : on la reconnaît par
    // sa nature, pas par son paramètre de type.
    final entries = tester.widgetList<Widget>(
      find.ancestor(
        of: find.text('Restaurer'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(entries, hasLength(1));
    expect((entries.single as PopupMenuItem).enabled, isFalse);
    await tester.tap(find.text('Restaurer'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(invoked, 0);
  });

  test('la restauration de lot a sa NATURE (plus « hors nomenclature »)', () {
    expect(ZBatchActionKind.values, contains(ZBatchActionKind.restore));
  });
}
