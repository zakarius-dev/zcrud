// Gardes du PORTAGE de `ZCrudScreen` sur `zcrud_ui_kit` (CR owner 2026-08-13) :
// l'écran assemblé ne refabrique plus la coquille de page — il CONSOMME celle
// du socle.
//
//  1. la coquille est `ZPageScaffold`/`ZSearchableAppBar`, PAS un `AppBar` nu
//     monté par l'écran ;
//  2. la recherche est celle de l'app-bar du socle, et elle FILTRE réellement
//     (portée vivants ET portée corbeille) ;
//  3. la mise à la corbeille est CONFIRMÉE (`showZConfirmDialog`) — annuler
//     n'écrit RIEN (garde d'ABSENCE d'appel au chemin de persistance) ;
//  4. `confirmDestructive: false` retire le dialogue (déclaration, jamais
//     contournement) ;
//  5. l'échec d'une action de LIGNE part au toaster (`ZToaster` substitué),
//     là où l'échec de SAUVEGARDE reste dans la surface d'édition.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/fixtures.dart';

/// Dépôt dont `softDelete`/`restore` ÉCHOUENT (chemin `Left`) — les autres
/// opérations délèguent au fake neutre.
class FailingTrashRepo implements ZRepository<Item> {
  FailingTrashRepo(this._inner);

  final FakeItemRepo _inner;

  /// `id` réellement passés au dépôt (mesure de l'ABSENCE d'écriture).
  final List<String> softDeleteCalls = <String>[];

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) =>
      _inner.getAll(request: request);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) =>
      _inner.count(request: request);

  @override
  Future<ZResult<Item>> getById(String id) => _inner.getById(id);

  @override
  Stream<List<Item>> watchAll() => _inner.watchAll();

  @override
  Stream<List<Item>> watch(ZDataRequest request) => _inner.watch(request);

  @override
  Future<ZResult<Item>> save(Item item, {String? collectionId}) =>
      _inner.save(item, collectionId: collectionId);

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    softDeleteCalls.add(id);
    return const Left(ZServerFailure('corbeille indisponible'));
  }

  @override
  Future<ZResult<Unit>> restore(String id) async =>
      const Left(ZServerFailure('restauration indisponible'));

  @override
  void dispose() => _inner.dispose();
}

/// Toaster de test substitué par `ZToasterScope` (seam AD-6).
class RecordingToaster implements ZToaster {
  final List<(String, ZToastSeverity)> shown = <(String, ZToastSeverity)>[];

  @override
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    shown.add((message, severity));
  }
}

void main() {
  testWidgets(
      'coquille : l\'écran monte l\'app-bar RECHERCHABLE du socle '
      '(ZPageScaffold/ZSearchableAppBar), pas un AppBar assemblé sur place',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    expect(find.byType(ZPageScaffold), findsOneWidget);
    expect(find.byType(ZSearchableAppBar), findsOneWidget);
    // L'unique `AppBar` de l'arbre est celui CONSTRUIT par le socle : il est
    // donc descendant de `ZSearchableAppBar` (aucun app-bar frère monté par
    // l'écran).
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ZSearchableAppBar),
        matching: find.byType(AppBar),
      ),
      findsOneWidget,
    );
    // Idem pour le `Scaffold` : celui du shell, pas un second monté ici.
    expect(find.byType(Scaffold), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'recherche du socle : la loupe morphe le titre en champ et le listing '
      'des VIVANTS est réellement filtré', (tester) async {
    final repo = FakeItemRepo(const <Item>[
      Item(id: 'i1', name: 'Alpha'),
      Item(id: 'i2', name: 'Beta'),
    ]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    // Avant activation : aucun champ de saisie dans l'app-bar (le titre est
    // un titre), donc aucune barre de recherche permanente dans le corps.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );

    await searchInAppBar(tester, 'bet');
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'recherche du socle sur la voie ITEMS : filtre in-memory par le moteur '
      'du cœur', (tester) async {
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: const ZCrudSource<Item>.items(<Item>[
          Item(id: 'i1', name: 'Alpha'),
          Item(id: 'i2', name: 'Beta'),
        ]),
        registry: buildItemRegistry(),
      ),
    );
    await searchInAppBar(tester, 'alp');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets(
      'confirmation : ANNULER la mise à la corbeille n\'écrit RIEN (aucun '
      'appel au dépôt, la ligne reste vivante)', (tester) async {
    final repo = FailingTrashRepo(
      FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]),
    );
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    // Le dialogue du socle est demandé AVANT toute écriture.
    expect(find.byType(ZConfirmDialog), findsOneWidget);
    expect(repo.softDeleteCalls, isEmpty);

    // Annulation : le dépôt n'est JAMAIS appelé, la ligne reste vivante.
    await tester.tap(
      find.descendant(
        of: find.byType(ZConfirmDialog),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ZConfirmDialog), findsNothing);
    expect(repo.softDeleteCalls, isEmpty);
    expect(find.text('Alpha'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'confirmation : ANNULER n\'appelle pas non plus le callback de source '
      '(voie items)', (tester) async {
    final deleted = <String>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.items(
          const <Item>[Item(id: 'i1', name: 'Alpha')],
          onSave: (_) async {},
          onSoftDelete: (_, item) => deleted.add(item.id!),
          onRestore: (_, item) => deleted.remove(item.id!),
          isDeleted: (item) => deleted.contains(item.id),
        ),
        registry: buildItemRegistry(),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.byType(ZConfirmDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ZConfirmDialog),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets(
      'confirmDestructive: false — aucun dialogue, l\'écriture part '
      'directement (l\'hôte garde son propre flux)', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        confirmDestructive: false,
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.byType(ZConfirmDialog), findsNothing);
    expect(find.text('Alpha'), findsNothing); // écrit sans confirmation
    repo.dispose();
  });

  testWidgets(
      'échec d\'une action de LIGNE : le message part au toaster substitué '
      '(sévérité error), jamais une exception', (tester) async {
    final toaster = RecordingToaster();
    final repo = FailingTrashRepo(
      FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]),
    );
    await pumpScreen(
      tester,
      ZToasterScope(
        toaster: toaster,
        child: ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      ),
    );
    await softDeleteFirstRow(tester);
    expect(tester.takeException(), isNull);
    expect(toaster.shown, hasLength(1));
    expect(toaster.shown.single.$1, contains('corbeille indisponible'));
    expect(toaster.shown.single.$2, ZToastSeverity.error);
    // La ligne reste vivante : l'échec n'est pas maquillé en succès.
    expect(find.text('Alpha'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'échec d\'une RESTAURATION : notifié au toaster (l\'action de corbeille '
      'n\'a aucune autre surface)', (tester) async {
    final toaster = RecordingToaster();
    final restored = <String>[];
    await pumpScreen(
      tester,
      ZToasterScope(
        toaster: toaster,
        child: ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.items(
            const <Item>[Item(id: 'i1', name: 'Alpha')],
            onSave: (_) async {},
            onSoftDelete: (context, item) {},
            onRestore: (_, item) {
              restored.add(item.id!);
              throw StateError('restauration refusée');
            },
            isDeleted: (item) => item.id == 'i1',
          ),
          registry: buildItemRegistry(),
        ),
      ),
    );
    // `i1` est déclaré supprimé : il n'apparaît qu'en corbeille.
    await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restore_from_trash).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(restored, <String>['i1']);
    expect(toaster.shown, hasLength(1));
    expect(toaster.shown.single.$1, contains('restauration refusée'));
    expect(toaster.shown.single.$2, ZToastSeverity.error);
  });

  testWidgets(
      'échec de SAUVEGARDE : reste dans la surface d\'édition, jamais au '
      'toaster (contre-témoin de la répartition des canaux)', (tester) async {
    final toaster = RecordingToaster();
    final repo = FakeItemRepo(const <Item>[]);
    await pumpScreen(
      tester,
      ZToasterScope(
        toaster: toaster,
        child: ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          onSave: (_) async => throw StateError('refus hôte'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zCrudFormError')), findsOneWidget);
    expect(toaster.shown, isEmpty);
    repo.dispose();
  });

  testWidgets(
      'a11y des actions assemblées : libellé sémantique explicite et cible '
      '≥ 48 dp (portés par le socle)', (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    expect(find.bySemanticsLabel('Create'), findsOneWidget);
    expect(find.bySemanticsLabel('Trash'), findsOneWidget);
    final createButton = find.ancestor(
      of: find.byKey(const ValueKey('zCrudCreate')),
      matching: find.byType(IconButton),
    );
    final size = tester.getSize(createButton);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
    semantics.dispose();
    repo.dispose();
  });

  testWidgets(
      'action d\'app-bar DÉCLARÉE (ZAppBarAction) : rendue avant les actions '
      'assemblées, avec son libellé a11y', (tester) async {
    var pressed = 0;
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        actions: <ZAppBarAction>[
          ZAppBarAction(
            icon: Icons.tune,
            semanticLabel: 'Réglages',
            onPressed: () => pressed++,
          ),
        ],
      ),
    );
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(pressed, 1);
    repo.dispose();
  });
}
