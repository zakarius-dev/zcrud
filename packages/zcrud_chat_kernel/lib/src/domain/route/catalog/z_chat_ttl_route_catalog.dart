/// Cache à durée de vie devant une source — `ZChatTtlRouteCatalog`
/// (invariants AD-9, AD-11).
///
/// Une source distante ne se consulte pas à chaque résolution : le cache
/// retient chaque réponse — routeur **ou absence** (cache négatif) — pendant
/// [ZChatTtlRouteCatalog.ttl], puis la redemande. Quand la source tombe en
/// panne (`Left`) alors qu'une entrée **périmée** existe, l'entrée périmée
/// est servie et la panne journalisée : le catalogue reste disponible le
/// temps que le backend revienne.
///
/// L'horloge est injectée (`ZClock`) : la durée de vie est mesurée, jamais
/// supposée.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_router.dart';
import 'z_chat_route_catalog_source.dart';

/// Une entrée datée ; [value] est `null` pour une absence mémorisée.
class _Entry<T> {
  const _Entry(this.value, this.at);
  final T value;
  final DateTime at;
}

/// Source **avec cache** : mémorise les réponses de [inner] pendant [ttl].
class ZChatTtlRouteCatalog implements ZChatRouteCatalogSource {
  /// Construit le cache devant [inner]. `ttl == Duration.zero` désactive la
  /// mémorisation (chaque appel interroge [inner]).
  ZChatTtlRouteCatalog(
    this.inner, {
    required this.ttl,
    ZClock clock = ZSystemClock.utc,
    this.log,
    // ignore: prefer_initializing_formals
  }) : _clock = clock;

  /// La source cachée.
  final ZChatRouteCatalogSource inner;

  /// Durée de vie d'une entrée ; `Duration.zero` = pas de cache.
  final Duration ttl;

  /// Journal optionnel (entrée périmée servie sur panne).
  final ZChatCatalogLog? log;

  final ZClock _clock;
  final Map<String, _Entry<ZChatRouter?>> _byId =
      <String, _Entry<ZChatRouter?>>{};
  _Entry<List<ZChatRouter>>? _all;

  /// Identités actuellement mémorisées (absences comprises).
  List<String> get cachedIds => List<String>.unmodifiable(_byId.keys);

  bool get _caching => ttl > Duration.zero;

  bool _fresh(DateTime at) => _clock().difference(at) < ttl;

  @override
  Future<ZResult<ZChatRouter?>> fetchRouter(String id) async {
    final _Entry<ZChatRouter?>? cached = _byId[id];
    if (cached != null && _fresh(cached.at)) {
      return Right<ZFailure, ZChatRouter?>(cached.value);
    }
    final ZResult<ZChatRouter?> result = await inner.fetchRouter(id);
    return result.fold(
      (ZFailure f) {
        if (cached == null) return Left<ZFailure, ZChatRouter?>(f);
        log?.call('route catalog: serving stale entry for $id', cause: f);
        return Right<ZFailure, ZChatRouter?>(cached.value);
      },
      (ZChatRouter? r) {
        if (_caching) _byId[id] = _Entry<ZChatRouter?>(r, _clock());
        return Right<ZFailure, ZChatRouter?>(r);
      },
    );
  }

  @override
  Future<ZResult<List<ZChatRouter>>> fetchAll() async {
    final _Entry<List<ZChatRouter>>? cached = _all;
    if (cached != null && _fresh(cached.at)) {
      return Right<ZFailure, List<ZChatRouter>>(cached.value);
    }
    final ZResult<List<ZChatRouter>> result = await inner.fetchAll();
    return result.fold(
      (ZFailure f) {
        if (cached == null) return Left<ZFailure, List<ZChatRouter>>(f);
        log?.call('route catalog: serving stale list', cause: f);
        return Right<ZFailure, List<ZChatRouter>>(cached.value);
      },
      (List<ZChatRouter> list) {
        final List<ZChatRouter> frozen = List<ZChatRouter>.unmodifiable(list);
        if (_caching) {
          final DateTime now = _clock();
          _all = _Entry<List<ZChatRouter>>(frozen, now);
          // La liste alimente les entrées unitaires : une résolution qui suit
          // un listing ne repart pas vers la source.
          for (final ZChatRouter r in frozen) {
            if (r.id != null) _byId[r.id!] = _Entry<ZChatRouter?>(r, now);
          }
        }
        return Right<ZFailure, List<ZChatRouter>>(frozen);
      },
    );
  }

  /// Oublie l'entrée [id] (et la liste, qui pouvait la porter), ou tout le
  /// cache si [id] est `null`.
  Future<void> invalidate([String? id]) async {
    if (id == null) {
      _byId.clear();
    } else {
      _byId.remove(id);
    }
    _all = null;
  }
}
