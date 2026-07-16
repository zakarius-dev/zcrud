// ES-11.1 AC1/AC4/AC5 — controller GetX générique branchant le port
// `ZStudyRepository<T>`.
//
// AC1 : `ZStudyWatchController` ré-émet EXACTEMENT la `Stream<List<T>>` nue du
//        repo (ordre/contenu préservés, AD-5) dans son observable.
// AC4 : seam absent ⇒ `ZScopeError` actionnable (message contient le Type) —
//        R3-I4 : avaler/retirer le throw ⇒ rougit.
// AC5 : `onClose()` annule la souscription (StreamController.onCancel) ⇒ pas de
//        fuite — R3-I5 : retirer `_sub.cancel()` ⇒ rougit.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Entité de test minimale (identité opaque, AD-4).
class _FakeEntity extends ZEntity {
  const _FakeEntity(this.id);
  @override
  final String? id;
}

/// Fake repo générique exposant une `StreamController` observable — implémente le
/// port `ZStudyRepository<_FakeEntity>`.
class _FakeRepo extends ZStudyRepository<_FakeEntity> {
  _FakeRepo(this._controller);
  final StreamController<List<_FakeEntity>> _controller;

  @override
  Stream<List<_FakeEntity>> watchAll() => _controller.stream;

  @override
  Stream<List<_FakeEntity>> watch(ZDataRequest request) => _controller.stream;

  @override
  Future<ZResult<_FakeEntity>> persist(_FakeEntity item,
          {String? collectionId}) async =>
      Right<ZFailure, _FakeEntity>(item);

  @override
  Future<ZResult<List<_FakeEntity>>> getAll({ZDataRequest? request}) =>
      throw UnimplementedError();
  @override
  Future<ZResult<_FakeEntity>> getById(String id) => throw UnimplementedError();
  @override
  Future<ZResult<Unit>> softDelete(String id) => throw UnimplementedError();
  @override
  Future<ZResult<Unit>> restore(String id) => throw UnimplementedError();
  @override
  Future<ZResult<int>> count({ZDataRequest? request}) =>
      throw UnimplementedError();
  @override
  Future<ZResult<Unit>> sync() => throw UnimplementedError();
  @override
  void dispose() {}
}

/// Resolver de test : renvoie le repo enregistré par `Type`, sinon *throw*
/// `ZScopeError` (contrat miroir de `ZGetResolver`, AD-6).
class _MapResolver extends ZDependencyResolver {
  _MapResolver(this._bindings);
  final Map<Type, Object> _bindings;
  @override
  T resolve<T>() {
    final v = _bindings[T];
    if (v == null) {
      throw ZScopeError('Aucune dépendance de type «$T» enregistrée.');
    }
    return v as T;
  }
}

void main() {
  test('AC1 — le controller ré-émet EXACTEMENT la Stream<List<T>> nue du repo '
      '(ordre/contenu préservés)', () async {
    final controller = StreamController<List<_FakeEntity>>();
    addTearDown(controller.close);
    final repo = _FakeRepo(controller);
    final ctrl = ZStudyWatchController<_FakeEntity>(repo);
    addTearDown(ctrl.onClose);

    final emitted = <List<String?>>[];
    // Observe l'évolution de l'observable après chaque émission.
    ctrl.onInit();

    controller.add(const <_FakeEntity>[_FakeEntity('a')]);
    await Future<void>.delayed(Duration.zero);
    emitted.add(ctrl.items.map((e) => e.id).toList());

    controller.add(const <_FakeEntity>[_FakeEntity('a'), _FakeEntity('b')]);
    await Future<void>.delayed(Duration.zero);
    emitted.add(ctrl.items.map((e) => e.id).toList());

    expect(emitted, <List<String?>>[
      <String?>['a'],
      <String?>['a', 'b'],
    ]);
  });

  test('AC1 — les écritures du port restent NON enveloppées (Future<ZResult<T>>)',
      () async {
    // Broadcast : jamais écouté ici ⇒ close() ne bloque pas la fin de test.
    final controller = StreamController<List<_FakeEntity>>.broadcast();
    addTearDown(controller.close);
    final ctrl = ZStudyWatchController<_FakeEntity>(_FakeRepo(controller));
    final res = await ctrl.repository.save(const _FakeEntity('a'));
    expect(res.isRight(), isTrue, reason: 'contrat du port inchangé (AD-11)');
  });

  test('AC4 — seam de repo absent ⇒ ZScopeError actionnable (message contient '
      'le Type) [R3-I4]', () {
    final resolver = _MapResolver(<Type, Object>{}); // AUCUN repo enregistré.
    expect(
      () => buildStudyWatchController<_FakeEntity>(resolver),
      throwsA(
        isA<ZScopeError>().having(
          (e) => e.message,
          'message',
          contains('_FakeEntity'),
        ),
      ),
    );
  });

  test('AC4 — seam présent ⇒ controller construit avec le repo résolu', () {
    // Broadcast : jamais écouté ici ⇒ close() ne bloque pas la fin de test.
    final controller = StreamController<List<_FakeEntity>>.broadcast();
    addTearDown(controller.close);
    final repo = _FakeRepo(controller);
    final resolver = _MapResolver(<Type, Object>{
      ZStudyRepository<_FakeEntity>: repo,
    });
    final ctrl = buildStudyWatchController<_FakeEntity>(resolver);
    expect(ctrl, isA<ZStudyWatchController<_FakeEntity>>());
    expect(ctrl.repository, same(repo));
  });

  test('AC5 — onClose() annule la souscription au flux (onCancel appelé) : '
      'aucune fuite [R3-I5]', () async {
    var cancelled = false;
    final controller = StreamController<List<_FakeEntity>>(
      onCancel: () => cancelled = true,
    );
    final ctrl = ZStudyWatchController<_FakeEntity>(_FakeRepo(controller));

    ctrl.onInit();
    controller.add(const <_FakeEntity>[_FakeEntity('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isFalse, reason: 'souscription active tant qu\'on écoute');

    ctrl.onClose();
    await Future<void>.delayed(Duration.zero);
    expect(
      cancelled,
      isTrue,
      reason: 'onClose() DOIT annuler la souscription (onCancel). Retirer '
          '_sub.cancel() laisserait le flux vivant (R3-I5).',
    );
  });
}
