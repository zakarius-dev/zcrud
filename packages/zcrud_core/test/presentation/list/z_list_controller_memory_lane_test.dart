// Gardes de la VOIE MÉMOIRE : ce qui part à la source, et ce que le moteur du
// socle ré-applique ensuite sur les lignes projetées.
//
// Ce que ces gardes tiennent :
//   * 🔴 un listing servi en mémoire n'envoie AUCUN tri à la source — sinon un
//     backend documentaire traduit le tri en ordre serveur et ampute
//     silencieusement le jeu des documents DÉPOURVUS du champ trié ;
//   * l'ordre rendu reste celui qui a été demandé, les valeurs absentes
//     CLASSÉES (jamais retirées) ;
//   * une clause déclarée `ZFilter.servedBySource` part dans la requête et
//     n'est JAMAIS ré-appliquée aux lignes : elle filtre à la lecture sans
//     exiger de cellule correspondante ;
//   * une clause ordinaire, elle, continue d'être ré-appliquée (non-régression) ;
//   * contre-témoin : un listing à périmètre requêtable garde tri ET
//     pagination SERVEUR, inchangés.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Schéma projeté : `etat_depotage` n'y figure PAS — c'est tout le sujet d'une
/// clause servie par la source seule.
const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'nom', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'date', type: EditionFieldType.text),
];

class _Doc implements ZEntity {
  const _Doc(this._id, this.nom, {this.date, this.etatDepotage = 'enCours'});
  final String _id;
  final String nom;

  /// Champ **nullable** : la valeur manque sur les dossiers non datés.
  final String? date;

  /// Champ **calculé** côté source, jamais projeté en cellule.
  final String etatDepotage;

  @override
  String? get id => _id;
  @override
  bool get isEphemeral => false;
}

/// Projection : deux cellules seulement — `etat_depotage` reste hors de la
/// ligne, comme un getter calculé qui n'existe pas en base.
ZListRow _toRow(_Doc doc) => ZListRow(
      id: doc.id!,
      cells: <String, Object?>{'nom': doc.nom, 'date': doc.date},
    );

/// Six dossiers, dont **deux** sans date et **deux** déjà terminés.
const _seed = <_Doc>[
  _Doc('d1', 'D1', date: '2026-03-01'),
  _Doc('d2', 'D2'),
  _Doc('d3', 'D3', date: '2026-01-15', etatDepotage: 'termine'),
  _Doc('d4', 'D4', date: '2026-02-10'),
  _Doc('d5', 'D5', etatDepotage: 'termine'),
  _Doc('d6', 'D6', date: '2026-04-20'),
];

/// Valeur d'un document pour un nom de champ **de la source** (le calculé
/// compris) — ce que voit un backend, pas ce que voit la ligne.
Object? _sourceValue(_Doc doc, String field) => switch (field) {
      'nom' => doc.nom,
      'date' => doc.date,
      'etat_depotage' => doc.etatDepotage,
      _ => null,
    };

/// Dépôt **espion** reproduisant la sémantique d'un backend documentaire :
///
///   * il sert TOUTES les clauses conjonctives de `request.filters`, y compris
///     celles déclarées servies par la source (c'est ce que fait l'adaptateur
///     Firestore, qui traduit la liste sans la trier) ;
///   * un tri sur un champ **ampute** le jeu des documents dépourvus de ce
///     champ — la sémantique `orderBy` d'un backend documentaire ;
///   * il enregistre chaque requête reçue.
class _SourceRepo implements ZRepository<_Doc> {
  _SourceRepo(this._data);

  final List<_Doc> _data;
  final StreamController<List<_Doc>> _changes =
      StreamController<List<_Doc>>.broadcast();

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<_Doc>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    var data = <_Doc>[..._data];
    for (final filter in req.filters) {
      data = <_Doc>[
        for (final doc in data)
          if (_serves(doc, filter)) doc,
      ];
    }
    // Sémantique `orderBy` : le champ trié doit être PRÉSENT.
    for (final sort in req.sorts) {
      data = <_Doc>[
        for (final doc in data)
          if (_sourceValue(doc, sort.field) != null) doc,
      ];
    }
    if (req.sorts.isNotEmpty) {
      final sort = req.sorts.first;
      data.sort((a, b) {
        final c = '${_sourceValue(a, sort.field)}'
            .compareTo('${_sourceValue(b, sort.field)}');
        return sort.direction == ZSortDirection.desc ? -c : c;
      });
    }
    final limit = req.limit;
    if (limit != null && data.length > limit) data = data.sublist(0, limit);
    return Right(data);
  }

  bool _serves(_Doc doc, ZFilter filter) {
    final value = _sourceValue(doc, filter.field);
    return switch (filter.op) {
      ZFilterOp.eq => value == filter.value,
      ZFilterOp.isIn =>
        filter.value is List && (filter.value! as List).contains(value),
      ZFilterOp.isNull => value == null,
      _ => true,
    };
  }

  @override
  Stream<List<_Doc>> watchAll() => _changes.stream;

  @override
  Stream<List<_Doc>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);

  @override
  Future<ZResult<_Doc>> getById(String id) async =>
      Left(ZNotFoundFailure('n/a', id: id));

  @override
  Future<ZResult<_Doc>> save(_Doc item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  void dispose() => unawaited(_changes.close());
}

/// Dépôt **naïf** : il rend tout, ne sert ni clause ni tri. C'est le dépôt
/// devant lequel une clause ordinaire DOIT rester ré-appliquée par le socle.
class _NaiveRepo implements ZRepository<_Doc> {
  _NaiveRepo(this._data);

  final List<_Doc> _data;
  final StreamController<List<_Doc>> _changes =
      StreamController<List<_Doc>>.broadcast();

  @override
  Future<ZResult<List<_Doc>>> getAll({ZDataRequest? request}) async =>
      Right(_data);

  @override
  Stream<List<_Doc>> watchAll() => _changes.stream;

  @override
  Stream<List<_Doc>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);

  @override
  Future<ZResult<_Doc>> getById(String id) async =>
      Left(ZNotFoundFailure('n/a', id: id));

  @override
  Future<ZResult<_Doc>> save(_Doc item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  void dispose() => unawaited(_changes.close());
}

/// Prédicat métier : ce qu'aucune clause n'exprime (il impose la voie mémoire).
bool _tous(_Doc doc) => true;

List<String> _ids(ZListController<_Doc> controller) {
  final state = controller.state.value;
  return state is ZListReady
      ? <String>[for (final row in state.rows) row.id]
      : const <String>[];
}

void main() {
  group('🔴 Le tri d\'un listing servi en mémoire ne part pas à la source', () {
    testWidgets(
        'un post-filtre + un tri sur champ NULLABLE rendent TOUS les documents, '
        'les valeurs absentes classées en dernier', (tester) async {
      final repo = _SourceRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        itemFilter: _tous,
        initialSorts: const <ZSort>[ZSort('date')],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        _ids(controller),
        <String>['d3', 'd4', 'd1', 'd6', 'd2', 'd5'],
        reason: 'les deux dossiers NON DATÉS (d2, d5) doivent être listés, '
            'classés en dernier — pas amputés par un ordre serveur',
      );
    });

    testWidgets('la requête réellement émise au dépôt ne porte AUCUN tri',
        (tester) async {
      final repo = _SourceRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        itemFilter: _tous,
        initialSorts: const <ZSort>[ZSort('date', ZSortDirection.desc)],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(repo.requests, isNotEmpty);
      expect(
        repo.last.sorts,
        isEmpty,
        reason: 'le jeu est ordonné en mémoire : un tri envoyé à la source '
            'n\'apporte aucun ordre au rendu, il ne peut que retrancher',
      );
      expect(
        _ids(controller),
        <String>['d2', 'd5', 'd6', 'd1', 'd4', 'd3'],
        reason: 'ordre décroissant demandé, absents en tête (négation du '
            'classement ascendant), aucun document perdu',
      );
    });

    testWidgets('le mode mémoire déclaré n\'envoie pas davantage de tri',
        (tester) async {
      final repo = _SourceRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        mode: ZListPaginationMode.inMemory,
        pageSize: 3,
        initialSorts: const <ZSort>[ZSort('date')],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(repo.last.sorts, isEmpty);
      expect(repo.last.limit, isNull);
      expect(
        _ids(controller),
        <String>['d3', 'd4', 'd1'],
        reason: 'la pagination mémoire, elle, s\'applique bien',
      );
    });

    testWidgets(
        'CONTRE-TÉMOIN : un listing à périmètre REQUÊTABLE garde tri ET '
        'pagination serveur', (tester) async {
      final repo = _SourceRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        pageSize: 2,
        initialSorts: const <ZSort>[ZSort('date')],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        repo.last.sorts,
        const <ZSort>[ZSort('date')],
        reason: 'rien ne justifie de retirer le tri d\'une requête que la '
            'source honore de bout en bout',
      );
      expect(repo.last.limit, 2);
      expect(_ids(controller), <String>['d3', 'd4']);
    });
  });

  group('Clauses servies par la source uniquement', () {
    testWidgets(
        'une clause servie par la source filtre à la lecture et ne vide PAS '
        'la liste faute de cellule', (tester) async {
      final repo = _SourceRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        itemFilter: _tous,
        baseFilters: const <ZFilter>[
          ZFilter.servedBySource(
            'etat_depotage',
            ZFilterOp.isIn,
            <String>['termine'],
          ),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        repo.last.filters,
        isNotEmpty,
        reason: 'la clause voyage : c\'est la source qui la sert',
      );
      expect(
        _ids(controller),
        <String>['d3', 'd5'],
        reason: 'les deux dossiers terminés, alors qu\'AUCUNE cellule '
            'etat_depotage n\'existe sur la ligne projetée',
      );
    });

    testWidgets(
        'NON-RÉGRESSION : une clause ordinaire reste ré-appliquée aux lignes',
        (tester) async {
      final repo = _NaiveRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        itemFilter: _tous,
        baseFilters: const <ZFilter>[ZFilter('nom', ZFilterOp.eq, 'D4')],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        _ids(controller),
        <String>['d4'],
        reason: 'devant un dépôt qui ne sert rien, le socle applique la '
            'clause ordinaire lui-même — c\'est ce qui la rend fiable',
      );
    });

    testWidgets(
        'la même clause DÉCLARÉE servie par la source ne filtre plus rien '
        'devant un dépôt qui ne la sert pas', (tester) async {
      final repo = _NaiveRepo(_seed);
      addTearDown(repo.dispose);
      final controller = ZListController<_Doc>(
        repository: repo,
        toRow: _toRow,
        schema: _schema,
        itemFilter: _tous,
        baseFilters: const <ZFilter>[
          ZFilter.servedBySource('nom', ZFilterOp.eq, 'D4'),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpAndSettle();

      expect(
        _ids(controller).length,
        6,
        reason: 'limite ASSUMÉE et documentée : la clause est une promesse '
            'faite à la source ; un dépôt qui ne la sert pas ne filtre rien',
      );
    });
  });

  group('Moteur du socle : ce qu\'il ré-applique, et comment il classe', () {
    const rows = <ZListRow>[
      ZListRow(id: 'r1', cells: <String, Object?>{'date': '2026-03-01'}),
      ZListRow(id: 'r2', cells: <String, Object?>{'date': null}),
      ZListRow(id: 'r3', cells: <String, Object?>{'date': '2026-01-15'}),
    ];

    test('les valeurs nulles sont CLASSÉES en dernier (asc), jamais retirées',
        () {
      final page = zApplyListRequest(
        rows,
        const ZDataRequest(sorts: <ZSort>[ZSort('date')]),
        schema: _schema,
      );
      expect(
        <String>[for (final row in page.rows) row.id],
        <String>['r3', 'r1', 'r2'],
      );
    });

    test('en décroissant, elles passent en tête — toujours sans perte', () {
      final page = zApplyListRequest(
        rows,
        const ZDataRequest(
          sorts: <ZSort>[ZSort('date', ZSortDirection.desc)],
        ),
        schema: _schema,
      );
      expect(
        <String>[for (final row in page.rows) row.id],
        <String>['r2', 'r1', 'r3'],
      );
    });

    test('une clause servie par la source n\'est pas évaluée sur les lignes',
        () {
      final page = zApplyListRequest(
        rows,
        const ZDataRequest(
          filters: <ZFilter>[
            ZFilter.servedBySource('etat_depotage', ZFilterOp.eq, 'termine'),
          ],
        ),
        schema: _schema,
      );
      expect(page.rows.length, 3);
    });

    test('une clause ordinaire sur un champ absent vide bien la liste', () {
      final page = zApplyListRequest(
        rows,
        const ZDataRequest(
          filters: <ZFilter>[ZFilter('etat_depotage', ZFilterOp.eq, 'termine')],
        ),
        schema: _schema,
      );
      expect(
        page.rows,
        isEmpty,
        reason: 'contraste voulu : c\'est exactement le piège que la '
            'déclaration servie-par-la-source évite',
      );
    });

    test('dans une disjonction, une clause servie par la source ne compte pas',
        () {
      final page = zApplyListRequest(
        rows,
        const ZDataRequest(
          filterGroups: <ZFilterGroup>[
            ZFilterGroup.any(<ZFilter>[
              ZFilter.servedBySource('etat_depotage', ZFilterOp.eq, 'termine'),
              ZFilter('date', ZFilterOp.isNull),
            ]),
          ],
        ),
        schema: _schema,
      );
      expect(
        <String>[for (final row in page.rows) row.id],
        <String>['r2'],
        reason: 'seule la clause que le socle sait juger décide',
      );
    });

    test('une disjonction entièrement servie par la source est INERTE', () {
      final page = zApplyListRequest(
        rows,
        const ZDataRequest(
          filterGroups: <ZFilterGroup>[
            ZFilterGroup.any(<ZFilter>[
              ZFilter.servedBySource('etat_depotage', ZFilterOp.eq, 'termine'),
            ]),
          ],
        ),
        schema: _schema,
      );
      expect(
        page.rows.length,
        3,
        reason: 'aucune clause jugeable ⇒ aucune contrainte, plutôt qu\'un '
            'listing vidé sans recours',
      );
    });
  });
}
