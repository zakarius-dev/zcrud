// CR-LEX-44 — quatre membres de `ZStudyRepository<T>` ont une implémentation par
// défaut qui rend `Left(...)` pour dire « ce dépôt n'a pas de couche de sync /
// de couche distante ». Le refus était **explicite mais indiscernable** : tous
// rendaient un `ZDomainFailure`, exactement comme une panne réelle. Pour choisir
// entre « je bascule sur mon propre chemin » et « je remonte l'erreur »,
// l'appelant n'avait que la **comparaison de chaîne**.
//
// 🔴 Mesuré côté hôte, deux fois indépendamment : adopter un de ces membres
// faisait passer une garantie de STRUCTURELLE à CONDITIONNELLE à
// l'implémentation injectée — avec une dégradation SILENCIEUSE dans un cas
// (index méta vide ⇒ tri faux) et un ÉCHEC VISIBLE PAR L'UTILISATEUR dans
// l'autre. C'est ce qui maintenait CR-26 et CR-35 contournées.
//
// ⚠️ La CR ne nommait que DEUX membres (`getAllWithMeta`,
// `purgeLocalPropagatingTombstone`). Le motif est identique sur `persistMerging`
// et `listParentIds` — dont les dartdocs se citaient mutuellement en modèle.
// Les quatre sont traités : n'en corriger que deux aurait laissé le défaut
// intact là où il se propageait.
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

class _FakeEntity implements ZEntity {
  const _FakeEntity({this.id});

  @override
  final String? id;

  @override
  bool get isEphemeral => id == null;
}

/// Dépôt qui n'override AUCUN membre optionnel : le cas exact de la CR.
class _DepotNu extends ZStudyRepository<_FakeEntity> {
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
      const Right<ZFailure, _FakeEntity>(_FakeEntity(id: 'x'));

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      const Right<ZFailure, int>(0);

  @override
  Future<ZResult<_FakeEntity>> persist(
    _FakeEntity item, {
    String? collectionId,
  }) async =>
      Right<ZFailure, _FakeEntity>(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async =>
      Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async => Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> sync() async => Right<ZFailure, Unit>(unit);

  @override
  Future<void> dispose() async {}
}

/// Dépôt qui SUPPORTE tout — contrôle positif : sans lui, un test qui voit
/// partout « non supporté » ne prouverait rien.
class _DepotComplet extends _DepotNu {
  @override
  Future<ZResult<List<ZSyncEntry<_FakeEntity>>>> getAllWithMeta() async =>
      const Right<ZFailure, List<ZSyncEntry<_FakeEntity>>>(
        <ZSyncEntry<_FakeEntity>>[],
      );

  @override
  Future<ZResult<Unit>> purgeLocalPropagatingTombstone(String id) async =>
      Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<List<String>>> listParentIds() async =>
      const Right<ZFailure, List<String>>(<String>['p1']);

  @override
  Future<ZResult<_FakeEntity>> persistMerging(
    _FakeEntity item, {
    String? collectionId,
  }) async =>
      Right<ZFailure, _FakeEntity>(item);
}

/// Dépôt EN PANNE — la moitié qui donne son sens au test : la discrimination
/// n'est prouvée que si un échec RÉEL n'est PAS pris pour une capacité absente.
class _DepotEnPanne extends _DepotNu {
  @override
  Future<ZResult<List<ZSyncEntry<_FakeEntity>>>> getAllWithMeta() async =>
      const Left<ZFailure, List<ZSyncEntry<_FakeEntity>>>(
        ZCacheFailure('la box Hive est corrompue'),
      );

  @override
  Future<ZResult<Unit>> purgeLocalPropagatingTombstone(String id) async =>
      const Left<ZFailure, Unit>(ZServerFailure('timeout réseau'));
}

/// Ce que l'hôte veut pouvoir écrire — SANS jamais comparer une chaîne.
bool _estCapaciteAbsente(ZFailure f) => f is ZUnsupportedOperationFailure;

void main() {
  group('🔴 CR-LEX-44 — l\'indisponibilité est DISCRIMINABLE par type', () {
    test('🔴 les QUATRE défauts rendent `ZUnsupportedOperationFailure`',
        () async {
      final repo = _DepotNu();
      final resultats = <String, ZFailure?>{
        'getAllWithMeta': (await repo.getAllWithMeta()).fold((f) => f, (_) => null),
        'purgeLocalPropagatingTombstone':
            (await repo.purgeLocalPropagatingTombstone('x'))
                .fold((f) => f, (_) => null),
        'listParentIds':
            (await repo.listParentIds()).fold((f) => f, (_) => null),
        'saveMerging': (await repo.saveMerging(const _FakeEntity(id: 'a')))
            .fold((f) => f, (_) => null),
      };
      for (final e in resultats.entries) {
        expect(e.value, isA<ZUnsupportedOperationFailure>(),
            reason: '${e.key} : refus indiscernable d\'une panne');
      }
    });

    test('🔴 chaque échec NOMME son opération (diagnostic sans parser)',
        () async {
      final repo = _DepotNu();
      Future<String?> op(Future<ZResult<Object?>> f) async => (await f).fold(
            (fail) =>
                fail is ZUnsupportedOperationFailure ? fail.operation : null,
            (_) => null,
          );
      expect(await op(repo.getAllWithMeta()), 'getAllWithMeta');
      expect(await op(repo.purgeLocalPropagatingTombstone('x')),
          'purgeLocalPropagatingTombstone');
      expect(await op(repo.listParentIds()), 'listParentIds');
      // `saveMerging` délègue au membre protégé `persistMerging` : c'est LUI que
      // l'hôte doit voir nommé, pas le Template Method qui l'appelle.
      expect(await op(repo.saveMerging(const _FakeEntity(id: 'a'))),
          'persistMerging');
    });

    test('🔴 une PANNE RÉELLE n\'est PAS prise pour une capacité absente',
        () async {
      final panne = _DepotEnPanne();
      final f1 = (await panne.getAllWithMeta()).fold((f) => f, (_) => null);
      final f2 = (await panne.purgeLocalPropagatingTombstone('x'))
          .fold((f) => f, (_) => null);
      expect(_estCapaciteAbsente(f1!), isFalse,
          reason: 'une box corrompue doit REMONTER, pas déclencher un repli');
      expect(_estCapaciteAbsente(f2!), isFalse);
      expect(f1, isA<ZCacheFailure>());
      expect(f2, isA<ZServerFailure>());
    });

    test('contrôle positif : un dépôt COMPLET ne rend aucun refus', () async {
      final complet = _DepotComplet();
      expect((await complet.getAllWithMeta()).isRight(), isTrue);
      expect((await complet.purgeLocalPropagatingTombstone('x')).isRight(),
          isTrue);
      expect((await complet.listParentIds()).isRight(), isTrue);
      expect(
          (await complet.saveMerging(const _FakeEntity(id: 'a'))).isRight(),
          isTrue);
    });

    test('🔴 le repli de l\'hôte est DÉTERMINISTE sur les trois cas', () async {
      // Le geste exact que la CR demande de rendre possible.
      Future<String> route(ZStudyRepository<_FakeEntity> r) async =>
          (await r.getAllWithMeta()).fold(
            (f) => _estCapaciteAbsente(f) ? 'repli' : 'erreur',
            (_) => 'ok',
          );
      expect(await route(_DepotNu()), 'repli');
      expect(await route(_DepotEnPanne()), 'erreur');
      expect(await route(_DepotComplet()), 'ok');
    });

    test('`ZUnsupportedOperationFailure` est un `ZFailure` à égalité de valeur',
        () {
      const a = ZUnsupportedOperationFailure('m', operation: 'op');
      const b = ZUnsupportedOperationFailure('m', operation: 'op');
      const c = ZUnsupportedOperationFailure('m', operation: 'autre');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c), reason: 'l\'opération participe à l\'identité');
      expect(a, isA<ZFailure>());
      expect(a.toString(), contains('op'));
    });

    test('🔴 il n\'est PAS confondu avec `ZDomainFailure` (l\'ancien défaut)',
        () {
      // C'est tout l'objet de la CR : avant, les quatre défauts étaient des
      // `ZDomainFailure`, donc `is ZDomainFailure` ne discriminait rien.
      const u = ZUnsupportedOperationFailure('m', operation: 'op');
      expect(u, isNot(isA<ZDomainFailure>()));
      expect(const ZDomainFailure('m'), isNot(isA<ZUnsupportedOperationFailure>()));
    });
  });
}
