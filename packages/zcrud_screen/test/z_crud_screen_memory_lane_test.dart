// Gardes de la VOIE MÉMOIRE d'un écran DÉCLARÉ : ce qui part au dépôt, et ce
// que le socle ré-applique aux lignes.
//
// Ce que ces gardes tiennent :
//   * 🔴 un écran déclarant un post-filtre ET un tri sur un champ NULLABLE
//     affiche TOUS ses documents, y compris ceux dont le champ est absent —
//     l'assertion porte sur les lignes RENDUES, et sur le tri réellement reçu
//     par le dépôt ;
//   * une clause `ZFilter.servedBySource` filtre à la lecture sans exiger de
//     cellule correspondante, et ne vide pas la liste ;
//   * sur la voie `items`, où il n'y a PAS de source, la même clause ne filtre
//     rien — limite assumée, mesurée ici pour qu'elle ne dérive pas ;
//   * contre-témoin : un écran à périmètre requêtable garde tri ET pagination
//     SERVEUR, inchangés.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Dossier de test : une **date facultative** (le champ trié) et un état
/// **calculé côté source**, qu'aucune colonne ne porte.
class Dossier extends ZEntity {
  const Dossier({
    this.id,
    required this.nom,
    this.date,
    this.etat = 'enCours',
  });

  @override
  final String? id;

  /// Libellé affiché.
  final String nom;

  /// Champ **nullable** : la valeur manque sur les dossiers non datés.
  final String? date;

  /// Champ **calculé** côté source : absent du schéma, absent des cellules.
  final String etat;
}

/// Schéma déclaré : `etat` n'y figure pas — c'est tout le sujet.
const List<ZFieldSpec> dossierSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'nom', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'date', type: EditionFieldType.text),
];

/// Registre manuel équivalent au registrar généré.
ZcrudRegistry buildDossierRegistry() {
  final registry = ZcrudRegistry();
  registry.register<Dossier>(
    'dossier',
    fromMap: (map) => Dossier(
      id: map['id'] as String?,
      nom: (map['nom'] as String?) ?? '',
      date: map['date'] as String?,
    ),
    toMap: (item) => <String, dynamic>{
      'id': item.id,
      'nom': item.nom,
      'date': item.date,
    },
    fieldSpecs: dossierSpecs,
  );
  return registry;
}

/// Valeur **de la source** pour un champ (le calculé compris).
Object? _sourceValue(Dossier d, String field) => switch (field) {
      'id' => d.id,
      'nom' => d.nom,
      'date' => d.date,
      'etat' => d.etat,
      _ => null,
    };

/// Dépôt **espion** reproduisant la sémantique d'un backend documentaire :
/// il sert toutes les clauses conjonctives reçues, et son ordre **exclut** les
/// documents dépourvus du champ trié.
class SourceRepo implements ZRepository<Dossier> {
  SourceRepo(this._data);

  final List<Dossier> _data;
  final StreamController<List<Dossier>> _changes =
      StreamController<List<Dossier>>.broadcast();

  /// Requêtes reçues par `getAll`, dans l'ordre.
  final List<ZDataRequest> requests = <ZDataRequest>[];

  /// Dernière requête reçue.
  ZDataRequest get last => requests.last;

  @override
  Future<ZResult<List<Dossier>>> getAll({ZDataRequest? request}) async {
    final req = request ?? const ZDataRequest();
    requests.add(req);
    var data = <Dossier>[..._data];
    for (final filter in req.filters) {
      data = <Dossier>[
        for (final d in data)
          if (_serves(d, filter)) d,
      ];
    }
    for (final sort in req.sorts) {
      data = <Dossier>[
        for (final d in data)
          if (_sourceValue(d, sort.field) != null) d,
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

  bool _serves(Dossier d, ZFilter filter) {
    final value = _sourceValue(d, filter.field);
    return switch (filter.op) {
      ZFilterOp.eq => value == filter.value,
      ZFilterOp.isIn =>
        filter.value is List && (filter.value! as List).contains(value),
      ZFilterOp.isNull => value == null,
      _ => true,
    };
  }

  @override
  Stream<List<Dossier>> watchAll() => _changes.stream;

  @override
  Stream<List<Dossier>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_data.length);

  @override
  Future<ZResult<Dossier>> getById(String id) async =>
      Left(ZNotFoundFailure('n/a', id: id));

  @override
  Future<ZResult<Dossier>> save(Dossier item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async => const Right(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  void dispose() => unawaited(_changes.close());
}

/// Périmètre métier que la requête ne sait pas dire (il impose la voie
/// mémoire, comme n'importe quel post-filtre d'écran).
bool _nonArchive(Dossier dossier) => dossier.nom != 'archive';

const List<Dossier> _seed = <Dossier>[
  Dossier(id: 'd1', nom: 'Delta', date: '2026-03-01'),
  Dossier(id: 'd2', nom: 'Bravo'),
  Dossier(id: 'd3', nom: 'Alpha', date: '2026-01-15', etat: 'termine'),
  Dossier(id: 'd4', nom: 'Charlie', date: '2026-02-10'),
  Dossier(id: 'd5', nom: 'Echo', etat: 'termine'),
];

/// Libellés RENDUS, dans l'ordre d'affichage.
List<String> _rendered(WidgetTester tester) => <String>[
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];

void main() {
  group('🔴 Tri sur un champ facultatif, listing servi en mémoire', () {
    testWidgets(
        'l\'écran affiche TOUS ses dossiers, non datés compris, dans l\'ordre '
        'demandé', (tester) async {
      final repo = SourceRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Dossier>(
          title: 'Dossiers',
          source: ZCrudSource<Dossier>.repository(repo),
          registry: buildDossierRegistry(),
          query: ZListQueryPolicy(
            sort: const <ZSort>[ZSort('date')],
            itemFilter: ZItemFilter.of(_nonArchive),
          ),
        ),
      );

      expect(
        _rendered(tester),
        <String>['Alpha', 'Charlie', 'Delta', 'Bravo', 'Echo'],
        reason: 'les deux dossiers NON DATÉS (Bravo, Echo) sont listés, '
            'classés en dernier — un ordre serveur les aurait retranchés',
      );
      expect(
        repo.last.sorts,
        isEmpty,
        reason: 'la requête part sans tri : le jeu est ordonné en mémoire',
      );
    });

    testWidgets(
        'CONTRE-TÉMOIN : à périmètre requêtable, tri ET pagination restent '
        'serveur', (tester) async {
      final repo = SourceRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Dossier>(
          title: 'Dossiers',
          source: ZCrudSource<Dossier>.repository(repo),
          registry: buildDossierRegistry(),
          query: const ZListQueryPolicy(
            sort: <ZSort>[ZSort('date')],
            pageSize: 2,
          ),
        ),
      );

      expect(
        repo.last.sorts,
        const <ZSort>[ZSort('date')],
        reason: 'rien ne justifie de retirer le tri d\'une requête que la '
            'source honore de bout en bout',
      );
      expect(repo.last.limit, 2);
      expect(_rendered(tester), <String>['Alpha', 'Charlie']);
    });
  });

  group('Clause servie par la source, déclarée sur l\'écran', () {
    testWidgets(
        'elle filtre à la lecture et ne vide PAS la liste faute de colonne',
        (tester) async {
      final repo = SourceRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Dossier>(
          title: 'Dossiers',
          source: ZCrudSource<Dossier>.repository(repo),
          registry: buildDossierRegistry(),
          query: ZListQueryPolicy(
            baseFilters: const <ZFilter>[
              ZFilter.servedBySource(
                'etat',
                ZFilterOp.isIn,
                <String>['termine'],
              ),
            ],
            itemFilter: ZItemFilter.of(_nonArchive),
          ),
        ),
      );

      expect(
        repo.last.filters,
        isNotEmpty,
        reason: 'la clause voyage : c\'est la source qui la sert',
      );
      expect(
        _rendered(tester)..sort(),
        <String>['Alpha', 'Echo'],
        reason: 'les deux dossiers terminés, alors qu\'AUCUNE colonne etat '
            'n\'existe sur la ligne projetée',
      );
    });

    testWidgets(
        'la MÊME clause déclarée ordinaire vide le listing — le piège que la '
        'déclaration évite', (tester) async {
      final repo = SourceRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Dossier>(
          title: 'Dossiers',
          source: ZCrudSource<Dossier>.repository(repo),
          registry: buildDossierRegistry(),
          query: ZListQueryPolicy(
            baseFilters: const <ZFilter>[
              ZFilter('etat', ZFilterOp.isIn, <String>['termine']),
            ],
            itemFilter: ZItemFilter.of(_nonArchive),
          ),
        ),
      );

      expect(
        _rendered(tester),
        isEmpty,
        reason: 'contraste voulu : la source sert bien la clause, mais le '
            'socle la rejoue sur des lignes qui n\'ont pas la colonne',
      );
    });

    testWidgets(
        'LIMITE ASSUMÉE : sur la voie items, sans source, la clause ne filtre '
        'rien', (tester) async {
      await pumpScreen(
        tester,
        ZCrudScreen<Dossier>(
          title: 'Dossiers',
          source: const ZCrudSource<Dossier>.items(_seed),
          registry: buildDossierRegistry(),
          query: const ZListQueryPolicy(
            baseFilters: <ZFilter>[
              ZFilter.servedBySource(
                'etat',
                ZFilterOp.isIn,
                <String>['termine'],
              ),
            ],
          ),
        ),
      );

      expect(
        _rendered(tester).length,
        5,
        reason: 'la liste fournie est prise telle quelle : il n\'y a pas de '
            'source à qui adresser la promesse — documenté, jamais deviné',
      );
    });

    testWidgets(
        'une clause ORDINAIRE, elle, filtre bien la voie items '
        '(non-régression)', (tester) async {
      await pumpScreen(
        tester,
        ZCrudScreen<Dossier>(
          title: 'Dossiers',
          source: const ZCrudSource<Dossier>.items(_seed),
          registry: buildDossierRegistry(),
          query: const ZListQueryPolicy(
            baseFilters: <ZFilter>[ZFilter('nom', ZFilterOp.eq, 'Delta')],
          ),
        ),
      );

      expect(_rendered(tester), <String>['Delta']);
    });
  });
}
