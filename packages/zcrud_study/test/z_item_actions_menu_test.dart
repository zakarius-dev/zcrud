// Tests DISCRIMINANTS ES-5.3 — `ZItemActionsMenu` (AC4, AC6).
//
// AC4 : le menu est paramétré par une List<ZItemAction> (enum kind + callbacks) ;
//   sélectionner une action à callback l'invoque 1× + label/icône INJECTÉS
//   affichés ; une action `onSelected: null` est ABSENTE du menu (AD-4).
//   Pouvoir discriminant R3-I4 : action null rendue ⇒ ROUGE.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const IconData kOpenIcon = Icons.open_in_new;
const IconData kRenameIcon = Icons.edit;
const IconData kDeleteIcon = Icons.delete;
const String kOpenLabel = 'OUVRIR-XYZ';
const String kRenameLabel = 'RENOMMER-XYZ';
const String kDeleteLabel = 'SUPPRIMER-ABSENTE';

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(child: Scaffold(body: Center(child: child))),
    ),
  );
}

void main() {
  testWidgets('AC4 : sélectionner une action à callback l\'invoque 1× (label/icône injectés)',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(_wrap(ZItemActionsMenu(
      tooltip: 'MENU-XYZ',
      actions: [
        ZItemAction(
          kind: ZItemActionKind.open,
          label: kOpenLabel,
          icon: kOpenIcon,
          onSelected: () => opens++,
        ),
        ZItemAction(
          kind: ZItemActionKind.rename,
          label: kRenameLabel,
          icon: kRenameIcon,
          onSelected: () {},
        ),
      ],
    )));

    await tester.tap(find.byType(ZItemActionsMenu));
    await tester.pumpAndSettle();

    // Labels/icônes INJECTÉS affichés dans le menu ouvert.
    expect(find.text(kOpenLabel), findsOneWidget);
    expect(find.text(kRenameLabel), findsOneWidget);
    expect(find.byIcon(kOpenIcon), findsOneWidget);

    await tester.tap(find.text(kOpenLabel));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('AC4 : action onSelected:null ⇒ ABSENTE du menu (AD-4)',
      (tester) async {
    await tester.pumpWidget(_wrap(ZItemActionsMenu(
      actions: [
        ZItemAction(
          kind: ZItemActionKind.open,
          label: kOpenLabel,
          icon: kOpenIcon,
          onSelected: () {},
        ),
        // Action SANS callback : doit être filtrée (absente).
        const ZItemAction(
          kind: ZItemActionKind.delete,
          label: kDeleteLabel,
          icon: kDeleteIcon,
        ),
      ],
    )));

    await tester.tap(find.byType(ZItemActionsMenu));
    await tester.pumpAndSettle();

    expect(find.text(kOpenLabel), findsOneWidget);
    expect(find.text(kDeleteLabel), findsNothing,
        reason: 'action à onSelected null : ABSENTE, jamais grisée ni no-op');
    expect(find.byIcon(kDeleteIcon), findsNothing);
  });

  testWidgets('AC6 : les items du menu ont une cible ≥ 48 dp', (tester) async {
    await tester.pumpWidget(_wrap(ZItemActionsMenu(
      actions: [
        ZItemAction(
          kind: ZItemActionKind.open,
          label: kOpenLabel,
          icon: kOpenIcon,
          onSelected: () {},
        ),
      ],
    )));

    await tester.tap(find.byType(ZItemActionsMenu));
    await tester.pumpAndSettle();

    final itemSize = tester.getSize(find.text(kOpenLabel).first);
    // La ligne d'action (via PopupMenuItem + ConstrainedBox) couvre ≥ 48 dp.
    final rowSize = tester.getSize(
      find.ancestor(of: find.text(kOpenLabel), matching: find.byType(Row)).first,
    );
    expect(rowSize.height, greaterThanOrEqualTo(48.0));
    expect(itemSize.height, greaterThan(0));
  });
}
