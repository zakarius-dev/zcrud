// AC1/AC6/AC7/AC8 (E4-4, AD-16/AD-9/AD-11) : modèle d'action de ligne NEUTRE.
//
// - construction + résolution `ZRowAction<T>` → `ZResolvedRowAction` (sans `T`,
//   `onInvoke` lié à l'entité) ;
// - fabriques corbeille `softDelete`/`restore` dépliant `ZResult<Unit>` :
//   `Right` → `onSuccess` ; `Left(ZFailure)` → `onFailure` NON fatal (0 throw) ;
// - fabrique `edit` (handler app) + permission requise par fabrique.
//
// Aucun Syncfusion : test pur cœur (SM-5).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _FakeEntity extends ZEntity {
  const _FakeEntity(this._id);
  final String? _id;
  @override
  String? get id => _id;
}

/// Repo fake : n'implémente QUE softDelete/restore (le reste via noSuchMethod).
class _FakeRepo implements ZRepository<_FakeEntity> {
  _FakeRepo({this.deleteResult});

  ZResult<Unit>? deleteResult;
  final List<String> softDeleted = <String>[];
  final List<String> restored = <String>[];

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    softDeleted.add(id);
    return deleteResult ?? Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    restored.add(id);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return ctx;
}

void main() {
  testWidgets('AC1 : résolution lie l\'entité et onInvoke appelle le handler',
      (tester) async {
    final context = await _pumpContext(tester);
    _FakeEntity? received;
    final action = ZRowAction<_FakeEntity>(
      id: 'a',
      labelKey: 'edit',
      icon: Icons.edit,
      destructive: false,
      onInvoke: (ctx, entity) => received = entity,
    );
    const entity = _FakeEntity('e1');
    final resolved = action.resolve(context, entity, enabled: true);

    expect(resolved.id, 'a');
    expect(resolved.labelKey, 'edit');
    expect(resolved.icon, Icons.edit);
    expect(resolved.enabled, isTrue);
    expect(resolved.destructive, isFalse);
    expect(received, isNull);
    resolved.onInvoke();
    expect(received, same(entity));
  });

  testWidgets('AC2 : resolve(enabled:false) produit une action désactivée',
      (tester) async {
    final context = await _pumpContext(tester);
    final action = ZRowAction<_FakeEntity>(
      id: 'a',
      labelKey: 'delete',
      onInvoke: (_, __) {},
    );
    final resolved =
        action.resolve(context, const _FakeEntity('x'), enabled: false);
    expect(resolved.enabled, isFalse);
  });

  testWidgets('AC6 : softDelete factory appelle repo.softDelete(entity.id)',
      (tester) async {
    final context = await _pumpContext(tester);
    final repo = _FakeRepo();
    var success = false;
    final action = ZRowAction<_FakeEntity>.softDelete(
      repo,
      onSuccess: () => success = true,
    );
    expect(action.requiredPermission, ZCrudAction.delete);
    expect(action.destructive, isTrue);

    final resolved =
        action.resolve(context, const _FakeEntity('e1'), enabled: true);
    resolved.onInvoke();
    await tester.pump();

    expect(repo.softDeleted, <String>['e1']);
    expect(success, isTrue);
  });

  testWidgets('AC6 : softDelete d\'une entité éphémère (id null) = no-op',
      (tester) async {
    final context = await _pumpContext(tester);
    final repo = _FakeRepo();
    final action = ZRowAction<_FakeEntity>.softDelete(repo);
    action.resolve(context, const _FakeEntity(null), enabled: true).onInvoke();
    await tester.pump();
    expect(repo.softDeleted, isEmpty);
  });

  testWidgets('AC7 : restore factory appelle repo.restore(entity.id)',
      (tester) async {
    final context = await _pumpContext(tester);
    final repo = _FakeRepo();
    final action = ZRowAction<_FakeEntity>.restore(repo);
    expect(action.requiredPermission, ZCrudAction.restore);
    action.resolve(context, const _FakeEntity('e9'), enabled: true).onInvoke();
    await tester.pump();
    expect(repo.restored, <String>['e9']);
  });

  testWidgets('AC8 : Left(ZFailure) sur softDelete → onFailure, 0 throw',
      (tester) async {
    final context = await _pumpContext(tester);
    final repo = _FakeRepo(
      deleteResult: Left<ZFailure, Unit>(const ServerFailure('boom')),
    );
    ZFailure? failure;
    var success = false;
    final action = ZRowAction<_FakeEntity>.softDelete(
      repo,
      onFailure: (f) => failure = f,
      onSuccess: () => success = true,
    );
    action.resolve(context, const _FakeEntity('e1'), enabled: true).onInvoke();
    await tester.pump();

    expect(failure, isA<ServerFailure>());
    expect((failure! as ServerFailure).message, 'boom');
    expect(success, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC1 : fabrique edit délègue au handler app (permission update)',
      (tester) async {
    final context = await _pumpContext(tester);
    _FakeEntity? edited;
    final action = ZRowAction<_FakeEntity>.edit(
      onInvoke: (ctx, entity) => edited = entity,
    );
    expect(action.requiredPermission, ZCrudAction.update);
    const entity = _FakeEntity('e2');
    action.resolve(context, entity, enabled: true).onInvoke();
    expect(edited, same(entity));
  });
}
