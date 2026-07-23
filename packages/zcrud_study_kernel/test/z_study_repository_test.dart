/// Test à **pouvoir discriminant** du port `ZStudyRepository<T>` (Story ES-3.1,
/// AC2-AC6, R2/R12).
///
/// Le cœur (AC2) prouve que le hook `validate` n'est **PAS décoratif** : il passe
/// PAR `save` en observant un **espion** sur `persist` (compteur d'appels). Un
/// `validate → Left` doit **BLOQUER mécaniquement** `persist` (compteur == 0) ;
/// un `validate → Right` doit le laisser passer (compteur == 1).
///
/// **Injection R3 (rejouée par l'orchestrateur)** : retirer l'appel `validate`
/// du Template Method `save` (le rendre inconditionnellement `persist(...)`) fait
/// **ROUGIR** le test « validate→Left bloque persist » (persist appelé + `Right`
/// remonté). Un chemin *powerless* (appeler `validate` directement sans passer
/// par `save`) prouverait seulement que la méthode existe — on l'évite : tout
/// passe par `save`.
///
/// **Web-safe** (AC11) : pur Dart, aucun `dart:io`, PAS de `@TestOn('vm')` — le
/// test tourne sous `dart test` (VM) ET `dart test -p node` (JS).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Entité de test minimale : identité opaque + `parentId` (pour l'invariant
/// « 2 niveaux max » d'AC4). Éphémère tant que `id == null`.
class _FakeEntity implements ZEntity {
  const _FakeEntity({this.id, this.parentId});

  @override
  final String? id;

  final String? parentId;

  @override
  bool get isEphemeral => id == null;
}

/// Dépôt-espion : `persist` compte ses appels et capture ses arguments. Les
/// membres hérités non exercés par le test sont stubés minimalement.
class _SpyRepo extends ZStudyRepository<_FakeEntity> {
  _SpyRepo({this.validateOverride});

  final ZResult<Unit> Function(_FakeEntity item)? validateOverride;

  /// Compteur d'appels de `persist` — l'espion au cœur de la preuve AC2.
  int persistCount = 0;
  _FakeEntity? lastPersisted;
  String? lastCollectionId;

  @override
  ZResult<Unit> validate(_FakeEntity item) =>
      validateOverride?.call(item) ?? super.validate(item);

  @override
  Future<ZResult<_FakeEntity>> persist(
    _FakeEntity item, {
    String? collectionId,
  }) async {
    persistCount++;
    lastPersisted = item;
    lastCollectionId = collectionId;
    // Matérialisation de l'éphémère PAR L'IMPL (AC5) : le port ne l'impose ni ne
    // l'empêche — c'est `persist` (adapter ES-3.2) qui attribue l'`id`.
    final materialized = item.isEphemeral
        ? _FakeEntity(id: 'generated-id', parentId: item.parentId)
        : item;
    return Right<ZFailure, _FakeEntity>(materialized);
  }

  // --- Membres hérités stubés (le test n'exerce QUE `save`) ---------------
  @override
  Stream<List<_FakeEntity>> watchAll() =>
      Stream<List<_FakeEntity>>.value(const <_FakeEntity>[]);

  @override
  Stream<List<_FakeEntity>> watch(ZDataRequest request) =>
      Stream<List<_FakeEntity>>.value(const <_FakeEntity>[]);

  @override
  Future<ZResult<List<_FakeEntity>>> getAll({ZDataRequest? request}) async =>
      const Right<ZFailure, List<_FakeEntity>>(<_FakeEntity>[]);

  @override
  Future<ZResult<_FakeEntity>> getById(String id) async =>
      const Left<ZFailure, _FakeEntity>(ZNotFoundFailure('stub'));

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

void main() {
  group('AC1 — port générique héritant de ZSyncableRepository', () {
    test('_SpyRepo compile en n\'implémentant QUE persist (+ héritage abstrait) '
        'et expose watchAll()/sync() sans redéclaration', () {
      final repo = _SpyRepo();
      expect(repo, isA<ZStudyRepository<_FakeEntity>>());
      expect(repo, isA<ZSyncableRepository<_FakeEntity>>());
      expect(repo, isA<ZRepository<_FakeEntity>>());
      // Surface héritée disponible sans redéclaration propre au port.
      expect(repo.watchAll(), isA<Stream<List<_FakeEntity>>>());
      expect(repo.sync(), isA<Future<ZResult<Unit>>>());
    });
  });

  group('AC2 — Template Method : validate→Left BLOQUE persist (DISCRIMINANT)', () {
    test('save renvoie le Left exact ET persist n\'est JAMAIS appelé', () async {
      const rejet = ZDomainFailure('rejet');
      final repo = _SpyRepo(
        validateOverride: (_) => const Left<ZFailure, Unit>(rejet),
      );

      final result = await repo.save(const _FakeEntity(id: 'x'));

      // 1) le rejet EXACT remonte, non avalé, non transformé.
      expect(result.isLeft(), isTrue);
      expect(
        result.fold((f) => f, (_) => null),
        rejet,
        reason: 'le ZDomainFailure du validate doit remonter inchangé',
      );
      // 2) preuve par l'espion : persist BLOQUÉ mécaniquement.
      expect(
        repo.persistCount,
        0,
        reason: 'INJECTION R3 : retirer l\'appel validate(item) du template save '
            'ferait passer persistCount à 1 → ce test ROUGIT (pouvoir '
            'discriminant : un hook décoratif serait attrapé)',
      );
    });
  });

  group('AC3 — validate→Right laisse persister ; défaut = no-op succès', () {
    test('sans override, persist est appelé 1× ; collectionId threadé ; Right '
        'remonté inchangé', () async {
      final repo = _SpyRepo();
      const item = _FakeEntity(id: 'a');

      final result = await repo.save(item, collectionId: 'col-42');

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (e) => e), same(item));
      expect(repo.persistCount, 1);
      expect(repo.lastPersisted, same(item));
      expect(repo.lastCollectionId, 'col-42',
          reason: 'collectionId doit être threadé tel quel à persist');
    });

    test('le validate par défaut est PUR/TOTAL/déterministe (même verdict à '
        'répétition, aucune exception)', () {
      final repo = _SpyRepo();
      const item = _FakeEntity(id: 'a');

      final r1 = repo.validate(item);
      final r2 = repo.validate(item);

      expect(r1.isRight(), isTrue);
      expect(r2.isRight(), isTrue);
      expect(r1.fold((_) => null, (u) => u), r2.fold((_) => null, (u) => u));
      // Aucun appel de persist : validate seul n'écrit rien.
      expect(repo.persistCount, 0);
    });
  });

  group('AC4 — override réaliste « 2 niveaux max » (fixtures ISOLÉES)', () {
    // Reproduit study_folders_repository_impl.dart:141-165 : placer un dossier
    // sous un parent QUI A DÉJÀ UN PARENT créerait un niveau 3 → rejet.
    const alreadyLevel2 = 'sub-folder';
    ZResult<Unit> twoLevelMax(_FakeEntity item) {
      if (item.parentId == alreadyLevel2) {
        return const Left<ZFailure, Unit>(
          ZDomainFailure('Hiérarchie limitée à 2 niveaux.'),
        );
      }
      return const Right<ZFailure, Unit>(unit);
    }

    test('item VIOLANT l\'invariant : save = Left, persist non appelé', () async {
      final repo = _SpyRepo(validateOverride: twoLevelMax);

      final result = await repo.save(const _FakeEntity(parentId: alreadyLevel2));

      expect(result.isLeft(), isTrue);
      expect(repo.persistCount, 0);
    });

    test('item CONFORME (parent = racine) : save persiste', () async {
      final repo = _SpyRepo(validateOverride: twoLevelMax);

      final result = await repo.save(const _FakeEntity(parentId: 'root'));

      expect(result.isRight(), isTrue);
      expect(repo.persistCount, 1);
    });
  });

  group('AC5 — matérialisation éphémère : ADMISE par le port, portée par persist',
      () {
    test('persist matérialise un id pour une entité éphémère (le port ne '
        'l\'empêche ni ne l\'impose)', () async {
      final repo = _SpyRepo();

      final result = await repo.save(const _FakeEntity()); // id == null

      expect(result.isRight(), isTrue);
      final saved = result.fold((_) => null, (e) => e);
      expect(saved?.id, 'generated-id',
          reason: 'la matérialisation vit dans persist (impl), pas dans le port');
      expect(repo.lastPersisted!.isEphemeral, isTrue,
          reason: 'le port passe l\'entité éphémère telle quelle à persist');
    });

    test('validate peut rejeter une cible manquante sans que le port ne fige '
        'la règle', () async {
      final repo = _SpyRepo(
        validateOverride: (item) => item.parentId == null
            ? const Left<ZFailure, Unit>(ZDomainFailure('cible requise'))
            : const Right<ZFailure, Unit>(unit),
      );

      final rejected = await repo.save(const _FakeEntity());
      expect(rejected.isLeft(), isTrue);
      expect(repo.persistCount, 0);
    });
  });

  group('AC6 — flux NUS + Either partout (miroir de type statique)', () {
    test('watchAll retourne Stream<List<T>> NU (jamais Stream<Either<...>>)',
        () {
      final repo = _SpyRepo();
      expect(repo.watchAll(), isA<Stream<List<_FakeEntity>>>());
      expect(repo.watchAll(), isNot(isA<Stream<Either<Object, Object>>>()));
    });

    test('save et validate retournent des Either', () async {
      final repo = _SpyRepo();
      expect(repo.validate(const _FakeEntity(id: 'a')),
          isA<Either<ZFailure, Unit>>());
      expect(await repo.save(const _FakeEntity(id: 'a')),
          isA<Either<ZFailure, _FakeEntity>>());
    });
  });

  group('CR-LEX-34 — saveMerging : Template Method PRÉSERVANT', () {
    test('🔴 défaut = Left explicite (jamais un écrasement silencieux)',
        () async {
      // Comme listParentIds : un dépôt dont le backend ne sait pas fusionner le
      // DIT, il ne retombe pas en silence sur une écriture écrasante.
      final res = await _SpyRepo().saveMerging(const _FakeEntity(id: 'a'));
      expect(res.isLeft(), isTrue);
      res.fold(
        (f) => expect(f, isA<ZDomainFailure>()),
        (_) => fail('un défaut non supporté doit être Left'),
      );
    });

    test('🔴 validate→Left BLOQUE persistMerging (même garantie que save)',
        () async {
      var merged = 0;
      final repo = _MergeSpyRepo(
        onMerge: () => merged++,
        validateOverride: (_) =>
            Left<ZFailure, Unit>(const ZDomainFailure('rejeté')),
      );
      final res = await repo.saveMerging(const _FakeEntity(id: 'a'));
      expect(res.isLeft(), isTrue);
      expect(merged, 0,
          reason: 'un rejet métier doit couper l\'écriture préservante AUSSI');
    });

    test('validate→Right laisse passer vers persistMerging', () async {
      var merged = 0;
      final repo = _MergeSpyRepo(onMerge: () => merged++);
      final res = await repo.saveMerging(const _FakeEntity(id: 'a'));
      expect(res.isRight(), isTrue);
      expect(merged, 1);
    });
  });
}

/// Dépôt-espion qui OVERRIDE `persistMerging` — prouve que le Template Method
/// `saveMerging` l'appelle bien, et seulement après un `validate → Right`.
class _MergeSpyRepo extends ZStudyRepository<_FakeEntity> {
  _MergeSpyRepo({required this.onMerge, this.validateOverride});

  final void Function() onMerge;
  final ZResult<Unit> Function(_FakeEntity item)? validateOverride;

  @override
  ZResult<Unit> validate(_FakeEntity item) =>
      validateOverride?.call(item) ?? super.validate(item);

  @override
  Future<ZResult<_FakeEntity>> persistMerging(
    _FakeEntity item, {
    String? collectionId,
  }) async {
    onMerge();
    return Right<ZFailure, _FakeEntity>(item);
  }

  @override
  Future<ZResult<_FakeEntity>> persist(
    _FakeEntity item, {
    String? collectionId,
  }) async =>
      Right<ZFailure, _FakeEntity>(item);

  @override
  Stream<List<_FakeEntity>> watchAll() =>
      Stream<List<_FakeEntity>>.value(const <_FakeEntity>[]);
  @override
  Stream<List<_FakeEntity>> watch(ZDataRequest request) =>
      Stream<List<_FakeEntity>>.value(const <_FakeEntity>[]);
  @override
  Future<ZResult<List<_FakeEntity>>> getAll({ZDataRequest? request}) async =>
      const Right<ZFailure, List<_FakeEntity>>(<_FakeEntity>[]);
  @override
  Future<ZResult<_FakeEntity>> getById(String id) async =>
      Left<ZFailure, _FakeEntity>(const ZNotFoundFailure('x'));
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
