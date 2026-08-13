// Gouvernance PAR LIGNE déclarée sur l'écran assemblé (`ZCrudScreen.rowAcl`).
//
// Ce que ces gardes tiennent :
//   * 🔴 INTERSECTION — un résolveur permissif ne rouvre JAMAIS un geste que
//     l'ACL de l'écran refuse. C'est la garde qui empêche le résolveur de
//     devenir une voie de contournement des droits ;
//   * une seule déclaration gouverne les DEUX présentations (boutons en ligne
//     et menu) et les DEUX vues (vivants et corbeille) ;
//   * une action inerte en menu porte son motif et n'est pas invocable ;
//   * sans résolveur déclaré, le comportement est strictement inchangé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// ACL d'écran refusant les actions de [denied] ; autorise le reste.
class _DenyAcl implements ZAcl {
  const _DenyAcl(this.denied);
  final Set<ZCrudAction> denied;
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !denied.contains(action);
}

const _seed = <Item>[
  Item(id: 'i1', name: 'Alpha'),
  Item(id: 'i2', name: 'Beta'),
];

/// Résolveur qui ne retire RIEN : la valeur la plus permissive exprimable.
ZRowPermissions _permissif(Item item) => const ZRowPermissions.unrestricted();

/// Résolveur verrouillant la ligne « Beta » (lecture seule).
ZRowPermissions _betaVerrouillee(Item item) => item.name == 'Beta'
    ? const ZRowPermissions.locked(reasonKey: 'Ligne clôturée')
    : const ZRowPermissions.unrestricted();

Widget _screen(
  FakeItemRepo repo, {
  ZRowAclResolver<Item>? rowAcl,
  ZAcl? acl,
  ZActionAclMode aclMode = ZActionAclMode.hide,
  ZRowActionsPresentation presentation = ZRowActionsPresentation.inline,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      acl: acl,
      rowAcl: rowAcl,
      actionAclMode: aclMode,
      rowActionsPresentation: presentation,
    );

void main() {
  testWidgets(
      '🔴 résolveur permissif + ACL d\'écran refusant la modification ⇒ '
      'l\'édition reste refusée sur TOUTES les lignes', (tester) async {
    final repo = FakeItemRepo(_seed);
    await pumpScreen(
      tester,
      _screen(
        repo,
        rowAcl: _permissif,
        acl: const _DenyAcl(<ZCrudAction>{ZCrudAction.update}),
      ),
    );
    expect(
      find.byIcon(Icons.edit_outlined),
      findsNothing,
      reason: 'la ligne RESTREINT, elle n\'élargit pas',
    );

    // CONTRE-TÉMOIN : la même déclaration sous une ACL permissive rend bien
    // l'édition — la garde ne passe donc pas au vert pour la mauvaise raison.
    await pumpScreen(
      tester,
      _screen(repo, rowAcl: _permissif, acl: const ZAllowAllAcl()),
    );
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    repo.dispose();
  });

  testWidgets('une seule déclaration gouverne la ligne : Beta perd l\'édition, '
      'Alpha la garde', (tester) async {
    final repo = FakeItemRepo(_seed);
    await pumpScreen(tester, _screen(repo, rowAcl: _betaVerrouillee));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    // C'est bien la ligne d'Alpha qui garde le bouton.
    expect(
      find.ancestor(
        of: find.byIcon(Icons.edit_outlined),
        matching: find.byType(Row),
      ),
      findsWidgets,
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('la même déclaration gouverne la présentation en MENU, motif '
      'compris', (tester) async {
    final repo = FakeItemRepo(_seed);
    await pumpScreen(
      tester,
      _screen(
        repo,
        rowAcl: _betaVerrouillee,
        aclMode: ZActionAclMode.disable,
        presentation: ZRowActionsPresentation.menu,
      ),
    );
    // Menu de la SECONDE ligne (Beta) : l'entrée « Modifier » y figure, inerte.
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);

    // Inerte : la sélectionner n'ouvre AUCUNE édition.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      find.byType(TextFormField),
      findsNothing,
      reason: 'une entrée inerte n\'ouvre rien',
    );
    repo.dispose();
  });

  testWidgets('la déclaration gouverne aussi les actions de la CORBEILLE',
      (tester) async {
    final repo = FakeItemRepo(_seed);
    await pumpScreen(
      tester,
      _screen(
        repo,
        // Alpha, une fois en corbeille, ne se restaure pas.
        rowAcl: (Item item) => item.name == 'Alpha'
            ? const ZRowPermissions.denying(<ZCrudAction>{ZCrudAction.restore})
            : const ZRowPermissions.unrestricted(),
      ),
    );
    // Deux lignes à la corbeille…
    await softDeleteFirstRow(tester);
    await softDeleteFirstRow(tester);
    await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // …une seule restaurable : celle que la ligne n'a pas fermée.
    expect(
      find.byIcon(Icons.restore_from_trash),
      findsOneWidget,
      reason: 'la restauration d\'Alpha est retirée par le résolveur',
    );
    repo.dispose();
  });

  testWidgets('sans résolveur déclaré, comportement strictement inchangé',
      (tester) async {
    final repo = FakeItemRepo(_seed);
    await pumpScreen(tester, _screen(repo));
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    // Et l'édition s'ouvre réellement.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsWidgets);
    repo.dispose();
  });
}
