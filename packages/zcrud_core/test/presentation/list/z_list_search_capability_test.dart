// Gardes de la CAPACITÉ DE RECHERCHE d'un dépôt (`ZDelegatesSearch`) sur la
// voie dépôt du `ZListController`.
//
// Ce que ces gardes mesurent :
//   (a) un terme présent ne laisse que les lignes correspondantes ;
//   (b) un terme ABSENT rend la liste VIDE (`ZListNoResults`), et non la
//       totalité — le défaut mesuré chez l'hôte ;
//   (c) le pliage diacritique tient (« elephant » trouve « Éléphant ») ;
//   (d) la portée reste celle des champs `searchable` (sémantique inchangée) ;
//   (e) un dépôt qui SERT la recherche n'est pas dévié : sa requête part
//       paginée, et rien n'est refiltré derrière lui ;
//   (f) NON-RUPTURE : une implémentation minimale de `ZRepository` compile
//       sans déclarer la capacité, et est réputée servir la recherche ;
//   (g) sans recherche active, la voie curseur reste le chemin nominal —
//       assertion sur ce qui est RÉELLEMENT demandé au dépôt.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'note', type: EditionFieldType.text),
];

class _Item extends ZEntity {
  const _Item(this._id, this.name, this.note);
  final String _id;
  final String name;
  final String note;
  @override
  String? get id => _id;
}

ZListRow _toRow(_Item it) => ZListRow(
      id: it.id!,
      cells: <String, Object?>{'name': it.name, 'note': it.note},
    );

const List<_Item> _seed = <_Item>[
  _Item('a', 'Éléphant', 'pachyderme'),
  _Item('b', 'Girafe', 'elephant en note'),
  _Item('c', 'Zèbre', 'rayures'),
];

/// Dépôt **aveugle à la recherche** : il honore filtres, tri, limite et
/// curseur, mais IGNORE `ZDataRequest.search` — le comportement exact d'un
/// backend sans `LIKE` ni plein-texte (Firestore). Il le **déclare** par
/// `ZDelegatesSearch`.
class _BlindSearchRepo
    with ZDelegatesSearch<_Item>
    implements ZRepository<_Item> {
  _BlindSearchRepo(this._data);

  final List<_Item> _data;

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  ZDataRequest get last => requests.last;

  final StreamController<List<_Item>> _changes =
      StreamController<List<_Item>>.broadcast();

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    // Le terme est REÇU puis ignoré : c'est là tout le défaut.
    final blind = req.copyWith(search: null);
    final page = zApplyListRequest(
      <ZListRow>[for (final it in _data) _toRow(it)],
      blind,
      schema: _schema,
    );
    final byId = <String, _Item>{for (final it in _data) it.id!: it};
    return Right(<_Item>[for (final r in page.rows) byId[r.id]!]);
  }

  @override
  Stream<List<_Item>> watchAll() => _changes.stream;

  @override
  Stream<List<_Item>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<_Item>> getById(String id) async =>
      Left(ZNotFoundFailure('absent', id: id));

  @override
  Future<ZResult<_Item>> save(_Item item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);

  @override
  void dispose() => unawaited(_changes.close());
}

/// Dépôt **servant** la recherche : le MÊME dépôt, sans le mixin, et qui
/// honore le terme. C'est le contre-témoin de la capacité.
class _ServingSearchRepo implements ZRepository<_Item> {
  _ServingSearchRepo(this._data);

  final List<_Item> _data;

  final List<ZDataRequest> requests = <ZDataRequest>[];

  ZDataRequest get last => requests.last;

  final StreamController<List<_Item>> _changes =
      StreamController<List<_Item>>.broadcast();

  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    final page = zApplyListRequest(
      <ZListRow>[for (final it in _data) _toRow(it)],
      req,
      schema: _schema,
    );
    final byId = <String, _Item>{for (final it in _data) it.id!: it};
    return Right(<_Item>[for (final r in page.rows) byId[r.id]!]);
  }

  @override
  Stream<List<_Item>> watchAll() => _changes.stream;

  @override
  Stream<List<_Item>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<_Item>> getById(String id) async =>
      Left(ZNotFoundFailure('absent', id: id));

  @override
  Future<ZResult<_Item>> save(_Item item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);

  @override
  void dispose() => unawaited(_changes.close());
}

/// Implémentation **minimale** du port, écrite comme l'écrirait une
/// application : rien d'autre que les membres de `ZRepository`. Elle prouve la
/// NON-RUPTURE — si la capacité était un membre du port, ce fichier ne
/// compilerait plus.
class _MinimalRepo implements ZRepository<_Item> {
  @override
  Future<ZResult<List<_Item>>> getAll({ZDataRequest? request}) async =>
      const Right(<_Item>[]);

  @override
  Stream<List<_Item>> watchAll() => const Stream<List<_Item>>.empty();

  @override
  Stream<List<_Item>> watch(ZDataRequest request) =>
      const Stream<List<_Item>>.empty();

  @override
  Future<ZResult<_Item>> getById(String id) async =>
      Left(ZNotFoundFailure('absent', id: id));

  @override
  Future<ZResult<_Item>> save(_Item item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async => const Right(0);

  @override
  void dispose() {}
}

List<String> _names(ZListViewState s) => s is ZListReady
    ? <String>[for (final r in s.rows) r.cells['name']! as String]
    : <String>[];

void main() {
  group('voie dépôt — un dépôt qui délègue la recherche est filtré en mémoire',
      () {
    testWidgets('un terme présent ne laisse que les lignes correspondantes',
        (tester) async {
      final repo = _BlindSearchRepo(List<_Item>.of(_seed));
      addTearDown(repo.dispose);
      final controller = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      controller.setSearch('Girafe');
      await tester.pumpAndSettle();

      expect(_names(controller.state.value), <String>['Girafe']);
    });

    testWidgets(
      'un terme ABSENT rend la liste VIDE (ZListNoResults), et non la totalité',
      (tester) async {
        final repo = _BlindSearchRepo(List<_Item>.of(_seed));
        addTearDown(repo.dispose);
        final controller = ZListController<_Item>(
          repository: repo,
          toRow: _toRow,
          schema: _schema,
        );
        addTearDown(controller.dispose);
        await tester.pumpAndSettle();

        controller.setSearch('xyzzy-introuvable');
        await tester.pumpAndSettle();

        expect(
          controller.state.value,
          isA<ZListNoResults>(),
          reason: 'une barre qui ne filtre pas ferait rendre les 3 lignes',
        );
      },
    );

    testWidgets('pliage diacritique : « elephant » trouve « Éléphant »',
        (tester) async {
      final repo = _BlindSearchRepo(List<_Item>.of(_seed));
      addTearDown(repo.dispose);
      final controller = ZListController<_Item>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      controller.setSearch('elephant');
      await tester.pumpAndSettle();

      expect(
        _names(controller.state.value),
        <String>['Éléphant'],
        reason: 'la ligne « Girafe » porte « elephant » dans une colonne NON '
            'searchable : la portée ne bouge pas',
      );
    });

    testWidgets(
      'la portée reste celle des champs searchable, sauf déclaration contraire',
      (tester) async {
        final repo = _BlindSearchRepo(List<_Item>.of(_seed));
        addTearDown(repo.dispose);
        final controller = ZListController<_Item>(
          repository: repo,
          toRow: _toRow,
          schema: _schema,
          searchScope: ZSearchScope.allColumns,
        );
        addTearDown(controller.dispose);
        await tester.pumpAndSettle();

        controller.setSearch('rayures');
        await tester.pumpAndSettle();

        expect(
          _names(controller.state.value),
          <String>['Zèbre'],
          reason: 'la colonne non searchable devient interrogeable UNIQUEMENT '
              'sur déclaration',
        );
      },
    );

    testWidgets(
      'sans recherche active, la voie curseur reste le chemin nominal',
      (tester) async {
        final repo = _BlindSearchRepo(List<_Item>.of(_seed));
        addTearDown(repo.dispose);
        final controller = ZListController<_Item>(
          repository: repo,
          toRow: _toRow,
          schema: _schema,
          pageSize: 2,
        );
        addTearDown(controller.dispose);
        await tester.pumpAndSettle();

        expect(
          repo.last.limit,
          2,
          reason: 'la première requête est PAGINÉE : aucune lecture du jeu '
              'entier tant que rien n\'est cherché',
        );
        expect(_names(controller.state.value).length, 2);

        controller.setSearch('elephant');
        await tester.pumpAndSettle();
        expect(
          repo.last.limit,
          isNull,
          reason: 'une recherche active — et elle seule — fait partir la '
              'requête NON paginée pour filtrer en mémoire',
        );

        controller.setSearch('');
        await tester.pumpAndSettle();
        expect(
          repo.last.limit,
          2,
          reason: 'terme effacé : retour immédiat au chemin paginé',
        );
      },
    );
  });

  group('CONTRE-TÉMOIN — un dépôt qui sert la recherche n\'est pas dévié', () {
    testWidgets(
      'sa requête part paginée, terme compris : rien n\'est refiltré derrière '
      'lui',
      (tester) async {
        final repo = _ServingSearchRepo(List<_Item>.of(_seed));
        addTearDown(repo.dispose);
        final controller = ZListController<_Item>(
          repository: repo,
          toRow: _toRow,
          schema: _schema,
          pageSize: 2,
        );
        addTearDown(controller.dispose);
        await tester.pumpAndSettle();

        controller.setSearch('elephant');
        await tester.pumpAndSettle();

        expect(repo.last.search, 'elephant');
        expect(
          repo.last.limit,
          2,
          reason: 'le dépôt sert la recherche : la pagination reste la sienne',
        );
        expect(_names(controller.state.value), <String>['Éléphant']);
      },
    );
  });

  group('NON-RUPTURE du port', () {
    test(
      'une implémentation minimale compile sans déclarer la capacité, et sert '
      'la recherche par défaut',
      () {
        final repo = _MinimalRepo();
        addTearDown(repo.dispose);
        expect(repo, isA<ZRepository<_Item>>());
        expect(zRepositoryServesSearch(repo), isTrue);
        expect(repo, isNot(isA<ZDelegatesSearch<_Item>>()));
      },
    );

    test('un dépôt qui applique le mixin est reconnu comme délégant', () {
      final repo = _BlindSearchRepo(List<_Item>.of(_seed));
      addTearDown(repo.dispose);
      expect(zRepositoryServesSearch(repo), isFalse);
      expect(repo, isA<ZDelegatesSearch<_Item>>());
    });
  });

  group('P1 — le mode in-memory déclaré fait chercher, quel que soit le dépôt',
      () {
    testWidgets(
      'mode inMemory : un dépôt aveugle à la recherche filtre quand même',
      (tester) async {
        final repo = _BlindSearchRepo(List<_Item>.of(_seed));
        addTearDown(repo.dispose);
        final controller = ZListController<_Item>(
          repository: repo,
          toRow: _toRow,
          schema: _schema,
          mode: ZListPaginationMode.inMemory,
        );
        addTearDown(controller.dispose);
        await tester.pumpAndSettle();

        controller.setSearch('zebre');
        await tester.pumpAndSettle();

        expect(_names(controller.state.value), <String>['Zèbre']);
      },
    );
  });
}
