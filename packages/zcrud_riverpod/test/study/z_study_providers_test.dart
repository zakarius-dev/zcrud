// ES-10.1 AC1/AC4/AC5 — providers study génériques branchant le port
// `ZStudyRepository<T>` sur Riverpod.
//
// AC1 : `zStudyWatchAllProvider` ré-émet EXACTEMENT la `Stream<List<T>>` nue du
//        repo (ordre/contenu préservés, AD-5).
// AC4 : seam absent ⇒ `ZScopeError` actionnable (message contient le Type) —
//        R3-I4 : retirer/avaler le throw ⇒ rougit.
// AC5 : `.autoDispose` annule la souscription (StreamController.onCancel) ⇒ pas
//        de fuite — R3-I5 : retirer `.autoDispose` ⇒ rougit.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Entité de test minimale (identité opaque, AD-4).
class _FakeEntity extends ZEntity {
  const _FakeEntity(this.id);
  @override
  final String? id;
}

/// Fake repo générique exposant une `StreamController` observable — implémente le
/// port `ZStudyRepository<_FakeEntity>` (persist réel, reste non utilisé).
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

void main() {
  test('AC1 — zStudyWatchAllProvider ré-émet EXACTEMENT la Stream<List<T>> nue '
      'du repo (ordre/contenu préservés)', () async {
    final controller = StreamController<List<_FakeEntity>>();
    addTearDown(controller.close);
    final repo = _FakeRepo(controller);

    final repoSeam = zStudyRepositoryProvider<_FakeEntity>();
    final container = ProviderContainer(
      overrides: <Override>[repoSeam.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final watch = zStudyWatchAllProvider<_FakeEntity>(repo: repoSeam);
    final emitted = <List<String?>>[];
    container.listen<AsyncValue<List<_FakeEntity>>>(
      watch,
      (_, next) => next.whenData(
        (list) => emitted.add(list.map((e) => e.id).toList()),
      ),
    );

    controller.add(const <_FakeEntity>[_FakeEntity('a')]);
    controller.add(const <_FakeEntity>[_FakeEntity('a'), _FakeEntity('b')]);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, <List<String?>>[
      <String?>['a'],
      <String?>['a', 'b'],
    ]);
  });

  test('AC4 — seam de repo absent ⇒ ZScopeError actionnable (message contient '
      'le Type) [R3-I4]', () {
    final repoSeam = zStudyRepositoryProvider<_FakeEntity>();
    final container = ProviderContainer(); // AUCUN override.
    addTearDown(container.dispose);

    expect(
      () => container.read(repoSeam),
      throwsA(
        isA<ZScopeError>().having(
          (e) => e.message,
          'message',
          contains('_FakeEntity'),
        ),
      ),
    );
  });

  test('AC5 — .autoDispose annule la souscription au flux (onCancel) après la '
      'fin d\'écoute : aucune fuite [R3-I5]', () async {
    var cancelled = false;
    final controller = StreamController<List<_FakeEntity>>(
      onCancel: () => cancelled = true,
    );
    final repo = _FakeRepo(controller);

    final repoSeam = zStudyRepositoryProvider<_FakeEntity>();
    final container = ProviderContainer(
      overrides: <Override>[repoSeam.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    final watch = zStudyWatchAllProvider<_FakeEntity>(repo: repoSeam);
    final sub = container.listen<AsyncValue<List<_FakeEntity>>>(
      watch,
      (_, __) {},
    );
    // Une émission établit pleinement la souscription au flux du repo.
    controller.add(const <_FakeEntity>[_FakeEntity('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isFalse, reason: 'souscription active tant qu\'on écoute');

    sub.close();
    // L'auto-dispose Riverpod planifie la libération ; l'annulation de la
    // souscription au flux (onCancel) suit sur un tour de boucle ultérieur.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      cancelled,
      isTrue,
      reason: 'plus d\'écoute ⇒ auto-dispose annule la souscription au flux '
          '(onCancel). Retirer .autoDispose laisserait la souscription vivante.',
    );
  });
}
