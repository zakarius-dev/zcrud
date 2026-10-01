/// Store local limité à un dossier, au-dessus d'un [ZLocalStore] partagé.
///
/// Les lectures ne voient que les entités dont [folderIdOf] renvoie [folderId].
/// Une écriture utilisateur ([put], [putMerged], [softDelete], [restore],
/// [purge]) visant un autre dossier est refusée et ne touche pas le store
/// interne. [applyMerged] reste délégué : c'est la voie du merge, qui doit
/// pouvoir déposer l'entrée gagnante. [clear] ne vide que ce dossier.
/// [dispose] ne libère pas le store interne, qui peut servir d'autres dossiers.
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Filtre un [ZLocalStore] partagé sur l'identité d'un dossier.
class ZFolderScopedLocalStore<T extends ZEntity> implements ZLocalStore<T> {
  /// [folderIdOf] extrait le dossier d'une entité. Une exception est lue
  /// comme « hors dossier » : l'entité n'est pas exposée.
  ZFolderScopedLocalStore({
    required this.inner,
    required this.folderId,
    required this.folderIdOf,
  });

  /// Store partagé. Ce filtre ne le possède pas.
  final ZLocalStore<T> inner;

  /// Dossier visible.
  final String folderId;

  /// Lecture du dossier porté par une entité.
  final String? Function(T value) folderIdOf;

  bool _matches(T value) {
    try {
      return folderIdOf(value) == folderId;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<List<T>> watchAll() => inner.watchAll().map(
    (List<T> all) => all.where(_matches).toList(growable: false),
  );

  @override
  Future<ZResult<List<T>>> getAll() async {
    final ZResult<List<T>> raw = await inner.getAll();
    return raw.map(
      (List<T> all) => all.where(_matches).toList(growable: false),
    );
  }

  @override
  Future<ZResult<T>> getById(String id) async {
    final ZResult<T> raw = await inner.getById(id);
    return raw.fold(
      (ZFailure failure) => Left<ZFailure, T>(failure),
      (T value) => _matches(value)
          ? Right<ZFailure, T>(value)
          : Left<ZFailure, T>(ZNotFoundFailure('hors dossier', id: id)),
    );
  }

  @override
  Future<ZResult<T>> put(T item) {
    if (!_matches(item)) {
      return Future<ZResult<T>>.value(
        Left<ZFailure, T>(const ZDomainFailure('dossier incoherent')),
      );
    }
    return inner.put(item);
  }

  @override
  Future<ZResult<T>> putMerged(T item) {
    if (!_matches(item)) {
      return Future<ZResult<T>>.value(
        Left<ZFailure, T>(const ZDomainFailure('dossier incoherent')),
      );
    }
    return inner.putMerged(item);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    final ZResult<T> seen = await getById(id);
    return seen.fold(
      (ZFailure failure) => Left<ZFailure, Unit>(failure),
      (_) => inner.softDelete(id),
    );
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    final ZResult<List<ZSyncEntry<T>>> raw = await inner.syncEntries();
    final List<ZSyncEntry<T>>? entries = raw.fold(
      (_) => null,
      (List<ZSyncEntry<T>> value) => value,
    );
    if (entries == null) {
      return raw.fold(
        (ZFailure failure) => Left<ZFailure, Unit>(failure),
        (_) => const Left<ZFailure, Unit>(ZCacheFailure('lecture')),
      );
    }
    for (final ZSyncEntry<T> entry in entries) {
      if (entry.id == id && _matches(entry.entity)) return inner.restore(id);
    }
    return Left<ZFailure, Unit>(ZNotFoundFailure('hors dossier', id: id));
  }

  @override
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries() async {
    final ZResult<List<ZSyncEntry<T>>> raw = await inner.syncEntries();
    return raw.map(
      (List<ZSyncEntry<T>> all) => all
          .where((ZSyncEntry<T> e) => _matches(e.entity))
          .toList(growable: false),
    );
  }

  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry) =>
      inner.applyMerged(entry);

  @override
  Future<ZResult<Unit>> purge(String id) async {
    final ZResult<List<ZSyncEntry<T>>> raw = await inner.syncEntries();
    final List<ZSyncEntry<T>>? entries = raw.fold(
      (_) => null,
      (List<ZSyncEntry<T>> value) => value,
    );
    if (entries == null) {
      return raw.fold(
        (ZFailure failure) => Left<ZFailure, Unit>(failure),
        (_) => const Left<ZFailure, Unit>(ZCacheFailure('lecture')),
      );
    }
    for (final ZSyncEntry<T> entry in entries) {
      if (entry.id == id && _matches(entry.entity)) return inner.purge(id);
    }
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> clear() async {
    final ZResult<List<ZSyncEntry<T>>> raw = await syncEntries();
    final List<ZSyncEntry<T>>? entries = raw.fold(
      (_) => null,
      (List<ZSyncEntry<T>> value) => value,
    );
    if (entries == null) {
      return raw.fold(
        (ZFailure failure) => Left<ZFailure, Unit>(failure),
        (_) => const Left<ZFailure, Unit>(ZCacheFailure('lecture')),
      );
    }
    for (final ZSyncEntry<T> entry in entries) {
      final String? id = entry.id;
      if (id == null) continue;
      final ZResult<Unit> purged = await inner.purge(id);
      final ZFailure? failed = purged.fold((ZFailure f) => f, (_) => null);
      if (failed != null) return Left<ZFailure, Unit>(failed);
    }
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() {}
}
