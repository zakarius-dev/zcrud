// Gardes de la voie d'écriture FUSIONNANTE (`saveMerging`) de
// `FirebaseZRepositoryImpl`.
//
// Le défaut visé : `save` écrit en écrasement TOTAL (`batch.set` sans options).
// Tout champ que la map d'écriture ne nomme pas est donc EFFACÉ du document
// distant. Une surface d'édition qui ne déclare qu'une partie des champs d'un
// document l'ampute à chaque enregistrement — silencieusement, sans erreur.
//
// Le premier groupe est le TÉMOIN de cet écrasement : il l'assert explicitement.
// Il doit rester vert après le lot — c'est lui qui rougirait si la fusion
// devenait le comportement par défaut.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

/// Entité qui ne décrit qu'une **partie** du document persisté : c'est le cas
/// mesuré chez les hôtes — le formulaire déclare `title`/`status`, le document
/// en porte davantage.
class _Doc extends ZEntity {
  const _Doc({this.id, required this.title, required this.status});

  @override
  final String? id;
  final String title;
  final String status;

  static _Doc fromMap(Map<String, dynamic> map) => _Doc(
        id: map['id'] as String?,
        title: (map['title'] as String?) ?? '',
        status: (map['status'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        'status': status,
      };
}

const String _kPath = 'docs';

FirebaseZRepositoryImpl<_Doc> _repo(FakeFirebaseFirestore fs) =>
    FirebaseZRepositoryImpl<_Doc>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'doc',
      fromMap: _Doc.fromMap,
      toMap: (d) => d.toMap(),
    );

/// Écrit un document **complet** sur disque, tel qu'il existe déjà chez l'hôte :
/// les champs du formulaire, plus ceux qu'aucune surface d'édition ne déclare.
Future<void> _seed(FakeFirebaseFirestore fs, String id) => fs
    .collection(_kPath)
    .doc(id)
    .set(<String, dynamic>{
      'id': id,
      'title': 'Rapport',
      'status': 'draft',
      'folder_id': 'dossier-7',
      'sub_folder_id': 'sous-dossier-3',
      'legacy_note': 'écrit par une version antérieure',
    });

Future<Map<String, dynamic>> _rawDoc(FakeFirebaseFirestore fs, String id) async {
  final snap = await fs.collection(_kPath).doc(id).get();
  expect(snap.exists, isTrue, reason: 'document $id attendu sur disque');
  return snap.data() ?? <String, dynamic>{};
}

void main() {
  group('TÉMOIN : `save` écrase le document ENTIER', () {
    test('les champs absents de la map écrite DISPARAISSENT du disque',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seed(fs, 'd1');

      final res = await repo.save(const _Doc(id: 'd1', title: 'Rapport v2',
          status: 'final'));
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'd1');
      // Le chemin de perte de données, nommé clé par clé.
      expect(raw.containsKey('folder_id'), isFalse,
          reason: 'le témoin ne mord plus : l\'écrasement total a disparu');
      expect(raw.containsKey('sub_folder_id'), isFalse);
      expect(raw.containsKey('legacy_note'), isFalse);
      // Ce qui reste : le corps écrit + la méta de sync.
      expect(raw['title'], 'Rapport v2');
      expect(raw['status'], 'final');
      expect(raw['id'], 'd1');
    });

    test('INERTIE : sur un document sans clé étrangère, `save` est inchangé',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);

      final res = await repo.save(
        const _Doc(id: 'd2', title: 'Neuf', status: 'draft'),
      );
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'd2');
      expect(raw.keys.toSet(),
          <String>{'id', 'title', 'status', 'is_deleted', 'updated_at'});
      expect(raw['title'], 'Neuf');
      expect(raw['is_deleted'], isFalse);
      expect(raw['updated_at'], isA<String>());
    });

    test('INERTIE : sur un document QUI en porte, `save` est inchangé lui aussi',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seed(fs, 'd3');

      await repo.save(const _Doc(id: 'd3', title: 'Rapport', status: 'draft'));

      final raw = await _rawDoc(fs, 'd3');
      expect(raw.keys.toSet(),
          <String>{'id', 'title', 'status', 'is_deleted', 'updated_at'});
    });
  });

  group('`saveMerging` — les champs non nommés SURVIVENT', () {
    test('les clés absentes de la map écrite restent sur disque', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seed(fs, 'd1');

      final res = await repo.saveMerging(
        const _Doc(id: 'd1', title: 'Rapport v2', status: 'final'),
      );
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'd1');
      expect(raw['folder_id'], 'dossier-7');
      expect(raw['sub_folder_id'], 'sous-dossier-3');
      expect(raw['legacy_note'], 'écrit par une version antérieure');
    });

    test('les clés NOMMÉES sont bien remplacées (jamais une demi-écriture)',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seed(fs, 'd1');

      await repo.saveMerging(
        const _Doc(id: 'd1', title: 'Rapport v2', status: 'final'),
      );

      final raw = await _rawDoc(fs, 'd1');
      expect(raw['title'], 'Rapport v2');
      expect(raw['status'], 'final');
      expect(raw['id'], 'd1');
    });

    test('la méta de sync est réécrite comme sur `save` (updated_at, vivant)',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seed(fs, 'd1');
      // Document soft-deleté : la voie fusionnante le RESSUSCITE, comme `save`.
      await fs.collection(_kPath).doc('d1').update(
        <String, dynamic>{'is_deleted': true, 'updated_at': '2020-01-01T00:00:00.000Z'},
      );

      await repo.saveMerging(
        const _Doc(id: 'd1', title: 'Rapport v2', status: 'final'),
      );

      final raw = await _rawDoc(fs, 'd1');
      expect(raw['is_deleted'], isFalse);
      expect(raw['updated_at'], isNot('2020-01-01T00:00:00.000Z'));
      expect(raw['legacy_note'], 'écrit par une version antérieure');
    });

    test('round-trip : l\'entité relue est rendue, comme sur `save`', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);
      await _seed(fs, 'd1');

      final res = await repo.saveMerging(
        const _Doc(id: 'd1', title: 'Rapport v2', status: 'final'),
      );

      final relu = res.getOrElse(() => const _Doc(title: '', status: ''));
      expect(relu.id, 'd1');
      expect(relu.title, 'Rapport v2');
      expect(relu.status, 'final');
    });

    test('document INEXISTANT : la fusion le crée (aucun échec)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);

      final res = await repo.saveMerging(
        const _Doc(id: 'neuf', title: 'Neuf', status: 'draft'),
      );
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'neuf');
      expect(raw['title'], 'Neuf');
      expect(raw['id'], 'neuf');
    });

    test('entité ÉPHÉMÈRE : l\'identifiant est matérialisé, comme sur `save`',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);

      final res = await repo.saveMerging(
        const _Doc(title: 'Sans id', status: 'draft'),
      );
      final cree = res.getOrElse(() => const _Doc(title: '', status: ''));
      expect(cree.id, isNotNull);
      expect(cree.id, isNotEmpty);

      final raw = await _rawDoc(fs, cree.id!);
      expect(raw['id'], cree.id);
      expect(raw['title'], 'Sans id');
    });
  });
}
