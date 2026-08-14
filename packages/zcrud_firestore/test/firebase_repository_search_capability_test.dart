// Gardes de la CAPACITÉ DE RECHERCHE de l'adaptateur Firestore, mesurées de
// bout en bout : un vrai `FirebaseZRepositoryImpl` sur `fake_cloud_firestore`,
// un vrai `ZListController` au-dessus, et les assertions portent sur l'ÉTAT
// RENDU — jamais sur la seule déclaration du mixin.
//
//   (a) un terme présent ne laisse que les lignes correspondantes ;
//   (b) un terme absent rend `ZListNoResults`, et non la totalité ;
//   (c) « elephant » trouve « Éléphant » (pliage diacritique) ;
//   (d) la portée reste celle des champs `searchable` ;
//   (e) sans recherche, la voie curseur reste le chemin nominal (la pagination
//       serveur est intacte).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class _Animal extends ZEntity {
  const _Animal({this.id, required this.name, required this.note});

  @override
  final String? id;
  final String name;
  final String note;

  static _Animal fromMap(Map<String, dynamic> map) => _Animal(
        id: map['id'] as String?,
        name: (map['name'] as String?) ?? '',
        note: (map['note'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
        'note': note,
      };
}

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'note', type: EditionFieldType.text),
];

ZListRow _toRow(_Animal a) => ZListRow(
      id: a.id!,
      cells: <String, Object?>{'id': a.id, 'name': a.name, 'note': a.note},
    );

const String _kPath = 'animals';

FirebaseZRepositoryImpl<_Animal> _repo(FakeFirebaseFirestore fs) =>
    FirebaseZRepositoryImpl<_Animal>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'animal',
      fromMap: _Animal.fromMap,
      toMap: (a) => a.toMap(),
    );

Future<void> _seed(FakeFirebaseFirestore fs) async {
  const rows = <String, List<String>>{
    'a': <String>['Éléphant', 'pachyderme'],
    'b': <String>['Girafe', 'elephant en note'],
    'c': <String>['Zèbre', 'rayures'],
  };
  for (final entry in rows.entries) {
    await fs.collection(_kPath).doc(entry.key).set(<String, dynamic>{
      'id': entry.key,
      'name': entry.value[0],
      'note': entry.value[1],
      'is_deleted': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

List<String> _names(ZListViewState s) => s is ZListReady
    ? <String>[for (final r in s.rows) r.cells['name']! as String]
    : <String>[];

void main() {
  test('l\'adaptateur DÉCLARE qu\'il délègue la recherche', () {
    final repo = _repo(FakeFirebaseFirestore());
    addTearDown(repo.dispose);
    expect(repo, isA<ZDelegatesSearch<_Animal>>());
    expect(zRepositoryServesSearch(repo), isFalse);
  });

  testWidgets('un terme présent ne laisse que les lignes correspondantes',
      (tester) async {
    final fs = FakeFirebaseFirestore();
    await _seed(fs);
    final repo = _repo(fs);
    addTearDown(repo.dispose);
    final controller = ZListController<_Animal>(
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

  testWidgets('un terme ABSENT rend la liste vide, et non la totalité',
      (tester) async {
    final fs = FakeFirebaseFirestore();
    await _seed(fs);
    final repo = _repo(fs);
    addTearDown(repo.dispose);
    final controller = ZListController<_Animal>(
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
      reason: 'Firestore rendrait les 3 documents : c\'est le défaut corrigé',
    );
  });

  testWidgets('pliage diacritique, et portée limitée aux champs searchable',
      (tester) async {
    final fs = FakeFirebaseFirestore();
    await _seed(fs);
    final repo = _repo(fs);
    addTearDown(repo.dispose);
    final controller = ZListController<_Animal>(
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
      reason: '« Girafe » porte « elephant » dans une colonne NON searchable',
    );
  });

  testWidgets('sans recherche, la pagination serveur reste intacte',
      (tester) async {
    final fs = FakeFirebaseFirestore();
    await _seed(fs);
    final repo = _repo(fs);
    addTearDown(repo.dispose);
    final controller = ZListController<_Animal>(
      repository: repo,
      toRow: _toRow,
      schema: _schema,
      pageSize: 2,
    );
    addTearDown(controller.dispose);
    await tester.pumpAndSettle();

    expect(
      _names(controller.state.value).length,
      2,
      reason: 'la première page est bien une PAGE : rien n\'a basculé en '
          'mémoire tant que rien n\'est cherché',
    );

    await controller.loadMore();
    await tester.pumpAndSettle();
    expect(_names(controller.state.value).length, 3);
  });
}
