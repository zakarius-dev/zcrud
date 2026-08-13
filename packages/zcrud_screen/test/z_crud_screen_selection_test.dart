// Gardes de la SÉLECTION MULTIPLE et des ACTIONS DE MASSE de `ZCrudScreen`.
//
// Ce que ces gardes tiennent, dans l'ordre :
//  - contre-témoin : sans politique de sélection déclarée, l'écran est celui
//    d'avant (aucune case, aucune barre) ;
//  - la barre d'actions de masse apparaît à la sélection, disparaît au vide ;
//  - un droit refusé retire l'action de masse (masquage) ou la rend inerte
//    (mode `disable`) — dans les deux cas AUCUNE écriture ;
//  - une entité que la gouvernance de ligne n'admet pas est EXCLUE du lot :
//    l'assertion porte sur ce qui a réellement été écrit au dépôt ;
//  - un échec PARTIEL est notifié avec le compte exact et les noms des
//    éléments en échec (le legacy avalait ces échecs) ;
//  - annuler la confirmation n'écrit rien (assertion d'ABSENCE d'appel) ;
//  - la sélection est vidée après une action de masse et à la bascule de vue ;
//  - cocher une case ne relit pas la source (coût, AD-2).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZConfirmDialog;

import 'support/fixtures.dart';

/// Dépôt qui **échoue** sur les identités déclarées, et réussit sur les autres
/// — le seul moyen d'observer un lot partiellement en échec.
class FailingItemRepo extends FakeItemRepo {
  FailingItemRepo(super.seed, this.failing);

  final Set<String> failing;

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    if (failing.contains(id)) return Left(ZServerFailure('boom $id'));
    return super.softDelete(id);
  }
}

const List<Item> _seed = <Item>[
  Item(id: 'a', name: 'Alpha', qty: 1),
  Item(id: 'b', name: 'Bravo', qty: 2),
  Item(id: 'c', name: 'Charlie', qty: 3),
];

Widget _screen(
  FakeItemRepo repo, {
  ZSelectionPolicy? selection,
  ZRowAclResolver<Item>? rowAcl,
  ZActionAclMode actionAclMode = ZActionAclMode.hide,
  bool confirmDestructive = true,
  ZRowLongPressOwner longPressOwner = ZRowLongPressOwner.contextMenu,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      selection: selection,
      rowAcl: rowAcl,
      actionAclMode: actionAclMode,
      confirmDestructive: confirmDestructive,
      longPressOwner: longPressOwner,
    );

/// Coche la ligne [id].
Future<void> _tick(WidgetTester tester, String id) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey<String>('zListRow_$id')),
      matching: find.byType(Checkbox),
    ),
  );
  await tester.pumpAndSettle();
}

final Finder _bar = find.byKey(const ValueKey('zCrudBatchBar'));

/// Texte de la NOTIFICATION (et non d'une tuile de liste, qui porte les mêmes
/// mots) : la portée est le `SnackBar` du repli de notification du socle.
Finder _toastContaining(String text) => find.descendant(
      of: find.byType(SnackBar),
      matching: find.textContaining(text),
    );

/// Bouton [icon] de la barre d'actions de masse (jamais celui d'une ligne).
Finder _barAction(IconData icon) =>
    find.descendant(of: _bar, matching: find.byIcon(icon));

void main() {
  group('CONTRE-TÉMOIN — sans sélection déclarée, rien ne change', () {
    testWidgets('aucune case à cocher, aucune barre d\'actions de masse',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo));

      expect(find.byType(Checkbox), findsNothing);
      expect(_bar, findsNothing);
      // La liste, elle, est bien rendue : l'absence de sélection n'est pas
      // l'absence d'écran.
      expect(find.byKey(const ValueKey('zListRow_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('zListRow_c')), findsOneWidget);
    });
  });

  group('PRÉSENCE — la barre suit la sélection', () {
    testWidgets('absente à vide, présente dès la première case cochée',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(_bar, findsNothing);

      await _tick(tester, 'a');
      expect(_bar, findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);

      await _tick(tester, 'b');
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('disparaît quand la sélection se vide', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await _tick(tester, 'a');
      expect(_bar, findsOneWidget);
      await _tick(tester, 'a');
      expect(_bar, findsNothing);
    });
  });

  group('GOUVERNANCE — le droit refusé ferme l\'action de masse', () {
    testWidgets('masquage (défaut) : aucune action, donc aucune barre',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
      );

      await _tick(tester, 'a');
      expect(_bar, findsNothing);
      expect(repo.softDeleted, isEmpty);
    });

    testWidgets(
        'mode inerte : l\'action garde sa place, GRISÉE, annoncée désactivée, '
        'et N\'ÉCRIT RIEN', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final handle = tester.ensureSemantics();
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: const ZSelectionPolicy(),
          actionAclMode: ZActionAclMode.disable,
        ),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
      );

      await _tick(tester, 'a');
      expect(_bar, findsOneWidget);

      // Présente (le masquage, c'est l'autre mode)…
      final barButton = find.ancestor(
        of: _barAction(Icons.delete_outline),
        matching: find.byType(IconButton),
      );
      // … et INERTE : aucun callback, donc rien à invoquer.
      expect(tester.widget<IconButton>(barButton).onPressed, isNull);
      // Annoncée désactivée, motif du refus à l'appui.
      final semantics = tester.getSemantics(barButton);
      expect(
        semantics.flagsCollection.isEnabled,
        Tristate.isFalse,
        reason: 'une action fermée doit être ANNONCÉE fermée (AD-13)',
      );
      expect(semantics.hint, contains('You are not allowed'));

      // Et la source n'a rien reçu.
      await tester.tap(_barAction(Icons.delete_outline), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.softDeleted, isEmpty);
      handle.dispose();
    });
  });

  group('ÉLIGIBILITÉ — une ligne non admise est EXCLUE du lot', () {
    testWidgets('seules les entités admises sont écrites', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: const ZSelectionPolicy(),
          rowAcl: (item) => item.id == 'b'
              ? const ZRowPermissions.denying(<ZCrudAction>{ZCrudAction.delete})
              : const ZRowPermissions.unrestricted(),
        ),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'b');
      await _tick(tester, 'c');
      await tester.tap(_barAction(Icons.delete_outline));
      await tester.pumpAndSettle();
      await confirmDestructiveDialog(tester);

      // Assertion sur ce qui a RÉELLEMENT été écrit, pas sur l'affichage.
      expect(repo.softDeleted, <String>['a', 'c']);
      // L'exclusion est dite, jamais silencieuse.
      expect(_toastContaining('1 skipped'), findsOneWidget);
    });
  });

  group('COMPTE RENDU — un échec partiel est NOTIFIÉ', () {
    testWidgets('le compte exact et les éléments en échec sont annoncés',
        (tester) async {
      final repo = FailingItemRepo(_seed, <String>{'b', 'c'});
      addTearDown(repo.dispose);
      ZBatchReport? received;
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: ZSelectionPolicy(onReport: (r) => received = r),
        ),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'b');
      await _tick(tester, 'c');
      await tester.tap(_barAction(Icons.delete_outline));
      await tester.pumpAndSettle();
      await confirmDestructiveDialog(tester);

      // Le legacy affichait « fait » : ici le lot rend des comptes.
      expect(_toastContaining('1 succeeded'), findsOneWidget);
      expect(_toastContaining('2 failed'), findsOneWidget);
      // …et NOMME les éléments en échec.
      expect(_toastContaining('Bravo'), findsOneWidget);
      expect(_toastContaining('Charlie'), findsOneWidget);
      // Le rapport complet est remis à l'application.
      expect(received, isNotNull);
      expect(received!.succeededRootIds, <String>{'a'});
      expect(received!.failedRootIds, <String>{'b', 'c'});
    });

    testWidgets('un lot entièrement réussi annonce son compte', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'b');
      await tester.tap(_barAction(Icons.delete_outline));
      await tester.pumpAndSettle();
      await confirmDestructiveDialog(tester);

      expect(repo.softDeleted, <String>['a', 'b']);
      expect(_toastContaining('2 succeeded'), findsOneWidget);
    });
  });

  group('CONFIRMATION — annuler n\'écrit rien', () {
    testWidgets('le nombre d\'éléments figure dans la question',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'b');
      await tester.tap(_barAction(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('(2)'), findsOneWidget);
    });

    testWidgets('ANNULER ⇒ aucun appel à la source', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'b');
      await tester.tap(_barAction(Icons.delete_outline));
      await tester.pumpAndSettle();
      await cancelDestructiveDialog(tester);

      expect(repo.softDeleted, isEmpty);
      // La sélection survit à l'annulation : rien n'a eu lieu.
      expect(_bar, findsOneWidget);
    });
  });

  group('CYCLE DE VIE — la sélection ne traîne pas', () {
    testWidgets('vidée après une action de masse', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await _tick(tester, 'a');
      await tester.tap(_barAction(Icons.delete_outline));
      await tester.pumpAndSettle();
      await confirmDestructiveDialog(tester);

      expect(repo.softDeleted, <String>['a']);
      expect(_bar, findsNothing);
    });

    testWidgets('vidée à la bascule vivants ⇄ corbeille', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await _tick(tester, 'a');
      expect(_bar, findsOneWidget);
      await openTrashView(tester);
      expect(_bar, findsNothing);
    });

    testWidgets('la corbeille a ses PROPRES actions de masse', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      await _tick(tester, 'a');

      // Restaurer (geste de corbeille) est offert ; la mise à la corbeille,
      // qui n'a pas de sens ici, ne l'est pas.
      expect(_barAction(Icons.restore_from_trash), findsOneWidget);
      expect(_barAction(Icons.delete_outline), findsNothing);

      await tester.tap(_barAction(Icons.restore_from_trash));
      await tester.pumpAndSettle();
      // La restauration n'est pas destructive : aucune confirmation.
      expect(find.byType(ZConfirmDialog), findsNothing);
      expect(repo.restored, <String>['a']);
    });
  });

  group('COÛT — cocher une case ne relit pas la source (AD-2)', () {
    testWidgets('aucune requête supplémentaire à la sélection', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      final before = repo.getAllCalls;
      await _tick(tester, 'a');
      await _tick(tester, 'b');
      await _tick(tester, 'a');
      expect(repo.getAllCalls, before);
    });
  });

  group('ARBITRAGE — un seul propriétaire pour l\'appui long', () {
    testWidgets(
        'appui long DÉCLARÉ à la sélection : il l\'ouvre, et la barre paraît',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: const ZSelectionPolicy(),
          longPressOwner: ZRowLongPressOwner.selection,
        ),
      );

      expect(
        find.byType(Checkbox),
        findsNothing,
        reason: 'sélection fermée tant que rien n\'est sélectionné',
      );
      expect(_bar, findsNothing);

      await tester.longPress(find.textContaining('Bravo').first);
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(_bar, findsOneWidget);
    });

    testWidgets(
        'CONTRE-TÉMOIN — sans déclaration, l\'appui long ne sélectionne pas',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, selection: const ZSelectionPolicy()),
      );

      // Cases d'emblée (défaut), barre absente tant que rien n'est coché.
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(_bar, findsNothing);

      await tester.longPress(find.textContaining('Bravo').first);
      await tester.pumpAndSettle();
      expect(_bar, findsNothing);
    });
  });
}
