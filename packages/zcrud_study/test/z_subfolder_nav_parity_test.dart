/// SUF-3 — **PARITÉ DE CAPACITÉS de part et d'autre du seuil de bascule**
/// (600 dp) : une même `ZSubfolderNavSpec` doit produire le MÊME contrat, que la
/// nav soit rendue en **sidebar** (≥ 600) ou en **sélecteur compact** (< 600).
///
/// C'est la mitigation documentée du risque **R-SUF2** (couture SUF-2 ↔ SUF-3) :
/// le seam `itemBuilder` existe précisément pour qu'un hôte branche son propre
/// rendu (p. ex. basé `ZFolderCard`) sans que SUF-3 se couple à sa signature. Un
/// seam honoré d'un seul côté du seuil est un seam CASSÉ.
///
/// Chaque garde est jouée sur les DEUX largeurs — jamais sur un flag.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Pastilles d'accent d'ITEM (containers circulaires), hors pastille d'en-tête
/// de page (clé `ZStudyFolderDetail.accentKey`).
Finder _itemPastilles() => find.byWidgetPredicate(
      (Widget w) =>
          w is Container &&
          w.key != ZStudyFolderDetail.accentKey &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    );

/// Active l'item injecté [id] (le sélecteur compact défile horizontalement :
/// l'item peut être hors du viewport à 500 dp).
Future<void> _tapItem(WidgetTester tester, String id) async {
  final Finder f = find.byKey(ValueKey<String>('custom:$id'));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Largeurs locales RÉELLES encadrant le seuil `mediumMinWidth` (600).
const Map<String, double> _sides = <String, double>{
  'compact (<600)': 500,
  'sidebar (≥600)': 900,
};

/// CR-IFFD-40 — sous le seuil, ces gardes visent la RANGÉE DE PUCES
/// (`ZSubfolderCompactSelector`), qui n'est plus la surface par DÉFAUT. Le mode
/// est donc NOMMÉ explicitement : c'est exactement ce qu'un hôte écrit pour
/// revenir au comportement historique, et ces gardes deviennent du même coup la
/// preuve de non-régression de ce mode. La parité de la nouvelle surface par
/// défaut est gardée par `cr_iffd40_subfolder_selector_test.dart`.
const ZSubfolderNarrowMode _chips = ZSubfolderNarrowMode.compact;

void main() {
  group('R-SUF2 — le seam itemBuilder est honoré des DEUX côtés du seuil', () {
    _sides.forEach((String side, double width) {
      testWidgets('$side : itemBuilder INJECTÉ appelé pour racine + items',
          (tester) async {
        await setScreen(tester, width, 800);
        final seen = <String>[];
        await pumpDetail(
          tester,
          nav: navSpec(
            narrowMode: _chips,
            itemBuilder: (context, ref, selected) {
              seen.add('${ref.id}:$selected');
              return Text(
                'CUSTOM:${ref.id}',
                key: ValueKey<String>('custom:${ref.id}'),
              );
            },
          ),
        );

        // GARDE MORDANTE : le sélecteur compact IGNORAIT `spec.itemBuilder`
        // (il rendait `Text(label)` en dur) ⇒ à 500 dp, ces marqueurs étaient
        // introuvables et `seen` restait vide.
        for (final id in <String>['', 'sf0', 'sf1', 'sf2']) {
          expect(
            find.byKey(ValueKey<String>('custom:$id')),
            findsOneWidget,
            reason: '$side : itemBuilder non appelé pour « $id »',
          );
        }
        // Le rendu par DÉFAUT ne doit plus apparaître : le builder REMPLACE.
        expect(find.text('Sous-dossier 0'), findsNothing);
        expect(seen, isNotEmpty);
      });

      testWidgets('$side : le flag `selected` du builder SUIT la sélection',
          (tester) async {
        await setScreen(tester, width, 800);
        final seen = <String>[];
        await pumpDetail(
          tester,
          nav: navSpec(
            narrowMode: _chips,
            itemBuilder: (context, ref, selected) {
              seen.add('${ref.id}:$selected');
              return Text(
                'CUSTOM:${ref.id}',
                key: ValueKey<String>('custom:${ref.id}'),
              );
            },
          ),
        );

        // Au départ : racine sélectionnée (sentinelle id vide), sf1 non.
        expect(seen, contains(':true'));
        expect(seen, contains('sf1:false'));

        seen.clear();
        await _tapItem(tester, 'sf1');

        // GARDE MORDANTE : passer une constante à la place de `isSelected`
        // (ou ne jamais re-invoquer le builder) empêcherait ce basculement.
        expect(seen, contains('sf1:true'));
        expect(seen, contains(':false'));
      });

      testWidgets('$side : la sélection reste FILTRANTE avec un itemBuilder',
          (tester) async {
        await setScreen(tester, width, 800);
        await pumpDetail(
          tester,
          nav: navSpec(
            narrowMode: _chips,
            itemBuilder: (context, ref, selected) => Text(
              'CUSTOM:${ref.id}',
              key: ValueKey<String>('custom:${ref.id}'),
            ),
          ),
        );

        expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
        await _tapItem(tester, 'sf2');
        // Le rendu injecté ne coupe PAS la voie de sélection (AC9).
        expect(find.byKey(const ValueKey<String>('empty:sf2')), findsOneWidget);
      });
    });
  });

  group('R-SUF2 — la surbrillance de sélection reste posée par SUF-3', () {
    testWidgets('sidebar : le contenu INJECTÉ est mis en évidence lui aussi',
        (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(
        tester,
        nav: navSpec(
          itemBuilder: (context, ref, selected) => Text(
            'CUSTOM:${ref.id}',
            key: ValueKey<String>('custom:${ref.id}'),
          ),
        ),
      );

      bool decorated(String id) => tester
          .widgetList<Container>(
            find.ancestor(
              of: find.byKey(ValueKey<String>('custom:$id')),
              matching: find.byType(Container),
            ),
          )
          .any((Container c) => c.decoration != null);

      // GARDE MORDANTE : la surbrillance était posée DANS `_defaultContent` —
      // donc jamais appliquée quand `itemBuilder` remplaçait ce contenu :
      // l'écran contredisait le `Semantics(selected:)`. La remettre à
      // l'intérieur de `_defaultContent` fait rougir les deux `isTrue`.
      expect(decorated(''), isTrue, reason: 'racine sélectionnée au départ');
      expect(decorated('sf1'), isFalse);

      await _tapItem(tester, 'sf1');

      expect(decorated('sf1'), isTrue);
      expect(decorated(''), isFalse);
    });

    testWidgets('compact : la puce du contenu INJECTÉ porte `selected`',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: navSpec(
          narrowMode: _chips,
          itemBuilder: (context, ref, selected) => Text(
            'CUSTOM:${ref.id}',
            key: ValueKey<String>('custom:${ref.id}'),
          ),
        ),
      );

      bool chipSelected(String id) => tester
          .widget<ChoiceChip>(
            find
                .ancestor(
                  of: find.byKey(ValueKey<String>('custom:$id')),
                  matching: find.byType(ChoiceChip),
                )
                .first,
          )
          .selected;

      expect(chipSelected(''), isTrue);
      expect(chipSelected('sf1'), isFalse);

      await _tapItem(tester, 'sf1');

      // GARDE MORDANTE : figer `selected: false` (ou déléguer la mise en
      // évidence à l'`itemBuilder`) ferait rougir cette bascule.
      expect(chipSelected('sf1'), isTrue);
      expect(chipSelected(''), isFalse);
    });
  });

  group('Parité du rendu par DÉFAUT : mêmes informations des deux côtés', () {
    _sides.forEach((String side, double width) {
      testWidgets('$side : compteur et pastille d\'accent rendus',
          (tester) async {
        await setScreen(tester, width, 800);
        await pumpDetail(
          tester,
          nav: navSpec(narrowMode: _chips),
        ); // refs() : count 0..2, colorKey alternée

        // GARDE MORDANTE : le sélecteur compact n'affichait NI `ref.count` NI
        // `ref.colorKey` (chips en texte nu) ⇒ ces attentes rougissaient à
        // 500 dp alors qu'elles passaient à 900 dp.
        for (final c in <String>['0', '1', '2']) {
          expect(
            find.text(c),
            findsWidgets,
            reason: '$side : compteur « $c » absent',
          );
        }
        // Pastilles d'accent (un `Container` circulaire par sous-dossier).
        expect(
          _itemPastilles(),
          findsNWidgets(3),
          reason: '$side : pastilles d\'accent absentes',
        );
      });
    });
  });
}
