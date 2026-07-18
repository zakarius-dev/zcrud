/// Fakes **en mémoire** pour les tests d'E9-4 — aucun Firebase/Hive.
///
/// - [FakeCardRepository] : implémente le port neutre
///   `ZSyncableRepository<ZFlashcard>` (matérialise l'`id` à `save`, estampille
///   `updatedAt`, couture `isConnected`, espion des `put`).
/// - [FakeRepetitionStore] : implémente le port flashcard-local
///   `ZRepetitionStore` (keyed by `flashcardId`, estampille `ZSyncMeta`
///   hors-entité, persiste la **map telle quelle** puis relit via
///   `ZRepetitionInfo.fromMap` — permet d'injecter un état **corrompu**, couture
///   offline/échec partiel).
library;

import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Fake en mémoire du port carte `ZSyncableRepository<ZFlashcard>`.
class FakeCardRepository extends ZSyncableRepository<ZFlashcard> {
  FakeCardRepository({this.connected = true});

  /// Couture de connectivité pour `sync()` (AC11).
  bool connected;

  /// Espion : nombre total d'appels `save` reçus (AC6/AC9 — doit rester 0
  /// pendant `reviewCard`, et l'appel doit être évité sur garde `folderId`).
  int saveCount = 0;

  /// Espion : nombre d'appels `sync()`.
  int syncCount = 0;

  final Map<String, ZFlashcard> _byId = <String, ZFlashcard>{};
  final Map<String, ZSyncMeta> _meta = <String, ZSyncMeta>{};
  var _seq = 0;

  @override
  Future<ZResult<ZFlashcard>> save(ZFlashcard item, {String? collectionId}) async {
    saveCount++;
    // Matérialisation de l'éphémère (AD-14) : attribution d'un id opaque +
    // estampille updated_at (clé LWW, ZSyncMeta hors-entité).
    final now = DateTime.now();
    final materialized = item.isEphemeral
        ? item.copyWith(id: 'mat-${_seq++}', updatedAt: now)
        : item.copyWith(updatedAt: now);
    final id = materialized.id!;
    _byId[id] = materialized;
    _meta[id] = ZSyncMeta(updatedAt: now);
    return Right<ZFailure, ZFlashcard>(materialized);
  }

  @override
  Future<ZResult<ZFlashcard>> getById(String id) async {
    final card = _byId[id];
    final meta = _meta[id];
    if (card == null || (meta?.isDeleted ?? false)) {
      return Left<ZFailure, ZFlashcard>(
        NotFoundFailure('carte introuvable', id: id, entity: 'flashcard'),
      );
    }
    return Right<ZFailure, ZFlashcard>(card);
  }

  @override
  Future<ZResult<List<ZFlashcard>>> getAll({ZDataRequest? request}) async {
    final visible = <ZFlashcard>[
      for (final e in _byId.entries)
        if (!(_meta[e.key]?.isDeleted ?? false)) e.value,
    ];
    return Right<ZFailure, List<ZFlashcard>>(visible);
  }

  @override
  Stream<List<ZFlashcard>> watchAll() async* {
    yield <ZFlashcard>[
      for (final e in _byId.entries)
        if (!(_meta[e.key]?.isDeleted ?? false)) e.value,
    ];
  }

  @override
  Stream<List<ZFlashcard>> watch(ZDataRequest request) => watchAll();

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async {
    final res = await getAll(request: request);
    return res.map((list) => list.length);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    if (!_byId.containsKey(id)) {
      return Left<ZFailure, Unit>(NotFoundFailure('carte introuvable', id: id));
    }
    _meta[id] = (_meta[id] ?? const ZSyncMeta()).copyWith(isDeleted: true);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    if (!_byId.containsKey(id)) {
      return Left<ZFailure, Unit>(NotFoundFailure('carte introuvable', id: id));
    }
    _meta[id] = (_meta[id] ?? const ZSyncMeta()).copyWith(isDeleted: false);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> sync() async {
    syncCount++;
    // Best-effort AD-9 : hors-ligne → Right(unit), local intact.
    if (!connected) return Right<ZFailure, Unit>(unit);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() {}
}

/// Fake en mémoire du port SRS flashcard-local `ZRepetitionStore`.
///
/// Persiste la **map telle quelle** (`toMap`) et relit via
/// `ZRepetitionInfo.fromMap` — mime la (dé)sérialisation réelle et permet
/// d'injecter un état **corrompu** ([injectRaw]) pour tester le défensif (AC8).
class FakeRepetitionStore implements ZRepetitionStore {
  FakeRepetitionStore({
    this.connected = true,
    this.failSync = false,
    this.failPut = false,
    this.failDeleteFor = const <String>{},
  });

  /// Couture de connectivité pour `sync()` (AC11).
  bool connected;

  /// Couture d'**échec partiel** : `sync()` renvoie `Left(ServerFailure)`
  /// (toléré/loggé par le coordinateur — AC11).
  bool failSync;

  /// Couture d'échec du `put` SRS : renvoie `Left(CacheFailure)` (utilisé pour
  /// prouver que `moveCard` LOGGE l'échec de re-sync — MEDIUM-2, jamais avalé).
  bool failPut;

  /// Couture d'**échec partiel** de purge (me-3, AC6) : `deleteByCard(id)`
  /// renvoie `Left(CacheFailure)` pour tout `id` de cet ensemble — permet de
  /// prouver qu'un échec de purge d'UNE racine est **rapporté** (jamais avalé)
  /// et que les **autres** racines continuent d'être purgées.
  Set<String> failDeleteFor;

  /// Espion : nombre d'appels `put` (voie d'écriture SRS).
  int putCount = 0;

  /// Espion (me-3, AC5) : `flashcardId` reçus par [deleteByCard], **dans
  /// l'ordre** — preuve FALSIFIABLE que la purge SRS a réellement lieu (compte
  /// EXACT + bons id). Prouvé captant AVANT toute assertion « purgé » (témoin).
  final List<String> deletedIds = <String>[];

  /// Espion : nombre d'appels `sync()`.
  int syncCount = 0;

  final Map<String, Map<String, dynamic>> _raw = <String, Map<String, dynamic>>{};
  final Map<String, ZSyncMeta> _meta = <String, ZSyncMeta>{};

  /// Injecte une map SRS **brute** (potentiellement corrompue) pour la carte
  /// [flashcardId] — utilisé par les tests du défensif (AC8).
  void injectRaw(String flashcardId, Map<String, dynamic> raw) {
    _raw[flashcardId] = raw;
    _meta[flashcardId] = ZSyncMeta(updatedAt: DateTime.now());
  }

  @override
  Future<ZResult<ZRepetitionInfo?>> getByCard(String flashcardId) async {
    final raw = _raw[flashcardId];
    if (raw == null) return Right<ZFailure, ZRepetitionInfo?>(null);
    // Reconstruction DÉFENSIVE (jamais de throw) — état corrompu toléré (AC8).
    return Right<ZFailure, ZRepetitionInfo?>(ZRepetitionInfo.fromMap(raw));
  }

  @override
  Future<ZResult<ZRepetitionInfo>> put(ZRepetitionInfo info) async {
    putCount++;
    if (failPut) {
      return Left<ZFailure, ZRepetitionInfo>(CacheFailure('put SRS KO'));
    }
    // Estampille LWW hors-entité (ZSyncMeta), persiste la map telle quelle.
    _raw[info.flashcardId] = info.toMap();
    _meta[info.flashcardId] = ZSyncMeta(updatedAt: DateTime.now());
    return Right<ZFailure, ZRepetitionInfo>(info);
  }

  @override
  Future<ZResult<List<ZRepetitionInfo>>> getAll() async {
    return Right<ZFailure, List<ZRepetitionInfo>>(<ZRepetitionInfo>[
      for (final raw in _raw.values) ZRepetitionInfo.fromMap(raw),
    ]);
  }

  @override
  Future<ZResult<Unit>> deleteByCard(String flashcardId) async {
    // Espion : consigne l'appel AVANT toute couture d'échec (l'ordre/le compte
    // sont assérés par les tests — preuve falsifiable de la purge, AC5).
    deletedIds.add(flashcardId);
    if (failDeleteFor.contains(flashcardId)) {
      // Panne réelle du store (AC6) : rapportée au grain de la racine, l'état
      // n'est PAS retiré (l'échec ne prétend jamais un succès).
      return Left<ZFailure, Unit>(CacheFailure('purge SRS KO pour "$flashcardId"'));
    }
    // Idempotence (AD-10) : purger un id absent est un SUCCÈS (no-op).
    _raw.remove(flashcardId);
    _meta.remove(flashcardId);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> sync() async {
    syncCount++;
    if (failSync) {
      return Left<ZFailure, Unit>(const ServerFailure('sync SRS distant indispo'));
    }
    if (!connected) return Right<ZFailure, Unit>(unit);
    return Right<ZFailure, Unit>(unit);
  }

  /// Lit la méta LWW hors-entité estampillée pour [flashcardId] (assertions).
  ZSyncMeta? metaOf(String flashcardId) => _meta[flashcardId];

  /// Lit la map SRS persistée brute pour [flashcardId] (assertions).
  Map<String, dynamic>? rawOf(String flashcardId) => _raw[flashcardId];

  @override
  void dispose() {}
}
