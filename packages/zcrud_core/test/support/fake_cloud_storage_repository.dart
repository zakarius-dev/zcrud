// Fake `CloudStorageRepository` (E3-3c) — prouve le comportement du port SANS
// aucune dépendance lourde (pas de firebase_storage). Succès → Right(uploaded +
// remoteUrl) ; échec → Left(ZServerFailure) ; delete → Right(unit).
import 'package:zcrud_core/zcrud_core.dart';

/// Fake déterministe du port de stockage cloud (aucune dépendance lourde).
class FakeCloudStorageRepository implements CloudStorageRepository {
  FakeCloudStorageRepository({this.fail = false});

  /// Si `true`, [upload] retourne `Left(ZServerFailure)`.
  bool fail;

  /// Nombre d'appels à [upload] (oracle de non-régression / retry).
  int uploadCount = 0;

  /// Fichiers passés à [delete].
  final List<AppFile> deleted = <AppFile>[];

  @override
  Future<ZResult<AppFile>> upload(AppFile file) async {
    uploadCount++;
    if (fail) {
      return Left<ZFailure, AppFile>(const ZServerFailure('upload failed'));
    }
    return Right<ZFailure, AppFile>(
      file.copyWith(
        uploadState: ZAppFileUploadState.uploaded,
        remoteUrl: 'https://cdn.example/${file.name}',
        id: file.id ?? 'remote-${file.name}',
      ),
    );
  }

  @override
  Future<ZResult<Unit>> delete(AppFile file) async {
    deleted.add(file);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<String>> downloadUrl(AppFile file) async =>
      file.remoteUrl != null
          ? Right<ZFailure, String>(file.remoteUrl!)
          : Left<ZFailure, String>(const ZNotFoundFailure('no remote url'));

  @override
  Stream<double> watchProgress(AppFile file) =>
      Stream<double>.fromIterable(<double>[0, 1]);
}
