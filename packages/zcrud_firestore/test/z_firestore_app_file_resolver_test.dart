// Gardes de `ZFirestoreAppFileResolver` — adaptateur Firestore du port neutre
// `ZAppFileResolver` (zcrud_core).
//
// Le défaut fermé : DODLP persiste des **identifiants** de fichiers
// (`shipDocumentsIds`, `bondStorePhotosIds`) ; sans résolveur, un champ fichier
// migré s'affiche VIDE sur une donnée existante, sans erreur.
//
// Backend : `fake_cloud_firestore` (aucun réseau). L'injection d'échec passe par
// des sous-classes de `FakeFirebaseFirestore` (`_ThrowingFirestore`,
// `_ThrowingOnNthFirestore`, `_HangingFirestore`) — même convention que
// `firebase_z_repository_impl_test.dart`.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

import 'support/z_sources.dart' show stripped, strippedSource;

const String _kFiles = 'AppFile';

/// Sème `count` documents `f0..f{count-1}` à la forme DODLP MESURÉE (camelCase).
Future<void> _seed(FakeFirebaseFirestore fs, int count) async {
  for (var i = 0; i < count; i++) {
    await fs.collection(_kFiles).doc('f$i').set(<String, dynamic>{
      'id': 'f$i',
      'name': 'doc$i.pdf',
      'type': 'pdf',
      'status': 'uploaded',
      'cloudPath': 'ships/doc$i.pdf',
      'cloudUrl': 'https://example.invalid/doc$i.pdf',
      'deleted': false,
    });
  }
}

ZFirestoreAppFileResolver _resolver(
  FirebaseFirestore fs, {
  List<ZAppFileRefLocation>? locations,
  int? batchSize,
  ZAppFileDocumentMapper? mapper,
  bool skipDeleted = true,
  Duration? resolveTimeout,
  void Function(List<String>)? onBatch,
}) =>
    ZFirestoreAppFileResolver(
      firestore: fs,
      collectionPath: _kFiles,
      locations: locations ??
          const <ZAppFileRefLocation>[ZAppFileRefLocation.documentId],
      batchSize: batchSize ?? kZFirestoreWhereInLimit,
      mapper: mapper,
      skipDeleted: skipDeleted,
      resolveTimeout: resolveTimeout,
      onBatch: onBatch,
    );

// ───────────────────────── Injecteurs d'échec ─────────────────────────────

class _ThrowingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'firestore', code: 'unavailable');
  }
}

/// Échoue à la **n-ième** ouverture de collection (⇒ un paquet sur sept).
class _ThrowingOnNthFirestore extends FakeFirebaseFirestore {
  _ThrowingOnNthFirestore(this.failAt);

  final int failAt;
  int calls = 0;
  bool armed = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (!armed) return super.collection(path);
    calls++;
    if (calls == failAt) {
      throw FirebaseException(plugin: 'firestore', code: 'unavailable');
    }
    return super.collection(path);
  }
}

// `CollectionReference` dérive du `Query` **scellé** de `cloud_firestore` : le
// seul moyen d'obtenir un `get()` PENDANT est de l'implémenter via
// `noSuchMethod`. Double de test uniquement, jamais en `lib/`.
// ignore: subtype_of_sealed_class
class _HangingCollection implements CollectionReference<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      return Completer<QuerySnapshot<Map<String, dynamic>>>().future;
    }
    return this;
  }
}

/// Lève une erreur ARBITRAIRE (Exception OU Error) à l'ouverture de collection.
class _ThrowingKindFirestore extends FakeFirebaseFirestore {
  _ThrowingKindFirestore(this.toThrow);

  final Object toThrow;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw toThrow;
  }
}

class _HangingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _HangingCollection();
}

void main() {
  // ───────────────────── Découpage en paquets (limite whereIn) ─────────────

  group('découpage en paquets — la limite `whereIn` est MESURÉE à 30', () {
    test('la constante reflète la limite de la version épinglée', () {
      expect(kZFirestoreWhereInLimit, 30);
    });

    test(
        'fake_cloud_firestore 4.2.0 REFUSE 31 valeurs — la limite est réelle, '
        'pas décorative', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 1);
      expect(
        () => fs
            .collection(_kFiles)
            .where(FieldPath.documentId,
                whereIn: List<String>.generate(31, (i) => 'f$i'))
            .get(),
        throwsA(isA<ArgumentError>()),
        reason:
            'sans découpage, une liste de 200 références est structurellement '
            'impossible — la garde des 200 ci-dessous ne serait pas vacante',
      );
    });

    test('zChunkAppFileRefs découpe 200 en 7 paquets de ≤ 30', () {
      final refs = List<String>.generate(200, (i) => 'f$i');
      final chunks = zChunkAppFileRefs(refs, kZFirestoreWhereInLimit);

      expect(chunks.length, 7);
      expect(chunks.map((c) => c.length).toList(),
          <int>[30, 30, 30, 30, 30, 30, 20]);
      expect(chunks.every((c) => c.length <= kZFirestoreWhereInLimit), isTrue);
      // Ni perte, ni doublon, ni réordonnancement.
      expect(chunks.expand((c) => c).toList(), refs);
    });

    test('zChunkAppFileRefs : reste exact quand la taille divise', () {
      expect(
        zChunkAppFileRefs(<String>['a', 'b', 'c', 'd'], 2),
        <List<String>>[
          <String>['a', 'b'],
          <String>['c', 'd'],
        ],
      );
      expect(zChunkAppFileRefs(<String>[], 30), isEmpty);
      expect(() => zChunkAppFileRefs(<String>['a'], 0),
          throwsA(isA<ArgumentError>()));
    });

    test(
        '200 références FRANCHISSENT la limite : 7 requêtes émises, aucune > 30, '
        '200 fichiers résolus', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 200);
      final batches = <List<String>>[];
      final refs = List<String>.generate(200, (i) => 'f$i');

      // Construction DIRECTE, sans passer `batchSize` : c'est la VALEUR PAR
      // DÉFAUT du constructeur qui est mise à l'épreuve ici (une garde qui
      // impose elle-même la taille de paquet serait vacante sur ce sujet).
      final files = await ZFirestoreAppFileResolver(
        firestore: fs,
        collectionPath: _kFiles,
        onBatch: batches.add,
      ).resolve(refs);

      expect(files.length, 200);
      expect(files.map((f) => f.id).toList(), refs,
          reason: 'appariement par id ET ordre de première apparition');
      expect(batches.length, 7, reason: 'ceil(200/30)');
      expect(batches.map((b) => b.length).toList(),
          <int>[30, 30, 30, 30, 30, 30, 20]);
      expect(batches.every((b) => b.length <= kZFirestoreWhereInLimit), isTrue);
      expect(batches.expand((b) => b).toList(), refs);
    });
  });

  // ───────────────────── Références manquantes / doublons / ordre ──────────

  group('références manquantes, doublons, ordre', () {
    test('une référence sans document est ABSENTE — pas une exception, '
        'pas un objet fabriqué', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 3);

      final files =
          await _resolver(fs).resolve(<String>['f0', 'inconnue', 'f2']);

      expect(files.map((f) => f.id).toList(), <String>['f0', 'f2']);
      expect(files.any((f) => f.id == 'inconnue'), isFalse,
          reason: 'aucun AppFile fabriqué pour une référence non résolue');
    });

    test('AUCUNE référence résolue ⇒ liste vide, jamais une erreur', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 2);

      final result =
          await _resolver(fs).resolveResult(<String>['x', 'y', 'z']);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => fail('Left inattendu')), isEmpty);
    });

    test('une référence en double n\'est demandée QU\'UNE fois et ne rend '
        'QU\'UN AppFile', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 3);
      final batches = <List<String>>[];

      final files = await _resolver(fs, onBatch: batches.add)
          .resolve(<String>['f1', 'f0', 'f1', 'f1']);

      expect(files.map((f) => f.id).toList(), <String>['f1', 'f0']);
      expect(batches.single, <String>['f1', 'f0'],
          reason: 'dédoublonné AVANT la requête');
    });

    test('l\'ordre rendu est celui de PREMIÈRE apparition, pas celui du '
        'backend', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 5);

      final files =
          await _resolver(fs).resolve(<String>['f4', 'f0', 'f3', 'f1']);

      expect(files.map((f) => f.id).toList(),
          <String>['f4', 'f0', 'f3', 'f1']);
    });

    test('références vides et liste vide : AUCUNE requête émise', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 2);
      final batches = <List<String>>[];
      final r = _resolver(fs, onBatch: batches.add);

      expect(await r.resolve(const <String>[]), isEmpty);
      expect(await r.resolve(const <String>['', '']), isEmpty);
      expect(batches, isEmpty,
          reason: '`whereIn` refuse une liste vide — jamais de requête à vide');
    });
  });

  // ───────────────────── Échecs (AD-10) ───────────────────────────────────

  group('AD-10 — les trois échecs sont tenus', () {
    test('échec réseau : FirebaseException → Left(ZServerFailure), '
        'AUCUN type backend ne fuit', () async {
      final result =
          await _resolver(_ThrowingFirestore()).resolveResult(<String>['f0']);

      expect(result.isLeft(), isTrue);
      final failure = result.fold((f) => f, (_) => fail('Right inattendu'));
      expect(failure, isA<ZServerFailure>());
      expect(failure, isNot(isA<FirebaseException>()));
    });

    test('échec réseau : `resolve` (voie du port) lève une Exception typée, '
        'jamais un Error', () async {
      final r = _resolver(_ThrowingFirestore());

      await expectLater(
        r.resolve(<String>['f0']),
        throwsA(
          isA<ZAppFileResolveException>()
              .having((e) => e.failure, 'failure', isA<ZServerFailure>()),
        ),
      );
      // `Exception`, pas `Error` : l'échec NORMAL d'une E/S. Un consommateur qui
      // n'attraperait que `Error` doit quand même le voir passer.
      expect(const ZAppFileResolveException(ZServerFailure('x')),
          isA<Exception>());
    });

    test('un paquet perdu N\'EST PAS rendu en liste partielle — sinon 30 '
        'références passeraient pour « introuvables »', () async {
      final fs = _ThrowingOnNthFirestore(3);
      await _seed(fs, 200);
      // Le seed ne compte pas : l'injecteur ne s'arme qu'après.
      fs.armed = true;

      final result = await _resolver(fs)
          .resolveResult(List<String>.generate(200, (i) => 'f$i'));

      expect(result.isLeft(), isTrue,
          reason: 'un échec partiel doit être un ÉCHEC, pas une absence');
      expect(result.fold((f) => f, (_) => null), isA<ZServerFailure>());
    });

    test('un Future qui ne se termine JAMAIS est tranché par le timeout',
        () async {
      final r = _resolver(
        _HangingFirestore(),
        resolveTimeout: const Duration(milliseconds: 40),
      );
      expect(r.timeout, const Duration(milliseconds: 40));

      // Filet de test : si l'adaptateur ne tranchait PAS, l'échec serait un
      // PENDU (rouge d'infrastructure, sans valeur de preuve). Le filet le
      // convertit en une valeur DISTINCTE, ce qui rend l'échec ASSERTIF.
      final result = await r.resolveResult(<String>['f0']).timeout(
            const Duration(seconds: 2),
            onTimeout: () => Left<ZFailure, List<AppFile>>(
              const ZDomainFailure('PENDU — adaptateur sans délai de garde'),
            ),
          );

      expect(result.isLeft(), isTrue);
      final failure = result.fold((f) => f, (_) => fail('Right inattendu'));
      expect(failure, isA<ZServerFailure>(),
          reason: 'un ZDomainFailure ici signifierait que le filet de TEST a '
              'tranché à la place de l\'adaptateur');
      expect(failure.message, contains('timed out'));
    });

    test('AUCUNE erreur ne s\'échappe de resolveResult — ni Exception, '
        'ni Error (les DEUX branches)', () async {
      for (final thrown in <Object>[
        const FormatException('E/S illisible'), // Exception
        StateError('bug de programmation'), // Error
      ]) {
        final r = _resolver(_ThrowingKindFirestore(thrown));
        // Filet : une erreur ÉCHAPPÉE devient une valeur distincte, l'échec
        // reste donc ASSERTIF (et non un rouge d'exception non rattrapée).
        final result = await r.resolveResult(<String>['f0']).catchError(
          (Object e) => Left<ZFailure, List<AppFile>>(
            ZDomainFailure('ÉCHAPPÉE: ${e.runtimeType}'),
          ),
        );

        expect(result.isLeft(), isTrue);
        expect(result.fold((f) => f, (_) => null), isA<ZServerFailure>(),
            reason: 'échappée pour ${thrown.runtimeType} — un `on Error` seul '
                'laisserait passer l\'échec NORMAL d\'une E/S');
      }
    });

    test('le timeout par défaut est celui du PORT (15 s), surchargeable', () {
      final fs = FakeFirebaseFirestore();
      expect(_resolver(fs).timeout, const Duration(seconds: 15));
      expect(
        _resolver(fs, resolveTimeout: const Duration(seconds: 3)).timeout,
        const Duration(seconds: 3),
      );
    });
  });

  // ───────────────────── Désérialisation défensive (AD-10) ────────────────

  group('AD-10 — désérialisation défensive', () {
    test('document au corps TOTALEMENT corrompu : AppFile produit quand même, '
        'jamais un throw, jamais une « absence »', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('f0').set(<String, dynamic>{
        'name': 42, // mauvais type
        'cloudUrl': <String>['pas', 'une', 'url'], // mauvais type
        'status': 'martien', // enum inconnue
        'sizeBytes': 'douze', // non parsable
      });

      final files = await _resolver(fs).resolve(<String>['f0']);

      expect(files, hasLength(1),
          reason: 'le document EXISTE — il ne doit pas passer pour introuvable');
      final f = files.single;
      expect(f.id, 'f0');
      expect(f.name, '');
      expect(f.remoteUrl, isNull);
      expect(f.sizeBytes, isNull);
      expect(f.uploadState, ZAppFileUploadState.pending,
          reason: 'enum inconnue ⇒ repli sûr');
    });

    test('document VIDE : AppFile minimal, id == référence', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('f0').set(<String, dynamic>{});

      final f = (await _resolver(fs).resolve(<String>['f0'])).single;

      expect(f.id, 'f0');
      expect(f.name, '');
      expect(f.uploadState, ZAppFileUploadState.pending);
    });

    test('mapping de valeur AppDocumentStatus (7 valeurs DODLP) → '
        'ZAppFileUploadState (4)', () {
      const m = ZFirestoreAppFileResolver.mapDodlpDocumentStatus;
      expect(m('draft'), 'pending');
      expect(m('uploading'), 'uploading');
      expect(m('uploaded'), 'uploaded');
      expect(m('converting'), 'uploaded');
      expect(m('converted'), 'uploaded');
      expect(m('embedding'), 'uploaded');
      expect(m('embedded'), 'uploaded');
      expect(m('failed'), 'failed');
      // Défensif : inconnu / non-String ⇒ replié par `fromName` sur `pending`.
      expect(ZAppFileUploadState.fromName(m('martien')),
          ZAppFileUploadState.pending);
      expect(ZAppFileUploadState.fromName(m(7)), ZAppFileUploadState.pending);
    });

    test('`converted` (DODLP) devient `uploaded` bout-en-bout', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('f0').set(<String, dynamic>{
        'status': 'converted',
        'name': 'a.pdf',
      });

      final f = (await _resolver(fs).resolve(<String>['f0'])).single;
      expect(f.uploadState, ZAppFileUploadState.uploaded);
    });

    test('sans état persisté : une URL distante ⇒ uploaded, sinon pending',
        () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('avec').set(<String, dynamic>{
        'cloudUrl': 'https://example.invalid/a.pdf',
      });
      await fs.collection(_kFiles).doc('sans').set(<String, dynamic>{
        'name': 'a.pdf',
      });

      final files = await _resolver(fs).resolve(<String>['avec', 'sans']);
      expect(files[0].uploadState, ZAppFileUploadState.uploaded);
      expect(files[1].uploadState, ZAppFileUploadState.pending);
    });

    test('champs DODLP mesurés projetés : name/cloudUrl/type ; cloudPath '
        'PRÉSERVÉ dans extra (jamais assimilé à localPath)', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 1);

      final f = (await _resolver(fs).resolve(<String>['f0'])).single;

      expect(f.name, 'doc0.pdf');
      expect(f.remoteUrl, 'https://example.invalid/doc0.pdf');
      expect(f.documentType, 'pdf',
          reason: 'AppDocumentType est un type de DOCUMENT, pas un MIME');
      expect(f.mimeType, isNull);
      expect(f.localPath, isNull,
          reason: 'cloudPath est un chemin Storage DISTANT, pas un chemin local');
      expect(f.extra?['cloudPath'], 'ships/doc0.pdf',
          reason: 'zéro perte : les champs non projetés survivent dans extra');
      expect(f.sizeBytes, isNull,
          reason: 'DODLP ne persiste aucune taille en octets — rien d\'inventé');
    });

    test('mapper hôte qui LÈVE ⇒ repli sur le mapper par défaut, le lot ne '
        'casse pas', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 2);

      final result = await _resolver(
        fs,
        mapper: (ref, data) => throw Exception('mapper hôte cassé'),
      ).resolveResult(<String>['f0', 'f1']);

      expect(result.isRight(), isTrue,
          reason: 'un mapper hôte cassé ne doit PAS faire échouer le lot');
      final files = result.getOrElse(() => fail('Left inattendu'));
      expect(files.map((f) => f.id).toList(), <String>['f0', 'f1']);
      expect(files.first.name, 'doc0.pdf');
    });

    test('mapper hôte qui rend null ⇒ référence INTROUVABLE (choix explicite)',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 2);

      final files = await _resolver(
        fs,
        mapper: (ref, data) => ref == 'f0' ? null : AppFile(id: ref),
      ).resolve(<String>['f0', 'f1']);

      expect(files.map((f) => f.id).toList(), <String>['f1']);
    });

    test('contrat du port : AppFile.id est TOUJOURS la référence, même si le '
        'mapper hôte en pose une autre', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 1);

      final f = (await _resolver(
        fs,
        mapper: (ref, data) => const AppFile(id: 'MAUVAIS', name: 'x'),
      ).resolve(<String>['f0']))
          .single;

      expect(f.id, 'f0');
      expect(f.name, 'x', reason: 'le reste du mapper hôte est respecté');
    });
  });

  // ───────────────────── Emplacement de la référence ──────────────────────

  group('emplacement de la référence (schéma paramétrable)', () {
    test('par CHAMP `id` — le chemin de lecture mesuré chez DODLP', () async {
      final fs = FakeFirebaseFirestore();
      // Id de document VOLONTAIREMENT différent du champ `id` : seule la
      // recherche par champ peut réussir.
      await fs.collection(_kFiles).doc('autoIdXYZ').set(<String, dynamic>{
        'id': 'ref-1',
        'name': 'a.pdf',
      });

      final parDocId = await _resolver(fs).resolve(<String>['ref-1']);
      expect(parDocId, isEmpty);

      final parChamp = await _resolver(
        fs,
        locations: const <ZAppFileRefLocation>[
          ZAppFileRefLocation.field('id'),
        ],
      ).resolve(<String>['ref-1']);
      expect(parChamp.single.id, 'ref-1');
    });

    test('emplacements MULTIPLES : ids et URLs mélangés (streamFromIdsOrPaths)',
        () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('f0').set(<String, dynamic>{
        'id': 'f0',
        'cloudUrl': 'https://example.invalid/a.pdf',
        'name': 'a.pdf',
      });
      final batches = <List<String>>[];

      final files = await _resolver(
        fs,
        locations: const <ZAppFileRefLocation>[
          ZAppFileRefLocation.documentId,
          ZAppFileRefLocation.field('cloudUrl'),
        ],
        onBatch: batches.add,
      ).resolve(<String>['f0', 'https://example.invalid/a.pdf']);

      expect(files.map((f) => f.id).toList(),
          <String>['f0', 'https://example.invalid/a.pdf']);
      expect(batches.length, 2);
      expect(batches[1], <String>['https://example.invalid/a.pdf'],
          reason: 'le 2ᵉ emplacement ne requête QUE le reliquat non résolu');
    });

    test('un emplacement suivant n\'est PAS requêté si tout est résolu',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, 2);
      final batches = <List<String>>[];

      await _resolver(
        fs,
        locations: const <ZAppFileRefLocation>[
          ZAppFileRefLocation.documentId,
          ZAppFileRefLocation.field('cloudUrl'),
        ],
        onBatch: batches.add,
      ).resolve(<String>['f0', 'f1']);

      expect(batches.length, 1);
    });

    test('ZAppFileRefLocation : égalité de valeur et surface NEUTRE', () {
      expect(const ZAppFileRefLocation.field('id'),
          const ZAppFileRefLocation.field('id'));
      expect(ZAppFileRefLocation.documentId.fieldName, isNull);
      expect(const ZAppFileRefLocation.field('id').fieldName, 'id');
    });
  });

  // ───────────────────── Soft-delete ──────────────────────────────────────

  group('soft-delete', () {
    test('`deleted: true` ⇒ INTROUVABLE ; drapeau ABSENT ⇒ conservé', () async {
      final fs = FakeFirebaseFirestore();
      await fs
          .collection(_kFiles)
          .doc('mort')
          .set(<String, dynamic>{'deleted': true, 'name': 'x'});
      await fs
          .collection(_kFiles)
          .doc('sansDrapeau')
          .set(<String, dynamic>{'name': 'y'});

      final files =
          await _resolver(fs).resolve(<String>['mort', 'sansDrapeau']);

      expect(files.map((f) => f.id).toList(), <String>['sansDrapeau'],
          reason: 'différence DÉLIBÉRÉE avec `is_deleted == false` : la '
              'collection fichier d\'un hôte n\'est pas zcrud-native');
    });

    test('skipDeleted: false rend le document supprimé', () async {
      final fs = FakeFirebaseFirestore();
      await fs
          .collection(_kFiles)
          .doc('mort')
          .set(<String, dynamic>{'deleted': true, 'name': 'x'});

      final files =
          await _resolver(fs, skipDeleted: false).resolve(<String>['mort']);
      expect(files.single.id, 'mort');
    });
  });

  // ───────────────────── AD-16 : aucun type backend ne fuit ───────────────

  group('AD-16 — aucun type cloud_firestore hors de l\'adaptateur', () {
    test('un Timestamp du document n\'atteint JAMAIS le domaine (extra porte '
        'une String ISO-8601)', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('f0').set(<String, dynamic>{
        'name': 'a.pdf',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 9, 12)),
        'nested': <String, dynamic>{
          'at': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        },
        'list': <dynamic>[Timestamp.fromDate(DateTime.utc(2025, 12, 31))],
      });

      final f = (await _resolver(fs).resolve(<String>['f0'])).single;

      expect(f.extra?['createdAt'], isA<String>());
      expect(f.extra?['createdAt'], '2026-08-09T12:00:00.000Z');
      expect(f.extra?['createdAt'], isNot(isA<Timestamp>()));
      expect((f.extra?['nested'] as Map)['at'], isA<String>());
      expect((f.extra?['list'] as List).single, isA<String>());
    });

    test('le mapper hôte ne reçoit AUCUN type cloud_firestore', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection(_kFiles).doc('f0').set(<String, dynamic>{
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 9)),
      });
      Map<String, dynamic>? seen;

      await _resolver(fs, mapper: (ref, data) {
        seen = data;
        return AppFile(id: ref);
      }).resolve(<String>['f0']);

      expect(seen, isNotNull);
      expect(seen!.values.whereType<Timestamp>(), isEmpty);
      expect(seen!['createdAt'], isA<String>());
    });

    test(
        'z_firestore_app_file_resolver.dart : aucune signature PUBLIQUE ne '
        'porte un type backend (seule couture tolérée : le paramètre '
        '`FirebaseFirestore firestore` du constructeur)', () {
      // P0b : dé-commentateur PARTAGÉ ROBUSTE — l'ancien `inBlockComment`
      // local (a) ne détectait un bloc QUE s'il s'ouvrait en DÉBUT de ligne,
      // et (b) la boucle de RECOLLAGE de signature (ci-dessous) ne l'utilisait
      // même PAS : elle ne retirait qu'un `//` de fin de ligne
      // (`l.split('//').first`), laissant un `/* … */` embarqué dans une
      // signature multi-lignes intact — un type banni CITÉ dans ce bloc aurait
      // fait rougir la garde à tort.
      final lines = stripped(
        File('${_pkgDir().path}/lib/src/data/z_firestore_app_file_resolver.dart'),
      );

      final forbidden = RegExp(
        r'\bTimestamp\b|\bFilter\b|\bFirebaseException\b|\bDocumentSnapshot\b'
        r'|\bQuerySnapshot\b|\bCollectionReference\b|\bDocumentReference\b'
        r'|\bWriteBatch\b|\bGeoPoint\b|\bFieldPath\b|\bQuery\b'
        r'|\bFirebaseFirestore\b|\bBox\b|\bHiveError\b',
      );

      final offenders = <String>[];
      var scanned = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // Déclaration PUBLIQUE : membre de classe (indentation 2) ou top-level
        // (indentation 0), dont le nom ne commence pas par `_`.
        final indent = line.length - trimmed.length;
        if (indent != 0 && indent != 2) continue;
        final decl = RegExp(
          r'^(?:@\w+\s+)*(?:abstract\s+|final\s+|const\s+|static\s+|factory\s+)*'
          r'(?:class|typedef|enum|mixin|extension)?\s*[\w<>,\.\?\[\]\s]*?'
          r'\b([A-Za-z]\w*)\s*(?:\(|=>|\{|;|=\s)',
        ).firstMatch(trimmed);
        if (decl == null) continue;
        if (decl.group(1)!.startsWith('_')) continue;

        // Signature = de la déclaration jusqu'à la fermeture des parenthèses
        // (ou la fin de ligne si aucune n'est ouverte).
        final buffer = StringBuffer();
        var depth = 0;
        var started = false;
        for (var j = i; j < lines.length; j++) {
          final code = lines[j];
          buffer.writeln(code);
          for (final ch in code.split('')) {
            if (ch == '(') {
              depth++;
              started = true;
            } else if (ch == ')') {
              depth--;
            }
          }
          if (!started || depth <= 0) break;
        }
        var signature = buffer.toString();
        // Couture backend SANCTIONNÉE (documentée), retirée avant contrôle.
        signature =
            signature.replaceAll('required FirebaseFirestore firestore,', '');
        scanned++;
        final hit = forbidden.firstMatch(signature);
        if (hit != null) {
          offenders.add('${decl.group(1)} → ${hit.group(0)}');
        }
      }

      expect(scanned, greaterThan(15),
          reason: 'la garde doit avoir un SUJET (déclarations réellement vues)');
      expect(offenders, isEmpty);
    });

    test('le barrel n\'exporte pas cloud_firestore', () {
      // P0b : source dé-commentée.
      final barrel =
          strippedSource(File('${_pkgDir().path}/lib/zcrud_firestore.dart'));
      expect(barrel.contains("export 'package:cloud_firestore"), isFalse);
      expect(
        barrel.contains("export 'src/data/z_firestore_app_file_resolver.dart'"),
        isTrue,
        reason: 'le résolveur DOIT être atteignable par l\'API publique',
      );
    });
  });

  // ───────────────────── Conformité au port ───────────────────────────────

  group('conformité au port ZAppFileResolver', () {
    test('l\'adaptateur EST un ZAppFileResolver injectable', () {
      final ZAppFileResolver r = _resolver(FakeFirebaseFirestore());
      expect(r, isA<ZAppFileResolver>());
      expect(r.timeout, isA<Duration>());
    });

    test('collectionPath vide et batchSize hors bornes sont refusés', () {
      final fs = FakeFirebaseFirestore();
      expect(
        () => ZFirestoreAppFileResolver(firestore: fs, collectionPath: ''),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ZFirestoreAppFileResolver(
            firestore: fs, collectionPath: _kFiles, batchSize: 31),
        throwsA(isA<AssertionError>()),
        reason: 'au-delà de la limite mesurée, la requête échouerait en vol',
      );
      expect(
        () => ZFirestoreAppFileResolver(
            firestore: fs, collectionPath: _kFiles, batchSize: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ZFirestoreAppFileResolver(
          firestore: fs,
          collectionPath: _kFiles,
          locations: const <ZAppFileRefLocation>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

Directory _pkgDir() {
  for (final base in <String>['', 'packages/zcrud_firestore/']) {
    final dir = Directory(base.isEmpty ? '.' : base);
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/src/data').existsSync()) {
      return dir;
    }
  }
  fail('racine du package zcrud_firestore introuvable');
}
