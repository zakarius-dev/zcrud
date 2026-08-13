// Gardes du vocabulaire de CORBEILLE : mixin `ZPurgeable` (capacité déclarée,
// jamais supposée), fabrique `ZRowAction.purgeWith` (troisième geste, gouverné
// par `ZCrudAction.clear`) et `ZTrashPolicy` (quels gestes sont voulus).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Entité minimale de test.
class _Doc extends ZEntity {
  const _Doc(this.id);

  @override
  final String? id;
}

/// Dépôt qui ne sait PAS purger : le port complet, rien de plus.
class _PlainRepo implements ZRepository<_Doc> {
  final List<String> softDeleted = <String>[];

  @override
  Future<ZResult<List<_Doc>>> getAll({ZDataRequest? request}) async =>
      const Right(<_Doc>[]);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async => const Right(0);

  @override
  Future<ZResult<_Doc>> getById(String id) async => Right(_Doc(id));

  @override
  Stream<List<_Doc>> watchAll() => const Stream<List<_Doc>>.empty();

  @override
  Stream<List<_Doc>> watch(ZDataRequest request) =>
      const Stream<List<_Doc>>.empty();

  @override
  Future<ZResult<_Doc>> save(_Doc item, {String? collectionId}) async =>
      Right(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    softDeleted.add(id);
    return const Right(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async => const Right(unit);

  @override
  void dispose() {}
}

/// Le MÊME dépôt, plus la capacité déclarée.
class _PurgeableRepo extends _PlainRepo with ZPurgeable<_Doc> {
  final List<String> purgedIds = <String>[];

  @override
  Future<ZResult<Unit>> purge(String id) async {
    purgedIds.add(id);
    return const Right(unit);
  }
}

void main() {
  group('ZPurgeable — capacité déclarée, jamais supposée', () {
    test('un dépôt sans le mixin ne se reconnaît PAS comme purgeable', () {
      final ZRepository<_Doc> repo = _PlainRepo();
      expect(repo is ZPurgeable<_Doc>, isFalse);
    });

    test('un dépôt avec le mixin se reconnaît, et reste un ZRepository', () {
      final ZRepository<_Doc> repo = _PurgeableRepo();
      expect(repo is ZPurgeable<_Doc>, isTrue);
      expect(repo, isA<ZRepository<_Doc>>());
    });

    test('la purge rend le contrat du port : ZResult<Unit>', () async {
      final repo = _PurgeableRepo();
      final result = await repo.purge('d1');
      expect(result.isRight(), isTrue);
      expect(repo.purgedIds, <String>['d1']);
      // Le geste de mise à la corbeille n'a PAS été emprunté au passage.
      expect(repo.softDeleted, isEmpty);
    });
  });

  group('ZRowAction.purgeWith', () {
    test('exige `clear`, est destructive, et porte ses défauts', () {
      final action = ZRowAction<_Doc>.purgeWith((context, entity) {});
      expect(action.requiredPermission, ZCrudAction.clear);
      expect(action.destructive, isTrue);
      expect(action.id, 'purge');
      expect(action.labelKey, 'deleteForever');
    });

    test('ne partage la permission d\'aucun autre geste de corbeille', () {
      final purge = ZRowAction<_Doc>.purgeWith((context, entity) {});
      final soft = ZRowAction<_Doc>.softDeleteWith((context, entity) {});
      final restore = ZRowAction<_Doc>.restoreWith((context, entity) {});
      expect(soft.requiredPermission, ZCrudAction.delete);
      expect(restore.requiredPermission, ZCrudAction.restore);
      expect(purge.requiredPermission, isNot(soft.requiredPermission));
      expect(purge.requiredPermission, isNot(restore.requiredPermission));
    });

    testWidgets('résolue, elle invoque le handler avec l\'entité de la ligne',
        (tester) async {
      final invoked = <String?>[];
      final action = ZRowAction<_Doc>.purgeWith(
        (context, entity) => invoked.add(entity.id),
      );
      late BuildContext ctx;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      );
      action.resolve(ctx, const _Doc('d7'), enabled: true).onInvoke();
      expect(invoked, <String?>['d7']);
    });
  });

  group('ZTrashPolicy', () {
    test('le défaut offre les trois gestes', () {
      const policy = ZTrashPolicy();
      expect(policy.softDelete, isTrue);
      expect(policy.restore, isTrue);
      expect(policy.purge, isTrue);
      expect(policy, ZTrashPolicy.full);
      expect(policy.isEmpty, isFalse);
    });

    test('`withoutPurge` ne retire QUE la purge', () {
      expect(ZTrashPolicy.withoutPurge.purge, isFalse);
      expect(ZTrashPolicy.withoutPurge.softDelete, isTrue);
      expect(ZTrashPolicy.withoutPurge.restore, isTrue);
    });

    test('`readOnly` n\'offre aucun geste', () {
      expect(ZTrashPolicy.readOnly.isEmpty, isTrue);
    });

    test('égalité de VALEUR et copyWith ciblé', () {
      expect(const ZTrashPolicy(restore: false),
          const ZTrashPolicy(restore: false));
      expect(const ZTrashPolicy(restore: false).hashCode,
          const ZTrashPolicy(restore: false).hashCode);
      expect(ZTrashPolicy.full.copyWith(purge: false),
          ZTrashPolicy.withoutPurge);
      expect(ZTrashPolicy.full.copyWith(), ZTrashPolicy.full);
    });
  });

  group('libellés du troisième geste', () {
    testWidgets('`deleteForever` et `confirmDeleteForeverItem` sont livrés en '
        'fr ET en en, et disent l\'irréversibilité', (tester) async {
      for (final locale in ZcrudLocalizationsDelegate.supportedLocales) {
        final loc = await const ZcrudLocalizationsDelegate().load(locale);
        for (final key in <String>['deleteForever', 'confirmDeleteForeverItem']) {
          expect(loc.maybeResolve(key), isNotNull,
              reason: '[$locale] clé $key absente');
          expect(loc.resolve(key), isNotEmpty);
        }
        // Le texte de la purge est DISTINCT de celui de la mise à la corbeille :
        // c'est ce qui empêche de confondre les deux gestes à l'écran.
        expect(loc.resolve('deleteForever'), isNot(loc.resolve('delete')));
        expect(loc.resolve('confirmDeleteForeverItem'),
            isNot(loc.resolve('confirmDeleteItem')));
      }
    });
  });
}
