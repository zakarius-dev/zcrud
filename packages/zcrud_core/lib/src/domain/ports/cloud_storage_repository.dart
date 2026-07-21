/// `CloudStorageRepository` — **port neutre** de stockage cloud de fichiers
/// (E3-3c). Contrat abstrait **backend-agnostique** (AD-5) : aucune signature
/// n'expose de type Firebase/`cloud_firestore` (`Timestamp`/`Filter`/
/// `FirebaseException`…). La traduction concrète (Firebase Storage) vit dans
/// l'adaptateur **E5** (`zcrud_firestore` → `FirebaseCloudStorageRepositoryImpl`),
/// **jamais ici** (AD-1 : `zcrud_core` OUT=0, aucune dépendance lourde).
///
/// origine: unique point de couplage Firebase Storage DODLP/IFFD
/// (`firebase_cloud_storage_repository_impl.dart`), généralisé en port neutre.
///
/// **Contrat de résultat** (AD-11) : les opérations retournent `ZResult<...>`
/// (`Either<ZFailure, T>`) et `ZResult<Unit>` pour les « void ». La
/// **progression** éventuelle est un `Stream<double>` **NU** — jamais enveloppé
/// dans un `Either`.
library;

import 'package:dartz/dartz.dart' show Unit;

import '../edition/app_file.dart';
import '../failures/z_failure.dart';

/// Contrat **abstrait** (port) de transport d'un [AppFile] vers/depuis un
/// stockage cloud. Aucune impl concrète dans `zcrud_core` (E5).
abstract class CloudStorageRepository {
  /// Téléverse les octets référencés par [file] (via son `localPath`) et
  /// retourne l'[AppFile] **mis à jour** — `remoteUrl` renseignée,
  /// `uploadState == ZAppFileUploadState.uploaded`. `Left(ZServerFailure)` en cas
  /// d'échec réseau/serveur.
  Future<ZResult<AppFile>> upload(AppFile file);

  /// Supprime la ressource distante référencée par [file] (par `remoteUrl`/`id`).
  /// `Right(unit)` si supprimée/inexistante ; `Left(ZServerFailure)` sinon.
  Future<ZResult<Unit>> delete(AppFile file);

  /// Résout l'URL de téléchargement de [file] (si connue côté backend).
  /// `Left(ZNotFoundFailure)` si la ressource est absente.
  Future<ZResult<String>> downloadUrl(AppFile file);

  /// Flux **nu** de progression d'upload `0..1` de [file] (AD-11 : jamais
  /// enveloppé dans un `Either`). Optionnel : une impl sans suivi fin peut
  /// émettre `0` puis `1`.
  Stream<double> watchProgress(AppFile file);
}
