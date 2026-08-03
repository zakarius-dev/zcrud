/// SUF-3 AC8 (item racine + surbrillance sélection) et AC9 (la sélection FILTRE
/// le corps Matériel en re-invoquant `materialSectionsBuilder`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// L'item portant [text] a-t-il (dans un de ses `Semantics` ancêtres directs)
/// `selected == true` ? Évite les API `SemanticsFlag` dépréciées.
bool _itemSelected(WidgetTester t, String text) {
  final ancestors = find.ancestor(
    of: find.text(text),
    matching: find.byType(Semantics),
  );
  return t
      .widgetList<Semantics>(ancestors)
      .any((s) => s.properties.selected == true);
}

void main() {
  group('AC8 — item racine « Tous » + surbrillance de la sélection', () {
    testWidgets('sélection initiale = racine ; sélectionner l\'index 1 la déplace',
        (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);

      // Racine sélectionnée, sous-dossiers non sélectionnés.
      expect(_itemSelected(tester, kAllLabel), isTrue);
      expect(_itemSelected(tester, 'Sous-dossier 1'), isFalse);

      await tester.tap(find.text('Sous-dossier 1'));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : figer la surbrillance sur la racine empêcherait ce
      // déplacement (rouge).
      expect(_itemSelected(tester, 'Sous-dossier 1'), isTrue);
      expect(_itemSelected(tester, kAllLabel), isFalse);
    });
  });

  group('AC9 — la sélection re-invoque le builder et change le corps Matériel',
      () {
    testWidgets('sidebar : sélectionner sf1 ⇒ builder(sf1) + contenu de sf1',
        (tester) async {
      await setScreen(tester, 900, 800);
      final calls = <String?>[];
      await pumpDetail(
        tester,
        materialSectionsBuilder: (id) {
          calls.add(id);
          return defaultSections(id);
        },
      );

      expect(calls.last, isNull); // racine au départ
      expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);

      await tester.tap(find.text('Sous-dossier 1'));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : ignorer l'id (toujours builder(null)) laisserait
      // `empty:null` et n'appellerait jamais builder('sf1') (rouge).
      expect(calls.contains('sf1'), isTrue);
      expect(find.byKey(const ValueKey<String>('empty:sf1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('empty:null')), findsNothing);
    });

    testWidgets('sélecteur compact : la puce filtre aussi le corps Matériel',
        (tester) async {
      await setScreen(tester, 500, 800);
      // CR-IFFD-40 — surface NOMMÉE : cette garde vise la rangée de puces. La
      // même voie de sélection est gardée sur la surface par DÉFAUT dans
      // `cr_iffd40_subfolder_selector_test.dart`.
      await pumpDetail(
        tester,
        nav: navSpec(narrowMode: ZSubfolderNarrowMode.compact),
      );

      expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
      await tester.tap(find.text('Sous-dossier 0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('empty:sf0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('empty:null')), findsNothing);
    });
  });
}
