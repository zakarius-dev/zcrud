// Tests DISCRIMINANTS ES-8.1 — `ZTagChips` : adaptateur MINCE d'affichage qui
// COMPOSE des primitives DÉJÀ TESTÉES au kernel (`remapColorKey`/`ZColorPalette`)
// + du cœur (`zResolveColorKeyOrSlot`). Ancrage R20/R24 : les assertions portent
// sur les LIGNES PROPRES au widget (le FIL palette→chip, la DÉRIVATION du compteur
// au rendu, le titre textuel toujours présent, la cible ≥ 48 dp), JAMAIS sur la
// correction de `remapColorKey`/`ZColorPalette` (re-tester serait POWERLESS).
//
// Pouvoir discriminant (R12) : chaque AC rougit sous l'injection R3 correspondante.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Enveloppe déterministe : `MaterialApp` (thème), direction fixe, `ZcrudScope`
/// (injection zéro-config AD-15), taille bornée.
Widget _host(
  Widget child, {
  ZcrudTheme? theme,
  TextDirection dir = TextDirection.ltr,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(
        theme: theme,
        child: Scaffold(
          body: SizedBox(width: 800, height: 600, child: child),
        ),
      ),
    ),
  );
}

Color _chipBg(WidgetTester tester, String keyId) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(ValueKey<String>('z-tag-chip-bg:$keyId')),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  // ===========================================================================
  // AC1 — Palette INJECTÉE filée jusqu'à la couleur du chip (fil palette→chip).
  // ===========================================================================
  group('AC1 — fil palette→chip (remapColorKey → zResolveColorKeyOrSlot)', () {
    // `colorKey` INCONNUE de la palette ⇒ soumise au remap (AC1). Palettes à UNE
    // clé ⇒ remap DÉTERMINISTE (indépendant du hash) mais clés DIFFÉRENTES ⇒
    // slots Material distincts ⇒ couleurs résolues distinctes.
    final tag = ZFlashcardTag(id: 't1', title: 'X', colorKey: 'unknown-key');
    final paletteA = ZColorPalette(keys: const ['primary'], fallbackKey: 'primary');
    final paletteB =
        ZColorPalette(keys: const ['secondary'], fallbackKey: 'secondary');

    testWidgets('couleur du chip == résolveur(palette INJECTÉE) — palette A',
        (tester) async {
      await tester
          .pumpWidget(_host(ZTagChips(tags: <ZFlashcardTag>[tag], palette: paletteA)));
      await tester.pump();

      final ctx = tester.element(find.byKey(const ValueKey<String>('z-tag-chip-bg:t1')));
      final remapped = remapColorKey(
        palette: paletteA,
        rawColorKey: tag.colorKey,
        seedTitle: tag.title,
      );
      final expected = zResolveColorKeyOrSlot(
        ctx,
        remapped,
        slotIndex: paletteA.indexOf(remapped),
      );
      // R20 : ancrage sur le FIL palette→chip PROPRE au widget (R3-I1 : palette
      // ignorée / clé codée en dur ⇒ couleur ≠ expected ⇒ rouge).
      expect(_chipBg(tester, 't1'), expected.color);
    });

    testWidgets('changer la palette INJECTÉE change la couleur résolue (R3-I1)',
        (tester) async {
      await tester
          .pumpWidget(_host(ZTagChips(tags: <ZFlashcardTag>[tag], palette: paletteA)));
      await tester.pump();
      final colorA = _chipBg(tester, 't1');

      await tester
          .pumpWidget(_host(ZTagChips(tags: <ZFlashcardTag>[tag], palette: paletteB)));
      await tester.pump();
      final colorB = _chipBg(tester, 't1');

      // Discriminant R3-I1 : une palette codée en dur (ignorant `widget.palette`)
      // rendrait colorA == colorB.
      expect(colorA == colorB, isFalse,
          reason: 'palette injectée ignorée ⇒ même couleur (R3-I1)');
    });
  });

  // ===========================================================================
  // AC4 — `usageCount` DÉRIVÉ au rendu (jamais un champ figé — AD-19).
  // ===========================================================================
  group('AC4 — compteur DÉRIVÉ au rendu', () {
    testWidgets('le compteur reflète referencingCardsCountOf recalculé (R3-I4)',
        (tester) async {
      final counts = <String, int>{'a': 3, 'b': 1};
      final tags = <ZFlashcardTag>[
        const ZFlashcardTag(id: 'a', title: 'Alpha'),
        const ZFlashcardTag(id: 'b', title: 'Beta'),
      ];

      late StateSetter rebuild;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return ZTagChips(
            tags: tags,
            showUsageCount: true,
            referencingCardsCountOf: (t) => counts[t.id] ?? 0,
          );
        },
      )));
      await tester.pump();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey<String>('z-tag-usage:a')))
            .data,
        '3',
      );

      // Mutation de la source DÉRIVÉE + rebuild : un compteur figé (passé en props
      // une fois) resterait à '3' ⇒ R3-I4 rougirait.
      counts['a'] = 7;
      rebuild(() {});
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey<String>('z-tag-usage:a')))
            .data,
        '7',
      );
    });

    testWidgets('après retrait d\'un tag : compteur du tag absent, autres exacts',
        (tester) async {
      final counts = <String, int>{'a': 3, 'b': 5};
      var tags = <ZFlashcardTag>[
        const ZFlashcardTag(id: 'a', title: 'Alpha'),
        const ZFlashcardTag(id: 'b', title: 'Beta'),
      ];
      late StateSetter rebuild;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return ZTagChips(
            tags: tags,
            showUsageCount: true,
            referencingCardsCountOf: (t) => counts[t.id] ?? 0,
          );
        },
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('z-tag-usage:b')), findsOneWidget);

      tags = <ZFlashcardTag>[const ZFlashcardTag(id: 'a', title: 'Alpha')];
      rebuild(() {});
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('z-tag-usage:b')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey<String>('z-tag-usage:a')))
            .data,
        '3',
      );
    });
  });

  // ===========================================================================
  // AC6 — A11y : titre TOUJOURS visible, ≥ 48 dp, labels INJECTÉS, directionnel.
  // ===========================================================================
  group('AC6 — couleur jamais seul canal / a11y', () {
    testWidgets('le TITRE textuel est rendu pour chaque chip (R3-I7)',
        (tester) async {
      final tags = <ZFlashcardTag>[
        const ZFlashcardTag(id: 'a', title: 'Droit'),
        const ZFlashcardTag(id: 'b', title: 'Fiscalité'),
      ];
      await tester.pumpWidget(_host(ZTagChips(tags: tags)));
      await tester.pump();

      // Discriminant R3-I7 : rendre la pastille SEULE (sans titre) rougirait.
      expect(find.text('Droit'), findsOneWidget);
      expect(find.text('Fiscalité'), findsOneWidget);
    });

    testWidgets('bouton de suppression ≥ 48 dp + label sémantique INJECTÉ',
        (tester) async {
      final handle = tester.ensureSemantics();
      final tag = const ZFlashcardTag(id: 'a', title: 'Droit');
      await tester.pumpWidget(_host(ZTagChips(
        tags: <ZFlashcardTag>[tag],
        onTagRemoved: (_) {},
        removeTagSemanticLabel: (t) => 'DEL-${t.id}',
      )));
      await tester.pump();

      // R3-I8 : cible < 48 dp rougirait ; ancrage sur la ConstrainedBox PROPRE.
      final box = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(IconButton),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48.0));
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48.0));

      // R3-I9 : label codé en dur ('Supprimer') ≠ label injecté ⇒ rouge.
      expect(find.bySemanticsLabel('DEL-a'), findsOneWidget);
      handle.dispose();
    });

    test('verrou-source : aucune Color/hex/EdgeInsets.only(left) codé en dur', () {
      final src =
          File('lib/src/presentation/z_tag_chips.dart').readAsStringSync();
      expect(src.contains('Colors.'), isFalse);
      expect(RegExp(r'0x[0-9a-fA-F]{6,8}').hasMatch(src), isFalse);
      expect(src.contains('EdgeInsets.only(left'), isFalse);
      expect(src.contains('Alignment.centerLeft'), isFalse);
      expect(src.contains('TextAlign.left'), isFalse);
    });
  });
}
