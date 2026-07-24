// CR-LEX-26 — la méta hors-entité (`updatedAt`/`isDeleted`) n'était lisible que
// via le STORE (`ZLocalStore.syncEntries`), jamais via le PORT. Un hôte devait
// court-circuiter `ZStudyRepository` pour l'atteindre — le même contournement a
// été réécrit CINQ fois chez un consommateur, le signal qu'il manquait au
// contrat, pas à l'hôte.
//
// CR-LEX-32 — aucune surface LECTURE SEULE : une migration par vagues recevait
// un dépôt complet, donc la capacité d'écrire, et sa seule protection était un
// décorateur écrit — et testé — à la main par chaque hôte.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const String _kNote = 'note';

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

void main() {
  late Directory tmp;
  var seq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('crlex2632');
    Hive.init(tmp.path);
  });
  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<ZOfflineFirstBoxRepository<_Note>> repo() async {
    final box = await Hive.openBox<dynamic>('notes_${seq++}');
    return ZOfflineFirstBoxRepository<_Note>(
      local: HiveZLocalStore<_Note>(
        box: box,
        kind: _kNote,
        fromMap: _Note.fromMap,
        toMap: (x) => x.toMap(),
        idFactory: () => 'gen',
      ),
      firestore: FakeFirebaseFirestore(),
      resolver: ZFirestorePathResolver(<String, ZFirestorePathRule>{
        _kNote: ZFirestorePathRule.flatTopLevel(collection: 'notes'),
      }),
      kind: _kNote,
      decode: _Note.fromMap,
      encode: (x) => x.toMap(),
      autoListen: false,
    );
  }

  group('🔴 CR-LEX-26 — la méta est lisible DEPUIS LE PORT', () {
    test('getAllWithMeta rend les entités APPARIÉES à leur ZSyncMeta', () async {
      final r = await repo();
      await r.save(const _Note(id: 'x1', title: 'A'));

      final res = await r.getAllWithMeta();
      final entries = res.getOrElse(() => throw StateError('left'));
      expect(entries, hasLength(1));
      expect(entries.first.entity.title, 'A');
      expect(entries.first.meta.updatedAt, isNotNull,
          reason: 'updatedAt hors-entité doit être atteignable sans le store');
      expect(entries.first.meta.isDeleted, isFalse);
    });

    test('🔴 les TOMBSTONES sont INCLUS (contraste avec getAll)', () async {
      // C'est tout l'intérêt : savoir qu'une entité est supprimée, et depuis
      // quand, EST l'information demandée.
      final r = await repo();
      await r.save(const _Note(id: 'x1', title: 'A'));
      await r.softDelete('x1');

      final visibles = (await r.getAll()).getOrElse(() => throw StateError('l'));
      expect(visibles, isEmpty, reason: 'getAll exclut les soft-deleted');

      final avecMeta =
          (await r.getAllWithMeta()).getOrElse(() => throw StateError('l'));
      expect(avecMeta, hasLength(1),
          reason: 'getAllWithMeta les INCLUT — sinon il ne servirait à rien');
      expect(avecMeta.first.meta.isDeleted, isTrue);
    });

    test('un dépôt vide rend Right([]), jamais un Left', () async {
      final r = await repo();
      final res = await r.getAllWithMeta();
      expect(res.isRight(), isTrue);
      expect(res.getOrElse(() => throw StateError('l')), isEmpty);
    });

    test('🔴 le DÉFAUT du port est un Left explicite, jamais une liste vide',
        () async {
      // Une liste vide serait indiscernable de « l'utilisateur n'a rien ».
      final res = await _RepoSansSync().getAllWithMeta();
      expect(res.isLeft(), isTrue);
      res.fold(
        (f) => expect(f, isA<ZDomainFailure>()),
        (_) => fail('un dépôt sans couche de sync doit le DIRE'),
      );
    });
  });

  group('🔴 CR-LEX-32 — la surface LECTURE SEULE existe', () {
    test('un dépôt se passe là où une lecture seule est attendue', () async {
      // Aucun décorateur : le dépôt EST déjà un ZReadOnlyRepository.
      final ZReadOnlyRepository<_Note> lecture = await repo();
      expect(lecture, isA<ZReadOnlyRepository<_Note>>());
    });

    test('les 5 membres de LECTURE sont joignables par cette surface', () async {
      final r = await repo();
      await r.save(const _Note(id: 'x1', title: 'A'));
      final ZReadOnlyRepository<_Note> lecture = r;

      expect((await lecture.getAll()).getOrElse(() => throw StateError('l')),
          hasLength(1));
      expect((await lecture.getById('x1')).isRight(), isTrue);
      expect((await lecture.count()).getOrElse(() => throw StateError('l')), 1);
      expect(lecture.watchAll(), isA<Stream<List<_Note>>>());
      expect(lecture.watch(const ZDataRequest()), isA<Stream<List<_Note>>>());
    });

    test('🔴 l\'ÉCRITURE est inexprimable — vérifié sur la SOURCE', () {
      // La protection est STATIQUE : `ZReadOnlyRepository` ne déclare aucun
      // membre d'écriture, donc un appel les invoquant ne compile pas. On le
      // vérifie sur le fichier SOURCE plutôt qu'en recopiant une liste ici —
      // sinon le test n'assèrerait que ce que le test lui-même a écrit, et un
      // ajout de `save` à l'interface passerait inaperçu.
      final File src = File(
        '../zcrud_core/lib/src/domain/ports/z_repository.dart',
      );
      expect(src.existsSync(), isTrue, reason: 'source du port introuvable');
      final String texte = src.readAsStringSync();
      final int debut = texte.indexOf('abstract class ZReadOnlyRepository');
      final int fin = texte.indexOf('abstract class ZRepository', debut);
      expect(debut, greaterThan(-1));
      expect(fin, greaterThan(debut));
      // Corps de l'interface, commentaires retirés (un exemple de dartdoc peut
      // légitimement citer `save`).
      final String corps = texte
          .substring(debut, fin)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('///'))
          .join('\n');

      for (final String ecriture in <String>[
        'save(',
        'softDelete(',
        'restore(',
        'purgeLocalPropagatingTombstone(',
      ]) {
        expect(corps.contains(ecriture), isFalse,
            reason: '`$ecriture` ne doit PAS rejoindre la surface de lecture — '
                'c\'est l\'invariant que CR-LEX-32 demande');
      }
      // Contrôle POSITIF : la détection sait trouver un membre présent.
      expect(corps.contains('getById('), isTrue,
          reason: 'sans ce contrôle, un corps vide rendrait le test vert à tort');
    });
  });
}

/// Dépôt sans couche de sync : prouve le défaut `Left` du port.
class _RepoSansSync extends ZStudyRepository<_Note> {
  @override
  Future<ZResult<_Note>> persist(_Note item, {String? collectionId}) async =>
      Right<ZFailure, _Note>(item);
  @override
  Stream<List<_Note>> watchAll() => Stream<List<_Note>>.value(const <_Note>[]);
  @override
  Stream<List<_Note>> watch(ZDataRequest request) =>
      Stream<List<_Note>>.value(const <_Note>[]);
  @override
  Future<ZResult<List<_Note>>> getAll({ZDataRequest? request}) async =>
      const Right<ZFailure, List<_Note>>(<_Note>[]);
  @override
  Future<ZResult<_Note>> getById(String id) async =>
      Left<ZFailure, _Note>(const ZNotFoundFailure('x'));
  @override
  Future<ZResult<Unit>> softDelete(String id) async =>
      const Right<ZFailure, Unit>(unit);
  @override
  Future<ZResult<Unit>> restore(String id) async =>
      const Right<ZFailure, Unit>(unit);
  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      const Right<ZFailure, int>(0);
  @override
  Future<ZResult<Unit>> sync() async => const Right<ZFailure, Unit>(unit);
  @override
  void dispose() {}
}
