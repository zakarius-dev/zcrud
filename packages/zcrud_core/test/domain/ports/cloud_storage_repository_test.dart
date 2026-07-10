// AC5 (E3-3c) — Port neutre `CloudStorageRepository` : le contrat retourne
// `ZResult` (Either<ZFailure,_>) ; un fake prouve upload→Right(uploaded),
// échec→Left(ServerFailure), delete→Right(unit), SANS dépendance lourde.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_cloud_storage_repository.dart';

void main() {
  const file = AppFile(
    name: 'doc.pdf',
    mimeType: 'application/pdf',
    localPath: '/tmp/doc.pdf',
  );

  test('upload succès → Right(uploaded + remoteUrl)', () async {
    final repo = FakeCloudStorageRepository();
    final res = await repo.upload(file);
    expect(res.isRight(), isTrue);
    final uploaded = res.getOrElse(() => const AppFile());
    expect(uploaded.uploadState, ZAppFileUploadState.uploaded);
    expect(uploaded.remoteUrl, isNotNull);
    expect(repo.uploadCount, 1);
  });

  test('upload échec → Left(ServerFailure)', () async {
    final repo = FakeCloudStorageRepository(fail: true);
    final res = await repo.upload(file);
    expect(res.isLeft(), isTrue);
    res.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('attendu Left'),
    );
  });

  test('delete → Right(unit)', () async {
    final repo = FakeCloudStorageRepository();
    final res = await repo.delete(file);
    expect(res.isRight(), isTrue);
    expect(res.getOrElse(() => throw StateError('x')), unit);
    expect(repo.deleted, contains(file));
  });

  test('downloadUrl : présente → Right ; absente → Left(NotFoundFailure)',
      () async {
    final repo = FakeCloudStorageRepository();
    final absent = await repo.downloadUrl(file);
    expect(absent.isLeft(), isTrue);
    final present = await repo.downloadUrl(
        file.copyWith(remoteUrl: 'https://cdn/doc.pdf'));
    expect(present.isRight(), isTrue);
    expect(present.getOrElse(() => ''), 'https://cdn/doc.pdf');
  });

  test('watchProgress : flux NU de double (jamais enveloppé — AD-11)', () async {
    final repo = FakeCloudStorageRepository();
    final values = await repo.watchProgress(file).toList();
    expect(values, <double>[0, 1]);
  });
}
