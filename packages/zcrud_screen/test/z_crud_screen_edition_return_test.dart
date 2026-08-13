// Gardes du **retour vers l'édition depuis la fiche**
// (`ZCrudEditionScope.onEdit`).
//
// Ce que ces gardes mesurent :
//
// (a) `onEdit` est non nul EN FICHE si et seulement si `ZCrudAction.update`
//     est accordé — même contrat que `zCrudEditionOpener` : `null` veut dire
//     « ne dessinez pas le bouton » ;
// (b) l'invoquer rend le formulaire ÉDITABLE, et la garde s'assère sur la
//     VALEUR écrite (le dépôt reçoit la saisie), pas sur l'apparence ;
// (c) la bascule ne referme rien : le formulaire n'est pas remonté (son
//     `State` survit) — sans quoi « basculer » ne serait qu'une réouverture ;
// (d) en `ZScreenMode.locked`, et sur une surface déjà en édition, `onEdit`
//     est nul ;
// (e) hors écran assemblé, `onEditOf` rend `null` (repli sûr, AD-10).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Formulaire d'application **à état**, qui relève ce que le scope lui dit et
/// compte ses MONTAGES : c'est ce compteur qui distingue une bascule d'une
/// réouverture.
class _HostForm extends StatefulWidget {
  const _HostForm({required this.spy});

  final _ScopeSpy spy;

  @override
  State<_HostForm> createState() => _HostFormState();
}

class _HostFormState extends State<_HostForm> {
  @override
  void initState() {
    super.initState();
    widget.spy.mounts++;
  }

  @override
  Widget build(BuildContext context) {
    widget.spy.readOnly.add(ZCrudEditionScope.readOnlyOf(context));
    final onEdit = ZCrudEditionScope.onEditOf(context);
    widget.spy.onEdit.add(onEdit);
    return TextButton(
      key: const ValueKey('hostEdit'),
      // Le contrat : `null` ⇒ le bouton n'est pas dessiné actif.
      onPressed: onEdit,
      child: const Text('Modifier'),
    );
  }
}

class _ScopeSpy {
  int mounts = 0;
  final List<bool> readOnly = <bool>[];
  final List<ZCrudOpener?> onEdit = <ZCrudOpener?>[];
}

/// Ouvre la fiche de la première ligne.
Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.visibility_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'garde (a) — `onEdit` est offert en fiche quand `update` est accordé, et '
      'nul quand il est refusé', (tester) async {
    Future<ZCrudOpener?> lastOnEdit({required ZAcl acl}) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      final spy = _ScopeSpy();
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          mode: ZScreenMode.details,
          editionBuilder: (context, initial, save) => _HostForm(spy: spy),
        ),
        acl: acl,
      );
      await _openDetails(tester);
      expect(spy.readOnly, isNotEmpty);
      expect(spy.readOnly.last, isTrue, reason: 'la fiche est une lecture');
      final result = spy.onEdit.last;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      repo.dispose();
      return result;
    }

    expect(await lastOnEdit(acl: const ZAllowAllAcl()), isNotNull);
    expect(
      await lastOnEdit(acl: const DenyAcl(<ZCrudAction>{ZCrudAction.update})),
      isNull,
    );
  });

  testWidgets(
      'garde (b) — l\'invoquer rend le formulaire ÉDITABLE : la saisie atteint '
      'le dépôt (assertion sur la VALEUR)', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
      ),
    );
    await _openDetails(tester);
    // Point de départ : rien n'est saisissable, rien ne s'enregistre.
    expect(find.byType(EditableText), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);

    // La fiche porte le rappel : on le prend là où l'application le prendrait.
    final scope = ZCrudEditionScope.maybeOf(
      tester.element(find.byKey(const ValueKey('zCrudFormTitle'))),
    );
    expect(scope, isNotNull);
    expect(scope!.onEdit, isNotNull);
    await scope.onEdit!();
    await tester.pumpAndSettle();

    // La fiche est devenue une édition : il y a désormais où taper, et de quoi
    // enregistrer.
    expect(find.byType(EditableText), findsWidgets);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsOneWidget);

    // Les valeurs déjà chargées ont SURVÉCU à la bascule : le champ ne
    // repart pas vide (le contrôleur de formulaire n'a pas été recréé).
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('name')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Alpha',
    );

    // La surface est maintenant éditable — et on le prouve par la VALEUR qui
    // en ressort, pas par un pixel : on saisit, on enregistre, le dépôt reçoit.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('name')),
        matching: find.byType(EditableText),
      ),
      'Beta',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.id, 'i1');
    expect(repo.saved.single.name, 'Beta');
    repo.dispose();
  });

  testWidgets(
      'garde (b bis) — le titre suit la bascule : « Details » devient celui de '
      'la modification', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        titles: const ZCrudTitles(
          read: 'Fiche du consignataire',
          update: 'Modifier le consignataire',
        ),
      ),
    );
    await _openDetails(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('zCrudFormTitle'))).data,
      'Fiche du consignataire',
    );
    final scope = ZCrudEditionScope.maybeOf(
      tester.element(find.byKey(const ValueKey('zCrudFormTitle'))),
    )!;
    await scope.onEdit!();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('zCrudFormTitle'))).data,
      'Modifier le consignataire',
    );
    repo.dispose();
  });

  testWidgets(
      'garde (c) — la bascule NE REFERME PAS la surface : le formulaire de '
      'l\'application n\'est pas remonté', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final spy = _ScopeSpy();
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        editionBuilder: (context, initial, save) => _HostForm(spy: spy),
      ),
    );
    await _openDetails(tester);
    expect(spy.mounts, 1);
    expect(spy.readOnly.last, isTrue);

    await tester.tap(find.byKey(const ValueKey('hostEdit')));
    await tester.pumpAndSettle();

    // La surface est passée en édition…
    expect(spy.readOnly.last, isFalse);
    // …et le `State` du formulaire a SURVÉCU : une fermeture suivie d'une
    // réouverture l'aurait remonté (c'est le comportement que ce lot évite).
    expect(spy.mounts, 1);
    // Le geste ne se propose plus : la surface est déjà éditable.
    expect(spy.onEdit.last, isNull);
    repo.dispose();
  });

  testWidgets(
      'garde (d) — `onEdit` est nul en `ZScreenMode.locked` et sur une surface '
      'ouverte EN ÉDITION', (tester) async {
    // Verrouillé : la fiche ne s'ouvre même pas — donc aucun `onEdit`.
    final lockedRepo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha')],
    );
    final lockedSpy = _ScopeSpy();
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(lockedRepo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.locked,
        detailsEnabled: true,
        editionBuilder: (context, initial, save) => _HostForm(spy: lockedSpy),
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(lockedSpy.onEdit, isEmpty);
    lockedRepo.dispose();

    // Écran complet, surface ouverte EN ÉDITION : le geste n'a pas d'objet.
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final spy = _ScopeSpy();
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        editionBuilder: (context, initial, save) => _HostForm(spy: spy),
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(spy.readOnly.last, isFalse);
    expect(spy.onEdit.last, isNull);
    repo.dispose();
  });

  testWidgets(
      'garde (e) — hors écran assemblé, `onEditOf` rend `null` (repli sûr)',
      (tester) async {
    ZCrudOpener? seen;
    var probed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            probed = true;
            seen = ZCrudEditionScope.onEditOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(probed, isTrue);
    expect(seen, isNull);
    // …et le scope posé seul, sans écran, reste lisible : c'est bien la valeur
    // portée qui ressort, pas un repli qui masquerait tout.
    ZCrudOpener? inScope;
    Future<void> geste() async {}
    await tester.pumpWidget(
      MaterialApp(
        home: ZCrudEditionScope(
          readOnly: true,
          onEdit: geste,
          child: Builder(
            builder: (context) {
              inScope = ZCrudEditionScope.onEditOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(identical(inScope, geste), isTrue);
  });
}
