// CR-LEX-35 RÉVISÉE — `purge(id)` seul est un PIÈGE data-loss.
//
// La demande d'origine (livrée v0.12.0) reposait sur une prémisse fausse :
// « l'annulation ne doit PAS être propagée ». Mesuré chez lex, leur
// `discardRejected` fait `_box.delete(id)` PUIS `_softDeleteInFirestore(id)` —
// la carte optimiste A ÉTÉ poussée au cloud, et c'est le tombstone cloud qui
// empêche le pull de la resynchroniser. Un `purge` pur RETIRERAIT ce tombstone
// ⇒ RÉSURRECTION au prochain sync().
//
// Et un `softDelete`-puis-`purge` ne sauve pas : le push du softDelete est
// fire-and-forget et RELIT l'entrée locale ; une purge awaitée la retire avant
// cette relecture — le tombstone n'est jamais émis.
//
// L'ordre correct — propager, ATTENDRE, puis purger — est ce que
// `purgeLocalPropagatingTombstone` encapsule.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

const String _kNote = 'note';
const String _kCollection = 'notes';

class _Note extends ZEntity {
  const _Note({this.id, required this.title});
  @override
  final String? id;
  final String title;
  static _Note fromMap(Map<String, dynamic> m) =>
      _Note(id: m['id'] as String?, title: m['title'] as String? ?? '');
  Map<String, dynamic> toMap() =>
      <String, dynamic>{if (id != null) 'id': id, 'title': title};
}

ZFirestorePathResolver _resolver() =>
    ZFirestorePathResolver(<String, ZFirestorePathRule>{
      _kNote: ZFirestorePathRule.flatTopLevel(collection: _kCollection),
    });

void main() {
  late Directory tmp;
  var seq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('crlex35rev');
    Hive.init(tmp.path);
  });
  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<HiveZLocalStore<_Note>> local() async {
    final box = await Hive.openBox<dynamic>('notes_${seq++}');
    return HiveZLocalStore<_Note>(
      box: box,
      kind: _kNote,
      fromMap: _Note.fromMap,
      toMap: (x) => x.toMap(),
      idFactory: () => 'gen',
    );
  }

  ZOfflineFirstBoxRepository<_Note> repo(
    HiveZLocalStore<_Note> store,
    FirebaseFirestore fs,
  ) =>
      ZOfflineFirstBoxRepository<_Note>(
        local: store,
        firestore: fs,
        resolver: _resolver(),
        kind: _kNote,
        decode: _Note.fromMap,
        encode: (x) => x.toMap(),
        autoListen: false,
      );

  group('🔴 CR-LEX-35 révisée — propager PUIS purger', () {
    test('le tombstone cloud EST émis, et l\'entrée locale est RETIRÉE',
        () async {
      final fs = FakeFirebaseFirestore();
      final store = await local();
      final r = repo(store, fs);
      await r.save(const _Note(id: 'x1', title: 'refusée'));

      final res = await r.purgeLocalPropagatingTombstone('x1');
      expect(res.isRight(), isTrue);

      // (1) tombstone CLOUD présent — c'est lui qui bloque la résurrection.
      final doc = await fs.collection(_kCollection).doc('x1').get();
      expect(doc.exists, isTrue, reason: 'le document cloud doit subsister…');
      expect(doc.data()!['is_deleted'], true,
          reason: '…en portant le tombstone');

      // (2) entrée LOCALE retirée — la box ne croît pas sur les refus.
      final entries =
          (await store.syncEntries()).getOrElse(() => throw StateError('l'));
      expect(entries.where((e) => e.id == 'x1'), isEmpty,
          reason: 'aucun tombstone local résiduel');
    });

    test('🔴 CONTRÔLE NÉGATIF — `purge` seul RETIRE le tombstone cloud',
        () async {
      // C'est le piège que lex a mesuré : adopter `purge` pour une suppression
      // qui doit se propager laisse le cloud SANS tombstone.
      final fs = FakeFirebaseFirestore();
      final store = await local();
      final r = repo(store, fs);
      await r.save(const _Note(id: 'x1', title: 'refusée'));
      await store.purge('x1'); // la voie naïve

      final doc = await fs.collection(_kCollection).doc('x1').get();
      expect(doc.exists && doc.data()!['is_deleted'] == true, isFalse,
          reason: 'purge seul ne pose AUCUN tombstone ⇒ résurrection au sync');
    });

    test('la suppression est effective pour les lectures', () async {
      final fs = FakeFirebaseFirestore();
      final store = await local();
      final r = repo(store, fs);
      await r.save(const _Note(id: 'x1', title: 'refusée'));
      await r.purgeLocalPropagatingTombstone('x1');

      final all = (await r.getAll()).getOrElse(() => throw StateError('l'));
      expect(all.where((n) => n.id == 'x1'), isEmpty);
    });

    test('un `id` inconnu remonte le Left du softDelete (pas de purge muette)',
        () async {
      final fs = FakeFirebaseFirestore();
      final store = await local();
      final r = repo(store, fs);
      final res = await r.purgeLocalPropagatingTombstone('jamais_ecrit');
      expect(res.isLeft(), isTrue,
          reason: 'rien à supprimer ⇒ le Left de softDelete remonte tel quel');
    });
  });

  group('Hors-ligne — anti-résurrection prioritaire sur l\'économie de place',
      () {
    test('🔴 propagation impossible ⇒ le tombstone LOCAL est CONSERVÉ',
        () async {
      // Chemin non résolu ⇒ la propagation échoue. Purger ici échangerait une
      // entrée résiduelle contre une RÉSURRECTION : on conserve donc le
      // tombstone local (= comportement de softDelete), et on le documente.
      final fs = FakeFirebaseFirestore();
      final store = await local();
      final r = ZOfflineFirstBoxRepository<_Note>(
        local: store,
        firestore: fs,
        // Résolveur VIDE : aucun chemin pour ce kind ⇒ propagation abandonnée.
        resolver: ZFirestorePathResolver(const <String, ZFirestorePathRule>{}),
        kind: _kNote,
        decode: _Note.fromMap,
        encode: (x) => x.toMap(),
        autoListen: false,
      );
      await store.put(const _Note(id: 'x1', title: 'T'));

      final res = await r.purgeLocalPropagatingTombstone('x1');
      expect(res.isRight(), isTrue,
          reason: 'la suppression EST effective (tombstone local)');

      final entries =
          (await store.syncEntries()).getOrElse(() => throw StateError('l'));
      final kept = entries.where((e) => e.id == 'x1');
      expect(kept, isNotEmpty,
          reason: 'sans propagation, on GARDE le tombstone — jamais de purge '
              'aveugle qui provoquerait une résurrection');
      expect(kept.first.meta.isDeleted, isTrue);
    });
  });
}
