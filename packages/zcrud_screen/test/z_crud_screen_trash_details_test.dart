// Gardes de la CONSULTATION EN VUE CORBEILLE.
//
// L'asymétrie mesurée ici est délibérée : écrire sur un élément supprimé n'a
// pas de sens, le lire en a — la purge étant irréversible, consulter la fiche
// est la vérification qui précède le geste destructeur.
//
// Ce que chaque garde verrouille :
//
// (a) en corbeille, une ligne offre `view` EN PLUS de `restore` et `purge` ;
// (a bis) l'ouverture PUBLIQUE (`zCrudDetailsOpener`) y est offerte elle aussi
//     — sans quoi toute action ajoutée par l'hôte serait un bouton mort ;
// (b) la fiche ouverte depuis la corbeille rend le FORMULAIRE ENTIER en lecture
//     seule — plus de champs que la liste n'a de colonnes ;
// (c) elle n'offre AUCUN retour vers l'édition, MÊME pour un usager muni de
//     `update` (`ZCrudEditionScope.onEdit` reste nul) ;
// (d) un usager sans `view` n'obtient pas l'action : la restriction reste
//     gouvernée par l'ACL, jamais par le mode de vue ;
// (e) contre-témoin d'élargissement — `edit`, `duplicate` et `softDelete`
//     restent ABSENTS de la corbeille ;
// (f) contre-témoin de non-régression — la vue VIVANTE est inchangée.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Colonne UNIQUE de la liste, contre TOUS les champs du formulaire : l'écart
/// entre « ce que la ligne montre » et « ce que la fiche montre » doit être
/// chiffrable — c'est tout l'argument du besoin en corbeille.
const List<ZFieldSpec> _listOneColumn = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
];

const List<ZFieldSpec> _formAllFields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text),
  ZFieldSpec(name: 'qty', type: EditionFieldType.integer),
];

/// Espion du contexte d'édition posé autour de la surface présentée : relève
/// le drapeau de lecture ET le retour vers l'édition RÉELLEMENT offerts au
/// formulaire de l'application.
class _EditionSpy {
  final List<bool> readOnly = <bool>[];
  final List<ZCrudOpener?> onEdit = <ZCrudOpener?>[];

  void clear() {
    readOnly.clear();
    onEdit.clear();
  }
}

/// Écran complet à corbeille et fiche de détail, dont le formulaire est celui
/// de l'application — c'est lui qui décide de dessiner « Modifier », et il ne
/// le peut que si le socle lui remet un `onEdit` non nul.
ZCrudScreen<Item> _screenWithSpy(
  ZRepository<Item> repo,
  _EditionSpy spy, {
  ZAcl? acl,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      detailsEnabled: true,
      acl: acl,
      editionBuilder: (context, initial, save) {
        spy.readOnly.add(ZCrudEditionScope.readOnlyOf(context));
        final onEdit = ZCrudEditionScope.onEditOf(context);
        spy.onEdit.add(onEdit);
        return Column(
          key: const ValueKey('hostForm'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Le bouton n'est dessiné QUE si le rappel existe : c'est le
            // contrat public (`null` ⇒ ne dessinez pas de bouton mort).
            if (onEdit != null)
              TextButton(
                key: const ValueKey('hostEdit'),
                onPressed: onEdit,
                child: const Text('Modifier'),
              ),
          ],
        );
      },
    );

/// ACL accordant tout à l'échelle de la COLLECTION, mais refusant `view` sur
/// une LIGNE : c'est le filtrage par ligne que l'écran revendique. L'écran
/// reste donc peuplé (la lecture de collection est accordée) ; seule l'action
/// de consultation de la ligne doit disparaître.
class _DenyRowViewAcl implements ZAcl {
  const _DenyRowViewAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !(action == ZCrudAction.view && target != null);
}

/// Ouvre la fiche de la première ligne (action « détails »).
Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.visibility_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'garde (a) — en corbeille, la ligne offre « détails » EN PLUS de '
      'restaurer et purger', (tester) async {
    final repo =
        FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    expect(find.text('Alpha'), findsOneWidget);

    // Les trois gestes de la ligne de corbeille.
    expect(
      find.byIcon(Icons.visibility_outlined),
      findsOneWidget,
      reason: 'la consultation doit rester offerte en corbeille',
    );
    expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);

    // …et elle OUVRE réellement la fiche (pas un bouton mort).
    await _openDetails(tester);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (a bis) — en corbeille, l\'ouverture PUBLIQUE de la fiche est '
      'offerte : `zCrudDetailsOpener` n\'est pas nul', (tester) async {
    final repo =
        FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    // Mise à la corbeille par la SOURCE, hors interface : la garde porte sur
    // le rappel offert aux tuiles de l'application, pas sur le geste qui a
    // conduit l'élément là.
    await repo.softDelete('i1');
    ZCrudOpener? seen;
    var probed = false;
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        itemBuilder: (context, item, columns) {
          probed = true;
          seen = zCrudDetailsOpener(context, item);
          return Text(item.name, key: ValueKey<String>('tile_${item.id}'));
        },
      ),
    );
    await openTrashView(tester);
    expect(probed, isTrue, reason: 'la tuile de corbeille doit être rendue');
    expect(
      seen,
      isNotNull,
      reason: 'un rappel nul ferait de toute action hôte un bouton mort',
    );
    // …et il OUVRE réellement (le contrat, pas seulement sa nullité). Le
    // `Future` rendu ne se complète qu'à la FERMETURE de la surface : il est
    // déclenché sans être attendu, puis la fiche est refermée.
    unawaited(seen!());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();
    repo.dispose();
  });

  testWidgets(
      'garde (b) — la fiche ouverte depuis la corbeille rend le FORMULAIRE '
      'entier, en lecture seule', (tester) async {
    final repo = FakePurgeableItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 7)],
    );
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        listFields: _listOneColumn,
        formFields: _formAllFields,
      ),
    );
    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    // La LISTE de corbeille ne connaît qu'une colonne : `qty` n'y est pas.
    expect(find.text('7'), findsNothing);

    await _openDetails(tester);
    final rendered = <String>[
      for (final spec in _formAllFields)
        if (find.byKey(ValueKey<String>(spec.name)).evaluate().isNotEmpty)
          spec.name,
    ];
    expect(rendered, <String>['name', 'qty']);
    // Le point chiffré : plus de champs rendus que de colonnes de ligne.
    expect(rendered.length, greaterThan(_listOneColumn.length));
    // Lecture stricte : rien où taper, rien à enregistrer.
    expect(find.byType(EditableText), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormClose')), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (c) — AUCUN retour vers l\'édition dans la fiche de corbeille, '
      'même avec `update` accordé', (tester) async {
    final repo =
        FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final spy = _EditionSpy();
    await pumpScreen(tester, _screenWithSpy(repo, spy));

    // CONTRE-TÉMOIN D'ABORD — sur les VIVANTS, la même ACL (tout accordé)
    // donne bien un « Modifier ». Sans ce couple, la garde serait verte même
    // si le socle n'offrait jamais l'édition nulle part.
    await _openDetails(tester);
    expect(spy.readOnly.last, isTrue);
    expect(
      spy.onEdit.last,
      isNotNull,
      reason: '`update` est accordé : la fiche vivante offre le retour',
    );
    expect(find.byKey(const ValueKey('hostEdit')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const ValueKey('hostForm')))).pop();
    await tester.pumpAndSettle();

    // …puis LA MESURE, à ACL strictement identique.
    spy.clear();
    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    await _openDetails(tester);

    expect(spy.readOnly, isNotEmpty);
    expect(
      spy.readOnly.every((bool ro) => ro),
      isTrue,
      reason: 'la fiche de corbeille est ouverte en consultation',
    );
    expect(
      spy.onEdit.last,
      isNull,
      reason: 'l\'édition d\'un élément supprimé n\'est offerte nulle part',
    );
    expect(
      find.byKey(const ValueKey('hostEdit')),
      findsNothing,
      reason: 'aucun bouton « Modifier » dans la fiche de corbeille',
    );
    repo.dispose();
  });

  testWidgets(
      'garde (d) — sans `view`, la corbeille n\'offre pas la consultation : '
      'c\'est l\'ACL qui tranche, pas le mode de vue', (tester) async {
    final repo =
        FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        acl: const _DenyRowViewAcl(),
      ),
    );
    // Refusée dès la vue vivante…
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    expect(find.text('Alpha'), findsOneWidget);
    // …et refusée en corbeille, alors que les gestes de corbeille, eux,
    // restent bien offerts (la ligne n'est pas vide : le refus est ciblé).
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (e) — aucun élargissement : `edit`, `duplicate` et `softDelete` '
      'restent absents de la corbeille', (tester) async {
    final repo =
        FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        canDuplicate: true,
      ),
    );
    // Vue vivante : les trois gestes d'écriture existent bel et bien — le
    // contre-témoin n'est donc pas vide.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // La création reste hors de la corbeille elle aussi.
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde (f) — la vue VIVANTE est strictement inchangée : ordre et gestes '
      'de la ligne identiques', (tester) async {
    final repo =
        FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        canDuplicate: true,
      ),
    );
    // Ordre de la ligne vivante : détails, modifier, dupliquer, corbeille —
    // relevé par la position horizontale des icônes.
    double x(IconData icon) => tester.getCenter(find.byIcon(icon)).dx;
    expect(x(Icons.visibility_outlined), lessThan(x(Icons.edit_outlined)));
    expect(x(Icons.edit_outlined), lessThan(x(Icons.copy_outlined)));
    expect(x(Icons.copy_outlined), lessThan(x(Icons.delete_outline)));
    // Aucun geste de corbeille n'a fui vers les vivants.
    expect(find.byIcon(Icons.restore_from_trash), findsNothing);
    expect(find.byIcon(Icons.delete_forever), findsNothing);
    repo.dispose();
  });
}
