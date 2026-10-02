@TestOn('vm')
library;

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

void main() {
  testWidgets(
    'une entrée verrouillée reste visible et n\'appelle pas onSelect',
    (WidgetTester tester) async {
      var locked = 0;
      var selects = 0;
      final Completer<void> gate = Completer<void>();
      await tester.pumpWidget(
        harness(
          ZTransformPaletteBar(
            palette: ZTransformPalette(<ZTransformPaletteEntry>[
              ZTransformPaletteEntry(
                artifactKey: 'plus',
                label: 'Plus',
                lockedWhen: (String? _) => true,
              ),
              const ZTransformPaletteEntry(artifactKey: 'note', label: 'Note'),
            ]),
            onLocked: (ZTransformPaletteEntry _) => locked++,
            onSelect: (ZTransformPaletteEntry _) {
              selects++;
              return gate.future;
            },
          ),
        ),
      );
      expect(find.text('Plus'), findsOneWidget);
      await tester.tap(find.text('Plus'));
      await tester.pump();
      expect(locked, 1);
      expect(selects, 0);

      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.tap(find.text('Note'));
      await tester.pump();
      expect(selects, 1);
      gate.complete();
      await tester.pump();
    },
  );

  testWidgets('une seconde entrée ne part pas tant que la première tourne', (
    WidgetTester tester,
  ) async {
    var selects = 0;
    final Completer<void> gate = Completer<void>();
    await tester.pumpWidget(
      harness(
        ZTransformPaletteBar(
          palette: ZTransformPalette(<ZTransformPaletteEntry>[
            const ZTransformPaletteEntry(artifactKey: 'a', label: 'Alpha'),
            const ZTransformPaletteEntry(artifactKey: 'b', label: 'Beta'),
          ]),
          onSelect: (ZTransformPaletteEntry _) {
            selects++;
            return gate.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(selects, 1);
    gate.complete();
    await tester.pump();
  });

  testWidgets('le déclencheur désactivé n\'ouvre pas le menu', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      harness(
        ZChatComposerPickerTrigger(
          enabled: false,
          actions: <ZChatComposerPickerAction>[
            ZChatComposerPickerAction(label: 'Photo', onTap: () => taps++),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('Photo'), findsNothing);
    expect(taps, 0);
    final SemanticsNode node = tester.getSemantics(find.text('Ajouter'));
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('un menu recalé en fin de ligne choisit encore', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    var taps = 0;
    await tester.pumpWidget(
      harness(
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ZChatComposerPickerTrigger(
            actions: <ZChatComposerPickerAction>[
              ZChatComposerPickerAction(
                label: 'Importer un document très long',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Importer un document très long'));
    await tester.pump();
    expect(taps, 1);
  });
}
