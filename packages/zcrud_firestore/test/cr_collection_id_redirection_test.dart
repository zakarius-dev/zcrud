// Garde de la sémantique réelle de `collectionId` sur l'adaptateur Firestore :
// le paramètre LOCALISE le conteneur d'écriture. Contre-témoin de la
// séparation faite côté écran assemblé (qui, lui, ne le transmet plus) : le
// port n'a pas changé, une redirection explicite reste possible — et reste
// invisible aux lectures du dépôt.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class _Ship extends ZEntity {
  const _Ship({this.id, required this.name});

  @override
  final String? id;
  final String name;

  static _Ship fromMap(Map<String, dynamic> map) =>
      _Ship(id: map['id'] as String?, name: (map['name'] as String?) ?? '');

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
      };
}

FirebaseZRepositoryImpl<_Ship> _repo(FakeFirebaseFirestore fs) =>
    FirebaseZRepositoryImpl<_Ship>(
      firestore: fs,
      collectionPath: 'bmd_ships',
      kind: 'ship',
      fromMap: _Ship.fromMap,
      toMap: (s) => s.toMap(),
    );

void main() {
  test('sans collectionId : l\'écriture atterrit dans la collection du dépôt',
      () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);

    final res = await repo.save(const _Ship(name: 'Aurore'));

    expect(res.isRight(), isTrue);
    expect((await fs.collection('bmd_ships').get()).docs, hasLength(1));
    repo.dispose();
  });

  test(
      'avec collectionId : l\'écriture est REDIRIGÉE vers ce conteneur, et le '
      'dépôt ne la relit pas', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);

    final res = await repo.save(const _Ship(name: 'Aurore'),
        collectionId: 'ships');

    // L'écriture RÉUSSIT : c'est précisément ce qui rendait la confusion
    // silencieuse quand `ships` était en réalité une clé d'autorisation.
    expect(res.isRight(), isTrue);
    expect((await fs.collection('ships').get()).docs, hasLength(1));
    expect((await fs.collection('bmd_ships').get()).docs, isEmpty);

    // Les lectures du dépôt restent ancrées sur son propre chemin : le
    // document écrit est introuvable par elles.
    final all = await repo.getAll();
    expect(all.getOrElse(() => const <_Ship>[]), isEmpty);
    repo.dispose();
  });
}
